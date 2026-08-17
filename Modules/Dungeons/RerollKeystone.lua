---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class RerollKeystoneModule
local RerollKeystone = NRSKNUI:GetModule('RerollKeystone')
function RerollKeystone:UpdateDB() self.db = NRSKNUI.db.profile.RerollKeystone end

-- TODO: Add glow

local Anchors = NRSKNUI.Anchors

local GetInstanceInfo = GetInstanceInfo
local GetRealZoneText = GetRealZoneText
local CreateFrame = CreateFrame
local select = select

local GetChallengeCompletionInfo = C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo
local GetOwnedKeystoneLevel = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLevel
local GetOwnedKeystoneMapID = C_MythicPlus and C_MythicPlus.GetOwnedKeystoneMapID

local DISPLAY_DURATION = 300 -- How long the reroll prompt stays up after a completed run.
local KEYSTONE_SETTLE = 1    -- How long to wait after a keystone is rerolled before checking if it changed.

-- Key information --

local function CanRerollKey()
    local info = GetChallengeCompletionInfo()
    if not info then return false end

    local keyStoneLevel = GetOwnedKeystoneLevel()
    if not keyStoneLevel then return false end

    return info.onTime and keyStoneLevel <= info.level
end

local function IsInMythicKeystone()
    local difficultyID = select(3, GetInstanceInfo())

    return difficultyID == 8
end

local function GetKeyInfo()
    local keyStoneLevel = GetOwnedKeystoneLevel()
    local mapID = GetOwnedKeystoneMapID()

    return keyStoneLevel, mapID
end

-- Frame --

function RerollKeystone:CreateFrame()
    if self.frame then return end

    local frame = CreateFrame('Frame', 'NRSKNUI_RerollKeystone', UIParent)
    frame:SetRolesets('encounterUI')
    frame:NUISetPixelSize(self.db.Size, self.db.Size)
    frame:NUIAddBorders()

    frame.icon = frame:CreateTexture(nil, 'ARTWORK')
    frame.icon:NUISetPixelInside(frame)
    frame.icon:NUISetZoom()
    frame.icon:SetTexture(525134)

    frame.text = frame:CreateFontString(nil, 'OVERLAY')
    frame.text:NUISetPixelPoint('BOTTOM', frame, 'TOP', 0, 8)

    frame.keyText = frame:CreateFontString(nil, 'OVERLAY')
    frame.keyText:NUISetPixelPoint('TOP', frame, 'BOTTOM', 0, -8)

    frame:Hide()
    self.frame = frame
    Anchors:Register(self, 'RerollKeystone', self.frame, 'rerollKeystone')
end

function RerollKeystone:ApplySettings()
    if not self.frame then return end

    local tC = self.db.FontColor
    local kC = self.db.FontColorKey

    self.frame:NUISetPixelSize(self.db.Size, self.db.Size)
    self.frame:NUIApplyPosition(self.db)

    self.frame.text:SetFontStyle(self.db)
    self.frame.text:SetTextColor(tC[1], tC[2], tC[3], tC[4])

    self.frame.keyText:SetFontStyle(self.db, self.db.FontSizeKey)
    self.frame.keyText:SetTextColor(kC[1], kC[2], kC[3], kC[4])
end

-- Display --

function RerollKeystone:UpdateDisplay()
    self.frame.text:SetText(self.hasRerolled and 'NEW KEY' or 'REROLL KEY?')

    local keyStoneLevel, mapID = GetKeyInfo()
    if keyStoneLevel and mapID then
        self.frame.keyText:SetFormattedText('%s\n%d', GetRealZoneText(mapID), keyStoneLevel)
    end
end

function RerollKeystone:ShowDisplay()
    self.timer = nil
    if not CanRerollKey() then return end

    self.displayActive = true
    self.hasRerolled = false
    self.initialKeyMapID = GetOwnedKeystoneMapID()

    self:UpdateDisplay()
    self.frame:Show()

    self.timer = self:ScheduleTimer('CancelDisplay', DISPLAY_DURATION)
    self:RegisterEvent('ITEM_CHANGED', 'KeystoneItemChanged')
end

function RerollKeystone:CancelDisplay()
    if self.timer then
        self:CancelTimer(self.timer)
        self.timer = nil
    end

    if self.rerollTimer then
        self:CancelTimer(self.rerollTimer)
        self.rerollTimer = nil
    end

    self:UnregisterEvent('ITEM_CHANGED')

    self.displayActive = false
    self.hasRerolled = false
    self.initialKeyMapID = nil

    if self.frame and not self.isPreview then
        self.frame:Hide()
    end
end

-- Events --

function RerollKeystone:KeystoneItemChanged()
    if self.hasRerolled or self.rerollTimer then return end

    self.rerollTimer = self:ScheduleTimer('CheckReroll', KEYSTONE_SETTLE)
end

function RerollKeystone:CheckReroll()
    self.rerollTimer = nil
    if self.hasRerolled or not self.displayActive then return end

    if GetOwnedKeystoneMapID() ~= self.initialKeyMapID then
        self.hasRerolled = true

        if not self.isPreview then
            self:UpdateDisplay()
        end
    end
end

function RerollKeystone:CHALLENGE_MODE_COMPLETED()
    if not IsInMythicKeystone() then return end

    if self.timer then self:CancelTimer(self.timer) end
    self.timer = self:ScheduleTimer('ShowDisplay', KEYSTONE_SETTLE)
end

function RerollKeystone:ZONE_CHANGED_NEW_AREA()
    if not IsInMythicKeystone() then
        self:CancelDisplay()
    end
end

function RerollKeystone:PLAYER_LEAVING_WORLD()
    self:CancelDisplay()
end

-- Lifecycle --

function RerollKeystone:OnEnable()
    self:CreateFrame()
    self:ApplySettings()

    self:RegisterEvent('CHALLENGE_MODE_COMPLETED')
    self:RegisterEvent('ZONE_CHANGED_NEW_AREA')
    self:RegisterEvent('PLAYER_LEAVING_WORLD')
end

function RerollKeystone:OnDisable()
    self.isPreview = false
    self:CancelDisplay()
end

-- Preview --

function RerollKeystone:ShowPreview()
    self:CreateFrame()

    self.isPreview = true
    self:ApplySettings()

    self.frame.text:SetText('REROLL KEY?')
    self.frame.keyText:SetText("Algeth'ar Academy\n21")
    self.frame:Show()
end

function RerollKeystone:HidePreview()
    if not self.isPreview then return end
    self.isPreview = false
    if not self.frame then return end

    if self.displayActive then
        self:UpdateDisplay()
    else
        self.frame:Hide()
    end
end
