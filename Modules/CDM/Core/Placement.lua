---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local Anchors = NRSKNUI.Anchors

local floor = math.floor

local GUI_PAGE = 'cooldownManager'

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
