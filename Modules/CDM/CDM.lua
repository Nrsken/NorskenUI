---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local Anchors = NRSKNUI.Anchors
local LoadConditions = NRSKNUI.LoadConditions

local pairs, ipairs = pairs, ipairs
local tremove = table.remove
local tsort = table.sort
local tostring = tostring
local format = string.format
local GetPhysicalScreenSize = GetPhysicalScreenSize
local wipe = wipe
local CreateFrame = CreateFrame
local GetSpellName = C_Spell.GetSpellName

local GUI_PAGE = 'cooldownManager'
local STATIC_GROUP_SIZE = 32 -- a static group draws nothing; this is what its mover grabs

function CDM:UpdateDB()
    self.db = NRSKNUI.db.profile.CDM
    self:Migrate(self.db)
end

function CDM:OnInitialize()
    self:UpdateDB()
    self.icons = {} ---@type table<string, CDMIcon>
    self.containers = {} ---@type table<string, Frame|NRSKNUI.DynamicGroup>
    self.spareStatic = {} ---@type Frame[]
    self.spareDynamic = {} ---@type NRSKNUI.DynamicGroup[]
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

---Top-level displays sit on the screen with a mover; inside a static group they hang off its frame.
---@param frame Frame
---@param id string
---@param display table
---@param point string? the frame's own anchor, when it isn't Position.AnchorFrom (a dynamic group's grow anchor)
function CDM:Place(frame, id, display, point)
    local parent = display.parent and self:Get(display.parent)
    local position = display.Position

    if parent then
        local host = self.containers[display.parent]
        frame:SetParent(host)
        frame:ClearAllPoints()
        frame:NUISetPixelPoint(point or position.AnchorFrom, host, position.AnchorTo, position.XOffset, position.YOffset)
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

-- Containers --

---@param id string
function CDM:BuildContainer(id)
    local display = self:Get(id)
    if not display then return self:Release(id) end

    if display.parent and not self.containers[display.parent] then self:BuildContainer(display.parent) end

    local dynamic = display.type == 'dynamicgroup'
    local frame = self.containers[id]
    if not frame then
        if dynamic then
            frame = tremove(self.spareDynamic) or NRSKNUI:CreateDynamicGroup(nil, UIParent)
        else
            frame = tremove(self.spareStatic) or CreateFrame('Frame', nil, UIParent)
            frame:NUISetPixelSize(STATIC_GROUP_SIZE, STATIC_GROUP_SIZE)
        end
        self.containers[id] = frame
    end

    if dynamic then
        ---@cast frame NRSKNUI.DynamicGroup
        frame:SetConfig(display.Layout)
        self:Place(frame, id, display, frame:GetResolvedAnchor(display.Layout.Grow))
    else
        self:Place(frame, id, display)
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
    if display.parent and not self.containers[display.parent] then self:BuildContainer(display.parent) end

    local frame = self.icons[id]
    if not frame then
        frame = self:AcquireIcon(id)
        frame.state = {}
        self.icons[id] = frame
    end

    frame.style = self:GetStyle(display)
    self:StyleIcon(frame, frame.style)
    self:ResolveTrigger(frame, display.Trigger)

    if self:IsDynamic(display.parent) then
        local group = self.containers[display.parent]
        ---@cast group NRSKNUI.DynamicGroup
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
        self:Place(frame, id, display)
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

    local container = self.containers[id]
    if container then
        container:Hide()
        container:ClearAllPoints()
        self.containers[id] = nil
        local spare = container.SetConfig and self.spareDynamic or self.spareStatic
        spare[#spare + 1] = container
    end

    Anchors:Unregister(id)
end

-- Load state --

local STATE_RANK = { loaded = 3, standby = 2, unloaded = 1 }

---WeakAuras' three states: loaded, standby when only situational conditions fail, unloaded when
---a hard one does (disabled, unknown spell, a role that can't change mid-fight). A group takes the
---best state of the icons inside it.
---@param id string
---@return 'loaded'|'standby'|'unloaded'
function CDM:GetLoadState(id)
    local display = self:Get(id)
    if not display or not display.Enabled then return 'unloaded' end

    if display.type ~= 'icon' then
        local best
        for _, iconId in ipairs(self:GetIcons(id)) do
            local state = self:GetLoadState(iconId)
            if not best or STATE_RANK[state] > STATE_RANK[best] then best = state end
        end
        return best or 'loaded'
    end

    for _, ancestor in ipairs(self:GetAncestors(id)) do
        if not self:Get(ancestor).Enabled then return 'unloaded' end
    end
    if not self.TriggerTypes[display.Trigger.Type].IsKnown(display.Trigger) then return 'unloaded' end
    if not LoadConditions:Check(display.Load, true) then return 'unloaded' end
    if not LoadConditions:Check(display.Load) then return 'standby' end
    return 'loaded'
end

-- Previews: WeakAuras' visibility levels, 1 shown by selection, 2 pinned by the eye.

---@param id string
---@return string[]
function CDM:GetPreviewTargets(id)
    if self:IsGroup(id) then return self:GetIcons(id) end
    return { id }
end

---@param id string
---@return number level 0 hidden, 1 shown by selection or partly (a group), 2 pinned
function CDM:GetPreview(id)
    if not self:IsGroup(id) then return self.preview[id] or 0 end

    local pinned, hidden, total = 0, 0, 0
    for _, iconId in ipairs(self:GetIcons(id)) do
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
    for id in pairs(self.icons) do
        if previewing then
            shown[id] = self:IsPreviewed(id)
        else
            shown[id] = self:GetLoadState(id) == 'loaded'
        end
    end

    for id, container in pairs(self.containers) do
        local any = false
        for _, iconId in ipairs(self:GetIcons(id)) do
            if shown[iconId] then any = true break end
        end
        container:SetShown(any)
    end

    for id, frame in pairs(self.icons) do
        frame.shown = shown[id]

        local group = frame.groupId and self.containers[frame.groupId]
        ---@cast group NRSKNUI.DynamicGroup?
        if group then
            if shown[id] then group:ActivateChild(id) else group:DeactivateChild(id) end
        else
            frame:SetShown(shown[id])
        end

        if shown[id] then self:UpdateIcon(id) end
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

---@param id string
local function ApplySubtree(id)
    if CDM:IsGroup(id) then
        CDM:BuildContainer(id)
        for _, child in ipairs(CDM:GetChildren(id)) do ApplySubtree(child.key) end
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
        for key, display in pairs(self.db.Displays) do
            if display.type ~= 'icon' then containers[#containers + 1] = key end
        end
        tsort(containers, function(a, b) return self:GetDepth(a) < self:GetDepth(b) end)
        for _, key in ipairs(containers) do self:BuildContainer(key) end

        for key, display in pairs(self.db.Displays) do
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
    for id in pairs(self.containers) do self:Release(id) end
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

---@param args string
function CDM:HandleCommand(args)
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
                local line, previousRight = self:GetName(id) .. ':', nil
                for _, child in container:IterateActive() do
                    local left, right = child:GetLeft() * toPixels, child:GetRight() * toPixels
                    if previousRight then line = line .. format(' gap %.2f |', left - previousRight) end
                    line = line .. format(' [%.2f-%.2f]', left, right)
                    previousRight = right
                end
                print(line)
            end
        end
    elseif args == 'wipe' then
        for id in pairs(self.db.Displays) do self:Release(id) end
        wipe(self.db.Displays)
    else
        NRSKNUI:Print("/nui cdm dump | seed | wipe | px")
    end
end
