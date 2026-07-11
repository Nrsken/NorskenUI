---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class CombatRes : NRSKNUI.Module
local CR = NRSKNUI:NewModule("CombatRes", "AceEvent-3.0")

local CreateFrame = CreateFrame
local UIParent = UIParent
local C_Spell = C_Spell
local GetTime = GetTime
local floor = math.floor
local format = string.format
local tostring = tostring

local SPELL_ID = 20484
local UPDATE_INTERVAL = 0.1

function CR:UpdateDB()
    self.db = NRSKNUI.db.profile.BattleRes
end

function CR:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function CR:UpdateAnchors()
    if not self.frame or not self.frame.content then return end

    local db = self.db
    local textSpacing = db.TextSpacing
    local growthDirection = db.GrowthDirection
    local padding = 4

    self.frame.content:ClearAllPoints()
    self.frame.separator:ClearAllPoints()
    self.frame.charge:ClearAllPoints()
    self.frame.timerText:ClearAllPoints()
    if self.frame.CRText then self.frame.CRText:ClearAllPoints() end

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

function CR:CreateFrame()
    if self.frame then return end

    local db = self.db

    local frame = CreateFrame("Frame", "NRSKNUI_BattleResFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(100, 26)
    frame:SetFrameStrata(db.Strata)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    frame:Hide()

    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetSize(1, 24)

    frame.timerText = NRSKNUI:CreateText(frame.content, "OVERLAY")
    frame.timerText:SetTextColor(1, 1, 1, 1)

    frame.separator = NRSKNUI:CreateText(frame.content, "OVERLAY")
    frame.separator:SetText(db.Separator)
    frame.separator:SetTextColor(1, 1, 1, 1)

    frame.charge = NRSKNUI:CreateText(frame.content, "OVERLAY")
    frame.charge:SetTextColor(1, 1, 1, 1)

    frame.CRText = NRSKNUI:CreateText(frame.content, "OVERLAY")
    frame.CRText:SetText("CR:")
    frame.CRText:SetTextColor(1, 1, 1, 1)

    self.frame = frame
end

function CR:ApplyTextSettings()
    if not self.frame then return end

    local db = self.db
    local sc = db.SeparatorColor
    local tc = db.TimerColor

    self.frame.separator:SetText(db.Separator)
    self.frame.separator:SetTextColor(sc[1], sc[2], sc[3], sc[4])
    NRSKNUI:SetTextFont(self.frame.separator, NRSKNUI:GetEffectiveFont(self.db), db.FontSize, db.FontOutline, db.FontShadow)

    NRSKNUI:SetTextFont(self.frame.charge, NRSKNUI:GetEffectiveFont(self.db), db.FontSize, db.FontOutline, db.FontShadow)

    self.frame.CRText:SetText(db.SeparatorCharges)
    self.frame.CRText:SetTextColor(sc[1], sc[2], sc[3], sc[4])
    NRSKNUI:SetTextFont(self.frame.CRText, NRSKNUI:GetEffectiveFont(self.db), db.FontSize, db.FontOutline, db.FontShadow)

    self.frame.timerText:SetTextColor(tc[1], tc[2], tc[3], tc[4])
    NRSKNUI:SetTextFont(self.frame.timerText, NRSKNUI:GetEffectiveFont(self.db), db.FontSize, db.FontOutline, db.FontShadow)

    self:UpdateAnchors()
    self:ApplyBackdropSettings()
end

function CR:ApplyBackdropSettings()
    if not self.frame then return end

    local backdrop = self.db.Backdrop
    self.frame:SetSize(backdrop.FrameWidth, backdrop.FrameHeight)

    if backdrop.Enabled then
        local bgColor = backdrop.Color
        local borderColor = backdrop.BorderColor
        self.frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        self.frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    else
        self.frame:SetBackdropColor(0, 0, 0, 0)
        self.frame:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

function CR:UpdateCharges()
    local frame = self.frame
    if not frame then return end

    local chargeTable = C_Spell.GetSpellCharges(SPELL_ID)

    if not chargeTable or not chargeTable.currentCharges then
        if self.isPreview then
            frame:Show()
            frame.timerText:SetText("02:00")
            frame.charge:SetText("2")
            local ac = self.db.ChargeAvailableColor
            frame.charge:SetTextColor(ac[1], ac[2], ac[3], ac[4])
        else
            frame:Hide()
        end
        self.chargeTable = nil
        return
    end

    self.chargeTable = chargeTable
    frame:Show()

    local curCharges = chargeTable.currentCharges
    local hasCharges = curCharges > 0

    frame.charge:SetText(tostring(curCharges))

    local color = hasCharges and self.db.ChargeAvailableColor or self.db.ChargeUnavailableColor
    frame.charge:SetTextColor(color[1], color[2], color[3], color[4])
end

function CR:UpdateTimer()
    local frame = self.frame
    if not frame or not frame:IsShown() then return end

    local chargeTable = self.chargeTable
    if not chargeTable then return end

    local currentCd = chargeTable.cooldownStartTime + chargeTable.cooldownDuration - GetTime()

    local timerText
    if currentCd > 0 then
        if currentCd >= 3600 then
            timerText = format("%d:%02d", floor(currentCd / 3600), floor((currentCd % 3600) / 60))
        else
            timerText = format("%02d:%02d", floor(currentCd / 60), floor(currentCd % 60))
        end
    else
        timerText = "00:00"
    end

    if timerText ~= self.lastTimerText then
        self.lastTimerText = timerText
        frame.timerText:SetText(timerText)
    end
end

function CR:OnUpdate(elapsed)
    self.lastUpdate = self.lastUpdate + elapsed
    if self.lastUpdate < UPDATE_INTERVAL then return end
    self.lastUpdate = 0
    self:UpdateTimer()
end

function CR:ApplySettings()
    if not self.frame then self:CreateFrame() end

    NRSKNUI:ApplyFramePosition(self.frame, self.db.Position, self.db)
    self:ApplyTextSettings()

    if not self.db.Enabled and not self.isPreview then
        self.frame:Hide()
        return
    end
    self:UpdateCharges()
end

function CR:ShowPreview()
    if not self.frame then self:CreateFrame() end
    self.isPreview = true
    self:ApplySettings()
end

function CR:HidePreview()
    self.isPreview = false
    if not self.db.Enabled and self.frame then self.frame:Hide() end
    self:UpdateCharges()
end

function CR:OnEnable()
    self.lastUpdate = 0
    self.lastTimerText = ""
    self.lastChargeText = ""
    self.lastChargeColor = nil
    self.isPreview = false

    self:CreateFrame()
    self.db.PreviewMode = false

    C_Timer.After(0.5, function() self:ApplySettings() end)

    self.frame:SetScript("OnUpdate", function(_, elapsed) self:OnUpdate(elapsed) end)

    local function DelayedUpdate() C_Timer.After(0.2, function() self:UpdateCharges() end) end
    self:RegisterEvent("SPELL_UPDATE_CHARGES", DelayedUpdate)
    self:RegisterEvent("CHALLENGE_MODE_START", DelayedUpdate)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", DelayedUpdate)

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

function CR:OnDisable()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    self.isPreview = false
    self:UnregisterAllEvents()
end
