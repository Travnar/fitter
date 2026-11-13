-- Export and import of this character's Fitter configuration, as a string or
-- spread across FITTER_CONFIG_N account macros.
local addonName, ns = ...

local CharacterExport = {}
ns.CharacterExport = CharacterExport

local Codec = ns.Codec

local FORMAT_VERSION = 1
local MACRO_PREFIX = "FITTER_CONFIG_"
local MACRO_ICON = 134400
-- Macro names are limited to 16 characters, leaving two digits for N.
local MAX_MACROS = 99
-- Bodies are limited to 255 characters; the leading "#" keeps a clicked
-- macro from doing anything.
local MACRO_MARKER = "#"
local CHUNK_SIZE = 250

CharacterExport.MACRO_PREFIX = MACRO_PREFIX

-- Caches and migration markers that describe this character's client state
-- rather than its configuration. They are neither exported nor overwritten.
local LOCAL_KEYS = {
    DefaultHearthstonesResetVersion = true,
    HunterPetStableCatalog = true,
    LastActiveOutfitID = true,
    LastHearthstoneMacroBody = true,
    LastFishingMacroBody = true,
    LastOutfitUpdateMacroBody = true,
}

local function IsOutfitKey(key)
    return type(key) == "string" and key:match("^Outfit%d+$") ~= nil
end

local function SourceName()
    local name = UnitName("player") or "Unknown"
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    return realm and realm ~= "" and (name .. "-" .. realm) or name
end

function CharacterExport.Export()
    local data = {}
    for key, value in pairs(FitterCharacterSaved or {}) do
        if not LOCAL_KEYS[key] then
            if IsOutfitKey(key) and type(value) == "table" then
                -- The situation baseline records Blizzard situation state
                -- for this character's outfits, so it stays local.
                local outfit = {}
                for field, fieldValue in pairs(value) do
                    if field ~= "SituationBaseline" then outfit[field] = fieldValue end
                end
                value = outfit
            end
            data[key] = value
        end
    end
    return Codec.Encode({
        version = FORMAT_VERSION,
        source = SourceName(),
        data = data,
    })
end

-- Returns the decoded export, or nil and an error message.
function CharacterExport.Decode(text)
    local payload, err = Codec.Decode(text)
    if not payload then return nil, err end
    if type(payload) ~= "table" or type(payload.data) ~= "table" then
        return nil, "This is not a Fitter character export."
    end
    if payload.version ~= FORMAT_VERSION then
        return nil, "This export was made by a different version of Fitter."
    end
    for key, value in pairs(payload.data) do
        if type(key) ~= "string" or LOCAL_KEYS[key]
            or (IsOutfitKey(key) and type(value) ~= "table") then
            payload.data[key] = nil
        end
    end
    return payload
end

-- Replaces this character's configuration with a decoded export.
function CharacterExport.Apply(payload)
    FitterCharacterSaved = FitterCharacterSaved or {}
    local saved = FitterCharacterSaved

    local baselines = {}
    local replaced = {}
    for key, value in pairs(saved) do
        if not LOCAL_KEYS[key] then
            replaced[#replaced + 1] = key
            if IsOutfitKey(key) and type(value) == "table" then
                baselines[key] = value.SituationBaseline
            end
        end
    end
    for _, key in ipairs(replaced) do saved[key] = nil end

    for key, value in pairs(payload.data) do
        saved[key] = value
        if IsOutfitKey(key) then value.SituationBaseline = baselines[key] end
    end

    saved.CustomEmotes = type(saved.CustomEmotes) == "table" and saved.CustomEmotes or {}
    saved.Loadouts = type(saved.Loadouts) == "table" and saved.Loadouts or {}
    if C_TransmogOutfitInfo then
        for _, info in ipairs(C_TransmogOutfitInfo.GetOutfitsInfo() or {}) do
            ns.Fitter:CreateEmptyOutfit(info.outfitID)
        end
    end
end

local function MacroName(index)
    return MACRO_PREFIX .. index
end

local function IsAccountMacro(index)
    return index > 0 and index <= ns.Macro.MAX_ACCOUNT_MACROS
end

local function RefreshMacroFrame()
    if MacroFrame and MacroFrame:IsShown() and MacroFrame.Update then
        pcall(MacroFrame.Update, MacroFrame)
    end
end

-- Number of sequential FITTER_CONFIG_N macros that currently exist.
function CharacterExport.CountMacros()
    local count = 0
    while GetMacroIndexByName(MacroName(count + 1)) > 0 do
        count = count + 1
    end
    return count
end

-- Returns true and the number of macros written, or false and a message.
function CharacterExport.WriteMacros(text)
    if InCombatLockdown() then
        return false, "Macros cannot be changed in combat."
    end

    local chunks = {}
    for i = 1, #text, CHUNK_SIZE do
        chunks[#chunks + 1] = text:sub(i, i + CHUNK_SIZE - 1)
    end
    local count = #chunks
    if count > MAX_MACROS then
        return false, string.format(
            "The export needs %d macros, but at most %d can be created. Use Generate Character Export String instead.",
            count, MAX_MACROS)
    end

    -- Existing FITTER_CONFIG_N account macros are overwritten, so they count
    -- as available space.
    local reusable = 0
    local slot = 1
    local index = GetMacroIndexByName(MacroName(slot))
    while index > 0 do
        if IsAccountMacro(index) then reusable = reusable + 1 end
        slot = slot + 1
        index = GetMacroIndexByName(MacroName(slot))
    end
    local available = ns.Macro.MAX_ACCOUNT_MACROS - GetNumMacros() + reusable
    if count > available then
        return false, string.format(
            "Not enough account macro space.\n\nThe export needs %d macros but only %d are available. Delete %d account macro(s) and try again, or use Generate Character Export String instead.",
            count, available, count - available)
    end

    for i, chunk in ipairs(chunks) do
        local name = MacroName(i)
        local body = MACRO_MARKER .. chunk
        local existing = GetMacroIndexByName(name)
        if IsAccountMacro(existing) then
            EditMacro(existing, name, MACRO_ICON, body)
        else
            -- A character macro with this name could not be read by other
            -- characters, so it is replaced with an account macro.
            if existing > 0 then DeleteMacro(existing) end
            CreateMacro(name, MACRO_ICON, body, false)
        end
    end

    -- Remove leftovers from an earlier, longer export.
    local stale = count + 1
    while GetMacroIndexByName(MacroName(stale)) > 0 do
        DeleteMacro(MacroName(stale))
        stale = stale + 1
    end

    RefreshMacroFrame()
    return true, count
end

-- Returns the joined macro text and the number of macros read, or nil and a
-- message.
function CharacterExport.ReadMacros()
    local parts = {}
    local index = GetMacroIndexByName(MacroName(1))
    while index > 0 do
        local body = (GetMacroBody(index) or ""):gsub("%s+", "")
        parts[#parts + 1] = body:gsub("^" .. MACRO_MARKER, "")
        index = GetMacroIndexByName(MacroName(#parts + 1))
    end
    if #parts == 0 then
        return nil, string.format("No %s1 macro was found.", MACRO_PREFIX)
    end
    return table.concat(parts), #parts
end

function CharacterExport.DeleteMacros()
    if InCombatLockdown() then return false end
    local index = 1
    while GetMacroIndexByName(MacroName(index)) > 0 do
        DeleteMacro(MacroName(index))
        index = index + 1
    end
    RefreshMacroFrame()
    return true
end
