local addonName, ns = ...
local L = ns.L
local Macro = ns.Macro

local FISHING_SPELL_ID = 131474
local LEGACY_FISHING_SPELL_ID = 7620

Macro.UpdateFishing, Macro.EnsureFishing = Macro.RegisterActivity({
    key = "fishing",
    macroName = Macro.FISHING_MACRO_NAME,
    icon = Macro.FISHING_MACRO_ICON,
    storageKey = "LastFishingMacroBody",
    stateKey = "fishingOutfitID",
    buttonKey = "FishingButton",
    buildAction = function()
        local fishing = Macro.SpellName(FISHING_SPELL_ID,
            Macro.SpellName(LEGACY_FISHING_SPELL_ID, "Fishing"))
        local equip = ns.FishingPole and ns.FishingPole.GetMacroLine() or ""
        return "#showtooltip " .. fishing, equip .. "/cast " .. fishing
    end,
    tooltipHeader = L["Switches to your Fishing outfit before casting:"],
    tooltipEmpty = L["No outfit has the Fishing activity, so this only casts Fishing."],
})
