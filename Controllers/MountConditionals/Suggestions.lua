local addonName, ns = ...

local Conditionals = ns.MountConditionals
local Entry = Conditionals.Entry

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
                    add(Entry.Spell(item.spellID))
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

    add(Entry.Ground(), true)
    add(Entry.Spell(Conditionals.G99_BREAKNECK_SPELL_ID), true)
    for _, mountID in ipairs(PRESET_MOUNT_IDS) do add(Entry.Mount(mountID), true) end

    CollectSpellbookSpells(add)
    for _, mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
        local _, _, _, _, _, _, _, _, _, shouldHideOnChar = C_MountJournal.GetMountInfoByID(mountID)
        if not shouldHideOnChar then add(Entry.Mount(mountID)) end
    end

    -- Toys whose item data is not cached yet get their name once it loads.
    local function addToy(itemID)
        local entry = Entry.Toy(itemID)
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
