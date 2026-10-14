-- Hearthstone cast preview on the transmog character model.
local addonName, ns = ...
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s

local PREVIEW_DURATION = 10

-- A nil request is never superseded. It is used to restore the player's
-- outfit, which must finish even when a newer preview cancels the "preview"
-- timers.
local function WhenActorLoaded(actor, request, callback)
    local attempts = 0
    local function Check()
        if request and request ~= s.hearthstonePreviewRequest then return end
        attempts = attempts + 1
        if actor.IsLoaded and not actor:IsLoaded() then
            if attempts < 40 then
                UI_Transmog:ScheduleTimer(.05, Check,
                    request and "preview" or "hearthstone-restore")
            end
            return
        end
        callback()
    end
    Check()
end

local function ResetPreviewActor(actor, request, onReady)
    -- A transformed actor cannot report the outfit, and a tried-on item would
    -- be reported as part of it, so restore the copy saved before either.
    local saved = s.hearthstonePreviewOutfit
    local outfitInfo, sheathed
    if saved then
        outfitInfo, sheathed = saved.outfitInfo, saved.sheathed
    else
        outfitInfo = actor.GetItemTransmogInfoList
            and actor:GetItemTransmogInfoList()
        sheathed = actor.GetSheathed and actor:GetSheathed()
    end

    if actor.SetSpellVisualKit then pcall(actor.SetSpellVisualKit, actor, 0, true) end
    if actor.PlayAnimationKit then pcall(actor.PlayAnimationKit, actor, 0, false) end
    if actor.SetAnimation then pcall(actor.SetAnimation, actor, 0) end

    -- Rebuilding the actor is the reliable way to remove persistent
    -- environmental attachments created by a spell visual kit.
    if actor.SetModelByUnit then
        pcall(actor.SetModelByUnit, actor, "player", sheathed ~= false, true)
    end

    WhenActorLoaded(actor, request, function()
        if outfitInfo and actor.SetItemTransmogInfo then
            for _, info in pairs(outfitInfo) do
                pcall(actor.SetItemTransmogInfo, actor, info)
            end
        end
        if sheathed ~= nil and actor.SetSheathed then
            pcall(actor.SetSheathed, actor, sheathed, false)
        end
        -- Keep the copy until it has been applied, so a superseded reset
        -- does not lose the outfit.
        if saved and s.hearthstonePreviewOutfit == saved then
            s.hearthstonePreviewOutfit = nil
        end
        if onReady then onReady() end
    end)
end

local function GetPreviewActor()
    local scene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    return scene and scene.GetPlayerActor and scene:GetPlayerActor()
end

-- Restores the player's outfit after a preview changed the model or tried on
-- an item. Returns the saved outfit, since the actor cannot report it until
-- rebuilt.
function UI_Transmog:RestoreHearthstonePreviewOutfit()
    local saved = s.hearthstonePreviewOutfit
    if not saved then return nil end
    local actor = GetPreviewActor()
    if actor then ResetPreviewActor(actor, nil) end
    return saved.outfitInfo
end

local function FinishPreviewOnExistingActor(actor, request)
    if request ~= s.hearthstonePreviewRequest then return end
    s.previewHearthstoneActive = nil
    if s.hearthstonePreviewOutfit then
        ResetPreviewActor(actor, nil)
        return
    end
    if actor.SetSpellVisualKit then pcall(actor.SetSpellVisualKit, actor, 0, true) end
    if actor.PlayAnimationKit then pcall(actor.PlayAnimationKit, actor, 0, false) end
    if actor.SetAnimationBlendOperation then
        -- Enum.ModelBlendOperation.Anim: blend from the cast pose back to idle
        -- instead of snapping or rebuilding the character model.
        pcall(actor.SetAnimationBlendOperation, actor, 1)
    end
    if actor.SetAnimation then pcall(actor.SetAnimation, actor, 0, 0, 1, 0) end
end

-- previewEquipItemID is an item ID, or a table of item IDs keyed by faction.
local function GetPreviewEquipItemID(item)
    local equip = item.previewEquipItemID
    if type(equip) == "table" then
        return equip[UnitFactionGroup("player")]
    end
    return equip
end

local function TryOnPreviewItem(actor, itemID)
    if not actor.TryOn then return end
    local _, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    pcall(actor.TryOn, actor, sourceID or ("item:" .. itemID))
end

function UI_Transmog:PreviewHearthstoneCast(item)
    self:CancelUITimers("preview")
    s.hearthstonePreviewRequest = (s.hearthstonePreviewRequest or 0) + 1
    local request = s.hearthstonePreviewRequest
    s.previewHearthstoneActive = item ~= nil

    self:ClearMountPreview()
    local actor = GetPreviewActor()
    if not actor then return end

    local function PlayCast(equipItemID)
        -- Some Hearthstones equip a cosmetic item for the cast.
        if equipItemID then TryOnPreviewItem(actor, equipItemID) end

        if actor.SetSpellVisualKit and item.previewSpellVisualKitID then
            pcall(actor.SetSpellVisualKit, actor,
                item.previewSpellVisualKitID, false)
        end

        local function ScheduleCleanup()
            UI_Transmog:ScheduleTimer(PREVIEW_DURATION, function()
                if request ~= s.hearthstonePreviewRequest then return end
                FinishPreviewOnExistingActor(actor, request)
            end, "preview")
        end

        if actor.PlayAnimationKit and item.previewAnimationKitID then
            pcall(actor.PlayAnimationKit, actor, item.previewAnimationKitID, true)
            ScheduleCleanup()
        elseif actor.SetAnimation and item.previewAnimationID then
            -- Persistent spell kits can update the actor's animation at the
            -- end of their initialization frame. Apply explicit animations
            -- one frame later so the standard Hearthstone cast is retained.
            UI_Transmog:ScheduleTimer(0, function()
                if request ~= s.hearthstonePreviewRequest then return end
                pcall(actor.SetAnimation, actor, item.previewAnimationID, 0, 1, 0)
                ScheduleCleanup()
            end, "preview")
        else
            ScheduleCleanup()
        end
    end

    ResetPreviewActor(actor, request, function()
        -- A nil item is a reset-only request.
        if not item then
            s.previewHearthstoneActive = nil
            return
        end
        local transformID = actor.SetModelByCreatureDisplayID
            and item.previewTransformDisplayID
        local equipItemID = GetPreviewEquipItemID(item)
        if not transformID and not equipItemID then
            PlayCast()
            return
        end
        s.hearthstonePreviewOutfit = {
            outfitInfo = actor.GetItemTransmogInfoList
                and actor:GetItemTransmogInfoList(),
            sheathed = actor.GetSheathed and actor:GetSheathed(),
        }
        if not transformID then
            PlayCast(equipItemID)
            return
        end
        -- Some Hearthstones transform the caster at the start of the cast.
        pcall(actor.SetModelByCreatureDisplayID, actor, transformID)
        WhenActorLoaded(actor, request, function() PlayCast(equipItemID) end)
    end)
end
