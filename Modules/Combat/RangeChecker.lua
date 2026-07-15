---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class RangeChecker
local RangeChecker = NRSKNUI:GetModule('RangeChecker')
local LRC = NRSKNUI.Libs.LRC
local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local InCombatLockdown = InCombatLockdown
local unpack = unpack
local tostring = tostring

function RangeChecker:UpdateDB()
    self.db = NRSKNUI.db.profile.RangeChecker
end

function RangeChecker:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function RangeChecker:BuildGradientPalette()
    local c1 = self.db.ColorOne
    local c2 = self.db.ColorTwo
    local c3 = self.db.ColorThree
    local c4 = self.db.ColorFour

    self.gradientPalette = { c1[1], c1[2], c1[3], c2[1], c2[2], c2[3], c3[1], c3[2], c3[3], c4[1], c4[2], c4[3], }
end

---@param minRange number|nil
---@param maxRange number|nil
---@return string
function RangeChecker:FormatRangeText(minRange, maxRange)
    if minRange and maxRange then -- Both min and max range are available
        return minRange .. ' - ' .. maxRange
    elseif maxRange then          -- No min range, but max range is available
        return '0 - ' .. maxRange
    elseif minRange then          -- No max range, but min range is available
        return tostring(minRange)
    end
    return '--' -- No range information available
end

function RangeChecker:CreateFrame()
    if self.frame then return end

    local frame = CreateFrame('Frame', 'NRSKNUI_RangeCheckerFrame', UIParent)
    frame:SetSize(100, 25)
    frame:EnableMouse(false)
    frame:SetMouseClickEnabled(false)

    frame.text = frame:CreateFontString(nil, 'OVERLAY')
    frame.text:SetAllPoints(frame)

    -- Finalize the frame and register it with Anchors.
    self.frame = frame
    EM:Register(self, 'RangeCheckerAlert', self.frame, 'RangeChecker')
    frame:Hide()
end

function RangeChecker:ApplySettings()
    if not self.frame then return end
    self:BuildGradientPalette()

    self.frame:ApplyPosition(self.db)
    self.frame.text:SetFontStyle(self.db)
    self.frame.text:SetFontJustify(self.db)
    self.frame.text:SetText(self:FormatRangeText(10, 12))

    local textWidth = self.frame.text:GetStringWidth() or 50
    local textHeight = self.frame.text:GetStringHeight() or 20
    self.frame:SetPixelSize(textWidth + 10, textHeight + 4)
end

function RangeChecker:ShouldShow()
    if not self.db.Enabled then return false end
    if self.isPreview then return true end
    if not UnitExists('target') then return false end
    if UnitIsUnit('target', 'player') then return false end
    if self.db.CombatOnly and not InCombatLockdown() then return false end
    return true
end

function RangeChecker:UpdateRange()
    if not self.frame then return end

    if not self:ShouldShow() then
        self.frame:Hide()
        return
    end

    local minRange, maxRange
    if self.isPreview then
        minRange, maxRange = 10, 12
    elseif LRC then
        minRange, maxRange = LRC:GetRange('target')
    end

    self.frame.text:SetText(self:FormatRangeText(minRange, maxRange))

    local rangeValue = minRange or maxRange or 40
    if rangeValue ~= self.lastRangeValue then
        self.lastRangeValue = rangeValue

        local r, g, b = NRSKNUI:ColorGradient(self.db.MaxRange - (rangeValue or 0), self.db.MaxRange, unpack(self.gradientPalette))
        self.frame.text:SetTextColor(r, g, b, 1)
    end

    local textWidth = self.frame.text:GetStringWidth() or 50
    local textHeight = self.frame.text:GetStringHeight() or 20
    self.frame:SetPixelSize(textWidth + 10, textHeight + 4)
    self.frame:Show()
end

local updateElapsed = 0
function RangeChecker:OnUpdate(elapsed)
    updateElapsed = updateElapsed + elapsed
    if updateElapsed < self.db.UpdateThrottle then return end
    updateElapsed = 0
    self:UpdateRange()
end

function RangeChecker:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()
    self:ApplySettings()
    self:UpdateRange()

    self.frame:SetScript('OnUpdate', function(_, elapsed) self:OnUpdate(elapsed) end)

    self:RegisterEvent('PLAYER_TARGET_CHANGED', function() self:UpdateRange() end)
    self:RegisterEvent('PLAYER_REGEN_DISABLED', function() self:UpdateRange() end)
    self:RegisterEvent('PLAYER_REGEN_ENABLED', function() self:UpdateRange() end)
end

function RangeChecker:OnDisable()
    if self.frame then
        self.frame:SetScript('OnUpdate', nil)
        self.frame:Hide()
        EM:UnregisterModuleElement('RangeChecker')
    end
    self.isPreview = false
end

function RangeChecker:ShowPreview()
    if not self.frame then self:CreateFrame() end
    self.isPreview = true
    self:ApplySettings()
    self:UpdateRange()

    -- Utilize 12.1.0 utility to run OnUpdate only once when previewing.
    if self.frame.SetOnUpdateMode then
        local disabledEnum = Enum and Enum.OnUpdateMode.Disabled
        self.frame:SetOnUpdateMode(disabledEnum)
    end
end

function RangeChecker:HidePreview()
    if not self.frame then return end
    self.isPreview = false
    self:UpdateRange()

    -- Utilize 12.1.0 utility to run OnUpdate only when visible.
    if self.frame.SetOnUpdateMode then
        local runWhenVisibleEnum = Enum and Enum.OnUpdateMode.RunWhenVisible
        self.frame:SetOnUpdateMode(runWhenVisibleEnum)
    end
end
