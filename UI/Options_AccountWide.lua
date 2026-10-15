-- UI/Options_AccountWide.lua
-- Adds the "Account Wide" section to the Fitter settings category.
-- Called from Options.lua; the conditional and mount list rows are custom
-- settings-list elements, everything else uses Blizzard's stock controls.

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

-- Custom settings rows --

-- Builds a settings-list initializer for a custom row. Each template has its own
-- frame pool, and pooled frames are recycled between rows of the same template,
-- so build(frame) runs once per frame and bind(frame, data) on every display.
local function CreateCustomInitializer(template, extent, data, build, bind)
    local initializer = CreateFromMixins(ScrollBoxFactoryInitializerMixin,
        SettingsElementHierarchyMixin, SettingsSearchableElementMixin)
    ScrollBoxFactoryInitializerMixin.Init(initializer, template)
    initializer.data = data
    if data.name then initializer:AddSearchTags(data.name) end

    function initializer:GetExtent()
        return extent
    end

    function initializer:InitFrame(frame)
        if not frame.cbrHandles then
            frame.cbrHandles = Settings.CreateCallbackHandleContainer()
        end
        frame.data = self.data
        frame.Text:SetFontObject("GameFontNormal")
        frame.Text:SetPoint("LEFT", 37, 0)
        frame.Text:SetPoint("RIGHT", frame, "CENTER", -85, 0)
        frame.Text:SetText(self.data.name or "")
        if not frame.fitterBuilt then
            build(frame)
            frame.fitterBuilt = true
        end
        if bind then bind(frame, self.data) end
    end

    return initializer
end

local function RefreshMountList(scrollBox, retainScroll)
    local b = scrollBox.binding
    scrollBox:SetDataProvider(
        CreateDataProvider(BuildDataWithSelection(b.mountType, b.savedKey, b.randomKey)),
        retainScroll and ScrollBoxConstants.RetainScrollPosition
            or ScrollBoxConstants.DiscardScrollPosition)
end

-- Builds the inset mount list inside a pooled row frame. The row may be reused
-- for a different mount type, so clicks read scrollBox.binding, not upvalues.
local function BuildMountList(frame)
    local container = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    -- Hang the list under the checkbox column of the row above.
    container:SetPoint("TOPLEFT", frame, "TOP", -80, -2)
    container:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 10)

    local scrollBar = CreateFrame("EventFrame", nil, container, "MinimalScrollBar")
    scrollBar:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, -5)
    scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -10, 5)

    local scrollBox = CreateFrame("Frame", nil, container, "WowScrollBoxList")
    scrollBox:SetPoint("TOPLEFT", container, "TOPLEFT", 2, -2)
    scrollBox:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMLEFT", -3, 0)

    local view = CreateScrollBoxListLinearView()
    view:SetPadding(4, 0, 0, 0, 0)
    view:SetElementExtent(22)
    view:SetElementInitializer("Button", function(row, elementData)
        row:SetPushedTextOffset(0, 0)
        row:SetNormalFontObject(GameFontHighlight)

        if not row.cbBorder then
            -- Gold hover highlight (HIGHLIGHT layer shows only on mouse-over)
            local hlTex = row:CreateTexture(nil, "HIGHLIGHT")
            hlTex:SetAllPoints()
            hlTex:SetColorTexture(1, 0.82, 0, 0.12)

            -- Checkbox border (always visible)
            row.cbBorder = row:CreateTexture(nil, "ARTWORK")
            row.cbBorder:SetSize(14, 14)
            row.cbBorder:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.cbBorder:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")

            -- Checkmark (shown when selected)
            row.cbCheck = row:CreateTexture(nil, "OVERLAY")
            row.cbCheck:SetSize(16, 16)
            row.cbCheck:SetPoint("CENTER", row.cbBorder, "CENTER", 0, 0)
            row.cbCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

            -- Mount icon
            row.mountIcon = row:CreateTexture(nil, "ARTWORK")
            row.mountIcon:SetSize(16, 16)
            row.mountIcon:SetPoint("LEFT", row.cbBorder, "RIGHT", 5, 0)

            -- Dedicated name label (avoids conflicts with the Button's built-in label anchors)
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.nameText:SetPoint("LEFT", row.mountIcon, "RIGHT", 5, 0)
            row.nameText:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.nameText:SetJustifyH("LEFT")
            row.nameText:SetWordWrap(false)
        end

        row.nameText:SetText(elementData.name)
        row.mountIcon:SetTexture(elementData.icon)
        row.cbCheck:SetShown(elementData.selected)

        row:SetScript("OnEnter", function(self)
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
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row:SetScript("OnClick", function()
            local b = scrollBox.binding
            elementData.selected = not elementData.selected
            row.cbCheck:SetShown(elementData.selected)

            if elementData.isRandom then
                FitterSaved[b.randomKey] = elementData.selected
                if elementData.selected then
                    -- Deselect all individual mounts
                    FitterSaved[b.savedKey] = {}
                end
            else
                if elementData.selected then
                    -- Deselect random
                    FitterSaved[b.randomKey] = false
                end
                local saved = FitterSaved[b.savedKey] or {}
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
                FitterSaved[b.savedKey] = saved
            end

            -- Rebuild data provider so all rows reflect the updated state
            RefreshMountList(scrollBox, true)
        end)
    end)

    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    frame.ScrollBox = scrollBox
end

local function BindMountList(frame, data)
    frame.ScrollBox.binding = data.binding
    RefreshMountList(frame.ScrollBox, false)
end

local FLYING_TOOLTIP = "When enabled, outfits that have no flying or ground mount selected"
    .. " will fall back to a random mount chosen from this list."
local GROUND_TOOLTIP = "When enabled, outfits that have no flying or ground mount selected"
    .. " will fall back to a random ground mount chosen from this list."
local AQUATIC_TOOLTIP = "When enabled, outfits that have no aquatic mount selected"
    .. " will fall back to a random aquatic mount chosen from this list."

-- Called from Options.lua:Register(). addCheckbox is Options.lua's checkbox
-- helper, so these settings bind to FitterSaved the same way as the rest.
function UI_Options:InitializeAccountWide(layout, addCheckbox)
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L["Account Wide"]))

    -- Mount bind conditionals --
    local conditionalsDropdown
    local function OnConditionalsChanged()
        if conditionalsDropdown then conditionalsDropdown:RefreshText() end
    end

    layout:AddInitializer(CreateCustomInitializer("FitterSettingsConditionAddTemplate", 34,
        {name = L["Add an Account Condition"]},
        function(frame)
            local addButton = ns.MountConditionalsUI.CreateAddButton(
                frame, "account", OnConditionalsChanged)
            addButton:SetPoint("LEFT", frame, "CENTER", -80, 0)
        end))

    layout:AddInitializer(CreateCustomInitializer("FitterSettingsConditionListTemplate", 34,
        {name = L["Current Account Conditionals"]},
        function(frame)
            frame.Dropdown = ns.MountConditionalsUI.CreateListDropdown(
                frame, "account", 220, OnConditionalsChanged)
            frame.Dropdown:SetPoint("LEFT", frame, "CENTER", -80, 0)
            -- Leaving the category or closing the panel hides this row.
            frame:HookScript("OnHide", function()
                ns.MountConditionalsUI.HidePopup("account")
            end)
        end,
        function(frame)
            conditionalsDropdown = frame.Dropdown
            conditionalsDropdown:RefreshText()
        end))

    -- Mount lists --
    -- Each list row is shown only while its checkbox is enabled; the checkbox's
    -- change callback repairs the display so the row appears or disappears.
    local function AddMountSection(mountType, label, tooltip)
        local enabledKey = "AccountWide" .. mountType .. "Enabled"
        local setting, checkboxInit = addCheckbox(enabledKey, label, tooltip,
            UI_Options.RepairDisplay)

        local list = CreateCustomInitializer("FitterSettingsMountListTemplate", 200, {
            binding = {
                mountType = mountType,
                savedKey = "AccountWide" .. mountType .. "Mounts",
                randomKey = "AccountWide" .. mountType .. "Random",
            },
        }, BuildMountList, BindMountList)
        list:SetParentInitializer(checkboxInit)
        list:AddShownPredicate(function() return setting:GetValue() end)
        layout:AddInitializer(list)
    end

    -- Clients without flying/aquatic mounts (e.g. WoW Forever) omit those sections.
    if ns.Features.FlyingMounts then
        AddMountSection("Flying", "Account Wide Flying Mounts", FLYING_TOOLTIP)
    end
    AddMountSection("Ground", "Account Wide Ground Mounts", GROUND_TOOLTIP)
    if ns.Features.AquaticMounts then
        AddMountSection("Aquatic", "Account Wide Aquatic Mounts", AQUATIC_TOOLTIP)
    end
end
