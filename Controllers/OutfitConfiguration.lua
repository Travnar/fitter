local _, ns = ...

-- Copying whole outfit configurations: loadouts and shared outfit links.
local OutfitConfiguration = {}
ns.OutfitConfiguration = OutfitConfiguration

function OutfitConfiguration.Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[OutfitConfiguration.Copy(key, seen)] = OutfitConfiguration.Copy(child, seen)
    end
    return result
end
local Copy = OutfitConfiguration.Copy

-- The character and account loadout lists.
function OutfitConfiguration.GetLoadoutStores()
    ns.Settings.ApplyDefaults()
    return FitterCharacterSaved.Loadouts, FitterSaved.Loadouts
end

local function IsMountAvailable(mountID)
    if type(mountID) ~= "number" or not C_MountJournal then return false end
    local name, _, _, _, _, _, _, _, _, shouldHideOnChar, isCollected =
        C_MountJournal.GetMountInfoByID(mountID)
    return name ~= nil and isCollected == true and shouldHideOnChar ~= true
end

local function IsPetAvailable(petGUID)
    return type(petGUID) == "string" and C_PetJournal
        and C_PetJournal.PetIsSummonable(petGUID) == true
end

local hearthstoneRules = {}
for _, entry in ipairs(ns.Constants.KNOWN_HEARTHSTONES or {}) do
    hearthstoneRules[entry.id] = entry
end

local function IsHearthstoneAvailable(itemID)
    local rule = hearthstoneRules[itemID]
    if rule and not ns.Macro.IsHearthstoneRaceEligible(rule) then return false end
    if rule and rule.baseItem then
        return C_Item.GetItemCount(itemID, false, false, false) > 0
    end
    return PlayerHasToy(itemID) == true
end

local function FilterList(source, predicate)
    local result = {}
    for _, value in ipairs(type(source) == "table" and source or {}) do
        if predicate(value) then result[#result + 1] = value end
    end
    return result
end

local function ZoneUsedByAnotherOutfit(mapID, currentID)
    for key, data in pairs(FitterCharacterSaved or {}) do
        local outfitID = type(key) == "string"
            and tonumber(key:match("^Outfit(%d+)$"))
        if outfitID and outfitID ~= currentID and type(data) == "table"
            and type(data.Zones) == "table" and tContains(data.Zones, mapID) then
            return true
        end
    end
    return false
end

-- Replaces outfitID's configuration with source, dropping anything this
-- character cannot use. Returns the outfit's zones before and after.
function OutfitConfiguration.Apply(source, outfitID)
    ns.Settings.CreateEmptyOutfit(outfitID)
    local destination = ns.Settings.GetOutfitData(outfitID)
    local oldZones = Copy(type(destination.Zones) == "table" and destination.Zones or {})
    local oldSituationBaseline = Copy(destination.SituationBaseline)
    local applied = Copy(source)
    applied.Flying = FilterList(source.Flying, IsMountAvailable)
    applied.Ground = FilterList(source.Ground, IsMountAvailable)
    applied.Aquatic = FilterList(source.Aquatic, IsMountAvailable)
    applied.Pets = FilterList(source.Pets, IsPetAvailable)
    local availablePets = {}
    for _, petGUID in ipairs(applied.Pets) do availablePets[petGUID] = true end
    if type(applied.PetSummonTriggers) ~= "table" then applied.PetSummonTriggers = {} end
    for petGUID in pairs(applied.PetSummonTriggers) do
        if not availablePets[petGUID] then
            applied.PetSummonTriggers[petGUID] = nil
        end
    end
    applied.Hearthstones = FilterList(source.Hearthstones, IsHearthstoneAvailable)
    applied.Toys = FilterList(source.Toys, function(id)
        return type(id) == "number" and PlayerHasToy(id) == true
    end)
    applied.Zones = FilterList(source.Zones, function(mapID)
        return not ZoneUsedByAnotherOutfit(mapID, outfitID)
    end)
    applied.SituationBaseline = nil

    wipe(destination)
    for key, value in pairs(applied) do destination[key] = value end
    destination.SituationBaseline = oldSituationBaseline
    return oldZones, applied.Zones
end
