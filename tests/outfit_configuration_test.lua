-- OutfitConfiguration.lua: applying loadouts and shared outfits.
local T = require("harness")

local function Setup()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    w.env.wipe = function(t)
        for key in pairs(t) do t[key] = nil end
        return t
    end
    w.summonablePets = {}
    w.env.C_PetJournal = {
        PetIsSummonable = function(petGUID) return w.summonablePets[petGUID] == true end,
    }
    w:Load({"Data/Defaults.lua", "Controllers/OutfitConfiguration.lua"})
    return w, w.ns.OutfitConfiguration
end

T.test("drops what this character cannot use", function()
    local w, Config = Setup()
    w.mounts[10] = {name = "Owned"}
    w.mounts[11] = {name = "Not collected", collected = false}
    w.summonablePets["Pet-1"] = true
    w.ownedToys[500] = true
    w.itemCounts[600] = 1
    Config.Apply({
        Flying = {10, 11, 12},
        Pets = {"Pet-1", "Pet-2"},
        PetSummonTriggers = {["Pet-1"] = {mount = true}, ["Pet-2"] = {mount = true}},
        Toys = {500, 501},
        Title = 7,
    }, 3)
    local data = w.env.FitterCharacterSaved.Outfit3
    T.eq(#data.Flying, 1)
    T.eq(data.Flying[1], 10)
    T.eq(#data.Pets, 1)
    T.truthy(data.PetSummonTriggers["Pet-1"], "trigger kept for available pet")
    T.eq(data.PetSummonTriggers["Pet-2"], nil)
    T.eq(#data.Toys, 1)
    T.eq(data.Title, 7)
end)

T.test("keeps zones only when no other outfit uses them", function()
    local w, Config = Setup()
    w.env.FitterCharacterSaved.Outfit1 = {Zones = {84}}
    w.env.FitterCharacterSaved.Outfit2 = {Zones = {85}, SituationBaseline = {x = 1}}
    local oldZones, newZones = Config.Apply({Zones = {84, 2112}, SituationBaseline = {y = 2}}, 2)
    T.eq(#oldZones, 1)
    T.eq(oldZones[1], 85)
    T.eq(#newZones, 1)
    T.eq(newZones[1], 2112)
    local data = w.env.FitterCharacterSaved.Outfit2
    T.eq(data.SituationBaseline.x, 1, "destination baseline kept")
    T.eq(data.SituationBaseline.y, nil)
end)

T.test("the source is not changed or shared", function()
    local _, Config = Setup()
    local source = {Emotes = {wave = {conditions = {MOUNTED = true}}}}
    Config.Apply(source, 4)
    local copy = Config.Copy(source)
    T.truthy(copy ~= source and copy.Emotes ~= source.Emotes, "deep copy")
    T.truthy(source.Emotes.wave.conditions.MOUNTED, "source intact")
end)
