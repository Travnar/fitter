-- Paged Toy selector. Keeps the original Outfit#.Toys array.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter

local PAGE_SIZE = 30
local BUTTON_START_X = 30
local BUTTON_START_Y = -120
local BUTTON_GAP_X = 14
local BUTTON_BOTTOM_PADDING = 65

local function LayoutButtons()
    if not s.toyButtons or not s.toyButtons[1] then return end
    local first = s.toyButtons[1]
    local buttonHeight = first:GetHeight()
    local availableWidth = s.toyFrame:GetWidth() - (BUTTON_START_X * 2)
    local columnWidth = availableWidth / 3
    local buttonWidth = math.max(100, columnWidth - BUTTON_GAP_X)
    local stepX = columnWidth
    local buttonInset = BUTTON_GAP_X / 2
    local rowCount = math.ceil(#s.toyButtons / 3)
    local availableHeight = math.max(buttonHeight,
        s.toyFrame:GetHeight() + BUTTON_START_Y - BUTTON_BOTTOM_PADDING)
    local stepY = rowCount > 1
        and (availableHeight - buttonHeight) / (rowCount - 1)
        or 0
    for i, button in ipairs(s.toyButtons) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        button:SetWidth(buttonWidth)
        local fontString = button:GetFontString()
        if fontString then fontString:SetWidth(math.max(buttonWidth - 58, 20)) end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", s.toyFrame, "TOPLEFT",
            BUTTON_START_X + buttonInset + col * stepX,
            BUTTON_START_Y - row * stepY)
    end
end

local function CurrentData(create)
    local id = UI_Transmog:GetViewedOutfitID()
    if not id or id == 0 then return nil end
    if create and not FitterCharacterSaved["Outfit"..id] then Fitter:CreateEmptyOutfit(id) end
    return FitterCharacterSaved["Outfit"..id], id
end

function UI_Transmog:PopulateToyList()
    local items, retry = {}, false
    local data = CurrentData(false)
    local selected = {}
    for _, toyID in ipairs(data and data.Toys or {}) do
        selected[toyID] = true
    end
    for _, entry in ipairs(ns.Toy.GetCatalog()) do
        local isCollected = PlayerHasToy(entry.id)
        if (isCollected or s.toyShowNotCollected)
            and (not s.toyAddedOnly or entry.custom == true)
            and (not s.toyCheckedOnly or selected[entry.id]) then
            local _, name, icon = C_ToyBox.GetToyInfo(entry.id)
            if name and icon then
                if s.toySearchString == "" or name:lower():find(s.toySearchString, 1, true) then
                    items[#items + 1] = {
                        id = entry.id, name = name, icon = icon,
                        isCollected = isCollected == true,
                        custom = entry.custom == true,
                    }
                end
            else
                C_Item.RequestLoadItemDataByID(entry.id)
                retry = true
            end
        end
    end
    UI_Transmog._PagedShared.SortFavoritesFirst(
        items, "id", FitterSaved and FitterSaved.FavoriteToys or {})
    return items, retry
end

local function ToggleToy(button)
    if InCombatLockdown() then
        s.toyRefreshAfterCombat = true
        return
    end
    local data, outfitID = CurrentData(true)
    if not data or not button.item or not button.item.isCollected then return end
    data.Toys = data.Toys or {}
    local isSelected
    if tContains(data.Toys, button.item.id) then
        tDeleteItem(data.Toys, button.item.id)
        isSelected = false
    else
        table.insert(data.Toys, button.item.id)
        isSelected = true
    end
    -- Update the clicked card before rebuilding macros. Its hover textures
    -- were chosen on mouse-enter using the previous selection state.
    if button.StateTexture then
        button.StateTexture:SetShown(isSelected)
    end
    button:HideCollectionHover()
    if button:IsMouseOver() then
        button:ShowCollectionHover()
    end
    if UI_Transmog:GetActiveOutfitID() == outfitID and not InCombatLockdown() then
        Fitter:UpdateMacroForCurrentState()
    end
    if s.toyCheckedOnly then
        UI_Transmog:RefreshToyList()
    else
        UI_Transmog:UpdateToyPageDisplay()
    end
    UI_Transmog:UpdateMountIcons()
    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
end

local function ConfigureToyUse(overlay)
    if InCombatLockdown() then return false end
    local button, data, outfitID = overlay.owner, CurrentData(false)
    if not button.item or not data
        or UI_Transmog:GetActiveOutfitID() ~= outfitID then
        overlay:SetAttribute("type", nil)
        overlay:SetAttribute("macrotext", "")
        return true
    end
    local selected = tContains(data.Toys or {}, button.item.id)
    if not selected and not ns.Toy.IsToyActive(button.item.id) and not ns.Toy.IsToyOnCooldown(button.item.id) then
        overlay:SetAttribute("type", "macro")
        overlay:SetAttribute("macrotext", "/use item:"..button.item.id)
    elseif selected and ns.Toy.IsToyActive(button.item.id) then
        local spellName = GetItemSpell(button.item.id)
        overlay:SetAttribute("type", spellName and "macro" or nil)
        overlay:SetAttribute("macrotext", spellName and ("/cancelaura "..spellName) or "")
    else
        overlay:SetAttribute("type", nil)
        overlay:SetAttribute("macrotext", "")
    end
    return true
end

local function ShowToyContextMenu(owner)
    local item = owner.item
    if not item or (not item.isCollected and not item.custom)
        or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        if item.isCollected then
            local favorite = UI_Transmog._PagedShared.IsToyFavorite(item.id)
            root:CreateButton(favorite and L["Remove Favorite"] or L["Set Favorite"], function()
                UI_Transmog._PagedShared.SetFavorite(
                    "FavoriteToys", item.id, not favorite)
                UI_Transmog:RefreshToyList()
            end)
        end
        if item.custom then
            root:CreateButton(L["Remove Added Toy"], function()
                tDeleteItem(FitterSaved.CustomToys, item.id)
                if FitterSaved.FavoriteToys then
                    FitterSaved.FavoriteToys[item.id] = nil
                end
                for key, data in pairs(FitterCharacterSaved or {}) do
                    if type(key) == "string" and key:match("^Outfit%d+$")
                        and type(data) == "table" and type(data.Toys) == "table" then
                        tDeleteItem(data.Toys, item.id)
                    end
                end
                UI_Transmog:RefreshToyList()
                UI_Transmog:UpdateMountIcons()
                Fitter:UpdateMacroForCurrentState()
            end)
        end
    end)
end

local function AddCustomToy(toyID)
    toyID = tonumber(toyID)
    if not toyID or toyID < 1 or toyID ~= math.floor(toyID) then
        UIErrorsFrame:AddMessage("Enter a valid numeric toy item ID.", 1, .2, .2)
        return false
    end
    if ns.Toy.IsCatalogToy(toyID) then
        UIErrorsFrame:AddMessage("That toy is already in the list.", 1, .2, .2)
        return false
    end
    local _, name, icon = C_ToyBox.GetToyInfo(toyID)
    if not name or not icon then return nil end
    FitterSaved.CustomToys[#FitterSaved.CustomToys + 1] = toyID
    s.toySearchString = ""
    if s.toyPagedSearchBox then s.toyPagedSearchBox:SetText("") end
    UI_Transmog:RefreshToyList()
    return true
end

local function FinishLoadingCustomToy(toyID, attemptsRemaining, loadToken)
    if s.customToyLoadToken ~= loadToken then return end
    local result = AddCustomToy(toyID)
    if result == true then
        StaticPopup_Hide("FITTER_ADD_CUSTOM_TOY")
        return
    end
    if result == false then return end
    if attemptsRemaining > 0 then
        C_Timer.After(.1, function()
            FinishLoadingCustomToy(toyID, attemptsRemaining - 1, loadToken)
        end)
        return
    end
    UIErrorsFrame:AddMessage(
        "That item ID is not a toy, or its data could not be loaded.",
        1, .2, .2)
end

local function ShowAddToyPopup()
    StaticPopupDialogs.FITTER_ADD_CUSTOM_TOY = StaticPopupDialogs.FITTER_ADD_CUSTOM_TOY or {
        text = "Enter a toy item ID",
        button1 = ADD,
        button2 = CANCEL,
        hasEditBox = true,
        editBoxWidth = 180,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(self)
            local editBox = self.EditBox or self.editBox
            editBox:SetText("")
            editBox:SetNumeric(true)
            editBox:SetMaxLetters(10)
            editBox:SetFocus()
            editBox:HighlightText()
        end,
        OnAccept = function(self)
            local editBox = self.EditBox or self.editBox
            local input = editBox:GetText()
            local toyID = tonumber(input)
            s.customToyLoadToken = (s.customToyLoadToken or 0) + 1
            local loadToken = s.customToyLoadToken
            local result = AddCustomToy(toyID)
            if result == true then
                return
            end
            if result == false then return true end

            C_Item.RequestLoadItemDataByID(toyID)
            C_Timer.After(.1, function()
                FinishLoadingCustomToy(toyID, 9, loadToken)
            end)
            -- A true return tells StaticPopup to remain visible. The async
            -- validation path hides it after the toy is successfully added.
            return true
        end,
        OnCancel = function()
            s.customToyLoadToken = (s.customToyLoadToken or 0) + 1
        end,
        EditBoxOnEnterPressed = function(self)
            local dialog = self:GetParent()
            local accept = dialog.Buttons and dialog.Buttons[1]
                or dialog.button1
            if accept then accept:Click() end
        end,
    }
    StaticPopup_Show("FITTER_ADD_CUSTOM_TOY")
end

function UI_Transmog:InitializeToyPaged()
    if InCombatLockdown() then
        s.toyRefreshAfterCombat = true
        return false
    end
    local _, _, search = UI_Transmog._PagedShared.CreateHeader(s.toyFrame, L["Cosmetic Toys"], function(text)
        s.toySearchString = text
        UI_Transmog:RefreshToyList()
    end)
    search.Instructions:SetText(L["Search"])
    s.toyPagedSearchBox = search
    s.toyPagedSourcesDropdown =
        UI_Transmog._PagedShared.CreateFilterDropdown(s.toyFrame, search, {
            isDefault = function()
                return not s.toyShowNotCollected and not s.toyCheckedOnly
                    and not s.toyAddedOnly
            end,
            default = function()
                s.toyShowNotCollected = false
                s.toyCheckedOnly = false
                s.toyAddedOnly = false
                UI_Transmog:RefreshToyList()
            end,
            setup = function(_, rootDescription)
                UI_Transmog._PagedShared.AddSelectedCheckbox(
                    rootDescription, s, "toyCheckedOnly",
                    function() UI_Transmog:RefreshToyList() end)
                rootDescription:CreateCheckbox(L["Not Collected"], function()
                    return s.toyShowNotCollected
                end, function()
                    s.toyShowNotCollected = not s.toyShowNotCollected
                    UI_Transmog:RefreshToyList()
                end)
                rootDescription:CreateCheckbox(L["Added Toys"], function()
                    return s.toyAddedOnly
                end, function()
                    s.toyAddedOnly = not s.toyAddedOnly
                    UI_Transmog:RefreshToyList()
                end)
            end,
        })

    local add = CreateFrame("Button", nil, s.toyFrame, "UIPanelButtonTemplate")
    add:SetSize(130, 26)
    add:SetPoint("TOPLEFT", s.toyFrame, "TOPLEFT", 50, -24)
    add:SetText(L["Add Toy By ID"])
    add:SetScript("OnClick", ShowAddToyPopup)
    add:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Add Toy By ID"], 1, .82, 0)
        GameTooltip:AddLine(
            L["Add a toy to Fitter's cosmetic toy list using its item ID."],
            1, 1, 1, true)
        GameTooltip:AddLine(
            L["Valid behavior is not guaranteed."],
            .6, .6, .6, true)
        GameTooltip:Show()
    end)
    add:SetScript("OnLeave", GameTooltip_Hide)
    s.toyAddButton = add

    for i = 1, PAGE_SIZE do
        local button =
            UI_Transmog._PagedShared.CreateCollectionEntryButton(s.toyFrame)
        button:SetPoint("TOPLEFT", s.toyFrame, "TOPLEFT", BUTTON_START_X, BUTTON_START_Y)
        local fontString = button:GetFontString()
        if fontString then
            fontString:SetWordWrap(true)
            if fontString.SetNonSpaceWrap then fontString:SetNonSpaceWrap(true) end
            if fontString.SetMaxLines then fontString:SetMaxLines(3) end
        end
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                ShowToyContextMenu(self)
            else
                ToggleToy(self)
            end
        end)
        local favoriteStar =
            UI_Transmog._PagedShared.CreateFavoriteStar(button)
        favoriteStar:ClearAllPoints()
        favoriteStar:SetPoint("CENTER", button.IconFrame, "TOPLEFT", 3, -3)
        button.favoriteStar = favoriteStar
        button:HookScript("OnEnter", function(self)
            if not self.item then return end
            self:ShowCollectionHover()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetToyByItemID(self.item.id)
            if self.item.isCollected then
                GameTooltip:AddLine(L["Right-click for favorite options."],
                    0.5, 0.8, 1)
            else
                GameTooltip:AddLine(L["You have not collected this toy."],
                    .6, .6, .6, true)
            end
            if self.item.custom then
                GameTooltip:AddLine(L["Right-click to remove this custom toy."],
                    .5, .8, 1, true)
            end
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function(self)
            self:HideCollectionHover()
            GameTooltip:Hide()
        end)
        local overlay = CreateFrame("Button", nil, button, "FitterToyButtonTemplate")
        overlay:SetAllPoints(button)
        overlay:SetFrameLevel(button:GetFrameLevel() + 5)
        overlay.owner = button
        overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        -- Explicitly make button 2 non-secure so opening the favorite menu
        -- can never use or cancel the toy configured for button 1.
        overlay:SetAttribute("type2", "")
        overlay:SetScript("PostClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                ShowToyContextMenu(self.owner)
            else
                ToggleToy(self.owner)
            end
        end)
        overlay:SetScript("OnEnter", function(self)
            local item = self.owner.item
            if not item then return end
            self.owner:ShowCollectionHover()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetToyByItemID(item.id)
            if item.isCollected then
                GameTooltip:AddLine(L["Right-click for favorite options."],
                    0.5, 0.8, 1)
            else
                GameTooltip:AddLine(L["You have not collected this toy."],
                    .6, .6, .6, true)
            end
            if item.custom then
                GameTooltip:AddLine(L["Right-click to remove this custom toy."],
                    .5, .8, 1, true)
            end
            GameTooltip:Show()
        end)
        overlay:SetScript("OnLeave", function(self)
            self.owner:HideCollectionHover()
            GameTooltip:Hide()
        end)
        button.secureOverlay = overlay
        s.toyButtons = s.toyButtons or {}
        s.toyButtons[i] = button
    end
    LayoutButtons()
    s.toyFrame:HookScript("OnSizeChanged", LayoutButtons)
    s.toyPageText, s.toyPrevButton, s.toyNextButton =
        UI_Transmog._PagedShared.CreateNavButtons(s.toyFrame,
            function() UI_Transmog:ToyPagePrev() end,
            function() UI_Transmog:ToyPageNext() end)
end

function UI_Transmog:ShowToyPaged()
    if not s.toyPagedInitialized then
        s.toyPagedInitialized = self:InitializeToyPaged() ~= false
    end
    if not s.toyPagedInitialized then return end
    self:_ShowPagedFrame(s.toyFrame, "UpdateToys")
end

function UI_Transmog:RefreshToyList()
    if not s.toyButtons then return end
    if InCombatLockdown() then
        s.toyRefreshAfterCombat = true
        return
    end
    local retry
    s.toyPagedItems, retry = self:PopulateToyList()
    s.toyTotalPages = math.max(1, math.ceil(#s.toyPagedItems / PAGE_SIZE))
    s.toyCurrentPage = math.min(s.toyCurrentPage, s.toyTotalPages)
    self:UpdateToyPageDisplay()
    if retry and not s.toyRetryPending then
        s.toyRetryPending = true
        UI_Transmog:ScheduleTimer(.5, function()
            s.toyRetryPending = false
            if s.toyFrame and s.toyFrame:IsShown() then UI_Transmog:RefreshToyList() end
        end, "toy-retry")
    end
end

function UI_Transmog:UpdateToys()
    if not CurrentData(true) then return end
    self:RefreshToyList()
end

function UI_Transmog:UpdateToyPageDisplay()
    if not s.toyButtons then return end
    if InCombatLockdown() then
        s.toyRefreshAfterCombat = true
        return
    end
    local data = CurrentData(false)
    local selected = {}
    for _, id in ipairs(data and data.Toys or {}) do selected[id] = true end
    local start = (s.toyCurrentPage - 1) * PAGE_SIZE
    for i, button in ipairs(s.toyButtons) do
        local item = s.toyPagedItems[start + i]
        button.item = item
        button:SetShown(item ~= nil)
        if item then
            button:SetText(item.name)
            button.IconFrame.Icon:SetTexture(item.icon)
            button.IconFrame.Icon:SetDesaturated(not item.isCollected)
            button.IconFrame.Icon:SetAlpha(item.isCollected and 1 or .45)
            button.CollectionBorder:SetDesaturated(not item.isCollected)
            button.CollectionBorder:SetAlpha(item.isCollected and 1 or .45)
            local fontString = button:GetFontString()
            if fontString then
                if item.custom then
                    local red, green, blue
                    if ACCOUNT_WIDE_FONT_COLOR
                        and ACCOUNT_WIDE_FONT_COLOR.GetRGB then
                        red, green, blue = ACCOUNT_WIDE_FONT_COLOR:GetRGB()
                    else
                        red, green, blue = 0, .8, 1
                    end
                    if item.isCollected then
                        fontString:SetTextColor(red, green, blue)
                    else
                        local gray = (red + green + blue) / 3
                        local saturation = .35
                        fontString:SetTextColor(
                            gray + (red - gray) * saturation,
                            gray + (green - gray) * saturation,
                            gray + (blue - gray) * saturation)
                    end
                else
                    fontString:SetTextColor(
                        item.isCollected and 1 or .5,
                        item.isCollected and .82 or .5,
                        item.isCollected and 0 or .5)
                end
            end
            if button.StateTexture then button.StateTexture:SetShown(selected[item.id] == true) end
            button.favoriteStar:SetShown(
                item.isCollected
                and UI_Transmog._PagedShared.IsToyFavorite(item.id))
            ConfigureToyUse(button.secureOverlay)
            button.secureOverlay:SetShown(item.isCollected
                and FitterSaved and FitterSaved.ApplyToyOnSelect)
        else
            button:SetText("")
            button.IconFrame.Icon:SetTexture(nil)
            button.IconFrame.Icon:SetDesaturated(false)
            button.IconFrame.Icon:SetAlpha(1)
            button.CollectionBorder:SetDesaturated(false)
            button.CollectionBorder:SetAlpha(1)
            if button.StateTexture then button.StateTexture:Hide() end
            button.favoriteStar:Hide()
            button:HideCollectionHover()
            ConfigureToyUse(button.secureOverlay)
            button.secureOverlay:Hide()
            if GameTooltip:GetOwner() == button
                or GameTooltip:GetOwner() == button.secureOverlay then
                GameTooltip:Hide()
            end
        end
    end
    s.toyPageText:SetText(string.format(
        L["Page %d/%d"], s.toyCurrentPage, s.toyTotalPages))
    s.toyPrevButton:SetEnabled(s.toyCurrentPage > 1)
    s.toyNextButton:SetEnabled(s.toyCurrentPage < s.toyTotalPages)
end

function UI_Transmog:RefreshCombatDeferredToyUI()
    if s.toyFrameShownAfterCombat ~= nil then
        local shown = s.toyFrameShownAfterCombat
        s.toyFrameShownAfterCombat = nil
        if s.toyFrame then s.toyFrame:SetShown(shown) end
    end
    local visible = s.toyFrame and s.toyFrame:IsShown()
    if not s.toyRefreshAfterCombat and not visible then return end
    s.toyRefreshAfterCombat = false
    if visible and not s.toyPagedInitialized then
        s.toyPagedInitialized = self:InitializeToyPaged() ~= false
        if not s.toyPagedInitialized then return end
    end
    if visible then
        self:RefreshToyList()
    elseif s.toyButtons then
        self:UpdateToyPageDisplay()
    end
end

function UI_Transmog:ToyPagePrev()
    if s.toyCurrentPage > 1 then
        s.toyCurrentPage = s.toyCurrentPage - 1
        self:UpdateToyPageDisplay()
    end
end

function UI_Transmog:ToyPageNext()
    if s.toyCurrentPage < s.toyTotalPages then
        s.toyCurrentPage = s.toyCurrentPage + 1
        self:UpdateToyPageDisplay()
    end
end
