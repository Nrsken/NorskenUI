---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

--[[
We never know when an aura is up, the game does.
So its conditions just style the button and the game shows each part at the right time for us.
]]

local ipairs = ipairs

---What an aura trigger's conditions put on it: While Up and pandemic on its button, While Missing on the stand-in.
---@param display table
---@param triggerIndex number
---@return table<string, any> active, table? pandemicColor, table<string, any> pandemic, table<string, any> missing
function CDM:GetAuraConditionChanges(display, triggerIndex)
    local active, pandemicColor, pandemic, missing = {}, nil, {}, {}

    for _, condition in ipairs(display.Conditions or {}) do
        local check = condition.check or {}
        if check.trigger == triggerIndex and check.value ~= false then
            for _, change in ipairs(condition.changes or {}) do
                if check.variable == 'active' and change.property and change.property ~= 'sound' then
                    active[change.property] = change.value
                elseif check.variable == 'pandemic' and change.property == 'pandemicColor' then
                    pandemicColor = change.value
                elseif check.variable == 'pandemic' and change.property then
                    pandemic[change.property] = change.value
                elseif check.variable == 'missing' and change.property and change.property ~= 'sound' then
                    missing[change.property] = change.value
                end
            end
        end
    end

    return active, pandemicColor, pandemic, missing
end
