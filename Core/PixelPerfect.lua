-- NorskenUI namespace
local _, NRSKNUI = ...

-- Module for pixelperfect utility

-- Localization Setup
local GetPhysicalScreenSize = GetPhysicalScreenSize
local type = type
local CreateFrame = CreateFrame
local select = select
local string_format = string.format
local math_floor = math.floor
local UIParent = UIParent

-- UIMult
-- Update UI multiplier from perfect scale
function NRSKNUI:UIMult()
    self.mult = self.perfect or 1
end

-- PixelBestSize
-- Get best pixel perfect size (clamped between 0.4 and 1.15)
function NRSKNUI:PixelBestSize()
    local perfectScale = self.perfect or 1

    -- Clamp to minimum
    if perfectScale < 0.4 then
        return 0.4
    end

    -- Clamp to maximum
    if perfectScale > 1.15 then
        return 1.15
    end

    return perfectScale
end

-- PixelScaleChanged
-- Handle pixel scale change events
function NRSKNUI:PixelScaleChanged(event)
    -- Update physical size and perfect scale
    if event == "UI_SCALE_CHANGED" then
        self.physicalWidth, self.physicalHeight = GetPhysicalScreenSize()
        self.resolution = string_format("%dx%d", self.physicalWidth, self.physicalHeight)
        self.perfect = 768 / self.physicalHeight
    end

    -- Update multiplier
    self:UIMult()

    -- Update spells if applicable
    if self.UpdateSpells then
        self:UpdateSpells()
    end
end

-- Pixelperfect
-- Using native wow stuff to apply better settings for pixels
do
	local SCALE = 768 / select(2, GetPhysicalScreenSize())
	function NRSKNUI:PixelPerfect(obj)
		if obj.SetTexelSnappingBias then
			obj:SetTexelSnappingBias(0)
			obj:SetSnapToPixelGrid(false)
		elseif obj.GetObjectType then
			obj:SetIgnoreParentScale(true)
			obj:SetScale(SCALE)
		end
	end
end

-- Scale
-- Apply pixel-perfect scaling to a value
function NRSKNUI:Scale(x)
    -- Validate input
    if not x then return 0 end
    if type(x) ~= "number" then return 0 end

    -- Apply scaling
    local multiplier = self.mult or 1
    if multiplier == 1 or x == 0 then
        return x
    end

    -- Round to nearest multiple of multiplier
    local scaled = x * multiplier
    local rounded

    if scaled >= 0 then
        rounded = math_floor(scaled + 0.5)
    else
        rounded = -math_floor(-scaled + 0.5)
    end

    return rounded / multiplier
end

-- SnapToPixel
-- Snap a value to pixel boundaries
function NRSKNUI:SnapToPixel(value)
    if not value or type(value) ~= "number" then return 0 end
    local scale = UIParent:GetEffectiveScale()
    return math_floor(value * scale + 0.5) / scale
end

-- SnapFrameToPixels
-- Snap a frame position to pixel boundaries
function NRSKNUI:SnapFrameToPixels(frame)
    if not frame then return end

    local scale = frame:GetEffectiveScale()
    local left = frame:GetLeft()
    local bottom = frame:GetBottom()

    if left and bottom then
        local snappedLeft = math_floor(left * scale + 0.5) / scale
        local snappedBottom = math_floor(bottom * scale + 0.5) / scale

        local offsetX = snappedLeft - left
        local offsetY = snappedBottom - bottom

        if offsetX ~= 0 or offsetY ~= 0 then
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
            if point then
                frame:ClearAllPoints()
                frame:SetPoint(point, relativeTo, relativePoint, (x or 0) + offsetX, (y or 0) + offsetY)
            end
        end
    end
end

-- Initialize physical size and perfect scale
NRSKNUI.physicalWidth, NRSKNUI.physicalHeight = GetPhysicalScreenSize()
NRSKNUI.resolution = string_format("%dx%d", NRSKNUI.physicalWidth, NRSKNUI.physicalHeight)
NRSKNUI.perfect = 768 / NRSKNUI.physicalHeight
NRSKNUI.mult = NRSKNUI.perfect

-- Register for UI scale change event
local pixelPerfectFrame = CreateFrame("Frame")
pixelPerfectFrame:RegisterEvent("UI_SCALE_CHANGED")
pixelPerfectFrame:SetScript("OnEvent", function(_, event)
    NRSKNUI:PixelScaleChanged(event)
end)
