--[[
# Util

* Helpers for the library and its consumers.
* A safe call wrapper, a pixel-perfect scaling helper, a media resolver, and the two
  shared primitives every widget is built from: the standard backdrop and the standard
  tooltip.

--]]

---@class LibKaji-1.0
local lib = _G.LibStub and _G.LibStub('LibKaji-1.0', true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local LSM = LibStub("LibSharedMedia-3.0", true)

local geterrorhandler = geterrorhandler
local xpcall = xpcall
local type = type
local tostring = tostring

local WHITE = "Interface\\Buttons\\WHITE8X8"

---Runs a consumer-supplied callback through the game's error handler so a broken handler surfaces an error but never breaks library layout.
---@param func? function
---@return ... results of func
function lib.safecall(func, ...)
    if not func then return end
    return xpcall(func, function(err) return geterrorhandler()(err) end, ...)
end

---Returns the best pixel size for the current resolution. See Pixel.lua for the math.
---@return number
function InstanceMixin:GetBestPixelSize()
    return lib.Pixel.GetBestPixelSize()
end

---Resolves an LSM media name to its path; a real path passes through unchanged.
---@param mediaType string 'font'|'sound'|'statusbar'|'border'|'background'
---@param name? string
---@return string? path
function InstanceMixin:ResolveMedia(mediaType, name)
    if not name or name == "" then return name end
    if LSM and LSM:IsValid(mediaType, name) then
        return LSM:Fetch(mediaType, name, true) -- noDefault: nil when unregistered
    end
    return name
end

---Registers a widget with the host's search index; a no-op unless the host injected one.
---@param widget Frame
---@param label? string
function InstanceMixin:RegisterSearchableWidget(widget, label)
    local register = self.services.registerSearchable
    if register then register(widget, label) end
end

-- Backdrop --

---Resolves a color given as a theme key, a literal {r,g,b[,a]}, or nil.
---@param theme table
---@param color? string|number[]
---@return number[]?
local function ResolveColor(theme, color)
    if type(color) == "string" then return theme[color] end
    return color
end

---Re-applies the spec recorded by SetBackdrop, resolving theme colors fresh on every call.
---@param frame Frame|BackdropTemplate
function lib.RefreshBackdrop(frame)
    local spec = frame._kajiBackdrop
    if not spec then return end
    local theme = frame._kajiGui.theme

    local bg = ResolveColor(theme, spec.bg)
    if bg then
        frame:SetBackdropColor(bg[1], bg[2], bg[3], spec.bgAlpha or bg[4] or 1)
    end

    local border = ResolveColor(theme, spec.border)
    if border then
        frame:SetBackdropBorderColor(border[1], border[2], border[3], spec.borderAlpha or border[4] or 1)
    end
end

---@class KajiGUIBackdropSpec
---@field bg? string|number[] theme key or literal color; omit for no fill
---@field border? string|number[] theme key or literal color; omit for no edge
---@field edgeSize? string|number theme key or literal thickness (default 1)
---@field insets? table passed straight through to SetBackdrop
---@field bgAlpha? number overrides the fill color's own alpha
---@field borderAlpha? number overrides the edge color's own alpha

---Applies the standard backdrop and records the spec for RefreshBackdrop.
---@param frame Frame|BackdropTemplate
---@param gui KajiGUIInstance
---@param spec KajiGUIBackdropSpec
function lib.SetBackdrop(frame, gui, spec)
    local theme = gui.theme
    local hasBorder = spec.border ~= nil
    local edgeSize = spec.edgeSize
    if type(edgeSize) == "string" then edgeSize = theme[edgeSize] end

    frame:SetBackdrop({
        bgFile = spec.bg ~= nil and WHITE or nil,
        edgeFile = hasBorder and WHITE or nil,
        edgeSize = hasBorder and (edgeSize or 1) or nil,
        insets = spec.insets,
    })

    frame._kajiGui = gui
    frame._kajiBackdrop = spec
    lib.RefreshBackdrop(frame)
end

-- Tooltip --

---Stores tooltip content in fields, never hooks, so re-pointing a recycled widget can't stack handlers.
---@param frame Frame
---@param gui KajiGUIInstance
---@param title? string shown in the accent color
---@param tooltip? string|{ text?: string, default?: any }|fun(tooltip: GameTooltip, frame: Frame) body text, or a filler that writes the tooltip itself
---@param opts? { anchor?: string, x?: number, y?: number, owner?: Frame }
function lib.SetTooltip(frame, gui, title, tooltip, opts)
    opts = opts or {}
    local text, default, content
    local kind = type(tooltip)
    if kind == "function" then
        content = tooltip
    elseif kind == "table" then
        text, default = tooltip.text, tooltip.default
    else
        text = tooltip
    end

    frame._kajiGui = gui
    frame._tooltipTitle = title
    frame._tooltipText = text
    frame._tooltipContent = content
    frame._tooltipDefault = default ~= nil and (type(default) == "boolean" and (default and "On" or "Off") or tostring(default)) or nil
    frame._tooltipOwner = opts.owner
    frame._tooltipAnchor = opts.anchor
    frame._tooltipX = opts.x
    frame._tooltipY = opts.y
end

---Clears a frame's tooltip content; its scripts stay put.
---@param frame Frame
function lib.ClearTooltip(frame)
    frame._tooltipTitle = nil
    frame._tooltipText = nil
    frame._tooltipContent = nil
    frame._tooltipDefault = nil
end

---Shows the tooltip configured by SetTooltip. Call from the widget's own OnEnter.
---@param frame Frame
function lib.ShowTooltip(frame)
    local title, text, content = frame._tooltipTitle, frame._tooltipText, frame._tooltipContent
    -- An icon-only button carries "" as its label, which is a title we must not print.
    if title == "" then title = nil end
    if not (title or text or content) then return end

    local theme = frame._kajiGui.theme
    local accent = frame._accentColor or theme.accent -- a config.accentColor widget titles in its own accent
    GameTooltip:SetOwner(frame._tooltipOwner or frame, frame._tooltipAnchor or "ANCHOR_CURSOR_RIGHT", frame._tooltipX or 30, frame._tooltipY or 0)

    -- A filler writes its own header, so the widget's title is its to set and ours only appends.
    if content then
        content(GameTooltip, frame)
        if text then
            GameTooltip:AddLine(text, theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], true)
        end
    else
        GameTooltip:SetText(title or text, accent[1], accent[2], accent[3], 1, false)
        if title and text then
            GameTooltip:AddLine(text, theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], true)
        end
    end
    if frame._tooltipDefault then
        GameTooltip:AddLine("Default: " .. frame._tooltipDefault, theme.success[1], theme.success[2], theme.success[3])
    end
    GameTooltip:Show()
end

---Counterpart to ShowTooltip, for the widget's own OnLeave.
function lib.HideTooltip()
    GameTooltip:Hide()
end

---@param texture Texture
---@param zoom? number
function lib.SetTextureZoom(texture, zoom)
    local zoomMult = zoom or 0.3
    local texMin = 0.25 * zoomMult
    local texMax = 1 - 0.25 * zoomMult

    texture:SetTexCoord(texMin, texMax, texMin, texMax)
end

-- Surface texture --

local SURFACE_TEXTURE_SIZE = 128 -- surface.png is 128x128 texels

---Tiles the surface texture one texel per physical pixel, so scanlines don't shimmer at fractional UI scales.
---@param frame Frame
---@param gui KajiGUIInstance
---@return Texture
function lib.AddSurfaceTexture(frame, gui)
    local theme = gui.theme
    local tex = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    tex:SetAllPoints()
    tex:SetTexture(theme.surfaceTexture, "REPEAT", "REPEAT")
    tex:SetAlpha(theme.surfaceAlpha)
    lib.Pixel.SetPixelSnap(tex)

    local function Retile()
        local w, h = frame:GetSize()
        if not w or w <= 0 or not h or h <= 0 then return end
        local pixelsPerUnit = frame:GetEffectiveScale() / lib.Pixel.GetPerfectPixel()
        tex:SetTexCoord(0, w * pixelsPerUnit / SURFACE_TEXTURE_SIZE, 0, h * pixelsPerUnit / SURFACE_TEXTURE_SIZE)
    end
    frame:HookScript("OnSizeChanged", Retile)
    Retile()

    return tex
end

-- Depth --

---Fades a light top into the frame's fill so the band reads as raised.
---@param frame Frame
---@param gui KajiGUIInstance
---@return Texture
function lib.AddTopSheen(frame, gui)
    local sheen = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    sheen:SetAllPoints()
    sheen:SetTexture(WHITE)
    -- VERTICAL runs bottom (first color) to top (second color).
    sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, gui.theme.sheenAlpha))
    return sheen
end

---A 1px light line just inside a frame's top border: the edge that catches the light.
---@param frame Frame
---@param gui KajiGUIInstance
---@param layer? DrawLayer defaults to ARTWORK
---@return Texture
function lib.AddTopHighlight(frame, gui, layer)
    local theme = gui.theme
    local line = frame:CreateTexture(nil, layer or "ARTWORK")
    lib.Pixel.SetPixelHeight(line, theme.borderSize)
    lib.Pixel.SetPixelPoint(line, "TOPLEFT", frame, "TOPLEFT", theme.borderSize, -theme.borderSize)
    lib.Pixel.SetPixelPoint(line, "TOPRIGHT", frame, "TOPRIGHT", -theme.borderSize, -theme.borderSize)
    lib.Pixel.SetPixelSnap(line)
    line:SetColorTexture(1, 1, 1, theme.highlightAlpha)
    return line
end

-- Selection glow --

local BAR_GLOW_WIDTH = 6

---A soft glow spilling right from a row's accent bar. Created hidden; lib.PaintSelected shows it.
---@param row Frame
---@param bar Texture the row's accent bar
---@return Texture
function lib.CreateBarGlow(row, bar)
    -- Above the selection tint (BACKGROUND 1), below icons and text.
    local glow = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetTexture(WHITE)
    lib.Pixel.SetPixelWidth(glow, BAR_GLOW_WIDTH)
    lib.Pixel.SetPixelPoint(glow, "TOPLEFT", bar, "TOPRIGHT", 0, 0)
    lib.Pixel.SetPixelPoint(glow, "BOTTOMLEFT", bar, "BOTTOMRIGHT", 0, 0)
    glow:Hide()
    return glow
end

---Shows the row's selection tint and bar glow, both fading out to the right; the caller owns the bar.
---@param row { selectedBg: Texture, barGlow: Texture } a sidebar row
---@param theme KajiTheme
function lib.PaintSelected(row, theme)
    local a = theme.accent
    local clear = CreateColor(a[1], a[2], a[3], 0)
    row.selectedBg:SetTexture(WHITE)
    row.selectedBg:SetGradient("HORIZONTAL", CreateColor(a[1], a[2], a[3], theme.selectionGlowAlpha), clear)
    row.selectedBg:Show()
    row.barGlow:SetGradient("HORIZONTAL", CreateColor(a[1], a[2], a[3], theme.barGlowAlpha), clear)
    row.barGlow:Show()
end

-- Frame glow --

local SMALL_GLOW_MARGIN = 8  -- glow_small.png's slice margin and falloff
local LARGE_GLOW_MARGIN = 16 -- glow.png's

---Hidden 9-slice glow anchored fully outside the frame, so a translucent fill never shows it through.
---@param frame Frame
---@param gui KajiGUIInstance
---@param reach number desired reach in px; rounded to 8 or 16
---@param host? Frame draws the glow on this frame instead (default: `frame` itself)
---@return Texture
function lib.CreateFrameGlow(frame, gui, reach, host)
    local small = reach <= SMALL_GLOW_MARGIN
    local margin = small and SMALL_GLOW_MARGIN or LARGE_GLOW_MARGIN
    local glow = (host or frame):CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetTexture(small and gui.theme.glowSmallTexture or gui.theme.glowTexture)
    glow:SetTextureSliceMargins(margin, margin, margin, margin)
    glow:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -margin, margin)
    glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", margin, -margin)
    glow:Hide()
    return glow
end

---Sets a frame glow's strength, 0 hides it; reads the accent live so a re-call repaints after theme changes.
---@param glow Texture from lib.CreateFrameGlow
---@param gui KajiGUIInstance
---@param strength number 0..1
---@param color? number[] a widget's own accent; defaults to the theme's
function lib.SetFrameGlow(glow, gui, strength, color)
    if strength <= 0 then
        glow:Hide()
        return
    end
    local a = color or gui.theme.accent
    glow:SetVertexColor(a[1], a[2], a[3], gui.theme.glowControlAlpha * strength)
    glow:Show()
end

---@class KajiTickBox : Frame, BackdropTemplate
---@field SetChecked fun(self: KajiTickBox, checked: boolean, instant?: boolean)
---@field SetHovered fun(self: KajiTickBox, hovered: boolean, instant?: boolean)
---@field Repaint fun(self: KajiTickBox) after a theme change
---@field SetEnabled fun(self: KajiTickBox, enabled: boolean) a disabled box keeps its fill but loses the glow

---A square tick in the Checkbox knob's style: accent fill, checkmark and glow fade in while checked.
---@param gui KajiGUIInstance
---@param parent Frame
---@param size number
---@return KajiTickBox
function lib.CreateTickBox(gui, parent, size)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    lib.Pixel.SetPixelSize(box, size, size)
    lib.SetBackdrop(box, gui, { bg = { 0, 0, 0 }, bgAlpha = 0.9, border = "widgetBorder", borderAlpha = 1 })
    ---@cast box KajiTickBox

    local glow = lib.CreateFrameGlow(box, gui, lib.FIELD_GLOW_REACH, parent)

    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetAllPoints()
    lib.Pixel.SetPixelSnap(fill)

    local check = box:CreateTexture(nil, "OVERLAY")
    check:SetAllPoints()
    lib.Pixel.SetPixelSnap(check)

    local progress, hovered, enabled = 0, false, true

    -- One tween drives fill, checkmark and glow together; only its alpha channel is used.
    local function Paint(_, _, _, p)
        progress = p
        local accent = gui.theme.accent
        fill:SetColorTexture(accent[1], accent[2], accent[3], p)
        check:SetAlpha(p)
        lib.SetFrameGlow(glow, gui, enabled and p or 0)
    end
    local animate, sync = lib.Animations:CreateColorAnimator(box, Paint, { 0, 0, 0, 0 }, gui.theme.animDuration)
    local animateEdge, syncEdge = lib.Animations:CreateHoverColorAnimator(box,
        function(r, g, b) box:SetBackdropBorderColor(r, g, b, 1) end,
        gui.theme.widgetBorder, gui.theme.accent, gui.theme.animDuration)

    function box:SetChecked(checked, instant)
        local target = checked and 1 or 0
        if instant then
            sync(0, 0, 0, target)
            Paint(0, 0, 0, target)
        else
            animate(0, 0, 0, target)
        end
    end

    function box:SetHovered(isHovered, instant)
        if instant then
            hovered = isHovered
            local edge = hovered and gui.theme.accent or gui.theme.widgetBorder
            syncEdge(edge[1], edge[2], edge[3], 1)
            self:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
        elseif isHovered ~= hovered then
            hovered = isHovered
            animateEdge(hovered)
        end
    end

    function box:SetEnabled(isEnabled)
        enabled = isEnabled
        Paint(0, 0, 0, progress)
    end

    function box:Repaint()
        lib.RefreshBackdrop(self)
        check:SetTexture(gui.theme.checkTexture)
        Paint(0, 0, 0, progress)
        self:SetHovered(hovered, true)
    end

    check:SetTexture(gui.theme.checkTexture)
    return box
end

---Shared popup treatment: the window's faint accent edge and a soft black shadow.
---@param frame Frame|BackdropTemplate a frame with a backdrop edge
---@param gui KajiGUIInstance
---@param accentEdge? boolean false keeps the plain widget border; default true
---@return fun() restyle call again on theme changes
function lib.StylePopup(frame, gui, accentEdge)
    local shadow = lib.CreateFrameGlow(frame, gui, gui.theme.shadowSize)
    shadow:Show()
    return function()
        local theme = gui.theme
        local edge, alpha = theme.accent, theme.windowEdgeAlpha
        if accentEdge == false then edge, alpha = theme.widgetBorder, 1 end
        frame:SetBackdropBorderColor(edge[1], edge[2], edge[3], alpha)
        shadow:SetVertexColor(0, 0, 0, theme.shadowAlpha)
    end
end

---Hover/focus strengths for fields, so every input reacts the same way.
lib.GLOW_HOVER = 0.5
lib.GLOW_ACTIVE = 1
lib.FIELD_GLOW_REACH = 8 -- the small glow
lib.HOVER_BAR_ALPHA = 0.45 -- a hovered list row's accent bar, before it's selected

-- Icon glow --

local ICON_GLOW_CANVAS = 2 -- baked glow files are the icon's blurred shape on a canvas this many times its size

---Accent glow behind an icon; returns a painter taking the icon's alpha, a no-op without glowPath.
---@param owner Frame
---@param icon Texture
---@param width number the icon's size
---@param height number
---@param glowPath? string|number
---@param gui KajiGUIInstance
---@param rotation? number radians, matching the icon's
---@return fun(alpha: number)
function lib.AddIconGlow(owner, icon, width, height, glowPath, gui, rotation)
    if not glowPath then return function() end end
    local theme = gui.theme
    local glow = owner:CreateTexture(nil, "BACKGROUND", nil, -1)
    glow:SetTexture(glowPath)
    local dx, dy = width * (ICON_GLOW_CANVAS - 1) / 2, height * (ICON_GLOW_CANVAS - 1) / 2
    glow:SetPoint("TOPLEFT", icon, "TOPLEFT", -dx, dy)
    glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", dx, -dy)
    if rotation then glow:SetRotation(rotation) end
    return function(alpha)
        local a = theme.accent
        glow:SetVertexColor(a[1], a[2], a[3], alpha * theme.iconGlowAlpha)
    end
end
