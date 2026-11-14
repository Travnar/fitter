local addonName, ns = ...

local Zones = {}
ns.Zones = Zones

-- Static data tables live in Data/Zones.lua. Expose them on ns.Zones so
-- existing UI code that reads ns.Zones.MAJOR_ZONES etc. keeps working.
Zones.MAJOR_ZONES = ns.Constants.MAJOR_ZONES
Zones.BIOME_GROUPS = ns.Constants.BIOME_GROUPS
Zones.EXPANSION_ZONES = ns.Constants.EXPANSION_ZONES
Zones.CONTINENT_ZONES = ns.Constants.CONTINENT_ZONES

-- Zone names in Data/Zones.lua are written in English. Other clients show the
-- game's own name for each map instead.
function Zones.GetMapName(mapID, englishName)
    if GetLocale():match("^en") then return englishName end
    local info = C_Map.GetMapInfo(mapID)
    if info and info.name and info.name ~= "" then return info.name end
    return englishName
end

for _, zone in ipairs(Zones.MAJOR_ZONES) do
    zone.name = Zones.GetMapName(zone.mapID, zone.name)
end
local hasAssignments

local function HasAssignments(outfitData)
    return (type(outfitData.Zones) == "table" and #outfitData.Zones > 0)
        or (type(outfitData.Holidays) == "table" and #outfitData.Holidays > 0)
end

local function HasZoneAssignments()
    if hasAssignments ~= nil then return hasAssignments end
    if not FitterCharacterSaved then return false end
    for key, outfitData in pairs(FitterCharacterSaved) do
        if type(key) == "string" and key:match("^Outfit%d+$")
            and type(outfitData) == "table"
            and HasAssignments(outfitData) then
            hasAssignments = true
            return true
        end
    end
    hasAssignments = false
    return false
end

function Zones.InvalidateTrackingCache()
    hasAssignments = nil
end

function Zones.RefreshCache()
    Zones.InvalidateTrackingCache()
    Zones.UpdateCache()
end

function Zones.IsTrackingEnabled()
    return (ns.Features.ZoneSpecificMounts and FitterSaved
            and FitterSaved.UseZoneSpecificMounts) == true
        or HasZoneAssignments()
end

local function ContainsAny(list, lookup)
    for _, value in ipairs(list) do
        if lookup[value] then return true end
    end
    return false
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

    local activeHolidays = ns.Holidays.GetActiveKeys()
    local holidayOutfitIDs, zoneOutfitIDs = {}, {}
    for key, outfitData in pairs(FitterCharacterSaved) do
        if type(key) == "string" and key:match("^Outfit%d+$")
            and type(outfitData) == "table" then
            local outfitID = tonumber(key:match("%d+"))
            if type(outfitData.Holidays) == "table"
                and ContainsAny(outfitData.Holidays, activeHolidays) then
                holidayOutfitIDs[#holidayOutfitIDs + 1] = outfitID
            end
            if mapID and type(outfitData.Zones) == "table"
                and tContains(outfitData.Zones, mapID) then
                zoneOutfitIDs[#zoneOutfitIDs + 1] = outfitID
            end
        end
    end

    local candidates = #holidayOutfitIDs > 0 and holidayOutfitIDs or zoneOutfitIDs
    local zoneOutfitID
    if #candidates > 0 then
        -- Keep the selection stable while the player remains in the same zone.
        -- A fresh random outfit is selected each time the player enters a zone.
        if mapID == previousMapID
            and tContains(candidates, state.currentZoneOutfitID) then
            zoneOutfitID = state.currentZoneOutfitID
        else
            zoneOutfitID = candidates[math.random(#candidates)]
        end
    end

    if mapID == previousMapID and zoneOutfitID == state.currentZoneOutfitID then return end

    state.currentZoneOutfitID = zoneOutfitID

    ns.RunOutOfCombat(function()
        state.nextMountToSummon = ns.Mount.SelectNext(false, ns.GetMountOutfitID())
        ns.Macro.UpdateMacroForMount(state.nextMountToSummon)
        ns.Macro.UpdateHearthstone()
        ns.Macro.UpdateOutfitUpdateMacro()
    end)
end

-- Zone events arrive in bursts while the map settles; act once after the last.
function Zones.OnZoneChanged()
    if not Zones.IsTrackingEnabled()
        and not ns.Emote.IsConditionConfigured("BIOMES") then
        return
    end
    local state = ns.state
    if state.zoneUpdateTimer then
        state.zoneUpdateTimer:Cancel()
    end
    state.zoneGeneration = state.zoneGeneration + 1
    local zoneGeneration = state.zoneGeneration
    state.zoneUpdateTimer = C_Timer.NewTimer(1, function()
        state.zoneUpdateTimer = nil
        if zoneGeneration ~= state.zoneGeneration then return end
        Zones.UpdateCache()
        ns.Emote.OnZoneChanged()
        ns.Pet.Apply(nil, "zoneChange")
    end)
end

function Zones.OnCalendarUpdated()
    if ns.state.loaded and Zones.IsTrackingEnabled() then
        Zones.UpdateCache()
    end
end
