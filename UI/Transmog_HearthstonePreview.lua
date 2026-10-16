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

local function GetPreviewScene()
    return TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
end

local motionFrame = CreateFrame("Frame")
motionFrame:Hide()

local function ClearPreviewEffects()
    motionFrame:Hide()
    s.hearthstonePreviewMotions = nil
    for _, effectActor in ipairs(s.hearthstonePreviewEffects or {}) do
        if effectActor.ClearModel then pcall(effectActor.ClearModel, effectActor) end
        effectActor:Hide()
    end
end

local function PlaceEffect(effectActor, effect, origin, elapsed)
    local x, y = (effect.x or 0) * origin.height, (effect.y or 0) * origin.height
    local z = effect.z or 0
    local yaw = origin.yaw + (effect.yaw or 0)
    if effect.orbit then
        local angle = (elapsed or 0) / effect.orbit.period * 2 * math.pi
        local radius = effect.orbit.radius * origin.height
        x, y = x + radius * math.cos(angle), y + radius * math.sin(angle)
        yaw = yaw + angle
    end
    if effect.rise then
        local t = math.min((elapsed or 0) / effect.rise.duration, 1)
        t = 1 - (1 - t) * (1 - t)
        z = effect.rise.from + (z - effect.rise.from) * t
    end
    local cosYaw, sinYaw = math.cos(origin.yaw), math.sin(origin.yaw)
    effectActor:SetPosition(origin.x + x * cosYaw - y * sinYaw,
        origin.y + x * sinYaw + y * cosYaw,
        origin.z + z * origin.height)
    effectActor:SetYaw(yaw)
end

motionFrame:SetScript("OnUpdate", function(self)
    local motions = s.hearthstonePreviewMotions
    if not motions then
        self:Hide()
        return
    end
    local now = GetTime()
    for _, motion in ipairs(motions) do
        PlaceEffect(motion.actor, motion.effect, motion.origin,
            now - motion.startTime)
    end
end)

local function ShowPreviewEffects(actor, effects, request)
    local scene = GetPreviewScene()
    if not scene or not scene.CreateActor then return end

    local actorScale = actor.GetScale and actor:GetScale() or 1
    local height
    if actor.GetActiveBoundingBox then
        local _, _, bottomZ, _, _, topZ = actor:GetActiveBoundingBox()
        height = bottomZ and topZ and (topZ - bottomZ) * actorScale
    end
    if not height or height <= 0 then height = 2 * actorScale end
    local origin = {x = 0, y = 0, z = 0, height = height,
        yaw = actor.GetYaw and actor:GetYaw() or 0}
    if actor.GetPosition then
        origin.x, origin.y, origin.z = actor:GetPosition()
    end

    s.hearthstonePreviewEffects = s.hearthstonePreviewEffects or {}
    for index, effect in ipairs(effects) do
        local effectActor = s.hearthstonePreviewEffects[index]
        if not effectActor then
            effectActor = scene:CreateActor()
            s.hearthstonePreviewEffects[index] = effectActor
        end
        effectActor:SetUseCenterForOrigin(false, false, false)
        PlaceEffect(effectActor, effect, origin, 0)
        effectActor:SetPitch(effect.pitch or 0)
        effectActor:SetRoll(0)
        effectActor:SetScale((effect.scale or 1) * actorScale)

        local function Activate()
            effectActor:SetModelByFileID(effect.fileID)
            if effect.animationKitID and effectActor.PlayAnimationKit then
                pcall(effectActor.PlayAnimationKit, effectActor,
                    effect.animationKitID, true)
            elseif effect.animationID then
                pcall(effectActor.SetAnimation, effectActor, effect.animationID)
            end
            effectActor:Show()
            if effect.orbit or effect.rise then
                s.hearthstonePreviewMotions = s.hearthstonePreviewMotions or {}
                table.insert(s.hearthstonePreviewMotions, {actor = effectActor,
                    effect = effect, origin = origin, startTime = GetTime()})
                motionFrame:Show()
            end
        end
        if effect.delay then
            effectActor:Hide()
            UI_Transmog:ScheduleTimer(effect.delay, function()
                if request ~= s.hearthstonePreviewRequest
                    or not s.previewHearthstoneActive then
                    return
                end
                Activate()
            end, "preview")
        else
            Activate()
        end
    end
end

local function ResetPreviewActor(actor, request, onReady)
    ClearPreviewEffects()
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
    local scene = GetPreviewScene()
    return scene and scene.GetPlayerActor and scene:GetPlayerActor()
end

-- Restores the player's outfit after a preview changed the model or tried on
-- an item. Returns the saved outfit, since the actor cannot report it until
-- rebuilt.
function UI_Transmog:RestoreHearthstonePreviewOutfit()
    ClearPreviewEffects()
    local saved = s.hearthstonePreviewOutfit
    if not saved then return nil end
    local actor = GetPreviewActor()
    if actor then ResetPreviewActor(actor, nil) end
    return saved.outfitInfo
end

local function FinishPreviewOnExistingActor(actor, request)
    if request ~= s.hearthstonePreviewRequest then return end
    s.previewHearthstoneActive = nil
    ClearPreviewEffects()
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

-- previewEquipItemID is an item ID, a list of item IDs, or a table of item
-- IDs keyed by faction. Returns a list (possibly empty).
local function GetPreviewEquipItemIDs(item)
    local equip = item.previewEquipItemID
    if type(equip) == "table" then
        if #equip > 0 then return equip end
        equip = equip[UnitFactionGroup("player")]
    end
    return equip and {equip} or {}
end

-- Returns the player's faction value from a {Alliance = x, Horde = y} table,
-- falling back to Alliance for neutral characters.
local function ForFaction(value)
    if type(value) ~= "table" or #value > 0 then return value end
    return value[UnitFactionGroup("player")] or value.Alliance
end

-- previewSpellVisualKitID is a kit ID, a list of kit IDs, or a table keyed by
-- faction. Some kits attach with different offsets on certain body types
-- (see TOY_PREVIEW_ALT_BODIES); those provide previewAltSpellVisualKitID.
local function GetPreviewSpellVisualKitIDs(item)
    local kits = item.previewSpellVisualKitID
    if item.previewAltSpellVisualKitID then
        local _, _, raceID = UnitRace("player")
        local bodies = ns.Constants.TOY_PREVIEW_ALT_BODIES or {}
        if raceID and bodies[raceID .. ":" .. UnitSex("player")] then
            kits = item.previewAltSpellVisualKitID
        end
    end
    kits = ForFaction(kits)
    if type(kits) == "table" then return kits end
    return kits and {kits} or {}
end

local function TryOnPreviewItem(actor, itemID)
    if not actor.TryOn then return end
    local _, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    pcall(actor.TryOn, actor, sourceID or ("item:" .. itemID))
end

-- Most transform creatures are missing from the client's Creature table, so
-- resolve their display through a hidden PlayerModel. SetCreature queries the
-- server-backed creature cache; GetDisplayInfo stays 0 until it arrives.
-- Each creature gets its own model: a reused model keeps reporting the
-- previous creature's display (even after ClearModel) until the server
-- answers, which would cache the wrong display.
local creatureDisplayCache = {}
local creatureModels = {}
local function ResolveCreatureDisplayID(creatureID, request, callback)
    if creatureDisplayCache[creatureID] then
        callback(creatureDisplayCache[creatureID])
        return
    end
    local creatureModel = creatureModels[creatureID]
    if not creatureModel then
        creatureModel = CreateFrame("PlayerModel", nil, UIParent)
        creatureModel:SetSize(1, 1)
        creatureModel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
        creatureModel:SetAlpha(0)
        creatureModels[creatureID] = creatureModel
    end
    creatureModel:Show()
    pcall(creatureModel.SetCreature, creatureModel, creatureID)
    local attempts = 0
    local function Check()
        if request ~= s.hearthstonePreviewRequest then
            creatureModel:Hide()
            return
        end
        local ok, displayID = pcall(creatureModel.GetDisplayInfo, creatureModel)
        if ok and displayID and displayID > 0 then
            creatureDisplayCache[creatureID] = displayID
            creatureModel:Hide()
            callback(displayID)
            return
        end
        attempts = attempts + 1
        if attempts < 60 then
            UI_Transmog:ScheduleTimer(.05, Check, "preview")
        else
            creatureModel:Hide()
            callback(nil)
        end
    end
    Check()
end

function UI_Transmog:PreviewHearthstoneCast(item)
    self:CancelUITimers("preview")
    s.hearthstonePreviewRequest = (s.hearthstonePreviewRequest or 0) + 1
    local request = s.hearthstonePreviewRequest
    s.previewHearthstoneActive = item ~= nil
    -- Lets the toy menu offer "Clear Preview" for the toy being shown.
    s.previewToyID = item and item.previewToyID or nil

    self:ClearMountPreview()
    local actor = GetPreviewActor()
    if not actor then return end

    local function PlayCast(equipItemIDs)
        -- Some Hearthstones and toys equip cosmetic items for their effect.
        for _, equipItemID in ipairs(equipItemIDs or {}) do
            TryOnPreviewItem(actor, equipItemID)
        end

        local kits = GetPreviewSpellVisualKitIDs(item)
        if actor.SetSpellVisualKit then
            for _, kitID in ipairs(kits) do
                pcall(actor.SetSpellVisualKit, actor, kitID, false)
            end
        end
        if item.previewEffectModels then
            ShowPreviewEffects(actor, item.previewEffectModels, request)
        end

        local function ScheduleCleanup()
            -- Toy effects are persistent auras; keep them until replaced
            -- or cleared instead of ending like a Hearthstone cast.
            if item.previewPersistent then return end
            UI_Transmog:ScheduleTimer(PREVIEW_DURATION, function()
                if request ~= s.hearthstonePreviewRequest then return end
                FinishPreviewOnExistingActor(actor, request)
            end, "preview")
        end

        -- Persistent spell kits can update the actor's animation at the end
        -- of their initialization frame. Apply explicit animations one frame
        -- later so the Hearthstone's own cast is retained.
        if actor.PlayAnimationKit and item.previewAnimationKitID then
            UI_Transmog:ScheduleTimer(0, function()
                if request ~= s.hearthstonePreviewRequest then return end
                pcall(actor.PlayAnimationKit, actor, item.previewAnimationKitID, true)
                ScheduleCleanup()
            end, "preview")
        elseif actor.SetAnimation and item.previewAnimationID then
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
        local canTransform = actor.SetModelByCreatureDisplayID ~= nil
        local transformID = canTransform and item.previewTransformDisplayID
        local transformCreatureID = canTransform
            and item.previewTransformCreatureID
        local equipItemIDs = GetPreviewEquipItemIDs(item)
        if not transformID and not transformCreatureID and #equipItemIDs == 0
            and not item.previewRebuildAfter then
            PlayCast()
            return
        end
        -- A saved outfit makes cleanup rebuild the actor, which also clears
        -- dissolves that outlast the spell kit.
        s.hearthstonePreviewOutfit = {
            outfitInfo = actor.GetItemTransmogInfoList
                and actor:GetItemTransmogInfoList(),
            sheathed = actor.GetSheathed and actor:GetSheathed(),
        }
        -- Some Hearthstones and toys transform the caster.
        local function Transform(displayID)
            if not displayID then
                PlayCast(equipItemIDs)
                return
            end
            pcall(actor.SetModelByCreatureDisplayID, actor, displayID)
            WhenActorLoaded(actor, request, function() PlayCast(equipItemIDs) end)
        end
        if transformID or not transformCreatureID then
            Transform(transformID)
        else
            ResolveCreatureDisplayID(transformCreatureID, request, Transform)
        end
    end)
end
