--[[
# Pixel

* Pixel-perfect geometry for the library and its consumers.
* Owns the perfect-pixel math (physical height -> multiplier) and a set of frame helpers that
* snap sizes/points onto the physical pixel grid, so borders and 1px lines stay crisp at any resolution.
* Fully self-contained: no dependency on the consuming addon. The math tracks resolution/scale changes
* on its own via UI_SCALE_CHANGED / DISPLAY_SIZE_CHANGED.

## Consuming
* `lib.Pixel`        - function table (object-first): ToPixelGrid, SetPixel*, SetGridPoint, GetMult, ...
* `lib.PixelMixin`   - the frame-method subset, ready to Mixin onto (or inject into) a frame's metatable.
* `lib.AttachPixelAPI(frame)` - convenience Mixin of PixelMixin onto a single frame.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end

local Mixin = Mixin
local CreateFrame = CreateFrame
local GetPhysicalScreenSize = GetPhysicalScreenSize
local canaccessvalue = canaccessvalue
local issecrettable = issecrettable
local floor = math.floor
local type = type
local pcall = pcall
local UIParent = UIParent

local physH, perfectPixel, bestPixel, mult

local function Recompute()
    local _, h = GetPhysicalScreenSize()
    physH = h or 768
    perfectPixel = 768 / physH

    bestPixel = perfectPixel
    if bestPixel > 1.15 then
        bestPixel = 1.15
    elseif bestPixel < 0.4 then
        bestPixel = 0.4
    end

    mult = perfectPixel / bestPixel
end

Recompute()

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("UI_SCALE_CHANGED")
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
watcher:SetScript("OnEvent", Recompute)

---The auto scale factor for the current resolution, clamped to a sane range.
---@return number
local function GetBestPixelSize()
    return bestPixel
end

---The raw perfect-pixel factor (768 / physical height), unclamped.
---@return number
local function GetPerfectPixel()
    return perfectPixel
end

---The pixel-grid multiplier. 1 means coordinates already land on whole pixels.
---@return number
local function GetMult()
    return mult
end

---Returns the value only when it is safe to read; otherwise nil. Mirrors the host's SafeValue.
---@param value any
---@return any|nil
local function SafeValue(value)
    if not canaccessvalue or canaccessvalue(value) then
        return value
    end
    return nil
end

---Snaps a coordinate to the nearest physical pixel. At mult 1 the grid is whole units, so
---measured values (GetWidth after a drag) still need rounding — never early-out on mult == 1.
---@param value number
---@return number
local function ToPixelGrid(value)
    if value == 0 then
        return value
    end
    return floor(value / mult + 0.5) * mult
end

---Turn off Blizzard's own grid snapping / texel bias so our pixel math is authoritative.
---Works on textures directly and on status bars via their fill texture. Runs once per object.
---@param object Frame|Texture
local function SetPixelSnap(object)
    if not object or object.NUIPixelSnapDisabled then return end
    if (issecrettable and issecrettable(object)) or (object.IsForbidden and object:IsForbidden()) then return end

    local target = object
    if not object.SetSnapToPixelGrid and object.GetStatusBarTexture then
        target = object:GetStatusBarTexture()
    end

    if type(target) == 'table' and target.SetSnapToPixelGrid then
        target:SetSnapToPixelGrid(false)
        target:SetTexelSnappingBias(0)
    end

    object.NUIPixelSnapDisabled = true
end

---Sets the size of a frame to the nearest pixel grid.
---@param object Frame
---@param width number
---@param height number
---@param ... any Additional arguments to pass to SetSize
local function SetPixelSize(object, width, height, ...)
    local w = ToPixelGrid(width)

    object:SetSize(w, height and ToPixelGrid(height) or w, ...)
end

---Sets the width of a frame to the nearest pixel grid.
---@param object Frame
---@param width number
---@param ... any Additional arguments to pass to SetWidth
local function SetPixelWidth(object, width, ...)
    object:SetWidth(ToPixelGrid(width), ...)
end

---Sets the height of a frame to the nearest pixel grid.
---@param object Frame
---@param height number
---@param ... any Additional arguments to pass to SetHeight
local function SetPixelHeight(object, height, ...)
    object:SetHeight(ToPixelGrid(height), ...)
end

---Sets the point of a frame to the nearest pixel grid.
---@param object Frame
---@param point string
---@param arg2 Frame|string|number? The frame (or its global name) to anchor to, or a number for xOffset if omitted.
---@param arg3 string|number? The point on the anchor frame to attach to, or a number for yOffset if omitted.
---@param arg4 number? The xOffset, or nil if omitted.
---@param arg5 number? The yOffset, or nil if omitted.
---@param ... any Additional arguments to pass to SetPoint
local function SetPixelPoint(object, point, arg2, arg3, arg4, arg5, ...)
    if not arg2 then arg2 = object:GetParent() end
    if type(arg2) == 'number' then
        arg2 = ToPixelGrid(arg2)
    end
    if type(arg3) == 'number' then
        arg3 = ToPixelGrid(arg3)
    end
    if type(arg4) == 'number' then
        arg4 = ToPixelGrid(arg4)
    end
    if type(arg5) == 'number' then
        arg5 = ToPixelGrid(arg5)
    end

    -- Overloaded passthrough: arg2/arg3 may be a relativeTo frame + relativePoint, or the
    -- short x/y offset form. The union is intentional and can't match SetPoint's typed overloads.
    ---@diagnostic disable-next-line: param-type-mismatch
    object:SetPoint(point, arg2, arg3, arg4, arg5, ...)
end

---Anchor a region a fixed pixel inset to another frame via its corners.
---When `outside` is set the inset flips outward so the region frames the anchor instead of sitting in it.
---@param object Frame
---@param anchor Frame
---@param xOffset number
---@param yOffset number
---@param anchor2 Frame? Optional second anchor frame for the bottom-right corner. Defaults to `anchor`.
---@param outside boolean? If true, the inset flips outward instead of inward.
local function AnchorPixelBox(object, anchor, xOffset, yOffset, anchor2, outside)
    anchor = anchor or object:GetParent()
    local x = ToPixelGrid(xOffset or 1)
    local y = ToPixelGrid(yOffset or 1)
    if outside then x, y = -x, -y end

    -- Need to pcall ClearAllPoints because some Blizzard frames throw an error if you try to clear points on a frame that has no points set yet.
    if pcall(object.GetPoint, object) then object:ClearAllPoints() end
    SetPixelSnap(object)
    object:SetPoint('TOPLEFT', anchor, 'TOPLEFT', x, -y)
    object:SetPoint('BOTTOMRIGHT', anchor2 or anchor, 'BOTTOMRIGHT', -x, y)
end

---Sets the point of a frame to the nearest pixel grid, inset from another frame's corners.
---@param object Frame
---@param anchor Frame
---@param xOffset number
---@param yOffset number
---@param anchor2 Frame? Optional second anchor frame for the bottom-right corner. Defaults to `anchor`.
local function SetPixelInside(object, anchor, xOffset, yOffset, anchor2)
    AnchorPixelBox(object, anchor, xOffset, yOffset, anchor2, false)
end

---Sets the point of a frame to the nearest pixel grid, outset from another frame's corners.
---@param object Frame
---@param anchor Frame
---@param xOffset number
---@param yOffset number
---@param anchor2 Frame? Optional second anchor frame for the bottom-right corner. Defaults to `anchor`.
local function SetPixelOutside(object, anchor, xOffset, yOffset, anchor2)
    AnchorPixelBox(object, anchor, xOffset, yOffset, anchor2, true)
end

-- Fractional position of each anchor point within a frame.
-- x and y, where 0 = left/bottom, 1 = right/top.
local POINT_FRACTION = {
    TOPLEFT     = { 0, 1 },
    TOP         = { 0.5, 1 },
    TOPRIGHT    = { 1, 1 },
    LEFT        = { 0, 0.5 },
    CENTER      = { 0.5, 0.5 },
    RIGHT       = { 1, 0.5 },
    BOTTOMLEFT  = { 0, 0 },
    BOTTOM      = { 0.5, 0 },
    BOTTOMRIGHT = { 1, 0 },
}

---Sets the point of a frame to the nearest pixel grid, snapping the resulting edges onto the pixel grid.
---@param object Frame
---@param point string
---@param relativeTo Frame|string? Anchor frame or its global name. Defaults to the object's parent.
---@param relativePoint string? Point on the anchor frame. Defaults to `point`.
---@param offsetX number? Defaults to 0.
---@param offsetY number? Defaults to 0.
local function SetGridPoint(object, point, relativeTo, relativePoint, offsetX, offsetY)
    if type(relativeTo) == 'string' then relativeTo = _G[relativeTo] end
    relativeTo = relativeTo or object:GetParent()
    relativePoint = relativePoint or point
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    local objF = POINT_FRACTION[point]
    local relF = POINT_FRACTION[relativePoint]

    local relLeft = objF and relF and SafeValue(relativeTo:GetLeft())
    local relBottom = relLeft and SafeValue(relativeTo:GetBottom())
    local relW = relBottom and SafeValue(relativeTo:GetWidth())
    local relH = relW and SafeValue(relativeTo:GetHeight())

    -- Unknown point or secret/unlaid-out geometry, fall back to a plain offset-rounded placement.
    if not relH then
        SetPixelPoint(object, point, relativeTo, relativePoint, offsetX, offsetY)
        return
    end

    -- Where the object's bottom-left lands with this anchor, derived from the relative frame's geometry.
    local objLeft = relLeft + relF[1] * relW - objF[1] * object:GetWidth() + offsetX
    local objBottom = relBottom + relF[2] * relH - objF[2] * object:GetHeight() + offsetY

    -- Correction pulling that edge onto the nearest grid line.
    local dx = floor(objLeft / mult + 0.5) * mult - objLeft
    local dy = floor(objBottom / mult + 0.5) * mult - objBottom
    object:SetPoint(point, relativeTo, relativePoint, offsetX + dx, offsetY + dy)
end

---Chooses a natural anchor for a movable frame based on which screen third it rests in
---(top/bottom + left/right/centre) and returns the offsets, relative to that UIParent edge,
---that reproduce its current position. Anchoring by the nearest edge keeps the frame put when
---the screen resolution changes, and is what the edge snap below aligns.
---@param frame Frame
---@return string point, number x, number y
local function CalculateFramePosition(frame)
    if not frame then return "CENTER", 0, 0 end
    local centerX, centerY = UIParent:GetCenter()
    local screenWidth = UIParent:GetRight()
    local frameX, frameY = frame:GetCenter()
    if not (centerX and centerY and screenWidth and frameX and frameY) then
        return "CENTER", 0, 0
    end

    local point = "BOTTOM"
    local x, y
    if frameY >= centerY then
        point = "TOP"
        y = -(UIParent:GetTop() - frame:GetTop())
    else
        y = frame:GetBottom()
    end

    if frameX >= (screenWidth * 2 / 3) then
        point = point .. "RIGHT"
        x = frame:GetRight() - screenWidth
    elseif frameX <= (screenWidth / 3) then
        point = point .. "LEFT"
        x = frame:GetLeft()
    else
        x = frameX - centerX
    end

    return point, floor(x + 0.5), floor(y + 0.5)
end

---Snaps a movable frame's position onto the pixel grid after a drag. Keeps the current
---anchor and rounds its offsets to a whole physical pixel (grid = mult, the pixel size in
---local units); once the frame lands perfect, children anchored with integer offsets inherit
---the alignment.
---@param frame Frame
---@param forceAbsolute boolean? Re-derive a fresh corner anchor from the frame's screen position.
local function SnapFrameToPixels(frame, forceAbsolute)
    if not frame then return end
    local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    if not point then return end

    if forceAbsolute then
        local newPoint, x, y = CalculateFramePosition(frame)
        frame:ClearAllPoints()
        frame:SetPoint(newPoint, UIParent, newPoint, x, y)
    else
        local snappedX = ToPixelGrid(xOfs or 0)
        local snappedY = ToPixelGrid(yOfs or 0)
        frame:ClearAllPoints()
        frame:SetPoint(point, relativeTo or UIParent, relativePoint or point, snappedX, snappedY)
    end
end

---Rounds a frame's size to whole pixels.
---@param frame Frame
local function SnapFrameSize(frame)
    if not frame then return end
    local width, height = frame:GetSize()
    frame:SetSize(ToPixelGrid(width), ToPixelGrid(height))
end

---Snaps both a frame's size and position onto the pixel grid, keeping the current anchor.
---@param frame Frame
local function SnapFrame(frame)
    if not frame then return end
    SnapFrameSize(frame)
    SnapFrameToPixels(frame)
end

---Snaps a frame's size and edges onto the pixel grid by re-anchoring its TOPLEFT corner to
---UIParent. For move/resize stops: a kept CENTER anchor plus an odd width leaves the edges
---on half pixels, which no amount of size rounding can fix.
---@param frame Frame
local function SnapFrameEdges(frame)
    if not frame then return end
    local left, top = frame:GetLeft(), frame:GetTop()
    if not left or not top then
        SnapFrame(frame)
        return
    end
    SnapFrameSize(frame)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ToPixelGrid(left), ToPixelGrid(top))
end

-- Frame-method subset: object-first funcs meant to live on a frame's metatable.
---@class KajiPixelMixin
---@field SetPixelSnap fun(self: Frame|Texture)
---@field SetPixelSize fun(self: Frame, width: number, height?: number, ...: any)
---@field SetPixelWidth fun(self: Frame, width: number, ...: any)
---@field SetPixelHeight fun(self: Frame, height: number, ...: any)
---@field SetPixelPoint fun(self: Frame, point: string, arg2?: Frame|string|number, arg3?: string|number, arg4?: number, arg5?: number, ...: any)
---@field SetPixelInside fun(self: Frame, anchor: Frame, xOffset: number, yOffset: number, anchor2?: Frame)
---@field SetPixelOutside fun(self: Frame, anchor: Frame, xOffset: number, yOffset: number, anchor2?: Frame)
---@field SetGridPoint fun(self: Frame, point: string, relativeTo?: Frame|string, relativePoint?: string, offsetX?: number, offsetY?: number)
local PixelMixin = {
    SetPixelSnap = SetPixelSnap,
    SetPixelSize = SetPixelSize,
    SetPixelWidth = SetPixelWidth,
    SetPixelHeight = SetPixelHeight,
    SetPixelPoint = SetPixelPoint,
    SetPixelInside = SetPixelInside,
    SetPixelOutside = SetPixelOutside,
    SetGridPoint = SetGridPoint,
}

lib.PixelMixin = PixelMixin

-- Full function table (scalar helpers + accessors + the frame methods).
lib.Pixel = {
    ToPixelGrid = ToPixelGrid,
    GetMult = GetMult,
    GetPerfectPixel = GetPerfectPixel,
    GetBestPixelSize = GetBestPixelSize,
    SetPixelSnap = SetPixelSnap,
    SetPixelSize = SetPixelSize,
    SetPixelWidth = SetPixelWidth,
    SetPixelHeight = SetPixelHeight,
    SetPixelPoint = SetPixelPoint,
    SetPixelInside = SetPixelInside,
    SetPixelOutside = SetPixelOutside,
    SetGridPoint = SetGridPoint,
    CalculateFramePosition = CalculateFramePosition,
    SnapFrameToPixels = SnapFrameToPixels,
    SnapFrameSize = SnapFrameSize,
    SnapFrame = SnapFrame,
    SnapFrameEdges = SnapFrameEdges,
}

---Mixes the pixel frame-methods onto a single frame/texture.
---@generic T
---@param object T
---@return T object
function lib.AttachPixelAPI(object)
    if object then Mixin(object, PixelMixin) end
    return object
end
