local addonName, ns = ...

local Macro = ns.Macro
local G99_BREAKNECK_SPELL_ID = 1215279
local SOAR_SPELL_ID = 369536
local RUNNING_WILD_SPELL_ID = 87840

local function OutfitGroundMountInfo()
    local outfitID = ns.GetMountOutfitID()
        or (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
            and C_TransmogOutfitInfo.GetActiveOutfitID())
    if not outfitID or outfitID == 0 or not FitterCharacterSaved then return false, false end
    local data = ns.Settings.GetOutfitData(outfitID)
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
    local outfitID = ns.GetMountOutfitID()
        or (C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
            and C_TransmogOutfitInfo.GetActiveOutfitID())
    if not outfitID or outfitID == 0 or not FitterCharacterSaved then return false end
    local data = ns.Settings.GetOutfitData(outfitID)
    if not data or not data.Ground or #data.Ground == 0 then return false end
    local pick = data.Ground[math.random(1, #data.Ground)]
    return pick == "runningwild"
end

-- Returns the #showtooltip line (nil when there is none), the lines that
-- summon the mount, and the macro icon.
local function ResolveMountAction(mountID, showTooltip)
    local icon = Macro.MOUNT_MACRO_ICON

    if mountID ~= "g99breakneck" then
        if Macro.IsDruidMacroEnabled() then return nil, Macro.GetDruidMacroBody(), icon end
        if Macro.IsShamanMacroEnabled() then return nil, Macro.GetShamanMacroBody(), icon end
        if Macro.IsMonkMacroEnabled() then return nil, Macro.GetMonkMacroBody(), icon end
    end

    local checkFn, macroMod, noMacroMod = Macro.GetModifierCondition()

    -- Resolve Running Wild info for ground modifier macro lines
    local groundHasRunningWild, runningWildIsOnly = false, false
    local runningWildName
    if checkFn then
        groundHasRunningWild, runningWildIsOnly = OutfitGroundMountInfo()
        if groundHasRunningWild then
            runningWildName = Macro.SpellName(RUNNING_WILD_SPELL_ID, "Running Wild")
        end
    end

    -- For mixed ground lists, pre-roll whether this macro cycle uses Running Wild
    local useRunningWildForMod = runningWildIsOnly
    if groundHasRunningWild and not runningWildIsOnly then
        useRunningWildForMod = PreRollGroundIsRunningWild()
    end

    local function SpellTooltip(spellID, fallback)
        local info = C_Spell.GetSpellInfo(spellID)
        local spellName = (info and info.name) or fallback
        icon = (info and info.iconID) or icon
        return spellName, showTooltip and ("#showtooltip " .. spellName) or nil
    end

    if mountID == "g99breakneck" then
        local spellName, tooltip = SpellTooltip(G99_BREAKNECK_SPELL_ID, "G-99 Breakneck")
        -- Other conditionals already stopped the macro; only Ground Mount
        -- modifiers reach this point.
        if checkFn then
            return tooltip, "/run if " .. checkFn .. "then FitM()end\n"
                .. "/cast [" .. noMacroMod .. "]" .. spellName, icon
        end
        return tooltip, "/cast " .. spellName, icon
    end

    if mountID == "soar" then
        local spellName, tooltip = SpellTooltip(SOAR_SPELL_ID, "Soar")
        if useRunningWildForMod then
            return tooltip, "/cast [mod:" .. macroMod .. "]" .. runningWildName .. "\n"
                .. "/cast [" .. noMacroMod .. "]" .. spellName, icon
        elseif checkFn then
            return tooltip, "/run if " .. checkFn .. "then FitG()end\n"
                .. "/cast [" .. noMacroMod .. "]" .. spellName, icon
        end
        return tooltip, "/cast " .. spellName, icon
    end

    if mountID == "runningwild" then
        local spellName, tooltip = SpellTooltip(RUNNING_WILD_SPELL_ID, "Running Wild")
        if checkFn and not useRunningWildForMod then
            -- Modifier picked a regular mount this cycle
            return tooltip, "/run if " .. checkFn .. "then FitG()end\n"
                .. "/cast " .. spellName, icon
        end
        return tooltip, "/cast " .. spellName, icon
    end

    -- Regular mount case
    local tooltip
    if mountID and type(mountID) == "number" and showTooltip then
        local name, _, mountIcon = C_MountJournal.GetMountInfoByID(mountID)
        if name then
            tooltip = "#showtooltip " .. name
            icon = mountIcon or icon
        end
    end
    if useRunningWildForMod then
        return tooltip, "/run if not(" .. checkFn .. ")then FitM()end\n"
            .. "/cast [mod:" .. macroMod .. "]" .. runningWildName, icon
    end
    return tooltip, "/run FitM()", icon
end

-- The sections of the mount macro (see Macro.ComposeBody) and its icon.
local function BuildMountSpec(mountID)
    local tooltip, action, icon = ResolveMountAction(mountID, Macro.ShouldShowMountTooltip())
    return {
        tooltip = tooltip,
        -- Conditionals come first so they take precedence over every mount option.
        conditionals = ns.MountConditionals and ns.MountConditionals.GetMacroLines(),
        outfit = Macro.GetOutfitMacroPrefix(),
        action = action,
    }, icon
end

function Macro.BuildMountMacroBody(mountID, includeTooltip)
    local spec, icon = BuildMountSpec(mountID)
    if includeTooltip == false then spec.tooltip = nil end
    return Macro.ComposeBody(spec), icon
end

function Macro.UpdateMacroForMount(mountID, outfitIDOverride)
    if InCombatLockdown() then
        ns.MarkMacroRefreshPending()
        return
    end

    local activeOutfitID = C_TransmogOutfitInfo and C_TransmogOutfitInfo.GetActiveOutfitID
        and C_TransmogOutfitInfo.GetActiveOutfitID()
    local resolvedToyOutfitID = outfitIDOverride or ns.GetMountOutfitID()
        or activeOutfitID or ns.state.outfitUpdateResolvedID

    -- Built once so the macro and the key binding share any random roll.
    local spec, icon = BuildMountSpec(mountID)
    spec.hunterPet = ns.HunterPet and ns.HunterPet.GetMountMacroLines(resolvedToyOutfitID)
    spec.cancel = ns.Toy and ns.Toy.GetCancelLines(resolvedToyOutfitID)
    spec.toys = ns.Toy and ns.Toy.GetMacroLines(resolvedToyOutfitID)

    local index = GetMacroIndexByName(Macro.MOUNT_MACRO_NAME)
    if index and index > 0 and Macro.CanEditMacros() then
        Macro.WriteSpec(index, Macro.MOUNT_MACRO_NAME, spec, "LastMountMacroBody", icon, true)
    end

    -- The keybind is independent of the optional character macro, but its
    -- secure macrotext has the same 255-character limit.
    if ns.MountButton then
        spec.tooltip = nil
        local btnBody = Macro.ComposeBody(spec)
        -- While falling, MountConditionals owns the macrotext and restores this on landing.
        ns.state.mountButtonBody = btnBody
        local fallingActive = ns.MountConditionals and ns.MountConditionals.IsFallingActive()
        if not fallingActive then Macro.SetButtonBody(ns.MountButton, btnBody) end
    end

    if ns.Toy and not ns.state.toyCooldownTimer then
        local cooldownRemaining = ns.Toy.GetEarliestUpdateDelay(resolvedToyOutfitID)
        if cooldownRemaining then
            ns.state.toyCooldownTimer = true
            C_Timer.After(cooldownRemaining + 0.1, function()
                ns.state.toyCooldownTimer = false
                if not InCombatLockdown() and ns.state.nextMountToSummon then
                    ns.Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
                elseif InCombatLockdown() then
                    ns.MarkMacroRefreshPending()
                end
            end)
        end
    end
    ns.Mount.MonitorSoarCooldown()
end

-- Returns the macro index, creating the macro if needed; nil when it cannot
-- be created.
function Macro.EnsureMount()
    Macro.MigrateLegacyNames()
    local index = GetMacroIndexByName(Macro.MOUNT_MACRO_NAME)
    if index and index > 0 then return index end
    if InCombatLockdown() or GetNumMacros() >= Macro.MAX_ACCOUNT_MACROS then
        return nil
    end
    Macro.Create(Macro.MOUNT_MACRO_NAME, Macro.MOUNT_MACRO_ICON, "/run FitM()",
        "LastMountMacroBody")
    Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
    index = GetMacroIndexByName(Macro.MOUNT_MACRO_NAME)
    return index and index > 0 and index or nil
end
