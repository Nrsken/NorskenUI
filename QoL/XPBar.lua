-- NorskenUI namespace
local _, NRSKNUI = ...
local Theme = NRSKNUI.Theme

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
local ipairs = ipairs
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

                self.frame:ClearAllPoints()
                self.frame:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset, pos.YOffset)
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
    local posDB = self.db.Position
    local r, g, b, a = self:GetColor()
    local statusbar = NRSKNUI:GetStatusbarPath(self.db.StatusBarTexture or "Blizzard")

    local bar = CreateFrame("StatusBar", "NorskenUI_XPBar", UIParent)
    bar:SetSize(self.db.width, self.db.height)
    bar:SetPoint(posDB.AnchorFrom, UIParent, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)
    bar:SetFrameStrata(self.db.Strata)
    bar:SetStatusBarTexture(statusbar)
    bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    bar:SetStatusBarColor(r, g, b, a)

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

    -- Create border container
    local borderFrame = CreateFrame("Frame", nil, bar)
    borderFrame:SetAllPoints(bar)
    borderFrame:SetFrameLevel(bar:GetFrameLevel() + 2)

    -- Create top border
    local borderTop = borderFrame:CreateTexture(nil, "BORDER", nil, 7)
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(unpack(self.db.BackdropBorderColor))
    borderTop:SetTexelSnappingBias(0)
    borderTop:SetSnapToPixelGrid(false)

    -- Create bottom border
    local borderBottom = borderFrame:CreateTexture(nil, "BORDER", nil, 7)
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(unpack(self.db.BackdropBorderColor))
    borderBottom:SetTexelSnappingBias(0)
    borderBottom:SetSnapToPixelGrid(false)

    -- Create left border
    local borderLeft = borderFrame:CreateTexture(nil, "BORDER", nil, 7)
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(unpack(self.db.BackdropBorderColor))
    borderLeft:SetTexelSnappingBias(0)
    borderLeft:SetSnapToPixelGrid(false)

    -- Create right border
    local borderRight = borderFrame:CreateTexture(nil, "BORDER", nil, 7)
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(unpack(self.db.BackdropBorderColor))
    borderRight:SetTexelSnappingBias(0)
    borderRight:SetSnapToPixelGrid(false)

    -- Text stuff
    local fontPath = NRSKNUI:GetFontPath(self.db.FontFace)
    local fontSize = self.db.FontSize
    local fontOutline = self.db.FontOutline
    if fontOutline == "NONE" then fontOutline = "" end

    -- Progress text
    bar.text = borderFrame:CreateFontString(nil, "OVERLAY")
    bar.text:SetPoint("CENTER")
    bar.text:SetFont(fontPath, fontSize, fontOutline)
    bar.text:SetTextColor(unpack(self.db.TextColor))
    bar.text:SetShadowOffset(0, 0)
    bar.text:SetShadowColor(0, 0, 0, 0)

    -- Level text (right side)
    bar.level = borderFrame:CreateFontString(nil, "OVERLAY")
    bar.level:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    bar.level:SetFont(fontPath, fontSize, fontOutline)
    bar.level:SetTextColor(unpack(self.db.TextColor))
    bar.level:SetShadowOffset(0, 0)
    bar.level:SetShadowColor(0, 0, 0, 0)

    NRSKNUI:SnapFrameToPixels(bar)

    self.bg = bar.bg
    self.borders = { borderTop, borderBottom, borderLeft, borderRight }

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
    local posDB = self.db.Position
    local r, g, b, a = self:GetColor()

    if not HideBlizzardBarInit and self.db.HideBlizzardBar then
        C_Timer.After(1, function()
            self:HideBlizzardXPBar()
            HideBlizzardBarInit = true
        end)
    end

    -- Update statusbar texture
    local statusbar = NRSKNUI:GetStatusbarPath(self.db.StatusBarTexture or "Blizzard")
    self.bar:SetStatusBarTexture(statusbar)
    self.bar.rested:SetStatusBarTexture(statusbar)

    -- Set statusbar coloring
    self.bar:SetStatusBarColor(r, g, b, a)

    -- Set rested coloring
    self.bar.rested:SetStatusBarColor(unpack(self.db.RestedColor))

    -- Set bar size and position
    self.bar:SetSize(self.db.width, self.db.height)
    self.bar:SetPoint(posDB.AnchorFrom, UIParent, posDB.AnchorTo, posDB.XOffset, posDB.YOffset)

    -- Set backdrop coloring
    self.bar.bg:SetColorTexture(unpack(self.db.BackdropColor))

    -- Set backdrop border coloring
    if self.borders then
        for _, border in ipairs(self.borders) do
            border:SetColorTexture(unpack(self.db.BackdropBorderColor))
        end
    end

    -- Set font stuff
    local fontPath = NRSKNUI:GetFontPath(self.db.FontFace)
    local fontSize = self.db.FontSize
    local fontOutline = self.db.FontOutline
    if fontOutline == "NONE" then fontOutline = "" end
    self.bar.text:SetFont(fontPath, fontSize, fontOutline)
    self.bar.text:SetTextColor(unpack(self.db.TextColor))
    self.bar.level:SetFont(fontPath, fontSize, fontOutline)
    self.bar.level:SetTextColor(unpack(self.db.TextColor))

    -- Set new strata
    self.bar:SetFrameStrata(self.db.Strata)

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
    -- Check if we should actually hide (respect db settings)
    if not self.db.Enabled then
        if self.bar then
            self.bar:Hide()
        end
    end
end
