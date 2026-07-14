---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class DungeonCasts: AceModule, AceEvent-3.0
local DC = NRSKNUI:NewModule("DungeonCasts", "AceEvent-3.0")

local CreateFrame = CreateFrame
local UnitCastingInfo, UnitChannelInfo = UnitCastingInfo, UnitChannelInfo
local UnitCastingDuration, UnitChannelDuration = UnitCastingDuration, UnitChannelDuration
local UnitExists = UnitExists
local UnitCanAttack = UnitCanAttack
local UnitName = UnitName
local UnitClass = UnitClass
local UnitSpellTargetName = UnitSpellTargetName
local UnitSpellTargetClass = UnitSpellTargetClass
local GetTime = GetTime
local GetRaidTargetIndex = GetRaidTargetIndex
local SetRaidTargetIconTexture = SetRaidTargetIconTexture
local IsInInstance = IsInInstance
local C_Timer = C_Timer
local C_DurationUtil = C_DurationUtil
local C_CastingInfo = C_CastingInfo
local C_ClassColor = C_ClassColor
local Enum = Enum
local CreateColor = CreateColor
local pairs, ipairs = pairs, ipairs
local wipe = wipe
local tinsert, tremove, tsort = table.insert, table.remove, table.sort
local strmatch = string.match
local mmin = math.min

local FALLBACK_ICON = 136243
local UPDATE_THROTTLE = 0.033
local PREVIEW_DURATION = 8
local NAMEPLATE_PATTERN = "^nameplate%d+$"
local MAX_NAMEPLATES = 40

local PREVIEW_SPELLS = {
    { name = "Shadow Bolt",     icon = 136197, shielded = false, channeling = false, raidIcon = 8,   hasTarget = true },
    { name = "Drain Life",      icon = 136169, shielded = true,  channeling = true,  raidIcon = 4,   hasTarget = false },
    { name = "Fireball",        icon = 135812, shielded = false, channeling = false, raidIcon = 1,   hasTarget = true },
    { name = "Frostbolt",       icon = 135846, shielded = false, channeling = false, raidIcon = 6,   hasTarget = true },
    { name = "Arcane Missiles", icon = 136096, shielded = false, channeling = true,  raidIcon = 2,   hasTarget = false },
    { name = "Pyroblast",       icon = 135808, shielded = false, channeling = false, raidIcon = 7,   hasTarget = true },
    { name = "Mind Flay",       icon = 136208, shielded = true,  channeling = true,  raidIcon = 3,   hasTarget = true },
    { name = "Lightning Bolt",  icon = 136048, shielded = false, channeling = false, raidIcon = 5,   hasTarget = false },
    { name = "Heal",            icon = 135916, shielded = true,  channeling = false, raidIcon = nil, hasTarget = false },
    { name = "Chain Lightning", icon = 136015, shielded = false, channeling = false, raidIcon = nil, hasTarget = true },
}

function DC:UpdateDB()
    self.db = NRSKNUI.db.profile.DungeonCasts
end

function DC:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)

    self.framePool = {}
    self.activeFrames = {}
    self.activeCount = 0
    self.sortedUnits = {}
end

function DC:CreateColorObjects()
    local db = self.db
    self.colors = {
        Casting = CreateColor(db.CastingColor[1], db.CastingColor[2], db.CastingColor[3]),
        Channeling = CreateColor(db.ChannelingColor[1], db.ChannelingColor[2], db.ChannelingColor[3]),
        Shielded = CreateColor(db.NotInterruptibleColor[1], db.NotInterruptibleColor[2], db.NotInterruptibleColor[3]),
    }
end

function DC:ShouldBeActive()
    if self.isPreview then return true end
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "party"
end

function DC:CheckInstanceType()
    local shouldBeActive = self:ShouldBeActive()
    if shouldBeActive and not self.instanceActive then
        self.instanceActive = true
        self:SetUpdateFrameRunning(true)
        self:ScanExistingNameplates()
    elseif not shouldBeActive and self.instanceActive then
        self.instanceActive = false
        self:SetUpdateFrameRunning(false)
        self:ReleaseAllBars()
    end
end

local function GetAnchorSize(frameDb)
    local maxBars = frameDb.MaxBars
    local height = maxBars * frameDb.Height + (maxBars - 1) * frameDb.Spacing
    return frameDb.Width, height
end

function DC:CreateAnchorFrame()
    if self.anchorFrame then return end
    local anchor = CreateFrame("Frame", "NRSKNUI_DungeonCastsAnchor", UIParent)
    anchor:SetSize(GetAnchorSize(self.db.Frame))
    anchor:SetFrameStrata("HIGH")
    self.anchorFrame = anchor
    self:ApplyAnchorPosition()
end

function DC:ApplyAnchorPosition()
    if not self.anchorFrame then return end
    local frameDb = self.db.Frame
    local pos = frameDb.Position
    local parent = NRSKNUI:ResolveAnchorFrame(frameDb.anchorFrameType, frameDb.ParentFrame)
    local growUp = frameDb.GrowthDirection == "UP"

    self.anchorFrame:SetParent(parent)
    self.anchorFrame:ClearAllPoints()
    self.anchorFrame:SetSize(GetAnchorSize(frameDb))
    self.anchorFrame:SetFrameStrata(frameDb.Strata)

    if growUp then
        self.anchorFrame:SetPoint("BOTTOM", parent, pos.AnchorTo, pos.XOffset, pos.YOffset)
    else
        self.anchorFrame:SetPoint("TOP", parent, pos.AnchorTo, pos.XOffset, pos.YOffset)
    end
end

function DC:CreateBarFrame()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    frame:EnableMouse(false)
    frame:Hide()

    frame.iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.iconFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    frame.iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)

    frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetPoint("TOPLEFT", 1, -1)
    frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)

    frame.castBar = CreateFrame("StatusBar", nil, frame)
    frame.castBar:SetMinMaxValues(0, 1)
    frame.castBar:SetValue(0)

    frame.spark = frame.castBar:CreateTexture(nil, "OVERLAY")
    frame.spark:SetBlendMode("ADD")
    frame.spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])

    frame.nameText = frame.castBar:CreateFontString(nil, "OVERLAY")
    frame.timeText = frame.castBar:CreateFontString(nil, "OVERLAY")
    frame.targetText = frame.castBar:CreateFontString(nil, "OVERLAY")

    frame.raidIcon = frame:CreateTexture(nil, "OVERLAY")
    frame.raidIcon:SetTexture("Interface/TargetingFrame/UI-RaidTargetingIcons")
    frame.raidIcon:Hide()

    return frame
end

---@param bar Frame
function DC:ConfigureBar(bar)
    if not bar then return end

    local db = self.db
    local frameDb = db.Frame
    local barDb = db.BarDisplay
    local iconDb = db.Icon
    local textDb = db.Text
    local raidDb = db.RaidIcon

    local height = frameDb.Height
    local width = frameDb.Width

    bar:SetSize(width, height)
    bar:SetFrameStrata(frameDb.Strata)
    local bg = db.BackgroundColor
    bar:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])

    local borderColor = db.BorderColor
    if not bar.borders then
        bar:AddBorders()
        bar:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    else
        bar:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    end

    if iconDb.Enabled then
        bar.iconFrame:SetSize(height, height)
        bar.iconFrame:Show()
        bar.iconFrame:SetBackdropColor(0, 0, 0, 0.8)
        if not bar.iconFrame:HasBorder() then
            bar.iconFrame:AddBorders()
            bar.iconFrame:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        else
            bar.iconFrame:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
        end
        bar.icon:SetZoom()
    else
        bar.iconFrame:Hide()
    end

    bar.castBar:ClearAllPoints()
    if iconDb.Enabled then
        bar.castBar:SetPoint("LEFT", bar.iconFrame, "RIGHT", 0, 0)
    else
        bar.castBar:SetPoint("LEFT", bar, "LEFT", 1, 0)
    end
    bar.castBar:SetPoint("RIGHT", bar, "RIGHT", -1, 0)
    bar.castBar:SetPoint("TOP", bar, "TOP", 0, -1)
    bar.castBar:SetPoint("BOTTOM", bar, "BOTTOM", 0, 1)
    bar.castBar:SetStatusBarTexture(NRSKNUI:GetStatusbarPath(NRSKNUI:GetEffectiveStatusBar(barDb)))

    bar.spark:SetSize(12, height)
    bar.spark:ClearAllPoints()
    bar.spark:SetPoint("CENTER", bar.castBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    bar.spark:SetShown(barDb.SparkEnabled)

    local tc = textDb.TextColor
    bar.nameText:ClearAllPoints()
    bar.nameText:SetPoint("LEFT", bar.castBar, "LEFT", 4, 0)
    bar.nameText:SetJustifyH(textDb.NameAlign)
    bar.nameText:SetFontStyle(barDb)
    bar.nameText:SetTextColor(tc[1], tc[2], tc[3], tc[4])

    bar.timeText:ClearAllPoints()
    bar.timeText:SetPoint("RIGHT", bar.castBar, "RIGHT", -4, 0)
    bar.timeText:SetJustifyH(textDb.TimeAlign)
    bar.timeText:SetFontStyle(barDb)
    bar.timeText:SetTextColor(tc[1], tc[2], tc[3], tc[4])
    bar.timeText:SetShown(textDb.ShowTime)

    local targetDb = db.Target
    bar.targetText:ClearAllPoints()
    if targetDb and targetDb.Position == "LEFT" then
        bar.targetText:SetPoint("LEFT", bar.nameText, "RIGHT", 2, 0)
        bar.targetText:SetJustifyH("LEFT")
    else
        bar.targetText:SetPoint("RIGHT", bar.timeText, "LEFT", -4, 0)
        bar.targetText:SetJustifyH("RIGHT")
    end
    bar.targetText:SetFontStyle(barDb)
    bar.targetText:SetTextColor(tc[1], tc[2], tc[3], tc[4])
    bar.targetText:Hide()

    if raidDb.Enabled then
        bar.raidIcon:SetSize(raidDb.Size, raidDb.Size)
        bar.raidIcon:ClearAllPoints()
        bar.raidIcon:SetPoint("RIGHT", bar, "LEFT", -4, 0)
    end
end

function DC:AcquireBar()
    local bar = tremove(self.framePool)
    if not bar then
        bar = self:CreateBarFrame()
    end
    self:ConfigureBar(bar)
    return bar
end

function DC:ReleaseBar(bar)
    if not bar then return end
    bar:Hide()
    bar:ClearAllPoints()
    bar.unit = nil
    bar.casting = nil
    bar.channeling = nil
    bar.notInterruptible = nil
    bar.cachedDuration = nil
    bar.spellName = nil
    bar.startTime = nil
    bar.previewRaidIcon = nil
    bar.previewIcon = nil
    bar.previewTarget = nil
    bar.previewTargetClass = nil
    bar.raidIcon:Hide()
    bar.targetText:Hide()
    tinsert(self.framePool, bar)
end

function DC:ReleaseAllBars()
    local frames = self.activeFrames
    self.activeFrames = {}
    self.activeCount = 0
    for _, bar in pairs(frames) do
        self:ReleaseBar(bar)
    end
    wipe(self.sortedUnits)
end

function DC:IsValidUnit(unit)
    if not unit then return false end
    if not strmatch(unit, NAMEPLATE_PATTERN) then return false end
    if not UnitExists(unit) then return false end
    if not UnitCanAttack("player", unit) then return false end
    return true
end

function DC:UpdateBarColor(bar)
    if not bar or not bar.castBar then return end
    local texture = bar.castBar:GetStatusBarTexture()

    if self.isPreview then
        local db = self.db
        local c = bar.notInterruptible and db.NotInterruptibleColor
            or (bar.channeling and db.ChannelingColor
                or db.CastingColor)
        texture:SetVertexColor(c[1], c[2], c[3], c[4])
        return
    end

    local baseColor = bar.channeling and self.colors.Channeling or self.colors.Casting
    if bar.notInterruptible ~= nil then
        texture:SetVertexColorFromBoolean(bar.notInterruptible, self.colors.Shielded, baseColor)
    else
        texture:SetVertexColor(baseColor:GetRGB())
    end
end

function DC:UpdateRaidIcon(bar, unit)
    if not bar.raidIcon then return end
    if not self.db.RaidIcon.Enabled then
        bar.raidIcon:Hide()
        return
    end

    if self.isPreview then
        if bar.previewRaidIcon then
            SetRaidTargetIconTexture(bar.raidIcon, bar.previewRaidIcon)
            bar.raidIcon:Show()
        end
        return
    end

    local index = GetRaidTargetIndex(unit)
    if index then
        SetRaidTargetIconTexture(bar.raidIcon, index)
        bar.raidIcon:Show()
    else
        bar.raidIcon:Hide()
    end
end

local TARGET_SEPARATORS = {
    ["»"] = "»",
    ["-"] = "-",
    [">"] = ">",
    [">>"] = ">>",
    ["•"] = "•",
    ["None"] = "",
}

function DC:UpdateTargetText(bar, targetName, targetClass)
    if not bar.targetText then return end

    local targetDb = self.db.Target
    if not targetDb or not targetDb.Enabled or not targetName then
        bar.targetText:Hide()
        if bar.targetText.softOutline then
            bar.targetText.softOutline:SetShown(false)
        end
        return
    end

    local separator = TARGET_SEPARATORS[targetDb.Separator] or targetDb.Separator or "»"

    local plainText
    if separator ~= "" then
        if targetDb.Position == "LEFT" then
            plainText = separator .. " " .. targetName
        else
            plainText = targetName .. " " .. separator
        end
    else
        plainText = targetName
    end

    local tc = self.db.Text.TextColor
    local textColorMarkup = string.format("|cff%02x%02x%02x", tc[1] * 255, tc[2] * 255, tc[3] * 255)
    local coloredTarget

    if targetDb.ShowClassColor and targetClass then
        local color = C_ClassColor.GetClassColor(targetClass)
        if color and color.WrapTextInColorCode then
            coloredTarget = color:WrapTextInColorCode(targetName)
        else
            coloredTarget = textColorMarkup .. targetName .. "|r"
        end
    else
        coloredTarget = textColorMarkup .. targetName .. "|r"
    end

    local coloredSeparator = textColorMarkup .. separator .. "|r"
    local displayText
    if separator ~= "" then
        if targetDb.Position == "LEFT" then
            displayText = coloredSeparator .. " " .. coloredTarget
        else
            displayText = coloredTarget .. " " .. coloredSeparator
        end
    else
        displayText = coloredTarget
    end

    bar.targetText:SetText(displayText)

    if bar.targetText.softOutline then
        bar.targetText.softOutline:SetShown(true)
        bar.targetText.softOutline:SetText(plainText)
    end

    bar.targetText:Show()
end

---@param unit string
---@return table|nil castData
function DC:FetchCastData(unit)
    local name, text, texture, _, _, _, castID, notInterruptible, spellID = UnitCastingInfo(unit)
    if name then
        local targetName = UnitSpellTargetName and UnitSpellTargetName(unit) or nil
        local targetClass = targetName and UnitSpellTargetClass and UnitSpellTargetClass(unit) or nil

        return {
            name = name,
            text = text,
            texture = texture,
            castID = castID,
            notInterruptible = notInterruptible,
            spellID = spellID,
            duration = UnitCastingDuration(unit),
            direction = Enum.StatusBarTimerDirection.ElapsedTime,
            isCasting = true,
            isChanneling = false,
            targetName = targetName,
            targetClass = targetClass,
        }
    end

    name, text, texture, _, _, _, notInterruptible, spellID = UnitChannelInfo(unit)
    if name then
        local targetName = UnitSpellTargetName and UnitSpellTargetName(unit) or nil
        local targetClass = targetName and UnitSpellTargetClass and UnitSpellTargetClass(unit) or nil

        return {
            name = name,
            text = text,
            texture = texture,
            notInterruptible = notInterruptible,
            spellID = spellID,
            duration = UnitChannelDuration(unit),
            direction = Enum.StatusBarTimerDirection.RemainingTime,
            isCasting = false,
            isChanneling = true,
            targetName = targetName,
            targetClass = targetClass,
        }
    end

    return nil
end

function DC:GetOrAcquireBar(unit)
    local bar = self.activeFrames[unit]
    if bar then return bar end

    if self.activeCount >= self.db.Frame.MaxBars then return nil end

    bar = self:AcquireBar()
    self.activeFrames[unit] = bar
    self.activeCount = self.activeCount + 1
    return bar
end

function DC:PopulateBar(bar, unit, data)
    bar.unit = unit
    bar.casting = data.isCasting
    bar.channeling = data.isChanneling
    bar.notInterruptible = data.notInterruptible
    bar.cachedDuration = data.duration
    bar.spellName = data.text or data.name
    bar.startTime = GetTime()

    if bar.icon then
        bar.icon:SetTexture(data.texture or FALLBACK_ICON)
    end
    bar.nameText:SetText(data.text or data.name or "")

    if data.duration then
        bar.castBar:SetTimerDuration(data.duration, Enum.StatusBarInterpolation.Immediate, data.direction)
    end

    self:UpdateBarColor(bar)
    self:UpdateRaidIcon(bar, unit)
    self:UpdateTargetText(bar, data.targetName, data.targetClass)

    if bar.spark then
        bar.spark:SetShown(data.isCasting and self.db.BarDisplay.SparkEnabled)
    end
end

function DC:StartCast(unit)
    if not self:IsValidUnit(unit) then return end

    local data = self:FetchCastData(unit)
    if not data then
        self:StopCast(unit)
        return
    end

    local bar = self:GetOrAcquireBar(unit)
    if not bar then return end

    self:PopulateBar(bar, unit, data)
    bar:Show()
    self:PositionAllBars()
end

function DC:StopCast(unit)
    local bar = self.activeFrames[unit]
    if not bar then return end
    self.activeFrames[unit] = nil
    self.activeCount = self.activeCount - 1
    self:ReleaseBar(bar)
    self:PositionAllBars()
end

function DC:SortUnits()
    wipe(self.sortedUnits)
    for unit in pairs(self.activeFrames) do
        tinsert(self.sortedUnits, unit)
    end
    local frames = self.activeFrames
    tsort(self.sortedUnits, function(a, b)
        local ba, bb = frames[a], frames[b]
        return (ba.startTime or 0) < (bb.startTime or 0)
    end)
end

function DC:PositionAllBars()
    if not self.anchorFrame then return end
    self:SortUnits()

    local frameDb = self.db.Frame
    local height = frameDb.Height
    local spacing = frameDb.Spacing
    local growUp = frameDb.GrowthDirection == "UP"
    local step = height + spacing

    for i, unit in ipairs(self.sortedUnits) do
        local bar = self.activeFrames[unit]
        if bar then
            bar:ClearAllPoints()
            local offset = (i - 1) * step
            if growUp then
                bar:SetPoint("BOTTOM", self.anchorFrame, "BOTTOM", 0, offset)
            else
                bar:SetPoint("TOP", self.anchorFrame, "TOP", 0, -offset)
            end
        end
    end
end

local CAST_EVENT_HANDLERS = {
    UNIT_SPELLCAST_START = "StartCast",
    UNIT_SPELLCAST_CHANNEL_START = "StartCast",
    UNIT_SPELLCAST_STOP = "StopCast",
    UNIT_SPELLCAST_CHANNEL_STOP = "StopCast",
    UNIT_SPELLCAST_FAILED = "StopCast",
    UNIT_SPELLCAST_INTERRUPTED = "StopCast",
    UNIT_SPELLCAST_INTERRUPTIBLE = "UpdateInterruptible",
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = "UpdateInterruptible",
}

function DC:OnNameplateAdded(_, unit)
    if not self.instanceActive then return end
    if not self:IsValidUnit(unit) then return end
    self:StartCast(unit)
end

function DC:OnNameplateRemoved(_, unit)
    self:StopCast(unit)
end

function DC:OnCastEvent(event, unit)
    if not self.instanceActive then return end
    if not unit or not strmatch(unit, NAMEPLATE_PATTERN) then return end

    local handler = CAST_EVENT_HANDLERS[event]
    if handler then
        self[handler](self, unit)
    end
end

function DC:UpdateInterruptible(unit)
    local bar = self.activeFrames[unit]
    if not bar then return end

    local castInfo = C_CastingInfo and
        (C_CastingInfo.GetCastInfo(unit) or C_CastingInfo.GetChannelInfo(unit))
    if castInfo then
        bar.notInterruptible = castInfo.notInterruptible
        self:UpdateBarColor(bar)
    end
end

function DC:ScanExistingNameplates()
    for i = 1, MAX_NAMEPLATES do
        local unit = "nameplate" .. i
        if UnitExists(unit) and self:IsValidUnit(unit) then
            self:StartCast(unit)
        end
    end
end

function DC:CreateUpdateFrame()
    if self.updateFrame then return end
    local f = CreateFrame("Frame")
    f:Hide()
    f.elapsed = 0
    f:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = frame.elapsed + elapsed
        if frame.elapsed < UPDATE_THROTTLE then return end
        frame.elapsed = 0
        self:OnUpdate()
    end)
    self.updateFrame = f
end

function DC:SetUpdateFrameRunning(running)
    if not self.updateFrame then return end
    if running then
        self.updateFrame:Show()
    else
        self.updateFrame:Hide()
    end
end

function DC:OnUpdate()
    local decimalsCurve = NRSKNUI.curves and NRSKNUI.curves.DurationDecimals
    for _, bar in pairs(self.activeFrames) do
        if bar:IsShown() and (bar.casting or bar.channeling) and bar.timeText then
            local duration = bar.cachedDuration or bar.castBar:GetTimerDuration()
            if duration then
                local remaining = duration:GetRemainingDuration()
                if remaining then
                    if decimalsCurve then
                        local decimals = duration:EvaluateRemainingDuration(decimalsCurve)
                        bar.timeText:SetFormattedText("%." .. decimals .. "f", remaining)
                    else
                        bar.timeText:SetFormattedText("%.1f", remaining)
                    end
                end
            end
        end
    end
end

function DC:ApplySettings()
    self:UpdateDB()
    self:CreateColorObjects()
    self:ApplyAnchorPosition()

    if self.isPreview then
        self:ReleaseAllBars()
        self:CreatePreviewBars()
        return
    end

    self:ReleaseAllBars()
    if self.instanceActive then
        self:ScanExistingNameplates()
    end
end

function DC:ApplyPosition()
    self:ApplyAnchorPosition()
    self:PositionAllBars()
end

function DC:CreatePreviewBars()
    self:UpdateDB()
    self:CreateColorObjects()

    local maxBars = mmin(self.db.Frame.MaxBars, #PREVIEW_SPELLS)
    local now = GetTime()

    local playerName = UnitName("player")
    local _, playerClass = UnitClass("player")

    for i = 1, maxBars do
        local fakeUnit = "preview" .. i
        local spell = PREVIEW_SPELLS[i]
        local bar = self:AcquireBar()
        self.activeFrames[fakeUnit] = bar
        self.activeCount = self.activeCount + 1

        local targetName = spell.hasTarget and playerName or nil
        local targetClass = spell.hasTarget and playerClass or nil

        bar.unit = fakeUnit
        bar.casting = not spell.channeling
        bar.channeling = spell.channeling
        bar.notInterruptible = spell.shielded
        bar.spellName = spell.name
        bar.previewRaidIcon = spell.raidIcon
        bar.previewIcon = spell.icon
        bar.previewTarget = targetName
        bar.previewTargetClass = targetClass
        bar.startTime = now + i * 0.001

        if bar.icon then
            bar.icon:SetTexture(spell.icon or FALLBACK_ICON)
        end
        bar.nameText:SetText(spell.name)

        local duration = C_DurationUtil.CreateDuration()
        duration:SetTimeFromStart(now, PREVIEW_DURATION)
        local dir = spell.channeling and Enum.StatusBarTimerDirection.RemainingTime
            or Enum.StatusBarTimerDirection.ElapsedTime
        bar.castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, dir)
        bar.cachedDuration = duration

        self:UpdateBarColor(bar)
        self:UpdateRaidIcon(bar, fakeUnit)
        self:UpdateTargetText(bar, targetName, targetClass)

        if bar.spark then
            bar.spark:SetShown(not spell.channeling and self.db.BarDisplay.SparkEnabled)
        end

        bar:Show()
    end

    self:PositionAllBars()
end

function DC:ShowPreview()
    if self.isPreview then return end
    if not self.anchorFrame then self:CreateAnchorFrame() end
    self:CreateUpdateFrame()

    self.isPreview      = true
    self.instanceActive = true

    self:CreatePreviewBars()
    self:SetUpdateFrameRunning(true)

    if self.previewTicker then self.previewTicker:Cancel() end
    self.previewTicker = C_Timer.NewTicker(PREVIEW_DURATION, function()
        if not self.isPreview then return end
        local now = GetTime()
        for _, bar in pairs(self.activeFrames) do
            if bar.cachedDuration then
                local duration = C_DurationUtil.CreateDuration()
                duration:SetTimeFromStart(now, PREVIEW_DURATION)
                local dir = bar.channeling and Enum.StatusBarTimerDirection.RemainingTime
                    or Enum.StatusBarTimerDirection.ElapsedTime
                bar.castBar:SetTimerDuration(duration, Enum.StatusBarInterpolation.Immediate, dir)
                bar.cachedDuration = duration
            end
        end
    end)
end

function DC:HidePreview()
    if not self.isPreview then return end
    self.isPreview = false

    if self.previewTicker then
        self.previewTicker:Cancel()
        self.previewTicker = nil
    end

    self:ReleaseAllBars()

    if self.db and self.db.Enabled then
        self:CheckInstanceType()
        self:SetUpdateFrameRunning(self.instanceActive)
    else
        self.instanceActive = false
        self:SetUpdateFrameRunning(false)
    end
end

function DC:OnEnable()
    self:UpdateDB()
    if not self.db.Enabled then return end

    self:CreateColorObjects()
    self:CreateAnchorFrame()
    self:CreateUpdateFrame()

    self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnNameplateAdded")
    self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnNameplateRemoved")

    for event in pairs(CAST_EVENT_HANDLERS) do
        self:RegisterEvent(event, "OnCastEvent")
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckInstanceType")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "CheckInstanceType")

    self:CheckInstanceType()
    self:SetUpdateFrameRunning(self.instanceActive)

    NRSKNUI.EditMode:RegisterElement({
        key = "DungeonCasts",
        displayName = "Dungeon Casts",
        frame = self.anchorFrame,
        getPosition = function() return self.db.Frame.Position end,
        setPosition = function(pos)
            local p = self.db.Frame.Position
            p.AnchorTo = pos.AnchorTo
            p.XOffset = pos.XOffset
            p.YOffset = pos.YOffset
            self:ApplyPosition()
        end,
        getAnchorFrom = function()
            return self.db.Frame.GrowthDirection == "UP" and "BOTTOM" or "TOP"
        end,
        getParentFrame = function()
            return NRSKNUI:ResolveAnchorFrame(self.db.Frame.anchorFrameType, self.db.Frame.ParentFrame)
        end,
        guiPath = "DungeonCasts",
    })
end

function DC:OnDisable()
    self:HidePreview()
    self:ReleaseAllBars()
    self.instanceActive = false

    self:SetUpdateFrameRunning(false)
    if self.anchorFrame then
        self.anchorFrame:Hide()
    end

    self:UnregisterAllEvents()
end
