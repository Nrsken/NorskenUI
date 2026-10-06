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
    if not (display and display.Enabled) then return self:Release(id) end

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
    local display = self:Get(id)
    local parent = display and display.parent and self:Get(display.parent)
    if not (display and display.Enabled) or (parent and not parent.Enabled) then return self:Release(id) end

    local frame = self.icons[id]
    if not frame then
        frame = self:AcquireIcon(id)
        frame.state = {}
        self.icons[id] = frame
    end

    frame.style = self:ResolveStyle(display)
    self:StyleIcon(frame, frame.style)
    frame.known = self:ResolveTrigger(frame, display.Trigger)

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
        frame.known = self:ResolveTrigger(frame, self:Get(id).Trigger)
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

---@param display table
---@return boolean
local function PassesLoad(display)
    return display.Enabled and LoadConditions:Check(display.Load)
end

---Show what should be loaded and hide the rest. Unloaded icons stop updating.
function CDM:RefreshLoad()
    local groupLoaded = {}
    for id, group in pairs(self.groups) do
        local loaded = PassesLoad(self:Get(id))
        groupLoaded[id] = loaded
        group:SetShown(loaded)
    end

    for id, frame in pairs(self.icons) do
        local display = self:Get(id)
        local loaded = frame.known and PassesLoad(display) and (not display.parent or groupLoaded[display.parent] == true)
        frame.loaded = loaded

        local group = frame.groupId and self.groups[frame.groupId]
        if group then
            if loaded then group:ActivateChild(id) else group:DeactivateChild(id) end
        else
            frame:SetShown(loaded)
        end

        if loaded then self:UpdateIcon(id) end
    end
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
