local addonName, ns = ...
local L = ns.L

local Macro = ns.Macro
local OUTFIT_UPDATE_BINDING = "CLICK FitterOutfitUpdateButton:LeftButton"

local function GetConsumers()
    local index = GetMacroIndexByName(Macro.OUTFIT_UPDATE_MACRO_NAME)
    local bindingKey = GetBindingKey and GetBindingKey(OUTFIT_UPDATE_BINDING)
    return index, bindingKey ~= nil
end

function Macro.IsOutfitUpdateUsed()
    local index, hasBinding = GetConsumers()
    return (index and index ~= 0) or hasBinding
end

local function BuildOutfitUpdateMacroBody()
    local prefix = Macro.GetOutfitMacroPrefix()
    return prefix .. "/run FitU()"
end

function Macro.UpdateOutfitUpdateMacro(outfitIDOverride)
    local index, hasBinding = GetConsumers()
    if (not index or index == 0) and not hasBinding then return end
    if InCombatLockdown() then
        if ns.MarkMacroRefreshPending then ns.MarkMacroRefreshPending() end
        return
    end
    local rawBody = BuildOutfitUpdateMacroBody()
    local userLen = index and index ~= 0 and Macro.GetUserAdditionsLength(
        Macro.OUTFIT_UPDATE_MACRO_NAME, "LastOutfitUpdateMacroBody") or 0
    local remaining = 255 - #rawBody - userLen

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

    local hunterPetLine = ns.HunterPet
        and ns.HunterPet.GetOutfitMacroLines(resolvedToyOutfitID)
    if hunterPetLine and remaining > #hunterPetLine + 1 then
        rawBody = hunterPetLine .. "\n" .. rawBody
        remaining = remaining - #hunterPetLine - 1
    end

    local cancelLines = ns.Toy and remaining > 1 and ns.Toy.GetCancelLines(
        resolvedToyOutfitID, remaining - 1)
    if cancelLines then remaining = remaining - #cancelLines - 1 end
    local toyLines = ns.Toy and remaining > 1 and ns.Toy.GetMacroLines(
        resolvedToyOutfitID, remaining - 1)
    if toyLines then rawBody = toyLines .. "\n" .. rawBody end
    if cancelLines then rawBody = cancelLines .. "\n" .. rawBody end

    if index and index ~= 0 then
        local body = Macro.ApplyPreservation(Macro.OUTFIT_UPDATE_MACRO_NAME,
            rawBody, "LastOutfitUpdateMacroBody")
        local _, currentIcon = GetMacroInfo(index)
        if GetMacroBody(index) ~= body
            or currentIcon ~= Macro.OUTFIT_UPDATE_MACRO_ICON then
            EditMacro(index, Macro.OUTFIT_UPDATE_MACRO_NAME,
                Macro.OUTFIT_UPDATE_MACRO_ICON, body)
        end
    end

    if hasBinding and ns.OutfitUpdateButton then
        local btnBody = BuildOutfitUpdateMacroBody()
        local remaining = 255 - #btnBody
        local hunterPetLine = ns.HunterPet
            and ns.HunterPet.GetOutfitMacroLines(resolvedToyOutfitID)
        if hunterPetLine and remaining > #hunterPetLine + 1 then
            btnBody = hunterPetLine .. "\n" .. btnBody
            remaining = remaining - #hunterPetLine - 1
        end
        local cancelLines = ns.Toy and remaining > 1
            and ns.Toy.GetCancelLines(resolvedToyOutfitID, remaining - 1)
        if cancelLines then remaining = remaining - #cancelLines - 1 end
        local toyLines = ns.Toy and remaining > 1
            and ns.Toy.GetMacroLines(resolvedToyOutfitID, remaining - 1)
        if toyLines then btnBody = toyLines .. "\n" .. btnBody end
        if cancelLines then btnBody = cancelLines .. "\n" .. btnBody end
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
                elseif ns.MarkMacroRefreshPending then
                    ns.MarkMacroRefreshPending()
                end
            end)
        end
    end
end

function Macro.EnsureOutfitUpdateMacro()
    if InCombatLockdown() then return end
    local index = GetMacroIndexByName(Macro.OUTFIT_UPDATE_MACRO_NAME)
    if index and index ~= 0 then
        Macro.UpdateOutfitUpdateMacro()
        return
    end
    if GetNumMacros() >= Macro.MAX_ACCOUNT_MACROS then
        print("|cff00ff00Fitter:|r " .. L["Cannot create macro: maximum number of account macros reached."])
        return
    end
    local body = "/run FitU()"
    CreateMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, Macro.OUTFIT_UPDATE_MACRO_ICON, body, nil)
    if FitterCharacterSaved then
        FitterCharacterSaved.LastOutfitUpdateMacroBody = body
    end
    if ns.OutfitUpdateButton then
        ns.OutfitUpdateButton:SetAttribute("macrotext", body)
    end
    Macro.UpdateOutfitUpdateMacro()
    print("|cff00ff00Fitter:|r " .. string.format(L["Created macro '%s'."], Macro.OUTFIT_UPDATE_MACRO_NAME))
end

function Macro.EnsureCharacterOutfitUpdateMacro()
    if InCombatLockdown() then return end
    -- Check only character macro slots (account macros occupy 1–MAX_ACCOUNT_MACROS)
    local _, numChar = GetNumMacros()
    for i = Macro.MAX_ACCOUNT_MACROS + 1, Macro.MAX_ACCOUNT_MACROS + numChar do
        local name = GetMacroInfo(i)
        if name == Macro.OUTFIT_UPDATE_MACRO_NAME then
            print("|cff00ff00Fitter:|r " .. string.format(L["Character macro '%s' already exists."], Macro.OUTFIT_UPDATE_MACRO_NAME))
            return
        end
    end
    if numChar >= Macro.MAX_CHARACTER_MACROS then
        print("|cff00ff00Fitter:|r " .. L["Cannot create macro: maximum number of character macros reached."])
        return
    end
    local body = "/run FitU()"
    CreateMacro(Macro.OUTFIT_UPDATE_MACRO_NAME, "INV_Misc_QuestionMark", body, true)
    if FitterCharacterSaved then
        FitterCharacterSaved.LastOutfitUpdateMacroBody = body
    end
    if ns.OutfitUpdateButton then
        ns.OutfitUpdateButton:SetAttribute("macrotext", body)
    end
    Macro.UpdateOutfitUpdateMacro()
    print("|cff00ff00Fitter:|r " .. string.format(L["Created character macro '%s'."], Macro.OUTFIT_UPDATE_MACRO_NAME))
end
