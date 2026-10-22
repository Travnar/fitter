-- Test harness: a small assertion library and a fake WoW client that loads
-- the addon's real source files. Compatible with Lua 5.1 (the game's version)
-- and later.

local T = {}
T.tests = {}

local currentFile

function T.SetFile(name)
    currentFile = name
end

function T.test(name, fn)
    T.tests[#T.tests + 1] = {file = currentFile, name = name, fn = fn}
end

-- Shows newlines and other control characters so macro bodies are readable
-- in failure messages.
local function Show(value)
    if type(value) ~= "string" then return tostring(value) end
    return '"' .. value:gsub("\n", "\\n"):gsub("[%c]", function(c)
        return string.format("\\%d", c:byte())
    end) .. '"'
end
T.Show = Show

local function Fail(message, level)
    error(message, (level or 1) + 2)
end

function T.eq(actual, expected, label)
    if actual ~= expected then
        Fail((label and (label .. ": ") or "")
            .. "\n  expected: " .. Show(expected)
            .. "\n  actual:   " .. Show(actual))
    end
end

function T.truthy(value, label)
    if not value then Fail((label or "expected a truthy value") .. ", got " .. Show(value)) end
end

function T.falsy(value, label)
    if value then Fail((label or "expected a falsy value") .. ", got " .. Show(value)) end
end

function T.contains(haystack, needle, label)
    if type(haystack) ~= "string" or not haystack:find(needle, 1, true) then
        Fail((label and (label .. ": ") or "") .. Show(haystack)
            .. " does not contain " .. Show(needle))
    end
end

function T.notContains(haystack, needle, label)
    if type(haystack) == "string" and haystack:find(needle, 1, true) then
        Fail((label and (label .. ": ") or "") .. Show(haystack)
            .. " should not contain " .. Show(needle))
    end
end

function T.atMost(value, limit, label)
    if value > limit then
        Fail((label or "value") .. " is " .. value .. ", limit is " .. limit)
    end
end

-- Files in the order Fitter.toc loads them.
T.MACRO_FILES = {
    "Macro.lua",
    "Macro/Mount.lua",
    "Macro/Hearthstone.lua",
    "Macro/Update.lua",
    "Macro/Fishing.lua",
}

local function LoadInto(path, env, ...)
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    if not chunk then error(err, 0) end
    return chunk(...)
end

-- An object whose every method is a no-op, for CreateFrame and the like.
local function Inert()
    return setmetatable({}, {__index = function() return function() end end})
end

local function NewButton()
    local attributes = {}
    return {
        attributes = attributes,
        setCount = 0,
        GetAttribute = function(self, key) return attributes[key] end,
        SetAttribute = function(self, key, value)
            self.setCount = self.setCount + 1
            attributes[key] = value
        end,
    }
end
T.NewButton = NewButton

-- Returns a world: fake client state (edit its fields to set up a test),
-- the global environment the addon sees (world.env) and its namespace
-- (world.ns). Load addon files with world:Load().
function T.NewWorld()
    local w = {
        account = {},        -- account macros, {name, icon, body}
        character = {},      -- character macros
        edits = {},          -- EditMacro calls
        spells = {},         -- [spellID] = {name =, iconID =}
        spellIcons = {},     -- [spellID] = texture
        knownSpells = {},    -- [spellID] = true
        mounts = {},         -- [mountID] = {name, spellID, icon, collected}
        outfits = {},        -- C_TransmogOutfitInfo.GetOutfitsInfo()
        lockedOutfits = {},  -- [outfitID] = true
        activeOutfitID = nil,
        mountOutfitID = nil, -- ns.GetMountOutfitID()
        toys = {},           -- [itemID] = {name, icon, usable, spell}
        ownedToys = {},      -- PlayerHasToy
        auras = {},          -- [spellName] = true
        itemCounts = {},     -- C_Item.GetItemCount
        itemIcons = {},
        cooldowns = {},      -- [itemID] = {start, duration}
        races = {},          -- [raceID] = clientFileString
        bindings = {},       -- [command] = key
        time = 1000,
        inCombat = false,
        randomResults = {},  -- queued math.random results; default is the lowest
        printed = {},
        timers = {},
    }

    local env = {}
    w.env = env

    local function FindMacro(name)
        for i, macro in ipairs(w.account) do
            if macro.name == name then return i end
        end
        for i, macro in ipairs(w.character) do
            if macro.name == name then return 120 + i end
        end
        return 0
    end
    local function MacroAt(index)
        if type(index) == "string" then index = FindMacro(index) end
        if index > 120 then return w.character[index - 120] end
        return w.account[index]
    end
    w.MacroAt = MacroAt

    function w:AddMacro(name, body, icon, perCharacter)
        local list = perCharacter and self.character or self.account
        list[#list + 1] = {name = name, icon = icon or 134400, body = body or ""}
        return FindMacro(name)
    end

    function w:MacroBody(name)
        local macro = MacroAt(FindMacro(name))
        return macro and macro.body
    end

    function w:MacroIcon(name)
        local macro = MacroAt(FindMacro(name))
        return macro and macro.icon
    end

    -- Makes a toy that the player owns and can use.
    function w:AddToy(itemID, info)
        info = info or {}
        self.toys[itemID] = {
            name = info.name or ("Toy " .. itemID),
            icon = info.icon or itemID,
            usable = info.usable ~= false,
            spell = info.spell,
        }
        self.ownedToys[itemID] = info.owned ~= false
    end

    -- Saved outfit data, as the transmog UI stores it.
    function w:SetOutfit(outfitID, data)
        self.env.FitterCharacterSaved = self.env.FitterCharacterSaved or {}
        self.env.FitterCharacterSaved["Outfit" .. outfitID] = data
    end

    env.GetMacroIndexByName = FindMacro
    env.GetNumMacros = function() return #w.account, #w.character end
    env.GetMacroInfo = function(index)
        local macro = MacroAt(index)
        if macro then return macro.name, macro.icon, macro.body end
    end
    env.GetMacroBody = function(index)
        local macro = MacroAt(index)
        return macro and macro.body
    end
    env.EditMacro = function(index, name, icon, body)
        local macro = MacroAt(index)
        macro.name, macro.icon, macro.body = name, icon, body
        w.edits[#w.edits + 1] = {name = name, icon = icon, body = body}
    end
    env.CreateMacro = function(name, icon, body, perCharacter)
        w:AddMacro(name, body, icon, perCharacter)
    end
    env.DeleteMacro = function(index)
        if type(index) == "string" then index = FindMacro(index) end
        if index > 120 then
            table.remove(w.character, index - 120)
        else
            table.remove(w.account, index)
        end
    end

    env.InCombatLockdown = function() return w.inCombat end
    env.GetTime = function() return w.time end
    env.UnitClass = function() return nil, w.playerClass end
    env.GetBindingKey = function(command) return w.bindings[command] end
    env.IsPlayerSpell = function(spellID) return w.knownSpells[spellID] == true end
    env.PlayerHasToy = function(itemID) return w.ownedToys[itemID] == true end
    env.CreateFrame = function() return Inert() end
    env.hooksecurefunc = function() end
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        w.printed[#w.printed + 1] = table.concat(parts, " ")
    end
    env.tContains = function(list, value)
        for _, item in ipairs(list or {}) do
            if item == value then return true end
        end
        return false
    end

    env.C_Timer = {
        After = function(delay, fn) w.timers[#w.timers + 1] = {delay = delay, fn = fn} end,
        NewTimer = function(delay, fn)
            w.timers[#w.timers + 1] = {delay = delay, fn = fn}
            return Inert()
        end,
    }

    env.C_Spell = {
        GetSpellInfo = function(spellID)
            local info = w.spells[spellID]
            if not info then return nil end
            return {name = info.name, iconID = info.iconID, spellID = spellID}
        end,
        GetSpellTexture = function(spellID) return w.spellIcons[spellID] end,
    }

    env.C_TransmogOutfitInfo = {
        GetActiveOutfitID = function() return w.activeOutfitID end,
        GetOutfitsInfo = function() return w.outfits end,
        IsLockedOutfit = function(outfitID) return w.lockedOutfits[outfitID] == true end,
    }

    env.C_MountJournal = {
        GetMountInfoByID = function(mountID)
            local m = w.mounts[mountID]
            if not m then return nil end
            return m.name, m.spellID, m.icon, nil, nil, nil, nil, nil, nil, nil,
                m.collected ~= false
        end,
        GetMountIDs = function()
            local ids = {}
            for id in pairs(w.mounts) do ids[#ids + 1] = id end
            table.sort(ids)
            return ids
        end,
    }

    env.C_Item = {
        GetItemCooldown = function(itemID)
            local cd = w.cooldowns[itemID]
            if not cd then return 0, 0 end
            return cd[1], cd[2]
        end,
        GetItemCount = function(itemID) return w.itemCounts[itemID] or 0 end,
        GetItemIconByID = function(itemID) return w.itemIcons[itemID] end,
        GetItemSpell = function(itemID)
            local toy = w.toys[itemID]
            return toy and toy.spell
        end,
    }

    env.C_ToyBox = {
        GetToyInfo = function(itemID)
            local toy = w.toys[itemID]
            if not toy then return nil end
            return itemID, toy.name, toy.icon
        end,
        IsToyUsable = function(itemID)
            local toy = w.toys[itemID]
            return toy ~= nil and toy.usable
        end,
    }

    env.C_UnitAuras = {
        GetAuraDataBySpellName = function(_, spellName)
            if w.auras[spellName] then return {name = spellName} end
            return nil
        end,
    }

    env.C_CreatureInfo = {
        GetRaceInfo = function(raceID)
            local file = w.races[raceID]
            return file and {clientFileString = file} or nil
        end,
    }

    -- math.random is replaced so that random picks are predictable.
    env.math = setmetatable({
        random = function(m, n)
            local queued = table.remove(w.randomResults, 1)
            if queued then return queued end
            if n then return m end
            return 1
        end,
    }, {__index = math})

    setmetatable(env, {__index = _G})

    local ns = {
        state = {},
        L = setmetatable({}, {__index = function(_, key) return key end}),
        Constants = {KNOWN_TOYS = {}, KNOWN_HEARTHSTONES = {}},
        Mount = {MonitorSoarCooldown = function() end},
        GetMountOutfitID = function() return w.mountOutfitID end,
    }
    w.ns = ns

    function w:Load(files)
        for _, file in ipairs(files) do
            LoadInto(T.root .. file, env, "Fitter", ns)
        end
        return ns
    end

    -- Loads the macro modules, plus the feature modules that build lines for
    -- the macros unless the test supplies its own.
    function w:LoadMacros(options)
        options = options or {}
        if options.toys ~= false then self:Load({"Toy.lua"}) end
        if options.conditionals ~= false then self:Load({"MountConditionals.lua"}) end
        self:Load(T.MACRO_FILES)
        return ns
    end

    return w
end

return T
