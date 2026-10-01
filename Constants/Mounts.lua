local addonName, ns = ...
local L = ns.L

ns.Constants = ns.Constants or {}

ns.Constants.MOUNT_EXPANSIONS = {
    {key = "classic",  label = L["Classic"],                minID = 1,    maxID = 128},
    {key = "bc",       label = L["Burning Crusade"],        minID = 129,  maxID = 229},
    {key = "wrath",    label = L["Wrath of the Lich King"], minID = 230,  maxID = 382},
    {key = "cata",     label = L["Cataclysm"],              minID = 383,  maxID = 447},
    {key = "mop",      label = L["Mists of Pandaria"],      minID = 448,  maxID = 571},
    {key = "wod",      label = L["Warlords of Draenor"],    minID = 572,  maxID = 769},
    {key = "legion",   label = L["Legion"],                 minID = 770,  maxID = 990},
    {key = "bfa",      label = L["Battle for Azeroth"],     minID = 991,  maxID = 1340},
    {key = "sl",       label = L["Shadowlands"],            minID = 1341, maxID = 1599},
    {key = "df",       label = L["Dragonflight"],           minID = 1600, maxID = 1899},
    {key = "tww",      label = L["The War Within"],         minID = 1900, maxID = 2199},
    {key = "midnight", label = L["Midnight"],               minID = 2200, maxID = 99999},
}

-- Former Shift/Ctrl/Alt mount condition labels, mapped to their current mount
-- name so they migrate to account-wide mount bind conditionals.
ns.Constants.RENAMED_MOUNT_CONDITIONS = {
    ["Ground Expedition Yak"] = "Grand Expedition Yak",
    ["Reins of the Mighty Caravan Brutosaur"] = "Mighty Caravan Brutosaur",
    ["Gilded Brutosaur"] = "Trader's Gilded Brutosaur",
}

-- Blizzard's mount type for mounts that can run, fly, and swim at mount speed.
ns.Constants.MOUNT_TYPE_ALL_TERRAIN = 407

function ns.Constants.GetMountExpansionKey(mountID)
    if type(mountID) ~= "number" then return nil end
    for _, exp in ipairs(ns.Constants.MOUNT_EXPANSIONS) do
        if mountID >= exp.minID and mountID <= exp.maxID then
            return exp.key
        end
    end
    return nil
end
