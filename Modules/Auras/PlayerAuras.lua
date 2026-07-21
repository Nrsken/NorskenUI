---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class PlayerAuras
local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
local EM = NRSKNUI.EditMode

local CreateFrame = CreateFrame
local pairs = pairs

-- kind -> { filter, moverKey, displayName }
local KINDS = {
    Buffs = { filter = 'HELPFUL', moverKey = 'PlayerBuffs', displayName = 'Player Buffs' },
    Debuffs = { filter = 'HARMFUL', moverKey = 'PlayerDebuffs', displayName = 'Player Debuffs' },
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
    local vertical = (cfg.GrowthY == 'DOWN') and 'TOP' or 'BOTTOM'
    local horizontal = (cfg.GrowthX == 'LEFT') and 'RIGHT' or 'LEFT'
    return vertical .. horizontal
end

---Create the mover host frame for a kind, the container is attached later, out of combat.
---@param kind string
---@return Frame
function PlayerAuras:GetHost(kind)
    if self.hosts[kind] then return self.hosts[kind] end

    local cfg = self.db[kind]
    local host = CreateFrame('Frame', 'NRSKNUI_Player' .. kind, UIParent)

    local cellW = cfg.Size + (cfg.SpacingX or 0)
    local cellH = cfg.Size + (cfg.SpacingY or 0)
    host:SetSize(cfg.PerRow * cellW, 3 * cellH)

    self.hosts[kind] = host
    return host
end

---Attach the native aura container to a host.
---@param kind string
function PlayerAuras:BuildContainer(kind)
    local host = self.hosts[kind]
    if not host or host.container then return end

    local cfg = self.db[kind]
    local corner = AnchorCorner(cfg)
    local weaponEnchants = (kind == 'Buffs') and cfg.ShowWeaponEnchants

    local container = host:CreateAuraContainer({
        maxWidth = cfg.PerRow * (cfg.Size + (cfg.SpacingX or 0)),
        initialAnchor = corner,
        growthX = cfg.GrowthX,
        growthY = cfg.GrowthY,
        size = cfg.Size,
        spacingX = cfg.SpacingX,
        spacingY = cfg.SpacingY,
        gap = weaponEnchants and (cfg.EnchantGap or 4) or nil,
        num = cfg.Max,
        showCount = cfg.ShowCount,
        showDuration = cfg.ShowDuration,
        showSwipe = cfg.ShowSwipe,
        showEdge = cfg.ShowEdge,
        reverseSwipe = cfg.ReverseSwipe,
        showBuffBorder = (kind == 'Buffs') and cfg.ShowBorder or nil,
        showDebuffBorder = (kind == 'Debuffs') and cfg.ShowBorder or nil,
        fontSize = cfg.FontSize,
        fontOutline = cfg.FontOutline,
        cancelButton = (kind == 'Buffs') and 'RightButtonUp' or nil,
    })
    if not container then return end

    container:ClearAllPoints()
    container:SetPoint(corner, host, corner)
    container:AddGroup(KINDS[kind].filter)

    if weaponEnchants then
        container:AddItemEnchant(AuraContainerItemEnchantmentSlot.MainHand)
        container:AddItemEnchant(AuraContainerItemEnchantmentSlot.OffHand)
    end

    container:SetUnit('player')

    host.container = container
end

function PlayerAuras:ApplySettings()
    for kind in pairs(KINDS) do
        local host = self:GetHost(kind)
        host:Show()
        host:ApplyPosition(self.db[kind])
        EM:Register(self, { key = KINDS[kind].moverKey, displayName = KINDS[kind].displayName, frame = host, db = self.db[kind], guiPath = 'playerauras', })
    end

    NRSKNUI:RunWhenSafe(function()
        for kind in pairs(KINDS) do
            self:BuildContainer(kind)
        end
    end)
end

function PlayerAuras:OnEnable()
    if not self.db.Enabled then return end

    self:ApplySettings()

    NRSKNUI:RunWhenSafe(function()
        _G.BuffFrame:Banish()
        _G.DebuffFrame:Banish()
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
