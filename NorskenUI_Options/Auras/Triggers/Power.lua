---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local ipairs = ipairs
local format = string.format

local Shared = NRSKNUI.CDMOptions
local CatalogueOptions = Shared.CatalogueOptions
local POWER_MODES = Shared.POWER_MODES
local TriggerRows = Shared.TriggerRows

function TriggerRows.power(card, typeRow, display, trigger, id, apply)
    typeRow:Dropdown(L['Power Type'], {
        width = 0.5,
        tooltip = L['Primary Power follows your form and spec.'],
        options = CDM.POWER_TYPES,
        value = trigger.PowerType or 'primary',
        callback = function(value)
            trigger.PowerType = value ~= 'primary' and value or nil
            if not CDM.SEGMENTED_POWER[trigger.PowerType] then trigger.Mode = nil end
            if trigger.PowerType == CDM.MAELSTROM_WEAPON and trigger.Mode == 'progress' then trigger.Mode = 'static' end
            apply()
            card:Rebuild()
        end,
    })
    if display.type ~= 'bar' or not CDM.SEGMENTED_POWER[trigger.PowerType] then return end

    local Power = Enum.PowerType
    local pType = trigger.Mode == 'progress' and trigger.PowerType ~= Power.Runes and trigger.PowerType ~= Power.Essence

    local modes = {}
    for _, mode in ipairs(POWER_MODES) do
        -- A stack has no partial fill to show.
        if not (mode.value == 'progress' and trigger.PowerType == CDM.MAELSTROM_WEAPON) then
            modes[#modes + 1] = { value = mode.value, text = mode.text, tooltip = format(mode.description, CDM.POWER_NAMES[trigger.PowerType]) }
        end
    end
    local row = card:Row(rowH)
    row:Dropdown(L['Mode'], {
        width = pType and 0.5 or 1,
        options = modes,
        value = trigger.Mode or 'bar',
        callback = function(value)
            trigger.Mode = value ~= 'bar' and value or nil
            apply()
            card:Rebuild()
        end,
    })
    if pType then
        local sources = { { value = 0, text = L['None'] } }
        for _, option in ipairs(CatalogueOptions({ Enum.CooldownViewerCategory.TrackedBar })) do sources[#sources + 1] = option end
        row:Dropdown(L['Progress Source'], {
            width = 0.5,
            tooltip = format(L['A Cooldown Manager bar that fills the next %s, like Crusading Strikes.'], CDM.PIP_NAMES[trigger.PowerType]),
            options = sources,
            value = trigger.ProgressCooldownID or 0,
            callback = function(value)
                trigger.ProgressCooldownID = value ~= 0 and value or nil
                apply()
            end,
        })
    end
end
