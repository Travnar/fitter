-- Opens Blizzard's TransmogFrame away from a transmogrifier so Fitter outfit
-- settings can be edited anywhere. Appearance editing, outfit purchasing and
-- situations need the vendor, so those parts of the frame are locked while
-- off-vendor.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s

local SLOT_CLICKS = { "LeftButtonUp", "RightButtonUp" }

local function IsAtTransmogrifier()
    local api = C_PlayerInteractionManager
    local interactionType = Enum.PlayerInteractionType
        and Enum.PlayerInteractionType.Transmogrifier
    return interactionType and api and api.IsInteractingWithNpcOfType
        and api.IsInteractingWithNpcOfType(interactionType) or false
end

function UI_Transmog:IsOffVendor()
    return s.offVendor == true
end

local function RefreshTabs()
    local wc = TransmogFrame and TransmogFrame.WardrobeCollection
    local headers = wc and wc.TabHeaders
    if not headers then return end
    if not s.offVendor then
        wc:UpdateTabs()
        return
    end
    -- Retail spells the custom sets key "custmSetsTabID"; Forever does not.
    for _, key in ipairs({
        "itemsTabID", "setsTabID", "custmSetsTabID", "customSetsTabID",
        "situationsTabID",
    }) do
        if wc[key] then headers:SetTabShown(wc[key], false) end
    end
end

local function RefreshOutfitControls()
    local collection = TransmogFrame and TransmogFrame.OutfitCollection
    if not collection then return end
    local shown = not s.offVendor
    for _, key in ipairs({
        "SaveOutfitButton", "MoneyFrame", "PurchaseOutfitButton",
    }) do
        if collection[key] then collection[key]:SetShown(shown) end
    end
end

-- Gear slots are made invisible and non-interactive rather than hidden, so the
-- slot columns Fitter's own slots anchor to keep their layout. Pooled frames
-- are reused across modes, so every active slot is reset on each refresh.
local function RefreshSlots()
    local charPreview = TransmogFrame and TransmogFrame.CharacterPreview
    if not charPreview then return end
    for _, pool in ipairs({
        charPreview.CharacterAppearanceSlotFramePool,
        charPreview.CharacterIllusionSlotFramePool,
    }) do
        for slotFrame in pool:EnumerateActive() do
            local editable = not s.offVendor or slotFrame.isFitterMountSlot
                and true or false
            if editable then
                slotFrame:RegisterForClicks(unpack(SLOT_CLICKS))
            else
                slotFrame:RegisterForClicks()
            end
            slotFrame:EnableMouse(editable)
            slotFrame:SetAlpha(editable and 1 or 0)
            if slotFrame.FlyoutDropdown then
                slotFrame.FlyoutDropdown:EnableMouse(editable)
            end
        end
    end
end

local function SetOffVendor(offVendor)
    s.offVendor = offVendor == true
    RefreshTabs()
    RefreshOutfitControls()
    RefreshSlots()
end

function UI_Transmog:InitializeOffVendorMode()
    if s.offVendorInitialized or not TransmogFrame then return end
    s.offVendorInitialized = true

    local wc = TransmogFrame.WardrobeCollection
    hooksecurefunc(wc, "UpdateTabs", function()
        if s.offVendor then RefreshTabs() end
    end)
    hooksecurefunc(TransmogFrame.CharacterPreview, "SetupSlots", RefreshSlots)

    TransmogFrame:HookScript("OnShow", function()
        local requested = s.offVendorRequested
        s.offVendorRequested = nil
        SetOffVendor(requested and not IsAtTransmogrifier())
    end)
    TransmogFrame:HookScript("OnHide", function()
        s.offVendorRequested = nil
        SetOffVendor(false)
    end)

    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("TRANSMOGRIFY_OPEN")
    eventFrame:SetScript("OnEvent", function()
        if s.offVendor then SetOffVendor(false) end
    end)
end

function UI_Transmog:OpenOffVendor()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1, 1)
        return
    end
    if not TransmogFrame then
        if Transmog_LoadUI then
            Transmog_LoadUI()
        elseif C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_Transmog")
        end
    end
    if not TransmogFrame then return end
    self:Initialize()
    if TransmogFrame:IsShown() then return end

    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    end
    s.offVendorRequested = true
    s.selectHeadOnNextTransmogOpen = true
    ShowUIPanel(TransmogFrame)
end

local function ToggleOutfitSettings()
    if TransmogFrame and TransmogFrame:IsShown() then
        HideUIPanel(TransmogFrame)
    else
        UI_Transmog:OpenOffVendor()
    end
end
_G.FitterOutfitSettings = ToggleOutfitSettings
_G.FitO = ToggleOutfitSettings

function FitterCompartment_OnEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText("Fitter", 1, 1, 1)
    GameTooltip:AddLine(L["Click to open the outfit window."], 1, 0.82, 0, true)
    GameTooltip:Show()
end

function FitterCompartment_OnLeave()
    GameTooltip:Hide()
end

hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
    local actionType, id = GetActionInfo(slot)
    if actionType ~= "macro" or not id then return end
    if GetMacroInfo(id) ~= ns.Macro.OUTFIT_SETTINGS_MACRO_NAME then return end
    tooltip:AddLine(L["Displays the transmog window without gear slots to adjust Fitter outfit configurations."],
        1, 0.82, 0, true)
    tooltip:Show()
end)
