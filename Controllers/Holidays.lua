local addonName, ns = ...

local Holidays = {}
ns.Holidays = Holidays

local HOLIDAY_KEYS_BY_EVENT_ID = {}
for _, holiday in ipairs(ns.Constants.HOLIDAYS) do
    HOLIDAY_KEYS_BY_EVENT_ID[holiday.eventID] = holiday.key
end

local function TimeValue(calendarTime)
    return ((((calendarTime.year * 100 + calendarTime.month) * 100
        + calendarTime.monthDay) * 100 + calendarTime.hour) * 100)
        + calendarTime.minute
end

function Holidays.RequestCalendarData()
    if C_Calendar and C_Calendar.OpenCalendar then
        C_Calendar.OpenCalendar()
    end
end

local lastActive = {}

local function IsTimeAccessible(calendarTime)
    return calendarTime
        and ns.CanAccessValue(calendarTime.year)
        and ns.CanAccessValue(calendarTime.month)
        and ns.CanAccessValue(calendarTime.monthDay)
        and ns.CanAccessValue(calendarTime.hour)
        and ns.CanAccessValue(calendarTime.minute)
end

-- Day events are indexed relative to the month the calendar is showing, so
-- the offset to today is computed instead of moving the player's calendar.
-- Calendar data is secret during restricted states (e.g. combat in
-- instances); the last readable result is kept so holiday outfits don't
-- drop out until the restriction lifts.
function Holidays.GetActiveKeys()
    if not C_Calendar or not C_Calendar.GetMonthInfo
        or not C_DateAndTime or not C_DateAndTime.GetCurrentCalendarTime then
        return {}
    end
    local now = C_DateAndTime.GetCurrentCalendarTime()
    local shown = C_Calendar.GetMonthInfo(0)
    if not now or not shown then return lastActive end
    if not IsTimeAccessible(now) or not ns.CanAccessValue(shown.year)
        or not ns.CanAccessValue(shown.month) then
        return lastActive
    end

    local monthOffset = (now.year - shown.year) * 12 + now.month - shown.month
    local numEvents = C_Calendar.GetNumDayEvents(monthOffset, now.monthDay)
    if not ns.CanAccessValue(numEvents) then return lastActive end

    local active = {}
    local nowValue = TimeValue(now)
    for index = 1, numEvents do
        local event = C_Calendar.GetDayEvent(monthOffset, now.monthDay, index)
        if event then
            if not ns.CanAccessValue(event.calendarType)
                or not ns.CanAccessValue(event.eventID) then
                return lastActive
            end
            local key = event.calendarType == "HOLIDAY"
                and HOLIDAY_KEYS_BY_EVENT_ID[event.eventID]
            if key then
                if not IsTimeAccessible(event.startTime)
                    or not IsTimeAccessible(event.endTime) then
                    return lastActive
                end
                if TimeValue(event.startTime) <= nowValue
                    and nowValue < TimeValue(event.endTime) then
                    active[key] = true
                end
            end
        end
    end
    lastActive = active
    return active
end
