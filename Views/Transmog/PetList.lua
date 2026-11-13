local addonName, ns = ...
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local GetPetExpansionKey = ns.Constants.GetPetExpansionKey

function UI_Transmog:RefreshPetPaged()
    if not s.petFrame then return end
    

    s.petPagedPets = {}
    -- Build set of selected pet GUIDs for "Selected" filter and selected visibility.
    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    local selectedPetSet = {}
    if ns.Settings.GetOutfitData(outfitID) then
        local pets = ns.Settings.GetOutfitData(outfitID).Pets or {}
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
    

    if ns.Settings.GetOutfitData(outfitID) then
        local pets = ns.Settings.GetOutfitData(outfitID).Pets or {}
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

