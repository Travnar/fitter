-- Lua value <-> compact text, compressed when the client supports it and
-- base64 encoded so it survives copy/paste and macro bodies.
--
-- Format: FITTER1:<method><checksum>:<base64>
--   method   : "Z" = zlib via C_EncodingUtil, "R" = raw (no compression available)
--   checksum : 8 hex digits, djb2 of the serialized (uncompressed) data
local addonName, ns = ...

local Codec = {}
ns.Codec = Codec

local type, next, tonumber = type, next, tonumber
local strbyte, strchar, strsub, strfind, strformat =
    string.byte, string.char, string.sub, string.find, string.format
local floor, huge = math.floor, math.huge
local tconcat = table.concat

local HEADER = "FITTER1:"
local MAX_DEPTH = 100

-- Serialized forms:
--   s<len>:<bytes>  string      i<digits>;  integer     d<number>;  float
--   T / F           booleans    N / I / J   nan / +inf / -inf
--   t ... e         table (key, value pairs)
-- Functions, userdata and cyclic references are skipped.
local SERIALIZABLE = {string = true, number = true, boolean = true, table = true}

local function WriteNumber(v, buf)
    if v ~= v then
        buf[#buf + 1] = "N"
    elseif v == huge then
        buf[#buf + 1] = "I"
    elseif v == -huge then
        buf[#buf + 1] = "J"
    elseif v == floor(v) and v > -2 ^ 53 and v < 2 ^ 53 then
        buf[#buf + 1] = "i" .. strformat("%.0f", v) .. ";"
    else
        local s = strformat("%.14g", v)
        if tonumber(s) ~= v then s = strformat("%.17g", v) end
        buf[#buf + 1] = "d" .. s .. ";"
    end
end

local function Write(v, buf, seen, depth)
    local t = type(v)
    if t == "string" then
        buf[#buf + 1] = "s" .. #v .. ":"
        buf[#buf + 1] = v
    elseif t == "number" then
        WriteNumber(v, buf)
    elseif t == "boolean" then
        buf[#buf + 1] = v and "T" or "F"
    elseif t == "table" then
        if seen[v] or depth > MAX_DEPTH then return false end
        seen[v] = true
        buf[#buf + 1] = "t"
        for key, value in next, v do
            if SERIALIZABLE[type(key)] and SERIALIZABLE[type(value)] then
                local mark = #buf
                if not (Write(key, buf, seen, depth + 1)
                    and Write(value, buf, seen, depth + 1)) then
                    for i = #buf, mark + 1, -1 do buf[i] = nil end
                end
            end
        end
        buf[#buf + 1] = "e"
        seen[v] = nil
    else
        return false
    end
    return true
end

local B_s, B_i, B_d, B_T, B_F, B_N, B_I, B_J, B_t, B_e =
    strbyte("sidTFNIJte", 1, 10)

local function Read(s, pos, depth)
    if depth > MAX_DEPTH then error("Data nested too deeply") end
    local c = strbyte(s, pos)
    if c == B_s then
        local colon = strfind(s, ":", pos + 1, true)
        local len = colon and tonumber(strsub(s, pos + 1, colon - 1))
        if not len or colon + len > #s then error("Malformed string") end
        return strsub(s, colon + 1, colon + len), colon + len + 1
    elseif c == B_i or c == B_d then
        local semi = strfind(s, ";", pos + 1, true)
        local n = semi and tonumber(strsub(s, pos + 1, semi - 1))
        if not n then error("Malformed number") end
        return n, semi + 1
    elseif c == B_T then
        return true, pos + 1
    elseif c == B_F then
        return false, pos + 1
    elseif c == B_N then
        return 0 / 0, pos + 1
    elseif c == B_I then
        return huge, pos + 1
    elseif c == B_J then
        return -huge, pos + 1
    elseif c == B_t then
        local tbl = {}
        pos = pos + 1
        while true do
            local nc = strbyte(s, pos)
            if nc == B_e then return tbl, pos + 1 end
            if not nc then error("Unterminated table") end
            local key, value
            key, pos = Read(s, pos, depth + 1)
            value, pos = Read(s, pos, depth + 1)
            if key == nil or key ~= key then error("Invalid table key") end
            tbl[key] = value
        end
    end
    error("Malformed data")
end

local function Serialize(value)
    local buf = {}
    if not Write(value, buf, {}, 0) then error("Value cannot be serialized") end
    return tconcat(buf)
end

local function Deserialize(s)
    local value, pos = Read(s, 1, 0)
    if pos ~= #s + 1 then error("Trailing data") end
    return value
end

local function Checksum(s)
    local h = 5381
    for i = 1, #s do
        h = (h * 33 + strbyte(s, i)) % 4294967296
    end
    return strformat("%08x", h)
end

-- Base64 with the standard alphabet. C_EncodingUtil is used when the client
-- has it; the Lua version produces identical output.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local encTable, decTable = {}, {}
for i = 1, 64 do
    local ch = strsub(B64, i, i)
    encTable[i - 1] = ch
    decTable[strbyte(ch)] = i - 1
end

local function LuaEncodeBase64(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = strbyte(s, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        out[#out + 1] = encTable[floor(n / 262144)]
            .. encTable[floor(n / 4096) % 64]
            .. (b and encTable[floor(n / 64) % 64] or "=")
            .. (c and encTable[n % 64] or "=")
    end
    return tconcat(out)
end

local function LuaDecodeBase64(s)
    s = s:gsub("=+$", "")
    local out = {}
    for i = 1, #s, 4 do
        local d1, d2, d3, d4 = strbyte(s, i, i + 3)
        d1, d2 = decTable[d1], decTable[d2]
        d3, d4 = d3 and decTable[d3], d4 and decTable[d4]
        if not d1 or not d2 then error("Invalid base64 data") end
        local n = d1 * 262144 + d2 * 4096 + (d3 or 0) * 64 + (d4 or 0)
        local a, b, c = floor(n / 65536), floor(n / 256) % 256, n % 256
        if d4 then
            out[#out + 1] = strchar(a, b, c)
        elseif d3 then
            out[#out + 1] = strchar(a, b)
        else
            out[#out + 1] = strchar(a)
        end
    end
    return tconcat(out)
end

local EncodingUtil = C_EncodingUtil
local ZLIB = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Zlib

local function EncodeBase64(s)
    if EncodingUtil and EncodingUtil.EncodeBase64 then
        return EncodingUtil.EncodeBase64(s)
    end
    return LuaEncodeBase64(s)
end

local function DecodeBase64(s)
    if EncodingUtil and EncodingUtil.DecodeBase64 then
        return EncodingUtil.DecodeBase64(s)
    end
    return LuaDecodeBase64(s)
end

function Codec.Encode(value)
    local serialized = Serialize(value)
    local method, body = "R", serialized
    if ZLIB and EncodingUtil and EncodingUtil.CompressString then
        local ok, compressed = pcall(EncodingUtil.CompressString, serialized, ZLIB)
        if ok and compressed then method, body = "Z", compressed end
    end
    return HEADER .. method .. Checksum(serialized) .. ":" .. EncodeBase64(body)
end

-- Returns the value, or nil and an error message.
function Codec.Decode(text)
    if type(text) ~= "string" then return nil, "No data." end
    text = text:gsub("%s+", "")
    local method, checksum, data =
        text:match("^FITTER1:([RZ])(%x%x%x%x%x%x%x%x):(.+)$")
    if not method then return nil, "This is not a Fitter export string." end

    local ok, body = pcall(DecodeBase64, data)
    if not ok or not body then
        return nil, "The export string is corrupt."
    end
    if method == "Z" then
        if not (ZLIB and EncodingUtil and EncodingUtil.DecompressString) then
            return nil, "This client cannot read compressed export strings."
        end
        ok, body = pcall(EncodingUtil.DecompressString, body, ZLIB)
        if not ok or not body then
            return nil, "The export string is incomplete or was altered."
        end
    end
    if Checksum(body) ~= checksum:lower() then
        return nil, "The export string is incomplete or was altered."
    end

    local value
    ok, value = pcall(Deserialize, body)
    if not ok then return nil, "The export string is corrupt." end
    return value
end
