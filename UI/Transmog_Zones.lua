local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter

local BIOME_GROUPS = ns.Zones.BIOME_GROUPS
local EXPANSION_ZONES = ns.Zones.EXPANSION_ZONES
local CONTINENT_ZONES = ns.Zones.CONTINENT_ZONES

local PAGE_SIZE = 30
local START_X, START_Y = 30, -120
local GAP_X, BOTTOM_PADDING = 14, 65
local ICON_PATH = "Interface\\Icons\\"

local EXPANSION_FALLBACKS = {
    midnight = "achievement_zone_eversongwoods",
    tww = "achievement_zone_azjkahet",
    dragonflight = "achievement_zone_azurespan",
    shadowlands = "achievement_zone_shadowlands",
    bfa = "achievement_zone_zuldazar",
    legion = "achievement_zone_brokenisles",
    wod = "achievement_zone_draenor",
    mop = "achievement_zone_pandaria_01",
    cata = "achievement_zone_cataclysm",
    wrath = "achievement_zone_northrend_01",
    bc = "achievement_zone_outland_01",
    classic = "achievement_worldevent_lunar",
}

local ZONE_EXPANSIONS = {}
for _, expansion in ipairs(EXPANSION_ZONES) do
    for _, mapID in ipairs(expansion.mapIDs) do
        ZONE_EXPANSIONS[mapID] = expansion.key
    end
end

local function GetZoneIcon(zone)
    local name = zone.icon
        or EXPANSION_FALLBACKS[ZONE_EXPANSIONS[zone.mapID]]
        or "achievement_zone_easternkingdoms_01"
    return ICON_PATH .. name
end

local function CurrentData(create)
    local outfitID = C_TransmogOutfitInfo
        and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if not outfitID then return nil end
    if create then Fitter:CreateEmptyOutfit(outfitID) end
    local data = FitterCharacterSaved and FitterCharacterSaved["Outfit" .. outfitID]
    if data and type(data.Zones) ~= "table" then data.Zones = {} end
    return data, outfitID
end

local function GetOutfitNameByID(outfitID)
    local outfits = C_TransmogOutfitInfo
        and C_TransmogOutfitInfo.GetOutfitsInfo
        and C_TransmogOutfitInfo.GetOutfitsInfo()
    for _, info in ipairs(outfits or {}) do
        if info.outfitID == outfitID then return info.name end
    end
end

local function GetOutfitIDsForZone(mapID)
    local outfitIDs = {}
    for key, data in pairs(FitterCharacterSaved or {}) do
        local outfitID = type(key) == "string" and tonumber(key:match("^Outfit(%d+)$"))
        if outfitID and type(data.Zones) == "table"
            and tContains(data.Zones, mapID) then
            outfitIDs[#outfitIDs + 1] = outfitID
        end
    end
    table.sort(outfitIDs)
    return outfitIDs
end

local function GetOutfitSituationWarnings(mapID, associatedOutfitIDs)
    local warnings = {}
    local situation = ns.Zones.GetZoneSituation(mapID)
    local targetName = situation == "rest" and "Rest Area" or "World"
    local hasSituation = {}

    if UI_Transmog.CacheViewedZoneSituations then
        UI_Transmog:CacheViewedZoneSituations()
    end
    local outfits = C_TransmogOutfitInfo
        and C_TransmogOutfitInfo.GetOutfitsInfo
        and C_TransmogOutfitInfo.GetOutfitsInfo() or {}
    for _, info in ipairs(outfits) do
        if not info.isDisabled then
            local data = FitterCharacterSaved
                and FitterCharacterSaved["Outfit" .. info.outfitID]
            local state = data and data.ZoneSituationState
            if state then
                hasSituation[info.outfitID] = state[situation] == true
            end
        end
    end

    for _, outfitID in ipairs(associatedOutfitIDs or {}) do
        if not hasSituation[outfitID] then
            for otherOutfitID, enabled in pairs(hasSituation) do
                if otherOutfitID ~= outfitID and enabled then
                    warnings[outfitID] = targetName
                    break
                end
            end
        end
    end

    return warnings
end

local function LayoutButtons()
    if not s.zoneButtons or not s.zoneButtons[1] then return end
    local first = s.zoneButtons[1]
    local availableWidth = s.zonesFrame:GetWidth() - START_X * 2
    local rows = math.ceil(#s.zoneButtons / 3)
    local availableHeight = math.max(first:GetHeight(),
        s.zonesFrame:GetHeight() + START_Y - BOTTOM_PADDING)
    local stepY = rows > 1
        and (availableHeight - first:GetHeight()) / (rows - 1) or 0
    local columnWidth = availableWidth / 3
    local width = math.max(100, columnWidth - GAP_X)
    local stepX = columnWidth
    local buttonInset = GAP_X / 2
    for index, button in ipairs(s.zoneButtons) do
        local col, row = (index - 1) % 3, math.floor((index - 1) / 3)
        button:SetWidth(width)
        local font = button:GetFontString()
        if font then font:SetWidth(math.max(width - 58, 20)) end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", s.zonesFrame, "TOPLEFT",
            START_X + buttonInset + col * stepX,
            START_Y - row * stepY)
    end
end

local function RefreshAfterSelection()
    UI_Transmog:RefreshZonesList()
    UI_Transmog:UpdateMountIcons()
    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    if Fitter and Fitter.RefreshZoneCache then Fitter:RefreshZoneCache() end
end

local function ToggleZone(button)
    local item = button.item
    local data, outfitID = CurrentData(true)
    if not item or not data then return end

    if tContains(data.Zones, item.mapID) then
        tDeleteItem(data.Zones, item.mapID)
        UI_Transmog:TryDisableZoneSituation(item.mapID, outfitID)
    else
        data.Zones[#data.Zones + 1] = item.mapID
        UI_Transmog:UpdateZoneSituation(item.mapID, true)
    end
    RefreshAfterSelection()

    local onEnter = button:GetScript("OnEnter")
    if button:IsShown() and button:IsMouseOver() and onEnter then
        onEnter(button)
    elseif GameTooltip:GetOwner() == button then
        GameTooltip:Hide()
    end
end

function UI_Transmog:RefreshZonesList()
    if not s.zoneButtons then return end
    if self.CacheViewedZoneSituations then
        self:CacheViewedZoneSituations()
    end
    local data, outfitID = CurrentData(true)
    local selected = {}
    for _, mapID in ipairs(data and data.Zones or {}) do selected[mapID] = true end
    s.zonePagedItems = self:GetFilteredZones(selected)
    self._PagedShared.SortFavoritesFirst(
        s.zonePagedItems, "mapID",
        FitterSaved and FitterSaved.FavoriteZones or {})
    s.zoneTotalPages = math.max(1, math.ceil(#s.zonePagedItems / PAGE_SIZE))
    s.zoneCurrentPage = math.min(s.zoneCurrentPage or 1, s.zoneTotalPages)

    local start = (s.zoneCurrentPage - 1) * PAGE_SIZE
    for index, button in ipairs(s.zoneButtons) do
        local item = s.zonePagedItems[start + index]
        button.item = item
        button:SetShown(item ~= nil)
        if item then
            button.associatedOutfitIDs = GetOutfitIDsForZone(item.mapID)
            button:SetText(item.name)
            button.IconFrame.Icon:SetTexture(GetZoneIcon(item))
            button.IconFrame.Icon:SetDesaturated(false)
            button:SetAlpha(1)
            local font = button:GetFontString()
            if font then
                font:SetTextColor(1, 0.82, 0)
            end
            button:SetEnabled(true)
            if button.SetMotionScriptsWhileDisabled then
                button:SetMotionScriptsWhileDisabled(true)
            end
            if button.StateTexture then
                button.StateTexture:SetShown(selected[item.mapID] == true)
            end
            button.favoriteStar:SetShown(
                self._PagedShared.IsZoneFavorite(item.mapID))
        else
            button.favoriteStar:Hide()
        end
    end
    s.zonePageText:SetText(string.format(
        L["Page %d/%d"], s.zoneCurrentPage, s.zoneTotalPages))
    s.zonePrevButton:SetEnabled(s.zoneCurrentPage > 1)
    s.zoneNextButton:SetEnabled(s.zoneCurrentPage < s.zoneTotalPages)
end

function UI_Transmog:InitializeZoneSection()
    local _, _, search = self._PagedShared.CreateHeader(
        s.zonesFrame, "Zones", function(text)
            s.additionalSearchString = text
            s.zoneCurrentPage = 1
            UI_Transmog:RefreshZonesList()
        end)
    search.Instructions:SetText(L["Search"])
    s.zonesSearchBox = search

    local filter = self._PagedShared.CreateFilterDropdown(
        s.zonesFrame, search, {
            isDefault = function()
                return not s.additionalCheckedOnly
                    and next(s.zonesSelectedBiomes) == nil
                    and next(s.zonesSelectedExpansions) == nil
                    and next(s.zonesSelectedContinents) == nil
            end,
            default = function()
                s.additionalCheckedOnly = false
                wipe(s.zonesSelectedBiomes)
                wipe(s.zonesSelectedExpansions)
                wipe(s.zonesSelectedContinents)
                s.zoneCurrentPage = 1
                UI_Transmog:RefreshZonesList()
            end,
            setup = function(_, root)
                self._PagedShared.AddSelectedCheckbox(
                    root, s, "additionalCheckedOnly",
                    function() s.zoneCurrentPage = 1; self:RefreshZonesList() end)
                self._PagedShared.AddCheckboxFilterSubmenu(
                    root, "Continents", CONTINENT_ZONES, s,
                    "zonesSelectedContinents",
                    function() s.zoneCurrentPage = 1; self:RefreshZonesList() end)
                self._PagedShared.AddCheckboxFilterSubmenu(
                    root, "Expansions", EXPANSION_ZONES, s,
                    "zonesSelectedExpansions",
                    function() s.zoneCurrentPage = 1; self:RefreshZonesList() end)
                self._PagedShared.AddCheckboxFilterSubmenu(
                    root, "Biomes", BIOME_GROUPS, s, "zonesSelectedBiomes",
                    function() s.zoneCurrentPage = 1; self:RefreshZonesList() end)
            end,
        })
    s.zonesFilterDropdown = filter

    local selectAll = CreateFrame("Button", nil, s.zonesFrame, "UIPanelButtonTemplate")
    selectAll:SetSize(105, 24)
    selectAll:SetPoint("TOPLEFT", s.zonesFrame, "TOPLEFT", 50, -25)
    selectAll:SetText(L["Select All"])
    selectAll:SetScript("OnClick", function() self:ApplyBiomeSelection("all") end)
    selectAll:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Select All"], 1, 1, 1)
        GameTooltip:AddLine(
            "Selects all currently filtered zones for this outfit.",
            1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    selectAll:SetScript("OnLeave", GameTooltip_Hide)

    local clear = CreateFrame("Button", nil, s.zonesFrame, "UIPanelButtonTemplate")
    clear:SetSize(105, 24)
    clear:SetPoint("LEFT", selectAll, "RIGHT", 8, 0)
    clear:SetText(L["Clear"])
    clear:SetScript("OnClick", function() self:ApplyBiomeSelection("uncheck") end)
    clear:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Clear"], 1, 1, 1)
        GameTooltip:AddLine(
            "Removes all currently filtered zones from this outfit.",
            1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    clear:SetScript("OnLeave", GameTooltip_Hide)

    s.zoneButtons = {}
    for index = 1, PAGE_SIZE do
        local button =
            self._PagedShared.CreateCollectionEntryButton(s.zonesFrame)
        local font = button:GetFontString()
        if font then
            font:SetWordWrap(true)
            if font.SetNonSpaceWrap then font:SetNonSpaceWrap(true) end
            if font.SetMaxLines then font:SetMaxLines(3) end
        end
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(owner, mouseButton)
            if mouseButton == "RightButton" then
                if not owner.item or not MenuUtil
                    or not MenuUtil.CreateContextMenu then return end
                local item = owner.item
                MenuUtil.CreateContextMenu(owner, function(_, root)
                    local favorite =
                        self._PagedShared.IsZoneFavorite(item.mapID)
                    root:CreateButton(
                        favorite and L["Remove Favorite"] or L["Set Favorite"],
                        function()
                            self._PagedShared.SetFavorite(
                                "FavoriteZones", item.mapID, not favorite)
                            self:RefreshZonesList()
                        end)
                end)
            else
                ToggleZone(owner)
            end
        end)
        button.favoriteStar =
            self._PagedShared.CreateFavoriteStar(button)
        button.favoriteStar:ClearAllPoints()
        button.favoriteStar:SetPoint(
            "CENTER", button.IconFrame, "TOPLEFT", 3, -3)
        button:HookScript("OnEnter", function(owner)
            if not owner.item then return end
            owner:ShowCollectionHover()
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetText(owner.item.name, 1, 0.82, 0)
            if owner.associatedOutfitIDs
                and #owner.associatedOutfitIDs > 0 then
                local warnings = GetOutfitSituationWarnings(
                    owner.item.mapID, owner.associatedOutfitIDs)
                local viewedOutfitID = C_TransmogOutfitInfo
                    and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID
                    and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
                if viewedOutfitID and warnings[viewedOutfitID] then
                    GameTooltip:AddLine(string.format(
                        "This outfit does not have the %s situation enabled. The game will override it in this zone with another outfit that does.",
                        warnings[viewedOutfitID]), 1, 0.25, 0.25, true)
                end
                GameTooltip:AddLine(L["Associated Outfits:"], 0.7, 0.7, 0.7)
                for _, outfitID in ipairs(owner.associatedOutfitIDs) do
                    local name = GetOutfitNameByID(outfitID)
                        or ("Outfit " .. outfitID)
                    GameTooltip:AddLine(name, 1, 0.82, 0)
                end
            end
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function(owner)
            owner:HideCollectionHover()
            GameTooltip:Hide()
        end)
        s.zoneButtons[index] = button
    end
    LayoutButtons()
    s.zonesFrame:HookScript("OnSizeChanged", LayoutButtons)
    s.zonePageText, s.zonePrevButton, s.zoneNextButton =
        self._PagedShared.CreateNavButtons(s.zonesFrame,
            function() self:ZonePagePrev() end,
            function() self:ZonePageNext() end)
end

function UI_Transmog:ZonePagePrev()
    if s.zoneCurrentPage > 1 then
        s.zoneCurrentPage = s.zoneCurrentPage - 1
        self:RefreshZonesList()
    end
end

function UI_Transmog:ZonePageNext()
    if s.zoneCurrentPage < s.zoneTotalPages then
        s.zoneCurrentPage = s.zoneCurrentPage + 1
        self:RefreshZonesList()
    end
end
