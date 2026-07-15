---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class PotionReady
local PotionReady = NRSKNUI:GetModule("PotionReady")
local EM = NRSKNUI.EditMode
local LC = NRSKNUI.LoadConditions

local unpack = unpack
local select = select
local GetTime = GetTime
local GetInstanceInfo = GetInstanceInfo
local CreateFrame = CreateFrame

local GetItemCooldown = C_Item and C_Item.GetItemCooldown
local NewTimer = C_Timer and C_Timer.NewTimer

-- R2 Light's Potential but can be any dmg pot, since they all share cd
local POTION_ID = 241308

-- Chache pot state to avoid unnecessary checks
local potionOnCooldown = false

function PotionReady:UpdateDB()
    self.db = NRSKNUI.db.profile.PotionReady
end

function PotionReady:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function PotionReady:CreateAlertFrame()
    if self.alertFrame then return end

    local frame = CreateFrame('Frame', 'NRSKNUI_PotionReadyAlert', UIParent)
    frame:SetSize(300, 40)

    frame.text = frame:CreateFontString(nil, 'OVERLAY')

    -- Finalize the frame and register it with Anchors.
    self.alertFrame = frame
    EM:Register(self, 'PotionReadyAlert', self.alertFrame, 'PotionReady')
    frame:Hide()
end

function PotionReady:ApplySettings()
    if not self.alertFrame then return end

    self.alertFrame:ApplyPosition(self.db)
    self.alertFrame.text:SetFontStyle(self.db)
    self.alertFrame.text:SetFontJustify(self.db)
    self.alertFrame.text:SetText(self.db.Text)
    self.alertFrame.text:SetTextColor(unpack(self.db.Color))

    local w = self.alertFrame.text:GetStringWidth()
    local h = self.alertFrame.text:GetStringHeight()
    self.alertFrame:SetPixelSize(w + 4, h + 4)
end

function PotionReady:UpdateCooldownState()
    if self.isPreview then return end

    if self.cooldownTimer then
        self.cooldownTimer:Cancel()
        self.cooldownTimer = nil
    end

    local startTime, duration = GetItemCooldown(POTION_ID)
    local remaining = duration > 0 and (startTime + duration) - GetTime() or 0
    if remaining > 0 then
        potionOnCooldown = true
        if self.alertFrame then self.alertFrame:Hide() end
        self.cooldownTimer = NewTimer(remaining, function()
            self.cooldownTimer = nil
            self:UpdateCooldownState()
        end)
    else
        potionOnCooldown = false
        if self.db.Enabled and self.alertFrame and LC:Check(self.db.LoadConditions) then
            self.alertFrame:Show()
        elseif self.alertFrame then
            self.alertFrame:Hide()
        end
    end
end

function PotionReady:OnEnable()
    if not self.db.Enabled then return end

    self:CreateAlertFrame()
    self:ApplySettings()
    self:UpdateCooldownState()

    -- Register for load condition changes
    LC:RegisterCallback(self, self.UpdateCooldownState)

    -- Only check pot state if not already on cooldown
    self:RegisterEvent("BAG_UPDATE_COOLDOWN", function()
        if not potionOnCooldown then
            PotionReady:UpdateCooldownState()
        end
    end)

    -- Pot cooldown is reset on M+ key start and boss resets, kills or wipes
    self:RegisterEvent("CHALLENGE_MODE_START", "UpdateCooldownState")
    self:RegisterEvent("ENCOUNTER_END", function()
        if select(2, GetInstanceInfo()) == "raid" then
            PotionReady:UpdateCooldownState()
        end
    end)
end

function PotionReady:OnDisable()
    LC:UnregisterCallback(self)
    if self.cooldownTimer then
        self.cooldownTimer:Cancel()
        self.cooldownTimer = nil
    end
    if self.alertFrame then
        self.alertFrame:Hide()
        EM:UnregisterModuleElement('PotionReadyAlert')
    end
    self.isPreview = false
end

function PotionReady:ShowPreview()
    if not self.alertFrame then return end

    self.isPreview = true
    self:ApplySettings()
    self.alertFrame:Show()
end

function PotionReady:HidePreview()
    self.isPreview = false

    if not self.db.Enabled and self.alertFrame then
        self.alertFrame:Hide()
    else
        self:UpdateCooldownState()
    end
end
