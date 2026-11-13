local addonName, ns = ...

local Settings = {}
ns.Settings = Settings

local function ApplyDefaults(saved, defaults)
    for key, value in pairs(defaults) do
        if saved[key] == nil then
            saved[key] = type(value) == "table" and {} or value
        end
    end
end

-- Runs at ADDON_LOADED, before any module reads a setting.
function Settings.ApplyDefaults()
    FitterSaved = FitterSaved or {}
    FitterCharacterSaved = FitterCharacterSaved or {}
    ApplyDefaults(FitterSaved, ns.Constants.ACCOUNT_DEFAULTS)
    ApplyDefaults(FitterCharacterSaved, ns.Constants.CHARACTER_DEFAULTS)
    FitterSaved.EmoteGlobalCooldown =
        math.max(5, math.min(60, tonumber(FitterSaved.EmoteGlobalCooldown) or 25))
end

function Settings.CreateEmptyOutfit(outfitID)
    FitterCharacterSaved = FitterCharacterSaved or {}
    local key = "Outfit" .. outfitID
    if FitterCharacterSaved[key] then return end
    local data = {}
    ApplyDefaults(data, ns.Constants.OUTFIT_DEFAULTS)
    FitterCharacterSaved[key] = data
end

local function ForEachOutfit(fn)
    for key, data in pairs(FitterCharacterSaved) do
        if type(key) == "string" and key:match("^Outfit%d+$")
            and type(data) == "table" then
            fn(data)
        end
    end
end

-- Empties hearthstone selections that hold only the bag Hearthstone, in
-- either the current list or the single-item format.
local function ClearBagHearthstoneSelections()
    local bagHearthstone = ns.Constants.BAG_HEARTHSTONE_ITEM_ID
    ForEachOutfit(function(data)
        if type(data.Hearthstones) == "table"
            and #data.Hearthstones == 1
            and data.Hearthstones[1] == bagHearthstone then
            data.Hearthstones = {}
            data.Hearthstone = nil
        elseif data.Hearthstones == nil and data.Hearthstone == bagHearthstone then
            data.Hearthstone = nil
            data.Hearthstones = {}
        end
    end)
end

-- The reset is stored as an account-wide counter so each character applies
-- it on its next login (character data only loads for that character).
local function ApplyPendingHearthstoneReset()
    local resetVersion = tonumber(FitterSaved.DefaultHearthstonesResetVersion) or 0
    local appliedVersion =
        tonumber(FitterCharacterSaved.DefaultHearthstonesResetVersion) or 0
    if appliedVersion < resetVersion then
        ClearBagHearthstoneSelections()
        FitterCharacterSaved.DefaultHearthstonesResetVersion = resetVersion
    end
end

-- Migration (2.1.1): earlier versions populated every outfit with the bag
-- Hearthstone even when the picker had never been configured. Clear that
-- generated default once so an empty selection reaches the macro's random
-- fallback. See dev/MIGRATIONS.md.
local function MigrateEmptyHearthstoneDefaults()
    if FitterSaved.EmptyHearthstoneDefaultsMigrated then return end
    local bagHearthstone = ns.Constants.BAG_HEARTHSTONE_ITEM_ID
    ForEachOutfit(function(data)
        if type(data.Hearthstones) == "table"
            and #data.Hearthstones == 1
            and data.Hearthstones[1] == bagHearthstone
            and data.Hearthstone == nil then
            data.Hearthstones = {}
        end
    end)
    FitterSaved.EmptyHearthstoneDefaultsMigrated = true
end

-- Runs once on the first PLAYER_ENTERING_WORLD.
function Settings.Initialize()
    Settings.ApplyDefaults()
    ApplyPendingHearthstoneReset()
    MigrateEmptyHearthstoneDefaults()

    local outfits = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetOutfitsInfo()
    if outfits then
        for _, info in ipairs(outfits) do
            Settings.CreateEmptyOutfit(info.outfitID)
        end
    end
end

function Settings.ResetDefaultHearthstones()
    Settings.ApplyDefaults()
    FitterSaved.DefaultHearthstonesResetVersion =
        (tonumber(FitterSaved.DefaultHearthstonesResetVersion) or 0) + 1
    ClearBagHearthstoneSelections()
    FitterCharacterSaved.DefaultHearthstonesResetVersion =
        FitterSaved.DefaultHearthstonesResetVersion
    ns.Macro.UpdateHearthstone()
    if ns.UI_Transmog and ns.UI_Transmog.UpdateHearthstones then
        ns.UI_Transmog:UpdateHearthstones()
    end
end
