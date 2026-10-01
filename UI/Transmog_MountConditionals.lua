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

local TYPE_BY_KEY = {}
for _, data in ipairs(TYPES) do TYPE_BY_KEY[data.key] = data end

local MAX_SUGGESTIONS = 8
local SUGGESTION_HEIGHT = 20

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
    popup.suggestions:Hide()
end

-- A list under the Name / ID field that filters the suggestion pool as
-- the player types. Up/Down move the highlight; Enter or Tab picks it.
local function CreateSuggestionList(popup, editBox)
    local list = CreateFrame("Frame", nil, popup, "TooltipBackdropTemplate")
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 4, 2)
    list:SetWidth(280)
    list:Hide()
    list.buttons = {}

    for index = 1, MAX_SUGGESTIONS do
        local button = CreateFrame("Button", nil, list)
        button:SetHeight(SUGGESTION_HEIGHT)
        button:SetPoint("TOPLEFT", 6, -6 - (index - 1) * SUGGESTION_HEIGHT)
        button:SetPoint("RIGHT", -6, 0)

        button.selected = button:CreateTexture(nil, "BACKGROUND")
        button.selected:SetAllPoints()
        button.selected:SetColorTexture(1, 0.82, 0, 0.2)
        button.selected:Hide()
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.12)

        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(16, 16)
        button.icon:SetPoint("LEFT", 2, 0)
        button.kind = button:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        button.kind:SetPoint("RIGHT", -2, 0)
        button.text = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        button.text:SetPoint("LEFT", button.icon, "RIGHT", 5, 0)
        button.text:SetPoint("RIGHT", button.kind, "LEFT", -5, 0)
        button.text:SetJustifyH("LEFT")
        button.text:SetWordWrap(false)

        button:SetScript("OnClick", function(self) list:Pick(self.entry) end)
        list.buttons[index] = button
    end

    function list:SetSelection(index)
        self.selection = index
        for buttonIndex, button in ipairs(self.buttons) do
            button.selected:SetShown(buttonIndex == index)
        end
    end

    function list:Update()
        local results = popup.pool and Conditionals.GetSuggestions(
            popup.pool, editBox:GetText(), popup.typeDropdown.value, MAX_SUGGESTIONS) or {}
        if #results == 0 then
            self:Hide()
            return
        end
        for index, button in ipairs(self.buttons) do
            local entry = results[index]
            button.entry = entry
            button:SetShown(entry ~= nil)
            if entry then
                button.icon:SetTexture(entry.icon or 134400)
                button.text:SetText(L[entry.name])
                local typeData = TYPE_BY_KEY[entry.kind]
                button.kind:SetText(entry.kind ~= "ground" and typeData and typeData.label or "")
            end
        end
        self:SetHeight(#results * SUGGESTION_HEIGHT + 12)
        self.count = #results
        self:SetSelection(nil)
        self:Show()
    end

    function list:MoveSelection(step)
        local index = (self.selection or (step > 0 and 0 or self.count + 1)) + step
        if index < 1 then index = self.count elseif index > self.count then index = 1 end
        self:SetSelection(index)
    end

    -- Fills in the field and the type, and remembers the entry so Add uses it
    -- directly instead of resolving the name again.
    function list:Pick(entry)
        if not entry then return end
        self:Hide()
        SetPopupType(popup, TYPE_BY_KEY[entry.kind])
        if entry.kind ~= "ground" then
            editBox:SetText(L[entry.name])
            editBox:SetCursorPosition(#editBox:GetText())
        end
        popup.pickedEntry = entry
    end

    function list:PickSelection()
        local button = self.buttons[self.selection or 1]
        if not self:IsShown() or not button or not button.entry then return false end
        self:Pick(button.entry)
        return true
    end

    return list
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
    abilityLabel:SetText(L["Name / ID"])
    popup.abilityLabel = abilityLabel

    local abilityEdit = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    abilityEdit:SetSize(195, 30)
    abilityEdit:SetPoint("TOPRIGHT", typeDropdown, "BOTTOMRIGHT", 0, -8)
    abilityEdit:SetAutoFocus(false)
    abilityEdit:SetMaxLetters(80)
    abilityEdit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Name / ID"])
        GameTooltip:AddLine(L["Enter the name or ID of an ability, toy or mount known by this character."],
            1, 1, 1, true)
        GameTooltip:AddLine(L["Start typing to see suggestions. Anything not listed can still be entered by its full name or ID."], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    abilityEdit:SetScript("OnLeave", GameTooltip_Hide)
    popup.abilityEdit = abilityEdit

    local suggestions = CreateSuggestionList(popup, abilityEdit)
    popup.suggestions = suggestions
    abilityEdit:SetScript("OnTextChanged", function(_, userInput)
        if not userInput then return end
        popup.pickedEntry = nil
        suggestions:Update()
    end)
    abilityEdit:SetScript("OnArrowPressed", function(_, key)
        if not suggestions:IsShown() then return end
        if key == "UP" then suggestions:MoveSelection(-1)
        elseif key == "DOWN" then suggestions:MoveSelection(1) end
    end)
    abilityEdit:SetScript("OnTabPressed", function() suggestions:PickSelection() end)
    abilityEdit:SetScript("OnEditFocusLost", function()
        -- Delayed so a click on a suggestion lands before the list hides.
        C_Timer.After(0.2, function()
            if not abilityEdit:HasFocus() then suggestions:Hide() end
        end)
    end)

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
        local picked = popup.pickedEntry
        local entry
        if picked and picked.kind == typeDropdown.value
            and (picked.kind == "ground" or abilityEdit:GetText() == L[picked.name]) then
            entry = picked
        else
            entry = Conditionals.Resolve(abilityEdit:GetText(), typeDropdown.value)
        end
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
    abilityEdit:SetScript("OnEnterPressed", function()
        if suggestions.selection and suggestions:PickSelection() then return end
        add:Click()
    end)
    abilityEdit:SetScript("OnEscapePressed", function()
        if suggestions:IsShown() then suggestions:Hide() else popup:Hide() end
    end)

    s.conditionalPopup = popup
    return popup
end

-- scope is "character" or "account"; onChanged runs after an entry is added.
function ConditionalsUI.ShowAddPopup(scope, onChanged)
    local popup = CreateConditionalPopup()
    popup.scope = scope
    popup.onChanged = onChanged
    popup:SetTitle(scope == "account" and L["Add an Account Wide Condition"]
        or L["Add a Character Condition"])
    popup.condition.value = nil
    popup.condition:OverrideText(L["Select a condition"])
    SetPopupType(popup, TYPES[1])
    popup.abilityEdit:SetText("")
    popup.pickedEntry = nil
    popup.pool = Conditionals.BuildSuggestionPool()
    popup:Show()
end

-- Hides the add popup if it is open for scope (any scope when nil), so closing
-- one panel does not close a popup opened from the other.
function ConditionalsUI.HidePopup(scope)
    local popup = s.conditionalPopup
    if popup and (not scope or popup.scope == scope) then popup:Hide() end
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
        GameTooltip:SetText(scope == "account" and L["Add an Account Wide Condition"]
            or L["Add a Character Condition"])
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

    local addLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, -200)
    addLabel:SetText(L["Add a Character Condition"])

    local add = ConditionalsUI.CreateAddButton(parent, "character", OnChanged)
    add:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -70, -191)

    local currentLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, -237)
    currentLabel:SetText(L["Current Character Conditionals"])

    local dropdown = ConditionalsUI.CreateListDropdown(parent, "character", 220, OnChanged)
    dropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -70, -228)
    s.mountConditionalsDropdown = dropdown
end
