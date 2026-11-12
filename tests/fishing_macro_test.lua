-- Macro/Fishing.lua: the "Outfit Fishing" macro and the fishing key binding.
local T = require("harness")

local function Setup()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    local ns = w:LoadMacros()
    ns.FishingButton = T.NewButton()
    w:AddMacro(ns.Macro.FISHING_MACRO_NAME, "")
    return w, ns.Macro
end

T.test("without a fishing outfit it only casts Fishing", function()
    local w, Macro = Setup()
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME), "#showtooltip Fishing\n/cast Fishing")
    T.eq(w.ns.FishingButton:GetAttribute("macrotext"), "/cast Fishing")
end)

T.test("uses the localized Fishing spell, then the legacy spell", function()
    local w, Macro = Setup()
    w.spells[7620] = {name = "Pesca antigua"}
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME), "#showtooltip Pesca antigua\n/cast Pesca antigua")
    w.spells[131474] = {name = "Pesca"}
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME), "#showtooltip Pesca\n/cast Pesca")
end)

T.test("switches to the fishing outfit before casting", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 5}, {outfitID = 7}}
    w.activeOutfitID = 5
    w:SetOutfit(7, {Activities = {"fishing"}})
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME), "#showtooltip Fishing\n/outfit 2\n/cast Fishing")
    T.eq(w.ns.FishingButton:GetAttribute("macrotext"), "/outfit 2\n/cast Fishing")
    T.eq(w.ns.state.fishingOutfitID, 7)
end)

T.test("no switch when a fishing outfit is already active", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 5}, {outfitID = 7}}
    w.activeOutfitID = 7
    w:SetOutfit(5, {Activities = {"fishing"}})
    w:SetOutfit(7, {Activities = {"fishing"}})
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME), "#showtooltip Fishing\n/cast Fishing")
end)

T.test("EnsureFishing creates the macro", function()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    local Macro = w:LoadMacros().Macro
    Macro.EnsureFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME), "#showtooltip Fishing\n/cast Fishing")
    T.eq(w.env.FitterCharacterSaved.LastFishingMacroBody, "#showtooltip Fishing\n/cast Fishing")
end)

local function PoleSetup(enabled)
    local w, Macro = Setup()
    w:Load({"FishingPole.lua"})
    w.ns.Features.EquipFishingPole = true
    w.env.FitterCharacterSaved.EquipFishingPole = enabled
    w.items[6256] = {classID = 2, subclassID = 20, level = 1}
    w.items[6365] = {classID = 2, subclassID = 20, level = 20}
    w.items[2131] = {classID = 2, subclassID = 7, level = 30}
    return w, Macro
end

T.test("equips the best fishing pole in the bags before casting", function()
    local w, Macro = PoleSetup(true)
    w.inventory[16] = 2131
    w.bags[0] = {6256, 2131}
    w.bags[1] = {6365}
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME),
        "#showtooltip Fishing\n/equip [noequipped:Fishing Poles] item:6365\n/cast Fishing")
    T.eq(w.ns.FishingButton:GetAttribute("macrotext"),
        "/equip [noequipped:Fishing Poles] item:6365\n/cast Fishing")
end)

T.test("keeps the equipped fishing pole", function()
    local w, Macro = PoleSetup(true)
    w.inventory[16] = 6256
    w.bags[0] = {6365}
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME),
        "#showtooltip Fishing\n/equip [noequipped:Fishing Poles] item:6256\n/cast Fishing")
end)

T.test("switches outfit before equipping the fishing pole", function()
    local w, Macro = PoleSetup(true)
    w.outfits = {{outfitID = 5}, {outfitID = 7}}
    w.activeOutfitID = 5
    w:SetOutfit(7, {Activities = {"fishing"}})
    w.env.FitterCharacterSaved.EquipFishingPole = true
    w.bags[0] = {6256}
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME),
        "#showtooltip Fishing\n/outfit 2\n/equip [noequipped:Fishing Poles] item:6256\n/cast Fishing")
end)

T.test("no equip line when disabled, without a pole, or off Forever", function()
    local w, Macro = PoleSetup(nil)
    w.bags[0] = {6256}
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME), "#showtooltip Fishing\n/cast Fishing")

    w.env.FitterCharacterSaved.EquipFishingPole = true
    w.bags[0] = {2131}
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME), "#showtooltip Fishing\n/cast Fishing")

    w.bags[0] = {6256}
    w.ns.Features.EquipFishingPole = false
    Macro.UpdateFishing()
    T.eq(w:MacroBody(Macro.FISHING_MACRO_NAME), "#showtooltip Fishing\n/cast Fishing")
end)
