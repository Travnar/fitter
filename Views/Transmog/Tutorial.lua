-- A guided tour of the outfit window, shown as Blizzard HelpTips.
local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog
local s = UI_Transmog._s

local tour
local hooksInstalled = false

local function BuildSteps()
    local Point, Alignment = HelpTip.Point, HelpTip.Alignment
    local steps = {}
    local function Add(step) steps[#steps + 1] = step end

    Add({
        title = L["Outfits"],
        text = L["Fitter adds mounts, pets, hearthstones, toys, titles and more to your outfits. Select an outfit here, and everything you choose in this window is saved to it.\n\nClose the window at any time to end the tutorial."],
        target = function() return TransmogFrame.OutfitCollection end,
        point = Point.RightEdgeCenter,
    })
    if ns.Features.FlyingMounts then
        Add({
            title = L["Mounts"],
            text = L["These slots hold the outfit's flying, ground and aquatic mounts. Select a slot, then choose one or more mounts. With several chosen, Fitter picks one at random."],
            slot = "flyingSlotFrame",
            point = Point.TopEdgeCenter,
            alignment = Alignment.Left,
        })
    else
        Add({
            title = L["Mounts"],
            text = L["This slot holds the outfit's mounts. Select it, then choose one or more mounts. With several chosen, Fitter picks one at random."],
            slot = "groundSlotFrame",
            point = Point.TopEdgeCenter,
            alignment = Alignment.Left,
        })
    end
    Add({
        title = L["Pets"],
        text = L["Choose one or more companion pets. Fitter summons one automatically when your outfit changes."],
        slot = "petSlotFrame",
        point = Point.RightEdgeCenter,
    })
    if s.hunterPetFrame then
        Add({
            title = L["Hunter Pets"],
            text = L["Choose the hunter pets that go with this outfit. Fitter calls one when you use its macros or key bindings."],
            slot = "hunterPetSlotFrame",
            point = Point.TopEdgeCenter,
        })
    end
    Add({
        title = L["Hearthstones"],
        text = L["Choose one or more hearthstones. Fitter's hearthstone action uses one at random, or any hearthstone you own when none are chosen."],
        slot = "hearthstoneSlotFrame",
        point = Point.LeftEdgeCenter,
    })
    Add({
        title = L["Cosmetic Toys"],
        text = L["Choose toys to use with this outfit. They are used when you press Fitter's mount action."],
        slot = "toySlotFrame",
        point = Point.TopEdgeCenter,
        alignment = Alignment.Right,
    })
    Add({
        title = L["Conditions"],
        text = L["Associate this outfit with zones, holidays and activities. Fitter switches to a matching outfit when you press its mount action."],
        slot = "zonesSlotFrame",
        point = Point.LeftEdgeCenter,
    })
    Add({
        title = L["Emotes"],
        text = L["Choose emotes for your character to perform while wearing this outfit, such as when mounting, resting or targeting someone."],
        slot = "emotesSlotFrame",
        point = Point.BottomEdgeCenter,
        alignment = Alignment.Right,
    })
    Add({
        title = L["Title"],
        text = L["Choose a title to wear with this outfit. It is applied when you press Fitter's mount action."],
        target = function()
            if s.titleSearch and s.titleSearch:IsShown() then return s.titleSearch end
            return s.titleDropdown
        end,
        point = Point.BottomEdgeCenter,
    })
    Add({
        title = "Fitter",
        text = L["The Fitter tab saves an outfit's choices as a loadout to reuse on other outfits, shares them in chat, and sets up mount conditionals."],
        enter = function()
            local wc = TransmogFrame.WardrobeCollection
            if wc.fitterAdditionalTabID then wc:SetTab(wc.fitterAdditionalTabID) end
        end,
        target = function()
            local wc = TransmogFrame.WardrobeCollection
            return wc.GetTabButton and wc.fitterAdditionalTabID
                and wc:GetTabButton(wc.fitterAdditionalTabID) or s.additionalFrame
        end,
        point = Point.TopEdgeCenter,
    })
    Add({
        title = L["Key Bindings and Macros"],
        text = L["Mounts, toys, titles and outfit changes need a button press. Bind Fitter's actions under Options > Keybindings > Fitter, or create its macros under Options > AddOns > Fitter and place them on your action bars.\n\nUse Fitter's mount action as your normal mount button."],
        target = function() return TransmogFrame.CharacterPreview end,
        point = Point.TopEdgeCenter,
        centered = true,
    })
    return steps
end

local function HideTip()
    if tour and tour.tipText then
        HelpTip:Hide(UIParent, tour.tipText)
        tour.tipText = nil
    end
end

local EnterStep

local function AnchorTip()
    HideTip()
    local step = tour.steps[tour.index]
    local target = step.slot and s[step.slot] or step.target and step.target()
        or TransmogFrame.CharacterPreview
    local isLast = tour.index == #tour.steps
    local heading = string.format(L["%s (%d/%d)"], step.title, tour.index, #tour.steps)
    local text = NORMAL_FONT_COLOR:WrapTextInColorCode(heading) .. "\n\n" .. step.text
    local thisTour = tour

    tour.tipText = text
    -- Parented to UIParent rather than TransmogFrame: see
    -- UI_Transmog._CreateDetachedFrame.
    HelpTip:Show(UIParent, {
        text = text,
        textJustifyH = "LEFT",
        buttonStyle = isLast
            and (HelpTip.ButtonStyle.GotIt or HelpTip.ButtonStyle.Okay)
            or HelpTip.ButtonStyle.Next,
        targetPoint = step.point,
        alignment = step.alignment,
        hideArrow = step.centered,
        offsetY = step.centered and -(target:GetHeight() / 2 + 80) or 0,
        autoEdgeFlipping = true,
        onAcknowledgeCallback = function()
            if tour ~= thisTour then return end
            tour.tipText = nil
            -- Wait for HelpTip to release this tip, so the next step reuses
            -- its frame instead of creating one while TransmogFrame is open.
            C_Timer.After(0, function()
                if tour ~= thisTour then return end
                if isLast then
                    tour = nil
                else
                    tour.index = tour.index + 1
                    EnterStep()
                end
            end)
        end,
    }, target)
end

EnterStep = function()
    local step = tour.steps[tour.index]
    local slotFrame = step.slot and s[step.slot]
    if slotFrame and slotFrame.isFitterMountSlot then
        slotFrame:Click("LeftButton")
    end
    if step.enter then step.enter() end
    AnchorTip()
end

local function InstallHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    TransmogFrame:HookScript("OnHide", function()
        UI_Transmog:StopTutorial()
    end)

    -- SetupSlots releases and re-acquires the slot frames the tips point at.
    hooksecurefunc(TransmogFrame.CharacterPreview, "SetupSlots", function()
        local thisTour = tour
        if not thisTour then return end
        C_Timer.After(0, function()
            if tour == thisTour and tour.tipText then AnchorTip() end
        end)
    end)
end

function UI_Transmog:StopTutorial()
    if not tour then return end
    HideTip()
    tour = nil
end

function UI_Transmog:StartTutorial()
    if not HelpTip then return end
    self:StopTutorial()

    if not (TransmogFrame and TransmogFrame:IsShown()) then
        -- Create the tip frame before TransmogFrame opens; see
        -- UI_Transmog._CreateDetachedFrame.
        if HelpTip:Show(UIParent, { text = " " }) then
            HelpTip:Hide(UIParent, " ")
        end
        self:OpenOffVendor()
    elseif SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    end
    if not (TransmogFrame and TransmogFrame:IsShown()) or not s.mountIconsInitialized then
        return
    end

    InstallHooks()
    tour = { index = 1, steps = BuildSteps() }
    EnterStep()
end
