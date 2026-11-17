local addonName, ns = ...

-- FitM() and FitG(): what the mount macro and key binding run on a press.
local Mount = ns.Mount

-- Set once a press has dismounted or summoned, so a later error in the same
-- press does not summon a second mount.
local pressHandled = false

local function Summon(mountID, outfitID)
    pressHandled = true
    C_MountJournal.SummonByID(mountID)
    ns.Title.Apply(outfitID)
end

local function DismountPlayer()
    pressHandled = true
    Dismount()
end

-- Every mount press goes through one /run line, so an error there would leave
-- the player unable to mount. The error is still reported, and the press
-- falls back to a random favorite mount.
local function ReportError(err)
    geterrorhandler()(err)
end

local function Guarded(press)
    return function(...)
        pressHandled = false
        if xpcall(press, ReportError, ...) or pressHandled then return end
        if IsMounted() then
            Dismount()
        else
            C_MountJournal.SummonByID(0)
        end
    end
end

local function IsOutfitLocked(outfitID)
    return outfitID ~= nil and C_TransmogOutfitInfo ~= nil
        and C_TransmogOutfitInfo.IsLockedOutfit ~= nil
        and C_TransmogOutfitInfo.IsLockedOutfit(outfitID) == true
end

-- Returns the outfit to mount for (nil means the active outfit), the active
-- outfit and whether it is locked. A zone outfit that has not been applied
-- yet is used unless the active outfit is locked.
local function ResolveOutfit(outfitIDOverride)
    local activeOutfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    local isLocked = IsOutfitLocked(activeOutfitID)
    local zoneOutfitID = ns.state.currentZoneOutfitID
    if not outfitIDOverride and zoneOutfitID and activeOutfitID ~= zoneOutfitID
        and not isLocked then
        outfitIDOverride = zoneOutfitID
    end
    return outfitIDOverride, activeOutfitID, isLocked
end

-- Returns the target player's active mount when this character owns it and can
-- use it here; nil otherwise (no player target, not mounted, not collected).
local function GetTargetPlayerMount()
    if not (FitterSaved and FitterSaved.CopyTargetMount) then return nil end
    if not UnitIsPlayer("target") or UnitIsUnit("target", "player") then return nil end
    for index = 1, 255 do
        local aura = C_UnitAuras.GetAuraDataByIndex("target", index, "HELPFUL")
        if not aura then return nil end
        local spellID = aura.spellId
        if spellID and ns.CanAccessValue(spellID) then
            local mountID = C_MountJournal.GetMountFromSpell(spellID)
            if mountID then
                if Mount.IsUsable(mountID) then return mountID end
                return nil
            end
        end
    end
end

-- The mount picked when the macro was last built, or nil when it no longer
-- suits this press.
local function GetPreRolledMount(activeOutfitID, isLocked)
    local state = ns.state
    local mountID = state.nextMountToSummon
    if type(mountID) ~= "number" then return nil end

    -- Entering/leaving water or crossing a flyability boundary changes the
    -- category hierarchy, so a preselected mount from the old context is stale.
    if state.nextMountWasSubmerged ~= Mount.IsAquaticContext()
        or state.nextMountWasFlyable ~= IsFlyableArea() then
        return nil
    end

    -- It was rolled for the zone outfit, which a locked outfit overrides.
    if isLocked and state.currentZoneOutfitID
        and state.currentZoneOutfitID ~= activeOutfitID then
        return nil
    end

    if IsFlyableArea() and Mount.IsGroundOnly(mountID) then return nil end
    if not Mount.IsUsable(mountID) then return nil end
    return mountID
end

local SummonGroundMount

local function SummonMount(outfitIDOverride)
    ns.Toy.ScheduleMacroRefresh()

    -- Other mount bind conditionals are cast by the macro before FitM() runs;
    -- only Ground Mount modifiers are handled here.
    if ns.MountConditionals and ns.MountConditionals.IsGroundModifierHeld() then
        SummonGroundMount(outfitIDOverride)
        return
    end

    local activeOutfitID, isLocked
    outfitIDOverride, activeOutfitID, isLocked = ResolveOutfit(outfitIDOverride)

    if IsMounted() then
        DismountPlayer()
        return
    end

    local targetMountID = GetTargetPlayerMount()
    if targetMountID then
        Summon(targetMountID, outfitIDOverride)
        return
    end

    local mountID = not outfitIDOverride and GetPreRolledMount(activeOutfitID, isLocked)
        or Mount.SelectNext(true, outfitIDOverride)
    if not mountID then return end

    Summon(mountID, outfitIDOverride)
    ns.state.nextMountToSummon = nil
end

function SummonGroundMount(outfitIDOverride)
    outfitIDOverride = ResolveOutfit(outfitIDOverride)

    if IsMounted() then
        DismountPlayer()
        return
    end

    local mountID = Mount.SelectGround(outfitIDOverride)
    if not mountID then return end

    Summon(mountID, outfitIDOverride)
    ns.state.nextMountToSummon = nil
end

_G.FitterMount = Guarded(SummonMount)
_G.FitM = _G.FitterMount
_G.FitterGroundMount = Guarded(SummonGroundMount)
_G.FitG = _G.FitterGroundMount
