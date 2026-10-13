---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme

local tinsert = table.insert
local ipairs = ipairs
local format = string.format
local CopyTable = CopyTable
local floor = math.floor

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture
local GetSpellName = C_Spell and C_Spell.GetSpellName

local Shared = NRSKNUI.CDMOptions
local Applier, QUESTION_MARK, Reopen = Shared.Applier, Shared.QUESTION_MARK, Shared.Reopen

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

Shared.AURA_BAR_MODES = AURA_BAR_MODES
Shared.AURA_SOURCES = AURA_SOURCES
Shared.AURA_UNITS = AURA_UNITS
Shared.CAST_ICON = CAST_ICON
Shared.CatalogueOptions = CatalogueOptions
Shared.CataloguePicker = CataloguePicker
Shared.ITEMS = ITEMS
Shared.LinkedAuraTrigger = LinkedAuraTrigger
Shared.NormalizeAuraTypes = NormalizeAuraTypes
Shared.PositionCard = PositionCard
Shared.TRIGGER_DEFAULTS = TRIGGER_DEFAULTS
Shared.TRIGGER_LISTS = TRIGGER_LISTS
Shared.TRIGGER_TYPES = TRIGGER_TYPES
Shared.TriggerChip = TriggerChip
Shared.TriggerLabel = TriggerLabel
Shared.TriggerRows = TriggerRows
Shared.TriggerTitle = TriggerTitle
Shared.triggerOpen = triggerOpen
