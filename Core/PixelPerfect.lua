---@class NRSKNUI
local NRSKNUI = select(2, ...)

local GetPhysicalScreenSize = GetPhysicalScreenSize
local GetScreenWidth = GetScreenWidth
local GetScreenHeight = GetScreenHeight
local format = format
local InCombatLockdown = InCombatLockdown

local UIParent = UIParent

NRSKNUI.PhysW, NRSKNUI.PhysH = GetPhysicalScreenSize()
NRSKNUI.ScreenW, NRSKNUI.ScreenH = GetScreenWidth(), GetScreenHeight()
NRSKNUI.Res = format('%dx%d', NRSKNUI.PhysW, NRSKNUI.PhysH)
NRSKNUI.PerfectPixel = 768 / NRSKNUI.PhysH -- Auto scale factor
NRSKNUI.TenEigthyPixel = 768 / 1080        -- Scale factor for 1080p resolution
NRSKNUI.FourteenFortyPixel = 768 / 1440    -- Scale factor for 1440p resolution

function NRSKNUI:SetScaleValue(custom)
    if not custom then
        self.db.global.UIScale.Scale = self:GetBestPixelSize()
    else
        self.db.global.UIScale.Scale = custom
    end
    self:SetUIScale()
end

function NRSKNUI:GetBestPixelSize()
    if self.PerfectPixel > 1.15 then
        return 1.15
    elseif self.PerfectPixel < 0.4 then
        return 0.4
    end
    return self.PerfectPixel
end

function NRSKNUI:UpdateMult()
    self.Mult = self.PerfectPixel / self:GetBestPixelSize()
end

function NRSKNUI:SetUIScale()
    if not self.db.global.UIScale.Enabled then return end

    if InCombatLockdown() then
        self:RegisterEvent('PLAYER_REGEN_ENABLED', function() self:SetUIScale() end)
        self.CombatEndRegistered = true
    else
        UIParent:SetScale(self.db.global.UIScale.Scale)

        if self.CombatEndRegistered then
            self:UnregisterEvent('PLAYER_REGEN_ENABLED')
            self.CombatEndRegistered = false
        end
    end
end

function NRSKNUI:UpdateValues()
    self.PhysW, self.PhysH = GetPhysicalScreenSize()
    self.ScreenW, self.ScreenH = GetScreenWidth(), GetScreenHeight()
    self.Res = format('%dx%d', self.PhysW, self.PhysH)
    self.PerfectPixel = 768 / self.PhysH
end

function NRSKNUI:ChangedScaleEvent(event)
    if event == "UI_SCALE_CHANGED" then
        self:UpdateValues()
    end

    self:UpdateMult()
    self:SetUIScale()
end
