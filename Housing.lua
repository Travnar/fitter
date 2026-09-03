local addonName, ns = ...

local Housing = {}
ns.Housing = Housing

local NEIGHBORHOODS = {
    [2352] = {
        key = "FOUNDERS_POINT",
        label = "Founder's Point",
        buttonName = "FitterHomeFP",
    },
    [2351] = {
        key = "RAZORWIND_SHORES",
        label = "Razorwind Shores",
        buttonName = "FitterHomeRS",
    },
}

local optionsByKey = {}
local buttonsByKey = {}
local pendingHouseInfo

for _, option in pairs(NEIGHBORHOODS) do
    optionsByKey[option.key] = option
    local button = CreateFrame(
        "Button", option.buttonName, UIParent, "SecureActionButtonTemplate")
    button:SetSize(1, 1)
    button:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1, -1)
    button:SetAttribute("useOnKeyDown", false)
    button:RegisterForClicks("AnyDown", "AnyUp")
    buttonsByKey[option.key] = button
end

local function ConfigureButtons(houseInfoList)
    if InCombatLockdown() then
        pendingHouseInfo = houseInfoList or {}
        return
    end

    pendingHouseInfo = nil
    for key, button in pairs(buttonsByKey) do
        button:SetAttribute("type", nil)
        Housing[key] = nil
    end

    for _, info in ipairs(houseInfoList or {}) do
        local mapID = info.neighborhoodGUID
            and C_Housing.GetUIMapIDForNeighborhood(info.neighborhoodGUID)
        local option = mapID and NEIGHBORHOODS[mapID]
        local button = option and buttonsByKey[option.key]
        if button and info.houseGUID and info.plotID then
            button:SetAttribute("type", "teleporthome")
            button:SetAttribute(
                "house-neighborhood-guid", info.neighborhoodGUID)
            button:SetAttribute("house-guid", info.houseGUID)
            button:SetAttribute("house-plot-id", info.plotID)
            Housing[option.key] = true
        end
    end

    if ns.Macro and ns.Macro.UpdateHearthstone then
        ns.Macro.UpdateHearthstone()
    end
end

function Housing.HasNeighborhood(key)
    return Housing[key] == true
end

function Housing.GetMacroAction(key)
    local option = optionsByKey[key]
    if not option or not Housing.HasNeighborhood(key) then return nil end
    return "/click " .. option.buttonName
end

function Housing.GetConditions()
    local result = {}
    for _, mapID in ipairs({2352, 2351}) do
        local option = NEIGHBORHOODS[mapID]
        if Housing.HasNeighborhood(option.key) then
            result[#result + 1] = option
        end
    end
    return result
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:SetScript("OnEvent", function(_, event, houseInfoList)
    if event == "PLAYER_HOUSE_LIST_UPDATED" then
        ConfigureButtons(houseInfoList)
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingHouseInfo then ConfigureButtons(pendingHouseInfo) end
    elseif C_Housing and C_Housing.GetPlayerOwnedHouses then
        C_Housing.GetPlayerOwnedHouses()
    end
end)
