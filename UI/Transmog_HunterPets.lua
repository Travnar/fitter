local addonName, ns = ...
local L = ns.L

local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local PAGE_SIZE = 20

local function CurrentData()
    local outfitID = UI_Transmog:GetViewedOutfitID()
    if not outfitID then return nil end
    ns.Fitter:CreateEmptyOutfit(outfitID)
    return FitterCharacterSaved["Outfit" .. outfitID], outfitID
end

local function ApplySelection(mode, info)
    local data, outfitID = CurrentData()
    if not data then return end
    local selections = ns.HunterPet.EnsureSelections(data)
    local previewInfo
    if mode == "pet" and info and info.petNumber then
        data.HunterPetDisabled = false
        data.HunterPetRandom = false
        local number, found = tonumber(info.petNumber), nil
        for index, selectedNumber in ipairs(selections) do
            if tonumber(selectedNumber) == number then found = index; break end
        end
        if found then
            table.remove(selections, found)
            data.HunterPetMetadata[number] = nil
        else
            selections[#selections + 1] = number
            data.HunterPetMetadata[number] = {
                petNumber = number,
                activeSlot = info.activeSlot,
                familyName = info.familyName,
                name = info.name,
                displayID = info.displayID,
                icon = info.icon,
            }
            previewInfo = info
        end
    else
        wipe(selections)
        wipe(data.HunterPetMetadata)
        data.HunterPetDisabled = mode == "disabled"
        data.HunterPetRandom = mode == "random"
    end
    local firstNumber = selections[1]
    local first = firstNumber and data.HunterPetMetadata[firstNumber] or nil
    data.HunterPetSlot = first and first.activeSlot or nil
    data.HunterPetNumber = firstNumber
    data.HunterPetFamilyName = first and first.familyName or nil
    data.HunterPetName = first and first.name or nil
    data.HunterPetDisplayID = first and first.displayID or nil
    data.HunterPetIcon = first and first.icon or nil
    if not previewInfo and #selections > 0 then
        previewInfo = ns.HunterPet.GetSelectedPet(data)
    end
    wipe(ns.state.hunterPetSelectionRolls or {})
    wipe(ns.state.hunterPetFallbacks or {})
    ns.state.outfitUpdateResolvedID = outfitID
    UI_Transmog:RefreshHunterPets()
    UI_Transmog:UpdateMountIcons()
    if previewInfo and previewInfo.displayID and previewInfo.displayID > 0 then
        UI_Transmog:PreviewSelectedPet(nil, previewInfo.displayID,
            "hunter:" .. tostring(previewInfo.petNumber or previewInfo.displayID))
    else
        UI_Transmog:ClearMountPreview()
    end
    if not InCombatLockdown() then
        ns.Fitter:UpdateOutfitUpdateMacro(outfitID)
        ns.Macro.UpdateMacroForMount(ns.state.nextMountToSummon, outfitID)
    elseif ns.MarkMacroRefreshPending then
        ns.MarkMacroRefreshPending()
    end
    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
end

function UI_Transmog:ShowHunterPets()
    if not ns.HunterPet.IsAvailable() then return end
    if not s.hunterPetInitialized then
        self:InitializeHunterPets()
        s.hunterPetInitialized = true
    end
    self:_ShowPagedFrame(s.hunterPetFrame, "RefreshHunterPets")
    local data = CurrentData()
    local selected = data and ns.HunterPet.GetSelectedPet(data)
    local displayID = selected and selected.displayID
        or (data and data.HunterPetDisplayID)
    if displayID and displayID > 0 then
        self:PreviewSelectedPet(nil, displayID,
            "hunter:" .. tostring(data.HunterPetNumber or displayID))
    else
        self:ClearMountPreview()
    end
end

local function CreatePetCard(parent, visualIndex)
    local width, height, spacing = 114, 146, 3
    local col = (visualIndex - 1) % 5
    local row = math.floor((visualIndex - 1) / 5)
    local gridStartX = -((5 * width + 4 * spacing - width) / 2)
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(width, height)
    card:SetPoint("TOP", parent, "TOP",
        gridStartX + col * (width + spacing), -175 - row * (height + spacing))
    card:SetClipsChildren(true)

    local black = card:CreateTexture(nil, "BACKGROUND", nil, -1)
    black:SetColorTexture(0, 0, 0, 1)
    black:SetPoint("TOPLEFT", 4, -4)
    black:SetPoint("BOTTOMRIGHT", -4, 4)
    local border = card:CreateTexture(nil, "ARTWORK")
    border:SetAtlas("transmog-setCard-default", true)
    border:SetAllPoints()
    local model = CreateFrame("PlayerModel", nil, card)
    model:SetPoint("TOPLEFT", 8, -8)
    model:SetPoint("BOTTOMRIGHT", -8, 8)
    model:SetClipsChildren(true)
    model:SetCamDistanceScale(.7)
    local hover = card:CreateTexture(nil, "OVERLAY")
    hover:SetAtlas("transmog-setCard-default", true)
    hover:SetAllPoints()
    hover:SetVertexColor(1, .9, .5, .75)
    hover:SetBlendMode("ADD")
    hover:Hide()
    local uncollectedGlow = card:CreateTexture(nil, "OVERLAY", nil, 1)
    uncollectedGlow:SetAtlas("transmog-setCard-default", true)
    uncollectedGlow:SetAllPoints(true)
    uncollectedGlow:SetDesaturated(true)
    uncollectedGlow:SetVertexColor(.65, .72, .78, .55)
    uncollectedGlow:SetBlendMode("ADD")
    uncollectedGlow:Hide()
    local favoriteStar = UI_Transmog._PagedShared.CreateFavoriteStar(card)
    card.model, card.border = model, border
    card.hoverHighlight = hover
    card.uncollectedGlow = uncollectedGlow
    card.favoriteStar = favoriteStar
    local function UpdateHoverStyle(self)
        hover:SetAtlas(self.selected
            and "transmog-wardrobe-border-current-transmogged"
            or "transmog-setCard-default", true)
        if self.selected then
            hover:SetVertexColor(1, 1, 1, .5)
        else
            hover:SetVertexColor(1, .9, .5, .75)
        end
    end
    card.UpdateHoverStyle = UpdateHoverStyle
    card:SetScript("OnEnter", function(self)
        UpdateHoverStyle(self)
        hover:Show()
        local info = self.petInfo
        if not info then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(info.name or L["Hunter Pet"], 1, .82, 0)
        if not info.isActive then
            GameTooltip:AddLine(L["In Stable"], .7, .7, .7)
        end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() hover:Hide(); GameTooltip:Hide() end)
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    card:SetScript("OnClick", function(self, mouseButton)
        local info = self.petInfo
        if not info then return end
        if mouseButton == "RightButton" then
            if not MenuUtil or not MenuUtil.CreateContextMenu then return end
            MenuUtil.CreateContextMenu(self, function(_, rootDescription)
                local petNumber = tonumber(info.petNumber)
                if petNumber then
                    local favorite = UI_Transmog._PagedShared
                        .IsHunterPetFavorite(petNumber)
                    rootDescription:CreateButton(
                        favorite and L["Remove Favorite"] or L["Set Favorite"],
                        function()
                            UI_Transmog._PagedShared.SetFavorite(
                                "FavoriteHunterPets", petNumber, not favorite)
                            UI_Transmog:RefreshHunterPets()
                        end)
                    rootDescription:CreateDivider()
                end
                rootDescription:CreateButton(L["Preview"], function()
                    UI_Transmog:PreviewSelectedPet(nil, info.displayID,
                        "hunter:" .. tostring(info.petNumber or info.displayID))
                end)
            end)
            return
        end
        ApplySelection("pet", info)
    end)
    return card
end

function UI_Transmog:InitializeHunterPets()
    local _, _, search = UI_Transmog._PagedShared.CreateHeader(
        s.hunterPetFrame, "Hunter Pets", function(text)
            s.hunterPetSearchString = text
            s.hunterPetCurrentPage = 1
            UI_Transmog:RefreshHunterPets()
        end)
    s.hunterPetSearchBox = search
    s.hunterPetFilterDropdown = UI_Transmog._PagedShared.CreateFilterDropdown(
        s.hunterPetFrame, search, {
            isDefault = function()
                return not s.hunterPetCheckedOnly
                    and not s.hunterPetShowActive
                    and not s.hunterPetShowStabled
            end,
            default = function()
                s.hunterPetCheckedOnly = false
                s.hunterPetShowActive = false
                s.hunterPetShowStabled = false
                s.hunterPetCurrentPage = 1
                UI_Transmog:RefreshHunterPets()
            end,
            setup = function(_, root)
                local refresh = function()
                    s.hunterPetCurrentPage = 1
                    UI_Transmog:RefreshHunterPets()
                end
                UI_Transmog._PagedShared.AddSelectedCheckbox(
                    root, s, "hunterPetCheckedOnly", refresh)
                root:CreateCheckbox(L["Active"], function()
                    return s.hunterPetShowActive
                end, function()
                    s.hunterPetShowActive = not s.hunterPetShowActive
                    refresh()
                end)
                root:CreateCheckbox(L["Stabled"], function()
                    return s.hunterPetShowStabled
                end, function()
                    s.hunterPetShowStabled = not s.hunterPetShowStabled
                    refresh()
                end)
            end,
        })
    s.hunterPetDisableCard = UI_Transmog._PagedShared.CreateNoSelectionCard(
        s.hunterPetFrame,
        {title = "Disable Hunter Pets", centerAtlas = "shop-icon-housing-pets-up"},
        function() ApplySelection("disabled", nil) end)

    s.hunterPetIgnoreButton = CreateFrame(
        "Button", nil, s.hunterPetFrame, "DisplayTypeButtonTemplate")
    s.hunterPetIgnoreButton:SetPoint(
        "TOPLEFT", s.hunterPetFrame, "TOPLEFT", 50, -130)
    s.hunterPetIgnoreButton:SetText(L["Ignore Hunter Pet"])
    s.hunterPetIgnoreButton.IconFrame.Icon:SetTexture(132311)
    s.hunterPetIgnoreButton.IconFrame.Icon:SetDesaturated(true)
    s.hunterPetIgnoreButton:SetScript("OnClick", function()
        ApplySelection("ignore", nil)
    end)

    s.hunterPetRandomButton = CreateFrame(
        "Button", nil, s.hunterPetFrame, "DisplayTypeButtonTemplate")
    s.hunterPetRandomButton:SetPoint(
        "LEFT", s.hunterPetIgnoreButton, "RIGHT", 25, 0)
    s.hunterPetRandomButton:SetText(L["Random Hunter Pet"])
    s.hunterPetRandomButton.IconFrame.Icon:SetTexture(1669485)
    s.hunterPetRandomButton:SetScript("OnClick", function()
        ApplySelection("random", nil)
    end)
    s.hunterPetCards = {}
    for index = 1, PAGE_SIZE do
        s.hunterPetCards[index] = CreatePetCard(
            s.hunterPetFrame, index + 1)
    end
    s.hunterPetPageText, s.hunterPetPrevButton, s.hunterPetNextButton =
        UI_Transmog._PagedShared.CreateNavButtons(
            s.hunterPetFrame,
            function() UI_Transmog:HunterPetPagePrev() end,
            function() UI_Transmog:HunterPetPageNext() end)
end

function UI_Transmog:RefreshHunterPets()
    if not s.hunterPetCards then return end
    local data = CurrentData()
    local isDisabled = data and data.HunterPetDisabled == true
    local isRandom = data and data.HunterPetRandom == true
    local selectedNumbers = {}
    if data and not isDisabled and not isRandom then
        for _, number in ipairs(ns.HunterPet.EnsureSelections(data)) do
            number = tonumber(number)
            if number then selectedNumbers[number] = true end
        end
    end
    local search = (s.hunterPetSearchString or ""):lower()
    local matching = {}
    local filterByStatus = s.hunterPetShowActive or s.hunterPetShowStabled
    for _, pet in ipairs(ns.HunterPet.GetAllPets()) do
        local isSelected = selectedNumbers[tonumber(pet.petNumber)] == true
        local matchesSelected = not s.hunterPetCheckedOnly or isSelected
        local matchesStatus = not filterByStatus
            or (s.hunterPetShowActive and pet.isActive == true)
            or (s.hunterPetShowStabled and pet.isActive ~= true)
        local matchesSearch = search == ""
            or (pet.name or ""):lower():find(search, 1, true)
            or (pet.familyName or ""):lower():find(search, 1, true)
        if matchesSelected and matchesStatus and matchesSearch then
            matching[#matching + 1] = pet
        end
    end
    local favorites = FitterSaved and FitterSaved.FavoriteHunterPets or {}
    table.sort(matching, function(a, b)
        local aNumber, bNumber = tonumber(a.petNumber), tonumber(b.petNumber)
        local aFavorite = aNumber ~= nil and favorites[aNumber] == true
        local bFavorite = bNumber ~= nil and favorites[bNumber] == true
        if aFavorite ~= bFavorite then return aFavorite end
        if a.isActive ~= b.isActive then return a.isActive end
        local aName, bName = (a.name or ""):lower(), (b.name or ""):lower()
        if aName ~= bName then return aName < bName end
        return (aNumber or 0) < (bNumber or 0)
    end)
    local pets = matching
    s.hunterPetPagedPets = pets
    local showDisableCard =
        UI_Transmog._PagedShared.DoesSpecialCardMatchSearch(
            "Disable Hunter Pets", search)
    s.hunterPetShowDisableCard = showDisableCard
    s.hunterPetTotalPages = UI_Transmog._PagedShared.GetSpecialCardTotalPages(
        #pets, showDisableCard)
    s.hunterPetCurrentPage = math.min(
        s.hunterPetCurrentPage or 1, s.hunterPetTotalPages)
    local start = UI_Transmog._PagedShared.GetSpecialCardPageStart(
        s.hunterPetCurrentPage, showDisableCard)
    if s.hunterPetDisableCard then
        s.hunterPetDisableCard:SetSelected(isDisabled)
        s.hunterPetDisableCard:SetShown(
            showDisableCard and s.hunterPetCurrentPage == 1)
    end
    if s.hunterPetRandomButton and s.hunterPetRandomButton.StateTexture then
        s.hunterPetRandomButton.StateTexture:SetShown(isRandom)
    end
    if s.hunterPetIgnoreButton and s.hunterPetIgnoreButton.StateTexture then
        local isIgnore = not isDisabled and not isRandom
            and next(selectedNumbers) == nil
        s.hunterPetIgnoreButton.StateTexture:SetShown(isIgnore)
    end
    for index, card in ipairs(s.hunterPetCards) do
        local info = not (showDisableCard
            and s.hunterPetCurrentPage == 1 and index > 19)
            and pets[start + index - 1] or nil
        card.petInfo = info
        UI_Transmog._PagedShared.PositionSpecialCardPageItem(
            card, s.hunterPetFrame, index,
            s.hunterPetCurrentPage, showDisableCard)
        card:SetShown(info ~= nil)
        if info then
            local isActive = info.isActive == true
            card.selected = selectedNumbers[tonumber(info.petNumber)] == true
            card.favoriteStar:SetShown(UI_Transmog._PagedShared
                .IsHunterPetFavorite(tonumber(info.petNumber)))
            card.model:SetAlpha(isActive and 1 or .45)
            card.border:SetAtlas(card.selected
                and "transmog-wardrobe-border-current-transmogged"
                or "transmog-setCard-default", true)
            card.border:SetDesaturated(not isActive and not card.selected)
            card.border:SetVertexColor(
                (isActive or card.selected) and 1 or .62,
                (isActive or card.selected) and 1 or .68,
                (isActive or card.selected) and 1 or .72)
            card.uncollectedGlow:SetShown(not isActive and not card.selected)
            if card.hoverHighlight:IsShown() and card.UpdateHoverStyle then
                card:UpdateHoverStyle()
            end
            local modelKey = tostring(info.petNumber or "") .. ":"
                .. tostring(info.displayID or "")
            if card.hunterPetModelKey ~= modelKey then
                card.hunterPetModelKey = modelKey
                card.model:ClearModel()
                if info.displayID and info.displayID > 0 then
                    card.model:SetDisplayInfo(info.displayID)
                end
            end
        else
            card.favoriteStar:Hide()
            card.model:SetAlpha(1)
            card.border:SetDesaturated(false)
            card.border:SetVertexColor(1, 1, 1)
            card.uncollectedGlow:Hide()
            if card.hunterPetModelKey then
                card.hunterPetModelKey = nil
                card.model:ClearModel()
            end
        end
    end
    s.hunterPetPageText:SetText(string.format(L["Page %d/%d"],
        s.hunterPetCurrentPage, s.hunterPetTotalPages))
    s.hunterPetPrevButton:SetEnabled(s.hunterPetCurrentPage > 1)
    s.hunterPetNextButton:SetEnabled(
        s.hunterPetCurrentPage < s.hunterPetTotalPages)
end

function UI_Transmog:HunterPetPagePrev()
    if (s.hunterPetCurrentPage or 1) > 1 then
        s.hunterPetCurrentPage = s.hunterPetCurrentPage - 1
        self:RefreshHunterPets()
    end
end

function UI_Transmog:HunterPetPageNext()
    if (s.hunterPetCurrentPage or 1) < (s.hunterPetTotalPages or 1) then
        s.hunterPetCurrentPage = s.hunterPetCurrentPage + 1
        self:RefreshHunterPets()
    end
end
