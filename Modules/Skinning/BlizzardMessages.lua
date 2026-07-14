---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class BlizzardMessages: AceModule, AceEvent-3.0
local BM = NRSKNUI:NewModule("BlizzardMessages", "AceEvent-3.0")

local GetTime = GetTime
local C_Timer = C_Timer
local UIParent = UIParent
local _G = _G

-- Positioning/visibility for the Blizzard message frames. Their fonts are SpecialFonts
-- entries owned by BlizzardFonts.lua; this module only handles the behavior around them.
function BM:UpdateDB()
    self.db = NRSKNUI.db.profile.globalMedia.blizzardFonts.Specials
end

function BM:OnInitialize()
    self:UpdateDB()
end

function BM:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    C_Timer.After(1.0, function()
        if self:IsEnabled() then
            self:ApplySettings()
        end
    end)
end

function BM:ZoneTextStyling()
    local zoneDB = self.db.ZoneText
    if not zoneDB.Enabled then
        self:ResetZoneText()
        return
    end

    if zoneDB.Hide then
        _G.ZoneTextFrame:UnregisterAllEvents()
    else
        local pos = zoneDB.Position
        _G.ZoneTextFrame:ClearAllPoints()
        _G.ZoneTextFrame:SetPoint(pos.Anchor, UIParent, pos.Anchor, pos.X, pos.Y)
        _G.ZoneTextFrame:RegisterEvent("ZONE_CHANGED")
        _G.ZoneTextFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        _G.ZoneTextFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    end
end

function BM:StyleUIErrorsFrame()
    local errorsDB = self.db.ErrorText
    local frame = _G.UIErrorsFrame
    if not frame then return end

    if not errorsDB.Enabled then
        self:ResetUIErrorsFrame()
        return
    end

    if errorsDB.Hide then
        frame:Hide()
        frame:SetAlpha(0)
    else
        frame:Show()
        frame:SetAlpha(1)
        local pos = errorsDB.Position
        frame:ClearAllPoints()
        frame:SetPoint(pos.Anchor, UIParent, pos.Anchor, pos.X, pos.Y)
    end
end

function BM:StyleActionStatusText()
    local statusDB = self.db.ActionStatus
    local frame = _G.ActionStatus
    if not frame or not frame.Text then return end

    if not statusDB.Enabled then
        self:ResetActionStatusText()
        return
    end

    if statusDB.Hide then
        frame.Text:Hide()
        frame.Text:SetAlpha(0)
    else
        frame.Text:Show()
        frame.Text:SetAlpha(1)
        local pos = statusDB.Position
        frame.Text:ClearAllPoints()
        frame.Text:SetPoint(pos.Anchor, UIParent, pos.Anchor, pos.X, pos.Y)
    end
end

function BM:ResetUIErrorsFrame()
    local frame = _G.UIErrorsFrame
    if not frame then return end
    frame:Show()
    frame:SetAlpha(1)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
end

function BM:ResetActionStatusText()
    local frame = _G.ActionStatus
    if not frame or not frame.Text then return end
    frame.Text:Show()
    frame.Text:SetAlpha(1)
    frame.Text:ClearAllPoints()
    frame.Text:SetPoint("TOP", UIParent, "TOP", 0, -150)
end

function BM:ResetZoneText()
    if _G.ZoneTextFrame then
        _G.ZoneTextFrame:RegisterEvent("ZONE_CHANGED")
        _G.ZoneTextFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
        _G.ZoneTextFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    end
end

function BM:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    self:UpdateDB()
    self:StyleUIErrorsFrame()
    self:StyleActionStatusText()
    self:ZoneTextStyling()
end

function BM:Reset()
    self:ResetUIErrorsFrame()
    self:ResetActionStatusText()
    self:ResetZoneText()
end

function BM:PreviewUIErrors()
    local frame = _G.UIErrorsFrame
    if frame then
        frame:Clear()
        frame:AddMessage("Error Message Text", 1, 0.1, 0.1, 1.0, 5)
    end
end

function BM:PreviewActionStatus()
    local frame = _G.ActionStatus
    if frame and frame.Text then
        frame.Text:SetText("Action Status Text")
        frame:Show()
        frame.startTime = GetTime()
        frame.holdTime = 5
        frame.fadeTime = 1
    end
end

function BM:PreviewZone()
    local zoneFrame = _G.ZoneTextFrame
    local zoneText = _G.ZoneTextString
    if zoneFrame and zoneText then
        zoneText:SetText("Main Zone Text")
        zoneFrame:Show()
        zoneFrame.fadingOut = false
        zoneFrame.startTime = GetTime()
    end

    local subFrame = _G.SubZoneTextFrame
    local subText = _G.SubZoneTextString
    if subFrame and subText then
        subText:SetText("Sub Zone Text")
        subFrame:Show()
        subFrame.fadingOut = false
        subFrame.startTime = GetTime()
    end

    local pvpArena = _G.PVPArenaTextString
    if pvpArena then
        pvpArena:SetText("(PVP Arena Text)")
        pvpArena:Show()
        pvpArena.fadingOut = false
        pvpArena.startTime = GetTime()
    end

    local pvpInfo = _G.PVPInfoTextString
    if pvpInfo then
        pvpInfo:SetText("(PVP Info Text)")
        pvpInfo:Show()
        pvpInfo.fadingOut = false
        pvpInfo.startTime = GetTime()
    end
end

function BM:OnDisable()
    self:Reset()
end
