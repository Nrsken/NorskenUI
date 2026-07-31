---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field Elements UnitFramesElements
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local GetTime = GetTime
local select = select
local pairs = pairs
local next = next

local C_Timer = C_Timer

local EvaluateColorFromBoolean = C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean
local CreateDuration = C_DurationUtil and C_DurationUtil.CreateDuration
local ElapsedTime = Enum and Enum.StatusBarTimerDirection.ElapsedTime

local FALLBACK_ICON = 136243
local PREVIEW_DURATION = 10

---Empowered-cast stage separator.
---@param element table Castbar element
---@return Texture
local function CreatePip(element)
    local pip = element:CreateTexture(nil, 'OVERLAY')
    pip:SetColorTexture(0, 0, 0, 1)
    pip:SetWidth(2)
    return pip
end

---Evaluate the castbar color.
---@param element table Castbar element
---@param unit string
---@return ColorRGBAData | colorRGBA
local function CastNormalColor(element, unit)
    if element.nuiColorByClass and not NRSKNUI:IsSecretUnit(unit) then
        local class = select(2, UnitClass(unit))
        if class then
            return NRSKNUI:CreateColor(NRSKNUI:GetClassColorRaw(class)) --[[@as colorRGBA]]
        end
    end
    return element.nuiColor
end

---Post cast start handler, color the bar based on interruptibility.
---@param element table Castbar element
---@param unit string
local function PostCastStart(element, unit)
    element.nuiContainer:Show() -- Runs on every cast start, before oUF shows the bar
    element:SetStatusBarColor(EvaluateColorFromBoolean(element.notInterruptible, element.nuiShieldColor, CastNormalColor(element, unit)):GetRGB())
end

---Post cast fail handler, color the bars in fail color.
---@param element table Castbar element
local function PostCastFail(element)
    element:SetStatusBarColor(element.nuiFailColor:GetRGBA())
end

-- Preview --

-- Previewed frames borrow an idle unit, so their castbar has nothing to draw. These run a fake cast instead,
-- driven by the same duration object oUF feeds a real one, so oUF's own OnUpdate keeps
-- the time text and the bar fill honest and nothing here has to reimplement them.
local previewBars = {}
local previewTicker

---@param element table Castbar element
local function StartPreviewCast(element)
    local duration = CreateDuration()
    duration:SetTimeFromStart(GetTime(), PREVIEW_DURATION)

    -- The attribute set oUF's CastStart leaves behind, so its OnUpdate holds the bar open.
    element.casting = true
    element.channeling, element.empowering = nil, nil
    element.castID, element.spellID = nil, nil
    element.spellName = L['Preview Cast']
    element.delay = 0
    element.holdTime = 0

    element:SetTimerDuration(duration, element.smoothing, ElapsedTime)
    if element.Icon then element.Icon:SetTexture(FALLBACK_ICON) end
    if element.Spark then element.Spark:Show() end
    if element.Text then element.Text:SetText(L['Preview Cast']) end

    element:PostCastStart(element.nuiCastPreviewUnit)
    element:Show()
end

---@param element table Castbar element
local function StopPreviewCast(element)
    -- Clearing the cast flags lets oUF's OnUpdate reset the rest of the attributes for us.
    element.casting = nil
    element.holdTime = 0
    element.nuiCastPreviewUnit = nil
    element:Hide() -- The OnHide hook takes the container with it.
end

local function RestartPreviewCasts()
    for element in pairs(previewBars) do
        StartPreviewCast(element)
    end
end

-- Update the ticker based on whether any frames are previewing casts.
local function UpdatePreviewTicker()
    local shouldRun = next(previewBars) ~= nil
    if shouldRun and not previewTicker then
        previewTicker = C_Timer.NewTicker(PREVIEW_DURATION, RestartPreviewCasts)
    elseif not shouldRun and previewTicker then
        previewTicker:Cancel()
        previewTicker = nil
    end
end

---@class UnitFramesElements
---@field Castbar UnitFramesCastbarElement
UF.Elements = UF.Elements or {}

---@class UnitFramesCastbarElement
UF.Elements.Castbar = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.Castbar then return end

        -- Container frame for the castbar and icon.
        local container = CreateFrame('Frame', nil, self)
        container:SetFrameLevel(self:GetFrameLevel() + 2)
        container:CreateBackdrop(true)
        container:AddBorders()
        container:Hide()
        self.CastbarContainer = container

        -- Icon texture, sits in the container's left square.
        local icon = container:CreateTexture(nil, 'ARTWORK', nil, 7)
        icon:SetZoom()

        -- Main castbar frame, oUF handles the bar's min/max values and OnUpdate.
        local castBar = CreateFrame('StatusBar', nil, container) --[[@as oUF.Castbar]]
        castBar:SetFrameLevel(container:GetFrameLevel() + 1)
        castBar:SetPixelSnap()
        castBar.nuiContainer = container -- PostCastStart shows it, OnHide hides it with the bar
        castBar:HookScript('OnHide', function() container:Hide() end)
        castBar.CreatePip = CreatePip
        castBar.PostCastStart = PostCastStart
        castBar.PostCastInterruptible = PostCastStart
        castBar.PostCastFail = PostCastFail
        castBar.PostCastInterrupted = PostCastFail
        castBar.Icon = icon -- oUF sets its texture on cast start

        -- Spark, its texture comes from the global spark media in Configure.
        local spark = castBar:CreateTexture(nil, 'OVERLAY')
        spark:SetBlendMode('ADD')
        spark:SetPixelSnap() -- When using solid spark style, we need this otherwise the spark will flicker.
        castBar.Spark = spark

        -- Safe zone texture for latency, player only, oUF handles positioning.
        -- Kept on nuiSafeZone as well: disabling it clears the element field oUF reads.
        local safeZone = castBar:CreateTexture(nil, 'ARTWORK', nil, 1)
        safeZone:SetColorTexture(0.8, 0.1, 0.1, 0.35)
        castBar.SafeZone = safeZone
        castBar.nuiSafeZone = safeZone

        -- Cast name text
        local text = castBar:CreateFontString(nil, 'OVERLAY')
        castBar.Text = text

        -- Cast time text
        local time = castBar:CreateFontString(nil, 'OVERLAY')
        castBar.Time = time

        self.Castbar = castBar
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local castBar = self.Castbar
        if not castBar then return end
        local container = self.CastbarContainer
        local icon = castBar.Icon
        local cDB = uDB.Castbar
        local pos = cDB.Position

        -- The whole colour set comes from General unless the unit overrides it.
        local classColor, color, shieldColor, failColor, background
        if cDB.UseGlobalColors then
            classColor = general.CastbarColorByClass
            color = general.Colors.Castbar
            shieldColor = general.Colors.CastbarNonInterruptible
            failColor = general.Colors.CastbarFail
            background = general.Colors.CastbarBackground
        else
            classColor = cDB.ColorByClass
            color = cDB.Color
            shieldColor = cDB.NonInterruptibleColor
            failColor = cDB.FailColor
            background = cDB.Background
        end

        -- The safe zone carries its own override: it toggles a feature, not just a colour.
        local safeZoneDB = cDB.SafeZone.UseGlobal and general.SafeZone or cDB.SafeZone

        -- Position and size the container.
        container:ClearAllPoints()
        container:SetPixelPoint('TOPLEFT', self, 'BOTTOMLEFT', pos.XOffset, pos.YOffset)
        container:SetPixelPoint('TOPRIGHT', self, 'BOTTOMRIGHT', pos.XOffset, pos.YOffset)
        container:SetPixelHeight(cDB.Height)
        container:SetBackgroundColor(background[1], background[2], background[3], background[4])

        -- Icon sits in the container's left square, the bar starts just right of it.
        local barLeftInset = 1
        if cDB.ShowIcon then
            icon:ClearAllPoints()
            icon:SetPixelPoint('TOPLEFT', container, 'TOPLEFT', 1, -1)
            icon:SetPixelPoint('BOTTOMLEFT', container, 'BOTTOMLEFT', 1, 1)
            icon:SetPixelWidth(cDB.Height - 2)
            icon:Show()
            barLeftInset = cDB.Height - 1
        else
            icon:Hide()
        end

        -- Position and size the castbar inside the container, with a 1px inset on all sides.
        castBar:ClearAllPoints()
        castBar:SetPixelPoint('TOPLEFT', container, 'TOPLEFT', barLeftInset, -1)
        castBar:SetPixelPoint('BOTTOMRIGHT', container, 'BOTTOMRIGHT', -1, 1)
        castBar:SetStatusBarTexture(NRSKNUI:GetStatusbar(general, cDB.StatusBarTexture))
        castBar.smoothing = Enum.StatusBarInterpolation.Immediate -- Easing would lag the cast progress.
        castBar.timeToHold = cDB.TimeToHold

        -- Cast colours read by the PostCast handlers.
        castBar.nuiColorByClass = classColor
        castBar.nuiColor = NRSKNUI:CreateColor(color[1], color[2], color[3], color[4])
        castBar.nuiShieldColor = NRSKNUI:CreateColor(shieldColor[1], shieldColor[2], shieldColor[3], shieldColor[4])
        castBar.nuiFailColor = NRSKNUI:CreateColor(failColor[1], failColor[2], failColor[3], failColor[4])

        -- Latency safe zone, player only (oUF positions it on cast start and skips a nil field).
        local safeZone = castBar.nuiSafeZone
        local safeZoneColor = safeZoneDB.Color
        safeZone:SetColorTexture(safeZoneColor[1], safeZoneColor[2], safeZoneColor[3], safeZoneColor[4])
        safeZone:SetShown(safeZoneDB.Enabled)
        castBar.SafeZone = safeZoneDB.Enabled and safeZone or nil

        -- Spark sits on the right edge of the bar, SetSpark sizes it to suit the chosen texture.
        local spark = castBar.Spark
        spark:ClearAllPoints()
        spark:SetPoint('CENTER', castBar:GetStatusBarTexture(), 'RIGHT', 0, 0)
        NRSKNUI:SetSpark(spark, general, cDB.Height)

        -- Cast name text sits inside the bar with a 4px inset.
        local text = castBar.Text
        text:SetFontStyle(general, 11, general.FontOutline)
        text:ClearAllPoints()
        text:SetPixelPoint('LEFT', castBar, 'LEFT', 4, 0)
        text:SetShown(cDB.ShowSpellName)

        -- Cast time text sits inside the bar with a 4px inset.
        local time = castBar.Time
        time:SetFontStyle(general, 11, general.FontOutline)
        time:ClearAllPoints()
        time:SetPixelPoint('RIGHT', castBar, 'RIGHT', -4, 0)
        time:SetShown(cDB.ShowTime)
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    ---@param previewing boolean
    Preview = function(self, unit, uDB, general, previewing)
        local castBar = self.Castbar
        if not castBar then return end

        -- No duration API means no synthetic cast, the rest of the preview still works.
        if previewing and uDB.Castbar.Enabled and CreateDuration then
            castBar.nuiCastPreviewUnit = self.unit
            -- Alternating frames preview a shielded cast, so both configured colours are on screen.
            castBar.notInterruptible = (self.nuiPreviewIndex or 1) % 2 == 0

            previewBars[castBar] = true
            StartPreviewCast(castBar)
        elseif previewBars[castBar] then
            previewBars[castBar] = nil
            StopPreviewCast(castBar)
        end

        UpdatePreviewTicker()
    end,
}
