---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class PlayerAurasModule
local PlayerAuras = NRSKNUI:GetModule('PlayerAuras')
local Anchors = NRSKNUI.Anchors
local AuraPreview = NRSKNUI.AuraPreview

local CreateFrame = CreateFrame
local CopyTable = CopyTable
local pairs = pairs
local min = math.min
local RunNextFrame = RunNextFrame

-- Weapon imbues, so the enchant dummies read as enchants rather than as two more buffs.
local ENCHANT_PREVIEW_SPELLS = { 33757, 318038 }

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
    container:UpdateUnitGate() -- also starts the container watching what can move a gate verdict

    host.container = container

    AuraPreview:Attach(container, host, config.anchorPoint)
    AuraPreview:Update(container, config, self:GetPreviewCount(kind), KINDS[kind].filter, self:GetPreviewLead(kind, config))
end

function PlayerAuras:ApplySettings()
    for kind, info in pairs(KINDS) do
        local cfg = self.db[kind]
        local host = self:GetHost(kind)

        if cfg.Enabled then
            self:ResizeHost(kind)
            host:Show()
            host:NUIApplyPosition(cfg)
            -- db is resolved live rather than captured: self.db is reassigned by
            -- UpdateDB() on a profile switch and cfg would still point at the old one.
            Anchors:Register(self, info.moverKey, host, info.guiPath, {
                displayName = info.displayName,
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
                _G[info.blizzardFrame]:NUIBanish()
            end
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
---@param onlyKind string? limits it to one kind, since buffs and debuffs are configured on their own pages
function PlayerAuras:SetPreviewing(previewing, onlyKind)
    for kind, info in pairs(KINDS) do
        local host = self.hosts[kind]
        local container = host and host.container
        if container then
            local wanted = previewing and (onlyKind == nil or onlyKind == info.guiPath)
            AuraPreview:SetShown(container, wanted)
            container:SetShown(not wanted)
        end
    end
end

---@param pageId string? the page asking, so only the display it configures previews
---@param showAll boolean? whether everything is being previewed, which means both displays
function PlayerAuras:ShowPreview(pageId, showAll)
    self:SetPreviewing(true, not showAll and pageId or nil)
end

function PlayerAuras:HidePreview()
    self:SetPreviewing(false)
end
