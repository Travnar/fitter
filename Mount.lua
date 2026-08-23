local addonName, ns = ...

local Mount = {}
ns.Mount = Mount

local SOAR_SPELL_ID = 369536
local G99_BREAKNECK_SPELL_ID = 1215279
local UNDERMINE_MAP_ID = 2346
local MOUNT_TYPE_GROUND_ONLY = 230
local MOUNT_TYPE_AMPHIBIOUS = 231
local MOUNT_TYPE_AQUATIC = 254
local MOUNT_TYPE_ALL_TERRAIN = 407
local MOUNT_TYPE_SKYRIDING_AQUATIC = 412
local WATER_EXIT_GRACE_SECONDS = 3

local MOUNT_FILTERS = {
    Flying = function(t)
        return t ~= MOUNT_TYPE_GROUND_ONLY
            and t ~= MOUNT_TYPE_AMPHIBIOUS
            and t ~= MOUNT_TYPE_AQUATIC
    end,
    Ground = function(t) return t ~= MOUNT_TYPE_AQUATIC end,
    Aquatic = function(t)
        return t == MOUNT_TYPE_AQUATIC or t == MOUNT_TYPE_AMPHIBIOUS
            or t == MOUNT_TYPE_ALL_TERRAIN or t == MOUNT_TYPE_SKYRIDING_AQUATIC
    end,
}

local mountPoolCache = {}

-- Mount usability changes when the player enters or leaves water, so Core
-- calls this from MOUNT_JOURNAL_USABILITY_CHANGED.  Selection also calls it
-- as a fallback in case a transition occurred before that event was handled.
function Mount.UpdateWaterState()
    local state = ns.state
    local submerged = IsSubmerged() == true
    if state.wasSubmerged == true and not submerged then
        state.waterExitGraceUntil = GetTime() + WATER_EXIT_GRACE_SECONDS
    end
    state.wasSubmerged = submerged
    return submerged
end

local function IsAquaticContext()
    local submerged = Mount.UpdateWaterState()
    return submerged and GetTime() >= (ns.state.waterExitGraceUntil or 0)
end

local function IsCastingSoar()
    local castingSpellID = select(9, UnitCastingInfo("player"))
    if castingSpellID == SOAR_SPELL_ID then return true end
    local channelSpellID = select(8, UnitChannelInfo("player"))
    return channelSpellID == SOAR_SPELL_ID
end

local function IsSoarOnCooldown()
    -- Soar reports a transient cooldown while its cast is in progress. Do not
    -- replace it with a fallback mount unless the cast actually completes.
    if IsCastingSoar() then return false end
    local cd = C_Spell.GetSpellCooldown(SOAR_SPELL_ID)
    if not cd or cd.startTime == 0 then return false end
    return (cd.startTime + cd.duration - GetTime()) > 0
end
Mount.IsSoarOnCooldown = IsSoarOnCooldown

local function FilterSpecialAbilityMounts(mounts, excludeSoar)
    local filtered = {}
    for _, mountID in ipairs(mounts) do
        local include = true
        if excludeSoar and (mountID == "soar" or mountID == "runningwild") then
            include = false
        elseif mountID == "soar" and IsSoarOnCooldown() then
            include = false
        end
        if include then filtered[#filtered + 1] = mountID end
    end
    return filtered
end

local function CollectMountPool(filterFn, cacheKey)
    if cacheKey and mountPoolCache[cacheKey] then
        return mountPoolCache[cacheKey]
    end
    local result = {}
    local allMountIDs = C_MountJournal.GetMountIDs()
    if not allMountIDs then return result end
    for _, mountID in ipairs(allMountIDs) do
        pcall(function()
            local _, _, _, _, _, _, _, _, _, shouldHideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
            if isCollected and not shouldHideOnChar then
                local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
                if mountTypeID and filterFn(mountTypeID) then
                    result[#result + 1] = mountID
                end
            end
        end)
    end
    if cacheKey then
        mountPoolCache[cacheKey] = result
    end
    return result
end

local function IsMountCurrentlyUsable(mountID)
    if type(mountID) ~= "number" then return mountID ~= nil end
    local _, _, _, _, _, _, _, _, _, shouldHideOnChar, isCollected =
        C_MountJournal.GetMountInfoByID(mountID)
    if not isCollected or shouldHideOnChar then return false end
    local ok, canUse = pcall(
        C_MountJournal.GetMountUsabilityByID, mountID, false)
    return ok and canUse == true
end

local function PickRandomUsableMount(mounts)
    local count = #mounts
    if count == 0 then return nil end
    local start = math.random(1, count)
    for offset = 0, count - 1 do
        local index = ((start + offset - 1) % count) + 1
        local mountID = mounts[index]
        if IsMountCurrentlyUsable(mountID) then return mountID end
    end
end

local function PickFromTypePool(category)
    local filterFn = MOUNT_FILTERS[category] or MOUNT_FILTERS.Flying
    return PickRandomUsableMount(CollectMountPool(filterFn, category))
end

local function GetMountCategoryOrder()
    if IsAquaticContext() then
        if IsFlyableArea() then return {"Aquatic", "Flying", "Ground"} end
        return {"Aquatic", "Ground", "Flying"}
    end
    if IsFlyableArea() then return {"Flying", "Ground"} end
    return {"Ground", "Flying"}
end

local function GetAccountWideMounts(category, excludeSoar)
    if not (FitterSaved and FitterSaved["AccountWide" .. category .. "Enabled"]) then
        return nil
    end
    if FitterSaved["AccountWide" .. category .. "Random"] then
        return FilterSpecialAbilityMounts(
            CollectMountPool(MOUNT_FILTERS[category], category), excludeSoar)
    end
    local mounts = FitterSaved["AccountWide" .. category .. "Mounts"]
    if mounts and #mounts > 0 then
        return FilterSpecialAbilityMounts(mounts, excludeSoar)
    end
end

local function TryMountCategory(outfitData, category, excludeSoar)
    -- Disable skips this category and deliberately bypasses account-wide.
    if outfitData[category .. "NoMount"] then return nil end

    if outfitData[category .. "Random"] then
        return PickFromTypePool(category)
    end

    local mounts = FilterSpecialAbilityMounts(
        outfitData[category] or {}, excludeSoar)
    if #mounts > 0 then return PickRandomUsableMount(mounts) end

    -- An empty category is Ignore: try its account-wide fallback, then let
    -- the caller continue to the next category in the environment hierarchy.
    local accountMounts = GetAccountWideMounts(category, excludeSoar)
    if accountMounts then return PickRandomUsableMount(accountMounts) end
end

local function SelectNextMount(excludeSoar, outfitIDOverride)
    if not C_TransmogOutfitInfo then return nil end

    -- Record the environment for callers that cache this selection for the
    -- macro icon or next summon.
    ns.state.nextMountWasSubmerged = IsAquaticContext()
    ns.state.nextMountWasFlyable = IsFlyableArea()

    if FitterSaved and FitterSaved.UseZoneSpecificMounts
        and ns.state.currentZoneMapID == UNDERMINE_MAP_ID
        and IsPlayerSpell(G99_BREAKNECK_SPELL_ID) then
        return "g99breakneck"
    end

    local activeOutfitID = outfitIDOverride or C_TransmogOutfitInfo.GetActiveOutfitID()

    if not activeOutfitID or activeOutfitID == 0 then
        local category = IsFlyableArea() and "Flying" or "Ground"
        return PickFromTypePool(category)
    end

    local outfitData = FitterCharacterSaved["Outfit"..activeOutfitID]
    if not outfitData then return nil end

    for _, category in ipairs(GetMountCategoryOrder()) do
        local mountID = TryMountCategory(outfitData, category, excludeSoar)
        if mountID then return mountID end
    end
    return nil
end
Mount.SelectNext = SelectNextMount

function Mount.OnSpellcastSucceeded(spellID)
    if spellID ~= SOAR_SPELL_ID then return end
    C_Timer.After(0.25, function()
        if InCombatLockdown() then
            if ns.MarkMacroRefreshPending then ns.MarkMacroRefreshPending() end
            return
        end
        ns.state.nextMountToSummon = SelectNextMount(false, ns.state.currentZoneOutfitID)
        ns.Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
    end)
end

function Mount.InvalidateMountCache()
    wipe(mountPoolCache)
end

function Mount.MonitorSoarCooldown()
    local state = ns.state
    if state.soarCooldownTimer then
        state.soarCooldownTimer:Cancel()
        state.soarCooldownTimer = nil
    end

    local playerRace = state.playerRace
    if playerRace ~= "Dracthyr" or not IsPlayerSpell(SOAR_SPELL_ID) then return end

    local playerClass = state.playerClass
    local useDruidMacro = FitterSaved and FitterSaved.UseDruidMacro
        and playerClass == "DRUID"
    if useDruidMacro then return end

    local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    if not activeOutfitID or activeOutfitID == 0 then return end

    local outfitData = FitterCharacterSaved["Outfit"..activeOutfitID]
    if not outfitData then return end

    local hasSoar = false
    for _, mountID in ipairs(outfitData.Flying or {}) do
        if mountID == "soar" then hasSoar = true; break end
    end
    if not hasSoar then return end

    local cd = C_Spell.GetSpellCooldown(SOAR_SPELL_ID)
    if not cd or cd.startTime <= 0 then return end
    local remaining = (cd.startTime + cd.duration - GetTime())
    if remaining <= 0 then return end

    state.soarCooldownTimer = C_Timer.NewTimer(remaining + 0.5, function()
        if not InCombatLockdown() then
            state.nextMountToSummon = SelectNextMount(false, state.currentZoneOutfitID)
            ns.Macro.UpdateMacroForMount(state.nextMountToSummon)
        elseif ns.MarkMacroRefreshPending then
            ns.MarkMacroRefreshPending()
        end
        state.soarCooldownTimer = nil
    end)
end

function FitterMount(outfitIDOverride)
    local state = ns.state
    ns.Toy.ScheduleMacroRefresh()

    -- Modifier conditions take precedence over the normal contextual mount.
    local condition
    if FitterSaved then
        if IsShiftKeyDown() then condition = FitterSaved.ShiftMountCondition
        elseif IsAltKeyDown() then condition = FitterSaved.AltMountCondition
        elseif IsControlKeyDown() then condition = FitterSaved.CtrlMountCondition end
    end
    if condition and condition ~= "None" then
        if condition == "Ground Mount" then
            FitterGroundMount(outfitIDOverride)
            return
        end
        for _, id in ipairs(C_MountJournal.GetMountIDs() or {}) do
            local name = C_MountJournal.GetMountInfoByID(id)
            if name == condition then
                if IsMounted() then Dismount() else C_MountJournal.SummonByID(id) end
                ns.Title.Apply(outfitIDOverride)
                state.nextMountToSummon = nil
                return
            end
        end
        return
    end

    local activeOutfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    local isLocked = C_TransmogOutfitInfo and C_TransmogOutfitInfo.IsLockedOutfit
        and C_TransmogOutfitInfo.IsLockedOutfit(activeOutfitID)
    if not outfitIDOverride and state.currentZoneOutfitID
        and activeOutfitID ~= state.currentZoneOutfitID
        and not isLocked then
        outfitIDOverride = state.currentZoneOutfitID
    end

    if IsMounted() then
        Dismount()
        return
    end

    local mountID = (not outfitIDOverride) and state.nextMountToSummon or nil

    -- Entering/leaving water or crossing a flyability boundary changes the
    -- category hierarchy, so a preselected mount from the old context is stale.
    if mountID and (state.nextMountWasSubmerged ~= IsAquaticContext()
            or state.nextMountWasFlyable ~= IsFlyableArea()) then
        mountID = nil
    end

    -- Discard pre-rolled mount if outfit is locked (it was rolled for the zone outfit)
    if mountID and isLocked and state.currentZoneOutfitID
        and state.currentZoneOutfitID ~= activeOutfitID then
        mountID = nil
    end

    if mountID == "soar" or mountID == "runningwild" or mountID == "g99breakneck" then
        mountID = nil
    end

    -- Discard stale pre-roll if flyability changed since selection
    if mountID and type(mountID) == "number" and IsFlyableArea() then
        local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
        if mountTypeID == MOUNT_TYPE_GROUND_ONLY then
            mountID = nil
        end
    end

    if mountID and not IsMountCurrentlyUsable(mountID) then
        mountID = nil
    end

    if not mountID then
        mountID = SelectNextMount(true, outfitIDOverride)
    end

    if not mountID then
        return
    end

    C_MountJournal.SummonByID(mountID)
    ns.Title.Apply(outfitIDOverride)
    state.nextMountToSummon = nil
end
_G.FitterMount = FitterMount
_G.FitM = FitterMount

local function SelectGroundMount(outfitIDOverride)
    if not C_TransmogOutfitInfo then return nil end

    local activeOutfitID = outfitIDOverride or C_TransmogOutfitInfo.GetActiveOutfitID()
    if not activeOutfitID or activeOutfitID == 0 then
        return PickFromTypePool("Ground")
    end

    local outfitData = FitterCharacterSaved and FitterCharacterSaved["Outfit"..activeOutfitID]
    if not outfitData then return nil end

    if outfitData.GroundNoMount then return nil end
    local mounts = outfitData.Ground or {}

    if #mounts == 0 then
        if outfitData.GroundRandom then
            return PickFromTypePool("Ground")
        end
        -- Ignore Ground only uses a configured account-wide ground fallback.
        if FitterSaved and FitterSaved.AccountWideGroundEnabled then
            if FitterSaved.AccountWideGroundRandom then
                return PickFromTypePool("Ground")
            end
            if FitterSaved.AccountWideGroundMounts
                    and #FitterSaved.AccountWideGroundMounts > 0 then
                local accountMounts = FitterSaved.AccountWideGroundMounts
                local regular = {}
                for _, id in ipairs(accountMounts) do
                    if id ~= "runningwild" and id ~= "soar" then
                        regular[#regular + 1] = id
                    end
                end
                if #regular > 0 then
                    return PickRandomUsableMount(regular)
                elseif #accountMounts > 0 then
                    return PickRandomUsableMount(accountMounts)
                end
            end
        end
        return nil
    end

    -- Filter out special ability mounts that can't be summoned via Lua
    -- (Running Wild, Soar) when there are regular mounts available
    local regular = {}
    for _, id in ipairs(mounts) do
        if id ~= "runningwild" and id ~= "soar" then
            regular[#regular + 1] = id
        end
    end
    if #regular > 0 then
        return PickRandomUsableMount(regular)
    end

    -- Only special mounts remain; pick one (caller handles the /cast)
    return PickRandomUsableMount(mounts)
end

function FitterGroundMount(outfitIDOverride)
    local state = ns.state

    local activeOutfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    local isLocked = C_TransmogOutfitInfo and C_TransmogOutfitInfo.IsLockedOutfit
        and C_TransmogOutfitInfo.IsLockedOutfit(activeOutfitID)
    if not outfitIDOverride and state.currentZoneOutfitID
        and activeOutfitID ~= state.currentZoneOutfitID
        and not isLocked then
        outfitIDOverride = state.currentZoneOutfitID
    end

    if IsMounted() then
        Dismount()
        return
    end

    local mountID = SelectGroundMount(outfitIDOverride)
    if not mountID then return end

    -- Special ability mounts (Running Wild, Soar) can't be summoned via Lua;
    -- the macro's /cast line handles them after this function returns.
    if mountID == "runningwild" or mountID == "soar" then return end

    C_MountJournal.SummonByID(mountID)
    ns.Title.Apply(outfitIDOverride)
    state.nextMountToSummon = nil
end
_G.FitterGroundMount = FitterGroundMount
_G.FitG = FitterGroundMount
