---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field IndicatorDefs UnitFramesIndicatorDef
---@field Elements UnitFramesElements
local UF = NRSKNUI:GetModule('UnitFrames')

local ipairs = ipairs
local CreateFrame = CreateFrame
local unpack = unpack

local PLAYER_UNITS = { player = true, target = true, targettarget = true, focus = true, focustarget = true, party = true }
local GROUPED = { player = true, party = true }

-- TODO: Add more texture options, just using baselinee oUF textures for now.

-- Native oUF indicator elements, keyed into uDB.Indicators. Consumed by the GUI and ApplyElementStates.
---@class UnitFramesIndicatorDef
---@field key string
---@field element string
---@field units? table<string, boolean> config keys it applies to, nil for every unit
---@field topLevel? string a UF.TopLevels key, when the icon needs a frame level of its own
---@field art? { atlas?: string, texture?: string, coords?: number[], desaturated?: boolean }
---@field configure? fun(tex: Texture, db: table) settings beyond size and position
---@field postUpdate? fun(element: Texture, ...) oUF PostUpdate, for filtering what the element shows
UF.IndicatorDefs = {
    {
        key = 'Resting',
        element = 'RestingIndicator',
        units = { player = true },
        art = { texture = [[Interface\HUD\UIUnitFrameRestingFlipbook]], coords = { 45 / 360, 80 / 360, 200 / 420, 240 / 420 }, desaturated = true }
    },
    {
        key = 'Combat',
        element = 'CombatIndicator',
        units = { player = true },
        art = { atlas = 'UI-HUD-UnitFrame-Player-CombatIcon' }
    },
    {
        key = 'Quest',
        element = 'QuestIndicator',
        units = { target = true },
        art = { texture = [[Interface\TargetingFrame\PortraitQuestBadge]] }
    },
    {
        key = 'ReadyCheck',
        element = 'ReadyCheckIndicator',
        units = { party = true },
        art = { atlas = 'UI-LFG-ReadyMark-Raid' }
    },
    {
        key = 'Role',
        element = 'GroupRoleIndicator',
        units = { party = true },
        art = { atlas = 'UI-LFG-RoleIcon-Healer-Micro-Raid' },
        configure = function(tex, db) tex.nuiTankHealerOnly = db.TankHealerOnly end,
        postUpdate = function(element, role)
            if element.nuiTankHealerOnly and role == Enum.LFGRole.Damage then
                element:Hide()
            end
        end,
    },
    {
        key = 'Summon',
        element = 'SummonIndicator',
        units = GROUPED,
        art = { atlas = 'RaidFrame-Icon-SummonPending' }
    },
    {
        key = 'Resurrect',
        element = 'ResurrectIndicator',
        units = GROUPED,
        art = { atlas = 'RaidFrame-Icon-Rez' }
    },
    {
        key = 'PvP',
        element = 'PvPIndicator',
        units = PLAYER_UNITS,
        art = { texture = [[Interface\TargetingFrame\UI-PVP-Horde]], coords = { 0, 0.65625, 0, 0.65625 } }
    },
    {
        key = 'Phase',
        element = 'PhaseIndicator',
        units = PLAYER_UNITS,
        art = { atlas = 'RaidFrame-Icon-Phasing' }
    },
    {
        key = 'Leader',
        element = 'LeaderIndicator',
        units = PLAYER_UNITS,
        art = { atlas = 'UI-HUD-UnitFrame-Player-Group-LeaderIcon' }
    },
    {
        key = 'RaidIcon',
        element = 'RaidTargetIndicator',
        topLevel = 'RaidMark',
        art = { texture = [[Interface\TargetingFrame\UI-RaidTargetingIcons]], coords = { 0, 0.25, 0, 0.25 } }
    },
}

local unitDefs = {}

---The indicator defs that apply to a unit.
---@param unit string config key or unit token
---@return UnitFramesIndicatorDef[]
function UF.UnitIndicators(unit)
    local key = UF.ConfigKey(unit) -- callers pass boss1/boss2 as readily as the config key
    local defs = unitDefs[key]
    if defs then return defs end

    defs = {}
    for _, def in ipairs(UF.IndicatorDefs) do
        if not def.units or def.units[key] then
            defs[#defs + 1] = def
        end
    end

    unitDefs[key] = defs
    return defs
end

-- Stands in for an element's Update while its tab is previewed, so oUF leaves the forced icon alone.
local function NoUpdate() end

---@param tex Texture
---@param def UnitFramesIndicatorDef
local function ApplyArt(tex, def)
    local art = def.art
    if not art then return end

    if art.atlas then
        tex:SetAtlas(art.atlas)
        return
    end

    tex:SetTexture(art.texture)
    if art.coords then tex:SetTexCoord(unpack(art.coords)) end
    tex:SetDesaturated(art.desaturated)
end

---@class UnitFramesElements
---@field Indicators UnitFramesIndicatorsElement
UF.Elements = UF.Elements or {}

---@class UnitFramesIndicatorsElement
UF.Elements.Indicators = {
    ---@param self oUF.UnitFrame
    ---@param unit string
    Construct = function(self, unit)
        if self.IndicatorContainer then return end

        -- Own overlay above the text container so icons never sit behind the name.
        local container = CreateFrame('Frame', nil, self)
        container:NUISetPixelPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        container:NUISetPixelPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 0)
        container:SetFrameLevel(UF.TopLevels.Status)
        container:SetFrameStrata("MEDIUM")
        self.IndicatorContainer = container

        for _, def in ipairs(UF.UnitIndicators(unit)) do
            local parent = container

            if def.topLevel then
                parent = CreateFrame('Frame', nil, self)
                parent:SetAllPoints()
                parent:SetFrameLevel(UF.TopLevels[def.topLevel])
            end

            local tex = parent:CreateTexture(nil, 'OVERLAY')
            tex.PostUpdate = def.postUpdate
            self[def.element] = tex
        end
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local container = self.IndicatorContainer

        for _, def in ipairs(UF.UnitIndicators(unit)) do
            local db = uDB.Indicators[def.key]
            local tex = self[def.element]

            tex:NUISetPixelSize(db.Size, db.Size)
            tex:ClearAllPoints()
            tex:NUISetPixelPoint(db.Position.AnchorFrom, container, db.Position.AnchorTo, db.Position.XOffset, db.Position.YOffset)
            ApplyArt(tex, def)

            if def.configure then def.configure(tex, db) end
        end
    end,

    ---Force-show the indicator whose sub-tab the GUI has open, so its size and position can be seen.
    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    Preview = function(self, unit, uDB)
        local container = self.IndicatorContainer
        if not container then return end

        local previewed = UF.Preview:GetIndicatorKey(self.nuiConfig or unit)
        local restore = false

        for _, def in ipairs(UF.UnitIndicators(unit)) do
            local tex = self[def.element]

            if def.key == previewed then
                tex.Override = NoUpdate
                ApplyArt(tex, def) -- oUF only applies art on enable, so a disabled one has none yet
                tex:Show()
            elseif tex.Override then
                tex.Override = nil
                tex:Hide() -- a disabled element has no update of its own to take it back down
                restore = true
            end
        end

        -- Safe after the force-show above: the previewed element ignores it through its Override.
        if restore then self:UpdateAllElements('ForceUpdate') end
    end,
}
