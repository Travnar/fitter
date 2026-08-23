-- Transmog_ZoneSituations.lua
-- Zone situation management: capturing situation baselines, enabling/disabling
-- transmog situations when zone assignments change, and bulk zone operations.

local addonName, ns = ...
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter

local MAJOR_ZONES = ns.Zones.MAJOR_ZONES
local BIOME_GROUPS = ns.Zones.BIOME_GROUPS
local EXPANSION_ZONES = ns.Zones.EXPANSION_ZONES
local CONTINENT_ZONES = ns.Zones.CONTINENT_ZONES

function UI_Transmog:CacheViewedZoneSituations()
    if not C_TransmogOutfitInfo
        or not C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID
        or not C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions
        or not C_TransmogOutfitInfo.GetOutfitSituation then return end

    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    local categoryData =
        C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions()
    if not outfitID or not categoryData then return end

    Fitter:CreateEmptyOutfit(outfitID)
    local data = FitterCharacterSaved["Outfit" .. outfitID]
    local enabled = not C_TransmogOutfitInfo.GetOutfitSituationsEnabled
        or C_TransmogOutfitInfo.GetOutfitSituationsEnabled()
    local state = { rest = false, world = false }
    if enabled then
        for _, category in ipairs(categoryData) do
            for _, group in ipairs(category.groupData) do
                for _, optionData in ipairs(group.optionData) do
                    local situation = optionData.name == "Rest Area" and "rest"
                        or optionData.name == "World" and "world" or nil
                    if situation then
                        state[situation] =
                            C_TransmogOutfitInfo.GetOutfitSituation(
                                optionData.option) and true or false
                    end
                end
            end
        end
    end
    data.ZoneSituationState = state
end

local situationCacheFrame = CreateFrame("Frame")
situationCacheFrame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_CHANGED")
situationCacheFrame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED")
situationCacheFrame:SetScript("OnEvent", function()
    C_Timer.After(0, function()
        UI_Transmog:CacheViewedZoneSituations()
    end)
end)


-- Captures the current state of a situation type for an outfit before Fitter enables it.
-- Only captures once per situation type per outfit; does nothing if already captured.
local function CaptureBaselineIfNeeded(outfitID, situation, categoryData)
    if not FitterCharacterSaved or not FitterCharacterSaved["Outfit"..outfitID] then return end
    local outfitData = FitterCharacterSaved["Outfit"..outfitID]
    if not outfitData.SituationBaseline then
        outfitData.SituationBaseline = {}
    end
    if outfitData.SituationBaseline[situation] ~= nil then return end  -- already captured

    local targetName = situation == "rest" and "Rest Area" or "World"
    for _, category in ipairs(categoryData) do
        for _, group in ipairs(category.groupData) do
            for _, optData in ipairs(group.optionData) do
                if optData.name == targetName then
                    -- Use GetOutfitSituation for the authoritative state; optData.value may not reflect outfit config
                    local isActive = C_TransmogOutfitInfo.GetOutfitSituation
                        and C_TransmogOutfitInfo.GetOutfitSituation(optData.option)
                    outfitData.SituationBaseline[situation] = isActive and true or false
                    return
                end
            end
        end
    end
    outfitData.SituationBaseline[situation] = false  -- option not found; assume disabled
end

function UI_Transmog:UpdateZoneSituation(mapID, enable)
    if not FitterSaved then return end
    if not C_TransmogOutfitInfo or not C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions then return end

    if enable then
        if not FitterSaved.AutoEnableZoneSituations then return end
        local categoryData = C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions()
        if not categoryData then return end

        local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()

        -- Capture the situation's baseline state before enabling it for the first time
        if outfitID then
            local situation = ns.Zones.GetZoneSituation(mapID)
            local outfitData = FitterCharacterSaved and FitterCharacterSaved["Outfit"..outfitID]
            if outfitData and outfitData.Zones then
                local countOfType = 0
                for _, zoneMapID in ipairs(outfitData.Zones) do
                    if ns.Zones.GetZoneSituation(zoneMapID) == situation then
                        countOfType = countOfType + 1
                    end
                end
                if countOfType == 1 then  -- zone was just added; this is the first of its type
                    CaptureBaselineIfNeeded(outfitID, situation, categoryData)
                end
            end
        end

        -- Check if the target situation is already active; if so, skip all API calls
        -- to avoid potentially destructive re-commits that could wipe other configured situations
        local targetName = ns.Zones.GetZoneSituation(mapID) == "rest" and "Rest Area" or "World"
        for _, category in ipairs(categoryData) do
            for _, group in ipairs(category.groupData) do
                for _, optData in ipairs(group.optionData) do
                    if optData.name == targetName then
                        local isActive = C_TransmogOutfitInfo.GetOutfitSituation
                            and C_TransmogOutfitInfo.GetOutfitSituation(optData.option)
                        if isActive then
                            return  -- Already enabled; nothing to do
                        end
                    end
                end
            end
        end

        if outfitID and C_TransmogOutfitInfo.SetOutfitSituationsEnabled then
            C_TransmogOutfitInfo.SetOutfitSituationsEnabled(true)
        end
        for _, category in ipairs(categoryData) do
            for _, group in ipairs(category.groupData) do
                for _, optData in ipairs(group.optionData) do
                    if optData.name == targetName then
                        C_TransmogOutfitInfo.UpdatePendingSituation(optData.option, true)
                        C_TransmogOutfitInfo.CommitPendingSituations()
                        return
                    end
                end
            end
        end
    else
        if not FitterSaved.AutoDisableZoneSituations then return end

        local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()

        -- Check baseline: only disable if Fitter was the one that enabled this situation
        local situation = ns.Zones.GetZoneSituation(mapID)
        local outfitData = outfitID and FitterCharacterSaved and FitterCharacterSaved["Outfit"..outfitID]
        local baseline = outfitData and outfitData.SituationBaseline

        -- If no baseline was captured for this situation, we have no record of enabling it.
        -- Be conservative: leave the situation unchanged to avoid removing settings we didn't set.
        if not baseline or baseline[situation] == nil then
            return
        end

        local baselineHad = baseline[situation] and true or false

        -- Clear this situation's baseline entry now that it's being removed
        baseline[situation] = nil
        if not next(baseline) then
            outfitData.SituationBaseline = nil
        end

        if baselineHad then
            -- This situation was already active before Fitter touched it; leave it unchanged
            return
        end

        local categoryData = C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions()
        if not categoryData then return end

        -- Single pass over categoryData to locate option handles and pre-compute post-change state,
        -- avoiding any additional fetches after each commit.
        --
        -- anyOtherLocationActive: we're only disabling targetName; all other options are untouched,
        -- so GetOutfitSituation() called pre-commit gives the correct post-commit result for them.
        --
        -- allDefaultAfterChanges: opt.value for non-target, non-"All *" options is unaffected by
        -- our commits, so the pre-commit value is the same as what a post-commit fetch would return.
        local targetName = situation == "rest" and "Rest Area" or "World"
        local targetOption = nil
        local allLocationsOption = nil
        local anyOtherLocationActive = false
        local allDefaultAfterChanges = true

        for catIdx, category in ipairs(categoryData) do
            for _, group in ipairs(category.groupData) do
                for _, optData in ipairs(group.optionData) do
                    if optData.name == targetName then
                        targetOption = optData.option
                    elseif catIdx == 1 and optData.name == "All Locations" then
                        allLocationsOption = optData.option
                    elseif catIdx == 1 then
                        local isActive = C_TransmogOutfitInfo.GetOutfitSituation
                            and C_TransmogOutfitInfo.GetOutfitSituation(optData.option)
                        if isActive then anyOtherLocationActive = true end
                    end
                    if optData.value and not optData.name:find("^All ") and optData.name ~= targetName then
                        allDefaultAfterChanges = false
                    end
                end
            end
        end

        -- Fitter enabled this situation; uncheck it now that no zones of this type remain
        if targetOption then
            C_TransmogOutfitInfo.UpdatePendingSituation(targetOption, false)
        end
        C_TransmogOutfitInfo.CommitPendingSituations()

        -- If no Location options remain active, fall back to "All Locations"
        if not anyOtherLocationActive and allLocationsOption then
            C_TransmogOutfitInfo.UpdatePendingSituation(allLocationsOption, true)
            C_TransmogOutfitInfo.CommitPendingSituations()
        end

        -- If all situations are now at defaults, disable entirely
        if allDefaultAfterChanges then
            if C_TransmogOutfitInfo.ResetOutfitSituations then
                C_TransmogOutfitInfo.ResetOutfitSituations()
            end
            if C_TransmogOutfitInfo.SetOutfitSituationsEnabled then
                C_TransmogOutfitInfo.SetOutfitSituationsEnabled(false)
            end
            C_TransmogOutfitInfo.CommitPendingSituations()
        end
    end
end

function UI_Transmog:TryDisableZoneSituation(mapID, outfitID)
    if not FitterSaved or not FitterSaved.AutoDisableZoneSituations then return end
    if not outfitID or not FitterCharacterSaved or not FitterCharacterSaved["Outfit"..outfitID] then return end

    local zones = FitterCharacterSaved["Outfit"..outfitID].Zones
    if not zones then return end

    local situation = ns.Zones.GetZoneSituation(mapID)
    for _, zoneMapID in ipairs(zones) do
        if ns.Zones.GetZoneSituation(zoneMapID) == situation then
            return
        end
    end

    self:UpdateZoneSituation(mapID, false)
end

function UI_Transmog:BuildActiveZoneFilter()
    local filter = {}
    local any = false
    for _, biome in ipairs(BIOME_GROUPS) do
        if s.zonesSelectedBiomes[biome.key] then
            for _, mapID in ipairs(biome.mapIDs) do
                filter[mapID] = true
                any = true
            end
        end
    end
    for _, expansion in ipairs(EXPANSION_ZONES) do
        if s.zonesSelectedExpansions[expansion.key] then
            for _, mapID in ipairs(expansion.mapIDs) do
                filter[mapID] = true
                any = true
            end
        end
    end
    for _, continent in ipairs(CONTINENT_ZONES) do
        if s.zonesSelectedContinents[continent.key] then
            for _, mapID in ipairs(continent.mapIDs) do
                filter[mapID] = true
                any = true
            end
        end
    end
    return any and filter or nil
end

function UI_Transmog:GetFilteredZones(selected)
    selected = selected or {}
    local activeFilter = self:BuildActiveZoneFilter()
    local hasFilter = s.additionalCheckedOnly or activeFilter ~= nil
    local search = s.additionalSearchString or ""
    local zones = {}

    for _, zone in ipairs(MAJOR_ZONES) do
        local searchMatch = search == ""
            or zone.name:lower():find(search, 1, true)
        local filterMatch = not hasFilter
            or (s.additionalCheckedOnly and selected[zone.mapID])
            or (activeFilter and activeFilter[zone.mapID])
        if searchMatch and filterMatch then
            zones[#zones + 1] = zone
        end
    end
    table.sort(zones, function(a, b) return a.name < b.name end)
    return zones
end

function UI_Transmog:ApplyBiomeSelection(biomeKey)
    local outfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if not outfitID or not FitterCharacterSaved["Outfit"..outfitID] then return end

    local data = FitterCharacterSaved["Outfit"..outfitID]
    if not data.Zones then data.Zones = {} end

    local selected = {}
    for _, mapID in ipairs(data.Zones) do selected[mapID] = true end
    local filteredZones = self:GetFilteredZones(selected)
    local targetMapIDs = {}
    for _, zone in ipairs(filteredZones) do
        targetMapIDs[zone.mapID] = true
    end

    if biomeKey == "uncheck" then
        if #data.Zones == 0 then return end
        local removedCityZone, removedWorldZone
        for mapID in pairs(targetMapIDs) do
            if tContains(data.Zones, mapID) then
                if ns.Zones.GetZoneSituation(mapID) == "rest" then removedCityZone = mapID
                else removedWorldZone = mapID end
            end
            tDeleteItem(data.Zones, mapID)
        end
        if removedCityZone then self:TryDisableZoneSituation(removedCityZone, outfitID) end
        if removedWorldZone then self:TryDisableZoneSituation(removedWorldZone, outfitID) end
        UI_Transmog:RefreshZonesList()
        UI_Transmog:UpdateMountIcons()
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
        if Fitter and Fitter.RefreshZoneCache then
            Fitter:RefreshZoneCache()
        end
        return
    end

    if biomeKey ~= "all" then return end

    -- Build O(1) lookup for zones already in this outfit
    local currentZoneSet = {}
    local hadRestBefore, hadWorldBefore = false, false
    for _, mapID in ipairs(data.Zones) do
        currentZoneSet[mapID] = true
        local sit = ns.Zones.GetZoneSituation(mapID)
        if sit == "rest" then hadRestBefore = true
        else hadWorldBefore = true end
    end

    local added = false
    local addedCityZone, addedWorldZone = false, false
    for mapID in pairs(targetMapIDs) do
        if not currentZoneSet[mapID] then
            table.insert(data.Zones, mapID)
            currentZoneSet[mapID] = true
            added = true
            if ns.Zones.GetZoneSituation(mapID) == "rest" then
                addedCityZone = true
            else
                addedWorldZone = true
            end
        end
    end

    if added and FitterSaved and FitterSaved.AutoEnableZoneSituations
        and C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions then
        local currentOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
        -- Fetch category data BEFORE enabling to get accurate baseline state
        local categoryData = C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions()
        if categoryData then
            -- Capture baseline for each situation type being enabled for the first time
            if addedCityZone and not hadRestBefore and currentOutfitID then
                CaptureBaselineIfNeeded(currentOutfitID, "rest", categoryData)
            end
            if addedWorldZone and not hadWorldBefore and currentOutfitID then
                CaptureBaselineIfNeeded(currentOutfitID, "world", categoryData)
            end
        end
        if categoryData then
            -- Determine which situations actually need enabling (skip already-active ones)
            local needEnableRest = addedCityZone
            local needEnableWorld = addedWorldZone
            for _, category in ipairs(categoryData) do
                for _, group in ipairs(category.groupData) do
                    for _, optData in ipairs(group.optionData) do
                        if optData.name == "Rest Area" and C_TransmogOutfitInfo.GetOutfitSituation
                            and C_TransmogOutfitInfo.GetOutfitSituation(optData.option) then
                            needEnableRest = false
                        elseif optData.name == "World" and C_TransmogOutfitInfo.GetOutfitSituation
                            and C_TransmogOutfitInfo.GetOutfitSituation(optData.option) then
                            needEnableWorld = false
                        end
                    end
                end
            end

            if needEnableRest or needEnableWorld then
                if currentOutfitID and C_TransmogOutfitInfo.SetOutfitSituationsEnabled then
                    C_TransmogOutfitInfo.SetOutfitSituationsEnabled(true)
                end
                for _, category in ipairs(categoryData) do
                    for _, group in ipairs(category.groupData) do
                        for _, optData in ipairs(group.optionData) do
                            if (needEnableRest and optData.name == "Rest Area") or
                               (needEnableWorld and optData.name == "World") then
                                C_TransmogOutfitInfo.UpdatePendingSituation(optData.option, true)
                            end
                        end
                    end
                end
                C_TransmogOutfitInfo.CommitPendingSituations()
            end
        end
    end

    UI_Transmog:RefreshZonesList()
    UI_Transmog:UpdateMountIcons()
    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)

    if added and Fitter and Fitter.RefreshZoneCache then
        Fitter:RefreshZoneCache()
    end
end
