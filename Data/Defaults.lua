local addonName, ns = ...

ns.Constants = ns.Constants or {}

-- Values for FitterSaved keys that are unset. A {} entry gives each key its
-- own new empty table.
ns.Constants.ACCOUNT_DEFAULTS = {
    UseDruidMacro = false,
    UseShamanMacro = false,
    UseMonkMacro = false,
    CopyTargetMount = false,
    ShiftHearthstoneCondition = "None",
    AltHearthstoneCondition = "None",
    CtrlHearthstoneCondition = "None",
    DefaultFlying = {},
    DefaultGround = {},
    AutoEnableZoneSituations = false,
    AutoDisableZoneSituations = false,
    RemoveMacroChangesOnUpdate = false,
    ShowTooltipMount = true,
    UseZoneSpecificMounts = false,
    ShowTooltipHearthstone = true,
    AstralRecallFallback = false,
    CancelNonOutfitToys = false,
    ApplyToyOnSelect = false,
    SearchableTitles = false,
    DismissPetOnStealth = false,
    DismissPetInInstancesWhileGrouped = false,
    ReviveHunterPet = false,
    AccountWideFlyingEnabled = false,
    AccountWideFlyingMounts = {},
    AccountWideFlyingRandom = false,
    AccountWideGroundEnabled = false,
    AccountWideGroundMounts = {},
    AccountWideGroundRandom = false,
    AccountWideAquaticEnabled = false,
    AccountWideAquaticMounts = {},
    AccountWideAquaticRandom = false,
    EmoteGlobalCooldown = 25,
    FavoriteMounts = {},
    FavoritePets = {},
    FavoriteHunterPets = {},
    FavoriteHearthstones = {},
    FavoriteToys = {},
    CustomToys = {},
    FavoriteZones = {},
    FavoriteEmotes = {},
    CustomEmotes = {},
    Loadouts = {},
}

-- Values for FitterCharacterSaved keys that are unset.
ns.Constants.CHARACTER_DEFAULTS = {
    CustomEmotes = {},
    Loadouts = {},
}

-- A new outfit's FitterCharacterSaved["Outfit<id>"] entry.
ns.Constants.OUTFIT_DEFAULTS = {
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
    HunterPets = {},
    HunterPetMetadata = {},
    HunterPetDisabled = false,
    HunterPetRandom = false,
    Hearthstones = {},
    Toys = {},
    Emotes = {},
}

ns.Constants.BAG_HEARTHSTONE_ITEM_ID = 6948
