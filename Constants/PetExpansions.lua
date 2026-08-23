local addonName, ns = ...
local L = ns.L

ns.Constants = ns.Constants or {}

ns.Constants.PET_EXPANSIONS = {
    {key = "classic",  label = L["Classic"],                minID = 1,    maxID = 172},
    {key = "bc",       label = L["Burning Crusade"],        minID = 173,  maxID = 222},
    {key = "wrath",    label = L["Wrath of the Lich King"], minID = 223,  maxID = 303},
    {key = "cata",     label = L["Cataclysm"],              minID = 304,  maxID = 510},
    {key = "mop",      label = L["Mists of Pandaria"],      minID = 511,  maxID = 1150},
    {key = "wod",      label = L["Warlords of Draenor"],    minID = 1151, maxID = 1600},
    {key = "legion",   label = L["Legion"],                 minID = 1601, maxID = 2164},
    {key = "bfa",      label = L["Battle for Azeroth"],     minID = 2165, maxID = 2780},
    {key = "sl",       label = L["Shadowlands"],            minID = 2781, maxID = 3350},
    {key = "df",       label = L["Dragonflight"],           minID = 3351, maxID = 4080},
    {key = "tww",      label = L["The War Within"],         minID = 4081, maxID = 4700},
    {key = "midnight", label = L["Midnight"],               minID = 4701, maxID = 99999},
}

ns.Constants.PET_FAMILIES = {
    {key = 1,  label = L["Humanoid"]},
    {key = 2,  label = L["Dragonkin"]},
    {key = 3,  label = L["Flying"]},
    {key = 4,  label = L["Undead"]},
    {key = 5,  label = L["Critter"]},
    {key = 6,  label = L["Magic"]},
    {key = 7,  label = L["Elemental"]},
    {key = 8,  label = L["Beast"]},
    {key = 9,  label = L["Aquatic"]},
    {key = 10, label = L["Mechanical"]},
}

function ns.Constants.GetPetExpansionKey(speciesID)
    if type(speciesID) ~= "number" then return nil end
    for _, exp in ipairs(ns.Constants.PET_EXPANSIONS) do
        if speciesID >= exp.minID and speciesID <= exp.maxID then
            return exp.key
        end
    end
    return nil
end
