-- MountConditionals.lua: the /cast and /stopmacro lines ahead of the summon.
local T = require("harness")

local function Setup(characterList, accountList)
    local w = T.NewWorld()
    w.env.FitterSaved = {MountConditionals = accountList or {}}
    w.env.FitterCharacterSaved = {MountConditionals = characterList or {}}
    w:LoadMacros()
    return w, w.ns.MountConditionals
end

T.test("no conditionals gives no lines", function()
    local _, Conditionals = Setup()
    T.eq(Conditionals.GetMacroLines(), "")
end)

T.test("spell, toy and mount conditionals become one /cast line", function()
    local w, Conditionals = Setup({
        {condition = "shift", kind = "spell", id = 1953, name = "Blink"},
        {condition = "indoors", kind = "toy", id = 54452},
        {condition = "swimming", kind = "mount", id = 312, name = "Sea Turtle"},
    })
    w.knownSpells[1953] = true
    w.spells[1953] = {name = "Parpadeo"}
    w:AddToy(54452)
    w.mounts[312] = {name = "Sea Turtle", spellID = 64731}
    w.spells[64731] = {name = "Tortuga marina"}
    T.eq(Conditionals.GetMacroLines(),
        "/cast [mod:shift]Parpadeo;[indoors]item:54452;[swimming]Tortuga marina\n"
        .. "/stopmacro [mod:shift][indoors][swimming]\n")
end)

T.test("a character conditional overrides the account one", function()
    local w, Conditionals = Setup(
        {{condition = "combat", kind = "spell", id = 2, name = "Character Spell"}},
        {{condition = "combat", kind = "spell", id = 3, name = "Account Spell"},
         {condition = "alt", kind = "spell", id = 3, name = "Account Spell"}})
    w.knownSpells[2], w.knownSpells[3] = true, true
    T.eq(Conditionals.GetMacroLines(),
        "/cast [combat]Character Spell;[mod:alt]Account Spell\n"
        .. "/stopmacro [combat][mod:alt]\n")
end)

T.test("abilities and toys the character lacks are skipped", function()
    local w, Conditionals = Setup(nil, {
        {condition = "shift", kind = "spell", id = 2, name = "Unknown Spell"},
        {condition = "ctrl", kind = "toy", id = 3},
        {condition = "alt", kind = "spell", id = 4, name = "Known Spell"},
    })
    w.knownSpells[4] = true
    T.eq(Conditionals.GetMacroLines(), "/cast [mod:alt]Known Spell\n/stopmacro [mod:alt]\n")
end)

T.test("ground mount and falling entries add no /cast lines", function()
    local w, Conditionals = Setup({
        {condition = "shift", kind = "ground"},
        {condition = "falling", kind = "spell", id = 130, name = "Slow Fall"},
    })
    w.knownSpells[130] = true
    T.eq(Conditionals.GetMacroLines(), "")
end)
