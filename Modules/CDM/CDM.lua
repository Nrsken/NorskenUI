---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local Anchors = NRSKNUI.Anchors
local LoadConditions = NRSKNUI.LoadConditions

local pairs, ipairs = pairs, ipairs
local tremove = table.remove
local tostring = tostring
local wipe = wipe
local GetSpellName = C_Spell.GetSpellName

local GUI_PAGE = 'cooldownManager'

function CDM:UpdateDB()
    self.db = NRSKNUI.db.profile.CDM
end

function CDM:OnInitialize()
    self:UpdateDB()
    self.icons = {} ---@type table<string, CDMIcon>
    self.groups = {} ---@type table<string, NRSKNUI.DynamicGroup>
    self.spareGroups = {} ---@type NRSKNUI.DynamicGroup[]
    self.preview = {} ---@type table<string, number>
    self.selectionPreview = {} ---@type string[]
end

---@param id string
---@return table
local function AnchorOptions(id)
    return {
        db = function() return CDM:Get(id) end,
        apply = function(module) module:ApplySettings(id) end,
        displayName = CDM:GetName(id),
    }
end

-- Groups --

---@param id string
function CDM:BuildGroup(id)
    local display = self:Get(id)
    if not display then return self:Release(id) end

    local group = self.groups[id]
    if not group then
        group = tremove(self.spareGroups) or NRSKNUI:CreateDynamicGroup(nil, UIParent)
        self.groups[id] = group
    end

    group:SetConfig(display.Layout)
    group:UpdateGroupPosition(display, display.Layout.Grow)
    Anchors:Register(self, id, group, GUI_PAGE, AnchorOptions(id))
end

-- Icons --

---@param frame CDMIcon
local function DetachFromGroup(frame)
    local group = frame.groupId and CDM.groups[frame.groupId]
    if group then group:DetachChild(frame) end
    frame.groupId = nil
end

---@param id string
function CDM:BuildIcon(id)
    -- Disabled displays keep a frame too: hidden, but the options page can still preview them.
    local display = self:Get(id)
    if not display then return self:Release(id) end
    local parent = display.parent and self:Get(display.parent)

    local frame = self.icons[id]
    if not frame then
        frame = self:AcquireIcon(id)
        frame.state = {}
        self.icons[id] = frame
    end

    frame.style = self:ResolveStyle(display)
    self:StyleIcon(frame, frame.style)
    self:ResolveTrigger(frame, display.Trigger)

    if parent then
        if not self.groups[display.parent] then self:BuildGroup(display.parent) end
        local group = self.groups[display.parent]
        if frame.groupId ~= display.parent then
            DetachFromGroup(frame)
            group:AttachChild(frame, id, display.order)
            frame.groupId = display.parent
            frame:Show()
        end
        group:SetChildOrder(id, display.order or 0)
        group:NotifyChildResized(id)
        Anchors:Unregister(id)
    else
        DetachFromGroup(frame)
        frame:SetParent(UIParent)
        frame:NUIApplyPosition(display)
        Anchors:Register(self, id, frame, GUI_PAGE, AnchorOptions(id))
    end
end

---Re-resolve every icon's trigger, for spell changes (talents, overrides, icons).
function CDM:ResolveAll()
    for id, frame in pairs(self.icons) do
        self:ResolveTrigger(frame, self:Get(id).Trigger)
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

    local group = self.groups[id]
    if group then
        local childIds = {}
        for _, child in group:IterateChildren() do
            ---@cast child CDMIcon
            childIds[#childIds + 1] = child.id
        end
        for _, childId in ipairs(childIds) do self:Release(childId) end
        group:Hide()
        self.groups[id] = nil
        self.spareGroups[#self.spareGroups + 1] = group
    end

    Anchors:Unregister(id)
end

-- Load state --

local STATE_RANK = { loaded = 3, standby = 2, unloaded = 1 }

---WeakAuras' three states: loaded, standby when only situational conditions fail, unloaded when
---a hard one does (disabled, unknown spell, a role or spec that can't change mid-fight).
---@param id string
---@return 'loaded'|'standby'|'unloaded'
function CDM:GetLoadState(id)
    local display = self:Get(id)
    if not display or not display.Enabled then return 'unloaded' end

    if display.type == 'group' then
        local best
        for _, child in ipairs(self:GetChildren(id)) do
            local state = self:GetLoadState(child.key)
            if not best or STATE_RANK[state] > STATE_RANK[best] then best = state end
        end
        return best or 'loaded'
    end

    local parent = display.parent and self:Get(display.parent)
    if parent and not parent.Enabled then return 'unloaded' end
    if not self.TriggerTypes[display.Trigger.Type].IsKnown(display.Trigger) then return 'unloaded' end

    local parentLoad = parent and parent.Load
    if not (LoadConditions:Check(display.Load, true) and LoadConditions:Check(parentLoad, true)) then return 'unloaded' end
    if not (LoadConditions:Check(display.Load) and LoadConditions:Check(parentLoad)) then return 'standby' end
    return 'loaded'
end

-- Previews: WeakAuras' visibility levels, 1 shown by selection, 2 pinned by the eye.

---@param id string
---@return number level 0 hidden, 1 some (group) or selected, 2 pinned
function CDM:GetPreview(id)
    if not self:IsGroup(id) then return self.preview[id] or 0 end

    local pinned, hidden, total = 0, 0, 0
    for _, child in ipairs(self:GetChildren(id)) do
        local level = self.preview[child.key] or 0
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
    if self:IsGroup(id) then
        for _, child in ipairs(self:GetChildren(id)) do self.preview[child.key] = level end
    else
        self.preview[id] = level
    end
    self:RefreshLoad()
end

---The selected display previews at level 1; the previous selection drops back unless it was pinned.
---@param id string?
function CDM:SetSelectionPreview(id)
    for _, key in ipairs(self.selectionPreview) do
        if self.preview[key] == 1 then self.preview[key] = nil end
    end
    wipe(self.selectionPreview)

    local display = id and self:Get(id)
    if display then
        local targets = display.type == 'group' and self:GetChildren(id) or { { key = id } }
        for _, target in ipairs(targets) do
            if (self.preview[target.key] or 0) == 0 then
                self.preview[target.key] = 1
                self.selectionPreview[#self.selectionPreview + 1] = target.key
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
---as WeakAuras pauses everything else. Hidden icons stop updating.
function CDM:RefreshLoad()
    local previewing = self.previewing
    local groupShown = {}
    for id, group in pairs(self.groups) do
        local display = self:Get(id)
        local shown = not previewing and display.Enabled and LoadConditions:Check(display.Load)
        if previewing then
            for _, child in ipairs(self:GetChildren(id)) do
                if self:IsPreviewed(child.key) then shown = true break end
            end
        end
        groupShown[id] = shown
        group:SetShown(shown)
    end

    for id, frame in pairs(self.icons) do
        local display = self:Get(id)
        local shown
        if previewing then
            shown = self:IsPreviewed(id)
        else
            shown = self:GetLoadState(id) == 'loaded'
        end
        if display.parent and not groupShown[display.parent] then shown = false end
        frame.shown = shown

        local group = frame.groupId and self.groups[frame.groupId]
        if group then
            if shown then group:ActivateChild(id) else group:DeactivateChild(id) end
        else
            frame:SetShown(shown)
        end

        if shown then self:UpdateIcon(id) end
    end

    if self.onStateChanged then self.onStateChanged() end
end

CDM.previewPages = GUI_PAGE

-- Opening the page starts every loaded icon visible at level 1, as WeakAuras does on first open.
function CDM:ShowPreview()
    self.previewing = true
    for id in pairs(self.icons) do
        if (self.preview[id] or 0) == 0 and self:GetLoadState(id) == 'loaded' then self.preview[id] = 1 end
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

---@param id string? nil applies every display
function CDM:ApplySettings(id)
    if not self:IsEnabled() then return end

    if id then
        if self:IsGroup(id) then
            self:BuildGroup(id)
            for _, child in ipairs(self:GetChildren(id)) do self:BuildIcon(child.key) end
        else
            self:BuildIcon(id)
        end
    else
        local displays = self.db.Displays
        for key, display in pairs(displays) do
            if display.type == 'group' then self:BuildGroup(key) end
        end
        for key, display in pairs(displays) do
            if display.type == 'icon' then self:BuildIcon(key) end
        end
    end

    self:RefreshLoad()
end

function CDM:OnCatalogueChanged()
end

function CDM:OnEnable()
    self:RegisterTriggerEvents()
    LoadConditions:RegisterCallback(self, function(module) module:RefreshLoad() end)
    self:ApplySettings()
end

function CDM:OnDisable()
    self:UnregisterTriggerEvents()
    LoadConditions:UnregisterCallback(self)

    for id in pairs(self.icons) do self:Release(id) end
    for id in pairs(self.groups) do self:Release(id) end
end

-- Dev commands --

---Seed one group per Blizzard cooldown category from the known spells it lists.
local function Seed()
    local Category = Enum.CooldownViewerCategory
    local yOffset = -180
    for _, category in ipairs({ Category.Essential, Category.Utility }) do
        local groupId = CDM:CreateGroup(category == Category.Essential and 'Essential' or 'Utility')
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

---@param args string
function CDM:HandleCommand(args)
    if args == 'dump' then
        self.Catalogue:Dump()
    elseif args == 'seed' then
        Seed()
        self.db.Enabled = true
        NRSKNUI:ToggleModule('CDM', true)
        self:ApplySettings()
    elseif args == 'wipe' then
        for id in pairs(self.db.Displays) do self:Release(id) end
        wipe(self.db.Displays)
    else
        NRSKNUI:Print('/nui cdm dump | seed | wipe')
    end
end
