-- Character section buttons that export or import this character's Fitter
-- configuration as a string or as FITTER_CONFIG_N macros.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local CharacterExport = ns.CharacterExport

local ROW_SPACING = 37

local function Notify(message)
    StaticPopup_Show("FITTER_CHARACTER_EXPORT_NOTICE", message)
end

local function ApplyImport(payload, fromMacros)
    if fromMacros and InCombatLockdown() then
        Notify("Macros cannot be changed in combat.")
        return
    end
    CharacterExport.Apply(payload)
    if fromMacros then CharacterExport.DeleteMacros() end
    UI_Transmog:RefreshAfterConfigurationReset()
    UI_Transmog:RefreshLoadouts()
    if UI_Transmog.RefreshMountConditionals then
        UI_Transmog:RefreshMountConditionals()
    end
end

StaticPopupDialogs["FITTER_IMPORT_CHARACTER_CONFIGURATION"] = {
    text = L["Import the Fitter configuration exported from |cffffd200%s|r?\n\nThis will overwrite all Fitter configurations for this character. This cannot be undone."],
    button1 = L["Import"],
    button2 = L["Cancel"],
    OnAccept = function(_, data)
        if data and data.payload then ApplyImport(data.payload, data.fromMacros) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
}

StaticPopupDialogs["FITTER_CHARACTER_EXPORT_NOTICE"] = {
    text = "%s",
    button1 = OKAY,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function ConfirmImport(payload, fromMacros)
    local source = tostring(payload.source or L["Unknown"]):gsub("|", "||")
    StaticPopup_Show("FITTER_IMPORT_CHARACTER_CONFIGURATION", source, nil,
        {payload = payload, fromMacros = fromMacros})
end

local function CreateTextPopup()
    if s.characterExportPopup then return s.characterExportPopup end
    local popup = CreateFrame("Frame", "FitterCharacterExportPopup", UIParent,
        "PortraitFrameTemplate")
    popup:SetSize(520, 380)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:Hide()

    local portrait = popup.Portrait
        or (popup.PortraitContainer and popup.PortraitContainer.portrait)
    if portrait then portrait:SetTexture("Interface\\Icons\\INV_Misc_Note_01") end

    local description = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    description:SetPoint("TOPLEFT", 30, -62)
    description:SetPoint("RIGHT", -30, 0)
    description:SetJustifyH("LEFT")
    popup.description = description

    local area = CreateFrame("Frame", nil, popup, "TooltipBackdropTemplate")
    area:SetPoint("TOPLEFT", description, "BOTTOMLEFT", -4, -10)
    area:SetPoint("BOTTOMRIGHT", -26, 56)

    local scroll = CreateFrame("ScrollFrame", nil, area, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(0)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(430)
    scroll:SetScrollChild(editBox)
    scroll:SetScript("OnSizeChanged", function(_, width) editBox:SetWidth(width) end)
    popup.editBox = editBox

    if ScrollingEdit_OnTextChanged then
        editBox:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
        editBox:SetScript("OnUpdate", function(self, elapsed)
            ScrollingEdit_OnUpdate(self, elapsed, scroll)
        end)
    end
    editBox:SetScript("OnTextChanged", function(self, userInput)
        -- The export text is read-only; typing restores it.
        if userInput and popup.exportText then
            self:SetText(popup.exportText)
            self:HighlightText()
        end
        if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(self, scroll) end
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        if popup.exportText then self:HighlightText() end
    end)
    editBox:SetScript("OnEscapePressed", function() popup:Hide() end)

    area:EnableMouse(true)
    area:SetScript("OnMouseDown", function() editBox:SetFocus() end)

    local close = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    close:SetSize(90, 24)
    close:SetPoint("BOTTOMRIGHT", -24, 20)
    close:SetScript("OnClick", function() popup:Hide() end)
    popup.closeButton = close

    local import = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    import:SetSize(90, 24)
    import:SetPoint("RIGHT", close, "LEFT", -8, 0)
    import:SetText(L["Import"])
    import:SetScript("OnClick", function()
        local text = editBox:GetText()
        if text:match("^%s*$") then
            UIErrorsFrame:AddMessage("Paste an export string first.", 1, 0.2, 0.2)
            return
        end
        local payload, err = CharacterExport.Decode(text)
        if not payload then
            UIErrorsFrame:AddMessage(err, 1, 0.2, 0.2)
            return
        end
        popup:Hide()
        ConfirmImport(payload, false)
    end)
    popup.importButton = import

    popup:SetScript("OnHide", function()
        popup.exportText = nil
        editBox:SetText("")
        editBox:ClearFocus()
    end)

    s.characterExportPopup = popup
    return popup
end

local function ShowExportString()
    local popup = CreateTextPopup()
    local text = CharacterExport.Export()
    popup:SetTitle(L["Character Export String"])
    popup.description:SetText(L["Press Ctrl+C to copy the export string."])
    popup.closeButton:SetText(L["Close"])
    popup.importButton:Hide()
    popup:Show()
    popup.exportText = text
    popup.editBox:SetText(text)
    popup.editBox:SetCursorPosition(0)
    popup.editBox:SetFocus()
    popup.editBox:HighlightText()
end

local function ShowImportString()
    local popup = CreateTextPopup()
    popup:SetTitle(L["Import Character Export String"])
    popup.description:SetText(L["Press Ctrl+V to paste an export string."])
    popup.closeButton:SetText(L["Cancel"])
    popup.importButton:Show()
    popup:Show()
    popup.exportText = nil
    popup.editBox:SetText("")
    popup.editBox:SetFocus()
end

local function ExportMacros()
    local ok, result = CharacterExport.WriteMacros(CharacterExport.Export())
    if not ok then
        Notify(result)
        return
    end
    local prefix = CharacterExport.MACRO_PREFIX
    local names = result == 1 and (prefix .. "1")
        or string.format("%s1 - %s%d", prefix, prefix, result)
    Notify(string.format(
        "Created %d account macro(s): %s.\n\nUse Import Character Export Macros on another character to apply them.",
        result, names))
end

local function ImportMacros()
    if InCombatLockdown() then
        Notify("Macros cannot be changed in combat.")
        return
    end
    local text, err = CharacterExport.ReadMacros()
    if not text then
        Notify(err)
        return
    end
    local payload
    payload, err = CharacterExport.Decode(text)
    if not payload then
        Notify(err .. "\n\nThe " .. CharacterExport.MACRO_PREFIX
            .. "N macros were left unchanged.")
        return
    end
    ConfirmImport(payload, true)
end

local ROWS = {
    {
        label = "Generate Character Export String",
        button = "Generate",
        tooltip = "Show a string containing this character's Fitter configuration, to copy and paste.",
        onClick = ShowExportString,
    },
    {
        label = "Generate Character Export Macros",
        button = "Generate",
        tooltip = "Store this character's Fitter configuration in FITTER_CONFIG_N account macros.",
        onClick = ExportMacros,
    },
    {
        label = "Import Character Export String",
        button = "Import",
        tooltip = "Paste an export string to overwrite this character's Fitter configuration.",
        onClick = ShowImportString,
    },
    {
        label = "Import Character Export Macros",
        button = "Import",
        tooltip = "Overwrite this character's Fitter configuration from the FITTER_CONFIG_N macros, then delete them.",
        onClick = ImportMacros,
    },
}

-- Rows match the Character section's reset row; y is the first row's offset.
function UI_Transmog:InitializeCharacterExport(parent, y)
    for index, info in ipairs(ROWS) do
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, y - (index - 1) * ROW_SPACING)
        row:SetPoint("RIGHT", parent, "RIGHT", -70, 0)
        row:SetHeight(26)
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT")
        text:SetText(L[info.label])
        local button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(80, 22)
        button:SetPoint("RIGHT")
        button:SetText(L[info.button])
        button:SetScript("OnClick", info.onClick)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[info.label])
            GameTooltip:AddLine(L[info.tooltip], 1, 1, 1, true)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
    end
    -- Built now rather than on first click; frames created while the transmog
    -- panel is open taint gamepad navigation.
    CreateTextPopup()
end
