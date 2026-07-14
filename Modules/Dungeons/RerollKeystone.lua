---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class RerollKeystone: AceModule, AceEvent-3.0
local RK = NRSKNUI:NewModule("RerollKeystone", "AceEvent-3.0")
local EM = NRSKNUI.EditMode

local GetTime = GetTime
local GetRealZoneText = GetRealZoneText
local select = select
local GetInstanceInfo = GetInstanceInfo
local C_Timer = C_Timer
local C_ChallengeMode = C_ChallengeMode
local C_MythicPlus = C_MythicPlus

RK.isPreview = false
RK.timerActive = false
RK.timerStart = 0
RK.timerHandle = nil
RK.initialKeyMapID = nil
RK.hasRerolled = false

local function IsInMythicKeystone()
    local difficultyID = select(3, GetInstanceInfo())
    return difficultyID == 8
end

local function CanRerollKey()
    local info = C_ChallengeMode.GetChallengeCompletionInfo()
    if not info then return false end
    local keyStoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    if not keyStoneLevel then return false end
    return info.onTime and keyStoneLevel <= info.level
end

function RK:UpdateDB()
    self.db = NRSKNUI.db.profile.RerollKeystone
end

function RK:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function RK:CreateFrame()
    if self.frame then return end

    local frame = CreateFrame("Frame", "NRSKNUI_RerollKeystone", UIParent)
    frame:SetSize(self.db.Size, self.db.Size)

    -- Add borders
    frame:AddBorders()

    -- Icon texture with zoom
    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints(frame)
    frame.icon:SetZoom(self.db.Zoom)

    frame.text = frame:CreateFontString(nil, "OVERLAY")

    frame.icon:SetTexture(525134)

    frame.text:SetPixelPoint("BOTTOM", frame, "TOP", 0, 8)
    frame.text:SetFontStyle(self.db)
    frame.text:SetTextColor(unpack(self.db.FontColor))

    local keyText = frame:CreateFontString(nil, "OVERLAY")
    keyText:SetPixelPoint("TOP", frame, "BOTTOM", 0, -8)
    keyText:SetFontStyle(self.db, self.db.FontSizeKey)
    keyText:SetTextColor(unpack(self.db.FontColorKey))
    frame.keyText = keyText

    frame:Hide()
    self.frame = frame
end

function RK:ApplySettings()
    if not self.frame then return end

    self.frame:SetPixelSize(self.db.Size)
    self.frame:ApplyPosition(self.db)
    self.frame.text:SetFontStyle(self.db)
    self.frame.text:SetTextColor(unpack(self.db.FontColor))
    self.frame.keyText:SetFontStyle(self.db, self.db.FontSizeKey)
    self.frame.keyText:SetTextColor(unpack(self.db.FontColorKey))
end

function RK:UpdateDisplay()
    if not self.frame then return end
    local keyLevel = C_MythicPlus.GetOwnedKeystoneLevel()
    local keyMapID = C_MythicPlus.GetOwnedKeystoneMapID()
    self.frame.text:SetText(self.hasRerolled and "NEW KEY" or "REROLL KEY?")
    if keyLevel and keyMapID then self.frame.keyText:SetFormattedText("%s - %d", GetRealZoneText(keyMapID), keyLevel) end
end

function RK:CheckTimer()
    if not self.timerActive then return end
    local elapsed = GetTime() - self.timerStart
    if elapsed >= 300 then self:StopTimer() end
end

function RK:StartTimer()
    if self.timerActive then return end
    if not CanRerollKey() then return end

    self.timerActive = true
    self.timerStart = GetTime()
    self.initialKeyMapID = C_MythicPlus.GetOwnedKeystoneMapID()

    if not self.frame then self:CreateFrame() end
    self:ApplySettings()
    self:UpdateDisplay()
    self.frame:Show()

    self.timerHandle = C_Timer.NewTicker(1, function()
        self:CheckTimer()
    end)

    self:RegisterEvent("ITEM_CHANGED", function()
        if not self.timerActive then return end
        C_Timer.After(1, function()
            local currentMapID = C_MythicPlus.GetOwnedKeystoneMapID()
            if not self.hasRerolled and currentMapID ~= self.initialKeyMapID then
                self.hasRerolled = true
                self:UpdateDisplay()
            end
        end)
    end)
end

function RK:StopTimer()
    self.timerActive = false
    self.timerStart = 0
    self.initialKeyMapID = nil
    self.hasRerolled = false

    if self.timerHandle then
        self.timerHandle:Cancel()
        self.timerHandle = nil
    end

    self:UnregisterEvent("ITEM_CHANGED")

    if self.frame and not self.isPreview then self.frame:Hide() end
end

function RK:OnEnable()
    if not self.db.Enabled then return end

    self:CreateFrame()

    C_Timer.After(0.5, function() self:ApplySettings() end)

    self:RegisterEvent("CHALLENGE_MODE_COMPLETED", function()
        if not self.db.Enabled or not IsInMythicKeystone() then return end
        C_Timer.After(1, function() self:StartTimer() end)
    end)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
        if self.timerActive and not IsInMythicKeystone() then self:StopTimer() end
    end)
    self:RegisterEvent("PLAYER_LEAVING_WORLD", function() self:StopTimer() end)

    EM:Register(self, 'RerollKeystone', self.frame, 'RerollKeystone')
end

function RK:OnDisable()
    self:StopTimer()
    if self.frame then
        self.frame:Hide()
    end
    self.isPreview = false
end

function RK:ShowPreview()
    if not self.frame then self:CreateFrame() end
    self.isPreview = true
    self.frame.text:SetText("REROLL KEY?")
    self.frame.keyText:SetText("Algeth'ar Academy - 21")
    self.frame:SetAlpha(1)
    self.frame:Show()
    self:ApplySettings()
end

function RK:HidePreview()
    self.isPreview = false
    if not self.frame then return end
    if not self.timerActive then self.frame:Hide() end
end
