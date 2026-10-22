-- Macro/Mount.lua: the "Outfit Mount" macro and the mount key binding.
local T = require("harness")

local MOUNT_ID = 100

local function Setup()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    w.ns.state.playerClass = "WARRIOR"
    w.mounts[MOUNT_ID] = {name = "Swift Horse", spellID = 23229, icon = 555}
    w:LoadMacros()
    return w, w.ns.Macro
end

local function SetGroundModifier(w, key)
    w.env.FitterCharacterSaved.MountConditionals = {{condition = key, kind = "ground"}}
end

T.test("regular mount shows its tooltip and icon", function()
    local _, Macro = Setup()
    local body, icon = Macro.BuildMountMacroBody(MOUNT_ID)
    T.eq(body, "#showtooltip Swift Horse\n/run FitM()")
    T.eq(icon, 555)
end)

T.test("regular mount without the tooltip option", function()
    local w, Macro = Setup()
    w.env.FitterSaved.ShowTooltipMount = false
    local body, icon = Macro.BuildMountMacroBody(MOUNT_ID)
    T.eq(body, "/run FitM()")
    T.eq(icon, Macro.MOUNT_MACRO_ICON)
end)

T.test("key binding body never has a tooltip", function()
    local _, Macro = Setup()
    T.eq(Macro.BuildMountMacroBody(MOUNT_ID, false), "/run FitM()")
end)

T.test("conditional lines and /outfit come before the summon", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.MountConditionals = {
        {condition = "shift", kind = "spell", id = 1953, name = "Blink"},
    }
    w.knownSpells[1953] = true
    w.outfits = {{outfitID = 5}, {outfitID = 7}}
    w.ns.state.currentZoneOutfitID = 7
    T.eq(Macro.BuildMountMacroBody(MOUNT_ID),
        "#showtooltip Swift Horse\n"
        .. "/cast [mod:shift]Blink\n"
        .. "/stopmacro [mod:shift]\n"
        .. "/outfit 2\n"
        .. "/run FitM()")
end)

T.test("druid macro replaces the summon, except for G-99 Breakneck", function()
    local w, Macro = Setup()
    w.ns.state.playerClass = "DRUID"
    w.env.FitterSaved.UseDruidMacro = true
    T.eq(Macro.BuildMountMacroBody(MOUNT_ID), Macro.GetDruidMacroBody())
    T.eq(Macro.BuildMountMacroBody("g99breakneck"),
        "#showtooltip G-99 Breakneck\n/cast G-99 Breakneck")
end)

T.test("class macro options only apply to their class", function()
    local w, Macro = Setup()
    w.env.FitterSaved.UseShamanMacro = true
    w.env.FitterSaved.UseMonkMacro = true
    T.eq(Macro.BuildMountMacroBody(MOUNT_ID), "#showtooltip Swift Horse\n/run FitM()")
    w.ns.state.playerClass = "MONK"
    T.eq(Macro.BuildMountMacroBody(MOUNT_ID), Macro.GetMonkMacroBody())
end)

T.test("Soar casts the localized spell with its icon", function()
    local w, Macro = Setup()
    w.spells[369536] = {name = "Elevarse", iconID = 4622}
    local body, icon = Macro.BuildMountMacroBody("soar")
    T.eq(body, "#showtooltip Elevarse\n/cast Elevarse")
    T.eq(icon, 4622)
end)

T.test("Soar with a ground mount modifier", function()
    local w, Macro = Setup()
    SetGroundModifier(w, "shift")
    T.eq(Macro.BuildMountMacroBody("soar"),
        "#showtooltip Soar\n"
        .. "/run if IsShiftKeyDown()then FitG()end\n"
        .. "/cast [nomod:shift]Soar")
end)

T.test("Soar when Running Wild is the only ground mount", function()
    local w, Macro = Setup()
    SetGroundModifier(w, "alt")
    w.mountOutfitID = 7
    w:SetOutfit(7, {Ground = {"runningwild"}})
    T.eq(Macro.BuildMountMacroBody("soar"),
        "#showtooltip Soar\n"
        .. "/cast [mod:alt]Running Wild\n"
        .. "/cast [nomod:alt]Soar")
end)

T.test("regular mount when Running Wild is the only ground mount", function()
    local w, Macro = Setup()
    SetGroundModifier(w, "shift")
    w.mountOutfitID = 7
    w:SetOutfit(7, {Ground = {"runningwild", "soar"}})
    T.eq(Macro.BuildMountMacroBody(MOUNT_ID),
        "#showtooltip Swift Horse\n"
        .. "/run if not(IsShiftKeyDown())then FitM()end\n"
        .. "/cast [mod:shift]Running Wild")
end)

T.test("mixed ground list rolls Running Wild for the modifier", function()
    local w, Macro = Setup()
    SetGroundModifier(w, "shift")
    w.mountOutfitID = 7
    w:SetOutfit(7, {Ground = {101, "runningwild"}})
    w.randomResults = {2}
    T.eq(Macro.BuildMountMacroBody(MOUNT_ID),
        "#showtooltip Swift Horse\n"
        .. "/run if not(IsShiftKeyDown())then FitM()end\n"
        .. "/cast [mod:shift]Running Wild")
end)

T.test("mixed ground list rolls a regular mount for the modifier", function()
    local w, Macro = Setup()
    SetGroundModifier(w, "shift")
    w.mountOutfitID = 7
    w:SetOutfit(7, {Ground = {101, "runningwild"}})
    w.randomResults = {1}
    T.eq(Macro.BuildMountMacroBody(MOUNT_ID), "#showtooltip Swift Horse\n/run FitM()")
    w.randomResults = {1}
    T.eq(Macro.BuildMountMacroBody("runningwild"),
        "#showtooltip Running Wild\n"
        .. "/run if IsShiftKeyDown()then FitG()end\n"
        .. "/cast Running Wild")
end)

T.test("G-99 Breakneck with a ground mount modifier", function()
    local w, Macro = Setup()
    SetGroundModifier(w, "ctrl")
    T.eq(Macro.BuildMountMacroBody("g99breakneck"),
        "#showtooltip G-99 Breakneck\n"
        .. "/run if IsControlKeyDown()then FitM()end\n"
        .. "/cast [nomod:ctrl]G-99 Breakneck")
end)

-- UpdateMacroForMount assembles the full body.

local function SetupUpdate()
    local w = T.NewWorld()
    w.env.FitterSaved = {CancelNonOutfitToys = true}
    w.env.FitterCharacterSaved = {}
    w.ns.state.playerClass = "HUNTER"
    w.mounts[MOUNT_ID] = {name = "Swift Horse", spellID = 23229, icon = 555}
    w.ns.Constants.KNOWN_TOYS = {{id = 1001}, {id = 1002}}
    w:AddToy(1001, {spell = "Bubbles"})
    w:AddToy(1002, {spell = "Sparkles"})
    w.auras["Bubbles"] = true
    w.mountOutfitID = 7
    w:SetOutfit(7, {Toys = {1002}})
    local ns = w:LoadMacros()
    ns.HunterPet = {GetMountMacroLines = function() return "/cast Call Pet 1" end}
    ns.MountButton = T.NewButton()
    w:AddMacro(ns.Macro.MOUNT_MACRO_NAME, "/run FitM()")
    return w, ns.Macro
end

T.test("full mount macro: cancel, toy and pet lines go first", function()
    local w, Macro = SetupUpdate()
    Macro.UpdateMacroForMount(MOUNT_ID)
    -- #showtooltip is not the first line here (MACRO_HARDENING.md, low priority).
    T.eq(w:MacroBody(Macro.MOUNT_MACRO_NAME),
        "/cancelaura Bubbles\n"
        .. "/use item:1002\n"
        .. "/cast Call Pet 1\n"
        .. "#showtooltip Swift Horse\n"
        .. "/run FitM()")
    T.eq(w:MacroIcon(Macro.MOUNT_MACRO_NAME), 555)
    T.eq(w.ns.MountButton:GetAttribute("macrotext"),
        "/cancelaura Bubbles\n/use item:1002\n/cast Call Pet 1\n/run FitM()")
    T.eq(w.ns.state.mountButtonBody, w.ns.MountButton:GetAttribute("macrotext"))
end)

T.test("an unchanged macro is not edited again", function()
    local w, Macro = SetupUpdate()
    Macro.UpdateMacroForMount(MOUNT_ID)
    Macro.UpdateMacroForMount(MOUNT_ID)
    T.eq(#w.edits, 1, "EditMacro calls")
    T.eq(w.ns.MountButton.setCount, 1, "SetAttribute calls")
end)

T.test("player lines survive a mount update", function()
    local w, Macro = SetupUpdate()
    Macro.UpdateMacroForMount(MOUNT_ID)
    local macro = w.MacroAt(Macro.MOUNT_MACRO_NAME)
    macro.body = macro.body .. "\n/say Giddy up"
    w.mounts[200] = {name = "Gryphon", spellID = 1, icon = 666}
    Macro.UpdateMacroForMount(200)
    T.eq(w:MacroBody(Macro.MOUNT_MACRO_NAME),
        "/cancelaura Bubbles\n/use item:1002\n/cast Call Pet 1\n"
        .. "#showtooltip Gryphon\n/run FitM()\n/say Giddy up")
end)

T.test("the key binding is left alone while falling", function()
    local w, Macro = SetupUpdate()
    w.ns.MountConditionals.IsFallingActive = function() return true end
    w.ns.MountButton:SetAttribute("macrotext", "/cast Slow Fall")
    Macro.UpdateMacroForMount(MOUNT_ID)
    T.eq(w.ns.MountButton:GetAttribute("macrotext"), "/cast Slow Fall")
    T.eq(w.ns.state.mountButtonBody,
        "/cancelaura Bubbles\n/use item:1002\n/cast Call Pet 1\n/run FitM()")
end)

T.test("nothing is edited in combat", function()
    local w, Macro = SetupUpdate()
    local pending = false
    w.ns.MarkMacroRefreshPending = function() pending = true end
    w.inCombat = true
    Macro.UpdateMacroForMount(MOUNT_ID)
    T.eq(#w.edits, 0)
    T.truthy(pending, "refresh marked pending")
end)

T.test("toy lines are trimmed to fit 255 characters", function()
    local w, Macro = SetupUpdate()
    local toys = {}
    for i = 1, 30 do
        local id = 50000 + i
        w:AddToy(id)
        toys[#toys + 1] = id
    end
    w:SetOutfit(7, {Toys = toys})
    w.mounts[MOUNT_ID].name = string.rep("Long Name ", 5)
    Macro.UpdateMacroForMount(MOUNT_ID)
    local body = w:MacroBody(Macro.MOUNT_MACRO_NAME)
    T.atMost(#body, 255, "macro length")
    T.truthy(body:find("\n/run FitM%(%)$"), "summon line kept: " .. T.Show(body))
    T.contains(body, "/use item:50001\n")
    T.notContains(body, "item:50030")
    T.atMost(#w.ns.MountButton:GetAttribute("macrotext"), 255, "binding length")
end)
