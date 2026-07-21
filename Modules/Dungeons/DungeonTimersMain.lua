-- NRSKNUI namespace
---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class DungeonTimers: AceModule, AceEvent-3.0, AceTimer-3.0
local DT = NRSKNUI:NewModule("DungeonTimers", "AceEvent-3.0", "AceTimer-3.0")

local CreateFrame = CreateFrame
local GetTime = GetTime
local unpack = unpack
local pairs, ipairs, next = pairs, ipairs, next
local wipe = wipe
local type = type
local select = select
local IsInInstance, GetInstanceInfo = IsInInstance, GetInstanceInfo
local CopyTable = CopyTable
local pcall = pcall
local issecretvalue = issecretvalue
local tostring, tonumber = tostring, tonumber
local floor = math.floor
local math_min = math.min
local table_insert = table.insert
local table_sort = table.sort
local C_Spell = C_Spell

DT.triggerFrames = {}
DT.triggerBars = {}
DT.spellCache = {}
DT.scheduledScans = {}

local instanceIdToDungeonKey = nil
local VISUAL_UPDATE_INTERVAL = 0.033

local function SortFramesByKey(a, b)
    if a.dungeonKey ~= b.dungeonKey then return (a.dungeonKey or "") < (b.dungeonKey or "") end
    return (tonumber(a.triggerId) or 0) < (tonumber(b.triggerId) or 0)
end

local LOAD_FILTERS = {
    { enabled = "loadRoleEnabled", key = "role",     fields = { TANK = "loadRoleTank", HEALER = "loadRoleHealer", DAMAGER = "loadRoleDPS" } },
    { enabled = "loadPosEnabled",  key = "position", fields = { MELEE = "loadPosMelee", RANGED = "loadPosRanged" } },
}

local function CheckLoadConditions(trigger, isPreview)
    if isPreview then return true end
    for _, filter in ipairs(LOAD_FILTERS) do
        if trigger[filter.enabled] then
            local value = NRSKNUI.MySpec[filter.key]
            if value and not trigger[filter.fields[value]] then return false end
        end
    end
    return true
end

function DT:UpdateDB()
    if NRSKNUI.db and NRSKNUI.db.profile then
        self.db = NRSKNUI.db.profile.DungeonTimers
        if self.db and not self.db.Dungeons then self.db.Dungeons = {} end
    end
end

function DT:InvalidateInstanceCache()
    instanceIdToDungeonKey = nil
end

function DT:UpdateCurrentDungeon()
    local inInstance, instanceType = IsInInstance()
    if not inInstance or (instanceType ~= "party" and instanceType ~= "raid") then
        if self.currentDungeonKey then
            self.currentDungeonKey = nil
            self:StopAllBars()
        end
        return
    end

    local instanceId = select(8, GetInstanceInfo())
    if not instanceId then
        self.currentDungeonKey = nil
        return
    end

    if not instanceIdToDungeonKey and self.db and self.db.Dungeons then
        instanceIdToDungeonKey = {}
        for dungeonKey, dungeonData in pairs(self.db.Dungeons) do
            if not dungeonData.instanceId then
                local info = NRSKNUI.DUNGEON_INFO and NRSKNUI.DUNGEON_INFO[dungeonKey]
                if info and info.instanceId then
                    dungeonData.instanceId = info.instanceId
                end
            end
            if dungeonData.instanceId then
                instanceIdToDungeonKey[dungeonData.instanceId] = dungeonKey
            end
        end
    end

    local newDungeonKey = instanceIdToDungeonKey and instanceIdToDungeonKey[instanceId] or nil

    if self.currentDungeonKey ~= newDungeonKey then
        self:StopAllBars()
        self.currentDungeonKey = newDungeonKey
    end
end

function DT:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function DT:GetBarGroupFrame()
    if not self.barGroupFrame then
        local frame = CreateFrame("Frame", "NorskenUI_DungeonTimers_BarGroup", UIParent)
        frame:SetSize(1, 1)
        frame:SetFrameStrata("HIGH")
        frame:Show()
        self.barGroupFrame = frame
    end
    return self.barGroupFrame
end

function DT:GetTextGroupFrame()
    if not self.textGroupFrame then
        local frame = CreateFrame("Frame", "NorskenUI_DungeonTimers_TextGroup", UIParent)
        frame:SetSize(1, 1)
        frame:SetFrameStrata("HIGH")
        frame:Show()
        self.textGroupFrame = frame
    end
    return self.textGroupFrame
end

function DT:PositionAllBars()
    self:UpdateDB()
    if not self.db then return end

    local barGroup = self.db.BarGroup
    local barDisplay = self.db.BarDisplay
    local pos = barGroup.Position
    local spacing = barGroup.Spacing
    local growUp = barGroup.GrowthDirection == "UP"
    local barHeight = barDisplay.barHeight
    local barWidth = barDisplay.barWidth

    local group = self:GetBarGroupFrame()
    group:ClearAllPoints()
    group:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset + 0.1, pos.YOffset + 0.1)

    local frames = {}
    for _, frame in pairs(self.triggerFrames) do
        if frame and frame:IsShown() and frame.isBarDisplay then table_insert(frames, frame) end
    end

    table_sort(frames, SortFramesByKey)

    for i, frame in ipairs(frames) do
        frame:SetSize(barWidth, barHeight)
        frame:ClearAllPoints()

        local offset = (i - 1) * (barHeight + spacing)
        local yPos = growUp and (pos.YOffset + offset) or (pos.YOffset - offset)
        frame:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset + 0.1, yPos + 0.1)
    end
end

function DT:PositionAllTexts()
    self:UpdateDB()
    if not self.db then return end

    local textGroup = self.db.TextGroup
    local textDisplay = self.db.TextDisplay
    local pos = textGroup.Position
    local spacing = textGroup.Spacing
    local growUp = textGroup.GrowthDirection == "UP"
    local textFontSize = textDisplay.FontSize
    local textHeight = textFontSize + 4

    local group = self:GetTextGroupFrame()
    group:ClearAllPoints()
    group:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset + 0.1, pos.YOffset + 0.1)

    local frames = {}
    for _, frame in pairs(self.triggerFrames) do
        if frame and frame:IsShown() and not frame.isBarDisplay then
            table_insert(frames, frame)
        end
    end

    table_sort(frames, SortFramesByKey)

    for i, frame in ipairs(frames) do
        frame:SetSize(400, textHeight)
        frame:ClearAllPoints()

        local offset = (i - 1) * (textHeight + spacing)
        local yPos = growUp and (pos.YOffset + offset) or (pos.YOffset - offset)
        frame:SetPoint(pos.AnchorFrom, UIParent, pos.AnchorTo, pos.XOffset + 0.1, yPos + 0.1)
    end
end

function DT:CreateTrigger(dungeonKey)
    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return nil end

    if not self.db.Dungeons[dungeonKey] then
        local info = NRSKNUI.DUNGEON_INFO and NRSKNUI.DUNGEON_INFO[dungeonKey]
        local instanceId = info and info.instanceId or nil
        self.db.Dungeons[dungeonKey] = { Enabled = true, instanceId = instanceId, Triggers = {} }
        self:InvalidateInstanceCache()
    end

    local dungeonDb = self.db.Dungeons[dungeonKey]
    if not dungeonDb.Triggers then
        dungeonDb.Triggers = {}
    end

    local maxId = 0
    for id in pairs(dungeonDb.Triggers) do
        local numId = tonumber(id)
        if numId and numId > maxId then
            maxId = numId
        end
    end
    local newId = maxId + 1

    local trigger = CopyTable(self.db.TriggerDefaults)
    trigger.id = newId
    trigger.name = "New Timer " .. newId
    dungeonDb.Triggers[newId] = trigger

    return newId
end

function DT:GetTriggerConfig(trigger)
    self:UpdateDB()
    local isBar = trigger.displayType == "bar"
    local barDisplay = self.db and self.db.BarDisplay or {}
    local textDisplay = self.db and self.db.TextDisplay or {}

    return {
        id = trigger.id,
        name = trigger.name,
        enabled = trigger.enabled ~= false,
        triggerType = trigger.triggerType,
        spellId = trigger.spellId,
        message = trigger.message,
        messageOperator = trigger.messageOperator,
        remainingEnabled = trigger.remainingEnabled,
        remainingOperator = trigger.remainingOperator,
        remainingValue = trigger.remainingValue,
        countEnabled = trigger.countEnabled,
        countOperator = trigger.countOperator,
        countValue = trigger.countValue,
        extendTimer = trigger.extendTimer,
        displayType = trigger.displayType,
        barWidth = barDisplay.barWidth,
        barHeight = barDisplay.barHeight,
        barTexture = barDisplay.barTexture,
        displaySettings = isBar and barDisplay or textDisplay,
        FontSize = isBar and barDisplay.FontSize or textDisplay.FontSize,
        FontOutline = isBar and barDisplay.FontOutline or textDisplay.FontOutline,
        FontShadow = isBar and barDisplay.FontShadow or textDisplay.FontShadow,
        iconEnabled = barDisplay.iconEnabled,
        textJustify = textDisplay.textAlign,
        useBigWigsColors = trigger.useBigWigsColors ~= false,
        barColor = trigger.barColor,
        backgroundColor = trigger.backgroundColor,
        textColor = trigger.textColor,
        barText1Format = trigger.barText1Format,
        barText1Justify = trigger.barText1Justify or "LEFT",
        barText1XOffset = trigger.barText1XOffset or 4,
        barText1YOffset = trigger.barText1YOffset or 0,
        barText2Format = trigger.barText2Format,
        barText2Justify = trigger.barText2Justify or "RIGHT",
        barText2XOffset = trigger.barText2XOffset or -4,
        barText2YOffset = trigger.barText2YOffset or 0,
        textFormat = trigger.textFormat,
        showDecimals = trigger.showDecimals,
        decimalThreshold = trigger.decimalThreshold,
        actionOnShowSound = trigger.actionOnShowSound,
        actionOnHideSound = trigger.actionOnHideSound,
    }
end

local function FormatTime(remaining, showDecimals, decimalThreshold)
    decimalThreshold = decimalThreshold or 3
    if remaining < 1 then return string.format("%.1f", remaining) end
    if showDecimals and remaining <= decimalThreshold then return string.format("%.1f", remaining) end
    return tostring(floor(remaining + 0.5))
end

function DT:BuildReplacements(config, barData, remaining)
    local replacements = {}

    if barData.icon then
        replacements["i"] = string.format("|T%s:0:0:0:0:64:64:4:60:4:60|t", barData.icon)
    else
        replacements["i"] = ""
    end

    replacements["n"] = barData.text or config.name or ""
    replacements["p"] = remaining and FormatTime(remaining, config.showDecimals, config.decimalThreshold) or ""
    replacements["s"] = barData.count and tostring(barData.count) or "0"
    replacements["d"] = barData.duration and tostring(floor(barData.duration + 0.5)) or ""

    return replacements
end

local STATE_NORMAL = 0
local STATE_PERCENT = 1
local STATE_PLACEHOLDER = 2

function DT:FormatText(formatStr, config, barData, remaining)
    if not formatStr or formatStr == "" then return "" end

    local replacements = self:BuildReplacements(config, barData, remaining)
    local result = ""
    local state = STATE_NORMAL
    local placeholderStart = nil
    local pos = 1
    local len = #formatStr

    while pos <= len do
        local char = formatStr:sub(pos, pos)
        local byte = string.byte(char)

        if state == STATE_NORMAL then
            if char == "%" then
                state = STATE_PERCENT
                placeholderStart = pos
            else
                result = result .. char
            end
        elseif state == STATE_PERCENT then
            if char == "%" then
                result = result .. "%"
                state = STATE_NORMAL
            elseif (byte >= 97 and byte <= 122) or (byte >= 48 and byte <= 57) then
                state = STATE_PLACEHOLDER
            else
                result = result .. "%"
                result = result .. char
                state = STATE_NORMAL
            end
        elseif state == STATE_PLACEHOLDER then
            if (byte >= 97 and byte <= 122) or (byte >= 48 and byte <= 57) then
            else
                local placeholder = formatStr:sub(placeholderStart + 1, pos - 1)
                local replacement = replacements[placeholder] or ""
                result = result .. replacement
                result = result .. char
                state = STATE_NORMAL
            end
        end
        pos = pos + 1
    end

    if state == STATE_PLACEHOLDER then
        local placeholder = formatStr:sub(placeholderStart + 1)
        local replacement = replacements[placeholder] or ""
        result = result .. replacement
    elseif state == STATE_PERCENT then
        result = result .. "%"
    end

    result = result:gsub("\\n", "\n")

    return result
end

function DT:CompareValue(value, operator, target)
    if operator == "==" then
        return value == target
    elseif operator == ">" then
        return value > target
    elseif operator == "<" then
        return value < target
    elseif operator == ">=" then
        return value >= target
    elseif operator == "<=" then
        return value <= target
    end
    return false
end

function DT:CheckRemainingTime(config, remaining)
    if not config.remainingEnabled then return true end
    local target = config.remainingValue or 5
    local operator = config.remainingOperator or "<="
    return self:CompareValue(remaining, operator, target)
end

function DT:CheckMessage(trigger, text)
    if not trigger.message or trigger.message == "" then return true end
    if not text then return false end

    if issecretvalue and issecretvalue(text) then return false end
    if issecretvalue and issecretvalue(trigger.message) then return false end

    local operator = trigger.messageOperator or "find"
    if operator == "==" then
        return text == trigger.message
    elseif operator == "find" then
        return text:find(trigger.message, 1, true) ~= nil
    elseif operator == "match" then
        local ok, result = pcall(function() return text:match(trigger.message) end)
        return ok and result ~= nil
    end
    return false
end

function DT:CheckCount(trigger, count)
    if not trigger.countEnabled then return true end
    local target = trigger.countValue or 0
    local operator = trigger.countOperator or "=="
    local countNum = tonumber(count) or 0
    return self:CompareValue(countNum, operator, target)
end

function DT:MatchesTrigger(trigger, barData)
    if not CheckLoadConditions(trigger, barData.isPreview) then return false end
    if trigger.excludeCastBars and barData.isCastBar then return false end
    if trigger.spellId and trigger.spellId ~= "" and tostring(barData.spellId) ~= tostring(trigger.spellId) then return false end
    if not self:CheckMessage(trigger, barData.text) then return false end
    if not self:CheckCount(trigger, barData.count) then return false end
    return true
end

function DT:CreateBarFrame(dungeonKey, triggerId, trigger)
    local config = self:GetTriggerConfig(trigger)
    local frameKey = dungeonKey .. "_" .. triggerId
    local frameName = "NorskenUI_DungeonTimer_" .. frameKey
    local showIcon = config.iconEnabled
    local iconSize = showIcon and config.barHeight or 0

    local group = self:GetBarGroupFrame()
    local frame = CreateFrame("Frame", frameName, group, "BackdropTemplate")
    frame:SetSize(config.barWidth, config.barHeight)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    frame.barContainer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.barContainer:SetPoint("TOPLEFT", iconSize, 0)
    frame.barContainer:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.barContainer:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    frame.barContainer:SetBackdropColor(unpack(config.backgroundColor))
    frame.barContainer:SetBackdropBorderColor(0, 0, 0, 1)

    frame.bar = CreateFrame("StatusBar", nil, frame.barContainer)
    frame.bar:SetPoint("TOPLEFT", 1, -1)
    frame.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.bar:SetStatusBarTexture(NRSKNUI:GetStatusbar(config.displaySettings))
    frame.bar:SetStatusBarColor(unpack(config.barColor))
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(1)

    if showIcon then
        frame.iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        frame.iconFrame:SetSize(config.barHeight, config.barHeight)
        frame.iconFrame:SetPoint("LEFT", frame, "LEFT", 0, 0)
        frame.iconFrame:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        frame.iconFrame:SetBackdropBorderColor(0, 0, 0, 1)

        frame.iconFrame.bg = frame.iconFrame:CreateTexture(nil, "BACKGROUND")
        frame.iconFrame.bg:SetAllPoints()
        frame.iconFrame.bg:SetColorTexture(0, 0, 0, 1)

        frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
        frame.icon:SetPoint("TOPLEFT", 1, -1)
        frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        frame.icon:SetZoom()
    end

    local FontSize = config.FontSize
    local FontOutline = config.FontOutline
    local FontShadow = config.FontShadow

    frame.text1 = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.text1:SetPoint(config.barText1Justify, frame.bar, config.barText1Justify,
        config.barText1XOffset, config.barText1YOffset)
    frame.text1:SetFontStyle(config.displaySettings, FontSize, FontOutline, FontShadow)
    frame.text1:SetTextColor(unpack(config.textColor))

    frame.text2 = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.text2:SetPoint(config.barText2Justify, frame.bar, config.barText2Justify,
        config.barText2XOffset, config.barText2YOffset)
    frame.text2:SetFontStyle(config.displaySettings, FontSize, FontOutline, FontShadow)
    frame.text2:SetTextColor(unpack(config.textColor))

    frame.config = config
    frame.dungeonKey = dungeonKey
    frame.triggerId = triggerId
    frame.showIcon = showIcon
    frame.isBarDisplay = true

    return frame
end

function DT:CreateTextFrame(dungeonKey, triggerId, trigger)
    local config = self:GetTriggerConfig(trigger)
    local frameKey = dungeonKey .. "_" .. triggerId
    local frameName = "NorskenUI_DungeonText_" .. frameKey
    local FontSize = config.FontSize

    local group = self:GetTextGroupFrame()
    local frame = CreateFrame("Frame", frameName, group)
    frame:SetSize(config.barWidth, FontSize + 4)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    local FontOutline = config.FontOutline
    local FontShadow = config.FontShadow

    frame.displayText = frame:CreateFontString(nil, "OVERLAY")
    frame.displayText:SetPoint(config.textJustify, frame, config.textJustify, 0, 0)
    frame.displayText:SetFontStyle(config.displaySettings, FontSize, FontOutline, FontShadow)
    frame.displayText:SetTextColor(unpack(config.textColor))

    frame.config = config
    frame.dungeonKey = dungeonKey
    frame.triggerId = triggerId
    frame.isBarDisplay = false

    return frame
end

function DT:GetTriggerFrame(dungeonKey, triggerId, trigger)
    local frameKey = dungeonKey .. "_" .. triggerId
    local frame = self.triggerFrames[frameKey]
    local config = self:GetTriggerConfig(trigger)
    local wantBar = config.displayType == "bar"

    if frame then
        local isBar = frame.isBarDisplay
        if (wantBar and not isBar) or (not wantBar and isBar) then
            frame:Hide()
            self.triggerFrames[frameKey] = nil
            self.triggerBars[frameKey] = nil
            frame = nil
        end
    end

    if not frame then
        if wantBar then
            frame = self:CreateBarFrame(dungeonKey, triggerId, trigger)
        else
            frame = self:CreateTextFrame(dungeonKey, triggerId, trigger)
        end
        if frame then self.triggerFrames[frameKey] = frame end
    end

    return frame
end

function DT:ApplyBarColors(frame, config, barData)
    if not frame.bar then return end

    local barColor = config.barColor
    local backgroundColor = config.backgroundColor
    local textColor = config.textColor

    if config.useBigWigsColors and barData.bwBarColor then barColor = barData.bwBarColor end
    if config.useBigWigsColors and barData.bwTextColor then textColor = barData.bwTextColor end

    if barColor and type(barColor) == "table" then
        frame.bar:SetStatusBarColor(barColor[1] or 1, barColor[2] or 1, barColor[3] or 1, barColor[4] or 1)
    end

    if backgroundColor and type(backgroundColor) == "table" and frame.barContainer then
        frame.barContainer:SetBackdropColor(unpack(config.backgroundColor))
    end

    if textColor and type(textColor) == "table" then
        local r, g, b, a = textColor[1] or 1, textColor[2] or 1, textColor[3] or 1, textColor[4] or 1
        if frame.text1 then frame.text1:SetTextColor(r, g, b, a) end
        if frame.text2 then frame.text2:SetTextColor(r, g, b, a) end
        if frame.displayText then frame.displayText:SetTextColor(r, g, b, a) end
    end
end

function DT:ShowTriggerDisplay(dungeonKey, triggerId, trigger, barData)
    local config = self:GetTriggerConfig(trigger)
    local frame = self:GetTriggerFrame(dungeonKey, triggerId, trigger)
    local frameKey = dungeonKey .. "_" .. triggerId

    if not frame then return end

    frame.config = config

    local now = GetTime()
    local effectiveDuration = config.remainingEnabled and config.remainingValue or barData.duration
    barData.effectiveDuration = effectiveDuration

    if frame.icon and barData.icon then frame.icon:SetTexture(barData.icon) end

    self:ApplyBarColors(frame, config, barData)

    local remaining = barData.expirationTime - now

    if frame.isBarDisplay then
        if frame.text1 then
            frame.text1:ClearAllPoints()
            frame.text1:SetPoint(config.barText1Justify, frame.bar, config.barText1Justify,
                config.barText1XOffset, config.barText1YOffset)
            frame.text1:SetText(self:FormatText(config.barText1Format, config, barData, remaining))
            if frame.text1._nrsknSoftOutline then frame.text1._nrsknSoftOutline:_ApplyOffsets() end
        end
        if frame.text2 then
            frame.text2:ClearAllPoints()
            frame.text2:SetPoint(config.barText2Justify, frame.bar, config.barText2Justify,
                config.barText2XOffset, config.barText2YOffset)
            frame.text2:SetText(self:FormatText(config.barText2Format, config, barData, remaining))
            if frame.text2._nrsknSoftOutline then frame.text2._nrsknSoftOutline:_ApplyOffsets() end
        end
    else
        if frame.displayText then
            frame.displayText:ClearAllPoints()
            frame.displayText:SetPoint(config.textJustify, frame, config.textJustify, 0, 0)
            frame.displayText:SetText(self:FormatText(config.textFormat, config, barData, remaining))
            if frame.displayText._nrsknSoftOutline then frame.displayText._nrsknSoftOutline:_ApplyOffsets() end
        end
    end

    if frame.bar then
        frame.bar:SetMinMaxValues(0, effectiveDuration)
        frame.bar:SetValue(math_min(remaining, effectiveDuration))
    end

    frame.barData = barData
    self.triggerBars[frameKey] = barData
    self:ScheduleNextExpire(barData.expirationTime)

    local shouldShowNow = true
    if config.remainingEnabled and not barData.isPreview then
        shouldShowNow = self:CheckRemainingTime(config, remaining)

        if not shouldShowNow and remaining > 0 then
            local remainingThreshold = config.remainingValue or 5
            local showTime = barData.expirationTime - remainingThreshold
            if showTime > now then self:ScheduleCheck(showTime) end
        end
    end

    if shouldShowNow then
        if not frame:IsShown() and not barData.isPreview then
            NRSKNUI:PlaySafeSound(config.actionOnShowSound)
        end
        frame:Show()
        self:PositionAllBars()
        self:PositionAllTexts()
        self:StartVisualUpdates()
    else
        frame:Hide()
        self:PositionAllBars()
        self:PositionAllTexts()
    end
end

function DT:HideTriggerDisplay(frameKey)
    local frame = self.triggerFrames[frameKey]
    if frame then
        if frame:IsShown() and frame.config and not (frame.barData and frame.barData.isPreview) then
            NRSKNUI:PlaySafeSound(frame.config.actionOnHideSound)
        end
        frame:Hide()
        frame.barData = nil
    end

    self.triggerBars[frameKey] = nil
    self.positionDirty = true

    if next(self.triggerBars) then
        self:PositionAllBars()
        self:PositionAllTexts()
        self.positionDirty = false
    else
        self:StopAllTimers()
    end
end

function DT:ProcessTimerTriggers(barData)
    if not self.db or not self.db.Dungeons then return end

    local dungeonKey = self.currentDungeonKey
    if not dungeonKey then return end

    local dungeonData = self.db.Dungeons[dungeonKey]
    if not dungeonData or not dungeonData.Enabled or not dungeonData.Triggers then return end

    for triggerId, trigger in pairs(dungeonData.Triggers) do
        if trigger.enabled ~= false and trigger.triggerType == "timer" then
            if self:MatchesTrigger(trigger, barData) then
                local adjustedBar = {}
                for k, v in pairs(barData) do adjustedBar[k] = v end
                adjustedBar.expirationTime = adjustedBar.expirationTime + (trigger.extendTimer or 0)
                adjustedBar.duration = adjustedBar.duration + (trigger.extendTimer or 0)
                self:ShowTriggerDisplay(dungeonKey, triggerId, trigger, adjustedBar)
            end
        end
    end
end

function DT:ProcessAnnounceTriggers(addon, spellId, text, icon)
    if not self.db or not self.db.Dungeons then return end

    local dungeonKey = self.currentDungeonKey
    if not dungeonKey then return end

    local dungeonData = self.db.Dungeons[dungeonKey]
    if not dungeonData or not dungeonData.Enabled or not dungeonData.Triggers then return end

    for triggerId, trigger in pairs(dungeonData.Triggers) do
        if trigger.enabled ~= false and trigger.triggerType == "announce" then
            local data = { spellId = tostring(spellId or ""), text = text, icon = icon }
            if self:MatchesTrigger(trigger, data) then
                local barData = {
                    text = text or "",
                    icon = icon,
                    duration = 3,
                    expirationTime = GetTime() + 3,
                    spellId = tostring(spellId or ""),
                }
                self:ShowTriggerDisplay(dungeonKey, triggerId, trigger, barData)
            end
        end
    end
end

function DT:StopBar(text)
    for frameKey, barData in pairs(self.triggerBars) do
        if barData and barData.text == text then self:HideTriggerDisplay(frameKey) end
    end
end

function DT:StopAllBars()
    for frameKey, _ in pairs(self.triggerBars) do
        local frame = self.triggerFrames[frameKey]
        if frame then
            frame:Hide()
            frame.barData = nil
        end
    end
    wipe(self.triggerBars)
    self:StopAllTimers()
end

function DT:PauseBar(text)
    local now = GetTime()
    for frameKey, barData in pairs(self.triggerBars) do
        if barData and barData.text == text and not barData.paused then
            barData.paused = true
            barData.pausedTime = now
            barData.remaining = barData.expirationTime - now
        end
    end

    if self.recheckTimer then
        self:CancelTimer(self.recheckTimer)
        self.recheckTimer = nil
    end
    self:RecheckTimers()
end

function DT:ResumeBar(text)
    local now = GetTime()
    local anyResumed = false

    for frameKey, barData in pairs(self.triggerBars) do
        if barData and barData.text == text and barData.paused then
            barData.expirationTime = now + (barData.remaining or 0)
            barData.paused = nil
            barData.pausedTime = nil
            barData.remaining = nil
            anyResumed = true

            self:ScheduleNextExpire(barData.expirationTime)

            local frame = self.triggerFrames[frameKey]
            if frame and frame.config and frame.config.remainingEnabled then
                local remainingThreshold = frame.config.remainingValue or 5
                local showTime = barData.expirationTime - remainingThreshold
                if showTime > now then
                    self:ScheduleCheck(showTime)
                end
            end
        end
    end

    if anyResumed then self:StartVisualUpdates() end
end

function DT:ScheduleCheck(fireTime)
    if not fireTime or fireTime <= GetTime() then return end
    if self.scheduledScans[fireTime] then return end

    local delay = fireTime - GetTime()
    if delay > 0 then self.scheduledScans[fireTime] = self:ScheduleTimer("DoScheduledScan", delay, fireTime) end
end

function DT:DoScheduledScan(fireTime)
    self.scheduledScans[fireTime] = nil

    local now = GetTime()
    local anyBecameVisible = false

    for frameKey, barData in pairs(self.triggerBars) do
        if barData and not barData.paused then
            local frame = self.triggerFrames[frameKey]
            if frame then
                local config = frame.config
                local remaining = barData.expirationTime - now

                if config.remainingEnabled and remaining > 0 then
                    local shouldShow = self:CheckRemainingTime(config, remaining)
                    if shouldShow and not frame:IsShown() then
                        if not barData.isPreview then
                            NRSKNUI:PlaySafeSound(config.actionOnShowSound)
                        end
                        frame:Show()
                        self.positionDirty = true
                        anyBecameVisible = true
                    end
                end
            end
        end
    end

    if self.positionDirty then
        self:PositionAllBars()
        self:PositionAllTexts()
        self.positionDirty = false
    end

    if anyBecameVisible then self:StartVisualUpdates() end
end

function DT:RecheckTimers()
    local now = GetTime()
    self.nextExpire = nil
    local callbacksToRun = {}

    for frameKey, barData in pairs(self.triggerBars) do
        if barData and not barData.paused then
            local expirationTime = barData.expirationTime

            if expirationTime <= now then
                if barData.isPreview and barData.loopCallback and self.previewsAllowed then
                    table_insert(callbacksToRun, barData.loopCallback)
                end
                self:HideTriggerDisplay(frameKey)
            else
                if self.nextExpire == nil or expirationTime < self.nextExpire then
                    self.nextExpire = expirationTime
                end
            end
        end
    end

    if self.nextExpire then
        local delay = self.nextExpire - now
        if delay > 0 then self.recheckTimer = self:ScheduleTimer("RecheckTimers", delay) end
    end

    for _, callback in ipairs(callbacksToRun) do callback() end
end

function DT:ScheduleNextExpire(expirationTime)
    local now = GetTime()

    if self.nextExpire == nil or expirationTime < self.nextExpire then
        if self.recheckTimer then self:CancelTimer(self.recheckTimer) end

        self.nextExpire = expirationTime
        local delay = expirationTime - now
        if delay > 0 then self.recheckTimer = self:ScheduleTimer("RecheckTimers", delay) end
    end
end

function DT:OnVisualUpdate()
    local now = GetTime()
    local anyVisible = false

    for frameKey, barData in pairs(self.triggerBars) do
        if barData then
            local frame = self.triggerFrames[frameKey]
            if frame and frame:IsShown() then
                anyVisible = true
                local remaining = barData.paused
                    and (barData.expirationTime - barData.pausedTime)
                    or (barData.expirationTime - now)

                if remaining > 0 then
                    local config = frame.config

                    if frame.bar then
                        local effectiveDuration = barData.effectiveDuration or barData.duration
                        frame.bar:SetValue(math_min(remaining, effectiveDuration))
                    end

                    if frame.isBarDisplay then
                        if frame.text1 then
                            frame.text1:SetText(self:FormatText(config.barText1Format, config, barData,
                                remaining))
                            if frame.text1._nrsknSoftOutline then
                                frame.text1._nrsknSoftOutline:_ApplyOffsets()
                            end
                        end
                        if frame.text2 then
                            frame.text2:SetText(self:FormatText(config.barText2Format, config, barData,
                                remaining))
                            if frame.text2._nrsknSoftOutline then
                                frame.text2._nrsknSoftOutline:_ApplyOffsets()
                            end
                        end
                    else
                        if frame.displayText then
                            frame.displayText:SetText(self:FormatText(config.textFormat, config, barData, remaining))
                            if frame.displayText._nrsknSoftOutline then
                                frame.displayText._nrsknSoftOutline:_ApplyOffsets()
                            end
                        end
                    end
                end
            end
        end
    end

    if not anyVisible then self:StopVisualUpdates() end
end

function DT:StartVisualUpdates()
    if not self.visualTicker then
        self.visualTicker = self:ScheduleRepeatingTimer("OnVisualUpdate", VISUAL_UPDATE_INTERVAL)
    end
end

function DT:StopVisualUpdates()
    if self.visualTicker then
        self:CancelTimer(self.visualTicker)
        self.visualTicker = nil
    end
end

function DT:CancelAllScheduledScans()
    for _, handle in pairs(self.scheduledScans) do self:CancelTimer(handle) end
    wipe(self.scheduledScans)
end

function DT:StopAllTimers()
    self:StopVisualUpdates()
    self:CancelAllScheduledScans()
    if self.recheckTimer then
        self:CancelTimer(self.recheckTimer)
        self.recheckTimer = nil
    end
    self.nextExpire = nil
end

function DT:OnEnable()
    self:UpdateDB()
    if not self.db or not self.db.Enabled then return end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateCurrentDungeon")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateCurrentDungeon")
    self:UpdateCurrentDungeon()

    if not self:RegisterBigWigsCallbacks() then
        self:RegisterEvent("ADDON_LOADED", function(_, addonName)
            if addonName == "BigWigs" or addonName == "BigWigs_Core" then
                self:RegisterBigWigsCallbacks()
            end
        end)
    end
end

function DT:OnDisable()
    self:UnregisterBigWigsCallbacks()
    self:StopAllBars()
    self:StopAllTimers()
    self:UnregisterAllEvents()
    self.currentDungeonKey = nil
    for _, frame in pairs(self.triggerFrames) do frame:Hide() end
end

function DT:ApplySettings()
    self:UpdateDB()
    if self.db and self.db.Enabled then
        if not self:IsEnabled() then
            NRSKNUI:EnableModule("DungeonTimers")
        else
            self:RegisterBigWigsCallbacks()
        end
    else
        if self:IsEnabled() then
            NRSKNUI:DisableModule("DungeonTimers")
        end
    end
end

function DT:UpdateFrameVisuals()
    self:UpdateDB()
    if not self.db then return end

    local barDisplay = self.db.BarDisplay
    local textDisplay = self.db.TextDisplay
    local texturePath = NRSKNUI:GetStatusbar(barDisplay)

    for _, frame in pairs(self.triggerFrames) do
        if frame and frame:IsShown() then
            if frame.isBarDisplay then
                local showIcon = barDisplay.iconEnabled
                local iconSize = showIcon and barDisplay.barHeight or 0

                frame:SetSize(barDisplay.barWidth, barDisplay.barHeight)

                if frame.barContainer then
                    frame.barContainer:ClearAllPoints()
                    frame.barContainer:SetPoint("TOPLEFT", iconSize, 0)
                    frame.barContainer:SetPoint("BOTTOMRIGHT", 0, 0)
                end

                if frame.bar then
                    frame.bar:SetStatusBarTexture(texturePath)
                end

                if frame.iconFrame then
                    frame.iconFrame:SetSize(barDisplay.barHeight, barDisplay.barHeight)
                    frame.iconFrame:SetShown(showIcon)
                end

                if frame.text1 then
                    frame.text1:SetFontStyle(barDisplay)
                end

                if frame.text2 then
                    frame.text2:SetFontStyle(barDisplay)
                end
            else
                local FontSize = textDisplay.FontSize or 14
                frame:SetSize(400, FontSize + 4)

                if frame.displayText then
                    frame.displayText:ClearAllPoints()
                    frame.displayText:SetJustifyH(textDisplay.textAlign or "LEFT")
                    frame.displayText:SetPoint(textDisplay.textAlign or "LEFT", frame, textDisplay.textAlign or "LEFT", 0,
                        0)
                    frame.displayText:SetFontStyle(textDisplay, FontSize)
                end
            end
        end
    end

    self:PositionAllBars()
    self:PositionAllTexts()
end

function DT:Refresh()
    self:StopAllTimers()

    for _, frame in pairs(self.triggerFrames) do frame:Hide() end
    wipe(self.triggerFrames)
    wipe(self.triggerBars)

    if self.barGroupFrame then
        self.barGroupFrame:Hide()
        self.barGroupFrame = nil
    end
    if self.textGroupFrame then
        self.textGroupFrame:Hide()
        self.textGroupFrame = nil
    end
end

function DT:DeleteTrigger(dungeonKey, triggerId)
    if not self.db or not self.db.Dungeons then return end
    local dungeonData = self.db.Dungeons[dungeonKey]
    if not dungeonData or not dungeonData.Triggers then return end

    local frameKey = dungeonKey .. "_" .. triggerId
    self:HideTriggerDisplay(frameKey)
    if self.triggerFrames[frameKey] then
        self.triggerFrames[frameKey]:Hide()
        self.triggerFrames[frameKey] = nil
    end

    dungeonData.Triggers[triggerId] = nil
end

function DT:DuplicateTrigger(dungeonKey, triggerId)
    if not self.db or not self.db.Dungeons then return nil end
    local dungeonData = self.db.Dungeons[dungeonKey]
    if not dungeonData or not dungeonData.Triggers then return nil end

    local source = dungeonData.Triggers[triggerId]
    if not source then return nil end

    local newId = self:CreateTrigger(dungeonKey)
    if not newId then return nil end

    local target = dungeonData.Triggers[newId]
    for k, v in pairs(source) do
        if k ~= "id" then
            if type(v) == "table" then
                target[k] = {}
                for k2, v2 in pairs(v) do target[k][k2] = v2 end
            else
                target[k] = v
            end
        end
    end
    target.name = (source.name or "Timer") .. " (Copy)"

    return newId
end

function DT:GetSortedTriggerIds(dungeonKey)
    if not self.db or not self.db.Dungeons then return {} end
    local dungeonData = self.db.Dungeons[dungeonKey]
    if not dungeonData or not dungeonData.Triggers then return {} end

    local ids = {}
    for id in pairs(dungeonData.Triggers) do table.insert(ids, id) end
    table.sort(ids, function(a, b) return tonumber(a) < tonumber(b) end)
    return ids
end

function DT:MoveTrigger(dungeonKey, triggerId, direction)
    if not self.db or not self.db.Dungeons then return false end
    local dungeonData = self.db.Dungeons[dungeonKey]
    if not dungeonData or not dungeonData.Triggers then return false end

    local sortedIds = self:GetSortedTriggerIds(dungeonKey)
    local currentIndex
    for i, id in ipairs(sortedIds) do
        if id == triggerId then
            currentIndex = i
            break
        end
    end

    local targetIndex = direction == "up" and currentIndex - 1 or currentIndex + 1
    if not currentIndex or targetIndex < 1 or targetIndex > #sortedIds then return false end

    local targetId = sortedIds[targetIndex]
    local currentData = dungeonData.Triggers[triggerId]
    local targetData = dungeonData.Triggers[targetId]

    dungeonData.Triggers[triggerId] = targetData
    dungeonData.Triggers[targetId] = currentData
    dungeonData.Triggers[triggerId].id = triggerId
    dungeonData.Triggers[targetId].id = targetId

    local frameKey1 = dungeonKey .. "_" .. triggerId
    local frameKey2 = dungeonKey .. "_" .. targetId
    if self.triggerFrames[frameKey1] then
        self.triggerFrames[frameKey1]:Hide()
        self.triggerFrames[frameKey1] = nil
    end
    if self.triggerFrames[frameKey2] then
        self.triggerFrames[frameKey2]:Hide()
        self.triggerFrames[frameKey2] = nil
    end

    return targetId
end

function DT:PreviewTrigger(dungeonKey, triggerId, loopCallback)
    if not self.previewsAllowed then return end

    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return end

    local dungeonData = self.db.Dungeons[dungeonKey]
    if not dungeonData or not dungeonData.Triggers then return end

    local trigger = dungeonData.Triggers[triggerId]
    if not trigger then return end

    local config = self:GetTriggerConfig(trigger)

    local frameKey = dungeonKey .. "_" .. triggerId
    if self.triggerFrames[frameKey] then
        self.triggerFrames[frameKey]:Hide()
        self.triggerFrames[frameKey] = nil
    end

    local icon = 136116
    local spellName
    local spellIdNum = tonumber(config.spellId)
    if spellIdNum and spellIdNum > 0 then
        local spellInfo = C_Spell.GetSpellInfo(spellIdNum)
        if spellInfo then
            if spellInfo.iconID then icon = spellInfo.iconID end
            spellName = spellInfo.name
        end
    end

    local bwBarColor, bwTextColor, bwBgColor
    if config.useBigWigsColors and spellIdNum then
        bwBarColor, bwTextColor, bwBgColor = self:GetBigWigsColors(nil, spellIdNum)
    end

    local duration = config.remainingEnabled and (config.remainingValue or 5) or 20

    local individualLoopCallback = function()
        if self.previewsAllowed then
            self:PreviewTrigger(dungeonKey, triggerId)
        end
    end

    local barData = {
        text = config.name or "Preview",
        icon = icon,
        duration = duration,
        effectiveDuration = duration,
        expirationTime = GetTime() + duration,
        spellId = config.spellId or "",
        count = 0,
        isPreview = true,
        loopCallback = individualLoopCallback,
        bwBarColor = bwBarColor,
        bwTextColor = bwTextColor,
        bwBgColor = bwBgColor,
        spellName = spellName,
    }

    self:ShowTriggerDisplay(dungeonKey, triggerId, trigger, barData)
end

function DT:PreviewDungeon(dungeonKey, loopCallback)
    if not self.previewsAllowed then return end

    self:UpdateDB()
    if not self.db or not self.db.Dungeons then return end

    local dungeonData = self.db.Dungeons[dungeonKey]
    if not dungeonData or not dungeonData.Triggers then return end

    for frameKey, frame in pairs(self.triggerFrames) do
        if frame.dungeonKey == dungeonKey then
            frame:Hide()
            self.triggerBars[frameKey] = nil
        end
    end

    for triggerId, trigger in pairs(dungeonData.Triggers) do
        if trigger.enabled ~= false then
            self:PreviewTrigger(dungeonKey, triggerId)
        end
    end

    self:PositionAllBars()
    self:PositionAllTexts()
end

function DT:HideAll()
    for _, frame in pairs(self.triggerFrames) do
        frame:Hide()
        frame.barData = nil
    end
    wipe(self.triggerBars)
    self:StopAllTimers()
end

function DT:HideAllPreviews()
    local hasRemainingFrames = false
    for frameKey, barData in pairs(self.triggerBars) do
        if barData and barData.isPreview then
            local frame = self.triggerFrames[frameKey]
            if frame then
                frame:Hide()
                frame.barData = nil
            end
            self.triggerBars[frameKey] = nil
        elseif barData then
            hasRemainingFrames = true
        end
    end

    if hasRemainingFrames then
        self:PositionAllBars()
        self:PositionAllTexts()
    else
        self:StopAllTimers()
    end
end

function DT:EnablePreviews()
    self.previewsAllowed = true
end

function DT:DisablePreviews()
    self.previewsAllowed = false
    self:HideAllPreviews()
end

local SETTINGS_BAR_PREVIEWS = {
    { name = "Tank Hit", duration = 20, icon = 136116, color = { 0.2, 0.6, 1.0 } },
    { name = "Soak",     duration = 10, icon = 135994, color = { 1.0, 0.5, 0.0 } },
    { name = "Frontal",  duration = 5,  icon = 132155, color = { 1.0, 0.2, 0.2 } },
}

local SETTINGS_TEXT_PREVIEWS = {
    { name = "ADDS", duration = 20, icon = 136116, color = { 1.0, 0.5, 0.2 } },
    { name = "HEAL", duration = 10, icon = 135915, color = { 0.4, 0.8, 1.0 } },
    { name = "KICK", duration = 5,  icon = 132219, color = { 0.9, 0.3, 0.9 } },
}

function DT:ShowSettingsBarPreview(index)
    local data = SETTINGS_BAR_PREVIEWS[index]
    if not data then return end

    local trigger = {
        displayType = "bar",
        name = data.name,
        barColor = data.color,
        textColor = { 1, 1, 1, 1 },
        backgroundColor = { 0, 0, 0, 0.8 },
        barText1Format = "%n",
        barText2Format = "%p",
    }

    local barData = {
        text = data.name,
        icon = data.icon,
        duration = data.duration,
        effectiveDuration = data.duration,
        expirationTime = GetTime() + data.duration,
        count = 0,
        isPreview = true,
        isSettingsPreview = true,
        loopCallback = function() if self.previewsAllowed then self:ShowSettingsBarPreview(index) end end,
    }

    self:ShowTriggerDisplay("_settings", "bar_" .. index, trigger, barData)
end

function DT:ShowSettingsBarPreviews()
    self:HideSettingsBarPreviews()
    self:UpdateDB()
    if not self.db then return end

    self.previewsAllowed = true

    for i = 1, #SETTINGS_BAR_PREVIEWS do self:ShowSettingsBarPreview(i) end
end

function DT:HideSettingsBarPreviews()
    for i = 1, #SETTINGS_BAR_PREVIEWS do
        local frameKey = "_settings_bar_" .. i
        if self.triggerFrames[frameKey] then self:HideTriggerDisplay(frameKey) end
    end
end

function DT:ShowSettingsTextPreview(index)
    local data = SETTINGS_TEXT_PREVIEWS[index]
    if not data then return end

    local trigger = {
        displayType = "text",
        name = data.name,
        textColor = data.color,
        textFormat = "%n » %p",
    }

    local barData = {
        text = data.name,
        icon = data.icon,
        duration = data.duration,
        effectiveDuration = data.duration,
        expirationTime = GetTime() + data.duration,
        isPreview = true,
        isSettingsPreview = true,
        loopCallback = function() if self.previewsAllowed then self:ShowSettingsTextPreview(index) end end,
    }

    self:ShowTriggerDisplay("_settings", "text_" .. index, trigger, barData)
end

function DT:ShowSettingsTextPreviews()
    self:HideSettingsTextPreviews()
    self:UpdateDB()
    if not self.db then return end

    self.previewsAllowed = true

    for i = 1, #SETTINGS_TEXT_PREVIEWS do self:ShowSettingsTextPreview(i) end
end

function DT:HideSettingsTextPreviews()
    for i = 1, #SETTINGS_TEXT_PREVIEWS do
        local frameKey = "_settings_text_" .. i
        if self.triggerFrames[frameKey] then self:HideTriggerDisplay(frameKey) end
    end
end

function DT:RefreshSettingsBarPreviews()
    local GUIFrame = NRSKNUI.GUIFrame
    if not GUIFrame or not GUIFrame:IsShown() or GUIFrame.selectedSidebarItem ~= "DT_Bars" then
        return
    end

    local hasAny = false
    for i = 1, #SETTINGS_BAR_PREVIEWS do
        if self.triggerFrames["_settings_bar_" .. i] then
            hasAny = true
            break
        end
    end

    if not hasAny then
        self:ShowSettingsBarPreviews()
        return
    end

    self:UpdateFrameVisuals()
end

function DT:RefreshSettingsTextPreviews()
    local GUIFrame = NRSKNUI.GUIFrame
    if not GUIFrame or not GUIFrame:IsShown() or GUIFrame.selectedSidebarItem ~= "DT_Texts" then
        return
    end

    local hasAny = false
    for i = 1, #SETTINGS_TEXT_PREVIEWS do
        if self.triggerFrames["_settings_text_" .. i] then
            hasAny = true
            break
        end
    end

    if not hasAny then
        self:ShowSettingsTextPreviews()
        return
    end

    self:UpdateFrameVisuals()
end
