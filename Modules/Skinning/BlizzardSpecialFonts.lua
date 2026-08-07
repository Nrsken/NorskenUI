---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BlizzardMessagesModule
local BlizzardMessages = NRSKNUI:GetModule('BlizzardMessages')
function BlizzardMessages:UpdateDB() self.db = NRSKNUI.db.profile.globalMedia.blizzardFonts end

local GetTime = GetTime
local UIParent = UIParent
local _G = _G

local ZONE_EVENTS = {
    'ZONE_CHANGED',
    'ZONE_CHANGED_INDOORS',
    'ZONE_CHANGED_NEW_AREA',
}

local anchors = {}
local function SaveAnchors(obj)
    if anchors[obj] then return end

    local points = {}
    for i = 1, obj:GetNumPoints() do
        points[i] = { obj:GetPoint(i) }
    end
    anchors[obj] = points
end

local function RestoreAnchors(obj)
    local points = anchors[obj]
    if not points then return end

    obj:ClearAllPoints()
    for i = 1, #points do
        local point = points[i]
        obj:SetPoint(point[1], point[2], point[3], point[4], point[5])
    end
end

local function SetZoneEvents(frame, register)
    for i = 1, #ZONE_EVENTS do
        if register then
            frame:RegisterEvent(ZONE_EVENTS[i])
        else
            frame:UnregisterEvent(ZONE_EVENTS[i])
        end
    end
end

function BlizzardMessages:ResetZoneText()
    local frame = _G.ZoneTextFrame
    if not frame then return end

    RestoreAnchors(frame)
    SetZoneEvents(frame, true)
end

function BlizzardMessages:ResetUIErrorsFrame()
    local frame = _G.UIErrorsFrame
    if not frame then return end

    frame:Show()
    frame:SetAlpha(1)
    RestoreAnchors(frame)
end

function BlizzardMessages:ResetActionStatusText()
    local frame = _G.ActionStatus
    if not frame or not frame.Text then return end

    frame.Text:Show()
    frame.Text:SetAlpha(1)
    RestoreAnchors(frame.Text)
end

function BlizzardMessages:Reset()
    self:ResetZoneText()
    self:ResetUIErrorsFrame()
    self:ResetActionStatusText()
end

function BlizzardMessages:HandleZoneText()
    local frame = _G.ZoneTextFrame
    if not frame then return end
    local db = self.db.Specials.ZoneText

    if not db.Enabled then
        self:ResetZoneText()
    elseif db.Hide then
        SetZoneEvents(frame, false)
    else
        SaveAnchors(frame)
        frame:ClearAllPoints()
        frame:SetPoint(db.Position.Anchor, UIParent, db.Position.Anchor, db.Position.X, db.Position.Y)
        SetZoneEvents(frame, true)
    end
end

function BlizzardMessages:HandleUIErrorsFrame()
    local frame = _G.UIErrorsFrame
    if not frame then return end
    local db = self.db.Specials.ErrorText

    if not db.Enabled then
        self:ResetUIErrorsFrame()
    elseif db.Hide then
        frame:Hide()
        frame:SetAlpha(0)
    else
        SaveAnchors(frame)
        frame:Show()
        frame:SetAlpha(1)
        frame:ClearAllPoints()
        frame:SetPoint(db.Position.Anchor, UIParent, db.Position.Anchor, db.Position.X, db.Position.Y)
    end
end

function BlizzardMessages:HandleActionStatusText()
    local frame = _G.ActionStatus
    if not frame or not frame.Text then return end
    local db = self.db.Specials.ActionStatus

    if not db.Enabled then
        self:ResetActionStatusText()
    elseif db.Hide then
        frame.Text:Hide()
        frame.Text:SetAlpha(0)
    else
        SaveAnchors(frame.Text)
        frame.Text:Show()
        frame.Text:SetAlpha(1)
        frame.Text:ClearAllPoints()
        frame.Text:SetPoint(db.Position.Anchor, UIParent, db.Position.Anchor, db.Position.X, db.Position.Y)
    end
end

function BlizzardMessages:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end

    if not self.db.Enabled then
        self:Reset()
        return
    end

    self:HandleZoneText()
    self:HandleUIErrorsFrame()
    self:HandleActionStatusText()
end

function BlizzardMessages:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end

    self:RegisterMessage('NRSKNUI_WORLD_READY', 'ApplySettings')
end

function BlizzardMessages:OnDisable()
    self:UnregisterMessage('NRSKNUI_WORLD_READY')
    self:Reset()
end

function BlizzardMessages:PreviewUIErrors()
    local frame = _G.UIErrorsFrame
    if frame then
        frame:Clear()
        frame:AddMessage('Error Message Text', 1, 0.1, 0.1, 1.0, 5)
    end
end

function BlizzardMessages:PreviewActionStatus()
    local frame = _G.ActionStatus
    if frame and frame.Text then
        frame.Text:SetText('Action Status Text')
        frame:Show()
        frame.startTime = GetTime()
        frame.holdTime = 5
        frame.fadeTime = 1
    end
end

function BlizzardMessages:PreviewZone()
    local zoneFrame, zoneText = _G.ZoneTextFrame, _G.ZoneTextString
    local subFrame, subText = _G.SubZoneTextFrame, _G.SubZoneTextString
    local pvpArena, pvpInfo = _G.PVPArenaTextString, _G.PVPInfoTextString

    if zoneFrame and zoneText then
        zoneText:SetText('Main Zone Text')
        zoneFrame:Show()
        zoneFrame.fadingOut = false
        zoneFrame.startTime = GetTime()
    end

    if subFrame and subText then
        subText:SetText('Sub Zone Text')
        subFrame:Show()
        subFrame.fadingOut = false
        subFrame.startTime = GetTime()
    end

    if pvpArena then
        pvpArena:SetText('(PVP Arena Text)')
        pvpArena:Show()
        pvpArena.fadingOut = false
        pvpArena.startTime = GetTime()
    end

    if pvpInfo then
        pvpInfo:SetText('(PVP Info Text)')
        pvpInfo:Show()
        pvpInfo.fadingOut = false
        pvpInfo.startTime = GetTime()
    end
end
