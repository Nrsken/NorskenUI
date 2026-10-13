---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local Anchors = NRSKNUI.Anchors
local LoadConditions = NRSKNUI.LoadConditions
local L = NRSKNUI.Libs.AL

local GetPhysicalScreenSize = GetPhysicalScreenSize
local tremove, tsort = table.remove, table.sort
local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local format = string.format
local tostring = tostring
local type = type
local floor = math.floor
local wipe = wipe

local SetCVar = C_CVar and C_CVar.SetCVar
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCharges = C_Spell.GetSpellCharges
local IsSpellUsable = C_Spell.IsSpellUsable
local GetTime = GetTime
local GetSpellName = C_Spell and C_Spell.GetSpellName

local GUI_PAGE = 'cooldownManager'
local STATIC_GROUP_SIZE = 32 -- a static group draws nothing; this is what its mover grabs

function CDM:UpdateDB()
    local db = NRSKNUI.db.profile.CDM
    -- Frames are keyed by display id, and another profile reuses the same ids for other displays.
    if self.icons and self.db ~= db then
        self:ReleaseAll()
        wipe(self.preview)
        wipe(self.selectionPreview)
    end
    self.db = db
    self:Migrate(db)
    self:EnsureUids()
end

function CDM:OnInitialize()
    self:UpdateDB()
    self.icons = {} ---@type table<string, CDMIcon>
    self.containers = {} ---@type table<string, Frame|NRSKNUI.DynamicGroup>
    self.spareStatic = {} ---@type Frame[]
    self.spareDynamic = {} ---@type NRSKNUI.DynamicGroup[]
    self.spareChain = {} ---@type CDMChainGroup[]
    self.preview = {} ---@type table<string, number>
    self.selectionPreview = {} ---@type string[]
end

---@param id string
---@return table
local function AnchorOptions(id)
    return {
        db = function() return CDM:Get(id) end,
        apply = function(aceModule) aceModule:ApplySettings(id) end,
        displayName = CDM:GetName(id),
    }
end

---Top-level displays sit on the screen with a mover; inside a static group they hang off its frame.
---@param frame Frame
---@param id string
---@param display table
---@param point string? the frame's own anchor, when it isn't Position.AnchorFrom (a dynamic group's grow anchor)
function CDM:Place(frame, id, display, point)
    local parent = display.parent and self:Get(display.parent)
    local position = display.Position

    -- Edge to edge on the icons themselves, so the engine sizes the bar; a group holding auras has a secret width.
    local matched = display.MatchWidth and self.containers[display.MatchWidth]
    if matched then
        local above = display.MatchSide == 'ABOVE'
        local gap = display.MatchGap or 0
        local left, right, padX, padY = matched, matched, 0, 0
        if matched.isChain then
            ---@cast matched CDMChainGroup
            -- The visible row, whose slots each carry their spacing on the right or bottom.
            left, right = matched.chain, matched.chain
            local spacing = matched.config.Spacing or 1
            if (self.CHAIN_GROWS[matched.config.Grow] or self.CHAIN_GROWS.RIGHT).horizontal then padX = spacing else padY = spacing end
        elseif matched.GetHorizontalEnds then
            ---@cast matched NRSKNUI.DynamicGroup
            local first, last = matched:GetHorizontalEnds()
            if first and last then left, right = first, last end
        end
        local y = above and gap or padY - gap
        local edge, groupEdge = above and 'BOTTOM' or 'TOP', above and 'TOP' or 'BOTTOM'
        frame:SetParent(parent and self.containers[display.parent] or UIParent)
        frame:ClearAllPoints()
        frame:NUISetPixelPoint(edge .. 'LEFT', left, groupEdge .. 'LEFT', 0, y)
        frame:NUISetPixelPoint(edge .. 'RIGHT', right, groupEdge .. 'RIGHT', -padX, y)
        frame:SetFrameStrata(display.Strata or matched:GetFrameStrata())
        Anchors:Unregister(id)
        return
    end

    if parent then
        local host = self.containers[display.parent]
        frame:SetParent(host)
        frame:ClearAllPoints()
        -- A picked frame wins over the group; the group still owns its visibility.
        local target = display.anchorFrameType == 'SELECTFRAME' and display.ParentFrame and _G[display.ParentFrame] or host
        frame:NUISetPixelPoint(point or position.AnchorFrom, target, position.AnchorTo, position.XOffset, position.YOffset)
        frame:SetFrameStrata(display.Strata or host:GetFrameStrata())
        Anchors:Unregister(id)
        return
    end

    frame:SetParent(UIParent)
    if point then
        ---@cast frame NRSKNUI.DynamicGroup
        frame:UpdateGroupPosition(display, display.Layout.Grow)
    else
        frame:NUIApplyPosition(display)
    end
    Anchors:Register(self, id, frame, GUI_PAGE, AnchorOptions(id))
end

---@param frame Frame
---@param point string
---@return number? x, number? y screen coordinates
local function PointCoords(frame, point)
    -- An icon in an engine-laid group (one holding an aura) has a secret rect.
    local left, bottom, width, height = NRSKNUI:ScrubSecrets(frame:GetRect())
    if not (left and bottom and width and height) then return end
    local scale = frame:GetEffectiveScale()
    local x = point:find('LEFT') and left or point:find('RIGHT') and left + width or left + width / 2
    local y = point:find('TOP') and bottom + height or point:find('BOTTOM') and bottom or bottom + height / 2
    return x * scale, y * scale
end

---Rewrite a display's offsets so it stays where it is on screen under a new parent.
---@param id string
---@param parentId string?
function CDM:KeepPlace(id, parentId)
    local display = self:Get(id)
    local position = display and display.Position
    local frame = self.containers[id] or self.icons[id] or self:GetAuraHost(id)
    if not (position and frame) then return end
    if display.anchorFrameType == 'SELECTFRAME' then return end -- anchored to its frame, wherever its group goes

    local host
    if parentId then
        host = self.containers[parentId]
    elseif display.anchorFrameType == 'SELECTFRAME' then
        host = _G[display.ParentFrame] or UIParent
    else
        host = UIParent
    end
    if not host then return end

    local point = display.type == 'dynamicgroup' and frame:GetResolvedAnchor(display.Layout.Grow) or position.AnchorFrom
    local fx, fy = PointCoords(frame, point)
    local hx, hy = PointCoords(host, position.AnchorTo)
    if not (fx and hx) then return end

    local scale = frame:GetEffectiveScale()
    position.XOffset = floor((fx - hx) / scale * 10 + 0.5) / 10
    position.YOffset = floor((fy - hy) / scale * 10 + 0.5) / 10
end

-- Containers --

---Groups holding an aura icon or a text are laid out by the engine, as their sizes can be secret.
---@param id string
---@return boolean
function CDM:WantsChain(id)
    local display = self:Get(id)
    if not (display and display.type == 'dynamicgroup' and display.Layout.Grow ~= 'GRID') then return false end
    for _, iconId in ipairs(self:GetIcons(id)) do
        if self:Get(iconId).type == 'text' then return true end
        for _, trigger in ipairs(self:Get(iconId).Triggers) do
            if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then return true end
        end
    end
    return false
end

---@param id string
function CDM:BuildContainer(id)
    local display = self:Get(id)
    if not display then return self:Release(id) end

    if display.parent and not self.containers[display.parent] then self:BuildContainer(display.parent) end

    local dynamic = display.type == 'dynamicgroup'
    local chained = dynamic and self:WantsChain(id)
    local frame = self.containers[id]
    if frame and dynamic and (frame.isChain == true) ~= chained then
        -- Grid and the chain are different containers: hand the icons over through a clean detach.
        for _, icon in pairs(self.icons) do
            if icon.groupId == id then
                frame:DetachChild(icon)
                icon.groupId = nil
            end
        end
        self:Release(id)
        frame = nil
    end
    if not frame then
        if chained then
            frame = tremove(self.spareChain) or self:CreateChainGroup()
        elseif dynamic then
            frame = tremove(self.spareDynamic) or NRSKNUI:CreateDynamicGroup(nil, UIParent)
        else
            frame = tremove(self.spareStatic) or CreateFrame('Frame', nil, UIParent)
            frame:NUISetPixelSize(STATIC_GROUP_SIZE, STATIC_GROUP_SIZE)
        end
        self.containers[id] = frame
    end

    if dynamic then
        ---@cast frame NRSKNUI.DynamicGroup
        if not chained then frame.onLayout = function() self:PlaceMatchedBars(id) end end
        frame:SetConfig(display.Layout)
        self:Place(frame, id, display, frame:GetResolvedAnchor(display.Layout.Grow))
    else
        ---@cast frame Frame
        self:Place(frame, id, display)
    end
    self:PlaceMatchedBars(id)
end

---Bars matching a group's width follow its frame, which a rebuild or release can swap.
---@param groupId string
function CDM:PlaceMatchedBars(groupId)
    for id, display in pairs(self.db.Displays) do
        local frame = self.icons[id]
        if display.MatchWidth == groupId and frame and not self:IsDynamic(display.parent) then
            self:Place(frame, id, display)
        end
    end
end

-- Icons --

---@param frame CDMIcon
local function DetachFromGroup(frame)
    local group = frame.groupId and CDM.containers[frame.groupId]
    ---@cast group NRSKNUI.DynamicGroup?
    if group then group:DetachChild(frame) end
    frame.groupId = nil
end

---@param id string
function CDM:BuildIcon(id)
    -- Disabled displays keep a frame too: hidden, but the options page can still preview them.
    local display = self:Get(id)
    if not display then return self:Release(id) end
    local parentFrame = display.parent and self.containers[display.parent]
    -- A first aura trigger in a group, or its last one gone, swaps the group's layout.
    if display.parent and not parentFrame then
        self:BuildContainer(display.parent)
    elseif parentFrame and self:IsDynamic(display.parent) and (parentFrame.isChain == true) ~= self:WantsChain(display.parent) then
        return self:ApplySettings(display.parent) -- the swap detaches every icon in the group, so all of them rebuild
    end

    local frame = self.icons[id]
    if not frame then
        frame = self:AcquireIcon(id)
        self.icons[id] = frame
    end

    if frame.groupId ~= display.parent then DetachFromGroup(frame) end
    frame.style = self:GetStyle(display)
    self:StyleIcon(frame, display, frame.style)

    if self:IsDynamic(display.parent) then
        local group = self.containers[display.parent]
        ---@cast group NRSKNUI.DynamicGroup
        if frame.groupId ~= display.parent then
            group:AttachChild(frame, id, display.order)
            frame.groupId = display.parent
            frame:Show()
        end
        group:SetChildOrder(id, display.order or 0)
        group:NotifyChildResized(id, frame.style.Width, frame.style.Height)
        Anchors:Unregister(id)
    else
        self:Place(frame, id, display)
    end
    -- After joining its group: an aura button the client creates while resolving is only reachable then, before it locks.
    self:ResolveTriggers(frame, display)
end

---Re-resolve every icon's trigger, for spell changes (talents, overrides, icons).
function CDM:ResolveAll()
    for id, frame in pairs(self.icons) do
        self:ResolveTriggers(frame, self:Get(id))
    end
    self:RefreshLoad()
end

---@param id string
function CDM:Release(id)
    local frame = self.icons[id]
    if frame then
        self:UnwatchIcon(id)
        DetachFromGroup(frame)
        self:ReleaseIcon(frame)
        self.icons[id] = nil
    end

    local container = self.containers[id]
    if container then
        container:Hide()
        container:ClearAllPoints()
        container.onLayout = nil
        self.containers[id] = nil
        local spare = container.isChain and self.spareChain or container.SetConfig and self.spareDynamic or self.spareStatic
        spare[#spare + 1] = container
        self:PlaceMatchedBars(id)
    end

    self:ReleaseAuraGroup(id)
    Anchors:Unregister(id)
end

-- Load state --

local STATE_RANK = { loaded = 3, standby = 2, unloaded = 1 }

---WeakAuras' three states: loaded, standby when only situational conditions fail, unloaded when
---a hard one does (disabled, unknown spell, a role that can't change mid-fight). A group takes the
---best state of the icons inside it.
---@param id string
---@return 'loaded'|'standby'|'unloaded'
---@return string? reason why a single display isn't loaded, for the debug report
function CDM:GetLoadState(id)
    local display = self:Get(id)
    if not display then return 'unloaded', 'missing' end
    if not display.Enabled then return 'unloaded', 'disabled' end

    if self:IsGroup(id) then
        local best
        for _, leafId in ipairs(self:GetLeaves(id)) do
            local state = self:GetLoadState(leafId)
            if not best or STATE_RANK[state] > STATE_RANK[best] then best = state end
        end
        return best or 'loaded'
    end

    for _, ancestor in ipairs(self:GetAncestors(id)) do
        if not self:Get(ancestor).Enabled then return 'unloaded', format("group '%s' disabled", self:GetName(ancestor)) end
    end
    if self.LAYERED_TYPES[display.type] then
        local known = false
        for _, trigger in ipairs(display.Triggers) do
            local triggerType = self.TriggerTypes[trigger.Type]
            if triggerType and triggerType.IsKnown(trigger) then
                known = true
                break
            end
        end
        if not known then return 'unloaded', 'no trigger is known' end
    end
    local hard, hardFailed = LoadConditions:Check(display.Load, true)
    if not hard then return 'unloaded', 'load condition ' .. tostring(hardFailed) end
    local situational, failed = LoadConditions:Check(display.Load)
    if not situational then return 'standby', 'load condition ' .. tostring(failed) end
    return 'loaded'
end

-- Previews: WeakAuras' visibility levels, 1 shown by selection, 2 pinned by the eye.

---@param id string
---@return string[]
function CDM:GetPreviewTargets(id)
    if self:IsGroup(id) then return self:GetLeaves(id) end
    return { id }
end

---@param id string
---@return number level 0 hidden, 1 shown by selection or partly (a group), 2 pinned
function CDM:GetPreview(id)
    if not self:IsGroup(id) then return self.preview[id] or 0 end

    local pinned, hidden, total = 0, 0, 0
    for _, iconId in ipairs(self:GetLeaves(id)) do
        local level = self.preview[iconId] or 0
        total = total + 1
        if level == 2 then pinned = pinned + 1 elseif level == 0 then hidden = hidden + 1 end
    end
    if total == 0 or hidden == total then return 0 end
    return pinned == total and 2 or 1
end

---Pin or clear the preview of an icon, or of every icon in a group.
---@param id string
---@param level number
function CDM:SetPreview(id, level)
    for _, iconId in ipairs(self:GetPreviewTargets(id)) do self.preview[iconId] = level end
    self:RefreshLoad()
end

---The selected display previews at level 1; the previous selection drops back unless it was pinned.
---@param id string?
function CDM:SetSelectionPreview(id)
    for _, key in ipairs(self.selectionPreview) do
        if self.preview[key] == 1 then self.preview[key] = nil end
    end
    wipe(self.selectionPreview)

    if id and self:Get(id) then
        for _, iconId in ipairs(self:GetPreviewTargets(id)) do
            if (self.preview[iconId] or 0) == 0 then
                self.preview[iconId] = 1
                self.selectionPreview[#self.selectionPreview + 1] = iconId
            end
        end
    end
    self:RefreshLoad()
end

---@param id string
---@return boolean
function CDM:IsPreviewed(id)
    return self.previewing == true and (self.preview[id] or 0) > 0
end

---Show what is loaded and hide the rest; while the options page is open only previewed icons show,
---as WeakAuras pauses everything else. A group shows while anything inside it does. Hidden icons stop updating.
function CDM:RefreshLoad()
    local previewing = self.previewing
    local shown = {}
    for id, display in pairs(self.db.Displays) do
        if self.icons[id] or display.type == 'auragroup' then
            if previewing then
                shown[id] = self:IsPreviewed(id)
            else
                shown[id] = self:GetLoadState(id) == 'loaded'
            end
        end
    end

    for id, container in pairs(self.containers) do
        local any = false
        for _, iconId in ipairs(self:GetLeaves(id)) do
            if shown[iconId] then
                any = true
                break
            end
        end
        container:SetShown(any)
    end

    for id, frame in pairs(self.icons) do
        frame.shown = shown[id]
        if shown[id] then self:UpdateIcon(id) else self:ApplyVisibility(id, frame) end
    end
    self:RefreshAuraGroups()

    local UF = NRSKNUI.UnitFrames
    if UF:IsEnabled() then UF:ScheduleCDMAnchorUpdate() end
    if self.onStateChanged then self.onStateChanged() end
    self:SyncBlizzardViewers()
end

---The shown dynamic groups carrying the unit frame anchor roles; the first in tree order wins.
---@return Frame? primary, Frame? secondary
function CDM:GetAnchorGroups()
    local found = {}
    local function Walk(entries)
        for _, entry in ipairs(entries) do
            local display = self:Get(entry.key)
            local container = self.containers[entry.key]
            if display.UFAnchor and not found[display.UFAnchor] and container and container:IsShown() then
                found[display.UFAnchor] = container
            end
            if display.type == 'group' then Walk(self:GetChildren(entry.key)) end
        end
    end
    Walk(self:GetRoots())

    if not found.primary then return found.secondary end
    return found.primary, found.secondary
end

local BLIZZARD_VIEWERS = { 'EssentialCooldownViewer', 'UtilityCooldownViewer', 'BuffIconCooldownViewer', 'BuffBarCooldownViewer' }
local hideViewers = false
local hookedViewers = {} ---@type table<table, true>

---@param viewer table
local function ApplyViewerVisibility(viewer)
    viewer:SetAlpha(hideViewers and 0 or 1)
    viewer:EnableMouse(not hideViewers)
end

---Whether a display that can currently load follows a Cooldown Manager bar (a Cooldown Bar trigger, or a split power
---bar's Progress Source), which needs Blizzard's viewers running.
---A standby one (load conditions only briefly unmet, like combat) counts; a disabled or unloaded one doesn't.
---@return boolean
function CDM:UsesViewerBar()
    for id, display in pairs(self.db.Displays) do
        if display.type == 'bar' and self:GetLoadState(id) ~= 'unloaded' then
            for _, trigger in ipairs(display.Triggers) do
                if trigger.Type == 'viewerbar' then return true end
                if trigger.Type == 'power' and trigger.Mode == 'progress' and trigger.ProgressCooldownID then return true end
            end
        end
    end
    return false
end

---Re-evaluate whether the hidden viewers must keep running, after displays load or unload.
function CDM:SyncBlizzardViewers()
    if self.db.HideBlizzard and self:UsesViewerBar() ~= hideViewers then self:SetBlizzardViewers(true) end
end

---Hide Blizzard's Cooldown Manager. It is turned fully off unless a Cooldown Bar trigger reads it; then it keeps
---running (a disabled viewer stops updating its frames) and is hidden by alpha instead.
---@param hide boolean
function CDM:SetBlizzardViewers(hide)
    local keepRunning = hide and self:UsesViewerBar()
    hideViewers = keepRunning
    NRSKNUI:RunWhenSafe(function()
        SetCVar('cooldownViewerEnabled', (hide and not keepRunning) and '0' or '1')
        for _, name in ipairs(BLIZZARD_VIEWERS) do
            local viewer = _G[name]
            if viewer then
                if not hookedViewers[viewer] then
                    hookedViewers[viewer] = true
                    -- Blizzard fades the viewers itself (visibility and combat settings)
                    hooksecurefunc(viewer, 'SetAlpha', function(self, alpha)
                        if hideViewers and alpha ~= 0 then self:SetAlpha(0) end
                    end)
                end
                ApplyViewerVisibility(viewer)
            end
        end
    end)
end

-- Banishing is one-way; turning the option off takes a reload.
function CDM:HidePlayerCastBar()
    NRSKNUI:RunWhenSafe(function() PlayerCastingBarFrame:NUIBanish() end)
end

CDM.previewPages = GUI_PAGE

-- Opening the page starts every loaded icon visible at level 1, as WeakAuras does on first open.
function CDM:ShowPreview()
    self.previewing = true
    for id, display in pairs(self.db.Displays) do
        if (self.icons[id] or display.type == 'auragroup') and (self.preview[id] or 0) == 0 and self:GetLoadState(id) == 'loaded' then
            self.preview[id] = 1
        end
    end
    self:RefreshLoad()
end

function CDM:HidePreview()
    self.previewing = false
    for id, level in pairs(self.preview) do
        if level == 1 then self.preview[id] = nil end
    end
    wipe(self.selectionPreview)
    self:RefreshLoad()
end

-- Apply --

---@param id string
local function ApplySubtree(id)
    if CDM:IsGroup(id) then
        CDM:BuildContainer(id)
        for _, child in ipairs(CDM:GetChildren(id)) do ApplySubtree(child.key) end
    elseif CDM:IsAuraGroup(id) then
        CDM:BuildAuraGroup(id)
    else
        CDM:BuildIcon(id)
    end
end

---@param id string? nil applies every display
function CDM:ApplySettings(id)
    if not self:IsEnabled() then return end

    if id then
        ApplySubtree(id)
    else
        -- Parents before children, so every display finds the frame it hangs off.
        local containers = {}
        for key in pairs(self.db.Displays) do
            if self:IsGroup(key) then containers[#containers + 1] = key end
        end
        tsort(containers, function(a, b) return self:GetDepth(a) < self:GetDepth(b) end)
        for _, key in ipairs(containers) do self:BuildContainer(key) end

        for key, display in pairs(self.db.Displays) do
            if self.LAYERED_TYPES[display.type] then
                self:BuildIcon(key)
            elseif display.type == 'auragroup' then
                self:BuildAuraGroup(key)
            end
        end
    end

    self:RefreshLoad()
end

function CDM:OnCatalogueChanged()
end

function CDM:OnEnable()
    if self.db.HideBlizzard then self:SetBlizzardViewers(true) end
    if self.db.HidePlayerCastBar then self:HidePlayerCastBar() end
    self:RegisterTriggerEvents()
    LoadConditions:RegisterCallback(self, function(module) module:RefreshLoad() end)
    NRSKNUI.AuraTriggers:RegisterCallback(self, function(module) module:ReapplyAuraTriggers() end)
    self:ApplySettings()
end

function CDM:OnDisable()
    if self.db.HideBlizzard then self:SetBlizzardViewers(false) end
    self:UnregisterTriggerEvents()
    LoadConditions:UnregisterCallback(self)
    NRSKNUI.AuraTriggers:UnregisterCallback(self)

    self:ReleaseAll()
end

function CDM:ReleaseAll()
    for id in pairs(self.icons) do self:Release(id) end
    for id in pairs(self.containers) do self:Release(id) end
    self:ReleaseAuraGroups()
end

-- Dev commands --

---Seed one dynamic group per Blizzard cooldown category from the known spells it lists.
local function Seed()
    local Category = Enum.CooldownViewerCategory
    local yOffset = -180
    for _, category in ipairs({ Category.Essential, Category.Utility }) do
        local groupId = CDM:CreateGroup(category == Category.Essential and 'Essential' or 'Utility', true)
        CDM:Get(groupId).Position.YOffset = yOffset
        yOffset = yOffset - 50

        for _, cooldownID in ipairs(CDM.Catalogue:GetList(category)) do
            local info = CDM.Catalogue:GetEntry(cooldownID)
            if info and info.isKnown and info.spellID then
                CDM:CreateIcon(GetSpellName(info.spellID) or tostring(info.spellID),
                    { Type = 'spell', SpellID = info.spellID, CooldownID = cooldownID }, groupId)
            end
        end
    end
end

---@param value any
---@return string
local function ProbeText(value)
    if NRSKNUI:IsSecretValue(value) then return '?' end
    if type(value) == 'number' then return (format('%.3f', value):gsub('%.?0+$', '')) end
    return tostring(value)
end

local probeFrame

---Print what the cooldown API reports for one spell on every SPELL_UPDATE_COOLDOWN; again turns it off.
---@param spellID number?
local function ProbeCooldown(spellID)
    probeFrame = probeFrame or CreateFrame('Frame')
    if probeFrame.spellID or not spellID then
        probeFrame:UnregisterAllEvents()
        probeFrame.spellID = nil
        NRSKNUI:Print('Cooldown probe off')
        return
    end
    probeFrame.spellID = spellID
    probeFrame:SetScript('OnEvent', function(self, _, eventSpell, baseSpell, _, category)
        local cooldown = GetSpellCooldown(self.spellID)
        local charges = GetSpellCharges(self.spellID)
        local usable, noPower = IsSpellUsable(self.spellID)
        print(format('%s ev=%s/%s cat=%s | active=%s gcd=%s enabled=%s activeCat=%s dur=%s rec=%s | charges=%s usable=%s/%s',
            ProbeText(GetTime()), ProbeText(eventSpell), ProbeText(baseSpell), ProbeText(category),
            ProbeText(cooldown and cooldown.isActive), ProbeText(cooldown and cooldown.isOnGCD), ProbeText(cooldown and cooldown.isEnabled),
            ProbeText(cooldown and cooldown.activeCategory), ProbeText(cooldown and cooldown.duration),
            ProbeText(cooldown and cooldown.timeUntilEndOfStartRecovery),
            charges and ProbeText(charges.currentCharges) .. '/' .. ProbeText(charges.maxCharges) or '-', ProbeText(usable), ProbeText(noPower)))
    end)
    probeFrame:RegisterEvent('SPELL_UPDATE_COOLDOWN')
    NRSKNUI:Print(format('Cooldown probe on %s (%d)', GetSpellName(spellID) or '?', spellID))
end

local PREVIEW_NAMES = { [0] = 'off', [1] = 'selected', [2] = 'pinned' }

---@param value any
---@return string
local function YesNo(value)
    return value and 'yes' or 'no'
end

---Each sub element's level, in list order, to check the draw order (an overlay's elements inside its button).
---@param subRegions table[]
---@param borders table
---@param glows table
---@param texts table
---@return string
local function ElementLevels(subRegions, borders, glows, texts)
    local out, counts = {}, { border = 0, glow = 0, text = 0 }
    for _, element in ipairs(subRegions) do
        local kind = element.type
        if counts[kind] then
            local n = counts[kind] + 1
            counts[kind] = n
            local level
            if kind == 'border' then
                level = borders[n] and borders[n]:GetFrameLevel()
            elseif kind == 'glow' then
                level = glows[n] and glows[n].host:GetFrameLevel()
            else
                level = texts[n] and texts[n].host and texts[n].host:GetFrameLevel()
            end
            out[#out + 1] = format('%s %d = %s', kind, n, level and tostring(level) or '-')
        end
    end
    return out[1] and table.concat(out, ', ') or 'none'
end

---An aura trigger's layer: what it was styled with and where its elements sit, to tell a missing pandemic border on our side from the game's.
---@param lines string[]
---@param frame CDMIcon
---@param display table
---@param i number
local function AuraLayerLines(lines, frame, display, i)
    local trigger = display.Triggers[i]
    local layer = frame.layers[i]
    local refs = layer and layer.auraRefs
    local _, color = CDM:GetAuraConditionChanges(display, i)
    local accessible = refs and refs.button and not NRSKNUI:AreAurasSecret()

    lines[#lines + 1] = format('  Aura: index %s, key %s, button %s', tostring(layer and layer.index), tostring(layer and layer.auraKey), YesNo(refs and refs.button))
    lines[#lines + 1] = format('  Pandemic: colour %s, border alpha %s', YesNo(color), refs and refs.pandemic and format('%.2f', refs.pandemic:GetAlpha()) or '-')
    lines[#lines + 1] = format('  Levels: layer %s, aura host %s, button %s, slot %s',
        tostring(layer and layer:GetFrameLevel()), tostring(layer and layer.auraHost and layer.auraHost:GetFrameLevel()),
        accessible and tostring(refs.button:GetFrameLevel()) or '-', tostring(trigger.Slot))
    if accessible then
        lines[#lines + 1] = '  Button elements: ' .. ElementLevels(display.SubRegions or {}, refs.borders, refs.glows or {}, refs.textHosts)
    end
    for j, other in ipairs(frame.layers) do
        if j ~= i and display.Triggers[j] and display.Triggers[j].Type ~= 'auraoverlay' then
            lines[#lines + 1] = format('  Under trigger %d (level %d): %s', j, other:GetFrameLevel(),
                ElementLevels(display.SubRegions or {}, other.borders, other.glows, other.texts))
        end
    end
end

---@param id string
---@return Frame?
local function RuntimeFrame(id)
    return CDM.containers[id] or CDM.icons[id] or CDM:GetAuraHost(id)
end

---@param trigger table
---@return string
local function TriggerSource(trigger)
    if trigger.Type == 'item' then
        if trigger.Item == 'custom' then return 'item ' .. tostring(trigger.ItemID) end
        return tostring(trigger.Item)
    end
    if trigger.Type == 'power' then return tostring(trigger.PowerType or 'primary') end
    local spellID = CDM:GetTriggerSpell(trigger)
    return spellID and ('spell ' .. spellID) or '-'
end

---Why a single display is or isn't on screen, from its load state and runtime frame.
---@param id string
---@return string
local function Verdict(id)
    local state, reason = CDM:GetLoadState(id)
    if state ~= 'loaded' then return state .. ': ' .. tostring(reason) end
    local frame = RuntimeFrame(id)
    if not frame then return 'loaded, but not built' end
    local icon = CDM.icons[id]
    if icon and icon.forceHidden then return 'loaded, hidden by a Show Display condition' end
    if icon and not icon.hasActive then return 'loaded, no trigger active' end
    return frame:IsShown() and 'shown' or 'loaded and active, but its frame is hidden'
end

---@param id string
---@return string[]
local function ReportedDisplays(id)
    if CDM:IsGroup(id) then return CDM:GetLeaves(id) end
    return { id }
end

---This session's NorskenUI errors from BugGrabber's list, newest first; our own reports left out.
---@param lines string[]
local function ErrorLines(lines)
    local db, session = BugGrabber:GetDB(), BugGrabber:GetSessionId()
    local found = {}
    for n = #db, 1, -1 do
        local entry = db[n]
        local message = type(entry) == 'table' and entry.session == session and entry.message
        if type(message) == 'string' and message:find('NorskenUI', 1, true)
            and not message:find('NorskenUI CDM debug report', 1, true) then
            found[#found + 1] = entry
        end
    end
    lines[#lines + 1] = format('NorskenUI errors this session (%d)', #found)
    if not found[1] then lines[#lines + 1] = '  none' end
    for n = 1, math.min(3, #found) do
        local entry = found[n]
        local first = entry.message:match('^[^\n]*'):sub(1, 200)
        lines[#lines + 1] = format('  %dx %s', entry.counter or 1, first)
    end
end

---One display's report as sections: a heading line, then its indented rows. Answers first, details after.
---@param id string
---@return string[]
local function DebugLines(id)
    local display = CDM:Get(id)
    local lines = {}
    if not display then return lines end

    local _, build = GetBuildInfo()
    local specIndex = GetSpecialization()
    local specName = specIndex and select(2, GetSpecializationInfo(specIndex))
    local _, instanceType, _, difficultyName = GetInstanceInfo()
    local Category = Enum.CooldownViewerCategory
    lines[#lines + 1] = 'NorskenUI CDM debug report'
    lines[#lines + 1] = '  Time: ' .. date('%Y-%m-%d %H:%M:%S')
    lines[#lines + 1] = format('  Version: %s, build %s', tostring(NRSKNUI.Version), tostring(build))
    lines[#lines + 1] = format('  Player: %s, %s', tostring(NRSKNUI.MyClassLocale), tostring(specName or 'no spec'))
    lines[#lines + 1] = format('  Instance: %s%s', tostring(instanceType), difficultyName and difficultyName ~= '' and (', ' .. difficultyName) or '')
    lines[#lines + 1] = format('  Combat: %s, restriction %d, auras secret %s, cooldowns secret %s', YesNo(NRSKNUI:InCombat()),
        NRSKNUI:GetRestrictionState(), YesNo(NRSKNUI:AreAurasSecret()), YesNo(NRSKNUI:AreCooldownsSecret()))
    lines[#lines + 1] = format('  Module: enabled %s, options open %s (previews show displays regardless)', YesNo(CDM.db.Enabled), YesNo(CDM.previewing))
    lines[#lines + 1] = format('  Cooldown Manager: essential %d, utility %d, buffs %d, bars %d, viewer CVar %s, hide Blizzard %s',
        #CDM.Catalogue:GetList(Category.Essential), #CDM.Catalogue:GetList(Category.Utility), #CDM.Catalogue:GetList(Category.TrackedBuff),
        #CDM.Catalogue:GetList(Category.TrackedBar), tostring(GetCVar('cooldownViewerEnabled')), YesNo(CDM.db.HideBlizzard))

    local isGroup = CDM:IsGroup(id)
    local reported = ReportedDisplays(id)
    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Verdict'
    if not reported[1] then lines[#lines + 1] = '  the group is empty' end
    for _, key in ipairs(reported) do
        lines[#lines + 1] = isGroup and format('  %s (%s): %s', CDM:GetName(key), key, Verdict(key)) or ('  ' .. Verdict(key))
    end

    lines[#lines + 1] = ''
    lines[#lines + 1] = 'Warnings'
    local warned = false
    for _, key in ipairs(isGroup and { id, unpack(reported) } or reported) do
        for _, warning in ipairs(CDM:GetWarnings(key)) do
            warned = true
            lines[#lines + 1] = (isGroup and key ~= id) and format('  %s: %s', CDM:GetName(key), warning) or ('  ' .. warning)
        end
    end
    if not warned then lines[#lines + 1] = '  none' end

    if BugGrabber then
        lines[#lines + 1] = ''
        ErrorLines(lines)
    end

    local state, reason = CDM:GetLoadState(id)
    lines[#lines + 1] = ''
    lines[#lines + 1] = format('Display: %s (%s)', CDM:GetName(id), id)
    lines[#lines + 1] = '  Type: ' .. display.type
    lines[#lines + 1] = '  Enabled: ' .. YesNo(display.Enabled)
    lines[#lines + 1] = '  Load: ' .. state .. (reason and (', ' .. reason) or '')
    lines[#lines + 1] = '  Preview: ' .. (PREVIEW_NAMES[CDM:GetPreview(id)] or '?')

    local container, icon = CDM.containers[id], CDM.icons[id]
    local frame = RuntimeFrame(id)
    if not frame then
        lines[#lines + 1] = '  Frame: not built'
        return lines
    end
    lines[#lines + 1] = format('  Frame: %s, strata %s, level %s', frame:IsShown() and 'shown' or 'hidden', frame:GetFrameStrata(), tostring(frame:GetFrameLevel()))

    if container then
        lines[#lines + 1] = '  Container: ' .. (container.isChain and 'chain' or (container.IterateActive and 'dynamic' or 'static'))
        local children = CDM:GetChildren(id)
        lines[#lines + 1] = ''
        lines[#lines + 1] = format('Children (%d)', #children)
        if not children[1] then lines[#lines + 1] = '  none' end
        for _, child in ipairs(children) do
            local childFrame = RuntimeFrame(child.key)
            lines[#lines + 1] = format('  %s (%s, %s): frame %s', child.text, child.key, CDM:Get(child.key).type,
                childFrame and (childFrame:IsShown() and 'shown' or 'hidden') or 'not built')
        end
    elseif icon then
        lines[#lines + 1] = format('  State: loaded %s, has active %s, force hidden %s', YesNo(icon.shown), YesNo(icon.hasActive), YesNo(icon.forceHidden))
        for i, trigger in ipairs(display.Triggers or {}) do
            local layer = icon.layers[i]
            local triggerType = CDM.TriggerTypes[trigger.Type]
            local triggerState
            if not triggerType then
                triggerState = 'unknown type'
            elseif triggerType.Secret then
                triggerState = 'secret'
            else
                triggerState = (layer ~= nil and triggerType.IsActive(layer, trigger)) and 'active' or 'inactive'
            end
            lines[#lines + 1] = ''
            lines[#lines + 1] = format('Trigger %d: %s', i, CDM:GetTriggerName(trigger) or trigger.Type)
            lines[#lines + 1] = format('  Type: %s (%s)', trigger.Type, TriggerSource(trigger))
            lines[#lines + 1] = '  Known: ' .. YesNo(triggerType and triggerType.IsKnown(trigger))
            lines[#lines + 1] = '  State: ' .. triggerState
            lines[#lines + 1] = format('  Layer: %s%s', layer ~= nil and layer:IsShown() and 'shown' or 'hidden',
                layer ~= nil and layer == icon.activeLayer and ', active layer' or '')
            if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then AuraLayerLines(lines, icon, display, i) end
        end
    end
    return lines
end

---@param lines string[]
local function PrintLines(lines)
    local accent = NRSKNUI.Theme.accent
    for n, line in ipairs(lines) do
        if n == 1 then
            NRSKNUI:Print(line)
        elseif line:find('^%S') then
            print(NRSKNUI:ColorText(line, accent))
        elseif line ~= '' then
            print(line)
        end
    end
end

---One display's live state for the Information tab: into BugSack when it's installed, so it can be copied and sent, otherwise to chat.
---@param id string
function CDM:PrintDebug(id)
    local lines = DebugLines(id)
    if not lines[1] then return end

    if BugGrabber then
        lines[#lines + 1] = ''
        lines[#lines + 1] = 'Settings string'
        local exported = self:Export(id)
        if not exported then lines[#lines + 1] = '  export failed' end
        for i = 1, exported and #exported or 0, 100 do -- BugSack's tooltip never wraps a line; import strips the breaks again
            lines[#lines + 1] = exported:sub(i, i + 99)
        end
        geterrorhandler()(table.concat(lines, '\n'), true) -- BugGrabber's simple entry: the message alone, no stack or locals
        NRSKNUI:Print(format(L['Debug report for %s saved to BugSack.'], self:GetName(id)))
    else
        lines[#lines + 1] = ''
        lines[#lines + 1] = 'Settings string'
        lines[#lines + 1] = '  too long for chat; right-click the display and pick Export'
        PrintLines(lines)
    end
end

---@param args string
function CDM:HandleCommand(args)
    local probeSpell = args:match('^cd%s*(%d*)$')
    if probeSpell then return ProbeCooldown(tonumber(probeSpell)) end

    if args == 'dump' then
        self.Catalogue:Dump()
    elseif args == 'seed' then
        Seed()
        self.db.Enabled = true
        NRSKNUI:ToggleModule('CDM', true)
        self:ApplySettings()
    elseif args == 'px' then
        -- Physical-pixel edges of the shown icons in each dynamic group, to see where a gap renders wider.
        local _, physicalHeight = GetPhysicalScreenSize()
        local scale = UIParent:GetEffectiveScale()
        local toPixels = scale * physicalHeight / 768
        NRSKNUI:Print(format('UIParent scale %.4f, perfect %.4f, 1 unit = %.4f px', scale, 768 / physicalHeight, toPixels))
        for id, container in pairs(self.containers) do
            if container.IterateActive and container:IsShown() then
                local line, previousRight = self:GetName(id) .. (container.isChain and ' (chain):' or ':'), nil
                for _, child in container:IterateActive() do
                    local left, right = child:GetLeft(), child:GetRight()
                    if not child:IsShown() then
                        -- a chain lists its unloaded icons too
                    elseif left == nil or NRSKNUI:IsSecretValue(left) or NRSKNUI:IsSecretValue(right) then
                        line, previousRight = line .. ' [?]', nil
                    else
                        left, right = left * toPixels, right * toPixels
                        if previousRight then line = line .. format(' gap %.2f |', left - previousRight) end
                        line = line .. format(' [%.2f-%.2f]', left, right)
                        previousRight = right
                    end
                end
                print(line)
            end
        end
    elseif args == 'aura' then
        local lines = { 'Aura layers' }
        for id, frame in pairs(self.icons) do
            local display = self:Get(id)
            for i, trigger in ipairs(display and display.Triggers or {}) do
                if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then
                    lines[#lines + 1] = format('%s: trigger %d (%s)', self:GetName(id), i, trigger.Type)
                    AuraLayerLines(lines, frame, display, i)
                end
            end
        end
        PrintLines(lines)
    elseif args == 'chain' then
        -- Where each chain group's frames really are, ? where the engine made a value secret.
        local function Num(value)
            if value == nil or NRSKNUI:IsSecretValue(value) then return '?' end
            return format('%.1f', value)
        end
        for id, container in pairs(self.containers) do
            if container.isChain and container:IsShown() then
                ---@cast container CDMChainGroup
                local chain = container.chain
                print(format('%s: group L %s W %s | chain L %s W %s', self:GetName(id), Num(container:GetLeft()), Num(container:GetWidth()),
                    Num(chain:GetLeft()), Num(chain:GetWidth())))
                for _, record in ipairs(container.order) do
                    print(format('  %s shown=%s loaded=%s logic=%s L %s W %s', self:GetName(record.key), tostring(record.slot:IsShown()),
                        tostring(record.loaded), tostring(record.logic), Num(record.slot:GetLeft()), Num(record.slot:GetWidth())))
                end
            end
        end
    elseif args == 'wipe' then
        for id in pairs(self.db.Displays) do self:Release(id) end
        wipe(self.db.Displays)
    else
        NRSKNUI:Print("/nui cdm dump | seed | wipe | px | aura | chain | cd <spellID>")
    end
end
