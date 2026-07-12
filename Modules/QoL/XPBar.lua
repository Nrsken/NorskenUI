---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class XPBar: AceModule, AceEvent-3.0
local XPBar = NRSKNUI:NewModule("XPBar", "AceEvent-3.0")

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
        return string_format("%.2fb", value / 1e9)
    elseif value >= 1e6 then
        return string_format("%.1fm", value / 1e6)
    elseif value >= 1e3 then
        return string_format("%.1fk", value / 1e3)
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

function XPBar:HideBlizzardXPBar()
    if not MainStatusTrackingBarContainer then return end
    NRSKNUI:Banish(MainStatusTrackingBarContainer)
    MainStatusTrackingBarContainer:UnregisterAllEvents()
    MainStatusTrackingBarContainer:Hide()
    MainStatusTrackingBarContainer:SetAlpha(0)
end

function XPBar:OnEnable()
    if not self.db.Enabled then return end

    self:CreateBar()
    self:RegisterEvents()
    self:Update()

    C_Timer.After(1, function()
        self:ApplySettings()
        self:HideBlizzardXPBar()
    end)

    NRSKNUI.EditMode:RegisterElement({
        key = "XPBar",
        displayName = "XP Bar",
        frame = self.bar,
        getPosition = function() return self.db.Position end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            NRSKNUI:ApplyFramePosition(self.bar, self.db.Position, self.db)
        end,
        guiPath = "XPBar",
    })
end

function XPBar:OnDisable()
    if self.bar then self.bar:Hide() end
    self:UnregisterAllEvents()
end

function XPBar:CreateBar()
    if self.bar then return end

    local statusbar = NRSKNUI:GetStatusbarPath(NRSKNUI:GetEffectiveStatusBar(self.db))

    local bar = CreateFrame("StatusBar", "NRSKNUI_XPBar", UIParent)
    bar:SetStatusBarTexture(statusbar)
    bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    bar:Hide()

    local tick = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    tick:SetWidth(1)
    tick:SetColorTexture(0, 0, 0, 1)
    tick:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    tick:Hide()
    bar.tick = tick

    bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bar.bg:SetAllPoints()

    bar.rested = CreateFrame("StatusBar", nil, bar)
    bar.rested:SetAllPoints()
    bar.rested:SetStatusBarTexture(statusbar)
    bar.rested:SetFrameLevel(bar:GetFrameLevel())
    bar.rested:GetStatusBarTexture():SetDrawLayer("BACKGROUND", 2)

    NRSKNUI:AddBorders(bar, self.db.BackdropBorderColor)

    bar.text = NRSKNUI:CreateText(bar, "OVERLAY")
    bar.text:SetPoint("CENTER")

    bar.level = NRSKNUI:CreateText(bar, "OVERLAY")
    bar.level:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

    self.bar = bar

    -- Basic setup without full font styling - ApplySettings will be called by OnEnable after delay
    self.bar:SetSize(self.db.width, self.db.height)
    NRSKNUI:ApplyFramePosition(self.bar, self.db.Position, self.db)
    self:Update()
end

function XPBar:RegisterEvents()
    self:RegisterEvent("PLAYER_XP_UPDATE", "Update")
    self:RegisterEvent("UPDATE_EXHAUSTION", "Update")
    self:RegisterEvent("PLAYER_LEVEL_UP", function()
        C_Timer.After(0.1, function() self:Update() end)
    end)
end

function XPBar:Update()
    if not self.bar then return end

    local currentLevel = UnitLevel("player")
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
        currXP = UnitXP("player")
        maxXP = UnitXPMax("player")
        restedXP = GetXPExhaustion() or 0
    end

    self.bar:SetMinMaxValues(0, maxXP)
    self.bar:SetValue(currXP)

    self.bar.rested:SetMinMaxValues(0, maxXP)
    self.bar.rested:SetValue(math_min(currXP + restedXP, maxXP))

    local percent = (currXP / maxXP) * 100
    self.bar.text:SetFormattedText("%s / %s (%.1f%%)", FormatNumber(currXP), FormatNumber(maxXP), percent)
    self.bar.level:SetFormattedText("Lv %d", currentLevel)

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

    if self.db.ColorModeRested == "theme" or self.db.ColorModeRested == "class" then
        aR = 0.25
    end

    local statusbar = NRSKNUI:GetStatusbarPath(NRSKNUI:GetEffectiveStatusBar(self.db))

    self.bar:SetStatusBarTexture(statusbar)
    self.bar.rested:SetStatusBarTexture(statusbar)

    self.bar:SetStatusBarColor(r, g, b, a)
    self.bar.rested:SetStatusBarColor(rR, gR, bR, aR)

    self.bar:SetSize(self.db.width, self.db.height)
    NRSKNUI:ApplyFramePosition(self.bar, self.db.Position, self.db)

    self.bar.tick:SetHeight(self.bar:GetHeight())
    self.bar.bg:SetColorTexture(unpack(self.db.BackdropColor))

    if self.bar.SetBorderColor then self.bar:SetBorderColor(unpack(self.db.BackdropBorderColor)) end

    NRSKNUI:SetTextFont(self.bar.text, NRSKNUI:GetEffectiveFont(self.db), self.db.FontSize, self.db.FontOutline,
        self.db.FontShadow)
    self.bar.text:SetTextColor(unpack(self.db.TextColor))
    NRSKNUI:SetTextFont(self.bar.level, NRSKNUI:GetEffectiveFont(self.db), self.db.FontSize, self.db.FontOutline,
        self.db.FontShadow)
    self.bar.level:SetTextColor(unpack(self.db.TextColor))

    self:Update()
end

function XPBar:ShowPreview()
    if not self.bar then self:CreateBar() end
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
