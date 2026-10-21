---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tinsert, tremove = table.insert, table.remove
local ipairs = ipairs
local format = string.format
local CopyTable = CopyTable

local Shared = NRSKNUI.CDMOptions
local Applier, LinkedAuraTrigger, NormalizeAuraTypes, TRIGGER_DEFAULTS = Shared.Applier, Shared.LinkedAuraTrigger, Shared.NormalizeAuraTypes, Shared.TRIGGER_DEFAULTS
local TRIGGER_GROUPS, TRIGGER_LISTS, TRIGGER_TYPES, TriggerLabel, TriggerRows = Shared.TRIGGER_GROUPS, Shared.TRIGGER_LISTS, Shared.TRIGGER_TYPES, Shared.TriggerLabel, Shared.TriggerRows
local triggerOpen = Shared.triggerOpen

local ACTIVATION_MODES = {
    { value = 'any', text = L['Any Triggers'] },
    { value = 'all', text = L['All Triggers'] },
}

---@param page table
---@param id string
local function BuildTriggerTab(page, id)
    local display = CDM:Get(id)
    local triggers = display.Triggers
    local apply = Applier(id)

    local combination = page:Card(nil, 'all')
    combination:Rebuild(function(card)
        local function Edit(fn)
            fn()
            apply()
            card:Rebuild()
        end

        if card:Section(L['Trigger Combination'], {
                key = 'cdm:combination',
                collapsed = not triggerOpen.combination,
                onToggle = function()
                    triggerOpen.combination = not triggerOpen.combination or nil
                    card:Rebuild()
                end,
            }) then
            card:Row(rowH):Dropdown(L['Required for Activation'], {
                width = 1,
                tooltip = L["Aura triggers don't count toward trigger combination, the game doesn't tell addons whether an aura is up or not."],
                options = ACTIVATION_MODES,
                value = display.Activation or 'any',
                callback = function(value) Edit(function() display.Activation = value ~= 'any' and value or nil end) end,
            })
            local dynamic = { { value = 0, text = L['Dynamic information from first active trigger'] } }
            for i in ipairs(triggers) do
                dynamic[#dynamic + 1] = { value = i, text = format(L['Dynamic information from Trigger %d'], i) }
            end
            card:Row(rowH):Dropdown(L['Dynamic Information'], {
                width = 1,
                tooltip = L['The trigger whose icon, texts and conditions the display shows while it is active. An aura trigger only has something to show while its aura is up.'],
                options = dynamic,
                value = display.DynamicTrigger or 0,
                callback = function(value) Edit(function() display.DynamicTrigger = value ~= 0 and value or nil end) end,
            })
        end
        card:EndSection()
    end)

    page:Card(L['Triggers'], 'all'):Rebuild(function(card)
        local function Edit(fn)
            fn()
            NormalizeAuraTypes(display)
            apply()
            card:Rebuild()
            combination:Rebuild() -- its Dynamic Information lists one entry per trigger
        end
        -- Aura alone, Aura Overlay beside other triggers; a group takes its first member's place.
        local types, members, groupOf = {}, {}, {}
        for _, entry in ipairs(TRIGGER_LISTS[display.type] or TRIGGER_TYPES) do
            local group = entry.group
            if group then
                if not members[group] then
                    members[group] = {}
                    types[#types + 1] = { value = group, text = TRIGGER_GROUPS[group] }
                end
                tinsert(members[group], entry)
                groupOf[entry.value] = group
            elseif not (entry.value == 'aura' and #triggers > 1 or entry.value == 'auraoverlay' and #triggers == 1) then
                types[#types + 1] = entry
            end
        end

        for index, trigger in ipairs(triggers) do
            local title = TriggerLabel(index, trigger)

            local open = triggerOpen[index]
            if open == nil then open = #triggers == 1 end

            local expanded = card:Section(title, {
                key = 'cdm:trigger:' .. index,
                collapsed = not open,
                onToggle = function()
                    triggerOpen[index] = not open
                    card:Rebuild()
                end,
                onMoveUp = index > 1 and function()
                    Edit(function()
                        triggers[index], triggers[index - 1] = triggers[index - 1], triggers[index]
                        CDM:RemapConditionTriggers(display, function(t) return t == index and index - 1 or t == index - 1 and index or t end)
                    end)
                end or nil,
                onMoveDown = index < #triggers and function()
                    Edit(function()
                        triggers[index], triggers[index + 1] = triggers[index + 1], triggers[index]
                        CDM:RemapConditionTriggers(display, function(t) return t == index and index + 1 or t == index + 1 and index or t end)
                    end)
                end or nil,
                onDuplicate = function()
                    Edit(function()
                        tinsert(triggers, index + 1, CopyTable(trigger))
                        CDM:RemapConditionTriggers(display, function(t) return t > index and t + 1 or t end)
                    end)
                end,
                onDelete = #triggers > 1 and function()
                    Edit(function()
                        tremove(triggers, index)
                        CDM:RemapConditionTriggers(display, function(t)
                            if t == index then return nil end
                            return t > index and t - 1 or t
                        end)
                    end)
                end or nil,
            })

            if expanded then
                local function SetType(value)
                    if value == trigger.Type then return end
                    Edit(function()
                        local new = (value == 'aura' or value == 'auraoverlay') and LinkedAuraTrigger(display) or CopyTable(TRIGGER_DEFAULTS[value])
                        new.Type = value
                        triggers[index] = new
                    end)
                end

                local group = groupOf[trigger.Type]
                local typeRow = card:Row(rowH)
                typeRow:Dropdown(L['Type'], {
                    width = 0.5,
                    options = types,
                    value = group or trigger.Type,
                    callback = function(value)
                        if value == group then return end
                        SetType(members[value] and members[value][1].value or value)
                    end,
                })
                -- the group's own dropdown takes the type row, so the type's rows start below it
                if group then
                    typeRow:Dropdown(nil, {
                        width = 0.5,
                        options = members[group],
                        value = trigger.Type,
                        callback = SetType,
                    })
                    typeRow = card:Row(rowH)
                end

                local rows = TriggerRows[trigger.Type]
                if rows then rows(card, typeRow, display, trigger, id, apply) end
            end
        end
        card:EndSection()

        card:Separator()

        card:Row(30, 0):Button(L['Add Trigger'], {
            width = 1,
            height = 24,
            callback = function()
                Edit(function()
                    local hasAura = false
                    for _, trigger in ipairs(triggers) do
                        if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then hasAura = true end
                    end
                    local aura = display.type == 'icon' and not hasAura and LinkedAuraTrigger(display)
                    if aura then
                        tinsert(triggers, 1, aura)
                        CDM:RemapConditionTriggers(display, function(t) return t + 1 end)
                    else
                        triggers[#triggers + 1] = { Type = 'spell', SpellID = triggers[1] and triggers[1].SpellID }
                    end
                end)
            end,
        })
    end)
end

Shared.BuildTriggerTab = BuildTriggerTab
