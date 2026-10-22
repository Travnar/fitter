-- Macro/Update.lua: the "Outfit Update" macro and its key binding.
local T = require("harness")

local BINDING = "CLICK FitterOutfitUpdateButton:LeftButton"

local function Setup()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    w.outfits = {{outfitID = 5}, {outfitID = 7}, {outfitID = 8}}
    w:AddToy(1002)
    w:SetOutfit(7, {Toys = {1002}})
    local ns = w:LoadMacros()
    ns.OutfitUpdateButton = T.NewButton()
    return w, ns.Macro
end

T.test("nothing happens without the macro or a key binding", function()
    local w, Macro = Setup()
    Macro.UpdateOutfitUpdateMacro()
    T.eq(#w.edits, 0)
    T.eq(w.ns.OutfitUpdateButton:GetAttribute("macrotext"), nil)
end)

T.test("switches to the zone outfit and uses its toys", function()
    local w, Macro = Setup()
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "/run FitU()")
    w.ns.state.currentZoneOutfitID = 7
    Macro.UpdateOutfitUpdateMacro()
    T.eq(w:MacroBody(Macro.OUTFIT_UPDATE_MACRO_NAME), "/use item:1002\n/outfit 2\n/run FitU()")
    T.eq(w:MacroIcon(Macro.OUTFIT_UPDATE_MACRO_NAME), Macro.OUTFIT_UPDATE_MACRO_ICON)
    T.eq(w.ns.state.outfitUpdateResolvedID, 7)
end)

T.test("a locked active outfit keeps its own toys and no switch", function()
    local w, Macro = Setup()
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "/run FitU()")
    w.ns.state.currentZoneOutfitID = 7
    w.activeOutfitID = 8
    w.lockedOutfits[8] = true
    w:AddToy(1003)
    w:SetOutfit(8, {Toys = {1003}})
    Macro.UpdateOutfitUpdateMacro()
    T.eq(w:MacroBody(Macro.OUTFIT_UPDATE_MACRO_NAME), "/use item:1003\n/run FitU()")
end)

T.test("hunter pet lines go ahead of the update", function()
    local w, Macro = Setup()
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "/run FitU()")
    w.activeOutfitID = 5
    w.ns.HunterPet = {GetOutfitMacroLines = function() return "/cast Call Pet 2" end}
    Macro.UpdateOutfitUpdateMacro()
    T.eq(w:MacroBody(Macro.OUTFIT_UPDATE_MACRO_NAME), "/cast Call Pet 2\n/run FitU()")
end)

T.test("a key binding alone updates only the button", function()
    local w, Macro = Setup()
    w.bindings[BINDING] = "F"
    w.ns.state.currentZoneOutfitID = 7
    Macro.UpdateOutfitUpdateMacro()
    T.eq(w.ns.OutfitUpdateButton:GetAttribute("macrotext"), "/use item:1002\n/outfit 2\n/run FitU()")
    T.eq(#w.edits, 0)
    T.eq(w:MacroBody(Macro.OUTFIT_UPDATE_MACRO_NAME), nil)
end)

T.test("EnsureOutfitUpdateMacro creates an account macro", function()
    local w, Macro = Setup()
    Macro.EnsureOutfitUpdateMacro()
    T.eq(w.account[1].name, Macro.OUTFIT_UPDATE_MACRO_NAME)
    T.eq(w.account[1].body, "/run FitU()")
    T.eq(w.printed[#w.printed], "|cff00ff00Fitter:|r Created macro 'Outfit Update'.")
end)
