-- Settings.lua: saved-variable defaults, new outfits and hearthstone migrations.
local T = require("harness")

local BAG_HEARTHSTONE = 6948

local function Setup(saved, characterSaved)
    local w = T.NewWorld()
    w.env.FitterSaved = saved
    w.env.FitterCharacterSaved = characterSaved
    w.ns.Macro = {UpdateHearthstone = function() w.hearthstoneUpdates = (w.hearthstoneUpdates or 0) + 1 end}
    w:Load({"Data/Defaults.lua", "Controllers/Settings.lua"})
    return w, w.ns.Settings
end

T.test("defaults fill unset keys without overwriting saved ones", function()
    local w, Settings = Setup({ShowTooltipMount = false, FavoriteMounts = {[5] = true}}, nil)
    Settings.ApplyDefaults()
    local saved = w.env.FitterSaved
    T.eq(saved.ShowTooltipMount, false)
    T.eq(saved.ShowTooltipHearthstone, true)
    T.eq(saved.ShiftHearthstoneCondition, "None")
    T.truthy(saved.FavoriteMounts[5], "saved favorites kept")
    T.eq(type(w.env.FitterCharacterSaved.Loadouts), "table")
end)

T.test("each default table is a new table", function()
    local w, Settings = Setup(nil, nil)
    Settings.ApplyDefaults()
    local saved = w.env.FitterSaved
    saved.FavoriteToys[1] = true
    T.truthy(saved.FavoritePets[1] == nil, "favorites tables are separate")
    T.eq(next(w.ns.Constants.ACCOUNT_DEFAULTS.FavoriteToys), nil, "defaults untouched")
end)

T.test("emote cooldown is kept between 5 and 60", function()
    local w, Settings = Setup({EmoteGlobalCooldown = 300}, nil)
    Settings.ApplyDefaults()
    T.eq(w.env.FitterSaved.EmoteGlobalCooldown, 60)
    w.env.FitterSaved.EmoteGlobalCooldown = "bad"
    Settings.ApplyDefaults()
    T.eq(w.env.FitterSaved.EmoteGlobalCooldown, 25)
end)

T.test("a new outfit gets its own empty lists and is not replaced", function()
    local w, Settings = Setup({}, {})
    Settings.CreateEmptyOutfit(3)
    Settings.CreateEmptyOutfit(4)
    local three = w.env.FitterCharacterSaved.Outfit3
    T.eq(three.Title, -1)
    three.Flying[1] = 100
    T.eq(#w.env.FitterCharacterSaved.Outfit4.Flying, 0)
    Settings.CreateEmptyOutfit(3)
    T.eq(w.env.FitterCharacterSaved.Outfit3.Flying[1], 100)
end)

T.test("generated bag Hearthstone selections are cleared once", function()
    local w, Settings = Setup({}, {
        Outfit1 = {Hearthstones = {BAG_HEARTHSTONE}},
        Outfit2 = {Hearthstones = {BAG_HEARTHSTONE, 140192}},
        Outfit3 = {Hearthstones = {140192}},
    })
    Settings.Initialize()
    local character = w.env.FitterCharacterSaved
    T.eq(#character.Outfit1.Hearthstones, 0)
    T.eq(#character.Outfit2.Hearthstones, 2)
    T.eq(character.Outfit3.Hearthstones[1], 140192)
    T.truthy(w.env.FitterSaved.EmptyHearthstoneDefaultsMigrated, "flag set")

    character.Outfit1.Hearthstones = {BAG_HEARTHSTONE}
    Settings.Initialize()
    T.eq(character.Outfit1.Hearthstones[1], BAG_HEARTHSTONE, "chosen after migrating, kept")
end)

T.test("a hearthstone reset reaches characters that log in later", function()
    local w, Settings = Setup({}, {Outfit1 = {Hearthstones = {140192}}})
    Settings.Initialize()
    Settings.ResetDefaultHearthstones()
    T.eq(w.hearthstoneUpdates, 1)
    T.eq(w.env.FitterSaved.DefaultHearthstonesResetVersion, 1)

    -- Another character, whose data predates the reset.
    w.env.FitterCharacterSaved = {
        Outfit1 = {Hearthstone = BAG_HEARTHSTONE},
        Outfit2 = {Hearthstones = {BAG_HEARTHSTONE}},
        Outfit3 = {Hearthstones = {140192}},
    }
    w.env.FitterSaved.EmptyHearthstoneDefaultsMigrated = true
    Settings.Initialize()
    local character = w.env.FitterCharacterSaved
    T.eq(#character.Outfit1.Hearthstones, 0)
    T.eq(character.Outfit1.Hearthstone, nil)
    T.eq(#character.Outfit2.Hearthstones, 0)
    T.eq(character.Outfit3.Hearthstones[1], 140192)
    T.eq(character.DefaultHearthstonesResetVersion, 1)

    character.Outfit2.Hearthstones = {BAG_HEARTHSTONE}
    Settings.Initialize()
    T.eq(character.Outfit2.Hearthstones[1], BAG_HEARTHSTONE, "reset applied once")
end)
