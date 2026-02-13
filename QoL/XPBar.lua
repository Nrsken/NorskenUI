-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("XPBar: Addon object not initialized. Check file load order!")
    return
end

-- Localization
local UnitLevel = UnitLevel
local CreateFrame = CreateFrame
local UnitXP = UnitXP
local UnitXPMax = UnitXPMax
local GetXPExhaustion = GetXPExhaustion
local tostring = tostring
local unpack = unpack
local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion
local MainStatusTrackingBarContainer = MainStatusTrackingBarContainer

-- Module variables
local HideBlizzardBarInit = false

-- Create module
local XPBar = NRSKNUI.Addon:NewModule("XPBar", "AceEvent-3.0")

-- Module init
function XPBar:OnInitialize()
    self.db = NRSKNUI.db.profile.Miscellaneous.XPBar
    self:SetEnabledState(false)
end

-- Get color based on color mode
function XPBar:GetColor()
    local colorMode = self.db.ColorMode or "theme"
    return NRSKNUI:GetAccentColor(colorMode, self.db.StatusColor)
end

-- Helper to format numbers
local function FormatNumber(value)
    if value >= 1e9 then
        return string.format("%.2fb", value / 1e9)
    elseif value >= 1e6 then
        return string.format("%.1fm", value / 1e6)
    elseif value >= 1e3 then
        return string.format("%.1fk", value / 1e3)
    else
        return tostring(value)
    end
end

-- Helper to hide blizzards own xp bar
function XPBar:HideBlizzardXPBar()
    if MainStatusTrackingBarContainer then
        NRSKNUI:Hide(MainStatusTrackingBarContainer)
        MainStatusTrackingBarContainer:UnregisterAllEvents()
        MainStatusTrackingBarContainer:Hide()
        MainStatusTrackingBarContainer:SetAlpha(0)
    end
end

-- Module OnEnable
function XPBar:OnEnable()
    if not self.db.Enabled then return end

    self:CreateBar()
    self:RegisterEvents()
    self:Update()
    C_Timer.After(1, function()
        self:ApplyStyling()
    end)

    -- Register with EditMode if not already registered
    if NRSKNUI.EditMode and not self.editModeRegistered then
        local config = {
            key = "XPBar",
            displayName = "XP Bar",
            frame = self.bar,
            getPosition = function()
                return self.db.Position
            end,
            setPosition = function(pos)
                self.db.Position.AnchorFrom = pos.AnchorFrom
                self.db.Position.AnchorTo = pos.AnchorTo
                self.db.Position.XOffset = pos.XOffset
                self.db.Position.YOffset = pos.YOffset
                NRSKNUI:ApplyFramePosition(self.bar, self.db.Position, self.db)
            end,
            guiPath = "XPBar",
        }
        NRSKNUI.EditMode:RegisterElement(config)
        self.editModeRegistered = true
    end

    if self.db.HideBlizzardBar then
        C_Timer.After(1, function()
            self:HideBlizzardXPBar()
            HideBlizzardBarInit = true
        end)
    end
end

-- Module OnDisable
function XPBar:OnDisable()
    if self.bar then
        self.bar:Hide()
    end

    self:UnregisterAllEvents()
end

-- Create XP bar
function XPBar:CreateBar()
    if self.bar then return end
    local r, g, b, a = self:GetColor()
    local statusbar = NRSKNUI:GetStatusbarPath(self.db.StatusBarTexture or "NorskenUI")

    local bar = CreateFrame("StatusBar", "NorskenUI_XPBar", UIParent)
    bar:SetSize(self.db.width, self.db.height)
    bar:SetStatusBarTexture(statusbar)
    bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    bar:SetStatusBarColor(r, g, b, a)

    -- Apply position
    NRSKNUI:ApplyFramePosition(bar, self.db.Position, self.db)

    -- Create the Tick
    local tick = bar:CreateTexture(nil, "OVERLAY", nil, 1)
    tick:SetWidth(1)
    tick:SetHeight(bar:GetHeight())
    tick:SetColorTexture(0, 0, 0, 1)
    tick:Hide()

    -- Anchor it to the right side of the main bar's texture
    tick:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    bar.tick = tick

    -- Background
    bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(unpack(self.db.BackdropColor))

    -- Rested XP bar
    bar.rested = CreateFrame("StatusBar", nil, bar)
    bar.rested:SetAllPoints()
    bar.rested:SetStatusBarTexture(statusbar)
    bar.rested:SetStatusBarColor(unpack(self.db.RestedColor))
    bar.rested:SetFrameLevel(bar:GetFrameLevel())
    bar.rested:GetStatusBarTexture():SetDrawLayer("BACKGROUND", 2)

    -- Add borders using helper
    NRSKNUI:AddBorders(bar, self.db.BackdropBorderColor)

    -- Progress text
    bar.text = bar:CreateFontString(nil, "OVERLAY")
    bar.text:SetPoint("CENTER")
    NRSKNUI:ApplyFontToText(bar.text, self.db.FontFace, self.db.FontSize, self.db.FontOutline)
    bar.text:SetTextColor(unpack(self.db.TextColor))

    -- Level text (right side)
    bar.level = bar:CreateFontString(nil, "OVERLAY")
    bar.level:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    NRSKNUI:ApplyFontToText(bar.level, self.db.FontFace, self.db.FontSize, self.db.FontOutline)
    bar.level:SetTextColor(unpack(self.db.TextColor))

    self.bg = bar.bg
    self.bar = bar
end

-- Event reg
function XPBar:RegisterEvents()
    self:RegisterEvent("PLAYER_XP_UPDATE", "Update")
    self:RegisterEvent("UPDATE_EXHAUSTION", "Update")
    self:RegisterEvent("PLAYER_LEVEL_UP", "OnLevelUp")
end

-- Update xp bar with new values
function XPBar:Update()
    if not self.bar then return end
    local currentLevel = UnitLevel("player")
    local maxLevel = GetMaxLevelForPlayerExpansion()

    -- Hide bar and return if current level == max level and hideWhenMax db is enabled
    if self.db.hideWhenMax and currentLevel == maxLevel then
        self.bar:Hide()
        self:UnregisterAllEvents()
        return
    end

    -- Handle Max Level display
    if currentLevel >= maxLevel then
        self.bar:SetMinMaxValues(0, 1)
        self.bar:SetValue(1)
        self.bar.rested:SetValue(0)

        -- Update text to show Max Level instead of numbers
        self.bar.text:SetText("Maximum Level Reached")
        self.bar.level:SetFormattedText("Lv %d", currentLevel)

        self.bar:Show()
        return
    end

    -- Standard XP logic for levels below max level
    local currXP = UnitXP("player")
    local maxXP = UnitXPMax("player")
    local restedXP = GetXPExhaustion() or 0

    self.bar:SetMinMaxValues(0, maxXP)
    self.bar:SetValue(currXP)

    self.bar.rested:SetMinMaxValues(0, maxXP)
    self.bar.rested:SetValue(math.min(currXP + restedXP, maxXP))

    local percent = (currXP / maxXP) * 100

    self.bar.text:SetFormattedText("%s / %s (%.1f%%)",
        FormatNumber(currXP),
        FormatNumber(maxXP),
        percent
    )

    self.bar.level:SetFormattedText("Lv %d", currentLevel)

    -- Tick update
    if currXP > 0 and currXP < maxXP then
        self.bar.tick:Show()
    else
        self.bar.tick:Hide()
    end

    self.bar:Show()
end

-- Delayed update on level up
function XPBar:OnLevelUp()
    C_Timer.After(0.1, function()
        self:Update()
    end)
end

-- Function that GUI can call for updates
function XPBar:ApplyStyling()
    if not self.bar then return end
    local r, g, b, a = self:GetColor()

    if not HideBlizzardBarInit and self.db.HideBlizzardBar then
        C_Timer.After(1, function()
            self:HideBlizzardXPBar()
            HideBlizzardBarInit = true
        end)
    end

    -- Update statusbar texture
    local statusbar = NRSKNUI:GetStatusbarPath(self.db.StatusBarTexture or "NorskenUI")
    self.bar:SetStatusBarTexture(statusbar)
    self.bar.rested:SetStatusBarTexture(statusbar)

    -- Set statusbar coloring
    self.bar:SetStatusBarColor(r, g, b, a)

    -- Set rested coloring
    self.bar.rested:SetStatusBarColor(unpack(self.db.RestedColor))

    -- Set bar size and position
    self.bar:SetSize(self.db.width, self.db.height)
    NRSKNUI:ApplyFramePosition(self.bar, self.db.Position, self.db)

    -- Set backdrop coloring
    self.bar.bg:SetColorTexture(unpack(self.db.BackdropColor))

    -- Set backdrop border coloring
    if self.bar.SetBorderColor then
        self.bar:SetBorderColor(unpack(self.db.BackdropBorderColor))
    end

    -- Set font stuff
    NRSKNUI:ApplyFontToText(self.bar.text, self.db.FontFace, self.db.FontSize, self.db.FontOutline)
    self.bar.text:SetTextColor(unpack(self.db.TextColor))
    NRSKNUI:ApplyFontToText(self.bar.level, self.db.FontFace, self.db.FontSize, self.db.FontOutline)
    self.bar.level:SetTextColor(unpack(self.db.TextColor))

    -- Send a update to the data func, got check for max level hide there
    self:Update()
end

-- Show preview for edit mode/GUI
function XPBar:ShowPreview()
    if not self.bar then
        self:CreateBar()
    end
    self.isPreview = true
    self.bar:Show()
    self:Update()
end

-- Hide preview
function XPBar:HidePreview()
    self.isPreview = false
    if not self.db.Enabled then
        if self.bar then
            self.bar:Hide()
        end
    end
end
