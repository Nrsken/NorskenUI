---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class PlayerAurasModule
local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
local L = NRSKNUI.Libs.AL
local Anchors = NRSKNUI.Anchors

local CopyTable = CopyTable
local CreateFrame = CreateFrame
local pairs, ipairs = pairs, ipairs
local setmetatable = setmetatable
local min = math.min

-- Weapon imbues, so the enchant dummies read as enchants rather than as two more buffs.
local ENCHANT_PREVIEW_SPELLS = { 33757, 318038 }

-- the enchants form their own flow group in front of the buffs
local ENCHANT_LAYOUT = { placement = CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups }

local KINDS = {
    Buffs = {
        moverKey = 'PlayerBuffs',
        displayName = L['Standard Buffs'],
        guiItem = 'buffs',
        blizzardFrame = 'BuffFrame',
        cvarCallbacks = { 'consolidateBuffs', 'collapseExpandBuffs' }, -- banishing leaves these live
        cancel = 'RightButtonUp',
    },
    Debuffs = {
        moverKey = 'PlayerDebuffs',
        displayName = L['Standard Debuffs'],
        guiItem = 'debuffs',
        blizzardFrame = 'DebuffFrame',
    },
}

PlayerAuras.displays = {}

function PlayerAuras:UpdateDB()
    self.db = self.namespace.profile
end

---A frame's settings ready to draw or edit, see Core:PrepareAuraGroup.
---@param kind string
---@return table style
function PlayerAuras:Prepare(kind)
    local cfg = self.db[kind]
    if kind == 'Buffs' and not cfg.SubRegions then
        -- seeded with its enchant texture, so the migration never puts back a deleted one
        cfg.EnchantTextureAdded = true
    end
    return NRSKNUI:PrepareAuraGroup(cfg, function() return CopyTable(self.Looks[kind]) end)
end

---Most auras the settings can put on screen, the enchants in front of them included.
---@param kind string
---@return number
function PlayerAuras:GetPreviewCount(kind)
    local cfg = self.db[kind]
    local enchants = (kind == 'Buffs' and cfg.showWeaponEnchants) and 2 or 0
    local auras = cfg.maxFrameCount * NRSKNUI:CountTriggerBranches(cfg.Trigger)
    return min(auras + enchants, cfg.previewLimit)
end

-- Look --

---An enchant's sub elements: the buffs', its aura type textures in the enchant colour.
---@param subRegions table[]
---@return table[]
local function EnchantLook(subRegions)
    local list = {}
    for n, element in ipairs(subRegions) do
        if element.type == 'auratype' then
            list[n] = setmetatable({ Color = NRSKNUI.Colors.enchantColor }, { __index = element })
        else
            list[n] = element
        end
    end
    return list
end

---@param kind string
---@param entry AuraDisplayEntry
local function StyleButton(kind, entry)
    local info = KINDS[kind]
    local subRegions = PlayerAuras.db[kind].SubRegions
    if entry.enchant then
        subRegions = EnchantLook(subRegions)
    end
    NRSKNUI:ApplyIconLook(entry.refs, info.style, subRegions, entry.branch)

    -- the button shows its own tooltip, we only say where it goes
    local button = entry.refs.button
    button:SetTooltipAnchorPoint('ANCHOR_BOTTOMLEFT', 0, 0)
    if info.cancel then
        button:SetCancelAuraButtons(info.cancel)
    end
end

---A frame's display, its host the mover; the container comes once combat allows it.
---@param kind string
---@return AuraDisplay
function PlayerAuras:GetDisplay(kind)
    local display = self.displays[kind]
    if display then
        return display
    end

    display = NRSKNUI:NewAuraDisplay(UIParent, {
        name = 'NRSKNUI_Player' .. kind,
        shape = 'group',
        style = function(entry) StyleButton(kind, entry) end,
    })
    display.host:SetRolesets('buffs')
    self.displays[kind] = display
    return display
end

function PlayerAuras:ApplySettings()
    for kind, info in pairs(KINDS) do
        local cfg = self.db[kind]
        local display = self:GetDisplay(kind)
        local host = display.host

        -- one switch for both frames, the module's own
        if self.db.Enabled then
            -- set before the display reads it: SetTrigger can hand a button over at once
            info.style = self:Prepare(kind)
            display:Restyle()

            local config = NRSKNUI:GetAuraGroupConfig(cfg, info.style)
            if kind == 'Buffs' then
                -- the seam between the enchants' flow group and the buffs'
                config.groupSpacing, config.groupLineSpacing = cfg.groupSpacing, cfg.groupLineSpacing
            end
            display:SetLayout(config, self:GetPreviewCount(kind))
            -- after the layout, whose spacing and size their flow group takes
            if kind == 'Buffs' then
                display:SetItemEnchants(cfg.showWeaponEnchants, ENCHANT_LAYOUT, ENCHANT_PREVIEW_SPELLS)
            end
            display:SetTrigger(cfg.Trigger)
            display:SetUnit(self.unit or 'player')

            host:Show()
            host:SetAlpha(info.style.Alpha)
            host:NCApplyPosition(cfg)
            -- db is resolved live rather than captured: self.db is reassigned by
            -- UpdateDB() on a profile switch and cfg would still point at the old one.
            Anchors:Register(self, info.moverKey, host, 'buffsDebuffs', {
                groups = 'interface',
                displayName = info.displayName,
                guiContext = info.guiItem,
                db = function(module) return module.db[kind] end,
            })
        else
            host:Hide()
            Anchors:Unregister(info.moverKey)
        end
    end
end

function PlayerAuras:OnEnable()
    self:ApplySettings()

    NRSKNUI:RunWhenSafe(function()
        for _, info in pairs(KINDS) do
            if self.db.Enabled then
                local frame = _G[info.blizzardFrame]
                frame:NCBanish()
                for _, cvar in ipairs(info.cvarCallbacks or {}) do
                    CVarCallbackRegistry:UnregisterCallback(cvar, frame)
                end
            end
        end

        -- Under a vehicle UI the vehicle's auras are the ones that matter.
        if not self.unitDriver then
            local driver = CreateFrame('Frame', nil, nil, 'SecureHandlerStateTemplate')
            driver:SetScript('OnAttributeChanged', function(_, attribute, unit)
                if attribute ~= 'unit' then return end
                self.unit = unit
                for _, display in pairs(self.displays) do
                    display:SetUnit(unit)
                    display:Refresh()
                end
            end)
            RegisterAttributeDriver(driver, 'unit', '[vehicleui] vehicle; player')
            self.unitDriver = driver
        end
    end)
end

function PlayerAuras:OnDisable()
    for _, display in pairs(self.displays) do
        display.host:Hide()
    end
end

-- Preview --

---@param previewing boolean
function PlayerAuras:SetPreviewing(previewing)
    for _, display in pairs(self.displays) do
        display:SetPreview(previewing)
    end
end

function PlayerAuras:ShowPreview()
    self:SetPreviewing(true)
end

function PlayerAuras:HidePreview()
    self:SetPreviewing(false)
end
