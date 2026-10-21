local addonName, ns = ...
local L = ns.L

ns.Constants = ns.Constants or {}

-- eventID is the calendar holiday ID returned by C_Calendar.GetDayEvent.
ns.Constants.HOLIDAYS = {
    { key = "lunarFestival",  eventID = 327, name = L["Lunar Festival"],          icon = "achievement_worldevent_lunar" },
    { key = "loveIsInTheAir", eventID = 423, name = L["Love is in the Air"],      icon = "achievement_worldevent_valentine" },
    { key = "noblegarden",    eventID = 181, name = L["Noblegarden"],             icon = "achievement_noblegarden_chocolate_egg" },
    { key = "childrensWeek",  eventID = 201, name = L["Children's Week"],         icon = "achievement_worldevent_childrensweek" },
    { key = "midsummer",      eventID = 341, name = L["Midsummer Fire Festival"], icon = "inv_summerfest_symbol_high" },
    { key = "brewfest",       eventID = 372, name = L["Brewfest"],                icon = "achievement_worldevent_brewmaster" },
    { key = "hallowsEnd",     eventID = 324, name = L["Hallow's End"],            icon = "achievement_halloween_witch_01" },
    { key = "dayOfTheDead",   eventID = 409, name = L["Day of the Dead"],         icon = "inv_misc_bone_humanskull_02" },
    { key = "pilgrimsBounty", eventID = 404, name = L["Pilgrim's Bounty"],        icon = "achievement_worldevent_thanksgiving" },
    { key = "winterVeil",     eventID = 141, name = L["Feast of Winter Veil"],    icon = "achievement_worldevent_merrymaker" },
    { key = "darkmoonFaire",  eventID = 479, name = L["Darkmoon Faire"],          icon = "inv_misc_ticket_darkmoon_01" },
}

ns.Constants.ACTIVITIES = {
    { key = "fishing", name = L["Fishing"], icon = "ui_profession_fishing" },
}
