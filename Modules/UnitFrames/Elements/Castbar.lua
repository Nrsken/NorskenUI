---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
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

        -- Spark
        local spark = castBar:CreateTexture(nil, 'OVERLAY')
        spark:SetBlendMode('ADD')
        spark:SetColorTexture(1, 1, 1, 0.5)
        castBar.Spark = spark

        -- Safe zone texture for latency, player only, oUF handles positioning.
        local safeZone = castBar:CreateTexture(nil, 'ARTWORK', nil, 1)
        safeZone:SetColorTexture(0.8, 0.1, 0.1, 0.35)
        castBar.SafeZone = safeZone

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

        -- Position and size the container.
        container:ClearAllPoints()
        container:SetPixelPoint('TOPLEFT', frame, 'BOTTOMLEFT', pos.XOffset, pos.YOffset)
        container:SetPixelPoint('TOPRIGHT', frame, 'BOTTOMRIGHT', pos.XOffset, pos.YOffset)
        container:SetPixelHeight(cDB.Height)
        container:SetBackgroundColor(cDB.Background[1], cDB.Background[2], cDB.Background[3], cDB.Background[4])

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
        castBar:SetStatusBarTexture(NRSKNUI:GetBarTexture(general, cDB.StatusBarTexture))
        castBar.smoothing = Enum.StatusBarInterpolation.Immediate -- Easing would lag the cast progress.
        castBar.timeToHold = cDB.TimeToHold

        -- Cast colours read by the PostCast handlers.
        castBar.nuiColorByClass = cDB.ColorByClass
        castBar.nuiColor = NRSKNUI:CreateColor(cDB.Color[1], cDB.Color[2], cDB.Color[3], cDB.Color[4])
        castBar.nuiShieldColor = NRSKNUI:CreateColor(cDB.NonInterruptibleColor[1], cDB.NonInterruptibleColor[2], cDB.NonInterruptibleColor[3], cDB.NonInterruptibleColor[4])
        castBar.nuiFailColor = NRSKNUI:CreateColor(cDB.FailColor[1], cDB.FailColor[2], cDB.FailColor[3], cDB.FailColor[4])

        -- Spark sits on the right edge of the bar, 2px wide and as tall as the bar minus 2px.
        local spark = castBar.Spark
        spark:SetPixelWidth(2)
        spark:SetPixelHeight(cDB.Height - 2)
        spark:ClearAllPoints()
        spark:SetPoint('CENTER', castBar:GetStatusBarTexture(), 'RIGHT', 0, 0)

        -- Cast name text sits inside the bar with a 4px inset.
        local text = castBar.Text
        text:SetFontStyle(general, 11, 'OUTLINE') --TODO: Hook up to db font settings
        text:ClearAllPoints()
        text:SetPixelPoint('LEFT', castBar, 'LEFT', 4, 0)
        text:SetShown(cDB.ShowSpellName)

        -- Cast time text sits inside the bar with a 4px inset.
        local time = castBar.Time
        time:SetFontStyle(general, 11, 'OUTLINE') --TODO: Hook up to db font settings
        time:ClearAllPoints()
        time:SetPixelPoint('RIGHT', castBar, 'RIGHT', -4, 0)
        time:SetShown(cDB.ShowTime)
    end,
}
