local addonName, ns = ...

-- One-button fishing: while the Fishing channel is active, the Cast Fishing
-- keybind and any action bar key holding the Outfit Fishing macro are rebound
-- to Interact With Target, so the next press reels in the bobber.

local FISHING_CHANNEL_SPELLS = {
    [131474] = true,
    [131476] = true,
    [131490] = true,
}

-- Soft-target interact is what lets Interact With Target pick up the bobber.
local CVARS = {
    SoftTargetInteract = "3",
    SoftTargetInteractArc = "2",
    SoftTargetInteractRange = "30",
}

local handler = CreateFrame("Frame", nil, nil,
    "SecureHandlerStateTemplate, SecureHandlerAttributeTemplate")
handler:SetAttribute("_onattributechanged", [[
    if name == "state-combat" and value == "clear" then
        self:ClearBindings()
    end
]])
RegisterStateDriver(handler, "combat", "[combat] clear; noop")

local storedCVars
local restorePending

local function RestoreCVars()
    if not storedCVars then return end
    if InCombatLockdown() then
        restorePending = true
        return
    end
    for name, value in pairs(storedCVars) do
        C_CVar.SetCVar(name, value)
    end
    storedCVars = nil
    restorePending = false
end

local function ApplyCVars()
    storedCVars = storedCVars or {}
    for name, value in pairs(CVARS) do
        if storedCVars[name] == nil then
            storedCVars[name] = C_CVar.GetCVar(name)
        end
        C_CVar.SetCVar(name, value)
    end
end

local function OverrideKeys(bindingAction)
    local key1, key2 = GetBindingKey(bindingAction)
    if key1 then SetOverrideBinding(handler, true, key1, "INTERACTTARGET") end
    if key2 then SetOverrideBinding(handler, true, key2, "INTERACTTARGET") end
end

local function OverrideFishingKeys()
    OverrideKeys("CLICK FitterFishingButton:LeftButton")
    local barNames = ActionButtonUtil and ActionButtonUtil.ActionBarButtonNames
    for _, barName in ipairs(barNames or {}) do
        for index = 1, NUM_ACTIONBAR_BUTTONS do
            local button = _G[barName .. index]
            local slot = button and button.action
            if slot and button.bindingAction
                and GetActionInfo(slot) == "macro"
                and GetActionText(slot) == ns.Macro.FISHING_MACRO_NAME then
                OverrideKeys(button.bindingAction)
            end
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
        if not FISHING_CHANNEL_SPELLS[spellID] or InCombatLockdown() then return end
        ApplyCVars()
        OverrideFishingKeys()
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if not FISHING_CHANNEL_SPELLS[spellID] then return end
        if not InCombatLockdown() then ClearOverrideBindings(handler) end
        RestoreCVars()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if restorePending then RestoreCVars() end
    elseif event == "PLAYER_LOGOUT" then
        if storedCVars then
            for name, value in pairs(storedCVars) do
                C_CVar.SetCVar(name, value)
            end
        end
    end
end)
