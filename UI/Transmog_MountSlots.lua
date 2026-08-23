-- Transmog_MountSlots.lua
-- The custom selector slots added to the TransmogFrame.CharacterPreview:
-- Flying / Ground / Aquatic, Pet / Hearthstone / Toy, Zones, and Emotes.
-- in UI_Transmog.lua but the slot lifecycle helpers live here.
--
-- Exposed on UI_Transmog._MountSlots so the core file can call them.

local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local ZONE_NAMES = {}
local ZONE_ICONS = {}
for _, zone in ipairs(ns.Zones.MAJOR_ZONES) do
    ZONE_NAMES[zone.mapID] = zone.name
    ZONE_ICONS[zone.mapID] = zone.icon
end

local function GetSelectedHearthstones(data)
    if not data then return {} end
    if type(data.Hearthstones) == "table" then return data.Hearthstones end
    if type(data.Hearthstone) == "number" then return {data.Hearthstone} end
    return {}
end

local function GetZonesIcon(mapID)
    local zoneIcon = mapID and ZONE_ICONS[mapID]
    if type(zoneIcon) == "string" and zoneIcon ~= "" then
        return "Interface\\Icons\\" .. zoneIcon
    end
    if UnitFactionGroup("player") == "Horde" then
        return "Interface\\Icons\\achievement_zone_kalimdor_01"
    end
    return "Interface\\Icons\\achievement_zone_easternkingdoms_01"
end

local function GetAssignedEmotes(data)
    local assigned = {}
    for id, assignment in pairs(data and data.Emotes or {}) do
        local definition = ns.Emote.GetDefinition(id)
        if definition and type(assignment) == "table"
            and type(assignment.conditions) == "table"
            and next(assignment.conditions) then
            assigned[#assigned + 1] = definition
        end
    end
    table.sort(assigned, function(a, b)
        return (a.name or a.text or a.id) < (b.name or b.text or b.id)
    end)
    return assigned
end


local function GetMountSlotIconState(category)
    local outfitID = UI_Transmog:GetViewedOutfitID()
    local data = outfitID and FitterCharacterSaved and FitterCharacterSaved["Outfit"..outfitID]
    local categoryIcon = (category == "Flying" and "Interface\\Icons\\ability_dragonriding_dragonridinggliding01")
        or (category == "Ground" and "Interface\\Icons\\ability_mount_ridinghorse")
        or (category == "Aquatic" and "Interface\\Icons\\item_aquaticfin_17")
        or 134400
    if not data then
        if category == "Hearthstone" then return 134414, false end
        if category == "Toy" then return 133015, false end
        if category == "Zones" then
            return GetZonesIcon(), false
        end
        if category == "Emotes" then
            return ns.Constants.EMOTE_CATEGORY_ICON, false
        end
        return categoryIcon, false
    end
    if category == "Zones" then
        local zones = data.Zones or {}
        if #zones == 1 then
            return GetZonesIcon(zones[1]), true
        end
        return GetZonesIcon(), #zones > 0
    end
    if category == "Emotes" then
        local emotes = GetAssignedEmotes(data)
        if #emotes == 1 then
            return ns.Emote.ResolveIcon(emotes[1].icon)
                or ns.Constants.EMOTE_CATEGORY_ICON, true
        end
        return ns.Constants.EMOTE_CATEGORY_ICON, #emotes > 0
    end
    if category == "HunterPet" then
        if data.HunterPetDisabled then return 132161, true end
        if data.HunterPetRandom then return 1669485, true end
        local pets = ns.HunterPet.GetSelectedPets(data)
        if #pets > 1 then return 132161, true end
        if #pets == 1 then return pets[1].icon or 132161, true end
        if data.HunterPetNumber then
            return data.HunterPetIcon or 132161, true
        end
        return 132161, false
    end
    if category == "Pet" then
        if data.PetNoPet then
            return 132598, true
        end
        local pets = data.Pets or {}
        if #pets > 1 then
            return 132598, true
        elseif #pets == 1 then
            local _, _, _, _, _, _, _, _, petIcon = C_PetJournal.GetPetInfoByPetID(pets[1])
            return petIcon or 134400, true
        end
        if data.PetRandom then
            return 1669485, true
        end
        return 132598, false
    end
    if category == "Hearthstone" then
        local hearthstones = GetSelectedHearthstones(data)
        if #hearthstones > 1 then return 134414, true end
        if #hearthstones == 0 then return 134414, false end
        local itemID = hearthstones[1]
        local icon = itemID == 6948 and C_Item.GetItemIconByID(itemID)
            or select(3, C_ToyBox.GetToyInfo(itemID))
        return icon or 134414, true
    end
    if category == "Toy" then
        local toys = data.Toys or {}
        if #toys == 1 then
            return select(3, C_ToyBox.GetToyInfo(toys[1])) or 134400, true
        end
        return 133015, #toys > 0
    end

    local arr = data[category]
    if data[category .. "NoMount"] then
        return categoryIcon, true
    end
    if not arr or #arr == 0 then
        if data[category .. "Random"] then
            return 1669485, true
        end
        return categoryIcon, false
    end
    if #arr > 1 then
        return categoryIcon, true
    end
    local sel = arr[1]
    if sel == "soar" then
        return 4622485, true
    elseif sel == "runningwild" then
        return 514641, true
    end
    local _, _, icon = C_MountJournal.GetMountInfoByID(sel)
    return icon or categoryIcon, true
end

local function BuildMountSlotTransmogLocation(category)
    local locationData = {
        slot = Enum.TransmogOutfitSlot.WeaponRanged,
        slotID = nil,
        transmogType = Enum.TransmogType.Appearance,
        isSecondary = false,
    }
    local location = CreateFromMixins(TransmogLocationMixin)
    location:Set(locationData)
    location.fitterCategory = category
    location.GetSlotName = function() return "FITTER_MOUNTSLOT_" .. category end
    location.IsAppearance = function() return false end
    location.IsEqual = function(self, other)
        return type(other) == "table"
            and other.fitterCategory ~= nil
            and other.fitterCategory == self.fitterCategory
    end
    return location
end

local function AcquireMountSlot(charPreview, def)
    local slotData = {
        transmogLocation = def.transmogLocation,
        transmogFrame = def.pagedFrame,
        currentWeaponOptionInfo = nil,
        texture = nil,
        canTransmogrify = true,
        isFitterMountSlot = true,
        fitterCategory = def.category,
        fitterPagedFrame = def.pagedFrame,
    }

    local slotFrame = charPreview.CharacterAppearanceSlotFramePool:Acquire()
    slotFrame.isFitterMountSlot = true
    slotFrame.fitterCategory = def.category
    slotFrame:Init(slotData)
    slotFrame:SetParent(charPreview)
    slotFrame:SetFrameLevel(5)

    slotFrame:SetScale(def.scale or 1)
    slotFrame:ClearAllPoints()
    if def.point then
        slotFrame:SetPoint(def.point, charPreview, def.relativePoint or def.point,
            def.xOffset, def.yOffset)
    else
        slotFrame:SetPoint("BOTTOMLEFT", charPreview.LeftSlots, "BOTTOMLEFT",
            def.xOffset, def.yOffset)
    end
    slotFrame:Show()

    slotFrame.GetSlotInfo = function(self)
        local icon, isTransmogd = GetMountSlotIconState(def.category)
        return {
            transmogID = 0,
            displayType = isTransmogd
                and Enum.TransmogOutfitDisplayType.Assigned
                or Enum.TransmogOutfitDisplayType.Unassigned,
            isTransmogrified = isTransmogd,
            hasPending = false,
            isPendingCollected = true,
            canTransmogrify = true,
            warning = Enum.TransmogOutfitSlotWarning.Ok,
            warningText = "",
            error = Enum.TransmogOutfitSlotError.Ok,
            errorText = "",
            texture = icon,
        }
    end

    slotFrame.OnEnter = function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local outfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
        local data = outfitID and FitterCharacterSaved and FitterCharacterSaved["Outfit"..outfitID]
        local isNoSelection = data and ((def.category == "Pet" and data.PetNoPet)
            or (def.category == "HunterPet" and data.HunterPetDisabled)
            or data[def.category .. "NoMount"])
        if isNoSelection then
            GameTooltip:SetText(def.category == "Pet" and L["Pets"]
                or def.category == "HunterPet" and L["Hunter Pets"]
                or L[def.category],
                1, 0.82, 0, 1, true)
            GameTooltip:AddLine(L["Disabled"], 1, .5, 1, true)
        elseif def.category == "Hearthstone" then
            local hearthstones = GetSelectedHearthstones(data)
            if #hearthstones == 1 then
                local itemID = hearthstones[1]
                local name = itemID == 6948 and C_Item.GetItemNameByID(itemID)
                    or select(2, C_ToyBox.GetToyInfo(itemID))
                GameTooltip:SetText(name or L["Hearthstones"], 1, 0.82, 0, 1, true)
            else
                GameTooltip:SetText(L["Hearthstones"], 1, 0.82, 0, 1, true)
                for _, itemID in ipairs(hearthstones) do
                    local name = itemID == 6948 and C_Item.GetItemNameByID(itemID)
                        or select(2, C_ToyBox.GetToyInfo(itemID))
                    if name then GameTooltip:AddLine(name, 1, 1, 1) end
                end
            end
        elseif def.category == "Toy" then
            local toys = data and data.Toys or {}
            GameTooltip:SetText(L["Cosmetic Toys"], 1, 0.82, 0, 1, true)
            for _, toyID in ipairs(toys) do
                local name = select(2, C_ToyBox.GetToyInfo(toyID))
                if name then GameTooltip:AddLine(name, 1, 1, 1) end
            end
        elseif def.category == "Zones" then
            local zones = data and data.Zones or {}
            GameTooltip:SetText(L["Zones"], 1, 0.82, 0, 1, true)
            local zoneNames = {}
            for _, mapID in ipairs(zones) do
                zoneNames[#zoneNames + 1] = ZONE_NAMES[mapID]
                    or ("Zone " .. tostring(mapID))
            end
            table.sort(zoneNames)
            for _, name in ipairs(zoneNames) do
                GameTooltip:AddLine(name, 1, 1, 1)
            end
        elseif def.category == "Emotes" then
            local emotes = GetAssignedEmotes(data)
            GameTooltip:SetText(L["Emotes"], 1, 0.82, 0, 1, true)
            for _, emote in ipairs(emotes) do
                GameTooltip:AddLine(
                    emote.name or emote.text or emote.id, 1, 1, 1)
            end
        elseif def.category == "Pet" then
            local singleName
            if data then
                local pets = data.Pets or {}
                if #pets == 1 then
                    local _, customName, _, _, _, _, _, speciesName = C_PetJournal.GetPetInfoByPetID(pets[1])
                    singleName = customName or speciesName
                elseif #pets > 1 then
                    GameTooltip:SetText(L["Pets"], 1, 0.82, 0, 1, true)
                    for _, guid in ipairs(pets) do
                        local _, customName, _, _, _, _, _, speciesName = C_PetJournal.GetPetInfoByPetID(guid)
                        local name = customName or speciesName
                        if name then
                            GameTooltip:AddLine(name, 1, 1, 1)
                        end
                    end
                    GameTooltip:Show()
                    return
                end
            end
            GameTooltip:SetText(singleName or L["Pets"], 1, 0.82, 0, 1, true)
        elseif def.category == "HunterPet" then
            local selectedPets = data and ns.HunterPet.GetSelectedPets(data) or {}
            if #selectedPets == 1 then
                GameTooltip:SetText(selectedPets[1].name or L["Hunter Pet"],
                    1, 0.82, 0, 1, true)
            elseif #selectedPets > 1 then
                GameTooltip:SetText(L["Hunter Pets"], 1, 0.82, 0, 1, true)
                for _, pet in ipairs(selectedPets) do
                    GameTooltip:AddLine(pet.name or L["Hunter Pet"], 1, 1, 1)
                end
            else
                GameTooltip:SetText(L["Hunter Pets"], 1, 0.82, 0, 1, true)
            end
        else
            local singleName
            if data then
                local mounts = data[def.category] or {}
                local function GetMountName(mountID)
                    if mountID == "soar" then
                        local info = C_Spell.GetSpellInfo(369536)
                        return info and info.name
                    elseif mountID == "runningwild" then
                        local info = C_Spell.GetSpellInfo(87840)
                        return info and info.name
                    end
                    return C_MountJournal.GetMountInfoByID(mountID)
                end

                if #mounts == 1 then
                    singleName = GetMountName(mounts[1])
                elseif #mounts > 1 then
                    GameTooltip:SetText(L[def.category], 1, 0.82, 0, 1, true)
                    for _, mountID in ipairs(mounts) do
                        local name = GetMountName(mountID)
                        if name then
                            GameTooltip:AddLine(name, 1, 1, 1)
                        end
                    end
                    GameTooltip:Show()
                    return
                end
            end
            GameTooltip:SetText(singleName or L[def.category], 1, 0.82, 0, 1, true)
        end
        GameTooltip:Show()
    end
    slotFrame:SetScript("OnEnter", function(self) self:OnEnter() end)

    local function ApplyDesaturation(sf)
        local icon, isSelected = GetMountSlotIconState(def.category)

        local tex = sf.IconTexture or sf.Icon or sf.Texture
        if not tex and sf.GetNormalTexture then tex = sf:GetNormalTexture() end
        if not tex then

            for _, region in ipairs({sf:GetRegions()}) do
                if region.SetDesaturated and region.GetDrawLayer
                    and region:GetDrawLayer() == "ARTWORK" then
                    tex = region
                    break
                end
            end
        end
        local outfitID = C_TransmogOutfitInfo
            and C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
        local data = outfitID and FitterCharacterSaved
            and FitterCharacterSaved["Outfit"..outfitID]
        local isNoSelection = data and ((def.category == "Pet" and data.PetNoPet)
            or (def.category == "HunterPet" and data.HunterPetDisabled)
            or data[def.category .. "NoMount"])
        if tex then
            -- Keep this explicit assignment as a safeguard for custom slot
            -- states; the base Update normally applies the same texture from
            -- GetSlotInfo immediately before this runs.
            tex:SetTexture(icon)
            if isNoSelection then
                tex:SetVertexColor(.18, .18, .18)
            else
                tex:SetVertexColor(1, 1, 1)
            end
            tex:SetDesaturated(isNoSelection or not isSelected)
        end

        if not sf.FitterNoSelectionIcon then
            local hiddenIcon = sf:CreateTexture(nil, "OVERLAY", nil, 7)
            hiddenIcon:SetAtlas("transmog-icon-hidden-small")
            hiddenIcon:SetSize(30, 30)
            hiddenIcon:SetPoint("CENTER", sf, "CENTER", 0, 0)
            hiddenIcon:Hide()
            sf.FitterNoSelectionIcon = hiddenIcon
        end
        sf.FitterNoSelectionIcon:SetShown(isNoSelection == true)
        if not isNoSelection and tex then
            tex:SetVertexColor(1, 1, 1)
        end
    end

    local baseUpdate = slotFrame.Update
    slotFrame.Update = function(self, ...)
        if baseUpdate then baseUpdate(self, ...) end
        ApplyDesaturation(self)
    end

    -- Init() can perform its first update before the wrapper above is installed.
    -- Apply the state now so newly acquired slots are grayscale while empty.
    ApplyDesaturation(slotFrame)

    return slotFrame
end

local function CleanupMountSlot(slotFrame)
    if slotFrame.FitterNoSelectionIcon then
        slotFrame.FitterNoSelectionIcon:Hide()
    end
    slotFrame.isFitterMountSlot = nil
    slotFrame.fitterCategory = nil
    slotFrame.GetSlotInfo = TransmogSlotMixin and TransmogSlotMixin.GetSlotInfo or nil
    slotFrame.OnEnter = TransmogSlotMixin and TransmogSlotMixin.OnEnter or nil
    slotFrame.Update = TransmogAppearanceSlotMixin
        and TransmogAppearanceSlotMixin.Update or nil
    slotFrame.RefreshSlot = nil
    slotFrame:SetScale(1)
end

local function RebuildMountSlots()
    local charPreview = TransmogFrame and TransmogFrame.CharacterPreview
    if not charPreview or not s.mountSlotDefs then return end
    s.flyingSlotFrame  = AcquireMountSlot(charPreview, s.mountSlotDefs.Flying)
    s.groundSlotFrame  = AcquireMountSlot(charPreview, s.mountSlotDefs.Ground)
    s.aquaticSlotFrame = AcquireMountSlot(charPreview, s.mountSlotDefs.Aquatic)
    s.petSlotFrame     = AcquireMountSlot(charPreview, s.mountSlotDefs.Pet)
    if s.mountSlotDefs.HunterPet then
        s.hunterPetSlotFrame = AcquireMountSlot(
            charPreview, s.mountSlotDefs.HunterPet)
    end
    s.hearthstoneSlotFrame = AcquireMountSlot(charPreview, s.mountSlotDefs.Hearthstone)
    s.toySlotFrame = AcquireMountSlot(charPreview, s.mountSlotDefs.Toy)
    s.zonesSlotFrame = AcquireMountSlot(charPreview, s.mountSlotDefs.Zones)
    s.emotesSlotFrame = AcquireMountSlot(charPreview, s.mountSlotDefs.Emotes)
end


UI_Transmog._MountSlots = {
    GetIconState         = GetMountSlotIconState,
    BuildTransmogLocation = BuildMountSlotTransmogLocation,
    Acquire              = AcquireMountSlot,
    Cleanup              = CleanupMountSlot,
    Rebuild              = RebuildMountSlots,
}

-- Moved from UI_Transmog.lua to keep that file under 500 lines.

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
        end)

        TransmogFrame:HookScript("OnShow", function()
            if s.selectHeadOnNextTransmogOpen then
                UI_Transmog:ScheduleTimer(0, function()
                    SelectHeadSlotAfterOpen(1)
                end)
            end
        end)

        hooksecurefunc(charPreview, "SetupSlots", function()
            RebuildMountSlots()

            PatchForeignCustomSlots()
            PatchStandardSlotPreviews()
        end)

        if TransmogSlotMixin then
            hooksecurefunc(TransmogSlotMixin, "Release", function(slot)
                if slot.isFitterMountSlot then
                    CleanupMountSlot(slot)
                end
            end)
        end
    end

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
        for _, sf in ipairs({s.flyingSlotFrame, s.groundSlotFrame, s.aquaticSlotFrame,
            s.petSlotFrame, s.hunterPetSlotFrame, s.hearthstoneSlotFrame,
            s.toySlotFrame, s.zonesSlotFrame,
            s.emotesSlotFrame}) do
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

-- Show the currently previewed transmog riding a selected mount.  Keeping the
-- mount actor in CharacterPreview's existing ModelScene is important: its
-- player actor already contains all pending outfit changes.
function UI_Transmog:ClearMountPreviewLegacy()
    s.mountPreviewRequest = (s.mountPreviewRequest or 0) + 1
    local scene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    local mountActor = s.characterPreviewMountActor
    local playerActor = scene and scene.GetPlayerActor and scene:GetPlayerActor()

    if mountActor then
        if playerActor and mountActor.DetachFromMount then
            pcall(mountActor.DetachFromMount, mountActor, playerActor)
        end
        mountActor:ClearModel()
    end
    if playerActor and playerActor.SetRequestedScale then
        playerActor:SetRequestedScale(1)
    end
    if playerActor and playerActor.SetSheathed and s.characterPreviewWasSheathed ~= nil then
        playerActor:SetSheathed(s.characterPreviewWasSheathed)
    end

    local camera = scene and scene.GetActiveCamera and scene:GetActiveCamera()
    if camera and s.characterPreviewCameraZoom and camera.SetZoomDistance then
        if s.characterPreviewCameraMaxZoom and camera.SetMaxZoomDistance then
            camera:SetMaxZoomDistance(s.characterPreviewCameraMaxZoom)
        end
        if s.characterPreviewCameraMinZoom and camera.SetMinZoomDistance then
            camera:SetMinZoomDistance(s.characterPreviewCameraMinZoom)
        end
        camera:SetZoomDistance(s.characterPreviewCameraZoom)
        if camera.SnapAllInterpolatedValues then
            camera:SnapAllInterpolatedValues()
        end
    end

    s.characterPreviewCameraZoom = nil
    s.characterPreviewCameraMinZoom = nil
    s.characterPreviewCameraMaxZoom = nil
    s.characterPreviewWasSheathed = nil
    s.previewMountID = nil
end

function UI_Transmog:PreviewSelectedMountLegacy(mountID)
    if type(mountID) ~= "number" then
        self:ClearMountPreview()
        return
    end

    local scene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    if not scene or not scene.GetPlayerActor then return end

    local displayID, _, _, isSelfMount, _, modelSceneID, animID, spellVisualKitID,
        disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
    if not displayID or displayID == 0 then
        local displays = C_MountJournal.GetMountAllCreatureDisplayInfoByID(mountID)
        displayID = displays and displays[1] and displays[1].creatureDisplayID
    end
    if not displayID or isSelfMount or disablePlayerMountPreview then
        self:ClearMountPreview()
        return
    end

    self:ClearMountPreview()
    local request = s.mountPreviewRequest

    local playerActor = scene:GetPlayerActor()
    if not playerActor then return end

    local mountActor = s.characterPreviewMountActor
    if not mountActor then
        mountActor = scene:CreateActor()
        s.characterPreviewMountActor = mountActor
    end

    mountActor:SetUseCenterForOrigin(false, false, false)
    mountActor:SetPosition(0, 0, 0)
    mountActor:SetYaw(0)
    mountActor:SetPitch(0)
    mountActor:SetRoll(0)
    mountActor:SetScale(1)

    -- Mount scene presets carry an actor transform tailored to that mount.
    -- Copy only the transform/scale fields: applying the whole preset would
    -- replace the transmog scene and its already-dressed player actor.
    if modelSceneID and C_ModelInfo then
        pcall(function()
            local _, _, actorIDs = C_ModelInfo.GetModelSceneInfoByID(modelSceneID)
            local mountActorInfo
            for _, actorID in ipairs(actorIDs or {}) do
                local actorInfo = C_ModelInfo.GetModelSceneActorInfoByID(actorID)
                if actorInfo and (actorInfo.scriptTag == "unwrapped" or not mountActorInfo) then
                    mountActorInfo = actorInfo
                    if actorInfo.scriptTag == "unwrapped" then break end
                end
            end
            if mountActorInfo then
                mountActor:SetUseCenterForOrigin(
                    mountActorInfo.useCenterForOriginX,
                    mountActorInfo.useCenterForOriginY,
                    mountActorInfo.useCenterForOriginZ)
                mountActor:SetPosition(mountActorInfo.position:GetXYZ())
                mountActor:SetYaw(mountActorInfo.yaw)
                mountActor:SetPitch(mountActorInfo.pitch)
                mountActor:SetRoll(mountActorInfo.roll)

                local actorDisplayInfo = mountActorInfo.modelActorDisplayID
                    and C_ModelInfo.GetModelSceneActorDisplayInfoByID(
                        mountActorInfo.modelActorDisplayID)
                mountActor:SetScale(actorDisplayInfo and actorDisplayInfo.scale or 1)
            end
        end)
    end

    if not mountActor:SetModelByCreatureDisplayID(displayID) then return end
    if spellVisualKitID then
        mountActor:SetSpellVisualKit(spellVisualKitID)
    end
    s.previewMountID = mountID

    -- SetModel is asynchronous. Calling the mount attachment API before both
    -- actors have geometry is unreliable and can be especially dangerous for
    -- unusually large flying models, so wait for both models to finish.
    local attempts = 0
    local function AttachWhenLoaded()
        if request ~= s.mountPreviewRequest or mountActor ~= s.characterPreviewMountActor then
            return
        end

        attempts = attempts + 1
        local mountLoaded = not mountActor.IsLoaded or mountActor:IsLoaded()
        local playerLoaded = not playerActor.IsLoaded or playerActor:IsLoaded()
        if not mountLoaded or not playerLoaded then
            if attempts < 40 then
                UI_Transmog:ScheduleTimer(0.05, AttachWhenLoaded, "preview")
            else
                UI_Transmog:ClearMountPreview()
            end
            return
        end

        local scaleOK, scale = pcall(mountActor.CalculateMountScale, mountActor, playerActor)
        if not scaleOK or not scale or scale ~= scale or scale <= 0 or scale > 100 then
            UI_Transmog:ClearMountPreview()
            return
        end

        -- This mirrors Blizzard's Mount Journal. CalculateMountScale describes
        -- the relative rider size; the rider receives its inverse before being
        -- attached to the mount's seat point.
        if playerActor.SetRequestedScale then
            playerActor:SetRequestedScale(1 / scale)
        end
        if playerActor.GetSheathed and playerActor.SetSheathed then
            s.characterPreviewWasSheathed = playerActor:GetSheathed()
            -- Match the journal rider pose: weapons are hidden so their hold
            -- animations cannot override or distort the mounted idle stance.
            playerActor:SetSheathed(true, true)
        end
        local ok, result = pcall(mountActor.AttachToMount, mountActor, playerActor,
            animID or 0, spellVisualKitID)
        if not ok or result == false then
            UI_Transmog:ClearMountPreview()
            return
        end

        local camera = scene:GetActiveCamera()
        if camera and camera.GetZoomDistance and camera.SetZoomDistance then
            s.characterPreviewCameraZoom = camera:GetZoomDistance()
            s.characterPreviewCameraMinZoom = camera.GetMinZoomDistance
                and camera:GetMinZoomDistance() or nil
            s.characterPreviewCameraMaxZoom = camera.GetMaxZoomDistance
                and camera:GetMaxZoomDistance() or nil

            -- Orbit-camera distance grows as the camera moves away. The normal
            -- transmog camera's maximum is too tight for mounts, so expand it
            -- before setting a wider mounted distance.
            local mountedDistance = s.characterPreviewCameraZoom * 2.6
            if camera.SetMaxZoomDistance then
                camera:SetMaxZoomDistance(math.max(
                    s.characterPreviewCameraMaxZoom or mountedDistance,
                    mountedDistance))
            end
            camera:SetZoomDistance(mountedDistance)
            if camera.SnapAllInterpolatedValues then
                camera:SnapAllInterpolatedValues()
            elseif camera.SnapToTargetInterpolationZoom then
                camera:SnapToTargetInterpolationZoom()
            end
        end
    end

    AttachWhenLoaded()
end

-- Use the complete Blizzard mount scene rather than inserting a mount into the
-- transmog scene. Mount presets contain the matching camera, actor transform,
-- rider actor, seat attachment, and animation data as one coordinated unit.
function UI_Transmog:ClearMountPreview()
    self:CancelUITimers("preview")
    s.mountPreviewRequest = (s.mountPreviewRequest or 0) + 1

    if s.characterPreviewPetActor then
        s.characterPreviewPetActor:ClearModel()
    end
    s.previewPetGUID = nil

    local charPreview = TransmogFrame and TransmogFrame.CharacterPreview
    local sourceScene = charPreview and charPreview.ModelScene
    if sourceScene then
        sourceScene:Show()
        local playerActor = sourceScene.GetPlayerActor and sourceScene:GetPlayerActor()
        if playerActor and playerActor.SetRequestedScale then
            playerActor:SetRequestedScale(1)
        end
        if playerActor and playerActor.SetSheathed
            and s.characterPreviewWasSheathed ~= nil then
            playerActor:SetSheathed(s.characterPreviewWasSheathed, false)
        end
        local camera = sourceScene.GetActiveCamera
            and sourceScene:GetActiveCamera()
        if camera and s.characterPreviewCameraZoom
            and camera.SetZoomDistance then
            if s.characterPreviewCameraMaxZoom
                and camera.SetMaxZoomDistance then
                camera:SetMaxZoomDistance(s.characterPreviewCameraMaxZoom)
            end
            if s.characterPreviewCameraMinZoom
                and camera.SetMinZoomDistance then
                camera:SetMinZoomDistance(s.characterPreviewCameraMinZoom)
            end
            camera:SetZoomDistance(s.characterPreviewCameraZoom)
            if camera.SnapAllInterpolatedValues then
                camera:SnapAllInterpolatedValues()
            elseif camera.SnapToTargetInterpolationZoom then
                camera:SnapToTargetInterpolationZoom()
            end
        end
    end

    -- Clean up an actor left by the earlier in-scene implementation.
    if s.characterPreviewMountActor then
        s.characterPreviewMountActor:ClearModel()
    end

    if s.mountedCharacterScene then
        s.mountedCharacterScene:Hide()
        if s.mountedCharacterScene.ClearScene then
            s.mountedCharacterScene:ClearScene()
        end
    end

    s.characterPreviewCameraZoom = nil
    s.characterPreviewCameraMinZoom = nil
    s.characterPreviewCameraMaxZoom = nil
    s.characterPreviewWasSheathed = nil
    s.previewMountID = nil
end

function UI_Transmog:PreviewSelectedPet(petGUID, previewDisplayID, previewKey)
    if type(petGUID) ~= "string"
        and (type(previewDisplayID) ~= "number" or previewDisplayID == 0) then
        self:ClearMountPreview()
        return
    end

    local displayID = previewDisplayID
    if type(petGUID) == "string" then
        displayID = select(6, C_PetJournal.GetPetInfoByPetID(petGUID))
    end
    if not displayID or displayID == 0 then
        self:ClearMountPreview()
        return
    end

    self:ClearMountPreview()
    local request = s.mountPreviewRequest

    local scene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    local playerActor = scene and scene.GetPlayerActor and scene:GetPlayerActor()
    if not scene or not playerActor then return end

    local petActor = s.characterPreviewPetActor
    if not petActor then
        petActor = scene:CreateActor()
        s.characterPreviewPetActor = petActor
    end

    petActor:SetUseCenterForOrigin(false, false, false)
    petActor:SetPosition(0, 0, 0)
    petActor:SetYaw(0)
    petActor:SetPitch(0)
    petActor:SetRoll(0)
    petActor:SetScale(1)
    petActor:SetModelByCreatureDisplayID(displayID)

    local trackedPreviewKey = previewKey or petGUID
    local isHunterPreview = type(previewKey) == "string"
        and previewKey:find("^hunter:") ~= nil
    s.previewPetGUID = trackedPreviewKey

    -- Creature display IDs have wildly different native dimensions. Once both
    -- models are loaded, size the pet relative to the dressed player instead
    -- of applying one fixed scale to every species.
    local attempts = 0
    local function NormalizePetWhenLoaded()
        if request ~= s.mountPreviewRequest
            or s.previewPetGUID ~= trackedPreviewKey then
            return
        end

        attempts = attempts + 1
        local petLoaded = not petActor.IsLoaded or petActor:IsLoaded()
        local playerLoaded = not playerActor.IsLoaded or playerActor:IsLoaded()
        if not petLoaded or not playerLoaded then
            if attempts < 40 then
                UI_Transmog:ScheduleTimer(
                    0.05, NormalizePetWhenLoaded, "preview")
            end
            return
        end

        local petBottomX, petBottomY, petBottomZ,
            petTopX, petTopY, petTopZ =
            petActor:GetActiveBoundingBox()
        local playerBottomX, playerBottomY, playerBottomZ,
            playerTopX, playerTopY, playerTopZ =
            playerActor:GetActiveBoundingBox()
        local petHeight = petBottomZ and petTopZ and petTopZ - petBottomZ
        local playerHeight = playerBottomZ and playerTopZ
            and playerTopZ - playerBottomZ

        if not petHeight or petHeight <= 0
            or not playerHeight or playerHeight <= 0
            or not petBottomX or not petTopX
            or not petBottomY or not petTopY then
            petActor:SetScale(isHunterPreview and 0.14 or 0.08)
            return
        end

        local targetHeight = isHunterPreview and 0.38 or 0.22
        local scale = (playerHeight * targetHeight) / petHeight
        scale = math.max(0.015, math.min(scale,
            isHunterPreview and 0.55 or 0.35))
        local petCenterX = (petBottomX + petTopX) * 0.5
        -- Keep the pet slightly in front of the player's depth plane so wide
        -- models do not intersect with or disappear beneath the character.
        local petPositionX = -petCenterX * scale + playerHeight * 0.12
        -- Anchor the pet's visible right edge beside the character. Centering
        -- very wide models (crabs, crawlers, and hares with long effects)
        -- pushes their entire body too far toward the edge of the preview.
        local petPositionY
        if isHunterPreview and playerBottomY then
            -- Put the pet's nearest model-space edge beyond the player's edge
            -- with a proportional gap. Bounding-box placement prevents broad
            -- pets from intersecting the character despite their larger size.
            local gap = playerHeight * 0.08
            petPositionY = playerBottomY - gap - petTopY * scale
        else
            petPositionY = -1.8 - petTopY * scale
        end

        petActor:SetScale(scale)
        petActor:SetPosition(petPositionX, petPositionY, -petBottomZ * scale)
        if playerActor.GetYaw then
            petActor:SetYaw(playerActor:GetYaw())
        end

        if isHunterPreview then
            local camera = scene.GetActiveCamera and scene:GetActiveCamera()
            if camera and camera.GetZoomDistance and camera.SetZoomDistance then
                s.characterPreviewCameraZoom = camera:GetZoomDistance()
                s.characterPreviewCameraMinZoom = camera.GetMinZoomDistance
                    and camera:GetMinZoomDistance() or nil
                s.characterPreviewCameraMaxZoom = camera.GetMaxZoomDistance
                    and camera:GetMaxZoomDistance() or nil
                local playerWidth = playerBottomY and playerTopY
                    and math.max(playerTopY - playerBottomY, 0.01) or 1
                local petWidth = math.max((petTopY - petBottomY) * scale, 0)
                local zoomFactor = math.max(1.22,
                    math.min(1.65, (playerWidth + petWidth
                        + playerHeight * 0.08) / playerWidth * 0.9))
                local distance = s.characterPreviewCameraZoom * zoomFactor
                if camera.SetMaxZoomDistance then
                    camera:SetMaxZoomDistance(math.max(
                        s.characterPreviewCameraMaxZoom or distance, distance))
                end
                camera:SetZoomDistance(distance)
                if camera.SnapAllInterpolatedValues then
                    camera:SnapAllInterpolatedValues()
                elseif camera.SnapToTargetInterpolationZoom then
                    camera:SnapToTargetInterpolationZoom()
                end
            end
        end
    end
    NormalizePetWhenLoaded()
end

function UI_Transmog:PreviewSelectedMount(mountID)
    if type(mountID) ~= "number" then
        self:ClearMountPreview()
        return
    end

    local charPreview = TransmogFrame and TransmogFrame.CharacterPreview
    local sourceScene = charPreview and charPreview.ModelScene
    local sourcePlayer = sourceScene and sourceScene.GetPlayerActor
        and sourceScene:GetPlayerActor()
    if not sourceScene or not sourcePlayer then return end

    local displayID, _, _, isSelfMount, _, modelSceneID, animID,
        spellVisualKitID, disablePlayerMountPreview =
        C_MountJournal.GetMountInfoExtraByID(mountID)
    if not displayID or displayID == 0 then
        local displays = C_MountJournal.GetMountAllCreatureDisplayInfoByID(mountID)
        displayID = displays and displays[1] and displays[1].creatureDisplayID
    end
    if not displayID or not modelSceneID then
        self:ClearMountPreview()
        return
    end

    local outfitInfo = sourcePlayer.GetItemTransmogInfoList
        and sourcePlayer:GetItemTransmogInfoList()

    self:ClearMountPreview()
    local request = s.mountPreviewRequest

    local previewScene = s.mountedCharacterScene
    if not previewScene then
        previewScene = CreateFrame("ModelScene", nil, charPreview,
            "ModelSceneMixinTemplate")
        previewScene:SetAllPoints(sourceScene)
        previewScene:SetFrameLevel(sourceScene:GetFrameLevel())
        previewScene:EnableMouse(true)
        previewScene:EnableMouseWheel(true)
        s.mountedCharacterScene = previewScene
    end

    previewScene:TransitionToModelSceneID(modelSceneID,
        CAMERA_TRANSITION_TYPE_IMMEDIATE,
        CAMERA_MODIFICATION_TYPE_DISCARD, true)

    local mountActor = previewScene:GetActorByTag("unwrapped")
    if not mountActor then
        self:ClearMountPreview()
        return
    end
    mountActor:SetModelByCreatureDisplayID(displayID)
    if spellVisualKitID then mountActor:SetSpellVisualKit(spellVisualKitID) end

    -- Transformation mounts (for example, Sandstone Drake) replace the player
    -- instead of carrying a rider.  Their native mount-journal scene actor is
    -- therefore the complete preview; attaching a player would either fail or
    -- leave only the regular character visible.
    if isSelfMount or disablePlayerMountPreview then
        sourceScene:Hide()
        previewScene:Show()
        s.previewMountID = mountID
        return
    end

    -- This is Blizzard's own Mount Journal composition path. Unlike the old
    -- approach, it targets the preset's native player-rider actor.
    previewScene:AttachPlayerToMount(mountActor, animID or 0, false, false,
        spellVisualKitID, true)
    local riderActor = previewScene:GetPlayerActor("player-rider")
    if not riderActor then
        self:ClearMountPreview()
        return
    end

    sourceScene:Hide()
    previewScene:Show()
    s.previewMountID = mountID

    -- SetModelByUnit in AttachPlayerToMount is asynchronous. Once ready, copy
    -- the pending transmog choices from the hidden source actor onto the rider.
    local attempts = 0
    local function DressRiderWhenLoaded()
        if request ~= s.mountPreviewRequest or s.previewMountID ~= mountID then return end
        attempts = attempts + 1
        if riderActor.IsLoaded and not riderActor:IsLoaded() then
            if attempts < 40 then
                UI_Transmog:ScheduleTimer(
                    0.05, DressRiderWhenLoaded, "preview")
            end
            return
        end

        if outfitInfo and riderActor.SetItemTransmogInfo then
            for _, itemTransmogInfo in pairs(outfitInfo) do
                pcall(riderActor.SetItemTransmogInfo, riderActor, itemTransmogInfo)
            end
        end
        if riderActor.SetSheathed then riderActor:SetSheathed(true, true) end
    end
    DressRiderWhenLoaded()
end

function UI_Transmog:RefreshMountedOutfitPreview()
    if not s.previewMountID or not s.mountedCharacterScene then return end

    local sourceScene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    local sourcePlayer = sourceScene and sourceScene.GetPlayerActor
        and sourceScene:GetPlayerActor()
    local riderActor = s.mountedCharacterScene.GetPlayerActor
        and s.mountedCharacterScene:GetPlayerActor("player-rider")
    if not sourcePlayer or not riderActor then return end

    local outfitInfo = sourcePlayer.GetItemTransmogInfoList
        and sourcePlayer:GetItemTransmogInfoList()
    if not outfitInfo or not riderActor.SetItemTransmogInfo then return end

    for _, itemTransmogInfo in pairs(outfitInfo) do
        pcall(riderActor.SetItemTransmogInfo, riderActor, itemTransmogInfo)
    end
    if riderActor.SetSheathed then riderActor:SetSheathed(true, true) end
end
