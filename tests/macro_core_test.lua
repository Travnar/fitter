-- Macro.lua: class bodies, the /outfit prefix and keeping player edits.
local T = require("harness")

local function Setup()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    w:LoadMacros()
    return w, w.ns.Macro
end

T.test("druid body uses English spell names when the lookup fails", function()
    local _, Macro = Setup()
    T.eq(Macro.GetDruidMacroBody(),
        "/stopmacro [flying,combat]\n"
        .. "/run FitM()\n"
        .. "/cast [indoors,noform:2]Cat Form;"
        .. "[nocombat,outdoors,advflyable,noform:3][swimming,noform:3]Travel Form;"
        .. "[outdoors,noform:3]Mount Form")
end)

T.test("druid body uses the client's localized spell names", function()
    local w, Macro = Setup()
    w.spells[768] = {name = "Forma felina"}
    w.spells[783] = {name = "Forma de viaje"}
    w.spells[210053] = {name = "Forma de montura"}
    local body = Macro.GetDruidMacroBody()
    T.contains(body, "[indoors,noform:2]Forma felina;")
    T.contains(body, "[swimming,noform:3]Forma de viaje;")
    T.contains(body, "[outdoors,noform:3]Forma de montura")
    T.notContains(body, "Cat Form")
end)

T.test("shaman and monk bodies", function()
    local w, Macro = Setup()
    T.eq(Macro.GetShamanMacroBody(),
        "/stopmacro [flying,combat]\n/run FitM()\n/cast [noform:1]Ghost Wolf")
    w.spells[125883] = {name = "Vuelo zen"}
    T.eq(Macro.GetMonkMacroBody(),
        "/stopmacro [flying,combat]\n/run FitM()\n/cast [nochanneling]Vuelo zen")
end)

T.test("outfit prefix is empty without a target outfit", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 7, playerFacingOutfitIndex = 2}}
    T.eq(Macro.GetOutfitMacroPrefix(), "")
end)

T.test("outfit prefix uses the player-facing index", function()
    local w, Macro = Setup()
    w.activeOutfitID = 3
    -- An event entry (Trial of Style) sits first in the array.
    w.outfits = {{outfitID = 99}, {outfitID = 7, playerFacingOutfitIndex = 1}}
    T.eq(Macro.GetOutfitMacroPrefix(7), "/outfit 1\n")
end)

T.test("outfit prefix falls back to the array position", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 5}, {outfitID = 7}}
    T.eq(Macro.GetOutfitMacroPrefix(7), "/outfit 2\n")
end)

T.test("outfit prefix defaults to the current zone outfit", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 5}, {outfitID = 7}}
    w.ns.state.currentZoneOutfitID = 5
    T.eq(Macro.GetOutfitMacroPrefix(), "/outfit 1\n")
end)

T.test("outfit prefix is empty when the outfit is already active", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 7}}
    w.activeOutfitID = 7
    T.eq(Macro.GetOutfitMacroPrefix(7), "")
end)

T.test("outfit prefix is empty while the active outfit is locked", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 7}, {outfitID = 8}}
    w.activeOutfitID = 8
    w.lockedOutfits[8] = true
    T.eq(Macro.GetOutfitMacroPrefix(7), "")
end)

T.test("outfit prefix is empty for an unknown outfit", function()
    local w, Macro = Setup()
    w.outfits = {{outfitID = 7}}
    T.eq(Macro.GetOutfitMacroPrefix(42), "")
end)

T.test("modifier condition joins every ground mount modifier", function()
    local w, Macro = Setup()
    T.eq(Macro.GetModifierCondition(), nil, "no conditionals")
    w.env.FitterCharacterSaved.MountConditionals = {
        {condition = "shift", kind = "ground"},
        {condition = "alt", kind = "ground"},
    }
    local check, positive, negative = Macro.GetModifierCondition()
    T.eq(check, "IsShiftKeyDown()orIsAltKeyDown()")
    T.eq(positive, "shift][mod:alt")
    T.eq(negative, "nomod:shift,nomod:alt")
end)

-- ApplyPreservation keeps lines the player added to a generated macro.

T.test("preservation stores the generated body on first use", function()
    local w, Macro = Setup()
    w:AddMacro(Macro.MOUNT_MACRO_NAME, "/run FitM()")
    T.eq(Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, "/run FitM()", "LastMountMacroBody"),
        "/run FitM()")
    T.eq(w.env.FitterCharacterSaved.LastMountMacroBody, "/run FitM()")
end)

T.test("preservation keeps a line the player appended", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastMountMacroBody = "/run FitM()"
    w:AddMacro(Macro.MOUNT_MACRO_NAME, "/run FitM()\n/say Off we go")
    T.eq(Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, "/outfit 2\n/run FitM()", "LastMountMacroBody"),
        "/outfit 2\n/run FitM()\n/say Off we go")
end)

T.test("preservation keeps a line the player prepended", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastMountMacroBody = "/run FitM()"
    w:AddMacro(Macro.MOUNT_MACRO_NAME, "/dismount\n/run FitM()")
    T.eq(Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, "/run FitM()", "LastMountMacroBody"),
        "/run FitM()\n/dismount")
end)

T.test("preservation keeps edits mixed into generated lines", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastMountMacroBody = "#showtooltip Horse\n/run FitM()"
    w:AddMacro(Macro.MOUNT_MACRO_NAME, "#showtooltip Horse\n/sit\n/run FitM()")
    T.eq(Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, "/run FitM()", "LastMountMacroBody"),
        "/run FitM()\n/sit")
end)

T.test("preservation drops catalog toy lines left in the mount macro", function()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {LastMountMacroBody = "/run FitM()"}
    w.ns.Constants.KNOWN_TOYS = {{id = 1001}}
    local Macro = w:LoadMacros().Macro
    w:AddMacro(Macro.MOUNT_MACRO_NAME, "/use item:1001\n/use item:2002\n/run FitM()")
    -- 1001 is in the catalog so it was generated; 2002 is the player's.
    T.eq(Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, "/run FitM()", "LastMountMacroBody"),
        "/run FitM()\n/use item:2002")
end)

T.test("preservation is skipped with RemoveMacroChangesOnUpdate", function()
    local w, Macro = Setup()
    w.env.FitterSaved.RemoveMacroChangesOnUpdate = true
    w.env.FitterCharacterSaved.LastMountMacroBody = "/run FitM()"
    w:AddMacro(Macro.MOUNT_MACRO_NAME, "/run FitM()\n/say hi")
    T.eq(Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, "/run FitM()", "LastMountMacroBody"),
        "/run FitM()")
    T.eq(Macro.GetUserAdditionsLength(Macro.MOUNT_MACRO_NAME, "LastMountMacroBody"), 0)
end)

T.test("preservation is skipped while rebuilding for a new character", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastMountMacroBody = "/run FitM()"
    w:AddMacro(Macro.MOUNT_MACRO_NAME, "/run FitM()\n/say hi")
    Macro.rebuildForCharacter = true
    T.eq(Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, "/run FitM()", "LastMountMacroBody"),
        "/run FitM()")
end)

T.test("user additions length counts the separator", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastMountMacroBody = "/run FitM()"
    w:AddMacro(Macro.MOUNT_MACRO_NAME, "/run FitM()\n/say hi")
    -- "\n/say hi" plus the separator ApplyPreservation may insert.
    T.eq(Macro.GetUserAdditionsLength(Macro.MOUNT_MACRO_NAME, "LastMountMacroBody"), 9)
end)

T.test("preserved lines that do not fit are dropped whole", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastMountMacroBody = "/run FitM()"
    w:AddMacro(Macro.MOUNT_MACRO_NAME, "/run FitM()\n/say one\n/say two")
    local generated = string.rep("a", 255 - 10) -- room for "\n/say one" only
    local body = Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, generated, "LastMountMacroBody")
    T.eq(body, generated .. "\n/say one")
    T.atMost(#body, 255, "body length")
end)

T.test("generated bodies are cut to 255 characters", function()
    local w, Macro = Setup()
    local body = Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, string.rep("x", 300), "LastMountMacroBody")
    T.eq(#body, 255)
    T.eq(#w.env.FitterCharacterSaved.LastMountMacroBody, 255)
end)

T.test("legacy macro names are renamed in place", function()
    local w, Macro = Setup()
    w:AddMacro("FitterMount", "/run FitM()")
    w:AddMacro("Fitter Update", "/run FitU()", nil, true)
    Macro.MigrateLegacyNames()
    T.eq(w:MacroBody(Macro.MOUNT_MACRO_NAME), "/run FitM()")
    T.eq(w:MacroBody(Macro.OUTFIT_UPDATE_MACRO_NAME), "/run FitU()")
    T.eq(w:MacroBody("FitterMount"), nil)
end)
