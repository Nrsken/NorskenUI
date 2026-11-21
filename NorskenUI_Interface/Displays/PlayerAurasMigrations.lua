---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class PlayerAurasModule
local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')

local CopyTable = CopyTable
local ipairs, pairs = ipairs, pairs
local tinsert = table.insert
local min = math.min

-- each frame's layout before it was an aura group: growth, -, per row, most auras
local OLD_LAYOUT = {
    Buffs = { 'LEFT', 'DOWN', nil, 10, 38 },
    Debuffs = { 'LEFT', 'DOWN', nil, 8, 8 },
}

-- the font the old texts shared; now each text has its own
local OLD_FONT_KEYS = { 'UseGlobalFont', 'FontFace', 'FontOutline', 'FontShadow' }

---Whether a frame's settings are still in the old shape.
---@param cfg table
---@return boolean
local function IsOld(cfg)
    for _, key in ipairs(NRSKNUI.OLD_AURA_KEYS) do
        if cfg[key] ~= nil then return true end
    end
    for _, key in ipairs(OLD_FONT_KEYS) do
        if cfg[key] ~= nil then return true end
    end
    return false
end

---@param cfg table
---@param kind string
local function UpgradeFrame(cfg, kind)
    -- a saved shadow holds only what differed, so it goes over the text's own
    local shadow = CopyTable(NRSKNUI.SUBREGION_TEMPLATES.text.FontShadow)
    for key, value in pairs(cfg.FontShadow or {}) do
        shadow[key] = value
    end

    local look = CopyTable(PlayerAuras.Looks[kind])
    look.font = {
        UseGlobalFont = cfg.UseGlobalFont ~= false,
        FontFace = cfg.FontFace or 'Expressway',
        FontOutline = cfg.FontOutline or 'OUTLINE',
        FontShadow = shadow,
    }
    NRSKNUI:UpgradeOldAuraGroup(cfg, OLD_LAYOUT[kind], look)

    for _, key in ipairs(OLD_FONT_KEYS) do
        cfg[key] = nil
    end
end

-- Standard Buffs and Debuffs became aura groups (2026-11). Read off the save, not a flag,
-- so an old export string imported later moves over too.
---@param db NRSKNUI.DBObject
function PlayerAuras:UpgradeSavedProfiles(db)
    local function Upgrade(data)
        for kind in pairs(OLD_LAYOUT) do
            local cfg = data[kind]
            if cfg and IsOld(cfg) then
                UpgradeFrame(cfg, kind)
            end
            if cfg then
                NRSKNUI:UpgradeDispelBorders(cfg.SubRegions)
                NRSKNUI:UpgradeTimeColor(cfg.SubRegions)
            end
        end

        -- weapon enchants drew their border by recolouring the group's borders; now they draw
        -- through an aura type texture, which Buffs only gets once, so deleting it holds
        local buffs = data.Buffs
        if buffs and buffs.SubRegions and not buffs.EnchantTextureAdded then
            local has = false
            for _, element in ipairs(buffs.SubRegions) do
                has = has or element.type == 'auratype'
            end
            if not has then
                local at = min(2, #buffs.SubRegions + 1)
                tinsert(buffs.SubRegions, at, NRSKNUI:NewSubRegion('auratype', { ShowHelpful = false }))
            end
            buffs.EnchantTextureAdded = true
        end
    end

    -- a release save holds it in the profile, a newer one in the namespace
    for _, profile in pairs(db.profiles) do
        if profile[self.dbKey] then
            Upgrade(profile[self.dbKey])
        end
    end
    local saved = db.sv.namespaces and db.sv.namespaces[self.moduleName]
    for _, data in pairs(saved and saved.profiles or {}) do
        Upgrade(data)
    end
end
