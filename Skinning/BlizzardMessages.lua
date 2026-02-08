-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("BlizzardMessages: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local BM = NRSKNUI.Addon:NewModule("BlizzardMessages", "AceEvent-3.0")

-- Localization
local GetTime = GetTime
local UIErrorsFrame = UIErrorsFrame
local ActionStatus = ActionStatus
local ChatBubbleFont = ChatBubbleFont
local ObjectiveTrackerLineFont = ObjectiveTrackerLineFont
local ObjectiveTrackerHeaderFont = ObjectiveTrackerHeaderFont
local C_Timer = C_Timer
local UIParent = UIParent
local _G = _G

-- Module init
function BM:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.BlizzardMessages
    self:SetEnabledState(false)
end

-- Module OnEnable
function BM:OnEnable()
    if not self.db.Enabled then return end
    C_Timer.After(1.0, function()
        if self:IsEnabled() then
            self:Apply()
        end
    end)
end

-- Zone Texts styling
function BM:ZoneTextStyling()
    local zoneDB = self.db.ZoneText
    if zoneDB.Hide then
        _G.ZoneTextFrame:UnregisterAllEvents()
    else
        -- Apply font styling
        local fontPath = NRSKNUI:GetFontPath(self.db.Font)
        local outline = self.db.FontOutline == "NONE" and "" or (self.db.FontOutline or "OUTLINE")
        ZoneTextString:SetFont(fontPath, zoneDB.MainZone.Size, outline)
        ZoneTextString:SetShadowColor(0, 0, 0, 0)
        ZoneTextString:SetShadowOffset(0, 0)
        SubZoneTextString:SetFont(fontPath, zoneDB.SubZone.Size, outline)
        SubZoneTextString:SetShadowColor(0, 0, 0, 0)
        SubZoneTextString:SetShadowOffset(0, 0)

        PVPArenaTextString:SetFont(fontPath, zoneDB.SubZone.Size, outline)
        PVPArenaTextString:SetShadowColor(0, 0, 0, 0)
        PVPArenaTextString:SetShadowOffset(0, 0)

        PVPInfoTextString:SetFont(fontPath, zoneDB.SubZone.Size, outline)
        PVPInfoTextString:SetShadowColor(0, 0, 0, 0)
        PVPInfoTextString:SetShadowOffset(0, 0)

        _G.ZoneTextFrame:ClearAllPoints()
        _G.ZoneTextFrame:SetPoint(zoneDB.MainZone.Anchor, UIParent, zoneDB.MainZone.Anchor,
            zoneDB.MainZone.X, zoneDB.MainZone.Y)
        _G.ZoneTextFrame:RegisterEvent('ZONE_CHANGED')
        _G.ZoneTextFrame:RegisterEvent('ZONE_CHANGED_INDOORS')
        _G.ZoneTextFrame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
    end
end

-- UI Error text styling
function BM:StyleUIErrorsFrame()
    local errorsDB = self.db.UIErrorsFrame
    if not errorsDB or not UIErrorsFrame then return end

    -- Apply hide/show
    if errorsDB.Hide then
        UIErrorsFrame:Hide()
        UIErrorsFrame:SetAlpha(0)
    else
        UIErrorsFrame:Show()
        UIErrorsFrame:SetAlpha(1)

        -- Apply font
        local fontPath = NRSKNUI:GetFontPath(self.db.Font)
        local outline = self.db.FontOutline == "NONE" and "" or (self.db.FontOutline or "OUTLINE")
        UIErrorsFrame:SetFont(fontPath, errorsDB.Size, outline)

        -- Apply position
        if errorsDB.Position then
            UIErrorsFrame:ClearAllPoints()
            local anchor = errorsDB.Position.Anchor or "TOP"
            local x = errorsDB.Position.X or 0
            local y = errorsDB.Position.Y or -100
            UIErrorsFrame:SetPoint(anchor, UIParent, anchor, x, y)
        end

        -- Remove shadow
        UIErrorsFrame:SetShadowColor(0, 0, 0, 0)
    end
end

-- Action status text styling
function BM:StyleActionStatusText()
    local statusDB = self.db.ActionStatusText
    if not statusDB or not ActionStatus or not ActionStatus.Text then return end

    -- Apply hide/show
    if statusDB.Hide then
        ActionStatus.Text:Hide()
        ActionStatus.Text:SetAlpha(0)
    else
        ActionStatus.Text:Show()
        ActionStatus.Text:SetAlpha(1)

        -- Apply font
        local fontPath = NRSKNUI:GetFontPath(self.db.Font)
        local outline = self.db.FontOutline == "NONE" and "" or (self.db.FontOutline or "OUTLINE")
        ActionStatus.Text:SetFont(fontPath, statusDB.Size, outline)

        -- Apply position
        if statusDB.Position then
            ActionStatus.Text:ClearAllPoints()
            local anchor = statusDB.Position.Anchor or "TOP"
            local x = statusDB.Position.X or 0
            local y = statusDB.Position.Y or -150
            ActionStatus.Text:SetPoint(anchor, UIParent, anchor, x, y)
        end

        -- Remove shadow
        ActionStatus.Text:SetShadowColor(0, 0, 0, 0)
    end
end

-- Chat bubble styling
function BM:StyleChatBubbles()
    local bubblesDB = self.db.ChatBubbles
    if not bubblesDB or not bubblesDB.Enabled or not ChatBubbleFont then return end

    -- Apply font
    local fontPath = NRSKNUI:GetFontPath(self.db.Font)
    local outline = self.db.FontOutline == "NONE" and "" or (self.db.FontOutline or "OUTLINE")
    ChatBubbleFont:SetFont(fontPath, bubblesDB.Size, outline)
end

-- Objective tracker styling
function BM:StyleObjectiveTracker()
    local trackerDB = self.db.ObjectiveTracker
    if not trackerDB or not trackerDB.Enabled then return end
    local fontPath = NRSKNUI:GetFontPath(self.db.Font)
    local outline = self.db.FontOutline == "NONE" and "" or (self.db.FontOutline or "OUTLINE")

    -- Style quest text font
    if ObjectiveTrackerLineFont then
        ObjectiveTrackerLineFont:SetFont(fontPath, trackerDB.QuestTextSize, outline)
        ObjectiveTrackerLineFont:SetShadowColor(0, 0, 0, 0)
        ObjectiveTrackerLineFont:SetShadowOffset(0, 0)
    end

    -- Style header font
    if ObjectiveTrackerHeaderFont then
        ObjectiveTrackerHeaderFont:SetFont(fontPath, trackerDB.QuestTitleSize, outline)
        ObjectiveTrackerHeaderFont:SetShadowColor(0, 0, 0, 0)
        ObjectiveTrackerHeaderFont:SetShadowOffset(0, 0)
    end
end

-- Reset to blizzard default
function BM:ResetUIErrorsFrame()
    if not UIErrorsFrame then return end
    UIErrorsFrame:Show()
    UIErrorsFrame:SetAlpha(1)
    UIErrorsFrame:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    UIErrorsFrame:ClearAllPoints()
    UIErrorsFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
end

function BM:ResetActionStatusText()
    if not ActionStatus or not ActionStatus.Text then return end
    ActionStatus.Text:Show()
    ActionStatus.Text:SetAlpha(1)
    ActionStatus.Text:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    ActionStatus.Text:ClearAllPoints()
    ActionStatus.Text:SetPoint("TOP", UIParent, "TOP", 0, -150)
end

-- Apply all styles
function BM:Apply()
    if not self.db or not self.db.Enabled then
        self:Reset()
        return
    end
    self:StyleUIErrorsFrame()
    self:StyleActionStatusText()
    self:StyleChatBubbles()
    self:StyleObjectiveTracker()
    self:ZoneTextStyling()
end

-- Reset all styled elements to default
function BM:Reset()
    self:ResetUIErrorsFrame()
    self:ResetActionStatusText()
end

-- Preview functions for GUI
function BM:PreviewUIErrors()
    if UIErrorsFrame then
        UIErrorsFrame:Clear()
        UIErrorsFrame:AddMessage("Error Message Text", 1, 0.1, 0.1, 1.0, 5)
    end
end

function BM:PreviewActionStatus()
    if ActionStatus and ActionStatus.Text then
        ActionStatus.Text:SetText("Action Status Text")
        ActionStatus:Show()
        ActionStatus.startTime = GetTime()
        ActionStatus.holdTime = 5
        ActionStatus.fadeTime = 1
    end
end

-- Preview functions for GUI
function BM:PreviewZone()
    -- Main zone text
    if ZoneTextFrame and ZoneTextString then
        ZoneTextString:SetText("Main Zone Text")
        ZoneTextFrame:Show()
        ZoneTextFrame.fadingOut = false
        ZoneTextFrame.startTime = GetTime()
    end

    -- Sub zone text
    if SubZoneTextFrame and SubZoneTextString then
        SubZoneTextString:SetText("Sub Zone Text")
        SubZoneTextFrame:Show()
        SubZoneTextFrame.fadingOut = false
        SubZoneTextFrame.startTime = GetTime()
    end

    -- PvP Arena text
    if PVPArenaTextString then
        PVPArenaTextString:SetText("(PVP Arena Text)")
        PVPArenaTextString:Show()
        PVPArenaTextString.fadingOut = false
        PVPArenaTextString.startTime = GetTime()
    end

    -- PvP Arena text
    if PVPInfoTextString then
        PVPInfoTextString:SetText("(PVP Info Text)")
        PVPInfoTextString:Show()
        PVPInfoTextString.fadingOut = false
        PVPInfoTextString.startTime = GetTime()
    end
end

-- On Module disable, reset to blizzar defaults
function BM:OnDisable()
    self:Reset()
end
