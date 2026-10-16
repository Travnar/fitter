local addonName, ns = ...

ns.Constants = ns.Constants or {}

-- Preview fields come from each toy's spell chain (item spell plus triggered
-- spells) in the client DB2 data:
--   previewTransformDisplayID / previewTransformCreatureID: SPELL_AURA_TRANSFORM
--     target; creature IDs are resolved to a display at runtime.
--   previewSpellVisualKitID: aura start-to-end visual kits on the caster; a
--     {Alliance, Horde} table when the toy's script picks a faction spell.
--   previewEquipItemID: items those kits equip (procedural effect 17).
-- Some toys apply only a dummy aura and the server casts the visible spell;
-- those use the same-named spell next to it (first variant when several).
ns.Constants.KNOWN_TOYS = {
    {id = 1973},   -- Orb of Deception
    {id = 18660},  -- World Enlarger
    {id = 35227},  -- Goblin Weather Machine - Prototype 01-B
    {id = 35275},  -- Orb of the Sin'dorei
    {id = 64373},  -- Chalice of the Mountain Kings
    {id = 64881},  -- Pendant of the Scarab Storm
    {id = 68806, previewTransformCreatureID = 35567,
        previewSpellVisualKitID = 15927}, -- Kalytha's Haunted Locket
    {id = 86568, previewTransformCreatureID = 65012, previewSpellVisualKitID = 28343}, -- Mr. Smite's Brass Compass
    {id = 86571, previewSpellVisualKitID = {28453, 28454}}, -- Kang's Bindstone
    {id = 86573, previewTransformCreatureID = 68309,
        previewSpellVisualKitID = 28458, previewEquipItemID = 111532}, -- Shard of Archstone
    {id = 86578, previewSpellVisualKitID = 28485}, -- Eternal Warrior's Sigil
    {id = 86582, previewSpellVisualKitID = 28405}, -- Aqua Jewel
    {id = 86589},  -- Ai-Li's Skymirror
    --{id = 88579},  -- Jin Warmkeg's Brewf
    {id = 95589},  -- Glorious Standard of the Kirin Tor Offensive
    {id = 104262, previewSpellVisualKitID = {28453, 28454}}, -- Odd Polished Stone
    {id = 104294, previewTransformCreatureID = 73731,
        previewSpellVisualKitID = 37039, previewEquipItemID = {90030, 62190}}, -- Rime of the Time-Lost Mariner
    {id = 113096, previewTransformCreatureID = 82076}, -- Bloodmane Charm
    {id = 116115, previewSpellVisualKitID = 48704}, -- Blazing Wings
    {id = 118716, previewTransformCreatureID = 81586}, -- Goren Garb
    {id = 119003}, -- Void Totem
    {id = 119092, previewSpellVisualKitID = {51682, 28621, 51684},
        previewEquipItemID = {62814, 62816}}, -- Moroes' Famous Polish
    {id = 119093, previewSpellVisualKitID = {51644, 51642}}, -- Aviana's Feather
    {id = 119182}, -- Soul Evacuation Crystal
    {id = 128807}, -- Coin of Many Faces
    {id = 133997}, -- Black Ice
    {id = 134026, previewSpellVisualKitID = {Alliance = 67869, Horde = 83725},
        previewAltSpellVisualKitID = {Alliance = 83723, Horde = 83726}}, -- Honorable Pennant
    {id = 134031, previewSpellVisualKitID = {Alliance = 67872, Horde = 67876},
        previewAltSpellVisualKitID = {Alliance = 83728, Horde = 83730}}, -- Prestigious Pennant
    {id = 134034, previewSpellVisualKitID = {Alliance = 67874, Horde = 67878},
        previewAltSpellVisualKitID = {Alliance = 83736, Horde = 83738}}, -- Esteemed Pennant
    {id = 173984, previewSpellVisualKitID = 121720}, -- Scroll of Aeons
    {id = 202022, previewSpellVisualKitID = 171274}, -- Yennu's Kite
    {id = 217726, previewSpellVisualKitID = 36398}, -- Fortitude of Niuzao
    {id = 217723, previewSpellVisualKitID = 36396}, -- Fury of Xuen
    {id = 217724, previewSpellVisualKitID = 36399}, -- Kindness of Chi-Ji
    {id = 217725, previewSpellVisualKitID = 36397}, -- Essence of Yu'lon
    {id = 116440, previewTransformCreatureID = 85873}, -- Burning Defender's Medallion
    {id = 147537, previewSpellVisualKitID = 82672}, -- A Tiny Set of Warglaives
    {id = 187840, previewSpellVisualKitID = 150511, previewEquipItemID = 60618}, -- Sparkle Wings
    {id = 122293, previewSpellVisualKitID = 49669}, -- Trans-Dimensional Bird Whistle
    {id = 220777, previewSpellVisualKitID = 199923}, -- Cherry Blossom Trail
    {id = 228413, previewSpellVisualKitID = 209375}, -- Lampyridae Lure
    {id = 150547, previewSpellVisualKitID = 83625}, -- Jolly Roger
    {id = 244470, previewSpellVisualKitID = 233091}, -- Etheric Victory
    {id = 264413, previewSpellVisualKitID = 252167}, -- Dominating Victory
    {id = 201927, previewSpellVisualKitID = 162823}, -- Gleaming Arcanocrystal
    {id = 205418, previewSpellVisualKitID = 179052}, -- Blazing Shadowflame Cinder
    {id = 129149, previewSpellVisualKitID = 35212}, -- Death's Door Charm
    {id = 246903, previewSpellVisualKitID = {221887, 231563}}, -- Guise of the Phase Diver
    {id = 206993, previewSpellVisualKitID = 182686}, -- Investi-gator's Pocketwatch
    {id = 250319, previewSpellVisualKitID = 240588}, -- Researcher's Shadowgraft
    {id = 205904, previewTransformCreatureID = 205296}, -- Vibrant Clacking Claw
    {id = 122283, previewTransformCreatureID = 90773}, -- Rukhmar's Sacred Memory
    {id = 191891, previewTransformCreatureID = 187854,
        previewSpellVisualKitID = 157210}, -- Professor Chirpsnide's Im-PECK-able Harpy Disguise
    {id = 202253, previewTransformCreatureID = 189372}, -- Primal Stave of Claw and Fur
    {id = 268717, previewTransformCreatureID = 260345}, -- Pango Plating
    {id = 252265, previewTransformCreatureID = 251887}, -- Hexed Potatoad Mucus
    {id = 64646, previewTransformCreatureID = 41979}, -- Bones of Transformation
    {id = 200960, previewTransformCreatureID = 176925}, -- Seed of Renewed Souls
    {id = 187913, previewSpellVisualKitID = 150817}, -- Apprentice Slimemancer's Boots
    {id = 202042, previewSpellVisualKitID = 171393, previewEquipItemID = 202041}, -- Aquatic Shades
    {id = 183847, previewTransformCreatureID = 173467}, -- Acolyte's Guise
    {id = 259899, previewSpellVisualKitID = {249212, 249213}}, -- Ashen Horn of the Fallen Keeper
    {id = 187139, previewTransformCreatureID = 180048}, -- Bottled Shade Heart
    {id = 71137, previewSpellVisualKitID = 20917}, -- Brewfest Keg Pony
    {id = 224552, previewSpellVisualKitID = 203471, previewEquipItemID = 151262}, -- Cave Spelunker's Torch
    {id = 138878}, -- Copy of Daglop's Contract
    {id = 235041}, -- Cyrce's Circlet
    {id = 212523, previewSpellVisualKitID = {192473, 192432, 192429}}, -- Delicate Jade Parasol
    {id = 209858}, -- Dreamsurge Remnant
    {id = 129113, previewTransformCreatureID = 98023}, -- Faintly Glowing Flagon of Mead
    {id = 208421}, -- Compendium of the New Moon
    {id = 160740}, -- Croak Crock
    {id = 122117, previewTransformCreatureID = 90281,
        previewSpellVisualKitID = 53315}, -- Cursed Feather of Ikzan
    {id = 166544, previewTransformCreatureID = 149140}, -- Dark Ranger's Spare Cowl
    {id = 122123, previewSpellVisualKitID = 18352}, -- Darkmoon Ring-Flinger
    {id = 108743, previewSpellVisualKitID = 42758}, -- Deceptia's Smoldering Boots
    {id = 159753}, -- Desert Flute
    {id = 134831}, -- Doomsayer's Robes
    {id = 64361, previewSpellVisualKitID = 19008}, -- Druid and Priest Statue Set
    {id = 244888}, -- Echo of Xal'atath, Blade of the Black Empire
    {id = 134007}, -- Eternal Black Diamond Ring
    {id = 225547, previewSpellVisualKitID = 198301}, -- Toxic Victory
    {id = 64651, previewTransformCreatureID = 3681}, -- Wisp Amulet
    {id = 53057},  -- Faded Wizard Hat
    {id = 140780, previewTransformCreatureID = 113068}, -- Fal'dorei Egg
    {id = 209859, previewSpellVisualKitID = 187324}, -- Festive Trans-Dimensional Bird Whistle
    {id = 235220, previewSpellVisualKitID = 221496, previewEquipItemID = 235219}, -- Fireworks Hat
    {id = 44719, previewTransformCreatureID = 32584}, -- Frenzyheart Brew
    {id = 118937, previewTransformCreatureID = 88007,
        previewSpellVisualKitID = 51585, previewEquipItemID = 63252}, -- Gamon's Braid
    {id = 161342, previewSpellVisualKitID = 100534, previewEquipItemID = 60746}, -- Gem of Acquiescence
    {id = 208186, previewSpellVisualKitID = 184127}, -- Boffins
    {id = 245946}, -- Brewer's Balloon
    {id = 116758, previewSpellVisualKitID = 49146}, -- Brewfest Banner
    {id = 134020, previewSpellVisualKitID = 64303, previewEquipItemID = 134013}, -- Chef's Hat
    {id = 228789}, -- Coldflame Ring
    {id = 129165, previewTransformCreatureID = 93033}, -- Barnacle-Encrusted Gem
    {id = 104302}, -- Blackflame Daggers
    {id = 183988, previewSpellVisualKitID = 138642}, -- Bondable Val'kyr Diadem
    {id = 249713}, -- Cartel Transmorpher
    {id = 131812, previewSpellVisualKitID = 61005}, -- Darkshard Fragment
    {id = 230727, previewSpellVisualKitID = 213610}, -- Explosive Victory
    {id = 209944}, -- Friendsurge Defenders
    {id = 233202, previewTransformCreatureID = 234479}, -- G.O.L.E.M, Jr.
    {id = 179393}, -- Mirror of Envious Dreams
    {id = 141862, previewTransformCreatureID = 114582,
        previewSpellVisualKitID = 76114}, -- Mote of Light
    {id = 130158, previewSpellVisualKitID = 60690}, -- Path of Elothir
    {id = 187113}, -- Personal Ball and Chain
    {id = 127864, previewSpellVisualKitID = 57174}, -- Personal Spotlight
    {id = 225910, previewTransformCreatureID = 226964}, -- Pileus Delight
    {id = 200636, previewTransformCreatureID = 197477}, -- Primal Invocation Quintessence
    {id = 140309, previewSpellVisualKitID = 73316}, -- Prismatic Bauble
    {id = 256881, previewTransformCreatureID = 254059,
        previewSpellVisualKitID = 246705}, -- Steward's Bauble
    {id = 152982, previewTransformCreatureID = 127971}, -- Vixx's Chest of Tricks
    {id = 141306, previewSpellVisualKitID = 74718}, -- Wisp in a Bottle
    {id = 109183}, -- World Shrinker
    {id = 235017, previewSpellVisualKitID = 222665}, -- Glittering Vault Shard
    {id = 138900, previewSpellVisualKitID = 70689, previewEquipItemID = 60746}, -- Gravil Goldbraid's Famous Sausage Hat
    {id = 187155, previewTransformCreatureID = 176673}, -- Guise of the Changeling
    {id = 133511, previewTransformCreatureID = 101925}, -- Gurboggle's Gleaming Bauble
    {id = 166790, previewTransformCreatureID = 149649}, -- Highborne Memento
    {id = 140325, previewSpellVisualKitID = 73858, previewEquipItemID = 136830}, -- Home Made Party Mask
    {id = 86593, previewSpellVisualKitID = {28620, 28621, 28622},
        previewEquipItemID = {62814, 62816}}, -- Hozen Beach Ball
    {id = 225641, previewTransformCreatureID = 226283,
        previewSpellVisualKitID = 205004, previewEquipItemID = {169042, 170465}}, -- Illusive Kobyss Lure
    {id = 190926, previewSpellVisualKitID = 155443}, -- Infested Automa Core
    {id = 43499, previewTransformCreatureID = 29370}, -- Iron Boot Flask
    {id = 118244}, -- Iron Buccaneer's Hat
    {id = 127668}, -- Jewel of Hellfire
    {id = 245567}, -- K'aresh Memory Crystal
    {id = 163750, previewTransformCreatureID = 143714}, -- Kovork Kostume
    {id = 88566, previewTransformCreatureID = 65631,
        previewSpellVisualKitID = 28096, previewEquipItemID = {88849, 88850}}, -- Krastinov's Bag of Horrors
    {id = 140786,
        previewSpellVisualKitID = {74326, 74330, 74334, 74335, 74336, 74337, 74331, 74332, 74333}}, -- Ley Spider Eggs
    {id = 71259, previewTransformCreatureID = 54304}, -- Leyara's Locket
    {id = 198857, previewSpellVisualKitID = 162651}, -- Lucky Duck
    {id = 129926, previewTransformCreatureID = 23506}, -- Mark of the Ashtongue
    {id = 167931}, -- Mechagonian Sawblades
    {id = 208658}, -- Mirror of Humility
    {id = 163775, previewSpellVisualKitID = 103447, previewEquipItemID = 9859}, -- Molok Morion
    {id = 101571, previewSpellVisualKitID = 35413, previewEquipItemID = 101572}, -- Moonfang Shroud
    {id = 105898, previewTransformCreatureID = 72371,
        previewSpellVisualKitID = 35564}, -- Moonfang's Paw
    {id = 138873, previewSpellVisualKitID = 53076,
        previewEquipItemID = {120955, 95495}}, -- Mystical Frosh Hat
    {id = 134004, previewSpellVisualKitID = 111660}, -- Noble's Eternal Elementium Signet
    {id = 168824, previewSpellVisualKitID = 112973}, -- Ocean Simulator
    {id = 115468, previewSpellVisualKitID = 52019}, -- Permanent Frost Essence
    {id = 127394, previewTransformCreatureID = 94376}, -- Podling Camouflage
    {id = 108739, previewSpellVisualKitID = 14349}, -- Pretty Draenor Pearl
    {id = 190457, previewTransformCreatureID = 185567}, -- Protopological Cube
    {id = 129093, previewSpellVisualKitID = 59275,
        previewEquipItemID = {129076, 129077}}, -- Ravenbear Disguise
    {id = 119215, previewTransformCreatureID = 88776}, -- Robo-Gnomebulator
    {id = 245631, previewTransformDisplayID = 121918}, -- Royal Visage
    {id = 119134, previewSpellVisualKitID = 46041}, -- Sargerei Disguise
    {id = 174830, previewSpellVisualKitID = 7641}, -- Shadowy Disguise
    {id = 224554, previewSpellVisualKitID = 203496,
        previewEquipItemID = {107849, 151262}}, -- Silver Linin' Scepter
    {id = 205963}, -- Sniffin' Salts
    {id = 156871}, -- Spitzy
    {id = 230924, previewSpellVisualKitID = 214072}, -- Spotlight Materializer 1000
    {id = 163738, previewSpellVisualKitID = 103377, previewEquipItemID = 120431}, -- Syndicate Mask
    {id = 200857, previewTransformCreatureID = 197918}, -- Talisman of Sargha
    {id = 130147, previewTransformCreatureID = 99441,
        previewSpellVisualKitID = 60542, previewEquipItemID = {115802, 92498}}, -- Thistleleaf Branch
    {id = 127709, previewTransformCreatureID = 94596}, -- Throbbing Blood Orb
    {id = 168123, previewSpellVisualKitID = 109123, previewEquipItemID = 168004}, -- Twitching Eyeball
    {id = 141301, previewSpellVisualKitID = 74708}, -- Unstable Powder Box
    {id = 141331, previewTransformCreatureID = 1211}, -- Vial of Green Goo
    {id = 113375, previewSpellVisualKitID = 14349}, -- Vindicator's Armor Polish Kit
    {id = 129938}, -- Will of Northrend
    {id = 165791, previewSpellVisualKitID = 106563,
        previewEquipItemID = {4322, 62816}}, -- Worn Cloak
    {id = 256893, previewTransformCreatureID = 254071}, -- Wretched Dredger's Brand
    {id = 98552},  -- Xan'tish's Flute
    -- Patch 12.1
    {id = 275988, previewSpellVisualKitID = 268325}, -- Corrosive Victory
    {id = 276189, previewTransformCreatureID = 267575,
        previewSpellVisualKitID = {268762, 268760},
        previewEquipItemID = {187518, 242533}}, -- Effigy of Dundun
    {id = 276207, previewTransformCreatureID = 267626,
        previewSpellVisualKitID = 268769}, -- Preyhunter's Masquerade
    {id = 276925, previewTransformCreatureID = 268496}, -- Idol of Ula'tek
    {id = 279021, previewTransformCreatureID = 269968}, -- Forgotten Memento
    {id = 279052, previewSpellVisualKitID = 271533}, -- Ancient Amani Mask
    {id = 280419, previewTransformCreatureID = 271558}, -- Cursed Badge of the Soulcoilers
    -- Patch 12.1.5
    {id = 280820, previewSpellVisualKitID = 275760}, -- Loa-Blessed Victory
    {id = 280821, previewSpellVisualKitID = 275767}, -- Trail of Halazzi
    {id = 280822, previewSpellVisualKitID = 275771}, -- Nalorakk's Strength Charm
    {id = 280823, previewSpellVisualKitID = 275774}, -- Feathers of Akil'zon
    {id = 280825, previewSpellVisualKitID = 275794}, -- Rite of Jan'alai's Flame
}

-- Race:sex pairs (UnitRace raceID, UnitSex) that use previewAltSpellVisualKitID.
-- Pennants attach with different offsets on these body types.
ns.Constants.TOY_PREVIEW_ALT_BODIES = {
    ["2:3"] = true, ["4:3"] = true, ["5:3"] = true, ["6:2"] = true,
    ["6:3"] = true, ["7:2"] = true, ["8:3"] = true, ["11:2"] = true,
    ["22:3"] = true, ["24:3"] = true, ["25:3"] = true, ["26:3"] = true,
    ["27:3"] = true, ["28:2"] = true, ["28:3"] = true, ["30:2"] = true,
    ["31:3"] = true, ["32:2"] = true, ["36:3"] = true, ["37:2"] = true,
    ["52:2"] = true, ["70:2"] = true, ["86:3"] = true, ["91:3"] = true,
}
