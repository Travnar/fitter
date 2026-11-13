local addonName, ns = ...
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s

function UI_Transmog:InitializeMountIcons()
    if s.mountIconsInitialized or not TransmogFrame or not TransmogFrame.CharacterPreview then
        return
    end

    local BuildMountSlotTransmogLocation = UI_Transmog._MountSlots.BuildTransmogLocation
    local RebuildMountSlots = UI_Transmog._MountSlots.Rebuild
    local CleanupMountSlot = UI_Transmog._MountSlots.Cleanup

    local charPreview = TransmogFrame.CharacterPreview

    local HideForeignCustomPanels

    local function MakePagedSelectSlot(pagedFrame, showFn)
        return function(_, slotFrame, forceRefresh)
            s.selectedFitterCategory = slotFrame.fitterCategory

            charPreview:UpdateSlot(slotFrame.slotData, forceRefresh)

            TransmogFrame.WardrobeCollection:SetToItemsTab()

            if TransmogFrame.WardrobeCollection.TabContent
                and TransmogFrame.WardrobeCollection.TabContent.ItemsFrame then
                TransmogFrame.WardrobeCollection.TabContent.ItemsFrame:Hide()
            end

            HideForeignCustomPanels(pagedFrame)
            showFn(UI_Transmog)
        end
    end

    s.flyingFrame.SelectSlot  = MakePagedSelectSlot(s.flyingFrame,  UI_Transmog.ShowFlyingPaged)
    s.groundFrame.SelectSlot  = MakePagedSelectSlot(s.groundFrame,  UI_Transmog.ShowGroundPaged)
    s.aquaticFrame.SelectSlot = MakePagedSelectSlot(s.aquaticFrame, UI_Transmog.ShowAquaticPaged)
    s.petFrame.SelectSlot     = MakePagedSelectSlot(s.petFrame,     UI_Transmog.ShowPetPaged)
    if s.hunterPetFrame then
        s.hunterPetFrame.SelectSlot = MakePagedSelectSlot(
            s.hunterPetFrame, UI_Transmog.ShowHunterPets)
    end
    s.hearthstoneFrame.SelectSlot = MakePagedSelectSlot(s.hearthstoneFrame, UI_Transmog.ShowHearthstonePaged)
    s.toyFrame.SelectSlot = MakePagedSelectSlot(s.toyFrame, UI_Transmog.ShowToyPaged)
    s.zonesFrame.SelectSlot = MakePagedSelectSlot(s.zonesFrame, UI_Transmog.ShowZones)
    s.emotesFrame.SelectSlot = MakePagedSelectSlot(s.emotesFrame, UI_Transmog.ShowEmotes)

    local slotSize = 44
    local slotScale = 0.95
    local effectiveSlotSize = slotSize * slotScale
    local slotSpacing = 15
    local hStep = effectiveSlotSize + slotSpacing   
    local vStep = effectiveSlotSize + slotSpacing  
    local baseX = 0
    local baseY = -100 
    -- Nudge the auxiliary selector group left to line up more naturally with
    -- Blizzard's right-side equipment slots.
    local rightX = -28
    local rightY = -18
    s.mountSlotDefs = {
        Flying  = { category = "Flying",  pagedFrame = s.flyingFrame,  scale = slotScale, xOffset = baseX,           yOffset = baseY,           transmogLocation = BuildMountSlotTransmogLocation("Flying")  },
        Ground  = { category = "Ground",  pagedFrame = s.groundFrame,  scale = slotScale, xOffset = baseX + hStep,   yOffset = baseY,           transmogLocation = BuildMountSlotTransmogLocation("Ground")  },
        Aquatic = { category = "Aquatic", pagedFrame = s.aquaticFrame, scale = slotScale, xOffset = baseX,           yOffset = baseY - vStep,   transmogLocation = BuildMountSlotTransmogLocation("Aquatic") },
        Pet     = { category = "Pet",     pagedFrame = s.petFrame,     scale = slotScale, xOffset = baseX + hStep,   yOffset = baseY - vStep,   transmogLocation = BuildMountSlotTransmogLocation("Pet")     },
        Hearthstone = {
            category = "Hearthstone", pagedFrame = s.hearthstoneFrame, scale = slotScale,
            point = "TOPRIGHT", relativePoint = "TOPRIGHT",
            xOffset = rightX - hStep, yOffset = rightY,
            transmogLocation = BuildMountSlotTransmogLocation("Hearthstone"),
        },
        Toy = {
            category = "Toy", pagedFrame = s.toyFrame, scale = slotScale,
            point = "TOPRIGHT", relativePoint = "TOPRIGHT",
            xOffset = rightX, yOffset = rightY,
            transmogLocation = BuildMountSlotTransmogLocation("Toy"),
        },
        Zones = {
            category = "Zones", pagedFrame = s.zonesFrame, scale = slotScale,
            point = "TOPRIGHT", relativePoint = "TOPRIGHT",
            xOffset = rightX - hStep, yOffset = rightY - vStep,
            transmogLocation = BuildMountSlotTransmogLocation("Zones"),
        },
        Emotes = {
            category = "Emotes", pagedFrame = s.emotesFrame, scale = slotScale,
            point = "TOPRIGHT", relativePoint = "TOPRIGHT",
            xOffset = rightX, yOffset = rightY - vStep,
            transmogLocation = BuildMountSlotTransmogLocation("Emotes"),
        },
    }
    -- Clients without flying/aquatic mounts (e.g. WoW Forever) drop those
    -- slots and pull Ground and Pet into the top row.
    if not ns.Features.FlyingMounts then
        s.mountSlotDefs.Flying = nil
        s.mountSlotDefs.Ground.xOffset = baseX
    end
    if not ns.Features.AquaticMounts then
        s.mountSlotDefs.Aquatic = nil
        if not s.mountSlotDefs.Flying then
            s.mountSlotDefs.Pet.xOffset = baseX + hStep
            s.mountSlotDefs.Pet.yOffset = baseY
        end
    end
    if s.hunterPetFrame then
        s.mountSlotDefs.HunterPet = {
            category = "HunterPet", pagedFrame = s.hunterPetFrame,
            scale = slotScale,
            -- Place Hunter Pets immediately to the right of Blizzard's
            -- weapon and off-hand slots along the bottom of the preview.
            xOffset = baseX + (7 * hStep) - 10,
            yOffset = baseY - vStep - 10,
            transmogLocation = BuildMountSlotTransmogLocation("HunterPet"),
        }
    end

    local function HideAllOurPagedFrames()
        if s.additionalFrame then s.additionalFrame:Hide() end
        if s.flyingFrame  then s.flyingFrame:Hide()  end
        if s.groundFrame  then s.groundFrame:Hide()  end
        if s.aquaticFrame then s.aquaticFrame:Hide() end
        if s.petFrame     then s.petFrame:Hide()     end
        if s.hunterPetFrame then s.hunterPetFrame:Hide() end
        if s.hearthstoneFrame then s.hearthstoneFrame:Hide() end
        UI_Transmog:SetToyFrameShown(false)
        if s.zonesFrame then s.zonesFrame:Hide() end
        if s.emotesFrame then s.emotesFrame:Hide() end
    end

    local function IsOurSlotFrame(slotFrame)
        return slotFrame == s.flyingSlotFrame
            or slotFrame == s.groundSlotFrame
            or slotFrame == s.aquaticSlotFrame
            or slotFrame == s.petSlotFrame
            or slotFrame == s.hunterPetSlotFrame
            or slotFrame == s.hearthstoneSlotFrame
            or slotFrame == s.toySlotFrame
            or slotFrame == s.zonesSlotFrame
            or slotFrame == s.emotesSlotFrame
    end

    local function IsOurPagedFrame(panel)
        return panel == s.flyingFrame
            or panel == s.groundFrame
            or panel == s.aquaticFrame
            or panel == s.petFrame
            or panel == s.hunterPetFrame
            or panel == s.hearthstoneFrame
            or panel == s.toyFrame
            or panel == s.additionalFrame
            or panel == s.zonesFrame
            or panel == s.emotesFrame
    end

    local function IterateActiveSlots()
        local pool = charPreview.CharacterAppearanceSlotFramePool
        if pool and pool.EnumerateActive then
            return pool:EnumerateActive()
        end
        return function() return nil end
    end

    local defaultIsEqual = TransmogLocationMixin and TransmogLocationMixin.IsEqual
    local function CollidesWithOurs(loc)
        if not loc or not defaultIsEqual then return false end
        for _, def in pairs(s.mountSlotDefs) do
            if defaultIsEqual(loc, def.transmogLocation) then
                return true
            end
        end
        return false
    end

    local function PatchForeignLocation(loc)
        if not loc or loc.fitterIsEqualPatched then return end
        loc.fitterIsEqualPatched = true
        local origIsEqual = loc.IsEqual
        loc.IsEqual = function(self, other)
            if type(other) == "table" and other.fitterCategory ~= nil then
                return false
            end
            if origIsEqual then return origIsEqual(self, other) end
            return rawequal(self, other)
        end
    end

    local function PatchForeignCustomSlots()
        for slotFrame in IterateActiveSlots() do
            if not IsOurSlotFrame(slotFrame)
                and slotFrame.slotData
                and slotFrame.slotData.transmogLocation then
                local loc = slotFrame.slotData.transmogLocation
                local panel = slotFrame.slotData.transmogFrame
                local isForeignCustom = panel and panel ~= TransmogFrame
                    and type(panel) == "table" and panel.Hide
                if isForeignCustom or CollidesWithOurs(loc) then
                    PatchForeignLocation(loc)
                    if not slotFrame.fitterClickHooked then
                        slotFrame.fitterClickHooked = true
                        slotFrame:HookScript("OnClick", function()
                            HideAllOurPagedFrames()
                        end)
                    end
                end
            end
        end
    end

    local function PatchStandardSlotPreviews()
        for slotFrame in IterateActiveSlots() do
            if not slotFrame.fitterNormalPreviewHooked then
                slotFrame.fitterNormalPreviewHooked = true
                slotFrame:HookScript("OnClick", function(self)
                    -- Pool frames can later be reused for a Fitter slot.
                    if not self.isFitterMountSlot
                        and (s.previewMountID or s.previewPetGUID
                            or s.previewHearthstoneActive) then
                        if s.previewHearthstoneActive then
                            UI_Transmog:PreviewHearthstoneCast(nil)
                        else
                            UI_Transmog:ClearMountPreview()
                        end
                    end
                end)
            end
        end
    end

    HideForeignCustomPanels = function(ourPagedFrame)
        for slotFrame in IterateActiveSlots() do
            if not IsOurSlotFrame(slotFrame) and slotFrame.slotData then
                local panel = slotFrame.slotData.transmogFrame
                if panel and panel ~= TransmogFrame
                    and type(panel) == "table" and panel.Hide
                    and not IsOurPagedFrame(panel)
                    and panel ~= ourPagedFrame then
                    panel:Hide()
                end
            end
        end
    end

    if not s.mountSlotsRegistered then
        s.mountSlotsRegistered = true

        if not s.mountedOutfitEventFrame then
            local eventFrame = CreateFrame("Frame")
            eventFrame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_CHANGED")
            eventFrame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH")
            eventFrame:SetScript("OnEvent", function(_, event)
                if event == "VIEWED_TRANSMOG_OUTFIT_CHANGED" then
                    UI_Transmog:HideTransientPopups()
                    UI_Transmog:CancelUITimers()
                    if s.previewHearthstoneActive then
                        UI_Transmog:PreviewHearthstoneCast(nil)
                    elseif s.previewMountID or s.previewPetGUID then
                        UI_Transmog:ClearMountPreview()
                    end
                    return
                end

                if not s.previewMountID then return end
                local request = s.mountPreviewRequest
                UI_Transmog:ScheduleTimer(0, function()
                    if request == s.mountPreviewRequest and s.previewMountID then
                        UI_Transmog:RefreshMountedOutfitPreview()
                    end
                end)
            end)
            s.mountedOutfitEventFrame = eventFrame
        end

        local function SelectHeadSlotAfterOpen(attempt)
            if not TransmogFrame:IsShown() then return end
            if UI_Transmog:IsOffVendor() then
                local slotFrame = s.flyingSlotFrame or s.groundSlotFrame
                if slotFrame and slotFrame.isFitterMountSlot then
                    s.selectHeadOnNextTransmogOpen = nil
                    slotFrame:Click("LeftButton")
                    return
                end
            end
            for slotFrame in IterateActiveSlots() do
                local location = slotFrame.slotData
                    and slotFrame.slotData.transmogLocation
                local slotID = location and location.GetSlotID
                    and location:GetSlotID()
                if not slotFrame.isFitterMountSlot
                    and slotID == Enum.TransmogOutfitSlot.Head then
                    s.selectHeadOnNextTransmogOpen = nil
                    if slotFrame.Click then slotFrame:Click("LeftButton") end
                    return
                end
            end

            if attempt < 10 then
                UI_Transmog:ScheduleTimer(0.05, function()
                    SelectHeadSlotAfterOpen(attempt + 1)
                end)
            end
        end

        TransmogFrame:HookScript("OnHide", function()
            UI_Transmog:ClearMountPreview()
            s.selectHeadOnNextTransmogOpen = true
            s.selectedFitterCategory = nil
        end)

        -- C_Timer rather than ScheduleTimer: the Blizzard reselect this
        -- follows cancels UI timers via the SetTab/SelectSlot hooks.
        local function ReselectFitterSlot()
            local category = s.selectedFitterCategory
            if not category then return end
            C_Timer.After(0, function()
                if not TransmogFrame:IsShown() then return end
                local selected = charPreview:GetSelectedSlotData()
                if selected and selected.isFitterMountSlot then return end
                for slotFrame in IterateActiveSlots() do
                    if slotFrame.isFitterMountSlot
                        and slotFrame.fitterCategory == category then
                        slotFrame:OnSelect()
                        return
                    end
                end
            end)
        end

        TransmogFrame:HookScript("OnShow", function()
            if s.selectHeadOnNextTransmogOpen then
                UI_Transmog:ScheduleTimer(0, function()
                    SelectHeadSlotAfterOpen(1)
                end)
            end
        end)

        hooksecurefunc(charPreview, "SetupSlots", function()
            -- Fitter slots share the ranged slot's location, so a Fitter
            -- selection can survive SetupSlots where a ranged slot exists
            -- (e.g. WoW Forever). Blizzard's RefreshSelectedSlot would then
            -- route it through TransmogFrame:SelectSlot, which errors on
            -- Fitter locations.
            local selected = charPreview:GetSelectedSlotData()
            if selected and selected.isFitterMountSlot then
                charPreview:SetSelectedSlotData(nil)
            end

            RebuildMountSlots()

            PatchForeignCustomSlots()
            PatchStandardSlotPreviews()
            ReselectFitterSlot()
        end)

        if TransmogSlotMixin then
            hooksecurefunc(TransmogSlotMixin, "Release", function(slot)
                if slot.isFitterMountSlot then
                    CleanupMountSlot(slot)
                end
            end)
        end
    end

    UI_Transmog._MountSlots.PrewarmPool(charPreview)
    RebuildMountSlots()
    PatchForeignCustomSlots()
    PatchStandardSlotPreviews()

    s.mountIconsInitialized = true

    
    if not s.mountPreviewFrame then
        s.mountPreviewFrame = CreateFrame("Frame", nil, UIParent)
        s.mountPreviewFrame:SetSize(300, 200)
        s.mountPreviewFrame:SetFrameStrata("TOOLTIP")
        s.mountPreviewFrame:SetFrameLevel(2000)
        s.mountPreviewFrame:Hide()
        
        local previewBg = s.mountPreviewFrame:CreateTexture(nil, "BACKGROUND")
        previewBg:SetAtlas("professions-recipe-background")
        previewBg:SetAllPoints(true)
        previewBg:SetVertexColor(0, 0, 0, 0.95)
        
        local previewBorder = s.mountPreviewFrame:CreateTexture(nil, "OVERLAY")
        previewBorder:SetAtlas("transmog-itemCard-default", true)
        previewBorder:SetAllPoints(true)
        
        s.mountPreviewModel = CreateFrame("PlayerModel", nil, s.mountPreviewFrame)
        s.mountPreviewModel:SetPoint("CENTER")
        s.mountPreviewModel:SetSize(280, 180)
        s.mountPreviewModel:SetFacing(-5.5)
    end
    

    self:RefreshFeatureVisibility()
    

    UI_Transmog:ScheduleTimer(0.1, function()
        self:UpdateMountIcons()
    end)
end


function UI_Transmog:UpdateMountIcons()
    if not s.mountIconsInitialized then
        return
    end
    local charPreview = TransmogFrame and TransmogFrame.CharacterPreview
    if not charPreview then return end
    if charPreview.RefreshSlots then
        charPreview:RefreshSlots()
    end

    local function RefreshFitterSlots()
        -- Iterate by key: optional slots (hunter pet, flying, aquatic) may
        -- be nil, which would stop ipairs over a list early.
        for _, key in ipairs({"flyingSlotFrame", "groundSlotFrame",
            "aquaticSlotFrame", "petSlotFrame", "hunterPetSlotFrame",
            "hearthstoneSlotFrame", "toySlotFrame", "zonesSlotFrame",
            "emotesSlotFrame"}) do
            local sf = s[key]
            if sf and sf.Update then
                sf:Update()
            end
        end
    end

    -- Refresh our pooled slots immediately.  CharacterPreview:RefreshSlots()
    -- does not reliably revisit custom slots, and relying only on a zero-delay
    -- timer leaves their icon/desaturation stale until the outfit is retabbed.
    RefreshFitterSlots()

    -- Blizzard can perform another slot update at the end of the frame, so
    -- retain a follow-up pass to keep the custom state authoritative.
    UI_Transmog:ScheduleTimer(0, RefreshFitterSlots)
end
