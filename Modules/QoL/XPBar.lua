---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class XPBar
local XPBar = NRSKNUI:GetModule('XPBar')
local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local UnitLevel = UnitLevel
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GetXPExhaustion = GetXPExhaustion
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion
local tostring = tostring
local unpack = unpack
local math_min = math.min
local string_format = string.format
local MainStatusTrackingBarContainer = MainStatusTrackingBarContainer

XPBar.isPreview = false

local function FormatNumber(value)
    if value >= 1e9 then
        return string_format('%.2fb', value / 1e9)
    elseif value >= 1e6 then
        return string_format('%.1fm', value / 1e6)
    elseif value >= 1e3 then
        return string_format('%.1fk', value / 1e3)
    end
    return tostring(value)
end

function XPBar:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.XPBar
end

function XPBar:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function XPBar:CreateBar()
    if self.bar then return end

    local statusbar = NRSKNUI:GetStatusbarPath(NRSKNUI:GetEffectiveStatusBar(self.db))

    local bar = CreateFrame('StatusBar', 'NRSKNUI_XPBar', UIParent)
    bar:SetStatusBarTexture(statusbar)
    bar:GetStatusBarTexture():SetDrawLayer('ARTWORK')
    bar:AddBorders()

    bar.tick = bar:CreateTexture(nil, 'OVERLAY', nil, 1)
    bar.tick:SetPixelWidth(1)
    bar.tick:SetColorTexture(0, 0, 0, 1)
    bar.tick:SetPixelPoint('CENTER', bar:GetStatusBarTexture(), 'RIGHT', 0, 0)
    bar.tick:Hide()

    bar.bg = bar:CreateTexture(nil, 'BACKGROUND', nil, -8)
    bar.bg:SetAllPoints()

    bar.rested = CreateFrame('StatusBar', nil, bar)
    bar.rested:SetAllPoints()
    bar.rested:SetStatusBarTexture(statusbar)
    bar.rested:SetFrameLevel(bar:GetFrameLevel())
    bar.rested:GetStatusBarTexture():SetDrawLayer('BACKGROUND', 2)

    bar.text = bar:CreateFontString(nil, 'OVERLAY')
    bar.text:SetPixelPoint('CENTER')
    bar.text:SetFontStyle(self.db)

    bar.level = bar:CreateFontString(nil, 'OVERLAY')
    bar.level:SetPixelPoint('RIGHT', bar, 'RIGHT', -4, 0)
    bar.level:SetFontStyle(self.db)

    self.bar = bar
    bar:Hide()
end

function XPBar:RegisterEvents()
    self:RegisterEvent('PLAYER_XP_UPDATE', 'Update')
    self:RegisterEvent('UPDATE_EXHAUSTION', 'Update')
    self:RegisterEvent('PLAYER_LEVEL_UP', function()
        C_Timer.After(0.1, function() self:Update() end)
    end)
end

function XPBar:Update()
    if not self.bar then return end

    local currentLevel = UnitLevel('player')
    local maxLevel = GetMaxLevelForPlayerExpansion()
    local isMaxLevel = currentLevel >= maxLevel

    if isMaxLevel and not self.isPreview then
        self.bar:Hide()
        self:UnregisterAllEvents()
        return
    end

    local currXP, maxXP, restedXP

    if self.isPreview or isMaxLevel then
        currXP = 125000
        maxXP = 250000
        restedXP = 50000
    else
        currXP = UnitXP('player')
        maxXP = UnitXPMax('player')
        restedXP = GetXPExhaustion() or 0
    end

    self.bar:SetMinMaxValues(0, maxXP)
    self.bar:SetValue(currXP)

    self.bar.rested:SetMinMaxValues(0, maxXP)
    self.bar.rested:SetValue(math_min(currXP + restedXP, maxXP))

    local percent = (currXP / maxXP) * 100
    self.bar.text:SetFormattedText('%s / %s (%.1f%%)', FormatNumber(currXP), FormatNumber(maxXP), percent)
    self.bar.level:SetFormattedText('Lv %d', currentLevel)

    if currXP > 0 and currXP < maxXP then
        self.bar.tick:Show()
    else
        self.bar.tick:Hide()
    end

    self.bar:Show()
end

function XPBar:ApplySettings()
    if not self.bar then return end

    local r, g, b, a = NRSKNUI:GetAccentColor(self.db.ColorMode, self.db.StatusColor)
    local rR, gR, bR, aR = NRSKNUI:GetAccentColor(self.db.ColorModeRested, self.db.RestedColor)

    if self.db.ColorModeRested == 'theme' or self.db.ColorModeRested == 'class' then
        aR = 0.25
    end

    local statusbar = NRSKNUI:GetStatusbarPath(NRSKNUI:GetEffectiveStatusBar(self.db))

    self.bar:SetStatusBarTexture(statusbar)
    self.bar.rested:SetStatusBarTexture(statusbar)

    self.bar:SetStatusBarColor(r, g, b, a)
    self.bar.rested:SetStatusBarColor(rR, gR, bR, aR)

    self.bar:SetPixelSize(self.db.width, self.db.height)
    self.bar:ApplyPosition(self.db)

    self.bar.tick:SetPixelHeight(self.bar:GetHeight())
    self.bar.bg:SetColorTexture(unpack(self.db.BackdropColor))

    if self.bar.SetBorderColor then self.bar:SetBorderColor(unpack(self.db.BackdropBorderColor)) end

    self.bar.text:SetFontStyle(self.db)
    self.bar.text:SetTextColor(unpack(self.db.TextColor))
    self.bar.level:SetFontStyle(self.db)
    self.bar.level:SetTextColor(unpack(self.db.TextColor))

    self:Update()
end

function XPBar:OnEnable()
    if not self.db.Enabled then return end

    self:CreateBar()
    self:ApplySettings()

    self:RegisterEvents()
    self:Update()

    if MainStatusTrackingBarContainer then
        MainStatusTrackingBarContainer:Banish()
        MainStatusTrackingBarContainer:UnregisterAllEvents()
        MainStatusTrackingBarContainer:Hide()
        MainStatusTrackingBarContainer:SetAlpha(0)
    end

    EM:Register(self, 'XPBar', self.bar, 'XPBar')
end

function XPBar:OnDisable()
    if self.bar then self.bar:Hide() end
end

function XPBar:ShowPreview()
    if not self.bar then return end
    self.isPreview = true
    self.bar:Show()
    self:ApplySettings()
end

function XPBar:HidePreview()
    self.isPreview = false
    if not self.bar then return end

    if not self.db.Enabled then
        self.bar:Hide()
        self:UnregisterAllEvents()
        return
    end

    self:Update()
end
