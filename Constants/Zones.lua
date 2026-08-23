local addonName, ns = ...
local L = ns.L

ns.Constants = ns.Constants or {}

ns.Constants.MAJOR_ZONES = {
    {name = "Founder's Point", mapID = 2352, situation = "rest", icon = "spell_housing"},
    {name = "Razorwind Shores", mapID = 2351, situation = "rest", icon = "spell_housing"},

    {name = "Silvermoon City",             mapID = 2393, situation = "rest", icon = "spell_arcane_teleportsilvermoon"},
    {name = "Eversong Woods",              mapID = 2395, situation = "world", icon = "achievement_zone_eversongwoods"},
    {name = "Isle of Quel'Danas",          mapID = 2424, situation = "world", icon = "achievement_zone_isleofqueldanas"},
    {name = "Zul'Aman",                    mapID = 2437, situation = "world", icon = "inv_achievement_zone_zulaman1"},
    {name = "Harandar",                    mapID = 2413, situation = "world", icon = "inv_achievement_zone_harandar"},
    {name = "Voidstorm",                   mapID = 2405, situation = "world", icon = "inv_battleground_voidstorm"},
    {name = "The Coiled Isle",             mapID = 2512, situation = "world", icon = "inv_achievement_zone_zulaman"},

    {name = "Dornogal",                    mapID = 2339, situation = "rest", icon = "inv_spell_arcane_telepotdornogal"},
    {name = "Isle of Dorn",                mapID = 2248, situation = "world", icon ="achievement_zone_isleofdorn"},
    {name = "The Ringing Deeps",           mapID = 2214, situation = "world", icon = "achievement_zone_theringingdeeps"},
    {name = "Hallowfall",                  mapID = 2215, situation = "world", icon = "achievement_zone_hallowfall"},
    {name = "Azj-Kahet",                   mapID = 2255, situation = "world", icon = "achievement_zone_azjkahet"},
    {name = "City of Threads",             mapID = 2256, situation = "world", icon = "inv_achievement_dungeon_cityofthreads"},
    {name = "Siren Isle",                  mapID = 2369, situation = "world", icon = "inv_siren_isle_ring"},
    {name = "Undermine",                   mapID = 2346, situation = "world", icon = "inv_achievement_zone_undermine"},
    {name = "K'aresh",                     mapID = 2371, situation = "world", icon = "inv_112_achievement_zone_karesh"},
    {name = "Tazavesh, the Veiled Market", mapID = 2472, situation = "rest", icon = "achievement_dungeon_brokerdungeon"},

    {name = "Valdrakken",                  mapID = 2112, situation = "rest", icon = "spell_arcane_teleportvaldrakken"},
    {name = "The Waking Shores",           mapID = 2022, situation = "world", icon = "achievement_zone_wakingshores"},
    {name = "Ohn'ahran Plains",            mapID = 2023, situation = "world", icon = "achievement_zone_ohnahranplains"},
    {name = "The Azure Span",              mapID = 2024, situation = "world", icon = "achievement_zone_azurespan"},
    {name = "Thaldraszus",                 mapID = 2025, situation = "world", icon = "achievement_zone_thaldraszus"},
    {name = "Zaralek Cavern",              mapID = 2133, situation = "world", icon = "achievement_zone_zaralekcavern"},
    {name = "Emerald Dream",               mapID = 2200, situation = "world", icon = "inv_achievement_raidemeralddream_raid"},

    {name = "Oribos",                      mapID = 1670, situation = "rest", icon = "spell_arcane_teleportoribos"},
    {name = "Bastion",                     mapID = 1533, situation = "world", icon = "inv_bastion"},
    {name = "Maldraxxus",                  mapID = 1536, situation = "world", icon = "inv_maldraxxus"},
    {name = "Ardenweald",                  mapID = 1565, situation = "world", icon = "inv_ardenweald"},
    {name = "Revendreth",                  mapID = 1525, situation = "world", icon = "inv_revendreth"},
    {name = "The Maw",                     mapID = 1543, situation = "world", icon = "inv_torghast"},
    {name = "Korthia",                     mapID = 1961, situation = "world", icon = "achievement_raid_torghastraid"},
    {name = "Zereth Mortis",               mapID = 1970, situation = "world", icon = "achievement_zone_zerethmortis"},

    {name = "Boralus",                     mapID = 1161, situation = "rest", icon = "spell_arcane_portalkultiras"},
    {name = "Dazar'alor",                  mapID = 1165, situation = "rest", icon = "spell_arcane_portalzandalar"},
    {name = "Tiragarde Sound",             mapID = 895,  situation = "world", icon = "inv_tiragardesound"},
    {name = "Drustvar",                    mapID = 896,  situation = "world", icon = "inv_drustvar"},
    {name = "Stormsong Valley",            mapID = 942,  situation = "world", icon = "inv_stormsongvalley"},
    {name = "Zuldazar",                    mapID = 862,  situation = "world", icon = "inv_zuldazar"},
    {name = "Nazmir",                      mapID = 863,  situation = "world", icon = "inv_nazmir"},
    {name = "Vol'dun",                     mapID = 864,  situation = "world", icon = "inv_voldun"},
    {name = "Nazjatar",                    mapID = 1355, situation = "world", icon = "achievement_boss_nagazone"},
    {name = "Mechagon",                    mapID = 1462, situation = "world", icon = "ui_endeavor_mechagon"},

    {name = "Dalaran (Legion)",            mapID = 627,  situation = "rest", icon = "spell_arcane_teleportdalaranbrokenisles"},
    {name = "Azsuna",                      mapID = 630,  situation = "world", icon = "achievements_zone_azsuna"},
    {name = "Val'sharah",                  mapID = 641,  situation = "world", icon = "achievements_zone_valsharah"},
    {name = "Highmountain",               mapID = 650,  situation = "world", icon = "achievements_zone_highmountain"},
    {name = "Stormheim",                   mapID = 634,  situation = "world", icon = "achievements_zone_stormheim"},
    {name = "Suramar",                     mapID = 680,  situation = "world", icon = "achievements_zone_suramar"},
    {name = "Broken Shore",                mapID = 646,  situation = "world", icon = "achievements_zone_brokenshore"},
    {name = "Argus",                       mapID = 905,  situation = "world", icon = "achievement_raid_argusraid"},

    {name = "Ashran (Alliance)",           mapID = 588,  situation = "world", icon = "achievement_zone_ashran"},
    {name = "Ashran (Horde)",              mapID = 590,  situation = "world", icon = "achievement_zone_ashran"},
    {name = "Frostfire Ridge",             mapID = 525,  situation = "world", icon = "achievement_zone_frostfire"},
    {name = "Shadowmoon Valley (Draenor)", mapID = 539,  situation = "world", icon = "achievement_zone_newshadowmoonvalley"},
    {name = "Gorgrond",                    mapID = 543,  situation = "world", icon = "achievement_zone_gorgrond"},
    {name = "Talador",                     mapID = 535,  situation = "world", icon = "achievement_zone_talador"},
    {name = "Spires of Arak",              mapID = 542,  situation = "world", icon = "achievement_zone_spiresofarak"},
    {name = "Nagrand (Draenor)",           mapID = 550,  situation = "world", icon = "achievement_zone_nagrand_02"},
    {name = "Tanaan Jungle",               mapID = 534,  situation = "world", icon = "achievement_zone_tanaanjungle"},

    {name = "The Jade Forest",             mapID = 371,  situation = "world", icon = "achievement_zone_jadeforest"},
    {name = "Valley of the Four Winds",    mapID = 376,  situation = "world", icon = "achievement_zone_valleyoffourwinds"},
    {name = "Krasarang Wilds",             mapID = 418,  situation = "world", icon = "achievement_zone_krasarangwilds"},
    {name = "Kun-Lai Summit",              mapID = 379,  situation = "world", icon = "achievement_zone_kunlaisummit"},
    {name = "Townlong Steppes",            mapID = 388,  situation = "world", icon = "achievement_zone_townlongsteppes"},
    {name = "Dread Wastes",                mapID = 422,  situation = "world", icon = "achievement_zone_dreadwastes"},
    {name = "Vale of Eternal Blossoms",    mapID = 390,  situation = "world", icon = "achievement_zone_valeofeternalblossoms"},
    {name = "Isle of Thunder",             mapID = 504,  situation = "world", icon = "achievement_raid_thunder_king"},
    {name = "Timeless Isle",               mapID = 554,  situation = "world", icon = "timelesscoin_yellow"},

    {name = "Mount Hyjal",                 mapID = 198,  situation = "world", icon = "achievement_zone_mount hyjal"},
    {name = "Vashj'ir",                    mapID = 203,  situation = "world", icon = "achievement_zone_vashjir"},
    {name = "Deepholm",                    mapID = 207,  situation = "world", icon = "achievement_zone_deepholm"},
    {name = "Uldum",                       mapID = 249,  situation = "world", icon = "achievement_zone_uldum"},
    {name = "Twilight Highlands",          mapID = 241,  situation = "world", icon = "achievement_zone_twilighthighlands"},
    {name = "Tol Barad",                   mapID = 245,  situation = "world", icon = "achievement_zone_tolbarad"},
    {name = "Southern Barrens",            mapID = 199,  situation = "world", icon = "achievement_zone_barrens_01"},
    {name = "Gilneas",                     mapID = 217,  situation = "world", icon = "achievement_battleground_battleforgilneas"},

    {name = "Dalaran (Northrend)",         mapID = 125,  situation = "rest", icon = "spell_arcane_teleportdalaran"},
    {name = "Crystalsong Forest",          mapID = 113,  situation = "world", icon = "achievement_zone_crystalsong_01"},
    {name = "Borean Tundra",               mapID = 114,  situation = "world", icon = "achievement_zone_boreantundra_01"},
    {name = "Howling Fjord",               mapID = 117,  situation = "world", icon = "achievement_zone_howlingfjord_01"},
    {name = "Dragonblight",                mapID = 115,  situation = "world", icon = "achievement_zone_dragonblight_01"},
    {name = "Grizzly Hills",               mapID = 116,  situation = "world", icon = "achievement_zone_grizzlyhills_01"},
    {name = "Zul'Drak",                    mapID = 121,  situation = "world", icon = "achievement_zone_zuldrak_01"},
    {name = "Sholazar Basin",              mapID = 119,  situation = "world", icon = "achievement_zone_sholazar_01"},
    {name = "Icecrown",                    mapID = 118,  situation = "world", icon = "achievement_zone_icecrown_01"},
    {name = "Storm Peaks",                 mapID = 120,  situation = "world", icon = "achievement_zone_stormpeaks_01"},
    {name = "Wintergrasp",                 mapID = 123,  situation = "world", icon = "inv_essenceofwintergrasp"},

    {name = "Hellfire Peninsula",          mapID = 100,  situation = "world", icon = "achievement_zone_hellfirepeninsula_01"},
    {name = "Zangarmarsh",                 mapID = 102,  situation = "world", icon = "achievement_zone_zangarmarsh"},
    {name = "Terokkar Forest",             mapID = 108,  situation = "world", icon = "achievement_zone_terrokar"},
    {name = "Nagrand (Outland)",           mapID = 107,  situation = "world", icon = "achievement_zone_nagrand_01"},
    {name = "Blade's Edge Mountains",      mapID = 105,  situation = "world", icon = "achievement_zone_bladesedgemtns_01"},
    {name = "Netherstorm",                 mapID = 109,  situation = "world", icon = "achievement_zone_netherstorm_01"},
    {name = "Shadowmoon Valley (Outland)", mapID = 104,  situation = "world", icon = "achievement_zone_shadowmoon"},
    {name = "Silvermoon City (Burning Crusade)",       mapID = 110,  situation = "rest", icon = "spell_arcane_teleportsilvermoon"},
    {name = "Isle of Quel'Danas (Burning Crusade)",    mapID = 122,  situation = "world", icon = "achievement_zone_isleofqueldanas"},
    {name = "Eversong Woods (Burning Crusade)",        mapID = 94,   situation = "world", icon = "achievement_zone_eversongwoods"},
    {name = "Ghostlands",            mapID = 95,   situation = "world", icon = "achievement_zone_ghostlands"},

    {name = "Stormwind City",              mapID = 84,   situation = "rest", icon = "spell_arcane_teleportstormwind"},
    {name = "Ironforge",                   mapID = 87,   situation = "rest", icon = "spell_arcane_teleportironforge"},
    {name = "Darnassus",                   mapID = 89,   situation = "rest", icon = "spell_arcane_teleportdarnassus"},
    {name = "The Exodar",                  mapID = 103,  situation = "rest", icon = "spell_arcane_teleportexodar"},
    {name = "Orgrimmar",                   mapID = 85,   situation = "rest", icon = "spell_arcane_teleportorgrimmar"},
    {name = "Thunder Bluff",               mapID = 88,   situation = "rest", icon = "spell_arcane_teleportthunderbluff"},
    {name = "Undercity",                   mapID = 90,   situation = "rest", icon = "spell_arcane_teleportundercity"},
    {name = "Elwynn Forest",               mapID = 37,   situation = "world", icon = "achievement_zone_elwynnforest"},
    {name = "Dun Morogh",                  mapID = 27,   situation = "world", icon = "achievement_zone_dunmorogh"},
    {name = "Teldrassil",                  mapID = 57,   situation = "world", icon = "10_2_raidability_flamingtree"},
    {name = "Azuremyst Isle",              mapID = 97,   situation = "world", icon = "achievement_zone_azuremystisle_01"},
    {name = "Durotar",                     mapID = 1,    situation = "world", icon = "achievement_zone_durotar"},
    {name = "Swamp of Sorrows",            mapID = 8,    situation = "world", icon = "achievement_zone_swampsorrows_01"},
    {name = "Mulgore",                     mapID = 7,    situation = "world", icon = "achievement_zone_mulgore_01"},
    {name = "Northern Stranglethorn",      mapID = 50,   situation = "world", icon = "achievement_zone_stranglethorn_01"},
    {name = "The Cape of Stranglethorn",   mapID = 210,  situation = "world", icon = "achievement_zone_stranglethorn_01"},
    {name = "Tirisfal Glades",             mapID = 18,   situation = "world", icon = "achievement_zone_tirisfalglades_01"},
    {name = "Westfall",                    mapID = 40,   situation = "world", icon = "achievement_zone_westfall_01"},
    {name = "Loch Modan",                  mapID = 48,   situation = "world", icon = "achievement_zone_lochmodan"},
    {name = "Darkshore",                   mapID = 62,   situation = "world", icon = "achievement_zone_darkshore_01"},
    {name = "The Barrens",                 mapID = 10,   situation = "world", icon = "achievement_zone_barrens_01"},
    {name = "Silverpine Forest",           mapID = 21,   situation = "world", icon = "achievement_zone_silverpine_01"},
    {name = "Redridge Mountains",          mapID = 49,   situation = "world", icon = "achievement_zone_redridgemountains"},
    {name = "Stonetalon Mountains",        mapID = 65,   situation = "world", icon = "achievement_zone_stonetalon_01"},
    {name = "Ashenvale",                   mapID = 63,   situation = "world", icon = "achievement_zone_ashenvale_01"},
    {name = "Thousand Needles",            mapID = 64,   situation = "world", icon = "achievement_zone_thousandneedles_01"},
    {name = "Desolace",                    mapID = 66,   situation = "world", icon = "achievement_zone_desolace"},
    {name = "Dustwallow Marsh",            mapID = 70,   situation = "world", icon = "achievement_zone_dustwallowmarsh"},
    {name = "Tanaris",                     mapID = 71,   situation = "world", icon = "achievement_zone_tanaris_01"},
    {name = "Felwood",                     mapID = 77,   situation = "world", icon = "achievement_zone_felwood"},
    {name = "Un'Goro Crater",              mapID = 78,   situation = "world", icon = "achievement_zone_ungorocrater_01"},
    {name = "Winterspring",                mapID = 83,   situation = "world", icon = "achievement_zone_winterspring"},
    {name = "Silithus",                    mapID = 81,   situation = "world", icon = "achievement_zone_silithus_01"},
    {name = "Duskwood",                    mapID = 47,   situation = "world", icon = "achievement_zone_duskwood"},
    {name = "Wetlands",                    mapID = 56,   situation = "world", icon = "achievement_zone_wetlands_01"},
    {name = "Arathi Highlands",            mapID = 14,   situation = "world", icon = "achievement_zone_arathihighlands_01"},
    {name = "Hillsbrad Foothills",         mapID = 25,   situation = "world", icon = "achievement_zone_hillsbradfoothills"},
    {name = "The Hinterlands",             mapID = 26,   situation = "world", icon = "achievement_zone_hinterlands_01"},
    {name = "Western Plaguelands",         mapID = 22,   situation = "world", icon = "achievement_zone_westernplaguelands_01"},
    {name = "Eastern Plaguelands",         mapID = 23,   situation = "world", icon = "achievement_zone_easternplaguelands"},
    {name = "Badlands",                    mapID = 15,   situation = "world", icon = "achievement_zone_badlands_01"},
    {name = "Searing Gorge",               mapID = 32,   situation = "world", icon = "achievement_zone_searinggorge_01"},
    {name = "Burning Steppes",             mapID = 36,   situation = "world", icon = "achievement_zone_burningsteppes_01"},
    {name = "Blasted Lands",               mapID = 17,   situation = "world", icon = "achievement_zone_blastedlands_01"},
    {name = "Deadwind Pass",               mapID = 42,   situation = "world", icon = "achievement_zone_deadwindpass"},
    {name = "Bloodmyst Isle",              mapID = 106,  situation = "world", icon = "achievement_zone_bloodmystisle_01"},
    {name = "Moonglade",                   mapID = 80,   situation = "world", icon = "spell_arcane_teleportmoonglade"},
    {name = "Feralas",                     mapID = 69,   situation = "world", icon = "achievement_zone_feralas"},
}

ns.Constants.BIOME_GROUPS = {
    { key = "arctic", label = L["Arctic"], mapIDs = {
        114, 117, 118, 120, 123, 379, 525, 83,
    }},
    { key = "forest", label = L["Forest"], mapIDs = {
        2395, 2437, 630, 641, 1565, 371, 418, 198, 116, 108,
        37, 57, 62, 21, 63, 77, 47, 26, 22, 23, 95, 106, 80, 217,
    }},
    { key = "jungle", label = L["Jungle"], mapIDs = {
        2413, 863, 534, 418, 78, 210, 50, 69,
    }},
    { key = "desert", label = L["Desert"], mapIDs = {
        864, 249, 71, 81, 2371, 15, 32, 36, 17,
    }},
    { key = "plains", label = L["Plains"], mapIDs = {
        2023, 376, 107, 550, 942, 7, 10, 14, 25, 199,
    }},
    { key = "mountain", label = L["Mountain"], mapIDs = {
        2437, 2022, 2025, 650, 542, 105, 241, 49, 65, 120, 379,
    }},
    { key = "swamp", label = L["Swamp"], mapIDs = {
        863, 102, 70, 64, 66, 8, 56,
    }},
    { key = "city", label = L["Cities"], mapIDs = {
        2393, 2339, 2346, 2112, 1670, 1161, 1165, 627,
        125, 110, 84, 85, 87, 88, 89, 90, 103,
    }},
}

ns.Constants.EXPANSION_ZONES = {
    { key = "midnight", label = L["Midnight"], mapIDs = {2393, 2395, 2437, 2413, 2405, 2512} },
    { key = "tww", label = L["The War Within"], mapIDs = {2339, 2248, 2214, 2215, 2255, 2256, 2369, 2346, 2371, 2472} },
    { key = "dragonflight", label = L["Dragonflight"], mapIDs = {2112, 2022, 2023, 2024, 2025, 2133, 2200} },
    { key = "shadowlands", label = L["Shadowlands"], mapIDs = {1670, 1533, 1536, 1565, 1525, 1543, 1961, 1970} },
    { key = "bfa", label = L["Battle for Azeroth"], mapIDs = {1161, 1165, 895, 896, 942, 862, 863, 864, 1355, 1462} },
    { key = "legion", label = L["Legion"], mapIDs = {627, 630, 641, 650, 634, 680, 646, 905} },
    { key = "wod", label = L["Warlords of Draenor"], mapIDs = {588, 590, 525, 539, 543, 535, 542, 550, 534} },
    { key = "mop", label = L["Mists of Pandaria"], mapIDs = {371, 376, 418, 379, 388, 422, 390, 504, 554} },
    { key = "cata", label = L["Cataclysm"], mapIDs = {198, 203, 207, 249, 241, 245, 199, 217} },
    { key = "wrath", label = L["Wrath of the Lich King"], mapIDs = {125, 113, 114, 117, 118, 120, 123, 379} },
    { key = "bc", label = L["Burning Crusade"], mapIDs = {100, 102, 108, 107, 105, 109, 104, 110, 122, 94, 95} },
    { key = "classic", label = L["Classic"], mapIDs = {84, 87, 89, 103, 85, 88, 90, 37, 27, 57, 97, 1, 8, 7, 50, 210, 18, 40, 48, 62, 10, 21, 63, 77, 47, 56, 14, 25, 26, 22, 23, 15, 32, 36, 17, 42, 106, 80, 69} },
}

ns.Constants.CONTINENT_ZONES = {
    { key = "khazalgar", label = L["Khaz Algar"], mapIDs = {2339, 2248, 2214, 2215, 2255, 2256, 2369, 2346} },
    { key = "karesh", label = L["K'aresh"], mapIDs = {2371, 2472} },
    { key = "dragonisles", label = L["Dragon Isles"], mapIDs = {2112, 2022, 2023, 2024, 2025, 2133, 2200} },
    { key = "kultiras", label = L["Kul Tiras"], mapIDs = {1161, 895, 896, 942, 1462} },
    { key = "zandalar", label = L["Zandalar"], mapIDs = {1165, 862, 863, 864} },
    { key = "nazjatar", label = L["Nazjatar"], mapIDs = {1355} },
    { key = "brokenisles", label = L["Broken Isles"], mapIDs = {627, 630, 641, 650, 634, 680, 646} },
    { key = "argus", label = L["Argus"], mapIDs = {905} },
    { key = "draenor", label = L["Draenor"], mapIDs = {588, 590, 525, 539, 543, 535, 542, 550, 534} },
    { key = "pandaria", label = L["Pandaria"], mapIDs = {371, 376, 418, 379, 388, 422, 390, 504, 554} },
    { key = "northrend", label = L["Northrend"], mapIDs = {125, 113, 114, 117, 115, 116, 121, 119, 118, 120, 123} },
    { key = "outland", label = L["Outland"], mapIDs = {100, 102, 108, 107, 105, 109, 104} },
    { key = "easternkingdoms", label = L["Eastern Kingdoms"], mapIDs = {
        110, 122, 94, 95, 84, 87, 90, 37, 27, 8, 50, 210, 18, 40, 48,
        21, 49, 47, 56, 14, 25, 26, 22, 23, 15, 32, 36, 17, 42, 217, 203, 241, 245, 2393, 2395, 2437, 2413, 2405, 2424
    }},
    { key = "kalimdor", label = L["Kalimdor"], mapIDs = {
        89, 103, 85, 88, 57, 97, 1, 7, 62, 10, 63, 65, 64, 66, 70, 71,
        77, 78, 83, 81, 106, 80, 69, 198, 249, 199,
    }},
    { key = "elementalplanes", label = L["Elemental Planes"], mapIDs = {207} },
}

local zoneSituationMap = {}
for _, zoneData in ipairs(ns.Constants.MAJOR_ZONES) do
    zoneSituationMap[zoneData.mapID] = zoneData.situation
end
ns.Constants.ZONE_SITUATION_MAP = zoneSituationMap

local cityMapIDSet = {}
for _, biome in ipairs(ns.Constants.BIOME_GROUPS) do
    if biome.key == "city" then
        for _, mapID in ipairs(biome.mapIDs) do
            cityMapIDSet[mapID] = true
        end
        break
    end
end
ns.Constants.CITY_MAP_IDS = cityMapIDSet
