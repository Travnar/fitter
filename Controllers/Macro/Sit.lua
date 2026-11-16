local addonName, ns = ...
local L = ns.L
local Macro = ns.Macro

-- Seconds to wait for the outfit change before sitting anyway, e.g. when
-- /outfit could not switch.
local SIT_FALLBACK_DELAY = 1.5

-- Emote slash commands are localized, so the client's own /sit is looked up
-- from the chat emote list.
local function SitCommand()
    local index = 1
    while _G["EMOTE" .. index .. "_TOKEN"] do
        if _G["EMOTE" .. index .. "_TOKEN"] == "SIT" then
            return _G["EMOTE" .. index .. "_CMD1"] or "/sit"
        end
        index = index + 1
    end
    return "/sit"
end

-- Sitting before the outfit change finishes blocks the outfit's pet summon
-- and is undone by its equip emote, so after a switch the sit is queued and
-- runs once those are done.
local sitPending = false

function Macro.RunPendingSit()
    if not sitPending then return end
    sitPending = false
    DoEmote("SIT")
end

local function QueueSit()
    sitPending = true
    C_Timer.After(SIT_FALLBACK_DELAY, Macro.RunPendingSit)
end
_G.FitS = QueueSit

Macro.UpdateSit, Macro.EnsureSit = Macro.RegisterActivity({
    key = "sit",
    macroName = Macro.SIT_MACRO_NAME,
    icon = Macro.SIT_MACRO_ICON,
    storageKey = "LastSitMacroBody",
    stateKey = "sitOutfitID",
    buttonKey = "SitButton",
    buildAction = function(switchesOutfit)
        return nil, switchesOutfit and "/run FitS()" or SitCommand()
    end,
    tooltipHeader = L["Switches to your Sit outfit before sitting:"],
    tooltipEmpty = L["No outfit has the Sit activity, so this only sits."],
})
