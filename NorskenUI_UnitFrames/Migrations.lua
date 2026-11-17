---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')

local sort = table.sort
local CopyTable = CopyTable

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

-- each kind's layout before aura groups (v12.1.0.8): growth, anchor, per row, max auras
local OLD_LAYOUT = {
    Buffs = { 'LEFT', 'UP', 'TOPRIGHT', 4, 8 },
    Debuffs = { 'RIGHT', 'UP', 'TOPLEFT', 2, 6 },
    Defensives = { 'CENTER', 'CENTER', 'CENTER', 4, 4 },
}
local OLD_UNIT_LAYOUT = {
    boss = { Buffs = { 'RIGHT', 'UP', 'BOTTOMRIGHT', 4, 4 }, Debuffs = { 'LEFT', 'UP', 'BOTTOMLEFT', 4, 4 } },
    party = { Buffs = { 'LEFT', 'UP', 'BOTTOMRIGHT', 2, 2 }, Debuffs = { 'RIGHT', 'UP', 'BOTTOMLEFT', 2, 2 } },
}
OLD_UNIT_LAYOUT.raid1 = OLD_UNIT_LAYOUT.party
OLD_UNIT_LAYOUT.raid2 = OLD_UNIT_LAYOUT.party
OLD_UNIT_LAYOUT.raid3 = OLD_UNIT_LAYOUT.party

---One kind's old settings in the aura group shape, see NRSKNUI:UpgradeOldAuraGroup.
---@param cfg table
---@param kind string
---@param unitKey string
---@param general table the save's UnitFrames.General
local function UpgradeAuraKind(cfg, kind, unitKey, general)
    local old = OLD_UNIT_LAYOUT[unitKey] and OLD_UNIT_LAYOUT[unitKey][kind] or OLD_LAYOUT[kind]
    local horizontal = cfg.horizontalGrowthDirection or old[1]
    local vertical = cfg.verticalGrowthDirection or old[2]

    -- the old code kept the point it first resolved when growth changed later, so a changed
    -- growth resolves it again: the growth's corner, or the middle on a middle anchor
    local position = cfg.Position or {}
    cfg.Position = position
    if cfg.horizontalGrowthDirection or cfg.verticalGrowthDirection or not position.AnchorFrom then
        local anchorTo = position.AnchorTo or old[3]
        local middleV = anchorTo == 'LEFT' or anchorTo == 'RIGHT' or anchorTo == 'CENTER'
        local middleH = anchorTo == 'TOP' or anchorTo == 'BOTTOM' or anchorTo == 'CENTER'
        local pointV = (vertical == 'CENTER' or middleV) and '' or (vertical == 'UP' and 'BOTTOM' or 'TOP')
        local pointH = (horizontal == 'CENTER' or middleH) and '' or (horizontal == 'LEFT' and 'RIGHT' or 'LEFT')
        local point = pointV .. pointH
        position.AnchorFrom = point ~= '' and point or 'CENTER'
    end

    local look = CopyTable(UF.AuraLooks[kind])
    look.font = UF.AuraFont(general)
    NRSKNUI:UpgradeOldAuraGroup(cfg, old, look)
end

-- Buffs, Debuffs and Defensives became aura groups (2026-11). Read off the save, not a flag,
-- so an old export string imported later moves over too.
---@param db NRSKNUI.DBObject
local function RunAuraGroupMigration(db)
    local function Upgrade(uf)
        for unitKey, uDB in pairs(uf.Units or {}) do
            for kind in pairs(OLD_LAYOUT) do
                local cfg = uDB.Auras and uDB.Auras[kind]
                for _, key in ipairs(cfg and NRSKNUI.OLD_AURA_KEYS or {}) do
                    if cfg[key] ~= nil then
                        UpgradeAuraKind(cfg, kind, unitKey, uf.General or {})
                        break
                    end
                end
            end
        end
    end

    -- a release save holds it in the profile, a newer one in the namespace with its role sets
    for _, profile in pairs(db.profiles) do
        if profile.UnitFrames then
            Upgrade(profile.UnitFrames)
        end
    end
    local saved = db.sv.namespaces and db.sv.namespaces.UnitFrames
    for _, data in pairs(saved and saved.profiles or {}) do
        Upgrade(data)
    end
end

-- what a spot saved before the aura library; any left means it hasn't moved over
local OLD_SPOT_KEYS = { 'Texture', 'Solid', 'Font', 'StackFont', 'DurationFont', 'Icon' }

---One spot's old look in the new shape, every style's part so a style switch still works.
---Nil reads as the old default, which is what the old code drew with.
---@param placement table
---@param general table the save's UnitFrames.General
local function UpgradeIndicatorSpot(placement, general)
    local font, icon, size = placement.Font or {}, placement.Icon or {}, placement.Size or {}
    local face = UF.AuraFont(general)
    if font.UseGlobalFont == false then
        face = { UseGlobalFont = false, FontFace = font.FontFace, FontOutline = font.FontOutline }
    end

    placement.Tint = placement.Tint or NRSKNUI:NewSubRegion('tint', {
        ColorMode = 'indicator',
        Texture = placement.Texture or '',
        Solid = placement.Solid == true,
    })

    -- a Duration text sat at its AnchorFrom on that same point of the target
    local pos = placement.Position or {}
    placement.Text = placement.Text or NRSKNUI:NewSubRegion('text', {
        FontSize = font.FontSize or 12,
        Position = { AnchorFrom = 'AUTO', AnchorTo = pos.AnchorFrom or 'CENTER', XOffset = pos.XOffset or 0, YOffset = pos.YOffset or 0 },
    }, face)

    local cooldown = icon.showCooldown ~= false
    placement.IconStyle = placement.IconStyle or {
        Width = size.Width or 24,
        Height = size.Height or 24,
        DrawSwipe = cooldown and icon.drawSwipe ~= false,
        DrawEdge = cooldown and icon.drawEdge == true,
        Reverse = icon.reverseSwipe ~= false,
    }
    placement.SubRegions = placement.SubRegions or NRSKNUI:DefaultAuraGroupSubRegions({
        font = face,
        auraType = icon.showBorder and { DispelUntyped = true } or nil,
        timer = NRSKNUI:OldAuraText({ GlobalTimeColor = true }, icon.showDuration ~= false, placement.DurationFont or { FontSize = 12 }, 'CENTER', 0),
        stacks = NRSKNUI:OldAuraText(nil, icon.showStacks ~= false, placement.StackFont or { FontSize = 10 }, 'BOTTOMRIGHT', 2),
    })

    for _, key in ipairs(OLD_SPOT_KEYS) do
        placement[key] = nil
    end
end

-- Indicator spots draw through the aura library (2026-11), read off the save as above.
---@param db NRSKNUI.DBObject
local function RunIndicatorLookMigration(db)
    local function Upgrade(uf)
        for _, uDB in pairs(uf.Units or {}) do
            for _, placement in ipairs(uDB.AuraIndicators or {}) do
                for _, key in ipairs(OLD_SPOT_KEYS) do
                    if placement[key] ~= nil then
                        UpgradeIndicatorSpot(placement, uf.General or {})
                        break
                    end
                end
            end
        end
    end

    local shipped = NRSKNUI:GetDefaultDB().profile.AuraIndicators['builtin:defensives']
    for _, profile in pairs(db.profiles) do
        if profile.UnitFrames then
            Upgrade(profile.UnitFrames)
        end
        -- an indicator shows one trigger now, and only an old save of this one holds several
        local defensives = profile.AuraIndicators and profile.AuraIndicators['builtin:defensives']
        if defensives and NRSKNUI:CountTriggerBranches(defensives.Trigger) > 1 then
            defensives.Trigger = CopyTable(shipped.Trigger)
        end
    end
    local saved = db.sv.namespaces and db.sv.namespaces.UnitFrames
    for _, data in pairs(saved and saved.profiles or {}) do
        Upgrade(data)
    end
end

-- Aura sub elements, read off the save (2026-11): borders hand their dispel colouring to an
-- aura type texture, old time texts keep the shared Duration Text colours.
---@param db NRSKNUI.DBObject
local function RunSubRegionMigration(db)
    local function Upgrade(uf)
        for _, uDB in pairs(uf.Units or {}) do
            for _, cfg in pairs(uDB.Auras or {}) do
                NRSKNUI:UpgradeDispelBorders(cfg.SubRegions)
                NRSKNUI:UpgradeTimeColor(cfg.SubRegions)
            end
            for _, placement in ipairs(uDB.AuraIndicators or {}) do
                NRSKNUI:UpgradeDispelBorders(placement.SubRegions)
                NRSKNUI:UpgradeTimeColor(placement.SubRegions)
            end
        end
    end

    for _, profile in pairs(db.profiles) do
        if profile.UnitFrames then
            Upgrade(profile.UnitFrames)
        end
    end
    local saved = db.sv.namespaces and db.sv.namespaces.UnitFrames
    for _, data in pairs(saved and saved.profiles or {}) do
        Upgrade(data)
    end
end

---Old layouts, fixed while the settings still sit in profile.UnitFrames, before they move into the namespace.
---@param db NRSKNUI.DBObject
function UF:UpgradeSavedProfiles(db)
    RunLayerMigration(db)
    RunIndicatorGroupMigration(db)
    RunAuraGroupMigration(db)
    RunIndicatorLookMigration(db)
    RunSubRegionMigration(db)
end
