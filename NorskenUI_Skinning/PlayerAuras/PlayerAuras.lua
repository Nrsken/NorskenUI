---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class PlayerAurasModule
local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
local L = NRSKNUI.Libs.AL
local Anchors = NRSKNUI.Anchors
local AuraPreview = NRSKNUI.AuraPreview

local CreateFrame = CreateFrame
local CopyTable = CopyTable
local pairs, ipairs = pairs, ipairs
local min = math.min
local RunNextFrame = RunNextFrame

-- Weapon imbues, so the enchant dummies read as enchants rather than as two more buffs.
local ENCHANT_PREVIEW_SPELLS = { 33757, 318038 }

local KINDS = {
    Buffs = {
        filter = 'HELPFUL',
        moverKey = 'PlayerBuffs',
        displayName = L['Standard Buffs'],
        guiItem = 'buffs',
        blizzardFrame = 'BuffFrame',
        cvarCallbacks = { 'consolidateBuffs', 'collapseExpandBuffs' }, -- banishing leaves these live
    },
    Debuffs = {
        filter = 'HARMFUL',
        moverKey = 'PlayerDebuffs',
        displayName = L['Standard Debuffs'],
        guiItem = 'debuffs',
        blizzardFrame = 'DebuffFrame',
    },
}

PlayerAuras.hosts = {}

function PlayerAuras:UpdateDB()
    self.db = self.namespace.profile
end

---Layout anchor corner derived from growth direction.
local function AnchorCorner(cfg)
    local vertical = (cfg.verticalGrowthDirection == 'DOWN') and 'TOP' or 'BOTTOM'
    local horizontal = (cfg.horizontalGrowthDirection == 'LEFT') and 'RIGHT' or 'LEFT'
    return vertical .. horizontal
end

---The container config built from a kind's current db. Shared by creation and live re-apply, so both
---always read the same settings.
---@param kind string
---@return table
function PlayerAuras:GetContainerConfig(kind)
    local cfg = self.db[kind]
    local weaponEnchants = (kind == 'Buffs') and cfg.showWeaponEnchants

    return {
        maximumLineSize = cfg.perRow * (cfg.size + cfg.elementSpacing),
        anchorPoint = AnchorCorner(cfg),
        horizontalGrowthDirection = cfg.horizontalGrowthDirection,
        verticalGrowthDirection = cfg.verticalGrowthDirection,
        size = cfg.size,
        elementSpacing = cfg.elementSpacing,
        lineSpacing = cfg.lineSpacing,
        groupSpacing = weaponEnchants and cfg.groupSpacing or nil,
        groupLineSpacing = weaponEnchants and cfg.groupLineSpacing or nil,
        maxFrameCount = cfg.maxFrameCount,
        sortMethod = AuraContainerSortMethod[cfg.sortMethod],
        sortDirection = AuraContainerSortDirection[cfg.sortDirection],
        showApplicationCount = cfg.showApplicationCount,
        showDurationText = cfg.showDurationText,
        durationTextColorCurve = true,
        drawSwipe = cfg.drawSwipe,
        drawEdge = cfg.drawEdge,
        reverseSwipe = cfg.reverseSwipe,
        showDebuffBorder = (kind == 'Debuffs') and cfg.showBorder or nil,
        showWithoutDispelType = (kind == 'Debuffs') and cfg.showBorderWithoutDispelType or nil,
        showDebuffDispelIcon = (kind == 'Debuffs') and cfg.showDebuffDispelIcon or nil,
        dispelIconSize = (kind == 'Debuffs') and cfg.dispelIconSize or nil,
        fontDB = cfg,
        stackFont = cfg.StackFont,
        durationFont = cfg.DurationFont,
        cancelAuraButtons = (kind == 'Buffs') and 'RightButtonUp' or nil,
        tooltipHideInCombat = cfg.tooltipHideInCombat,
    }
end

---How many enchant frames a kind flows in front of its auras, which is none unless it is the buffs
---display with weapon enchants turned on.
---@param kind string
---@return number
function PlayerAuras:GetEnchantCount(kind)
    return (kind == 'Buffs' and self.db[kind].showWeaponEnchants) and 2 or 0
end

---Most auras the current settings can put on screen.
---@param kind string
---@return number
function PlayerAuras:GetPreviewCount(kind)
    return min(self.db[kind].maxFrameCount + self:GetEnchantCount(kind), self.db[kind].previewLimit)
end

---Size the host to the largest grid the current settings can produce, so the mover covers the display's
---full footprint.
---@param kind string
function PlayerAuras:ResizeHost(kind)
    self.hosts[kind]:SetSize(NRSKNUI:GetAuraGridSize(self.db[kind], self:GetPreviewCount(kind)))
end

---The preview's enchant group: the same buttons with the enchant border on them.
---@param kind string
---@param config table
---@return table? lead
function PlayerAuras:GetPreviewLead(kind, config)
    local count = self:GetEnchantCount(kind)
    if count == 0 then return nil end

    local enchantConfig = CopyTable(config)
    enchantConfig.borderColor = NRSKNUI.Colors.enchantColor

    return { count = count, config = enchantConfig, spells = ENCHANT_PREVIEW_SPELLS }
end

---Create the mover host frame for a kind, the container is attached later, out of combat.
---@param kind string
---@return Frame
function PlayerAuras:GetHost(kind)
    if self.hosts[kind] then return self.hosts[kind] end

    self.hosts[kind] = CreateFrame('Frame', 'NRSKNUI_Player' .. kind, UIParent)
    self.hosts[kind]:SetRolesets('buffs')
    self:ResizeHost(kind)

    return self.hosts[kind]
end

---Attach the native aura container to a host.
---@param kind string
function PlayerAuras:BuildContainer(kind)
    local host = self.hosts[kind]
    if not host or host.container then return end

    local cfg = self.db[kind]
    local config = self:GetContainerConfig(kind)
    local container = host:CreateAuraContainer(config)
    if not container then return end

    container:ClearAllPoints()
    container:SetPoint(config.anchorPoint, host, config.anchorPoint)

    -- Since these are basic player auras, we just use the basic HELPFUL/HARMFUL filters.
    container:AddGroup(KINDS[kind].filter)

    if kind == 'Buffs' and cfg.showWeaponEnchants then
        RunNextFrame(function() -- Need delay slightly, enchant info isn't ready.
            container:AddItemEnchant(AuraContainerItemEnchantmentSlot.MainHand)
            container:AddItemEnchant(AuraContainerItemEnchantmentSlot.OffHand)

            -- Item enchants form their own flow group, elementSpacing is enchant-to-enchant, groupSpacing is the seam to aura groups.
            container:SetItemEnchantLayout({
                placement = CustomAuraContainerItemEnchantmentPlacement.BeforeAuraGroups,
            })
        end)
    end

    container:SetUnit(self.unit or 'player')
    container:UpdateUnitGate() -- also starts the container watching what can move a gate verdict

    host.container = container

    AuraPreview:Attach(container, host, config.anchorPoint)
    AuraPreview:Update(container, config, self:GetPreviewCount(kind), KINDS[kind].filter, self:GetPreviewLead(kind, config))
end

function PlayerAuras:ApplySettings()
    for kind, info in pairs(KINDS) do
        local cfg = self.db[kind]
        local host = self:GetHost(kind)

        -- one switch for both frames, the module's own
        if self.db.Enabled then
            self:ResizeHost(kind)
            host:Show()
            host:NUIApplyPosition(cfg)
            -- db is resolved live rather than captured: self.db is reassigned by
            -- UpdateDB() on a profile switch and cfg would still point at the old one.
            Anchors:Register(self, info.moverKey, host, 'buffsDebuffs', {
                displayName = info.displayName,
                guiContext = info.guiItem,
                db = function(module) return module.db[kind] end,
            })

            local container = host.container
            if container then
                -- Layout re-applies live, button appearance does not (see container:ApplyLayout).
                local config = self:GetContainerConfig(kind)
                container:ClearAllPoints()
                container:SetPoint(config.anchorPoint, host, config.anchorPoint)
                container:ApplyLayout(config)
                AuraPreview:Attach(container, host, config.anchorPoint)
                AuraPreview:Update(container, config, self:GetPreviewCount(kind), info.filter, self:GetPreviewLead(kind, config))
            end
        else
            host:Hide()
            Anchors:Unregister(info.moverKey)
        end
    end

    NRSKNUI:RunWhenSafe(function()
        for kind in pairs(KINDS) do
            if self.db.Enabled then
                self:BuildContainer(kind)
            end
        end
    end)
end

function PlayerAuras:OnEnable()
    self:ApplySettings()

    NRSKNUI:RunWhenSafe(function()
        for kind, info in pairs(KINDS) do
            if self.db.Enabled then
                local frame = _G[info.blizzardFrame]
                frame:NUIBanish()
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
                for _, host in pairs(self.hosts) do
                    local container = host.container
                    if container then
                        container:SetUnit(unit)
                        container:UpdateUnitGate()
                        container:UpdateAllAuras()
                    end
                end
            end)
            RegisterAttributeDriver(driver, 'unit', '[vehicleui] vehicle; player')
            self.unitDriver = driver
        end
    end)
end

function PlayerAuras:OnDisable()
    for _, host in pairs(self.hosts) do
        host:Hide()
    end
end

-- Previews. The real container swaps out for dummy auras, which are the only ones that can follow a
-- settings change without a reload.

---@param previewing boolean
function PlayerAuras:SetPreviewing(previewing)
    for kind in pairs(KINDS) do
        local host = self.hosts[kind]
        local container = host and host.container
        if container then
            AuraPreview:SetShown(container, previewing)
            container:SetShown(not previewing)
        end
    end
end

function PlayerAuras:ShowPreview()
    self:SetPreviewing(true)
end

function PlayerAuras:HidePreview()
    self:SetPreviewing(false)
end
