local addonName, ns = ...

local Zones = {}
ns.Zones = Zones

-- Static data tables live in Data/Zones.lua. Expose them on ns.Zones so
-- existing UI code that reads ns.Zones.MAJOR_ZONES etc. keeps working.
Zones.MAJOR_ZONES = ns.Constants.MAJOR_ZONES
Zones.BIOME_GROUPS = ns.Constants.BIOME_GROUPS
Zones.EXPANSION_ZONES = ns.Constants.EXPANSION_ZONES
Zones.CONTINENT_ZONES = ns.Constants.CONTINENT_ZONES
local hasZoneAssignments

local function HasZoneAssignments()
    if hasZoneAssignments ~= nil then return hasZoneAssignments end
    if not FitterCharacterSaved then return false end
    for key, outfitData in pairs(FitterCharacterSaved) do
        if type(key) == "string" and key:match("^Outfit%d+$")
            and type(outfitData) == "table"
            and type(outfitData.Zones) == "table"
            and #outfitData.Zones > 0 then
            hasZoneAssignments = true
            return true
        end
    end
    hasZoneAssignments = false
    return false
end

function Zones.InvalidateTrackingCache()
    hasZoneAssignments = nil
end

function Zones.IsTrackingEnabled()
    return (FitterSaved and FitterSaved.UseZoneSpecificMounts) == true
        or HasZoneAssignments()
end

function Zones.GetZoneSituation(mapID)
    return ns.Constants.ZONE_SITUATION_MAP[mapID] or "world"
end

function Zones.IsCityZone(mapID)
    return ns.Constants.CITY_MAP_IDS[mapID] or false
end

function Zones.UpdateCache()
    local state = ns.state
    if not Zones.IsTrackingEnabled() then
        state.currentZoneMapID = nil
        state.currentZoneOutfitID = nil
        return
    end
    if not C_Map or not C_TransmogOutfitInfo or not FitterCharacterSaved then
        state.currentZoneMapID = nil
        state.currentZoneOutfitID = nil
        return
    end

    local previousMapID = state.currentZoneMapID
    local mapID = C_Map.GetBestMapForUnit("player")
    state.currentZoneMapID = mapID

    if not mapID then
        state.currentZoneOutfitID = nil
        return
    end

    local zoneOutfitIDs = {}
    for key, outfitData in pairs(FitterCharacterSaved) do
        if type(key) == "string" and key:match("^Outfit%d+$")
            and type(outfitData) == "table"
            and type(outfitData.Zones) == "table" then
            for _, zoneMapID in ipairs(outfitData.Zones) do
                if zoneMapID == mapID then
                    zoneOutfitIDs[#zoneOutfitIDs + 1] = tonumber(key:match("%d+"))
                    break
                end
            end
        end
    end

    local zoneOutfitID
    if #zoneOutfitIDs > 0 then
        -- Keep the selection stable while the player remains in the same zone.
        -- A fresh random outfit is selected each time the player enters a zone.
        if mapID == previousMapID
            and tContains(zoneOutfitIDs, state.currentZoneOutfitID) then
            zoneOutfitID = state.currentZoneOutfitID
        else
            zoneOutfitID = zoneOutfitIDs[math.random(#zoneOutfitIDs)]
        end
    end

    if mapID == previousMapID and zoneOutfitID == state.currentZoneOutfitID then return end

    state.currentZoneOutfitID = zoneOutfitID

    if not InCombatLockdown() and ns.Macro then
        state.nextMountToSummon = ns.Mount.SelectNext(false, state.currentZoneOutfitID)
        ns.Macro.UpdateMacroForMount(state.nextMountToSummon)
        ns.Macro.UpdateHearthstone()
        ns.Macro.UpdateOutfitUpdateMacro()
    elseif InCombatLockdown() and ns.MarkMacroRefreshPending then
        ns.MarkMacroRefreshPending()
    end
end
