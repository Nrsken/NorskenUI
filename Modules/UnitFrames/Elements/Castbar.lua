---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local select = select

local EvaluateColorFromBoolean = C_CurveUtil and C_CurveUtil.EvaluateColorFromBoolean

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

UF.Elements = UF.Elements or {}
UF.Elements.Castbar = {
    Construct = function(frame, unit)
        if frame.Castbar then return end

        -- Container frame for the castbar and icon.
        local container = CreateFrame('Frame', nil, frame)
        container:SetFrameLevel(frame:GetFrameLevel() + 2)
        container:CreateBackdrop(true)
        container:AddBorders()
        container:Hide()
        frame.CastbarContainer = container

        -- Icon texture, sits in the container's left square.
        local icon = container:CreateTexture(nil, 'ARTWORK', nil, 7)
        icon:SetZoom()

        -- Main castbar frame, oUF handles the bar's min/max values and OnUpdate.
        local castBar = CreateFrame('StatusBar', nil, container)
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

        frame.Castbar = castBar
    end,

    Configure = function(frame, unit, uDB, general)
        local castBar = frame.Castbar
        if not castBar then return end
        local container = frame.CastbarContainer
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
        container:SetPixelPoint('TOPLEFT', frame, 'BOTTOMLEFT', pos.XOffset, pos.YOffset)
        container:SetPixelPoint('TOPRIGHT', frame, 'BOTTOMRIGHT', pos.XOffset, pos.YOffset)
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
}
