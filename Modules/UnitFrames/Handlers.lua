---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
local UF = NRSKNUI:GetModule('UnitFrames')

local UnitHealthMissing = UnitHealthMissing
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsConnected = UnitIsConnected
local UnitIsTapDenied = UnitIsTapDenied

---Prime the smoothing function for a health or power element.
---@param element table Health element
local function PrimeSmoothing(element)
    if element.smoothing ~= element.nuiSmoothing then
        element.smoothing = element.nuiSmoothing
    end
end

---Post-update function for health and power elements.
---@param element table Health element
---@param unit string
---@param cur number
---@param max number
---@param lossPerc number
function UF.PostUpdateHealth(element, unit, cur, max, lossPerc)
    local healthBackground = element.healthBackground
    if healthBackground then
        healthBackground:SetMinMaxValues(0, max)
        healthBackground:SetValue(UnitHealthMissing(unit, true), element.smoothing)

        -- Dead units sit at empty health, so the background bar fills the whole frame.
        local bg = UnitIsDeadOrGhost(unit) and NRSKNUI.Colors.status.Dead or element.nuiBackground
        healthBackground:SetStatusBarColor(bg[1], bg[2], bg[3], bg[4])
    end

    PrimeSmoothing(element)
end

---Post-update function for power elements.
---@param element table Power element
function UF.PostUpdatePower(element)
    PrimeSmoothing(element)
end

---Post-update function for health and power elements to set the color based on class or custom color.
---@param element oUF.Health
---@param unit string
function UF.PostUpdateHealthColor(element, unit)
    local fg = element.nuiForeground
    if not fg then return end

    local status = NRSKNUI.Colors.status

    -- oUF fills the bar to max for Offline units, so recolor the whole foreground and skip the hue logic.
    if not UnitIsConnected(unit) then
        local off = status.Disconnected
        element:SetStatusBarColor(off[1], off[2], off[3], off[4])
        return
    end

    -- Tapped mobs get the muted tapped tint.
    if UnitIsTapDenied(unit) then
        local tap = status.Tapped
        element:SetStatusBarColor(tap[1], tap[2], tap[3], tap[4] or fg[4])
        return
    end

    if element.nuiColorByClass then
        local r, g, b = element:GetStatusBarColor()
        element:SetStatusBarColor(r, g, b, fg[4])
    else
        element:SetStatusBarColor(fg[1], fg[2], fg[3], fg[4])
    end
end
