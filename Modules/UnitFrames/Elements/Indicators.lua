---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL

local ipairs, pairs = ipairs, pairs
local CreateFrame = CreateFrame
local format = string.format
local unpack = unpack

local GROUP_UNITS = {}
for _, unit in ipairs(UF.GroupUnits) do GROUP_UNITS[unit] = true end

local PLAYER_UNITS = { player = true, target = true, targettarget = true, focus = true, focustarget = true }
local GROUPED = { player = true }
for unit in pairs(GROUP_UNITS) do
    PLAYER_UNITS[unit] = true
    GROUPED[unit] = true
end

local unitDefs = {}

---@class UnitFramesIndicatorDef
---@field key string
---@field label string display name, used by the GUI tabs and the page search index
---@field element string
---@field units? table<string, boolean> config keys it applies to, nil for every unit
---@field topLevel? string a UF.TopLevels key, when the icon needs a frame level of its own
---@field art UnitFramesIndicatorArt[] the first entry is what an unrecognized Texture falls back to
---@field configure? fun(tex: Texture, db: table) settings beyond size and position
---@field postUpdate? fun(element: Texture, ...) oUF PostUpdate, for filtering what the element shows

UF.IndicatorDefs = {
    {
        key = 'Resting',
        label = L['Resting'],
        element = 'RestingIndicator',
        units = { player = true },
        art = {
            { key = 'Blizzard', label = L['Blizzard'], texture = [[Interface\HUD\UIUnitFrameRestingFlipbook]], coords = { 45 / 360, 80 / 360, 200 / 420, 240 / 420 }, desaturated = true },
        },
    },
    {
        key = 'Combat',
        label = L['Combat'],
        element = 'CombatIndicator',
        units = { player = true },
        art = {
            { key = 'Blizzard', label = L['Blizzard'], atlas = 'UI-HUD-UnitFrame-Player-CombatIcon' },
        },
    },
    {
        key = 'Quest',
        label = L['Quest'],
        element = 'QuestIndicator',
        units = { target = true },
        art = {
            { key = 'Blizzard', label = L['Blizzard'], atlas = 'UI-HUD-UnitFrame-Target-PortraitOn-Boss-Quest' },
        },
    },
    {
        key = 'ReadyCheck',
        label = L['Ready Check'],
        element = 'ReadyCheckIndicator',
        units = GROUP_UNITS,
        art = {
            { key = 'Blizzard', label = L['Blizzard'], atlas = 'UI-LFG-ReadyMark-Raid' },
        },
    },
    {
        key = 'Role',
        label = L['Group Role'],
        element = 'GroupRoleIndicator',
        units = GROUP_UNITS,
        art = {
            { key = 'Blizzard', label = L['Blizzard'], atlas = 'UI-LFG-RoleIcon-Healer-Micro-Raid' },
        },
        configure = function(tex, db) tex.nuiTankHealerOnly = db.TankHealerOnly end,
        postUpdate = function(element, role)
            if element.nuiTankHealerOnly and role == Enum.LFGRole.Damage then
                element:Hide()
            end
        end,
    },
    {
        key = 'Summon',
        label = L['Summon'],
        element = 'SummonIndicator',
        units = GROUPED,
        art = {
            { key = 'Blizzard', label = L['Blizzard'], atlas = 'RaidFrame-Icon-SummonPending' },
        },
    },
    {
        key = 'Resurrect',
        label = L['Resurrect'],
        element = 'ResurrectIndicator',
        units = GROUPED,
        art = {
            { key = 'Blizzard', label = L['Blizzard'], atlas = 'RaidFrame-Icon-Rez' },
        },
    },
    {
        key = 'PvP',
        label = L['PvP'],
        element = 'PvPIndicator',
        units = PLAYER_UNITS,
        art = {
            { key = 'Blizzard', label = L['Blizzard'], texture = [[Interface\TargetingFrame\UI-PVP-Horde]], coords = { 0, 0.65625, 0, 0.65625 } },
        },
    },
    {
        key = 'Phase',
        label = L['Phase'],
        element = 'PhaseIndicator',
        units = PLAYER_UNITS,
        art = {
            { key = 'Blizzard', label = L['Blizzard'], atlas = 'RaidFrame-Icon-Phasing' },
        },
    },
    {
        key = 'Leader',
        label = L['Leader Indicator'],
        element = 'LeaderIndicator',
        units = PLAYER_UNITS,
        art = {
            { key = 'Blizzard', label = L['Blizzard'], atlas = 'UI-HUD-UnitFrame-Player-Group-LeaderIcon' },
        },
    },
    {
        key = 'RaidIcon',
        label = L['Raid Icon'],
        element = 'RaidTargetIndicator',
        topLevel = 'RaidMark',
        art = {
            { key = 'Blizzard', label = L['Blizzard'], texture = [[Interface\TargetingFrame\UI-RaidTargetingIcons]], coords = { 0, 0.25, 0, 0.25 } },
        },
    },
}

---@param unit string config key or unit token
---@return UnitFramesIndicatorDef[]
function UF.UnitIndicators(unit)
    local key = UF.ConfigKey(unit)
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

-- Previewed group frames cycle these instead of repeating the player's own role.
local PREVIEW_ROLES = { 'Tank', 'Healer', 'DPS' }
local PREVIEW_ROLES_NO_DPS = { 'Tank', 'Healer' }

---@param frame oUF.UnitFrame
---@param db table
---@return string atlas
local function PreviewRoleAtlas(frame, db)
    local roles = db.TankHealerOnly and PREVIEW_ROLES_NO_DPS or PREVIEW_ROLES

    -- Offset by subgroup so columns do not repeat the same run.
    local header = frame:GetParent()
    local slot = (frame.nuiPreviewIndex or 1) + ((header and header.nuiGroup or 0))

    return format('UI-LFG-RoleIcon-%s-Micro-Raid', roles[slot % #roles + 1])
end

---@param tex Texture
---@param def UnitFramesIndicatorDef
---@param db table the unit's Indicators[def.key] block
local function ApplyArt(tex, def, db)
    local art = def.art[1]
    for _, variant in ipairs(def.art) do
        if variant.key == db.Texture then
            art = variant
            break
        end
    end

    if art.atlas then
        tex:SetAtlas(art.atlas)
    else
        tex:SetTexture(art.texture)
        if art.coords then
            tex:SetTexCoord(unpack(art.coords))
        else
            tex:SetTexCoord(0, 1, 0, 1) -- Switching off a cropped variant, nothing else puts the rect back
        end
    end

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
        container:NUISetPixelPoint('TOPLEFT', self, 'TOPLEFT', 0, 0)
        container:NUISetPixelPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 0)
        container:SetFrameLevel(UF.TopLevels.Status)
        container:SetFrameStrata('MEDIUM')
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
            ApplyArt(tex, def, db)

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

        -- Previewed group frames have no real role, so this ignores the open sub-tab.
        local groupRoles = self.nuiGroupChild and self.nuiPreviewUnit ~= nil

        for _, def in ipairs(UF.UnitIndicators(unit)) do
            local tex = self[def.element]

            if groupRoles and def.key == 'Role' and uDB.Indicators.Role.Enabled then
                tex.Override = function() NRSKNUI:NOP() end
                tex:SetAtlas(PreviewRoleAtlas(self, uDB.Indicators.Role))
                tex:SetDesaturated(nil)
                tex:Show()
            elseif def.key == previewed then
                tex.Override = function() NRSKNUI:NOP() end
                ApplyArt(tex, def, uDB.Indicators[def.key]) -- oUF only applies art on enable, so a disabled one has none yet
                tex:Show()
            elseif tex.Override then
                tex.Override = nil
                tex:Hide() -- a disabled element has no update of its own to take it back down
                restore = true
            end
        end

        -- Restore the real states.
        if restore then
            self:UpdateAllElements('ForceUpdate')
        end
    end,
}
