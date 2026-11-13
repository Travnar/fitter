-- The custom selector slots added to TransmogFrame.CharacterPreview:
-- Flying / Ground / Aquatic, Pet / Hearthstone / Toy, Zones, and Emotes.

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
local CONDITION_LOOKUPS = {}
for dataKey, items in pairs({
    Holidays = ns.Constants.HOLIDAYS,
    Activities = ns.Constants.ACTIVITIES,
}) do
    CONDITION_LOOKUPS[dataKey] = {}
    for _, item in ipairs(items) do
        CONDITION_LOOKUPS[dataKey][item.key] = item
    end
end

local function GetConditionsBaseIcon()
    if UnitFactionGroup("player") == "Horde" then
        return "Interface\\Icons\\inv_10_specialization_tailoring2_outfits_color1"
    end
    return "Interface\\Icons\\inv_10_specialization_tailoring2_outfits_color2"
end

local function GetConditionsIcon(data)
    local total, singleIcon = 0, nil
    for _, mapID in ipairs(data and data.Zones or {}) do
        total = total + 1
        singleIcon = ZONE_ICONS[mapID]
    end
    for dataKey, lookup in pairs(CONDITION_LOOKUPS) do
        for _, key in ipairs(data and data[dataKey] or {}) do
            total = total + 1
            singleIcon = lookup[key] and lookup[key].icon
        end
    end
    if total == 1 and type(singleIcon) == "string" and singleIcon ~= "" then
        return "Interface\\Icons\\" .. singleIcon, true
    end
    return GetConditionsBaseIcon(), total > 0
end

local function GetConditionNames(data, dataKey)
    local names = {}
    for _, id in ipairs(data and data[dataKey] or {}) do
        if dataKey == "Zones" then
            names[#names + 1] = ZONE_NAMES[id] or string.format(L["Zone %d"], id)
        else
            local item = CONDITION_LOOKUPS[dataKey][id]
            names[#names + 1] = item and item.name or tostring(id)
        end
    end
    table.sort(names)
    return names
end

local function GetAssignedEmotes(data)
    local assigned = {}
    for id, assignment in pairs(data and data.Emotes or {}) do
        local definition = ns.Emote.GetDefinition(id)
        if definition and ns.Emote.IsAssigned(assignment) then
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
    local data = ns.Settings.GetOutfitData(outfitID)
    local categoryIcon = (category == "Flying" and "Interface\\Icons\\ability_dragonriding_dragonridinggliding01")
        or (category == "Ground" and "Interface\\Icons\\ability_mount_ridinghorse")
        or (category == "Aquatic" and "Interface\\Icons\\item_aquaticfin_17")
        or 134400
    if not data then
        if category == "Hearthstone" then return 134414, false end
        if category == "Toy" then return 133015, false end
        if category == "Zones" then
            return GetConditionsBaseIcon(), false
        end
        if category == "Emotes" then
            return ns.Constants.EMOTE_CATEGORY_ICON, false
        end
        return categoryIcon, false
    end
    if category == "Zones" then
        return GetConditionsIcon(data)
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
        local hearthstones = ns.Settings.GetSelectedHearthstones(data)
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
        local data = ns.Settings.GetOutfitData(outfitID)
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
            local hearthstones = ns.Settings.GetSelectedHearthstones(data)
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
            GameTooltip:SetText(L["Conditions"], 1, 0.82, 0, 1, true)
            for _, dataKey in ipairs({ "Zones", "Holidays", "Activities" }) do
                local names = GetConditionNames(data, dataKey)
                if #names > 0 then
                    GameTooltip:AddLine(L[dataKey], 0.7, 0.7, 0.7)
                    for _, name in ipairs(names) do
                        GameTooltip:AddLine(name, 1, 1, 1)
                    end
                end
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
            and ns.Settings.GetOutfitData(outfitID)
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

-- SetupSlots releases every slot, Blizzard re-acquires its own, then our hook
-- acquires ours.  If the pool has to grow at that point it creates frames
-- inside our execution while TransmogFrame is open, which taints gamepad
-- SmartNavigation (see UI_Transmog._CreateDetachedFrame).  Grow it now,
-- before the frame is first shown, to cover Blizzard's slots plus ours.
local PREWARM_MARGIN = 8
local function PrewarmSlotPool(charPreview)
    local pool = charPreview.CharacterAppearanceSlotFramePool
    if not pool or TransmogFrame:IsShown() then return end
    local needed = PREWARM_MARGIN
    for _ in pairs(s.mountSlotDefs or {}) do needed = needed + 1 end
    local groups = C_TransmogOutfitInfo.GetSlotGroupInfo()
    if groups then
        for _, groupData in ipairs(groups) do
            needed = needed + #groupData.appearanceSlotInfo
        end
    else
        needed = needed + 24
    end
    local acquired = {}
    for i = 1, needed do
        acquired[i] = pool:Acquire()
    end
    for _, frame in ipairs(acquired) do
        pool:Release(frame)
    end
end

local function RebuildMountSlots()
    local charPreview = TransmogFrame and TransmogFrame.CharacterPreview
    if not charPreview or not s.mountSlotDefs then return end
    if s.mountSlotDefs.Flying then
        s.flyingSlotFrame = AcquireMountSlot(charPreview, s.mountSlotDefs.Flying)
    end
    s.groundSlotFrame  = AcquireMountSlot(charPreview, s.mountSlotDefs.Ground)
    if s.mountSlotDefs.Aquatic then
        s.aquaticSlotFrame = AcquireMountSlot(charPreview, s.mountSlotDefs.Aquatic)
    end
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
    PrewarmPool          = PrewarmSlotPool,
}
