local addonName, ns = ...
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
    local index = GetMacroIndexByName(Macro.FISHING_MACRO_NAME)
    if index == 0 then return end
    local body = Macro.ApplyPreservation(Macro.FISHING_MACRO_NAME,
        BuildFishingMacroBody(), "LastFishingMacroBody")
    if GetMacroBody(index) ~= body then
        EditMacro(index, Macro.FISHING_MACRO_NAME, Macro.FISHING_MACRO_ICON, body)
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
