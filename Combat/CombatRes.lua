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
local ipairs = ipairs

-- Module constants
local SPELL_ID = 20484 -- Rebirth
local UPDATE_INTERVAL = 0.1

-- Shadow offsets for soft outline
local SHADOW_OFFSETS = {
    { 0,  1 },  -- N
    { 1,  1 },  -- NE
    { 1,  0 },  -- E
    { 1,  -1 }, -- SE
    { 0,  -1 }, -- S
    { -1, -1 }, -- SW
    { -1, 0 },  -- W
    { -1, 1 },  -- NW
}

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

-- Update shadow text content
local function UpdateShadowTextContent(shadows, text)
    if not shadows then return end
    for _, shadow in ipairs(shadows) do
        shadow:SetText(text)
    end
end

-- Re-anchor shadow layers to their parent text
function CR:UpdateShadowAnchors()
    if not self.frame then return end

    local function reanchorShadows(shadows, parentText)
        if not shadows then return end
        for i, shadow in ipairs(shadows) do
            if shadow then
                shadow:ClearAllPoints()
                local offset = SHADOW_OFFSETS[i]
                shadow:SetPoint("CENTER", parentText, "CENTER", offset[1], offset[2])
                shadow:SetJustifyH(parentText:GetJustifyH())
            end
        end
    end

    local textMode = self.db.TextMode or {}
    local sepShadow = textMode.SeparatorShadow or {}
    local chargeShadow = textMode.ChargeShadow or {}
    local timerShadow = textMode.TimerShadow or {}

    if sepShadow.UseSoftOutline then
        reanchorShadows(self.frame.separatorShadows, self.frame.separator)
        reanchorShadows(self.frame.CRTextShadows, self.frame.CRText)
    end
    if chargeShadow.UseSoftOutline then
        reanchorShadows(self.frame.chargeShadows, self.frame.charge)
    end
    if timerShadow.UseSoftOutline then
        reanchorShadows(self.frame.timerShadows, self.frame.timerText)
    end
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

    self:UpdateShadowAnchors()
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
    frame.timerShadows = NRSKNUI:CreateStackedShadowText(frame.content, frame.timerText, fontPath, fontSize, { 0, 0, 0 },
        0.9)

    -- Separator text
    frame.separator = frame.content:CreateFontString(nil, "OVERLAY")
    frame.separator:SetFont(fontPath, fontSize, "")
    frame.separator:SetText(textMode.Separator or "|")
    frame.separator:SetTextColor(1, 1, 1, 1)
    frame.separatorShadows = NRSKNUI:CreateStackedShadowText(frame.content, frame.separator, fontPath, fontSize,
        { 0, 0, 0 }, 0.9)

    -- Charge text
    frame.charge = frame.content:CreateFontString(nil, "OVERLAY")
    frame.charge:SetFont(fontPath, fontSize, "")
    frame.charge:SetTextColor(1, 1, 1, 1)
    frame.chargeShadows = NRSKNUI:CreateStackedShadowText(frame.content, frame.charge, fontPath, fontSize, { 0, 0, 0 },
        0.9)

    -- CR label text
    frame.CRText = frame.content:CreateFontString(nil, "OVERLAY")
    frame.CRText:SetFont(fontPath, fontSize, "")
    frame.CRText:SetText("CR:")
    frame.CRText:SetTextColor(1, 1, 1, 1)
    frame.CRTextShadows = NRSKNUI:CreateStackedShadowText(frame.content, frame.CRText, fontPath, fontSize, { 0, 0, 0 },
        0.9)

    self.frame = frame
end

-- Apply text mode settings
function CR:ApplyTextModeSettings()
    if not self.frame then return end

    local db = self.db
    local textMode = db.TextMode or {}
    local fontPath = NRSKNUI:GetFontPath(textMode.FontFace or "Friz Quadrata TT")
    local fontSize = textMode.FontSize or 18
    local fontOutline = NRSKNUI:GetFontOutline(textMode.FontOutline)

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

    -- Cache shadow settings
    self.cachedSettings.timerUseSoftOutline = timerShadow.UseSoftOutline or false
    self.cachedSettings.chargeUseSoftOutline = chargeShadow.UseSoftOutline or false
    self.cachedSettings.separatorUseSoftOutline = sepShadow.UseSoftOutline or false

    -- Apply separator
    local sc = self.cachedSettings.separatorColor
    self.frame.separator:SetText(self.cachedSettings.separator)
    self.frame.separator:SetTextColor(sc[1], sc[2], sc[3], sc[4] or 1)
    self:ApplyShadowSettings(self.frame.separator, self.frame.separatorShadows, sepShadow, fontPath, fontSize,
        fontOutline, self.cachedSettings.separator)

    -- Apply charge
    self:ApplyShadowSettings(self.frame.charge, self.frame.chargeShadows, chargeShadow, fontPath, fontSize, fontOutline)

    -- Apply CR text
    self.frame.CRText:SetText(self.cachedSettings.separatorCharges)
    self.frame.CRText:SetTextColor(sc[1], sc[2], sc[3], sc[4] or 1)
    self:ApplyShadowSettings(self.frame.CRText, self.frame.CRTextShadows, sepShadow, fontPath, fontSize, fontOutline,
        self.cachedSettings.separatorCharges)

    -- Apply timer
    local tc = self.cachedSettings.timerColor
    self.frame.timerText:SetTextColor(tc[1], tc[2], tc[3], tc[4] or 1)
    self:ApplyShadowSettings(self.frame.timerText, self.frame.timerShadows, timerShadow, fontPath, fontSize, fontOutline)

    self:UpdateAnchors()
    self:ApplyBackdropSettings()
end

-- Apply shadow settings to a text element
function CR:ApplyShadowSettings(fontString, shadows, shadowSettings, fontPath, fontSize, fontOutline, text)
    local shadowColor = shadowSettings.Color or { 0, 0, 0, 1 }

    if shadowSettings.UseSoftOutline then
        fontString:SetFont(fontPath, fontSize, "")
        fontString:SetShadowOffset(0, 0)
        fontString:SetShadowColor(0, 0, 0, 0)
        if shadows then
            for _, shadow in ipairs(shadows) do
                shadow:SetFont(fontPath, fontSize, "")
                shadow:SetTextColor(0, 0, 0, 1)
                if text then shadow:SetText(text) end
                shadow:Show()
            end
        end
    elseif shadowSettings.Enabled then
        if shadows then
            for _, shadow in ipairs(shadows) do shadow:Hide() end
        end
        fontString:SetFont(fontPath, fontSize, fontOutline)
        fontString:SetShadowOffset(shadowSettings.OffsetX or 0, shadowSettings.OffsetY or 0)
        fontString:SetShadowColor(shadowColor[1], shadowColor[2], shadowColor[3], shadowColor[4] or 1)
    else
        fontString:SetFont(fontPath, fontSize, fontOutline)
        fontString:SetShadowOffset(0, 0)
        fontString:SetShadowColor(0, 0, 0, 0)
        if shadows then
            for _, shadow in ipairs(shadows) do shadow:Hide() end
        end
    end
end

-- Apply backdrop settings
function CR:ApplyBackdropSettings()
    if not self.frame then return end

    local textMode = self.db.TextMode or {}
    local backdrop = textMode.Backdrop or {}

    if backdrop.Enabled then
        local bgColor = backdrop.Color or { 0, 0, 0, 0.6 }
        local borderColor = backdrop.BorderColor or { 0, 0, 0, 1 }
        self.frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.6)
        self.frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 1)
        self.frame:SetSize(backdrop.FrameWidth or 100, backdrop.FrameHeight or 26)
    else
        self.frame:SetBackdropColor(0, 0, 0, 0)
        self.frame:SetBackdropBorderColor(0, 0, 0, 0)
        self.frame:SetSize(100, 26)
    end
end

-- Apply position
function CR:ApplyPosition()
    if not self.frame then return end

    local db = self.db
    local pos = db.Position or {}
    local parent = NRSKNUI:ResolveAnchorFrame(db.anchorFrameType, db.ParentFrame)

    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        pos.AnchorFrom or "CENTER",
        parent,
        pos.AnchorTo or "CENTER",
        pos.XOffset or 0,
        pos.YOffset or 0
    )
    self.frame:SetFrameStrata(db.Strata or "HIGH")

    NRSKNUI:SnapFrameToPixels(self.frame)
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
                if self.cachedSettings.timerUseSoftOutline then
                    UpdateShadowTextContent(self.frame.timerShadows, "02:00")
                end
            end
            if self.lastChargeText ~= "2" then
                self.lastChargeText = "2"
                self.frame.charge:SetText("2")
                if self.cachedSettings.chargeUseSoftOutline then
                    UpdateShadowTextContent(self.frame.chargeShadows, "2")
                end
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
            if self.cachedSettings.timerUseSoftOutline then
                UpdateShadowTextContent(self.frame.timerShadows, timerText)
            end
        end
    else
        if self.lastTimerText ~= "00:00" then
            self.lastTimerText = "00:00"
            self.frame.timerText:SetText("00:00")
            if self.cachedSettings.timerUseSoftOutline then
                UpdateShadowTextContent(self.frame.timerShadows, "00:00")
            end
        end
    end

    -- Update charge text
    local chargeText = tostring(curCharges)
    if chargeText ~= self.lastChargeText then
        self.lastChargeText = chargeText
        self.frame.charge:SetText(chargeText)
        if self.cachedSettings.chargeUseSoftOutline then
            UpdateShadowTextContent(self.frame.chargeShadows, chargeText)
        end
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
    self:UpdateShadowAnchors()
    self:Update()
end

-- Apply all settings
function CR:ApplySettings()
    if not self.db.Enabled and not self.isPreview then
        if self.frame then self.frame:Hide() end
        return
    end

    if not self.frame then
        self:CreateFrame()
    end

    self:ApplyPosition()
    self:ApplyTextModeSettings()
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

    if self.db.Enabled then
        self:ApplySettings()
    end

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
