local addonName, ns = ...
local L = ns.L
local Macro = ns.Macro

-- An activity macro switches to an outfit with that activity, then runs the
-- activity's action. Each one has an action bar macro and a key binding
-- button that share the same body.
--
-- spec fields:
--   key          activity key stored in an outfit's Activities list
--   macroName    action bar macro name
--   icon         action bar macro icon
--   storageKey   FitterCharacterSaved key for the last generated body
--   stateKey     ns.state key for the outfit picked on the last build
--   buttonKey    ns key for the key binding button
--   buildAction  given whether the macro switches outfit, returns an
--                optional header line and the lines that run after it
--   tooltipHeader, tooltipEmpty  action bar tooltip lines
local activities = {}

local function GetActivityOutfitIDs(key)
    local outfitIDs = {}
    for savedKey, data in pairs(FitterCharacterSaved or {}) do
        local outfitID = type(savedKey) == "string"
            and tonumber(savedKey:match("^Outfit(%d+)$"))
        if outfitID and type(data) == "table" and type(data.Activities) == "table"
            and tContains(data.Activities, key) then
            outfitIDs[#outfitIDs + 1] = outfitID
        end
    end
    return outfitIDs
end

-- Prefers the active outfit so no swap is needed, then keeps the previous
-- pick stable between rebuilds.
local function ResolveOutfitID(spec)
    local outfitIDs = GetActivityOutfitIDs(spec.key)
    if #outfitIDs == 0 then
        ns.state[spec.stateKey] = nil
        return nil
    end
    local activeOutfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    local outfitID
    if tContains(outfitIDs, activeOutfitID) then
        outfitID = activeOutfitID
    elseif tContains(outfitIDs, ns.state[spec.stateKey]) then
        outfitID = ns.state[spec.stateKey]
    else
        outfitID = outfitIDs[math.random(#outfitIDs)]
    end
    ns.state[spec.stateKey] = outfitID
    return outfitID
end

local function BuildBody(spec)
    local outfitID = ResolveOutfitID(spec)
    local prefix = outfitID and Macro.GetOutfitMacroPrefix(outfitID) or ""
    local header, action = spec.buildAction(prefix ~= "")
    return (header and (header .. "\n") or "") .. prefix .. action
end

local function Update(spec)
    if InCombatLockdown() then return end
    local body = BuildBody(spec)
    local index = GetMacroIndexByName(spec.macroName)
    if index ~= 0 and Macro.CanEditMacros() then
        Macro.Write(index, spec.macroName, body, spec.storageKey, spec.icon)
    end
    Macro.SetButtonBody(ns[spec.buttonKey], Macro.StripTooltip(body))
end

local function Ensure(spec)
    if InCombatLockdown() then return end
    if GetMacroIndexByName(spec.macroName) ~= 0 then
        Update(spec)
        return
    end
    if GetNumMacros() >= Macro.MAX_ACCOUNT_MACROS then return end
    Macro.Create(spec.macroName, spec.icon, BuildBody(spec), spec.storageKey)
end

-- Returns update and ensure functions for the activity.
function Macro.RegisterActivity(spec)
    activities[#activities + 1] = spec
    return function() Update(spec) end, function() Ensure(spec) end
end

function Macro.UpdateActivities()
    for _, spec in ipairs(activities) do Update(spec) end
end

local function GetOutfitName(outfitID)
    local outfits = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo
        and C_TransmogOutfitInfo.GetOutfitsInfo()
    for _, info in ipairs(outfits or {}) do
        if info.outfitID == outfitID then return info.name end
    end
    return string.format(L["Outfit %d"], outfitID)
end

-- Runs after the game fills in the spell tooltip from #showtooltip, so
-- Fitter's lines are appended below the default text.
if GameTooltip and GameTooltip.SetAction then
    hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
        if GetActionInfo(slot) ~= "macro" then return end
        local text = GetActionText(slot)
        local spec
        for _, candidate in ipairs(activities) do
            if candidate.macroName == text then spec = candidate break end
        end
        if not spec then return end
        local names = {}
        for _, outfitID in ipairs(GetActivityOutfitIDs(spec.key)) do
            names[#names + 1] = GetOutfitName(outfitID)
        end
        table.sort(names)
        tooltip:AddLine(" ")
        if #names == 0 then
            tooltip:AddLine(spec.tooltipEmpty, 0.7, 0.7, 0.7, true)
        else
            tooltip:AddLine(spec.tooltipHeader, 1, 0.82, 0, true)
            for _, name in ipairs(names) do
                tooltip:AddLine(name, 1, 1, 1)
            end
        end
        tooltip:Show()
    end)
end
