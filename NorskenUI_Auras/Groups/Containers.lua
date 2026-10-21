---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local pairs, ipairs = pairs, ipairs
local CreateFrame = CreateFrame
local tremove = table.remove

local UIParent = UIParent

local STATIC_GROUP_SIZE = 32 -- a static group draws nothing; this is what its mover grabs

--[[
The frames groups live in.
A plain frame for a group, a dynamic group or a chain group when the engine has to lay it out.
]]

---A dynamic group (not Grid) holding an aura or a text is laid out by the engine, as their sizes can be secret.
---@param id string
---@return boolean
function CDM:WantsChain(id)
    local display = self:Get(id)
    if not (display and display.type == 'dynamicgroup' and display.Layout.Grow ~= 'GRID') then
        return false
    end
    for _, iconId in ipairs(self:GetIcons(id)) do
        local child = self:Get(iconId)
        if child.type == 'text' then
            return true
        end
        for _, trigger in ipairs(child.Triggers) do
            if trigger.Type == 'aura' or trigger.Type == 'auraoverlay' then
                return true
            end
        end
    end
    return false
end

---@param id string
function CDM:BuildContainer(id)
    local display = self:Get(id)
    if not display then return self:Release(id) end

    if display.parent and not self.containers[display.parent] then
        self:BuildContainer(display.parent)
    end

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

    ---@cast frame -nil
    self:EvaluateGroupConditions(display, frame)

    if dynamic then
        ---@cast frame NRSKNUI.DynamicGroup
        if not chained then
            frame.onLayout = function()
                self:PlaceMatchedBars(id)
            end
        end

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
