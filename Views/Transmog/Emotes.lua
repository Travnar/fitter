local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s
local Fitter = ns.Fitter

local PAGE_SIZE = 27
local START_X, START_Y = 30, -155
local GAP_X = 14
local BOTTOM_PADDING = 65

local CONDITIONS = {
    { key = "MOUNTED", label = L["Mounting"] },
    { key = "DISMOUNTED", label = L["Dismounting"] },
    { key = "COMBAT_START", label = L["Entering Combat"] },
    { key = "COMBAT_END", label = L["Leaving Combat"] },
    { key = "EATING_START", label = L["Starting to Eat"] },
    { key = "EATING_END", label = L["Finishing Eating"] },
    { key = "DRINKING_START", label = L["Starting to Drink"] },
    { key = "DRINKING_END", label = L["Finishing Drinking"] },
    { key = "RESTING_START", label = L["Entering a Rest Area"] },
    { key = "RESTING_END", label = L["Leaving a Rest Area"] },
    { key = "AFK_START", label = L["AFK"] },
    { key = "HEARTHSTONE_USED", label = L["Using a Hearthstone"] },
    { key = "OUTFIT_EQUIPPED", label = L["Equipping This Outfit"] },
    {
        key = "SOCIAL",
        label = L["Social"],
        submenu = {
            { key = "TARGET_FRIENDLY_PLAYER", label = L["Target Friendly Player"] },
            { key = "TARGET_FRIENDLY_NPC", label = L["Target Friendly NPC"] },
            { key = "TARGET_HOSTILE_NPC", label = L["Target Hostile NPC"] },
        },
    },
    { key = "BIOMES", label = L["Biomes"], submenu = ns.Constants.BIOME_GROUPS },
}

local function CurrentData(create)
    local data = UI_Transmog:GetViewedOutfitData(create)
    if data and type(data.Emotes) ~= "table" then data.Emotes = {} end
    return data
end

local function IsAssigned(assignment)
    for _, enabled in pairs(assignment and assignment.conditions or {}) do
        if enabled == true
            or (type(enabled) == "table" and next(enabled)) then
            return true
        end
    end
    return false
end

local function GetAssignmentLabels(assignment)
    local conditions = assignment and assignment.conditions
    local labels = {}
    for _, condition in ipairs(CONDITIONS) do
        local value = conditions and conditions[condition.key]
        if value == true then
            labels[#labels + 1] = condition.label
        elseif type(value) == "table" and type(condition.submenu) == "table" then
            for _, option in ipairs(condition.submenu) do
                if value[option.key] then
                    labels[#labels + 1] = option.label
                end
            end
        end
    end
    return labels
end

local function GetEmoteExample(item)
    if not item then return nil end
    local template = item.example
    if not template and item.custom and item.text then
        template = "{name} " .. item.text
    end
    if not template then return nil end
    return template:gsub("{name}", UnitName("player") or L["Your character"])
end

local function LayoutButtons()
    if not s.emoteButtons or not s.emoteButtons[1] then return end
    local first = s.emoteButtons[1]
    local availableWidth = s.emotesFrame:GetWidth() - START_X * 2
    local rowCount = math.ceil(#s.emoteButtons / 3)
    local availableHeight = math.max(first:GetHeight(),
        s.emotesFrame:GetHeight() + START_Y - BOTTOM_PADDING)
    local columnWidth = availableWidth / 3
    local width = math.max(100, columnWidth - GAP_X)
    local stepX = columnWidth
    local buttonInset = GAP_X / 2
    local stepY = rowCount > 1
        and (availableHeight - first:GetHeight()) / (rowCount - 1)
        or 0
    for i, button in ipairs(s.emoteButtons) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        button:SetWidth(width)
        local font = button:GetFontString()
        if font then font:SetWidth(math.max(width - 58, 20)) end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", s.emotesFrame, "TOPLEFT",
            START_X + buttonInset + col * stepX, START_Y - row * stepY)
    end
end

local function DeleteCustomEmote(item)
    local store = item.scope == "account"
        and FitterSaved.CustomEmotes or FitterCharacterSaved.CustomEmotes
    for index, entry in ipairs(store or {}) do
        if entry.id == item.id then
            table.remove(store, index)
            break
        end
    end
    -- Remove assignments from every outfit available on this character.
    for key, data in pairs(FitterCharacterSaved or {}) do
        if type(key) == "string" and key:match("^Outfit%d+$")
            and type(data) == "table" and type(data.Emotes) == "table" then
            data.Emotes[item.id] = nil
        end
    end
    UI_Transmog._PagedShared.SetFavorite("FavoriteEmotes", item.id, false)
    UI_Transmog:RefreshEmoteList()
    UI_Transmog:UpdateMountIcons()
    Fitter:RefreshFeatureEvents()
end

function UI_Transmog:StopEmotePreview()
    s.emotePreviewRequest = (s.emotePreviewRequest or 0) + 1
    local scene = TransmogFrame and TransmogFrame.CharacterPreview
        and TransmogFrame.CharacterPreview.ModelScene
    local actor = scene and scene.GetPlayerActor and scene:GetPlayerActor()
    if actor and actor.SetAnimation then
        if actor.SetAnimationBlendOperation then
            pcall(actor.SetAnimationBlendOperation, actor, 1)
        end
        pcall(actor.SetAnimation, actor, 0, 0, 1, 0)
    end
end

function UI_Transmog:PreviewEmoteAnimation(item)
    local animationID = item and item.previewAnimationID
    if type(animationID) ~= "number" then return end

    self:CancelUITimers("preview")
    self:StopEmotePreview()
    local request = s.emotePreviewRequest
    local clearHearthstoneVisuals = s.previewHearthstoneActive == true
    s.hearthstonePreviewRequest = (s.hearthstonePreviewRequest or 0) + 1
    s.previewHearthstoneActive = nil
    self:ClearMountPreview()
    self:RestoreHearthstonePreviewOutfit()

    local attempts = 0
    local function PlayWhenLoaded()
        if request ~= s.emotePreviewRequest then return end
        attempts = attempts + 1
        -- Fetch the actor again after ClearMountPreview: the wardrobe can
        -- replace or redress it during its first asynchronous update.
        local scene = TransmogFrame and TransmogFrame.CharacterPreview
            and TransmogFrame.CharacterPreview.ModelScene
        local actor = scene and scene.GetPlayerActor and scene:GetPlayerActor()
        if not actor or not actor.SetAnimation
            or (actor.IsLoaded and not actor:IsLoaded()) then
            if attempts < 40 then
                UI_Transmog:ScheduleTimer(
                    .05, PlayWhenLoaded, "preview")
            end
            return
        end

        if clearHearthstoneVisuals then
            if actor.SetSpellVisualKit then
                pcall(actor.SetSpellVisualKit, actor, 0, true)
            end
            if actor.PlayAnimationKit then
                pcall(actor.PlayAnimationKit, actor, 0, false)
            end
        end
        if actor.SetAnimationBlendOperation then
            pcall(actor.SetAnimationBlendOperation, actor, 1)
        end
        pcall(actor.SetAnimation, actor, animationID, 0, 1, 0)

        UI_Transmog:ScheduleTimer(5, function()
            if request ~= s.emotePreviewRequest then return end
            if actor.SetAnimationBlendOperation then
                pcall(actor.SetAnimationBlendOperation, actor, 1)
            end
            pcall(actor.SetAnimation, actor, 0, 0, 1, 0)
        end, "preview")
    end

    -- Even an actor reporting IsLoaded can still be redressed on the frame in
    -- which the wardrobe opens.  Let that initial update settle first.
    self:ScheduleTimer(.1, PlayWhenLoaded, "preview")
end

local function ShowAssignmentMenu(owner)
    local item, data = owner.item, CurrentData(true)
    if not item or not data or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    local assignment = data.Emotes[item.id]
    if type(assignment) ~= "table"
        or type(assignment.conditions) ~= "table" then
        assignment = { conditions = {} }
        data.Emotes[item.id] = assignment
    end
    local conditions = assignment.conditions

    MenuUtil.CreateContextMenu(owner, function(_, root)
        root:CreateTitle(item.name)
        local function FinishAssignmentChange()
            data.Emotes[item.id] = IsAssigned(assignment) and assignment or nil
            if s.emoteCheckedOnly then
                UI_Transmog:RefreshEmoteList()
            else
                UI_Transmog:UpdateEmotePageDisplay()
            end
            UI_Transmog:UpdateMountIcons()
            Fitter:RefreshFeatureEvents()
        end
        if item.command or ns.Emote.IsBuiltInCommand(item.text) then
            local ignoreTarget = root:CreateCheckbox(L["Ignore target"], function()
                return assignment.ignoreTarget == true
            end, function()
                assignment.ignoreTarget = not assignment.ignoreTarget or nil
                FinishAssignmentChange()
            end)
            ignoreTarget:SetTooltip(function(tooltip)
                GameTooltip_SetTitle(tooltip, L["Ignore target"])
                GameTooltip_AddNormalLine(tooltip,
                    L["Uses the emote's untargeted wording without clearing your selected target."])
            end)
            root:CreateDivider()
        end
        for _, definition in ipairs(CONDITIONS) do
            local condition = definition
            if type(condition.submenu) == "table" then
                local flyout = root:CreateButton(condition.label)
                for _, definition in ipairs(condition.submenu) do
                    local option = definition
                    flyout:CreateCheckbox(option.label, function()
                        return type(conditions[condition.key]) == "table"
                            and conditions[condition.key][option.key] == true
                    end, function()
                        conditions[condition.key] =
                            conditions[condition.key] or {}
                        local selections = conditions[condition.key]
                        selections[option.key] =
                            not selections[option.key] or nil
                        if not next(selections) then
                            conditions[condition.key] = nil
                        end
                        FinishAssignmentChange()
                    end)
                end
            else
                root:CreateCheckbox(condition.label, function()
                    return conditions[condition.key] == true
                end, function()
                    conditions[condition.key] =
                        not conditions[condition.key] or nil
                    FinishAssignmentChange()
                end)
            end
        end
    end)
end

local function ShowEmoteContextMenu(owner)
    local item = owner.item
    if not item or not MenuUtil or not MenuUtil.CreateContextMenu then return end
    MenuUtil.CreateContextMenu(owner, function(_, root)
        local favorite = UI_Transmog._PagedShared.IsEmoteFavorite(item.id)
        root:CreateButton(favorite and L["Remove Favorite"] or L["Set Favorite"], function()
            UI_Transmog._PagedShared.SetFavorite(
                "FavoriteEmotes", item.id, not favorite)
            UI_Transmog:RefreshEmoteList()
        end)
        if item.custom or item.previewAnimationID then
            root:CreateDivider()
        end
        if item.custom then
            root:CreateButton(L["Delete Emote"], function() DeleteCustomEmote(item) end)
        end
        if item.previewAnimationID then
            root:CreateButton(L["Preview"], function()
                UI_Transmog:PreviewEmoteAnimation(item)
            end)
        end
    end)
end

function UI_Transmog:InitializeEmotesView()
    local label, _, search = self._PagedShared.CreateHeader(
        s.emotesFrame, "Emotes", function(text)
            s.emoteSearchString = text
            UI_Transmog:RefreshEmoteList()
        end)
    search.Instructions:SetText(L["Search"])
    s.emoteSearchString = ""
    s.emoteSourcesDropdown =
        self._PagedShared.CreateFilterDropdown(s.emotesFrame, search, {
            isDefault = function()
                return not s.emoteCheckedOnly
                    and not s.emoteDefaultOnly
                    and not s.emoteCustomOnly
                    and not s.emoteCharacterOnly
                    and not s.emoteAccountOnly
                    and not s.emoteAnimationOnly
                    and not s.emoteVoicelineOnly
            end,
            default = function()
                s.emoteCheckedOnly = false
                s.emoteDefaultOnly = false
                s.emoteCustomOnly = false
                s.emoteCharacterOnly = false
                s.emoteAccountOnly = false
                s.emoteAnimationOnly = false
                s.emoteVoicelineOnly = false
                UI_Transmog:RefreshEmoteList()
            end,
            setup = function(_, rootDescription)
                self._PagedShared.AddSelectedCheckbox(
                    rootDescription, s, "emoteCheckedOnly",
                    function() UI_Transmog:RefreshEmoteList() end)
                rootDescription:CreateCheckbox(L["Default"], function()
                    return s.emoteDefaultOnly
                end, function()
                    s.emoteDefaultOnly = not s.emoteDefaultOnly
                    if s.emoteDefaultOnly then
                        s.emoteCustomOnly = false
                        s.emoteCharacterOnly = false
                        s.emoteAccountOnly = false
                    end
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Custom"], function()
                    return s.emoteCustomOnly
                end, function()
                    s.emoteCustomOnly = not s.emoteCustomOnly
                    if s.emoteCustomOnly then
                        s.emoteDefaultOnly = false
                        s.emoteCharacterOnly = false
                        s.emoteAccountOnly = false
                    end
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Character"], function()
                    return s.emoteCharacterOnly
                end, function()
                    s.emoteCharacterOnly = not s.emoteCharacterOnly
                    if s.emoteCharacterOnly then
                        s.emoteDefaultOnly = false
                        s.emoteCustomOnly = false
                        s.emoteAccountOnly = false
                    end
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Account Wide"], function()
                    return s.emoteAccountOnly
                end, function()
                    s.emoteAccountOnly = not s.emoteAccountOnly
                    if s.emoteAccountOnly then
                        s.emoteDefaultOnly = false
                        s.emoteCustomOnly = false
                        s.emoteCharacterOnly = false
                    end
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Animation"], function()
                    return s.emoteAnimationOnly
                end, function()
                    s.emoteAnimationOnly = not s.emoteAnimationOnly
                    UI_Transmog:RefreshEmoteList()
                end)
                rootDescription:CreateCheckbox(L["Voiceline"], function()
                    return s.emoteVoicelineOnly
                end, function()
                    s.emoteVoicelineOnly = not s.emoteVoicelineOnly
                    UI_Transmog:RefreshEmoteList()
                end)
            end,
        })

    local add = CreateFrame("Button", nil, s.emotesFrame, "DisplayTypeButtonTemplate")
    self._PagedShared.AnchorDisplayTypeButton(add, label)
    add:SetText(L["Add New Emote"])
    add.IconFrame.Icon:SetTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
    add:SetScript("OnClick", function() UI_Transmog:ShowEmoteCreatePopup() end)
    s.emoteAddButton = add

    s.emoteButtons = {}
    for index = 1, PAGE_SIZE do
        local button =
            self._PagedShared.CreateCollectionEntryButton(s.emotesFrame)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local font = button:GetFontString()
        if font then
            font:SetWordWrap(true)
            if font.SetNonSpaceWrap then font:SetNonSpaceWrap(true) end
            if font.SetMaxLines then font:SetMaxLines(3) end
        end
        button:SetScript("OnClick", function(self, mouseButton)
            if mouseButton == "RightButton" then
                ShowEmoteContextMenu(self)
            else
                ShowAssignmentMenu(self)
            end
        end)
        button.favoriteStar =
            self._PagedShared.CreateFavoriteStar(button)
        button.favoriteStar:ClearAllPoints()
        button.favoriteStar:SetPoint(
            "CENTER", button.IconFrame, "TOPLEFT", 3, -3)
        button:HookScript("OnEnter", function(self)
            if not self.item then return end
            self:ShowCollectionHover()
            local data = CurrentData(false)
            local assignments =
                GetAssignmentLabels(data and data.Emotes[self.item.id])
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.item.name, 1, 0.82, 0)
            local example = GetEmoteExample(self.item)
            if example then
                GameTooltip:AddLine(example, 1, 1, 1, true)
            else
                GameTooltip:AddLine(self.item.command and ("/" .. self.item.id)
                    or self.item.text, 1, 1, 1, true)
            end
            if self.item.requiresStill then
                GameTooltip:AddLine(
                    L["This emote requires your character to be standing still to trigger."],
                    1, 0.45, 0.15, true)
            end
            if #assignments > 0 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L["Conditions:"], 0.7, 0.7, 0.7)
                for _, label in ipairs(assignments) do
                    GameTooltip:AddLine(label, 1, 0.82, 0)
                end
            end
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function(self)
            self:HideCollectionHover()
            GameTooltip:Hide()
        end)
        s.emoteButtons[index] = button
    end
    LayoutButtons()
    s.emotesFrame:HookScript("OnSizeChanged", LayoutButtons)
    s.emotePageText, s.emotePrevButton, s.emoteNextButton =
        self._PagedShared.CreateNavButtons(s.emotesFrame,
            function() UI_Transmog:EmotePagePrev() end,
            function() UI_Transmog:EmotePageNext() end)
    self:RefreshEmoteList()
end

function UI_Transmog:RefreshEmoteList()
    if not s.emoteButtons then return end
    local search = s.emoteSearchString or ""
    local data = CurrentData(false)
    s.emotePagedItems = {}
    for _, item in ipairs(ns.Emote.GetCatalog()) do
        local matchesSearch = search == ""
            or item.name:lower():find(search, 1, true)
            or (item.text and item.text:lower():find(search, 1, true))
        local selected = IsAssigned(data and data.Emotes[item.id])
        local matchesDefault = not s.emoteDefaultOnly or item.custom ~= true
        local matchesCustom = not s.emoteCustomOnly or item.custom == true
        local matchesCharacter = not s.emoteCharacterOnly
            or (item.custom == true and item.scope == "character")
        local matchesAccount = not s.emoteAccountOnly
            or (item.custom == true and item.scope == "account")
        local matchesAnimation =
            not s.emoteAnimationOnly or item.animation == true
        local matchesVoiceline =
            not s.emoteVoicelineOnly or item.voiceline == true
        if matchesSearch and matchesDefault and matchesCustom
            and matchesCharacter and matchesAccount
            and matchesAnimation and matchesVoiceline
            and (not s.emoteCheckedOnly or selected) then
            s.emotePagedItems[#s.emotePagedItems + 1] = item
        end
    end
    local favorites = FitterSaved and FitterSaved.FavoriteEmotes or {}
    table.sort(s.emotePagedItems, function(a, b)
        local aCustom, bCustom = a.custom == true, b.custom == true
        if aCustom ~= bCustom then return aCustom end
        if aCustom then
            local aCharacter = a.scope == "character"
            local bCharacter = b.scope == "character"
            if aCharacter ~= bCharacter then return aCharacter end
        end
        local aFavorite = favorites[a.id] == true
        local bFavorite = favorites[b.id] == true
        if aFavorite ~= bFavorite then return aFavorite end
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    s.emoteTotalPages = math.max(1, math.ceil(#s.emotePagedItems / PAGE_SIZE))
    s.emoteCurrentPage = math.min(s.emoteCurrentPage or 1, s.emoteTotalPages)
    self:UpdateEmotePageDisplay()
end

function UI_Transmog:UpdateEmotePageDisplay()
    if not s.emoteButtons then return end
    local data = CurrentData(true)
    local start = ((s.emoteCurrentPage or 1) - 1) * PAGE_SIZE
    for index, button in ipairs(s.emoteButtons) do
        local item = s.emotePagedItems[start + index]
        button.item = item
        button:SetShown(item ~= nil)
        if item then
            button:SetText(item.name)
            local fontString = button:GetFontString()
            if fontString then
                if item.custom and item.scope == "account" then
                    if ACCOUNT_WIDE_FONT_COLOR
                        and ACCOUNT_WIDE_FONT_COLOR.GetRGB then
                        fontString:SetTextColor(
                            ACCOUNT_WIDE_FONT_COLOR:GetRGB())
                    else
                        fontString:SetTextColor(0, 0.8, 1)
                    end
                elseif item.custom then
                    fontString:SetTextColor(1, 1, 1)
                else
                    fontString:SetTextColor(1, 0.82, 0)
                end
            end
            button.IconFrame.Icon:SetTexture(ns.Emote.ResolveIcon(item.icon))
            if button.StateTexture then
                button.StateTexture:SetShown(
                    IsAssigned(data and data.Emotes[item.id]))
            end
            button.favoriteStar:SetShown(
                self._PagedShared.IsEmoteFavorite(item.id))
        else
            button.favoriteStar:Hide()
        end
    end
    s.emotePageText:SetText(string.format(L["Page %d/%d"],
        s.emoteCurrentPage or 1, s.emoteTotalPages or 1))
    s.emotePrevButton:SetEnabled((s.emoteCurrentPage or 1) > 1)
    s.emoteNextButton:SetEnabled(
        (s.emoteCurrentPage or 1) < (s.emoteTotalPages or 1))
end

function UI_Transmog:RefreshEmoteRows()
    self:RefreshEmoteList()
end

function UI_Transmog:EmotePagePrev()
    if s.emoteCurrentPage > 1 then
        s.emoteCurrentPage = s.emoteCurrentPage - 1
        self:UpdateEmotePageDisplay()
    end
end

function UI_Transmog:EmotePageNext()
    if s.emoteCurrentPage < s.emoteTotalPages then
        s.emoteCurrentPage = s.emoteCurrentPage + 1
        self:UpdateEmotePageDisplay()
    end
end

function UI_Transmog:ShowEmotes()
    if not s.emotesViewInitialized then
        self:InitializeEmotesView()
        s.emotesViewInitialized = true
    end
    self:_ShowPagedFrame(s.emotesFrame, "RefreshEmoteList")
end
