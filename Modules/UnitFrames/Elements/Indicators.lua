---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field IndicatorDefs UnitFramesIndicatorDef
---@field Elements UnitFramesElements
local UF = NRSKNUI:GetModule('UnitFrames')

local ipairs = ipairs
local CreateFrame = CreateFrame
local unpack = unpack

-- Native oUF indicator elements, keyed into uDB.Indicators. Consumed by the GUI and ApplyElementStates.
---@class UnitFramesIndicatorDef
---@field key string
---@field element string
---@field texture? boolean
---@field atlas? boolean
---@field path? string
---@field coords? number[]
---@field desaturated? boolean
UF.IndicatorDefs = {
    { key = 'Resting',    element = 'RestingIndicator',   texture = true, path = [[Interface\HUD\UIUnitFrameRestingFlipbook]], coords = { 45 / 360, 80 / 360, 200 / 420, 240 / 420 }, desaturated = true },
    { key = 'Combat',     element = 'CombatIndicator' },
    { key = 'ReadyCheck', element = 'ReadyCheckIndicator' },
    { key = 'Summon',     element = 'SummonIndicator' },
    { key = 'Resurrect',  element = 'ResurrectIndicator' },
    { key = 'Quest',      element = 'QuestIndicator' },
    { key = 'PvP',        element = 'PvPIndicator' },
    { key = 'Phase',      element = 'PhaseIndicator' },
}

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
        container:SetFrameLevel(1000)
        container:SetFrameStrata("MEDIUM")
        self.IndicatorContainer = container

        -- oUF applies each element's default texture/atlas on enable.
        for _, def in ipairs(UF.IndicatorDefs) do
            self[def.element] = container:CreateTexture(nil, 'OVERLAY')
        end
    end,

    ---@param self oUF.UnitFrame
    ---@param unit string
    ---@param uDB table
    ---@param general table
    Configure = function(self, unit, uDB, general)
        local container = self.IndicatorContainer

        for _, def in ipairs(UF.IndicatorDefs) do
            local db = uDB.Indicators[def.key]
            local tex = self[def.element]

            tex:NUISetPixelSize(db.Size, db.Size)
            tex:ClearAllPoints()
            tex:NUISetPixelPoint(db.Position.AnchorFrom, container, db.Position.AnchorTo, db.Position.XOffset, db.Position.YOffset)
            if def.texture then
                tex:SetTexture(def.path)
                tex:SetTexCoord(unpack(def.coords))
                tex:SetDesaturated(def.desaturated)
            elseif def.atlas then
                tex:SetAtlas(def.atlas)
            end
        end
    end,
}
