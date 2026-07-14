---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class BenchAlert: AceModule, AceEvent-3.0
local BA = NRSKNUI:NewModule("BenchAlert", "AceEvent-3.0")
local EM = NRSKNUI.EditMode

local IsInRaid = IsInRaid
local IsInInstance = IsInInstance
local GetRaidDifficultyID = GetRaidDifficultyID
local GetRaidRosterInfo = GetRaidRosterInfo
local UnitName = UnitName
local C_Timer = C_Timer
local unpack = unpack

BA.isPreview = false

function BA:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.BenchAlert
end

function BA:OnInitialize()
    self:UpdateDB()
    self.isBenched = false
    self:SetEnabledState(false)
end

function BA:OnEnable()
    if not self.db.Enabled then return end
    self:CreateAlertFrame()
    C_Timer.After(0.5, function() self:ApplySettings() end)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "CheckConditions")
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "CheckConditions")
    self:RegisterEvent("PLAYER_DIFFICULTY_CHANGED", "CheckConditions")
    self:CheckConditions()

    EM:Register(self, 'BenchAlert', self.alertFrame, 'benchalert')
end

function BA:OnDisable()
    self:UnregisterAllEvents()
    if self.alertFrame then self.alertFrame:Hide() end
    self.isBenched = false
    self.isPreview = false
end

function BA:CheckConditions()
    if self.isPreview then return end

    C_Timer.After(0.2, function()
        if not IsInRaid() then return self:UpdateState(false) end

        local inInstance, instanceType = IsInInstance()
        if not inInstance or instanceType ~= "raid" then return self:UpdateState(false) end

        if GetRaidDifficultyID() ~= 16 then return self:UpdateState(false) end

        local playerName = UnitName("player")
        for i = 1, 40 do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name and name == playerName then
                self:UpdateState(subgroup == 8)
                return
            end
        end

        self:UpdateState(false)
    end)
end

function BA:UpdateState(isBenched)
    if self.isPreview then return end
    if isBenched == self.isBenched then return end
    self.isBenched = isBenched

    if isBenched then
        self.alertFrame.text:SetText(self.db.Text)
        self.alertFrame:SetAlpha(1)
        self.alertFrame:Show()
    else
        if self.alertFrame then self.alertFrame:Hide() end
    end
end

function BA:CreateAlertFrame()
    if self.alertFrame then return end
    local frame = CreateFrame("Frame", "NRSKNUI_BenchAlertFrame", UIParent)
    frame:SetSize(300, 50)
    frame.text = frame:CreateFontString(nil, "OVERLAY")
    frame.text:SetFontStyle(self.db)

    frame:Hide()
    self.alertFrame = frame
    return frame
end

function BA:ApplySettings()
    if not self.alertFrame then return end
    self.alertFrame:ApplyPosition(self.db)
    self.alertFrame.text:SetTextColor(unpack(self.db.Color))
    self.alertFrame.text:SetFontStyle(self.db, self.db.FontSize)

    if self.db.Strata then self.alertFrame:SetFrameStrata(self.db.Strata) end
end

function BA:ShowPreview()
    if not self.alertFrame then self:CreateAlertFrame() end

    if NRSKNUI.EditMode and not self.editModeRegistered then
        NRSKNUI.EditMode:RegisterElement({
            key = "BenchAlert",
            displayName = "Bench Alert",
            frame = self.alertFrame,
            getPosition = function() return self.db.Position end,
            setPosition = function(pos)
                self.db.Position.AnchorFrom = pos.AnchorFrom
                self.db.Position.AnchorTo = pos.AnchorTo
                self.db.Position.XOffset = pos.XOffset
                self.db.Position.YOffset = pos.YOffset
                self.alertFrame:ApplyPosition(self.db)
            end,
            guiPath = "benchalert",
        })
        self.editModeRegistered = true
    end

    self.isPreview = true
    self.alertFrame.text:SetText(self.db.Text)
    self.alertFrame:SetAlpha(1)
    self.alertFrame:Show()
    self:ApplySettings()
end

function BA:HidePreview()
    self.isPreview = false
    if self.db.Enabled then
        self.isBenched = nil
        self:CheckConditions()
    else
        if self.alertFrame then self.alertFrame:Hide() end
    end
end
