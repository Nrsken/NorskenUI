-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("CombatRes: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local CR = NRSKNUI.Addon:NewModule("CombatRes", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local UIParent = UIParent
local pcall = pcall
local C_Spell = C_Spell
local tostring = tostring
local GetTime = GetTime

-- Module constants
local SPELL_ID = 20484 -- Rebirth
local UPDATE_INTERVAL = 0.1

-- Module state
CR.frame = nil
CR.lastUpdate = 0
CR.lastTimerText = ""
CR.lastChargeText = ""
CR.lastChargeColor = nil
CR.isPreview = false

-- Cached settings for performance
CR.cachedSettings = {}

-- Module init
function CR:OnInitialize()
    self.db = NRSKNUI.db.profile.BattleRes
    self:SetEnabledState(false)
end

-- Update anchors based on growth direction
function CR:UpdateAnchors()
    if not self.frame or not self.frame.content then return end

    local textMode = self.db.TextMode or {}
    local textSpacing = textMode.TextSpacing or 4
    local growthDirection = textMode.GrowthDirection or "RIGHT"
    local padding = 4

    self.frame.content:ClearAllPoints()
    self.frame.separator:ClearAllPoints()
    self.frame.charge:ClearAllPoints()
    self.frame.timerText:ClearAllPoints()
    if self.frame.CRText then
        self.frame.CRText:ClearAllPoints()
    end

    if growthDirection == "RIGHT" then
        self.frame.content:SetPoint("LEFT", self.frame, "LEFT", padding, 0)

        if self.frame.CRText then
            self.frame.CRText:SetPoint("LEFT", self.frame.content, "LEFT", 0, 0)
            self.frame.charge:SetPoint("LEFT", self.frame.CRText, "RIGHT", textSpacing, 0)
        else
            self.frame.charge:SetPoint("LEFT", self.frame.content, "LEFT", 0, 0)
        end

        self.frame.separator:SetPoint("LEFT", self.frame.charge, "RIGHT", textSpacing, 0)
        self.frame.timerText:SetPoint("LEFT", self.frame.separator, "RIGHT", textSpacing, 0)
        self.frame.timerText:SetJustifyH("LEFT")
    elseif growthDirection == "LEFT" then
        self.frame.content:SetPoint("RIGHT", self.frame, "RIGHT", -padding, 0)
        self.frame.timerText:SetPoint("RIGHT", self.frame.content, "RIGHT", -textSpacing, 0)
        self.frame.separator:SetPoint("RIGHT", self.frame.timerText, "LEFT", -textSpacing, 0)

        if self.frame.CRText then
            self.frame.charge:SetPoint("RIGHT", self.frame.separator, "LEFT", -textSpacing, 0)
            self.frame.CRText:SetPoint("RIGHT", self.frame.charge, "LEFT", -textSpacing, 0)
        else
            self.frame.charge:SetPoint("RIGHT", self.frame.separator, "LEFT", 0, 0)
        end

        self.frame.timerText:SetJustifyH("RIGHT")
    end
end

-- Create the main frame
function CR:CreateFrame()
    if self.frame then return end

    local db = self.db
    local textMode = db.TextMode or {}
    local fontPath = NRSKNUI:GetFontPath(textMode.FontFace or "Friz Quadrata TT")
    local fontSize = textMode.FontSize or 18

    local frame = CreateFrame("Frame", "NRSKNUI_BattleResFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(100, 26)
    frame:SetFrameStrata(db.Strata or "HIGH")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:Hide()

    -- Content container
    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetSize(1, 24)

    -- Timer text
    frame.timerText = frame.content:CreateFontString(nil, "OVERLAY")
    frame.timerText:SetFont(fontPath, fontSize, "")
    frame.timerText:SetTextColor(1, 1, 1, 1)

    -- Separator text
    frame.separator = frame.content:CreateFontString(nil, "OVERLAY")
    frame.separator:SetFont(fontPath, fontSize, "")
    frame.separator:SetText(textMode.Separator or "|")
    frame.separator:SetTextColor(1, 1, 1, 1)

    -- Charge text
    frame.charge = frame.content:CreateFontString(nil, "OVERLAY")
    frame.charge:SetFont(fontPath, fontSize, "")
    frame.charge:SetTextColor(1, 1, 1, 1)

    -- CR label text
    frame.CRText = frame.content:CreateFontString(nil, "OVERLAY")
    frame.CRText:SetFont(fontPath, fontSize, "")
    frame.CRText:SetText("CR:")
    frame.CRText:SetTextColor(1, 1, 1, 1)

    self.frame = frame
end

-- Apply text mode settings
function CR:ApplyTextModeSettings()
    if not self.frame then return end

    local db = self.db
    local textMode = db.TextMode or {}
    local fontName = textMode.FontFace or "Friz Quadrata TT"
    local fontSize = textMode.FontSize or 18
    local fontOutline = textMode.FontOutline or "OUTLINE"

    -- Cache settings
    self.cachedSettings.separator = textMode.Separator or "|"
    self.cachedSettings.separatorCharges = textMode.SeparatorCharges or "CR:"
    self.cachedSettings.availableColor = textMode.ChargeAvailableColor or { 0.3, 1, 0.3, 1 }
    self.cachedSettings.unavailableColor = textMode.ChargeUnavailableColor or { 1, 0.3, 0.3, 1 }
    self.cachedSettings.timerColor = textMode.TimerColor or { 1, 1, 1, 1 }
    self.cachedSettings.separatorColor = textMode.SeparatorColor or { 1, 1, 1, 1 }
    self.cachedSettings.growthDirection = textMode.GrowthDirection or "RIGHT"

    local sepShadow = textMode.SeparatorShadow or {}
    local chargeShadow = textMode.ChargeShadow or {}
    local timerShadow = textMode.TimerShadow or {}

    -- Apply separator
    local sc = self.cachedSettings.separatorColor
    self.frame.separator:SetText(self.cachedSettings.separator)
    self.frame.separator:SetTextColor(sc[1], sc[2], sc[3], sc[4] or 1)
    NRSKNUI:ApplyFontToText(self.frame.separator, fontName, fontSize, fontOutline, sepShadow)

    -- Apply charge
    NRSKNUI:ApplyFontToText(self.frame.charge, fontName, fontSize, fontOutline, chargeShadow)

    -- Apply CR text
    self.frame.CRText:SetText(self.cachedSettings.separatorCharges)
    self.frame.CRText:SetTextColor(sc[1], sc[2], sc[3], sc[4] or 1)
    NRSKNUI:ApplyFontToText(self.frame.CRText, fontName, fontSize, fontOutline, sepShadow)

    -- Apply timer
    local tc = self.cachedSettings.timerColor
    self.frame.timerText:SetTextColor(tc[1], tc[2], tc[3], tc[4] or 1)
    NRSKNUI:ApplyFontToText(self.frame.timerText, fontName, fontSize, fontOutline, timerShadow)

    self:UpdateAnchors()
    self:ApplyBackdropSettings()
end

-- Apply backdrop settings
function CR:ApplyBackdropSettings()
    if not self.frame then return end

    local textMode = self.db.TextMode or {}
    local backdrop = textMode.Backdrop or {}

    -- Always use the same frame size to prevent text shifting
    self.frame:SetSize(backdrop.FrameWidth or 100, backdrop.FrameHeight or 26)

    if backdrop.Enabled then
        local bgColor = backdrop.Color or { 0, 0, 0, 0.6 }
        local borderColor = backdrop.BorderColor or { 0, 0, 0, 1 }
        self.frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.6)
        self.frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
    else
        self.frame:SetBackdropColor(0, 0, 0, 0)
        self.frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

-- Update display
function CR:Update()
    if not self.frame then return end

    local chargeTable
    local ok = pcall(function()
        chargeTable = C_Spell.GetSpellCharges(SPELL_ID)
    end)

    if not ok or not chargeTable or not chargeTable.currentCharges then
        if self.isPreview then
            self.frame:Show()
            if self.lastTimerText ~= "02:00" then
                self.lastTimerText = "02:00"
                self.frame.timerText:SetText("02:00")
            end
            if self.lastChargeText ~= "2" then
                self.lastChargeText = "2"
                self.frame.charge:SetText("2")
            end
            local ac = self.cachedSettings.availableColor or { 0.3, 1, 0.3, 1 }
            if self.lastChargeColor ~= "available" then
                self.lastChargeColor = "available"
                self.frame.charge:SetTextColor(ac[1], ac[2], ac[3], ac[4] or 1)
            end
        else
            self.frame:Hide()
            self.lastTimerText = ""
            self.lastChargeText = ""
            self.lastChargeColor = nil
        end
        return
    end

    local cdStart = chargeTable.cooldownStartTime
    local curCharges = chargeTable.currentCharges
    local cdDur = chargeTable.cooldownDuration
    local hasCharges = curCharges > 0
    local expiTime = cdStart + cdDur
    local currentCd = expiTime - GetTime()

    self.frame:Show()

    -- Update timer text
    if currentCd > 0 then
        local timerText
        if currentCd >= 3600 then
            local hours = math.floor(currentCd / 3600)
            local minutes = math.floor((currentCd % 3600) / 60)
            timerText = string.format("%d:%02d", hours, minutes)
        else
            local minutes = math.floor(currentCd / 60)
            local seconds = math.floor(currentCd % 60)
            timerText = string.format("%02d:%02d", minutes, seconds)
        end

        if timerText ~= self.lastTimerText then
            self.lastTimerText = timerText
            self.frame.timerText:SetText(timerText)
        end
    else
        if self.lastTimerText ~= "00:00" then
            self.lastTimerText = "00:00"
            self.frame.timerText:SetText("00:00")
        end
    end

    -- Update charge text
    local chargeText = tostring(curCharges)
    if chargeText ~= self.lastChargeText then
        self.lastChargeText = chargeText
        self.frame.charge:SetText(chargeText)
    end

    -- Update charge color
    local colorKey = hasCharges and "available" or "unavailable"
    if colorKey ~= self.lastChargeColor then
        self.lastChargeColor = colorKey
        local color = hasCharges and self.cachedSettings.availableColor or self.cachedSettings.unavailableColor
        if color then
            self.frame.charge:SetTextColor(color[1], color[2], color[3], color[4] or 1)
        end
    end
end

-- OnUpdate handler
function CR:OnUpdate(elapsed)
    self.lastUpdate = self.lastUpdate + elapsed
    if self.lastUpdate < UPDATE_INTERVAL then return end
    self.lastUpdate = 0
    self:Update()
end

-- Apply all settings
function CR:ApplySettings()
    if not self.frame then
        self:CreateFrame()
    end

    NRSKNUI:ApplyFramePosition(self.frame, self.db.Position, self.db)
    self:ApplyTextModeSettings()

    if not self.db.Enabled and not self.isPreview then
        self.frame:Hide()
        return
    end
    self:Update()
end

-- Preview mode
function CR:ShowPreview()
    if not self.frame then
        self:CreateFrame()
    end
    self.isPreview = true
    self:ApplySettings()
end

function CR:HidePreview()
    self.isPreview = false
    if not self.db.Enabled then
        self.frame:Hide()
    end
    self:Update()
end

-- Module OnEnable
function CR:OnEnable()
    self:CreateFrame()

    -- Reset preview mode on init
    self.db.PreviewMode = false
    self.isPreview = false

    C_Timer.After(0.5, function()
        self:ApplySettings()
    end)

    -- Set up OnUpdate
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    -- Register with EditMode
    local config = {
        key = "CombatRes",
        displayName = "Combat Res",
        frame = self.frame,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            if self.frame then
                local parent = NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
                self.frame:ClearAllPoints()
                self.frame:SetPoint(pos.AnchorFrom, parent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        getParentFrame = function()
            return NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
        end,
        guiPath = "battleRes",
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

-- Module OnDisable
function CR:OnDisable()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    self.isPreview = false
end
