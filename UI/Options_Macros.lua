local addonName, ns = ...
local L = ns.L
local UI_Options = ns.UI_Options

local ROW_STEP = 30

local function GetRowDefs()
    local Macro = ns.Macro
    return {
        {
            label = "Outfit Mount Macro",
            tooltip = "Creates a macro that summons a mount based on your current outfit or zone you are in.",
            exists = function() return Macro.Exists(Macro.MOUNT_MACRO_NAME) end,
            create = Macro.EnsureMount,
        },
        {
            label = "Outfit Hearthstone Macro",
            tooltip = "Creates a macro that uses a hearthstone based on your current outfit or zone you are in.",
            exists = function() return Macro.Exists(Macro.HEARTHSTONE_MACRO_NAME) end,
            create = Macro.EnsureHearthstone,
        },
        {
            label = "Outfit Update Macro",
            tooltip = "Creates a macro that updates your outfit by applying toys and titles,"
                .. " and summoning pets, based on your current outfit or zone you are in.",
            exists = function()
                return Macro.Exists(Macro.OUTFIT_UPDATE_MACRO_NAME, "account")
            end,
            create = Macro.EnsureOutfitUpdateMacro,
            reportsOwnErrors = true,
        },
        {
            label = "Outfit Fishing Macro",
            tooltip = "Creates a macro that casts Fishing. If an outfit on this character"
                .. " has the Fishing activity selected, it switches to that outfit first.",
            exists = function() return Macro.Exists(Macro.FISHING_MACRO_NAME) end,
            create = Macro.EnsureFishing,
        },
        {
            label = "Outfit Window Macro",
            tooltip = "Creates a macro that opens the transmog window anywhere to change"
                .. " Fitter settings for your outfits. Appearances and situations can"
                .. " only be changed at a transmogrifier.",
            exists = function() return Macro.Exists(Macro.OUTFIT_SETTINGS_MACRO_NAME) end,
            create = Macro.EnsureOutfitSettings,
        },
        {
            label = "Character Outfit Update Macro",
            tooltip = "Creates a character-specific version of the outfit update macro in your"
                .. " character macro list, allowing it to be used alongside an ability on"
                .. " your action bar.",
            tooltipNote = "It is suggested to disable |cffffd100Remove Macro Changes On Update|r before"
                .. " adding abilities to this macro, to prevent them from being removed on updates.",
            exists = function()
                return Macro.Exists(Macro.OUTFIT_UPDATE_MACRO_NAME, "character")
            end,
            create = Macro.EnsureCharacterOutfitUpdateMacro,
            reportsOwnErrors = true,
        },
    }
end

-- Builds a "Create" row for each Fitter macro, shown only while that macro is
-- missing. Rows stack from firstY (a positive offset below the top of frame);
-- onLayoutChanged receives the offset of the lowest visible row, or of the row
-- above firstY when none are shown. Returns the refresh function.
function UI_Options:InitializeMacros(frame, x, firstY, onLayoutChanged)
    local rows = {}
    local Refresh

    local function CreateRow(def)
        local row = CreateFrame("Frame", nil, frame)
        row:SetHeight(26)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", row, "LEFT", 0, 0)
        label:SetText(L[def.label])

        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(110, 22)
        button:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        button:SetText(L["Create"])
        button:SetScript("OnClick", function()
            if InCombatLockdown() then
                UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1, 1)
                return
            end
            def.create()
            if not def.exists() and not def.reportsOwnErrors then
                print("|cff00ff00Fitter:|r "
                    .. L["Cannot create macro: maximum number of account macros reached."])
            end
            Refresh()
        end)

        local function ShowTip(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[def.label], 1, 1, 1)
            GameTooltip:AddLine(def.tooltip, 1, 0.82, 0, true)
            if def.tooltipNote then
                GameTooltip:AddLine(" ", 1, 1, 1)
                GameTooltip:AddLine(def.tooltipNote, 1, 0.82, 0, true)
            end
            GameTooltip:Show()
        end
        row:SetScript("OnEnter", ShowTip)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:HookScript("OnEnter", ShowTip)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)

        row.def = def
        return row
    end

    for _, def in ipairs(GetRowDefs()) do
        rows[#rows + 1] = CreateRow(def)
    end

    Refresh = function()
        ns.Macro.MigrateLegacyNames()
        local y = firstY
        local lowestY = firstY - ROW_STEP
        for _, row in ipairs(rows) do
            local shown = not row.def.exists()
            row:SetShown(shown)
            if shown then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
                row:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
                lowestY = y
                y = y + ROW_STEP
            end
        end
        onLayoutChanged(lowestY)
    end

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("UPDATE_MACROS")
    eventFrame:SetScript("OnEvent", function()
        if frame:IsVisible() then Refresh() end
    end)

    return Refresh
end
