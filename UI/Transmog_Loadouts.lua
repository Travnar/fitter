-- Saved snapshots of all Fitter configuration attached to an outfit.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
        result[Copy(key, seen)] = Copy(child, seen)
    end
    return result
end

local function CurrentOutfit(create)
    local id = UI_Transmog:GetViewedOutfitID()
    if not id or id == 0 then return nil end
    if create then Fitter:CreateEmptyOutfit(id) end
    return FitterCharacterSaved and FitterCharacterSaved["Outfit" .. id], id
end

local function LoadoutStores()
    FitterSaved = FitterSaved or {}
    FitterCharacterSaved = FitterCharacterSaved or {}
    FitterSaved.Loadouts = FitterSaved.Loadouts or {}
    FitterCharacterSaved.Loadouts = FitterCharacterSaved.Loadouts or {}
    return FitterCharacterSaved.Loadouts, FitterSaved.Loadouts
end

local function IsMountAvailable(mountID)
    if type(mountID) ~= "number" or not C_MountJournal then return false end
    local name, _, _, _, _, _, _, _, _, shouldHideOnChar, isCollected =
        C_MountJournal.GetMountInfoByID(mountID)
    return name ~= nil and isCollected == true and shouldHideOnChar ~= true
end

local function IsPetAvailable(petGUID)
    return type(petGUID) == "string" and C_PetJournal
        and C_PetJournal.PetIsSummonable(petGUID) == true
end

local hearthstoneRules = {}
for _, entry in ipairs(ns.Constants.KNOWN_HEARTHSTONES or {}) do
    hearthstoneRules[entry.id] = entry
end

local function IsHearthstoneAvailable(itemID)
    local rule = hearthstoneRules[itemID]
    if rule and rule.race and rule.race ~= ns.state.playerRace then return false end
    if rule and rule.baseItem then
        return C_Item.GetItemCount(itemID, false, false, false) > 0
    end
    return PlayerHasToy(itemID) == true
end

local function FilterList(source, predicate)
    local result = {}
    for _, value in ipairs(type(source) == "table" and source or {}) do
        if predicate(value) then result[#result + 1] = value end
    end
    return result
end

local function ZoneUsedByAnotherOutfit(mapID, currentID)
    for key, data in pairs(FitterCharacterSaved or {}) do
        local outfitID = type(key) == "string"
            and tonumber(key:match("^Outfit(%d+)$"))
        if outfitID and outfitID ~= currentID and type(data) == "table"
            and type(data.Zones) == "table" and tContains(data.Zones, mapID) then
            return true
        end
    end
    return false
end

local zoneNames = {}
for _, zone in ipairs(ns.Constants.MAJOR_ZONES or {}) do
    zoneNames[zone.mapID] = zone.name
end

local function SummarizeNames(values, getName)
    local names = {}
    for _, value in ipairs(type(values) == "table" and values or {}) do
        names[#names + 1] = getName(value) or ("ID " .. tostring(value))
    end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    local shown = {}
    for index = 1, math.min(#names, 6) do shown[index] = names[index] end
    local text = table.concat(shown, ", ")
    if text == "" then return "|cff888888None|r" end
    if #names > #shown then
        text = text .. string.format(" |cff888888(+%d more)|r",
            #names - #shown)
    end
    return text
end

local function AddTooltipSetting(label, value)
    if value and value ~= "" then
        GameTooltip:AddDoubleLine(label, value, 1, 0.82, 0,
            0.92, 0.92, 0.92)
    end
end

local function MountSummary(data, key)
    if data[key .. "NoMount"] then return "|cffff8080No Mount|r" end
    if data[key .. "Random"] then return "Random" end
    return SummarizeNames(data[key], function(mountID)
        return C_MountJournal and C_MountJournal.GetMountInfoByID(mountID)
    end)
end

local function PetName(petGUID)
    if not C_PetJournal or not C_PetJournal.GetPetInfoByPetID then return end
    local _, customName, _, _, _, _, _, speciesName =
        C_PetJournal.GetPetInfoByPetID(petGUID)
    return customName or speciesName
end

local function ItemName(itemID)
    local name = C_Item and C_Item.GetItemNameByID(itemID)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
    return name
end

local function EmoteSummary(emotes)
    local selected, catalogNames = {}, {}
    for _, item in ipairs(ns.Emote.GetCatalog()) do
        catalogNames[item.id] = item.name
    end
    for id, assignment in pairs(type(emotes) == "table" and emotes or {}) do
        if type(assignment) == "table"
            and type(assignment.conditions) == "table"
            and next(assignment.conditions) then
            selected[#selected + 1] = catalogNames[id] or tostring(id)
        end
    end
    return SummarizeNames(selected, function(name) return name end)
end

local function ShowLoadoutTooltip(owner, elementData)
    local loadout = elementData and elementData.loadout
    local data = loadout and loadout.data
    if type(data) ~= "table" then return end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(loadout.name or L["Unnamed Loadout"], 1, 0.82, 0)
    GameTooltip:AddLine(elementData.scope == "character"
        and L["Character Loadout"] or L["Account Wide Loadout"],
        0.65, 0.65, 0.65)
    GameTooltip:AddLine(" ")

    AddTooltipSetting(L["Flying"], MountSummary(data, "Flying"))
    AddTooltipSetting(L["Ground"], MountSummary(data, "Ground"))
    AddTooltipSetting(L["Aquatic"], MountSummary(data, "Aquatic"))

    local pets
    if data.PetNoPet then
        pets = "|cffff8080" .. L["No Pet"] .. "|r"
    elseif data.PetRandom then
        pets = L["Random"]
    else
        pets = SummarizeNames(data.Pets, PetName)
    end
    AddTooltipSetting(L["Pets"], pets)
    AddTooltipSetting(L["Hearthstones"],
        SummarizeNames(data.Hearthstones, ItemName))
    AddTooltipSetting(L["Toys"], SummarizeNames(data.Toys, ItemName))
    AddTooltipSetting(L["Zones"], SummarizeNames(data.Zones, function(mapID)
        return zoneNames[mapID]
    end))

    local title
    if data.Title == nil or data.Title == -1 then
        title = "|cff888888" .. L["Ignore Title"] .. "|r"
    elseif data.Title == 0 then
        title = UnitName("player") or L["Character"]
    else
        title = GetTitleName(data.Title)
            or ("ID " .. tostring(data.Title))
    end
    AddTooltipSetting(L["Title"], title)
    AddTooltipSetting(L["Emotes"], EmoteSummary(data.Emotes))
    GameTooltip:Show()
end

local function ApplyLoadout(loadout)
    local destination, outfitID = CurrentOutfit(true)
    local source = loadout and loadout.data
    if not destination or type(source) ~= "table" then
        UIErrorsFrame:AddMessage("Select an outfit before applying a loadout.",
            1, 0.2, 0.2)
        return
    end

    local oldZones = Copy(destination.Zones or {})
    local oldSituationBaseline = Copy(destination.SituationBaseline)
    local applied = Copy(source)
    applied.Flying = FilterList(source.Flying, IsMountAvailable)
    applied.Ground = FilterList(source.Ground, IsMountAvailable)
    applied.Aquatic = FilterList(source.Aquatic, IsMountAvailable)
    applied.Pets = FilterList(source.Pets, IsPetAvailable)
    local availablePets = {}
    for _, petGUID in ipairs(applied.Pets) do availablePets[petGUID] = true end
    applied.PetSummonTriggers = applied.PetSummonTriggers or {}
    for petGUID in pairs(applied.PetSummonTriggers) do
        if not availablePets[petGUID] then
            applied.PetSummonTriggers[petGUID] = nil
        end
    end
    applied.Hearthstones = FilterList(source.Hearthstones, IsHearthstoneAvailable)
    applied.Toys = FilterList(source.Toys, function(id)
        return type(id) == "number" and PlayerHasToy(id) == true
    end)
    applied.Zones = FilterList(source.Zones, function(mapID)
        return not ZoneUsedByAnotherOutfit(mapID, outfitID)
    end)
    applied.SituationBaseline = nil

    wipe(destination)
    for key, value in pairs(applied) do destination[key] = value end
    destination.SituationBaseline = oldSituationBaseline

    for _, mapID in ipairs(oldZones) do
        if not tContains(applied.Zones, mapID)
            and UI_Transmog.TryDisableZoneSituation then
            UI_Transmog:TryDisableZoneSituation(mapID, outfitID)
        end
    end
    if UI_Transmog.UpdateZoneSituation then
        for _, mapID in ipairs(applied.Zones) do
            if not tContains(oldZones, mapID) then
                UI_Transmog:UpdateZoneSituation(mapID, true)
            end
        end
    end

    UI_Transmog:UpdateMountIcons()
    UI_Transmog:UpdateTitleDropdown()
    if UI_Transmog.RefreshEmoteRows then UI_Transmog:RefreshEmoteRows() end
    if Fitter.RefreshZoneCache then Fitter:RefreshZoneCache() end
    Fitter:RefreshFeatureEvents()
    if UI_Transmog:GetActiveOutfitID() == outfitID
        and not InCombatLockdown() then
        Fitter:UpdatePet()
        Fitter:UpdateMacroForCurrentState()
        Fitter:UpdateHearthstoneMacro()
        Fitter:UpdateOutfitUpdateMacro()
    end
    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    s.selectedApplyLoadoutElement = nil
    UI_Transmog:RefreshLoadouts()
end

local function CreateLoadoutPopup()
    if s.loadoutPopup then return s.loadoutPopup end
    local popup = CreateFrame("Frame", "FitterNewLoadoutPopup", UIParent,
        "PortraitFrameTemplate")
    popup:SetSize(400, 220)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:Hide()
    popup:SetTitle("Save Loadout")

    local portrait = popup.Portrait
        or (popup.PortraitContainer and popup.PortraitContainer.portrait)
    if portrait then portrait:SetTexture("Interface\\Icons\\INV_Misc_Note_05") end

    local nameLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", 30, -62)
    nameLabel:SetText(L["Name"])

    local nameEdit = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    nameEdit:SetSize(330, 30)
    nameEdit:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 5, -7)
    nameEdit:SetAutoFocus(false)
    nameEdit:SetMaxLetters(80)
    popup.nameEdit = nameEdit

    local scopeLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    scopeLabel:SetPoint("TOPLEFT", nameEdit, "BOTTOMLEFT", -5, -18)
    scopeLabel:SetText(L["Save for"])

    local scope = CreateFrame("DropdownButton", nil, popup,
        "WowStyle1DropdownTemplate")
    scope:SetSize(175, 30)
    scope:SetPoint("LEFT", scopeLabel, "RIGHT", 12, 0)
    scope.value = "character"
    scope:SetDefaultText("Character")
    scope:SetupMenu(function(_, root)
        root:CreateRadio(L["Character"], function()
            return scope.value == "character"
        end, function()
            scope.value = "character"
            scope:SetDefaultText("Character")
        end)
        root:CreateRadio(L["Account Wide"], function()
            return scope.value == "account"
        end, function()
            scope.value = "account"
            scope:SetDefaultText("Account Wide")
        end)
    end)
    popup.scope = scope

    local cancel = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    cancel:SetSize(90, 24)
    cancel:SetPoint("BOTTOMRIGHT", -24, 20)
    cancel:SetText(L["Cancel"])
    cancel:SetScript("OnClick", function() popup:Hide() end)

    local save = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    save:SetSize(90, 24)
    save:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
    save:SetText(L["Save"])
    save:SetScript("OnClick", function()
        local name = nameEdit:GetText():match("^%s*(.-)%s*$")
        local data = CurrentOutfit(false)
        if name == "" then
            UIErrorsFrame:AddMessage("Enter a loadout name.", 1, 0.2, 0.2)
            return
        end
        if not data then
            UIErrorsFrame:AddMessage("Select an outfit before saving a loadout.",
                1, 0.2, 0.2)
            return
        end
        local character, account = LoadoutStores()
        local store = scope.value == "account" and account or character
        store[#store + 1] = {
            id = string.format("%s:%d:%d", scope.value, GetServerTime(),
                math.random(1000000)),
            name = name,
            data = Copy(data),
        }
        popup:Hide()
        UI_Transmog:RefreshLoadouts()
        PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
    end)
    nameEdit:SetScript("OnEnterPressed", function() save:Click() end)
    nameEdit:SetScript("OnEscapePressed", function() popup:Hide() end)
    s.loadoutPopup = popup
    return popup
end

local function ShowCreatePopup()
    if not CurrentOutfit(false) then
        UIErrorsFrame:AddMessage("Select an outfit before saving a loadout.",
            1, 0.2, 0.2)
        return
    end
    local popup = CreateLoadoutPopup()
    popup.nameEdit:SetText("")
    popup.scope.value = "character"
    popup.scope:SetDefaultText("Character")
    popup:Show()
    popup.nameEdit:SetFocus()
end

local function RemoveLoadout(elementData)
    local character, account = LoadoutStores()
    local store = elementData.scope == "account" and account or character
    for index, loadout in ipairs(store) do
        if loadout.id == elementData.loadout.id then
            table.remove(store, index)
            break
        end
    end
    s.selectedDeleteLoadoutElement = nil
    UI_Transmog:RefreshLoadouts()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

StaticPopupDialogs["FITTER_APPLY_LOADOUT"] = {
    text = L["Apply the loadout |cffffd200%s|r to the currently selected outfit?\n\nThis will replace its current Fitter configuration."],
    button1 = L["Apply"],
    button2 = L["Cancel"],
    OnAccept = function(_, data)
        if data and data.loadout then ApplyLoadout(data.loadout) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["FITTER_DELETE_LOADOUT"] = {
    text = L["Delete the loadout |cffffd200%s|r?\n\nThis cannot be undone."],
    button1 = L["Delete"],
    button2 = L["Cancel"],
    OnAccept = function(_, data)
        if data and data.loadout then RemoveLoadout(data) end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
}

local function ConfirmApplyLoadout(elementData)
    StaticPopup_Show("FITTER_APPLY_LOADOUT",
        elementData.loadout.name or L["Unnamed"], nil, elementData)
end

local function ConfirmDeleteLoadout(elementData)
    StaticPopup_Show("FITTER_DELETE_LOADOUT",
        elementData.loadout.name or L["Unnamed"], nil, elementData)
end

local function RefreshAfterConfigurationReset()
    UI_Transmog:UpdateTitleDropdown()
    UI_Transmog:UpdateMountIcons()
    if UI_Transmog.RefreshEmoteRows then UI_Transmog:RefreshEmoteRows() end
    if Fitter.RefreshZoneCache then Fitter:RefreshZoneCache() end
    Fitter:RefreshFeatureEvents()
    if not InCombatLockdown() then
        Fitter:UpdateTitle()
        Fitter:UpdatePet()
        Fitter:UpdateMacroForCurrentState()
        Fitter:UpdateHearthstoneMacro()
        Fitter:UpdateOutfitUpdateMacro()
    end
    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
end

local function ResetCharacterConfiguration()
    FitterCharacterSaved = FitterCharacterSaved or {}
    local outfitKeys = {}
    for key in pairs(FitterCharacterSaved) do
        if type(key) == "string" and key:match("^Outfit%d+$") then
            outfitKeys[#outfitKeys + 1] = key
        end
    end
    for _, key in ipairs(outfitKeys) do FitterCharacterSaved[key] = nil end

    if C_TransmogOutfitInfo then
        for _, info in ipairs(C_TransmogOutfitInfo.GetOutfitsInfo() or {}) do
            Fitter:CreateEmptyOutfit(info.outfitID)
        end
    end

    RefreshAfterConfigurationReset()
end

local function ResetOutfitConfiguration(_, outfitID)
    if not outfitID then return end
    FitterCharacterSaved = FitterCharacterSaved or {}
    FitterCharacterSaved["Outfit" .. outfitID] = nil
    Fitter:CreateEmptyOutfit(outfitID)
    RefreshAfterConfigurationReset()
end

StaticPopupDialogs["FITTER_RESET_CHARACTER_CONFIGURATION"] = {
    text = L["Reset all Fitter outfit configurations for this character?\n\nSaved loadouts and custom emotes will be preserved. This cannot be undone."],
    button1 = L["Reset"],
    button2 = L["Cancel"],
    OnAccept = ResetCharacterConfiguration,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
}

StaticPopupDialogs["FITTER_RESET_OUTFIT_CONFIGURATION"] = {
    text = L["Reset the Fitter configuration for |cffffd200%s|r?\n\nThis cannot be undone."],
    button1 = L["Reset"],
    button2 = L["Cancel"],
    OnAccept = ResetOutfitConfiguration,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
    preferredIndex = 3,
}

local function ConfirmResetOutfitConfiguration()
    local _, outfitID = CurrentOutfit(false)
    if not outfitID then
        UIErrorsFrame:AddMessage(
            "Select an outfit before resetting its configuration.",
            1, 0.2, 0.2)
        return
    end
    local name = "Outfit " .. outfitID
    for _, info in ipairs(C_TransmogOutfitInfo.GetOutfitsInfo() or {}) do
        if info.outfitID == outfitID then
            name = info.name or name
            break
        end
    end
    StaticPopup_Show("FITTER_RESET_OUTFIT_CONFIGURATION",
        name, nil, outfitID)
end

local function BuildLoadoutElements()
    local character, account = LoadoutStores()
    local elements = {}
    local function AddSorted(store, scope)
        local sorted = {}
        for _, loadout in ipairs(store) do sorted[#sorted + 1] = loadout end
        table.sort(sorted, function(a, b)
            return (a.name or ""):lower() < (b.name or ""):lower()
        end)
        for _, loadout in ipairs(sorted) do
            elements[#elements + 1] = {loadout = loadout, scope = scope}
        end
    end
    AddSorted(character, "character")
    if #character > 0 and #account > 0 then
        elements[#elements + 1] = {divider = true}
    end
    AddSorted(account, "account")
    return elements
end

function UI_Transmog:RefreshLoadouts()
    if not s.loadoutApplyDropdown then return end
    local function RefreshSelection(stateKey, dropdown)
        local selected = s[stateKey]
        if selected then
            local stillExists = false
            for _, element in ipairs(BuildLoadoutElements()) do
                if not element.divider
                    and element.loadout.id == selected.loadout.id
                    and element.scope == selected.scope then
                    s[stateKey] = element
                    selected = element
                    stillExists = true
                    break
                end
            end
            if not stillExists then
                s[stateKey] = nil
                selected = nil
            end
        end
        dropdown:OverrideText(selected
            and (selected.loadout.name or "Unnamed") or "Select a loadout")
    end
    RefreshSelection("selectedApplyLoadoutElement", s.loadoutApplyDropdown)
    RefreshSelection("selectedDeleteLoadoutElement", s.loadoutDeleteDropdown)
end

local function PopulateLoadoutMenu(root, stateKey, onSelect)
    local elements = BuildLoadoutElements()
    local hasCharacter, hasAccount = false, false
    for _, element in ipairs(elements) do
        if not element.divider then
            if element.scope == "character" and not hasCharacter then
                root:CreateTitle("Character")
                hasCharacter = true
            elseif element.scope == "account" and not hasAccount then
                if hasCharacter then root:CreateDivider() end
                root:CreateTitle("Account Wide")
                hasAccount = true
            end
            local choice = element
            root:CreateRadio(choice.loadout.name or L["Unnamed"], function()
                return s[stateKey]
                    and s[stateKey].loadout.id == choice.loadout.id
                    and s[stateKey].scope == choice.scope
            end, function()
                s[stateKey] = choice
                UI_Transmog:RefreshLoadouts()
                onSelect(choice)
            end)
        end
    end
    if not hasCharacter and not hasAccount then
        root:CreateTitle("No loadouts saved")
    end
end

local function AddLoadoutDropdownTooltip(dropdown, stateKey)
    dropdown:HookScript("OnEnter", function(self)
        if s[stateKey] then ShowLoadoutTooltip(self, s[stateKey]) end
    end)
    dropdown:HookScript("OnLeave", GameTooltip_Hide)
end

function UI_Transmog:InitializeLoadouts()
    if s.loadoutApplyDropdown then
        self:RefreshLoadouts()
        return
    end
    local parent = s.additionalFrame
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetFont("Fonts\\FRIZQT__.TTF", 22, "")
    title:SetShadowColor(0, 0, 0, 0.8)
    title:SetShadowOffset(1, -1)
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 50, -65)
    title:SetText("Fitter")
    title:SetTextColor(1, 1, 1, 1)

    local separator = parent:CreateTexture(nil, "ARTWORK")
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", parent, "TOPLEFT", 50, -97)
    separator:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -50, -97)
    separator:SetColorTexture(0.4, 0.4, 0.4, 0.8)

    local generalSection = parent:CreateFontString(nil, "OVERLAY",
        "GameFontNormalLarge")
    generalSection:SetPoint("TOPLEFT", parent, "TOPLEFT", 66, -120)
    generalSection:SetTextColor(1, 1, 1, 1)
    generalSection:SetText(L["General"])

    local function CreateResetRow(label, y, onClick)
        local row = CreateFrame("Frame", nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, y)
        row:SetPoint("RIGHT", parent, "RIGHT", -70, 0)
        row:SetHeight(26)
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT")
        text:SetText(label)
        local button =
            CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        button:SetSize(80, 22)
        button:SetPoint("RIGHT")
        button:SetText(L["Reset"])
        button:SetScript("OnClick", onClick)
        return row
    end

    CreateResetRow("Reset Character Configuration", -157, function()
        StaticPopup_Show("FITTER_RESET_CHARACTER_CONFIGURATION")
    end)

    local outfitsSection = parent:CreateFontString(nil, "OVERLAY",
        "GameFontNormalLarge")
    outfitsSection:SetPoint("TOPLEFT", parent, "TOPLEFT", 66, -205)
    outfitsSection:SetTextColor(1, 1, 1, 1)
    outfitsSection:SetText(L["Outfits"])

    CreateResetRow("Reset Outfit Configuration", -243,
        ConfirmResetOutfitConfiguration)

    local section = parent:CreateFontString(nil, "OVERLAY",
        "GameFontNormalLarge")
    section:SetPoint("TOPLEFT", parent, "TOPLEFT", 66, -290)
    section:SetTextColor(1, 1, 1, 1)
    section:SetText(L["Loadouts"])

    local addLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    addLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, -328)
    addLabel:SetText(L["Add New Loadout"])

    local add = CreateFrame("Button", nil, parent)
    add:SetSize(32, 32)
    add:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -70, -319)
    local addIcon = add:CreateTexture(nil, "ARTWORK")
    addIcon:SetPoint("CENTER")
    addIcon:SetAtlas("128-redbutton-plus", true)
    addIcon:SetSize(32, 32)
    add.icon = addIcon
    local addHighlight = add:CreateTexture(nil, "HIGHLIGHT")
    addHighlight:SetAllPoints(addIcon)
    addHighlight:SetAtlas("128-redbutton-plus", true)
    addHighlight:SetBlendMode("ADD")
    addHighlight:SetAlpha(0.25)
    add:SetScript("OnMouseDown", function(self)
        self.icon:SetAtlas("128-redbutton-plus-pressed", true)
        self.icon:SetSize(32, 32)
    end)
    add:SetScript("OnMouseUp", function(self)
        self.icon:SetAtlas("128-redbutton-plus", true)
        self.icon:SetSize(32, 32)
    end)
    add:SetScript("OnClick", ShowCreatePopup)
    add:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Save Loadout"])
        GameTooltip:AddLine(L["Save all Fitter settings from the selected outfit."],
            1, 1, 1, true)
        GameTooltip:Show()
    end)
    add:SetScript("OnLeave", GameTooltip_Hide)

    local applyLabel =
        parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    applyLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, -371)
    applyLabel:SetText(L["Apply Loadout"])

    local applyDropdown = CreateFrame("DropdownButton", nil, parent,
        "WowStyle1DropdownTemplate")
    applyDropdown:SetSize(220, 30)
    applyDropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -70, -362)
    applyDropdown:SetDefaultText("Select a loadout")
    applyDropdown:SetupMenu(function(_, root)
        PopulateLoadoutMenu(root, "selectedApplyLoadoutElement",
            ConfirmApplyLoadout)
    end)
    AddLoadoutDropdownTooltip(
        applyDropdown, "selectedApplyLoadoutElement")
    s.loadoutApplyDropdown = applyDropdown

    local deleteLabel =
        parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    deleteLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, -408)
    deleteLabel:SetText(L["Delete Loadout"])

    local deleteDropdown = CreateFrame("DropdownButton", nil, parent,
        "WowStyle1DropdownTemplate")
    deleteDropdown:SetSize(220, 30)
    deleteDropdown:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -70, -399)
    deleteDropdown:SetDefaultText("Select a loadout")
    deleteDropdown:SetupMenu(function(_, root)
        PopulateLoadoutMenu(root, "selectedDeleteLoadoutElement",
            ConfirmDeleteLoadout)
    end)
    AddLoadoutDropdownTooltip(
        deleteDropdown, "selectedDeleteLoadoutElement")
    s.loadoutDeleteDropdown = deleteDropdown

    self:RefreshLoadouts()
end
