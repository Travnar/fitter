local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s

local ICONS_PER_PAGE = 24
local DEFAULT_MACRO_ICON = 134400

local function GetAvailableIcons(searchText)
    local icons, seen = {}, {}
    local search = (searchText or ""):lower()

    local function AddIcon(icon)
        local searchableIcon = tostring(icon):lower()
        if icon and not seen[icon]
            and (search == ""
                or searchableIcon:find(search, 1, true)) then
            seen[icon] = true
            icons[#icons + 1] = icon
        end
    end

    -- Match the game's default macro icon and keep it first in the picker.
    AddIcon(DEFAULT_MACRO_ICON)

    local function AddIcons(api)
        if type(api) ~= "function" then return end
        local results = {}
        local ok, returned = pcall(api, results)
        if not ok then return end
        if type(returned) == "table" then results = returned end
        for _, icon in ipairs(results) do
            AddIcon(icon)
        end
    end

    -- These are the same two catalogs used by the game's macro icon picker.
    -- Together they contain the standard spell/item icons and loose UI icons.
    AddIcons(GetMacroIcons)
    AddIcons(GetLooseMacroIcons)

    return icons
end

local function CreatePopup()
    if s.emoteCreatePopup then return s.emoteCreatePopup end
    local popup = CreateFrame("Frame", "FitterNewEmotePopup", UIParent,
        "PortraitFrameTemplate")
    popup:SetSize(430, 495)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:Hide()
    popup:SetScript("OnHide", function(self)
        self.filteredIcons = nil
    end)
    popup:SetTitle(L["Add New Emote"])
    local portrait = popup.Portrait
        or (popup.PortraitContainer and popup.PortraitContainer.portrait)
    if portrait then
        portrait:SetTexture(ns.Constants.EMOTE_CATEGORY_ICON)
    end

    local titleLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleLabel:SetPoint("TOPLEFT", 28, -55)
    titleLabel:SetText(L["Title (optional)"])

    local titleEdit = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    titleEdit:SetSize(365, 30)
    titleEdit:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 4, -7)
    titleEdit:SetAutoFocus(false)
    titleEdit:SetMaxLetters(80)
    popup.titleEdit = titleEdit

    local textLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    textLabel:SetPoint("TOPLEFT", titleEdit, "BOTTOMLEFT", -4, -14)
    textLabel:SetText(L["Emote text"])

    local edit = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    edit:SetSize(365, 30)
    edit:SetPoint("TOPLEFT", textLabel, "BOTTOMLEFT", 4, -7)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(255)
    popup.edit = edit

    local scopeLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scopeLabel:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", -4, -18)
    scopeLabel:SetText(L["Available to"])

    local scope = CreateFrame("DropdownButton", nil, popup, "WowStyle1DropdownTemplate")
    scope:SetSize(180, 30)
    scope:SetPoint("LEFT", scopeLabel, "RIGHT", 12, 0)
    scope.value = "character"
    scope:SetDefaultText(L["This Character"])
    scope:SetupMenu(function(_, root)
        root:CreateRadio(L["This Character"], function()
            return scope.value == "character"
        end, function()
            scope.value = "character"
            scope:SetDefaultText(L["This Character"])
        end)
        root:CreateRadio(L["Account"], function()
            return scope.value == "account"
        end, function()
            scope.value = "account"
            scope:SetDefaultText(L["Account"])
        end)
    end)
    popup.scope = scope

    local iconLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    iconLabel:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", 0, -25)
    iconLabel:SetText(L["Icon"])

    popup.iconButtons = {}
    for index = 1, ICONS_PER_PAGE do
        local button = CreateFrame("Button", nil, popup)
        button:SetSize(34, 34)
        local col, row = (index - 1) % 8, math.floor((index - 1) / 8)
        button:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT",
            col * 45, -8 - row * 43)
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints()
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        local selected = CreateFrame("Frame", nil, button)
        selected:SetPoint("CENTER")
        selected:SetSize(62, 62)
        local selectedBorder = selected:CreateTexture(nil, "OVERLAY")
        selectedBorder:SetAllPoints()
        selectedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        selectedBorder:SetBlendMode("ADD")
        selectedBorder:SetVertexColor(1, 0.72, 0, 1)
        local selectedGlow = selected:CreateTexture(nil, "OVERLAY")
        selectedGlow:SetAllPoints()
        selectedGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        selectedGlow:SetBlendMode("ADD")
        selectedGlow:SetVertexColor(1, 0.62, 0, 0.55)
        selected:Hide()
        button.selected, button.texture = selected, texture
        button:SetScript("OnClick", function()
            popup.selectedIcon = button.icon
            for _, other in ipairs(popup.iconButtons) do
                other.selected:SetShown(other.icon == popup.selectedIcon)
            end
        end)
        popup.iconButtons[index] = button
    end

    local function UpdateIconPage(refreshIcons)
        if refreshIcons or not popup.filteredIcons then
            popup.filteredIcons = GetAvailableIcons(popup.iconSearchText)
        end
        local icons = popup.filteredIcons
        local pageCount = math.max(1, math.ceil(#icons / ICONS_PER_PAGE))
        popup.iconPage = math.max(1, math.min(popup.iconPage or 1, pageCount))
        local offset = (popup.iconPage - 1) * ICONS_PER_PAGE
        for index, button in ipairs(popup.iconButtons) do
            local icon = icons[offset + index]
            button.icon = icon
            button.texture:SetTexture(icon)
            button:SetShown(icon ~= nil)
            button.selected:SetShown(icon == popup.selectedIcon)
        end
        popup.iconPageText:SetText(string.format(L["Page %d/%d"],
            popup.iconPage, pageCount))
        popup.iconPrev:SetEnabled(popup.iconPage > 1)
        popup.iconNext:SetEnabled(popup.iconPage < pageCount)
    end

    function popup:ChangeIconPage(delta)
        local oldPage = self.iconPage or 1
        self.iconPage = oldPage + (delta > 0 and -1 or 1)
        UpdateIconPage()
    end
    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel", function(self, delta)
        self:ChangeIconPage(delta)
    end)

    local iconSearch = CreateFrame("EditBox", nil, popup, "SearchBoxTemplate")
    iconSearch:SetSize(340, 28)
    iconSearch:SetPoint("TOPLEFT", iconLabel, "BOTTOMLEFT", 4, -140)
    iconSearch:SetAutoFocus(false)
    if iconSearch.Instructions then
        iconSearch.Instructions:SetText(L["Search by ID"])
    end
    iconSearch:HookScript("OnTextChanged", function(self)
        popup.iconSearchText = self:GetText():match("^%s*(.-)%s*$"):lower()
        popup.iconPage = 1
        UpdateIconPage(true)
    end)
    popup.iconSearch = iconSearch

    popup.iconPageText, popup.iconPrev, popup.iconNext =
        UI_Transmog._PagedShared.CreateNavButtons(popup, function()
            popup.iconPage = popup.iconPage - 1
            UpdateIconPage()
        end, function()
            popup.iconPage = popup.iconPage + 1
            UpdateIconPage()
        end)
    local iconNav = popup.iconPageText:GetParent()
    iconNav:ClearAllPoints()
    iconNav:SetPoint("BOTTOM", popup, "BOTTOM", 0, 62)
    popup.UpdateIconPage = UpdateIconPage

    local cancel = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    cancel:SetSize(90, 24)
    cancel:SetPoint("BOTTOMRIGHT", -24, 22)
    cancel:SetText(L["Cancel"])
    cancel:SetScript("OnClick", function() popup:Hide() end)

    local save = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    save:SetSize(90, 24)
    save:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
    save:SetText(L["Save"])
    save:SetScript("OnClick", function()
        local title = titleEdit:GetText():match("^%s*(.-)%s*$")
        local text = edit:GetText():match("^%s*(.-)%s*$")
        if text == "" then
            UIErrorsFrame:AddMessage(L["Enter emote text."], 1, 0.2, 0.2)
            return
        end
        FitterSaved.CustomEmotes = FitterSaved.CustomEmotes or {}
        FitterCharacterSaved.CustomEmotes = FitterCharacterSaved.CustomEmotes or {}
        local store = scope.value == "account"
            and FitterSaved.CustomEmotes or FitterCharacterSaved.CustomEmotes
        local id = string.format("custom:%s:%d:%d", scope.value,
            GetServerTime(), math.random(1000000))
        store[#store + 1] = {
            id = id,
            name = title ~= "" and title or text,
            text = text,
            example = "{name} " .. text,
            icon = popup.selectedIcon,
            scope = scope.value,
            custom = true,
        }
        popup:Hide()
        UI_Transmog:RefreshEmoteList()
    end)
    s.emoteCreatePopup = popup
    return popup
end

function UI_Transmog:ShowEmoteCreatePopup()
    local popup = CreatePopup()
    popup.titleEdit:SetText("")
    popup.edit:SetText("")
    popup.scope.value = "character"
    popup.scope:SetDefaultText(L["This Character"])
    popup.iconSearch:SetText("")
    popup.iconSearchText = ""
    popup.filteredIcons = GetAvailableIcons()
    popup.selectedIcon = popup.filteredIcons[1]
        or ns.Constants.EMOTE_CATEGORY_ICON
    popup.iconPage = 1
    popup:UpdateIconPage()
    popup:Show()
    popup:Raise()
    popup.titleEdit:SetFocus()
end
