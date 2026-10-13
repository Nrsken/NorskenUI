---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Thumbnail = NRSKNUI.CDMThumbnail
local Theme = NRSKNUI.Theme
local AuraCards = NRSKNUI.GUIAuraCards
local TriggerEditor = NRSKNUI.GUITriggerEditor
local IconPicker = NRSKNUI.CDMIconPicker
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local tinsert, tremove, tconcat = table.insert, table.remove, table.concat
local pairs, ipairs = pairs, ipairs
local tostring = tostring
local format = string.format
local tonumber = tonumber
local CopyTable = CopyTable
local floor = math.floor
local RunNextFrame = RunNextFrame

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local GetSpellName = C_Spell and C_Spell.GetSpellName
local GetMaxStacks = C_Spell and C_Spell.GetSpellMaxCumulativeAuraApplications
local GetItemIconByID = C_Item and C_Item.GetItemIconByID
local GetItemNameByID = C_Item and C_Item.GetItemNameByID

local PAGE = 'cooldownManager'
local GENERAL = 'cdm:general'
local TRINKETS = 'cdm:trinkets'
local SETTINGS = 'cdm:settings'
local IMPORT = 'cdm:import'
local SECTION_LOADED = 'cdm:section:loaded'
local SECTION_UNLOADED = 'cdm:section:unloaded'
local QUESTION_MARK = 134400
local NEW_TILE_HEIGHT = 104
local NEW_TILE_ICON = 44
local NEW_TILE_PREVIEW = 74 -- a picture's width: fills a tile at the narrowest window
local POWER_MODES = {
    { value = 'bar',      text = L['Static Single Bar'],   description = L['One bar for all your %s.'] },
    { value = 'static',   text = L['Static Segments'],     description = L['One segment each, filled while it is ready, empty otherwise.'] },
    { value = 'progress', text = L['Recharging Segments'], description = L['Like Static Segments but each one fills up as it recharges.'] },
}

-- WeakAuras' tab order; the ones without settings yet stay empty.
local TABS = {
    { id = 'group',       text = L['Group'] },
    { id = 'display',     text = L['Display'] },
    { id = 'trigger',     text = L['Trigger'] },
    { id = 'conditions',  text = L['Conditions'] },
    { id = 'actions',     text = L['Actions'] },
    { id = 'animations',  text = L['Animations'] },
    { id = 'load',        text = L['Load'] },
    { id = 'custom',      text = L['Custom Options'] },
    { id = 'information', text = L['Information'] },
}

-- An aura group only has what the Auras page gave it, and its look is split from where it sits.
local AURA_GROUP_TABS = {
    { id = 'display',     text = L['Display'] },
    { id = 'layout',      text = L['Layout'] },
    { id = 'trigger',     text = L['Trigger'] },
    { id = 'load',        text = L['Load'] },
    { id = 'information', text = L['Information'] },
}

local TYPE_NAMES = {
    icon = L['Icon'],
    bar = L['Progress Bar'],
    text = L['Text'],
    group = L['Group'],
    dynamicgroup = L['Dynamic Group'],
    auragroup = L['Aura Group'],
}

local expandedGroups = {} -- [group id] = true, for the session; groups start collapsed

---@return table? tree
local function Tree()
    local content = NRSKNUI.GUIFrame and NRSKNUI.GUIFrame.content
    return content and content.miniSidebar
end

local function Reopen(selectKey)
    local window = NRSKNUI.GUIFrame
    if not (window and window.content) then return end

    if selectKey and CDM:Get(selectKey) then
        for _, ancestor in ipairs(CDM:GetAncestors(selectKey)) do
            expandedGroups[ancestor] = true
        end
    end
    window.content:ShowPage(PAGE, selectKey and { itemKey = selectKey } or nil)
end

IconPicker.navigate = Reopen

local function RefreshTree()
    local tree = Tree()
    if tree and tree.frame:IsShown() and tree.Render then
        tree:Render()
    end
end

local function EnsureModuleEnabled()
    if CDM.db.Enabled then return end
    CDM.db.Enabled = true
    NRSKNUI:ToggleModule('CDM', true)
end

---@param id string?
---@return fun()
local function Applier(id)
    return function() CDM:ApplySettings(id) end
end

---@param key string
---@return boolean
local function IsCollapsed(key)
    return NRSKNUI.db.global.SidebarCollapsed[PAGE][key] == true
end

-- Tabs --

---@param page table
---@param id string
local function PositionCard(page, id)
    local display = CDM:Get(id)
    page:PositionCard({
        title = L['Position and Size Settings'],
        db = display,
        showAnchorFrameType = not CDM:IsDynamic(display.parent), -- inside a static group, Screen means the group
        showStrata = display.parent == nil,
        disableAnchorFrom = display.type == 'dynamicgroup',      -- a dynamic group anchors from its grow direction
        onChangeCallback = Applier(id),
    })
end

local TRIGGER_TYPES = {
    { value = 'spell',       text = L['Cooldown'] },
    { value = 'aura',        text = L['Aura'] },
    { value = 'auraoverlay', text = L['Aura Overlay'] },
    { value = 'item',        text = L['Item'] },
    { value = 'timer',       text = L['Cast Timer'] },
    { value = 'totem',       text = L['Totem'] },
}
local BAR_TRIGGER_TYPES = {
    { value = 'cast',        text = L['Cast'] },
    { value = 'power',       text = L['Power'] },
    { value = 'aura',        text = L['Aura'] },
    { value = 'stat',        text = L['Player Stat'] },
    { value = 'viewerbar',   text = L['Cooldown Bar'] },
    { value = 'spell',       text = L['Cooldown'] },
    { value = 'item',        text = L['Item'] },
    { value = 'timer',       text = L['Cast Timer'] },
    { value = 'auraoverlay', text = L['Aura Overlay'] },
}
-- No auras: an aura draws through a native aura button, which a text has none of.
local TEXT_TRIGGER_TYPES = {
    { value = 'spell', text = L['Cooldown'] },
    { value = 'power', text = L['Power'] },
    { value = 'stat',  text = L['Player Stat'] },
    { value = 'cast',  text = L['Cast'] },
    { value = 'item',  text = L['Item'] },
    { value = 'timer', text = L['Cast Timer'] },
}
local TRIGGER_LISTS = { bar = BAR_TRIGGER_TYPES, text = TEXT_TRIGGER_TYPES }
local TRIGGER_NAMES = {}
for _, entry in ipairs(TRIGGER_TYPES) do TRIGGER_NAMES[entry.value] = entry.text end
for _, entry in ipairs(BAR_TRIGGER_TYPES) do TRIGGER_NAMES[entry.value] = entry.text end
local CAST_ICON = 'Interface\\Icons\\INV_Misc_PocketWatch_01'

-- What a trigger starts with when it's added or its type changes.
local TRIGGER_DEFAULTS = {
    spell       = {},
    aura        = { Source = 'cdm', Unit = 'player', OwnOnly = true },
    auraoverlay = { Source = 'cdm', Unit = 'player', OwnOnly = true },
    item        = { Item = 'trinket1', HidePassive = true },
    timer       = { Duration = 8 },
    totem       = {},
    power       = {},
    viewerbar   = {},
    cast        = { HoldTime = 0.5, ShowLatency = true },
    stat        = { Stat = 'haste' },
}
local AURA_SOURCES = {
    { value = 'cdm',    text = L['Cooldown Manager'] },
    { value = 'custom', text = L['Custom'] },
}
local AURA_BAR_MODES = {
    { value = 'duration', text = L['Duration'] },
    { value = 'stacks',   text = L['Stacks'] },
}
local AURA_UNITS = {
    { value = 'player', text = L['Player'] },
    { value = 'target', text = L['Target'] },
}
local ITEMS = {
    { value = 'trinket1',     text = L['Trinket 1'] },
    { value = 'trinket2',     text = L['Trinket 2'] },
    { value = 'healthstone',  text = L['Healthstone'] },
    { value = 'combatPotion', text = L['Combat Potion'] },
    { value = 'custom',       text = L['Custom Item'] },
}
local triggerOpen = {} -- [index] = open, for the session; a lone trigger starts open

---'Trigger 2: Aura', the name the Conditions tab gives a trigger.
---@param index number
---@param trigger table
---@return string
local function TriggerTitle(index, trigger)
    return format(L['Trigger %d: %s'], index, TRIGGER_NAMES[trigger.Type] or trigger.Type)
end

---'[icon] Flame Shock', the name the Conditions tab gives the layer a trigger draws; its title when it has no name.
---@param index number
---@param trigger table
---@return string
local function TriggerChip(index, trigger)
    local name = CDM:GetTriggerName(trigger)
    if not name then return TriggerTitle(index, trigger) end
    local texture = CDM:GetTriggerTexture(trigger)
    return texture and format('|T%s:0:0:0:0:64:64:5:59:5:59|t %s', texture, name) or name
end

---'Trigger 2: Aura - [icon] Flame Shock', the name the Trigger tab gives a trigger.
---@param index number
---@param trigger table
---@return string
local function TriggerLabel(index, trigger)
    local label = TriggerTitle(index, trigger)
    return CDM:GetTriggerName(trigger) and (label .. ' - ' .. TriggerChip(index, trigger)) or label
end
local trinketReturnKey ---@type string?

---An aura alone is the icon; beside other triggers it's an overlay on them, which starts with the aura's own icon.
---@param display table
local function NormalizeAuraTypes(display)
    local triggers = display.Triggers
    local alone = #triggers == 1
    for index, trigger in ipairs(triggers) do
        if trigger.Type == 'aura' and not alone then
            trigger.Type = 'auraoverlay'
            display.Conditions = display.Conditions or {}
            tinsert(display.Conditions, { check = { trigger = index, variable = 'active', value = true }, changes = { { property = 'auraIcon', value = true } } })
        elseif trigger.Type == 'auraoverlay' and alone then
            trigger.Type = 'aura'
        end
    end
end

---A new aura trigger for the Cooldown Manager aura that shares a spell with one of the icon's cooldowns.
---@param display table
---@return table? trigger
local function LinkedAuraTrigger(display)
    for _, trigger in ipairs(display.Triggers) do
        local cooldownID = trigger.Type == 'spell' and trigger.SpellID and CDM.Catalogue:FindBySpell(trigger.SpellID, 'aura')
        local info = cooldownID and CDM.Catalogue:GetEntry(cooldownID)
        if info then
            local new = CopyTable(TRIGGER_DEFAULTS.aura)
            new.Type, new.CooldownID, new.SpellID = 'aura', cooldownID, info.spellID
            return new
        end
    end
end

---Every spell the Cooldown Manager has for these categories: known ones first, the rest dimmed after them.
---@param categories number[] Enum.CooldownViewerCategory values
---@return table[] options
local function CatalogueOptions(categories)
    local known, unknown = {}, {}
    local muted = Theme.textMuted
    local tint = format('%d:%d:%d', floor(muted[1] * 255 + 0.5), floor(muted[2] * 255 + 0.5), floor(muted[3] * 255 + 0.5))
    for _, category in ipairs(categories) do
        for _, cooldownID in ipairs(CDM.Catalogue:GetList(category)) do
            local info = CDM.Catalogue:GetEntry(cooldownID)
            if info and info.spellID then
                local texture = GetSpellTexture(info.spellID) or QUESTION_MARK
                local name = GetSpellName(info.spellID) or info.spellID
                if info.isKnown then
                    known[#known + 1] = { value = cooldownID, spellID = info.spellID, text = format('|T%d:16:16:0:0:64:64:5:59:5:59|t %s', texture, name) }
                else
                    unknown[#unknown + 1] = {
                        value = cooldownID,
                        spellID = info.spellID,
                        text = format('|T%d:16:16:0:0:64:64:5:59:5:59:%s|t %s', texture, tint, name),
                        color = muted,
                    }
                end
            end
        end
    end
    for _, option in ipairs(unknown) do known[#known + 1] = option end
    return known
end

---@param trigger table
---@param display table
---@param id string
---@param apply fun()
---@return fun(cooldownID: number)
local function CataloguePicker(trigger, display, id, apply)
    return function(cooldownID)
        local info = CDM.Catalogue:GetEntry(cooldownID)
        if not info or cooldownID == trigger.CooldownID then return end
        -- A new icon, or one still named after its spell, takes the new spell's name.
        if display.name == L['New Icon'] or (trigger.SpellID and display.name == GetSpellName(trigger.SpellID)) then
            display.name = GetSpellName(info.spellID) or display.name
        end
        trigger.SpellID = info.spellID
        trigger.CooldownID = cooldownID
        apply()
        Reopen(id)
    end
end

-- Rows per trigger type: the first row opens with the Type dropdown, the rest follow.
local TriggerRows = {}

function TriggerRows.spell(card, typeRow, display, trigger, id, apply)
    local Category = Enum.CooldownViewerCategory
    typeRow:Dropdown(L['Cooldown Manager'], {
        width = 0.5,
        tooltip = L["Spells Blizzard's Cooldown Manager tracks for your current spec."],
        options = CatalogueOptions({ Category.Essential, Category.Utility }),
        value = trigger.CooldownID,
        callback = CataloguePicker(trigger, display, id, apply),
    })
    card:Row(rowH):Checkbox(L['Ignore Override'], {
        width = 0.5,
        tooltip = L["Keep tracking this spell's own cooldown and charges while another spell replaces it."],
        value = trigger.IgnoreOverride,
        callback = function(checked)
            trigger.IgnoreOverride = checked or nil
            apply()
        end,
    })
end

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

function TriggerRows.stat(card, typeRow, display, trigger, id, apply)
    local options = {}
    for _, stat in ipairs(CDM.STATS) do options[#options + 1] = { value = stat.key, text = stat.name } end
    typeRow:Dropdown(L['Stat'], {
        width = 0.5,
        tooltip = L['%p is the percent, %t the rating, as the character sheet shows them. Versatility is its rating part.'],
        options = options,
        value = trigger.Stat or 'haste',
        callback = function(value)
            trigger.Stat = value
            apply()
        end,
    })
end

function TriggerRows.item(card, typeRow, display, trigger, id, apply)
    typeRow:Dropdown(L['Item'], {
        width = 0.5,
        options = ITEMS,
        value = trigger.Item,
        callback = function(value)
            trigger.Item = value
            apply()
            card:Rebuild()
        end,
    })
    if trigger.Item == 'trinket1' or trigger.Item == 'trinket2' then
        local trinketRow = card:Row(rowH)
        trinketRow:Checkbox(L['Hide Passive Trinkets'], {
            width = 0.5,
            tooltip = L['A trinket without an on-use effect is not tracked.'],
            value = trigger.HidePassive,
            callback = function(checked)
                trigger.HidePassive = checked
                apply()
            end,
        })
        trinketRow:Button(L['Trinket Blacklist'], {
            width = 0.5,
            height = 24,
            yOffset = -14,
            tooltip = L['Trinkets that are never tracked, for on-use effects that only switch a mode.'],
            callback = function()
                trinketReturnKey = id
                Reopen(TRINKETS)
            end,
        })
    elseif trigger.Item == 'custom' then
        local itemRow = card:Row(rowH)
        itemRow:EditBox(L['Item ID'], {
            width = 0.5,
            value = trigger.ItemID and tostring(trigger.ItemID) or '',
            callback = function(text)
                trigger.ItemID = tonumber(text)
                apply()
                card:Rebuild()
            end,
        })
        itemRow:Icon({
            width = 0.1,
            size = 24,
            yOffset = -14,
            texture = trigger.ItemID and GetItemIconByID(trigger.ItemID) or QUESTION_MARK,
            tooltip = function(tooltip)
                if trigger.ItemID then tooltip:SetItemByID(trigger.ItemID) end
            end,
        })
    end
    if trigger.Item ~= 'trinket1' and trigger.Item ~= 'trinket2' then
        card:Row(rowH):Checkbox(L['Show When Not in Bags'], {
            width = 0.5,
            tooltip = L["Keep showing the item even when not in bags."],
            value = trigger.ShowNotOwned,
            callback = function(checked)
                trigger.ShowNotOwned = checked or nil
                apply()
            end,
        })
    end
end

function TriggerRows.timer(card, typeRow, display, trigger, id, apply)
    typeRow:EditBox(L['Spell ID'], {
        width = 0.5,
        tooltip = L['The timer starts when you cast this spell.'],
        value = trigger.SpellID and tostring(trigger.SpellID) or '',
        callback = function(text)
            trigger.SpellID = tonumber(text)
            apply()
            card:Rebuild()
        end,
    })
    card:Row(rowH):Slider(L['Duration'], {
        width = 0.5,
        min = 1,
        max = 60,
        step = 0.5,
        value = trigger.Duration,
        callback = function(value)
            trigger.Duration = value
            apply()
        end,
    })
end

function TriggerRows.power(card, typeRow, display, trigger, id, apply)
    typeRow:Dropdown(L['Power Type'], {
        width = 0.5,
        tooltip = L['Primary Power follows your form and spec.'],
        options = CDM.POWER_TYPES,
        value = trigger.PowerType or 'primary',
        callback = function(value)
            trigger.PowerType = value ~= 'primary' and value or nil
            if not CDM.SEGMENTED_POWER[trigger.PowerType] then trigger.Mode = nil end
            apply()
            card:Rebuild()
        end,
    })
    if display.type ~= 'bar' or not CDM.SEGMENTED_POWER[trigger.PowerType] then return end

    local Power = Enum.PowerType
    local pType = trigger.Mode == 'progress' and trigger.PowerType ~= Power.Runes and trigger.PowerType ~= Power.Essence

    local modes = {}
    for i, mode in ipairs(POWER_MODES) do
        modes[i] = { value = mode.value, text = mode.text, tooltip = format(mode.description, CDM.POWER_NAMES[trigger.PowerType]) }
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

function TriggerRows.cast(card, typeRow, display, trigger, id, apply)
    local ids = {}
    for _, spellID in ipairs(trigger.SpellIDs or {}) do ids[#ids + 1] = tostring(spellID) end
    typeRow:EditBox(L['Spell IDs'], {
        width = 0.5,
        tooltip = L['Only these spells, comma separated. Empty shows every cast.'],
        value = tconcat(ids, ', '),
        callback = function(text)
            local list = {}
            for number in text:gmatch('%d+') do list[#list + 1] = tonumber(number) end
            trigger.SpellIDs = list[1] and list or nil
            apply()
            card:Rebuild()
        end,
    })

    local row = card:Row(rowH)
    row:Slider(L['Hold Time'], {
        width = 0.5,
        tooltip = L['Keep the bar up this long after the cast ends, for the Succeeded / Interrupted / Failed conditions. 0 hides it at once.'],
        min = 0,
        max = 3,
        step = 0.1,
        value = trigger.HoldTime or 0,
        callback = function(value)
            trigger.HoldTime = value
            apply()
        end,
    })
    row:Checkbox(L['Show Latency'], {
        width = 0.5,
        tooltip = L['Shades the end of the bar by the time your cast took to reach the server. Its color is on the Display tab.'],
        value = trigger.ShowLatency,
        callback = function(checked)
            trigger.ShowLatency = checked
            apply()
        end,
    })
end

function TriggerRows.viewerbar(card, typeRow, display, trigger, id, apply)
    typeRow:Dropdown(L['Cooldown Manager'], {
        width = 0.5,
        tooltip = L['A Tracked Bar from the Cooldown Manager, mirrored onto this bar. For entries that are not real auras, like Crusading Strikes.'],
        options = CatalogueOptions({ Enum.CooldownViewerCategory.TrackedBar }),
        value = trigger.CooldownID,
        callback = CataloguePicker(trigger, display, id, apply),
    })
end

function TriggerRows.totem(card, typeRow, display, trigger, id, apply)
    local Category = Enum.CooldownViewerCategory
    typeRow:Dropdown(L['Cooldown Manager'], {
        width = 0.5,
        tooltip = L['The spell that summons the totem.'],
        options = CatalogueOptions({ Category.Essential, Category.Utility }),
        value = trigger.CooldownID,
        callback = CataloguePicker(trigger, display, id, apply),
    })
end

local ACTIVATION_MODES = {
    { value = 'any', text = L['Any Triggers'] },
    { value = 'all', text = L['All Triggers'] },
}

---WeakAuras' trigger list: the first active trigger is the one shown, so the order is the priority.
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
        -- Aura alone, Aura Overlay beside other triggers.
        local types = {}
        for _, entry in ipairs(TRIGGER_LISTS[display.type] or TRIGGER_TYPES) do
            if not (entry.value == 'aura' and #triggers > 1 or entry.value == 'auraoverlay' and #triggers == 1) then types[#types + 1] = entry end
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
                local typeRow = card:Row(rowH)
                typeRow:Dropdown(L['Type'], {
                    width = 0.5,
                    options = types,
                    value = trigger.Type,
                    callback = function(value)
                        if value == trigger.Type then return end
                        Edit(function()
                            local new = (value == 'aura' or value == 'auraoverlay') and LinkedAuraTrigger(display) or CopyTable(TRIGGER_DEFAULTS[value])
                            new.Type = value
                            triggers[index] = new
                        end)
                    end,
                })
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
                    -- A cooldown with a matching aura gets it on top, WeakAuras' aura-over-cooldown pair.
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

local ANCHOR_ROLES = {
    { value = 'none',      text = L['None'] },
    { value = 'primary',   text = L['Primary'] },
    { value = 'secondary', text = L['Secondary'] },
}

local function ScheduleAnchorUpdate()
    local UF = NRSKNUI.UnitFrames
    if UF:IsEnabled() then UF:ScheduleCDMAnchorUpdate() end
end

---@param page table
---@param id string
local function BuildGroupTab(page, id)
    local display = CDM:Get(id)
    local apply = Applier(id)

    if display.type == 'dynamicgroup' then
        page:DynamicGroupCard({ title = L['Dynamic Group Settings'], db = display.Layout, onChangeCallback = apply })
        page:Card(L['Unit Frame Anchor'], 'all'):Row(rowHL, 0):Dropdown(L['Anchor Role'], {
            width = 1,
            options = ANCHOR_ROLES,
            value = display.UFAnchor or 'none',
            tooltip = L['The unit frame anchor follows the loaded group with this role. Give one group per class or spec the Primary role.'],
            callback = function(value)
                display.UFAnchor = value ~= 'none' and value or nil
                ScheduleAnchorUpdate()
            end,
        })
    end

    local iconRow = page:Card(L['Group Icon'], 'all'):Row(rowHL, 0)
    iconRow:EditBox(L['Icon ID'], {
        width = 0.9,
        tooltip = L['The icon this group shows in the list. Empty uses its first icon.'],
        value = display.Icon and tostring(display.Icon) or '',
        callback = function(text)
            display.Icon = tonumber(text)
            RefreshTree()
        end,
    })
    IconPicker:BrowseButton(iconRow, display.Icon, function()
        IconPicker:Open(display.Icon, function(texture)
            display.Icon = texture
            RefreshTree()
        end)
    end)

    PositionCard(page, id)
end

---Any debuff branch earns an aura group its dispel settings, as on the Auras page.
---@param trigger table?
---@return boolean
local function HasHarmful(trigger)
    local helpful = AuraUtil.AuraFilters.Helpful
    if trigger == nil or trigger.Base ~= helpful then return true end
    for _, branch in ipairs(trigger.branches or {}) do
        if (branch.type or trigger.Base) ~= helpful then return true end
    end
    return false
end

local auraSectionOpen = {} -- [title] = true, for the session; sections start closed as on an icon's Display tab

-- What a collapsed section's rows build into: every widget call does nothing.
local NULL_ROW = setmetatable({}, { __index = function() return function() end end })
local NULL_CARD = { Row = function() return NULL_ROW end, Separator = function() end }

---Lets the Auras page cards build as collapsible sections of one card, the way an icon's Display tab is laid out.
---@param page table
---@param card table
---@return table
local function SectionPage(page, card)
    return {
        Card = function(_, title)
            local open = card:Section(title, {
                key = 'cdm:aura:' .. title,
                collapsed = not auraSectionOpen[title],
                onToggle = function()
                    auraSectionOpen[title] = not auraSectionOpen[title] or nil
                    card:Rebuild()
                end,
            })
            return open and card or NULL_CARD
        end,
        SetCondition = function(_, ...) return page:SetCondition(...) end,
        Refresh = function() page:Refresh() end,
    }
end

---@param id string
---@return table ctx what the Auras page cards read
local function AuraCardContext(id)
    return { Apply = Applier(id), filtered = true, dispelIconKey = 'showDebuffDispelIcon', withoutDispelType = true }
end

---An aura group's look, sectioned like an icon's: the list icon, the swipe, the texts, then the rest.
---@param page table
---@param id string
local function BuildAuraGroupDisplayTab(page, id)
    local display = CDM:Get(id)
    local ctx = AuraCardContext(id)
    local Heading = NRSKNUI.CDMDisplayTab.Heading

    page:Card(L['Display'], 'all'):Rebuild(function(card)
        local sections = SectionPage(page, card)
        Heading(card, L['Icon'])
        local iconRow = sections:Card(L['Icon Settings']):Row(rowHL, 0)
        iconRow:EditBox(L['Icon ID'], {
            width = 0.9,
            tooltip = L['The icon this aura group shows in the list. Empty uses its first spell.'],
            value = display.Icon and tostring(display.Icon) or '',
            callback = function(text)
                display.Icon = tonumber(text)
                RefreshTree()
            end,
        })
        IconPicker:BrowseButton(iconRow, display.Icon, function()
            IconPicker:Open(display.Icon, function(texture)
                display.Icon = texture
                RefreshTree()
            end)
        end)
        AuraCards:Cooldown(sections, display, ctx)
        Heading(card, L['Sub Elements'])
        AuraCards:Text(sections, display, ctx)
        Heading(card, L['General'])
        if HasHarmful(display.Trigger) then AuraCards:Dispel(sections, display, ctx) end
        AuraCards:Tooltip(sections, display, ctx)
    end)

    page:FontSettingsCard({
        db = display,
        includeSoftOutline = true,
        globalOverride = {},
        hideFontSize = true, -- each string's size sits with the rest of its settings in its section
        onChangeCallback = ctx.Apply,
    })
    AuraCards:Reload(page)
end

---Where an aura group's auras go: the grid, its growth and order, then the group's own position.
---@param page table
---@param id string
local function BuildAuraGroupLayoutTab(page, id)
    local display = CDM:Get(id)
    local ctx = AuraCardContext(id)

    page:Card(L['Layout'], 'all'):Rebuild(function(card)
        local sections = SectionPage(page, card)
        AuraCards:Grid(sections, display, ctx)
        AuraCards:Growth(sections, display, ctx)
        AuraCards:Sorting(sections, display, ctx)
    end)
    PositionCard(page, id)
end

---@param page table
---@param id string
local function BuildDisplayTab(page, id)
    local display = CDM:Get(id)
    if display.type == 'auragroup' then
        BuildAuraGroupDisplayTab(page, id)
        return
    elseif CDM:IsGroup(id) then
        local ids = CDM:GetIcons(id)
        local kind = ids[1] and CDM:Get(ids[1]).type
        for _, iconId in ipairs(ids) do
            if CDM:Get(iconId).type ~= kind then
                page:Card(L['Display']):Row(rowHL, 0):Text(nil, { width = 1, text = L['This group holds more than one kind of display; edit their look per display.'], bgMode = 'hide' })
                return
            end
        end
        NRSKNUI.CDMDisplayTab:Build(page, ids, Applier(id), RefreshTree, TriggerChip)
        return
    end

    NRSKNUI.CDMDisplayTab:Build(page, { id }, Applier(id), RefreshTree, TriggerChip)
end

---A group's load settings are its icons' and aura groups', edited together as in WeakAuras.
---@param page table
---@param id string
local function BuildLoadTab(page, id)
    local iconIds = CDM:IsGroup(id) and CDM:GetLeaves(id) or { id }
    if #iconIds == 0 then
        page:Card(L['Load']):Row(rowHL, 0):Text(L['This group has no icons yet.'], { width = 1 })
        return
    end

    local first = CDM:Get(iconIds[1])
    page:LoadConditionsCard({
        db = first.Load,
        specs = true,
        onChangeCallback = function()
            for i = 2, #iconIds do CDM:Get(iconIds[i]).Load = CopyTable(first.Load) end
            CDM:RefreshLoad()
        end,
    })
end

local DESCRIPTION_HEIGHT = 80

---@param page table
---@param id string
local function BuildInformationTab(page, id)
    local display = CDM:Get(id)

    -- Card 1
    local infoCard = page:Card(L['Information'], 'all')
    infoCard:Row(rowH):EditBox(L['Name'], {
        width = 1,
        value = display.name,
        callback = function(text)
            text = strtrim(text or '')
            if text == '' then return end
            CDM:Rename(id, text)
            RefreshTree()
        end,
    })
    infoCard:Row(DESCRIPTION_HEIGHT + 18, 0):MultiLineEditBox(L['Description'], {
        width = 1,
        height = DESCRIPTION_HEIGHT,
        value = display.Description or '',
        callback = function(text)
            text = strtrim(text or '')
            display.Description = text ~= '' and text or nil
        end,
    })

    -- Card 2
    local names = {}
    local ancestors = CDM:GetAncestors(id)
    for i = #ancestors, 1, -1 do names[#names + 1] = CDM:GetName(ancestors[i]) end
    local lines = {
        format('%s: %s', L['ID'], id),
        format('%s: %s', L['UID'], tostring(display.uid)),
        format('%s: %s', L['Type'], TYPE_NAMES[display.type] or display.type),
        format('%s: %s', L['Group'], names[1] and tconcat(names, ' » ') or L['None']),
    }
    if CDM:IsGroup(id) then
        lines[#lines + 1] = format('%s: %d', L['Children'], #CDM:GetChildren(id))
        lines[#lines + 1] = format('%s: %d', L['Displays Inside'], #CDM:GetLeaves(id))
    elseif display.Triggers then
        lines[#lines + 1] = format('%s: %d', L['Triggers'], #display.Triggers)
        lines[#lines + 1] = format('%s: %d', L['Conditions'], #(display.Conditions or {}))
        lines[#lines + 1] = format('%s: %d', L['Sub Elements'], #(display.SubRegions or {}))
    end
    local metaHeight = #lines * 16
    page:Card(L['Metadata'], 'all'):Row(metaHeight, 0):Text(nil, { width = 1, height = metaHeight, autoHeight = true, bgMode = 'hide', text = lines })

    -- Card 3
    local warnings = CDM:GetWarnings(id)
    if warnings[1] then
        for i, warning in ipairs(warnings) do warnings[i] = NRSKNUI:ColorText(warning, Theme.warning) end
        local warnHeight = #warnings * 16
        page:Card(L['Warnings'], 'all'):Row(warnHeight, 0):Text(nil, { width = 1, height = warnHeight, autoHeight = true, bgMode = 'hide', text = warnings })
    end

    -- Card 4
    local debugHeight = 24
    page:Card(L['Debug'], 'all'):Row(debugHeight):Button(L['Create Debug Report'], {
        width = 1,
        height = debugHeight,
        tooltip = L['Sends a report of what this display is doing right now to BugSack, or to chat without it.'],
        callback = function() CDM:PrintDebug(id) end,
    })
end

-- Tree data --

---@param id string
---@return number|string
local function DisplayIcon(id)
    local display = CDM:Get(id)
    if CDM.LAYERED_TYPES[display.type] then
        local style = CDM:GetStyle(display)
        if style.IconSource == 'manual' and style.ManualIcon then return style.ManualIcon end -- as CDM:SetIconTexture draws it
        for _, trigger in ipairs(display.Triggers) do
            if trigger.Type ~= 'auraoverlay' then                                             -- an overlay sits on the icon below it
                return CDM:GetTriggerTexture(trigger) or (trigger.Type == 'cast' and CAST_ICON) or QUESTION_MARK
            end
        end
        return QUESTION_MARK
    end
    if display.Icon then return display.Icon end
    if display.type == 'auragroup' then
        -- The lowest spell ID of the first spell list, presets resolved.
        for _, branch in ipairs(NRSKNUI:GetTriggerBranches(display.Trigger)) do
            local lowest
            for spellID in pairs(branch.candidates and branch.candidates.includeSpellIDs or {}) do
                if not lowest or spellID < lowest then lowest = spellID end
            end
            if lowest then return GetSpellTexture(lowest) or QUESTION_MARK end
        end
        return QUESTION_MARK
    end

    local first = CDM:GetLeaves(id)[1]
    return first and DisplayIcon(first) or QUESTION_MARK
end

---@param id string
---@param index number? position among its group's children
---@param count number? children in its group
---@return table
local function RowData(id, index, count)
    local display = CDM:Get(id)
    local isGroup = CDM:IsGroup(id)
    local children = isGroup and CDM:GetChildren(id) or nil
    local icon = DisplayIcon(id)

    local data = {
        key = id,
        text = display.name,
        icon = icon,
        draw = function(canvas, size) return Thumbnail:Draw(canvas, display, size, icon) end,
        isGroup = isGroup,
        depth = CDM:GetDepth(id),
        enabled = display.Enabled,
        loadState = CDM:GetLoadState(id),
        preview = CDM:GetPreview(id),
        draggable = true,
        expanded = isGroup and expandedGroups[id] == true,
        childCount = children and #children or 0,
        canMoveUp = index ~= nil and index > 1,
        canMoveDown = index ~= nil and index < count,
    }

    data.tooltip = function(tooltip)
        local accent, secondary, muted = Theme.accent, Theme.textSecondary, Theme.textMuted
        tooltip:SetText(display.name, accent[1], accent[2], accent[3], 1, false)
        tooltip:AddLine(TYPE_NAMES[display.type], secondary[1], secondary[2], secondary[3])
        if display.Description then tooltip:AddLine(display.Description, muted[1], muted[2], muted[3], true) end
        if isGroup then
            if #children == 0 then tooltip:AddLine(L['No Children'], muted[1], muted[2], muted[3]) end
            for _, child in ipairs(children) do tooltip:AddLine('  ' .. child.text, secondary[1], secondary[2], secondary[3]) end
        end
        tooltip:AddLine(' ')
        tooltip:AddLine(L['Right-click for more options'], muted[1], muted[2], muted[3])
        tooltip:AddLine(L['Drag to move'], muted[1], muted[2], muted[3])
    end

    if isGroup then
        data.children = {}
        for i, child in ipairs(children) do data.children[i] = RowData(child.key, i, #children) end
    end
    return data
end

---@param row table
---@param into string[]
local function CollectIcons(row, into)
    if not row.isGroup then
        into[#into + 1] = row.key
        return
    end
    for _, child in ipairs(row.children) do CollectIcons(child, into) end
end

---@param section table
---@return string[]
local function SectionIcons(section)
    local ids = {}
    for _, row in ipairs(section.rows) do CollectIcons(row, ids) end
    return ids
end

---@param ids string[]
---@return number level
local function PreviewLevel(ids)
    local pinned, hidden = 0, 0
    for _, id in ipairs(ids) do
        local level = CDM.preview[id] or 0
        if level == 2 then pinned = pinned + 1 elseif level == 0 then hidden = hidden + 1 end
    end
    if #ids == 0 or hidden == #ids then return 0 end
    return pinned == #ids and 2 or 1
end

---Top-level rows go under Loaded/Standby unless every icon they hold is not loaded, as in WeakAuras.
---@return table
local function TreeContent()
    local loaded = {
        key = SECTION_LOADED,
        text = L['Loaded/Standby'],
        collapseText = L['Show or hide the loaded displays'],
        previewText = L['Toggle the visibility of all loaded displays'],
        rows = {},
    }
    local unloaded = {
        key = SECTION_UNLOADED,
        text = L['Not Loaded'],
        collapseText = L['Show or hide the displays that are not loaded'],
        previewText = L['Toggle the visibility of all displays that are not loaded'],
        rows = {},
    }

    for _, root in ipairs(CDM:GetRoots()) do
        local section = CDM:GetLoadState(root.key) == 'unloaded' and unloaded or loaded
        section.rows[#section.rows + 1] = RowData(root.key)
    end

    for _, section in ipairs({ loaded, unloaded }) do
        section.collapsed = IsCollapsed(section.key)
        section.preview = PreviewLevel(SectionIcons(section))
    end

    return {
        general = { key = GENERAL, text = L['General'] },
        pages = {
            { key = TRINKETS,        text = L['Trinket Blacklist'] },
            { key = SETTINGS,        text = L['Cooldown & Aura Manager Settings'] },
            { key = IMPORT,          text = L['Import'] },
            { key = IconPicker.PAGE, text = L['Choose an Icon'] },
        },
        sections = { loaded, unloaded },
    }
end

-- Actions --

---Select a display that was just created and open its name for editing in the tree.
---@param id string
local function SelectAndRename(id)
    EnsureModuleEnabled()
    CDM:ApplySettings(id)
    Reopen(id)
    RunNextFrame(function()
        local tree = Tree()
        if tree then tree:BeginRename(id) end
    end)
end

---@param parentId string?
local function NewIcon(parentId)
    SelectAndRename(CDM:CreateIcon(L['New Icon'], { Type = 'spell' }, parentId))
end

---A new progress bar starts as a cast bar, its trigger picks what it shows.
---@param parentId string?
local function NewProgressBar(parentId)
    local trigger = CopyTable(TRIGGER_DEFAULTS.cast)
    trigger.Type = 'cast'
    SelectAndRename(CDM:CreateBar(L['New Progress Bar'], trigger, parentId))
end

---@param parentId string?
local function NewText(parentId)
    SelectAndRename(CDM:CreateText(L['New Text'], { Type = 'spell' }, parentId))
end

---@param parentId string?
local function NewResourceBar(parentId)
    local id = CDM:CreateResourceBar(parentId)
    if not id then
        NRSKNUI:Print(L['Your class has no Runes, Holy Power or Combo Points.'])
        return
    end
    SelectAndRename(id)
end

---@param dynamic boolean
---@param parentId string?
local function NewGroup(dynamic, parentId)
    SelectAndRename(CDM:CreateGroup(dynamic and L['New Dynamic Group'] or L['New Group'], dynamic, parentId))
end

---@param parentId string?
local function NewAuraGroup(parentId)
    SelectAndRename(CDM:CreateAuraGroup(L['New Aura Group'], nil, parentId))
end

---@param id string
local function ToggleDisplay(id)
    local display = CDM:Get(id)
    display.Enabled = not display.Enabled
    CDM:ApplySettings(id)
    local tree = Tree()
    Reopen(tree and tree:GetSelected() or id)
end

---@param id string
local function DuplicateDisplay(id)
    local newId = CDM:Duplicate(id)
    if not newId then return end

    CDM:ApplySettings()
    Reopen(newId)
end

local COPY_PARTS = {
    { part = 'all',        text = L['Everything'], paste = L['Paste Settings'] },
    { part = 'display',    text = L['Display'],    paste = L['Paste Display Settings'] },
    { part = 'trigger',    text = L['Trigger'],    paste = L['Paste Trigger Settings'] },
    { part = 'conditions', text = L['Conditions'], paste = L['Paste Condition Settings'] },
    { part = 'load',       text = L['Load'],       paste = L['Paste Load Settings'] },
}
local GROUP_PARTS = {
    { part = 'group', text = L['Group'], paste = L['Paste Group Settings'] },
}
local AURA_GROUP_PARTS = { COPY_PARTS[1], COPY_PARTS[2], COPY_PARTS[3], COPY_PARTS[5] } -- an aura group has no conditions

local clipboard ---@type { source: table, part: table }? -- session only, as in WeakAuras

---@param id string
local function PasteSettings(id)
    CDM:PasteSettings(clipboard.source, id, clipboard.part.part)
    CDM:ApplySettings(id)
    Reopen(id)
end

---@param id string
---@param keepChildren boolean?
local function DeletePrompt(id, keepChildren)
    local text = keepChildren
        and format(L["Remove the group '%s'? Everything inside it stays."], CDM:GetName(id))
        or format(L["Delete '%s'? This cannot be undone."], CDM:GetName(id))

    NRSKNUI:CreatePrompt({
        title = L['Delete'],
        text = text,
        onAccept = function()
            CDM:Delete(id, keepChildren)
            CDM:ApplySettings()
            Reopen()
        end,
        acceptText = L['Delete'],
        cancelText = L['Cancel'],
    })
end

---Right click on a multi selection: WeakAuras' Delete All.
---@param ids string[]
local function MultiContextMenu(ids)
    GUI:ShowContextMenu({
        {
            text = L['Delete All'],
            onClick = function()
                NRSKNUI:CreatePrompt({
                    title = L['Delete All'],
                    text = format(L['Delete %d displays? Groups take everything inside them. This cannot be undone.'], #ids),
                    onAccept = function()
                        for _, id in ipairs(ids) do CDM:Delete(id) end -- a child already taken by its group is skipped
                        CDM:ApplySettings()
                        Reopen()
                    end,
                    acceptText = L['Delete'],
                    cancelText = L['Cancel'],
                })
            end,
        },
    })
end

---A built-in aura group's two resets, as the Auras page had them: its spells, or everything.
---@param id string
---@param entries table[]
local function BuiltinResetEntries(id, entries)
    local display = CDM:Get(id)
    local shipped = NRSKNUI.AuraTriggers:GetShipped(display.Trigger)
    if shipped and (shipped.Added or shipped.Removed) then
        entries[#entries + 1] = {
            text = L['Reset Spells to Default'],
            onClick = function()
                NRSKNUI:CreatePrompt({
                    title = L['Reset Spells to Default'],
                    text = L['Remove the spells you added and switch every default spell back on?'],
                    onAccept = function()
                        shipped.Added, shipped.Removed = nil, nil
                        NRSKNUI.AuraTriggers:Invalidate()
                        Reopen(id)
                    end,
                    acceptText = L['Reset'],
                    cancelText = L['Cancel'],
                })
            end,
        }
    end
    entries[#entries + 1] = {
        text = L['Reset Everything to Default'],
        onClick = function()
            NRSKNUI:CreatePrompt({
                title = L['Reset Everything to Default'],
                text = format(L["Put '%s' back to how it shipped, spells, layout and position included?"], CDM:GetName(id)),
                onAccept = function()
                    CDM:ResetBuiltin(id)
                    CDM:ApplySettings(id)
                    NRSKNUI.AuraTriggers:Invalidate()
                    Reopen(id)
                end,
                acceptText = L['Reset'],
                cancelText = L['Cancel'],
            })
        end,
    }
end

---@param id string
local function ContextMenu(id)
    local display = CDM:Get(id)
    local isGroup = CDM:IsGroup(id)
    local entries = {}
    if isGroup then
        entries[#entries + 1] = { text = L['Add Icon'], onClick = function() NewIcon(id) end }
        entries[#entries + 1] = { text = L['Add Progress Bar'], onClick = function() NewProgressBar(id) end }
        entries[#entries + 1] = { text = L['Add Text'], onClick = function() NewText(id) end }
        if display.type == 'group' then
            entries[#entries + 1] = { text = L['Add Aura Group'], onClick = function() NewAuraGroup(id) end }
            entries[#entries + 1] = { text = L['Add Group'], onClick = function() NewGroup(false, id) end }
            entries[#entries + 1] = { text = L['Add Dynamic Group'], onClick = function() NewGroup(true, id) end }
        end
        entries[#entries + 1] = { divider = true }
    end
    entries[#entries + 1] = { text = display.Enabled and L['Disable'] or L['Enable'], onClick = function() ToggleDisplay(id) end }
    entries[#entries + 1] = { text = L['Rename'], onClick = function() Tree():BeginRename(id) end }
    entries[#entries + 1] = { text = L['Duplicate'], onClick = function() DuplicateDisplay(id) end }
    entries[#entries + 1] = {
        text = L['Export'],
        onClick = function()
            local text = CDM:Export(id)
            if text then NRSKNUI:CreateCopyDialog(format(L['Export %s'], CDM:GetName(id)), text) end
        end,
    }

    local copyEntries = {}
    local parts = isGroup and GROUP_PARTS or display.type == 'auragroup' and AURA_GROUP_PARTS or COPY_PARTS
    for _, part in ipairs(parts) do
        copyEntries[#copyEntries + 1] = {
            text = part.text,
            onClick = function() clipboard = { source = CopyTable(display), part = part } end,
        }
    end
    entries[#entries + 1] = { text = L['Copy settings...'], submenu = copyEntries }
    if clipboard and CDM:CanPasteSettings(clipboard.source, id) then
        entries[#entries + 1] = { text = clipboard.part.paste, onClick = function() PasteSettings(id) end }
    end
    if display.builtin then BuiltinResetEntries(id, entries) end

    if display.parent then
        entries[#entries + 1] = {
            text = L['Remove from Group'],
            onClick = function()
                CDM:Ungroup(id)
                CDM:ApplySettings()
                Reopen(id)
            end,
        }
    end

    entries[#entries + 1] = { divider = true }
    if isGroup then
        entries[#entries + 1] = { text = L['Ungroup'], onClick = function() DeletePrompt(id, true) end }
        entries[#entries + 1] = { text = L['Delete Group and Contents'], onClick = function() DeletePrompt(id) end }
    else
        entries[#entries + 1] = { text = L['Delete'], onClick = function() DeletePrompt(id) end }
    end

    GUI:ShowContextMenu(entries)
end

-- New display page: shown when nothing is selected, WeakAuras' New Aura view --

-- New page pictures: small versions of each type, drawn from the player's own spec --

local SAMPLE_ICONS = { -- when the Cooldown Manager has fewer spells than a picture needs
    'Interface\\Icons\\Spell_Holy_SealOfSalvation',
    'Interface\\Icons\\INV_Sword_62',
    'Interface\\Icons\\Spell_Holy_WordFortitude',
    'Interface\\Icons\\Spell_Nature_Lightning',
    'Interface\\Icons\\Ability_Rogue_Sprint',
    'Interface\\Icons\\Spell_Fire_Fireball02',
}
local SAMPLE_BAR = { type = 'bar', Style = {} } -- the default bar style, for its texture and background
local SAMPLE_STACKS = { 3, nil, 2 }
local SAMPLE_COOLDOWN = 10
local SAMPLE_SLOTS = 6
local DYNAMIC_CYCLE = 8  -- seconds for the Dynamic Group picture: an icon leaves the row and comes back
local DYNAMIC_STEP = 0.5 -- each fade and slide in it

---The textures of the spec's first known Cooldown Manager spells in some categories, stock icons after them.
---@param categories number[] Enum.CooldownViewerCategory values
---@param count number
---@return (string|number)[]
local function SampleIcons(categories, count)
    local icons = {}
    for _, category in ipairs(categories) do
        for _, cooldownID in ipairs(CDM.Catalogue:GetList(category)) do
            local info = CDM.Catalogue:GetEntry(cooldownID)
            local texture = info and info.isKnown and info.spellID and GetSpellTexture(info.spellID)
            if texture and #icons < count then icons[#icons + 1] = texture end
        end
    end
    for i = #icons + 1, count do icons[i] = SAMPLE_ICONS[i] end
    return icons
end

---@param canvas Frame
---@param layer DrawLayer
---@return Texture
local function SampleTexture(canvas, layer)
    local texture = canvas:CreateTexture(nil, layer)
    texture:NUISetPixelSnap()
    return texture
end

---The regions a New tile's picture is drawn with, kept on its canvas; the Icon widget hides them before each draw.
---@param canvas Frame
---@return table
local function SampleParts(canvas)
    local parts = canvas.nuiSample
    if parts then return parts end
    parts = { icons = {}, edges = {}, stacks = {}, pips = {} }
    for i = 1, SAMPLE_SLOTS do
        parts.edges[i] = SampleTexture(canvas, 'BORDER')
        parts.edges[i]:SetColorTexture(0, 0, 0, 1)
        parts.icons[i] = SampleTexture(canvas, 'ARTWORK')
        parts.icons[i]:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        parts.stacks[i] = canvas:CreateFontString(nil, 'OVERLAY')
        parts.pips[i] = SampleTexture(canvas, 'ARTWORK')
    end
    parts.frame = SampleTexture(canvas, 'BACKGROUND') -- a bar's black edge
    parts.frame:SetColorTexture(0, 0, 0, 1)
    parts.barBg = SampleTexture(canvas, 'BORDER')
    parts.barFill = SampleTexture(canvas, 'ARTWORK')
    parts.timer = canvas:CreateFontString(nil, 'OVERLAY')
    parts.cooldown = CreateFrame('Cooldown', nil, canvas, 'CooldownFrameTemplate')
    parts.cooldown:SetDrawEdge(false)
    parts.cooldown:SetDrawBling(false)
    parts.cooldown:SetScript('OnCooldownDone', function(cooldown) cooldown:SetCooldown(GetTime(), SAMPLE_COOLDOWN) end)
    parts.driver = CreateFrame('Frame', nil, canvas) --[[@as CDMSampleDriver]] -- runs an animated picture; hidden with the canvas, which stops it
    canvas.nuiSample = parts
    return parts
end

---Place a texture at `x`, `y` from the canvas's top left.
---@param region Texture
---@param x number
---@param y number
---@param width number
---@param height number
local function Place(region, x, y, width, height)
    region:ClearAllPoints()
    region:NUISetPixelSize(width, height)
    region:NUISetPixelPoint('TOPLEFT', region:GetParent(), 'TOPLEFT', x, -y)
    region:Show()
end

---The `n`th icon of a picture, with its black edge, `size` square at `x`, `y`.
---@param parts table
---@param n number
---@param texture string|number
---@param size number
---@param x number
---@param y number
---@return Texture icon
local function SampleIcon(parts, n, texture, size, x, y)
    Place(parts.edges[n], x, y, size, size)
    parts.edges[n]:SetAlpha(1)
    local icon = parts.icons[n]
    Place(icon, x + 1, y + 1, size - 2, size - 2)
    icon:SetTexture(texture)
    icon:SetAlpha(1)
    return icon
end

---A row of `count` icons `size` square with 1px between them, centred in the picture.
---@param parts table
---@param icons (string|number)[]
---@param count number
---@param size number
---@param width number
---@param height number
---@return Texture[]
local function SampleRow(parts, icons, count, size, width, height)
    local x, y = floor((width - (count * size + count - 1)) / 2), floor((height - size) / 2)
    local placed = {}
    for i = 1, count do placed[i] = SampleIcon(parts, i, icons[i], size, x + (i - 1) * (size + 1), y) end
    return placed
end

---Icon: the spec's first cooldown with a swipe running round.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawIconSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local icon = SampleIcon(parts, 1, SampleIcons({ Enum.CooldownViewerCategory.Essential }, 1)[1], height, floor((width - height) / 2), 0)
    local cooldown = parts.cooldown
    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(icon)
    cooldown:Show()
    cooldown:SetCooldown(GetTime(), SAMPLE_COOLDOWN)
    -- Blizzard's countdown carries its own shadowed font; the GUI's texts are outlined without a shadow.
    local countdown = cooldown:GetCountdownFontString()
    if countdown then GUI:ApplyFont(countdown, 'large') end
    return true
end

---Progress Bar: the default bar texture in the class colour, a cooldown as its icon and a timer at its end.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawProgressSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local style = CDM:GetStyle(SAMPLE_BAR)
    local barHeight = floor(height * 0.45)
    local y = floor((height - barHeight) / 2)
    Place(parts.frame, 0, y, width, barHeight)
    SampleIcon(parts, 1, SampleIcons({ Enum.CooldownViewerCategory.Essential }, 1)[1], barHeight, 0, y)
    local inner = width - barHeight - 1
    Place(parts.barBg, barHeight, y + 1, inner, barHeight - 2)
    parts.barBg:SetColorTexture(unpack(style.BackgroundColor))
    Place(parts.barFill, barHeight, y + 1, floor(inner * 0.65), barHeight - 2)
    parts.barFill:SetTexture(NRSKNUI:GetStatusbar(style))
    parts.barFill:SetVertexColor(unpack(NRSKNUI:GetPlayerClassColor()))
    local timer = parts.timer
    GUI:ApplyFont(timer, 'small')
    timer:SetText('6.2')
    timer:ClearAllPoints()
    timer:SetPoint('RIGHT', parts.barBg, 'RIGHT', -2, 0)
    timer:Show()
    return true
end

---Resource Bar: the class's own points, a little over half full, in their power colour.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawResourceSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local powerType = CDM.CLASS_RESOURCES[NRSKNUI.MyClass] or Enum.PowerType.ComboPoints
    local count = math.max(3, math.min(UnitPowerMax('player', powerType) or 5, SAMPLE_SLOTS))
    local color = NRSKNUI.Colors.power[powerType]
    local r, g, b = 1, 0.96, 0.41
    if color then r, g, b = color:GetRGB() end
    local pipWidth = floor((width - 1) / count) - 1
    local barWidth = count * (pipWidth + 1) + 1
    local barHeight = floor(height * 0.35)
    local x, y = floor((width - barWidth) / 2), floor((height - barHeight) / 2)
    Place(parts.frame, x, y, barWidth, barHeight)
    for i = 1, count do
        local pip = parts.pips[i]
        local filled = i <= math.ceil(count * 0.6)
        pip:SetColorTexture(filled and r or 0.15, filled and g or 0.15, filled and b or 0.17, 1)
        Place(pip, x + 1 + (i - 1) * (pipWidth + 1), y + 1, pipWidth, barHeight - 2)
    end
    return true
end

---Group: six of the spec's cooldowns in two rows.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawGroupSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local icons = SampleIcons({ Enum.CooldownViewerCategory.Essential, Enum.CooldownViewerCategory.Utility }, 6)
    local size = floor((height - 1) / 2)
    local x = floor((width - (3 * size + 2)) / 2)
    for i = 1, 6 do
        SampleIcon(parts, i, icons[i], size, x + ((i - 1) % 3) * (size + 1), floor((i - 1) / 3) * (size + 1))
    end
    return true
end

---@param p number
---@return number
local function Ease(p)
    p = math.max(0, math.min(p, 1))
    return p * p * (3 - 2 * p)
end

---@class CDMSampleDriver : Frame
---@field parts table
---@field icons (string|number)[]
---@field size number
---@field width number
---@field height number
---@field t number

---One frame of the Dynamic Group picture: the middle icon fades out and the other two close up, centred, then
---they part and it fades back in.
---@param driver CDMSampleDriver
---@param elapsed number
local function StepDynamic(driver, elapsed)
    driver.t = (driver.t + elapsed) % DYNAMIC_CYCLE
    local t = driver.t
    -- Full row 2.5s, middle fades out, the others close up, hold 2.5s, they part, it fades back in.
    local step = DYNAMIC_STEP
    local gone = Ease((t - 2.5) / step) * (1 - Ease((t - 6.5) / step))
    local closed = Ease((t - 3) / step) * (1 - Ease((t - 6) / step))
    local parts, icons, size = driver.parts, driver.icons, driver.size
    local three = floor((driver.width - (3 * size + 2)) / 2)
    local two = floor((driver.width - (2 * size + 1)) / 2)
    local y = floor((driver.height - size) / 2)
    SampleIcon(parts, 1, icons[1], size, floor(three + (two - three) * closed + 0.5), y)
    SampleIcon(parts, 2, icons[2], size, three + size + 1, y)
    SampleIcon(parts, 3, icons[3], size, floor(three + 2 * (size + 1) + (two - three - size - 1) * closed + 0.5), y)
    parts.icons[2]:SetAlpha(1 - gone)
    parts.edges[2]:SetAlpha(1 - gone)
end

---Dynamic Group: a row of cooldowns that stays centred as one leaves it and comes back.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawDynamicSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local driver = parts.driver
    driver.parts, driver.t = parts, 0
    driver.icons = SampleIcons({ Enum.CooldownViewerCategory.Essential, Enum.CooldownViewerCategory.Utility }, 3)
    driver.size, driver.width, driver.height = math.min(height, floor((width - 2) / 3)), width, height
    StepDynamic(driver, 0)
    driver:SetScript('OnUpdate', StepDynamic)
    driver:Show()
    return true
end

---Aura Group: three of the spec's tracked buffs, two with stacks.
---@param canvas Frame
---@param height number
---@param width number
---@return boolean
local function DrawAuraSample(canvas, height, width)
    local parts = SampleParts(canvas)
    local icons = SampleIcons({ Enum.CooldownViewerCategory.TrackedBuff, Enum.CooldownViewerCategory.TrackedBar }, 3)
    local placed = SampleRow(parts, icons, 3, math.min(height, floor((width - 2) / 3)), width, height)
    for i, icon in ipairs(placed) do
        local stack = parts.stacks[i]
        if SAMPLE_STACKS[i] then
            GUI:ApplyFont(stack, 'normal')
            stack:SetText(SAMPLE_STACKS[i])
            stack:ClearAllPoints()
            stack:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', 1, 0)
            stack:Show()
        end
    end
    return true
end

---The Text type's picture: a word in the accent.
---@param canvas Frame
---@return boolean
local function DrawTextSample(canvas)
    local fs = canvas.nuiTextSample or canvas:CreateFontString(nil, 'OVERLAY')
    canvas.nuiTextSample = fs
    GUI:ApplyFont(fs, 'large')
    fs:SetText('Abc')
    fs:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    fs:ClearAllPoints()
    fs:SetPoint('CENTER')
    fs:Show()
    return true
end

---The Texture type's picture, until it exists: a ring tinted in the accent.
---@param canvas Frame
---@param height number
---@return boolean
local function DrawTextureSample(canvas, height)
    local texture = canvas.nuiTextureSample or canvas:CreateTexture(nil, 'ARTWORK')
    canvas.nuiTextureSample = texture
    texture:SetTexture('Interface\\AddOns\\NorskenUI\\Media\\CursorCircles\\nauraThick.png')
    texture:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    texture:ClearAllPoints()
    texture:NUISetPixelSize(height, height)
    texture:NUISetPixelPoint('CENTER', canvas, 'CENTER', 0, 0)
    texture:NUISetPixelSnap()
    texture:Show()
    return true
end

-- Four to a row; a type that isn't built yet shows greyed out.
local NEW_SECTIONS = {
    {
        title = L['Displays'],
        types = {
            {
                text = L['Icon'],
                description = L['Spell or aura'],
                draw = DrawIconSample,
                create = function() NewIcon() end,
            },
            {
                text = L['Progress Bar'],
                description = L['Timer bar'],
                draw = DrawProgressSample,
                create = function() NewProgressBar() end,
            },
            {
                text = L['Text'],
                description = L['Words or timers'],
                draw = DrawTextSample,
                create = function() NewText() end,
            },
            { text = L['Texture'], description = L['Any image'], draw = DrawTextureSample, disabled = true },
        },
    },
    {
        title = L['Groups & Premade Trackers'],
        types = {
            {
                text = L['Resource Bar'],
                description = L['Class points'],
                draw = DrawResourceSample,
                create = function() NewResourceBar() end,
            },
            {
                text = L['Aura Group'],
                description = L['Multiple auras'],
                draw = DrawAuraSample,
                create = function() NewAuraGroup() end,
            },
            {
                text = L['Group'],
                description = L['Move together'],
                draw = DrawGroupSample,
                create = function() NewGroup(false) end,
            },
            {
                text = L['Dynamic Group'],
                description = L['Auto layout'],
                draw = DrawDynamicSample,
                create = function() NewGroup(true) end,
            },
        },
    },
}

---The trinket blacklist, its own page so the main page stays short; Back returns to the trigger it came from.
---@param page table
local function BuildTrinketPage(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    local blacklist = page:Card(L['Trinket Blacklist'], 'all')
    if trinketReturnKey and CDM:Get(trinketReturnKey) then
        blacklist:HeaderButton({
            texture = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\right-arrow.png',
            size = 20,
            rotation = math.pi, -- our right arrow, pointing back
            tooltip = format(L['Back to %s'], CDM:GetName(trinketReturnKey)),
            onClick = function() Reopen(trinketReturnKey) end,
        })
    end
    blacklist:Rebuild(function(card)
        card:Row(rowH):EditBox(L['Add Trinket'], {
            width = 1,
            tooltip = L["An item ID. Trinkets on this list are never tracked, for on-use effects that only switch the trinket's mode."],
            callback = function(text)
                local itemID = tonumber(text)
                if not itemID then return end
                CDM.db.TrinketBlacklist[itemID] = true
                CDM:ApplySettings()
                card:Rebuild()
            end,
        })

        card:Separator()

        local ids = {}
        for itemID in pairs(CDM.db.TrinketBlacklist) do ids[#ids + 1] = itemID end
        table.sort(ids)
        for _, itemID in ipairs(ids) do
            card:Row(28):Icon({
                width = 1,
                size = 24,
                texture = GetItemIconByID(itemID) or QUESTION_MARK,
                text = { text = GetItemNameByID(itemID) or tostring(itemID), description = tostring(itemID) },
                tooltip = function(tooltip)
                    tooltip:SetItemByID(itemID)
                    tooltip:AddLine(L['Click to remove it from the blacklist.'], Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], true)
                end,
                onClick = function(button)
                    if button ~= 'LeftButton' then return end
                    CDM.db.TrinketBlacklist[itemID] = nil
                    CDM:ApplySettings()
                    card:Rebuild()
                end,
            })
        end
    end)
end

---The module's own settings, behind the New card's cog.
---@param page table
local function BuildSettingsPage(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    page:Card(L['Cooldown & Aura Manager']):HeaderButton({
        texture = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\right-arrow.png',
        size = 20,
        rotation = math.pi, -- our right arrow, pointing back
        tooltip = L['Back'],
        onClick = function() Reopen(GENERAL) end,
    }):Row(rowHL, 0):Checkbox(L['Enable Cooldown & Aura Manager'], {
        width = 1,
        master = true,
        value = CDM.db.Enabled,
        callback = function(checked)
            CDM.db.Enabled = checked
            NRSKNUI:ToggleModule('CDM', checked)
            page:Refresh()
            RefreshTree()
        end,
    })

    local integration = page:Card(L['Integration'], 'all')
    integration:Row(rowH):Checkbox(L['Hide Blizzard Cooldown Manager'], {
        width = 1,
        value = CDM.db.HideBlizzard,
        tooltip = L["Hides Blizzard's Cooldown Manager. It is turned off completely, unless a Cooldown Bar trigger needs it: then it keeps running out of sight. Its spell list still feeds the icon picker."],
        callback = function(checked)
            CDM.db.HideBlizzard = checked
            if CDM:IsEnabled() then CDM:SetBlizzardViewers(checked) end
        end,
    })
    integration:Row(rowH):Checkbox(L['Hide Blizzard Player Cast Bar'], {
        width = 1,
        value = CDM.db.HidePlayerCastBar,
        tooltip = L["For a cast bar of your own. Showing Blizzard's again takes a reload."],
        callback = function(checked)
            CDM.db.HidePlayerCastBar = checked
            if checked and CDM:IsEnabled() then
                CDM:HidePlayerCastBar()
            elseif not checked then
                NRSKNUI:CreatePrompt({
                    title = L['Reload UI'],
                    text = L["Blizzard's cast bar comes back after a reload. Reload now?"],
                    onAccept = ReloadUI,
                })
            end
        end,
    })
    integration:Separator()
    integration:Row(rowHL, 0):Slider(L['Unit Frame Anchor Minimum Width'], {
        width = 1,
        min = 0,
        max = 600,
        step = 1,
        value = CDM.db.AnchorMinWidth,
        tooltip = L['The unit frame anchor is never narrower than this, so frames beside it keep their distance from a short group.'],
        callback = function(value)
            CDM.db.AnchorMinWidth = value
            ScheduleAnchorUpdate()
        end,
    })
end

local IMPORT_BOX_HEIGHT = 120
local importState = { text = '', mode = 'update', picked = {} } ---@type { text: string, plan: table?, error: string?, mode: 'update'|'copy', picked: table<string, boolean> }

---@param text string
local function ReadImport(text)
    importState.text = text
    local payload, err = CDM:DecodeImport(text)
    importState.error = err
    importState.plan = payload and CDM:PlanImport(payload) or nil
    importState.mode = importState.plan and importState.plan.target and CDM:Get(importState.plan.target).preferToUpdate and 'update' or 'copy' -- WeakAuras' default
    importState.picked = {}
    for _, category in ipairs(CDM.IMPORT_CATEGORIES) do importState.picked[category.key] = category.default end
end

local RADIO_ROW_HEIGHT = 20 -- a Radio without a description is 16 tall

---@param card table
---@param lines string[]
local function TextBlock(card, lines)
    local height = #lines * 16
    card:Row(height):Text(nil, { width = 1, height = height, autoHeight = true, bgMode = 'hide', text = table.concat(lines, '\n') })
end

---What an import would add or change, laid out like WeakAuras' import window.
---@param card table
local function BuildImportSummary(card)
    local plan = importState.plan
    if importState.error then
        TextBlock(card, { NRSKNUI:ColorText(importState.error, Theme.warning) })
        return
    elseif not plan then
        TextBlock(card, { NRSKNUI:ColorText(L['Paste a string to see what it adds.'], Theme.textSecondary) })
        return
    end

    local d, root = plan.payload.d, plan.payload.d[plan.payload.root]
    local hasChanges = plan.target and not plan.blocked and next(plan.categories) ~= nil
    local bullet = NRSKNUI:ColorText('• ', Theme.accent) -- Kaji Text's own list bullet
    local lines = {
        NRSKNUI:ColorText(L['Importing:'], Theme.accent) .. ' ' .. root.name,
        bullet .. format(L['Made with NorskenUI %s'], tostring(plan.payload._a)),
        bullet .. (TYPE_NAMES[root.type] or root.type),
        bullet .. (plan.count == 1 and L['1 display'] or format(L['%d displays'], plan.count)),
    }
    if root.Description then lines[#lines + 1] = bullet .. root.Description end
    if plan.blocked then
        lines[#lines + 1] = bullet .. L['You have this under another display type, so it can only be imported as a copy.']
    elseif plan.target and not hasChanges then
        lines[#lines + 1] = bullet .. L['You already have this.']
    elseif hasChanges then
        lines[#lines + 1] = bullet .. format(L['This is a changed version of your %s.'], NRSKNUI:ColorText(CDM:GetName(plan.target), Theme.accent))

        local labels = {}
        for _, category in ipairs(CDM.IMPORT_CATEGORIES) do labels[category.key] = category.label end
        local added, modified, removed = {}, {}, {}
        for _, key in ipairs(plan.added) do added[#added + 1] = d[key].name end
        for key, changed in pairs(plan.modified) do
            local names = {}
            for _, category in ipairs(CDM.IMPORT_CATEGORIES) do
                if changed[category.key] then names[#names + 1] = labels[category.key] end
            end
            modified[#modified + 1] = format('%s (%s)', d[key].name, table.concat(names, ', '))
        end
        for _, id in ipairs(plan.removed) do removed[#removed + 1] = CDM:GetName(id) end
        for _, list in ipairs({ { title = L['Added'], names = added }, { title = L['Modified'], names = modified }, { title = L['Removed'], names = removed } }) do
            if list.names[1] then
                table.sort(list.names)
                lines[#lines + 1] = ''
                lines[#lines + 1] = NRSKNUI:ColorText(list.title, Theme.accent)
                for _, name in ipairs(list.names) do lines[#lines + 1] = bullet .. name end
            end
        end
    end
    TextBlock(card, lines)

    local update = hasChanges and importState.mode == 'update'
    if hasChanges then
        card:Separator(L['What do you want to do?'], { useLabel = true })
        local previous
        local modes = { { id = 'copy', text = L['Create a Copy'] }, { id = 'update', text = L['Update Displays'] } }
        for i, mode in ipairs(modes) do
            previous = card:Row(RADIO_ROW_HEIGHT, i == #modes and 0 or nil):Radio(mode.text, {
                width = 1,
                selected = importState.mode == mode.id,
                linkTo = previous,
                callback = function()
                    importState.mode = mode.id
                    card:Rebuild()
                end,
            })
        end
        if update then
            card:Separator(L['Categories to Update'], { useLabel = true })
            local row
            local shown = 0
            for _, category in ipairs(CDM.IMPORT_CATEGORIES) do
                if plan.categories[category.key] then
                    shown = shown + 1
                    if shown % 2 == 1 then row = card:Row(rowH) end
                    row:Checkbox(category.label, {
                        width = 0.5,
                        value = importState.picked[category.key],
                        callback = function(checked) importState.picked[category.key] = checked end,
                    })
                end
            end
        end
    end

    card:Separator()
    card:Row(30, 0):Button(update and L['Update'] or (plan.target and L['Import as Copy'] or L['Import']), {
        width = 1,
        height = 24,
        callback = function()
            local mode, picked = update and 'update' or 'copy', importState.picked
            NRSKNUI:RunWhenSafe(function()
                local id = CDM:ApplyImport(plan, mode, picked)
                ReadImport('')
                EnsureModuleEnabled()
                CDM:ApplySettings()
                Reopen(id)
            end)
        end,
    })
end

---Paste a string and see what it adds or updates before importing it.
---@param page table
local function BuildImportPage(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    ReadImport(importState.text) -- the tree may have changed since the string was pasted
    local summary
    page:Card(L['Import'], 'all'):HeaderButton({
        texture = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\right-arrow.png',
        size = 20,
        rotation = math.pi,
        tooltip = L['Back'],
        onClick = function() Reopen(GENERAL) end,
    }):Row(IMPORT_BOX_HEIGHT + 18, 0):MultiLineEditBox(L['Import String'], {
        width = 1,
        height = IMPORT_BOX_HEIGHT,
        value = importState.text,
        tooltip = L['CTRL+V to paste, CTRL+A to select all'],
        onTextChanged = function(text)
            ReadImport(text)
            summary:Rebuild()
        end,
    })
    summary = page:Card(L['Contents'], 'all')
    summary:Rebuild(BuildImportSummary)
end

---@param page table
local function BuildNewPage(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    -- The card's side padding is the gap between the tiles and below the last row too.
    local gap, edge = Theme.paddingMedium, Theme.paddingMedium - Theme.paddingSmall
    local card = page:Card(L['New Display'], 'all'):HeaderButton({
        atlas = 'questlog-icon-setting',
        size = 18,
        tooltip = L['Cooldown & Aura Manager Settings'],
        onClick = function() Reopen(SETTINGS) end,
    })
    for s, section in ipairs(NEW_SECTIONS) do
        NRSKNUI.CDMDisplayTab.Heading(card, section.title)
        local row = card:Row(NEW_TILE_HEIGHT, s == #NEW_SECTIONS and edge or gap):Even()
        for _, entry in ipairs(section.types) do
            row:Icon({
                width = 1 / #section.types,
                spacing = gap,
                size = NEW_TILE_ICON,
                previewWidth = NEW_TILE_PREVIEW,
                showBorder = false,
                tile = true,
                tileHeight = NEW_TILE_HEIGHT,
                disabled = entry.disabled,
                texture = entry.icon,
                draw = entry.draw,
                text = { text = entry.text, description = entry.description, color = Theme.textPrimary },
                onClick = entry.create and function(button) if button == 'LeftButton' then entry.create() end end or nil,
            })
        end
    end

    local importH = 24
    page:Card(L['Import'], 'all'):Row(importH):Button(L['Import a String'], {
        width = 1,
        height = importH,
        tooltip = L['Add displays someone shared, or update the ones you have.'],
        callback = function() Reopen(IMPORT) end,
    })
end

GUI:RegisterPage(PAGE, {
    mode = 'tabs',
    search = { L['Cooldown & Aura Manager'], L['Sub Elements'], L['Swipe Settings'] },
    onEnter = function()
        CDM.onStateChanged = RefreshTree
        IconPicker:Preload()
    end,
    onLeave = function()
        CDM.onStateChanged = nil
        CDM:SetSelectionPreview(nil)
    end,
    sidebar = {
        width = 260,
        create = NRSKNUI.CreateCDMTree,
        locked = function() return not CDM.db.Enabled end,
        items = TreeContent,
        onSelectionChanged = function(key)
            CDM:SetSelectionPreview(CDM:Get(key) and key or nil)
        end,
        onToggleExpanded = function(key, expanded)
            if CDM:IsGroup(key) then
                expandedGroups[key] = expanded or nil
            else
                NRSKNUI.db.global.SidebarCollapsed[PAGE][key] = (not expanded) or nil
            end
        end,
        onRename = function(key, text)
            CDM:Rename(key, text)
            RefreshTree()
        end,
        -- Into a group that can hold it, or next to a display inside one, the top level stays alphabetical.
        canDrop = function(item, target, position)
            if position == 'into' then return target.isGroup and CDM:CanContain(target.key, item.key) end
            local parent = CDM:Get(target.key).parent
            return parent ~= nil and CDM:CanContain(parent, item.key)
        end,
        onMove = function(keys, targetKey, position)
            -- A display inside a moved group travels with it.
            local moving, top = {}, {}
            for _, key in ipairs(keys) do moving[key] = true end
            for _, key in ipairs(keys) do
                local inside = false
                for _, ancestor in ipairs(CDM:GetAncestors(key)) do
                    if moving[ancestor] then
                        inside = true
                        break
                    end
                end
                if not inside then top[#top + 1] = key end
            end
            -- Into a group each one leads it, after a display each one follows it: reversed, they keep their order.
            local reverse = position ~= 'before'
            for i = reverse and #top or 1, reverse and 1 or #top, reverse and -1 or 1 do
                if position == 'into' then
                    CDM:SetParent(top[i], targetKey, true)
                else
                    CDM:MoveNextTo(top[i], targetKey, position)
                end
            end
            CDM:ApplySettings()
            RefreshTree()
        end,
        onMoveInGroup = function(key, delta)
            CDM:MoveInGroup(key, delta)
            CDM:ApplySettings(CDM:Get(key).parent)
            RefreshTree()
        end,
        onUngroup = function(key)
            CDM:Ungroup(key)
            CDM:ApplySettings()
            RefreshTree()
        end,
        onTogglePreview = function(key)
            CDM:SetPreview(key, CDM:GetPreview(key) == 2 and 0 or 2)
        end,
        onSectionPreview = function(sectionKey)
            for _, section in ipairs(TreeContent().sections) do
                if section.key == sectionKey then
                    local ids = SectionIcons(section)
                    local level = PreviewLevel(ids) ~= 2 and 2 or nil
                    for _, id in ipairs(ids) do CDM.preview[id] = level end
                    CDM:RefreshLoad()
                end
            end
        end,
        onContextMenu = function(key)
            if CDM:Get(key) then ContextMenu(key) end
        end,
        onMultiContextMenu = MultiContextMenu,
    },
    tabs = function(itemKey)
        local display = CDM:Get(itemKey)
        if not display then return {} end -- the new display page has no tabs

        if display.type == 'auragroup' then return AURA_GROUP_TABS end

        local tabs = {}
        for _, tab in ipairs(TABS) do
            if tab.id ~= 'group' or CDM:IsGroup(itemKey) then tabs[#tabs + 1] = tab end
        end
        return tabs
    end,
    build = function(page, tabId, itemKey)
        local display = CDM:Get(itemKey)
        if itemKey == IconPicker.PAGE then
            IconPicker:Build(page)
            return
        end
        IconPicker:Release()
        IconPicker.currentKey = itemKey

        if itemKey == TRINKETS then
            BuildTrinketPage(page)
            return
        elseif itemKey == IMPORT then
            BuildImportPage(page)
            return
        elseif itemKey == SETTINGS then
            BuildSettingsPage(page)
            return
        elseif not display then
            BuildNewPage(page)
            return
        end

        page:SetEnabled(function() return CDM.db.Enabled end)

        if tabId == 'group' then
            BuildGroupTab(page, itemKey)
        elseif tabId == 'display' then
            BuildDisplayTab(page, itemKey)
        elseif tabId == 'layout' then
            BuildAuraGroupLayoutTab(page, itemKey)
        elseif tabId == 'trigger' and CDM.LAYERED_TYPES[display.type] then
            BuildTriggerTab(page, itemKey)
        elseif tabId == 'trigger' and display.type == 'auragroup' then
            display.Trigger = display.Trigger or NRSKNUI.AuraTriggers:New()
            TriggerEditor:Build(page, display.Trigger, { title = L['Tracker'], group = 'all', showUnit = true, onChange = Applier(itemKey) })
        elseif tabId == 'conditions' then
            NRSKNUI.CDMConditionsTab:Build(page, itemKey, Applier(itemKey), TriggerTitle, TriggerChip)
        elseif tabId == 'load' then
            BuildLoadTab(page, itemKey)
        elseif tabId == 'information' then
            BuildInformationTab(page, itemKey)
        end
    end,
})
