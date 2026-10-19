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
    {id = 172179, previewSpellVisualKitID = 118950, previewAnimationID = 878},
    {id = 180290, previewSpellVisualKitID = 128103, previewAnimationKitID = 11602},
    {id = 182773, previewSpellVisualKitID = 142152, previewAnimationKitID = 11603},
    -- previewEffectModels: kit models placed by positioners, which the
    -- preview does not render, shown as separate actors instead.
    {id = 183716, previewSpellVisualKitID = 139168, previewAnimationID = 52,
        previewEffectModels = {
            {fileID = 3490420, x = 0.12, y = 0.2,  z = 0.55, scale = 1.2, animationID = 158},
            {fileID = 3490420, x = 0.12, y = -0.2, z = 0.55, scale = 1.2, animationID = 158},
            {fileID = 3490421, scale = 1.1},
            {fileID = 3734198, z = 0.75, scale = 0.8, yaw = math.pi / 2,
                orbit = {radius = 0.35, period = 3}},
            {fileID = 3490420, z = 0.75, scale = 2,
                orbit = {radius = 0.35, period = 3}},
        }},
    {id = 184353, previewSpellVisualKitID = 140841, previewAnimationKitID = 10212},
    {id = 188952, previewSpellVisualKitID = 152793, previewAnimationID = 52,
        previewEffectModels = {
            {fileID = 3483478, x = 0.12, y = 0.2,  z = 0.55, scale = 1.2, animationID = 158},
            {fileID = 3483478, x = 0.12, y = -0.2, z = 0.55, scale = 1.2, animationID = 158},
            {fileID = 4062864, x = 0.6, z = 0.12},
        }},
    {id = 190196, previewSpellVisualKitID = 154737, previewAnimationID = 1448},
    {id = 190237, previewSpellVisualKitID = 154740, previewAnimationID = 52},
    {id = 193588, previewSpellVisualKitID = 159673, previewAnimationID = 52},
    {id = 200630, previewSpellVisualKitID = 167276, previewAnimationID = 52},
    {id = 206195, previewSpellVisualKitID = 180823, previewAnimationID = 878},
    {id = 208704, previewSpellVisualKitID = 185670, previewAnimationKitID = 27823},
    {id = 209035, previewSpellVisualKitID = 186691, previewAnimationID = 52},
    -- Both kit models use positioners: the summoning circle sweeps from the
    -- head to the feet over the cast, and the projector is in the left hand,
    -- which is approximated here.
    {id = 210455, races = {11, 30}, previewSpellVisualKitID = 198294, previewAnimationKitID = 28517,
        previewEffectModels = {
            {fileID = 4226513, z = 0, animationKitID = 29400, rise = {from = 1, duration = 10}},
            {fileID = 5479266, x = 0.2, y = 0.12, z = 0.75, animationID = 158},
        }},
    {id = 212337, previewSpellVisualKitID = 174334, previewAnimationKitID = 26649},
    {id = 228940, previewSpellVisualKitID = 210248, previewAnimationKitID = 30897},
    {id = 263489, previewSpellVisualKitID = 251306, previewAnimationID = 52},
    {id = 236687, previewSpellVisualKitID = 224060, previewAnimationKitID = 32318},
    {id = 246565, previewSpellVisualKitID = 235783, previewAnimationKitID = 19057},
    {id = 245970, previewSpellVisualKitID = 234534, previewAnimationID = 52},
    -- Spell 1217281 has no visual, so this uses the Redeployment Module aura
    -- visual. It dissolves the caster, so the actor is rebuilt afterward.
    {id = 235016, previewSpellVisualKitID = 217747, previewAnimationKitID = 31526,
        previewRebuildAfter = true},
    {id = 265100, previewSpellVisualKitID = 252859, previewAnimationKitID = 19057},
    -- Kit 127176 attaches the same hand glow as kit 248146 directly to the
    -- hands, since 248146's positioners do not render. The final aura plays
    -- at 9.65s in game and is shown earlier so it appears before cleanup.
    {id = 257736, previewSpellVisualKitID = {247250, 127176}, previewAnimationKitID = 35175,
        previewEffectModels = {
            {fileID = 6795071, x = 0.55, z = 0.5, scale = 0.75,
                yaw = math.pi, pitch = -0.349, rise = {from = -0.3, duration = 2}},
            {fileID = 5870752, x = 0.8, z = 0.4, animationKitID = 35203,
                rise = {from = -0.3, duration = 2}},
            {fileID = 5550643, x = 0.8, z = 0.18, scale = 0.5},
            {fileID = 5503527, x = 0.8, scale = 0.5},
            {fileID = 5635867, x = 0.8, scale = 0.8, delay = 8.5},
        }},
    {id = 263933, previewSpellVisualKitID = 251445, previewAnimationID = 52},
    -- The toadstool ring (kit 259619) and Fungarians come from aura 1271852.
    -- It spawns a Fungarian area trigger at the caster's front-right,
    -- front-left, back-left and back-right every 0.5s from 0.5s to 2s. Each
    -- beams a spore orb at the caster, shown here as the orb at its hands.
    -- They spawn 5 yards out in game and are pulled in to stay on camera.
    {id = 264367, previewSpellVisualKitID = {268818, 259619}, previewAnimationKitID = 26949,
        previewEffectModels = {
            {fileID = 7525314, animationID = 158},
            {displayID = 139419, x = 0.9,  y = -0.9, yaw = 3 * math.pi / 4,
                animationID = 125, delay = 0.5, rise = {from = -0.6, duration = 0.4}},
            {displayID = 139418, x = 0.9,  y = 0.9,  yaw = -3 * math.pi / 4,
                animationID = 125, delay = 1,   rise = {from = -0.6, duration = 0.4}},
            {displayID = 139438, x = -0.9, y = 0.9,  yaw = -math.pi / 4,
                animationID = 125, delay = 1.5, rise = {from = -0.6, duration = 0.4}},
            {displayID = 139445, x = -0.9, y = -0.9, yaw = math.pi / 4,
                animationID = 125, delay = 2,   rise = {from = -0.6, duration = 0.4}},
            {fileID = 6920502, x = 0.58,  y = -0.58, z = 0.6, animationID = 158, delay = 1.5},
            {fileID = 6920502, x = 0.58,  y = 0.58,  z = 0.6, animationID = 158, delay = 2},
            {fileID = 6920502, x = -0.58, y = 0.58,  z = 0.6, animationID = 158, delay = 2.5},
            {fileID = 6920502, x = -0.58, y = -0.58, z = 0.6, animationID = 158, delay = 3},
        }},
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
