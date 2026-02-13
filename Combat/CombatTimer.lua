-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("CombatTimer: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local CT = NRSKNUI.Addon:NewModule("CombatTimer", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local GetTime = GetTime
local math_floor, math_max, math_min = math.floor, math.max, math.min
local string_format = string.format

-- Module state
CT.frame = nil
CT.text = nil
CT.startTime = 0
CT.running = false
CT.lastDisplayedText = ""
CT.isPreview = false

-- Store last combat duration
NRSKNUI.lastCombatDuration = 0

-- Module init
function CT:OnInitialize()
    self.db = NRSKNUI.db.profile.CombatTimer
    self:SetEnabledState(false)
end

-- Format time based on settings
local function FormatTime(total_seconds, format)
    local mins = math_floor(total_seconds / 60)
    local secs = math_floor(total_seconds % 60)

    if format == "MM:SS:MS" then
        local frac = total_seconds - math_floor(total_seconds)
        local ms = math_floor(frac * 10)
        return string_format("%02d:%02d:%d", mins, secs, ms)
    end

    return string_format("%02d:%02d", mins, secs)
end

-- Get refresh rate based on format
local function GetRefreshRate(format)
    return (format == "MM:SS:MS") and 0.1 or 0.25
end

-- Create timer frame
function CT:CreateFrame()
    if self.frame then return end

    local frame = CreateFrame("Frame", "NRSKNUI_CombatTimerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    frame:SetSize(100, 25)
    NRSKNUI:ApplyFramePosition(frame, self.db.Position, self.db)
    frame:SetFrameLevel(100)
    frame:EnableMouse(false)
    frame:SetMouseClickEnabled(false)
    frame:Hide()

    -- Create font string
    local text = frame:CreateFontString("NRSKNUI_CombatTimerText", "OVERLAY")
    local fontPath = NRSKNUI:GetFontPath(self.db.FontFace)
    local fontSize = self.db.FontSize
    text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    text:SetFont(fontPath, fontSize, "")
    text:SetText("00:00")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")

    self.frame = frame
    frame.text = text
    self.text = text
end

-- Update frame size based on text
function CT:UpdateFrameSize()
    if not self.frame or not self.text then return end

    local backdrop = self.db.Backdrop or {}
    local bgWidth = backdrop.bgWidth or 100
    local bgHeight = backdrop.bgHeight or 10

    local w = math_floor((self.text:GetStringWidth() or 0) + bgWidth)
    local h = math_floor((self.text:GetStringHeight() or 0) + bgHeight)

    w = math_max(w, 40)
    h = math_max(h, 20)

    self.frame:SetSize(w, h)
end

-- Update timer text display
function CT:UpdateText()
    if not self.text then return end

    local total_time
    if self.running then
        total_time = self.startTime > 0 and (GetTime() - self.startTime) or 0
    else
        total_time = NRSKNUI.lastCombatDuration or 0
    end

    local status = FormatTime(total_time, self.db.Format)
    if status ~= self.lastDisplayedText then
        self.text:SetText(status)
        self.lastDisplayedText = status
        self:UpdateFrameSize()
    end
end

-- Apply all settings from DB
function CT:ApplySettings()
    if not self.text then return end
    local db = self.db

    -- Apply font settings
    NRSKNUI:ApplyFontSettings(self.frame, db, nil)

    -- Apply text alignment based on anchor
    local justify = NRSKNUI:GetTextJustifyFromAnchor(db.Position.AnchorFrom)
    local point = NRSKNUI:GetTextPointFromAnchor(db.Position.AnchorFrom)
    self.text:ClearAllPoints()
    self.text:SetJustifyH(justify)

    if point == "LEFT" then
        self.text:SetPoint("LEFT", self.frame, "LEFT", 4, 0)
    elseif point == "RIGHT" then
        self.text:SetPoint("RIGHT", self.frame, "RIGHT", -4, 0)
    else
        self.text:SetPoint("CENTER", self.frame, "CENTER", 0, 0)
    end

    -- Apply text color based on combat state
    local textColor = self.running and db.ColorInCombat or db.ColorOutOfCombat
    if textColor then
        self.text:SetTextColor(textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1)
    else
        self.text:SetTextColor(1, 1, 1, 1)
    end

    -- Apply frame strata
    if self.frame then
        -- Apply backdrop
        local backdrop = db.Backdrop
        if backdrop and backdrop.Enabled then
            local borderSize = backdrop.BorderSize or 1
            self.frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                tile = false,
                tileSize = 0,
                edgeSize = borderSize,
                insets = { left = 0, right = 0, top = 0, bottom = 0 }
            })

            local bgColor = backdrop.Color or { 0, 0, 0, 0.6 }
            local borderColor = backdrop.BorderColor or { 1, 1, 1, 0.8 }
            self.frame:SetBackdropColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4] or 0.6)
            self.frame:SetBackdropBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.8)
        else
            self.frame:SetBackdrop(nil)
        end
    end

    self:UpdateFrameSize()
    self:UpdateText()
end

-- OnUpdate handler for timer updates
function CT:OnUpdate(elapsed)
    if not self.running and not self.isPreview then return end

    -- Throttle updates
    self.elapsed = (self.elapsed or 0) + elapsed
    local refresh = GetRefreshRate(self.db.Format)
    if self.elapsed < refresh then return end
    self.elapsed = self.elapsed - refresh

    self:UpdateText()
end

-- Combat event handlers
function CT:OnEnterCombat()
    if self.running or not self.db.Enabled then return end

    self.startTime = GetTime()
    self.running = true
    NRSKNUI.lastCombatDuration = 0
    self.lastDisplayedText = ""

    if self.frame then
        self.frame:Show()
    end

    self:ApplySettings()
    self:UpdateText()
end

function CT:OnExitCombat()
    if not self.running then return end

    NRSKNUI.lastCombatDuration = GetTime() - self.startTime
    self.running = false
    self.startTime = 0

    -- Print duration to chat
    local duration = FormatTime(NRSKNUI.lastCombatDuration, self.db.Format)
    NRSKNUI:Print("Combat lasted " .. duration)

    self:ApplySettings()
    self:UpdateText()
end

-- Preview mode
function CT:ShowPreview()
    if not self.frame then
        self:CreateFrame()
    end
    self.isPreview = true
    self.frame:Show()
    self:ApplySettings()
end

function CT:HidePreview()
    self.isPreview = false
    if not self.running and not self.db.Enabled then
        self.frame:Hide()
    end
end

-- Expose position update for GUI changes
function CT:ApplyPosition()
    if not self.db.Enabled then return end
    if not self.frame then return end
    NRSKNUI:ApplyFramePosition(self.frame, self.db.Position, self.db)
end

-- Module OnEnable
function CT:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()
    self:ApplySettings()
    C_Timer.After(0.5, function() -- Delayed positioning to make sure frames exist
        self:ApplyPosition()
    end)
    -- Register events
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnExitCombat")

    -- Set up OnUpdate
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    if self.db.Enabled then
        self.frame:Show()
    end

    -- Register with EditMode
    local config = {
        key = "CombatTimer",
        displayName = "Combat Timer",
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
        guiPath = "combatTimer",
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

-- Module OnDisable
function CT:OnDisable()
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:Hide()
    end
    self.running = false
    self.isPreview = false
    self:UnregisterAllEvents()
end
