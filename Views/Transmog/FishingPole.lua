local addonName, ns = ...
local L = ns.L
local UI_Transmog = ns.UI_Transmog

-- Row matches the Character section's reset row; y is its offset.
function UI_Transmog:InitializeFishingPoleOption(parent, y)
    if not ns.Features.EquipFishingPole then return end
    local label = L["Equip Fishing Pole"]

    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 86, y)
    row:SetPoint("RIGHT", parent, "RIGHT", -70, 0)
    row:SetHeight(26)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT")
    text:SetText(label)

    local checkbox = CreateFrame("CheckButton", nil, row, "SettingsCheckBoxTemplate")
    checkbox:SetPoint("RIGHT")
    checkbox:SetScript("OnClick", function(self)
        FitterCharacterSaved = FitterCharacterSaved or {}
        FitterCharacterSaved.EquipFishingPole = self:GetChecked() or nil
        ns.Macro.UpdateFishing()
    end)

    local function ShowTooltip(owner)
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(label)
        GameTooltip:AddLine(L["When casting Fishing from Fitter's macro or key binding, equip the best fishing pole in your bags. Your weapons are put back 10 seconds after you stop fishing."],
            1, 1, 1, true)
        GameTooltip:Show()
    end
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)
    checkbox:SetScript("OnEnter", ShowTooltip)
    checkbox:SetScript("OnLeave", GameTooltip_Hide)

    local function Refresh()
        checkbox:SetChecked(ns.FishingPole.IsEnabled())
    end
    parent:HookScript("OnShow", Refresh)
    Refresh()
end
