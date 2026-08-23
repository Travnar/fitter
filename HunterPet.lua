local addonName, ns = ...

local HunterPet = {}
ns.HunterPet = HunterPet

local MARKSMANSHIP_SPEC_ID = 254
local UNBREAKABLE_BOND_SPELL_ID = 1223323
local isHunter
local cachedActivePets
local cachedAllPets

function HunterPet.IsAvailable()
    if isHunter == nil then
        local _, class = UnitClass("player")
        isHunter = class == "HUNTER"
    end
    return isHunter
end

function HunterPet.InvalidateCache()
    cachedActivePets = nil
    cachedAllPets = nil
end

local function CanSummonHunterPet()
    local specialization = GetSpecialization and GetSpecialization()
    local specID = specialization and GetSpecializationInfo
        and GetSpecializationInfo(specialization)
    return specID ~= MARKSMANSHIP_SPEC_ID
        or (IsPlayerSpell and IsPlayerSpell(UNBREAKABLE_BOND_SPELL_ID))
end

local function CopyPet(info, activeSlot, isActive)
    if type(info) ~= "table" then return nil end
    return {
        slotID = info.slotID,
        activeSlot = activeSlot,
        isActive = isActive == true,
        icon = info.icon,
        name = info.name,
        level = info.level,
        familyName = info.familyName,
        specialization = info.specialization,
        displayID = info.displayID,
        isFavorite = info.isFavorite,
        isExotic = info.isExotic,
        petNumber = info.petNumber,
        creatureID = info.creatureID,
        specID = info.specID,
    }
end

function HunterPet.GetActivePets()
    if not HunterPet.IsAvailable() or not C_StableInfo then return {} end
    if cachedActivePets then return cachedActivePets end
    local pets = {}
    local active = C_StableInfo.GetActivePetList
        and C_StableInfo.GetActivePetList() or nil
    if type(active) == "table" then
        for index, info in ipairs(active) do
            local pet = CopyPet(info, info.slotID or index, true)
            if pet then pets[#pets + 1] = pet end
        end
    end
    if #pets == 0 and C_StableInfo.GetStablePetInfo then
        for slot = 1, 5 do
            local pet = CopyPet(C_StableInfo.GetStablePetInfo(slot), slot, true)
            if pet then pets[#pets + 1] = pet end
        end
    end
    cachedActivePets = pets
    return cachedActivePets
end


function HunterPet.GetAllPets()
    if cachedAllPets then return cachedAllPets end
    local pets, seen = {}, {}
    for _, pet in ipairs(HunterPet.GetActivePets()) do
        pets[#pets + 1] = pet
        if pet.petNumber then seen[tonumber(pet.petNumber)] = true end
    end
    local stabled = C_StableInfo and C_StableInfo.GetStabledPetList
        and C_StableInfo.GetStabledPetList() or nil
    if type(stabled) == "table" and (#stabled > 0
        or (C_StableInfo.IsAtStableMaster
            and C_StableInfo.IsAtStableMaster())) then
        FitterCharacterSaved = FitterCharacterSaved or {}
        FitterCharacterSaved.HunterPetStableCatalog = {}
        for _, info in ipairs(stabled) do
            local pet = CopyPet(info, nil, false)
            if pet then
                FitterCharacterSaved.HunterPetStableCatalog[#FitterCharacterSaved.HunterPetStableCatalog + 1] = pet
            end
        end
    elseif FitterCharacterSaved
        and type(FitterCharacterSaved.HunterPetStableCatalog) == "table" then
        stabled = FitterCharacterSaved.HunterPetStableCatalog
    end
    for _, info in ipairs(type(stabled) == "table" and stabled or {}) do
        local number = tonumber(info.petNumber)
        if not number or not seen[number] then
            local pet = CopyPet(info, nil, false)
            if pet then pets[#pets + 1] = pet end
            if number then seen[number] = true end
        end
    end
    table.sort(pets, function(a, b)
        if a.isActive ~= b.isActive then return a.isActive end
        local an, bn = (a.name or ""):lower(), (b.name or ""):lower()
        if an ~= bn then return an < bn end
        return (tonumber(a.petNumber) or 0) < (tonumber(b.petNumber) or 0)
    end)
    cachedAllPets = pets
    return cachedAllPets
end

function HunterPet.GetSelectedPet(data)
    local selected = HunterPet.GetSelectedPets(data)
    return selected[1]
end

function HunterPet.EnsureSelections(data)
    if type(data) ~= "table" then return {} end
    if type(data.HunterPets) ~= "table" then
        data.HunterPets = {}
        if data.HunterPetNumber then
            data.HunterPets[1] = tonumber(data.HunterPetNumber)
        end
    end
    data.HunterPetMetadata = data.HunterPetMetadata or {}
    local legacyNumber = tonumber(data.HunterPetNumber)
    if legacyNumber and not data.HunterPetMetadata[legacyNumber] then
        data.HunterPetMetadata[legacyNumber] = {
            petNumber = legacyNumber,
            familyName = data.HunterPetFamilyName,
            name = data.HunterPetName,
            displayID = data.HunterPetDisplayID,
            icon = data.HunterPetIcon,
        }
    end
    return data.HunterPets
end

function HunterPet.GetSelectedPets(data)
    if type(data) ~= "table" then return {} end
    local numbers = HunterPet.EnsureSelections(data)
    local byNumber = {}
    for _, pet in ipairs(HunterPet.GetAllPets()) do
        local number = tonumber(pet.petNumber)
        if number then byNumber[number] = pet end
    end
    local selected = {}
    for _, number in ipairs(numbers) do
        number = tonumber(number)
        local pet = byNumber[number]
            or (data.HunterPetMetadata and data.HunterPetMetadata[number])
        if pet then selected[#selected + 1] = pet end
    end
    return selected
end

local function ActiveSignature(active)
    local values = {}
    for _, pet in ipairs(active) do
        values[#values + 1] = tostring(pet.petNumber or pet.activeSlot or "")
    end
    table.sort(values)
    return table.concat(values, ":")
end

local function CanCallPet(pet)
    if not pet or not pet.isExotic then return pet ~= nil end
    local specialization = GetSpecialization and GetSpecialization()
    local specID = specialization and GetSpecializationInfo
        and GetSpecializationInfo(specialization)
    return specID == 253 -- Beast Mastery
end

function HunterPet.ResolveTarget(data)
    if type(data) ~= "table" or data.HunterPetDisabled
        or not CanSummonHunterPet() then return nil end
    local isRandom = data.HunterPetRandom == true
    local selections = HunterPet.EnsureSelections(data)
    if not isRandom and #selections == 0 then return nil end
    local active = {}
    for _, pet in ipairs(HunterPet.GetActivePets()) do
        if CanCallPet(pet) then active[#active + 1] = pet end
    end
    if #active == 0 then return nil end
    local selectedInfo, selectedNumber
    if not isRandom then
        local selectedPets = HunterPet.GetSelectedPets(data)
        if #selectedPets == 0 then return nil end
        -- With multiple selections, stabled pets are unavailable choices rather
        -- than requests for a same-family substitute. Roll only among the
        -- selected pets that can actually be called.
        local rollPets = selectedPets
        if #selections > 1 then
            local activeByNumber = {}
            for _, pet in ipairs(active) do
                local number = tonumber(pet.petNumber)
                if number then activeByNumber[number] = pet end
            end
            rollPets = {}
            for _, pet in ipairs(selectedPets) do
                local callable = activeByNumber[tonumber(pet.petNumber)]
                if callable then rollPets[#rollPets + 1] = callable end
            end
            if #rollPets == 0 then return nil end
        end
        ns.state.hunterPetSelectionRolls = ns.state.hunterPetSelectionRolls or {}
        local selectionValues = {}
        for _, pet in ipairs(rollPets) do
            selectionValues[#selectionValues + 1] = tostring(pet.petNumber)
        end
        table.sort(selectionValues)
        local selectionKey = table.concat(selectionValues, ":")
            .. "|" .. ActiveSignature(active)
        local rolledNumber = ns.state.hunterPetSelectionRolls[selectionKey]
        for _, pet in ipairs(rollPets) do
            if tonumber(pet.petNumber) == rolledNumber then selectedInfo = pet end
        end
        if not selectedInfo then
            selectedInfo = rollPets[math.random(1, #rollPets)]
            ns.state.hunterPetSelectionRolls[selectionKey] =
                tonumber(selectedInfo.petNumber)
        end
        selectedNumber = tonumber(selectedInfo.petNumber)
        for _, pet in ipairs(active) do
            if tonumber(pet.petNumber) == selectedNumber then return pet, pet end
        end
    end

    local family = not isRandom and ((selectedInfo and selectedInfo.familyName)
        or data.HunterPetFamilyName) or nil
    local candidates = {}
    if family and family ~= "" then
        for _, pet in ipairs(active) do
            if pet.familyName == family then candidates[#candidates + 1] = pet end
        end
    end
    if #candidates == 0 then candidates = active end

    ns.state.hunterPetFallbacks = ns.state.hunterPetFallbacks or {}
    local key = table.concat({tostring(selectedNumber or ""), family or "",
        ActiveSignature(active)}, "|")
    local cachedNumber = ns.state.hunterPetFallbacks[key]
    if cachedNumber then
        for _, pet in ipairs(candidates) do
            if tonumber(pet.petNumber) == cachedNumber then
                return pet, selectedInfo
            end
        end
    end
    local rollPool = candidates
    if isRandom and #candidates > 1
        and ns.state.lastRandomHunterPetNumber then
        local withoutLast = {}
        for _, pet in ipairs(candidates) do
            if tonumber(pet.petNumber)
                ~= ns.state.lastRandomHunterPetNumber then
                withoutLast[#withoutLast + 1] = pet
            end
        end
        if #withoutLast > 0 then rollPool = withoutLast end
    end
    local chosen = rollPool[math.random(1, #rollPool)]
    if isRandom then
        ns.state.lastRandomHunterPetNumber = tonumber(chosen.petNumber)
    end
    ns.state.hunterPetFallbacks[key] = tonumber(chosen.petNumber)
    return chosen, selectedInfo
end

function HunterPet.ResolveActivePet(data)
    return HunterPet.ResolveTarget(data)
end

function HunterPet.GetMacroLine(outfitID, resolvedPet)
    if not HunterPet.IsAvailable() or not outfitID
        or not FitterCharacterSaved then return nil end
    local data = FitterCharacterSaved["Outfit" .. outfitID]
    local pet = resolvedPet or HunterPet.ResolveActivePet(data)
    local slot = pet and tonumber(pet.activeSlot)
    if not slot or slot < 1 or slot > 5 then return nil end
    return string.format("/cast [nopet] Call Pet %d", slot)
end

local function GetReviveLines(data, stopMacro)
    if not FitterSaved or FitterSaved.ReviveHunterPet ~= true
        or type(data) ~= "table" or data.HunterPetDisabled
        or (not data.HunterPetRandom
            and #HunterPet.EnsureSelections(data) == 0) then
        return nil
    end
    local info = C_Spell and C_Spell.GetSpellInfo
        and C_Spell.GetSpellInfo(982)
    local reviveName = info and info.name or "Revive Pet"
    local line = "/cast [@pet,dead] " .. reviveName
    if stopMacro == false then return line end
    return line .. "\n/stopmacro [@pet,dead]"
end

local function PrependLines(first, rest)
    if not first then return rest end
    if not rest then return first end
    return first .. "\n" .. rest
end

function HunterPet.GetOutfitMacroLines(outfitID)
    local data = FitterCharacterSaved
        and FitterCharacterSaved["Outfit" .. outfitID]
    if data and data.HunterPetDisabled and HunterPet.HasHunterPet() then
        local info = C_Spell and C_Spell.GetSpellInfo
            and C_Spell.GetSpellInfo(2641)
        return "/cast " .. (info and info.name or "Dismiss Pet")
    end
    local reviveLines = GetReviveLines(data)
    local callLine = HunterPet.GetMacroLine(outfitID)
    if callLine and data and data.HunterPetRandom then
        callLine = callLine .. "\n/run FitHR()"
    end
    return PrependLines(reviveLines, callLine)
end

function HunterPet.GetMountMacroLines(outfitID)
    local data = FitterCharacterSaved
        and FitterCharacterSaved["Outfit" .. outfitID]
    if data and data.HunterPetDisabled then
        if not HunterPet.HasHunterPet() then return nil end
        local info = C_Spell and C_Spell.GetSpellInfo
            and C_Spell.GetSpellInfo(2641)
        local dismissName = info and info.name or "Dismiss Pet"
        return "/cast " .. dismissName .. "\n/stopmacro [pet]"
    end
    -- Pet recovery must not prevent the mount portion of the macro from
    -- running, even when the pet is dead or Call Pet fails.
    local reviveLines = GetReviveLines(data, false)
    local target, selectedPet = HunterPet.ResolveTarget(data)
    local callLine = HunterPet.GetMacroLine(outfitID, target)
    if not callLine then return reviveLines end
    if HunterPet.HasHunterPet() then
        if data and data.HunterPetRandom then return reviveLines end
        if HunterPet.IsAnySelectedPetSummoned(data) then return reviveLines end
        -- A stabled selection uses its family/random fallback only when no pet
        -- is out. Never dismiss an existing pet merely to replace it with a
        -- substitute for a pet that cannot currently be called.
        if not selectedPet or not selectedPet.isActive then return reviveLines end
        if HunterPet.IsPetSummoned(target and target.petNumber) then
            return reviveLines
        end
        local info = C_Spell and C_Spell.GetSpellInfo
            and C_Spell.GetSpellInfo(2641)
        local dismissName = info and info.name or "Dismiss Pet"
        return PrependLines(reviveLines,
            "/cast " .. dismissName .. "\n/stopmacro [pet]")
    end
    if data and data.HunterPetRandom then
        callLine = callLine .. "\n/run FitHR()"
    end
    return PrependLines(reviveLines, callLine)
end

function HunterPet.IsAnySelectedPetSummoned(data)
    local summoned = HunterPet.GetSummonedPetNumber()
    if not summoned then return false end
    for _, pet in ipairs(HunterPet.GetSelectedPets(data)) do
        if tonumber(pet.petNumber) == summoned then return true end
    end
    return false
end

function HunterPet.HasHunterPet()
    local hasPet, isHunterPet = HasPetUI()
    return hasPet == true and isHunterPet == true
end

function HunterPet.GetSummonedPetNumber()
    if not HunterPet.HasHunterPet() then return nil end
    local guid = UnitGUID("pet")
    local spawnUID = guid and select(7, strsplit("-", guid))
    if not spawnUID or #spawnUID <= 2 then return nil end
    return tonumber(spawnUID:sub(3), 16)
end

function HunterPet.IsPetSummoned(petNumber)
    local summoned = HunterPet.GetSummonedPetNumber()
    return tonumber(petNumber) ~= nil and summoned ~= nil
        and tonumber(petNumber) == summoned
end

function HunterPet.ResolveSlot(data)
    local pet = HunterPet.ResolveActivePet(data)
    return pet and tonumber(pet.activeSlot) or nil
end

function HunterPet.RerollRandomMacro()
    wipe(ns.state.hunterPetFallbacks or {})
    C_Timer.After(0, function()
        if InCombatLockdown() then
            if ns.MarkMacroRefreshPending then ns.MarkMacroRefreshPending() end
            return
        end
        ns.Macro.UpdateOutfitUpdateMacro()
        ns.Macro.UpdateMacroForMount(ns.state.nextMountToSummon)
    end)
end

_G.FitterHunterPetReroll = HunterPet.RerollRandomMacro
_G.FitHR = HunterPet.RerollRandomMacro
