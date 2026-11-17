local addonName, ns = ...

local Macro = ns.Macro

local MAX_BODY_LENGTH = 255

-- Lines in the order they appear in a macro. When the body is too long, the
-- lines with the highest priority number are left out first, so the action
-- (the mount summon or outfit update) is never the line that is lost.
-- split lets a group lose single lines; yields makes room for the player's
-- own lines.
local SECTIONS = {
    {key = "tooltip", priority = 7, yields = true},
    {key = "cancel", priority = 5, yields = true, split = true},
    {key = "toys", priority = 6, yields = true, split = true},
    {key = "hunterPet", priority = 4, yields = true},
    {key = "conditionals", priority = 2},
    {key = "outfit", priority = 3},
    {key = "action", priority = 1},
}

local function AddPart(parts, text, section, offset)
    parts[#parts + 1] = {
        text = text,
        priority = section.priority + offset,
        yields = section.yields,
    }
end

-- spec holds the text for each section (see SECTIONS); every one but action
-- is optional. reserved is the length kept free for the player's own lines.
function Macro.ComposeBody(spec, reserved)
    local parts = {}
    for _, section in ipairs(SECTIONS) do
        local text = spec[section.key]
        text = text and text:gsub("\n+$", "") or ""
        if text ~= "" then
            if section.split then
                local count = 0
                for line in text:gmatch("[^\n]+") do
                    count = count + 1
                    AddPart(parts, line, section, count / 1000)
                end
            else
                AddPart(parts, text, section, 0)
            end
        end
    end

    local byPriority = {}
    for index, part in ipairs(parts) do byPriority[index] = part end
    table.sort(byPriority, function(a, b) return a.priority < b.priority end)

    local length = 0
    for _, part in ipairs(byPriority) do
        local limit = MAX_BODY_LENGTH - (part.yields and reserved or 0)
        local newLength = length + #part.text + (length > 0 and 1 or 0)
        if newLength <= limit or part.priority == 1 then
            part.kept = true
            length = newLength
        end
    end

    local lines = {}
    for _, part in ipairs(parts) do
        if part.kept then lines[#lines + 1] = part.text end
    end
    return table.concat(lines, "\n")
end

-- Blizzard's Macro window keeps its own copy of the selected macro's text and
-- saves it when the window closes, which would overwrite an edit made while
-- it is open. Macro edits wait until it closes; key bindings are not affected.
local editorRefreshPending = false

function Macro.IsEditorOpen()
    return MacroFrame ~= nil and MacroFrame:IsShown() == true
end

-- False while the Macro window is open; the macros are then rebuilt when it
-- closes.
function Macro.CanEditMacros()
    if not Macro.IsEditorOpen() then return true end
    editorRefreshPending = true
    return false
end

function Macro.OnEditorHidden()
    if not editorRefreshPending then return end
    -- Next frame, after the window has saved its own text.
    C_Timer.After(0, function()
        if not editorRefreshPending or Macro.IsEditorOpen() then return end
        editorRefreshPending = false
        Macro.UpdateHearthstone()
        Macro.UpdateActivities()
        Macro.UpdateForCurrentState()
    end)
end

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_MacroUI", function()
        if MacroFrame then MacroFrame:HookScript("OnHide", Macro.OnEditorHidden) end
    end)
end
