-- Transmog_Mounts.lua
-- The `PopulateMountList` method used by the Flying / Ground / Aquatic
-- paged frames. Pure data filtering, no widget creation.

local addonName, ns = ...
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local GetMountExpansionKey = ns.Constants.GetMountExpansionKey
local MOUNT_TYPE_ALL_TERRAIN = ns.Constants.MOUNT_TYPE_ALL_TERRAIN


function UI_Transmog:PopulateMountList(mountType)

    local mountIDs = C_MountJournal.GetMountIDs()
    if not mountIDs then return {} end

    local mounts = {}
    local searchString = ""
    local checkedOnly = false
    local showNotCollected = false
    local selectedExpansions = nil

    if mountType == "Flying" then
        searchString = s.flyingSearchString
        checkedOnly = s.flyingCheckedOnly
        showNotCollected = s.flyingShowNotCollected
        selectedExpansions = s.flyingSelectedExpansions
    elseif mountType == "Ground" then
        searchString = s.groundSearchString
        checkedOnly = s.groundCheckedOnly
        showNotCollected = s.groundShowNotCollected
        selectedExpansions = s.groundSelectedExpansions
    elseif mountType == "Aquatic" then
        searchString = s.aquaticSearchString
        checkedOnly = s.aquaticCheckedOnly
        showNotCollected = s.aquaticShowNotCollected
        selectedExpansions = s.aquaticSelectedExpansions
    end

    local hasExpansionFilter = selectedExpansions and next(selectedExpansions) ~= nil

    -- Build cache key only when no search/filter is active
    local cacheKey
    if searchString == "" and not checkedOnly and not showNotCollected and not hasExpansionFilter then
        if mountType == "Ground" then
            cacheKey = "Ground|" .. (s.groundFilterFlying and "1" or "0") .. "|" .. (s.groundFilterGround and "1" or "0")
        else
            cacheKey = mountType
        end
    end
    if cacheKey and s.mountListCache[cacheKey] then
        return s.mountListCache[cacheKey]
    end


    local outfitID = self:GetViewedOutfitID()
    local selectedMounts = {}
    if checkedOnly and outfitID and FitterCharacterSaved["Outfit"..outfitID] then
        local mountList = FitterCharacterSaved["Outfit"..outfitID][mountType] or {}
        for _, mountID in ipairs(mountList) do
            selectedMounts[mountID] = true
        end
    end


    if mountType == "Flying" then
        local playerRace = ns.state.playerRace
        if playerRace == "Dracthyr" and IsPlayerSpell(369536) then
            local soarName = "Soar"
            local shouldInclude = true


            if searchString ~= "" then
                if not soarName:lower():find(searchString, 1, true) then
                    shouldInclude = false
                end
            end


            if shouldInclude and checkedOnly then
                if not selectedMounts["soar"] then
                    shouldInclude = false
                end
            end

            if shouldInclude then
                table.insert(mounts, {
                    name = soarName, id = "soar", icon = 4622485,
                    model = nil, isPlayerModel = true, camScale = 0.8,
                    isCollected = true,
                })
            end
        end
    end


    if mountType == "Ground" then
        local playerRace = ns.state.playerRace
        if playerRace == "Worgen" and IsPlayerSpell(87840) then
            local runningWildName = "Running Wild"
            local shouldInclude = true

            local hasTypeFilter = s.groundFilterFlying or s.groundFilterGround
            if hasTypeFilter and not s.groundFilterGround then
                shouldInclude = false
            end

            if shouldInclude and searchString ~= "" then
                if not runningWildName:lower():find(searchString, 1, true) then
                    shouldInclude = false
                end
            end


            if shouldInclude and checkedOnly then
                if not selectedMounts["runningwild"] then
                    shouldInclude = false
                end
            end

            if shouldInclude then
                table.insert(mounts, {
                    name = runningWildName, id = "runningwild", icon = 514641,
                    model = nil, isPlayerModel = true, isCollected = true,
                })
            end
        end
    end

    for _, mountID in ipairs(mountIDs) do
        local name, _, icon, _, isUsable, _, _, _, _, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)

        if (isCollected or showNotCollected) and not shouldHideOnChar then

            local creatureDisplayInfoID, _, _, _, mountTypeID, modelSceneID, animID, spellVisualKitID = C_MountJournal.GetMountInfoExtraByID(mountID)
            local isAllTerrain = mountTypeID == MOUNT_TYPE_ALL_TERRAIN

            if not creatureDisplayInfoID or creatureDisplayInfoID == 0 then
                local allDisplays = C_MountJournal.GetMountAllCreatureDisplayInfoByID(mountID)
                if allDisplays and #allDisplays > 0 then
                    creatureDisplayInfoID = allDisplays[1].creatureDisplayID
                end
            end

            local shouldInclude = true

            if not isAllTerrain and mountType == "Flying" and (mountTypeID == 230 or mountTypeID == 231 or mountTypeID == 254 or mountTypeID == 412) then
                shouldInclude = false
            elseif not isAllTerrain and mountType == "Aquatic" and mountTypeID ~= 254 and mountTypeID ~= 231 and mountTypeID ~= 412 then
                shouldInclude = false
            elseif not isAllTerrain and mountType == "Ground" and mountTypeID == 254 then
                shouldInclude = false
            end

            if shouldInclude and mountType == "Ground" then
                local hasTypeFilter = s.groundFilterFlying or s.groundFilterGround
                if hasTypeFilter and not isAllTerrain then
                    local isFlying = (mountTypeID ~= 230 and mountTypeID ~= 231 and mountTypeID ~= 254 and mountTypeID ~= 412)
                    if isFlying and not s.groundFilterFlying then
                        shouldInclude = false
                    elseif not isFlying and not s.groundFilterGround then
                        shouldInclude = false
                    end
                end
            end


            -- GetMountUsabilityByID reports false for otherwise valid mounts
            -- during combat.  This page configures an outfit rather than
            -- summoning immediately, so retain the complete catalogue in
            -- combat instead of filtering every flying/ground mount out.
            if shouldInclude and isCollected and mountType ~= "Aquatic"
                and not isAllTerrain and not InCombatLockdown() then
                local canUse, useError = C_MountJournal.GetMountUsabilityByID(mountID, false)
                if not canUse then
                    shouldInclude = false
                end
            end


            if shouldInclude and searchString ~= "" then
                if not name:lower():find(searchString, 1, true) then
                    shouldInclude = false
                end
            end


            if shouldInclude and checkedOnly then
                if not selectedMounts[mountID] then
                    shouldInclude = false
                end
            end

            if shouldInclude and hasExpansionFilter then
                local expKey = GetMountExpansionKey(mountID)
                if not expKey or not selectedExpansions[expKey] then
                    shouldInclude = false
                end
            end

            if shouldInclude then
                table.insert(mounts, {
                    name = name, id = mountID, icon = icon,
                    model = creatureDisplayInfoID, sceneID = modelSceneID,
                    spellVisualKitID = spellVisualKitID,
                    isCollected = isCollected == true,
                })
            end
        end
    end

    UI_Transmog._PagedShared.SortFavoritesFirst(
        mounts, "id", FitterSaved and FitterSaved.FavoriteMounts or {})

    -- Re-evaluate situational usability after combat rather than preserving a
    -- catalogue built while that API could not provide meaningful results.
    if cacheKey and not InCombatLockdown() then
        s.mountListCache[cacheKey] = mounts
    end

    return mounts
end
