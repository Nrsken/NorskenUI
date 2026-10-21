---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local sort = table.sort

-- path walks a unit block to the element's settings. Layers are global, so a unit's own value is dropped.
local LAYER_SLOTS = {
    { key = 'Dispel',       path = { 'Dispel' } },
    { key = 'HealAbsorb',   path = { 'Health', 'HealAbsorb' } },
    { key = 'DamageAbsorb', path = { 'Health', 'DamageAbsorb' } },
}

---@param db NRSKNUI.DBObject
local function RunLayerMigration(db)
    if db.global.UFLayersMigrated then return end

    for _, profile in pairs(db.profiles) do
        local uf = profile.UnitFrames
        local general = uf and uf.General

        if general then
            for _, slot in ipairs(LAYER_SLOTS) do
                local block = general[slot.key]
                if block and block.Layer ~= nil then
                    general.Layers = general.Layers or {}
                    general.Layers[slot.key] = block.Layer
                    block.Layer = nil
                end
            end

            for _, uDB in pairs(uf.Units or {}) do
                for _, slot in ipairs(LAYER_SLOTS) do
                    local block = uDB
                    for _, step in ipairs(slot.path) do
                        block = block and block[step]
                    end
                    if block then block.Layer = nil end
                end
            end
        end
    end

    db.global.UFLayersMigrated = true
end

-- The map before the indicator groups joined it, to read a profile that only saved what it changed.
local PRE_GROUP_LAYERS = {
    Power = 1, Castbar = 2, Dispel = 3, DamageAbsorb = 4, HealAbsorb = 5, Highlight = 9, Border = 10,
    Tags = 11, Buffs = 12, Debuffs = 12, Defensives = 13, RaidMark = 14, Status = 15,
}

-- Indicator spots trade their Layer for a per-unit Order; Whole Frame attaches now mean the health area.
---@param db NRSKNUI.DBObject
local function RunIndicatorGroupMigration(db)
    if db.global.UFIndicatorGroupsMigrated then return end

    for _, profile in pairs(db.profiles) do
        local uf = profile.UnitFrames
        local general = uf and uf.General

        if general then
            if general.Layers then
                local map = {}
                for key, layer in pairs(PRE_GROUP_LAYERS) do map[key] = general.Layers[key] or layer end

                local icons = map.RaidMark
                for key, layer in pairs(map) do
                    map[key] = layer + 1 + (layer >= icons and 1 or 0)
                end
                map.IndicatorTints = 1
                map.IndicatorIcons = icons + 1
                general.Layers = map
            end

            if general.Dispel and general.Dispel.Attach == 'frame' then general.Dispel.Attach = 'health' end

            for _, uDB in pairs(uf.Units or {}) do
                if uDB.Dispel and uDB.Dispel.Attach == 'frame' then uDB.Dispel.Attach = 'health' end

                local placements = uDB.AuraIndicators or {}
                local ranked = {}
                for index, placement in ipairs(placements) do
                    ranked[index] = { placement = placement, layer = placement.Layer or 1, index = index }
                    if placement.Attach == 'frame' then placement.Attach = 'health' end
                end
                sort(ranked, function(a, b)
                    if a.layer ~= b.layer then return a.layer < b.layer end
                    return a.index < b.index
                end)
                for order, entry in ipairs(ranked) do
                    entry.placement.Order = order
                    entry.placement.Layer = nil
                end
            end
        end
    end

    db.global.UFIndicatorGroupsMigrated = true
end

---Old layouts, fixed while the settings still sit in profile.UnitFrames, before they move into the namespace.
---@param db NRSKNUI.DBObject
function UF:UpgradeSavedProfiles(db)
    RunLayerMigration(db)
    RunIndicatorGroupMigration(db)
end
