-- Shared controller for the Flying, Ground, and Aquatic mount pickers.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter
local MOUNT_EXPANSIONS = ns.Constants.MOUNT_EXPANSIONS

local PAGE_SIZE = 20

local function EnsureMountMacro()
    local name = "FitterMount"
    local index = GetMacroIndexByName(name)
    if index and index > 0 then return index end
    if select(1, GetNumMacros()) >= 120 then return nil end
    local class = ns.state.playerClass
    local body
    if FitterSaved and FitterSaved.UseDruidMacro and class == "DRUID" then
        body = "/stopmacro [flying,combat]\n/run FitterMount()\n/cast [indoors,noform:2] Cat Form; [nocombat,outdoors,advflyable,noform:3][swimming,noform:3]Travel Form;[outdoors,noform:3]Mount Form;"
    elseif FitterSaved and FitterSaved.UseShamanMacro and class == "SHAMAN" then
        body = "/stopmacro [flying,combat]\n/run FitterMount()\n/cast [noform:1] Ghost Wolf;"
    else
        body = "/run FitterMount()"
    end
    CreateMacro(name, 1769015, body, nil)
    index = GetMacroIndexByName(name)
    return index and index > 0 and index or nil
end

local function SetupMacroButton(frame)
    local button = UI_Transmog._CreateMacroIconButton(frame, 1769015)
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", 50, -25)
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", button, "RIGHT", 8, 0)
    label:SetText(L["Mount Macro"])
    label:SetTextColor(1, .82, 0, 1)
    local function Pickup()
        local index = EnsureMountMacro()
        if index then PickupMacro(index) end
    end
    button:SetScript("OnDragStart", Pickup)
    button:SetScript("OnClick", Pickup)
    button:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Mount Macro"], 1, 1, 1)
        local macroIndex = GetMacroIndexByName("FitterMount")
        if (not macroIndex or macroIndex == 0)
            and select(1, GetNumMacros()) >= 120 then
            GameTooltip:AddLine(
                "Cannot create macro: all 120 account macro slots are full.",
                1, .3, .3, true)
        else
            GameTooltip:AddLine(
                L["Drag or click to pick up the macro."], 1, .82, 0, true)
        end
        GameTooltip:Show()
    end)
end

local function CreateEntry(controller, index)
    local frameParent = controller:State("Frame")
    local col = (index - 1) % 5
    local row = math.floor((index - 1) / 5)
    local width, height, gap = 114, 146, 3
    local startX = -((5 * width + 4 * gap - width) / 2)
    local container = CreateFrame("Frame", nil, frameParent)
    container:SetSize(width, height)
    container:SetPoint("TOP", frameParent, "TOP",
        startX + col * (width + gap), -175 - row * (height + gap))
    container:SetClipsChildren(true)

    local black = container:CreateTexture(nil, "BACKGROUND", nil, -1)
    black:SetColorTexture(0, 0, 0, 1)
    black:SetPoint("TOPLEFT", 4, -4)
    black:SetPoint("BOTTOMRIGHT", -4, 4)
    local border = container:CreateTexture(nil, "ARTWORK")
    border:SetAtlas("transmog-setCard-default", true)
    border:SetAllPoints(true)
    local model = CreateFrame(
        "ModelScene", nil, container, "NonInteractableModelSceneMixinTemplate")
    model:SetPoint("TOPLEFT", 8, -8)
    model:SetPoint("BOTTOMRIGHT", -8, 8)
    model:SetClipsChildren(true)
    local checkbox = CreateFrame(
        "CheckButton", nil, container, "UICheckButtonTemplate")
    checkbox:SetSize(18, 18)
    checkbox:SetPoint("TOPRIGHT", container, "TOPRIGHT", -8, -8)
    local favorite = UI_Transmog._PagedShared.CreateFavoriteStar(container)
    local hover = container:CreateTexture(nil, "OVERLAY")
    hover:SetAtlas("transmog-setCard-default", true)
    hover:SetAllPoints(true)
    hover:SetBlendMode("ADD")
    hover:Hide()
    local uncollected = container:CreateTexture(nil, "OVERLAY", nil, 1)
    uncollected:SetAtlas("transmog-setCard-default", true)
    uncollected:SetAllPoints(true)
    uncollected:SetDesaturated(true)
    uncollected:SetVertexColor(.65, .72, .78, .55)
    uncollected:SetBlendMode("ADD")
    uncollected:Hide()

    local entry = {
        container = container, model = model, checkbox = checkbox,
        bg = border, hoverHighlight = hover, favoriteStar = favorite,
        uncollectedGlow = uncollected,
    }
    controller:State("ModelFrames")[index] = entry

    local function SetHover(selected)
        hover:SetAtlas(selected
            and "transmog-wardrobe-border-current-transmogged"
            or "transmog-setCard-default", true)
        hover:SetVertexColor(selected and 1 or 1, selected and 1 or .9,
            selected and 1 or .5, selected and .5 or .75)
    end
    container:SetScript("OnEnter", function(self)
        SetHover(checkbox:GetChecked())
        hover:Show()
        if entry.mountData then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(entry.mountData.name, 1, .82, 0, 1, true)
            if not entry.mountData.isCollected then
                GameTooltip:AddLine(
                    "You have not collected this mount.", .6, .6, .6, true)
            end
            GameTooltip:Show()
        end
    end)
    container:SetScript("OnLeave", function()
        hover:Hide()
        GameTooltip:Hide()
    end)
    container:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            if entry.mountData and not entry.mountData.isCollected then return end
            checkbox:Click()
            SetHover(checkbox:GetChecked())
        elseif button == "RightButton" then
            UI_Transmog._PagedShared.ShowMountContextMenu(
                self, entry.mountData, function() controller:Refresh() end)
        end
    end)
    container:EnableMouse(true)
    checkbox:SetScript("OnClick", function(self)
        local mount = entry.mountData
        if not mount or not mount.isCollected then
            self:SetChecked(false)
            return
        end
        local outfitID = UI_Transmog:GetViewedOutfitID()
        local data = outfitID and FitterCharacterSaved["Outfit" .. outfitID]
        if not data then return end
        local mounts = data[controller.category] or {}
        if self:GetChecked() then
            if not tContains(mounts, mount.id) then mounts[#mounts + 1] = mount.id end
        else
            tDeleteItem(mounts, mount.id)
        end
        data[controller.category] = mounts
        if #mounts > 0 then
            data[controller.category .. "Random"] = false
            data[controller.category .. "NoMount"] = false
            local card = controller:State("NoMountCard")
            if card then card:SetSelected(false) end
        end
        if self:GetChecked() then
            UI_Transmog:PreviewSelectedMount(mount.id)
        elseif s.previewMountID == mount.id then
            UI_Transmog:PreviewSelectedMount(mounts[#mounts])
        end
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
        controller:UpdateDisplay()
        UI_Transmog:UpdateMountIcons()
        UI_Transmog:RefreshActiveMountMacro(self:GetChecked() and mount.id or nil)
    end)
end

local Controller = {}
Controller.__index = Controller

function Controller:State(suffix, value)
    local key = self.prefix .. suffix
    if value ~= nil then s[key] = value end
    return s[key]
end

function Controller:IsDefaultFilter()
    return not self:State("CheckedOnly")
        and not self:State("ShowNotCollected")
        and (not self.groundMovementFilters
            or not self:State("FilterFlying") and not self:State("FilterGround"))
        and next(self:State("SelectedExpansions")) == nil
end

function Controller:ResetFilters()
    self:State("CheckedOnly", false)
    self:State("ShowNotCollected", false)
    if self.groundMovementFilters then
        self:State("FilterFlying", false)
        self:State("FilterGround", false)
    end
    wipe(self:State("SelectedExpansions"))
end

function Controller:Initialize()
    local frame = self:State("Frame")
    local _, _, search = UI_Transmog._PagedShared.CreateHeader(
        frame, self.category, function(text)
            self:State("SearchString", text)
            self:Refresh()
        end)
    self:State("PagedSearchBox", search)
    self:State("PagedSourcesDropdown",
        UI_Transmog._PagedShared.CreateFilterDropdown(frame, search, {
            isDefault = function() return self:IsDefaultFilter() end,
            default = function() self:ResetFilters(); self:Refresh() end,
            setup = function(_, root)
                local refresh = function() self:Refresh() end
                if self.groundMovementFilters then
                    root:CreateCheckbox(L["Flying"],
                        function() return self:State("FilterFlying") end,
                        function()
                            self:State("FilterFlying", not self:State("FilterFlying"))
                            refresh()
                        end)
                    root:CreateCheckbox(L["Ground"],
                        function() return self:State("FilterGround") end,
                        function()
                            self:State("FilterGround", not self:State("FilterGround"))
                            refresh()
                        end)
                end
                UI_Transmog._PagedShared.AddSelectedCheckbox(
                    root, s, self.prefix .. "CheckedOnly", refresh)
                root:CreateCheckbox(L["Not Collected"],
                    function() return self:State("ShowNotCollected") end,
                    function()
                        self:State("ShowNotCollected",
                            not self:State("ShowNotCollected"))
                        UI_Transmog:InvalidateMountListCache()
                        refresh()
                    end)
                UI_Transmog._PagedShared.AddCheckboxFilterSubmenu(
                    root, "Expansions", MOUNT_EXPANSIONS, s,
                    self.prefix .. "SelectedExpansions", refresh)
            end,
        }))

    local ignore = CreateFrame("Button", nil, frame, "DisplayTypeButtonTemplate")
    ignore:SetPoint("TOPLEFT", frame, "TOPLEFT", 50, -130)
    ignore:SetText(string.format(L["Ignore %s"], L[self.category]))
    ignore.IconFrame.Icon:SetTexture(self.ignoreIcon)
    ignore.IconFrame.Icon:SetDesaturated(true)
    ignore:SetScript("OnClick", function()
        local outfitID = UI_Transmog:GetViewedOutfitID()
        local data = outfitID and FitterCharacterSaved["Outfit" .. outfitID]
        if not data then return end
        data[self.category] = {}
        data[self.category .. "Random"] = false
        data[self.category .. "NoMount"] = false
        self:UpdateDisplay()
        UI_Transmog:UpdateMountIcons()
        UI_Transmog:RefreshActiveMountMacro()
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    end)
    ignore:HookScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(string.format(L["Ignore %s"], L[self.category]), 1, 1, 1)
        GameTooltip:AddLine(self.ignoreTooltip, 1, .82, 0, true)
        GameTooltip:Show()
    end)
    ignore:HookScript("OnLeave", function() GameTooltip:Hide() end)
    self:State("IgnoreButton", ignore)

    local random = CreateFrame("Button", nil, frame, "DisplayTypeButtonTemplate")
    random:SetPoint("LEFT", ignore, "RIGHT", 25, 0)
    random:SetText(L["Random Mount"])
    random.IconFrame.Icon:SetTexture(1669485)
    random:SetScript("OnClick", function()
        local outfitID = UI_Transmog:GetViewedOutfitID()
        local data = outfitID and FitterCharacterSaved["Outfit" .. outfitID]
        if not data then return end
        local key = self.category .. "Random"
        data[key] = not data[key]
        if data[key] then
            data[self.category] = {}
            data[self.category .. "NoMount"] = false
        end
        self:UpdateDisplay()
        UI_Transmog:UpdateMountIcons()
        UI_Transmog:RefreshActiveMountMacro()
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    end)
    random:HookScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Random Mount"], 1, 1, 1)
        GameTooltip:AddLine(L["Summons a random mount from this category."], 1, .82, 0)
        GameTooltip:AddLine(L["Selecting specific mounts turns this off."], .8, .8, .8)
        GameTooltip:Show()
    end)
    random:HookScript("OnLeave", function() GameTooltip:Hide() end)
    self:State("RandomButton", random)
    SetupMacroButton(frame)

    self:State("ModelFrames", {})
    for index = 1, PAGE_SIZE do CreateEntry(self, index) end
    self:State("NoMountCard", UI_Transmog._PagedShared.CreateNoSelectionCard(
        frame, { title = string.format(L["Disable %s"], L[self.category]), centerAtlas = self.noMountAtlas },
        function(selected)
            local outfitID = UI_Transmog:GetViewedOutfitID()
            local data = outfitID and FitterCharacterSaved["Outfit" .. outfitID]
            if not data then return end
            data[self.category .. "NoMount"] = selected
            if selected then
                data[self.category] = {}
                data[self.category .. "Random"] = false
                UI_Transmog:ClearMountPreview()
            end
            self:UpdateDisplay()
            UI_Transmog:UpdateMountIcons()
            UI_Transmog:RefreshActiveMountMacro()
            PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
        end))
    local page, previous, nextButton =
        UI_Transmog._PagedShared.CreateNavButtons(frame,
            function() self:PreviousPage() end,
            function() self:NextPage() end)
    self:State("PageText", page)
    self:State("PrevButton", previous)
    self:State("NextButton", nextButton)
end

function Controller:Show()
    local outfitID = UI_Transmog:GetViewedOutfitID()
    local data = outfitID and FitterCharacterSaved["Outfit" .. outfitID]
    local mounts = data and data[self.category]
    local focus = mounts and #mounts > 0 and mounts[math.random(#mounts)] or nil
    self:State("FocusMountID", focus)
    if not self:State("PagedInitialized") then
        self:Initialize()
        self:State("PagedInitialized", true)
    end
    UI_Transmog:_ShowPagedFrame(self:State("Frame"), self.updateMethod)
    UI_Transmog:PreviewSelectedMount(focus)
    s[self.prefix .. "FocusMountID"] = nil
end

function Controller:Update()
    if not self:State("Frame") then return end
    local outfitID = UI_Transmog:GetViewedOutfitID()
    if not outfitID then return end
    if not FitterCharacterSaved["Outfit" .. outfitID] then
        Fitter:CreateEmptyOutfit(outfitID)
    end
    self:ResetFilters()
    local search = self:State("PagedSearchBox")
    if search then search:SetText("") end
    self:State("SearchString", "")
    self:State("CurrentPage", 1)
    self:Refresh()
end

function Controller:Refresh()
    if not self:State("Frame") then return end
    local mounts = UI_Transmog:PopulateMountList(self.category)
    self:State("PagedMounts", mounts)
    local showCard = UI_Transmog._PagedShared.DoesSpecialCardMatchSearch(
        "Disable " .. self.category, self:State("SearchString"))
    self:State("ShowDisabledCard", showCard)
    self:State("TotalPages",
        UI_Transmog._PagedShared.GetSpecialCardTotalPages(#mounts, showCard))
    local outfitID = UI_Transmog:GetViewedOutfitID()
    local data = outfitID and FitterCharacterSaved["Outfit" .. outfitID]
    local selected = data and data[self.category] or {}
    local focus = self:State("FocusMountID") or selected[1]
    if focus then
        for index, mount in ipairs(mounts) do
            if mount.id == focus then
                self:State("CurrentPage",
                    UI_Transmog._PagedShared.GetSpecialCardPageForIndex(
                        index, showCard))
                break
            end
        end
    end
    self:State("CurrentPage", math.min(
        self:State("CurrentPage"), self:State("TotalPages")))
    self:UpdateDisplay()
end

local function ResetEntry(entry)
    entry.mountData = nil
    entry.model:SetAlpha(1)
    entry.bg:SetDesaturated(false)
    entry.bg:SetVertexColor(1, 1, 1)
    entry.uncollectedGlow:Hide()
    if entry.playerModel then entry.playerModel:Hide() end
    entry.model:Show()
    local actor = entry.model:GetActorByTag("unwrapped")
    if actor then actor:ClearModel() end
    entry.checkbox:SetChecked(false)
    entry.favoriteStar:Hide()
    entry.hoverHighlight:Hide()
    entry.bg:SetAtlas("transmog-setCard-default", true)
    if GameTooltip:GetOwner() == entry.container then GameTooltip:Hide() end
    entry.container:Hide()
end

function Controller:UpdateDisplay()
    local frame = self:State("Frame")
    if not frame then return end
    local outfitID = UI_Transmog:GetViewedOutfitID()
    local data = outfitID and FitterCharacterSaved["Outfit" .. outfitID]
    local random = self:State("RandomButton")
    if random and random.StateTexture then
        random.StateTexture:SetShown(data
            and data[self.category .. "Random"] == true)
    end
    local ignore = self:State("IgnoreButton")
    if ignore and ignore.StateTexture then
        local selected = data and data[self.category]
        local configured = data and (data[self.category .. "NoMount"] == true
            or selected and #selected > 0
            or data[self.category .. "Random"] == true)
        ignore.StateTexture:SetShown(not configured)
    end
    local card = self:State("NoMountCard")
    if card then
        card:SetSelected(data and data[self.category .. "NoMount"] == true)
        card:SetShown(self:State("ShowDisabledCard")
            and self:State("CurrentPage") == 1)
    end
    wipe(s.savedMountsScratch)
    for _, id in ipairs(data and data[self.category] or {}) do
        s.savedMountsScratch[id] = true
    end
    local currentPage = self:State("CurrentPage")
    local showCard = self:State("ShowDisabledCard")
    local start = UI_Transmog._PagedShared.GetSpecialCardPageStart(
        currentPage, showCard)
    local mounts = self:State("PagedMounts")
    for index, entry in ipairs(self:State("ModelFrames")) do
        UI_Transmog._PagedShared.PositionSpecialCardPageItem(
            entry.container, frame, index, currentPage, showCard)
        local mountIndex = start + index - 1
        local mount = (not showCard or currentPage ~= 1 or index <= 19)
            and mounts[mountIndex] or nil
        if not mount then
            ResetEntry(entry)
        else
            entry.mountData = mount
            local collected = mount.isCollected ~= false
            entry.model:SetAlpha(collected and 1 or .45)
            entry.bg:SetDesaturated(not collected)
            entry.bg:SetVertexColor(collected and 1 or .62,
                collected and 1 or .68, collected and 1 or .72)
            entry.uncollectedGlow:SetShown(not collected)
            if mount.isPlayerModel then
                entry.model:Hide()
                if not entry.playerModel then
                    entry.playerModel = CreateFrame("PlayerModel", nil, entry.container)
                    entry.playerModel:SetPoint("TOPLEFT", 8, -8)
                    entry.playerModel:SetPoint("BOTTOMRIGHT", -8, 8)
                end
                entry.playerModel:SetUnit("player")
                entry.playerModel:SetCustomCamera(0)
                entry.playerModel:SetCamDistanceScale(mount.camScale or 1.5)
                entry.playerModel:Show()
            else
                if entry.playerModel then entry.playerModel:Hide() end
                entry.model:Show()
                if mount.model and mount.sceneID then
                    entry.model:TransitionToModelSceneID(mount.sceneID,
                        CAMERA_TRANSITION_TYPE_IMMEDIATE,
                        CAMERA_MODIFICATION_TYPE_DISCARD, false)
                    local actor = entry.model:GetActorByTag("unwrapped")
                    if actor then
                        actor:SetModelByCreatureDisplayID(mount.model)
                        if mount.spellVisualKitID then
                            actor:SetSpellVisualKit(mount.spellVisualKitID)
                        end
                    end
                    local camera = entry.model:GetActiveCamera()
                    if camera and camera.SetZoomDistance
                        and camera.GetZoomDistance then
                        camera:SetZoomDistance(camera:GetZoomDistance() * .55)
                    end
                else
                    local actor = entry.model:GetActorByTag("unwrapped")
                    if actor then actor:ClearModel() end
                end
            end
            local selected = s.savedMountsScratch[mount.id] == true
            entry.checkbox:SetChecked(selected)
            entry.checkbox:Hide()
            entry.favoriteStar:SetShown(
                UI_Transmog._PagedShared.IsMountFavorite(mount.id))
            entry.bg:SetAtlas(selected
                and "transmog-wardrobe-border-current-transmogged"
                or "transmog-setCard-default", true)
            entry.container:Show()
        end
    end
    self:State("PageText"):SetText(string.format(
        L["Page %d/%d"], currentPage, self:State("TotalPages")))
    self:State("PrevButton"):SetEnabled(currentPage > 1)
    self:State("NextButton"):SetEnabled(currentPage < self:State("TotalPages"))
    for _, entry in ipairs(self:State("ModelFrames")) do
        if entry.container:IsVisible() and entry.container:IsMouseOver() then
            entry.container:GetScript("OnEnter")(entry.container)
            break
        end
    end
end

function Controller:PreviousPage()
    if self:State("CurrentPage") > 1 then
        self:State("CurrentPage", self:State("CurrentPage") - 1)
        self:UpdateDisplay()
        PlaySound(SOUNDKIT.UI_TRANSMOG_PAGE_TURN)
    end
end

function Controller:NextPage()
    if self:State("CurrentPage") < self:State("TotalPages") then
        self:State("CurrentPage", self:State("CurrentPage") + 1)
        self:UpdateDisplay()
        PlaySound(SOUNDKIT.UI_TRANSMOG_PAGE_TURN)
    end
end

function UI_Transmog:RegisterMountPage(config)
    local controller = setmetatable(config, Controller)
    controller.updateMethod = "Update" .. config.category .. "Paged"
    self["Show" .. config.category .. "Paged"] = function() controller:Show() end
    self["Initialize" .. config.category .. "Paged"] =
        function() controller:Initialize() end
    self[controller.updateMethod] = function() controller:Update() end
    self["Refresh" .. config.category .. "Paged"] =
        function() controller:Refresh() end
    self["Update" .. config.category .. "PageDisplay"] =
        function() controller:UpdateDisplay() end
    self[config.category .. "PagePrev"] =
        function() controller:PreviousPage() end
    self[config.category .. "PageNext"] =
        function() controller:NextPage() end
end
