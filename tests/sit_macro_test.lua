-- Macro/Sit.lua: the "Outfit Sit" macro and the sit key binding.
local T = require("harness")

local function Setup()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    local ns = w:LoadMacros()
    ns.SitButton = T.NewButton()
    w:AddMacro(ns.Macro.SIT_MACRO_NAME, "")
    return w, ns.Macro
end

T.test("without a sit outfit it only sits", function()
    local w, Macro = Setup()
    Macro.UpdateSit()
    T.eq(w:MacroBody(Macro.SIT_MACRO_NAME), "/sit")
    T.eq(w.ns.SitButton:GetAttribute("macrotext"), "/sit")
end)

T.test("uses the client's localized sit command", function()
    local w, Macro = Setup()
    w.env.EMOTE1_TOKEN = "AGREE"
    w.env.EMOTE1_CMD1 = "/acuerdo"
    w.env.EMOTE2_TOKEN = "SIT"
    w.env.EMOTE2_CMD1 = "/sentarse"
    Macro.UpdateSit()
    T.eq(w:MacroBody(Macro.SIT_MACRO_NAME), "/sentarse")
end)

T.test("switches to the sit outfit before sitting", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 5}, {outfitID = 7}}
    w.activeOutfitID = 5
    w:SetOutfit(7, {Activities = {"sit"}})
    Macro.UpdateSit()
    T.eq(w:MacroBody(Macro.SIT_MACRO_NAME), "/outfit 2\n/run FitS()")
    T.eq(w.ns.SitButton:GetAttribute("macrotext"), "/outfit 2\n/run FitS()")
    T.eq(w.ns.state.sitOutfitID, 7)
end)

T.test("a queued sit runs once, after the outfit change", function()
    local w, Macro = Setup()
    local emotes = {}
    w.env.DoEmote = function(token) emotes[#emotes + 1] = token end
    w.env.FitS()
    T.eq(#emotes, 0)
    Macro.RunPendingSit()
    T.eq(emotes[1], "SIT")
    for _, timer in ipairs(w.timers) do timer.fn() end
    Macro.RunPendingSit()
    T.eq(#emotes, 1)
end)

T.test("a queued sit still runs when no outfit change arrives", function()
    local w = Setup()
    local emotes = {}
    w.env.DoEmote = function(token) emotes[#emotes + 1] = token end
    w.env.FitS()
    for _, timer in ipairs(w.timers) do timer.fn() end
    T.eq(emotes[1], "SIT")
end)

T.test("a fishing outfit does not change the sit macro", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 5}, {outfitID = 7}}
    w.activeOutfitID = 5
    w:SetOutfit(7, {Activities = {"fishing"}})
    Macro.UpdateActivities()
    T.eq(w:MacroBody(Macro.SIT_MACRO_NAME), "/sit")
end)

T.test("EnsureSit creates the macro", function()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    local Macro = w:LoadMacros().Macro
    Macro.EnsureSit()
    T.eq(w:MacroBody(Macro.SIT_MACRO_NAME), "/sit")
    T.eq(w.env.FitterCharacterSaved.LastSitMacroBody, "/sit")
end)
