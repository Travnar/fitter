-- Transmog_Titles.lua
-- Player-title dropdown attached to the Wardrobe character preview.
-- Split out of UI_Transmog.lua. Shares state via UI_Transmog._s.

local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter

local IGNORE_TITLE_LABEL = "|cff888888" .. L["Ignore Title"] .. "|r"

local function CreateDisplayTitle(titleID)
    if titleID == nil or titleID == -1 then
        return IGNORE_TITLE_LABEL
    end
    if titleID == 0 then
        return UnitName("player")
    end

    local titleName = GetTitleName(titleID)
    if not titleName then
        return UnitName("player")
    end

    local playerName = UnitName("player")

    if titleName:sub(-1) == " " then
        return titleName .. playerName
    else
        return playerName .. " " .. titleName
    end
end

local function SetSelectedTitle(titleID)
    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if not outfitID or not FitterCharacterSaved["Outfit"..outfitID] then
        return
    end

    FitterCharacterSaved["Outfit"..outfitID].Title = titleID

    if s.titleDropdown then
        s.titleDropdown:SetDefaultText(CreateDisplayTitle(titleID))
    end

    local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    if activeOutfitID and activeOutfitID == outfitID then
        Fitter:UpdateTitle()
    end

    PlaySound(SOUNDKIT.UI_TRANSMOG_ITEM_CLICK)
end

function UI_Transmog:InitializeTitleDropdown()
    if s.titleDropdownInitialized or not TransmogFrame or not TransmogFrame.CharacterPreview then
        return
    end

    s.titleDropdown = CreateFrame("DropdownButton", nil, TransmogFrame.CharacterPreview, "WowStyle1DropdownTemplate")


    local function GetViewedSavedTitle()
        local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
        if outfitID and FitterCharacterSaved and FitterCharacterSaved["Outfit"..outfitID] then
            return FitterCharacterSaved["Outfit"..outfitID].Title
        end
        return nil
    end

    local function IsIgnoreTitleSelected(_value)
        local saved = GetViewedSavedTitle()
        return saved == nil or saved == -1
    end

    local function IsTitleSelected(titleID)
        return GetViewedSavedTitle() == titleID
    end

    local function GeneratorFunctionTitles(dropdown, rootDescription)
        rootDescription:CreateRadio(IGNORE_TITLE_LABEL, IsIgnoreTitleSelected, SetSelectedTitle, -1)
        rootDescription:CreateRadio(UnitName("player"), IsTitleSelected, SetSelectedTitle, 0)

        local titlesRaw = {}
        local count = 1

        for i = 1, GetNumTitles() do
            if IsTitleKnown(i) then
                titlesRaw[count] = {}
                titlesRaw[count].id = i
                titlesRaw[count].name = CreateDisplayTitle(i)
                count = count + 1
            end
        end

        table.sort(titlesRaw, function(a, b)
            return a.name < b.name
        end)

        for i = 1, #titlesRaw do
            rootDescription:CreateRadio(titlesRaw[i].name, IsTitleSelected, SetSelectedTitle, titlesRaw[i].id)
        end

        local extent = 20
        local maxCharacters = 20
        local maxScrollExtent = extent * maxCharacters
        rootDescription:SetScrollMode(maxScrollExtent)
    end

    if TransmogFrame.CharacterPreview.ModelScene and TransmogFrame.CharacterPreview.ModelScene.ControlFrame then
        TransmogFrame.CharacterPreview.ModelScene.ControlFrame:SetPoint("TOP", 0, -64)
    end

    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if outfitID and FitterCharacterSaved["Outfit"..outfitID] then
        local savedTitle = FitterCharacterSaved["Outfit"..outfitID].Title
        s.titleDropdown:SetDefaultText(CreateDisplayTitle(savedTitle))
    else
        s.titleDropdown:SetDefaultText(IGNORE_TITLE_LABEL)
    end

    s.titleDropdown:SetWidth(240)
    s.titleDropdown:SetPoint("TOP", TransmogFrame.CharacterPreview, "TOP", 0, -27)
    s.titleDropdown:SetFrameStrata("MEDIUM")
    s.titleDropdown:SetFrameLevel(200)
    s.titleDropdown.Text:SetJustifyH("CENTER")

    s.titleDropdown:SetupMenu(GeneratorFunctionTitles)

    s.titleDropdown:SetScript("OnEnter", function()
        GameTooltip:SetOwner(s.titleDropdown, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["Character Title"], 1, 1, 1)
        GameTooltip:AddLine(L["Select a title for this transmog outfit"], 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    s.titleDropdown:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    s.titleDropdownInitialized = true
end

function UI_Transmog:UpdateTitleDropdown()
    if not s.titleDropdown or not s.titleDropdownInitialized then
        return
    end

    local outfitID = C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID()
    if not outfitID or not FitterCharacterSaved["Outfit"..outfitID] then
        s.titleDropdown:SetDefaultText(IGNORE_TITLE_LABEL)
        return
    end

    local savedTitle = FitterCharacterSaved["Outfit"..outfitID].Title
    s.titleDropdown:SetDefaultText(CreateDisplayTitle(savedTitle))
    s.titleDropdown:GenerateMenu()
end
