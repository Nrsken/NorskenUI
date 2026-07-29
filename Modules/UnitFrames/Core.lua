---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
---@field IndicatorDefs { key: string, element: string }[]
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local Anchors = NRSKNUI.Anchors

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
---@param widget oUF.ToggleWidget?
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

    -- Handle the native indicator elements
    for _, def in ipairs(UF.IndicatorDefs) do
        SetElement(frame, def.element, frame[def.element], uDB.Indicators[def.key].Enabled)
    end
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
        if uDB.Enabled then
            RegisterUnitWatch(frame)
        else
            UnregisterUnitWatch(frame)
            frame:Hide()
        end
    end

    frame:UpdateAllElements('ForceUpdate')
end

---Title-case a unit into a readable label, e.g. 'targettarget' -> 'TargetTarget'.
---@param unit string
---@return string
local function UnitLabel(unit)
    local label = unit:gsub('^%l', upper)    -- Player, Targettarget, ...
    return (label:gsub('target$', 'Target')) -- TargetTarget, FocusTarget, PetTarget
end

---Generate a global name for a unit frame, e.g. 'NUF_Player' or 'NUF_TargetTarget'.
---@param unit string
---@return string
local function GlobalName(unit)
    return 'NUF_' .. UnitLabel(unit)
end

-- Spawn units and register them with anchors.
function UF:SpawnUnits()
    oUF:SetActiveStyle(self.styleName)

    for _, unit in ipairs(UF.SoloUnits) do
        local frame = UF.frames[unit]
        if not frame then
            frame = oUF:Spawn(unit, GlobalName(unit))
            UF.frames[unit] = frame

            -- db is resolved live rather than captured: UF.db is reassigned by UpdateDB()
            -- on a profile switch, so a captured table would write to the old profile.
            Anchors:Register(self, 'UnitFrame_' .. unit, frame, 'unitFramesUnits', {
                displayName = UnitLabel(unit),
                db = function() return UF.GetUnitDB(unit) end,
                guiContext = unit,
            })

            -- oUF auto-enables every constructed element during Spawn, and the PLAYER_ENTERING_WORLD
            -- ApplySettings can land before this deferred spawn, so the disabled ones are backed out
            -- here. The repaint settles the status-driven elements SetElement force-shows.
            self:ApplyElementStates(frame, unit, UF.GetUnitDB(unit))
            frame:UpdateAllElements('ForceUpdate')
        else
            RegisterUnitWatch(frame)
        end

        -- oUF:Spawn registers the unit watch itself, so disabled units back it out here.
        if not UF.GetUnitDB(unit).Enabled then
            UnregisterUnitWatch(frame)
            frame:Hide()
        end
    end
end

function UF:OnEnable()
    self:UpdateDB()
    self:CreateCDMAnchor()

    -- List of unit frames that we tell SCM that we created, so SCM can find them easily by typing 'NUF' in the anchor search box.
    self.NRSKNUFAnchors = {
        ["Player"] = "NUF_Player",
        ["Target"] = "NUF_Target",
        ["Pet"] = "NUF_Pet",
        ["Focus"] = "NUF_Focus",
        ["Focus Target"] = "NUF_FocusTarget",
        ["Target of Target"] = "NUF_TargetTarget",
    }
    if SCMAPI and SCMAPI.RegisterAnchorParents then
        SCMAPI.RegisterAnchorParents("NorskenUI", self.NRSKNUFAnchors)
    end

    self.TagSeparator = self.db.TagSettings.Separator
    self.styleName = NRSKNUI.oUFPrefix .. 'Solo'

    if not self.styleRegistered then
        oUF:RegisterStyle(self.styleName, function(frame, unit) UF:BuildStyle(frame, unit) end)
        self.styleRegistered = true
    end

    NRSKNUI.AuraFilters:RegisterCallback(self, function(module) module:ReapplyAuraFilters() end)

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
    NRSKNUI.AuraFilters:UnregisterCallback(self)
    NRSKNUI:RunWhenSafe(function()
        for _, frame in pairs(UF.frames) do
            UnregisterUnitWatch(frame)
            frame:Hide()
        end
    end)
end
