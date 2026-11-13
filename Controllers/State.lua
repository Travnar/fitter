local _, ns = ...

ns.state = {
    nextMountToSummon = nil,
    wasSubmerged = nil,
    waterExitGraceUntil = 0,
    wasMounted = false,
    soarCooldownTimer = nil,
    currentZoneMapID = nil,
    currentZoneOutfitID = nil,
    loaded = false,
    playerClass = nil,
    playerRace = nil,
    wasStealthed = false,
    zoneUpdateTimer = nil,
    outfitUpdateCooldownTimer = false,
    toyMacroRefreshTimer = nil,
    hearthstoneCooldownTimer = nil,
    macroRefreshPending = false,
    transmogInitTimer = nil,
    worldGeneration = 0,
    viewedOutfitGeneration = 0,
    displayedOutfitGeneration = 0,
    mountGeneration = 0,
    outfitMacroGeneration = 0,
    zoneGeneration = 0,
    hunterPetRefreshTimer = nil,
    featureEvents = {},
}

-- Macros cannot be edited in combat; PLAYER_REGEN_ENABLED rebuilds them when
-- this is set.
function ns.MarkMacroRefreshPending()
    ns.state.macroRefreshPending = true
end

-- Runs fn now, or marks the macro refresh pending when in combat.
function ns.RunOutOfCombat(fn, ...)
    if InCombatLockdown() then
        ns.MarkMacroRefreshPending()
        return false
    end
    fn(...)
    return true
end
