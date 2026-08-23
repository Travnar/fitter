local addonName, ns = ...

local Emote = {}
ns.Emote = Emote

local state = {
    mounted = false,
    resting = false,
    afk = false,
    eating = false,
    drinking = false,
    hearthstoneSpellIDs = { [8690] = true },
    lastTriggerAt = {},
    consumptionBySpellID = {},
}

local ZONE_EMOTE_MIN_DELAY = 180
local ZONE_EMOTE_MAX_DELAY = 300
local AFK_EMOTE_MIN_DELAY = 180
local AFK_EMOTE_MAX_DELAY = 300
local biomeKeysByMapID = {}
for _, biome in ipairs(ns.Constants.BIOME_GROUPS or {}) do
    for _, mapID in ipairs(biome.mapIDs or {}) do
        biomeKeysByMapID[mapID] = biomeKeysByMapID[mapID] or {}
        biomeKeysByMapID[mapID][biome.key] = true
    end
end

local builtInEmoteTokens

-- Combat-related API results can be secret in WoW 12.0.  Secret values may
-- be passed through, but addons cannot compare them or use them as table keys.
local function CanAccessValue(value)
    if canaccessvalue then return canaccessvalue(value) end
    return not issecretvalue or not issecretvalue(value)
end

local CONSUMPTION_KEYWORDS = {
    enUS = { eating = { "eating", "food" }, drinking = { "drinking", "drink" } },
    enGB = { eating = { "eating", "food" }, drinking = { "drinking", "drink" } },
    deDE = { eating = { "essen", "nahrung" }, drinking = { "trinken", "getränk" } },
    frFR = { eating = { "mange", "nourriture" }, drinking = { "boit", "boisson" } },
    esES = { eating = { "comiendo", "comida" }, drinking = { "bebiendo", "bebida" } },
    esMX = { eating = { "comiendo", "comida" }, drinking = { "bebiendo", "bebida" } },
    itIT = { eating = { "mangi", "cibo" }, drinking = { "bevi", "bevanda" } },
    ptBR = { eating = { "comendo", "comida" }, drinking = { "bebendo", "bebida" } },
    ruRU = { eating = { "едите", "пища" }, drinking = { "пьете", "напиток" } },
    koKR = { eating = { "음식", "먹" }, drinking = { "음료", "마시" } },
    zhCN = { eating = { "食物", "进食" }, drinking = { "饮料", "喝" } },
    zhTW = { eating = { "食物", "進食" }, drinking = { "飲料", "喝" } },
}

local consumptionKeywords = CONSUMPTION_KEYWORDS[GetLocale()]
    or CONSUMPTION_KEYWORDS.enUS

local function AddGlobalKeyword(target, globalName)
    local value = _G[globalName]
    if type(value) == "string" and value ~= "" then
        target[#target + 1] = value
    end
end
AddGlobalKeyword(consumptionKeywords.eating, "FOOD")
AddGlobalKeyword(consumptionKeywords.drinking, "DRINK")

local function GetDisplayName(command, token)
    local name = command and command:match("^/([^%s]+)") or token:lower()
    return name:gsub("^%l", string.upper)
end

local function BuildBuiltInEmotes()
    local catalog, tokens, seenTokens = {}, {}, {}
    local icons = ns.Constants.DEFAULT_EMOTE_ICONS or {}
    local info = ns.Constants.DEFAULT_EMOTE_INFO or {}
    local animations = ns.Constants.DEFAULT_EMOTE_ANIMATIONS or {}
    local requiresStill = ns.Constants.DEFAULT_EMOTES_REQUIRE_STILL or {}
    local usedIcons, fallbackIcon = {}, 134401

    for _, icon in pairs(icons) do usedIcons[icon] = true end

    local function GetFallbackIcon()
        while usedIcons[fallbackIcon] do
            fallbackIcon = fallbackIcon + 1
        end
        local icon = fallbackIcon
        usedIcons[icon] = true
        fallbackIcon = fallbackIcon + 1
        return icon
    end

    for index = 1, (MAXEMOTEINDEX or 1000) do
        local prefix = "EMOTE" .. index
        local token = _G[prefix .. "_TOKEN"]
        if token then
            local tokenKey = token:lower()
            tokens[tokenKey] = token
            local primaryCommand
            for commandIndex = 1, 2 do
                local command = _G[prefix .. "_CMD" .. commandIndex]
                local commandName = command and command:match("^/([^%s]+)")
                if commandName then
                    primaryCommand = primaryCommand or command
                    tokens[commandName:lower()] = token
                end
            end

            if not seenTokens[token] then
                seenTokens[token] = true
                local commandKey = primaryCommand
                    and primaryCommand:match("^/([^%s]+)")
                commandKey = commandKey and commandKey:lower()
                local icon = icons[tokenKey] or icons[commandKey]
                    or GetFallbackIcon()
                local metadata = info[tokenKey] or info[commandKey] or {}
                catalog[#catalog + 1] = {
                    id = tokenKey,
                    name = GetDisplayName(primaryCommand, token),
                    command = token,
                    slashCommand = primaryCommand,
                    icon = icon,
                    example = metadata.example,
                    animation = metadata.animation == true,
                    previewAnimationID = animations[tokenKey]
                        or animations[commandKey],
                    requiresStill = requiresStill[tokenKey] == true
                        or requiresStill[commandKey] == true,
                    voiceline = metadata.voiceline == true,
                }
            end
        end
    end

    builtInEmoteTokens = tokens
    return catalog
end

Emote.DEFAULTS = BuildBuiltInEmotes()

-- Accept a FileDataID, a numeric string, a short icon name such as "thumbup",
-- or a complete Interface/Icons path.
function Emote.ResolveIcon(icon)
    if type(icon) == "number" then return icon end
    if type(icon) ~= "string" or icon == "" then return nil end

    local numericID = tonumber(icon)
    if numericID then return numericID end

    local normalized = icon:lower():gsub("\\", "/")
        :gsub("^interface/icons/", ""):gsub("%.blp$", "")
    return "Interface\\Icons\\" .. normalized
end

local function FindCustomEmote(id)
    for _, entry in ipairs(FitterCharacterSaved and FitterCharacterSaved.CustomEmotes or {}) do
        if entry.id == id then return entry end
    end
    for _, entry in ipairs(FitterSaved and FitterSaved.CustomEmotes or {}) do
        if entry.id == id then return entry end
    end
end

function Emote.GetDefinition(id)
    for _, entry in ipairs(Emote.DEFAULTS) do
        if entry.id == id then return entry end
    end
    return FindCustomEmote(id)
end

function Emote.GetCatalog()
    local result = {}
    for _, entry in ipairs(Emote.DEFAULTS) do result[#result + 1] = entry end
    for _, entry in ipairs(FitterSaved and FitterSaved.CustomEmotes or {}) do
        result[#result + 1] = entry
    end
    for _, entry in ipairs(FitterCharacterSaved and FitterCharacterSaved.CustomEmotes or {}) do
        result[#result + 1] = entry
    end
    return result
end

local function Trim(text)
    return type(text) == "string"
        and text:match("^%s*(.-)%s*$")
        or ""
end

local function GetBuiltInEmoteToken(text)
    local command = text:match("^/([^%s]+)%s*$")
    if not command then return nil end

    return builtInEmoteTokens[command:lower()]
end

function Emote.IsBuiltInCommand(text)
    return GetBuiltInEmoteToken(Trim(text)) ~= nil
end

local function GetActiveOutfitData()
    local outfitID = C_TransmogOutfitInfo
        and C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    if not outfitID or not FitterCharacterSaved then return nil end
    return FitterCharacterSaved["Outfit" .. outfitID]
end

local function HasCondition(condition)
    local outfitData = GetActiveOutfitData()
    local entries = outfitData and outfitData.Emotes
    if type(entries) ~= "table" then return false end
    for _, assignment in pairs(entries) do
        local conditions = type(assignment) == "table"
            and assignment.conditions
        if type(conditions) == "table" then
            if conditions[condition] == true then return true end
            if condition == "BIOMES" and type(conditions.BIOMES) == "table"
                and next(conditions.BIOMES) then return true end
            if condition:find("^TARGET_")
                and type(conditions.SOCIAL) == "table"
                and conditions.SOCIAL[condition] then return true end
        end
    end
    return false
end

local function HasAnyCondition(...)
    for index = 1, select("#", ...) do
        if HasCondition(select(index, ...)) then return true end
    end
    return false
end

function Emote.IsConditionConfigured(condition)
    return HasCondition(condition)
end

function Emote.IsAnyConditionConfigured(...)
    return HasAnyCondition(...)
end

function Emote.Trigger(condition, activeBiomeKeys)
    local outfitData = GetActiveOutfitData()
    local entries = outfitData and outfitData.Emotes
    if type(entries) ~= "table" then return end

    local candidates = {}
    for id, assignment in pairs(entries) do
        local conditions = type(assignment) == "table"
            and assignment.conditions
        local matches = type(conditions) == "table"
            and conditions[condition] == true
        if condition == "BIOMES" and type(conditions) == "table"
            and type(conditions.BIOMES) == "table" then
            for biomeKey in pairs(activeBiomeKeys or {}) do
                if conditions.BIOMES[biomeKey] then
                    matches = true
                    break
                end
            end
        elseif type(conditions) == "table"
            and type(conditions.SOCIAL) == "table"
            and conditions.SOCIAL[condition] then
            matches = true
        end
        if matches then
            local definition = Emote.GetDefinition(id)
            if definition then
                candidates[#candidates + 1] = {
                    definition = definition,
                    ignoreTarget = assignment.ignoreTarget == true,
                }
            end
        end
    end
    if #candidates == 0 then return end

    local now = GetTime()
    local globalCooldown = tonumber(
        FitterSaved and FitterSaved.EmoteGlobalCooldown) or 25
    globalCooldown = math.max(5, math.min(60, globalCooldown))
    if now - (state.lastEmoteAt or 0) < globalCooldown then return end

    -- Some state events can arrive more than once during the same transition.
    if now - (state.lastTriggerAt[condition] or 0) < 0.5 then return end
    state.lastTriggerAt[condition] = now
    state.lastEmoteAt = now

    local candidate = candidates[math.random(#candidates)]
    local emote = candidate.definition
    local unit = candidate.ignoreTarget and "none" or nil
    if emote.command and DoEmote then
        -- Resolve the built-in entry's actual slash command through the same
        -- path used by custom entries such as text="/pray". The display ID is
        -- based on Blizzard's token and is not necessarily the command key.
        local token = GetBuiltInEmoteToken(emote.slashCommand or "")
            or emote.command
        pcall(DoEmote, token, unit)
    else
        local text = Trim(emote.text)
        local builtInToken = GetBuiltInEmoteToken(text)
        if builtInToken and DoEmote then
            pcall(DoEmote, builtInToken, unit)
        else
            local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
            if text ~= "" and send then pcall(send, text, "EMOTE") end
        end
    end
end

local function ScheduleAFKEmote()
    if not HasCondition("AFK_START") then return end
    if state.afkEmoteTimer then state.afkEmoteTimer:Cancel() end
    state.afkEmoteTimer = C_Timer.NewTimer(
        math.random(AFK_EMOTE_MIN_DELAY, AFK_EMOTE_MAX_DELAY), function()
            state.afkEmoteTimer = nil
            if not state.afk or UnitIsAFK("player") ~= true then return end
            Emote.Trigger("AFK_START")
            ScheduleAFKEmote()
        end)
end

local function GetTooltipConsumptionTypes(auraIndex, spellID)
    if not CanAccessValue(spellID) then spellID = nil end
    local cached = spellID and state.consumptionBySpellID[spellID]
    if cached then return cached.eating, cached.drinking end
    if not C_TooltipInfo or not C_TooltipInfo.GetUnitBuff then
        return false, false
    end
    local ok, tooltip = pcall(C_TooltipInfo.GetUnitBuff, "player", auraIndex)
    if not ok then return false, false end
    local eating, drinking = false, false
    for _, line in ipairs(tooltip and tooltip.lines or {}) do
        local text
        if type(line.leftText) == "string" then
            local textOK, lowered = pcall(string.lower, line.leftText)
            if textOK then text = lowered end
        end
        if text then
            for _, keyword in ipairs(consumptionKeywords.eating) do
                local okKeyword, lowered = pcall(string.lower, keyword)
                lowered = okKeyword and lowered or keyword
                if text:find(lowered, 1, true) then eating = true; break end
            end
            for _, keyword in ipairs(consumptionKeywords.drinking) do
                local okKeyword, lowered = pcall(string.lower, keyword)
                lowered = okKeyword and lowered or keyword
                if text:find(lowered, 1, true) then drinking = true; break end
            end
        end
    end
    if spellID then
        state.consumptionBySpellID[spellID] = {
            eating = eating,
            drinking = drinking,
        }
    end
    return eating, drinking
end

local function GetConsumptionState()
    if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then
        return false, false, {}
    end
    local eating, drinking = false, false
    local consumptionAuraIDs = {}
    for index = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", index, "HELPFUL")
        if not aura then break end
        local auraEating, auraDrinking = GetTooltipConsumptionTypes(
            index, aura.spellId)
        eating = eating or auraEating
        drinking = drinking or auraDrinking
        if (auraEating or auraDrinking)
            and CanAccessValue(aura.auraInstanceID)
            and aura.auraInstanceID then
            consumptionAuraIDs[aura.auraInstanceID] = true
        end
    end
    return eating, drinking, consumptionAuraIDs
end

function Emote.RefreshRuntimeState()
    state.mounted = IsMounted() == true
    state.resting = IsResting() == true
    state.afk = UnitIsAFK("player") == true

    local tracksAFK = HasCondition("AFK_START")
    if state.afk and tracksAFK then
        if not state.afkEmoteTimer then ScheduleAFKEmote() end
    elseif state.afkEmoteTimer then
        state.afkEmoteTimer:Cancel()
        state.afkEmoteTimer = nil
    end

    local tracksConsumption = HasAnyCondition(
        "EATING_START", "EATING_END", "DRINKING_START", "DRINKING_END")
    if tracksConsumption then
        state.eating, state.drinking, state.consumptionAuraIDs =
            GetConsumptionState()
    else
        if state.auraUpdateTimer then
            state.auraUpdateTimer:Cancel()
            state.auraUpdateTimer = nil
        end
        state.eating = false
        state.drinking = false
        state.consumptionAuraIDs = {}
    end

    if HasCondition("HEARTHSTONE_USED") then
        Emote.RefreshHearthstoneSpells()
    else
        state.hearthstoneSpellIDs = {}
    end

    Emote.OnZoneChanged()
end

Emote.InitializeState = Emote.RefreshRuntimeState

function Emote.OnPlayerTargetChanged()
    if not HasAnyCondition("TARGET_FRIENDLY_PLAYER", "TARGET_HOSTILE_NPC",
        "TARGET_FRIENDLY_NPC") then return end
    if not UnitExists("target") then return end
    if UnitIsPlayer("target") and UnitIsFriend("player", "target") then
        Emote.Trigger("TARGET_FRIENDLY_PLAYER")
    elseif not UnitIsPlayer("target") then
        if UnitCanAttack("player", "target") then
            Emote.Trigger("TARGET_HOSTILE_NPC")
        elseif UnitIsFriend("player", "target")
            or (UnitReaction("player", "target") or 0) >= 5 then
            Emote.Trigger("TARGET_FRIENDLY_NPC")
        end
    end
end

function Emote.OnMountChanged()
    if not HasAnyCondition("MOUNTED", "DISMOUNTED") then
        state.mounted = IsMounted() == true
        return
    end
    local mounted = IsMounted() == true
    if mounted ~= state.mounted then
        state.mounted = mounted
        Emote.Trigger(mounted and "MOUNTED" or "DISMOUNTED")
    end
end

function Emote.OnRestingChanged()
    if not HasAnyCondition("RESTING_START", "RESTING_END") then
        state.resting = IsResting() == true
        return
    end
    local resting = IsResting() == true
    if resting ~= state.resting then
        state.resting = resting
        Emote.Trigger(resting and "RESTING_START" or "RESTING_END")
    end
end

function Emote.OnPlayerFlagsChanged()
    if not HasCondition("AFK_START") then
        state.afk = UnitIsAFK("player") == true
        if state.afkEmoteTimer then
            state.afkEmoteTimer:Cancel()
            state.afkEmoteTimer = nil
        end
        return
    end
    local afk = UnitIsAFK("player") == true
    if afk ~= state.afk then
        state.afk = afk
        if afk then
            Emote.Trigger("AFK_START")
            ScheduleAFKEmote()
        elseif state.afkEmoteTimer then
            state.afkEmoteTimer:Cancel()
            state.afkEmoteTimer = nil
        end
    end
end

local function ApplyConsumptionState()
    local eating, drinking, consumptionAuraIDs = GetConsumptionState()
    state.consumptionAuraIDs = consumptionAuraIDs
    if eating ~= state.eating then
        state.eating = eating
        Emote.Trigger(eating and "EATING_START" or "EATING_END")
    end
    if drinking ~= state.drinking then
        state.drinking = drinking
        Emote.Trigger(drinking and "DRINKING_START" or "DRINKING_END")
    end
end

local function ContainsConsumptionAura(auraInstanceIDs)
    local tracked = state.consumptionAuraIDs
    if not tracked then return false end
    for _, auraInstanceID in ipairs(auraInstanceIDs or {}) do
        if CanAccessValue(auraInstanceID) and tracked[auraInstanceID] then
            return true
        end
    end
    return false
end

function Emote.OnAurasChanged(updateInfo)
    if not HasAnyCondition("EATING_START", "EATING_END",
        "DRINKING_START", "DRINKING_END") then return end
    -- Incremental UNIT_AURA updates are commonly emitted for unrelated buffs.
    -- An added aura might be food or drink, while an update/removal matters only
    -- when it belongs to a consumption aura found by the previous scan.
    if updateInfo and not updateInfo.isFullUpdate
        and not (updateInfo.addedAuras and #updateInfo.addedAuras > 0)
        and not ContainsConsumptionAura(updateInfo.updatedAuraInstanceIDs)
        and not ContainsConsumptionAura(updateInfo.removedAuraInstanceIDs) then
        return
    end
    -- UNIT_AURA can fire several times in one frame. Coalesce bursts and rely
    -- on the per-spell cache to avoid repeated tooltip construction.
    if state.auraUpdateTimer then return end
    state.auraUpdateTimer = C_Timer.NewTimer(0.1, function()
        state.auraUpdateTimer = nil
        ApplyConsumptionState()
    end)
end

function Emote.RefreshHearthstoneSpells()
    if not HasCondition("HEARTHSTONE_USED") then return end
    local spellIDs = { [8690] = true }
    for _, entry in ipairs(ns.Constants.KNOWN_HEARTHSTONES or {}) do
        local _, spellID = GetItemSpell(entry.id)
        if spellID and CanAccessValue(spellID) then spellIDs[spellID] = true end
    end
    state.hearthstoneSpellIDs = spellIDs
end

function Emote.OnSpellcastStarted(spellID)
    if not HasCondition("HEARTHSTONE_USED") then return end
    if spellID and CanAccessValue(spellID)
        and state.hearthstoneSpellIDs[spellID] then
        Emote.Trigger("HEARTHSTONE_USED")
    end
end

local function ScheduleZoneEmote(mapID)
    if state.zoneEmoteTimer then state.zoneEmoteTimer:Cancel() end
    state.zoneEmoteTimer = C_Timer.NewTimer(
        math.random(ZONE_EMOTE_MIN_DELAY, ZONE_EMOTE_MAX_DELAY), function()
            state.zoneEmoteTimer = nil
            local currentMapID = C_Map and C_Map.GetBestMapForUnit("player")
            local biomeKeys = currentMapID and biomeKeysByMapID[currentMapID]
            if currentMapID ~= mapID or not biomeKeys then return end
            Emote.Trigger("BIOMES", biomeKeys)
            ScheduleZoneEmote(mapID)
        end)
end

function Emote.OnZoneChanged()
    if not HasCondition("BIOMES") then
        state.zoneEmoteMapID = nil
        if state.zoneEmoteTimer then
            state.zoneEmoteTimer:Cancel()
            state.zoneEmoteTimer = nil
        end
        return
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit("player")
    if mapID == state.zoneEmoteMapID then return end
    state.zoneEmoteMapID = mapID
    if state.zoneEmoteTimer then
        state.zoneEmoteTimer:Cancel()
        state.zoneEmoteTimer = nil
    end
    local biomeKeys = mapID and biomeKeysByMapID[mapID]
    if not biomeKeys then return end
    Emote.Trigger("BIOMES", biomeKeys)
    ScheduleZoneEmote(mapID)
end
