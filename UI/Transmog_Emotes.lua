local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter

local PAGE_SIZE = 30
local START_X, START_Y = 30, -120
local GAP_X = 14
local BOTTOM_PADDING = 65
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

local CONDITIONS = {
    { key = "MOUNTED", label = L["Mounting"] },
    { key = "DISMOUNTED", label = L["Dismounting"] },
    { key = "COMBAT_START", label = L["Entering Combat"] },
    { key = "COMBAT_END", label = L["Leaving Combat"] },
    { key = "EATING_START", label = L["Starting to Eat"] },
    { key = "EATING_END", label = L["Finishing Eating"] },
    { key = "DRINKING_START", label = L["Starting to Drink"] },
    { key = "DRINKING_END", label = L["Finishing Drinking"] },
    { key = "RESTING_START", label = L["Entering a Rest Area"] },
    { key = "RESTING_END", label = L["Leaving a Rest Area"] },
    { key = "AFK_START", label = L["AFK"] },
    { key = "HEARTHSTONE_USED", label = L["Using a Hearthstone"] },
    { key = "OUTFIT_EQUIPPED", label = L["Equipping This Outfit"] },
    {
        key = "SOCIAL",
        label = L["Social"],
        submenu = {
            { key = "TARGET_FRIENDLY_PLAYER", label = L["Target Friendly Player"] },
            { key = "TARGET_FRIENDLY_NPC", label = L["Target Friendly NPC"] },
            { key = "TARGET_HOSTILE_NPC", label = L["Target Hostile NPC"] },
        },
    },
    { key = "BIOMES", label = L["Biomes"], submenu = ns.Constants.BIOME_GROUPS },
}

local function CurrentData(create)
    local id = UI_Transmog:GetViewedOutfitID()
    if not id or id == 0 then return nil end
    if create then Fitter:CreateEmptyOutfit(id) end
    local data = FitterCharacterSaved and FitterCharacterSaved["Outfit" .. id]
    if data and type(data.Emotes) ~= "table" then data.Emotes = {} end
    return data
end

local function IsAssigned(assignment)
    for _, enabled in pairs(assignment and assignment.conditions or {}) do
        if enabled == true
            or (type(enabled) == "table" and next(enabled)) then
            return true
        end
    end
    return false
end

local function GetAssignmentLabels(assignment)
    local conditions = assignment and assignment.conditions
    local labels = {}
    for _, condition in ipairs(CONDITIONS) do
        local value = conditions and conditions[condition.key]
        if value == true then
            labels[#labels + 1] = condition.label
        elseif type(value) == "table" and type(condition.submenu) == "table" then
            for _, option in ipairs(condition.submenu) do
                if value[option.key] then
                    labels[#labels + 1] = option.label
                end
            end
        end
    end
    return labels
end

local function GetEmoteExample(item)
    if not item then return nil end
    local template = item.example
    if not template and item.custom and item.text then
        template = "{name} " .. item.text
    end
    if not template then return nil end
    return template:gsub("{name}", UnitName("player") or "Your character")
end

local function LayoutButtons()
    if not s.emoteButtons or not s.emoteButtons[1] then return end
    local first = s.emoteButtons[1]
    local availableWidth = s.emotesFrame:GetWidth() - START_X * 2
    local rowCount = math.ceil(#s.emoteButtons / 3)
    local availableHeight = math.max(first:GetHeight(),
        s.emotesFrame:GetHeight() + START_Y - BOTTOM_PADDING)
    local columnWidth = availableWidth / 3
    local width = math.max(100, columnWidth - GAP_X)
    local stepX = columnWidth
    local buttonInset = GAP_X / 2
    local stepY = rowCount > 1
        and (availableHeight - first:GetHeight()) / (rowCount - 1)
        or 0
    for i, button in ipairs(s.emoteButtons) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        button:SetWidth(width)
        local font = button:GetFontString()
        if font then font:SetWidth(math.max(width - 58, 20)) end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", s.emotesFrame, "TOPLEFT",
            START_X + buttonInset + col * stepX, START_Y - row * stepY)
    end
end

local function DeleteCustomEmote(item)
    local store = item.scope == "account"
        and FitterSaved.CustomEmotes or FitterCharacterSaved.CustomEmotes
    for index, entry in ipairs(store or {}) do
        if entry.id == item.id then
            table.remove(store, index)
            break
        end
    end
    -- Remove assignments from every outfit available on this character.
    for key, data in pairs(FitterCharacterSaved or {}) do
        if type(key) == "string" and key:match("^Outfit%d+$")
            and type(data) == "table" and type(data.Emotes) == "table" then
            data.Emotes[item.id] = nil
        end
    end
    UI_Transmog._PagedShared.SetFavorite("FavoriteEmotes", item.id, false)
    UI_Transmog:RefreshEmoteList()
    UI_Transmog:UpdateMountIcons()
    Fitter:RefreshFeatureEvents()
end

function UI_Transmog:StopEmotePreview()
    s.emotePreviewRequest = (s.emotePreviewRequest or 0) + 1
    local scene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    local actor = scene and scene.GetPlayerActor and scene:GetPlayerActor()
    if actor and actor.SetAnimation then
        if actor.SetAnimationBlendOperation then
            pcall(actor.SetAnimationBlendOperation, actor, 1)
        end
        pcall(actor.SetAnimation, actor, 0, 0, 1, 0)
    end
end

function UI_Transmog:PreviewEmoteAnimation(item)
    local animationID = item and item.previewAnimationID
    if type(animationID) ~= "number" then return end

    self:CancelUITimers("preview")
    self:StopEmotePreview()
    local request = s.emotePreviewRequest
    local clearHearthstoneVisuals = s.previewHearthstoneActive == true
    s.hearthstonePreviewRequest = (s.hearthstonePreviewRequest or 0) + 1
    s.previewHearthstoneActive = nil
    self:ClearMountPreview()

    local attempts = 0
    local function PlayWhenLoaded()
        if request ~= s.emotePreviewRequest then return end
        attempts = attempts + 1
        -- Fetch the actor again after ClearMountPreview: the wardrobe can
        -- replace or redress it during its first asynchronous update.
        local scene = TransmogFrame and TransmogFrame.CharacterPreview
            and TransmogFrame.CharacterPreview.ModelScene
        local actor = scene and scene.GetPlayerActor and scene:GetPlayerActor()
        if not actor or not actor.SetAnimation
            or (actor.IsLoaded and not actor:IsLoaded()) then
            if attempts < 40 then
                UI_Transmog:ScheduleTimer(
                    .05, PlayWhenLoaded, "preview")
            end
            return
        end

        if clearHearthstoneVisuals then
            if actor.SetSpellVisualKit then
                pcall(actor.SetSpellVisualKit, actor, 0, true)
            end
            if actor.PlayAnimationKit then
                pcall(actor.PlayAnimationKit, actor, 0, false)
            end
        end
        if actor.SetAnimationBlendOperation then
            pcall(actor.SetAnimationBlendOperation, actor, 1)
        end
        pcall(actor.SetAnimation, actor, animationID, 0, 1, 0)

        UI_Transmog:ScheduleTimer(5, function()
            if request ~= s.emotePreviewRequest then return end
            if actor.SetAnimationBlendOperation then
                pcall(actor.SetAnimationBlendOperation, actor, 1)
            end
            pcall(actor.SetAnimation, actor, 0, 0, 1, 0)
        end, "preview")
    end

    -- Even an actor reporting IsLoaded can still be redressed on the frame in
    -- which the wardrobe opens.  Let that initial update settle first.
    self:ScheduleTimer(.1, PlayWhenLoaded, "preview")
end

local function ShowAssignmentMenu(owner)
    local item, data = owner.item, CurrentData(true)
    if not item or not data or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    local assignment = data.Emotes[item.id]
    if type(assignment) ~= "table"
        or type(assignment.conditions) ~= "table" then
        assignment = { conditions = {} }
        data.Emotes[item.id] = assignment
    end
    local conditions = assignment.conditions

    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(item.name)
        local function FinishAssignmentChange()
            data.Emotes[item.id] = IsAssigned(assignment) and assignment or nil
            if s.emoteCheckedOnly then
                UI_Transmog:RefreshEmoteList()
            else
                UI_Transmog:UpdateEmotePageDisplay()
            end
            UI_Transmog:UpdateMountIcons()
            Fitter:RefreshFeatureEvents()
        end
        if item.command or ns.Emote.IsBuiltInCommand(item.text) then
            local ignoreTarget = root:CreateCheckbox(L["Ignore target"], function()
                return assignment.ignoreTarget == true
            end, function()
                assignment.ignoreTarget = not assignment.ignoreTarget or nil
                FinishAssignmentChange()
            end)
            ignoreTarget:SetTooltip(function(tooltip)
                GameTooltip_SetTitle(tooltip, "Ignore target")
                GameTooltip_AddNormalLine(tooltip,
                    "Uses the emote's untargeted wording without clearing your selected target.")
            end)
            root:CreateDivider()
        end
        for _, definition in ipairs(CONDITIONS) do
            local condition = definition
            if type(condition.submenu) == "table" then
                local flyout = root:CreateButton(condition.label)
                for _, definition in ipairs(condition.submenu) do
                    local option = definition
                    flyout:CreateCheckbox(option.label, function()
                        return type(conditions[condition.key]) == "table"
                            and conditions[condition.key][option.key] == true
                    end, function()
                        conditions[condition.key] =
                            conditions[condition.key] or {}
                        local selections = conditions[condition.key]
                        selections[option.key] =
                            not selections[option.key] or nil
                        if not next(selections) then
                            conditions[condition.key] = nil
                        end
                        FinishAssignmentChange()
                    end)
                end
            else
                root:CreateCheckbox(condition.label, function()
                    return conditions[condition.key] == true
                end, function()
                    conditions[condition.key] =
                        not conditions[condition.key] or nil
                    FinishAssignmentChange()
                end)
            end
        end
    end)
end

local function ShowEmoteContextMenu(owner)
    local item = owner.item
    if not item or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        local favorite = UI_Transmog._PagedShared.IsEmoteFavorite(item.id)
        root:CreateButton(favorite and L["Remove Favorite"] or L["Set Favorite"], function()
            UI_Transmog._PagedShared.SetFavorite(
                "FavoriteEmotes", item.id, not favorite)
            UI_Transmog:RefreshEmoteList()
        end)
        if item.custom or item.previewAnimationID then
            root:CreateDivider()
        end
        if item.custom then
            root:CreateButton(L["Delete Emote"], function() DeleteCustomEmote(item) end)
        end
        if item.previewAnimationID then
            root:CreateButton(L["Preview"], function()
                UI_Transmog:PreviewEmoteAnimation(item)
            end)
        end
    end)
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
    popup:SetTitle("Add New Emote")
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
    scope:SetDefaultText("This Character")
    scope:SetupMenu(function(_, root)
        root:CreateRadio(L["This Character"], function()
            return scope.value == "character"
        end, function()
            scope.value = "character"
            scope:SetDefaultText("This Character")
        end)
        root:CreateRadio(L["Account"], function()
            return scope.value == "account"
        end, function()
            scope.value = "account"
            scope:SetDefaultText("Account")
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
            UIErrorsFrame:AddMessage("Enter emote text.", 1, 0.2, 0.2)
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

local function ShowCreatePopup()
    local popup = CreatePopup()
    popup.titleEdit:SetText("")
    popup.edit:SetText("")
    popup.scope.value = "character"
    popup.scope:SetDefaultText("This Character")
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

function UI_Transmog:InitializeEmotesView()
    local _, _, search = self._PagedShared.CreateHeader(
        s.emotesFrame, "Emotes", function(text)
            s.emoteSearchString = text
            UI_Transmog:RefreshEmoteList()
        end)
    search.Instructions:SetText(L["Search"])
    s.emoteSearchString = ""
    s.emoteSourcesDropdown =
        self._PagedShared.CreateFilterDropdown(s.emotesFrame, search, {
            isDefault = function()
                return not s.emoteCheckedOnly
                    and not s.emoteDefaultOnly
                    and not s.emoteCustomOnly
                    and not s.emoteCharacterOnly
                    and not s.emoteAccountOnly
                    and not s.emoteAnimationOnly
                    and not s.emoteVoicelineOnly
            end,
            default = function()
                s.emoteCheckedOnly = false
                s.emoteDefaultOnly = false
                s.emoteCustomOnly = false
                s.emoteCharacterOnly = false
                s.emoteAccountOnly = false
                s.emoteAnimationOnly = false
                s.emoteVoicelineOnly = false
                UI_Transmog:RefreshEmoteList()
            end,
            setup = function(_, rootDescription)
                self._PagedShared.AddSelectedCheckbox(
                    rootDescription, s, "emoteCheckedOnly",
                    function() UI_Transmog:RefreshEmoteList() end)
                rootDescription:CreateCheckbox(L["Default"], function()
                    return s.emoteDefaultOnly
                end, function()
                    s.emoteDefaultOnly = not s.emoteDefaultOnly
                    if s.emoteDefaultOnly then
                        s.emoteCustomOnly = false
                        s.emoteCharacterOnly = false
                        s.emoteAccountOnly = false
                    end
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Custom"], function()
                    return s.emoteCustomOnly
                end, function()
                    s.emoteCustomOnly = not s.emoteCustomOnly
                    if s.emoteCustomOnly then
                        s.emoteDefaultOnly = false
                        s.emoteCharacterOnly = false
                        s.emoteAccountOnly = false
                    end
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Character"], function()
                    return s.emoteCharacterOnly
                end, function()
                    s.emoteCharacterOnly = not s.emoteCharacterOnly
                    if s.emoteCharacterOnly then
                        s.emoteDefaultOnly = false
                        s.emoteCustomOnly = false
                        s.emoteAccountOnly = false
                    end
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Account Wide"], function()
                    return s.emoteAccountOnly
                end, function()
                    s.emoteAccountOnly = not s.emoteAccountOnly
                    if s.emoteAccountOnly then
                        s.emoteDefaultOnly = false
                        s.emoteCustomOnly = false
                        s.emoteCharacterOnly = false
                    end
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Animation"], function()
                    return s.emoteAnimationOnly
                end, function()
                    s.emoteAnimationOnly = not s.emoteAnimationOnly
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Voiceline"], function()
                    return s.emoteVoicelineOnly
                end, function()
                    s.emoteVoicelineOnly = not s.emoteVoicelineOnly
                    UI_Transmog:RefreshEmoteList()
                end)
            end,
        })

    local add = CreateFrame("Button", nil, s.emotesFrame, "UIPanelButtonTemplate")
    add:SetSize(130, 26)
    add:SetPoint("TOPLEFT", s.emotesFrame, "TOPLEFT", 50, -24)
    add:SetText(L["Add New Emote"])
    add:SetScript("OnClick", ShowCreatePopup)
    s.emoteAddButton = add

    s.emoteButtons = {}
    for index = 1, PAGE_SIZE do
        local button =
            self._PagedShared.CreateCollectionEntryButton(s.emotesFrame)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local font = button:GetFontString()
        if font then
            font:SetWordWrap(true)
            if font.SetNonSpaceWrap then font:SetNonSpaceWrap(true) end
            if font.SetMaxLines then font:SetMaxLines(3) end
        end
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                ShowEmoteContextMenu(self)
            else
                ShowAssignmentMenu(self)
            end
        end)
        button.favoriteStar =
            self._PagedShared.CreateFavoriteStar(button)
        button.favoriteStar:ClearAllPoints()
        button.favoriteStar:SetPoint(
            "CENTER", button.IconFrame, "TOPLEFT", 3, -3)
        button:HookScript("OnEnter", function(self)
            if not self.item then return end
            self:ShowCollectionHover()
            local data = CurrentData(false)
            local assignments =
                GetAssignmentLabels(data and data.Emotes[self.item.id])
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.item.name, 1, 0.82, 0)
            local example = GetEmoteExample(self.item)
            if example then
                GameTooltip:AddLine(example, 1, 1, 1, true)
            else
                GameTooltip:AddLine(self.item.command and ("/" .. self.item.id)
                    or self.item.text, 1, 1, 1, true)
            end
            if self.item.requiresStill then
                GameTooltip:AddLine(
                    "This emote requires your character to be standing still to trigger.",
                    1, 0.45, 0.15, true)
            end
            if #assignments > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["Conditions:"], 0.7, 0.7, 0.7)
                for _, label in ipairs(assignments) do
                    GameTooltip:AddLine(label, 1, 0.82, 0)
                end
            end
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function(self)
            self:HideCollectionHover()
            GameTooltip:Hide()
        end)
        s.emoteButtons[index] = button
    end
    LayoutButtons()
    s.emotesFrame:HookScript("OnSizeChanged", LayoutButtons)
    s.emotePageText, s.emotePrevButton, s.emoteNextButton =
        self._PagedShared.CreateNavButtons(s.emotesFrame,
            function() UI_Transmog:EmotePagePrev() end,
            function() UI_Transmog:EmotePageNext() end)
    self:RefreshEmoteList()
end

function UI_Transmog:RefreshEmoteList()
    if not s.emoteButtons then return end
    local search = s.emoteSearchString or ""
    local data = CurrentData(false)
    s.emotePagedItems = {}
    for _, item in ipairs(ns.Emote.GetCatalog()) do
        local matchesSearch = search == ""
            or item.name:lower():find(search, 1, true)
            or (item.text and item.text:lower():find(search, 1, true))
        local selected = IsAssigned(data and data.Emotes[item.id])
        local matchesDefault = not s.emoteDefaultOnly or item.custom ~= true
        local matchesCustom = not s.emoteCustomOnly or item.custom == true
        local matchesCharacter = not s.emoteCharacterOnly
            or (item.custom == true and item.scope == "character")
        local matchesAccount = not s.emoteAccountOnly
            or (item.custom == true and item.scope == "account")
        local matchesAnimation =
            not s.emoteAnimationOnly or item.animation == true
        local matchesVoiceline =
            not s.emoteVoicelineOnly or item.voiceline == true
        if matchesSearch and matchesDefault and matchesCustom
            and matchesCharacter and matchesAccount
            and matchesAnimation and matchesVoiceline
            and (not s.emoteCheckedOnly or selected) then
            s.emotePagedItems[#s.emotePagedItems + 1] = item
        end
    end
    local favorites = FitterSaved and FitterSaved.FavoriteEmotes or {}
    table.sort(s.emotePagedItems, function(a, b)
        local aCustom, bCustom = a.custom == true, b.custom == true
        if aCustom ~= bCustom then return aCustom end
        if aCustom then
            local aCharacter = a.scope == "character"
            local bCharacter = b.scope == "character"
            if aCharacter ~= bCharacter then return aCharacter end
        end
        local aFavorite = favorites[a.id] == true
        local bFavorite = favorites[b.id] == true
        if aFavorite ~= bFavorite then return aFavorite end
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    s.emoteTotalPages = math.max(1, math.ceil(#s.emotePagedItems / PAGE_SIZE))
    s.emoteCurrentPage = math.min(s.emoteCurrentPage or 1, s.emoteTotalPages)
    self:UpdateEmotePageDisplay()
end

function UI_Transmog:UpdateEmotePageDisplay()
    if not s.emoteButtons then return end
    local data = CurrentData(true)
    local start = ((s.emoteCurrentPage or 1) - 1) * PAGE_SIZE
    for index, button in ipairs(s.emoteButtons) do
        local item = s.emotePagedItems[start + index]
        button.item = item
        button:SetShown(item ~= nil)
        if item then
            button:SetText(item.name)
            local fontString = button:GetFontString()
            if fontString then
                if item.custom and item.scope == "account" then
                    if ACCOUNT_WIDE_FONT_COLOR
                        and ACCOUNT_WIDE_FONT_COLOR.GetRGB then
                        fontString:SetTextColor(
                            ACCOUNT_WIDE_FONT_COLOR:GetRGB())
                    else
                        fontString:SetTextColor(0, 0.8, 1)
                    end
                elseif item.custom then
                    fontString:SetTextColor(1, 1, 1)
                else
                    fontString:SetTextColor(1, 0.82, 0)
                end
            end
            button.IconFrame.Icon:SetTexture(ns.Emote.ResolveIcon(item.icon))
            if button.StateTexture then
                button.StateTexture:SetShown(
                    IsAssigned(data and data.Emotes[item.id]))
            end
            button.favoriteStar:SetShown(
                self._PagedShared.IsEmoteFavorite(item.id))
        else
            button.favoriteStar:Hide()
        end
    end
    s.emotePageText:SetText(string.format(L["Page %d/%d"],
        s.emoteCurrentPage or 1, s.emoteTotalPages or 1))
    s.emotePrevButton:SetEnabled((s.emoteCurrentPage or 1) > 1)
    s.emoteNextButton:SetEnabled(
        (s.emoteCurrentPage or 1) < (s.emoteTotalPages or 1))
end

function UI_Transmog:RefreshEmoteRows()
    self:RefreshEmoteList()
end

function UI_Transmog:EmotePagePrev()
    if s.emoteCurrentPage > 1 then
        s.emoteCurrentPage = s.emoteCurrentPage - 1
        self:UpdateEmotePageDisplay()
    end
end

function UI_Transmog:EmotePageNext()
    if s.emoteCurrentPage < s.emoteTotalPages then
        s.emoteCurrentPage = s.emoteCurrentPage + 1
        self:UpdateEmotePageDisplay()
    end
end

function UI_Transmog:ShowEmotes()
    if not s.emotesViewInitialized then
        self:InitializeEmotesView()
        s.emotesViewInitialized = true
    end
    self:_ShowPagedFrame(s.emotesFrame, "RefreshEmoteList")
end
