local addonName, ns = ...
local L = ns.L

local Macro = ns.Macro
local OUTFIT_UPDATE_BINDING = "CLICK FitterOutfitUpdateButton:LeftButton"
local ACTION = "/run FitU()"
local ACCOUNT_STORAGE_KEY = "LastOutfitUpdateMacroBody"
local CHARACTER_STORAGE_KEY = "LastCharacterOutfitUpdateMacroBody"

local function GetConsumers()
    local accountIndex, characterIndex = Macro.FindIndexes(Macro.OUTFIT_UPDATE_MACRO_NAME)
    local bindingKey = GetBindingKey and GetBindingKey(OUTFIT_UPDATE_BINDING)
    return accountIndex, characterIndex, bindingKey ~= nil
end

function Macro.IsOutfitUpdateUsed()
    local accountIndex, characterIndex, hasBinding = GetConsumers()
    return accountIndex ~= nil or characterIndex ~= nil or hasBinding
end

-- icon is nil to keep the macro's own icon.
local function WriteMacro(index, spec, storageKey, icon)
    local name = Macro.OUTFIT_UPDATE_MACRO_NAME
    local reserved = Macro.GetUserAdditionsLength(name, storageKey, index)
    local body = Macro.ApplyPreservation(name, Macro.ComposeBody(spec, reserved),
        storageKey, index)
    local _, currentIcon = GetMacroInfo(index)
    if GetMacroBody(index) ~= body or (icon and currentIcon ~= icon) then
        EditMacro(index, name, icon, body)
    end
end

function Macro.UpdateOutfitUpdateMacro(outfitIDOverride)
    local accountIndex, characterIndex, hasBinding = GetConsumers()
    if not (accountIndex or characterIndex or hasBinding) then return end
    if InCombatLockdown() then
        ns.MarkMacroRefreshPending()
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
    if outfitIDOverride then
        ns.state.outfitUpdateResolvedID = outfitIDOverride
    elseif resolvedToyOutfitID then
        ns.state.outfitUpdateResolvedID = resolvedToyOutfitID
    end

    local spec = {
        cancel = ns.Toy and ns.Toy.GetCancelLines(resolvedToyOutfitID),
        toys = ns.Toy and ns.Toy.GetMacroLines(resolvedToyOutfitID),
        hunterPet = ns.HunterPet and ns.HunterPet.GetOutfitMacroLines(resolvedToyOutfitID),
        outfit = Macro.GetOutfitMacroPrefix(),
        action = ACTION,
    }

    if (accountIndex or characterIndex) and Macro.CanEditMacros() then
        if accountIndex then
            WriteMacro(accountIndex, spec, ACCOUNT_STORAGE_KEY, Macro.OUTFIT_UPDATE_MACRO_ICON)
        end
        if characterIndex then
            FitterCharacterSaved = FitterCharacterSaved or {}
            -- Through 2.13.0 both macros shared one stored body and only one
            -- of them was updated; the character macro was left as created
            -- when an account macro existed.
            if FitterCharacterSaved[CHARACTER_STORAGE_KEY] == nil then
                FitterCharacterSaved[CHARACTER_STORAGE_KEY] = accountIndex and ACTION
                    or FitterCharacterSaved[ACCOUNT_STORAGE_KEY]
            end
            WriteMacro(characterIndex, spec, CHARACTER_STORAGE_KEY, nil)
        end
    end

    if hasBinding and ns.OutfitUpdateButton then
        local btnBody = Macro.ComposeBody(spec)
        if ns.OutfitUpdateButton:GetAttribute("macrotext") ~= btnBody then
            ns.OutfitUpdateButton:SetAttribute("macrotext", btnBody)
        end
    end

    if ns.Toy and not ns.state.outfitUpdateCooldownTimer then
        local delay = ns.Toy.GetEarliestUpdateDelay(resolvedToyOutfitID)
        if delay then
            ns.state.outfitUpdateCooldownTimer = true
            C_Timer.After(delay + 0.1, function()
                ns.state.outfitUpdateCooldownTimer = false
                if not InCombatLockdown() then
                    Macro.UpdateOutfitUpdateMacro(resolvedToyOutfitID)
                else
                    ns.MarkMacroRefreshPending()
                end
            end)
        end
    end
end

function Macro.EnsureOutfitUpdateMacro()
    if InCombatLockdown() then return end
    Macro.MigrateLegacyNames()
    if Macro.Exists(Macro.OUTFIT_UPDATE_MACRO_NAME, "account") then
        Macro.UpdateOutfitUpdateMacro()
        return
    end
    if GetNumMacros() >= Macro.MAX_ACCOUNT_MACROS then
        print("|cff00ff00Fitter:|r " .. L["Cannot create macro: maximum number of account macros reached."])
        return
    end
    CreateMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, Macro.OUTFIT_UPDATE_MACRO_ICON, ACTION, nil)
    if FitterCharacterSaved then
        FitterCharacterSaved[ACCOUNT_STORAGE_KEY] = ACTION
    end
    if ns.OutfitUpdateButton then
        ns.OutfitUpdateButton:SetAttribute("macrotext", ACTION)
    end
    Macro.UpdateOutfitUpdateMacro()
    print("|cff00ff00Fitter:|r " .. string.format(L["Created macro '%s'."], Macro.OUTFIT_UPDATE_MACRO_NAME))
end

function Macro.EnsureCharacterOutfitUpdateMacro()
    if InCombatLockdown() then return end
    Macro.MigrateLegacyNames()
    local _, numChar = GetNumMacros()
    if Macro.Exists(Macro.OUTFIT_UPDATE_MACRO_NAME, "character") then
        print("|cff00ff00Fitter:|r " .. string.format(L["Character macro '%s' already exists."], Macro.OUTFIT_UPDATE_MACRO_NAME))
        return
    end
    if numChar >= Macro.MAX_CHARACTER_MACROS then
        print("|cff00ff00Fitter:|r " .. L["Cannot create macro: maximum number of character macros reached."])
        return
    end
    CreateMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "INV_Misc_QuestionMark", ACTION, true)
    if FitterCharacterSaved then
        FitterCharacterSaved[CHARACTER_STORAGE_KEY] = ACTION
    end
    Macro.UpdateOutfitUpdateMacro()
    print("|cff00ff00Fitter:|r " .. string.format(L["Created character macro '%s'."], Macro.OUTFIT_UPDATE_MACRO_NAME))
end
