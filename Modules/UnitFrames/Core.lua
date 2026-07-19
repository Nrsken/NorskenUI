---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFrames
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local EM = NRSKNUI.EditMode

local upper = string.upper
local pairs = pairs
local ipairs = ipairs
local RegisterUnitWatch = RegisterUnitWatch
local UnregisterUnitWatch = UnregisterUnitWatch

UF.frames = UF.frames or {}     -- unit -> oUF object, used for global restyles.
UF.Elements = UF.Elements or {} -- name -> { Construct, Configure }, populated by element files.

function UF:UpdateDB()
    self.db = NRSKNUI.db.profile.UnitFrames
end

function UF:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

---Global show tooltip handler for all unit frames.
---@param unit string
function UF:ShowTooltip(unit)
    if GameTooltip:IsForbidden() then return end

    GameTooltip:SetOwner(UIParent, 'ANCHOR_NONE')
    GameTooltip:SetPoint('BOTTOMRIGHT', _G.NRSKNUI_TooltipAnchorFrame or GameTooltipDefaultContainer) -- Use my own anchor from 'Modules\AdvancedSkinning\Tooltips.lua' or fallback to default.

    if GameTooltip:SetUnit(unit) then
        GameTooltip:Show()
    end
end

---Global hide tooltip handler for all unit frames.
function UF:HideTooltip()
    GameTooltip:Hide()
end

---Construct a new oUF frame and apply the style function to it.
---@param name string
---@param frame oUF.UnitFrame
---@param unit string
function UF:ConstructElement(name, frame, unit)
    local def = UF.Elements[name]

    if def and def.Construct then
        def.Construct(frame, unit)
    end
end

---Set enabled/disabled for a constructed element on a frame.
---@param frame oUF.UnitFrame
---@param name string
---@param widget oUF.Castbar|oUF.Power|oUF.Health
---@param enabled boolean
local function SetElement(frame, name, widget, enabled)
    if not widget then return end
    if enabled then
        frame:EnableElement(name)
        widget:Show()
    else
        frame:DisableElement(name)
        widget:Hide()
    end
end

---Apply the DB Enabled flags to a frame's constructed elements.
---@param frame oUF.UnitFrame
---@param unit string
---@param uDB table
function UF:ApplyElementStates(frame, unit, uDB)
    -- Handle power element
    SetElement(frame, 'Power', frame.Power, uDB.Power.Enabled)
    if frame.powerBackground then frame.powerBackground:SetShown(uDB.Power.Enabled) end
    if frame.powerBorderFrame then frame.powerBorderFrame:SetShown(uDB.Power.Enabled) end

    -- Handle castbar element
    SetElement(frame, 'Castbar', frame.Castbar, uDB.Castbar.Enabled)

    -- Handle RaidTargetIndicator and LeaderIndicator elements
    SetElement(frame, 'RaidTargetIndicator', frame.RaidTargetIndicator, uDB.RaidIcon.Enabled)
    SetElement(frame, 'LeaderIndicator', frame.LeaderIndicator, uDB.LeaderIndicator.Enabled)
end

---Apply the whole DB to one frame: geometry, backdrop, every element and then one ForceUpdate.
---@param frame oUF.UnitFrame
---@param unit string
function UF:ConfigureFrame(frame, unit)
    local uDB = UF.GetUnitDB(unit)
    local general = self.db.General

    frame:SetPixelSize(uDB.Width, uDB.Height)
    frame:ApplyPosition(uDB)

    for _, def in pairs(UF.Elements) do
        if def.Configure then
            def.Configure(frame, unit, uDB, general)
        end
    end

    -- oUF auto-enables elements on spawn, so ApplyElementStates is only needed for later DB changes.
    if frame.nuiBuilt then
        self:ApplyElementStates(frame, unit, uDB)
    end

    frame:UpdateAllElements('ForceUpdate')
end

---Generate a global name for a unit frame, e.g. "NUF_Player" or "NUF_TargetTarget".
---@param unit string
---@return string
local function GlobalName(unit)
    local label = unit:gsub('^%l', upper)   -- Player, Targettarget, ...
    label = label:gsub('target$', 'Target') -- TargetTarget, FocusTarget, PetTarget
    return 'NUF_' .. label
end

-- Spawn units and register them with anchors.
function UF:SpawnUnits()
    oUF:SetActiveStyle(self.styleName)

    for _, unit in ipairs(UF.SoloUnits) do
        local frame = UF.frames[unit]
        if not frame then
            frame = oUF:Spawn(unit, GlobalName(unit))
            UF.frames[unit] = frame

            if EM and EM.Register then
                EM:Register(self, 'UnitFrame_' .. unit, frame, nil, { db = UF.GetUnitDB(unit) })
            end
        else
            RegisterUnitWatch(frame)
        end
    end
end

function UF:OnEnable()
    self:UpdateDB()

    self.TagSeparator = self.db.TagSettings.Separator
    self.styleName = NRSKNUI.oUFPrefix .. 'Solo'

    if not self.styleRegistered then
        oUF:RegisterStyle(self.styleName, function(frame, unit) UF:BuildStyle(frame, unit) end)
        self.styleRegistered = true
    end

    -- Deferring the spawn of units until combat has ended.
    NRSKNUI:RunWhenSafe(function()
        self:SpawnUnits()
    end)
end

-- Universal re-read-and-apply entry point.
function UF:ApplySettings()
    self:UpdateDB()

    self.TagSeparator = self.db.TagSettings.Separator
    NRSKNUI:RunWhenSafe(function()
        for unit, frame in pairs(UF.frames) do
            self:ConfigureFrame(frame, unit)
        end
    end)
end

function UF:OnDisable()
    NRSKNUI:RunWhenSafe(function()
        for _, frame in pairs(UF.frames) do
            UnregisterUnitWatch(frame)
            frame:Hide()
        end
    end)
end
