---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
local UF = NRSKNUI:GetModule('UnitFrames')

local ipairs = ipairs
local CreateFrame = CreateFrame

-- Native oUF indicator elements, keyed into uDB.Indicators. Consumed by the GUI and ApplyElementStates.
UF.IndicatorDefs = {
    { key = 'Resting',    element = 'RestingIndicator' },
    { key = 'Combat',     element = 'CombatIndicator' },
    { key = 'ReadyCheck', element = 'ReadyCheckIndicator' },
    { key = 'Summon',     element = 'SummonIndicator' },
    { key = 'Resurrect',  element = 'ResurrectIndicator' },
    { key = 'Quest',      element = 'QuestIndicator' },
    { key = 'PvP',        element = 'PvPIndicator' },
    { key = 'Phase',      element = 'PhaseIndicator' },
}

UF.Elements = UF.Elements or {}
UF.Elements.Indicators = {
    Construct = function(frame, unit)
        if frame.IndicatorContainer then return end

        -- Own overlay above the text container so icons never sit behind the name.
        local container = CreateFrame('Frame', nil, frame)
        container:SetPixelPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        container:SetPixelPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        container:SetFrameLevel(1000)
        container:SetFrameStrata("MEDIUM")
        frame.IndicatorContainer = container

        -- oUF applies each element's default texture/atlas on enable.
        for _, def in ipairs(UF.IndicatorDefs) do
            frame[def.element] = container:CreateTexture(nil, 'OVERLAY')
        end
    end,

    Configure = function(frame, unit, uDB, general)
        local container = frame.IndicatorContainer

        for _, def in ipairs(UF.IndicatorDefs) do
            local db = uDB.Indicators[def.key]
            local tex = frame[def.element]

            tex:SetPixelSize(db.Size, db.Size)
            tex:ClearAllPoints()
            tex:SetPixelPoint(db.Position.AnchorFrom, container, db.Position.AnchorTo, db.Position.XOffset, db.Position.YOffset)
        end
    end,
}
