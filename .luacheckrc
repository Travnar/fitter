std = "lua51"
max_line_length = false

ignore = {
    "212",          -- unused argument (event handlers / mixin callbacks)
    "211",          -- unused local (dead aliases; remove once cleaned up)
    "311",          -- value assigned to local is unused
    "421", "422", "423", -- shadowing local / argument / loop variable
    "431", "432",   -- shadowing upvalue / upvalue argument
    "611", "612", "613", "614", -- whitespace
}

exclude_files = {
    "dev/",
    ".codex/",
    ".agents/",
}

globals = {
    -- SavedVariables
    "FitterSaved",
    "FitterCharacterSaved",
    -- Named frames / globals Fitter creates
    "FitterMount",
    "FitterGroundMount",
    "FitterOutfitUpdate",
    "FitterMountButton",
    "FitterHearthstoneButton",
    "FitterOutfitUpdateButton",
    -- Blizzard globals Fitter writes fields on
    "StaticPopupDialogs",
    "TransmogFrame",
}

read_globals = {
    "ACCOUNT_WIDE_FONT_COLOR", "ADD", "CAMERA_MODIFICATION_TYPE_DISCARD", "CAMERA_TRANSITION_TYPE_IMMEDIATE", "CANCEL", "C_ChatInfo",
    "C_Housing", "C_Item", "C_Map", "C_ModelInfo", "C_MountJournal", "C_PetJournal",
    "C_Spell", "C_SpellBook", "C_StableInfo", "C_Timer", "C_TooltipInfo", "C_ToyBox",
    "C_TransmogOutfitInfo", "C_UnitAuras", "CreateDataProvider", "CreateFrame", "CreateFromMixins", "CreateMacro",
    "CreateMinimalSliderFormatter", "CreateScrollBoxLinearView", "CreateScrollBoxListLinearView", "Dismount", "DoEmote", "EditMacro",
    "Enum", "EventUtil", "GameFontHighlight", "GameTooltip", "GameTooltip_AddNormalLine", "GameTooltip_Hide",
    "GameTooltip_SetTitle", "GetBindingKey", "GetBuildInfo", "GetCurrentTitle", "GetItemCooldown", "GetItemSpell",
    "GetLocale", "GetLooseMacroIcons", "GetMacroBody", "GetMacroIcons", "GetMacroIndexByName", "GetMacroInfo",
    "GetNumExpansions", "GetNumMacros", "GetNumTitles", "GetServerTime", "GetSpecialization", "GetSpecializationInfo",
    "GetTime", "GetTitleName", "HasPetUI", "InCombatLockdown", "IsAltKeyDown", "IsControlKeyDown",
    "IsFalling", "IsFlyableArea", "IsInGroup", "IsInInstance", "IsMounted", "IsPlayerSpell",
    "IsResting", "IsShiftKeyDown", "IsSpellKnownOrOverridesKnown", "IsStealthed", "IsSubmerged", "IsTitleKnown",
    "Item", "LE_PET_JOURNAL_FILTER_NOT_COLLECTED", "MAXEMOTEINDEX", "MOUNT", "MenuUtil", "MinimalSliderWithSteppersMixin",
    "PickupMacro", "PlaySound", "PlayerHasToy", "RegisterStateDriver", "SOUNDKIT", "ScrollBoxConstants",
    "ScrollUtil", "SecureCmdOptionParse", "SendChatMessage", "SetCurrentTitle", "Settings", "StaticPopup_Hide",
    "StaticPopup_Show", "TOY", "TabSystemOwnerMixin", "ToyBox", "TransmogAppearanceSlotMixin", "TransmogLocationMixin",
    "TransmogSlotMixin", "UIErrorsFrame", "UIParent", "UnitCanAttack", "UnitCastingInfo", "UnitChannelInfo",
    "UnitClass", "UnitExists", "UnitFactionGroup", "UnitGUID", "UnitIsAFK", "UnitIsFriend",
    "UnitIsPlayer", "UnitIsUnit", "UnitName", "UnitRace", "UnitReaction", "canaccessvalue",
    "geterrorhandler", "hooksecurefunc", "issecretvalue", "strsplit", "tContains", "tDeleteItem",
    "wipe"
}
