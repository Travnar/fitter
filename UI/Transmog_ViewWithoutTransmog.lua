-- "View Without Transmog" toggle below the character preview's Sheathe Weapon
-- toggle. Shows the equipped items' own appearances, as seen by players who
-- have transmog display turned off.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s

local EQUIPPED_SLOTS = {
    INVSLOT_HEAD, INVSLOT_SHOULDER, INVSLOT_BODY, INVSLOT_CHEST, INVSLOT_WAIST,
    INVSLOT_LEGS, INVSLOT_FEET, INVSLOT_WRIST, INVSLOT_HAND, INVSLOT_BACK,
    INVSLOT_TABARD, INVSLOT_OFFHAND, INVSLOT_MAINHAND,
}

local RANGED_INVTYPES = {
    INVTYPE_RANGED = true,
    INVTYPE_RANGEDRIGHT = true,
}

local function GetPreviewActor()
    local scene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    return scene and scene.GetPlayerActor and scene:GetPlayerActor()
end

local function DressSlot(actor, slotID)
    local itemLink = GetInventoryItemLink("player", slotID)
    local _, sourceID
    if itemLink then
        _, sourceID = C_TransmogCollection.GetItemInfo(itemLink)
    end

    local isWeapon = slotID == INVSLOT_MAINHAND or slotID == INVSLOT_OFFHAND
    if isWeapon and actor.SetSheathedCategory then
        actor:SetSheathedCategory(slotID, Enum.TransmogOutfitSlotOptionSheatheCategory.Default)
    end

    if not sourceID then
        actor:UndressSlot(slotID)
        return
    end

    local itemTransmogInfo = ItemUtil.CreateItemTransmogInfo(sourceID)
    local slotToSetID = slotID
    if slotID == INVSLOT_MAINHAND then
        local categoryID = C_TransmogOutfitInfo.GetItemModifiedAppearanceEffectiveCategory
            and C_TransmogOutfitInfo.GetItemModifiedAppearanceEffectiveCategory(sourceID)
        itemTransmogInfo:ConfigureSecondaryForMainHand(categoryID
            and TransmogUtil.IsCategoryLegionArtifact(categoryID) or false)
        local invType = select(4, C_Item.GetItemInfoInstant(itemLink))
        if RANGED_INVTYPES[invType] then
            slotToSetID = nil
        end
    end
    actor:SetItemTransmogInfo(itemTransmogInfo, slotToSetID)
end

local function ApplyEquippedAppearances()
    if not s.viewWithoutTransmog then return end
    local actor = GetPreviewActor()
    if not actor or not actor.SetItemTransmogInfo then return end
    for _, slotID in ipairs(EQUIPPED_SLOTS) do
        DressSlot(actor, slotID)
    end
end

local function RefreshToggle()
    local toggle = s.viewWithoutTransmogToggle
    if not toggle then return end
    local checked = s.viewWithoutTransmog == true
    toggle.Checkbox:SetChecked(checked)
    toggle.Text:SetFontObject(checked and "GameFontHighlight" or "GameFontNormal")
end

-- ToggleOptions keeps the hidden ranged weapon toggle's height until its next
-- layout pass, so follow the last visible toggle instead of its bottom edge.
local function AnchorToggle()
    local toggle = s.viewWithoutTransmogToggle
    local toggleOptions = TransmogFrame.CharacterPreview.ToggleOptions
    if not toggle or not toggleOptions then return end
    local previous = toggleOptions.SheatheWeaponToggle
    local ranged = toggleOptions.PreviewedWeaponToggle
    if ranged and ranged:IsShown() then
        previous = ranged
    end
    toggle:ClearAllPoints()
    if previous then
        toggle:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -5)
    else
        toggle:SetPoint("TOPLEFT", toggleOptions, "BOTTOMLEFT", 0, -5)
    end
end

function UI_Transmog:SetViewWithoutTransmog(enabled)
    s.viewWithoutTransmog = enabled == true
    RefreshToggle()
    if s.viewWithoutTransmog then
        ApplyEquippedAppearances()
    elseif TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview:IsShown() then
        TransmogFrame.CharacterPreview:RefreshSlots()
    end
end

function UI_Transmog:InitializeViewWithoutTransmogToggle()
    if s.viewWithoutTransmogToggle or not ns.Features.ViewWithoutTransmog then
        return
    end
    local charPreview = TransmogFrame and TransmogFrame.CharacterPreview
    local toggleOptions = charPreview and charPreview.ToggleOptions
    if not toggleOptions then return end

    -- Anchored rather than added to ToggleOptions' layout, so Blizzard's
    -- layout code never reads addon-set keys.
    local toggle = CreateFrame("Frame", nil, charPreview)
    toggle:SetSize(30, 29)
    toggle:SetFrameLevel(toggleOptions:GetFrameLevel())

    toggle.Checkbox = CreateFrame("CheckButton", nil, toggle, "MinimalCheckboxArtTemplate")
    toggle.Checkbox:SetAllPoints(toggle)

    toggle.Text = toggle:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    toggle.Text:SetMaxLines(1)
    toggle.Text:SetJustifyH("LEFT")
    toggle.Text:SetPoint("LEFT", toggle.Checkbox, "RIGHT", 4, 0)
    toggle.Text:SetText(L["View Without Transmog"])

    toggle.Checkbox:SetScript("OnClick", function()
        local enabled = not s.viewWithoutTransmog
        PlaySound(enabled and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
            or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        UI_Transmog:SetViewWithoutTransmog(enabled)
    end)
    s.viewWithoutTransmogToggle = toggle
    AnchorToggle()

    hooksecurefunc(charPreview, "RefreshPlayerModel", ApplyEquippedAppearances)
    hooksecurefunc(charPreview, "RefreshSlots", ApplyEquippedAppearances)
    charPreview:HookScript("OnShow", AnchorToggle)
    charPreview:HookScript("OnHide", function()
        s.viewWithoutTransmog = nil
        RefreshToggle()
    end)
    RefreshToggle()
end
