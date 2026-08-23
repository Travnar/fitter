local addonName, ns = ...

local Macro = ns.Macro
local ASTRAL_RECALL_SPELL_ID = 556

local function GetAstralRecallIcon()
    return C_Spell.GetSpellTexture(ASTRAL_RECALL_SPELL_ID)
        or Macro.HEARTHSTONE_MACRO_ICON
end

local function IsAstralRecallFallbackEnabled()
    local playerClass = ns.state and ns.state.playerClass
    if not playerClass then
        local _, detectedClass = UnitClass("player")
        playerClass = detectedClass
    end
    return playerClass == "SHAMAN"
        and FitterSaved
        and FitterSaved.AstralRecallFallback
end

local function IsHearthstoneOnCooldown(itemID)
    local startTime, duration = GetItemCooldown(itemID)
    return startTime and duration and startTime > 0 and duration > 0
        and (startTime + duration) > GetTime()
end

local function GetHearthstoneAction(itemID)
    if IsAstralRecallFallbackEnabled()
        and IsHearthstoneOnCooldown(itemID) then
        return "Astral Recall"
    end
    return "item:" .. itemID
end

local function GetDefaultBody(showTooltip)
    local action = "Hearthstone"
    if IsAstralRecallFallbackEnabled()
        and IsHearthstoneOnCooldown(Macro.DEFAULT_HEARTHSTONE_ITEM_ID) then
        action = "Astral Recall"
    end
    return (showTooltip and "#showtooltip\n" or "") .. "/use " .. action
end

local function HasDefaultHearthstone()
    return C_Item.GetItemCount(Macro.DEFAULT_HEARTHSTONE_ITEM_ID, false, false, false) > 0
end

local function GetRandomAvailableHearthstone()
    local available = {}
    if HasDefaultHearthstone() then
        available[#available + 1] = Macro.DEFAULT_HEARTHSTONE_ITEM_ID
    end
    for _, entry in ipairs(ns.Constants.KNOWN_HEARTHSTONES) do
        if not entry.baseItem
            and (not entry.race or entry.race == ns.state.playerRace)
            and PlayerHasToy(entry.id) then
            available[#available + 1] = entry.id
        end
    end
    if #available == 0 then return nil end
    return available[math.random(#available)]
end

local function GetSelectedHearthstones(data)
    if not data then return nil end
    if type(data.Hearthstones) == "table" then
        return data.Hearthstones
    end
    -- Read the former single-selection field so existing outfits continue
    -- to work until they are next edited in the Hearthstone picker.
    if type(data.Hearthstone) == "number" then
        return {data.Hearthstone}
    end
    return nil
end

local function GetRandomSelectedHearthstone(data)
    local selected = GetSelectedHearthstones(data)
    if not selected or #selected == 0 then return nil end

    local usable = {}
    for _, itemID in ipairs(selected) do
        if itemID == Macro.DEFAULT_HEARTHSTONE_ITEM_ID then
            if HasDefaultHearthstone() then
                usable[#usable + 1] = itemID
            end
        elseif PlayerHasToy(itemID) then
            usable[#usable + 1] = itemID
        end
    end
    if #usable == 0 then return nil end
    return usable[math.random(#usable)]
end

local function ResolveHearthstoneMacro()
    local showTooltip = Macro.ShouldShowHearthstoneTooltip()
    local body = GetDefaultBody(showTooltip)
    local icon = Macro.HEARTHSTONE_MACRO_ICON
    if IsAstralRecallFallbackEnabled()
        and IsHearthstoneOnCooldown(Macro.DEFAULT_HEARTHSTONE_ITEM_ID) then
        icon = GetAstralRecallIcon()
    end
    if not C_TransmogOutfitInfo then return body, icon end

    local activeOutfitID = C_TransmogOutfitInfo.GetActiveOutfitID()
    if (not activeOutfitID or activeOutfitID <= 0) and FitterCharacterSaved then
        activeOutfitID = FitterCharacterSaved.LastActiveOutfitID
    end
    if activeOutfitID and activeOutfitID > 0 and FitterCharacterSaved then
        FitterCharacterSaved.LastActiveOutfitID = activeOutfitID
    end
    local data = activeOutfitID and activeOutfitID > 0 and FitterCharacterSaved
        and FitterCharacterSaved["Outfit"..activeOutfitID]
    local selected = GetSelectedHearthstones(data)
    local hasExplicitSelection = selected and #selected > 0
    if not hasExplicitSelection then
        icon = Macro.HEARTHSTONE_MACRO_ICON
        body = body:gsub("^#showtooltip\n", "")
    end
    local itemID = GetRandomSelectedHearthstone(data)

    -- With no usable selection, choose from every eligible Hearthstone.
    if not itemID or itemID == 0 then
        itemID = GetRandomAvailableHearthstone()
    end

    if not itemID then return body, icon end

    local itemIcon
    if itemID == Macro.DEFAULT_HEARTHSTONE_ITEM_ID then
        itemIcon = C_Item.GetItemIconByID(itemID)
    else
        _, _, itemIcon = C_ToyBox.GetToyInfo(itemID)
    end

    local uses = {}
    for _, condition in ipairs({
        {key = "ShiftHearthstoneCondition", macro = "mod:shift"},
        {key = "CtrlHearthstoneCondition", macro = "mod:ctrl"},
        {key = "AltHearthstoneCondition", macro = "mod:alt"},
    }) do
        local conditionItemID = FitterSaved and FitterSaved[condition.key]
        if type(conditionItemID) == "number" and PlayerHasToy(conditionItemID) then
            uses[#uses + 1] = "[" .. condition.macro .. "] "
                .. GetHearthstoneAction(conditionItemID)
        end
    end
    uses[#uses + 1] = GetHearthstoneAction(itemID)
    local tooltip = showTooltip and hasExplicitSelection
        and "#showtooltip\n" or ""
    body = tooltip .. "/use " .. table.concat(uses, "; ")
    if not hasExplicitSelection then
        -- Empty means random, but its presentation should
        -- remain stable across bag, cooldown, and outfit macro refreshes.
        icon = Macro.HEARTHSTONE_MACRO_ICON
    elseif IsAstralRecallFallbackEnabled() and IsHearthstoneOnCooldown(itemID) then
        icon = GetAstralRecallIcon()
    elseif showTooltip then
        icon = itemIcon or 134400
    else
        icon = itemIcon or icon
    end
    return body, icon
end

function Macro.UpdateHearthstone()
    if InCombatLockdown() then return end

    local index = GetMacroIndexByName(Macro.HEARTHSTONE_MACRO_NAME)
    local rawBody, icon = ResolveHearthstoneMacro()
    local body = rawBody
    if index ~= 0 then
        body = Macro.ApplyPreservation(Macro.HEARTHSTONE_MACRO_NAME, rawBody, "LastHearthstoneMacroBody")
        local _, currentIcon = GetMacroInfo(index)
        if GetMacroBody(index) ~= body or currentIcon ~= icon then
            EditMacro(index, Macro.HEARTHSTONE_MACRO_NAME, icon, body)
        end
    end
    if ns.HearthstoneButton then
        local keybindBody = rawBody:gsub("^#showtooltip[^\n]*\n", "")
        if ns.HearthstoneButton:GetAttribute("macrotext") ~= keybindBody then
            ns.HearthstoneButton:SetAttribute("macrotext", keybindBody)
        end
    end
end

function Macro.EnsureHearthstone()
    if InCombatLockdown() then return end

    local index = GetMacroIndexByName(Macro.HEARTHSTONE_MACRO_NAME)
    if index ~= 0 then
        Macro.UpdateHearthstone()
        return
    end

    if GetNumMacros() >= Macro.MAX_ACCOUNT_MACROS then return end
    local body = (Macro.ShouldShowHearthstoneTooltip() and "#showtooltip\n" or "") .. "/use Hearthstone"
    CreateMacro(Macro.HEARTHSTONE_MACRO_NAME, Macro.HEARTHSTONE_MACRO_ICON, body, nil)
    if FitterCharacterSaved then
        FitterCharacterSaved.LastHearthstoneMacroBody = body
    end
    if ns.HearthstoneButton then
        ns.HearthstoneButton:SetAttribute("macrotext", body)
    end
    Macro.UpdateHearthstone()
end
