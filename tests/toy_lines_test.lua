-- Toy.lua: /use and /cancelaura lines added to the mount and update macros.
local T = require("harness")

local function Setup()
    local w = T.NewWorld()
    w.env.FitterSaved = {}
    w.env.FitterCharacterSaved = {}
    w:Load({"Toy.lua"})
    return w, w.ns.Toy
end

T.test("no lines without outfit toys", function()
    local w, Toy = Setup()
    T.eq(Toy.GetMacroLines(nil), nil)
    T.eq(Toy.GetMacroLines(7), nil)
    w:SetOutfit(7, {Toys = {}})
    T.eq(Toy.GetMacroLines(7), nil)
end)

T.test("skips toys that are active, on cooldown or unusable", function()
    local w, Toy = Setup()
    w:AddToy(1, {spell = "Active Effect"})
    w:AddToy(2)
    w:AddToy(3, {usable = false})
    w:AddToy(4)
    w:AddToy(5)
    w.auras["Active Effect"] = true
    w.cooldowns[2] = {990, 60}
    w:SetOutfit(7, {Toys = {1, 2, 3, 4, 5}})
    T.eq(Toy.GetMacroLines(7), "/use item:4\n/use item:5")
end)

T.test("an expired cooldown does not block a toy", function()
    local w, Toy = Setup()
    w:AddToy(2)
    w.cooldowns[2] = {100, 60}
    w:SetOutfit(7, {Toys = {2}})
    T.eq(Toy.GetMacroLines(7), "/use item:2")
end)

T.test("toy lines stop at the length limit", function()
    local w, Toy = Setup()
    for id = 10001, 10003 do w:AddToy(id) end
    w:SetOutfit(7, {Toys = {10001, 10002, 10003}})
    -- Each line is 15 characters; two lines and a newline are 31.
    T.eq(Toy.GetMacroLines(7, 31), "/use item:10001\n/use item:10002")
    T.eq(Toy.GetMacroLines(7, 30), "/use item:10001")
    T.eq(Toy.GetMacroLines(7, 14), nil)
end)

T.test("cancel lines are off unless the option is set", function()
    local w, Toy = Setup()
    w.ns.Constants.KNOWN_TOYS = {{id = 1}}
    w:AddToy(1, {spell = "Bubbles"})
    w.auras["Bubbles"] = true
    T.eq(Toy.GetCancelLines(7), nil)
end)

T.test("cancels active catalog toys the outfit does not use", function()
    local w, Toy = Setup()
    w.env.FitterSaved.CancelNonOutfitToys = true
    w.env.FitterSaved.CustomToys = {3}
    Toy.KNOWN_TOYS = {{id = 1}, {id = 2}, {id = 4}}
    w:AddToy(1, {spell = "Bubbles"})
    w:AddToy(2, {spell = "Kept"})
    w:AddToy(3, {spell = "Custom Glow"})
    w:AddToy(4, {spell = "Inactive"})
    w.auras["Bubbles"], w.auras["Kept"], w.auras["Custom Glow"] = true, true, true
    w:SetOutfit(7, {Toys = {2}})
    T.eq(Toy.GetCancelLines(7), "/cancelaura Bubbles\n/cancelaura Custom Glow")
    T.eq(Toy.GetCancelLines(7, 25), "/cancelaura Bubbles")
end)
