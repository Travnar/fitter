local addonName, ns = ...
local L = ns.L

local Pet = {}
ns.Pet = Pet

Pet.SUMMON_TRIGGERS = {
    { key = "outfitChange", label = L["Outfit Change"] },
    { key = "worldEntry", label = L["Enter World"] },
    { key = "mount", label = L["Mount"] },
    { key = "dismount", label = L["Dismount"] },
    { key = "zoneChange", label = L["Zone Change"] },
    { key = "stealthEnd", label = L["Leave Stealth"] },
}

local function IsSummonTriggerEnabled(data, petGUID, trigger)
    if not trigger then return true end
    local petSettings = data.PetSummonTriggers and data.PetSummonTriggers[petGUID]
    return not petSettings or petSettings[trigger] ~= false
end

local function PickRandomPet()
    local currentPet = C_PetJournal.GetSummonedPetGUID()
    local candidates = {}
    local numPets = C_PetJournal.GetNumPets()
    for i = 1, numPets do
        local petID, _, owned = C_PetJournal.GetPetInfoByIndex(i)
        if petID and owned and C_PetJournal.PetIsSummonable(petID) and petID ~= currentPet then
            candidates[#candidates + 1] = petID
        end
    end
    if #candidates > 0 then
        return candidates[math.random(1, #candidates)]
    end
end

function Pet.IsPlayerStealthed()
    if IsStealthed and IsStealthed() then return true end
    return SecureCmdOptionParse and SecureCmdOptionParse("[stealth] 1; 0") == "1"
end

function Pet.DismissCurrent()
    if not C_PetJournal or not C_PetJournal.GetSummonedPetGUID
        or not C_PetJournal.SummonPetByGUID then
        return
    end

    local function TryDismiss()
        local currentPet = C_PetJournal.GetSummonedPetGUID()
        if currentPet then
            C_PetJournal.SummonPetByGUID(currentPet)
            return true
        end
        return false
    end

    if not TryDismiss() then return end

    Pet.dismissAttempts = (Pet.dismissAttempts or 0) + 1
    local dismissAttemptID = Pet.dismissAttempts

    local function RetryDismiss(attempt)
        if Pet.dismissAttempts ~= dismissAttemptID then return end
        if not Pet.IsPlayerStealthed() then return end
        if not TryDismiss() then return end
        if attempt < 12 then
            C_Timer.After(0.25, function()
                RetryDismiss(attempt + 1)
            end)
        end
    end

    C_Timer.After(0.25, function()
        RetryDismiss(1)
    end)
end

function Pet.DismissIfStealthed()
    if not FitterSaved or not FitterSaved.DismissPetOnStealth then return end
    if Pet.IsPlayerStealthed() then
        Pet.DismissCurrent()
    end
end

function Pet.ShouldDismissInInstance()
    if not FitterSaved or not FitterSaved.DismissPetInInstancesWhileGrouped then return false end
    if not IsInInstance or not IsInGroup then return false end

    return IsInInstance() and IsInGroup()
end

function Pet.OutfitShouldDismiss(outfitIDOverride)
    if not C_TransmogOutfitInfo then return false end

    local activeOutfitID = outfitIDOverride
        or (C_TransmogOutfitInfo.GetActiveOutfitID and C_TransmogOutfitInfo.GetActiveOutfitID())
    if not activeOutfitID or activeOutfitID == 0 then return false end

    local data = FitterCharacterSaved and FitterCharacterSaved["Outfit"..activeOutfitID]
    if not data then return false end

    return data.PetNoPet == true
end

function Pet.Apply(outfitIDOverride, trigger)
    if InCombatLockdown() then return end
    if not C_TransmogOutfitInfo then return end

    if Pet.ShouldDismissInInstance() then
        Pet.DismissCurrent()
        return
    end

    local activeOutfitID = outfitIDOverride
        or (C_TransmogOutfitInfo.GetActiveOutfitID and C_TransmogOutfitInfo.GetActiveOutfitID())
    if not activeOutfitID or activeOutfitID == 0 then return end

    local data = FitterCharacterSaved["Outfit"..activeOutfitID]
    if not data then return end

    local petRandom = data.PetRandom == true
    local pets = data.Pets or {}

    if data.PetNoPet == true then
        Pet.DismissCurrent()
        return
    end

    if #pets > 0 then
        if Pet.IsPlayerStealthed() then return end
        local currentPet = C_PetJournal.GetSummonedPetGUID()
        local candidates = {}
        for _, guid in ipairs(pets) do
            if IsSummonTriggerEnabled(data, guid, trigger)
                and guid ~= currentPet and C_PetJournal.PetIsSummonable(guid) then
                candidates[#candidates + 1] = guid
            end
        end
        if #candidates == 0 then
            for _, guid in ipairs(pets) do
                if IsSummonTriggerEnabled(data, guid, trigger)
                    and C_PetJournal.PetIsSummonable(guid) then
                    candidates[#candidates + 1] = guid
                end
            end
        end
        if #candidates > 0 then
            local pick = candidates[math.random(1, #candidates)]
            if pick ~= currentPet then
                C_PetJournal.SummonPetByGUID(pick)
            end
        end
        return
    end

    if petRandom then
        if Pet.IsPlayerStealthed() then return end
        local pick = PickRandomPet()
        if pick then C_PetJournal.SummonPetByGUID(pick) end
        return
    end

    -- Ignore Pet: leave the currently summoned pet alone. Global dismissal
    -- settings above still take precedence.
end
