---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_UnitFrames') then return end
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast
local AuraIndicators = NRSKNUI.AuraIndicators

local ipairs, pairs = ipairs, pairs
local CopyTable = CopyTable
local C_Spell = C_Spell
local format, tostring = string.format, tostring
local sort, tinsert, tremove = table.sort, table.insert, table.remove

local function DB() return UF.db end
local function LayerMap() return DB().General.Layers end

-- Aura indicator spots appear as their two groups; order inside a group lives on each spot's page.
---@return table[] occupants
local function Occupants()
    local map = LayerMap()
    local occupants = {}
    for order, element in ipairs(UF.LayerElements) do
        occupants[#occupants + 1] = { id = element.key, name = element.label, order = order, layer = map[element.key] }
    end
    return occupants
end

---@param occupants table[]
---@return { layer: number?, members: table[] }[]
local function Groups(occupants)
    local byLayer, groups = {}, {}
    for _, occupant in ipairs(occupants) do
        local group = byLayer[occupant.layer]
        if not group then
            group = { layer = occupant.layer, members = {} }
            byLayer[occupant.layer] = group
            groups[#groups + 1] = group
        end
        group.members[#group.members + 1] = occupant
    end

    sort(groups, function(a, b) return a.layer > b.layer end)
    for _, group in ipairs(groups) do
        sort(group.members, function(a, b) return a.order > b.order end)
    end
    return groups
end

---@param group table
---@param id any
---@return boolean
local function Holds(group, id)
    for _, member in ipairs(group.members) do
        if member.id == id then return true end
    end
    return false
end

---before/after opens a new layer beside the target, into shares the target's; layers renumber 1..N.
---@param occupants table[]
---@return table<string, number> layers
local function Plan(occupants, id, targetId, position)
    local groups = Groups(occupants)

    local moving
    for gi = #groups, 1, -1 do
        local members = groups[gi].members
        for mi = #members, 1, -1 do
            if members[mi].id == id then moving = tremove(members, mi) end
        end
        if not members[1] then tremove(groups, gi) end
    end

    for gi, group in ipairs(groups) do
        if Holds(group, targetId) then
            if position == 'into' then
                tinsert(group.members, moving)
            else
                tinsert(groups, position == 'before' and gi or gi + 1, { members = { moving } })
            end
            break
        end
    end

    local layers = {}
    for gi, group in ipairs(groups) do
        for _, member in ipairs(group.members) do
            layers[member.id] = #groups - gi + 1
        end
    end
    return layers
end

---A shared layer is left onto a layer of its own first; only then does a step pass the neighbour.
---@param occupants table[]
---@param id string
---@param dir number 1 up, -1 down
---@return table<string, number>? layers nil when there is nowhere to go
local function Step(occupants, id, dir)
    local groups = Groups(occupants)
    local position = dir > 0 and 'before' or 'after'
    for gi, group in ipairs(groups) do
        if Holds(group, id) then
            for _, member in ipairs(group.members) do
                if member.id ~= id then return Plan(occupants, id, member.id, position) end
            end
            local neighbour = groups[gi - dir]
            return neighbour and Plan(occupants, id, neighbour.members[1].id, position) or nil
        end
    end
end

-- Dispel and aura indicator slots are native buttons built once, so renumbering them needs a reload.
local RELOAD = {
    Dispel = L['Dispel highlight style changes show after a reload.'],
    IndicatorTints = L['Aura indicator layer changes show after a reload.'],
    IndicatorIcons = L['Aura indicator layer changes show after a reload.'],
}

---@param layers table<string, number> element key -> layer
local function Commit(layers)
    local map = LayerMap()
    for key, layer in pairs(layers) do
        if RELOAD[key] and map[key] ~= layer then NRSKNUI:RequestReload(RELOAD[key]) end
        map[key] = layer
    end
end

-- Sidebar icons --

local SPELLS = { Buff = 774, Debuff = 172, Defensive = 102342, Indicator = 139 }
local RAID_ICON = [[Interface\TargetingFrame\UI-RaidTargetingIcons]]
local STATE_ICON = [[Interface\CharacterFrame\UI-StateIcon]]
local TAGS_ICON = [[Interface\Icons\INV_Misc_Note_01]]
-- The dispel highlight's own art: a top-to-bottom fade the game tints by dispel type.
local DISPEL_GRADIENT = 'Interface\\AddOns\\NorskenCore\\Media\\white_gradient.tga'

---@param color table { r, g, b, a } or an oUF color
---@return table rgba
local function RGBA(color)
    if color.GetRGB then
        local r, g, b = color:GetRGB()
        return { r, g, b, 1 }
    end
    return { color[1], color[2], color[3], 1 }
end

---@param key string
---@return table
local function IconSpec(key)
    local general = DB().General
    local bar = NRSKNUI:GetStatusbar(general, general.statusBar)
    local spec = {
        IndicatorTints = { icon = NRSKNUI.WhiteTexture, iconColor = { 0.24, 0.82, 0.39, 1 } },
        Power = { icon = bar, iconColor = RGBA(NRSKNUI.Colors.power[0]) },
        Castbar = { icon = bar, iconColor = RGBA(general.Colors.Castbar) },
        Dispel = {
            icon = general.Dispel.Style == 'Gradient' and DISPEL_GRADIENT or NRSKNUI.WhiteTexture,
            iconColor = RGBA(NRSKNUI.Colors.dispel.Magic),
        },
        Border = { icon = NRSKNUI.WhiteTexture, iconColor = { 0.17, 0.17, 0.19, 1 } },
        Tags = { icon = TAGS_ICON },
        Buffs = { icon = C_Spell.GetSpellTexture(SPELLS.Buff) },
        Debuffs = { icon = C_Spell.GetSpellTexture(SPELLS.Debuff) },
        Defensives = { icon = C_Spell.GetSpellTexture(SPELLS.Defensive) },
        IndicatorIcons = { icon = C_Spell.GetSpellTexture(SPELLS.Indicator) },
        -- Marker art with a shape of its own, so no box behind it.
        RaidMark = { icon = RAID_ICON, iconCoords = { 0.5, 0.75, 0, 0.25 }, iconBare = true },
        Status = { icon = STATE_ICON, iconCoords = { 0.5, 1, 0, 0.49 }, iconBare = true },
    }
    for _, overlay in ipairs({ 'HealPrediction', 'HealAbsorb', 'DamageAbsorb', 'Highlight' }) do
        spec[overlay] = { icon = NRSKNUI:GetStatusbar(general[overlay]), iconColor = RGBA(general[overlay].Color) }
    end
    return spec[key] or {}
end

---@param uDB table
---@param group string
---@return table[] spots
local function SpotsIn(uDB, group)
    local spots = {}
    for index, placement in ipairs(uDB.AuraIndicators) do
        if UF.IndicatorGroup(placement) == group then
            spots[#spots + 1] = { placement = placement, name = AuraIndicators:GetPlacementName(placement, index) }
        end
    end
    sort(spots, function(a, b) return (a.placement.Order or 0) > (b.placement.Order or 0) end)
    return spots
end

---Reuses the group's own Order values in the new order, so the other group is left as it was.
---@param spots table[] SpotsIn result
---@param moved table placement
---@param target table placement
---@param position string before / after
local function ReorderSpots(spots, moved, target, position)
    local orders, ordered = {}, {}
    for _, spot in ipairs(spots) do
        orders[#orders + 1] = spot.placement.Order or 0
        if spot.placement ~= moved then ordered[#ordered + 1] = spot.placement end
    end
    for i, placement in ipairs(ordered) do
        if placement == target then
            tinsert(ordered, position == 'before' and i or i + 1, moved)
            break
        end
    end
    for i, placement in ipairs(ordered) do placement.Order = orders[i] end
end

-- Page --

local PAGE = 'unitFramesGeneral'

local function Reopen()
    NRSKNUI.GUIFrame:ShowPage(PAGE, { itemKey = 'layers' })
end

---@param layers table<string, number>? nil when there was nowhere to go
local function Apply(layers)
    if not layers then return end
    Commit(layers)
    UF:ApplySettings()
    Reopen()
end

---@param page KajiGUIPage
local function BuildStackCard(page)
    local occupants = Occupants()
    local groups = {}
    for _, group in ipairs(Groups(occupants)) do
        local items = {}
        for _, member in ipairs(group.members) do
            local item = { key = member.id, text = member.name, description = format(L['Layer %d'], group.layer) }
            for field, value in pairs(IconSpec(member.id)) do item[field] = value end
            items[#items + 1] = item
        end
        groups[#groups + 1] = { label = tostring(group.layer), items = items }
    end

    local card = page:Card(L['Layers'], 'all')
    card:Row(rowH):Widget('SortableStack', nil, {
        width = 1,
        id = 'unitFramesLayers',
        groups = groups,
        sharedCaption = L['Shared Layer %s'],
        onMove = function(id, targetId, position) Apply(Plan(occupants, id, targetId, position)) end,
        onStep = function(id, dir) Apply(Step(occupants, id, dir)) end,
    })
    card:Separator()
    card:Row(rowHL - 9, 0):Button(L['Reset to Default'], {
        width = 1,
        height = 30,
        yOffset = -2,
        callback = function()
            NRSKNUI:CreatePrompt({
                title = L['Reset to Default'],
                text = L['Put every layer back where it shipped?'],
                onAccept = function()
                    Apply(CopyTable(UF.Defaults.General.Layers))
                end,
                acceptText = L['Reset'],
                cancelText = L['Cancel'],
            })
        end,
    })
end

---Left out while the spot's draw group has nothing else to order against.
---@param page KajiGUIPage
---@param uDB table the unit's config block
---@param placement table the spot whose page this is
---@param reload fun() rebuilds the spot page
function UF.GUIDrawOrderCard(page, uDB, placement, reload)
    local group = UF.IndicatorGroup(placement)
    local spots = SpotsIn(uDB, group)
    if #spots < 2 then return end

    local stackGroups = {}
    for _, spot in ipairs(spots) do
        stackGroups[#stackGroups + 1] = { items = { { key = spot.placement, text = spot.name } } }
    end

    local function Reorder(moved, target, position)
        ReorderSpots(spots, moved, target, position)
        AuraIndicators:Invalidate(nil)
        NRSKNUI:RequestReload(L['Aura indicator layer changes show after a reload.'])
        reload()
    end

    page:Card(L['Draw Order'], 'all'):Row(rowHL, 0):Widget('SortableStack', nil, {
        width = 1,
        id = 'drawOrder:' .. group,
        groups = stackGroups,
        highlight = placement,
        canDrop = function(_, _, position) return position ~= 'into' end,
        onMove = Reorder,
        onStep = function(moved, dir)
            for i, spot in ipairs(spots) do
                local neighbour = spots[i - dir]
                if spot.placement == moved and neighbour then
                    return Reorder(moved, neighbour.placement, dir > 0 and 'before' or 'after')
                end
            end
        end,
    })
end

UF.GUILayersTab = BuildStackCard
