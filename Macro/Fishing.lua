local addonName, ns = ...
local L = ns.L
local Macro = ns.Macro

local FISHING_SPELL_ID = 131474
local LEGACY_FISHING_SPELL_ID = 7620

local function GetFishingOutfitIDs()
    local outfitIDs = {}
    for key, data in pairs(FitterCharacterSaved or {}) do
        local outfitID = type(key) == "string" and tonumber(key:match("^Outfit(%d+)$"))
        if outfitID and type(data) == "table" and type(data.Activities) == "table"
            and tContains(data.Activities, "fishing") then
            outfitIDs[#outfitIDs + 1] = outfitID
        end
    end
    return outfitIDs
end

-- Prefers the active outfit so no swap is needed, then keeps the previous
-- pick stable between rebuilds.
local function ResolveFishingOutfitID()
    local outfitIDs = GetFishingOutfitIDs()
    if #outfitIDs == 0 then
        ns.state.fishingOutfitID = nil
        return nil
    end
    local activeOutfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    local outfitID
    if tContains(outfitIDs, activeOutfitID) then
        outfitID = activeOutfitID
    elseif tContains(outfitIDs, ns.state.fishingOutfitID) then
        outfitID = ns.state.fishingOutfitID
    else
        outfitID = outfitIDs[math.random(#outfitIDs)]
    end
    ns.state.fishingOutfitID = outfitID
    return outfitID
end

local function BuildFishingMacroBody()
    local fishing = Macro.SpellName(FISHING_SPELL_ID,
        Macro.SpellName(LEGACY_FISHING_SPELL_ID, "Fishing"))
    local outfitID = ResolveFishingOutfitID()
    local prefix = outfitID and Macro.GetOutfitMacroPrefix(outfitID) or ""
    return "#showtooltip " .. fishing .. "\n" .. prefix .. "/cast " .. fishing
end

function Macro.UpdateFishing()
    if InCombatLockdown() then return end
    local rawBody = BuildFishingMacroBody()
    local index = GetMacroIndexByName(Macro.FISHING_MACRO_NAME)
    if index ~= 0 then
        local body = Macro.ApplyPreservation(Macro.FISHING_MACRO_NAME,
            rawBody, "LastFishingMacroBody")
        if GetMacroBody(index) ~= body then
            EditMacro(index, Macro.FISHING_MACRO_NAME, Macro.FISHING_MACRO_ICON, body)
        end
    end
    if ns.FishingButton then
        local keybindBody = rawBody:gsub("^#showtooltip[^\n]*\n", "")
        if ns.FishingButton:GetAttribute("macrotext") ~= keybindBody then
            ns.FishingButton:SetAttribute("macrotext", keybindBody)
        end
    end
end

function Macro.EnsureFishing()
    if InCombatLockdown() then return end
    if GetMacroIndexByName(Macro.FISHING_MACRO_NAME) ~= 0 then
        Macro.UpdateFishing()
        return
    end
    if GetNumMacros() >= Macro.MAX_ACCOUNT_MACROS then return end
    local body = BuildFishingMacroBody()
    CreateMacro(Macro.FISHING_MACRO_NAME, Macro.FISHING_MACRO_ICON, body, nil)
    if FitterCharacterSaved then
        FitterCharacterSaved.LastFishingMacroBody = body
    end
end

local function GetOutfitName(outfitID)
    local outfits = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo
        and C_TransmogOutfitInfo.GetOutfitsInfo()
    for _, info in ipairs(outfits or {}) do
        if info.outfitID == outfitID then return info.name end
    end
    return "Outfit " .. outfitID
end

-- Runs after the game fills in the Fishing spell tooltip from #showtooltip,
-- so Fitter's lines are appended below the default text.
if GameTooltip and GameTooltip.SetAction then
    hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
        if GetActionInfo(slot) ~= "macro"
            or GetActionText(slot) ~= Macro.FISHING_MACRO_NAME then
            return
        end
        local names = {}
        for _, outfitID in ipairs(GetFishingOutfitIDs()) do
            names[#names + 1] = GetOutfitName(outfitID)
        end
        table.sort(names)
        tooltip:AddLine(" ")
        if #names == 0 then
            tooltip:AddLine(L["No outfit has the Fishing activity, so this only casts Fishing."],
                0.7, 0.7, 0.7, true)
        else
            tooltip:AddLine(L["Switches to your Fishing outfit before casting:"],
                1, 0.82, 0, true)
            for _, name in ipairs(names) do
                tooltip:AddLine(name, 1, 1, 1)
            end
        end
        tooltip:Show()
    end)
end
