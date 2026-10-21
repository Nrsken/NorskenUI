---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')

local floor = math.floor
local unpack = unpack
local ipairs = ipairs
local CreateFrame = CreateFrame
local UnitPowerType = UnitPowerType

local WHITE = 'Interface\\Buttons\\WHITE8X8'
local QUESTION_MARK = 134400
local FILL = 0.7 -- how full the mini bar is drawn

-- The WA-style group pictures, at 32px: width, height, colour, and the offset below the piece above.
local GROUP_BLOCKS = {
    { 24, 8,  { 0.8, 0, 0, 0.5 } },
    { 20, 20, { 0.2, 0.8, 0.2, 0.5 }, 5 },
    { 20, 12, { 0.1, 0.25, 1, 0.5 },  8, -5 },
}
local DYNAMIC_BLOCKS = {
    { 24, 6,  { 0.8, 0, 0, 1 } },
    { 12, 12, { 0.2, 0.8, 0.2, 1 }, -2 },
    { 30, 4,  { 0.1, 0.25, 1, 1 },  -2 },
}

---@class NRSKNUI.CDMThumbnail
local Thumbnail = {}
NRSKNUI.CDMThumbnail = Thumbnail

---@param host Frame
---@return CDMThumbnailParts
local function Parts(host)
    local parts = host.nuiThumb
    if parts then return parts end
    parts = {} ---@type CDMThumbnailParts
    parts.bar = CreateFrame('Frame', nil, host)
    parts.barBg = parts.bar:CreateTexture(nil, 'BACKGROUND')
    parts.barBg:SetAllPoints()
    parts.barBg:SetTexture(WHITE)
    parts.fill = parts.bar:CreateTexture(nil, 'ARTWORK')
    parts.icon = host:CreateTexture(nil, 'ARTWORK')
    parts.blocks = {}
    for i = 1, 3 do parts.blocks[i] = host:CreateTexture(nil, 'ARTWORK') end
    parts.line = host:CreateTexture(nil, 'OVERLAY')
    parts.line:SetColorTexture(1, 1, 1, 1)
    for _, texture in ipairs({ parts.barBg, parts.fill, parts.icon, parts.line, unpack(parts.blocks) }) do texture:NUISetPixelSnap() end
    parts.anim = CreateFrame('Frame', nil, host)
    parts.text = host:CreateFontString(nil, 'OVERLAY')
    parts.text:SetPoint('CENTER')
    host.nuiThumb = parts
    return parts
end

---@param parts CDMThumbnailParts
local function HideAll(parts)
    parts.bar:Hide()
    parts.icon:Hide()
    for _, block in ipairs(parts.blocks) do block:Hide() end
    parts.line:Hide()
    parts.anim:Hide()
    parts.anim:SetScript('OnUpdate', nil)
    parts.text:Hide()
end

---The bar's fill colour as it would draw outside combat: custom, class, or the current power's.
---@param style table
---@return number[]
local function BarColor(style)
    if style.BarColorMode == 'class' then return NRSKNUI:GetPlayerClassColor() end
    if style.BarColorMode == 'power' then
        local color = NRSKNUI.Colors.power[UnitPowerType('player')]
        if color then return { color:GetRGB() } end
    end
    return style.BarColor
end

---@param host Frame
---@param display table a bar display, or a stand-in with type and Style
---@param size number
---@param texture string|number? the bar's icon
local function DrawBar(host, display, size, texture)
    local parts = Parts(host)
    local style = CDM:GetStyle(display)
    local vertical = style.Orientation == 'VERTICAL'
    local reverse = style.ReverseFill == true
    local length, thickness = size - 4, floor(size * 0.5)

    local bar, icon, fill = parts.bar, parts.icon, parts.fill
    bar:ClearAllPoints()
    icon:ClearAllPoints()
    local barLength = length
    if style.IconShow then
        barLength = length - thickness
        icon:NUISetPixelSize(thickness, thickness)
        icon:SetTexture(texture or QUESTION_MARK)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Show()
    end

    local side = style.IconSide
    if vertical then
        local top = side == 'TOP' or side == 'LEFT'
        bar:NUISetPixelSize(thickness, barLength)
        if style.IconShow then
            icon:NUISetPixelPoint(top and 'TOP' or 'BOTTOM', host, top and 'TOP' or 'BOTTOM', 0, top and -2 or 2)
            bar:NUISetPixelPoint(top and 'TOP' or 'BOTTOM', icon, top and 'BOTTOM' or 'TOP')
        else
            bar:NUISetPixelPoint('CENTER', host, 'CENTER')
        end
    else
        local left = side == 'LEFT' or side == 'TOP'
        bar:NUISetPixelSize(barLength, thickness)
        if style.IconShow then
            icon:NUISetPixelPoint(left and 'LEFT' or 'RIGHT', host, left and 'LEFT' or 'RIGHT', left and 2 or -2, 0)
            bar:NUISetPixelPoint(left and 'LEFT' or 'RIGHT', icon, left and 'RIGHT' or 'LEFT')
        else
            bar:NUISetPixelPoint('CENTER', host, 'CENTER')
        end
    end

    parts.barBg:SetVertexColor(unpack(style.BackgroundColor))
    fill:SetTexture(NRSKNUI:GetStatusbar(style))
    fill:SetVertexColor(unpack(BarColor(style)))
    fill:ClearAllPoints()
    if vertical then
        local from = reverse and 'TOP' or 'BOTTOM'
        fill:NUISetPixelPoint(from .. 'LEFT', bar, from .. 'LEFT')
        fill:NUISetPixelPoint(from .. 'RIGHT', bar, from .. 'RIGHT')
        fill:NUISetPixelHeight(barLength * FILL)
    else
        local from = reverse and 'RIGHT' or 'LEFT'
        fill:NUISetPixelPoint('TOP' .. from, bar, 'TOP' .. from)
        fill:NUISetPixelPoint('BOTTOM' .. from, bar, 'BOTTOM' .. from)
        fill:NUISetPixelWidth(barLength * FILL)
    end
    bar:Show()
end

---@param parts CDMThumbnailParts
---@param host Frame
---@param blocks table[]
---@param scale number
local function StackBlocks(parts, host, blocks, scale)
    local previous
    for i, spec in ipairs(blocks) do
        local block = parts.blocks[i]
        block:ClearAllPoints()
        block:NUISetPixelSize(spec[1] * scale, spec[2] * scale)
        block:SetColorTexture(unpack(spec[3]))
        block:SetAlpha(1)
        if previous then
            block:NUISetPixelPoint('TOP', previous, 'BOTTOM', (spec[5] or 0) * scale, (spec[4] or 0) * scale)
        else
            block:NUISetPixelPoint('TOP', host, 'TOP', 0, -6 * scale)
        end
        block:Show()
        previous = block
    end
end

-- The dynamic group picture: the middle block slides into the top one and back, every 3s.
---@param anim Frame
---@param elapsed number
local function Animate(anim, elapsed)
    anim.elapsed = (anim.elapsed + elapsed) % 3
    local t, block = anim.elapsed, anim.block
    local scale = anim.scale
    if t < 0.5 then
        block:NUISetPixelPoint('TOP', anim.top, 'BOTTOM', 0, (-2 + 28 * t) * scale)
        block:SetAlpha(1 - 2 * t)
    elseif t >= 1.5 and t < 2 then
        block:NUISetPixelPoint('TOP', anim.top, 'BOTTOM', 0, (-2 + 28 * (2 - t)) * scale)
        block:SetAlpha(2 * t - 3)
    end
end

---Draw a WeakAuras-style picture of a display into `host`; false when a plain texture shows it better.
---@param host Frame
---@param display table
---@param size number
---@param texture string|number? the display's icon, for a bar's icon
---@return boolean drawn
function Thumbnail:Draw(host, display, size, texture)
    local parts = Parts(host)
    HideAll(parts)

    if display.type == 'bar' then
        DrawBar(host, display, size, texture)
        return true
    end
    if display.type == 'text' then
        local element = display.SubRegions and display.SubRegions[1]
        if not element then return false end
        parts.text:SetFontStyle(element, floor(size * 0.45), nil, nil, true)
        parts.text:SetTextColor(unpack(element.Color))
        parts.text:SetText('Abc')
        parts.text:Show()
        return true
    end
    if display.Icon or (display.type ~= 'group' and display.type ~= 'dynamicgroup') then return false end

    local scale = size / 32
    if display.type == 'group' then
        StackBlocks(parts, host, GROUP_BLOCKS, scale)
        return true
    end

    StackBlocks(parts, host, DYNAMIC_BLOCKS, scale)
    parts.line:NUISetPixelSize(1, size)
    parts.line:ClearAllPoints()
    parts.line:NUISetPixelPoint('CENTER', host, 'CENTER')
    parts.line:Show()
    local anim = parts.anim
    anim.elapsed, anim.scale, anim.top, anim.block = 0, scale, parts.blocks[1], parts.blocks[2]
    anim:SetScript('OnUpdate', Animate)
    anim:Show()
    return true
end
