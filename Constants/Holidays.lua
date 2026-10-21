local addonName, ns = ...
local L = ns.L

ns.Constants = ns.Constants or {}

-- eventID is the calendar holiday ID returned by C_Calendar.GetDayEvent.
-- The WoW Anniversary gets a new ID every year and must be updated manually.
ns.Constants.HOLIDAYS = {
    { key = "lunarFestival",  eventID = 327, name = L["Lunar Festival"],          icon = "achievement_worldevent_lunar" },
    { key = "loveIsInTheAir", eventID = 423, name = L["Love is in the Air"],      icon = "achievement_worldevent_valentine" },
    { key = "noblegarden",    eventID = 181, name = L["Noblegarden"],             icon = "inv_misc_easterbasket" },
    { key = "childrensWeek",  eventID = 201, name = L["Children's Week"],         icon = "achievement_worldevent_childrensweek" },
    { key = "midsummer",      eventID = 341, name = L["Midsummer Fire Festival"], icon = "inv_summerfest_symbol_high" },
    { key = "brewfest",       eventID = 372, name = L["Brewfest"],                icon = "inv_holiday_brewfestbuff_01" },
    { key = "hallowsEnd",     eventID = 324, name = L["Hallow's End"],            icon = "inv_misc_bag_28_halloween" },
    { key = "dayOfTheDead",   eventID = 409, name = L["Day of the Dead"],         icon = "inv_helm_armor_sugarskull_c_01" },
    { key = "wowAnniversary", eventID = 1808, name = L["WoW Anniversary"],         icon = "inv_misc_wow15year_balloons_blue" },
    { key = "pilgrimsBounty", eventID = 404, name = L["Pilgrim's Bounty"],        icon = "inv_holiday_thanksgiving_cornucopia" },
    { key = "winterVeil",     eventID = 141, name = L["Feast of Winter Veil"],    icon = "inv_holiday_christmas_present_01" },
    { key = "darkmoonFaire",  eventID = 479, name = L["Darkmoon Faire"],          icon = "inv_misc_ticket_darkmoon_01" },
}

ns.Constants.ACTIVITIES = {
    { key = "fishing", name = L["Fishing"], icon = "ui_profession_fishing" },
}
