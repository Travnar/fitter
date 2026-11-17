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

    local name = Macro.OUTFIT_UPDATE_MACRO_NAME
    if (accountIndex or characterIndex) and Macro.CanEditMacros() then
        if accountIndex then
            Macro.WriteSpec(accountIndex, name, spec, ACCOUNT_STORAGE_KEY,
                Macro.OUTFIT_UPDATE_MACRO_ICON, true)
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
            -- No icon, so the character macro keeps the one the player chose.
            Macro.WriteSpec(characterIndex, name, spec, CHARACTER_STORAGE_KEY)
        end
    end

    if hasBinding then
        Macro.SetButtonBody(ns.OutfitUpdateButton, Macro.ComposeBody(spec))
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
        ns.Print(L["Cannot create macro: maximum number of account macros reached."])
        return
    end
    Macro.Create(Macro.OUTFIT_UPDATE_MACRO_NAME, Macro.OUTFIT_UPDATE_MACRO_ICON, ACTION,
        ACCOUNT_STORAGE_KEY)
    Macro.SetButtonBody(ns.OutfitUpdateButton, ACTION)
    Macro.UpdateOutfitUpdateMacro()
    ns.Print(string.format(L["Created macro '%s'."], Macro.OUTFIT_UPDATE_MACRO_NAME))
end

function Macro.EnsureCharacterOutfitUpdateMacro()
    if InCombatLockdown() then return end
    Macro.MigrateLegacyNames()
    local _, numChar = GetNumMacros()
    if Macro.Exists(Macro.OUTFIT_UPDATE_MACRO_NAME, "character") then
        ns.Print(string.format(L["Character macro '%s' already exists."], Macro.OUTFIT_UPDATE_MACRO_NAME))
        return
    end
    if numChar >= Macro.MAX_CHARACTER_MACROS then
        ns.Print(L["Cannot create macro: maximum number of character macros reached."])
        return
    end
    Macro.Create(Macro.OUTFIT_UPDATE_MACRO_NAME, "INV_Misc_QuestionMark", ACTION,
        CHARACTER_STORAGE_KEY, true)
    Macro.UpdateOutfitUpdateMacro()
    ns.Print(string.format(L["Created character macro '%s'."], Macro.OUTFIT_UPDATE_MACRO_NAME))
end
