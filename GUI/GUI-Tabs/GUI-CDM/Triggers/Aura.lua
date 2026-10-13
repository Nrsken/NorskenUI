---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tinsert, tconcat = table.insert, table.concat
local ipairs = ipairs
local tonumber = tonumber

local GetMaxStacks = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications

local Shared = NRSKNUI.CDMOptions
local AURA_BAR_MODES, AURA_SOURCES, AURA_UNITS, CatalogueOptions = Shared.AURA_BAR_MODES, Shared.AURA_SOURCES, Shared.AURA_UNITS, Shared.CatalogueOptions
local CataloguePicker = Shared.CataloguePicker
local TriggerRows = Shared.TriggerRows

function TriggerRows.aura(card, typeRow, display, trigger, id, apply)
    local Category = Enum.CooldownViewerCategory
    local function set(key, value)
        trigger[key] = value
        apply()
    end

    typeRow:Dropdown(L['Source'], {
        width = 0.5,
        options = AURA_SOURCES,
        value = trigger.Source,
        callback = function(value)
            set('Source', value)
            card:Rebuild()
        end,
    })

    local auraRow = card:Row(rowH)
    if trigger.Source == 'custom' then
        auraRow:EditBox(L['Spell IDs'], {
            width = 0.5,
            tooltip = L['Aura spell IDs, separated by commas.'],
            value = trigger.SpellIDs and tconcat(trigger.SpellIDs, ', ') or '',
            callback = function(text)
                local ids = {}
                for number in text:gmatch('%d+') do ids[#ids + 1] = tonumber(number) end
                set('SpellIDs', ids)
            end,
        })
    else
        auraRow:Dropdown(L['Aura'], {
            width = 0.5,
            tooltip = L["Auras Blizzard's Cooldown Manager tracks for your current spec."],
            options = CatalogueOptions({ Category.TrackedBuff, Category.TrackedBar }),
            value = trigger.CooldownID,
            callback = CataloguePicker(trigger, display, id, apply),
        })
    end
    auraRow:Dropdown(L['Unit'], {
        width = 0.5,
        options = AURA_UNITS,
        value = trigger.Unit,
        callback = function(value) set('Unit', value) end,
    })

    local mineRow = card:Row(rowH)
    mineRow:Checkbox(L['Cast by Me'], {
        width = 0.5,
        value = trigger.OwnOnly,
        callback = function(checked) set('OwnOnly', checked) end,
    })
    if trigger.Type ~= 'aura' then return end
    local placeholder = {
        width = 0.5,
        tooltip = display.type == 'bar' and L['Keep the empty bar and its border up while the aura is missing. Its look is the While Missing condition.']
            or L['Keep the icon up while the aura is missing. Its look is the While Missing condition.'],
        value = trigger.Placeholder,
        callback = function(checked)
            trigger.Placeholder = checked or nil
            -- Its look is a While Missing condition, so it stays editable; a new one starts dimmed and grey.
            local index = tIndexOf(display.Triggers, trigger)
            local seeded = false
            for _, condition in ipairs(display.Conditions or {}) do
                if condition.check and condition.check.trigger == index and condition.check.variable == 'missing' then seeded = true end
            end
            if checked and index and not seeded then
                display.Conditions = display.Conditions or {}
                tinsert(display.Conditions, {
                    check = { trigger = index, variable = 'missing', value = true },
                    changes = { { property = 'desaturate', value = true }, { property = 'alpha', value = 0.5 } },
                })
            end
            apply()
        end,
    }
    if display.type ~= 'bar' then
        mineRow:Checkbox(L['Placeholder'], placeholder)
        return
    end

    -- A lone aura is the bar itself: its button fills it from the duration or the stacks.
    mineRow:Dropdown(L['Bar Shows'], {
        width = 0.5,
        tooltip = L['Duration drains with the time left; Stacks fills with the stack count. %p and %s work in both.'],
        options = AURA_BAR_MODES,
        value = trigger.BarMode or 'duration',
        callback = function(value)
            trigger.BarMode = value ~= 'duration' and value or nil
            if value == 'stacks' and not trigger.MaxStacks then
                -- The game's own cap, read once here (secret while auras are restricted); editable after.
                local spellID = CDM:GetTriggerSpell(trigger)
                local cap = spellID and GetMaxStacks(spellID)
                trigger.MaxStacks = cap and not NRSKNUI:IsSecretValue(cap) and cap > 0 and cap or 10
            end
            apply()
            card:Rebuild()
        end,
    })
    local barRow = card:Row(rowH)
    barRow:Checkbox(L['Placeholder'], placeholder)
    if trigger.BarMode == 'stacks' then
        barRow:Slider(L['Max Stacks'], {
            width = 0.5,
            tooltip = L['The stack count of a full bar.'],
            min = 1,
            max = 100,
            step = 1,
            value = trigger.MaxStacks or 10,
            callback = function(value) set('MaxStacks', value) end,
        })
    end
end

TriggerRows.auraoverlay = TriggerRows.aura
