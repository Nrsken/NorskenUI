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
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
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
    if self.frame then
        self.frame:Hide()
    end
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
    self.text = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.text:SetPoint("CENTER")
    self.text:SetText("+")
    self.text:SetFont(NRSKNUI.FONT or STANDARD_TEXT_FONT, 24, "OUTLINE")
    self.text:SetShadowOffset(0, 0)
    self.text:SetShadowColor(0, 0, 0, 0)

    self.text:ClearAllPoints()
    self.text:SetPoint("CENTER", self.frame, "CENTER", 0, 0)

    NRSKNUI:UpdateStackedShadowText(self.frame, "+")
end

-- Apply settings from profile
function CC:ApplySettings()
    if not self.frame or not self.text then return end

    -- Get position settings
    local pos = self.db.Position or {}
    local anchorFrom = pos.AnchorFrom or "CENTER"
    local anchorTo = pos.AnchorTo or "CENTER"
    local xOffset = pos.XOffset or 0
    local yOffset = pos.YOffset or -10

    -- Apply position
    self.frame:ClearAllPoints()
    self.frame:SetPoint(anchorFrom, UIParent, anchorTo, xOffset, yOffset)

    -- Apply frame strata
    self.frame:SetFrameStrata(self.db.Strata or "HIGH")

    -- Apply font
    local fontSize = (self.db.Thickness or 22) * FONT_SIZE_MULTIPLIER
    local fontPath = NRSKNUI.FONT or STANDARD_TEXT_FONT

    if not self.text:SetFont(fontPath, fontSize, "OUTLINE") then
        self.text:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
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
