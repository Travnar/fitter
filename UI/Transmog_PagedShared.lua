-- UI/Transmog_PagedShared.lua
-- Helpers shared by Transmog_FlyingPaged / GroundPaged / AquaticPaged / PetPaged.
-- Extracted to keep each paged file under 500 lines.

local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog

local function GetFavorites(key)
    FitterSaved = FitterSaved or {}
    FitterSaved[key] = FitterSaved[key] or {}
    return FitterSaved[key]
end

local function IsMountFavorite(mountID)
    return GetFavorites("FavoriteMounts")[mountID] == true
end

local function IsPetFavorite(petGUID)
    return GetFavorites("FavoritePets")[petGUID] == true
end

local function IsHunterPetFavorite(petNumber)
    return GetFavorites("FavoriteHunterPets")[petNumber] == true
end

local function IsHearthstoneFavorite(itemID)
    return GetFavorites("FavoriteHearthstones")[itemID] == true
end

local function IsToyFavorite(itemID)
    return GetFavorites("FavoriteToys")[itemID] == true
end

local function IsZoneFavorite(mapID)
    return GetFavorites("FavoriteZones")[mapID] == true
end

local function IsEmoteFavorite(emoteID)
    return GetFavorites("FavoriteEmotes")[emoteID] == true
end

local function CreateFavoriteStar(parent)
    local overlay = CreateFrame("Frame", nil, parent)
    overlay:SetAllPoints(parent)
    overlay:SetFrameLevel(parent:GetFrameLevel() + 10)
    overlay:EnableMouse(false)

    local star = overlay:CreateTexture(nil, "OVERLAY")
    star:SetAtlas("campcollection-icon-star")
    star:SetSize(20, 20)
    star:SetPoint("TOPLEFT", overlay, "TOPLEFT", 10, -12)
    star:Hide()
    return star
end

local function CreateNoSelectionCard(parent, tooltipText, onClick)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(114, 146)
    card:SetPoint("TOP", parent, "TOP", -234, -175)

    local blackBg = card:CreateTexture(nil, "BACKGROUND", nil, -1)
    blackBg:SetColorTexture(0, 0, 0, 1)
    blackBg:SetPoint("TOPLEFT", 4, -4)
    blackBg:SetPoint("BOTTOMRIGHT", -4, 4)

    local border = card:CreateTexture(nil, "ARTWORK")
    border:SetAllPoints()
    border:SetAtlas("transmog-setCard-default", true)

    local icon = card:CreateTexture(nil, "OVERLAY", nil, 2)
    icon:SetAtlas("transmog-icon-hidden")
    icon:SetSize(28, 28)
    icon:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)

    if tooltipText.centerAtlas then
        local centerIcon = card:CreateTexture(nil, "ARTWORK", nil, 1)
        centerIcon:SetAtlas(tooltipText.centerAtlas)
        centerIcon:SetSize(72, 72)
        centerIcon:SetPoint("CENTER")
        centerIcon:SetDesaturated(true)
        centerIcon:SetVertexColor(.42, .42, .42, .8)
        card.CenterIcon = centerIcon
    end

    local hover = card:CreateTexture(nil, "OVERLAY", nil, 1)
    hover:SetAllPoints()
    hover:SetAtlas("transmog-setCard-default", true)
    hover:SetVertexColor(1, .9, .5, .75)
    hover:SetBlendMode("ADD")
    hover:Hide()

    local function UpdateHoverStyle()
        if card.selected then
            hover:SetAtlas("transmog-wardrobe-border-current-transmogged", true)
            hover:SetVertexColor(1, 1, 1, .5)
        else
            hover:SetAtlas("transmog-setCard-default", true)
            hover:SetVertexColor(1, .9, .5, .75)
        end
    end

    function card:SetSelected(selected)
        self.selected = selected == true
        border:SetAtlas(self.selected
            and "transmog-wardrobe-border-current-transmogged"
            or "transmog-setCard-default", true)
        if hover:IsShown() then
            UpdateHoverStyle()
        end
    end

    card:SetScript("OnClick", function()
        onClick(not card.selected)
    end)
    card:SetScript("OnEnter", function(self)
        UpdateHoverStyle()
        hover:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[tooltipText.title], 1, .82, 0, 1, true)
        if tooltipText.body then
            GameTooltip:AddLine(L[tooltipText.body], 1, .5, 1, true)
        end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function()
        hover:Hide()
        GameTooltip:Hide()
    end)
    return card
end

local function DoesSpecialCardMatchSearch(title, search)
    search = (search or ""):lower()
    return search == "" or title:lower():find(search, 1, true) ~= nil
end

local function GetSpecialCardTotalPages(itemCount, showSpecialCard)
    if showSpecialCard == false then
        return math.max(1, math.ceil(itemCount / 20))
    end
    if itemCount <= 19 then return 1 end
    return 1 + math.ceil((itemCount - 19) / 20)
end

local function GetSpecialCardPageForIndex(index, showSpecialCard)
    if showSpecialCard == false then return math.ceil(index / 20) end
    if index <= 19 then return 1 end
    return 1 + math.ceil((index - 19) / 20)
end

local function GetSpecialCardPageStart(page, showSpecialCard)
    if showSpecialCard == false then return 1 + ((page - 1) * 20) end
    if page <= 1 then return 1 end
    return 20 + ((page - 2) * 20)
end

local function PositionSpecialCardPageItem(container, parent, itemIndex, page, showSpecialCard)
    local visualIndex = page == 1 and showSpecialCard ~= false
        and itemIndex + 1 or itemIndex
    local col = (visualIndex - 1) % 5
    local row = math.floor((visualIndex - 1) / 5)
    container:ClearAllPoints()
    container:SetPoint("TOP", parent, "TOP",
        -234 + (col * 117), -175 - (row * 149))
end

-- Compact collection entry inspired by Blizzard's Toy Box: a framed square
-- icon, label to its right, and selection communicated on the icon frame
-- instead of with DisplayTypeButtonTemplate's fixed-width card atlas.
local function CreateCollectionEntryButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(220, 46)

    local iconFrame = CreateFrame("Frame", nil, button)
    iconFrame:SetSize(50, 50)
    iconFrame:SetPoint("LEFT", button, "LEFT", 0, 0)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(42, 42)
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 1)
    icon:SetTexCoord(0.04347826, 0.95652173, 0.04347826, 0.95652173)
    iconFrame.Icon = icon
    button.IconFrame = iconFrame

    local collectedBorder = iconFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    collectedBorder:SetAtlas("collections-itemborder-collected")
    collectedBorder:SetSize(56, 56)
    collectedBorder:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    button.CollectionBorder = collectedBorder

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", iconFrame, "RIGHT", 9, 1)
    label:SetWidth(161)
    label:SetHeight(42)
    label:SetJustifyH("LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(true)
    if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end
    if label.SetMaxLines then label:SetMaxLines(3) end
    button:SetFontString(label)

    local selected = iconFrame:CreateTexture(nil, "OVERLAY", nil, 2)
    selected:SetAtlas("collections-itemborder-collected")
    selected:SetSize(56, 56)
    selected:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    selected:SetDesaturated(true)
    selected:SetVertexColor(0.82, 0.18, 1, .60)
    selected:Hide()
    button.StateTexture = selected

    local highlight = iconFrame:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(1)
    highlight:SetSize(48, 48)
    highlight:SetPoint("CENTER", iconFrame, "CENTER", 0, 2)
    button:SetHighlightTexture(highlight)
    button.collectionHighlight = highlight

    local hoverGlow = iconFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    hoverGlow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hoverGlow:SetBlendMode("ADD")
    hoverGlow:SetAlpha(0.75)
    hoverGlow:SetSize(48, 48)
    hoverGlow:SetPoint("CENTER", iconFrame, "CENTER", 0, 2)
    hoverGlow:Hide()

    local hoverBorder = iconFrame:CreateTexture(nil, "OVERLAY", nil, 4)
    hoverBorder:SetAtlas("collections-itemborder-collected")
    hoverBorder:SetBlendMode("ADD")
    hoverBorder:SetVertexColor(1, 0.92, 0.62, 0.8)
    hoverBorder:SetSize(56, 56)
    hoverBorder:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    hoverBorder:Hide()

    local selectedHoverBorder = iconFrame:CreateTexture(nil, "OVERLAY", nil, 4)
    selectedHoverBorder:SetAtlas("collections-itemborder-collected")
    selectedHoverBorder:SetDesaturated(true)
    selectedHoverBorder:SetBlendMode("ADD")
    selectedHoverBorder:SetVertexColor(0.9, 0.32, 1, 0.85)
    selectedHoverBorder:SetSize(56, 56)
    selectedHoverBorder:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    selectedHoverBorder:Hide()

    function button:ShowCollectionHover()
        if button:IsEnabled() then
            hoverGlow:Show()
            hoverBorder:SetShown(not selected:IsShown())
            selectedHoverBorder:SetShown(selected:IsShown())
        end
    end
    function button:HideCollectionHover()
        hoverGlow:Hide()
        hoverBorder:Hide()
        selectedHoverBorder:Hide()
    end
    button:HookScript("OnEnter", function()
        button:ShowCollectionHover()
    end)
    button:HookScript("OnLeave", function()
        button:HideCollectionHover()
    end)

    return button
end

local function SortFavoritesFirst(items, idField, favorites)
    table.sort(items, function(a, b)
        local aCollected = a.isCollected ~= false
        local bCollected = b.isCollected ~= false
        if aCollected ~= bCollected then
            return aCollected
        end
        local aID, bID = a[idField], b[idField]
        local aFavorite = aID ~= nil and favorites[aID] == true
        local bFavorite = bID ~= nil and favorites[bID] == true
        if aFavorite ~= bFavorite then
            return aFavorite
        end
        return a.name < b.name
    end)
end

local function SetFavorite(key, id, favorite)
    local favorites = GetFavorites(key)
    favorites[id] = favorite and true or nil
end


-- Creates the header row used by each paged frame:
--   * label  ("Flying" / "Ground" / "Aquatic" / "Pets")
--   * separator line under the label
--   * search box anchored top-right (lowercased text forwarded to onSearchChanged)
-- Returns (label, separator, searchBox).
local function CreateHeader(parentFrame, labelText, onSearchChanged)
    local label = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    label:SetJustifyH("LEFT")
    label:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 50, -75)
    label:SetText(L[labelText])

    local separator = parentFrame:CreateTexture(nil, "ARTWORK")
    separator:SetAtlas("transmog-tabs-header-line", true)
    separator:SetAlpha(0.1)
    separator:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)

    local searchBox = CreateFrame("EditBox", nil, parentFrame, "SearchBoxTemplate")
    searchBox:SetSize(168, 20)
    searchBox:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", -160, -26)
    searchBox:SetAutoFocus(false)
    searchBox.Instructions:SetText(L["Search"])
    searchBox:HookScript("OnTextChanged", function(self)
        onSearchChanged(self:GetText():lower())
    end)

    return label, separator, searchBox
end


-- Creates a filter dropdown anchored to the right of `anchorRight`.
local function CreateFilterDropdown(parentFrame, anchorRight, cfg)
    local dropdown = CreateFrame("DropdownButton", nil, parentFrame, "WowStyle1FilterDropdownTemplate")
    dropdown:SetPoint("LEFT", anchorRight, "RIGHT", 5, 0)
    dropdown:SetWidth(104)
    dropdown.resizeToText = false
    dropdown:SetIsDefaultCallback(cfg.isDefault)
    dropdown:SetDefaultCallback(cfg.default)
    dropdown:SetupMenu(cfg.setup)
    return dropdown
end


-- Adds a "Selected"-only checkbox to `rootDescription` that toggles
-- `state[checkedField]` and calls `refresh` on change.
local function AddSelectedCheckbox(rootDescription, state, checkedField, refresh)
    rootDescription:CreateCheckbox(L["Selected"], function()
        return state[checkedField]
    end, function()
        state[checkedField] = not state[checkedField]
        refresh()
    end)
end


-- Adds a named submenu with Check All / Uncheck All buttons followed by one
-- checkbox per entry in `entries` (each entry has .key and .label). Toggles
-- `state[selectedField][key]` and invokes `refresh` after every change.
local function AddCheckboxFilterSubmenu(rootDescription, label, entries, state, selectedField, refresh)
    local submenu = rootDescription:CreateButton(label)
    submenu:CreateButton(L["Check All"], function()
        for _, entry in ipairs(entries) do
            state[selectedField][entry.key] = true
        end
        refresh()
    end)
    submenu:CreateButton(L["Uncheck All"], function()
        wipe(state[selectedField])
        refresh()
    end)
    for _, entry in ipairs(entries) do
        local entryKey = entry.key
        submenu:CreateCheckbox(entry.label, function()
            return state[selectedField][entryKey] == true
        end, function()
            state[selectedField][entryKey] = (not state[selectedField][entryKey]) and true or nil
            refresh()
        end)
    end
    return submenu
end


-- Creates a bottom-centered pagination navigation row on `parentFrame`:
-- a centered "X / Y" font string flanked by Prev / Next arrow buttons.
-- Returns (pageText, prevButton, nextButton).
local function CreateNavButtons(parentFrame, onPrev, onNext)
    local navContainer = CreateFrame("Frame", nil, parentFrame)
    navContainer:SetSize(200, 30)
    navContainer:SetPoint("BOTTOM", parentFrame, "BOTTOM", 0, 18)

    local pageText = navContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pageText:SetPoint("CENTER", -25, 0)

    local prevButton = CreateFrame("Button", nil, navContainer)
    prevButton:SetSize(32, 32)
    prevButton:SetPoint("LEFT", pageText, "RIGHT", 5, 0)

    local prevNormal = prevButton:CreateTexture(nil, "ARTWORK")
    prevNormal:SetAllPoints()
    prevNormal:SetTexture(130869)
    prevButton:SetNormalTexture(prevNormal)

    local prevHighlight = prevButton:CreateTexture(nil, "HIGHLIGHT")
    prevHighlight:SetAllPoints()
    prevHighlight:SetTexture(130757)
    prevHighlight:SetBlendMode("ADD")
    prevButton:SetHighlightTexture(prevHighlight)

    local prevPushed = prevButton:CreateTexture(nil, "ARTWORK")
    prevPushed:SetAllPoints()
    prevPushed:SetTexture(130868)
    prevPushed:SetTexCoord(0, 1, 0, 1)
    prevButton:SetPushedTexture(prevPushed)

    local prevDisabled = prevButton:CreateTexture(nil, "ARTWORK")
    prevDisabled:SetAllPoints()
    prevDisabled:SetTexture(130867)
    prevButton:SetDisabledTexture(prevDisabled)

    prevButton:SetScript("OnClick", onPrev)
    prevButton:Show()

    local nextButton = CreateFrame("Button", nil, navContainer)
    nextButton:SetSize(32, 32)
    nextButton:SetPoint("LEFT", prevButton, "RIGHT", 3, 0)

    local nextNormal = nextButton:CreateTexture(nil, "ARTWORK")
    nextNormal:SetAllPoints()
    nextNormal:SetTexture(130866)
    nextButton:SetNormalTexture(nextNormal)

    local nextHighlight = nextButton:CreateTexture(nil, "HIGHLIGHT")
    nextHighlight:SetAllPoints()
    nextHighlight:SetTexture(130757)
    nextHighlight:SetBlendMode("ADD")
    nextButton:SetHighlightTexture(nextHighlight)

    local nextPushed = nextButton:CreateTexture(nil, "ARTWORK")
    nextPushed:SetAllPoints()
    nextPushed:SetTexture(130865)
    nextPushed:SetTexCoord(0, 1, 0, 1)
    nextButton:SetPushedTexture(nextPushed)

    local nextDisabled = nextButton:CreateTexture(nil, "ARTWORK")
    nextDisabled:SetAllPoints()
    nextDisabled:SetTexture(130864)
    nextButton:SetDisabledTexture(nextDisabled)

    nextButton:SetScript("OnClick", onNext)
    nextButton:Show()

    return pageText, prevButton, nextButton
end


-- Opens the standard Blizzard context menu for a mount card.  Standard menu
-- buttons use white text and the same gold hover highlight as the Hearthstone
-- selection rows.
local function ShowMountContextMenu(owner, mountData, refresh)
    if not mountData or (type(mountData.id) ~= "number"
        and type(mountData.id) ~= "string") then return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then return end

    local mountID = mountData.id
    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        if mountData.isCollected ~= false then
            local favorite = IsMountFavorite(mountID)
            rootDescription:CreateButton(favorite and L["Remove Favorite"] or L["Set Favorite"], function()
                SetFavorite("FavoriteMounts", mountID, not favorite)
                UI_Transmog:InvalidateMountListCache()
                if refresh then refresh() end
            end)
            rootDescription:CreateDivider()
        end
        if type(mountID) == "number" then
            rootDescription:CreateButton(L["Preview"], function()
                UI_Transmog:PreviewSelectedMount(mountID)
            end)
        end
        if mountData.isCollected ~= false and type(mountID) == "number" then
            rootDescription:CreateButton(L["Summon Mount"], function()
                C_MountJournal.SummonByID(mountID)
            end)
        end
    end)
end


UI_Transmog._PagedShared = {
    CreateHeader = CreateHeader,
    CreateFilterDropdown = CreateFilterDropdown,
    AddSelectedCheckbox = AddSelectedCheckbox,
    AddCheckboxFilterSubmenu = AddCheckboxFilterSubmenu,
    CreateNavButtons = CreateNavButtons,
    CreateFavoriteStar = CreateFavoriteStar,
    CreateNoSelectionCard = CreateNoSelectionCard,
    DoesSpecialCardMatchSearch = DoesSpecialCardMatchSearch,
    GetSpecialCardTotalPages = GetSpecialCardTotalPages,
    GetSpecialCardPageForIndex = GetSpecialCardPageForIndex,
    GetSpecialCardPageStart = GetSpecialCardPageStart,
    PositionSpecialCardPageItem = PositionSpecialCardPageItem,
    CreateCollectionEntryButton = CreateCollectionEntryButton,
    IsMountFavorite = IsMountFavorite,
    IsPetFavorite = IsPetFavorite,
    IsHunterPetFavorite = IsHunterPetFavorite,
    IsHearthstoneFavorite = IsHearthstoneFavorite,
    IsToyFavorite = IsToyFavorite,
    IsZoneFavorite = IsZoneFavorite,
    IsEmoteFavorite = IsEmoteFavorite,
    SetFavorite = SetFavorite,
    SortFavoritesFirst = SortFavoritesFirst,
    ShowMountContextMenu = ShowMountContextMenu,
}
