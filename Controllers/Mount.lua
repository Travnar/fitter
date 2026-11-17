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
Mount.IsAquaticContext = IsAquaticContext

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
Mount.IsUsable = IsMountCurrentlyUsable

function Mount.IsGroundOnly(mountID)
    local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
    return mountTypeID == MOUNT_TYPE_GROUND_ONLY
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

local CATEGORY_FEATURES = {
    Flying = "FlyingMounts",
    Aquatic = "AquaticMounts",
}

local function GetMountCategoryOrder()
    local order
    if IsAquaticContext() then
        if IsFlyableArea() then
            order = {"Aquatic", "Flying", "Ground"}
        else
            order = {"Aquatic", "Ground", "Flying"}
        end
    elseif IsFlyableArea() then
        order = {"Flying", "Ground"}
    else
        order = {"Ground", "Flying"}
    end
    -- Drop categories the client does not support (e.g. WoW Forever).
    for i = #order, 1, -1 do
        local feature = CATEGORY_FEATURES[order[i]]
        if feature and not ns.Features[feature] then
            table.remove(order, i)
        end
    end
    return order
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

    if ns.Features.ZoneSpecificMounts
        and FitterSaved and FitterSaved.UseZoneSpecificMounts
        and ns.state.currentZoneMapID == UNDERMINE_MAP_ID
        and IsPlayerSpell(G99_BREAKNECK_SPELL_ID) then
        return "g99breakneck"
    end

    local activeOutfitID = outfitIDOverride or C_TransmogOutfitInfo.GetActiveOutfitID()

    if not activeOutfitID or activeOutfitID == 0 then
        local category = ns.Features.FlyingMounts and IsFlyableArea()
            and "Flying" or "Ground"
        return PickFromTypePool(category)
    end

    local outfitData = ns.Settings.GetOutfitData(activeOutfitID)
    if not outfitData then return nil end

    for _, category in ipairs(GetMountCategoryOrder()) do
        local mountID = TryMountCategory(outfitData, category, excludeSoar)
        if mountID then return mountID end
    end
    return nil
end
Mount.SelectNext = SelectNextMount

-- The mount for a Ground Mount modifier press. Running Wild and Soar are cast
-- by the macro, so a list holding only those returns nil.
function Mount.SelectGround(outfitIDOverride)
    if not C_TransmogOutfitInfo then return nil end

    local outfitID = outfitIDOverride or C_TransmogOutfitInfo.GetActiveOutfitID()
    if not outfitID or outfitID == 0 then
        return PickFromTypePool("Ground")
    end

    local outfitData = ns.Settings.GetOutfitData(outfitID)
    if not outfitData then return nil end

    local mounts = outfitData.Ground or {}
    if #mounts > 0 and #FilterSpecialAbilityMounts(mounts, true) == 0 then
        return nil
    end
    return TryMountCategory(outfitData, "Ground", true)
end

function Mount.OnSpellcastSucceeded(spellID)
    if spellID ~= SOAR_SPELL_ID then return end
    C_Timer.After(0.25, function()
        if InCombatLockdown() then
            ns.MarkMacroRefreshPending()
            return
        end
        ns.state.nextMountToSummon = SelectNextMount(false, ns.GetMountOutfitID())
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

    local outfitData = ns.Settings.GetOutfitData(activeOutfitID)
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
            state.nextMountToSummon = SelectNextMount(false, ns.GetMountOutfitID())
            ns.Macro.UpdateMacroForMount(state.nextMountToSummon)
        else
            ns.MarkMacroRefreshPending()
        end
        state.soarCooldownTimer = nil
    end)
end
