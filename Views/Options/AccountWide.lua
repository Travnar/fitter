-- UI/Options_AccountWide.lua
-- Adds the "Account Wide" section to the Fitter canvas settings panel.
-- Called from Options.lua; adds widgets directly to the shared canvas frame.

local addonName, ns = ...
local L = ns.L

local UI_Options = ns.UI_Options

local SOAR_SPELL_ID = 369536

local function CollectAccountWideMounts(mountType)
    local mounts = {}
    local mountIDs = C_MountJournal.GetMountIDs()
    if not mountIDs then return mounts end

    if mountType == "Flying" then
        local playerRace = ns.state and ns.state.playerRace
        if playerRace == "Dracthyr" and IsPlayerSpell(SOAR_SPELL_ID) then
            table.insert(mounts, {id = "soar", name = "Soar", icon = 4622485})
        end
    elseif mountType == "Ground" then
        local playerRace = ns.state and ns.state.playerRace
        if playerRace == "Worgen" and IsPlayerSpell(87840) then
            table.insert(mounts, {id = "runningwild", name = "Running Wild", icon = 514641})
        end
    end

    for _, mountID in ipairs(mountIDs) do
        local name, _, icon, _, _, _, _, _, _, shouldHideOnChar, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        if isCollected and not shouldHideOnChar then
            local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
            local isAllTerrain = mountTypeID == ns.Constants.MOUNT_TYPE_ALL_TERRAIN
            local include = false
            if mountType == "Flying" then
                include = isAllTerrain or (mountTypeID ~= 230 and mountTypeID ~= 231
                    and mountTypeID ~= 254 and mountTypeID ~= 412
                )
            elseif mountType == "Ground" then
                include = isAllTerrain or mountTypeID ~= 254
            elseif mountType == "Aquatic" then
                include = isAllTerrain or mountTypeID == 254
                    or mountTypeID == 231 or mountTypeID == 412
            end
            if include then
                -- Match the outfit aquatic picker: aquatic usability is
                -- situational, so do not hide collected choices while dry.
                local canUse = mountType == "Aquatic"
                    or C_MountJournal.GetMountUsabilityByID(mountID, false)
                if canUse or isAllTerrain then
                    table.insert(mounts, {id = mountID, name = name, icon = icon})
                end
            end
        end
    end

    table.sort(mounts, function(a, b) return a.name < b.name end)
    return mounts
end

local RANDOM_ICON = 1669485

local function BuildDataWithSelection(mountType, savedKey, randomFlagKey)
    local all = CollectAccountWideMounts(mountType)
    local savedSet = {}
    for _, id in ipairs(FitterSaved[savedKey] or {}) do
        savedSet[id] = true
    end
    for _, m in ipairs(all) do
        m.selected = savedSet[m.id] == true
    end
    table.insert(all, 1, {
        id = "random",
        name = "Random Mount",
        icon = RANDOM_ICON,
        isRandom = true,
        selected = FitterSaved[randomFlagKey] == true,
    })
    return all
end

local function CreateMountScrollBox(parent, mountType, savedKey, randomFlagKey)
    local container = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")

    local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
    scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, -5)
    scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -10, 5)

    local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", container, "TOPLEFT", 2, -2)
    scrollBox:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -3, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetPadding(4, 0, 0, 0, 0)
    view:SetElementExtent(22)
    view:SetElementInitializer("Button", function(frame, elementData)
        frame:SetPushedTextOffset(0, 0)
        frame:SetNormalFontObject(GameFontHighlight)

        if not frame.cbBorder then
            -- Gold hover highlight (HIGHLIGHT layer shows only on mouse-over)
            local hlTex = frame:CreateTexture(nil, "HIGHLIGHT")
            hlTex:SetAllPoints()
            hlTex:SetColorTexture(1, 0.82, 0, 0.12)

            -- Checkbox border (always visible)
            frame.cbBorder = frame:CreateTexture(nil, "ARTWORK")
            frame.cbBorder:SetSize(14, 14)
            frame.cbBorder:SetPoint("LEFT", frame, "LEFT", 4, 0)
            frame.cbBorder:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")

            -- Checkmark (shown when selected)
            frame.cbCheck = frame:CreateTexture(nil, "OVERLAY")
            frame.cbCheck:SetSize(16, 16)
            frame.cbCheck:SetPoint("CENTER", frame.cbBorder, "CENTER", 0, 0)
            frame.cbCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

            -- Mount icon
            frame.mountIcon = frame:CreateTexture(nil, "ARTWORK")
            frame.mountIcon:SetSize(16, 16)
            frame.mountIcon:SetPoint("LEFT", frame.cbBorder, "RIGHT", 5, 0)

            -- Dedicated name label (avoids conflicts with the Button's built-in label anchors)
            frame.nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            frame.nameText:SetPoint("LEFT", frame.mountIcon, "RIGHT", 5, 0)
            frame.nameText:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
            frame.nameText:SetJustifyH("LEFT")
            frame.nameText:SetWordWrap(false)
        end

        frame.nameText:SetText(elementData.name)
        frame.mountIcon:SetTexture(elementData.icon)
        frame.cbCheck:SetShown(elementData.selected)

        frame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if elementData.isRandom then
                GameTooltip:SetText(L["Random Mount"], 1, 1, 1)
                GameTooltip:AddLine("Selects a random mount from your entire"
                    .. " collection for this fallback category.", 1, 0.82, 0, true)
            else
                GameTooltip:SetText(elementData.name, 1, 1, 1)
                if type(elementData.id) == "number" then
                    local _, spellID = C_MountJournal.GetMountInfoByID(elementData.id)
                    if spellID then
                        GameTooltip:SetSpellByID(spellID)
                    end
                end
            end
            GameTooltip:Show()
        end)
        frame:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        frame:SetScript("OnClick", function()
            elementData.selected = not elementData.selected
            frame.cbCheck:SetShown(elementData.selected)

            if elementData.isRandom then
                FitterSaved[randomFlagKey] = elementData.selected
                if elementData.selected then
                    -- Deselect all individual mounts
                    FitterSaved[savedKey] = {}
                end
            else
                if elementData.selected then
                    -- Deselect random
                    FitterSaved[randomFlagKey] = false
                end
                local saved = FitterSaved[savedKey] or {}
                if elementData.selected then
                    table.insert(saved, elementData.id)
                else
                    for i, id in ipairs(saved) do
                        if id == elementData.id then
                            table.remove(saved, i)
                            break
                        end
                    end
                end
                FitterSaved[savedKey] = saved
            end

            -- Rebuild data provider so all rows reflect the updated state
            scrollBox:SetDataProvider(
                CreateDataProvider(BuildDataWithSelection(mountType, savedKey, randomFlagKey)))
        end)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    return container, scrollBox
end

local FLYING_TOOLTIP = "When enabled, outfits that have no flying or ground mount selected"
    .. " will fall back to a random mount chosen from this list."
local GROUND_TOOLTIP = "When enabled, outfits that have no flying or ground mount selected"
    .. " will fall back to a random ground mount chosen from this list."
local AQUATIC_TOOLTIP = "When enabled, outfits that have no aquatic mount selected"
    .. " will fall back to a random aquatic mount chosen from this list."

local function AddCheckboxTooltip(cb, label, tooltip)
    cb:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[label], 1, 1, 1)
        GameTooltip:AddLine(L[tooltip], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    cb:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Called from Options.lua:Initialize(). Adds account-wide widgets to the
-- shared canvas frame at xOffset and returns a refresh function that
-- Options.lua calls from its OnShow/OnRefresh handler.
function UI_Options:InitializeAccountWide(frame, xOffset, yStart, onHeightChanged)
    local X  = xOffset or 10
    local YS = yStart  or 450
    local SW = 275   -- scrollbox width
    local SH = 185   -- scrollbox height

    -- Section header
    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", X, -YS)
    header:SetTextColor(1, 1, 1, 1)
    header:SetText(L["Account Wide"])

    -- Mount bind conditionals --
    local CH = 76  -- height of the conditional rows; the mount rows start below them

    local conditionalsDropdown
    local function OnConditionalsChanged()
        if conditionalsDropdown then conditionalsDropdown:RefreshText() end
    end

    local addConditionRow = CreateFrame("Frame", nil, frame)
    addConditionRow:SetPoint("TOPLEFT", frame, "TOPLEFT", X + 20, -(YS + 32))
    addConditionRow:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    addConditionRow:SetHeight(32)

    local addConditionLabel = addConditionRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addConditionLabel:SetPoint("LEFT", addConditionRow, "LEFT", 0, 0)
    addConditionLabel:SetText(L["Add an Account Condition"])

    local addConditionButton = ns.MountConditionalsUI.CreateAddButton(
        addConditionRow, "account", OnConditionalsChanged)
    addConditionButton:SetPoint("RIGHT", addConditionRow, "RIGHT", 0, 0)

    local currentConditionsRow = CreateFrame("Frame", nil, frame)
    currentConditionsRow:SetPoint("TOPLEFT", addConditionRow, "BOTTOMLEFT", 0, -8)
    currentConditionsRow:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    currentConditionsRow:SetHeight(30)

    local currentConditionsLabel = currentConditionsRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentConditionsLabel:SetPoint("LEFT", currentConditionsRow, "LEFT", 0, 0)
    currentConditionsLabel:SetText(L["Current Account Conditionals"])

    conditionalsDropdown = ns.MountConditionalsUI.CreateListDropdown(
        currentConditionsRow, "account", 220, OnConditionalsChanged)
    conditionalsDropdown:SetPoint("RIGHT", currentConditionsRow, "RIGHT", 0, 0)
    -- Closing the options panel hides its children, including this row.
    currentConditionsRow:HookScript("OnHide", function()
        ns.MountConditionalsUI.HidePopup("account")
    end)

    -- Flying --
    local flyingRow = CreateFrame("Frame", nil, frame)
    flyingRow:SetPoint("TOPLEFT", frame, "TOPLEFT", X + 20, -(YS + 32 + CH))
    flyingRow:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    flyingRow:SetHeight(26)

    local flyingLabel = flyingRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    flyingLabel:SetPoint("LEFT", flyingRow, "LEFT", 0, 0)
    flyingLabel:SetText(L["Account Wide Flying Mounts"])

    local flyingCheckbox = CreateFrame("CheckButton", nil, flyingRow, "SettingsCheckBoxTemplate")
    flyingCheckbox:SetPoint("RIGHT", flyingRow, "RIGHT", 0, 0)
    AddCheckboxTooltip(flyingCheckbox, L["Account Wide Flying Mounts"], FLYING_TOOLTIP)

    -- Forward-declared so the flying OnClick closure can reference it before ground is created.
    local UpdateGroundPosition

    local flyingContainer, flyingScrollBox = CreateMountScrollBox(frame, "Flying", "AccountWideFlyingMounts", "AccountWideFlyingRandom")
    flyingContainer:SetPoint("TOPLEFT", flyingRow, "BOTTOMLEFT", 0, -12)
    flyingContainer:SetSize(SW, SH)
    flyingContainer:Hide()  -- hidden until enabled

    -- Clients without flying/aquatic mounts (e.g. WoW Forever) hide those
    -- sections; Ground moves up into the Flying row's position.
    local hasFlying = ns.Features.FlyingMounts
    local hasAquatic = ns.Features.AquaticMounts
    flyingRow:SetShown(hasFlying)

    flyingCheckbox:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        if FitterSaved then FitterSaved.AccountWideFlyingEnabled = enabled end
        flyingContainer:SetShown(enabled)
        UpdateGroundPosition()
        if enabled then
            flyingScrollBox:SetDataProvider(
                CreateDataProvider(BuildDataWithSelection("Flying", "AccountWideFlyingMounts", "AccountWideFlyingRandom")))
        end
    end)

    -- Ground --
    local groundRow = CreateFrame("Frame", nil, frame)
    groundRow:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    groundRow:SetHeight(26)

    local groundLabel = groundRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groundLabel:SetPoint("LEFT", groundRow, "LEFT", 0, 0)
    groundLabel:SetText(L["Account Wide Ground Mounts"])

    local groundCheckbox = CreateFrame("CheckButton", nil, groundRow, "SettingsCheckBoxTemplate")
    groundCheckbox:SetPoint("RIGHT", groundRow, "RIGHT", 0, 0)
    AddCheckboxTooltip(groundCheckbox, L["Account Wide Ground Mounts"], GROUND_TOOLTIP)

    local groundContainer, groundScrollBox = CreateMountScrollBox(frame, "Ground", "AccountWideGroundMounts", "AccountWideGroundRandom")
    groundContainer:SetPoint("TOPLEFT", groundRow, "BOTTOMLEFT", 0, -12)
    groundContainer:SetSize(SW, SH)
    groundContainer:Hide()  -- hidden until enabled

    -- Aquatic --
    local aquaticRow = CreateFrame("Frame", nil, frame)
    aquaticRow:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
    aquaticRow:SetHeight(26)

    local aquaticLabel = aquaticRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aquaticLabel:SetPoint("LEFT", aquaticRow, "LEFT", 0, 0)
    aquaticLabel:SetText(L["Account Wide Aquatic Mounts"])

    local aquaticCheckbox = CreateFrame("CheckButton", nil, aquaticRow, "SettingsCheckBoxTemplate")
    aquaticCheckbox:SetPoint("RIGHT", aquaticRow, "RIGHT", 0, 0)
    AddCheckboxTooltip(aquaticCheckbox, L["Account Wide Aquatic Mounts"], AQUATIC_TOOLTIP)

    local aquaticContainer, aquaticScrollBox = CreateMountScrollBox(
        frame, "Aquatic", "AccountWideAquaticMounts", "AccountWideAquaticRandom")
    aquaticContainer:SetPoint("TOPLEFT", aquaticRow, "BOTTOMLEFT", 0, -12)
    aquaticContainer:SetSize(SW, SH)
    aquaticContainer:Hide()
    aquaticRow:SetShown(hasAquatic)

    -- Height of the Account Wide section from its start (YS) to the bottom of the last
    -- visible element, plus padding. Used to resize the content scroll frame.
    local function CalcAWHeight()
        local gndBottom = 54
        if hasFlying then
            local flyBottom = flyingContainer:IsShown() and (64 + SH) or 54
            local gndOffset = flyingContainer:IsShown() and 13 or 8
            gndBottom = flyBottom + gndOffset + 26
        end
        local groundBottom = groundContainer:IsShown() and (gndBottom + 12 + SH) or gndBottom
        local awBottom = groundBottom
        if hasAquatic then
            local aquaticBottom = groundBottom + (groundContainer:IsShown() and 13 or 8) + 26
            awBottom = aquaticContainer:IsShown()
                and (aquaticBottom + 12 + SH) or aquaticBottom
        end
        return awBottom + 20 + CH
    end

    -- Repositions the ground section depending on whether the flying scrollbox is visible.
    UpdateGroundPosition = function()
        groundRow:ClearAllPoints()
        groundRow:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
        if not hasFlying then
            groundRow:SetPoint("TOPLEFT", frame, "TOPLEFT", X + 20, -(YS + 32 + CH))
        elseif flyingContainer:IsShown() then
            groundRow:SetPoint("TOPLEFT", flyingContainer, "BOTTOMLEFT", 0, -13)
        else
            groundRow:SetPoint("TOPLEFT", flyingRow, "BOTTOMLEFT", 0, -8)
        end
        aquaticRow:ClearAllPoints()
        aquaticRow:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
        if groundContainer:IsShown() then
            aquaticRow:SetPoint("TOPLEFT", groundContainer, "BOTTOMLEFT", 0, -13)
        else
            aquaticRow:SetPoint("TOPLEFT", groundRow, "BOTTOMLEFT", 0, -8)
        end
        if onHeightChanged then onHeightChanged(CalcAWHeight()) end
    end
    UpdateGroundPosition()

    groundCheckbox:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        if FitterSaved then FitterSaved.AccountWideGroundEnabled = enabled end
        groundContainer:SetShown(enabled)
        UpdateGroundPosition()
        if enabled then
            groundScrollBox:SetDataProvider(
                CreateDataProvider(BuildDataWithSelection("Ground", "AccountWideGroundMounts", "AccountWideGroundRandom")))
        end
    end)

    aquaticCheckbox:SetScript("OnClick", function(self)
        local enabled = self:GetChecked()
        if FitterSaved then FitterSaved.AccountWideAquaticEnabled = enabled end
        aquaticContainer:SetShown(enabled)
        if onHeightChanged then onHeightChanged(CalcAWHeight()) end
        if enabled then
            aquaticScrollBox:SetDataProvider(CreateDataProvider(BuildDataWithSelection(
                "Aquatic", "AccountWideAquaticMounts", "AccountWideAquaticRandom")))
        end
    end)

    -- Return the refresh function that Options.lua calls on OnRefresh/OnShow
    return function()
        if not FitterSaved then return end
        OnConditionalsChanged()
        local flyEnabled = hasFlying and FitterSaved.AccountWideFlyingEnabled
        local gndEnabled = FitterSaved.AccountWideGroundEnabled
        local aquaticEnabled = hasAquatic and FitterSaved.AccountWideAquaticEnabled
        flyingCheckbox:SetChecked(flyEnabled)
        groundCheckbox:SetChecked(gndEnabled)
        aquaticCheckbox:SetChecked(aquaticEnabled)
        flyingContainer:SetShown(flyEnabled)
        groundContainer:SetShown(gndEnabled)
        aquaticContainer:SetShown(aquaticEnabled)
        UpdateGroundPosition()
        if flyEnabled then
            flyingScrollBox:SetDataProvider(
                CreateDataProvider(BuildDataWithSelection("Flying", "AccountWideFlyingMounts", "AccountWideFlyingRandom")))
        end
        if gndEnabled then
            groundScrollBox:SetDataProvider(
                CreateDataProvider(BuildDataWithSelection("Ground", "AccountWideGroundMounts", "AccountWideGroundRandom")))
        end
        if aquaticEnabled then
            aquaticScrollBox:SetDataProvider(CreateDataProvider(BuildDataWithSelection(
                "Aquatic", "AccountWideAquaticMounts", "AccountWideAquaticRandom")))
        end
    end
end
