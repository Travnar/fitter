local addonName, ns = ...
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s

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
        if s.characterPreviewAlpha ~= nil then
            sourceScene:SetAlpha(s.characterPreviewAlpha)
            s.characterPreviewAlpha = nil
        end
        sourceScene:Show()
        local playerActor = sourceScene.GetPlayerActor and sourceScene:GetPlayerActor()
        if playerActor and playerActor.SetRequestedScale then
            playerActor:SetRequestedScale(1)
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

    if s.mountedCharacterScene then
        s.mountedCharacterScene:OnMouseUp("LeftButton")
        s.mountedCharacterScene:OnMouseUp("RightButton")
        s.mountedCharacterScene:Hide()
        if s.mountedCharacterScene.ClearScene then
            s.mountedCharacterScene:ClearScene()
        end
    end

    s.characterPreviewCameraZoom = nil
    s.characterPreviewCameraMinZoom = nil
    s.characterPreviewCameraMaxZoom = nil
    s.previewMountID = nil
end

-- Sizes petActor relative to the loaded playerActor and places it beside the
-- player. Returns the player's height and Y bounds and the pet's scaled
-- width, or nil when either model has no usable bounding box.
function UI_Transmog._PlacePetBesidePlayer(petActor, playerActor, isHunterPreview)
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
        return nil
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
    return playerHeight, playerBottomY, playerTopY,
        math.max((petTopY - petBottomY) * scale, 0)
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

        local playerHeight, playerBottomY, playerTopY, petWidth =
            UI_Transmog._PlacePetBesidePlayer(petActor, playerActor, isHunterPreview)
        if not playerHeight then return end

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

    local outfitInfo = self:RestoreHearthstonePreviewOutfit()
        or (sourcePlayer.GetItemTransmogInfoList
        and sourcePlayer:GetItemTransmogInfoList())

    self:ClearMountPreview()
    local request = s.mountPreviewRequest

    local previewScene = s.mountedCharacterScene
    if not previewScene then
        previewScene = UI_Transmog._CreateDetachedFrame("ModelScene", nil,
            sourceScene, "PanningModelSceneMixinTemplate")
        previewScene:SetAllPoints(sourceScene)
        previewScene:SetIgnoreParentAlpha(true)
        previewScene:EnableMouse(false)
        previewScene:EnableMouseWheel(false)
        previewScene:Hide()
        s.mountedCharacterScene = previewScene

        -- Keep Blizzard's working input surface in place across mount, pet,
        -- and normal previews. The child scene only renders the mounted
        -- player; the original scene receives mouse input and forwards it.
        -- HookScript, not SetScript: gamepad SmartNavigation calls
        -- GetScript("OnMouseDown"/"OnMouseUp") on non-button frames while
        -- building navigation data, and an addon-set handler returned there
        -- taints it (blocking protected gamepad calls when the panel
        -- closes).  Hooks don't replace what GetScript returns.  The
        -- original handler also runs, but only moves the hidden actor.
        for _, script in ipairs({"OnMouseDown", "OnMouseUp", "OnMouseWheel",
            "OnEnter", "OnLeave"}) do
            local mountedHandler = previewScene:GetScript(script)
            if mountedHandler then
                sourceScene:HookScript(script, function(_, ...)
                    if s.previewMountID and previewScene:IsShown() then
                        mountedHandler(previewScene, ...)
                    end
                end)
            end
        end
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

    local function ShowMountedPreview()
        -- A child defaults to one level above its parent, which can cover
        -- equipment slots. Render at Blizzard's original preview level.
        previewScene:SetFrameLevel(sourceScene:GetFrameLevel())
        s.characterPreviewAlpha = sourceScene:GetAlpha()
        sourceScene:SetAlpha(0)
        if sourceScene.ControlFrame then sourceScene.ControlFrame:Hide() end
        s.previewMountID = mountID
        previewScene:Show()
    end

    -- Transformation mounts (for example, Sandstone Drake) replace the player
    -- instead of carrying a rider.  Their native mount-journal scene actor is
    -- therefore the complete preview; attaching a player would either fail or
    -- leave only the regular character visible.
    if isSelfMount or disablePlayerMountPreview then
        ShowMountedPreview()
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

    ShowMountedPreview()

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
