-- UI/Transmog_PetPaged.lua
-- Split out of UI_Transmog.lua. Operates on the shared state table
-- ns.UI_Transmog._s; methods are added to ns.UI_Transmog.

local addonName, ns = ...
local L = ns.L

local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter
local PET_EXPANSIONS = ns.Constants.PET_EXPANSIONS
local PET_FAMILIES = ns.Constants.PET_FAMILIES
local GetPetExpansionKey = ns.Constants.GetPetExpansionKey

function UI_Transmog:ShowPetPaged()
    local outfitID = self:GetViewedOutfitID()
    local data = outfitID and FitterCharacterSaved["Outfit"..outfitID]
    local pets = data and data.Pets or nil
    local selectedPetGUID = pets and #pets > 0
        and pets[math.random(1, #pets)] or nil
    s.petFocusGUID = selectedPetGUID

    if not s.petPagedInitialized then
        self:InitializePetPaged()
        s.petPagedInitialized = true
    end
    self:_ShowPagedFrame(s.petFrame, "UpdatePetPaged")
    self:PreviewSelectedPet(selectedPetGUID)
    s.petFocusGUID = nil
end


function UI_Transmog:InitializePetPaged()
    local _, _, searchBox = UI_Transmog._PagedShared.CreateHeader(s.petFrame, L["Pets"], function(text)
        s.petSearchString = text
        UI_Transmog:RefreshPetPaged()
    end)
    -- Pet search box is anchored 10px further from the right than the mount headers.
    searchBox:ClearAllPoints()
    searchBox:SetPoint("TOPRIGHT", s.petFrame, "TOPRIGHT", -150, -26)
    s.petPagedSearchBox = searchBox

    s.petPagedSourcesDropdown = UI_Transmog._PagedShared.CreateFilterDropdown(s.petFrame, searchBox, {
        isDefault = function()
            return not s.petCheckedOnly and not s.petShowNotCollected
                and s.petHideDuplicateNames ~= false
                and next(s.petSelectedFamilies) == nil
                and next(s.petSelectedExpansions) == nil
        end,
        default = function()
            s.petCheckedOnly = false
            s.petShowNotCollected = false
            s.petHideDuplicateNames = true
            wipe(s.petSelectedFamilies)
            wipe(s.petSelectedExpansions)
            UI_Transmog:RefreshPetPaged()
        end,
        setup = function(dropdown, rootDescription)
            local refresh = function() UI_Transmog:RefreshPetPaged() end
            UI_Transmog._PagedShared.AddSelectedCheckbox(rootDescription, s, "petCheckedOnly", refresh)
            rootDescription:CreateCheckbox(L["Not Collected"], function()
                return s.petShowNotCollected
            end, function()
                s.petShowNotCollected = not s.petShowNotCollected
                refresh()
            end)
            rootDescription:CreateCheckbox(L["Hide Duplicate Names"], function()
                return s.petHideDuplicateNames ~= false
            end, function()
                s.petHideDuplicateNames = s.petHideDuplicateNames == false
                refresh()
            end)
            UI_Transmog._PagedShared.AddCheckboxFilterSubmenu(
                rootDescription, "Pet Families", PET_FAMILIES, s, "petSelectedFamilies", refresh)
            UI_Transmog._PagedShared.AddCheckboxFilterSubmenu(
                rootDescription, "Expansions", PET_EXPANSIONS, s, "petSelectedExpansions", refresh)
        end,
    })
    

    s.petIgnoreButton = CreateFrame("Button", nil, s.petFrame, "DisplayTypeButtonTemplate")
    s.petIgnoreButton:SetPoint("TOPLEFT", s.petFrame, "TOPLEFT", 50, -130)
    s.petIgnoreButton:SetText(L["Ignore Pets"])
    s.petIgnoreButton.IconFrame.Icon:SetTexture(132598)
    s.petIgnoreButton.IconFrame.Icon:SetDesaturated(true)
    s.petIgnoreButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
        local outfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
        if outfitID and FitterCharacterSaved["Outfit"..outfitID] then
            local data = FitterCharacterSaved["Outfit"..outfitID]
            data.Pets = {}
            data.PetRandom = false
            data.PetNoPet = false
            data.PetSummonTriggers = {}
            UI_Transmog:ClearMountPreview()
            UI_Transmog:UpdatePetPageDisplay()
            UI_Transmog:UpdateMountIcons()
            local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
            if activeOutfitID and activeOutfitID == outfitID then
                Fitter:UpdatePet()
            end
        end
    end)
    s.petIgnoreButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Ignore Pet"], 1, 1, 1, 1)
        GameTooltip:AddLine(L["Leave the currently summoned pet unchanged, except when a global dismissal setting applies."], 1, .82, 0, true)
        GameTooltip:Show()
    end)
    s.petIgnoreButton:HookScript("OnLeave", function() GameTooltip:Hide() end)

    s.petRandomButton = CreateFrame("Button", nil, s.petFrame, "DisplayTypeButtonTemplate")
    s.petRandomButton:SetPoint("LEFT", s.petIgnoreButton, "RIGHT", 25, 0)
    s.petRandomButton:SetText(L["Random Pet"])
    s.petRandomButton.IconFrame.Icon:SetTexture(1669485) 
    s.petRandomButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
        local outfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
        if outfitID and FitterCharacterSaved["Outfit"..outfitID] then
            local data = FitterCharacterSaved["Outfit"..outfitID]
            local newState = not data.PetRandom
            data.PetRandom = newState

            if newState then
                data.Pets = {}
                data.PetNoPet = false
                UI_Transmog:ClearMountPreview()
            end
            UI_Transmog:UpdatePetPageDisplay()
            UI_Transmog:UpdateMountIcons()

            local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
            if activeOutfitID and activeOutfitID == outfitID then
                Fitter:UpdatePet()
            end
        end
    end)
    s.petRandomButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Random Pet"], 1, 1, 1, 1)
        GameTooltip:AddLine(L["Summons a random favorite battle pet."], 1, .82, 0, 1)
        GameTooltip:AddLine(L["Selecting a specific pet turns this off."], 0.8, 0.8, 0.8, 1)
        GameTooltip:Show()
    end)
    s.petRandomButton:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local startY = -175
    local spacingX = 3
    local spacingY = 3
    local modelWidth = 114
    local modelHeight = 146
    local gridStartX = -((5 * modelWidth + 4 * spacingX - modelWidth) / 2)
    
    for i = 1, 20 do
        local visualIndex = i
        local col = (visualIndex - 1) % 5
        local row = math.floor((visualIndex - 1) / 5)
        
        local container = CreateFrame("Button", nil, s.petFrame)
        container:SetSize(modelWidth, modelHeight)
        container:SetPoint("TOP", s.petFrame, "TOP", gridStartX + (col * (modelWidth + spacingX)), startY - (row * (modelHeight + spacingY)))
        container:SetClipsChildren(true)
        

        local blackBg = container:CreateTexture(nil, "BACKGROUND", nil, -1)
        blackBg:SetColorTexture(0, 0, 0, 1)
        blackBg:SetPoint("TOPLEFT", 4, -4)
        blackBg:SetPoint("BOTTOMRIGHT", -4, 4)
        

        local bg = container:CreateTexture(nil, "ARTWORK")
        bg:SetAtlas("transmog-setCard-default", true)
        bg:SetAllPoints(true)
        
        local model = CreateFrame("PlayerModel", nil, container)
        model:SetPoint("TOPLEFT", 8, -8)
        model:SetPoint("BOTTOMRIGHT", -8, 8)
        model:SetClipsChildren(true)
        model:SetCamDistanceScale(0.7)

        local checkbox = CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
        checkbox:SetSize(18, 18)
        checkbox:SetPoint("TOPRIGHT", container, "TOPRIGHT", -8, -8)

        local favoriteStar = UI_Transmog._PagedShared.CreateFavoriteStar(container)
        

        local hoverHighlight = container:CreateTexture(nil, "OVERLAY")
        hoverHighlight:SetAtlas("transmog-setCard-default", true)
        hoverHighlight:SetAllPoints(true)
        hoverHighlight:SetVertexColor(1, 0.9, 0.5, 0.75)
        hoverHighlight:SetBlendMode("ADD")
        hoverHighlight:Hide()

        local uncollectedGlow = container:CreateTexture(nil, "OVERLAY", nil, 1)
        uncollectedGlow:SetAtlas("transmog-setCard-default", true)
        uncollectedGlow:SetAllPoints(true)
        uncollectedGlow:SetDesaturated(true)
        uncollectedGlow:SetVertexColor(.65, .72, .78, .55)
        uncollectedGlow:SetBlendMode("ADD")
        uncollectedGlow:Hide()
        

        container:SetScript("OnEnter", function(self)
            local frame = s.petModelFrames[i]
            local isSelected = false
            if frame then
                local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
                if outfitID and FitterCharacterSaved["Outfit"..outfitID] then
                    local data = FitterCharacterSaved["Outfit"..outfitID]
                    local pets = data.Pets or {}
                    for _, guid in ipairs(pets) do
                        if guid == frame.petGUID then
                            isSelected = true
                            break
                        end
                    end
                end
                if isSelected then
                    frame.hoverHighlight:SetAtlas("transmog-wardrobe-border-current-transmogged", true)
                    frame.hoverHighlight:SetVertexColor(1, 1, 1, 0.5)
                else
                    frame.hoverHighlight:SetAtlas("transmog-setCard-default", true)
                    frame.hoverHighlight:SetVertexColor(1, 0.9, 0.5, 0.75)
                end
                frame.hoverHighlight:Show()
            end
            if frame then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local petData = s.petPagedPets[frame.petIndex]
                if petData then
                    GameTooltip:SetText(petData.name, 1, 0.82, 0, 1, true)
                    if not petData.isCollected then
                        GameTooltip:AddLine(
                            "You have not collected this pet.",
                            .6, .6, .6, true)
                    elseif isSelected then
                        GameTooltip:AddLine("Right-click for summon settings.", 0.8, 0.8, 0.8, true)
                    end
                    GameTooltip:Show()
                end
            end
        end)
        container:SetScript("OnLeave", function()
            local frame = s.petModelFrames[i]
            if frame then frame.hoverHighlight:Hide() end
            GameTooltip:Hide()
        end)
        

        container:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                local frame = s.petModelFrames[i]
                if frame and not frame.petGUID then return end
                if frame and frame.checkbox then
                    frame.checkbox:Click()
                    if frame.checkbox:GetChecked() then
                        frame.hoverHighlight:SetAtlas("transmog-wardrobe-border-current-transmogged", true)
                        frame.hoverHighlight:SetVertexColor(1, 1, 1, 0.5)
                    else
                        frame.hoverHighlight:SetAtlas("transmog-setCard-default", true)
                        frame.hoverHighlight:SetVertexColor(1, 0.9, 0.5, 0.75)
                    end
                end
            elseif button == "RightButton" then
                local frame = s.petModelFrames[i]
                if not frame or not frame.petIndex then return end
                if not MenuUtil or not MenuUtil.CreateContextMenu then return end
                local petData = s.petPagedPets[frame.petIndex]
                if not petData then return end

                local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
                local data = outfitID and FitterCharacterSaved["Outfit"..outfitID]

                local isSelected = false
                if data then
                    for _, guid in ipairs(data.Pets or {}) do
                        if guid == frame.petGUID then
                            isSelected = true
                            break
                        end
                    end
                end

                local petGUID = frame.petGUID
                MenuUtil.CreateContextMenu(self, function(_, rootDescription)
                    if not petGUID then return end

                    local favorite = UI_Transmog._PagedShared.IsPetFavorite(petGUID)
                    rootDescription:CreateButton(
                        favorite and L["Remove Favorite"] or L["Set Favorite"], function()
                            UI_Transmog._PagedShared.SetFavorite(
                                "FavoritePets", petGUID, not favorite)
                            UI_Transmog:RefreshPetPaged()
                        end)
                    rootDescription:CreateDivider()
                    rootDescription:CreateButton(L["Preview"], function()
                        UI_Transmog:PreviewSelectedPet(
                            petGUID, petData.displayID, petGUID)
                    end)
                    rootDescription:CreateButton(L["Summon Pet"], function()
                        C_PetJournal.SummonPetByGUID(petGUID)
                    end)

                    if isSelected then
                        rootDescription:CreateTitle("Summon Pet When")
                        for _, trigger in ipairs(ns.Pet.SUMMON_TRIGGERS) do
                            local triggerKey = trigger.key
                            rootDescription:CreateCheckbox(trigger.label, function()
                                local settings = data.PetSummonTriggers and data.PetSummonTriggers[petGUID]
                                return not settings or settings[triggerKey] ~= false
                            end, function()
                                data.PetSummonTriggers = data.PetSummonTriggers or {}
                                local settings = data.PetSummonTriggers[petGUID]
                                if not settings then
                                    settings = {}
                                    data.PetSummonTriggers[petGUID] = settings
                                end
                                settings[triggerKey] = settings[triggerKey] == false and nil or false
                                if not next(settings) then
                                    data.PetSummonTriggers[petGUID] = nil
                                end
                            end)
                        end
                    end
                end)
            end
        end)
        container:EnableMouse(true)

        checkbox:SetScript("OnClick", function(cb)
            local frame = s.petModelFrames[i]
            if not frame or not frame.petGUID then return end
            local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
            if not outfitID or not FitterCharacterSaved["Outfit"..outfitID] then return end

            local data = FitterCharacterSaved["Outfit"..outfitID]

            local pets = data.Pets or {}
            if cb:GetChecked() then
                local found = false
                for _, guid in ipairs(pets) do
                    if guid == frame.petGUID then found = true; break end
                end
                if not found then
                    table.insert(pets, frame.petGUID)
                end
            else
                for j = #pets, 1, -1 do
                    if pets[j] == frame.petGUID then
                        table.remove(pets, j)
                    end
                end
                if data.PetSummonTriggers then
                    data.PetSummonTriggers[frame.petGUID] = nil
                end
            end
            data.Pets = pets
            data.PetRandom = false
            if #pets > 0 then data.PetNoPet = false end

            if cb:GetChecked() then
                UI_Transmog:PreviewSelectedPet(frame.petGUID)
            elseif s.previewPetGUID == frame.petGUID then
                UI_Transmog:PreviewSelectedPet(pets[#pets])
            end

            UI_Transmog:UpdatePetPageDisplay()
            UI_Transmog:UpdateMountIcons()

            local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
            if activeOutfitID and activeOutfitID == outfitID then
                Fitter:UpdatePet()
            end

            PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
        end)
        
        s.petModelFrames[i] = {
            container = container,
            model = model,
            checkbox = checkbox,
            bg = bg,
            hoverHighlight = hoverHighlight,
            favoriteStar = favoriteStar,
            uncollectedGlow = uncollectedGlow,
            petGUID = nil,
            petIndex = nil
        }
    end
    

    s.petPageText, s.petPrevButton, s.petNextButton = UI_Transmog._PagedShared.CreateNavButtons(
        s.petFrame,
        function() UI_Transmog:PetPagePrev() end,
        function() UI_Transmog:PetPageNext() end)
end


function UI_Transmog:UpdatePetPaged()
    if not s.petFrame or not C_TransmogOutfitInfo
        or not C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID then
        return
    end
    
    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    
    if not outfitID or outfitID == 0 then
        return
    end
    
    if not FitterCharacterSaved["Outfit"..outfitID] then
        Fitter:CreateEmptyOutfit(outfitID)
    end
    
    s.petSearchString = ""
    wipe(s.petSelectedExpansions)
    wipe(s.petSelectedFamilies)
    s.petCheckedOnly = false
    s.petShowNotCollected = false
    s.petHideDuplicateNames = true
    if s.petPagedSearchBox then s.petPagedSearchBox:SetText("") end
    
    s.petCurrentPage = 1
    self:RefreshPetPaged()
end


function UI_Transmog:RefreshPetPaged()
    if not s.petFrame then return end
    

    s.petPagedPets = {}
    -- Build set of selected pet GUIDs for "Selected" filter and selected visibility.
    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    local selectedPetSet = {}
    if outfitID and FitterCharacterSaved["Outfit"..outfitID] then
        local pets = FitterCharacterSaved["Outfit"..outfitID].Pets or {}
        for _, guid in ipairs(pets) do
            selectedPetSet[guid] = true
        end
    end

    -- Check if any family filter is active
    local hasFamilyFilter = next(s.petSelectedFamilies) ~= nil
    local hasExpansionFilter = next(s.petSelectedExpansions) ~= nil
    s.petShowDisabledCard =
        UI_Transmog._PagedShared.DoesSpecialCardMatchSearch(
            "Disable Pets", s.petSearchString)
    local hideDuplicateNames = s.petHideDuplicateNames ~= false
    
    local seenPetNames = {}
    local notCollectedFilter = LE_PET_JOURNAL_FILTER_NOT_COLLECTED

    if not s.petNoPetCard then
        s.petNoPetCard = UI_Transmog._PagedShared.CreateNoSelectionCard(
            s.petFrame,
            {
                title = "Disable Pets",
                centerAtlas = "shop-icon-housing-pets-up",
            },
            function(selected)
                local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
                local data = outfitID
                    and FitterCharacterSaved["Outfit"..outfitID]
                if not data then return end
                data.PetNoPet = selected
                if selected then
                    data.Pets = {}
                    data.PetRandom = false
                    data.PetSummonTriggers = {}
                    UI_Transmog:ClearMountPreview()
                end
                UI_Transmog:UpdatePetPageDisplay()
                UI_Transmog:UpdateMountIcons()
                if C_TransmogOutfitInfo.GetActiveOutfitID() == outfitID then
                    Fitter:UpdatePet()
                end
                PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
            end)
    end
    -- Fitter intentionally resets the shared Pet Journal filters. They are
    -- left at their defaults instead of being restored after enumeration.
    if C_PetJournal.SetDefaultFilters then
        C_PetJournal.SetDefaultFilters()
    end
    if C_PetJournal.ClearSearchFilter then
        C_PetJournal.ClearSearchFilter()
    elseif C_PetJournal.SetSearchFilter then
        C_PetJournal.SetSearchFilter("")
    end
    if s.petShowNotCollected and notCollectedFilter
        and C_PetJournal.SetFilterChecked then
        C_PetJournal.SetFilterChecked(notCollectedFilter, true)
    end

    local ok, enumerationError = xpcall(function()
        local numPets = C_PetJournal.GetNumPets()
        for i = 1, numPets do
            local petID, speciesID, owned, customName, level, favorite, isRevoked, speciesName, icon, petType = C_PetJournal.GetPetInfoByIndex(i)

            -- Some account-wide pets are visible to this character but cannot
            -- actually be summoned (for example faction- or guild-restricted
            -- companions). Do not offer those pets as outfit selections.
            local isSummonable = not (owned and petID)
                or not C_PetJournal.PetIsSummonable
                or C_PetJournal.PetIsSummonable(petID)

            if speciesID and isSummonable
                and ((owned and petID) or s.petShowNotCollected) then

                local displayID
                if owned and petID then
                    displayID = select(6, C_PetJournal.GetPetInfoByPetID(petID))
                elseif C_PetJournal.GetDisplayIDByIndex then
                    displayID = C_PetJournal.GetDisplayIDByIndex(speciesID, 1)
                elseif C_PetJournal.GetPetInfoBySpeciesID then
                    displayID = select(12,
                        C_PetJournal.GetPetInfoBySpeciesID(speciesID))
                end
                local displayName = customName or speciesName or "Unknown Pet"
                local petGUID = owned and petID or nil
                local isSelected = petGUID
                    and selectedPetSet[petGUID] == true or false
                local isFavorite = petGUID
                    and UI_Transmog._PagedShared.IsPetFavorite(petGUID)

                local matchesSearch = s.petSearchString == ""
                    or displayName:lower():find(s.petSearchString, 1, true)
                local matchesFamily = not hasFamilyFilter
                    or (petType and s.petSelectedFamilies[petType])
                local matchesChecked = not s.petCheckedOnly or isSelected
                local matchesExpansion = not hasExpansionFilter
                    or (speciesID and s.petSelectedExpansions[GetPetExpansionKey(speciesID)])
                local isNewName = not seenPetNames[displayName]

                if matchesSearch and matchesFamily and matchesChecked and matchesExpansion
                    and (not hideDuplicateNames or isNewName or isSelected or isFavorite) then
                    seenPetNames[displayName] = true
                    table.insert(s.petPagedPets, {
                        petGUID = petGUID,
                        name = displayName,
                        icon = icon,
                        speciesID = speciesID,
                        displayID = displayID or 0,
                        petType = petType,
                        isCollected = owned == true,
                    })
                end
            end
        end
    end, function(message) return message end)

    if not ok then error(enumerationError, 0) end

    UI_Transmog._PagedShared.SortFavoritesFirst(
        s.petPagedPets, "petGUID", FitterSaved and FitterSaved.FavoritePets or {})
    

    s.petTotalPages =
        UI_Transmog._PagedShared.GetSpecialCardTotalPages(
            #s.petPagedPets, s.petShowDisabledCard)
    

    if outfitID and FitterCharacterSaved["Outfit"..outfitID] then
        local pets = FitterCharacterSaved["Outfit"..outfitID].Pets or {}
        if #pets > 0 then
            local selectedPetGUID = s.petFocusGUID or pets[1]
            for index, petData in ipairs(s.petPagedPets) do
                if petData.petGUID == selectedPetGUID then
                    s.petCurrentPage =
                        UI_Transmog._PagedShared.GetSpecialCardPageForIndex(
                            index, s.petShowDisabledCard)
                    break
                end
            end
        end
    end
    
    s.petCurrentPage = math.min(s.petCurrentPage, s.petTotalPages)
    
    self:UpdatePetPageDisplay()
end


function UI_Transmog:UpdatePetPageDisplay()
    if not s.petFrame then return end
    
    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if not outfitID then return end
    
    local data = FitterCharacterSaved["Outfit"..outfitID]
    if not data then return end

    if s.petRandomButton and s.petRandomButton.StateTexture then
        s.petRandomButton.StateTexture:SetShown(data.PetRandom == true)
    end

    if s.petIgnoreButton and s.petIgnoreButton.StateTexture then
        local pets = data.Pets or {}
        local hasSelection = data.PetNoPet == true
            or #pets > 0 or data.PetRandom == true
        s.petIgnoreButton.StateTexture:SetShown(not hasSelection)
    end
    if s.petNoPetCard then
        s.petNoPetCard:SetSelected(data.PetNoPet == true)
        s.petNoPetCard:SetShown(
            s.petShowDisabledCard and s.petCurrentPage == 1)
    end
    
    -- Build lookup for selected pets
    local selectedPets = {}
    local pets = data.Pets or {}
    for _, guid in ipairs(pets) do
        selectedPets[guid] = true
    end
    

    if s.petPageText then
        s.petPageText:SetText(string.format(L["Page %d/%d"], s.petCurrentPage, s.petTotalPages))
    end
    

    if s.petPrevButton then
        s.petPrevButton:SetEnabled(s.petCurrentPage > 1)
    end
    if s.petNextButton then
        s.petNextButton:SetEnabled(s.petCurrentPage < s.petTotalPages)
    end
    

    local startIndex =
        UI_Transmog._PagedShared.GetSpecialCardPageStart(
            s.petCurrentPage, s.petShowDisabledCard)
    for i = 1, 20 do
        local petIndex = startIndex + i - 1
        local frame = s.petModelFrames[i]
        UI_Transmog._PagedShared.PositionSpecialCardPageItem(
            frame.container, s.petFrame, i, s.petCurrentPage,
            s.petShowDisabledCard)
        
        if frame then
            if (not s.petShowDisabledCard
                    or s.petCurrentPage ~= 1 or i <= 19)
                and petIndex <= #s.petPagedPets then
                local petData = s.petPagedPets[petIndex]
                frame.petGUID = petData.petGUID
                frame.petIndex = petIndex
                frame.container:Show()
                frame.model:SetAlpha(petData.isCollected and 1 or .45)
                frame.bg:SetDesaturated(not petData.isCollected)
                frame.bg:SetVertexColor(
                    petData.isCollected and 1 or .62,
                    petData.isCollected and 1 or .68,
                    petData.isCollected and 1 or .72)
                frame.uncollectedGlow:SetShown(not petData.isCollected)
                
                local isSelected = petData.petGUID
                    and selectedPets[petData.petGUID] or false
                frame.checkbox:SetChecked(isSelected)
                frame.checkbox:Hide()
                frame.favoriteStar:SetShown(
                    petData.isCollected
                    and UI_Transmog._PagedShared.IsPetFavorite(petData.petGUID))

                if isSelected then
                    frame.bg:SetAtlas("transmog-wardrobe-border-current-transmogged", true)
                else
                    frame.bg:SetAtlas("transmog-setCard-default", true)
                end
                

                frame.model:Show()
                frame.modelUpdateID = (frame.modelUpdateID or 0) + 1
                local modelUpdateID = frame.modelUpdateID
                UI_Transmog:ScheduleTimer(0.05, function()
                    if frame.model and frame.modelUpdateID == modelUpdateID
                        and frame.petIndex == petIndex
                        and frame.petGUID == petData.petGUID then
                        frame.model:ClearModel()
                        if petData.displayID and petData.displayID > 0 then
                            frame.model:SetDisplayInfo(petData.displayID)
                        end
                        frame.model:SetPosition(0, 0, 0)
                    end
                end, "pet-page")
            else
                frame.container:Hide()
                frame.model:SetAlpha(1)
                frame.bg:SetDesaturated(false)
                frame.bg:SetVertexColor(1, 1, 1)
                frame.uncollectedGlow:Hide()
                frame.model:Show()
                frame.favoriteStar:Hide()
                frame.checkbox:SetChecked(false)
                frame.hoverHighlight:Hide()
                frame.petGUID = nil
                frame.petIndex = nil
                frame.modelUpdateID = (frame.modelUpdateID or 0) + 1
                frame.model:ClearModel()
                if GameTooltip:GetOwner() == frame.container then
                    GameTooltip:Hide()
                end
            end
        end
    end

    -- Refresh tooltip if mouse is over a pet model frame after page change
    for i = 1, 20 do
        local frame = s.petModelFrames[i]
        if frame and frame.container:IsVisible() and frame.container:IsMouseOver() then
            frame.container:GetScript("OnEnter")(frame.container)
            break
        end
    end
end


function UI_Transmog:PetPagePrev()
    if s.petCurrentPage > 1 then
        s.petCurrentPage = s.petCurrentPage - 1
        self:UpdatePetPageDisplay()
        PlaySound(SOUNDKIT.UI_TRANSMOG_PAGE_TURN)
    end
end


function UI_Transmog:PetPageNext()
    if s.petCurrentPage < s.petTotalPages then
        s.petCurrentPage = s.petCurrentPage + 1
        self:UpdatePetPageDisplay()
        PlaySound(SOUNDKIT.UI_TRANSMOG_PAGE_TURN)
    end
end

