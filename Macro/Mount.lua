local addonName, ns = ...

local Macro = ns.Macro
local G99_BREAKNECK_SPELL_ID = 1215279

local function GetG99ModifierMacroLines()
    if not FitterSaved then return "" end

    local mods = {}
    for _, data in ipairs({
        {"ShiftMountCondition", "shift"},
        {"AltMountCondition", "alt"},
        {"CtrlMountCondition", "ctrl"},
    }) do
        if FitterSaved[data[1]] == "G-99 Breakneck" then
            mods[#mods + 1] = data[2]
        end
    end

    if #mods == 0 then return "" end

    local conditional = "mod:" .. table.concat(mods, "][mod:")
    local info = C_Spell.GetSpellInfo(G99_BREAKNECK_SPELL_ID)
    local spellName = (info and info.name) or "G-99 Breakneck"
    return "/cast [" .. conditional .. "]" .. spellName .. "\n"
        .. "/stopmacro [" .. conditional .. "]\n"
end

local function GetAnyMountModifierCondition()
    if not FitterSaved then return nil end

    local checks, mods = {}, {}
    for _, data in ipairs({
        {"ShiftMountCondition", "IsShiftKeyDown()", "shift"},
        {"AltMountCondition", "IsAltKeyDown()", "alt"},
        {"CtrlMountCondition", "IsControlKeyDown()", "ctrl"},
    }) do
        local condition = FitterSaved[data[1]]
        if condition and condition ~= "None" then
            checks[#checks + 1] = data[2]
            mods[#mods + 1] = data[3]
        end
    end

    if #checks == 0 then return nil end

    local negativeParts = {}
    for _, mod in ipairs(mods) do
        negativeParts[#negativeParts + 1] = "nomod:" .. mod
    end
    return table.concat(checks, "or"), table.concat(negativeParts, ",")
end

local function OutfitGroundMountInfo()
    local outfitID = ns.state.currentZoneOutfitID
        or (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
            and C_TransmogOutfitInfo.GetActiveOutfitID())
    if not outfitID or outfitID == 0 or not FitterCharacterSaved then return false, false end
    local data = FitterCharacterSaved["Outfit"..outfitID]
    if not data or not data.Ground then return false, false end
    local hasRunningWild = false
    local regularCount = 0
    for _, id in ipairs(data.Ground) do
        if id == "runningwild" then
            hasRunningWild = true
        elseif id ~= "soar" then
            regularCount = regularCount + 1
        end
    end
    local isOnlyGround = hasRunningWild and regularCount == 0
    return hasRunningWild, isOnlyGround
end

local function PreRollGroundIsRunningWild()
    local outfitID = ns.state.currentZoneOutfitID
        or (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
            and C_TransmogOutfitInfo.GetActiveOutfitID())
    if not outfitID or outfitID == 0 or not FitterCharacterSaved then return false end
    local data = FitterCharacterSaved["Outfit"..outfitID]
    if not data or not data.Ground or #data.Ground == 0 then return false end
    local pick = data.Ground[math.random(1, #data.Ground)]
    return pick == "runningwild"
end

local function BuildMountMacroBody(mountID, includeTooltip)
    local prefix = Macro.GetOutfitMacroPrefix() .. GetG99ModifierMacroLines()
    local icon = Macro.MOUNT_MACRO_ICON
    local showTooltip = includeTooltip ~= false and Macro.ShouldShowMountTooltip()

    if mountID ~= "g99breakneck" and Macro.IsDruidMacroEnabled() then
        return prefix .. Macro.DRUID_MACRO_BODY, icon
    end
    if mountID ~= "g99breakneck" and Macro.IsShamanMacroEnabled() then
        return prefix .. Macro.SHAMAN_MACRO_BODY, icon
    end

    local checkFn, macroMod, noMacroMod = Macro.GetModifierCondition()

    -- Resolve Running Wild info for ground modifier macro lines
    local groundHasRunningWild, runningWildIsOnly = false, false
    local runningWildName
    if checkFn then
        groundHasRunningWild, runningWildIsOnly = OutfitGroundMountInfo()
        if groundHasRunningWild then
            local info = C_Spell.GetSpellInfo(87840)
            runningWildName = (info and info.name) or "Running Wild"
        end
    end

    -- For mixed ground lists, pre-roll whether this macro cycle uses Running Wild
    local useRunningWildForMod = false
    if groundHasRunningWild and not runningWildIsOnly then
        useRunningWildForMod = PreRollGroundIsRunningWild()
    end

    if mountID == "g99breakneck" then
        local info = C_Spell.GetSpellInfo(G99_BREAKNECK_SPELL_ID)
        local spellName = (info and info.name) or "G-99 Breakneck"
        icon = (info and info.iconID) or icon
        local tooltip = showTooltip and ("#showtooltip " .. spellName .. "\n") or ""
        local anyModifierCheck, noConfiguredModifier = GetAnyMountModifierCondition()
        if anyModifierCheck then
            return tooltip .. prefix
                .. "/run if " .. anyModifierCheck .. "then FitM()end\n"
                .. "/cast [" .. noConfiguredModifier .. "]" .. spellName, icon
        end
        return tooltip .. prefix .. "/cast " .. spellName, icon
    end

    if mountID == "soar" then
        local info = C_Spell.GetSpellInfo(369536)
        local spellName = (info and info.name) or "Soar"
        icon = (info and info.iconID) or icon
        local tooltip = showTooltip and ("#showtooltip " .. spellName .. "\n") or ""
        if runningWildIsOnly then
            return tooltip .. prefix
                .. "/cast [mod:" .. macroMod .. "]" .. runningWildName .. "\n"
                .. "/cast [" .. noMacroMod .. "]" .. spellName, icon
        elseif useRunningWildForMod then
            return tooltip .. prefix
                .. "/cast [mod:" .. macroMod .. "]" .. runningWildName .. "\n"
                .. "/cast [" .. noMacroMod .. "]" .. spellName, icon
        elseif checkFn then
            return tooltip .. prefix
                .. "/run if " .. checkFn .. "then FitG()end\n"
                .. "/cast [" .. noMacroMod .. "]" .. spellName, icon
        end
        return tooltip .. prefix .. "/cast " .. spellName, icon
    end
    if mountID == "runningwild" then
        local info = C_Spell.GetSpellInfo(87840)
        local spellName = (info and info.name) or "Running Wild"
        icon = (info and info.iconID) or icon
        local tooltip = showTooltip and ("#showtooltip " .. spellName .. "\n") or ""
        if checkFn and not runningWildIsOnly and not useRunningWildForMod then
            -- Modifier picked a regular mount this cycle
            return tooltip .. prefix
                .. "/run if " .. checkFn .. "then FitG()end\n"
                .. "/cast " .. spellName, icon
        end
        return tooltip .. prefix .. "/cast " .. spellName, icon
    end

    -- Regular mount case
    local mountTooltip = ""
    if mountID and type(mountID) == "number" and showTooltip then
        local name, _, mountIcon = C_MountJournal.GetMountInfoByID(mountID)
        if name then
            mountTooltip = "#showtooltip " .. name .. "\n"
            icon = mountIcon or icon
        end
    end
    if runningWildIsOnly then
        return mountTooltip .. prefix
            .. "/run if not(" .. checkFn .. ")then FitM()end\n"
            .. "/cast [mod:" .. macroMod .. "]" .. runningWildName, icon
    elseif useRunningWildForMod then
        return mountTooltip .. prefix
            .. "/run if not(" .. checkFn .. ")then FitM()end\n"
            .. "/cast [mod:" .. macroMod .. "]" .. runningWildName, icon
    end
    return mountTooltip .. prefix .. "/run FitM()", icon
end

Macro.BuildMountMacroBody = BuildMountMacroBody

function Macro.UpdateMacroForMount(mountID, outfitIDOverride)
    if InCombatLockdown() then
        if ns.MarkMacroRefreshPending then ns.MarkMacroRefreshPending() end
        return
    end

    local toyOutfitID = ns.state.currentZoneOutfitID
    local activeOutfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    if activeOutfitID and C_TransmogOutfitInfo.IsLockedOutfit
        and C_TransmogOutfitInfo.IsLockedOutfit(activeOutfitID) then
        toyOutfitID = activeOutfitID
    end
    local resolvedToyOutfitID = outfitIDOverride or toyOutfitID
        or activeOutfitID or ns.state.outfitUpdateResolvedID

    local index = GetMacroIndexByName(Macro.MOUNT_MACRO_NAME)
    if index and index > 0 then
        local rawBody, icon = BuildMountMacroBody(mountID)
        local userLen = Macro.GetUserAdditionsLength(Macro.MOUNT_MACRO_NAME, "LastMountMacroBody")
        local remaining = 255 - #rawBody - userLen
        local hunterPetLines = ns.HunterPet
            and ns.HunterPet.GetMountMacroLines(resolvedToyOutfitID)
        if hunterPetLines and remaining > #hunterPetLines + 1 then
            rawBody = hunterPetLines .. "\n" .. rawBody
            remaining = remaining - #hunterPetLines - 1
        end
        local cancelLines = ns.Toy and remaining > 1 and ns.Toy.GetCancelLines(
            resolvedToyOutfitID, remaining - 1)
        if cancelLines then
            remaining = remaining - #cancelLines - 1
        end
        local toyLines = ns.Toy and remaining > 1 and ns.Toy.GetMacroLines(
            resolvedToyOutfitID, remaining - 1)
        if toyLines then
            rawBody = toyLines .. "\n" .. rawBody
        end
        if cancelLines then
            rawBody = cancelLines .. "\n" .. rawBody
        end
        local body = Macro.ApplyPreservation(Macro.MOUNT_MACRO_NAME, rawBody, "LastMountMacroBody")
        local _, currentIcon = GetMacroInfo(index)
        if GetMacroBody(index) ~= body or currentIcon ~= icon then
            EditMacro(index, Macro.MOUNT_MACRO_NAME, icon, body)
        end
    end

    -- The keybind is independent of the optional character macro, but its
    -- secure macrotext has the same 255-character limit.
    if ns.MountButton then
        local btnBody, _ = BuildMountMacroBody(mountID, false)
        local remaining = 255 - #btnBody
        local hunterPetLines = ns.HunterPet
            and ns.HunterPet.GetMountMacroLines(resolvedToyOutfitID)
        if hunterPetLines and remaining > #hunterPetLines + 1 then
            btnBody = hunterPetLines .. "\n" .. btnBody
            remaining = remaining - #hunterPetLines - 1
        end
        local cancelLines = ns.Toy and remaining > 1
            and ns.Toy.GetCancelLines(resolvedToyOutfitID, remaining - 1)
        if cancelLines then remaining = remaining - #cancelLines - 1 end
        local toyLines = ns.Toy and remaining > 1
            and ns.Toy.GetMacroLines(resolvedToyOutfitID, remaining - 1)
        if toyLines then
            btnBody = toyLines .. "\n" .. btnBody
        end
        if cancelLines then
            btnBody = cancelLines .. "\n" .. btnBody
        end
        if ns.MountButton:GetAttribute("macrotext") ~= btnBody then
            ns.MountButton:SetAttribute("macrotext", btnBody)
        end
    end

    if ns.Toy and not ns.state.toyCooldownTimer then
        local cooldownRemaining = ns.Toy.GetEarliestUpdateDelay(resolvedToyOutfitID)
        if cooldownRemaining then
            ns.state.toyCooldownTimer = true
            C_Timer.After(cooldownRemaining + 0.1, function()
                ns.state.toyCooldownTimer = false
                if not InCombatLockdown() and ns.state.nextMountToSummon then
                    ns.Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
                elseif InCombatLockdown() and ns.MarkMacroRefreshPending then
                    ns.MarkMacroRefreshPending()
                end
            end)
        end
    end
    ns.Mount.MonitorSoarCooldown()
end
