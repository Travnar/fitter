local addonName, ns = ...

local Toy = {}
ns.Toy = Toy

-- Toy item data lives in Data/Toys.lua. Expose it here so the rest of the
-- addon can keep using ns.Toy.KNOWN_TOYS.
Toy.KNOWN_TOYS = ns.Constants.KNOWN_TOYS

function Toy.GetCatalog()
    local catalog, seen = {}, {}
    for _, entry in ipairs(Toy.KNOWN_TOYS or {}) do
        if type(entry.id) == "number" and not seen[entry.id] then
            catalog[#catalog + 1] = entry
            seen[entry.id] = true
        end
    end
    for _, toyID in ipairs(FitterSaved and FitterSaved.CustomToys or {}) do
        toyID = tonumber(toyID)
        if toyID and not seen[toyID] then
            catalog[#catalog + 1] = {id = toyID, custom = true}
            seen[toyID] = true
        end
    end
    return catalog
end

function Toy.IsCatalogToy(toyID)
    toyID = tonumber(toyID)
    if not toyID then return false end
    for _, entry in ipairs(Toy.GetCatalog()) do
        if entry.id == toyID then return true end
    end
    return false
end

local function CanAccessValue(value)
    if canaccessvalue then return canaccessvalue(value) end
    return not issecretvalue or not issecretvalue(value)
end

function Toy.ScheduleMacroRefresh()
    local outfitID = ns.state.currentZoneOutfitID
        or (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
            and C_TransmogOutfitInfo.GetActiveOutfitID())
    local data = outfitID and FitterCharacterSaved
        and FitterCharacterSaved["Outfit" .. outfitID]
    if not (FitterSaved and FitterSaved.CancelNonOutfitToys)
        and not (data and type(data.Toys) == "table" and #data.Toys > 0) then
        return
    end
    if ns.state.toyMacroRefreshTimer then return end
    ns.state.toyMacroRefreshTimer = C_Timer.NewTimer(0.25, function()
        ns.state.toyMacroRefreshTimer = nil
        if InCombatLockdown() then
            if ns.MarkMacroRefreshPending then ns.MarkMacroRefreshPending() end
            return
        end
        ns.Macro.UpdateForCurrentState()
    end)
end

function Toy.IsToyActive(toyID)
    local spellName = GetItemSpell(toyID)
    if not spellName then return false end
    local aura = C_UnitAuras.GetAuraDataBySpellName("player", spellName)
    return aura ~= nil
end

function Toy.IsToyOnCooldown(toyID)
    local startTime, duration = GetItemCooldown(toyID)
    if CanAccessValue(startTime) and CanAccessValue(duration)
        and startTime and duration and startTime > 0 and duration > 0 then
        return (startTime + duration) > GetTime()
    end
    return false
end

function Toy.GetMacroLines(outfitID, maxLength)
    if not outfitID or not FitterCharacterSaved then return nil end

    local data = FitterCharacterSaved["Outfit"..outfitID]
    if not data or not data.Toys or #data.Toys == 0 then return nil end

    local lines = {}
    local totalLen = 0
    for _, toyID in ipairs(data.Toys) do
        local active = Toy.IsToyActive(toyID)
        local onCooldown = Toy.IsToyOnCooldown(toyID)
        local toyUsable = C_ToyBox.IsToyUsable(toyID)
        if not CanAccessValue(toyUsable) then toyUsable = false end
        if not active and not onCooldown and toyUsable then
            local line = "/use item:" .. toyID
            local newLen = totalLen + #line + (totalLen > 0 and 1 or 0)
            if not maxLength or newLen <= maxLength then
                table.insert(lines, line)
                totalLen = newLen
            end
        end
    end

    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

function Toy.GetCancelLines(outfitID, maxLength)
    if not FitterSaved or not FitterSaved.CancelNonOutfitToys then return nil end

    local outfitToys = {}
    if outfitID and FitterCharacterSaved then
        local data = FitterCharacterSaved["Outfit"..outfitID]
        if data and data.Toys then
            for _, id in ipairs(data.Toys) do
                outfitToys[id] = true
            end
        end
    end

    local lines = {}
    local totalLen = 0
    for _, entry in ipairs(Toy.GetCatalog()) do
        local toyID = entry.id
        if not outfitToys[toyID] and Toy.IsToyActive(toyID) then
            local spellName = GetItemSpell(toyID)
            if spellName then
                local line = "/cancelaura " .. spellName
                local newLen = totalLen + #line + (totalLen > 0 and 1 or 0)
                if not maxLength or newLen <= maxLength then
                    table.insert(lines, line)
                    totalLen = newLen
                end
            end
        end
    end

    if #lines == 0 then return nil end
    return table.concat(lines, "\n")
end

function Toy.GetEarliestUpdateDelay(outfitID)
    if not outfitID or not FitterCharacterSaved then return nil end
    local data = FitterCharacterSaved["Outfit"..outfitID]
    if not data or not data.Toys or #data.Toys == 0 then return nil end
    local earliest = nil
    local now = GetTime()
    for _, toyID in ipairs(data.Toys) do
        local startTime, duration = GetItemCooldown(toyID)
        if CanAccessValue(startTime) and CanAccessValue(duration)
            and startTime and duration and startTime > 0 and duration > 0 then
            local remaining = (startTime + duration) - now
            if remaining > 0 and (not earliest or remaining < earliest) then
                earliest = remaining
            end
        end
        local spellName = GetItemSpell(toyID)
        if spellName then
            local aura = C_UnitAuras.GetAuraDataBySpellName("player", spellName)
            local expirationTime = aura and aura.expirationTime
            if CanAccessValue(expirationTime) and expirationTime
                and expirationTime > now then
                local remaining = expirationTime - now
                if not earliest or remaining < earliest then
                    earliest = remaining
                end
            end
        end
    end
    return earliest
end
