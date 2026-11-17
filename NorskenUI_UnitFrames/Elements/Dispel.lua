---@class NorskenUI
local NRSKNUI = _G.NorskenUI
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local CreateFrame = CreateFrame
local ipairs = ipairs
local select = select
local wipe = wipe

local AF = AuraUtil.AuraFilters

local SOURCE_TOKENS = {
    raid = AF.RaidPlayerDispellable,
    any = AF.Dispellable,
}

-- the size a slot's button is made at, before it covers its target
local SLOT_LAYOUT = { width = 24, height = 24, disableMouse = true }

-- the highlight keeps to units the player can help
local SLOT_OPTIONS = { assistOnly = true }

-- RAID_PLAYER_DISPELLABLE counts Arcane Torrent as a Magic dispel,
-- so torrent-only Blood Elves drop Magic
local FRIENDLY_MAGIC_DISPELS = { 527, 32375, 4987, 88423, 77130, 115450, 360823, 378438, 412113, 132411 }
local PET_MAGIC_DISPELS = { 89808 } -- Imp's Singe Magic

local magicFromTorrentOnly = false

---@return boolean
local function KnowsFriendlyMagicDispel()
    for _, spellID in ipairs(FRIENDLY_MAGIC_DISPELS) do
        if C_SpellBook.IsSpellInSpellBook(spellID, nil, true) then return true end
    end
    for _, spellID in ipairs(PET_MAGIC_DISPELS) do
        if C_SpellBook.IsSpellInSpellBook(spellID, Enum.SpellBookSpellBank.Pet, true) then return true end
    end
    return false
end

---@param uDB table
---@param general table?
---@return table
local function ResolveConfig(uDB, general)
    general = general or UF.db.General

    return uDB.Dispel.UseGlobal and general.Dispel or uDB.Dispel
end

---What the highlight matches: its Source, less the ignored types. Exclusion applies before
---picking, so an ignored bleed never hides a Magic debuff on the same unit.
---@param dispel table the frame's
---@param cfg table
---@return table trigger
local function SourceTrigger(dispel, cfg)
    local excluded = dispel.excluded
    wipe(excluded)
    for _, dispelType in ipairs(cfg.IgnoreTypes or {}) do
        excluded[dispelType] = true
    end
    if magicFromTorrentOnly and cfg.Source == 'raid' then
        excluded.Magic = true
    end

    local branch = dispel.trigger.branches[1]
    wipe(branch.tokens)
    branch.tokens[SOURCE_TOKENS[cfg.Source] or SOURCE_TOKENS.raid] = true
    return dispel.trigger
end

-- Look --

-- a tint and a border in the aura's dispel colour, and the type's icon
local look = {
    color = { 1, 1, 1, 1 },
    showIcon = false,
    swipe = false,
    timerText = false,
    spellName = '',
    subRegions = {},
}

---@param frame oUF.UnitFrame
---@param entry AuraDisplayEntry
local function StyleHighlight(frame, entry)
    local dispel = frame.nuiDispel
    local cfg = dispel.config
    local refs = entry.refs
    local button = refs.button

    -- before the look, which levels the elements off the button
    if not entry.preview then
        button:SetFrameLevel(UF.GetElementLevel(frame, 'Dispel'))
    end
    button:ClearAllPoints()
    button:SetAllPoints(entry.host)

    local alpha, untyped = cfg.Alpha or 1, cfg.ShowWithoutDispelType == true
    local tint, border, style = dispel.tint, dispel.border, dispel.style
    tint.Texture = cfg.Style == 'Gradient' and NRSKNUI.Media.Gradient or ''
    tint.Color[4], tint.DispelUntyped = alpha, untyped
    -- the border is its own setting rather than a style, so it draws over either; size 0 is off
    border.Enabled = (cfg.BorderSize or 0) > 0
    border.Size = cfg.BorderSize or 0
    border.DispelAlpha, border.DispelUntyped = alpha, untyped
    style.DispelIcon, style.DispelIconSize, style.DispelIconPosition = cfg.ShowIcon == true, cfg.IconSize, cfg.IconPosition

    look.style, look.textParent = dispel.look, refs.inner
    look.subRegions[1], look.subRegions[2] = tint, border
    NRSKNUI:ApplyAuraLook(refs, look)
    refs.inner:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT')
    -- never the unit frame's clicks
    button:EnableMouse(false)
end

-- Element --

---Point the proxy at what the config attaches to; the highlight always covers it.
---@param frame oUF.UnitFrame
---@param cfg table
---@return boolean anchored
local function AnchorProxy(frame, cfg)
    local proxy = frame.nuiDispel.proxy
    local target = UF.ResolveAttachTarget(frame, cfg.Attach)
    if not target then return false end

    proxy:ClearAllPoints()
    proxy:SetAllPoints(target)
    return true
end

---@param frame oUF.UnitFrame
local function Update(frame)
    local dispel = frame.nuiDispel
    local display = dispel and dispel.display
    if not display or not display.config then return end

    -- a healthFill attach is nothing until Health's Configure builds the fill
    if not dispel.anchored and dispel.config then
        dispel.anchored = AnchorProxy(frame, dispel.config)
    end

    -- a roster change can point the same token at someone else
    display:SetUnit(frame.__unit)
    display:Refresh()
end

---@param frame oUF.UnitFrame
---@return boolean
local function Enable(frame)
    if frame.nuiDispel then
        frame.nuiDispel.display.host:Show()
    end
    return true
end

---@param frame oUF.UnitFrame
local function Disable(frame)
    if frame.nuiDispel then
        frame.nuiDispel.display.host:Hide()
    end
end

oUF:AddElement('NRSKNDispel', Update, Enable, Disable)

-- spec, talent and pet swaps change what the player can dispel
local function Repoint()
    for _, frame in ipairs(oUF.objects) do
        local dispel = frame.nuiDispel
        local cfg = dispel and dispel.config
        if cfg and cfg.Enabled and dispel.display.config then
            dispel.display:SetSlot('highlight', SourceTrigger(dispel, cfg), dispel.proxy, SLOT_OPTIONS)
            dispel.display:Refresh()
        end
    end
end

local spellWatcher = CreateFrame('Frame')
spellWatcher:RegisterEvent('SPELLS_CHANGED')
spellWatcher:RegisterUnitEvent('UNIT_PET', 'player')
spellWatcher:SetScript('OnEvent', function()
    local torrentOnly = select(2, UnitRace('player')) == 'BloodElf' and not KnowsFriendlyMagicDispel()
    if torrentOnly == magicFromTorrentOnly then return end
    magicFromTorrentOnly = torrentOnly

    NRSKNUI:RunWhenSafe(Repoint)
end)

---@class UnitFramesElements
---@field Dispel UnitFramesDispelElement
UF.Elements = UF.Elements or {}

---@class UnitFramesDispelElement
UF.Elements.Dispel = {
    ---A slot display whose one slot covers the attach target; it gets a container once enabled.
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.nuiDispel then return end

        local frame = self
        local style = {}
        self.nuiDispel = {
            display = NRSKNUI:NewAuraDisplay(self, {
                shape = 'slots',
                style = function(entry) StyleHighlight(frame, entry) end,
            }),
            proxy = CreateFrame('Frame', nil, self),
            excluded = {},
            trigger = {
                Type = NRSKNUI.AuraTriggers.Types.AuraFilter,
                Base = AF.Harmful,
                branches = { { tokens = {} } },
            },
            tint = NRSKNUI:NewSubRegion('tint', { ColorMode = 'dispel', Solid = true, Color = { 1, 1, 1, 1 } }),
            border = NRSKNUI:NewSubRegion('border', { DispelColor = true, Color = { 1, 1, 1, 1 } }),
            style = style,
            look = NRSKNUI:ReadStyle(style, NRSKNUI.ICON_STYLE_TEMPLATE),
        }
        self.nuiDispel.trigger.branches[1].candidates = { excludeDispelTypes = self.nuiDispel.excluded }
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table?
    ---@param restyle table? set when the buttons redraw (UF:ApplySettings)
    Configure = function(self, unit, uDB, general, restyle)
        local dispel = self.nuiDispel
        if not dispel then return end

        local cfg = ResolveConfig(uDB, general)
        dispel.config = cfg
        local display = dispel.display
        if not cfg.Enabled then
            display:RemoveSlot('highlight')
            return
        end

        if not display.config then
            display:SetLayout(SLOT_LAYOUT)
        end
        -- re-pointed by value, so an unchanged source and ignore list push nothing
        display:SetSlot('highlight', SourceTrigger(dispel, cfg), dispel.proxy, SLOT_OPTIONS)
        dispel.anchored = AnchorProxy(self, cfg)
        -- the preview dummy sits on the proxy, so it layers where the live highlight does
        dispel.proxy:SetFrameLevel(UF.GetElementLevel(self, 'Dispel'))
        -- the live token, which a preview repoints away from the configured unit
        display:SetUnit(self.__unit or unit)
        if restyle then
            display:Restyle()
        end
    end,

    ---A dummy highlight on the target while the unit's dispel section is open.
    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    Preview = function(self, unit, uDB)
        local dispel = self.nuiDispel
        if not dispel then return end

        local previewing = UF.Preview:IsPreviewing('Dispel', self.nuiConfig or unit)
        dispel.display:SetPreview(previewing and ResolveConfig(uDB).Enabled, 'highlight')
    end,
}
