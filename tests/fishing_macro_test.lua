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
