---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
---@class NorskenUF
local oUF = NRSKNUI.oUF
local Anchors = NRSKNUI.Anchors
local L = NRSKNUI.Libs.AL

local upper = string.upper
local format = string.format
local pairs = pairs
local ipairs = ipairs
local CreateFrame = CreateFrame
local RegisterUnitWatch = RegisterUnitWatch
local UnregisterUnitWatch = UnregisterUnitWatch
local UnregisterStateDriver = UnregisterStateDriver

UF.Elements = UF.Elements or {} -- name -> { Construct, Configure }, populated by element files.

---Copies a colour out of the DB onto a frame field, reusing the frame's own table.
---Never store the DB table itself: AceDB strips default-valued keys out of the old profile in place
---during SetProfile, so a captured colour becomes an empty table the moment the profile changes and
---every read of it after that hands nil to SetStatusBarColor.
---@param owner table frame or element the colour is cached on
---@param key string field name to cache under
---@param src table {r, g, b, a} read from the DB
---@return table cached
function UF.CacheColor(owner, key, src)
    local cached = owner[key]
    if not cached then
        cached = {}
        owner[key] = cached
    end
    cached[1], cached[2], cached[3], cached[4] = src[1], src[2], src[3], src[4]
    return cached
end

function UF:UpdateDB()
    self.db = NRSKNUI.db.profile.UnitFrames
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

    if not frame.nuiPreviewUnit then
        if enabled then
            frame:EnableElement(name)
        else
            frame:DisableElement(name)
        end
    end

    widget:SetShown(enabled)
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

    -- Handle the native indicator elements.
    for _, def in ipairs(UF.UnitIndicators(frame.nuiConfig or unit)) do
        local tex = frame[def.element]
        local enabled = uDB.Indicators[def.key].Enabled

        if tex then
            if not frame.nuiPreviewUnit then
                if enabled then
                    frame:EnableElement(def.element)
                else
                    frame:DisableElement(def.element)
                end
            end

            if not enabled then tex:Hide() end
        end
    end

    -- oUF's Range element is a plain options table rather than a widget, so it cannot go through
    -- SetElement. Group frames are the only ones that carry it, see Elements/Range.lua.
    if frame.Range and not frame.nuiPreviewUnit then
        if self.db.General.Range.Enabled then
            frame:EnableElement('Range')
        else
            frame:DisableElement('Range')
        end
    end
end

-- Anchor pair and offset sign each growth direction chains a boss frame off its predecessor with.
local BOSS_GROWTH = {
    UP    = { from = 'BOTTOMLEFT', to = 'TOPLEFT', x = 0, y = 1 },
    DOWN  = { from = 'TOPLEFT', to = 'BOTTOMLEFT', x = 0, y = -1 },
    LEFT  = { from = 'TOPRIGHT', to = 'TOPLEFT', x = -1, y = 0 },
    RIGHT = { from = 'TOPLEFT', to = 'TOPRIGHT', x = 1, y = 0 },
}

-- Corner of boss1 the chain grows away from, and the axis it grows along. Mirrors BOSS_GROWTH: the
-- overlay span starts at the frame that holds the position and extends over the rest of the chain.
local BOSS_SPAN = {
    UP    = { point = 'BOTTOMLEFT', vertical = true },
    DOWN  = { point = 'TOPLEFT', vertical = true },
    LEFT  = { point = 'TOPRIGHT', vertical = false },
    RIGHT = { point = 'TOPLEFT', vertical = false },
}

---The frame the boss anchor overlay covers. Only boss1 carries the group's position, so it is the one
---that gets dragged, but the overlay should be grabbable across the whole chain. Anchored to boss1 so
---it tracks a live drag rather than snapping into place at the end of one.
---@return Frame
function UF:GetBossSpan()
    if not self.bossSpan then
        self.bossSpan = CreateFrame('Frame', nil, UIParent)
    end
    return self.bossSpan
end

---Size the span to the footprint of every boss frame, whether or not that boss exists right now.
function UF:UpdateBossSpan()
    local first = UF.frames.boss1
    if not first then return end

    local uDB = UF.GetUnitDB('boss1')
    local growth = BOSS_SPAN[uDB.GrowthDirection] or BOSS_SPAN.DOWN
    local count = #UF.BossUnits
    local size = growth.vertical and uDB.Height or uDB.Width
    local extent = count * size + (count - 1) * (uDB.Spacing or 0)

    local span = self:GetBossSpan()
    span:ClearAllPoints()
    span:SetPoint(growth.point, first, growth.point, 0, 0)
    span:SetSize(growth.vertical and uDB.Width or extent, growth.vertical and extent or uDB.Height)
end

---Position one frame. Every unit reads its own position out of the DB, except boss frames past the
---first, which chain off their predecessor so the whole group moves with the one mover on boss1.
---@param frame oUF.UnitFrame
---@param unit string
---@param uDB table
function UF:ApplyUnitPosition(frame, unit, uDB)
    local index = UF.BossIndex(unit)
    local previous = index and index > 1 and UF.frames['boss' .. (index - 1)]
    if not previous then
        frame:NUIApplyPosition(uDB)
        return
    end

    local growth = BOSS_GROWTH[uDB.GrowthDirection] or BOSS_GROWTH.DOWN
    local spacing = uDB.Spacing or 0

    frame:ClearAllPoints()
    frame:NUISetPixelPoint(growth.from, previous, growth.to, growth.x * spacing, growth.y * spacing)
    frame:SetFrameStrata(uDB.Strata or 'MEDIUM')
end

---Apply the whole DB to one frame: geometry, backdrop, every element and then one ForceUpdate.
---@param frame oUF.UnitFrame
---@param unit string
function UF:ConfigureFrame(frame, unit)
    local uDB = UF.GetUnitDB(frame.nuiConfig or unit)
    local general = self.db.General

    if not frame.nuiGroupChild then
        frame:NUISetPixelSize(uDB.Width, uDB.Height)
        self:ApplyUnitPosition(frame, unit, uDB)
    elseif frame.nuiBuilt and not NRSKNUI:InCombat() then
        frame:NUISetPixelSize(uDB.Width, uDB.Height)
    end

    for _, def in pairs(UF.Elements) do
        if def.Configure then
            def.Configure(frame, unit, uDB, general)
        end
    end

    if frame.nuiBuilt then
        self:ApplyElementStates(frame, unit, uDB)

        if not frame.nuiPreviewUnit and not frame.nuiGroupChild then
            if uDB.Enabled then
                RegisterUnitWatch(frame)
            else
                UnregisterUnitWatch(frame)
                frame:Hide()
            end
        end
    end

    frame:UpdateAllElements('ForceUpdate')

    -- Preview overrides land last. They hand-drive elements that the pass above resets (the castbar
    -- has nothing to draw when its unit is idle), so they have to run after the final repaint.
    self:ApplyElementPreviews(frame, unit, frame.nuiPreviewUnit ~= nil)
end

---Run every element's preview hook for one frame. Everything these hooks touch is unprotected, so
---this is also the part of a preview that can be torn down mid-combat.
---@param frame oUF.UnitFrame
---@param unit string
---@param previewing boolean
function UF:ApplyElementPreviews(frame, unit, previewing)
    local uDB = UF.GetUnitDB(frame.nuiConfig or unit)
    local general = self.db.General

    for _, def in pairs(UF.Elements) do
        if def.Preview then
            def.Preview(frame, unit, uDB, general, previewing)
        end
    end
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

---Spawn one unit, wire it up, and settle its visibility.
---@param unit string
---@param opts table? anchor overrides: skipAnchor, displayName, overlayFrame
---@return oUF.UnitFrame
function UF:SpawnUnit(unit, opts)
    opts = opts or {}

    local frame = UF.frames[unit]
    if not frame then
        frame = oUF:Spawn(unit, GlobalName(unit))
        UF.frames[unit] = frame

        if not opts.skipAnchor then
            -- db is resolved live rather than captured: UF.db is reassigned by UpdateDB()
            -- on a profile switch, so a captured table would write to the old profile.
            Anchors:Register(self, 'UnitFrame_' .. unit, frame, 'unitFrames_' .. UF.NormalizeUnit(unit), {
                displayName = opts.displayName or UnitLabel(unit),
                db = function() return UF.GetUnitDB(unit) end,
                guiContext = 'frame',
                overlayFrame = opts.overlayFrame,
            })
        end

        frame:UpdateAllElements('ForceUpdate')
    elseif not frame.nuiPreviewUnit then
        RegisterUnitWatch(frame)
    end

    -- oUF:Spawn registers the unit watch itself, so disabled units back it out here. A previewing
    -- frame owns its own visibility until the preview is stopped.
    if not frame.nuiPreviewUnit and not UF.GetUnitDB(unit).Enabled then
        UnregisterUnitWatch(frame)
        frame:Hide()
    end

    return frame
end

-- Spawn units and register them with anchors.
function UF:SpawnUnits()
    oUF:SetActiveStyle(self.styleName)

    for _, unit in ipairs(UF.SoloUnits) do
        self:SpawnUnit(unit)
    end

    -- Boss frames chain off boss1, so only boss1 gets a mover. They spawn in order because every
    -- frame anchors to the one before it.
    for index, unit in ipairs(UF.BossUnits) do
        local frame = self:SpawnUnit(unit, {
            skipAnchor = index > 1,
            displayName = L['Boss Frames'],
            overlayFrame = index == 1 and self:GetBossSpan() or nil,
        })
        UF.Preview:Register('boss', frame, 'player', format('%s %d', L['Boss'], index))
    end

    self:UpdateBossSpan()
    self:SpawnGroups()
end

function UF:OnEnable()
    -- Main.lua already skips us on login, this catches the GUI toggle re-enabling us in session.
    if NRSKNUI.UFBlocked then return end

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
    for index = 1, UF.MAX_BOSS_FRAMES do
        self.NRSKNUFAnchors[format('Boss %d', index)] = 'NUF_Boss' .. index
    end
    if SCMAPI and SCMAPI.RegisterAnchorParents then
        SCMAPI.RegisterAnchorParents("NorskenUI", self.NRSKNUFAnchors)
    end

    self.TagSeparator = self.db.TagSettings.Separator
    self.styleName = NRSKNUI.oUFPrefix .. 'Solo'

    if not self.styleRegistered then
        oUF:RegisterStyle(self.styleName, function(frame, unit) UF:BuildStyle(frame, unit) end)
        oUF:RegisterInitCallback(function(frame)
            local key = frame.nuiConfig -- only our own style sets this
            if key then
                UF:ApplyElementStates(frame, key, UF.GetUnitDB(key))
                -- Again after the auto-enable, since a preview forces elements off to hold an icon up.
                UF:ApplyElementPreviews(frame, key, frame.nuiPreviewUnit ~= nil)
            end
        end)

        self.styleRegistered = true
    end

    NRSKNUI.AuraTriggers:RegisterCallback(self, function(module) module:ReapplyAuraFilters() end)
    NRSKNUI.AuraIndicators:RegisterCallback(self, function(module) module:ReapplyAuraIndicators() end)

    -- Deferring the spawn of units until combat has ended.
    NRSKNUI:RunWhenSafe(function()
        self:SpawnUnits()
    end)
end

---Universal re-read-and-apply entry point.
---@param configKey string? restrict the pass to one unit's frames, which is all the GUI ever changes
function UF:ApplySettings(configKey)
    self:UpdateDB()

    self.TagSeparator = self.db.TagSettings.Separator
    NRSKNUI:RunWhenSafe(function()
        UF:ForEachFrame(function(frame, unit) self:ConfigureFrame(frame, unit) end, configKey)

        if not configKey or configKey == 'boss' then
            self:UpdateBossSpan() -- boss size, spacing and growth all move the group's footprint
        end

        for key in pairs(UF.GroupConfigs) do
            if not configKey or configKey == key then
                self:LayoutGroup(key)
            end
        end
    end)
end

function UF:OnDisable()
    NRSKNUI.AuraTriggers:UnregisterCallback(self)
    NRSKNUI.AuraIndicators:UnregisterCallback(self)
    UF.Preview:ReleaseAll()
    NRSKNUI:RunWhenSafe(function()
        for _, frame in pairs(UF.frames) do
            UnregisterUnitWatch(frame)
            frame:Hide()
        end
        for _, group in pairs(UF.groups) do
            UnregisterStateDriver(group.container, 'visibility')
            group.container:Hide()
        end
    end)
end
