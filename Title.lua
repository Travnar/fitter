local addonName, ns = ...

local Title = {}
ns.Title = Title

function Title.GetSlashArg(titleID)
    if not titleID or titleID <= 0 then return nil end
    if not IsTitleKnown or not IsTitleKnown(titleID) then return nil end
    local raw = GetTitleName and GetTitleName(titleID)
    if not raw or raw == "" then return nil end
    local cleaned = raw:gsub("%%s", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if cleaned == "" then return nil end
    return cleaned
end

local titleButton = CreateFrame("Button", "FitterTitleButton", UIParent, "SecureActionButtonTemplate")
titleButton:SetSize(1, 1)
titleButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
titleButton:SetAlpha(0)
titleButton:RegisterForClicks("AnyUp", "AnyDown")
titleButton:SetAttribute("type", "macro")
titleButton:SetAttribute("macrotext", "")
titleButton:SetScript("PostClick", function(self)
    self:SetAttribute("macrotext", "")
end)
Title.button = titleButton

function Title.Apply(outfitIDOverride)
    if InCombatLockdown() then return end
    if not C_TransmogOutfitInfo or not FitterCharacterSaved then return end

    local activeOutfitID = outfitIDOverride
        or (C_TransmogOutfitInfo.GetActiveOutfitID and C_TransmogOutfitInfo.GetActiveOutfitID())
    if not activeOutfitID or activeOutfitID == 0 then return end

    local data = FitterCharacterSaved["Outfit"..activeOutfitID]
    if not data then return end

    local target = data.Title
    -- nil or -1 means "Ignore Title" - leave the current title unchanged
    if target == nil or target == -1 then return end

    -- 0 means "No Title" - clear via WoW API sentinel -1
    local apiTarget = (target == 0) and -1 or target

    local current = GetCurrentTitle and GetCurrentTitle() or -1
    if apiTarget == current then return end

    if apiTarget == -1 or (IsTitleKnown and IsTitleKnown(apiTarget)) then
        SetCurrentTitle(apiTarget)
    end
end
