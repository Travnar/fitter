-- Mount.lua: FitM() and FitG(), the functions the mount macro runs.
local T = require("harness")

local MOUNT_ID = 100

local function Setup()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    w.mounts[MOUNT_ID] = {name = "Swift Horse", spellID = 23229, icon = 555}
    w.summoned, w.errors, w.dismounts = {}, {}, 0
    w.mounted = false

    local env = w.env
    env.IsMounted = function() return w.mounted end
    env.Dismount = function() w.dismounts = w.dismounts + 1 end
    env.IsSubmerged = function() return false end
    env.IsFlyableArea = function() return false end
    env.UnitIsPlayer = function() return false end
    env.geterrorhandler = function()
        return function(err) w.errors[#w.errors + 1] = err end
    end
    env.C_MountJournal.SummonByID = function(mountID) w.summoned[#w.summoned + 1] = mountID end
    env.C_MountJournal.GetMountInfoExtraByID = function() return nil, nil, nil, nil, 230 end
    env.C_MountJournal.GetMountUsabilityByID = function() return true end

    local ns = w.ns
    ns.Toy = {ScheduleMacroRefresh = function() end}
    ns.Title = {Apply = function() end}
    w:Load({"Controllers/Mount.lua"})
    return w
end

T.test("FitM summons a mount when no outfit is active", function()
    local w = Setup()
    w.env.FitM()
    T.eq(w.summoned[1], MOUNT_ID)
    T.eq(#w.errors, 0)
end)

T.test("FitM dismounts when mounted", function()
    local w = Setup()
    w.mounted = true
    w.env.FitM()
    T.eq(w.dismounts, 1)
    T.eq(#w.summoned, 0)
end)

T.test("an error in FitM falls back to a random favorite mount", function()
    local w = Setup()
    w.ns.Toy.ScheduleMacroRefresh = function() error("boom") end
    w.env.FitM()
    T.eq(#w.summoned, 1)
    T.eq(w.summoned[1], 0)
    T.contains(w.errors[1], "boom")
end)

T.test("an error in FitM while mounted still dismounts", function()
    local w = Setup()
    w.mounted = true
    w.ns.Toy.ScheduleMacroRefresh = function() error("boom") end
    w.env.FitM()
    T.eq(w.dismounts, 1)
    T.eq(#w.summoned, 0)
end)

T.test("an error after the summon does not summon again", function()
    local w = Setup()
    w.ns.Title.Apply = function() error("boom") end
    w.env.FitM()
    T.eq(#w.summoned, 1)
    T.eq(w.summoned[1], MOUNT_ID)
    T.eq(#w.errors, 1)
end)

T.test("an error in FitG falls back to a random favorite mount", function()
    local w = Setup()
    w.env.C_MountJournal.GetMountIDs = function() error("boom") end
    w.env.FitG()
    T.eq(w.summoned[1], 0)
    T.eq(#w.errors, 1)
end)

T.test("a ground modifier sends FitM to the ground mount", function()
    local w = Setup()
    w.ns.MountConditionals = {IsGroundModifierHeld = function() return true end}
    w.activeOutfitID = 7
    w:SetOutfit(7, {Ground = {MOUNT_ID}, Flying = {200}})
    w.env.FitM()
    T.eq(w.summoned[1], MOUNT_ID)
end)
