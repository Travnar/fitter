local addonName, ns = ...

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

function ns.MarkMacroRefreshPending()
    ns.state.macroRefreshPending = true
end

local Fitter = CreateFrame("Frame", "FitterAddonFrame", UIParent)
ns.Fitter = Fitter

-- References to secure keybind buttons (created in Bindings_Frames.xml).
ns.MountButton = FitterMountButton
ns.HearthstoneButton = FitterHearthstoneButton
ns.OutfitUpdateButton = FitterOutfitUpdateButton
if ns.MountButton then
    ns.MountButton:HookScript("PostClick", function()
        ns.Toy.ScheduleMacroRefresh()
    end)
end

local stealthDriver

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
        if not InCombatLockdown() then
            ns.Macro.UpdateOutfitUpdateMacro()
        else
            ns.MarkMacroRefreshPending()
        end
    end)
end
_G.FitterOutfitUpdate = FitterOutfitUpdate
_G.FitU = FitterOutfitUpdate

-- True when an opt-in class macro (druid/shaman) replaces the standard
-- FitterMount() driver; in that case the periodic mount re-roll is skipped.
function ns.IsClassMountMacroEnabled()
    if not FitterSaved then return false end
    local class = ns.state.playerClass
    return (FitterSaved.UseDruidMacro and class == "DRUID")
        or (FitterSaved.UseShamanMacro and class == "SHAMAN")
end

function Fitter:CreateEmptyOutfit(outfitID)
    if not FitterCharacterSaved then
        FitterCharacterSaved = {}
    end
    local key = "Outfit"..outfitID
    if not FitterCharacterSaved[key] then
        FitterCharacterSaved[key] = {
            Flying = {},
            Ground = {},
            Aquatic = {},
            FlyingRandom = false,
            GroundRandom = false,
            AquaticRandom = false,
            FlyingNoMount = false,
            GroundNoMount = false,
            AquaticNoMount = false,
            Title = -1,
            Pets = {},
            PetRandom = false,
            PetNoPet = false,
            PetSummonTriggers = {},
            HunterPetSlot = nil,
            HunterPets = {},
            HunterPetMetadata = {},
            HunterPetDisabled = false,
            HunterPetRandom = false,
            Hearthstones = {},
            Toys = {},
            Emotes = {},
        }
    end
end

function Fitter:UpdateTitle(outfitIDOverride) ns.Title.Apply(outfitIDOverride) end
function Fitter:UpdatePet() ns.Pet.Apply() end
function Fitter:UpdateOutfitUpdateMacro(outfitIDOverride)
    ns.Macro.UpdateOutfitUpdateMacro(outfitIDOverride)
end
function Fitter:RefreshZoneCache()
    ns.Zones.InvalidateTrackingCache()
    ns.Zones.UpdateCache()
end
function Fitter:UpdateMacroForCurrentState() ns.Macro.UpdateForCurrentState() end
function Fitter:UpdateMacroForMount(mountID) ns.Macro.UpdateMacroForMount(mountID) end
function Fitter:UpdateHearthstoneMacro() ns.Macro.UpdateHearthstone() end
function Fitter:EnsureHearthstoneMacro() ns.Macro.EnsureHearthstone() end

function Fitter:SelectNextMount(excludeSoar)
    local mountID = ns.Mount.SelectNext(excludeSoar, ns.state.currentZoneOutfitID)
    ns.state.nextMountToSummon = mountID
    return mountID
end

local function RerollMountMacro()
    if InCombatLockdown() then
        ns.MarkMacroRefreshPending()
        return
    end
    if ns.IsClassMountMacroEnabled() then return end
    ns.state.nextMountToSummon = ns.Mount.SelectNext(false, ns.state.currentZoneOutfitID)
    ns.Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
end

local function InitializeSettings()
    FitterSaved = FitterSaved or {}
    FitterSaved.FavoriteMounts = FitterSaved.FavoriteMounts or {}
    FitterSaved.FavoritePets = FitterSaved.FavoritePets or {}
    FitterSaved.FavoriteHunterPets = FitterSaved.FavoriteHunterPets or {}
    FitterSaved.FavoriteHearthstones = FitterSaved.FavoriteHearthstones or {}
    FitterSaved.FavoriteToys = FitterSaved.FavoriteToys or {}
    FitterSaved.CustomToys = FitterSaved.CustomToys or {}
    FitterSaved.FavoriteZones = FitterSaved.FavoriteZones or {}
    FitterSaved.FavoriteEmotes = FitterSaved.FavoriteEmotes or {}
    FitterSaved.CustomEmotes = FitterSaved.CustomEmotes or {}
    FitterSaved.Loadouts = FitterSaved.Loadouts or {}

    if not FitterCharacterSaved then
        FitterCharacterSaved = {}
    end
    FitterCharacterSaved.CustomEmotes = FitterCharacterSaved.CustomEmotes or {}
    FitterCharacterSaved.Loadouts = FitterCharacterSaved.Loadouts or {}

    local resetVersion = tonumber(FitterSaved.DefaultHearthstonesResetVersion) or 0
    local appliedVersion =
        tonumber(FitterCharacterSaved.DefaultHearthstonesResetVersion) or 0
    if appliedVersion < resetVersion then
        for key, data in pairs(FitterCharacterSaved) do
            if type(key) == "string" and key:match("^Outfit%d+$")
                and type(data) == "table" then
                if type(data.Hearthstones) == "table"
                    and #data.Hearthstones == 1
                    and data.Hearthstones[1] == 6948 then
                    data.Hearthstones = {}
                    data.Hearthstone = nil
                elseif data.Hearthstones == nil and data.Hearthstone == 6948 then
                    data.Hearthstone = nil
                    data.Hearthstones = {}
                end
            end
        end
        FitterCharacterSaved.DefaultHearthstonesResetVersion = resetVersion
    end

    -- Earlier versions populated every outfit with the bag Hearthstone even
    -- when the picker had never been configured. Clear that generated default
    -- once so an empty selection reaches the macro's random fallback.
    if not FitterSaved.EmptyHearthstoneDefaultsMigrated then
        for key, data in pairs(FitterCharacterSaved) do
            if type(key) == "string" and key:match("^Outfit%d+$")
                and type(data) == "table"
                and type(data.Hearthstones) == "table"
                and #data.Hearthstones == 1
                and data.Hearthstones[1] == 6948
                and data.Hearthstone == nil then
                data.Hearthstones = {}
            end
        end
        FitterSaved.EmptyHearthstoneDefaultsMigrated = true
    end

    if C_TransmogOutfitInfo then
        local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
        if outfits then
            for _, info in ipairs(outfits) do
                Fitter:CreateEmptyOutfit(info.outfitID)
            end
        end
    end

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
    Fitter:CreateEmptyOutfit(viewedOutfitID)
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

local function ResummonPetAfterStealth()
    local state = ns.state
    state.petResummonAfterStealth = (state.petResummonAfterStealth or 0) + 1
    local resummonID = state.petResummonAfterStealth

    C_Timer.After(0.25, function()
        if state.petResummonAfterStealth ~= resummonID then return end
        if ns.Pet.IsPlayerStealthed() then return end
        if C_PetJournal.GetSummonedPetGUID() then return end
        ns.Pet.Apply(nil, "stealthEnd")
    end)
end

local function OnPlayerStealthChanged(isStealthed)
    local state = ns.state

    if isStealthed then
        ns.Pet.DismissIfStealthed()
    elseif state.wasStealthed then
        ResummonPetAfterStealth()
    end

    state.wasStealthed = isStealthed
end

local function InitializeStealthDriver()
    if stealthDriver or not RegisterStateDriver then return end

    stealthDriver = CreateFrame("Frame", nil, UIParent)
    stealthDriver:Hide()
    stealthDriver:SetScript("OnShow", function()
        OnPlayerStealthChanged(true)
    end)
    stealthDriver:SetScript("OnHide", function()
        OnPlayerStealthChanged(false)
    end)
    RegisterStateDriver(stealthDriver, "visibility", "[stealth] show; hide")
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

function Fitter:OnEvent(event, ...)
    local state = ns.state
    if event == "PLAYER_ENTERING_WORLD" then
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
            InitializeSettings()
            Fitter:RefreshFeatureEvents()
            InitializeStealthDriver()
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
    elseif event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_INDOORS"
        or event == "ZONE_CHANGED_NEW_AREA" then
        if not ns.Zones.IsTrackingEnabled()
            and not ns.Emote.IsConditionConfigured("BIOMES") then
            return
        end
        if state.zoneUpdateTimer then
            state.zoneUpdateTimer:Cancel()
        end
        state.zoneGeneration = state.zoneGeneration + 1
        local zoneGeneration = state.zoneGeneration
        state.zoneUpdateTimer = C_Timer.NewTimer(1, function()
            state.zoneUpdateTimer = nil
            if zoneGeneration ~= state.zoneGeneration then return end
            ns.Zones.UpdateCache()
            ns.Emote.OnZoneChanged()
            ns.Pet.Apply(nil, "zoneChange")
        end)
    elseif event == "MOUNT_JOURNAL_USABILITY_CHANGED"
        or event == "NEW_MOUNT_ADDED" then
        ns.Mount.UpdateWaterState()
        ns.Mount.InvalidateMountCache()
        if ns.UI_Transmog and ns.UI_Transmog.InvalidateMountListCache then
            ns.UI_Transmog:InvalidateMountListCache()
        end
    elseif event == "TRANSMOGRIFY_OPEN" then
        InitializeTransmogUI()
    elseif event == "TRANSMOGRIFY_CLOSE" then
        CancelTransmogUIInitialization()
    elseif event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" then
        OnViewedOutfitChanged()
    elseif event == "TRANSMOG_DISPLAYED_OUTFIT_CHANGED" then
        OnDisplayedOutfitChanged()
        local displayedGeneration = state.displayedOutfitGeneration
        C_Timer.After(0.2, function()
            if displayedGeneration ~= state.displayedOutfitGeneration then return end
            ns.Emote.Trigger("OUTFIT_EQUIPPED")
        end)
    elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        OnMountDisplayChanged()
        ns.Emote.OnMountChanged()
    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.Emote.Trigger("COMBAT_START")
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.Emote.Trigger("COMBAT_END")
        if ns.Pet.ShouldDismissInInstance() then
            ns.Pet.Apply()
        end
        if state.macroRefreshPending then
            state.macroRefreshPending = false
            ns.Macro.UpdateForCurrentState()
        end
        ns.Macro.UpdateHearthstone()
        if ns.UI_Transmog and ns.UI_Transmog.RefreshCombatDeferredToyUI then
            ns.UI_Transmog:RefreshCombatDeferredToyUI()
        end
    elseif event == "UPDATE_BINDINGS" then
        if ns.Macro.IsOutfitUpdateUsed() then
            if not InCombatLockdown() then
                ns.Macro.UpdateOutfitUpdateMacro()
            else
                ns.MarkMacroRefreshPending()
            end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        ns.Macro.UpdateHearthstone()
        ns.Emote.RefreshHearthstoneSpells()
    elseif event == "BAG_UPDATE_COOLDOWN" then
        -- Item cooldowns only alter Fitter's hearthstone macro when a Shaman
        -- uses the Astral Recall fallback. Ignore this noisy event otherwise,
        -- and coalesce bursts when the feature is active.
        if state.playerClass == "SHAMAN"
            and FitterSaved
            and FitterSaved.AstralRecallFallback
            and not state.hearthstoneCooldownTimer then
            state.hearthstoneCooldownTimer = C_Timer.NewTimer(0.1, function()
                state.hearthstoneCooldownTimer = nil
                ns.Macro.UpdateHearthstone()
            end)
        end
    elseif event == "UNIT_AURA" then
        local unit, updateInfo = ...
        if state.loaded and unit == "player" then
            ns.Emote.OnAurasChanged(updateInfo)
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if state.loaded and unit == "player" then
            ns.Mount.OnSpellcastSucceeded(spellID)
        end
    elseif event == "UNIT_SPELLCAST_START" then
        local unit, _, spellID = ...
        if state.loaded and unit == "player" then
            ns.Emote.OnSpellcastStarted(spellID)
        end
    elseif event == "PLAYER_UPDATE_RESTING" then
        ns.Emote.OnRestingChanged()
    elseif event == "PLAYER_FLAGS_CHANGED" then
        local unit = ...
        if state.loaded and unit == "player" then
            ns.Emote.OnPlayerFlagsChanged()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        ns.Emote.OnPlayerTargetChanged()
    elseif event == "PET_STABLE_UPDATE" or event == "PET_INFO_UPDATE" then
        if ns.HunterPet and ns.HunterPet.IsAvailable() then
            ns.HunterPet.InvalidateCache()
            -- PET_INFO_UPDATE can arrive in bursts for changes that do not
            -- affect secure macros. Refresh its visible UI only. A stable
            -- roster change also refreshes macros, once after the burst.
            if event == "PET_STABLE_UPDATE" then
                ns.state.hunterPetRosterChanged = true
                wipe(ns.state.hunterPetFallbacks or {})
                wipe(ns.state.hunterPetSelectionRolls or {})
            end
            local ui = ns.UI_Transmog
            local uiState = ui and ui._s
            local hunterPetUIVisible = uiState and uiState.hunterPetFrame
                and uiState.hunterPetFrame:IsShown()
            if (event == "PET_STABLE_UPDATE" or hunterPetUIVisible)
                and not ns.state.hunterPetRefreshTimer then
                ns.state.hunterPetRefreshTimer = C_Timer.NewTimer(0.1, function()
                    ns.state.hunterPetRefreshTimer = nil
                    local ui = ns.UI_Transmog
                    local uiState = ui and ui._s
                    if uiState and uiState.hunterPetFrame
                        and uiState.hunterPetFrame:IsShown() then
                        ui:RefreshHunterPets()
                        ui:UpdateMountIcons()
                    end
                    if not ns.state.hunterPetRosterChanged then return end
                    ns.state.hunterPetRosterChanged = nil
                    if not InCombatLockdown() then
                        ns.Macro.UpdateOutfitUpdateMacro()
                        ns.Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
                    else
                        ns.MarkMacroRefreshPending()
                    end
                end)
            end
        end
    elseif event == "UNIT_PET" then
        local unit = ...
        if unit == "player" and ns.HunterPet
            and ns.HunterPet.IsAvailable() then
            ns.HunterPet.InvalidateCache()
            wipe(ns.state.hunterPetSelectionRolls or {})
            wipe(ns.state.hunterPetFallbacks or {})
            if InCombatLockdown() then
                ns.MarkMacroRefreshPending()
            else
                C_Timer.After(0, function()
                    if not InCombatLockdown() then
                        ns.Macro.UpdateOutfitUpdateMacro()
                        ns.Macro.UpdateMacroForMount(
                            ns.state.nextMountToSummon)
                    else
                        ns.MarkMacroRefreshPending()
                    end
                end)
            end
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == "player" and ns.HunterPet
            and ns.HunterPet.IsAvailable() then
            wipe(ns.state.hunterPetFallbacks or {})
            wipe(ns.state.hunterPetSelectionRolls or {})
            if InCombatLockdown() then
                ns.MarkMacroRefreshPending()
            else
                ns.Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
            end
        end
    end
end

function Fitter:ResetDefaultHearthstones()
    FitterSaved = FitterSaved or {}
    FitterCharacterSaved = FitterCharacterSaved or {}
    FitterSaved.DefaultHearthstonesResetVersion =
        (tonumber(FitterSaved.DefaultHearthstonesResetVersion) or 0) + 1

    for key, data in pairs(FitterCharacterSaved) do
        if type(key) == "string" and key:match("^Outfit%d+$")
            and type(data) == "table" then
            if type(data.Hearthstones) == "table"
                and #data.Hearthstones == 1
                and data.Hearthstones[1] == 6948 then
                data.Hearthstones = {}
                data.Hearthstone = nil
            elseif data.Hearthstones == nil and data.Hearthstone == 6948 then
                data.Hearthstone = nil
                data.Hearthstones = {}
            end
        end
    end

    FitterCharacterSaved.DefaultHearthstonesResetVersion =
        FitterSaved.DefaultHearthstonesResetVersion
    ns.Macro.UpdateHearthstone()
    if ns.UI_Transmog and ns.UI_Transmog.UpdateHearthstones then
        ns.UI_Transmog:UpdateHearthstones()
    end
end

local EVENTS = {
    "PLAYER_ENTERING_WORLD",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
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
