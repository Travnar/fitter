local addonName, ns = ...

local Fitter = CreateFrame("Frame", "FitterAddonFrame", UIParent)
ns.Fitter = Fitter

-- References to secure keybind buttons (created in Bindings_Frames.xml).
ns.MountButton = FitterMountButton
ns.HearthstoneButton = FitterHearthstoneButton
ns.FishingButton = FitterFishingButton
ns.OutfitUpdateButton = FitterOutfitUpdateButton
if ns.MountButton then
    ns.MountButton:HookScript("PostClick", function()
        ns.Toy.ScheduleMacroRefresh()
    end)
end

-- Global callable from /run in a WoW macro.
function FitterOutfitUpdate()
    if InCombatLockdown() then
        ns.MarkMacroRefreshPending()
        return
    end
    ns.Toy.ScheduleMacroRefresh()
    local outfitID = ns.state.currentZoneOutfitID
    ns.Title.Apply(outfitID)
    ns.Pet.Apply(outfitID, "outfitChange")
    -- Regenerate the macro body after toys have been applied so that
    -- IsToyActive() reflects the new state and active toys are dropped
    -- from the macro (matching the mount macro's post-execution behaviour).
    ns.state.outfitMacroGeneration = ns.state.outfitMacroGeneration + 1
    local generation = ns.state.outfitMacroGeneration
    C_Timer.After(0.1, function()
        if generation ~= ns.state.outfitMacroGeneration then return end
        ns.RunOutOfCombat(ns.Macro.UpdateOutfitUpdateMacro)
    end)
end
_G.FitterOutfitUpdate = FitterOutfitUpdate
_G.FitU = FitterOutfitUpdate

-- True when an opt-in class macro (druid/shaman/monk) replaces the standard
-- FitterMount() driver; in that case the periodic mount re-roll is skipped.
function ns.IsClassMountMacroEnabled()
    if not FitterSaved then return false end
    local class = ns.state.playerClass
    return (FitterSaved.UseDruidMacro and class == "DRUID")
        or (FitterSaved.UseShamanMacro and class == "SHAMAN")
        or (FitterSaved.UseMonkMacro and class == "MONK")
end

-- A locked outfit takes precedence over the zone outfit for mount selection.
function ns.GetMountOutfitID()
    local activeOutfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    if activeOutfitID and C_TransmogOutfitInfo.IsLockedOutfit
        and C_TransmogOutfitInfo.IsLockedOutfit(activeOutfitID) then
        return activeOutfitID
    end
    return ns.state.currentZoneOutfitID
end

function Fitter:SelectNextMount(excludeSoar)
    local mountID = ns.Mount.SelectNext(excludeSoar, ns.GetMountOutfitID())
    ns.state.nextMountToSummon = mountID
    return mountID
end

local function RerollMountMacro()
    if InCombatLockdown() then
        ns.MarkMacroRefreshPending()
        return
    end
    if ns.IsClassMountMacroEnabled() then return end
    ns.state.nextMountToSummon = ns.Mount.SelectNext(false, ns.GetMountOutfitID())
    ns.Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
end

local function CancelTransmogUIInitialization()
    if ns.state.transmogInitTimer then
        ns.state.transmogInitTimer:Cancel()
        ns.state.transmogInitTimer = nil
    end
end

local function InitializeTransmogUI()
    if not ns.UI_Transmog then return end
    CancelTransmogUIInitialization()
    local attempts = 0
    local maxAttempts = 50
    local function tryInit()
        ns.state.transmogInitTimer = nil
        if TransmogFrame and TransmogFrame.WardrobeCollection then
            ns.UI_Transmog:Initialize()
            return
        end
        attempts = attempts + 1
        if attempts >= maxAttempts then return end
        ns.state.transmogInitTimer = C_Timer.NewTimer(0.1, tryInit)
    end
    tryInit()
end

local function OnViewedOutfitChanged()
    local viewedOutfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if not viewedOutfitID then return end
    ns.Settings.CreateEmptyOutfit(viewedOutfitID)
    if ns.UI_Transmog then
        ns.state.viewedOutfitGeneration = ns.state.viewedOutfitGeneration + 1
        local generation = ns.state.viewedOutfitGeneration
        C_Timer.After(0.1, function()
            if generation ~= ns.state.viewedOutfitGeneration then return end
            if C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
                ~= viewedOutfitID then return end
            ns.UI_Transmog:UpdateTitleDropdown()
            ns.UI_Transmog:UpdateMountIcons()
            ns.UI_Transmog:UpdateHearthstones()
            ns.UI_Transmog:UpdateToys()
            if ns.UI_Transmog.RefreshEmoteRows then
                ns.UI_Transmog:RefreshEmoteRows()
            end
        end)
    end
end

local function OnDisplayedOutfitChanged()
    ns.state.displayedOutfitGeneration =
        ns.state.displayedOutfitGeneration + 1
    local generation = ns.state.displayedOutfitGeneration
    C_Timer.After(0.1, function()
        if generation ~= ns.state.displayedOutfitGeneration then return end
        Fitter:RefreshFeatureEvents()
        ns.Pet.Apply(nil, "outfitChange")
        ns.Macro.UpdateHearthstone()
        ns.Macro.UpdateFishing()
        ns.Macro.UpdateOutfitUpdateMacro()
        RerollMountMacro()
    end)
end

local function OnMountDisplayChanged()
    local state = ns.state
    local currentlyMounted = IsMounted()
    state.mountGeneration = state.mountGeneration + 1
    local generation = state.mountGeneration
    local function ShouldApplyPet()
        return not C_PetJournal.GetSummonedPetGUID() or ns.Pet.OutfitShouldDismiss()
    end

    if state.wasMounted and not currentlyMounted then
        C_Timer.After(0.1, function()
            if generation ~= state.mountGeneration or IsMounted() then return end
            if ShouldApplyPet() then
                ns.Pet.Apply(nil, "dismount")
            end
            RerollMountMacro()
        end)
    elseif not state.wasMounted and currentlyMounted then
        C_Timer.After(0.1, function()
            if generation ~= state.mountGeneration or not IsMounted() then return end
            if ShouldApplyPet() then
                ns.Pet.Apply(nil, "mount")
            end
        end)
    end

    state.wasMounted = currentlyMounted
end

local function SetFeatureEvent(event, enabled, unit)
    local registered = ns.state.featureEvents[event] == true
    if registered == enabled then return end
    if enabled then
        if unit then
            Fitter:RegisterUnitEvent(event, unit)
        else
            Fitter:RegisterEvent(event)
        end
    else
        Fitter:UnregisterEvent(event)
    end
    ns.state.featureEvents[event] = enabled or nil
end

function Fitter:RefreshFeatureEvents()
    local emote = ns.Emote
    SetFeatureEvent("UNIT_AURA", emote.IsAnyConditionConfigured(
        "EATING_START", "EATING_END", "DRINKING_START", "DRINKING_END"),
        "player")
    SetFeatureEvent("PLAYER_TARGET_CHANGED", emote.IsAnyConditionConfigured(
        "TARGET_FRIENDLY_PLAYER", "TARGET_FRIENDLY_NPC",
        "TARGET_HOSTILE_NPC"))
    SetFeatureEvent("PLAYER_UPDATE_RESTING", emote.IsAnyConditionConfigured(
        "RESTING_START", "RESTING_END"))
    SetFeatureEvent("PLAYER_FLAGS_CHANGED",
        emote.IsConditionConfigured("AFK_START"), "player")
    SetFeatureEvent("UNIT_SPELLCAST_START",
        emote.IsConditionConfigured("HEARTHSTONE_USED"), "player")

    local hunter = ns.HunterPet and ns.HunterPet.IsAvailable()
    SetFeatureEvent("PET_STABLE_UPDATE", hunter)
    SetFeatureEvent("PET_INFO_UPDATE", hunter)
    SetFeatureEvent("PLAYER_SPECIALIZATION_CHANGED", hunter)
    SetFeatureEvent("UNIT_PET", hunter, "player")

    emote.RefreshRuntimeState()
end

local function OnPlayerEnteringWorld()
    local state = ns.state
    state.worldGeneration = state.worldGeneration + 1
    ns.Mount.UpdateWaterState()
    local worldGeneration = state.worldGeneration
    if not state.loaded then
        state.loaded = true
        local _, pClass = UnitClass("player")
        local _, pRace = UnitRace("player")
        state.playerClass = pClass
        state.playerRace = pRace
        state.wasStealthed = ns.Pet.IsPlayerStealthed()
        ns.Settings.Initialize()
        Fitter:RefreshFeatureEvents()
        ns.Pet.InitializeStealthDriver()
        ns.Holidays.RequestCalendarData()
        C_Timer.NewTicker(60, function()
            if ns.Zones.IsTrackingEnabled() then ns.Zones.UpdateCache() end
        end)
        -- Build the transmog UI as soon as Blizzard_Transmog loads, before
        -- TransmogFrame is first shown.  Gamepad SmartNavigation hooks
        -- CreateFrame and rebuilds an open panel's navigation data inside
        -- the caller's execution, so creating our frames while the panel
        -- is open taints that data and later blocks protected gamepad
        -- calls when the panel closes.  Created beforehand, they are
        -- picked up by SmartNavigation's own (secure) rebuild on show.
        EventUtil.ContinueOnAddOnLoaded("Blizzard_Transmog", InitializeTransmogUI)
        C_Timer.After(2, function()
            if worldGeneration ~= state.worldGeneration then return end
            ns.Zones.UpdateCache()
            ns.Emote.OnZoneChanged()
            ns.Pet.Apply(nil, "worldEntry")
            ns.Macro.RebuildForCurrentCharacter()
        end)
    else
        C_Timer.After(1, function()
            if worldGeneration ~= state.worldGeneration then return end
            ns.Zones.UpdateCache()
            ns.Emote.OnZoneChanged()
            ns.Pet.Apply(nil, "worldEntry")
        end)
    end
end

local function OnMountJournalChanged()
    ns.Mount.UpdateWaterState()
    ns.Mount.InvalidateMountCache()
    if ns.UI_Transmog and ns.UI_Transmog.InvalidateMountListCache then
        ns.UI_Transmog:InvalidateMountListCache()
    end
end

local function OnDisplayedOutfitEvent()
    OnDisplayedOutfitChanged()
    local displayedGeneration = ns.state.displayedOutfitGeneration
    C_Timer.After(0.2, function()
        if displayedGeneration ~= ns.state.displayedOutfitGeneration then return end
        ns.Emote.Trigger("OUTFIT_EQUIPPED")
    end)
end

local function OnCombatEnded()
    local state = ns.state
    ns.Emote.Trigger("COMBAT_END")
    if ns.Pet.ShouldDismissInInstance() then
        ns.Pet.Apply()
    end
    if state.macroRefreshPending then
        state.macroRefreshPending = false
        ns.Macro.UpdateForCurrentState()
    end
    ns.Macro.UpdateHearthstone()
    ns.Macro.UpdateFishing()
    if ns.UI_Transmog and ns.UI_Transmog.RefreshCombatDeferredToyUI then
        ns.UI_Transmog:RefreshCombatDeferredToyUI()
    end
end

local function OnBindingsUpdated()
    if ns.Macro.IsOutfitUpdateUsed() then
        ns.RunOutOfCombat(ns.Macro.UpdateOutfitUpdateMacro)
    end
end

local function OnBagsUpdated()
    ns.Macro.UpdateHearthstone()
    if ns.FishingPole.IsEnabled() then ns.Macro.UpdateFishing() end
    ns.Emote.RefreshHearthstoneSpells()
end

-- Wraps a handler for a unit event so it runs only for the player, once
-- loaded, with the unit argument dropped.
local function ForPlayer(handler)
    return function(unit, ...)
        if ns.state.loaded and unit == "player" then handler(...) end
    end
end

local function OnAddonLoaded(name)
    if name == addonName then ns.Settings.ApplyDefaults() end
end

local HANDLERS = {
    ADDON_LOADED = OnAddonLoaded,
    PLAYER_ENTERING_WORLD = OnPlayerEnteringWorld,
    ZONE_CHANGED = ns.Zones.OnZoneChanged,
    ZONE_CHANGED_INDOORS = ns.Zones.OnZoneChanged,
    ZONE_CHANGED_NEW_AREA = ns.Zones.OnZoneChanged,
    CALENDAR_UPDATE_EVENT_LIST = ns.Zones.OnCalendarUpdated,
    MOUNT_JOURNAL_USABILITY_CHANGED = OnMountJournalChanged,
    NEW_MOUNT_ADDED = OnMountJournalChanged,
    TRANSMOGRIFY_OPEN = InitializeTransmogUI,
    TRANSMOGRIFY_CLOSE = CancelTransmogUIInitialization,
    VIEWED_TRANSMOG_OUTFIT_CHANGED = OnViewedOutfitChanged,
    TRANSMOG_DISPLAYED_OUTFIT_CHANGED = OnDisplayedOutfitEvent,
    PLAYER_MOUNT_DISPLAY_CHANGED = function()
        OnMountDisplayChanged()
        ns.Emote.OnMountChanged()
    end,
    PLAYER_REGEN_DISABLED = function() ns.Emote.Trigger("COMBAT_START") end,
    PLAYER_REGEN_ENABLED = OnCombatEnded,
    UPDATE_BINDINGS = OnBindingsUpdated,
    BAG_UPDATE_DELAYED = OnBagsUpdated,
    BAG_UPDATE_COOLDOWN = ns.Macro.OnBagCooldownUpdate,
    UNIT_SPELLCAST_SUCCEEDED = ForPlayer(function(_, spellID)
        ns.Mount.OnSpellcastSucceeded(spellID)
    end),

    -- Registered only while a feature needs them (see RefreshFeatureEvents).
    UNIT_AURA = ForPlayer(ns.Emote.OnAurasChanged),
    UNIT_SPELLCAST_START = ForPlayer(function(_, spellID)
        ns.Emote.OnSpellcastStarted(spellID)
    end),
    PLAYER_UPDATE_RESTING = ns.Emote.OnRestingChanged,
    PLAYER_FLAGS_CHANGED = ForPlayer(ns.Emote.OnPlayerFlagsChanged),
    PLAYER_TARGET_CHANGED = ns.Emote.OnPlayerTargetChanged,
    PET_STABLE_UPDATE = ns.HunterPet.OnStableUpdate,
    PET_INFO_UPDATE = ns.HunterPet.OnPetInfoUpdate,
    UNIT_PET = ns.HunterPet.OnUnitPet,
    PLAYER_SPECIALIZATION_CHANGED = ns.HunterPet.OnSpecializationChanged,
}

function Fitter:OnEvent(event, ...)
    local handler = HANDLERS[event]
    if handler then handler(...) end
end

local EVENTS = {
    "ADDON_LOADED",
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "CALENDAR_UPDATE_EVENT_LIST",
    "MOUNT_JOURNAL_USABILITY_CHANGED",
    "NEW_MOUNT_ADDED",
    "TRANSMOGRIFY_OPEN",
    "TRANSMOGRIFY_CLOSE",
    "VIEWED_TRANSMOG_OUTFIT_CHANGED",
    "TRANSMOG_DISPLAYED_OUTFIT_CHANGED",
    "PLAYER_MOUNT_DISPLAY_CHANGED",
    "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED",
    "UPDATE_BINDINGS",
    "BAG_UPDATE_DELAYED",
    "BAG_UPDATE_COOLDOWN",
}
for _, event in ipairs(EVENTS) do
    Fitter:RegisterEvent(event)
end
Fitter:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
Fitter:SetScript("OnEvent", Fitter.OnEvent)
