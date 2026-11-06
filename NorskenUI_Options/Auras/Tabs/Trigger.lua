---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local tinsert, tremove = table.insert, table.remove
local format = string.format
local CopyTable = CopyTable
local ipairs = ipairs

local Shared = NRSKNUI.CDMOptions
local Applier = Shared.Applier
local LinkedAuraTrigger = Shared.LinkedAuraTrigger
local NormalizeAuraTypes = Shared.NormalizeAuraTypes
local TRIGGER_DEFAULTS = Shared.TRIGGER_DEFAULTS
local TRIGGER_GROUPS = Shared.TRIGGER_GROUPS
local TRIGGER_LISTS = Shared.TRIGGER_LISTS
local TRIGGER_TYPES = Shared.TRIGGER_TYPES
local TriggerLabel = Shared.TriggerLabel
local TriggerRows = Shared.TriggerRows
local triggerOpen = Shared.triggerOpen

-- types that start on rows of their own height, an unused type row would leave a gap
local OWN_ROWS = { conditions = true }

---@param page table
---@param id string
local function BuildTriggerTab(page, id)
    local display = CDM:Get(id)
    local triggers = display.Triggers
    local apply = Applier(id)

    page:Card(L['Triggers'], 'all'):Rebuild(function(card)
        local function Edit(fn)
            fn()
            NormalizeAuraTypes(display)
            apply()
            card:Rebuild()
        end

        -- overlays sit outside the combination, as SelectLayer skips them: the game keeps whether they're up to itself;
        -- a lone aura is the whole display, so it still stands as its one trigger
        local combined, hasAura = {}, false
        for i, trigger in ipairs(triggers) do
            hasAura = hasAura or trigger.Type == 'aura' or trigger.Type == 'auraoverlay'
            if trigger.Type ~= 'auraoverlay' then
                combined[#combined + 1] = i
            end
        end

        if combined[1] then
            if card:Section(L['Trigger Combination'], {
                    key = 'cdm:combination',
                    collapsed = triggerOpen.combination,
                    onToggle = function()
                        triggerOpen.combination = not triggerOpen.combination or nil
                        card:Rebuild()
                    end,
                }) then
                local several = combined[2] ~= nil
                local activationModes, dynamic
                if several then
                    activationModes = { { value = 'any', text = L['Any Triggers'] }, { value = 'all', text = L['All Triggers'] } }
                    dynamic = { { value = 0, text = L['Dynamic information from first active trigger'] } }
                    for _, i in ipairs(combined) do
                        dynamic[#dynamic + 1] = { value = i, text = format(L['Dynamic information from Trigger %d'], i) }
                    end
                else
                    activationModes = { { value = 'any', text = format(L['Trigger %d'], combined[1]) } }
                end

                card:Row(rowH):Dropdown(L['Required for Activation'], {
                    width = 1,
                    notice = hasAura and { level = 'info', text = L["Aura triggers aren't part of the combination system, the game keeps them secret."] } or nil,
                    options = activationModes,
                    value = several and display.Activation or 'any',
                    callback = function(value) Edit(function() display.Activation = value ~= 'any' and value or nil end) end,
                })

                if several then
                    local pin = display.DynamicTrigger
                    local pinned = pin and triggers[pin] and triggers[pin].Type ~= 'aura' and triggers[pin].Type ~= 'auraoverlay'
                    card:Row(rowH):Dropdown(L['Dynamic Information'], {
                        width = 1,
                        options = dynamic,
                        value = pinned and pin or 0,
                        callback = function(value) Edit(function() display.DynamicTrigger = value ~= 0 and value or nil end) end,
                    })
                end
            end
            card:EndSection()
            card:Separator()
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
                    -- at the end as WA does, so no other trigger's number changes and %N. texts keep reading the same one
                    Edit(function()
                        triggers[#triggers + 1] = CopyTable(trigger)
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
                    typeRow = not OWN_ROWS[trigger.Type] and card:Row(rowH) or nil
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
                    -- hasAura is this build's, which every edit rebuilds; appended like any trigger: as the icon's only aura it becomes an overlay, which shows whatever its number
                    local aura = display.type == 'icon' and not hasAura and LinkedAuraTrigger(display)
                    if aura then
                        triggers[#triggers + 1] = aura
                    else
                        -- an empty one, as WA adds; copying trigger 1's spell left its Cooldown Manager pick blank
                        local new = CopyTable(TRIGGER_DEFAULTS.spell)
                        new.Type = 'spell'
                        triggers[#triggers + 1] = new
                    end
                end)
            end,
        })
    end)
end

Shared.BuildTriggerTab = BuildTriggerTab
