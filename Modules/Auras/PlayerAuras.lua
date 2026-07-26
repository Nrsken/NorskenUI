---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class PlayerAuras
local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local pairs = pairs
local RunNextFrame = RunNextFrame

local KINDS = {
    Buffs = {
        filter = 'HELPFUL',
        moverKey = 'PlayerBuffs',
        displayName = 'Standard Buffs',
        guiPath = 'standardBuffs',
        blizzardFrame = 'BuffFrame',
    },
    Debuffs = {
        filter = 'HARMFUL',
        moverKey = 'PlayerDebuffs',
        displayName = 'Standard Debuffs',
        guiPath = 'standardDebuffs',
        blizzardFrame = 'DebuffFrame',
    },
}

function PlayerAuras:UpdateDB()
    self.db = NRSKNUI.db.profile.Auras
end

function PlayerAuras:OnInitialize()
    self:UpdateDB()
    self.hosts = {}
    self:SetEnabledState(false)
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
        showDebuffDispelIcon = (kind == 'Debuffs') and cfg.showDebuffDispelIcon or nil,
        dispelIconSize = (kind == 'Debuffs') and cfg.dispelIconSize or nil,
        fontDB = cfg,
        stackFont = cfg.StackFont,
        durationFont = cfg.DurationFont,
        cancelAuraButtons = (kind == 'Buffs') and 'RightButtonUp' or nil,
        tooltipHideInCombat = cfg.tooltipHideInCombat,
    }
end

---Size the host to the grid the current settings describe, so the mover matches what is rendered.
---@param kind string
function PlayerAuras:ResizeHost(kind)
    local cfg = self.db[kind]
    self.hosts[kind]:SetSize(cfg.perRow * (cfg.size + cfg.elementSpacing), 3 * (cfg.size + cfg.lineSpacing))
end

---Create the mover host frame for a kind, the container is attached later, out of combat.
---@param kind string
---@return Frame
function PlayerAuras:GetHost(kind)
    if self.hosts[kind] then return self.hosts[kind] end

    self.hosts[kind] = CreateFrame('Frame', 'NRSKNUI_Player' .. kind, UIParent)
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

    container:SetUnit('player')

    host.container = container
end

function PlayerAuras:ApplySettings()
    for kind, info in pairs(KINDS) do
        local cfg = self.db[kind]
        local host = self:GetHost(kind)

        if cfg.Enabled then
            self:ResizeHost(kind)
            host:Show()
            host:ApplyPosition(cfg)
            EM:Register(self, { key = info.moverKey, displayName = info.displayName, frame = host, db = cfg, guiPath = info.guiPath, })

            local container = host.container
            if container then
                -- Layout re-applies live, button appearance does not (see container:ApplyLayout).
                local config = self:GetContainerConfig(kind)
                container:ClearAllPoints()
                container:SetPoint(config.anchorPoint, host, config.anchorPoint)
                container:ApplyLayout(config)
            end
        else
            host:Hide()
            EM:UnregisterElement(info.moverKey)
        end
    end

    NRSKNUI:RunWhenSafe(function()
        for kind in pairs(KINDS) do
            if self.db[kind].Enabled then
                self:BuildContainer(kind)
            end
        end
    end)
end

function PlayerAuras:OnEnable()
    if not self.db.Enabled then return end

    self:ApplySettings()

    NRSKNUI:RunWhenSafe(function()
        for kind, info in pairs(KINDS) do
            if self.db[kind].Enabled then
                _G[info.blizzardFrame]:Banish()
            end
        end
    end)
end

function PlayerAuras:OnDisable()
    for _, host in pairs(self.hosts) do
        host:Hide()
    end
end

-- Previews, calling the aura data provider API's while in Blizzard Edit Mode can cause some errors so return early if that's the case.

function PlayerAuras:ShowPreview()
    if not self.db.Enabled or NRSKNUI:IsEditModeActive() then return end
    C_UnitAuras.SwitchAuraDataProvider()
end

function PlayerAuras:HidePreview()
    if NRSKNUI:IsEditModeActive() then return end
    C_UnitAuras.ResetAuraDataProvider()
end
