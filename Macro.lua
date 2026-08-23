local addonName, ns = ...

local Macro = {}
ns.Macro = Macro

-- Constants (exposed for sub-modules)
Macro.MOUNT_MACRO_NAME = "FitterMount"
Macro.MOUNT_MACRO_ICON = 1769015
Macro.HEARTHSTONE_MACRO_NAME = "FitterHearthstone"
Macro.HEARTHSTONE_MACRO_ICON = 134414
Macro.DEFAULT_HEARTHSTONE_ITEM_ID = 6948
Macro.MAX_ACCOUNT_MACROS = 120
Macro.MAX_CHARACTER_MACROS = 18
Macro.OUTFIT_UPDATE_MACRO_NAME = "Fitter Update"
Macro.OUTFIT_UPDATE_MACRO_ICON = 4624566

Macro.DRUID_MACRO_BODY = "/stopmacro [flying,combat]\n"
    .. "/run FitM()\n"
    .. "/cast [indoors,noform:2]Cat Form;"
    .. "[nocombat,outdoors,advflyable,noform:3][swimming,noform:3]Travel Form;"
    .. "[outdoors,noform:3]Mount Form"

Macro.SHAMAN_MACRO_BODY = "/stopmacro [flying,combat]\n"
    .. "/run FitM()\n"
    .. "/cast [noform:1]Ghost Wolf"

local function GetUserAdditions(macroName, lastGenerated)
    if not lastGenerated then return nil end
    local index = GetMacroIndexByName(macroName)
    if not index or index == 0 then return nil end
    local currentBody = GetMacroBody(index)
    if not currentBody or currentBody == lastGenerated then return nil end

    -- Try to find the last-generated body as a contiguous substring
    local startIdx, endIdx = currentBody:find(lastGenerated, 1, true)
    if startIdx then
        local prefix = currentBody:sub(1, startIdx - 1)
        local suffix = currentBody:sub(endIdx + 1)
        local additions = prefix .. suffix
        if additions ~= "" then return additions end
        return nil
    end

    -- Fallback: line-based diff
    local generatedSet = {}
    for line in lastGenerated:gmatch("[^\n]+") do
        generatedSet[line] = (generatedSet[line] or 0) + 1
    end
    local additions = {}
    for line in currentBody:gmatch("[^\n]+") do
        if generatedSet[line] and generatedSet[line] > 0 then
            generatedSet[line] = generatedSet[line] - 1
        else
            table.insert(additions, line)
        end
    end
    if #additions > 0 then
        return "\n" .. table.concat(additions, "\n")
    end
    return nil
end

local function IsGeneratedToyUseLine(line)
    local toyID = line and line:match("^%s*/use%s+item:(%d+)%s*$")
    return toyID and ns.Toy and ns.Toy.IsCatalogToy(tonumber(toyID)) == true
end

local function StripGeneratedToyAdditions(additions)
    if not additions then return nil end

    local filtered = {}
    for line in additions:gmatch("[^\n]+") do
        if not IsGeneratedToyUseLine(line) then
            table.insert(filtered, line)
        end
    end

    if #filtered == 0 then return nil end
    local text = table.concat(filtered, "\n")
    if additions:sub(1, 1) == "\n" then
        return "\n" .. text
    end
    return text
end

local function CleanPreservedAdditions(macroName, additions)
    if macroName == Macro.MOUNT_MACRO_NAME
        or macroName == Macro.OUTFIT_UPDATE_MACRO_NAME then
        return StripGeneratedToyAdditions(additions)
    end
    return additions
end

function Macro.GetUserAdditionsLength(macroName, storageKey)
    if not FitterCharacterSaved then return 0 end
    if Macro.rebuildForCharacter then return 0 end
    if FitterSaved and FitterSaved.RemoveMacroChangesOnUpdate then return 0 end
    local lastGenerated = FitterCharacterSaved[storageKey]
    local additions = CleanPreservedAdditions(macroName, GetUserAdditions(macroName, lastGenerated))
    if not additions then return 0 end
    -- +1 for the newline separator that ApplyPreservation inserts
    return #additions + 1
end

function Macro.ApplyPreservation(macroName, newBody, storageKey)
    if not FitterCharacterSaved then FitterCharacterSaved = {} end
    local generated = newBody:sub(1, 255)
    local lastGenerated = FitterCharacterSaved[storageKey]
    FitterCharacterSaved[storageKey] = generated

    if Macro.rebuildForCharacter then
        return generated
    end

    if not FitterSaved or FitterSaved.RemoveMacroChangesOnUpdate then
        return generated
    end

    local additions = CleanPreservedAdditions(macroName, GetUserAdditions(macroName, lastGenerated))
    if not additions then return generated end

    local separator = ""
    if additions:sub(1, 1) ~= "\n" and generated:sub(-1) ~= "\n" then
        separator = "\n"
    end
    local available = 255 - #generated - #separator
    if available <= 0 then return generated end
    local preserved = additions:sub(1, available)
    if #additions > available then
        -- Never leave a partial command at the end of a truncated macro.
        preserved = preserved:match("^(.*)\n[^\n]*$") or ""
    end
    if preserved == "" then return generated end
    return generated .. separator .. preserved
end

local function GetOutfitPosition(outfitID)
    if not outfitID or not C_TransmogOutfitInfo or not C_TransmogOutfitInfo.GetOutfitsInfo then
        return nil
    end
    local outfits = C_TransmogOutfitInfo.GetOutfitsInfo()
    if not outfits then return nil end
    for index, info in ipairs(outfits) do
        if info and info.outfitID == outfitID then
            -- The array can include event entries such as Trial of Style, so its
            -- index is not necessarily the number accepted by /outfit.
            return info.playerFacingOutfitIndex or index
        end
    end
    return nil
end

function Macro.GetOutfitMacroPrefix()
    local outfitID = ns.state.currentZoneOutfitID
    if not outfitID or not C_TransmogOutfitInfo then return "" end

    local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    if activeOutfitID and activeOutfitID == outfitID then return "" end

    if activeOutfitID and C_TransmogOutfitInfo.IsLockedOutfit
        and C_TransmogOutfitInfo.IsLockedOutfit(activeOutfitID) then
        return ""
    end

    local position = GetOutfitPosition(outfitID)
    if not position then return "" end
    return "/outfit " .. position .. "\n"
end

function Macro.ShouldShowMountTooltip()
    return not FitterSaved or FitterSaved.ShowTooltipMount ~= false
end

function Macro.ShouldShowHearthstoneTooltip()
    return not FitterSaved or FitterSaved.ShowTooltipHearthstone ~= false
end

function Macro.IsDruidMacroEnabled()
    return FitterSaved
        and FitterSaved.UseDruidMacro
        and ns.state.playerClass == "DRUID"
end

function Macro.IsShamanMacroEnabled()
    return FitterSaved
        and FitterSaved.UseShamanMacro
        and ns.state.playerClass == "SHAMAN"
end

function Macro.GetModifierCondition()
    if not FitterSaved then return nil end
    local checks, mods = {}, {}
    for _, data in ipairs({
        {"ShiftMountCondition", "IsShiftKeyDown()", "shift"},
        {"AltMountCondition", "IsAltKeyDown()", "alt"},
        {"CtrlMountCondition", "IsControlKeyDown()", "ctrl"},
    }) do
        if FitterSaved[data[1]] == "Ground Mount" then
            checks[#checks + 1], mods[#mods + 1] = data[2], data[3]
        end
    end
    if #checks == 0 then return nil end
    local positive = table.concat(mods, "][mod:")
    local negativeParts = {}
    for _, mod in ipairs(mods) do negativeParts[#negativeParts + 1] = "nomod:" .. mod end
    return table.concat(checks, "or"), positive, table.concat(negativeParts, ",")
end

function Macro.UpdateForCurrentState()
    if InCombatLockdown() then
        if ns.MarkMacroRefreshPending then ns.MarkMacroRefreshPending() end
        return
    end
    ns.state.nextMountToSummon = ns.Mount.SelectNext(false, ns.state.currentZoneOutfitID)
    Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
    Macro.UpdateOutfitUpdateMacro()
end

function Macro.RebuildForCurrentCharacter()
    if InCombatLockdown() then return end

    Macro.rebuildForCharacter = true
    Macro.UpdateHearthstone()
    Macro.UpdateForCurrentState()
    Macro.rebuildForCharacter = false
end
