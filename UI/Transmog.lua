

local addonName, ns = ...

local UI_Transmog = {}
ns.UI_Transmog = UI_Transmog

-- Shared mutable UI state. Cross-file consumers read/write via
-- ns.UI_Transmog._s once this file has been loaded.
local s = {}
UI_Transmog._s = s

local Fitter = ns.Fitter

function UI_Transmog:GetViewedOutfitID()
    local api = C_TransmogOutfitInfo
    return api and api.GetCurrentlyViewedOutfitID
        and api.GetCurrentlyViewedOutfitID() or nil
end

function UI_Transmog:GetActiveOutfitID()
    local api = C_TransmogOutfitInfo
    return api and api.GetActiveOutfitID and api.GetActiveOutfitID() or nil
end

function UI_Transmog:SetToyFrameShown(shown)
    if not s.toyFrame then return false end
    if InCombatLockdown() then
        s.toyFrameShownAfterCombat = shown == true
        return false
    end
    s.toyFrameShownAfterCombat = nil
    s.toyFrame:SetShown(shown == true)
    return true
end

function UI_Transmog:HideEmoteCreatePopup()
    if s.emoteCreatePopup then
        s.emoteCreatePopup:Hide()
    end
end

function UI_Transmog:HideTransientPopups()
    self:HideEmoteCreatePopup()
    if s.loadoutPopup then s.loadoutPopup:Hide() end
    if StaticPopup_Hide then
        StaticPopup_Hide("FITTER_APPLY_LOADOUT")
        StaticPopup_Hide("FITTER_DELETE_LOADOUT")
        StaticPopup_Hide("FITTER_RESET_CHARACTER_CONFIGURATION")
        StaticPopup_Hide("FITTER_RESET_OUTFIT_CONFIGURATION")
    end
end

s.uiTimers = {}

function UI_Transmog:ScheduleTimer(delay, callback, group)
    if not C_Timer or not C_Timer.NewTimer then return nil end
    local timer
    timer = C_Timer.NewTimer(delay, function()
        s.uiTimers[timer] = nil
        callback()
    end)
    s.uiTimers[timer] = group or true
    return timer
end

function UI_Transmog:CancelUITimers(group)
    for timer, timerGroup in pairs(s.uiTimers) do
        if not group or timerGroup == group then
            if timer and timer.Cancel then timer:Cancel() end
            s.uiTimers[timer] = nil
        end
    end
    if not group or group == "toy-retry" then s.toyRetryPending = false end
    if not group or group == "hearthstone-retry" then
        s.hearthstoneRetryPending = false
    end
end

function UI_Transmog:Cleanup()
    self:HideTransientPopups()
    GameTooltip:Hide()
    if self.StopEmotePreview then self:StopEmotePreview() end
    self:CancelUITimers()
    s.mountPreviewRequest = (s.mountPreviewRequest or 0) + 1
    s.hearthstonePreviewRequest = (s.hearthstonePreviewRequest or 0) + 1
    if self.ClearMountPreview then self:ClearMountPreview() end
    s.previewHearthstoneActive = nil
    for _, frames in ipairs({
        s.flyingModelFrames, s.groundModelFrames,
        s.aquaticModelFrames, s.petModelFrames,
        s.hearthstoneModelFrames,
    }) do
        for _, frame in ipairs(frames or {}) do
            frame.modelUpdateID = (frame.modelUpdateID or 0) + 1
            frame.mountData = nil
            frame.petGUID = nil
            frame.petIndex = nil
            frame.item = nil
            if frame.hoverHighlight then frame.hoverHighlight:Hide() end
            if frame.container and frame.container.HideCollectionHover then
                frame.container:HideCollectionHover()
            end
            if frame.model and frame.model.ClearModel then
                frame.model:ClearModel()
            elseif frame.model and frame.model.ClearScene then
                frame.model:ClearScene()
            end
        end
    end
    s.flyingPagedMounts = {}
    s.groundPagedMounts = {}
    s.aquaticPagedMounts = {}
    s.petPagedPets = {}
    s.hearthstonePagedItems = {}
    s.toyPagedItems = {}
    for _, card in ipairs(s.hunterPetCards or {}) do
        card.petInfo = nil
        if card.model and card.model.ClearModel then card.model:ClearModel() end
        if card.hoverHighlight then card.hoverHighlight:Hide() end
    end
    wipe(s.savedMountsScratch)
    wipe(s.mountListCache)
    if InCombatLockdown() then
        s.toyRefreshAfterCombat = true
    elseif s.toyButtons and self.UpdateToyPageDisplay then
        self:UpdateToyPageDisplay()
    end
end


s.mountSlotsRegistered = false 


s.flyingModelFrames = {}  
s.flyingPagedMounts = {}  
s.flyingCurrentPage = 1
s.flyingTotalPages = 1

s.groundModelFrames = {}  
s.groundPagedMounts = {}  
s.groundCurrentPage = 1
s.groundTotalPages = 1

s.aquaticModelFrames = {}  
s.aquaticPagedMounts = {}  
s.aquaticCurrentPage = 1
s.aquaticTotalPages = 1

s.petModelFrames = {}  
s.petPagedPets = {}  
s.petCurrentPage = 1
s.petTotalPages = 1
s.hearthstonePagedItems = {}
s.hearthstoneCurrentPage = 1
s.hearthstoneTotalPages = 1
s.toyPagedItems = {}
s.toyCurrentPage = 1
s.toyTotalPages = 1


s.additionalTabInitialized = false
s.zonesViewInitialized = false
s.emotesViewInitialized = false
s.flyingPagedInitialized = false
s.groundPagedInitialized = false
s.aquaticPagedInitialized = false
s.petPagedInitialized = false
s.hunterPetInitialized = false
s.hearthstonePagedInitialized = false
s.toyPagedInitialized = false
s.fitterPagedWasViewed = false
s.mountIconsInitialized = false
s.titleDropdownInitialized = false

s.mountListCache = {}
s.savedMountsScratch = {}

s.flyingSearchString = ""
s.groundSearchString = ""
s.aquaticSearchString = ""
s.petSearchString = ""
s.petHideDuplicateNames = true
s.hunterPetCheckedOnly = false
s.hunterPetShowActive = false
s.hunterPetShowStabled = false
s.flyingShowNotCollected = false
s.groundShowNotCollected = false
s.aquaticShowNotCollected = false
s.petShowNotCollected = false

s.hearthstoneSearchString = ""
s.toySearchString = ""
s.hearthstoneShowNotCollected = false
s.toyShowNotCollected = false
s.hearthstoneCheckedOnly = false
s.toyCheckedOnly = false
s.emoteCheckedOnly = false
s.emoteCustomOnly = false
s.additionalSearchString = ""
s.additionalCheckedOnly = false
s.zonesSelectedBiomes = {}    
s.zonesSelectedExpansions = {} 
s.zonesSelectedContinents = {}

s.flyingCheckedOnly = false
s.groundCheckedOnly = false
s.groundFilterFlying = false
s.groundFilterGround = false
s.aquaticCheckedOnly = false
s.petCheckedOnly = false
s.petSelectedFamilies = {}

s.flyingSelectedExpansions = {}
s.groundSelectedExpansions = {}
s.aquaticSelectedExpansions = {}
s.petSelectedExpansions = {}

-- Constants/data tables live in Data/. Aliased here so existing references
-- inside this file remain unchanged.
local MOUNT_EXPANSIONS = ns.Constants.MOUNT_EXPANSIONS
local PET_EXPANSIONS = ns.Constants.PET_EXPANSIONS
local PET_FAMILIES = ns.Constants.PET_FAMILIES
local GetMountExpansionKey = ns.Constants.GetMountExpansionKey
local GetPetExpansionKey = ns.Constants.GetPetExpansionKey


local MAJOR_ZONES = ns.Zones.MAJOR_ZONES
local BIOME_GROUPS = ns.Zones.BIOME_GROUPS
local EXPANSION_ZONES = ns.Zones.EXPANSION_ZONES

local SORTED_ZONES = {}
for _, zoneData in ipairs(MAJOR_ZONES) do
    table.insert(SORTED_ZONES, zoneData)
end
table.sort(SORTED_ZONES, function(a, b) return a.name < b.name end)

function UI_Transmog:InvalidateMountListCache()
    wipe(s.mountListCache)
end

function UI_Transmog:Initialize()
    if s.additionalFrame then
        return  
    end
    
    if not TransmogFrame or not TransmogFrame.WardrobeCollection then
        return
    end
    
    if TransmogFrame.WardrobeCollection.fitterAdditionalTabID then
        return
    end
    
    s.additionalFrame = CreateFrame("Frame", "FitterAdditionalFrame", TransmogFrame.WardrobeCollection.TabContent)
    s.additionalFrame:SetAllPoints(true)
    s.additionalFrame:Hide()

    s.zonesFrame = CreateFrame("Frame", "FitterZonesFrame",
        TransmogFrame.WardrobeCollection.TabContent)
    s.zonesFrame:SetAllPoints(true)
    s.zonesFrame:Hide()
    s.zonesFrame:EnableMouseWheel(true)
    s.zonesFrame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            UI_Transmog:ZonePagePrev()
        else
            UI_Transmog:ZonePageNext()
        end
    end)
    s.zonesFrame:SetScript("OnShow", function()
        s.fitterPagedWasViewed = true
        if not s.zonesViewInitialized then
            self:InitializeZonesView()
            s.zonesViewInitialized = true
        end
        self:RefreshZonesList()
    end)

    s.emotesFrame = CreateFrame("Frame", "FitterEmotesFrame",
        TransmogFrame.WardrobeCollection.TabContent)
    s.emotesFrame:SetAllPoints(true)
    s.emotesFrame:Hide()
    s.emotesFrame:EnableMouseWheel(true)
    s.emotesFrame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            UI_Transmog:EmotePagePrev()
        else
            UI_Transmog:EmotePageNext()
        end
    end)
    s.emotesFrame:SetScript("OnShow", function()
        s.fitterPagedWasViewed = true
        if not s.emotesViewInitialized then
            self:InitializeEmotesView()
            s.emotesViewInitialized = true
        end
        self:RefreshEmoteRows()
    end)
    s.emotesFrame:SetScript("OnHide", function()
        UI_Transmog:HideEmoteCreatePopup()
    end)
    
    s.flyingFrame = CreateFrame("Frame", "FitterFlyingFrame", TransmogFrame.WardrobeCollection.TabContent)
    s.flyingFrame:SetAllPoints(true)
    s.flyingFrame:Hide()
    s.flyingFrame:EnableMouseWheel(true)
    s.flyingFrame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            UI_Transmog:FlyingPagePrev()
        else
            UI_Transmog:FlyingPageNext()
        end
    end)
    s.flyingFrame:SetScript("OnShow", function()
        s.fitterPagedWasViewed = true
        if not s.flyingPagedInitialized then
            self:InitializeFlyingPaged()
            s.flyingPagedInitialized = true
        end
    end)
    
    s.groundFrame = CreateFrame("Frame", "FitterGroundFrame", TransmogFrame.WardrobeCollection.TabContent)
    s.groundFrame:SetAllPoints(true)
    s.groundFrame:Hide()
    s.groundFrame:EnableMouseWheel(true)
    s.groundFrame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            UI_Transmog:GroundPagePrev()
        else
            UI_Transmog:GroundPageNext()
        end
    end)
    s.groundFrame:SetScript("OnShow", function()
        s.fitterPagedWasViewed = true
        if not s.groundPagedInitialized then
            self:InitializeGroundPaged()
            s.groundPagedInitialized = true
        end
    end)
    
    s.aquaticFrame = CreateFrame("Frame", "FitterAquaticFrame", TransmogFrame.WardrobeCollection.TabContent)
    s.aquaticFrame:SetAllPoints(true)
    s.aquaticFrame:Hide()
    s.aquaticFrame:EnableMouseWheel(true)
    s.aquaticFrame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            UI_Transmog:AquaticPagePrev()
        else
            UI_Transmog:AquaticPageNext()
        end
    end)
    s.aquaticFrame:SetScript("OnShow", function()
        s.fitterPagedWasViewed = true
        if not s.aquaticPagedInitialized then
            self:InitializeAquaticPaged()
            s.aquaticPagedInitialized = true
        end
    end)
    
    s.petFrame = CreateFrame("Frame", "FitterPetFrame", TransmogFrame.WardrobeCollection.TabContent)
    s.petFrame:SetAllPoints(true)
    s.petFrame:Hide()
    s.petFrame:EnableMouseWheel(true)
    s.petFrame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            UI_Transmog:PetPagePrev()
        else
            UI_Transmog:PetPageNext()
        end
    end)
    s.petFrame:SetScript("OnShow", function()
        s.fitterPagedWasViewed = true
        if not s.petPagedInitialized then
            self:InitializePetPaged()
            s.petPagedInitialized = true
        end
    end)

    if ns.HunterPet and ns.HunterPet.IsAvailable() then
        s.hunterPetFrame = CreateFrame("Frame", "FitterHunterPetFrame",
            TransmogFrame.WardrobeCollection.TabContent)
        s.hunterPetFrame:SetAllPoints(true)
        s.hunterPetFrame:Hide()
        s.hunterPetFrame:EnableMouseWheel(true)
        s.hunterPetFrame:SetScript("OnMouseWheel", function(_, delta)
            if delta > 0 then
                UI_Transmog:HunterPetPagePrev()
            else
                UI_Transmog:HunterPetPageNext()
            end
        end)
        s.hunterPetFrame:SetScript("OnShow", function()
            s.fitterPagedWasViewed = true
            if not s.hunterPetInitialized then
                self:InitializeHunterPets()
                s.hunterPetInitialized = true
            end
            self:RefreshHunterPets()
        end)
    end

    local function CreateItemPagedFrame(name, pagePrev, pageNext, initialize, initializedField)
        local frame = CreateFrame("Frame", name, TransmogFrame.WardrobeCollection.TabContent)
        frame:SetAllPoints(true)
        frame:Hide()
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(_, delta)
            if delta > 0 then pagePrev(UI_Transmog) else pageNext(UI_Transmog) end
        end)
        frame:SetScript("OnShow", function()
            s.fitterPagedWasViewed = true
            if not s[initializedField] then
                s[initializedField] = initialize(UI_Transmog) ~= false
            end
        end)
        return frame
    end
    s.hearthstoneFrame = CreateItemPagedFrame("FitterHearthstoneFrame",
        UI_Transmog.HearthstonePagePrev, UI_Transmog.HearthstonePageNext,
        UI_Transmog.InitializeHearthstonePaged, "hearthstonePagedInitialized")
    s.toyFrame = CreateItemPagedFrame("FitterToyFrame",
        UI_Transmog.ToyPagePrev, UI_Transmog.ToyPageNext,
        UI_Transmog.InitializeToyPaged, "toyPagedInitialized")

    -- Toy entries own secure action overlays and therefore cannot be created
    -- or configured once combat lockdown begins.  Prepare the lazy page while
    -- the transmog UI is initialized so its existing catalogue remains
    -- available if combat starts before the user first visits it.
    if not InCombatLockdown() then
        s.toyPagedInitialized = self:InitializeToyPaged() ~= false
        if s.toyPagedInitialized then self:RefreshToyList() end
    end

    s.additionalFrame:SetScript("OnShow", function()
        if not s.additionalTabInitialized then
            self:InitializeAdditionalTab()
            s.additionalTabInitialized = true
        end
        if s.flyingFrame then s.flyingFrame:Hide() end
        if s.groundFrame then s.groundFrame:Hide() end
        if s.aquaticFrame then s.aquaticFrame:Hide() end
        if s.petFrame then s.petFrame:Hide() end
        if s.hunterPetFrame then s.hunterPetFrame:Hide() end
        if s.hearthstoneFrame then s.hearthstoneFrame:Hide() end
        UI_Transmog:SetToyFrameShown(false)
        if s.zonesFrame then s.zonesFrame:Hide() end
        if s.emotesFrame then s.emotesFrame:Hide() end
        if TransmogFrame and TransmogFrame.WardrobeCollection then
            local wc = TransmogFrame.WardrobeCollection
            if wc.TabContent and wc.TabContent.ItemsFrame then
                wc.TabContent.ItemsFrame:Hide()
            end
        end
    end)
    s.additionalFrame:SetScript("OnHide", function()
        if s.loadoutPopup then s.loadoutPopup:Hide() end
    end)
    
    TransmogFrame.WardrobeCollection.fitterAdditionalTabID =
        TransmogFrame.WardrobeCollection:AddNamedTab("Fitter", s.additionalFrame)
    

    local function HideAllPaged(keep)
        UI_Transmog:HideTransientPopups()
        UI_Transmog:CancelUITimers()
        if s.flyingFrame  and s.flyingFrame  ~= keep then s.flyingFrame:Hide()  end
        if s.groundFrame  and s.groundFrame  ~= keep then s.groundFrame:Hide()  end
        if s.aquaticFrame and s.aquaticFrame ~= keep then s.aquaticFrame:Hide() end
        if s.petFrame     and s.petFrame     ~= keep then s.petFrame:Hide()     end
        if s.hunterPetFrame and s.hunterPetFrame ~= keep then s.hunterPetFrame:Hide() end
        if s.hearthstoneFrame and s.hearthstoneFrame ~= keep then s.hearthstoneFrame:Hide() end
        if s.toyFrame ~= keep then UI_Transmog:SetToyFrameShown(false) end
        if s.zonesFrame and s.zonesFrame ~= keep then s.zonesFrame:Hide() end
        if s.emotesFrame and s.emotesFrame ~= keep then s.emotesFrame:Hide() end
    end

    -- Hook this tab owner, not TabSystemOwnerMixin itself.  The mixin is shared
    -- by unrelated Blizzard UI (including the damage meter); a global hook
    -- causes those callers to resume after addon code and taints comparisons
    -- against secret combat values.
    local wardrobeCollection = TransmogFrame.WardrobeCollection
    hooksecurefunc(wardrobeCollection, "SetTab", function(owner, tabID)
        local wc = owner
        local selectedSlotData = TransmogFrame.CharacterPreview
            and TransmogFrame.CharacterPreview.GetSelectedSlotData
            and TransmogFrame.CharacterPreview:GetSelectedSlotData()
        local pagedFrame = selectedSlotData and selectedSlotData.fitterPagedFrame or nil

        if tabID == wc.itemsTabID and pagedFrame then

            if wc.TabContent and wc.TabContent.ItemsFrame then
                wc.TabContent.ItemsFrame:Hide()
            end
            HideAllPaged(pagedFrame)
            pagedFrame:Show()
        else

            HideAllPaged(nil)
        end
    end)

    -- The wardrobe's tab system can show its registered content directly,
    -- without every transition going through TransmogWardrobeMixin:SetTab.
    -- Our paged views are siblings of those frames (they cannot be children of
    -- ItemsFrame because ItemsFrame is hidden while a Fitter page is open), so
    -- explicitly hide them whenever Blizzard shows a non-items tab.
    local tabContent = wardrobeCollection.TabContent
    for _, frame in ipairs({
        tabContent and tabContent.SetsFrame,
        tabContent and tabContent.CustomSetsFrame,
        tabContent and tabContent.SituationsFrame,
    }) do
        if frame then
            frame:HookScript("OnShow", function()
                HideAllPaged(nil)
            end)
        end
    end

    if TransmogFrame.WardrobeCollection.TabContent
        and TransmogFrame.WardrobeCollection.TabContent.ItemsFrame then
        TransmogFrame.WardrobeCollection.TabContent.ItemsFrame:HookScript("OnHide", function()
            local wc = TransmogFrame.WardrobeCollection
            local activeTab = TabSystemOwnerMixin.GetTab(wc)
            if activeTab ~= wc.itemsTabID then
                HideAllPaged(nil)
            end
        end)
    end
    

    hooksecurefunc(TransmogFrame, "SelectSlot", function()
        UI_Transmog:HideTransientPopups()

        local wc = TransmogFrame.WardrobeCollection
        if TabSystemOwnerMixin.GetTab(wc) == wc.itemsTabID then
            if wc.TabContent and wc.TabContent.ItemsFrame then
                wc.TabContent.ItemsFrame:Show()
            end
        end

        if s.flyingFrame then s.flyingFrame:Hide() end
        if s.groundFrame then s.groundFrame:Hide() end
        if s.aquaticFrame then s.aquaticFrame:Hide() end
        if s.petFrame then s.petFrame:Hide() end
        if s.hunterPetFrame then s.hunterPetFrame:Hide() end
        if s.hearthstoneFrame then s.hearthstoneFrame:Hide() end
        UI_Transmog:SetToyFrameShown(false)
        if s.zonesFrame then s.zonesFrame:Hide() end
        if s.emotesFrame then s.emotesFrame:Hide() end
        if s.additionalFrame then s.additionalFrame:Hide() end
    end)
    
    UI_Transmog:InitializeTitleDropdown()
    
    self:InitializeMountIcons()

    if self.CacheViewedZoneSituations then
        self:CacheViewedZoneSituations()
    end
    
    self:RefreshFeatureVisibility()

    TransmogFrame:HookScript("OnHide", function()
        UI_Transmog:Cleanup()

        if s.fitterPagedWasViewed then
            s.fitterPagedWasViewed = false
            UI_Transmog:ScheduleTimer(1, function()
                collectgarbage("collect")
            end)
        end
    end)
end

function UI_Transmog:RefreshFeatureVisibility()
    if s.zonesViewInitialized then
        if s.zonesSearchBox then s.zonesSearchBox:Show() end
        if s.zonesFilterDropdown then s.zonesFilterDropdown:Show() end
    end

    if TransmogFrame and TransmogFrame.WardrobeCollection and TransmogFrame.WardrobeCollection.fitterAdditionalTabID then
        local tabID = TransmogFrame.WardrobeCollection.fitterAdditionalTabID
        local tabButton = _G["WardrobeCollectionFrameTab"..tabID]
        if tabButton then
            tabButton:Show()
        end
    end
end

local macroIconButtonCount = 0
function UI_Transmog._CreateMacroIconButton(parent, iconFileID)
    macroIconButtonCount = macroIconButtonCount + 1
    local btn = CreateFrame("Button", "FitterMacroIconButton" .. macroIconButtonCount, parent)
    btn:SetSize(37, 37)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexture(iconFileID)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn.icon = icon

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    border:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    border:SetAllPoints(btn)
    btn.border = border

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    return btn
end

function UI_Transmog:RefreshActiveMountMacro(preferredMountID)
    if InCombatLockdown() then return end

    local currentOutfitID = self:GetViewedOutfitID()
    local activeOutfitID = self:GetActiveOutfitID()
    if not currentOutfitID or currentOutfitID ~= activeOutfitID then return end

    local playerClass = ns.state.playerClass
    if (FitterSaved and FitterSaved.UseDruidMacro and playerClass == "DRUID")
        or (FitterSaved and FitterSaved.UseShamanMacro and playerClass == "SHAMAN") then
        ns.state.nextMountToSummon = preferredMountID or ns.Mount.SelectNext(false, ns.state.currentZoneOutfitID)
        Fitter:UpdateMacroForCurrentState()
        return
    end

    local mountID = preferredMountID
    if mountID ~= nil then
        ns.state.nextMountToSummon = mountID
    else
        mountID = Fitter:SelectNextMount()
    end
    Fitter:UpdateMacroForMount(mountID)
end

function UI_Transmog:InitializeAdditionalTab()
    self:InitializeLoadouts()
end

function UI_Transmog:InitializeZonesView()
    self:InitializeZoneSection()
end

-- Removed inline section setup; lives in per-feature files now.

-- Exposed as a method (rather than file-local) so per-feature split modules
-- (Transmog_FlyingPaged.lua, etc.) can call it via UI_Transmog:_ShowPagedFrame.
function UI_Transmog:_ShowPagedFrame(target, updateMethod)
    self:HideTransientPopups()

    if TransmogFrame and TransmogFrame.WardrobeCollection then
        TransmogFrame.WardrobeCollection:SetToItemsTab()
        local tabContent = TransmogFrame.WardrobeCollection.TabContent
        if tabContent and tabContent.ItemsFrame then
            tabContent.ItemsFrame:Hide()
        end
    end
    if s.additionalFrame and s.additionalFrame ~= target then s.additionalFrame:Hide() end
    if s.flyingFrame     and s.flyingFrame     ~= target then s.flyingFrame:Hide()     end
    if s.groundFrame     and s.groundFrame     ~= target then s.groundFrame:Hide()     end
    if s.aquaticFrame    and s.aquaticFrame    ~= target then s.aquaticFrame:Hide()    end
    if s.petFrame        and s.petFrame        ~= target then s.petFrame:Hide()        end
    if s.hunterPetFrame and s.hunterPetFrame ~= target then s.hunterPetFrame:Hide() end
    if s.hearthstoneFrame and s.hearthstoneFrame ~= target then s.hearthstoneFrame:Hide() end
    if s.toyFrame ~= target then self:SetToyFrameShown(false) end
    if s.zonesFrame and s.zonesFrame ~= target then s.zonesFrame:Hide() end
    if s.emotesFrame and s.emotesFrame ~= target then s.emotesFrame:Hide() end
    if target then
        if target ~= s.toyFrame or self:SetToyFrameShown(true) then
            target:Show()
        end
        if updateMethod then self[updateMethod](self) end
    end
end

function UI_Transmog:ShowZones()
    if not s.zonesViewInitialized then
        self:InitializeZonesView()
        s.zonesViewInitialized = true
    end
    self:_ShowPagedFrame(s.zonesFrame, "RefreshZonesList")
end


