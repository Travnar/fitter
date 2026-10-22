-- Transmog_Titles.lua
-- Player-title dropdown attached to the Wardrobe character preview.
-- Split out of UI_Transmog.lua. Shares state via UI_Transmog._s.

local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter

local IGNORE_TITLE_LABEL = "|cff888888" .. L["Ignore Title"] .. "|r"

local SEARCH_ROW_HEIGHT = 24
local SEARCH_MAX_ROWS = 12
local SEARCH_LIST_ALPHA = 1

-- Matches the character pane's title list: gold text, blue highlight bar.
local TITLE_HIGHLIGHT_TEXTURE = "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar-Blue"

local function CreateDisplayTitle(titleID)
    if titleID == nil or titleID == -1 then
        return IGNORE_TITLE_LABEL
    end

    local playerName = UnitName("player")
    local titleName = titleID ~= 0 and GetTitleName(titleID)
    if not titleName then
        return NORMAL_FONT_COLOR:WrapTextInColorCode(playerName)
    end

    if titleName:sub(-1) == " " then
        return NORMAL_FONT_COLOR:WrapTextInColorCode(titleName .. playerName)
    else
        return NORMAL_FONT_COLOR:WrapTextInColorCode(playerName .. " " .. titleName)
    end
end

local function CreateTitleHighlight(region, layer, alpha)
    local texture = region:CreateTexture(nil, layer)
    texture:SetAllPoints()
    texture:SetTexture(TITLE_HIGHLIGHT_TEXTURE)
    texture:SetBlendMode("ADD")
    texture:SetAlpha(alpha or 1)
    return texture
end

local function SetSelectedTitle(titleID)
    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if not outfitID or not FitterCharacterSaved["Outfit"..outfitID] then
        return
    end

    FitterCharacterSaved["Outfit"..outfitID].Title = titleID

    if s.titleDropdown then
        s.titleDropdown:SetDefaultText(CreateDisplayTitle(titleID))
    end
    if s.titleSearch then
        s.titleSearch:RefreshCurrent()
    end

    local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    if activeOutfitID and activeOutfitID == outfitID then
        Fitter:UpdateTitle()
    end

    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
end

local function GetViewedSavedTitle()
    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if outfitID and FitterCharacterSaved and FitterCharacterSaved["Outfit"..outfitID] then
        return FitterCharacterSaved["Outfit"..outfitID].Title
    end
    return nil
end

-- Ignore Title, then the bare player name, then known titles by name.
-- search is the plain lowercase text matched against what the player types.
local function BuildTitleEntries()
    local playerName = UnitName("player")
    local entries = {
        {id = -1, label = IGNORE_TITLE_LABEL, search = L["Ignore Title"]:lower()},
        {id = 0, label = playerName, search = playerName:lower()},
    }

    local titles = {}
    for i = 1, GetNumTitles() do
        if IsTitleKnown(i) then
            local raw = (GetTitleName(i) or ""):gsub("%%s", "")
            titles[#titles + 1] = {
                id = i,
                label = CreateDisplayTitle(i),
                search = strtrim(raw):lower(),
            }
        end
    end
    table.sort(titles, function(a, b) return a.label < b.label end)

    for _, entry in ipairs(titles) do
        entries[#entries + 1] = entry
    end
    return entries
end

local function IsCurrentTitle(id)
    local saved = GetViewedSavedTitle()
    if id == -1 then return saved == nil or saved == -1 end
    return saved == id
end

-- A text box that, when focused, lists every title under it and filters the
-- list as the player types. Up/Down move the highlight; Enter or Tab picks it.
local function CreateTitleSearch(parent)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(260, 30)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(80)
    editBox:SetJustifyH("CENTER")
    editBox:Hide()

    -- Shows the outfit's title while the box is empty and unfocused.
    local current = editBox:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
    current:SetPoint("LEFT", 0, 0)
    current:SetPoint("RIGHT", 0, 0)
    current:SetJustifyH("CENTER")
    current:SetWordWrap(false)

    local list = CreateFrame("Frame", nil, editBox, "TooltipBackdropTemplate")
    list:SetFrameStrata("FULLSCREEN_DIALOG")
    list:SetPoint("TOPLEFT", editBox, "BOTTOMLEFT", -9, 2)
    list:SetPoint("TOPRIGHT", editBox, "BOTTOMRIGHT", 4, 2)
    list:Hide()
    list.results, list.positions = {}, {}
    -- The tooltip backdrop's center is translucent, so back it with a solid fill.
    local backing = list:CreateTexture(nil, "BACKGROUND")
    backing:SetPoint("TOPLEFT", 3, -3)
    backing:SetPoint("BOTTOMRIGHT", -3, 3)
    backing:SetColorTexture(0, 0, 0, SEARCH_LIST_ALPHA)

    local scrollBox = CreateFrame("Frame", nil, list, "WowScrollBoxList")
    local scrollBar = CreateFrame("EventFrame", nil, list, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(SEARCH_ROW_HEIGHT)
    view:SetElementInitializer("Button", function(button, entry)
        if not button.text then
            button.stripe = button:CreateTexture(nil, "BACKGROUND")
            button.stripe:SetAllPoints()
            button.stripe:SetColorTexture(1, 1, 1, 0.06)
            -- The outfit's current title keeps the bar, like the character pane.
            button.current = CreateTitleHighlight(button, "BORDER")
            button.selected = CreateTitleHighlight(button, "ARTWORK", 0.6)
            CreateTitleHighlight(button, "HIGHLIGHT", 0.6)

            button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            button.text:SetPoint("LEFT", 6, 0)
            button.text:SetPoint("RIGHT", -6, 0)
            button.text:SetJustifyH("LEFT")
            button.text:SetWordWrap(false)

            button:SetScript("OnClick", function(self) list:Pick(self.entry) end)
        end
        button.entry = entry
        button.text:SetText(entry.label)
        button.stripe:SetShown(list.positions[entry] % 2 == 0)
        button.current:SetShown(IsCurrentTitle(entry.id))
        button.selected:SetShown(entry == list.selectedEntry)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar,
        {CreateAnchor("TOPLEFT", list, "TOPLEFT", 6, -6),
         CreateAnchor("BOTTOMRIGHT", list, "BOTTOMRIGHT", -20, 6)},
        {CreateAnchor("TOPLEFT", list, "TOPLEFT", 6, -6),
         CreateAnchor("BOTTOMRIGHT", list, "BOTTOMRIGHT", -6, 6)})

    function editBox:RefreshCurrent()
        current:SetText(CreateDisplayTitle(GetViewedSavedTitle()))
        current:SetShown(not self:HasFocus() and self:GetText() == "")
    end

    function list:SetSelection(index)
        self.selection = index
        self.selectedEntry = index and self.results[index] or nil
        scrollBox:ForEachFrame(function(button)
            button.selected:SetShown(button.entry == self.selectedEntry)
        end)
        if index then
            scrollBox:ScrollToElementDataIndex(index, ScrollBoxConstants.AlignNearest)
        end
    end

    function list:Update()
        local text = strtrim(editBox:GetText()):lower()
        local results, positions = {}, {}
        for _, entry in ipairs(self.entries or {}) do
            if text == "" or entry.search:find(text, 1, true) then
                results[#results + 1] = entry
                positions[entry] = #results
            end
        end
        self.results, self.positions = results, positions
        self.selection, self.selectedEntry = nil, nil
        if #results == 0 then
            self:Hide()
            return
        end
        self:SetHeight(math.min(#results, SEARCH_MAX_ROWS) * SEARCH_ROW_HEIGHT + 12)
        self:Show()
        scrollBox:SetDataProvider(CreateDataProvider(results))
        -- Once the player is filtering, Enter picks the top match.
        if text ~= "" then self:SetSelection(1) end
    end

    function list:MoveSelection(step)
        local count = #self.results
        local index = (self.selection or (step > 0 and 0 or count + 1)) + step
        if index < 1 then index = count elseif index > count then index = 1 end
        self:SetSelection(index)
    end

    function list:Pick(entry)
        if not entry then return end
        self:Hide()
        editBox:SetText("")
        editBox:ClearFocus()
        SetSelectedTitle(entry.id)
        editBox:RefreshCurrent()
    end

    function list:PickSelection()
        if not self:IsShown() or not self.selectedEntry then return false end
        self:Pick(self.selectedEntry)
        return true
    end

    editBox:SetScript("OnEditFocusGained", function()
        current:Hide()
        -- Still open when focus returns after a click on the list's scroll bar.
        if list:IsShown() then return end
        list.entries = BuildTitleEntries()
        list:Update()
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        -- Delayed so a click on a title lands before the list hides.
        C_Timer.After(0.2, function()
            if self:HasFocus() then return end
            if list:IsShown() and list:IsMouseOver() then
                self:SetFocus()
                return
            end
            list:Hide()
            self:SetText("")
            self:RefreshCurrent()
        end)
    end)
    editBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput then list:Update() end
    end)
    editBox:SetScript("OnArrowPressed", function(_, key)
        if not list:IsShown() then return end
        if key == "UP" then list:MoveSelection(-1)
        elseif key == "DOWN" then list:MoveSelection(1) end
    end)
    editBox:SetScript("OnTabPressed", function() list:PickSelection() end)
    editBox:SetScript("OnEnterPressed", function(self)
        if not list:PickSelection() then self:ClearFocus() end
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        list:Hide()
        self:ClearFocus()
    end)
    editBox:SetScript("OnHide", function(self)
        list:Hide()
        self:SetText("")
        self:ClearFocus()
    end)
    editBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Character Title"], 1, 1, 1)
        GameTooltip:AddLine(L["Select a title for this transmog outfit"], 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L["Click to list every title, then type to filter."], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    editBox:SetScript("OnLeave", GameTooltip_Hide)

    return editBox
end

-- Shows either the title dropdown or the search box, per the Searchable
-- Title Selection option.
function UI_Transmog:RefreshTitleMode()
    if not s.titleDropdownInitialized then
        return
    end
    local searchable = FitterSaved and FitterSaved.SearchableTitles and true or false
    s.titleDropdown:SetShown(not searchable)
    s.titleSearch:SetShown(searchable)
    s.titleSearch:RefreshCurrent()
end

function UI_Transmog:InitializeTitleDropdown()
    if s.titleDropdownInitialized or not TransmogFrame or not TransmogFrame.CharacterPreview then
        return
    end

    s.titleDropdown = CreateFrame("DropdownButton", nil, TransmogFrame.CharacterPreview, "WowStyle1DropdownTemplate")

    local function IsIgnoreTitleSelected(_value)
        local saved = GetViewedSavedTitle()
        return saved == nil or saved == -1
    end

    local function IsTitleSelected(titleID)
        return GetViewedSavedTitle() == titleID
    end

    local function GeneratorFunctionTitles(dropdown, rootDescription)
        rootDescription:CreateRadio(IGNORE_TITLE_LABEL, IsIgnoreTitleSelected, SetSelectedTitle, -1)
        rootDescription:CreateRadio(CreateDisplayTitle(0), IsTitleSelected, SetSelectedTitle, 0)

        local titlesRaw = {}
        local count = 1

        for i = 1, GetNumTitles() do
            if IsTitleKnown(i) then
                titlesRaw[count] = {}
                titlesRaw[count].id = i
                titlesRaw[count].name = CreateDisplayTitle(i)
                count = count + 1
            end
        end

        table.sort(titlesRaw, function(a, b)
            return a.name < b.name
        end)

        for i = 1, #titlesRaw do
            rootDescription:CreateRadio(titlesRaw[i].name, IsTitleSelected, SetSelectedTitle, titlesRaw[i].id)
        end

        local extent = 20
        local maxCharacters = 20
        local maxScrollExtent = extent * maxCharacters
        rootDescription:SetScrollMode(maxScrollExtent)
    end

    if TransmogFrame.CharacterPreview.ModelScene and TransmogFrame.CharacterPreview.ModelScene.ControlFrame then
        TransmogFrame.CharacterPreview.ModelScene.ControlFrame:SetPoint("TOP", 0, -64)
    end

    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if outfitID and FitterCharacterSaved["Outfit"..outfitID] then
        local savedTitle = FitterCharacterSaved["Outfit"..outfitID].Title
        s.titleDropdown:SetDefaultText(CreateDisplayTitle(savedTitle))
    else
        s.titleDropdown:SetDefaultText(IGNORE_TITLE_LABEL)
    end

    s.titleDropdown:SetWidth(240)
    s.titleDropdown:SetPoint("TOP", TransmogFrame.CharacterPreview, "TOP", 0, -27)
    s.titleDropdown:SetFrameStrata("MEDIUM")
    s.titleDropdown:SetFrameLevel(200)
    s.titleDropdown.Text:SetJustifyH("CENTER")

    s.titleDropdown:SetupMenu(GeneratorFunctionTitles)

    s.titleDropdown:SetScript("OnEnter", function()
        GameTooltip:SetOwner(s.titleDropdown, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Character Title"], 1, 1, 1)
        GameTooltip:AddLine(L["Select a title for this transmog outfit"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    s.titleDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    s.titleSearch = CreateTitleSearch(TransmogFrame.CharacterPreview)
    s.titleSearch:SetPoint("TOP", TransmogFrame.CharacterPreview, "TOP", 2, -25)
    s.titleSearch:SetFrameStrata("MEDIUM")
    s.titleSearch:SetFrameLevel(200)

    s.titleDropdownInitialized = true
    UI_Transmog:RefreshTitleMode()
end

function UI_Transmog:UpdateTitleDropdown()
    if not s.titleDropdown or not s.titleDropdownInitialized then
        return
    end

    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if not outfitID or not FitterCharacterSaved["Outfit"..outfitID] then
        s.titleDropdown:SetDefaultText(IGNORE_TITLE_LABEL)
        return
    end

    local savedTitle = FitterCharacterSaved["Outfit"..outfitID].Title
    s.titleDropdown:SetDefaultText(CreateDisplayTitle(savedTitle))
    s.titleDropdown:GenerateMenu()
    s.titleSearch:RefreshCurrent()
end
