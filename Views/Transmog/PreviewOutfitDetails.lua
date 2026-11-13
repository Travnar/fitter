-- Slot buttons and item list for the shared preview window, laid out like
-- Blizzard's Dressing Room and its outfit details panel.
local addonName, ns = ...

local Details = {}
ns.PreviewOutfitDetails = Details

-- Same columns and order as the Dressing Room.
local LEFT_SLOTS = {"HeadSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "ShirtSlot", "TabardSlot", "WristSlot"}
local RIGHT_SLOTS = {"HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
    "MainHandSlot", "SecondaryHandSlot"}
local ARMOR_SLOTS = {"HeadSlot", "ShoulderSlot", "BackSlot", "ChestSlot",
    "ShirtSlot", "TabardSlot", "WristSlot", "HandsSlot", "WaistSlot",
    "LegsSlot", "FeetSlot"}
local WEAPON_SLOTS = {"MainHandSlot", "SecondaryHandSlot"}

local SLOT_SPACING = 44
local ROW_HEIGHT = 34
local MAX_ROWS = 20

local slotButtons = {}
local rows = {}
local generation = 0

local function SlotID(slotName)
    return (GetInventorySlotInfo(slotName))
end

-- Returns name, quality, icon and item link for an appearance source. Item
-- data may still be loading, in which case name and quality are nil.
local function GetSourceDisplay(sourceID)
    local api = C_TransmogCollection
    local info = api.GetSourceInfo and api.GetSourceInfo(sourceID)
    local icon = api.GetSourceIcon and api.GetSourceIcon(sourceID)
    local link
    if api.GetAppearanceSourceInfo then
        local first, _, _, sourceIcon, _, itemLink = api.GetAppearanceSourceInfo(sourceID)
        if type(first) == "table" then
            link, icon = first.itemLink, icon or first.icon
        else
            link, icon = itemLink, icon or sourceIcon
        end
    end
    local itemID = info and info.itemID
    local name = info and info.name
    local quality = info and info.quality
    if itemID then
        name = name or C_Item.GetItemNameByID(itemID)
        quality = quality or C_Item.GetItemQualityByID(itemID)
        link = link or select(2, C_Item.GetItemInfo(itemID))
    end
    return name, quality, icon, link, itemID
end

local function QualityColor(quality)
    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

-- Calls update now and again once the item's data has loaded.
local function WithItemData(itemID, update)
    update()
    if not itemID or not Item or not Item.CreateFromItemID then return end
    local current = generation
    Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
        if current == generation then update() end
    end)
end

local function ShowLinkTooltip(owner, link, fallbackText)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if link then
        GameTooltip:SetHyperlink(link)
    else
        GameTooltip:SetText(fallbackText or "")
    end
    GameTooltip:Show()
end

local function OnLinkClick(self)
    if self.link and HandleModifiedItemClick then HandleModifiedItemClick(self.link) end
end

local function SetButtonIcon(button, icon, quality)
    button.icon:SetTexture(icon)
    if quality then
        button.border:SetVertexColor(QualityColor(quality))
        button.border:Show()
    else
        button.border:Hide()
    end
end

local function CreateSlotButton(parent, slotName)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(37, 37)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetAllPoints()
    button.border:SetTexture("Interface\\Common\\WhiteIconFrame")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    button.slotName = slotName
    local _, emptyTexture = GetInventorySlotInfo(slotName)
    button.emptyTexture = emptyTexture
    button:SetScript("OnEnter", function(self)
        ShowLinkTooltip(self, self.link, _G[slotName:upper()])
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", OnLinkClick)
    slotButtons[slotName] = button
    return button
end

local function CreateRow(panel, index)
    local row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 12, -12 - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", -12, 0)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
    row.text:SetPoint("RIGHT")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
        ShowLinkTooltip(self, self.link, self.text:GetText())
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", OnLinkClick)
    row:Hide()
    rows[index] = row
    return row
end

-- modelArea gets the slot columns; panel gets the item list.
function Details.Create(modelArea, panel)
    for index, slotName in ipairs(LEFT_SLOTS) do
        CreateSlotButton(modelArea, slotName):SetPoint("TOPLEFT", modelArea,
            "TOPLEFT", 10, -10 - (index - 1) * SLOT_SPACING)
    end
    for index, slotName in ipairs(RIGHT_SLOTS) do
        CreateSlotButton(modelArea, slotName):SetPoint("TOPRIGHT", modelArea,
            "TOPRIGHT", -10, -10 - (index - 1) * SLOT_SPACING)
    end
    for index = 1, MAX_ROWS do CreateRow(panel, index) end
    Details.Clear()
end

local function SetSlotButton(button, sourceID)
    button.link = nil
    if not sourceID then
        SetButtonIcon(button, button.emptyTexture, nil)
        return
    end
    local _, _, _, _, itemID = GetSourceDisplay(sourceID)
    WithItemData(itemID, function()
        local _, quality, icon, link = GetSourceDisplay(sourceID)
        SetButtonIcon(button, icon or button.emptyTexture, quality)
        button.link = link
    end)
end

local function SetRow(row, indent, iconSize, icon, text, r, g, b, link)
    row.icon:ClearAllPoints()
    row.icon:SetPoint("LEFT", indent, 0)
    row.icon:SetSize(iconSize, iconSize)
    row.icon:SetTexture(icon or 134400)
    row.text:SetText(text or RETRIEVING_ITEM_INFO or "")
    row.text:SetTextColor(r, g, b)
    row.link = link
    row:Show()
end

function Details.Clear()
    generation = generation + 1
    for _, button in pairs(slotButtons) do SetSlotButton(button, nil) end
    for _, row in ipairs(rows) do
        row:Hide()
        row.link = nil
    end
end

-- transmog: {[inventorySlotID] = {sourceID, secondarySourceID, illusionID}}
function Details.Show(transmog)
    Details.Clear()
    local function Source(slotName)
        local info = transmog[SlotID(slotName)]
        return info and info[1] ~= 0 and info or nil
    end

    for slotName, button in pairs(slotButtons) do
        local info = Source(slotName)
        SetSlotButton(button, info and info[1])
    end

    local index = 0
    local function NextRow()
        index = index + 1
        return rows[index]
    end
    local function AddSource(sourceID, indent, iconSize)
        local row = NextRow()
        if not row then return end
        local _, _, _, _, itemID = GetSourceDisplay(sourceID)
        WithItemData(itemID, function()
            local name, quality, icon, link = GetSourceDisplay(sourceID)
            local r, g, b = QualityColor(quality)
            SetRow(row, indent, iconSize, icon, name, r, g, b, link)
        end)
    end
    local function AddIllusion(illusionID)
        local api = C_TransmogCollection
        local info = api.GetIllusionInfo and api.GetIllusionInfo(illusionID)
        if not info or info.isHideVisual then return end
        local name, link
        if api.GetIllusionStrings then name, link = api.GetIllusionStrings(illusionID) end
        local row = NextRow()
        if row then
            SetRow(row, 20, 16, info.icon, name, 0.6, 0.8, 1, link)
        end
    end

    for _, slotName in ipairs(ARMOR_SLOTS) do
        local info = Source(slotName)
        if info then
            AddSource(info[1], 0, 24)
            if info[2] ~= 0 then AddSource(info[2], 20, 16) end
        end
    end
    local weaponsShown = false
    for _, slotName in ipairs(WEAPON_SLOTS) do
        local info = Source(slotName)
        if info then
            -- Blizzard separates weapons from armor with a blank line.
            if not weaponsShown and index > 0 then NextRow() end
            weaponsShown = true
            AddSource(info[1], 0, 24)
            if info[3] ~= 0 then AddIllusion(info[3]) end
        end
    end
end
