-- NorskenUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Safety check
if not NorskenUI then
    error("RangeChecker: Addon object not initialized. Check file load order!")
    return
end

-- Create module
---@class RangeChecker: AceModule, AceEvent-3.0
local RANGE = NorskenUI:NewModule("RangeChecker", "AceEvent-3.0")
local LRC = LibStub("LibRangeCheck-3.0", true)

-- Localization
local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack
local InCombatLockdown = InCombatLockdown
local unpack = unpack

-- Gradient color palette (red -> orange -> yellow -> green)
local GradientColorPalet = {
    1, 0, 0,    -- Red (far)
    1, 0.42, 0, -- Orange
    1, 0.82, 0, -- Yellow
    0, 1, 0     -- Green (close)
}

-- Module state
RANGE.frame = nil
RANGE.text = nil
RANGE.isPreview = false

-- Update db, used for profile changes
function RANGE:UpdateDB()
    self.db = NRSKNUI.db.profile.RangeChecker
end

-- Module init
function RANGE:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Get color based on range
function RANGE:GetColorForRange(minRange)
    local maxRange = self.db.MaxRange or 40
    local r, g, b = NRSKNUI:ColorGradient(maxRange - (minRange or 0), maxRange, unpack(GradientColorPalet))
    return r, g, b
end

-- Format range text
function RANGE:FormatRangeText(minRange, maxRange)
    if minRange and maxRange then
        return minRange .. " - " .. maxRange
    elseif maxRange then
        return "0 - " .. maxRange
    elseif minRange then
        return minRange
    else
        return "--"
    end
end

-- Create range display frame
function RANGE:CreateFrame()
    if self.frame then return end
    local parent = NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
    local frame = CreateFrame("Frame", "NRSKNUI_RangeCheckerFrame", parent)
    frame:SetSize(100, 25)
    frame:EnableMouse(false)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")

    self.frame = frame
    self.text = text

    self:ApplySettings()
end

-- Apply settings
function RANGE:ApplySettings()
    if not self.frame or not self.text then return end
    NRSKNUI:ApplyFontToText(self.text, self.db.FontFace, self.db.FontSize, self.db.FontOutline, {})
    self.frame:SetFrameStrata(self.db.Strata or "HIGH")
    self:ApplyPosition()
end

-- Apply position
function RANGE:ApplyPosition()
    if not self.frame then return end
    NRSKNUI:ApplyFramePosition(self.frame, self.db.Position, self.db, true)
end

-- Check if we should show the range display
function RANGE:ShouldShow()
    if self.isPreview then return true end
    if not UnitExists("target") then return false end
    if not UnitCanAttack("player", "target") then return false end
    if self.db.CombatOnly and not InCombatLockdown() then return false end
    return true
end

-- Update range display
function RANGE:UpdateRange()
    if not self.frame or not self.text then return end

    if not self:ShouldShow() then
        self.frame:Hide()
        return
    end

    local minRange, maxRange

    -- Preview stuff
    if self.isPreview then
        minRange, maxRange = 10, 15
    else
        -- Get actual range from LibRangeCheck
        if LRC then
            minRange, maxRange = LRC:GetRange("target")
        end
    end

    -- Format and display range text
    local rangeText = self:FormatRangeText(minRange, maxRange)
    self.text:SetText(rangeText)

    -- Apply color based on range
    local r, g, b = self:GetColorForRange(minRange or maxRange or 40)
    self.text:SetTextColor(r, g, b, 1)

    -- Update frame size to fit text, looks nicer in editMode
    local textWidth = self.text:GetStringWidth() or 50
    local textHeight = self.text:GetStringHeight() or 20
    self.frame:SetSize(textWidth + 10, textHeight + 4)
    self.frame:Show()
end

-- OnUpdate handler
local updateElapsed = 0
function RANGE:OnUpdate(elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < self.db.UpdateThrottle then return end
    updateElapsed = 0

    self:UpdateRange()
end

-- Preview mode
function RANGE:ShowPreview()
    if not self.frame then self:CreateFrame() end
    self.isPreview = true
    self:ApplySettings()
    self:UpdateRange()
end

function RANGE:HidePreview()
    self.isPreview = false
    self:UpdateRange()
end

-- Module OnEnable
function RANGE:OnEnable()
    if not self.db.Enabled then return end
    if not LRC then
        NRSKNUI:Print("RangeChecker: LibRangeCheck-3.0 not found!")
        return
    end

    self:CreateFrame()
    self:ApplySettings()

    C_Timer.After(0.5, function()
        self:ApplyPosition()
    end)

    -- Register events
    self:RegisterEvent("PLAYER_TARGET_CHANGED", function() self:UpdateRange() end)
    self:RegisterEvent("PLAYER_REGEN_DISABLED", function() self:UpdateRange() end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function() self:UpdateRange() end)
    -- Set up OnUpdate
    self.frame:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)

    -- Initial update
    self:UpdateRange()

    -- Register with EditMode
    NRSKNUI.EditMode:RegisterElement({
        key = "RangeChecker",
        displayName = "Range Checker",
        frame = self.frame,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            self:ApplyPosition()
        end,
        getParentFrame = function()
            return NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
        end,
        guiPath = "RangeChecker",
    })
end

-- Module OnDisable
function RANGE:OnDisable()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    self.isPreview = false
    self:UnregisterAllEvents()
end
