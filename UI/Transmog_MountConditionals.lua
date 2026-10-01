-- Mount bind conditional widgets, shared by the Fitter tab (character) and the
-- options panel's Account Wide section (account), plus the Fitter tab section.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Conditionals = ns.MountConditionals

local ConditionalsUI = {}
ns.MountConditionalsUI = ConditionalsUI

local REMOVE_ICON = "Interface\\RaidFrame\\ReadyCheck-NotReady"

-- MOUNT and TOY are Blizzard's localized nouns; L["Mount"] is the emote verb.
local TYPES = {
    {key = "auto", label = L["Auto Detect"]},
    {key = "spell", label = L["Ability"]},
    {key = "toy", label = TOY or "Toy"},
    {key = "mount", label = MOUNT or "Mount"},
    {key = "ground", label = L["Ground Mount"]},
}

local function EntryLabel(entry)
    local icon = entry.icon and ("|T" .. entry.icon .. ":16:16|t ") or ""
    return icon .. L[entry.name or "?"] .. " |cff999999("
        .. L[Conditionals.GetConditionLabel(entry.condition)] .. ")|r"
end

local function SetPopupType(popup, data)
    popup.typeDropdown.value = data.key
    popup.typeDropdown:OverrideText(data.label)
    -- Ground Mount uses the outfit's ground mount, so there is nothing to enter.
    local needsInput = data.key ~= "ground"
    popup.abilityLabel:SetShown(needsInput)
    popup.abilityEdit:SetShown(needsInput)
end

local function CreateConditionalPopup()
    if s.conditionalPopup then return s.conditionalPopup end
    local popup = CreateFrame("Frame", "FitterMountConditionalPopup", UIParent,
        "PortraitFrameTemplate")
    popup:SetSize(400, 258)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:Hide()

    local portrait = popup.Portrait
        or (popup.PortraitContainer and popup.PortraitContainer.portrait)
    if portrait then portrait:SetTexture("Interface\\Icons\\Ability_Mount_RidingHorse") end

    local conditionLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    conditionLabel:SetPoint("TOPLEFT", 30, -72)
    conditionLabel:SetText(L["Condition"])

    local condition = CreateFrame("DropdownButton", nil, popup,
        "WowStyle1DropdownTemplate")
    condition:SetSize(200, 30)
    condition:SetPoint("TOPRIGHT", -30, -63)
    condition:SetupMenu(function(_, root)
        for _, data in ipairs(Conditionals.CONDITIONS) do
            local key = data.key
            root:CreateRadio(L[data.label], function()
                return condition.value == key
            end, function()
                condition.value = key
                condition:OverrideText(L[data.label])
            end)
        end
    end)
    popup.condition = condition

    local typeLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", conditionLabel, "BOTTOMLEFT", 0, -26)
    typeLabel:SetText(L["Type"])

    local typeDropdown = CreateFrame("DropdownButton", nil, popup,
        "WowStyle1DropdownTemplate")
    typeDropdown:SetSize(200, 30)
    typeDropdown:SetPoint("TOPRIGHT", condition, "BOTTOMRIGHT", 0, -8)
    typeDropdown:SetupMenu(function(_, root)
        for _, data in ipairs(TYPES) do
            local choice = data
            root:CreateRadio(choice.label, function()
                return typeDropdown.value == choice.key
            end, function()
                SetPopupType(popup, choice)
            end)
        end
    end)
    typeDropdown:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Type"])
        GameTooltip:AddLine(L["Auto Detect tries each type in turn. Choose a type when an ID could match more than one."],
            1, 1, 1, true)
        GameTooltip:AddLine(L["Ground Mount summons the ground mount selected for your current outfit, and only works with Shift, Ctrl or Alt."],
            1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    typeDropdown:HookScript("OnLeave", GameTooltip_Hide)
    popup.typeDropdown = typeDropdown

    local abilityLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    abilityLabel:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -26)
    abilityLabel:SetText(L["Ability / Item"])
    popup.abilityLabel = abilityLabel

    local abilityEdit = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    abilityEdit:SetSize(195, 30)
    abilityEdit:SetPoint("TOPRIGHT", typeDropdown, "BOTTOMRIGHT", 0, -8)
    abilityEdit:SetAutoFocus(false)
    abilityEdit:SetMaxLetters(80)
    abilityEdit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Ability / Item"])
        GameTooltip:AddLine(L["Enter the name or ID of an ability, toy or mount known by this character."],
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    abilityEdit:SetScript("OnLeave", GameTooltip_Hide)
    popup.abilityEdit = abilityEdit

    local cancel = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    cancel:SetSize(90, 24)
    cancel:SetPoint("BOTTOMRIGHT", -24, 20)
    cancel:SetText(L["Cancel"])
    cancel:SetScript("OnClick", function() popup:Hide() end)

    local add = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    add:SetSize(90, 24)
    add:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
    add:SetText(L["Add"])
    add:SetScript("OnClick", function()
        if not condition.value then
            UIErrorsFrame:AddMessage(L["Choose a condition."], 1, 0.2, 0.2)
            return
        end
        local entry = Conditionals.Resolve(abilityEdit:GetText(), typeDropdown.value)
        if not entry then
            UIErrorsFrame:AddMessage(
                L["No ability, toy or mount with that name or ID is known by this character."],
                1, 0.2, 0.2)
            return
        end
        local ok, err = Conditionals.Add(popup.scope, condition.value, entry)
        if not ok then
            UIErrorsFrame:AddMessage(L[err], 1, 0.2, 0.2)
            return
        end
        popup:Hide()
        if popup.onChanged then popup.onChanged() end
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    end)
    abilityEdit:SetScript("OnEnterPressed", function() add:Click() end)
    abilityEdit:SetScript("OnEscapePressed", function() popup:Hide() end)

    s.conditionalPopup = popup
    return popup
end

-- scope is "character" or "account"; onChanged runs after an entry is added.
function ConditionalsUI.ShowAddPopup(scope, onChanged)
    local popup = CreateConditionalPopup()
    popup.scope = scope
    popup.onChanged = onChanged
    popup:SetTitle(scope == "account" and L["Add an Account Wide Condition"]
        or L["Add a Condition"])
    popup.condition.value = nil
    popup.condition:OverrideText(L["Select a condition"])
    SetPopupType(popup, TYPES[1])
    popup.abilityEdit:SetText("")
    popup:Show()
end

function ConditionalsUI.HidePopup()
    if s.conditionalPopup then s.conditionalPopup:Hide() end
end

StaticPopupDialogs["FITTER_REMOVE_MOUNT_CONDITIONAL"] = {
    text = L["Remove the conditional |cffffd200%s|r?"],
    button1 = L["Remove"],
    button2 = L["Cancel"],
    OnAccept = function(_, data)
        if not data then return end
        Conditionals.Remove(data.scope, data.entry)
        if data.onChanged then data.onChanged() end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- A red plus button that opens the add popup for scope.
function ConditionalsUI.CreateAddButton(parent, scope, onChanged)
    local add = CreateFrame("Button", nil, parent)
    add:SetSize(32, 32)
    local addIcon = add:CreateTexture(nil, "ARTWORK")
    addIcon:SetPoint("CENTER")
    addIcon:SetAtlas("128-redbutton-plus", true)
    addIcon:SetSize(32, 32)
    add.icon = addIcon
    local addHighlight = add:CreateTexture(nil, "HIGHLIGHT")
    addHighlight:SetAllPoints(addIcon)
    addHighlight:SetAtlas("128-redbutton-plus", true)
    addHighlight:SetBlendMode("ADD")
    addHighlight:SetAlpha(0.25)
    add:SetScript("OnMouseDown", function(self)
        self.icon:SetAtlas("128-redbutton-plus-pressed", true)
        self.icon:SetSize(32, 32)
    end)
    add:SetScript("OnMouseUp", function(self)
        self.icon:SetAtlas("128-redbutton-plus", true)
        self.icon:SetSize(32, 32)
    end)
    add:SetScript("OnClick", function()
        ConditionalsUI.ShowAddPopup(scope, onChanged)
    end)
    add:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Add a Condition"])
        GameTooltip:AddLine(L["Use an ability, toy or mount instead of the normal mount when the mount macro or key binding is used while a condition is met."],
            1, 1, 1, true)
        if scope == "account" then
            GameTooltip:AddLine(L["Applies to every character. A character's own conditional for the same condition takes priority, and abilities or toys a character does not have are skipped."],
                1, 0.82, 0, true)
        end
        GameTooltip:AddLine(L["Falling only applies to the key binding, and only out of combat."],
            1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    add:SetScript("OnLeave", GameTooltip_Hide)
    return add
end

-- A dropdown listing scope's conditionals; choosing one asks to remove it.
-- Call dropdown:RefreshText() after the list changes.
function ConditionalsUI.CreateListDropdown(parent, scope, width, onChanged)
    local dropdown = CreateFrame("DropdownButton", nil, parent,
        "WowStyle1DropdownTemplate")
    dropdown:SetSize(width, 30)
    function dropdown:RefreshText()
        local empty = #Conditionals.GetList(scope) == 0
        self:OverrideText(empty and L["None"] or L["Manage Conditionals"])
    end
    dropdown:SetupMenu(function(_, root)
        local list = Conditionals.GetList(scope)
        if #list == 0 then
            root:CreateTitle(L["No conditionals added"])
            return
        end
        for _, entry in ipairs(list) do
            local button = root:CreateButton(EntryLabel(entry), function()
                StaticPopup_Show("FITTER_REMOVE_MOUNT_CONDITIONAL", EntryLabel(entry), nil,
                    {scope = scope, entry = entry, onChanged = onChanged})
            end)
            button:AddInitializer(function(frame)
                local remove = frame:AttachTexture()
                remove:SetSize(14, 14)
                remove:SetPoint("RIGHT")
                remove:SetTexture(REMOVE_ICON)
            end)
        end
    end)
    dropdown:RefreshText()
    return dropdown
end

function UI_Transmog:RefreshMountConditionals()
    if s.mountConditionalsDropdown then s.mountConditionalsDropdown:RefreshText() end
end

function UI_Transmog:InitializeMountConditionals(parent)
    if s.mountConditionalsDropdown then
        self:RefreshMountConditionals()
        return
    end
    local function OnChanged() UI_Transmog:RefreshMountConditionals() end

    local section = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 66, -455)
    section:SetTextColor(1, 1, 1, 1)
    section:SetText(L["Mount Bind Conditionals"])

    local addLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, -493)
    addLabel:SetText(L["Add a Condition"])

    local add = ConditionalsUI.CreateAddButton(parent, "character", OnChanged)
    add:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -70, -484)

    local currentLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, -536)
    currentLabel:SetText(L["Current Conditionals"])

    local dropdown = ConditionalsUI.CreateListDropdown(parent, "character", 220, OnChanged)
    dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -70, -527)
    s.mountConditionalsDropdown = dropdown
end
