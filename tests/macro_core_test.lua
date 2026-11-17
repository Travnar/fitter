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
        .. "[swimming,noform:3][outdoors,noform:3]Travel Form")
end)

T.test("druid body uses the client's localized spell names", function()
    local w, Macro = Setup()
    w.spells[768] = {name = "Forma felina"}
    w.spells[783] = {name = "Forma de viaje"}
    local body = Macro.GetDruidMacroBody()
    T.contains(body, "[indoors,noform:2]Forma felina;")
    T.contains(body, "[swimming,noform:3][outdoors,noform:3]Forma de viaje")
    T.notContains(body, "Cat Form")
end)

T.test("Forever druid body numbers forms by stance bar order", function()
    local w, Macro = Setup()
    w.ns.Features.DruidMountForm = false
    w.shapeshiftForms = {5487, 1066, 768, 783}
    T.eq(Macro.GetDruidMacroBody(),
        "/stopmacro [flying,combat]\n"
        .. "/run FitM()\n"
        .. "/cast [indoors,noform:3]Cat Form;[swimming,noform:2]Aquatic Form;"
        .. "[outdoors,noform:4]Travel Form")
end)

T.test("Forever druid body leaves out forms not learned yet", function()
    local w, Macro = Setup()
    w.ns.Features.DruidMountForm = false
    w.shapeshiftForms = {5487, 1066}
    T.eq(Macro.GetDruidMacroBody(),
        "/stopmacro [flying,combat]\n/run FitM()\n/cast [swimming,noform:2]Aquatic Form")
    T.eq(Macro.GetDruidFormLayout(), "0,2,0")
    w.shapeshiftForms = {}
    T.eq(Macro.GetDruidMacroBody(), "/stopmacro [flying,combat]\n/run FitM()")
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

-- The Macro window can save an older generated body back, so lines Fitter
-- writes itself are never kept as player edits.

T.test("preservation drops stale generated lines", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastMountMacroBody = "#showtooltip Gryphon\n/outfit 3\n/run FitM()"
    w:AddMacro(Macro.MOUNT_MACRO_NAME,
        "#showtooltip Horse\n/cancelaura Bubbles\n/outfit 2\n/run FitterMount()\n/say hi")
    T.eq(Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, "/run FitM()", "LastMountMacroBody"),
        "/run FitM()\n/say hi")
end)

T.test("preservation keeps the player's /cancelaura in other macros", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.LastHearthstoneMacroBody = "/use item:6948"
    w:AddMacro(Macro.HEARTHSTONE_MACRO_NAME, "#showtooltip\n/cancelaura Ghost Wolf\n/use item:6948")
    T.eq(Macro.ApplyPreservation(Macro.HEARTHSTONE_MACRO_NAME, "/use item:1", "LastHearthstoneMacroBody"),
        "/use item:1\n/cancelaura Ghost Wolf")
end)

T.test("preservation reads the macro at the given index", function()
    local w, Macro = Setup()
    w.env.FitterCharacterSaved.Stored = "/run FitU()"
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "/run FitU()")
    w:AddMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "/run FitU()\n/cast Charge", nil, true)
    local accountIndex, characterIndex = Macro.FindIndexes(Macro.OUTFIT_UPDATE_MACRO_NAME)
    T.eq(accountIndex, 1)
    T.eq(characterIndex, 121)
    T.eq(Macro.GetUserAdditionsLength(Macro.OUTFIT_UPDATE_MACRO_NAME, "Stored", characterIndex), 14)
    T.eq(Macro.ApplyPreservation(Macro.OUTFIT_UPDATE_MACRO_NAME, "/outfit 2\n/run FitU()",
        "Stored", characterIndex), "/outfit 2\n/run FitU()\n/cast Charge")
end)

-- ComposeBody drops the least important lines first when a body is too long.

T.test("compose orders the sections", function()
    local _, Macro = Setup()
    T.eq(Macro.ComposeBody({
        action = "/run FitM()",
        outfit = "/outfit 2\n",
        conditionals = "/cast [mod:shift]Blink\n/stopmacro [mod:shift]\n",
        hunterPet = "/cast Call Pet 1",
        toys = "/use item:1\n/use item:2",
        cancel = "/cancelaura Bubbles",
        tooltip = "#showtooltip Horse",
    }), "#showtooltip Horse\n/cancelaura Bubbles\n/use item:1\n/use item:2\n/cast Call Pet 1\n"
        .. "/cast [mod:shift]Blink\n/stopmacro [mod:shift]\n/outfit 2\n/run FitM()")
end)

T.test("compose drops the tooltip, then toys, before anything else", function()
    local _, Macro = Setup()
    local conditionals = "/cast " .. string.rep("c", 170)
    local spec = {
        action = "/run FitM()",
        outfit = "/outfit 2",
        conditionals = conditionals,
        hunterPet = "/cast Call Pet 1",
        toys = "/use item:10001\n/use item:10002\n/use item:10003",
        tooltip = "#showtooltip A Mount With A Long Name",
    }
    T.eq(Macro.ComposeBody(spec),
        "/use item:10001\n/use item:10002\n/cast Call Pet 1\n" .. conditionals .. "\n/outfit 2\n/run FitM()")
    -- Room kept for the player's lines comes out of the optional lines only.
    T.eq(Macro.ComposeBody(spec, 45), conditionals .. "\n/outfit 2\n/run FitM()")
end)

T.test("compose keeps the action when the lines before it are too long", function()
    local _, Macro = Setup()
    local body = Macro.ComposeBody({
        action = "/stopmacro [flying,combat]\n/run FitM()\n/cast " .. string.rep("d", 140),
        outfit = "/outfit 2",
        conditionals = "/cast " .. string.rep("c", 170),
        tooltip = "#showtooltip Horse",
    })
    T.atMost(#body, 255, "body length")
    T.contains(body, "/run FitM()")
    T.notContains(body, "ccc")
    T.contains(body, "/outfit 2\n/stopmacro")
end)

-- Edits wait while Blizzard's Macro window is open.

T.test("the Macro window defers edits until it closes", function()
    local w, Macro = Setup()
    w.ns.state.playerClass = "WARRIOR"
    w.ns.Mount.SelectNext = function() return nil end
    w.itemCounts[6948] = 1
    w:AddMacro(Macro.HEARTHSTONE_MACRO_NAME, "/use Hearthstone")
    w.ns.HearthstoneButton = T.NewButton()
    local shown = true
    w.env.MacroFrame = {IsShown = function() return shown end}

    Macro.UpdateHearthstone()
    T.eq(#w.edits, 0, "edits while open")
    T.eq(w.env.FitterCharacterSaved.LastHearthstoneMacroBody, nil, "stored body while open")
    T.eq(w.ns.HearthstoneButton:GetAttribute("macrotext"), "/use item:6948", "key binding")

    shown = false
    Macro.OnEditorHidden()
    for _, timer in ipairs(w.timers) do timer.fn() end
    T.eq(w:MacroBody(Macro.HEARTHSTONE_MACRO_NAME), "/use item:6948")
end)
