-- "Send Preview" for mount and pet cards, and the window opened by clicking
-- a shared preview link. The preview shows the viewer's own character in the
-- sender's transmog, riding the mount or beside the pet.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local OutfitShare = ns.OutfitShare
local Details = ns.PreviewOutfitDetails

-- Blizzard's dressing room scene, which has a "player" actor.
local PLAYER_MODEL_SCENE_ID = 290

local window

-- preview: {mountID = number} or {petDisplayID = number}.
function UI_Transmog:SendPreview(preview, label)
    local scene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    local actor = scene and scene.GetPlayerActor and scene:GetPlayerActor()
    local list = actor and actor.GetItemTransmogInfoList
        and actor:GetItemTransmogInfoList()
    if not list then
        UIErrorsFrame:AddMessage("The transmog preview is not ready yet.", 1, 0.2, 0.2)
        return
    end
    local transmog = {}
    for slot, info in pairs(list) do
        if type(slot) == "number" and info.appearanceID then
            transmog[slot] = {info.appearanceID, info.secondaryAppearanceID or 0,
                info.illusionID or 0}
        end
    end
    preview.transmog = transmog
    local token = OutfitShare.SharePreview(preview, label)
    if token then OutfitShare.InsertIntoChat(token) end
end

local function SetStatus(text, isError)
    window.status:SetText(text or "")
    if isError then
        window.status:SetTextColor(1, 0.3, 0.3)
    else
        window.status:SetTextColor(0.6, 0.6, 0.6)
    end
end

-- Runs callback once every actor has finished loading its model, unless a
-- newer preview has started in the meantime.
local function WhenLoaded(request, actors, callback)
    local attempts = 0
    local function Check()
        if request ~= window.request then return end
        attempts = attempts + 1
        for _, actor in ipairs(actors) do
            if actor.IsLoaded and not actor:IsLoaded() then
                if attempts < 40 then C_Timer.After(0.05, Check) end
                return
            end
        end
        callback()
    end
    Check()
end

local function CreateTransmogInfo(info)
    if ItemUtil and ItemUtil.CreateItemTransmogInfo then
        return ItemUtil.CreateItemTransmogInfo(info[1], info[2], info[3])
    end
    return {appearanceID = info[1], secondaryAppearanceID = info[2],
        illusionID = info[3]}
end

local function Dress(actor, transmog)
    if actor.Undress then actor:Undress() end
    if not actor.SetItemTransmogInfo then return end
    for _, info in pairs(transmog) do
        pcall(actor.SetItemTransmogInfo, actor, CreateTransmogInfo(info))
    end
end

-- Shows the outfit alone in Blizzard's Dressing Room, where it can be saved
-- as a custom set.
local function OpenInDressingRoom()
    local transmog = window.transmog
    if not transmog or not DressUpItemTransmogInfoList then return end
    local lastSlot = 0
    for slot in pairs(transmog) do lastSlot = math.max(lastSlot, slot) end
    local list = {}
    for slot = 1, lastSlot do
        list[slot] = CreateTransmogInfo(transmog[slot] or {0, 0, 0})
    end
    window:Hide()
    DressUpItemTransmogInfoList(list, true)
end

local function ShowMount(request, preview)
    local mountID = preview.mountID
    local displayID, _, _, isSelfMount, _, modelSceneID, animID,
        spellVisualKitID, disablePlayerMountPreview =
        C_MountJournal.GetMountInfoExtraByID(mountID)
    if not displayID or displayID == 0 then
        local displays = C_MountJournal.GetMountAllCreatureDisplayInfoByID(mountID)
        displayID = displays and displays[1] and displays[1].creatureDisplayID
    end
    if not displayID or not modelSceneID then
        SetStatus(L["This mount cannot be previewed."], true)
        return
    end

    local scene = window.mountScene
    scene:Show()
    scene:TransitionToModelSceneID(modelSceneID, CAMERA_TRANSITION_TYPE_IMMEDIATE,
        CAMERA_MODIFICATION_TYPE_DISCARD, true)
    local mountActor = scene:GetActorByTag("unwrapped")
    if not mountActor then
        SetStatus(L["This mount cannot be previewed."], true)
        return
    end
    mountActor:SetModelByCreatureDisplayID(displayID)
    if spellVisualKitID then mountActor:SetSpellVisualKit(spellVisualKitID) end

    -- Transformation mounts replace the rider, so there is nothing to dress.
    if isSelfMount or disablePlayerMountPreview then return end
    scene:AttachPlayerToMount(mountActor, animID or 0, false, false,
        spellVisualKitID, true)
    local rider = scene:GetPlayerActor("player-rider")
    if not rider then return end
    WhenLoaded(request, {rider}, function()
        Dress(rider, preview.transmog)
        if rider.SetSheathed then rider:SetSheathed(true, true) end
    end)
end

local function ShowPet(request, preview)
    local scene = window.petScene
    scene:Show()
    if not window.petSceneReady then
        scene:TransitionToModelSceneID(PLAYER_MODEL_SCENE_ID,
            CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
        window.petSceneReady = true
    end
    local player = scene:GetPlayerActor()
    if not player then
        SetStatus(L["This pet cannot be previewed."], true)
        return
    end
    player:SetModelByUnit("player", true, true)

    local pet = window.petActor
    if not pet then
        pet = scene:CreateActor()
        window.petActor = pet
    end
    pet:SetUseCenterForOrigin(false, false, false)
    pet:SetPosition(0, 0, 0)
    pet:SetYaw(0)
    pet:SetPitch(0)
    pet:SetRoll(0)
    pet:SetScale(1)
    pet:SetModelByCreatureDisplayID(preview.petDisplayID)

    WhenLoaded(request, {player, pet}, function()
        Dress(player, preview.transmog)
        UI_Transmog._PlacePetBesidePlayer(pet, player, false)
    end)
end

local function ClearScenes()
    window.transmog = nil
    window.dressingRoomButton:Disable()
    Details.Clear()
    window.mountScene:Hide()
    if window.mountScene.ClearScene then window.mountScene:ClearScene() end
    window.petScene:Hide()
    if window.petActor then window.petActor:ClearModel() end
    local player = window.petSceneReady and window.petScene:GetPlayerActor()
    if player then player:ClearModel() end
end

local function CreateModelScene()
    local scene = CreateFrame("ModelScene", nil, window, "PanningModelSceneMixinTemplate")
    scene:SetPoint("TOPLEFT", window.background)
    scene:SetPoint("BOTTOMRIGHT", window.background)
    scene:Hide()
    return scene
end

local function CreateWindow()
    window = CreateFrame("Frame", "FitterPreviewShareFrame", UIParent,
        "PortraitFrameTemplate")
    window:SetSize(840, 600)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:Hide()
    window.request = 0
    tinsert(UISpecialFrames, "FitterPreviewShareFrame")

    local portrait = window.Portrait
        or (window.PortraitContainer and window.PortraitContainer.portrait)
    if portrait then portrait:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03") end

    local background = window:CreateTexture(nil, "BACKGROUND", nil, 1)
    background:SetPoint("TOPLEFT", 8, -64)
    background:SetPoint("BOTTOMLEFT", 8, 34)
    background:SetWidth(452)
    local _, classFile = UnitClass("player")
    local atlas = classFile and "dressingroom-background-" .. classFile:lower()
    if atlas and C_Texture and C_Texture.GetAtlasInfo(atlas) then
        background:SetAtlas(atlas)
    else
        background:SetColorTexture(0, 0, 0, 0.6)
    end
    window.background = background

    window.mountScene = CreateModelScene()
    window.petScene = CreateModelScene()

    -- Slot buttons sit above the model scenes.
    local modelArea = CreateFrame("Frame", nil, window)
    modelArea:SetAllPoints(background)
    modelArea:SetFrameLevel(window.mountScene:GetFrameLevel() + 5)

    local panel = CreateFrame("Frame", nil, window)
    panel:SetPoint("TOPLEFT", background, "TOPRIGHT", 4, 0)
    panel:SetPoint("BOTTOMRIGHT", -8, 34)
    local panelBackground = panel:CreateTexture(nil, "BACKGROUND")
    panelBackground:SetAllPoints()
    panelBackground:SetColorTexture(0, 0, 0, 0.75)

    Details.Create(modelArea, panel)

    local dressingRoom = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    dressingRoom:SetSize(170, 22)
    dressingRoom:SetPoint("TOPRIGHT", -12, -32)
    dressingRoom:SetText(L["Open in Dressing Room"])
    dressingRoom:SetScript("OnClick", OpenInDressingRoom)
    dressingRoom:SetShown(DressUpItemTransmogInfoList ~= nil)
    dressingRoom:Disable()
    window.dressingRoomButton = dressingRoom

    local status = window:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("BOTTOMLEFT", 16, 12)
    status:SetPoint("BOTTOMRIGHT", -16, 12)
    status:SetJustifyH("LEFT")
    window.status = status

    window:SetScript("OnHide", function()
        window.request = window.request + 1
        ClearScenes()
    end)
end

-- Built at load; frames created while the transmog panel is open taint
-- gamepad navigation, and links can be clicked with it open.
CreateWindow()

local function OpenPreview(owner, id, name)
    window.request = window.request + 1
    local request = window.request
    ClearScenes()
    local shortOwner = Ambiguate and Ambiguate(owner, "short") or owner
    window:SetTitle(name or L["Preview"])
    SetStatus(string.format(L["Requesting the preview from %s..."], shortOwner))
    window:Show()

    OutfitShare.Fetch(owner, id, "preview", function(payload, err)
        if request ~= window.request then return end
        if not payload then
            SetStatus(err, true)
            return
        end
        window:SetTitle(payload.name)
        SetStatus(nil)
        window.transmog = payload.preview.transmog
        window.dressingRoomButton:Enable()
        Details.Show(payload.preview.transmog)
        if payload.preview.mountID then
            ShowMount(request, payload.preview)
        else
            ShowPet(request, payload.preview)
        end
    end)
end

OutfitShare.linkHandlers.preview = OpenPreview
