-- NorskenUI namespace
local _, NRSKNUI = ...

-- Safety check
if not NRSKNUI.Addon then
    error("CombatCross: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local CC = NRSKNUI.Addon:NewModule("CombatCross", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UIFrameFadeIn = UIFrameFadeIn
local UIParent = UIParent

-- Constants
local FONT_SIZE_MULTIPLIER = 2

-- Module state
CC.frame = nil
CC.text = nil
CC.previewActive = false
CC.combatActive = false

-- Module init
function CC:OnInitialize()
    self.db = NRSKNUI.db.profile.CombatCross
    self:SetEnabledState(false)
end

-- Module OnEnable
function CC:OnEnable()
    if not self.db.Enabled then return end
    self:CreateFrame()
    self:ApplySettings()

    -- Register combat events
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnExitCombat")
end

-- Module OnDisable
function CC:OnDisable()
    self:UnregisterAllEvents()
    if self.frame then self.frame:Hide() end
end

-- Get color based on color mode
function CC:GetColor()
    local colorMode = self.db.ColorMode or "custom"
    return NRSKNUI:GetAccentColor(colorMode, self.db.Color)
end

-- Create the combat cross frame
function CC:CreateFrame()
    if self.frame then return end

    -- Create frame
    self.frame = CreateFrame("Frame", "NRSKNUI_CombatCrossFrame", UIParent)
    self.frame:SetSize(30, 30)
    self.frame:SetPoint("CENTER")
    self.frame:SetFrameStrata("HIGH")
    self.frame:SetFrameLevel(100)
    self.frame:Hide()

    -- Create cross text
    local fontSize = self.db.Thickness * FONT_SIZE_MULTIPLIER
    self.text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.text:SetPoint("CENTER")
    self.text:SetFont(NRSKNUI.FONT, fontSize, "")
    self.text:SetText("+")

    if self.db.Outline then
        self.frame.softOutline = NRSKNUI:CreateSoftOutline(self.text, {
            thickness = 1,
            color = { 0, 0, 0 },
            alpha = 0.9,
        })
    end

    self.text:ClearAllPoints()
    self.text:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
end

-- Apply settings from profile
function CC:ApplySettings()
    if not self.frame or not self.text then return end

    -- Apply position & Strata
    NRSKNUI:ApplyFramePosition(self.frame, self.db.Position, self.db)

    -- Apply font
    local fontSize = self.db.Thickness * FONT_SIZE_MULTIPLIER
    self.text:SetFont(NRSKNUI.FONT, fontSize, "")

    if self.db.Outline then
        if not self.frame.softOutline then
            self.frame.softOutline = NRSKNUI:CreateSoftOutline(self.text, {
                thickness = 1,
                color = { 0, 0, 0 },
                alpha = 0.9,
            })
        else
            self.frame.softOutline:SetShown(true)
        end
    else
        if self.frame.softOutline then
            self.frame.softOutline:SetShown(false)
        end
    end

    -- Apply color
    local r, g, b, a = self:GetColor()
    self.text:SetTextColor(r, g, b, a)
end

-- Show combat cross
function CC:Show(isPreview)
    if not self.frame then
        self:CreateFrame()
        self:ApplySettings()
    end
    if not self.frame then return end

    -- Set active state
    if isPreview then
        self.previewActive = true
    else
        self.combatActive = true
    end

    -- Show frame if either state is active
    if self.previewActive or self.combatActive then
        if not self.frame:IsShown() then
            self.frame:Show()
            self.frame:SetAlpha(0)
            UIFrameFadeIn(self.frame, 0.3, 0, 1)
        end
    end
end

-- Hide combat cross
function CC:Hide(isPreview)
    if not self.frame then return end

    -- Clear active state
    if isPreview then
        self.previewActive = false
    else
        self.combatActive = false
    end

    -- Hide frame if neither state is active
    if not self.previewActive and not self.combatActive then
        self.frame:Hide()
    end
end

-- Show preview
function CC:ShowPreview()
    if InCombatLockdown() then return end
    self:Show(true)
end

-- Hide preview
function CC:HidePreview()
    if InCombatLockdown() then return end
    if not self.previewActive then return end
    self:Hide(true)
end

-- Combat enter event
function CC:OnEnterCombat()
    if not self.db.Enabled then return end
    self:Show(false)
end

-- Combat exit event
function CC:OnExitCombat()
    if not self.db.Enabled then return end
    self:Hide(false)
end

-- Refresh (called from GUI)
function CC:Refresh()
    self:ApplySettings()
end
