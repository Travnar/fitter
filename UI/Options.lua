local addonName, ns = ...
local L = ns.L

local UI_Options = {}
ns.UI_Options = UI_Options

local function EnsureDefaults()
    if FitterSaved == nil then FitterSaved = {} end
    if FitterSaved.UseDruidMacro == nil then FitterSaved.UseDruidMacro = false end
    if FitterSaved.UseShamanMacro == nil then FitterSaved.UseShamanMacro = false end
    if FitterSaved.ShiftMountCondition == nil then FitterSaved.ShiftMountCondition = "None" end
    if FitterSaved.AltMountCondition == nil then FitterSaved.AltMountCondition = "None" end
    if FitterSaved.CtrlMountCondition == nil then FitterSaved.CtrlMountCondition = "None" end
    if FitterSaved.ShiftHearthstoneCondition == nil then FitterSaved.ShiftHearthstoneCondition = "None" end
    if FitterSaved.AltHearthstoneCondition == nil then FitterSaved.AltHearthstoneCondition = "None" end
    if FitterSaved.CtrlHearthstoneCondition == nil then FitterSaved.CtrlHearthstoneCondition = "None" end
    local renamedMountConditions = {
        ["Ground Expedition Yak"] = "Grand Expedition Yak",
        ["Reins of the Mighty Caravan Brutosaur"] = "Mighty Caravan Brutosaur",
    }
    for _, key in ipairs({"ShiftMountCondition", "CtrlMountCondition", "AltMountCondition"}) do
        FitterSaved[key] = renamedMountConditions[FitterSaved[key]] or FitterSaved[key]
    end
    -- Migrate the former single Ground Mount option once.
    if FitterSaved.GroundMountModifier and FitterSaved.GroundMountModifier ~= "None" then
        local key = FitterSaved.GroundMountModifier .. "MountCondition"
        FitterSaved[key] = "Ground Mount"
    end
    FitterSaved.GroundMountModifier = nil
    if FitterSaved.DefaultFlying == nil then FitterSaved.DefaultFlying = {} end
    if FitterSaved.DefaultGround == nil then FitterSaved.DefaultGround = {} end
    if FitterSaved.AutoEnableZoneSituations == nil then FitterSaved.AutoEnableZoneSituations = false end
    if FitterSaved.AutoDisableZoneSituations == nil then FitterSaved.AutoDisableZoneSituations = false end
    if FitterSaved.RemoveMacroChangesOnUpdate == nil then FitterSaved.RemoveMacroChangesOnUpdate = false end
    if FitterSaved.ShowTooltipMount == nil then FitterSaved.ShowTooltipMount = true end
    if FitterSaved.UseZoneSpecificMounts == nil then FitterSaved.UseZoneSpecificMounts = false end
    if FitterSaved.ShowTooltipHearthstone == nil then FitterSaved.ShowTooltipHearthstone = true end
    if FitterSaved.AstralRecallFallback == nil then FitterSaved.AstralRecallFallback = false end
    if FitterSaved.CancelNonOutfitToys == nil then FitterSaved.CancelNonOutfitToys = false end
    if FitterSaved.ApplyToyOnSelect == nil then FitterSaved.ApplyToyOnSelect = false end
    if FitterSaved.DismissPetOnStealth == nil then FitterSaved.DismissPetOnStealth = false end
    if FitterSaved.DismissPetInInstancesWhileGrouped == nil then FitterSaved.DismissPetInInstancesWhileGrouped = false end
    if FitterSaved.ReviveHunterPet == nil then FitterSaved.ReviveHunterPet = false end
    if FitterSaved.AccountWideFlyingEnabled == nil then FitterSaved.AccountWideFlyingEnabled = false end
    if FitterSaved.AccountWideFlyingMounts == nil then FitterSaved.AccountWideFlyingMounts = {} end
    if FitterSaved.AccountWideGroundEnabled == nil then FitterSaved.AccountWideGroundEnabled = false end
    if FitterSaved.AccountWideGroundMounts == nil then FitterSaved.AccountWideGroundMounts = {} end
    if FitterSaved.AccountWideFlyingRandom == nil then FitterSaved.AccountWideFlyingRandom = false end
    if FitterSaved.AccountWideGroundRandom == nil then FitterSaved.AccountWideGroundRandom = false end
    if FitterSaved.AccountWideAquaticEnabled == nil then FitterSaved.AccountWideAquaticEnabled = false end
    if FitterSaved.AccountWideAquaticMounts == nil then FitterSaved.AccountWideAquaticMounts = {} end
    if FitterSaved.AccountWideAquaticRandom == nil then FitterSaved.AccountWideAquaticRandom = false end
    if FitterSaved.EmoteGlobalCooldown == nil then FitterSaved.EmoteGlobalCooldown = 25 end
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

-- Canvas layout helpers --

local HEADER_X  = 16   -- category headers indented from panel edge
local OPTION_X  = 36   -- options indented from category headers
local CB_X      = 340  -- fixed X for checkboxes/controls (right-aligned)

local function MakeSectionHeader(frame, text, x, y)
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    header:SetTextColor(1, 1, 1, 1)
    header:SetText(L[text])
    return header
end

local function MakeCheckbox(frame, key, label, tooltip, x, y, onChange)
    local row = CreateFrame("Frame", nil, frame)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    row:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    row:SetHeight(26)

    local cb = CreateFrame("CheckButton", nil, row, "SettingsCheckBoxTemplate")
    cb:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    cb:SetScript("OnClick", function(self)
        if FitterSaved then FitterSaved[key] = self:GetChecked() end
        if onChange then onChange() end
    end)

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", row, "LEFT", 0, 0)
    lbl:SetText(L[label])

    if tooltip then
        local function ShowTip(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[label], 1, 1, 1)
            if type(tooltip) == "table" then
                for _, line in ipairs(tooltip) do
                    GameTooltip:AddLine(L[line[1]], line[2], line[3], line[4], line[5])
                end
            else
                GameTooltip:AddLine(L[tooltip], 1, 0.82, 0, true)
            end
            GameTooltip:Show()
        end
        row:SetScript("OnEnter", ShowTip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cb:HookScript("OnEnter", ShowTip)
        cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return cb
end

function UI_Options:Initialize(optionsFrame, alreadyRegistered)
    EnsureDefaults()

    optionsFrame = optionsFrame or CreateFrame("Frame")
    if not alreadyRegistered then optionsFrame:Hide() end
    optionsFrame.OnCommit  = function() end
    optionsFrame.OnDefault = function() end

    local titleText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetFont("Fonts\\FRIZQT__.TTF", 22, "")
    titleText:SetShadowColor(0, 0, 0, 0.8)
    titleText:SetShadowOffset(1, -1)
    titleText:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 12, -16)
    titleText:SetText("Fitter")
    titleText:SetTextColor(1, 1, 1, 1)

    local titleSep = optionsFrame:CreateTexture(nil, "ARTWORK")
    titleSep:SetHeight(1)
    titleSep:SetPoint("TOPLEFT",  optionsFrame, "TOPLEFT",  0, -44)
    titleSep:SetPoint("TOPRIGHT", optionsFrame, "TOPRIGHT", 0, -44)
    titleSep:SetColorTexture(0.4, 0.4, 0.4, 0.8)

    -- Viewport: fills the canvas below the title, leaving the right edge for the scrollbar
    local scrollBox = CreateFrame("Frame", nil, optionsFrame, "WowScrollBox")
    scrollBox:SetPoint("TOPLEFT",     optionsFrame, "TOPLEFT",     0, -52)
    scrollBox:SetPoint("BOTTOMRIGHT", optionsFrame, "BOTTOMRIGHT", -14,  0)
    scrollBox:EnableMouseWheel(true)

    -- MinimalScrollBar — visibility managed automatically by AddManagedScrollBarVisibilityBehavior
    local scrollBar = CreateFrame("EventFrame", nil, optionsFrame, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT",    scrollBox, "TOPRIGHT",    1, -4)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 1,  4)

    -- Scroll child: WowScrollBox scrolls this frame; scrollable=true is required
    local scrollChild = CreateFrame("Frame", nil, scrollBox)
    scrollChild.scrollable = true

    -- Content frame — all widgets live here; height updated dynamically
    local content = CreateFrame("Frame", nil, scrollChild)
    content:SetWidth(580)
    content:SetHeight(600)
    content:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)

    ScrollUtil.InitScrollBoxWithScrollBar(scrollBox, scrollBar, CreateScrollBoxLinearView())
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar)
    scrollBox:SetPanExtent(50)

    -- ===== General =====

    MakeSectionHeader(content, "General", HEADER_X, -10)
    local cbRemoveMacro = MakeCheckbox(content, "RemoveMacroChangesOnUpdate",
        "Remove Macro Changes On Update",
        "When enabled, changes to this addon's macros will be cleared whenever"
        .. " the macro is updated for different outfits, zones, etc.",
        OPTION_X, -40)

    local createOutfitUpdateRow = CreateFrame("Frame", nil, content)
    createOutfitUpdateRow:SetPoint("TOPLEFT", content, "TOPLEFT", OPTION_X, -70)
    createOutfitUpdateRow:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    createOutfitUpdateRow:SetHeight(26)

    local createOutfitUpdateLabel = createOutfitUpdateRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    createOutfitUpdateLabel:SetPoint("LEFT", createOutfitUpdateRow, "LEFT", 0, 0)
    createOutfitUpdateLabel:SetText(L["Create Outfit Update Macro"])

    local createOutfitUpdateBtn = CreateFrame("Button", nil, createOutfitUpdateRow, "UIPanelButtonTemplate")
    createOutfitUpdateBtn:SetSize(110, 22)
    createOutfitUpdateBtn:SetPoint("RIGHT", createOutfitUpdateRow, "RIGHT", 0, 0)
    createOutfitUpdateBtn:SetText(L["Create Macro"])
    createOutfitUpdateBtn:SetScript("OnClick", function()
        if ns.Macro and ns.Macro.EnsureOutfitUpdateMacro then
            ns.Macro.EnsureOutfitUpdateMacro()
        end
    end)

    local function ShowOutfitUpdateTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Create Outfit Update Macro"], 1, 1, 1)
        GameTooltip:AddLine(
            "Create a macro that updates your outfit by applying toys and titles,"
            .. " and summoning pets, based on your current outfit or zone you are in.",
            1, 0.82, 0, true)
        GameTooltip:Show()
    end
    createOutfitUpdateRow:SetScript("OnEnter", ShowOutfitUpdateTip)
    createOutfitUpdateRow:SetScript("OnLeave", function() GameTooltip:Hide() end)
    createOutfitUpdateBtn:HookScript("OnEnter", ShowOutfitUpdateTip)
    createOutfitUpdateBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local createCharOutfitUpdateRow = CreateFrame("Frame", nil, content)
    createCharOutfitUpdateRow:SetPoint("TOPLEFT", content, "TOPLEFT", OPTION_X, -100)
    createCharOutfitUpdateRow:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    createCharOutfitUpdateRow:SetHeight(26)

    local createCharOutfitUpdateLabel = createCharOutfitUpdateRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    createCharOutfitUpdateLabel:SetPoint("LEFT", createCharOutfitUpdateRow, "LEFT", 0, 0)
    createCharOutfitUpdateLabel:SetText(L["Create Character Outfit Update Macro"])

    local createCharOutfitUpdateBtn = CreateFrame("Button", nil, createCharOutfitUpdateRow, "UIPanelButtonTemplate")
    createCharOutfitUpdateBtn:SetSize(110, 22)
    createCharOutfitUpdateBtn:SetPoint("RIGHT", createCharOutfitUpdateRow, "RIGHT", 0, 0)
    createCharOutfitUpdateBtn:SetText(L["Create Macro"])
    createCharOutfitUpdateBtn:SetScript("OnClick", function()
        if ns.Macro and ns.Macro.EnsureCharacterOutfitUpdateMacro then
            ns.Macro.EnsureCharacterOutfitUpdateMacro()
        end
    end)

    local function ShowCharMacroTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Create Character Outfit Update Macro"], 1, 1, 1)
        GameTooltip:AddLine(
            "Creates a character-specific version of the outfit update macro in your"
            .. " character macro list, allowing it to be used alongside an ability on"
            .. " your action bar.",
            1, 0.82, 0, true)
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine(
            "It is suggested to disable |cffffd100Remove Macro Changes On Update|r before"
            .. " adding abilities to this macro, to prevent them from being removed on updates.",
            1, 0.82, 0, true)
        GameTooltip:Show()
    end
    createCharOutfitUpdateRow:SetScript("OnEnter", ShowCharMacroTip)
    createCharOutfitUpdateRow:SetScript("OnLeave", function() GameTooltip:Hide() end)
    createCharOutfitUpdateBtn:HookScript("OnEnter", ShowCharMacroTip)
    createCharOutfitUpdateBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- ===== Mount Features =====

    MakeSectionHeader(content, "Mounts", HEADER_X, -150)
    local cbTooltipMount = MakeCheckbox(content, "ShowTooltipMount",
        "Show Tooltip in Mount Macro",
        "Include #showtooltip in the mount macro. Disabling this frees up space"
        .. " for custom macro text and/or toys in the mount macro.",
        OPTION_X, -180, OnGroundMountModifierChanged)
    local cbDruidMacro = MakeCheckbox(content, "UseDruidMacro",
        "Use Druid Macro",
        "Replace the standard FitterMount on druid characters that intelligently"
        .. " transforms into flight form, cat form, aquatic form, or summons a mount"
        .. " while not moving.",
        OPTION_X, -210, OnDruidMacroChanged)
    local cbShamanMacro = MakeCheckbox(content, "UseShamanMacro",
        "Use Shaman Macro",
        "Replace the standard FitterMount on shaman characters that casts Ghost Wolf"
        .. " when not already in Ghost Wolf form, or summons a mount otherwise.",
        OPTION_X, -240, OnDruidMacroChanged)
    local cbZoneSpecificMounts = MakeCheckbox(content, "UseZoneSpecificMounts",
        "Use Zone Specific Mounts",
        "Summon a special mount intended for the current zone when it is available"
        .. " to this character. Currently uses the G-99 Breakneck in Undermine.",
        OPTION_X, -270, OnGroundMountModifierChanged)

    local function GetCollectedMountNames()
        local collected = {}
        for _, mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
            local name, _, _, _, _, _, _, _, _, _, isCollected =
                C_MountJournal.GetMountInfoByID(mountID)
            if name and isCollected then collected[name] = true end
        end
        return collected
    end

    local conditionDropdowns = {}
    local function MakeConditionDropdown(modifier, y)
        local key = modifier .. "MountCondition"
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", OPTION_X, y)
        row:SetPoint("RIGHT", content, "RIGHT", -10, 0)
        row:SetHeight(26)
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetText(string.format(L["%s Condition:"], modifier))
        local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        dropdown:SetSize(260, 26)
        dropdown.Text:SetJustifyH("LEFT")
        dropdown:SetupMenu(function(_, rootDescription)
            local collectedMountNames = GetCollectedMountNames()
            for _, optionData in ipairs(ns.Constants.MOUNT_CONDITIONS) do
                local option = optionData.label
                if optionData.alwaysAvailable or collectedMountNames[option] then
                    rootDescription:CreateRadio(option,
                        function(value)
                            return FitterSaved and FitterSaved[key] == value
                        end,
                        function(value)
                            FitterSaved[key] = value
                            dropdown:OverrideText(value)
                            OnGroundMountModifierChanged()
                        end,
                        option)
                end
            end
        end)
        local function ShowConditionTooltip(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format(L["%s Condition"], modifier), 1, 1, 1)
            GameTooltip:AddLine(
                "Choose the mount Fitter summons when you hold " .. modifier
                .. " while using the mount macro or key binding.",
                1, 0.82, 0, true)
            GameTooltip:AddLine(
                "Ground Mount summons the ground mount selected for your current outfit.",
                1, 0.82, 0, true)
            GameTooltip:Show()
        end
        local function HideConditionTooltip()
            GameTooltip:Hide()
        end
        row:SetScript("OnEnter", ShowConditionTooltip)
        row:SetScript("OnLeave", HideConditionTooltip)
        dropdown:HookScript("OnEnter", ShowConditionTooltip)
        dropdown:HookScript("OnLeave", HideConditionTooltip)
        dropdown:OverrideText(FitterSaved[key] or "None")
        conditionDropdowns[key] = dropdown
    end
    MakeConditionDropdown("Shift", -306)
    MakeConditionDropdown("Ctrl", -336)
    MakeConditionDropdown("Alt", -366)

    local function UpdateModDisplay()
        for key, dropdown in pairs(conditionDropdowns) do
            dropdown:OverrideText(FitterSaved[key] or "None")
        end
    end

    -- ===== Hearthstone Features =====

    MakeSectionHeader(content, "Hearthstones", HEADER_X, -412)
    local cbTooltipHS = MakeCheckbox(content, "ShowTooltipHearthstone",
        "Show Tooltip in Hearthstone Macro",
        "Include #showtooltip in the hearthstone macro. Disabling this frees up"
        .. " additional space for custom macro text.",
        OPTION_X, -442, OnHearthstoneSettingChanged)
    local cbAstralRecallFallback = MakeCheckbox(content, "AstralRecallFallback",
        "Astral Recall Fallback",
        "On Shaman characters, use Astral Recall when the selected Hearthstone"
        .. " cannot be used because it is on cooldown.",
        OPTION_X, -472, OnHearthstoneSettingChanged)

    local hearthstoneConditionDropdowns = {}
    local function GetHearthstoneConditionLabel(value)
        for _, option in ipairs(ns.Constants.HEARTHSTONE_CONDITIONS) do
            if value == (option.id or "None") then return option.label end
        end
        return "None"
    end
    local function MakeHearthstoneConditionDropdown(modifier, y)
        local key = modifier .. "HearthstoneCondition"
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", OPTION_X, y)
        row:SetPoint("RIGHT", content, "RIGHT", -10, 0)
        row:SetHeight(26)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetText(string.format(L["%s Condition:"], modifier))

        local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        dropdown:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        dropdown:SetSize(260, 26)
        dropdown.Text:SetJustifyH("LEFT")
        dropdown:SetupMenu(function(_, rootDescription)
            for _, option in ipairs(ns.Constants.HEARTHSTONE_CONDITIONS) do
                if option.alwaysAvailable or PlayerHasToy(option.id) then
                    rootDescription:CreateRadio(option.label,
                        function(value)
                            return FitterSaved and FitterSaved[key] == value
                        end,
                        function(value)
                            FitterSaved[key] = value
                            dropdown:OverrideText(GetHearthstoneConditionLabel(value))
                            OnHearthstoneSettingChanged()
                        end,
                        option.id or "None")
                end
            end
        end)

        local function ShowConditionTooltip(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetText(string.format(L["%s Condition"], modifier), 1, 1, 1)
            GameTooltip:AddLine(
                "Choose the teleport toy Fitter uses when you hold " .. modifier
                .. " while using the hearthstone macro or key binding.",
                1, 0.82, 0, true)
            GameTooltip:Show()
        end
        row:SetScript("OnEnter", ShowConditionTooltip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        dropdown:HookScript("OnEnter", ShowConditionTooltip)
        dropdown:HookScript("OnLeave", function() GameTooltip:Hide() end)

        dropdown:OverrideText(GetHearthstoneConditionLabel(FitterSaved[key]))
        hearthstoneConditionDropdowns[key] = dropdown
    end
    MakeHearthstoneConditionDropdown("Shift", -502)
    MakeHearthstoneConditionDropdown("Ctrl", -532)
    MakeHearthstoneConditionDropdown("Alt", -562)

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

    local resetDefaultHearthstonesRow = CreateFrame("Frame", nil, content)
    resetDefaultHearthstonesRow:SetPoint(
        "TOPLEFT", content, "TOPLEFT", OPTION_X, -592)
    resetDefaultHearthstonesRow:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    resetDefaultHearthstonesRow:SetHeight(26)

    local resetDefaultHearthstonesLabel =
        resetDefaultHearthstonesRow:CreateFontString(
            nil, "OVERLAY", "GameFontNormal")
    resetDefaultHearthstonesLabel:SetPoint(
        "LEFT", resetDefaultHearthstonesRow, "LEFT", 0, 0)
    resetDefaultHearthstonesLabel:SetText(L["Reset Default Hearthstones"])

    local resetDefaultHearthstonesButton = CreateFrame(
        "Button", nil, resetDefaultHearthstonesRow, "UIPanelButtonTemplate")
    resetDefaultHearthstonesButton:SetSize(110, 22)
    resetDefaultHearthstonesButton:SetPoint(
        "RIGHT", resetDefaultHearthstonesRow, "RIGHT", 0, 0)
    resetDefaultHearthstonesButton:SetText(L["Reset"])
    resetDefaultHearthstonesButton:SetScript("OnClick", function()
        StaticPopup_Show("FITTER_RESET_DEFAULT_HEARTHSTONES")
    end)

    -- ===== Pet Features =====

    MakeSectionHeader(content, "Pets", HEADER_X, -642)
    local cbDismissPetOnStealth = MakeCheckbox(content, "DismissPetOnStealth",
        "Dismiss Pet On Stealth",
        "When enabled, dismiss the currently summoned battle pet when your character"
        .. " becomes stealthed.",
        OPTION_X, -672)
    local cbDismissPetInInstancesWhileGrouped = MakeCheckbox(content, "DismissPetInInstancesWhileGrouped",
        "Dismiss Pet In Instances While Grouped",
        "When enabled, dismiss the currently summoned battle pet in any instance while"
        .. " you are in a party or raid, and prevent Fitter from summoning one there.",
        OPTION_X, -702, OnPetSettingChanged)

    -- ===== Hunter Pet Features =====

    MakeSectionHeader(content, "Hunter Pets", HEADER_X, -752)
    local cbReviveHunterPet = MakeCheckbox(content, "ReviveHunterPet",
        "Revive Pet",
        "When enabled, Fitter attempts to revive a dead hunter pet before continuing."
        .. " When disabled, Fitter only attempts to summon the selected hunter pet."
        .. " If the pet's corpse has despawned, it must be resurrected manually"
        .. " regardless of whether this setting is enabled.",
        OPTION_X, -782, OnHunterPetSettingChanged)

    -- ===== Emote Features =====

    MakeSectionHeader(content, "Emotes", HEADER_X, -832)
    local emoteCooldownRow = CreateFrame("Frame", nil, content)
    emoteCooldownRow:SetPoint("TOPLEFT", content, "TOPLEFT", OPTION_X, -862)
    emoteCooldownRow:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    emoteCooldownRow:SetHeight(36)

    local emoteCooldownLabel =
        emoteCooldownRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emoteCooldownLabel:SetPoint("LEFT", emoteCooldownRow, "LEFT", 0, 0)
    emoteCooldownLabel:SetText(L["Global Cooldown"])

    local emoteCooldownSlider = CreateFrame(
        "Slider", nil, emoteCooldownRow, "MinimalSliderWithSteppersTemplate")
    emoteCooldownSlider:SetPoint("RIGHT", emoteCooldownRow, "RIGHT", 0, 0)
    emoteCooldownSlider:SetSize(260, 20)
    emoteCooldownSlider:Init(
        FitterSaved.EmoteGlobalCooldown, 5, 60, 55, {
            [MinimalSliderWithSteppersMixin.Label.Right] =
                CreateMinimalSliderFormatter(
                    MinimalSliderWithSteppersMixin.Label.Right,
                    function(value)
                        return math.floor(value + 0.5) .. "s"
                    end),
        })
    emoteCooldownSlider.Slider:SetValueStep(1)
    emoteCooldownSlider.Slider:SetObeyStepOnDrag(true)

    local function SetEmoteCooldown(value, save)
        value = math.floor((tonumber(value) or 25) + 0.5)
        value = math.max(5, math.min(60, value))
        if save and FitterSaved then
            FitterSaved.EmoteGlobalCooldown = value
        end
    end
    emoteCooldownSlider:RegisterCallback(
        MinimalSliderWithSteppersMixin.Event.OnValueChanged,
        function(_, value)
            SetEmoteCooldown(value, true)
        end)

    -- ===== Toy Features =====

    MakeSectionHeader(content, "Cosmetic Toys", HEADER_X, -922)
    local cbCancelToys = MakeCheckbox(content, "CancelNonOutfitToys",
        "Cancel Non-Outfit Cosmetic Toys",
        "When switching outfits, automatically cancel any active toys from the"
        .. " previous outfit that are not also selected by the new outfit.",
        OPTION_X, -952)
    local cbApplyToy = MakeCheckbox(content, "ApplyToyOnSelect",
        "Apply Toy On Select",
        "When selecting or deselecting a toy while the outfit is currently active,"
        .. " immediately activate or cancel the toy.",
        OPTION_X, -982)

    -- ===== Zone Features =====

    MakeSectionHeader(content, "Zones", HEADER_X, -1032)
    local cbAutoEnable = MakeCheckbox(content, "AutoEnableZoneSituations",
        "Auto Enable Zone Situations",
        "When enabled, associating zones with an outfit will automatically enable their"
        .. " respective Location situations: Rest for cities and World for others.",
        OPTION_X, -1062)
    local cbAutoDisable = MakeCheckbox(content, "AutoDisableZoneSituations",
        "Auto Disable Zone Situations",
        {
            {"Requires Auto Enable Zone Situations enabled.", 0.4, 0.8, 1, true},
            {"When enabled, unselecting the last city or other zone associated with an outfit"
            .. " will disable the respective Location situation: Rest for cities and World for"
            .. " others. Only situations that were enabled by Fitter are disabled, determined"
            .. " by the situation state captured before auto-enabling.", 1, 0.82, 0, true},
        },
        OPTION_X, -1092)

    cbAutoEnable:HookScript("OnClick", function(self)
        if not self:GetChecked() and FitterSaved then
            FitterSaved.AutoDisableZoneSituations = false
            cbAutoDisable:SetChecked(false)
            cbAutoDisable:Disable()
            -- Clear all per-outfit situation baselines; they're only relevant when Auto Enable is on
            if FitterCharacterSaved then
                for key, outfitData in pairs(FitterCharacterSaved) do
                    if type(key) == "string" and key:match("^Outfit") and type(outfitData) == "table" then
                        outfitData.SituationBaseline = nil
                    end
                end
            end
        else
            cbAutoDisable:Enable()
        end
    end)

    -- ===== Account Wide (below Zone Features) =====

    local AW_Y_START = 1150

    local function UpdateContentHeight(awHeight)
        local h = AW_Y_START + awHeight
        content:SetHeight(h)
        scrollChild:SetSize(580, h)
        scrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately)
    end

    local awRefreshFn
    pcall(function()
        awRefreshFn = UI_Options:InitializeAccountWide(content, HEADER_X, AW_Y_START, UpdateContentHeight)
    end)

    UpdateContentHeight(142)  -- initial: header + three checkboxes, no scrollboxes open

    -- ===== SYNC =====

    local function SyncAll()
        if not FitterSaved then return end
        UpdateModDisplay()
        cbRemoveMacro:SetChecked(FitterSaved.RemoveMacroChangesOnUpdate)
        cbTooltipMount:SetChecked(FitterSaved.ShowTooltipMount)
        cbDruidMacro:SetChecked(FitterSaved.UseDruidMacro)
        cbShamanMacro:SetChecked(FitterSaved.UseShamanMacro)
        cbZoneSpecificMounts:SetChecked(FitterSaved.UseZoneSpecificMounts)
        cbTooltipHS:SetChecked(FitterSaved.ShowTooltipHearthstone)
        cbAstralRecallFallback:SetChecked(FitterSaved.AstralRecallFallback)
        for key, dropdown in pairs(hearthstoneConditionDropdowns) do
            dropdown:OverrideText(GetHearthstoneConditionLabel(FitterSaved[key]))
        end
        cbDismissPetOnStealth:SetChecked(FitterSaved.DismissPetOnStealth)
        cbDismissPetInInstancesWhileGrouped:SetChecked(FitterSaved.DismissPetInInstancesWhileGrouped)
        cbReviveHunterPet:SetChecked(FitterSaved.ReviveHunterPet)
        emoteCooldownSlider:SetValue(FitterSaved.EmoteGlobalCooldown)
        SetEmoteCooldown(FitterSaved.EmoteGlobalCooldown, false)
        cbCancelToys:SetChecked(FitterSaved.CancelNonOutfitToys)
        cbApplyToy:SetChecked(FitterSaved.ApplyToyOnSelect)
        cbAutoEnable:SetChecked(FitterSaved.AutoEnableZoneSituations)
        cbAutoDisable:SetChecked(FitterSaved.AutoDisableZoneSituations)
        if FitterSaved.AutoEnableZoneSituations then
            cbAutoDisable:Enable()
        else
            cbAutoDisable:Disable()
        end
        if awRefreshFn then awRefreshFn() end
    end

    optionsFrame.OnRefresh = SyncAll
    optionsFrame:SetScript("OnShow", SyncAll)

    if not alreadyRegistered then
        local category = Settings.RegisterCanvasLayoutCategory(
            optionsFrame, "Fitter")
        Settings.RegisterAddOnCategory(category)
    else
        SyncAll()
    end
end

function UI_Options:Register()
    EnsureDefaults()
    local optionsFrame = CreateFrame("Frame")
    optionsFrame:Hide()
    optionsFrame.OnCommit = function() end
    optionsFrame.OnDefault = function() end

    local initialized = false
    local function InitializeOnDemand()
        if initialized then return end
        initialized = true
        UI_Options:Initialize(optionsFrame, true)
    end
    optionsFrame.OnRefresh = InitializeOnDemand
    optionsFrame:SetScript("OnShow", InitializeOnDemand)

    local category = Settings.RegisterCanvasLayoutCategory(
        optionsFrame, "Fitter")
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
