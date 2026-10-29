local addonName, ns = ...
local L = ns.L

local GuildCloak = {}
ns.GuildCloak = GuildCloak

GuildCloak.KEY = "GUILD_CLOAK"

local BUTTON_NAME = "FitterGuildCloakButton"
local BACK_SLOT = INVSLOT_BACK or 15

-- restoreLink is false when the back slot was empty before Fitter equipped
-- a cloak, and nil when there is nothing to restore.
local equippedItemID
local restoreLink
local restorePending = false

local button = CreateFrame(
    "Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
button:SetSize(1, 1)
button:SetPoint("BOTTOMRIGHT", UIParent, "TOPLEFT", -1, -1)
button:SetAttribute("useOnKeyDown", false)
button:RegisterForClicks("AnyDown", "AnyUp")

local function IsGuildCloak(itemID)
    if not itemID then return false end
    for _, entry in ipairs(ns.Constants.GUILD_CLOAKS) do
        if entry.id == itemID then return true end
    end
    return false
end

local function IsEquipped(itemID)
    return GetInventoryItemID("player", BACK_SLOT) == itemID
end

-- Equipping a cloak starts a short cooldown on it, so a cloak that is about
-- to be ready still counts as ready.
local EQUIP_COOLDOWN = 30

local function IsReady(itemID)
    local startTime, duration = C_Item.GetItemCooldown(itemID)
    return not startTime or startTime == 0 or not duration or duration == 0
        or (startTime + duration) - GetTime() <= EQUIP_COOLDOWN
end

function GuildCloak.GetItemID()
    if equippedItemID and IsEquipped(equippedItemID) then
        return equippedItemID
    end
    local faction = UnitFactionGroup("player")
    local fallback
    for _, entry in ipairs(ns.Constants.GUILD_CLOAKS) do
        if entry.faction == faction
            and C_Item.GetItemCount(entry.id, false, false, false) > 0 then
            if IsReady(entry.id) then return entry.id end
            fallback = fallback or entry.id
        end
    end
    return fallback
end

-- The item action equips a cloak that is in the bags and uses one that is
-- equipped, so the first click equips the cloak and the next click uses it.
button:SetScript("PreClick", function(self)
    if InCombatLockdown() then return end
    local itemID = GuildCloak.GetItemID()
    if not itemID then return end
    self:SetAttribute("type", "item")
    self:SetAttribute("item", "item:" .. itemID)
    if IsEquipped(itemID) then return end
    if restoreLink == nil then
        local current = GetInventoryItemID("player", BACK_SLOT)
        if not IsGuildCloak(current) then
            restoreLink = GetInventoryItemLink("player", BACK_SLOT) or false
        end
    end
    equippedItemID = itemID
end)

button:SetScript("PostClick", function(self)
    if InCombatLockdown() then return end
    self:SetAttribute("type", nil)
    self:SetAttribute("item", nil)
end)

local function Restore()
    if not restorePending then return end
    if InCombatLockdown() then return end
    if not IsGuildCloak(GetInventoryItemID("player", BACK_SLOT)) or not restoreLink then
        restorePending = false
        restoreLink = nil
        equippedItemID = nil
        return
    end
    C_Item.EquipItemByName(restoreLink, BACK_SLOT)
end

function GuildCloak.GetMacroAction(key)
    if key ~= GuildCloak.KEY or not GuildCloak.GetItemID() then return nil end
    return "/click " .. BUTTON_NAME
end

function GuildCloak.GetConditions()
    if not GuildCloak.GetItemID() then return {} end
    return {{key = GuildCloak.KEY, label = L["Guild Cloak"]}}
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
EventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        local itemID = GetInventoryItemID("player", BACK_SLOT)
        if restoreLink ~= nil and IsGuildCloak(itemID)
            and select(2, C_Item.GetItemSpell(itemID)) == spellID then
            restorePending = true
            Restore()
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        local slot = ...
        if slot ~= BACK_SLOT then return end
        if restorePending then
            Restore()
        elseif restoreLink ~= nil
            and not IsGuildCloak(GetInventoryItemID("player", BACK_SLOT)) then
            restoreLink = nil
            equippedItemID = nil
        end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
        Restore()
    end
end)
