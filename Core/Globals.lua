---@class NRSKNUI
local NRSKNUI = select(2, ...)

local print = print
local GetNumGroupMembers = GetNumGroupMembers
local IsInRaid = IsInRaid
local UnitClass = UnitClass
local select = select
local CreateFrame = CreateFrame
local _G = _G

local EditModeManagerFrame = EditModeManagerFrame

local IsAddonLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

-- Check if ElvUI is loaded use ElvUI skinning is enabled
function NRSKNUI:ShouldNotLoadModule() return IsAddonLoaded("ElvUI") and NRSKNUI.db.profile.UseElvUI.Enabled end

-- Check if Blizzard Edit Mode is currently active
function NRSKNUI:IsEditModeActive() return EditModeManagerFrame and EditModeManagerFrame:IsShown() end

-- Print message with class colored addon name prefix
function NRSKNUI:Print(msg) print(self:ColorTextByTheme("Norsken") .. "UI:|r " .. msg) end

-- Preview Utilities --

local PreviewManager = {
    guiOpen = false,
    editModeActive = false,
    previewsActive = false,
}
NRSKNUI.PreviewManager = PreviewManager

function PreviewManager:UpdatePreviewState()
    local shouldShowPreviews = self.guiOpen or self.editModeActive

    if shouldShowPreviews and not self.previewsActive then
        self:StartAllPreviews()
        self.previewsActive = true
    elseif not shouldShowPreviews and self.previewsActive then
        self:StopAllPreviews()
        self.previewsActive = false
    end
end

function PreviewManager:SetGUIOpen(open)
    self.guiOpen = open
    self:UpdatePreviewState()
end

function PreviewManager:SetEditModeActive(active)
    self.editModeActive = active
    self:UpdatePreviewState()
end

function PreviewManager:StartAllPreviews()
    if self._startingPreviews then return end
    self._startingPreviews = true
    for _, module in NRSKNUI:IterateModules() do
        if module.ShowPreview and module.db and module.db.Enabled then module:ShowPreview() end
    end
    self._startingPreviews = false
end

function PreviewManager:StopAllPreviews()
    for _, module in NRSKNUI:IterateModules() do
        if module.HidePreview then module:HidePreview() end
    end
end

function PreviewManager:IsPreviewActive()
    return self.previewsActive
end

-- Positioning Utilities --

-- Get text justification based on anchor point
---@param anchorPoint string
---@return string
function NRSKNUI:GetTextJustifyFromAnchor(anchorPoint)
    if not anchorPoint then return "CENTER" end
    if anchorPoint == "RIGHT" or anchorPoint == "TOPRIGHT" or anchorPoint == "BOTTOMRIGHT" then
        return "RIGHT"
    elseif anchorPoint == "LEFT" or anchorPoint == "TOPLEFT" or anchorPoint == "BOTTOMLEFT" then
        return "LEFT"
    end
    return "CENTER"
end

---@param frame Frame
---@param posConfig table Position config with AnchorFrom, AnchorTo, XOffset, YOffset
---@param Config table Config with anchorFrameType, ParentFrame, Strata
---@param SetParent boolean? If true, also set frame parent
function NRSKNUI:ApplyFramePosition(frame, posConfig, Config, SetParent)
    if not frame or not posConfig then return end
    local parent = self:ResolveAnchorFrame(Config.anchorFrameType, Config.ParentFrame)
    if SetParent then frame:SetParent(parent) end
    frame:ClearAllPoints()
    frame:SetPoint(posConfig.AnchorFrom or "CENTER", parent, posConfig.AnchorTo or "CENTER", posConfig.XOffset or 0, posConfig.YOffset or 0)
    frame:SetFrameStrata(Config.Strata or "MEDIUM")
end

-- Class Utilities --

---@param classFilenameToCheck 'WARRIOR'|'HUNTER'|'ROGUE'|'MAGE'|'PRIEST'|'WARLOCK'|'DRUID'|'SHAMAN'|'PALADIN'|'DEATHKNIGHT'|'MONK'|'DEMONHUNTER'
function NRSKNUI:IsClassInGroup(classFilenameToCheck)
    local numMembers = GetNumGroupMembers()
    local prefix = (IsInRaid() and 'raid') or 'party'
    local maxCheck = (IsInRaid() and numMembers) or (numMembers - 1)
    for i = 1, maxCheck do
        local unit = prefix .. i
        local classFilename = select(2, UnitClass(unit))
        if classFilename == classFilenameToCheck then
            return true
        end
    end
    return false
end
