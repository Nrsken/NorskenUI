-- NRSKNUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

-- Check for addon object
-- Create module
---@class UIWidgets: AceModule, AceEvent-3.0
local UIW = NRSKNUI:NewModule("UIWidgets", "AceEvent-3.0")

-- Localization
local hooksecurefunc = hooksecurefunc
local pairs = pairs
local _G = _G
local C_Timer = C_Timer

-- Track if hooks are installed
local hooked = {
    statusBar = false,
    textWithState = false,
    captureBar = false,
}

-- Update db, used for profile changes
function UIW:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.UIWidgets
end

-- Module init
function UIW:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

-- Module OnEnable
function UIW:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end

    C_Timer.After(0.5, function()
        if self:IsEnabled() then
            self:SetupHooks()
            self:StyleExistingWidgets()
        end
    end)

    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0.5, function()
            self:StyleExistingWidgets()
        end)
    end)
end

-- Get font settings
function UIW:GetFontSettings()
    local fontPath = NRSKNUI:GetFontPath(NRSKNUI:GetEffectiveFont(self.db))
    local outline = NRSKNUI:GetFontOutline(self.db.FontOutline)
    return fontPath, outline
end

-- Style a status bar widget
function UIW:StyleStatusBarWidget(widget)
    if not widget or widget:IsForbidden() then return end

    local fontPath, outline = self:GetFontSettings()
    local barDB = self.db.StatusBar

    -- Apply custom width if set
    local width = barDB.Width or 0
    if width > 0 then
        widget:SetWidth(width)
        if widget.Bar then
            widget.Bar:SetWidth(width)
        end
    end

    -- Title label above the bar
    if widget.Label and barDB.StyleLabel then
        widget.Label:SetFont(fontPath, barDB.LabelSize, outline)
        widget.Label:SetShadowColor(0, 0, 0, 0)

        -- Re-anchor to span full width and center
        widget.Label:ClearAllPoints()
        widget.Label:SetPoint("LEFT", widget, "LEFT", 0, 0)
        widget.Label:SetPoint("RIGHT", widget, "RIGHT", 0, 0)
        widget.Label:SetJustifyH("CENTER")
    end

    -- Bar itself
    local bar = widget.Bar
    if bar then
        -- Text on the bar (centered)
        if bar.Label and barDB.StyleBarText then
            bar.Label:SetFont(fontPath, barDB.BarTextSize, outline)
            bar.Label:SetShadowColor(0, 0, 0, 0)

            -- Re-anchor to span full width and center
            bar.Label:ClearAllPoints()
            bar.Label:SetPoint("LEFT", bar, "LEFT", 0, 0)
            bar.Label:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
            bar.Label:SetJustifyH("CENTER")
            bar.Label:SetJustifyV("MIDDLE")
        end

        -- Left/Right text on bar, some widgets have these
        if bar.LeftText and barDB.StyleBarText then
            bar.LeftText:SetFont(fontPath, barDB.BarTextSize, outline)
            bar.LeftText:SetShadowColor(0, 0, 0, 0)
            bar.LeftText:SetJustifyH("LEFT")
            bar.LeftText:SetJustifyV("MIDDLE")
        end

        if bar.RightText and barDB.StyleBarText then
            bar.RightText:SetFont(fontPath, barDB.BarTextSize, outline)
            bar.RightText:SetShadowColor(0, 0, 0, 0)
            bar.RightText:SetJustifyH("RIGHT")
            bar.RightText:SetJustifyV("MIDDLE")
        end

        -- Strip Blizzard textures if enabled
        if barDB.StripTextures then
            if bar.BGLeft then bar.BGLeft:SetAlpha(0) end
            if bar.BGRight then bar.BGRight:SetAlpha(0) end
            if bar.BGCenter then bar.BGCenter:SetAlpha(0) end
            if bar.BorderLeft then bar.BorderLeft:SetAlpha(0) end
            if bar.BorderRight then bar.BorderRight:SetAlpha(0) end
            if bar.BorderCenter then bar.BorderCenter:SetAlpha(0) end
            if bar.Spark then bar.Spark:SetAlpha(0) end

            if not bar.nrsknBackdrop then
                local backdrop = CreateFrame("Frame", nil, bar)
                backdrop:SetFrameLevel(bar:GetFrameLevel() - 1)
                backdrop:SetAllPoints(bar)

                backdrop.bg = backdrop:CreateTexture(nil, "BACKGROUND")
                backdrop.bg:SetAllPoints()
                backdrop.bg:SetColorTexture(unpack(barDB.BackdropColor))

                backdrop:AddBorders()
                backdrop:SetBorderColor(unpack(barDB.BorderColor))
                bar.nrsknBackdrop = backdrop
            end
        end
    end
end

-- Style a text widget
function UIW:StyleTextWidget(widget)
    if not widget or widget:IsForbidden() then return end

    local fontPath, outline = self:GetFontSettings()
    local textDB = self.db.TextWidget

    -- Apply custom width if set
    local width = textDB.Width or 0
    if width > 0 then
        widget:SetWidth(width)
    end

    if widget.Text and textDB.StyleText then
        widget.Text:SetFont(fontPath, textDB.Size, outline)
        widget.Text:SetShadowColor(0, 0, 0, 0)

        -- Re-anchor text to span full width and center it
        widget.Text:ClearAllPoints()
        widget.Text:SetPoint("LEFT", widget, "LEFT", 0, 0)
        widget.Text:SetPoint("RIGHT", widget, "RIGHT", 0, 0)
        widget.Text:SetJustifyH("CENTER")
        widget.Text:SetJustifyV("MIDDLE")
    end
end

-- Setup hooks for widget templates
function UIW:SetupHooks()
    -- Hook status bar widgets
    if not hooked.statusBar and _G.UIWidgetTemplateStatusBarMixin then
        hooksecurefunc(_G.UIWidgetTemplateStatusBarMixin, "Setup", function(widget)
            if self.db.Enabled and self.db.StatusBar.Enabled then
                self:StyleStatusBarWidget(widget)
            end
        end)
        hooked.statusBar = true
    end

    -- Hook text with state widgets
    if not hooked.textWithState and _G.UIWidgetTemplateTextWithStateMixin then
        hooksecurefunc(_G.UIWidgetTemplateTextWithStateMixin, "Setup", function(widget)
            if self.db.Enabled and self.db.TextWidget.Enabled then
                self:StyleTextWidget(widget)
            end
        end)
        hooked.textWithState = true
    end
end

-- Style widgets that already exist
function UIW:StyleExistingWidgets()
    if not self.db.Enabled then return end

    -- Top center container
    if _G.UIWidgetTopCenterContainerFrame and _G.UIWidgetTopCenterContainerFrame.widgetFrames then
        for _, widget in pairs(_G.UIWidgetTopCenterContainerFrame.widgetFrames) do
            self:StyleWidgetByType(widget)
        end
    end

    -- Power bar container
    if _G.UIWidgetPowerBarContainerFrame and _G.UIWidgetPowerBarContainerFrame.widgetFrames then
        for _, widget in pairs(_G.UIWidgetPowerBarContainerFrame.widgetFrames) do
            self:StyleWidgetByType(widget)
        end
    end

    -- Below minimap container
    if _G.UIWidgetBelowMinimapContainerFrame and _G.UIWidgetBelowMinimapContainerFrame.widgetFrames then
        for _, widget in pairs(_G.UIWidgetBelowMinimapContainerFrame.widgetFrames) do
            self:StyleWidgetByType(widget)
        end
    end
end

-- Determine widget type and style accordingly
function UIW:StyleWidgetByType(widget)
    if not widget or widget:IsForbidden() then return end
    if widget.Bar and self.db.StatusBar.Enabled then
        self:StyleStatusBarWidget(widget)
    elseif widget.Text and not widget.Bar and self.db.TextWidget.Enabled then
        self:StyleTextWidget(widget)
    end
end

-- Apply settings
function UIW:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end
    self:StyleExistingWidgets()
end

-- Module OnDisable
function UIW:OnDisable()
end
