local addonName, ns = ...

ns.Constants = ns.Constants or {}

ns.Constants.KNOWN_HEARTHSTONES = {
    {id = 6948,   baseItem = true, previewSpellVisualKitID = 36, previewAnimationID = 51},
    -- Ethereal Portal: item spell 75136 -> SpellVisual 15783.
    -- Its caster-start event uses SpellVisualKit 14579.
    {id = 54452,  previewSpellVisualKitID = 14579,  previewAnimationID = 52},
    {id = 64488,  previewSpellVisualKitID = 36,     previewAnimationID = 51},
    {id = 93672,  previewSpellVisualKitID = 31681,  previewAnimationID = 52},
    {id = 142542, previewSpellVisualKitID = 180930, previewAnimationKitID = 27317},
    -- previewEquipItemID: a cosmetic item the cast equips for its duration
    -- (SpellProceduralEffect type 17 in the caster-start kit).
    {id = 162973, previewSpellVisualKitID = 102715, previewAnimationID = 69,
        previewEquipItemID = 139299},
    {id = 163045, previewSpellVisualKitID = 102824, previewAnimationID = 922,
        previewEquipItemID = 33292},
    {id = 163206, previewSpellVisualKitID = 104086, previewAnimationID = 51},
    {id = 165669, previewSpellVisualKitID = 106223, previewAnimationKitID = 16976},
    {id = 165670, previewSpellVisualKitID = 106285, previewAnimationKitID = 16984,
        previewEquipItemID = 151355},
    {id = 165802, previewSpellVisualKitID = 106481, previewAnimationID = 1330,
        previewEquipItemID = 44803},
    {id = 166746, previewSpellVisualKitID = 106582, previewAnimationKitID = 17054,
        previewEquipItemID = {Horde = 35280, Alliance = 35279}},
    {id = 166747, previewSpellVisualKitID = 106588, previewAnimationID = 69,
        previewEquipItemID = 33864},
    {id = 168907, previewSpellVisualKitID = 112576, previewAnimationID = 113},
    {id = 172179, previewSpellVisualKitID = 118950, previewAnimationID = 879},
    {id = 180290, previewSpellVisualKitID = 128103, previewAnimationKitID = 11602},
    {id = 182773, previewSpellVisualKitID = 142152, previewAnimationKitID = 11603},
    {id = 183716, previewSpellVisualKitID = 139168, previewAnimationID = 52},
    {id = 184353, previewSpellVisualKitID = 140841, previewAnimationKitID = 10212},
    {id = 188952, previewSpellVisualKitID = 152793, previewAnimationID = 52},
    {id = 190196, previewSpellVisualKitID = 154737, previewAnimationID = 1448},
    {id = 190237, previewSpellVisualKitID = 154740, previewAnimationID = 52},
    {id = 193588, previewSpellVisualKitID = 159673, previewAnimationID = 52},
    {id = 200630, previewSpellVisualKitID = 167276, previewAnimationID = 52},
    {id = 206195, previewSpellVisualKitID = 180823, previewAnimationID = 879},
    {id = 208704, previewSpellVisualKitID = 185670, previewAnimationKitID = 27823},
    {id = 209035, previewSpellVisualKitID = 186691, previewAnimationID = 52},
    {id = 210455, race = "Draenei", previewSpellVisualKitID = 198294, previewAnimationKitID = 28517},
    {id = 212337, previewSpellVisualKitID = 174334, previewAnimationKitID = 26649},
    {id = 228940, previewSpellVisualKitID = 210248, previewAnimationKitID = 30897},
    {id = 263489, previewSpellVisualKitID = 251306, previewAnimationID = 52},
    {id = 236687, previewSpellVisualKitID = 224060, previewAnimationKitID = 32318},
    {id = 246565, previewSpellVisualKitID = 235783, previewAnimationKitID = 19057},
    {id = 245970, previewSpellVisualKitID = 234534, previewAnimationID = 52},
    -- Spell 1217281 currently has no SpellXSpellVisual record, so this one
    -- retains the generic character precast animation.
    {id = 235016, previewAnimationID = 51},
    {id = 265100, previewSpellVisualKitID = 252859, previewAnimationKitID = 19057},
    {id = 257736, previewSpellVisualKitID = 247250, previewAnimationKitID = 35175},
    {id = 263933, previewSpellVisualKitID = 251445, previewAnimationID = 52},
    -- Spell 1310234 casts 1310241, which transforms the caster into the
    -- Aqir Scuttler (creature 272289) at the start of the cast.
    {id = 281136, previewSpellVisualKitID = 276054, previewAnimationKitID = 2194,
        previewTransformDisplayID = 144616},
    {id = 281615, previewSpellVisualKitID = 277034, previewAnimationID = 878},
}

-- Toys that can override the outfit Hearthstone while a modifier is held.
-- IDs are stored in SavedVariables so this continues to work on non-English clients.
ns.Constants.HEARTHSTONE_CONDITIONS = {
    {label = "None", alwaysAvailable = true},
    {label = "Personal Key to the Arcantina", id = 253629},
    {label = "Dalaran Hearthstone", id = 140192},
    {label = "Garrison Hearthstone", id = 110560},
    {label = "Delver's Mana-Bound Ethergate", id = 243056},
}
