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

-- Day events are indexed relative to the month the calendar is showing, so
-- the offset to today is computed instead of moving the player's calendar.
function Holidays.GetActiveKeys()
    local active = {}
    if not C_Calendar or not C_Calendar.GetMonthInfo
        or not C_DateAndTime or not C_DateAndTime.GetCurrentCalendarTime then
        return active
    end
    local now = C_DateAndTime.GetCurrentCalendarTime()
    local shown = C_Calendar.GetMonthInfo(0)
    if not now or not shown then return active end

    local monthOffset = (now.year - shown.year) * 12 + now.month - shown.month
    local nowValue = TimeValue(now)
    for index = 1, C_Calendar.GetNumDayEvents(monthOffset, now.monthDay) do
        local event = C_Calendar.GetDayEvent(monthOffset, now.monthDay, index)
        local key = event and event.calendarType == "HOLIDAY"
            and HOLIDAY_KEYS_BY_EVENT_ID[event.eventID]
        if key and event.startTime and event.endTime
            and TimeValue(event.startTime) <= nowValue
            and nowValue < TimeValue(event.endTime) then
            active[key] = true
        end
    end
    return active
end
