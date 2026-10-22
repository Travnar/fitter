-- Share button for the viewed outfit, and the window opened by clicking a
-- shared outfit link.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local OutfitShare = ns.OutfitShare

local OutfitShareUI = {}
ns.OutfitShareUI = OutfitShareUI

local window

local function GetOutfits()
    local outfits = {}
    local api = C_TransmogOutfitInfo
    for _, info in ipairs(api and api.GetOutfitsInfo and api.GetOutfitsInfo() or {}) do
        local name = info.name
        if not name or name == "" then name = "Outfit " .. info.outfitID end
        outfits[#outfits + 1] = {outfitID = info.outfitID, name = name}
    end
    return outfits
end

function UI_Transmog:ShareViewedOutfit()
    local outfitID = self:GetViewedOutfitID()
    if not outfitID or outfitID == 0 then
        UIErrorsFrame:AddMessage("Select an outfit before sharing its configuration.",
            1, 0.2, 0.2)
        return
    end
    local name
    for _, info in ipairs(GetOutfits()) do
        if info.outfitID == outfitID then name = info.name break end
    end
    local token = OutfitShare.Share(outfitID, name)
    if token then OutfitShare.InsertIntoChat(token) end
end

local function UpdateApplyButton()
    window.applyButton:SetEnabled(window.payload ~= nil and window.outfitID ~= nil)
end

local function CreateWindow()
    window = CreateFrame("Frame", "FitterSharedOutfitPopup", UIParent,
        "PortraitFrameTemplate")
    window:SetSize(420, 250)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:Hide()
    window:SetTitle(L["Shared Outfit"])
    tinsert(UISpecialFrames, "FitterSharedOutfitPopup")

    local portrait = window.Portrait
        or (window.PortraitContainer and window.PortraitContainer.portrait)
    if portrait then portrait:SetTexture("Interface\\Icons\\INV_Misc_Note_05") end

    local source = window:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    source:SetPoint("TOPLEFT", 30, -62)
    source:SetPoint("RIGHT", -30, 0)
    source:SetJustifyH("LEFT")
    window.source = source

    local prompt = window:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    prompt:SetPoint("TOPLEFT", source, "BOTTOMLEFT", 0, -18)
    prompt:SetText(L["What outfit do you want to apply this to?"])

    local dropdown = CreateFrame("DropdownButton", nil, window,
        "WowStyle1DropdownTemplate")
    dropdown:SetSize(240, 30)
    dropdown:SetPoint("TOPLEFT", prompt, "BOTTOMLEFT", -2, -8)
    dropdown:SetDefaultText(L["Select an outfit"])
    dropdown:SetupMenu(function(_, root)
        for _, info in ipairs(GetOutfits()) do
            root:CreateRadio(info.name, function()
                return window.outfitID == info.outfitID
            end, function()
                window.outfitID = info.outfitID
                UpdateApplyButton()
            end)
        end
    end)
    window.dropdown = dropdown

    local status = window:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 2, -10)
    status:SetPoint("RIGHT", -30, 0)
    status:SetJustifyH("LEFT")
    window.status = status

    local cancel = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    cancel:SetSize(90, 24)
    cancel:SetPoint("BOTTOMRIGHT", -24, 20)
    cancel:SetText(L["Cancel"])
    cancel:SetScript("OnClick", function() window:Hide() end)

    local apply = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    apply:SetSize(90, 24)
    apply:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
    apply:SetText(L["Apply"])
    apply:SetScript("OnClick", function()
        if not window.payload or not window.outfitID then return end
        UI_Transmog:ApplyOutfitConfiguration(window.payload.data, window.outfitID)
        local outfitName = window.outfitID
        for _, info in ipairs(GetOutfits()) do
            if info.outfitID == window.outfitID then outfitName = info.name break end
        end
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "Fitter: Applied |cffffd200%s|r to |cffffd200%s|r.",
            window.payload.name, tostring(outfitName)))
        window:Hide()
    end)
    window.applyButton = apply

    window:SetScript("OnHide", function()
        window.request = nil
        window.payload = nil
    end)
end

local function SetStatus(text, isError)
    window.status:SetText(text or "")
    if isError then
        window.status:SetTextColor(1, 0.3, 0.3)
    else
        window.status:SetTextColor(0.6, 0.6, 0.6)
    end
end

local function DefaultOutfitID()
    local outfits = GetOutfits()
    local preferred = UI_Transmog:GetViewedOutfitID() or UI_Transmog:GetActiveOutfitID()
    for _, info in ipairs(outfits) do
        if info.outfitID == preferred then return preferred end
    end
    return outfits[1] and outfits[1].outfitID
end

-- Built at load; frames created while the transmog panel is open taint
-- gamepad navigation, and links can be clicked with it open.
CreateWindow()

function OutfitShareUI.Open(owner, id, name)
    local request = owner .. ":" .. id
    window.request = request
    window.payload = nil
    window.outfitID = DefaultOutfitID()
    local shortOwner = Ambiguate and Ambiguate(owner, "short") or owner
    window.source:SetText(string.format(L["|cffffd200%s|r shared by %s"],
        name or L["Outfit"], shortOwner))
    SetStatus(string.format(L["Requesting the configuration from %s..."], shortOwner))
    window.dropdown:GenerateMenu()
    UpdateApplyButton()
    window:Show()

    OutfitShare.Fetch(owner, id, "outfit", function(payload, err)
        if window.request ~= request then return end
        if not payload then
            SetStatus(err, true)
            return
        end
        window.payload = payload
        window.source:SetText(string.format(L["|cffffd200%s|r shared by %s"],
            payload.name, shortOwner))
        SetStatus(L["This replaces the outfit's current Fitter configuration. Anything this character has not collected is skipped."])
        UpdateApplyButton()
    end)
end

OutfitShare.linkHandlers.outfit = OutfitShareUI.Open
