-- Macro/Hearthstone.lua: the "Outfit Hearth" macro and the hearthstone key binding.
local T = require("harness")

local DEFAULT_HEARTHSTONE = 6948

local function Setup()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    w.ns.state.playerClass = "WARRIOR"
    w.ns.state.playerRace = "Human"
    w:AddToy(2001, {icon = 777})
    w:AddToy(2002, {icon = 888})
    local ns = w:LoadMacros()
    ns.HearthstoneButton = T.NewButton()
    w:AddMacro(ns.Macro.HEARTHSTONE_MACRO_NAME, "/use Hearthstone")
    return w, ns.Macro
end

local function Body(w)
    return w:MacroBody(w.ns.Macro.HEARTHSTONE_MACRO_NAME)
end

local function Keybind(w)
    return w.ns.HearthstoneButton:GetAttribute("macrotext")
end

T.test("without a selection the default Hearthstone is used by item ID", function()
    local w, Macro = Setup()
    w.itemCounts[DEFAULT_HEARTHSTONE] = 1
    Macro.UpdateHearthstone()
    T.eq(Body(w), "/use item:6948")
    T.eq(w:MacroIcon(Macro.HEARTHSTONE_MACRO_NAME), Macro.HEARTHSTONE_MACRO_ICON)
    T.eq(Keybind(w), "/use item:6948")
end)

T.test("without any hearthstone the body falls back to its name", function()
    local w, Macro = Setup()
    Macro.UpdateHearthstone()
    T.eq(Body(w), "/use Hearthstone")
end)

T.test("random pick skips other races' and base-item hearthstones", function()
    local w, Macro = Setup()
    w.ns.Constants.KNOWN_HEARTHSTONES = {
        {id = 3001, baseItem = true},
        {id = 3002, races = {3}},
        {id = 3003, races = {1, 3}},
    }
    w.races[1], w.races[3] = "Human", "Dwarf"
    for _, id in ipairs({3001, 3002, 3003}) do w:AddToy(id) end
    Macro.UpdateHearthstone()
    T.eq(Body(w), "/use item:3003")
end)

T.test("a selected hearthstone shows its tooltip and icon", function()
    local w, Macro = Setup()
    w.activeOutfitID = 7
    w:SetOutfit(7, {Hearthstones = {2001}})
    Macro.UpdateHearthstone()
    T.eq(Body(w), "#showtooltip\n/use item:2001")
    T.eq(w:MacroIcon(Macro.HEARTHSTONE_MACRO_NAME), 777)
    T.eq(Keybind(w), "/use item:2001")
    T.eq(w.env.FitterCharacterSaved.LastActiveOutfitID, 7)
end)

T.test("the former single-selection field still works", function()
    local w, Macro = Setup()
    w.activeOutfitID = 7
    w:SetOutfit(7, {Hearthstone = 2002})
    Macro.UpdateHearthstone()
    T.eq(Body(w), "#showtooltip\n/use item:2002")
end)

T.test("the last active outfit is used when none is active", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastActiveOutfitID = 7
    w:SetOutfit(7, {Hearthstones = {2002}})
    Macro.UpdateHearthstone()
    T.eq(Body(w), "#showtooltip\n/use item:2002")
end)

T.test("selection without the tooltip option", function()
    local w, Macro = Setup()
    w.env.FitterSaved.ShowTooltipHearthstone = false
    w.activeOutfitID = 7
    w:SetOutfit(7, {Hearthstones = {2001}})
    Macro.UpdateHearthstone()
    T.eq(Body(w), "/use item:2001")
    T.eq(w:MacroIcon(Macro.HEARTHSTONE_MACRO_NAME), 777)
end)

T.test("an unowned selection falls back to a random hearthstone", function()
    local w, Macro = Setup()
    w.activeOutfitID = 7
    w:SetOutfit(7, {Hearthstones = {9999}})
    w.itemCounts[DEFAULT_HEARTHSTONE] = 1
    w.itemIcons[DEFAULT_HEARTHSTONE] = 134414
    Macro.UpdateHearthstone()
    T.eq(Body(w), "#showtooltip\n/use item:6948")
end)

T.test("modifier hearthstones and housing teleports", function()
    local w, Macro = Setup()
    w.activeOutfitID = 7
    w:SetOutfit(7, {Hearthstones = {2001}})
    w.env.FitterSaved.ShiftHearthstoneCondition = 2002
    w.env.FitterSaved.CtrlHearthstoneCondition = 9999 -- not owned, so skipped
    w.env.FitterSaved.AltHearthstoneCondition = "alliance"
    w.ns.Housing = {
        GetMacroAction = function(key)
            return key == "alliance" and "/click FitterHousingAlliance" or nil
        end,
    }
    Macro.UpdateHearthstone()
    T.eq(Body(w),
        "#showtooltip\n"
        .. "/click [mod:alt] FitterHousingAlliance\n"
        .. "/stopmacro [mod:alt]\n"
        .. "/use [mod:shift] item:2002; item:2001")
    T.eq(Keybind(w),
        "/click [mod:alt] FitterHousingAlliance\n"
        .. "/stopmacro [mod:alt]\n"
        .. "/use [mod:shift] item:2002; item:2001")
end)

T.test("shaman uses Astral Recall while the hearthstone is on cooldown", function()
    local w, Macro = Setup()
    w.ns.state.playerClass = "SHAMAN"
    w.env.FitterSaved.AstralRecallFallback = true
    w.spellIcons[556] = 136010
    w.activeOutfitID = 7
    w:SetOutfit(7, {Hearthstones = {2001}})
    w.cooldowns[2001] = {900, 1800}
    Macro.UpdateHearthstone()
    T.eq(Body(w), "#showtooltip\n/use Astral Recall")
    T.eq(w:MacroIcon(Macro.HEARTHSTONE_MACRO_NAME), 136010)

    w.time = 5000 -- cooldown over
    Macro.UpdateHearthstone()
    T.eq(Body(w), "#showtooltip\n/use item:2001")
end)

T.test("Astral Recall is only for shamans", function()
    local w, Macro = Setup()
    w.env.FitterSaved.AstralRecallFallback = true
    w.activeOutfitID = 7
    w:SetOutfit(7, {Hearthstones = {2001}})
    w.cooldowns[2001] = {900, 1800}
    Macro.UpdateHearthstone()
    T.eq(Body(w), "#showtooltip\n/use item:2001")
end)

T.test("EnsureHearthstone creates the macro and fills it in", function()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    w.ns.state.playerClass = "WARRIOR"
    w.itemCounts[DEFAULT_HEARTHSTONE] = 1
    local Macro = w:LoadMacros().Macro
    Macro.EnsureHearthstone()
    T.eq(w:MacroBody(Macro.HEARTHSTONE_MACRO_NAME), "/use item:6948")
end)
