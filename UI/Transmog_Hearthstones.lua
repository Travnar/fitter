-- Paged multi-select Hearthstone selector.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter

local PAGE_SIZE = 30
local DEFAULT_ID = 6948
local PREVIEW_DURATION = 10
local BUTTON_START_X = 30
local BUTTON_START_Y = -120
local BUTTON_GAP_X = 14
local BUTTON_BOTTOM_PADDING = 65

local function LayoutHearthstoneButtons()
    if not s.hearthstoneModelFrames or not s.hearthstoneModelFrames[1] then return end
    local first = s.hearthstoneModelFrames[1].container
    local buttonHeight = first:GetHeight()
    local availableWidth = s.hearthstoneFrame:GetWidth() - BUTTON_START_X * 2
    local columnWidth = availableWidth / 3
    local buttonWidth = math.max(100, columnWidth - BUTTON_GAP_X)
    local rowCount = math.ceil(#s.hearthstoneModelFrames / 3)
    local availableHeight = math.max(buttonHeight,
        s.hearthstoneFrame:GetHeight() + BUTTON_START_Y - BUTTON_BOTTOM_PADDING)
    local stepY = rowCount > 1
        and (availableHeight - buttonHeight) / (rowCount - 1) or 0
    for i, frame in ipairs(s.hearthstoneModelFrames) do
        local button = frame.container
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        button:SetWidth(buttonWidth)
        local fontString = button:GetFontString()
        if fontString then fontString:SetWidth(math.max(buttonWidth - 58, 20)) end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", s.hearthstoneFrame, "TOPLEFT",
            BUTTON_START_X + BUTTON_GAP_X / 2 + col * columnWidth,
            BUTTON_START_Y - row * stepY)
    end
end

local function CurrentData(create)
    local id = UI_Transmog:GetViewedOutfitID()
    if not id or id == 0 then return nil end
    if create and not FitterCharacterSaved["Outfit"..id] then Fitter:CreateEmptyOutfit(id) end
    return FitterCharacterSaved["Outfit"..id], id
end

local function GetSelectedHearthstones(data, migrate)
    if not data then return {} end
    if type(data.Hearthstones) ~= "table" then
        local formerSelection = type(data.Hearthstone) == "number"
            and data.Hearthstone or nil
        if not migrate then
            return formerSelection and {formerSelection} or {}
        end
        data.Hearthstones = formerSelection and {formerSelection} or {}
        data.Hearthstone = nil
    end
    return data.Hearthstones
end

local function ResetPreviewActor(actor, request, onReady)
    local outfitInfo = actor.GetItemTransmogInfoList
        and actor:GetItemTransmogInfoList()
    local sheathed = actor.GetSheathed and actor:GetSheathed()

    if actor.SetSpellVisualKit then pcall(actor.SetSpellVisualKit, actor, 0, true) end
    if actor.PlayAnimationKit then pcall(actor.PlayAnimationKit, actor, 0, false) end
    if actor.SetAnimation then pcall(actor.SetAnimation, actor, 0) end

    -- Rebuilding the actor is the reliable way to remove persistent
    -- environmental attachments created by a spell visual kit.
    if actor.SetModelByUnit then
        pcall(actor.SetModelByUnit, actor, "player", sheathed ~= false, true)
    end

    local attempts = 0
    local function RestoreWhenLoaded()
        if request ~= s.hearthstonePreviewRequest then return end
        attempts = attempts + 1
        if actor.IsLoaded and not actor:IsLoaded() then
            if attempts < 40 then
                UI_Transmog:ScheduleTimer(
                    .05, RestoreWhenLoaded, "preview")
            end
            return
        end
        if outfitInfo and actor.SetItemTransmogInfo then
            for _, info in pairs(outfitInfo) do
                pcall(actor.SetItemTransmogInfo, actor, info)
            end
        end
        if sheathed ~= nil and actor.SetSheathed then
            pcall(actor.SetSheathed, actor, sheathed, false)
        end
        if onReady then onReady() end
    end
    RestoreWhenLoaded()
end

local function FinishPreviewOnExistingActor(actor, request)
    if request ~= s.hearthstonePreviewRequest then return end
    s.previewHearthstoneActive = nil
    if actor.SetSpellVisualKit then pcall(actor.SetSpellVisualKit, actor, 0, true) end
    if actor.PlayAnimationKit then pcall(actor.PlayAnimationKit, actor, 0, false) end
    if actor.SetAnimationBlendOperation then
        -- Enum.ModelBlendOperation.Anim: blend from the cast pose back to idle
        -- instead of snapping or rebuilding the character model.
        pcall(actor.SetAnimationBlendOperation, actor, 1)
    end
    if actor.SetAnimation then pcall(actor.SetAnimation, actor, 0, 0, 1, 0) end
end

function UI_Transmog:PreviewHearthstoneCast(item)
    self:CancelUITimers("preview")
    s.hearthstonePreviewRequest = (s.hearthstonePreviewRequest or 0) + 1
    local request = s.hearthstonePreviewRequest
    s.previewHearthstoneActive = item ~= nil

    self:ClearMountPreview()
    local scene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    local actor = scene and scene.GetPlayerActor and scene:GetPlayerActor()
    if not actor then return end

    ResetPreviewActor(actor, request, function()
        -- A nil item is a reset-only request.
        if not item then
            s.previewHearthstoneActive = nil
            return
        end
        if actor.SetSpellVisualKit and item.previewSpellVisualKitID then
            pcall(actor.SetSpellVisualKit, actor,
                item.previewSpellVisualKitID, false)
        end

        local function ScheduleCleanup()
            UI_Transmog:ScheduleTimer(PREVIEW_DURATION, function()
                if request ~= s.hearthstonePreviewRequest then return end
                FinishPreviewOnExistingActor(actor, request)
            end, "preview")
        end

        if actor.PlayAnimationKit and item.previewAnimationKitID then
            pcall(actor.PlayAnimationKit, actor, item.previewAnimationKitID, true)
            ScheduleCleanup()
        elseif actor.SetAnimation and item.previewAnimationID then
            -- Persistent spell kits can update the actor's animation at the
            -- end of their initialization frame. Apply explicit animations
            -- one frame later so the standard Hearthstone cast is retained.
            UI_Transmog:ScheduleTimer(0, function()
                if request ~= s.hearthstonePreviewRequest then return end
                pcall(actor.SetAnimation, actor, item.previewAnimationID, 0, 1, 0)
                ScheduleCleanup()
            end, "preview")
        else
            ScheduleCleanup()
        end
    end)
end

function UI_Transmog:PopulateHearthstoneList()
    local items, retry = {}, false
    local data = CurrentData(false)
    local selected = {}
    for _, itemID in ipairs(GetSelectedHearthstones(data, false)) do
        selected[itemID] = true
    end
    for _, entry in ipairs(ns.Constants.KNOWN_HEARTHSTONES) do
        local eligible = not entry.race or entry.race == ns.state.playerRace
        local owned = entry.baseItem or PlayerHasToy(entry.id)
        local name, icon
        if entry.baseItem then
            name, icon = C_Item.GetItemNameByID(entry.id),
                C_Item.GetItemIconByID(entry.id)
        else
            _, name, icon = C_ToyBox.GetToyInfo(entry.id)
        end
        if name and icon then
            if (owned and eligible or s.hearthstoneShowNotCollected)
                and (not s.hearthstoneCheckedOnly or selected[entry.id])
                and (s.hearthstoneSearchString == ""
                or name:lower():find(s.hearthstoneSearchString, 1, true)) then
                items[#items + 1] = {
                    id = entry.id,
                    name = name,
                    icon = icon,
                    baseItem = entry.baseItem,
                    isCollected = owned == true and eligible,
                    requiredRace = entry.race,
                    -- Mapped visual kits contain their own SpellVisualAnim.
                    -- previewAnimationID is only a fallback for unmapped spells.
                    previewAnimationID = entry.previewAnimationID,
                    previewAnimationKitID = entry.previewAnimationKitID,
                    previewSpellVisualKitID = entry.previewSpellVisualKitID,
                }
            end
        else
            C_Item.RequestLoadItemDataByID(entry.id)
            retry = true
        end
    end
    UI_Transmog._PagedShared.SortFavoritesFirst(
        items, "id", FitterSaved and FitterSaved.FavoriteHearthstones or {})
    return items, retry
end

local function SetupMacroButton()
    s.hearthstoneMacroButton = UI_Transmog._CreateMacroIconButton(s.hearthstoneFrame, 134414)
    s.hearthstoneMacroButton:SetPoint("TOPLEFT", s.hearthstoneFrame, "TOPLEFT", 50, -25)
    local label = s.hearthstoneFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", s.hearthstoneMacroButton, "RIGHT", 8, 0)
    label:SetText(L["Hearthstone Macro"])
    label:SetTextColor(1, .82, 0, 1)
    local function Pickup()
        Fitter:EnsureHearthstoneMacro()
        local index = GetMacroIndexByName("FitterHearthstone")
        if index and index > 0 then PickupMacro(index) end
    end
    s.hearthstoneMacroButton:SetScript("OnDragStart", Pickup)
    s.hearthstoneMacroButton:SetScript("OnClick", Pickup)
    s.hearthstoneMacroButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Hearthstone Macro"], 1, 1, 1)
        GameTooltip:AddLine(L["Drag or click to pick up the macro."], 1, .82, 0, true)
        GameTooltip:Show()
    end)
end

function UI_Transmog:InitializeHearthstonePaged()
    SetupMacroButton()
    local _, _, search = UI_Transmog._PagedShared.CreateHeader(s.hearthstoneFrame, L["Hearthstones"], function(text)
        s.hearthstoneSearchString = text
        UI_Transmog:RefreshHearthstoneList()
    end)
    search.Instructions:SetText(L["Search"])
    s.hearthstonePagedSearchBox = search
    s.hearthstonePagedSourcesDropdown =
        UI_Transmog._PagedShared.CreateFilterDropdown(
            s.hearthstoneFrame, search, {
                isDefault = function()
                    return not s.hearthstoneShowNotCollected
                        and not s.hearthstoneCheckedOnly
                end,
                default = function()
                    s.hearthstoneShowNotCollected = false
                    s.hearthstoneCheckedOnly = false
                    UI_Transmog:RefreshHearthstoneList()
                end,
                setup = function(_, rootDescription)
                    UI_Transmog._PagedShared.AddSelectedCheckbox(
                        rootDescription, s, "hearthstoneCheckedOnly",
                        function()
                            UI_Transmog:RefreshHearthstoneList()
                        end)
                    rootDescription:CreateCheckbox(L["Not Collected"], function()
                        return s.hearthstoneShowNotCollected
                    end, function()
                        s.hearthstoneShowNotCollected =
                            not s.hearthstoneShowNotCollected
                        UI_Transmog:RefreshHearthstoneList()
                    end)
                end,
            })

    s.hearthstoneModelFrames = {}
    for i = 1, PAGE_SIZE do
        local container =
            UI_Transmog._PagedShared.CreateCollectionEntryButton(
                s.hearthstoneFrame)
        container:SetPoint(
            "TOPLEFT", s.hearthstoneFrame, "TOPLEFT",
            BUTTON_START_X, BUTTON_START_Y)
        container:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local favoriteStar =
            UI_Transmog._PagedShared.CreateFavoriteStar(container)
        favoriteStar:ClearAllPoints()
        favoriteStar:SetPoint("CENTER", container.IconFrame, "TOPLEFT", 3, -3)

        local frame = {
            container = container,
            favoriteStar = favoriteStar,
        }
        s.hearthstoneModelFrames[i] = frame

        local function ToggleSelection()
            local item = frame.item
            local data, outfitID = CurrentData(true)
            if not data or not item then return end
            if not item.isCollected then
                return
            end
            local selected = GetSelectedHearthstones(data, true)
            local wasSelected = tContains(selected, item.id)
            if wasSelected then tDeleteItem(selected, item.id) else table.insert(selected, item.id) end
            if UI_Transmog:GetActiveOutfitID() == outfitID
                and not InCombatLockdown() then
                Fitter:UpdateHearthstoneMacro()
            end
            if s.hearthstoneCheckedOnly then
                UI_Transmog:RefreshHearthstoneList()
            else
                UI_Transmog:UpdateHearthstonePageDisplay()
            end
            UI_Transmog:UpdateMountIcons()
            if wasSelected then
                UI_Transmog:PreviewHearthstoneCast(nil)
            else
                UI_Transmog:PreviewHearthstoneCast(item)
            end
            PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
        end

        container:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                if not frame.item
                    or not MenuUtil or not MenuUtil.CreateContextMenu then
                    return
                end
                local item = frame.item
                MenuUtil.CreateContextMenu(self, function(_, rootDescription)
                    if item.isCollected then
                        local favorite =
                            UI_Transmog._PagedShared.IsHearthstoneFavorite(item.id)
                        rootDescription:CreateButton(
                            favorite and L["Remove Favorite"] or L["Set Favorite"],
                            function()
                                UI_Transmog._PagedShared.SetFavorite(
                                    "FavoriteHearthstones", item.id, not favorite)
                                UI_Transmog:RefreshHearthstoneList()
                            end)
                        rootDescription:CreateDivider()
                    end
                    rootDescription:CreateButton(L["Preview"], function()
                        UI_Transmog:PreviewHearthstoneCast(item)
                    end)
                end)
                return
            end
            ToggleSelection()
        end)
        container:SetScript("OnEnter", function(self)
            if not frame.item then return end
            self:ShowCollectionHover()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if frame.item.baseItem then
                GameTooltip:SetItemByID(frame.item.id)
            else
                GameTooltip:SetToyByItemID(frame.item.id)
            end
            if not frame.item.isCollected then
                GameTooltip:AddLine(
                    "You have not collected this Hearthstone.",
                    .6, .6, .6, true)
                if frame.item.requiredRace then
                    GameTooltip:AddLine(
                        "Requires " .. frame.item.requiredRace .. ".",
                        .8, .2, .2, true)
                end
            end
            GameTooltip:Show()
        end)
        container:SetScript("OnLeave", function(self)
            self:HideCollectionHover()
            GameTooltip:Hide()
        end)
    end
    LayoutHearthstoneButtons()
    s.hearthstoneFrame:HookScript(
        "OnSizeChanged", LayoutHearthstoneButtons)
    s.hearthstonePageText, s.hearthstonePrevButton, s.hearthstoneNextButton =
        UI_Transmog._PagedShared.CreateNavButtons(s.hearthstoneFrame,
            function() UI_Transmog:HearthstonePagePrev() end,
            function() UI_Transmog:HearthstonePageNext() end)
end

function UI_Transmog:ShowHearthstonePaged()
    if not s.hearthstonePagedInitialized then
        self:InitializeHearthstonePaged()
        s.hearthstonePagedInitialized = true
    end
    self:_ShowPagedFrame(s.hearthstoneFrame, "UpdateHearthstones")
end

function UI_Transmog:RefreshHearthstoneList()
    if not s.hearthstoneModelFrames then return end
    local retry
    s.hearthstonePagedItems, retry = self:PopulateHearthstoneList()
    s.hearthstoneTotalPages = math.max(1, math.ceil(#s.hearthstonePagedItems / PAGE_SIZE))
    s.hearthstoneCurrentPage = math.min(s.hearthstoneCurrentPage, s.hearthstoneTotalPages)
    self:UpdateHearthstonePageDisplay()
    if retry and not s.hearthstoneRetryPending then
        s.hearthstoneRetryPending = true
        UI_Transmog:ScheduleTimer(.5, function()
            s.hearthstoneRetryPending = false
            if s.hearthstoneFrame and s.hearthstoneFrame:IsShown() then
                UI_Transmog:RefreshHearthstoneList()
            end
        end, "hearthstone-retry")
    end
end
function UI_Transmog:UpdateHearthstones()
    local data = CurrentData(true)
    if not data then return end
    self:RefreshHearthstoneList()
end

function UI_Transmog:UpdateHearthstonePageDisplay()
    if not s.hearthstoneModelFrames then return end
    local data = CurrentData(false)
    local selected = {}
    for _, itemID in ipairs(GetSelectedHearthstones(data, false)) do
        selected[itemID] = true
    end
    local start = (s.hearthstoneCurrentPage - 1) * PAGE_SIZE
    for i, frame in ipairs(s.hearthstoneModelFrames) do
        local item = s.hearthstonePagedItems[start + i]
        frame.item = item
        frame.container:SetShown(item ~= nil)
        if item then
            frame.isSelected = selected[item.id] == true
            frame.container:SetText(item.name)
            frame.container.IconFrame.Icon:SetTexture(item.icon)
            frame.container.IconFrame.Icon:SetDesaturated(
                not item.isCollected)
            frame.container.IconFrame.Icon:SetAlpha(
                item.isCollected and 1 or .45)
            if frame.container.CollectionBorder then
                frame.container.CollectionBorder:SetDesaturated(
                    not item.isCollected)
                frame.container.CollectionBorder:SetAlpha(
                    item.isCollected and 1 or .45)
            end
            if frame.container.StateTexture then
                frame.container.StateTexture:SetShown(frame.isSelected)
            end
            local fontString = frame.container:GetFontString()
            if fontString then
                fontString:SetTextColor(
                    item.isCollected and 1 or .5,
                    item.isCollected and .82 or .5,
                    item.isCollected and 0 or .5)
            end
            frame.favoriteStar:SetShown(
                item.isCollected
                and UI_Transmog._PagedShared.IsHearthstoneFavorite(item.id))
        else
            frame.isSelected = false
            frame.container:SetText("")
            frame.container.IconFrame.Icon:SetTexture(nil)
            frame.container.IconFrame.Icon:SetDesaturated(false)
            frame.container.IconFrame.Icon:SetAlpha(1)
            if frame.container.CollectionBorder then
                frame.container.CollectionBorder:SetDesaturated(false)
                frame.container.CollectionBorder:SetAlpha(1)
            end
            if frame.container.StateTexture then
                frame.container.StateTexture:Hide()
            end
            frame.favoriteStar:Hide()
            frame.container:HideCollectionHover()
            if GameTooltip:GetOwner() == frame.container then
                GameTooltip:Hide()
            end
        end
    end
    s.hearthstonePageText:SetText(string.format(
        L["Page %d/%d"], s.hearthstoneCurrentPage, s.hearthstoneTotalPages))
    s.hearthstonePrevButton:SetEnabled(s.hearthstoneCurrentPage > 1)
    s.hearthstoneNextButton:SetEnabled(s.hearthstoneCurrentPage < s.hearthstoneTotalPages)
end

function UI_Transmog:HearthstonePagePrev()
    if s.hearthstoneCurrentPage > 1 then
        s.hearthstoneCurrentPage = s.hearthstoneCurrentPage - 1
        self:UpdateHearthstonePageDisplay()
    end
end

function UI_Transmog:HearthstonePageNext()
    if s.hearthstoneCurrentPage < s.hearthstoneTotalPages then
        s.hearthstoneCurrentPage = s.hearthstoneCurrentPage + 1
        self:UpdateHearthstonePageDisplay()
    end
end
