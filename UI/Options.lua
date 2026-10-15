local addonName, ns = ...
local L = ns.L

local UI_Options = {}
ns.UI_Options = UI_Options

-- Scalar defaults; also used as each registered setting's Defaults value.
local DEFAULTS = {
    UseDruidMacro = false,
    UseShamanMacro = false,
    UseMonkMacro = false,
    CopyTargetMount = false,
    ShiftHearthstoneCondition = "None",
    AltHearthstoneCondition = "None",
    CtrlHearthstoneCondition = "None",
    AutoEnableZoneSituations = false,
    AutoDisableZoneSituations = false,
    RemoveMacroChangesOnUpdate = false,
    ShowTooltipMount = true,
    UseZoneSpecificMounts = false,
    ShowTooltipHearthstone = true,
    AstralRecallFallback = false,
    CancelNonOutfitToys = false,
    ApplyToyOnSelect = false,
    DismissPetOnStealth = false,
    DismissPetInInstancesWhileGrouped = false,
    ReviveHunterPet = false,
    AccountWideFlyingEnabled = false,
    AccountWideGroundEnabled = false,
    AccountWideAquaticEnabled = false,
    AccountWideFlyingRandom = false,
    AccountWideGroundRandom = false,
    AccountWideAquaticRandom = false,
    EmoteGlobalCooldown = 25,
}
UI_Options.DEFAULTS = DEFAULTS

local TABLE_KEYS = {
    "DefaultFlying",
    "DefaultGround",
    "AccountWideFlyingMounts",
    "AccountWideGroundMounts",
    "AccountWideAquaticMounts",
}

local function EnsureDefaults()
    if FitterSaved == nil then FitterSaved = {} end
    for key, value in pairs(DEFAULTS) do
        if FitterSaved[key] == nil then FitterSaved[key] = value end
    end
    for _, key in ipairs(TABLE_KEYS) do
        if FitterSaved[key] == nil then FitterSaved[key] = {} end
    end
    FitterSaved.EmoteGlobalCooldown =
        math.max(5, math.min(60, tonumber(FitterSaved.EmoteGlobalCooldown) or 25))
end

local function OnDruidMacroChanged()
    if not (ns.Fitter and ns.Fitter.UpdateMacroForCurrentState) then return end
    C_Timer.After(0.1, function()
        if not InCombatLockdown() then ns.Fitter:UpdateMacroForCurrentState() end
    end)
end

local function OnGroundMountModifierChanged()
    if not (ns.Fitter and ns.Fitter.UpdateMacroForCurrentState) then return end
    C_Timer.After(0.1, function()
        if not InCombatLockdown() then ns.Fitter:UpdateMacroForCurrentState() end
    end)
end

local function OnHearthstoneSettingChanged()
    if not (ns.Fitter and ns.Fitter.UpdateHearthstoneMacro) then return end
    C_Timer.After(0.1, function()
        if not InCombatLockdown() then ns.Fitter:UpdateHearthstoneMacro() end
    end)
end

local function OnPetSettingChanged()
    if not (ns.Fitter and ns.Fitter.UpdatePet) then return end
    C_Timer.After(0.1, function()
        if not InCombatLockdown() then ns.Fitter:UpdatePet() end
    end)
end

local function OnHunterPetSettingChanged()
    if not (ns.Fitter and ns.Fitter.UpdateMacroForCurrentState) then return end
    C_Timer.After(0.1, function()
        if not InCombatLockdown() then
            ns.Fitter:UpdateMacroForCurrentState()
        elseif ns.MarkMacroRefreshPending then
            ns.MarkMacroRefreshPending()
        end
    end)
end

-- Settings helpers --

local category, layout

-- Re-evaluates shown/enabled predicates so dependent rows (such as the account
-- wide mount lists) appear or disappear as soon as their checkbox changes.
function UI_Options.RepairDisplay()
    if not (SettingsPanel and SettingsPanel:IsShown()) then return end
    if SettingsInbound and SettingsInbound.RepairDisplay then
        SettingsInbound.RepairDisplay()
    elseif SettingsPanel.RepairDisplay then
        SettingsPanel:RepairDisplay()
    end
end

local function AddHeader(text)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L[text]))
end

-- Binds a checkbox directly to FitterSaved[key]; returns the setting and its initializer.
local function AddCheckbox(key, label, tooltip, onChange)
    local setting = Settings.RegisterAddOnSetting(category, "Fitter_" .. key, key,
        FitterSaved, Settings.VarType.Boolean, L[label], DEFAULTS[key])
    if onChange then
        setting:SetValueChangedCallback(function() onChange() end)
    end
    local initializer = Settings.CreateCheckbox(category, setting, tooltip and L[tooltip])
    return setting, initializer
end

local function AddButton(label, buttonText, tooltip, onClick)
    layout:AddInitializer(CreateSettingsButtonInitializer(
        L[label], L[buttonText], onClick, tooltip, true))
end

-- Condition values are "None", toy item IDs, or housing neighborhood keys, so
-- the setting stores them as strings and converts IDs back to numbers.
local function AddHearthstoneConditionDropdown(modifier)
    local key = modifier .. "HearthstoneCondition"
    local function GetValue() return tostring(FitterSaved[key] or "None") end

    local setting = Settings.RegisterProxySetting(category, "Fitter_" .. key,
        Settings.VarType.String, string.format(L["%s Condition"], modifier), "None",
        GetValue,
        function(value)
            FitterSaved[key] = tonumber(value) or value
            OnHearthstoneSettingChanged()
        end)

    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        local current = GetValue()
        for _, option in ipairs(ns.Constants.HEARTHSTONE_CONDITIONS) do
            local value = tostring(option.id or "None")
            if option.alwaysAvailable or PlayerHasToy(option.id) or value == current then
                container:Add(value, option.label)
            end
        end
        if ns.Housing then
            for _, option in ipairs(ns.Housing.GetConditions()) do
                container:Add(option.key, option.label)
            end
        end
        return container:GetData()
    end

    Settings.CreateDropdown(category, setting, GetOptions,
        "Choose the teleport Fitter uses when you hold " .. modifier
        .. " while using the hearthstone macro or key binding.")
end

StaticPopupDialogs.FITTER_RESET_DEFAULT_HEARTHSTONES = {
    text = L["Reset outfits that have only the default Hearthstone selected?\n\nThis applies now to this character and when each other character on the account next logs in."],
    button1 = L["Reset"],
    button2 = L["Cancel"],
    OnAccept = function()
        if ns.Fitter and ns.Fitter.ResetDefaultHearthstones then
            ns.Fitter:ResetDefaultHearthstones()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function UI_Options:Register()
    EnsureDefaults()
    category, layout = Settings.RegisterVerticalLayoutCategory("Fitter")

    -- ===== General =====

    AddHeader("General")
    AddCheckbox("RemoveMacroChangesOnUpdate",
        "Remove Macro Changes On Update",
        "When enabled, changes to this addon's macros will be cleared whenever"
        .. " the macro is updated for different outfits, zones, etc.")
    AddButton("Create Outfit Update Macro", "Create Macro",
        "Create a macro that updates your outfit by applying toys and titles,"
        .. " and summoning pets, based on your current outfit or zone you are in.",
        function()
            if ns.Macro and ns.Macro.EnsureOutfitUpdateMacro then
                ns.Macro.EnsureOutfitUpdateMacro()
            end
        end)
    AddButton("Create Character Outfit Update Macro", "Create Macro",
        "Creates a character-specific version of the outfit update macro in your"
        .. " character macro list, allowing it to be used alongside an ability on"
        .. " your action bar.\n\n"
        .. "It is suggested to disable |cffffd100Remove Macro Changes On Update|r before"
        .. " adding abilities to this macro, to prevent them from being removed on updates.",
        function()
            if ns.Macro and ns.Macro.EnsureCharacterOutfitUpdateMacro then
                ns.Macro.EnsureCharacterOutfitUpdateMacro()
            end
        end)

    -- ===== Mount Features =====

    AddHeader("Mounts")
    AddCheckbox("ShowTooltipMount",
        "Show Tooltip in Mount Macro",
        "Include #showtooltip in the mount macro. Disabling this frees up space"
        .. " for custom macro text and/or toys in the mount macro.",
        OnGroundMountModifierChanged)
    AddCheckbox("UseDruidMacro",
        "Use Druid Macro",
        "Replace the standard FitterMount on druid characters that intelligently"
        .. " transforms into flight form, cat form, aquatic form, or summons a mount"
        .. " while not moving.",
        OnDruidMacroChanged)
    AddCheckbox("UseShamanMacro",
        "Use Shaman Macro",
        "Replace the standard FitterMount on shaman characters that casts Ghost Wolf"
        .. " when not already in Ghost Wolf form, or summons a mount otherwise.",
        OnDruidMacroChanged)
    AddCheckbox("UseMonkMacro",
        "Use Monk Macro",
        "Replace the standard FitterMount on monk characters that casts Zen Flight"
        .. " when not already in Zen Flight, or summons a mount otherwise.",
        OnDruidMacroChanged)
    AddCheckbox("UseZoneSpecificMounts",
        "Use Zone Specific Mounts",
        "Summon a special mount intended for the current zone when it is available"
        .. " to this character. Currently uses the G-99 Breakneck in Undermine.",
        OnGroundMountModifierChanged)
    AddCheckbox("CopyTargetMount",
        "Copy Target Player's Mount",
        "When targeting a mounted player whose mount you own, summon that mount"
        .. " instead. Otherwise, the regular mount selection is used.")

    -- ===== Hearthstone Features =====

    AddHeader("Hearthstones")
    AddCheckbox("ShowTooltipHearthstone",
        "Show Tooltip in Hearthstone Macro",
        "Include #showtooltip in the hearthstone macro. Disabling this frees up"
        .. " additional space for custom macro text.",
        OnHearthstoneSettingChanged)
    AddCheckbox("AstralRecallFallback",
        "Astral Recall Fallback",
        "On Shaman characters, use Astral Recall when the selected Hearthstone"
        .. " cannot be used because it is on cooldown.",
        OnHearthstoneSettingChanged)
    AddHearthstoneConditionDropdown("Shift")
    AddHearthstoneConditionDropdown("Ctrl")
    AddHearthstoneConditionDropdown("Alt")
    AddButton("Reset Default Hearthstones", "Reset", nil, function()
        StaticPopup_Show("FITTER_RESET_DEFAULT_HEARTHSTONES")
    end)

    -- ===== Pet Features =====

    AddHeader("Pets")
    AddCheckbox("DismissPetOnStealth",
        "Dismiss Pet On Stealth",
        "When enabled, dismiss the currently summoned battle pet when your character"
        .. " becomes stealthed.")
    AddCheckbox("DismissPetInInstancesWhileGrouped",
        "Dismiss Pet In Instances While Grouped",
        "When enabled, dismiss the currently summoned battle pet in any instance while"
        .. " you are in a party or raid, and prevent Fitter from summoning one there.",
        OnPetSettingChanged)

    -- ===== Hunter Pet Features =====

    AddHeader("Hunter Pets")
    AddCheckbox("ReviveHunterPet",
        "Revive Pet",
        "When enabled, Fitter attempts to revive a dead hunter pet before continuing."
        .. " When disabled, Fitter only attempts to summon the selected hunter pet."
        .. " If the pet's corpse has despawned, it must be resurrected manually"
        .. " regardless of whether this setting is enabled.",
        OnHunterPetSettingChanged)

    -- ===== Emote Features =====

    AddHeader("Emotes")
    local cooldownSetting = Settings.RegisterAddOnSetting(category,
        "Fitter_EmoteGlobalCooldown", "EmoteGlobalCooldown", FitterSaved,
        Settings.VarType.Number, L["Global Cooldown"], DEFAULTS.EmoteGlobalCooldown)
    local cooldownOptions = Settings.CreateSliderOptions(5, 60, 1)
    cooldownOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right,
        function(value) return math.floor(value + 0.5) .. "s" end)
    Settings.CreateSlider(category, cooldownSetting, cooldownOptions)

    -- ===== Toy Features =====

    AddHeader("Cosmetic Toys")
    AddCheckbox("CancelNonOutfitToys",
        "Cancel Non-Outfit Cosmetic Toys",
        "When switching outfits, automatically cancel any active toys from the"
        .. " previous outfit that are not also selected by the new outfit.")
    AddCheckbox("ApplyToyOnSelect",
        "Apply Toy On Select",
        "When selecting or deselecting a toy while the outfit is currently active,"
        .. " immediately activate or cancel the toy.")

    -- ===== Zone Features =====

    AddHeader("Zones")
    local autoEnableSetting, autoEnableInit = AddCheckbox("AutoEnableZoneSituations",
        "Auto Enable Zone Situations",
        "When enabled, associating zones with an outfit will automatically enable their"
        .. " respective Location situations: Rest for cities and World for others.")
    local autoDisableSetting, autoDisableInit = AddCheckbox("AutoDisableZoneSituations",
        "Auto Disable Zone Situations",
        "|cff66ccff" .. L["Requires Auto Enable Zone Situations enabled."] .. "|r\n\n"
        .. L["When enabled, unselecting the last city or other zone associated with an outfit"
        .. " will disable the respective Location situation: Rest for cities and World for"
        .. " others. Only situations that were enabled by Fitter are disabled, determined"
        .. " by the situation state captured before auto-enabling."])
    autoDisableInit:SetParentInitializer(autoEnableInit,
        function() return autoEnableSetting:GetValue() end)

    autoEnableSetting:SetValueChangedCallback(function(_, value)
        if not value then
            autoDisableSetting:SetValue(false)
            -- Clear all per-outfit situation baselines; they're only relevant when Auto Enable is on
            if FitterCharacterSaved then
                for key, outfitData in pairs(FitterCharacterSaved) do
                    if type(key) == "string" and key:match("^Outfit") and type(outfitData) == "table" then
                        outfitData.SituationBaseline = nil
                    end
                end
            end
        end
        UI_Options.RepairDisplay()
    end)

    -- ===== Account Wide =====

    UI_Options:InitializeAccountWide(layout, AddCheckbox)

    Settings.RegisterAddOnCategory(category)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        UI_Options:Register()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
