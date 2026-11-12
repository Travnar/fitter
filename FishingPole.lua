local addonName, ns = ...

-- World of Warcraft Forever needs a fishing pole in the main hand to fish.
-- The fishing macro equips one, and the weapons it replaced are put back when
-- the Fishing channel ends.

local FishingPole = {}
ns.FishingPole = FishingPole

local MAINHAND = INVSLOT_MAINHAND or 16
local OFFHAND = INVSLOT_OFFHAND or 17
local WEAPON_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
local POLE_SUBCLASS = Enum and Enum.ItemWeaponSubclass
    and Enum.ItemWeaponSubclass.Fishingpole or 20

local FISHING_CHANNEL_SPELLS = {
    [7620] = true,
    [7731] = true,
    [7732] = true,
    [18248] = true,
}

function FishingPole.IsEnabled()
    return ns.Features.EquipFishingPole
        and FitterCharacterSaved ~= nil
        and FitterCharacterSaved.EquipFishingPole == true
end

function FishingPole.IsFishingPole(item)
    if not item then return false end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(item)
    return classID == WEAPON_CLASS and subclassID == POLE_SUBCLASS
end

local function ItemLevel(link)
    local level = C_Item.GetDetailedItemLevelInfo
        and C_Item.GetDetailedItemLevelInfo(link)
    return level or 0
end

-- The equipped pole, otherwise the highest item level pole in the bags.
function FishingPole.FindItemID()
    local equipped = GetInventoryItemID("player", MAINHAND)
    if FishingPole.IsFishingPole(equipped) then return equipped end
    local bestID, bestLevel
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and FishingPole.IsFishingPole(info.itemID) then
                local level = ItemLevel(info.hyperlink)
                if not bestLevel or level > bestLevel then
                    bestID, bestLevel = info.itemID, level
                end
            end
        end
    end
    return bestID
end

function FishingPole.GetMacroLine()
    if not FishingPole.IsEnabled() then return nil end
    local itemID = FishingPole.FindItemID()
    if not itemID then return nil end
    local subclassName = C_Item.GetItemSubClassInfo
        and C_Item.GetItemSubClassInfo(WEAPON_CLASS, POLE_SUBCLASS)
    local condition = subclassName and ("[noequipped:" .. subclassName .. "] ") or ""
    return "/equip " .. condition .. "item:" .. itemID .. "\n"
end

-- The weapons last held without a pole; a slot is false when it was empty.
local weapons
local restorePending = false
local offhandPending

local function Snapshot()
    local mainLink = GetInventoryItemLink("player", MAINHAND)
    if FishingPole.IsFishingPole(mainLink) then return end
    weapons = {
        main = mainLink or false,
        off = GetInventoryItemLink("player", OFFHAND) or false,
    }
end

local function Restore()
    restorePending = false
    if not weapons or not weapons.main then return end
    if not FishingPole.IsFishingPole(GetInventoryItemID("player", MAINHAND)) then return end
    if InCombatLockdown() then
        restorePending = true
        return
    end
    offhandPending = weapons.off or nil
    C_Item.EquipItemByName(weapons.main, MAINHAND)
end

-- Casting again within this window keeps the pole equipped.
local RESTORE_DELAY = 10
local restoreTimer

local function CancelRestore()
    if restoreTimer then
        restoreTimer:Cancel()
        restoreTimer = nil
    end
end

local function ScheduleRestore()
    CancelRestore()
    restoreTimer = C_Timer.NewTimer(RESTORE_DELAY, function()
        restoreTimer = nil
        Restore()
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_EQUIPMENT_CHANGED" then
        local slot = ...
        if slot ~= MAINHAND and slot ~= OFFHAND then return end
        -- A two-handed pole changes both hands; read them once both are in.
        C_Timer.After(0, function()
            Snapshot()
            if offhandPending and not InCombatLockdown()
                and not FishingPole.IsFishingPole(GetInventoryItemID("player", MAINHAND)) then
                local link = offhandPending
                offhandPending = nil
                C_Item.EquipItemByName(link, OFFHAND)
            end
        end)
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        local _, _, spellID = ...
        if FISHING_CHANNEL_SPELLS[spellID] then
            CancelRestore()
            restorePending = false
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local _, _, spellID = ...
        if FISHING_CHANNEL_SPELLS[spellID] and FishingPole.IsEnabled() then
            ScheduleRestore()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if restorePending then Restore() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Snapshot()
    end
end)
