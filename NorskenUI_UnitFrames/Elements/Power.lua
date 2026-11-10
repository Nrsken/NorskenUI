---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local pairs, ipairs = pairs, ipairs

local NO_POWER = UF.NoPower

local Interpolation = Enum and Enum.StatusBarInterpolation

---Whether a frame should carry a power bar at all.
---@param self oUF.UnitFrame
---@param unit string
---@param pDB table the unit's Power block
---@return boolean
local function Wanted(self, unit, pDB)
    return pDB.Enabled and not NO_POWER[self.nuiConfig or unit]
end

---An unassigned role passes only while every role is picked; no picked class lets every class through.
---@param unit string
---@param pDB table
---@return boolean
local function PassesFilter(unit, pDB)
    local roles = pDB.Roles
    local role = NRSKNUI:GetSafeRole(unit)
    if role and role ~= 'NONE' then
        if not roles[role] then return false end
    elseif not (roles.TANK and roles.HEALER and roles.DAMAGER) then
        return false
    end

    local anyClass = false
    for _, picked in pairs(pDB.Classes) do
        if picked then anyClass = true break end
    end
    if not anyClass then return true end

    local _, class = UnitClass(unit)
    return NRSKNUI:NotSecretValue(class) and pDB.Classes[class] == true
end

---Called from both elements, as their Configure order is not fixed.
---@param frame oUF.UnitFrame
function UF.LayoutBars(frame)
    local power = frame.Power
    local pDB = power and power.nuiDB
    local docked = pDB and pDB.Enabled and pDB.Docked and power.nuiPasses ~= false
    local health = frame.Health

    if health then
        local lift = docked and pDB.Height + 1 or 0
        for _, bar in ipairs({ health, health.healthBackground, frame.healthBorderFrame, health.nuiTempLoss }) do
            bar:ClearAllPoints()
            bar:NCSetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
            bar:NCSetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, lift)
        end

        -- Health ends where the temporarily lost max health begins.
        if health.TempLoss then
            local edge = health.TempLoss:GetStatusBarTexture()
            for _, bar in ipairs({ health, health.healthBackground }) do
                if health.nuiInverse then
                    bar:NCSetPoint('TOPLEFT', edge, 'TOPRIGHT', 0, 0)
                else
                    bar:NCSetPoint('BOTTOMRIGHT', edge, 'BOTTOMLEFT', 0, 0)
                end
            end
        end
    end

    if pDB then
        local y = pDB.Docked and 0 or -pDB.Height - 1
        power:ClearAllPoints()
        power:NCSetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 0, y)
        power:NCSetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', 0, y)
        power:NCSetHeight(pDB.Height)
    end
end

---oUF shows the bar on every update, so hide it again on a filtered-out member.
---@param element oUF.Power
---@param unit string
local function ApplyFilter(element, unit)
    local pDB = element.nuiFilter
    if not pDB then return end

    local shown = PassesFilter(unit, pDB)
    element:SetShown(shown)
    local frame = element.__owner
    frame.powerBackground:SetShown(shown)
    frame.powerBorderFrame:SetShown(shown)

    -- A docked bar coming or going moves the health bar, which is anchored to the secure frame.
    if element.nuiPasses ~= shown then
        element.nuiPasses = shown
        if pDB.Docked then NRSKNUI:RunWhenSafe(function() UF.LayoutBars(frame) end) end
    end
end
UF.ApplyPowerFilter = ApplyFilter

-- A role change moves nobody, so the frame's unit never changes and oUF has no reason to update.
local function RefreshFilter(frame)
    if frame.Power and frame.Power.nuiFilter then frame.Power:ForceUpdate() end
end

---Build the bar and its chrome.
---@param self oUF.UnitFrame
local function BuildPower(self)
    -- Power bar background frame
    local powerBackground = CreateFrame('Frame', nil, self)
    powerBackground:NCCreateBackdrop(true)
    self.powerBackground = powerBackground

    -- Power bar border frame
    local powerBorderFrame = CreateFrame('Frame', nil, self)
    powerBorderFrame:NCAddBorders()
    self.powerBorderFrame = powerBorderFrame

    -- Power bar
    local powerBar = CreateFrame('StatusBar', nil, self) --[[@as oUF.Power]]
    powerBar:NCDisablePixelSnap()
    powerBar.PostUpdate = UF.PostUpdatePower
    powerBar.PostUpdateColor = UF.PostUpdatePowerColor

    local costPrediction = CreateFrame('StatusBar', nil, powerBar)
    costPrediction:NCDisablePixelSnap()
    costPrediction:SetReverseFill(true)
    costPrediction:NCSetPoint('TOP')
    costPrediction:NCSetPoint('BOTTOM')
    costPrediction:NCSetPoint('RIGHT', powerBar:GetStatusBarTexture())
    powerBar.nuiCostPrediction = costPrediction

    self.Power = powerBar
end

---@class UnitFramesElements
---@field Power UnitFramesPowerElement
UF.Elements = UF.Elements or {}

---@class UnitFramesPowerElement
UF.Elements.Power = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.Power then return end
        if not Wanted(self, unit, UF.GetUnitDB(unit).Power) then return end

        BuildPower(self)
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local pDB = uDB.Power

        if not self.Power then
            if not Wanted(self, unit, pDB) then return end
            BuildPower(self)
        end

        local powerBar = self.Power
        local powerBackground = self.powerBackground
        local powerBorderFrame = self.powerBorderFrame

        powerBar:SetStatusBarTexture(NRSKNUI:GetStatusbar(general, pDB.StatusBarTexture))
        powerBar.nuiDB = pDB
        -- Only group frames filter; everyone else always passes.
        powerBar.nuiFilter = UF.GroupConfigs[self.nuiConfig or unit] and pDB or nil
        if not powerBar.nuiFilter then powerBar.nuiPasses = nil end
        UF.LayoutBars(self)

        -- Set background and border frame sizing
        powerBackground:ClearAllPoints()
        powerBackground:SetAllPoints(powerBar)
        powerBorderFrame:ClearAllPoints()
        powerBorderFrame:SetAllPoints(powerBar)

        --TODO: Keep looking for a better solution to the inital empty -> fill slide in effect.
        -- Only smoothing for the player's power bar.
        local smooth = pDB.UseGlobalSmooth and general.Smooth or (not pDB.UseGlobalSmooth and pDB.Smooth)
        powerBar.nuiSmoothing = ((smooth and unit == 'player') and Interpolation.ExponentialEaseOut) or Interpolation.Immediate
        powerBar.smoothing = Interpolation.Immediate

        -- Power type colouring, or a flat colour that PostUpdatePowerColor re-applies over oUF's pick.
        local colorByPower, color
        if pDB.UseGlobalColors then
            colorByPower = general.ColorByPower
            color = general.Colors.Power
        else
            colorByPower = pDB.ColorByPower
            color = pDB.Color
        end

        powerBar.colorPower = colorByPower
        powerBar.colorClass = false
        powerBar.colorReaction = false
        UF.CacheColor(powerBar, 'nuiColor', color)
        powerBar.nuiColorByPower = colorByPower

        local costDB = pDB.CostPrediction
        local showCost = unit == 'player' and costDB.Enabled
        local costPrediction = powerBar.nuiCostPrediction
        costPrediction:SetStatusBarTexture(NRSKNUI:GetStatusbar(general, pDB.StatusBarTexture))
        costPrediction:SetStatusBarColor(costDB.Color[1], costDB.Color[2], costDB.Color[3], costDB.Color[4])
        costPrediction:SetShown(showCost)
        powerBar.CostPrediction = showCost and costPrediction or nil

        -- oUF registers the cast events on enable only.
        if powerBar.nuiShowCost ~= nil and powerBar.nuiShowCost ~= showCost and self:IsElementEnabled('Power') then
            self:DisableElement('Power')
            self:EnableElement('Power')
        end
        powerBar.nuiShowCost = showCost

        -- The same handler every time, so oUF registers it once per frame.
        if powerBar.nuiFilter then
            self:RegisterEvent('PLAYER_ROLES_ASSIGNED', RefreshFilter, true)
            self:RegisterEvent('GROUP_ROSTER_UPDATE', RefreshFilter, true)
        end
    end,
}
