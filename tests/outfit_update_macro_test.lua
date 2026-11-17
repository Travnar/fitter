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

T.test("the account and character macros are both updated", function()
    local w, Macro = Setup()
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "/run FitU()", 4624566)
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "/run FitU()\n/cast Charge", 132337, true)
    w.ns.state.currentZoneOutfitID = 7
    Macro.UpdateOutfitUpdateMacro()
    T.eq(w.account[1].body, "/use item:1002\n/outfit 2\n/run FitU()")
    T.eq(w.character[1].body, "/use item:1002\n/outfit 2\n/run FitU()\n/cast Charge")
    T.eq(w.character[1].icon, 132337, "character macro keeps its icon")

    w.ns.state.currentZoneOutfitID = 5
    Macro.UpdateOutfitUpdateMacro()
    T.eq(w.account[1].body, "/outfit 1\n/run FitU()")
    T.eq(w.character[1].body, "/outfit 1\n/run FitU()\n/cast Charge")
end)

T.test("a character macro on its own keeps the player's lines from 2.13.0 and earlier", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastOutfitUpdateMacroBody = "/outfit 1\n/run FitU()"
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "/outfit 1\n/run FitU()\n/cast Charge", 132337, true)
    w.ns.state.currentZoneOutfitID = 7
    Macro.UpdateOutfitUpdateMacro()
    T.eq(w.character[1].body, "/use item:1002\n/outfit 2\n/run FitU()\n/cast Charge")
    T.eq(w.character[1].icon, 132337)
end)

T.test("creating the character macro leaves the account macro's stored body alone", function()
    local w, Macro = Setup()
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "/run FitU()")
    w.ns.state.currentZoneOutfitID = 7
    Macro.UpdateOutfitUpdateMacro()
    Macro.EnsureCharacterOutfitUpdateMacro()
    T.eq(w.env.FitterCharacterSaved.LastOutfitUpdateMacroBody, "/use item:1002\n/outfit 2\n/run FitU()")
    T.eq(w.character[1].body, "/use item:1002\n/outfit 2\n/run FitU()")
    Macro.EnsureCharacterOutfitUpdateMacro()
    T.eq(#w.character, 1)
end)

T.test("a tooltip line the player added to the update macro is kept", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastOutfitUpdateMacroBody = "/run FitU()"
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "#showtooltip Charge\n/run FitU()\n/cast Charge")
    w.ns.state.currentZoneOutfitID = 7
    Macro.UpdateOutfitUpdateMacro()
    T.eq(w.account[1].body, "/use item:1002\n/outfit 2\n/run FitU()\n#showtooltip Charge\n/cast Charge")
end)
