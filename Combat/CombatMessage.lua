-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("CombatMessage: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local CM = NRSKNUI.Addon:NewModule("CombatMessage", "AceEvent-3.0")

-- Localization
local CreateFrame = CreateFrame
local UIFrameFadeRemoveFrame = UIFrameFadeRemoveFrame
local UIFrameFadeOut = UIFrameFadeOut
local UnitExists = UnitExists
local InCombatLockdown = InCombatLockdown
local ipairs, pairs = ipairs, pairs
local UIParent = UIParent
local C_Timer = C_Timer

-- Module state
CM.container = nil
CM.messageFrames = {}
CM.activeMessages = {}
CM.messageGeneration = 0
CM.isPreview = false
CM.inCombat = false

-- Module init bruv
function CM:OnInitialize()
    self.db = NRSKNUI.db.profile.CombatMessage
    self:SetEnabledState(false)
end

-- Message types
local MESSAGE_TYPES = {
    "enterCombat",
    "exitCombat",
    "noTarget",
}

-- Get message config
local function GetMessageConfig(db, msgType)
    if msgType == "enterCombat" then
        local cfg = db.EnterCombat or {}
        return cfg.Enabled ~= false,
            cfg.Text or "+ COMBAT +",
            cfg.Color or { 0.929, 0.259, 0, 1 }
    elseif msgType == "exitCombat" then
        local cfg = db.ExitCombat or {}
        return cfg.Enabled ~= false,
            cfg.Text or "- COMBAT -",
            cfg.Color or { 0.788, 1, 0.627, 1 }
    elseif msgType == "noTarget" then
        local cfg = db.NoTarget or {}
        return cfg.Enabled == true,
            cfg.Text or "NO TARGET",
            cfg.Color or { 1, 0.8, 0, 1 }
    end
    return false, "", { 1, 1, 1, 1 }
end

-- Create container frame
function CM:CreateContainer()
    if self.container then return end

    local db = self.db
    local parent = NRSKNUI:ResolveAnchorFrame(db.anchorFrameType, db.ParentFrame)

    local container = CreateFrame("Frame", "NRSKNUI_CombatMessageContainer", UIParent)
    container:SetSize(200, 100)
    container:SetPoint(
        db.Position.AnchorFrom or "CENTER",
        parent,
        db.Position.AnchorTo or "CENTER",
        db.Position.XOffset or 0,
        db.Position.YOffset or 180
    )
    container:SetFrameStrata(db.Strata or "HIGH")
    container:SetFrameLevel(100)

    self.container = container
end

-- Create or get a message frame
function CM:GetMessageFrame(msgType)
    if self.messageFrames[msgType] then
        return self.messageFrames[msgType]
    end
    local frame = CreateFrame("Frame", nil, self.container)
    frame:SetSize(200, 30)
    frame:Hide()

    local text = frame:CreateFontString(nil, "OVERLAY")
    text:SetAllPoints(frame)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")

    -- Setting some min sizes for cleaner edit mode
    local width, height = math.max(text:GetWidth(), 150), math.max(text:GetHeight(), 14)
    frame:SetSize(width + 5, height)

    frame.text = text
    frame.msgType = msgType
    frame.generation = 0

    self.messageFrames[msgType] = frame
    self:ApplyFontSettings(frame)

    return frame
end

-- Apply font settings to a message frame
function CM:ApplyFontSettings(frame)
    if not frame or not frame.text then return end
    local db = self.db
    local text = frame.text
    local fontPath = NRSKNUI:GetFontPath(db.FontFace)
    local outline = db.FontOutline == "NONE" and "" or (db.FontOutline or "OUTLINE")
    -- Font
    text:SetFont(fontPath, db.FontSize or 28, outline)

    -- Font Shadow
    local shadow = db.FontShadow or {}
    if shadow.Enabled then
        local shadowColor = shadow.Color or { 0, 0, 0, 1 }
        text:SetShadowColor(shadowColor[1] or 0, shadowColor[2] or 0, shadowColor[3] or 0, shadowColor[4] or 1)
        text:SetShadowOffset(shadow.OffsetX or 1, shadow.OffsetY or -1)
    else
        text:SetShadowOffset(0, 0)
        text:SetShadowColor(0, 0, 0, 0)
    end
end

-- Arrange visible messages vertically
function CM:ArrangeMessages()
    local spacing = self.db.Spacing or 4
    local yOffset = 0

    for _, msgType in ipairs(MESSAGE_TYPES) do
        local frame = self.messageFrames[msgType]
        if frame and frame:IsShown() then
            frame:ClearAllPoints()
            frame:SetPoint("TOP", self.container, "TOP", 0, -yOffset)
            yOffset = yOffset + frame:GetHeight() + spacing
        end
    end

    -- Update container height
    if self.container then
        self.container:SetHeight(math.max(30, yOffset - spacing))
    end
end

-- Show a flash message
function CM:ShowFlashMessage(msgType)
    if not self.db or self.db.Enabled == false then return end
    if self.isPreview then return end

    local enabled, msgText, color = GetMessageConfig(self.db, msgType)
    if not enabled then return end

    local frame = self:GetMessageFrame(msgType)
    if not frame then return end

    local duration = self.db.Duration or 2.5
    frame.generation = frame.generation + 1
    local myGeneration = frame.generation

    -- Stop any existing fade
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(frame)
    end
    frame:SetScript("OnUpdate", nil)

    -- Set text and color
    frame.text:SetText(msgText)
    frame.text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)

    -- Show and arrange
    frame:SetAlpha(1)
    frame:Show()
    self.activeMessages[msgType] = true
    self:ArrangeMessages()

    -- Fade out and hide
    local function HideIfCurrent()
        if frame.generation == myGeneration and not self.isPreview then
            frame:Hide()
            self.activeMessages[msgType] = nil
            self:ArrangeMessages()
        end
    end

    if UIFrameFadeOut then
        UIFrameFadeOut(frame, duration, 1, 0)
        C_Timer.After(duration, HideIfCurrent)
    else
        C_Timer.After(duration, HideIfCurrent)
    end
end

-- Show a persistent message
function CM:ShowPersistentMessage(msgType)
    if not self.db or self.db.Enabled == false then return end
    if self.isPreview then return end

    local enabled, msgText, color = GetMessageConfig(self.db, msgType)
    if not enabled then return end

    local frame = self:GetMessageFrame(msgType)
    if not frame then return end

    -- Stop any existing fade
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(frame)
    end
    frame:SetScript("OnUpdate", nil)

    -- Set text and color
    frame.text:SetText(msgText)
    frame.text:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)

    -- Show and arrange
    frame:SetAlpha(1)
    frame:Show()
    self.activeMessages[msgType] = true
    self:ArrangeMessages()
end

-- Hide a persistent message
function CM:HidePersistentMessage(msgType)
    local frame = self.messageFrames[msgType]
    if frame then
        frame:Hide()
        self.activeMessages[msgType] = nil
        self:ArrangeMessages()
    end
end

-- Check if we have target or not in combat
function CM:CheckNoTarget()
    if not self.db or self.db.Enabled == false then return end
    if self.isPreview then return end

    local noTargetEnabled = self.db.NoTarget and self.db.NoTarget.Enabled

    -- Don't show NO TARGET if player is dead or ghost
    if UnitIsDeadOrGhost("player") then
        self:HidePersistentMessage("noTarget")
        return
    end

    if self.inCombat and noTargetEnabled then
        C_Timer.After(0.1, function()
            -- Re-check death state after timer
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

-- Event Handlers
function CM:OnEnterCombat()
    self.inCombat = true
    self:ShowFlashMessage("enterCombat")
    self:CheckNoTarget()
end

function CM:OnExitCombat()
    self.inCombat = false
    self:HidePersistentMessage("noTarget")
    self:ShowFlashMessage("exitCombat")
end

function CM:OnTargetChanged()
    self:CheckNoTarget()
end

function CM:OnPlayerDead()
    self:HidePersistentMessage("noTarget")
end

-- Settings Application
function CM:ApplySettings()
    if not self.container then return end

    local db = self.db
    local parent = NRSKNUI:ResolveAnchorFrame(db.anchorFrameType, db.ParentFrame)

    -- Update container position
    self.container:ClearAllPoints()
    self.container:SetPoint(
        db.Position.AnchorFrom or "CENTER",
        parent,
        db.Position.AnchorTo or "CENTER",
        db.Position.XOffset or 0,
        db.Position.YOffset or 180
    )
    self.container:SetFrameStrata(db.Strata or "HIGH")

    -- Update font settings for all message frames
    for _, frame in pairs(self.messageFrames) do
        self:ApplyFontSettings(frame)
    end

    -- Update preview content if in preview mode
    if self.isPreview then
        for _, msgType in ipairs(MESSAGE_TYPES) do
            local frame = self.messageFrames[msgType]
            if frame then
                local _, msgText, msgColor = GetMessageConfig(db, msgType)
                frame.text:SetText(msgText)
                frame.text:SetTextColor(msgColor[1] or 1, msgColor[2] or 1, msgColor[3] or 1, msgColor[4] or 1)
            end
        end
        self:ArrangeMessages()
    else
        -- Re-check no target state
        self:CheckNoTarget()
    end
end

-- Preview Mode
function CM:ShowPreview()
    if not self.container then
        self:CreateContainer()
    end

    self.isPreview = true

    -- Show all message types for preview to demonstrate vertical grouping
    for _, msgType in ipairs(MESSAGE_TYPES) do
        local frame = self:GetMessageFrame(msgType)
        if frame then
            local _, msgText, msgColor = GetMessageConfig(self.db, msgType)
            frame.text:SetText(msgText)
            frame.text:SetTextColor(msgColor[1] or 1, msgColor[2] or 1, msgColor[3] or 1, msgColor[4] or 1)
            frame:SetAlpha(1)
            frame:Show()
            self.activeMessages[msgType] = true
        end
    end

    self:ArrangeMessages()
end

function CM:HidePreview()
    if not self.isPreview then return end

    self.isPreview = false

    -- Hide all message frames
    for msgType, frame in pairs(self.messageFrames) do
        frame:Hide()
        self.activeMessages[msgType] = nil
    end

    -- Re-check actual state
    if self.inCombat then
        self:CheckNoTarget()
    end
end

-- Module OnEnable
function CM:OnEnable()
    if not self.db.Enabled then return end

    -- Create container
    self:CreateContainer()

    -- Pre-create message frames
    for _, msgType in ipairs(MESSAGE_TYPES) do
        self:GetMessageFrame(msgType)
    end

    -- Register events
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnExitCombat")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnTargetChanged")
    self:RegisterEvent("PLAYER_DEAD", "OnPlayerDead")

    -- Check initial combat state
    self.inCombat = InCombatLockdown()
    if self.inCombat then
        self:CheckNoTarget()
    end

    -- Register with EditMode
    local config = {
        key = "CombatMessages",
        displayName = "Combat Messages",
        frame = self.container,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset
            if self.container then
                local parent = NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
                self.container:ClearAllPoints()
                self.container:SetPoint(pos.AnchorFrom, parent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end
        end,
        getParentFrame = function()
            return NRSKNUI:ResolveAnchorFrame(self.db.anchorFrameType, self.db.ParentFrame)
        end,
        guiPath = "combatMessage",
    }
    NRSKNUI.EditMode:RegisterElement(config)
end

-- Module OnDisable
function CM:OnDisable()
    -- Hide all frames
    for _, frame in pairs(self.messageFrames) do
        frame:Hide()
    end
    self.activeMessages = {}
    self.isPreview = false
    self.inCombat = false

    -- Unregister events
    self:UnregisterAllEvents()
end
