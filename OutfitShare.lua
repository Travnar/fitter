-- Shared outfit links. Chat messages cannot hold a configuration, so sharing
-- posts a plain [Fitter: Name #id] token that Fitter clients turn into a
-- link. Clicking it fetches the snapshot from the sender over addon whispers.
local addonName, ns = ...

local OutfitShare = {}
ns.OutfitShare = OutfitShare

local Codec = ns.Codec

local FORMAT_VERSION = 1
local PREFIX = "Fitter"
local LINK_COLOR = "ff71d5ff"
local TOKEN_PATTERN = "%[Fitter: ([^%]#|]-) #(%w+)%]"
local MAX_SAVED_SHARES = 30
local MAX_CHUNKS = 100
-- Addon messages are limited to 255 bytes, including the "D:id:i:n:" header.
local CHUNK_SIZE = 230
local REQUEST_TIMEOUT = 15

local CHAT_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL",
}

-- Expected types of the outfit fields other code indexes directly. Shared
-- data comes from other players, so mismatched fields are dropped.
local FIELD_TYPES = {
    Flying = "table", Ground = "table", Aquatic = "table", Pets = "table",
    PetSummonTriggers = "table", HunterPets = "table",
    HunterPetMetadata = "table", Hearthstones = "table", Toys = "table",
    Emotes = "table", Zones = "table",
    FlyingRandom = "boolean", GroundRandom = "boolean",
    AquaticRandom = "boolean", FlyingNoMount = "boolean",
    GroundNoMount = "boolean", AquaticNoMount = "boolean",
    PetRandom = "boolean", PetNoPet = "boolean",
    HunterPetDisabled = "boolean", HunterPetRandom = "boolean",
    Title = "number",
}

local function IsReadable(value)
    return type(value) == "string"
        and (not issecretvalue or not issecretvalue(value))
end

local function FullName(name)
    if not name or name == "" then return nil end
    if name:find("-", 1, true) then return name end
    return name .. "-" .. (GetNormalizedRealmName() or "")
end

local function PlayerFullName()
    return FullName(UnitName("player"))
end

local function Store()
    FitterSaved = FitterSaved or {}
    FitterSaved.SharedOutfits = FitterSaved.SharedOutfits or {}
    return FitterSaved.SharedOutfits
end

local function NewID(store)
    local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
    local id
    repeat
        local parts = {}
        for i = 1, 6 do
            local n = math.random(#chars)
            parts[i] = chars:sub(n, n)
        end
        id = table.concat(parts)
    until not store[id]
    return id
end

local function PruneStore(store)
    local ids = {}
    for id in pairs(store) do ids[#ids + 1] = id end
    if #ids <= MAX_SAVED_SHARES then return end
    table.sort(ids, function(a, b)
        return (store[a].time or 0) < (store[b].time or 0)
    end)
    for i = 1, #ids - MAX_SAVED_SHARES do store[ids[i]] = nil end
end

local function CleanName(name)
    name = tostring(name or ""):gsub("[%[%]#|]", ""):match("^%s*(.-)%s*$")
    if name == "" then name = "Outfit" end
    return name:sub(1, 40)
end

-- Snapshots outfitID's configuration and returns the chat token for it.
function OutfitShare.Share(outfitID, outfitName)
    local data = FitterCharacterSaved and FitterCharacterSaved["Outfit" .. outfitID]
    if type(data) ~= "table" then return nil end
    local snapshot = {}
    for key, value in pairs(data) do
        if key ~= "SituationBaseline" then snapshot[key] = value end
    end
    local name = CleanName(outfitName)
    local encoded = Codec.Encode({
        version = FORMAT_VERSION,
        kind = "outfit",
        name = name,
        data = snapshot,
    })

    local store = Store()
    local id
    for existingID, entry in pairs(store) do
        if entry.encoded == encoded then id = existingID break end
    end
    id = id or NewID(store)
    store[id] = {encoded = encoded, time = GetServerTime()}
    PruneStore(store)
    return string.format("[Fitter: %s #%s]", name, id)
end

local CHAT_TARGET_ATTRIBUTES = {"chatType", "tellTarget", "channelTarget"}

-- Clicking the share button closes the chat box, which resets it to the
-- last channel a message was sent in before the click is handled. The
-- channel is therefore recorded while the box still has focus.
local trackedEditBox, trackedTarget

local function TrackChatTarget(editBox)
    if not editBox or not editBox.HasFocus or not editBox:HasFocus() then return end
    local target = {}
    for _, attribute in ipairs(CHAT_TARGET_ATTRIBUTES) do
        target[attribute] = editBox:GetAttribute(attribute)
    end
    trackedEditBox, trackedTarget = editBox, target
end

for i = 1, NUM_CHAT_WINDOWS or 10 do
    local editBox = _G["ChatFrame" .. i .. "EditBox"]
    if editBox then
        editBox:HookScript("OnEditFocusGained", TrackChatTarget)
        editBox:HookScript("OnTextChanged", TrackChatTarget)
    end
end
if ChatEdit_UpdateHeader then hooksecurefunc("ChatEdit_UpdateHeader", TrackChatTarget) end

local function GetFocusedChatEditBox()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox and editBox:HasFocus() then return editBox end
    end
end

-- Puts text in the open chat box, or opens the chat box with it on the
-- channel it was last set to.
function OutfitShare.InsertIntoChat(text)
    local focused = GetFocusedChatEditBox()
    if focused then
        focused:Insert(text)
        return
    end

    local openChat = ChatFrameUtil and ChatFrameUtil.OpenChat or ChatFrame_OpenChat
    if not openChat then return end
    -- Read before opening; gaining focus records the reset channel.
    local target = trackedTarget
    local editBox = openChat(text, trackedEditBox and trackedEditBox.chatFrame)
        or GetFocusedChatEditBox()
    if not editBox or not target or not target.chatType
        or editBox:GetAttribute("chatType") == target.chatType then return end
    for _, attribute in ipairs(CHAT_TARGET_ATTRIBUTES) do
        editBox:SetAttribute(attribute, target[attribute])
    end
    local updateHeader = ChatFrameUtil and ChatFrameUtil.UpdateHeader
        or ChatEdit_UpdateHeader
    if editBox.UpdateHeader then
        editBox:UpdateHeader()
    elseif updateHeader then
        updateHeader(editBox)
    end
end

local function DecodeShare(encoded)
    local payload, err = Codec.Decode(encoded)
    if not payload then return nil, err end
    if type(payload) ~= "table" or payload.kind ~= "outfit"
        or type(payload.data) ~= "table" then
        return nil, "This is not a Fitter outfit configuration."
    end
    if payload.version ~= FORMAT_VERSION then
        return nil, "This outfit was shared by a different version of Fitter."
    end
    for key, value in pairs(payload.data) do
        local expected = FIELD_TYPES[key]
        if type(key) ~= "string" or key == "SituationBaseline"
            or (expected and type(value) ~= expected) then
            payload.data[key] = nil
        end
    end
    payload.name = CleanName(payload.name)
    return payload
end

---------------------------------------------------------------------------
-- Addon messages
--   R:<id>                   request a shared outfit
--   N:<id>                   the requested outfit is not saved
--   D:<id>:<i>:<n>:<chunk>   chunk i of n of the encoded outfit
---------------------------------------------------------------------------

local sendQueue = {}
local sending = false
local THROTTLED = Enum and Enum.SendAddonMessageResult
    and Enum.SendAddonMessageResult.AddonMessageThrottle

local function PumpQueue()
    local item = sendQueue[1]
    if not item then
        sending = false
        return
    end
    local result = C_ChatInfo.SendAddonMessage(PREFIX, item.text, "WHISPER",
        item.target)
    if THROTTLED and result == THROTTLED then
        C_Timer.After(1, PumpQueue)
        return
    end
    table.remove(sendQueue, 1)
    C_Timer.After(0.1, PumpQueue)
end

local function Send(target, text)
    if #sendQueue >= MAX_CHUNKS * 2 then return end
    sendQueue[#sendQueue + 1] = {target = target, text = text}
    if not sending then
        sending = true
        PumpQueue()
    end
end

local recentRequests = {}

local function OnRequest(sender, id)
    local key = sender .. ":" .. id
    local now = GetTime()
    if recentRequests[key] and now - recentRequests[key] < 5 then return end
    recentRequests[key] = now

    local entry = Store()[id]
    if not entry then
        Send(sender, "N:" .. id)
        return
    end
    local encoded = entry.encoded
    local total = math.ceil(#encoded / CHUNK_SIZE)
    for i = 1, total do
        local chunk = encoded:sub((i - 1) * CHUNK_SIZE + 1, i * CHUNK_SIZE)
        Send(sender, string.format("D:%s:%d:%d:%s", id, i, total, chunk))
    end
end

local pending = {}
local received = {}

local function Finish(key, payload, err)
    local request = pending[key]
    if not request then return end
    pending[key] = nil
    if request.timer then request.timer:Cancel() end
    if payload then received[key] = payload end
    request.callback(payload, err)
end

local function RestartTimeout(key, owner)
    local request = pending[key]
    if request.timer then request.timer:Cancel() end
    request.timer = C_Timer.NewTimer(REQUEST_TIMEOUT, function()
        Finish(key, nil, string.format(
            "%s did not respond. They need to be online with Fitter enabled.",
            owner))
    end)
end

local function OnChunk(sender, id, index, total, chunk)
    local key = sender .. ":" .. id
    local request = pending[key]
    if not request or total < 1 or total > MAX_CHUNKS
        or index < 1 or index > total then return end
    if request.total and request.total ~= total then return end
    request.total = total
    if not request.chunks[index] then
        request.chunks[index] = chunk
        request.count = request.count + 1
    end
    if request.count < total then
        RestartTimeout(key, sender)
        return
    end
    Finish(key, DecodeShare(table.concat(request.chunks)))
end

-- Calls callback(payload) or callback(nil, message), possibly immediately.
function OutfitShare.Fetch(owner, id, callback)
    local entry = Store()[id]
    if entry then
        callback(DecodeShare(entry.encoded))
        return
    end
    if owner == PlayerFullName() then
        callback(nil, "This shared outfit is no longer saved.")
        return
    end
    local key = owner .. ":" .. id
    if received[key] then
        callback(received[key])
        return
    end
    if pending[key] then
        pending[key].callback = callback
        return
    end
    pending[key] = {callback = callback, chunks = {}, count = 0}
    RestartTimeout(key, owner)
    Send(owner, "R:" .. id)
end

local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix ~= PREFIX or channel ~= "WHISPER"
        or not IsReadable(message) or not IsReadable(sender) then return end
    sender = FullName(sender)
    local id = message:match("^R:(%w+)$")
    if id then
        OnRequest(sender, id)
        return
    end
    id = message:match("^N:(%w+)$")
    if id then
        Finish(sender .. ":" .. id, nil, string.format(
            "%s no longer has this outfit configuration.", sender))
        return
    end
    local index, total, chunk
    id, index, total, chunk = message:match("^D:(%w+):(%d+):(%d+):(.+)$")
    if id then OnChunk(sender, id, tonumber(index), tonumber(total), chunk) end
end)
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

---------------------------------------------------------------------------
-- Chat links
---------------------------------------------------------------------------

local function ChatFilter(_, event, message, author, ...)
    if not IsReadable(message) or not IsReadable(author)
        or not message:find("[Fitter: ", 1, true) then
        return false
    end
    -- For whispers you send, the author argument is the recipient.
    local owner = event == "CHAT_MSG_WHISPER_INFORM" and PlayerFullName()
        or FullName(author)
    if not owner then return false end
    local linked = message:gsub(TOKEN_PATTERN, function(name, id)
        return string.format("|c%s|Haddon:%s:outfit:%s:%s|h[Fitter: %s]|h|r",
            LINK_COLOR, addonName, owner, id, name)
    end)
    return false, linked, author, ...
end

local addFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter
    or ChatFrame_AddMessageEventFilter
if addFilter then
    for _, event in ipairs(CHAT_EVENTS) do addFilter(event, ChatFilter) end
end

if EventRegistry then
    EventRegistry:RegisterCallback("SetItemRef", function(_, link, text)
        if type(link) ~= "string" then return end
        local owner, id = link:match("^addon:" .. addonName .. ":outfit:([^:]+):(%w+)$")
        if owner and ns.OutfitShareUI then
            local name = type(text) == "string" and text:match("%[Fitter: (.-)%]")
            ns.OutfitShareUI.Open(owner, id, name)
        end
    end)
end
