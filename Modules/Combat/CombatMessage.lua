---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class CombatMessage: AceModule, AceEvent-3.0
local CM = NRSKNUI:NewModule("CombatMessage", "AceEvent-3.0")

local CreateFrame = CreateFrame
local UnitExists, UnitIsDead, UnitIsDeadOrGhost = UnitExists, UnitIsDead, UnitIsDeadOrGhost
local InCombatLockdown = InCombatLockdown
local ipairs, pairs = ipairs, pairs
local UnitInParty, UnitInRaid = UnitInParty, UnitInRaid
local IsInRaid, IsInGroup, GetNumGroupMembers = IsInRaid, IsInGroup, GetNumGroupMembers
local UnitClass, UnitIsUnit = UnitClass, UnitIsUnit
local UnitTokenFromGUID, UnitGUID = UnitTokenFromGUID, UnitGUID
local C_ClassColor = C_ClassColor
local C_Timer = C_Timer
local GetTime = GetTime
local max = math.max
local gsub = string.gsub

CM.messageFrames = {}

local function ProcessRaidTargetIcons(text)
    if not text then return text end
    return gsub(text, "{rt(%d)}", function(num)
        return "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_" .. num .. ":0|t"
    end)
end
CM.activeMessages = {}

local MESSAGE_TYPES = {
    "enterCombat",
    "exitCombat",
    "noTarget",
    "partyDeath",
    "focusDeath",
}

local function GetUnitFromGUID(guid)
    if not guid then return nil end
    if NRSKNUI:IsSecretValue(guid) then return nil end

    if UnitTokenFromGUID then
        local token = UnitTokenFromGUID(guid)
        if token then return token end
    end

    if UnitGUID("player") == guid then return "player" end

    if IsInRaid() then
        for i = 1, 40 do
            local u = "raid" .. i
            if UnitGUID(u) == guid then return u end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local u = "party" .. i
            if UnitGUID(u) == guid then return u end
        end
    end

    return nil
end

local GROW_ANCHORS = {
    DOWN = { childPoint = "TOP", containerAnchor = "TOP", yDir = -1 },
    UP = { childPoint = "BOTTOM", containerAnchor = "BOTTOM", yDir = 1 },
}

local function IsLoadConditionMet(loadCondition)
    if not loadCondition or loadCondition == "ALWAYS" then return true end
    local groupSize = GetNumGroupMembers()
    local inRaid = IsInRaid()
    local inGroup = groupSize > 0

    if loadCondition == "ANYGROUP" then
        return inGroup
    elseif loadCondition == "PARTY" then
        return inGroup and not inRaid
    elseif loadCondition == "RAID" then
        return inRaid
    elseif loadCondition == "NOGROUP" then
        return not inGroup
    end

    return true
end

local function FormatDeathMessage(format, name, nameColor, textColor)
    local textHex = NRSKNUI:RGBAToHex(textColor[1], textColor[2], textColor[3])
    local textStart = "|cFF" .. textHex
    local textEnd = "|r"

    local coloredName
    if nameColor.WrapTextInColorCode then
        coloredName = nameColor:WrapTextInColorCode(name)
    else
        local nameHex = NRSKNUI:RGBAToHex(nameColor[1], nameColor[2], nameColor[3])
        coloredName = "|cFF" .. nameHex .. name .. "|r"
    end

    local before, after = format:match("^(.-)%%name(.*)$")
    if before then
        return textStart .. before .. textEnd .. coloredName .. textStart .. after .. textEnd
    else
        return textStart .. format .. textEnd
    end
end

function CM:UpdateDB()
    self.db = NRSKNUI.db.profile.CombatMessage
end

function CM:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

local function GetDbKey(msgType)
    return msgType and (msgType:sub(1, 1):upper() .. msgType:sub(2))
end

local function GetMessageConfig(db, msgType)
    local key = GetDbKey(msgType)
    local cfg = key and db[key]
    if not cfg then return false, "", { 1, 1, 1, 1 } end
    return cfg.Enabled, cfg.Text or "", cfg.Color or { 1, 1, 1, 1 }
end

local function FormatPartyDeathMessage(db, unitID, fallbackName)
    local name = NRSKNUI:GetSafeUnitName(unitID) or fallbackName
    if not name then return nil end

    local _, classFilename = UnitClass(unitID)

    local nameColor = { 1, 1, 1, 1 }
    if db.PartyDeath.UseClassColor and classFilename and not NRSKNUI:IsSecretValue(classFilename) then
        local classColor = C_ClassColor.GetClassColor(classFilename)
        if classColor then nameColor = classColor end
    end

    local format = db.PartyDeath.TextFormat or "%name DIED"
    return FormatDeathMessage(format, name, nameColor, db.PartyDeath.TextColor)
end

function CM:ApplyContainerPosition()
    if not self.container then return end

    local grow = GROW_ANCHORS[self.db.Grow] or GROW_ANCHORS.DOWN
    local parent = NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)

    self.container:ClearAllPoints()
    self.container:SetPoint(
        grow.containerAnchor,
        parent,
        self.db.Position.AnchorTo or "CENTER",
        self.db.Position.XOffset or 0,
        self.db.Position.YOffset or 0
    )
    self.container:SetFrameStrata(self.db.Strata or "HIGH")
end

function CM:CreateContainer()
    if self.container then return end

    local container = CreateFrame("Frame", "NRSKNUI_CombatMessageContainer", UIParent)
    container:SetSize(100, 20)
    container:SetFrameLevel(100)

    self.container = container

    -- Coalesced one-shot layout, arm with container:ScheduleUpdate(), auto-disarms after firing.
    container:SetScheduledUpdate(function() self:ArrangeMessages() end)

    self:ApplyContainerPosition()
end

function CM:GetMessageFrame(msgType)
    if self.messageFrames[msgType] then return self.messageFrames[msgType] end

    local frame = CreateFrame("Frame", nil, self.container)
    frame:SetSize(200, 20)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER")
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")

    frame.text = text
    frame.msgType = msgType
    frame.generation = 0
    frame.width = 200
    frame.height = 20

    self.messageFrames[msgType] = frame
    self:UpdateFrameFont(frame, msgType)

    return frame
end

function CM:UpdateFrameFont(frame, msgType)
    local key = GetDbKey(msgType)
    local fontSize = (key and self.db[key] and self.db[key].FontSize) or self.db.FontSize
    frame.text:SetFontStyle(self.db, fontSize)
end

function CM:SetMessageContent(frame, msgText, color, msgType)
    if msgType then
        self:UpdateFrameFont(frame, msgType)
    end
    frame.text:SetText("")
    frame.text:SetText(ProcessRaidTargetIcons(msgText))
    frame.text:SetTextColor(color[1], color[2], color[3], color[4])

    if frame.text._nrsknSoftOutline then
        frame.text._nrsknSoftOutline:_ApplyOffsets()
    end

    local textWidth = frame.text:GetStringWidth()
    local textHeight = frame.text:GetStringHeight()

    local width = max(textWidth + 10, 100)
    local height = max(textHeight, 12)
    frame.width = width
    frame.height = height
    frame:SetSize(width, height)
end

function CM:ArrangeMessages()
    if not self.container then return end

    local grow = GROW_ANCHORS[self.db.Grow] or GROW_ANCHORS.DOWN
    local spacing = self.db.Spacing
    local yDir = grow.yDir

    local visibleFrames = {}
    for _, msgType in ipairs(MESSAGE_TYPES) do
        local frame = self.messageFrames[msgType]
        if frame and frame:IsShown() then
            visibleFrames[#visibleFrames + 1] = frame
        end
    end

    local yOffset = 0
    local maxWidth = 0
    local totalHeight = 0

    for i, frame in ipairs(visibleFrames) do
        frame:ClearAllPoints()
        frame:SetPoint(grow.childPoint, self.container, grow.containerAnchor, 0, yOffset * yDir)
        yOffset = yOffset + frame.height + spacing

        if frame.width > maxWidth then maxWidth = frame.width end
        totalHeight = totalHeight + frame.height
        if i < #visibleFrames then totalHeight = totalHeight + spacing end
    end

    if #visibleFrames > 0 then
        self.container:SetSize(max(maxWidth, 100), totalHeight)
    else
        self.container:SetSize(100, 20)
    end
end


function CM:ShowFlashMessage(msgType, customText, customColor)
    if not self.db.Enabled then return end
    if self.isPreview then return end

    local enabled, msgText, color = GetMessageConfig(self.db, msgType)
    if not enabled then return end

    local frame = self:GetMessageFrame(msgType)
    if not frame then return end

    frame.generation = frame.generation + 1
    local myGeneration = frame.generation

    self:SetMessageContent(frame, customText or msgText, customColor or color, msgType)

    frame:SetAlpha(1)
    frame:Show()
    self.activeMessages[msgType] = true
    self:ArrangeMessages()

    C_Timer.After(self.db.Duration, function()
        if frame.generation == myGeneration and not self.isPreview then
            frame:Hide()
            self.activeMessages[msgType] = nil
            self:ArrangeMessages()
        end
    end)
end

function CM:ShowPersistentMessage(msgType)
    if not self.db.Enabled then return end
    if self.isPreview then return end

    local enabled, msgText, color = GetMessageConfig(self.db, msgType)
    if not enabled then return end

    local frame = self:GetMessageFrame(msgType)
    if not frame then return end

    self:SetMessageContent(frame, msgText, color, msgType)

    frame:SetAlpha(1)
    frame:Show()
    self.activeMessages[msgType] = true
    self:ArrangeMessages()
end

function CM:HidePersistentMessage(msgType)
    local frame = self.messageFrames[msgType]
    if frame then
        frame:Hide()
        self.activeMessages[msgType] = nil
        self:ArrangeMessages()
    end
end

function CM:CheckNoTarget()
    if not self.db.Enabled then return end
    if self.isPreview then return end

    local noTargetEnabled = self.db.NoTarget.Enabled

    if UnitIsDeadOrGhost("player") then
        self:HidePersistentMessage("noTarget")
        return
    end

    if self.inCombat and noTargetEnabled then
        self.noTargetCheckGeneration = (self.noTargetCheckGeneration or 0) + 1
        local myGeneration = self.noTargetCheckGeneration

        C_Timer.After(0.1, function()
            if self.noTargetCheckGeneration ~= myGeneration then return end
            if not self.inCombat then return end
            if UnitIsDeadOrGhost("player") then
                self:HidePersistentMessage("noTarget")
                return
            end
            if not UnitExists("target") then
                self:ShowPersistentMessage("noTarget")
            else
                self:HidePersistentMessage("noTarget")
            end
        end)
    else
        self:HidePersistentMessage("noTarget")
    end
end

function CM:CheckFocusDeath(deadGUID)
    if not self.db.FocusDeath.Enabled then return end

    local focusGUID = UnitGUID("focus")
    if not focusGUID then return end
    if NRSKNUI:IsSecretValue(focusGUID) then return end
    if NRSKNUI:IsSecretValue(deadGUID) then return end
    if focusGUID ~= deadGUID then return end

    self:ShowFlashMessage("focusDeath")
end

function CM:OnUnitDied(_, deadGUID)
    if not self.db.Enabled then return end
    if self.isPreview then return end

    self:CheckFocusDeath(deadGUID)

    if not self.db.PartyDeath.Enabled then return end
    if not IsLoadConditionMet(self.db.PartyDeath.LoadCondition) then return end
    if self.db.PartyDeath.CombatOnly and not self.inCombat then return end

    local now = GetTime()
    if now > self.deathThrottle.resetTime then
        self.deathThrottle.count = 0
        self.deathThrottle.resetTime = now + 10
    end

    if self.deathThrottle.count >= 4 then return end

    local unitID = GetUnitFromGUID(deadGUID)
    if not unitID then return end
    if NRSKNUI:IsSecretValue(unitID) then return end
    if UnitIsUnit(unitID, "player") then return end

    local isDead = UnitIsDead(unitID)
    if NRSKNUI:IsSecretValue(isDead) then isDead = true end
    if not isDead then return end

    if not UnitInParty(unitID) and not UnitInRaid(unitID) then return end

    self.deathThrottle.count = self.deathThrottle.count + 1

    local msgText = FormatPartyDeathMessage(self.db, unitID)
    if not msgText then return end

    self:ShowFlashMessage("partyDeath", msgText, { 1, 1, 1, 1 })
end

function CM:ApplySettings()
    if not self.container then return end
    self:ApplyContainerPosition()

    for msgType, frame in pairs(self.messageFrames) do self:UpdateFrameFont(frame, msgType) end

    if self.isPreview then
        self:UpdatePreview()
    else
        for _, msgType in ipairs(MESSAGE_TYPES) do
            local frame = self.messageFrames[msgType]
            if frame and frame:IsShown() then
                local _, msgText, msgColor = GetMessageConfig(self.db, msgType)
                self:SetMessageContent(frame, msgText, msgColor, msgType)
            end
        end

        self.container:ScheduleUpdate()
        self:CheckNoTarget()
    end
end

function CM:ShowPreview()
    if not self.container then self:CreateContainer() end

    self.isPreview = true
    self:UpdatePreview()
end

function CM:UpdatePreview()
    if not self.isPreview then return end

    for _, msgType in ipairs(MESSAGE_TYPES) do
        local frame = self:GetMessageFrame(msgType)
        if frame then
            local enabled, msgText, msgColor = GetMessageConfig(self.db, msgType)

            if msgType == "partyDeath" and enabled then
                msgText = FormatPartyDeathMessage(self.db, "player", "Player")
                msgColor = { 1, 1, 1, 1 }
            end

            if enabled then
                self:SetMessageContent(frame, msgText, msgColor, msgType)
                frame:SetAlpha(1)
                frame:Show()
                self.activeMessages[msgType] = true
            else
                frame:Hide()
                self.activeMessages[msgType] = nil
            end
        end
    end
    self.container:ScheduleUpdate()
end

function CM:HidePreview()
    if not self.isPreview then return end

    self.isPreview = false

    for msgType, frame in pairs(self.messageFrames) do
        frame:Hide()
        self.activeMessages[msgType] = nil
    end

    self:ArrangeMessages()

    if self.inCombat then self:CheckNoTarget() end
end

function CM:OnEnable()
    if not self.db.Enabled then return end

    self.inCombat = false
    self.isPreview = false
    self.noTargetCheckGeneration = 0
    self.deathThrottle = { count = 0, resetTime = 0 }

    self:CreateContainer()

    for _, msgType in ipairs(MESSAGE_TYPES) do self:GetMessageFrame(msgType) end

    C_Timer.After(0.5, function() self:ApplySettings() end)

    self:RegisterEvent("PLAYER_REGEN_DISABLED", function()
        self.inCombat = true
        self:ShowFlashMessage("enterCombat")
        self:CheckNoTarget()
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        self.inCombat = false
        self.noTargetCheckGeneration = (self.noTargetCheckGeneration or 0) + 1
        self:HidePersistentMessage("noTarget")
        self:ShowFlashMessage("exitCombat")
    end)
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "CheckNoTarget")
    self:RegisterEvent("PLAYER_DEAD", function()
        self.noTargetCheckGeneration = (self.noTargetCheckGeneration or 0) + 1
        self:HidePersistentMessage("noTarget")
    end)
    self:RegisterEvent("UNIT_DIED", "OnUnitDied")

    self.inCombat = InCombatLockdown()
    if self.inCombat then self:CheckNoTarget() end

    NRSKNUI.EditMode:RegisterElement({
        key = "CombatMessages",
        displayName = "Combat Messages",
        frame = self.container,
        getPosition = function()
            local grow = GROW_ANCHORS[self.db.Grow] or GROW_ANCHORS.DOWN
            return {
                AnchorFrom = grow.containerAnchor,
                AnchorTo = self.db.Position.AnchorTo,
                XOffset = self.db.Position.XOffset,
                YOffset = self.db.Position.YOffset,
            }
        end,
        setPosition = function(pos)
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            self:ApplyContainerPosition()
        end,
        getParentFrame = function()
            return NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
        end,
        guiPath = "combatMessage",
    })
end

function CM:OnDisable()
    for _, frame in pairs(self.messageFrames) do frame:Hide() end
    self.activeMessages = {}
    self.isPreview = false
    self.inCombat = false
    self.noTargetCheckGeneration = 0
    self:UnregisterAllEvents()
end
