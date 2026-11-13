local addonName, ns = ...

-- Abilities, toys and mounts that the mount macro and key binding use instead
-- of the normal mount while a condition is met. Entries are saved per character
-- and account wide; a character entry overrides an account entry for the same
-- condition.
local Conditionals = {}
ns.MountConditionals = Conditionals

-- Conditions with a macro conditional are evaluated by the game at click time
-- (and so work in combat). There is no [falling] conditional, so Falling is
-- polled with IsFalling() and swaps the key binding's macrotext out of combat.
Conditionals.CONDITIONS = {
    {key = "shift", label = "Shift", macro = "mod:shift", check = "IsShiftKeyDown()"},
    {key = "ctrl", label = "Ctrl", macro = "mod:ctrl", check = "IsControlKeyDown()"},
    {key = "alt", label = "Alt", macro = "mod:alt", check = "IsAltKeyDown()"},
    {key = "falling", label = "Falling"},
    {key = "combat", label = "Combat", macro = "combat"},
    {key = "indoors", label = "Indoors", macro = "indoors"},
    {key = "swimming", label = "Swimming", macro = "swimming"},
}

local CONDITION_BY_KEY = {}
for _, condition in ipairs(Conditionals.CONDITIONS) do
    CONDITION_BY_KEY[condition.key] = condition
end

local SCOPES = {"character", "account"}

-- Keeps room in the 255-character macro for the mount summon itself.
local MAX_MACRO_LINES_LENGTH = 180

-- Jumps also report IsFalling(); raise this to ignore short jumps.
local FALL_DELAY = 0.01

local G99_BREAKNECK_SPELL_ID = 1215279
-- Zone abilities are only known inside their zone, so they are allowed anyway.
local ZONE_SPELLS = {[G99_BREAKNECK_SPELL_ID] = true}

function Conditionals.GetConditionLabel(key)
    local condition = CONDITION_BY_KEY[key]
    return condition and condition.label or key
end

function Conditionals.GetList(scope)
    if scope == "account" then
        if not FitterSaved then return {} end
        FitterSaved.MountConditionals = FitterSaved.MountConditionals or {}
        return FitterSaved.MountConditionals
    end
    if not FitterCharacterSaved then return {} end
    FitterCharacterSaved.MountConditionals = FitterCharacterSaved.MountConditionals or {}
    return FitterCharacterSaved.MountConditionals
end

local function IsKnownSpell(spellID)
    return ZONE_SPELLS[spellID] or IsPlayerSpell(spellID)
        or (IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID))
end

local function FindZoneSpell(name)
    local lowered = name:lower()
    for spellID in pairs(ZONE_SPELLS) do
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name and info.name:lower() == lowered then return info end
    end
    return nil
end

local function SpellEntry(spell)
    local info = C_Spell.GetSpellInfo(spell)
        or (type(spell) == "string" and FindZoneSpell(spell))
    if not info or not info.spellID or not IsKnownSpell(info.spellID) then return nil end
    return {kind = "spell", id = info.spellID, name = info.name, icon = info.iconID}
end

local function MountEntry(mountID)
    local name, _, icon, _, _, _, _, _, _, _, isCollected =
        C_MountJournal.GetMountInfoByID(mountID)
    if not name or not isCollected then return nil end
    return {kind = "mount", id = mountID, name = name, icon = icon}
end

local function ToyEntry(itemID)
    if not itemID or not PlayerHasToy or not PlayerHasToy(itemID) then return nil end
    local _, name, icon = C_ToyBox.GetToyInfo(itemID)
    return {kind = "toy", id = itemID, name = name or ("Toy " .. itemID), icon = icon}
end

local function FindMountByName(name)
    local lowered = name:lower()
    for _, mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
        local mountName = C_MountJournal.GetMountInfoByID(mountID)
        if mountName and mountName:lower() == lowered then
            local entry = MountEntry(mountID)
            if entry then return entry end
        end
    end
    return nil
end

local function MountFromSpellEntry(spellID)
    local mountID = C_MountJournal.GetMountFromSpell
        and C_MountJournal.GetMountFromSpell(spellID)
    return mountID and MountEntry(mountID) or nil
end

-- Summons the ground mount selected for the current outfit (FitG).
local function GroundEntry()
    return {kind = "ground", name = "Ground Mount", icon = 132261}
end

-- Lookups for each type, by numeric ID and by name.
local RESOLVERS = {
    spell = {
        id = SpellEntry,
        name = SpellEntry,
    },
    toy = {
        id = ToyEntry,
        name = function(name) return ToyEntry(C_Item.GetItemInfoInstant(name)) end,
    },
    mount = {
        -- Mount journal IDs first, then the mount's summon spell ID.
        id = function(id) return MountEntry(id) or MountFromSpellEntry(id) end,
        name = FindMountByName,
    },
}

-- Resolves user input (a name or an ID) to a known spell, collected mount or
-- owned toy. kind is "spell", "toy", "mount" or "ground"; "auto" or nil tries
-- each type. Returns nil when nothing on this character matches.
function Conditionals.Resolve(input, kind)
    if kind == "ground" then return GroundEntry() end
    input = input and input:match("^%s*(.-)%s*$") or ""
    if input == "" then return nil end

    local id = tonumber(input)
    local resolver = RESOLVERS[kind]
    if resolver then
        if id then return resolver.id(id) end
        return resolver.name(input)
    end

    if id then
        return ToyEntry(id)
            or MountFromSpellEntry(id)
            or SpellEntry(id)
            or MountEntry(id)
    end
    return FindMountByName(input) or SpellEntry(input)
        or RESOLVERS.toy.name(input)
end

-- Utility mounts (vendors, repairs, mailbox) shown first in suggestions.
local PRESET_MOUNT_IDS = {
    460,   -- Grand Expedition Yak
    1039,  -- Mighty Caravan Brutosaur
    2265,  -- Trader's Gilded Brutosaur
    1792,  -- Grizzly Hills Packmaster
    280,   -- Traveler's Tundra Mammoth (Alliance)
    284,   -- Traveler's Tundra Mammoth (Horde)
}

local function CollectSpellbookSpells(add)
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return end
    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local lineInfo = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if lineInfo and not lineInfo.shouldHide and not lineInfo.offSpecID then
            local first = lineInfo.itemIndexOffset + 1
            for index = first, lineInfo.itemIndexOffset + lineInfo.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(index, bank)
                if item and item.spellID and not item.isPassive and not item.isOffSpec
                    and item.itemType == Enum.SpellBookItemType.Spell then
                    add(SpellEntry(item.spellID))
                end
            end
        end
    end
end

-- The toy box API only lists toys that pass the Toy Box's own filters, so
-- the player's filters are saved, opened up to every usable collected toy,
-- read and then restored. Calls ownedToy(itemID) for each toy found.
local function CollectOwnedToys(ownedToy)
    local T = C_ToyBox
    if not (T and T.GetNumFilteredToys and T.GetToyFromIndex and T.SetCollectedShown
        and T.SetAllSourceTypeFilters and T.SetAllExpansionTypeFilters and T.SetFilterString) then
        return
    end

    local numSources = C_PetJournal and C_PetJournal.GetNumPetSources
        and C_PetJournal.GetNumPetSources() or 0
    local numExpansions = GetNumExpansions and GetNumExpansions() or 0
    local saved = {
        collected = T.GetCollectedShown(),
        uncollected = T.GetUncollectedShown(),
        unusable = T.GetUnusableShown and T.GetUnusableShown(),
        sources = {},
        expansions = {},
        -- There is no getter for the filter string; the Toy Box search box
        -- holds it when the Collections UI is loaded, otherwise it is empty.
        search = ToyBox and ToyBox.searchBox and ToyBox.searchBox:GetText() or "",
    }
    for index = 1, numSources do saved.sources[index] = T.IsSourceTypeFilterChecked(index) end
    for index = 1, numExpansions do
        saved.expansions[index] = T.IsExpansionTypeFilterChecked(index)
    end

    local ok, err = pcall(function()
        T.SetCollectedShown(true)
        T.SetUncollectedShown(false)
        if T.SetUnusableShown then T.SetUnusableShown(false) end
        T.SetAllSourceTypeFilters(true)
        T.SetAllExpansionTypeFilters(true)
        T.SetFilterString("")
        if T.ForceToyRefilter then T.ForceToyRefilter() end
        for index = 1, T.GetNumFilteredToys() do
            local itemID = T.GetToyFromIndex(index)
            if itemID and itemID > 0 then ownedToy(itemID) end
        end
    end)

    -- Restore even if reading failed, so the Toy Box looks as the player left it.
    T.SetCollectedShown(saved.collected)
    T.SetUncollectedShown(saved.uncollected)
    if T.SetUnusableShown and saved.unusable ~= nil then T.SetUnusableShown(saved.unusable) end
    for index, checked in ipairs(saved.sources) do T.SetSourceTypeFilter(index, checked) end
    for index, checked in ipairs(saved.expansions) do T.SetExpansionTypeFilter(index, checked) end
    T.SetFilterString(saved.search)
    if T.ForceToyRefilter then T.ForceToyRefilter() end

    if not ok then geterrorhandler()(err) end
end

-- Everything the add popup can suggest on this character: presets, known
-- spellbook abilities, collected mounts and owned toys.
function Conditionals.BuildSuggestionPool()
    local pool, seen = {}, {}
    local function add(entry, preset)
        if not entry or not entry.name then return end
        local key = entry.kind .. ":" .. tostring(entry.id)
        if seen[key] then return end
        seen[key] = true
        entry.preset = preset
        entry.lowerName = ns.L[entry.name]:lower()
        pool[#pool + 1] = entry
    end

    add(GroundEntry(), true)
    add(SpellEntry(G99_BREAKNECK_SPELL_ID), true)
    for _, mountID in ipairs(PRESET_MOUNT_IDS) do add(MountEntry(mountID), true) end

    CollectSpellbookSpells(add)
    for _, mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
        local _, _, _, _, _, _, _, _, _, shouldHideOnChar = C_MountJournal.GetMountInfoByID(mountID)
        if not shouldHideOnChar then add(MountEntry(mountID)) end
    end

    -- Toys whose item data is not cached yet get their name once it loads.
    local function addToy(itemID)
        local entry = ToyEntry(itemID)
        if not entry or seen["toy:" .. itemID] then return end
        local cached = select(2, C_ToyBox.GetToyInfo(itemID))
        add(entry)
        if not cached and Item and Item.CreateFromItemID then
            Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
                local name = select(2, C_ToyBox.GetToyInfo(itemID))
                if name then
                    entry.name = name
                    entry.lowerName = name:lower()
                end
            end)
        end
    end
    CollectOwnedToys(addToy)
    -- Fallback for clients where the toy box cannot be listed.
    for _, toy in ipairs(ns.Toy and ns.Toy.GetCatalog() or {}) do addToy(toy.id) end
    for _, hearthstone in ipairs(ns.Constants.KNOWN_HEARTHSTONES or {}) do
        addToy(hearthstone.id)
    end
    return pool
end

-- Up to limit pool entries matching text, best first: name prefix matches
-- before substring matches, presets first within each, then alphabetical.
-- A number matches IDs that start with it. kind limits results to one type.
function Conditionals.GetSuggestions(pool, text, kind, limit)
    text = text and text:match("^%s*(.-)%s*$"):lower() or ""
    if text == "" then return {} end
    local isNumber = tonumber(text) ~= nil
    local matches = {}
    for _, entry in ipairs(pool) do
        if not kind or kind == "auto" or entry.kind == kind then
            local position
            if isNumber then
                position = entry.id and tostring(entry.id):find(text, 1, true) == 1 and 1
            else
                position = entry.lowerName:find(text, 1, true)
            end
            if position then
                local score = (position == 1 and 0 or 2) + (entry.preset and 0 or 1)
                matches[#matches + 1] = {entry = entry, score = score}
            end
        end
    end
    table.sort(matches, function(a, b)
        if a.score ~= b.score then return a.score < b.score end
        return a.entry.lowerName < b.entry.lowerName
    end)
    local results = {}
    for index = 1, math.min(limit, #matches) do results[index] = matches[index].entry end
    return results
end

-- Account-wide entries may name abilities or toys this character lacks.
local function IsUsable(entry)
    if entry.kind == "spell" then
        return entry.id and IsKnownSpell(entry.id)
    elseif entry.kind == "toy" then
        return ToyEntry(entry.id) ~= nil
    elseif entry.kind == "mount" then
        return entry.id and MountEntry(entry.id) ~= nil
    end
    return entry.kind == "ground"
end

-- The entries in effect on this character: character entries first, then
-- account entries for conditions the character has not claimed.
local function GetEffectiveList()
    local list, claimed = {}, {}
    for _, scope in ipairs(SCOPES) do
        for _, entry in ipairs(Conditionals.GetList(scope)) do
            if not claimed[entry.condition] and CONDITION_BY_KEY[entry.condition]
                and IsUsable(entry) then
                claimed[entry.condition] = true
                list[#list + 1] = entry
            end
        end
    end
    return list
end

-- The text after /cast for an entry. /cast also uses items, so toys use item:ID.
local function ActionText(entry)
    if entry.kind == "toy" then
        return "item:" .. entry.id
    elseif entry.kind == "mount" then
        local _, spellID = C_MountJournal.GetMountInfoByID(entry.id)
        local info = spellID and C_Spell.GetSpellInfo(spellID)
        return (info and info.name) or entry.name
    end
    local info = C_Spell.GetSpellInfo(entry.id)
    return (info and info.name) or entry.name
end

-- Ground Mount entries are handled by FitM()/FitG() further down the macro.
local function BuildMacroLines(list)
    local casts, stops = {}, {}
    for _, entry in ipairs(list) do
        local condition = CONDITION_BY_KEY[entry.condition]
        if condition.macro and entry.kind ~= "ground" then
            casts[#casts + 1] = "[" .. condition.macro .. "]" .. ActionText(entry)
            stops[#stops + 1] = "[" .. condition.macro .. "]"
        end
    end
    if #casts == 0 then return "" end
    return "/cast " .. table.concat(casts, ";") .. "\n"
        .. "/stopmacro " .. table.concat(stops) .. "\n"
end

-- Lines placed ahead of the mount summon in the mount macro and key binding.
function Conditionals.GetMacroLines()
    return BuildMacroLines(GetEffectiveList())
end

-- Modifier keys ("shift", "ctrl", "alt") set to summon the outfit's ground mount.
function Conditionals.GetGroundModifiers()
    local modifiers = {}
    for _, entry in ipairs(GetEffectiveList()) do
        if entry.kind == "ground" and CONDITION_BY_KEY[entry.condition].check then
            modifiers[#modifiers + 1] = CONDITION_BY_KEY[entry.condition]
        end
    end
    return modifiers
end

function Conditionals.IsGroundModifierHeld()
    for _, condition in ipairs(Conditionals.GetGroundModifiers()) do
        if (condition.key == "shift" and IsShiftKeyDown())
            or (condition.key == "ctrl" and IsControlKeyDown())
            or (condition.key == "alt" and IsAltKeyDown()) then
            return true
        end
    end
    return false
end

local function GetFallingEntry()
    for _, entry in ipairs(GetEffectiveList()) do
        if entry.condition == "falling" then return entry end
    end
    return nil
end

local active = false
local fallingSince = nil

local watcher = CreateFrame("Frame")
watcher:Hide()

local function SetFallingActive(value)
    if InCombatLockdown() or not ns.MountButton then return end
    local body
    if value then
        local entry = GetFallingEntry()
        if not entry then return end
        body = Conditionals.GetMacroLines() .. "/cast " .. ActionText(entry)
    else
        body = ns.state.mountButtonBody or "/run FitM()"
    end
    if ns.MountButton:GetAttribute("macrotext") ~= body then
        ns.MountButton:SetAttribute("macrotext", body)
    end
    active = value
end

watcher:SetScript("OnUpdate", function()
    local wantActive = false
    if IsFalling() then
        local now = GetTime()
        fallingSince = fallingSince or now
        -- A fall while mounted keeps the key binding's dismount behaviour.
        wantActive = now - fallingSince >= FALL_DELAY and not IsMounted()
    else
        fallingSince = nil
    end
    if wantActive ~= active then SetFallingActive(wantActive) end
end)

function Conditionals.IsFallingActive()
    return active
end

-- Re-applies the conditionals to the macro, key binding and falling watcher.
function Conditionals.Refresh()
    if GetFallingEntry() then
        watcher:Show()
    else
        watcher:Hide()
        fallingSince = nil
        if active then SetFallingActive(false) end
    end
    if InCombatLockdown() then
        if ns.MarkMacroRefreshPending then ns.MarkMacroRefreshPending() end
    elseif ns.Macro and ns.state.loaded then
        ns.Macro.UpdateForCurrentState()
    end
end

-- Returns true on success, or false and an error message.
function Conditionals.Add(scope, conditionKey, entry)
    local condition = CONDITION_BY_KEY[conditionKey]
    if not condition or not entry then
        return false, "Choose a condition and an ability or item."
    end
    if entry.kind == "ground" and not condition.check then
        return false, "Ground Mount can only be used with Shift, Ctrl or Alt."
    end
    local list = Conditionals.GetList(scope)
    for _, existing in ipairs(list) do
        if existing.condition == conditionKey then
            return false, "That condition already has an ability or item."
        end
    end

    list[#list + 1] = {
        condition = conditionKey,
        kind = entry.kind,
        id = entry.id,
        name = entry.name,
        icon = entry.icon,
    }
    if #Conditionals.GetMacroLines() > MAX_MACRO_LINES_LENGTH then
        list[#list] = nil
        return false, "Too many conditionals to fit in the mount macro."
    end

    Conditionals.Refresh()
    return true
end

function Conditionals.Remove(scope, entry)
    local list = Conditionals.GetList(scope)
    for index, existing in ipairs(list) do
        if existing == entry then
            table.remove(list, index)
            break
        end
    end
    Conditionals.Refresh()
end

-- Converts the former account-wide Shift/Ctrl/Alt mount dropdowns into
-- account-wide conditionals. A setting whose mount cannot be found yet is left
-- in place and retried on the next login.
local function MigrateLegacyModifierConditions()
    if not FitterSaved then return end
    local legacyGround = FitterSaved.GroundMountModifier
    if legacyGround and legacyGround ~= "None" then
        FitterSaved[legacyGround .. "MountCondition"] = "Ground Mount"
    end
    FitterSaved.GroundMountModifier = nil

    local renamed = ns.Constants.RENAMED_MOUNT_CONDITIONS or {}
    local list = Conditionals.GetList("account")
    for _, data in ipairs({{"Shift", "shift"}, {"Ctrl", "ctrl"}, {"Alt", "alt"}}) do
        local key = data[1] .. "MountCondition"
        local value = renamed[FitterSaved[key]] or FitterSaved[key]
        local entry
        if value == "Ground Mount" then
            entry = GroundEntry()
        elseif value == "G-99 Breakneck" then
            entry = SpellEntry(G99_BREAKNECK_SPELL_ID)
        elseif value and value ~= "None" then
            entry = FindMountByName(value)
        end
        if entry then
            local claimed = false
            for _, existing in ipairs(list) do
                if existing.condition == data[2] then claimed = true end
            end
            if not claimed then
                entry.condition = data[2]
                list[#list + 1] = entry
            end
        end
        if entry or not value or value == "None" then FitterSaved[key] = nil end
    end
end

watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function()
    MigrateLegacyModifierConditions()
    Conditionals.Refresh()
end)
