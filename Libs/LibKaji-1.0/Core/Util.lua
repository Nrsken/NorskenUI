--[[
# Util

* Helpers for the library and its consumers.
* A safe call wrapper, a pixel-perfect scaling helper, a media resolver, and the
  shared primitives every widget is built from: the standard backdrop, the standard
  tooltip and the notice marker (`notice = { level = 'warning', text = '…' }` on a widget,
  `card:SetNotice(...)` on a card).

--]]

---@class LibKaji-1.0
local lib = _G.LibStub and _G.LibStub('LibKaji-1.0', true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local LSM = LibStub("LibSharedMedia-3.0", true)
local L = lib.L

local format = string.format
local geterrorhandler = geterrorhandler
local xpcall = xpcall
local type = type
local ipairs = ipairs
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
---@param opts? { anchor?: string, x?: number, y?: number, owner?: Frame, beside?: boolean } beside: the tooltip's left edge on the owner's right
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
    frame._tooltipDefault = default ~= nil and (type(default) == "boolean" and (default and L["On"] or L["Off"]) or tostring(default)) or nil
    frame._tooltipOwner = opts.owner
    frame._tooltipAnchor = opts.anchor
    frame._tooltipBeside = opts.beside
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
    if not (title or text or content or frame._mixed) then return end

    local theme = frame._kajiGui.theme
    local accent = frame._accentColor or theme.accent -- a config.accentColor widget titles in its own accent
    local owner = frame._tooltipOwner or frame
    if frame._tooltipBeside then
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", frame._tooltipX or 4, frame._tooltipY or 0)
    else
        GameTooltip:SetOwner(owner, frame._tooltipAnchor or "ANCHOR_CURSOR_RIGHT", frame._tooltipX or 30, frame._tooltipY or 0)
    end

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
        GameTooltip:AddLine(format(L["Default: %s"], frame._tooltipDefault), theme.success[1], theme.success[2], theme.success[3])
    end
    -- a setting that differs: each one's value, as WA lists them
    if frame._mixed then
        local mixed, secondary, primary = theme.mixed, theme.textSecondary, theme.textPrimary
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["Differs"], mixed[1], mixed[2], mixed[3])
        for _, entry in ipairs(frame._mixed) do
            GameTooltip:AddDoubleLine(entry.name, frame._mixedDescribe(entry.value),
                secondary[1], secondary[2], secondary[3], primary[1], primary[2], primary[3])
        end
    end
    GameTooltip:Show()
end

---Counterpart to ShowTooltip, for the widget's own OnLeave.
function lib.HideTooltip()
    GameTooltip:Hide()
end

-- Notice --

local NOTICE_SIZE = 14
local NOTICE_GAP = 3
-- only something wrong pulses; an info marker just explains and stays still
local NOTICE_LEVELS = {
    info = { title = "Info", color = "textMuted" },
    warning = { title = "Warning", color = "warning", pulse = true },
    error = { title = "Error", color = "error", pulse = true },
}

local NOTICE_PULSE_ALPHA = 0.25
local NOTICE_PULSE_STEP = 0.25 -- seconds per fade out or in; two flashes in all

---@param marker Frame
---@param label FontString?
---@param before Frame? sit left of this frame instead of after the label
local function PlaceNotice(marker, label, before)
    marker:ClearAllPoints()
    if before then
        lib.Pixel.SetPixelPoint(marker, "RIGHT", before, "LEFT", -NOTICE_GAP, 0)
        return
    end
    ---@cast label -nil
    if label:GetNumPoints() == 1 then
        -- a label held by one point sizes to its text, so its right edge is where the text ends
        lib.Pixel.SetPixelPoint(marker, "LEFT", label, "RIGHT", NOTICE_GAP, 0)
        return
    end

    local width = label:GetStringWidth()
    lib.Pixel.SetPixelPoint(marker, "LEFT", label, "LEFT", math.min(width, label:GetWidth()) + NOTICE_GAP, 0)

    -- a cold font measures 0 on a fresh login's first pass, so place it again once it has loaded
    if width == 0 and (label:GetText() or "") ~= "" then
        C_Timer.After(0, function()
            if marker:IsShown() then
                PlaceNotice(marker, label)
            end
        end)
    end
end

---How far a shown notice marker reaches past its label, for layouts that place things after the label.
---@param owner Frame
---@return number
function lib.NoticeWidth(owner)
    local marker = owner._noticeMarker
    return marker and marker._noticeLevel and NOTICE_SIZE + NOTICE_GAP or 0
end

---Tints a notice marker from the current theme; the theme fire repaints every acquired widget's.
---@param owner Frame
function lib.PaintNotice(owner)
    local marker = owner._noticeMarker
    if not (marker and marker._noticeLevel) then return end

    local theme = marker._kajiGui.theme
    local color = theme[marker._noticeLevel.color]
    marker.icon:SetTexture(theme.noticeTexture)
    marker.icon:SetVertexColor(color[1], color[2], color[3], 1)
    marker._accentColor = color -- the tooltip titles in the level's colour
end

---@class KajiGUINotice
---@field level? "info"|"warning"|"error" defaults to warning
---@field title? string the tooltip's title, the level's name by default
---@field text string|string[] what the marker's tooltip says; several messages list as bullets

---@param text string|string[]
---@return string
local function NoticeText(text)
    if type(text) ~= "table" then return text end
    if #text == 1 then return text[1] end

    local lines = {}
    for i, line in ipairs(text) do
        lines[i] = "• " .. line
    end
    return table.concat(lines, "\n")
end

---Two soft flashes, so a message that just appeared catches the eye; it sits still after.
---Alpha rather than scale: a 14px marker scaled under pixel rounding steps a pixel at a time.
---@param marker Frame
local function PulseNotice(marker)
    local pulse = marker._pulse
    if not pulse then
        pulse = marker:CreateAnimationGroup()
        for i = 1, 4 do
            local out = i % 2 == 1
            local fade = pulse:CreateAnimation("Alpha")
            fade:SetFromAlpha(out and 1 or NOTICE_PULSE_ALPHA)
            fade:SetToAlpha(out and NOTICE_PULSE_ALPHA or 1)
            fade:SetDuration(NOTICE_PULSE_STEP)
            fade:SetSmoothing("IN_OUT")
            fade:SetOrder(i)
        end
        marker._pulse = pulse
    end
    pulse:Stop()
    pulse:Play()
end

---A marker after `label` that shows the message on hover; nil hides it. Call once the label has its text.
---A warning or error pulses the first time it shows after the window opens; rebuilds that keep it don't.
---@param owner Frame the widget or card the marker belongs to
---@param gui KajiGUIInstance
---@param label FontString? what the marker follows; unused with `before`
---@param notice? KajiGUINotice
---@param before? Frame sit left of this frame instead, for rows whose buttons end on the right
function lib.SetNotice(owner, gui, label, notice, before)
    local marker = owner._noticeMarker
    if not notice then
        if marker then
            marker:Hide()
            marker._noticeLevel = nil
            lib.ClearTooltip(marker)
        end
        return
    end

    if not marker then
        marker = CreateFrame("Frame", nil, owner)
        marker:EnableMouse(true)
        lib.Pixel.SetPixelSize(marker, NOTICE_SIZE, NOTICE_SIZE)
        local icon = marker:CreateTexture(nil, "OVERLAY")
        icon:SetAllPoints()
        lib.Pixel.SetPixelSnap(icon)
        marker.icon = icon
        marker:SetScript("OnEnter", lib.ShowTooltip)
        marker:SetScript("OnLeave", lib.HideTooltip)
        owner._noticeMarker = marker
    end

    local level = NOTICE_LEVELS[notice.level] or NOTICE_LEVELS.warning
    local text = NoticeText(notice.text)
    marker._noticeLevel = level
    lib.SetTooltip(marker, gui, notice.title or L[level.title], text, { anchor = "ANCHOR_TOP", x = 0, y = 4 })
    -- above the widget's own hit areas, which can cover its label
    marker:SetFrameLevel(owner:GetFrameLevel() + 10)
    PlaceNotice(marker, label, before)
    lib.PaintNotice(owner)
    marker:Show()

    -- keyed by the message, as pooled widgets and rebuilt cards hand the same one to different frames
    if not level.pulse then return end
    gui._noticesSeen = gui._noticesSeen or {}
    if not gui._noticesSeen[text] then
        gui._noticesSeen[text] = true
        PulseNotice(marker)
    end
end

-- Mixed --

---@class KajiGUIMixedEntry
---@field name string whose value it is, e.g. a display's name
---@field value any

---A setting that differs between the things edited together. The label takes theme.mixed, the tooltip lists each
---value and the widget shows its empty state; the first change makes them all the same, so it goes (ClearMixed).
---@param owner Frame the widget, whose own OnEnter shows the tooltip
---@param mixed? KajiGUIMixedEntry[] nil when they all agree
---@param describe fun(value: any): string a value as the widget words it
function lib.SetMixed(owner, mixed, describe)
    owner._mixed = mixed
    owner._mixedDescribe = describe
end

---The mixed tint on a widget's label; widgets call it last in UpdateColors so a repaint keeps it.
---@param owner Frame
---@param label FontString
function lib.PaintMixed(owner, label)
    if not owner._mixed then return end

    local c = owner.gui.theme.mixed
    label:SetTextColor(c[1], c[2], c[3], 1)
end

---The first change writes one value to them all: the mark goes and the widget repaints as a plain one.
---@param owner Frame a widget with UpdateColors
function lib.ClearMixed(owner)
    if not owner._mixed then return end

    owner._mixed = nil
    owner:UpdateColors()
end

---Lets every message pulse once more, for when the window opens again.
---@param gui KajiGUIInstance
function lib.ResetNoticePulses(gui)
    gui._noticesSeen = nil
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

local SURFACE_TEXTURE_SIZE = 128 -- the surface and page tiles are 128x128 texels

---Tiles the surface texture one texel per physical pixel, so grain doesn't shimmer at fractional UI scales.
---@param frame Frame
---@param gui KajiGUIInstance
---@param kind? "surface"|"page" the theme's `<kind>Texture` and `<kind>Alpha`, surface by default
---@return Texture
function lib.AddSurfaceTexture(frame, gui, kind)
    local theme = gui.theme
    kind = kind or "surface"
    local tex = frame:CreateTexture(nil, "BACKGROUND", nil, kind == "page" and 2 or 1)
    tex:SetAllPoints()
    tex:SetTexture(theme[kind .. "Texture"], "REPEAT", "REPEAT")
    tex:SetAlpha(theme[kind .. "Alpha"])
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

-- Corner ticks --

---Registration marks on a frame's four corners, as the + marks on the page behind; the caller colours them.
---@param owner Frame draws the ticks, so a frame above a covering band can hold them
---@param target Frame whose corners they mark
---@param theme table
---@return Texture[] ticks
function lib.CreateCornerTicks(owner, target, theme)
    local length, edge = theme.cardCornerLength, theme.borderSize
    local ticks = {}
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        for _, across in ipairs({ true, false }) do
            local tick = owner:CreateTexture(nil, "OVERLAY")
            lib.Pixel.SetPixelSize(tick, across and length or edge, across and edge or length)
            lib.Pixel.SetPixelPoint(tick, corner, target, corner, 0, 0)
            lib.Pixel.SetPixelSnap(tick)
            ticks[#ticks + 1] = tick
        end
    end
    return ticks
end

---Colours a frame's corner ticks in the muted text colour.
---@param ticks Texture[]
---@param theme table
function lib.PaintCornerTicks(ticks, theme)
    local muted = theme.textMuted
    for _, tick in ipairs(ticks) do
        tick:SetColorTexture(muted[1], muted[2], muted[3], theme.cardCornerAlpha)
    end
end

-- Panel chrome --

local HALFTONE_COLUMNS = 128 -- the dots repeat across a panel every 128 texels
local HALFTONE_ROWS = 1024 -- texels, drawn one per physical pixel

--[[ # Panel chrome

The list columns' panel: a bordered bgMedium fill with corner ticks and the header's dot field rising from
its foot. The window sidebar, page lists and item trees all wear it, so they read as one family.

## Example

    local RestyleChrome = lib.CreatePanelChrome(panel, gui)
    gui:OnThemeChanged(RestyleChrome)
]]
---@param panel Frame a BackdropTemplate frame
---@param gui table
---@return fun() restyle repaints for the current theme
function lib.CreatePanelChrome(panel, gui)
    local theme = gui.theme
    local edge = theme.borderSize
    lib.SetBackdrop(panel, gui, { bg = "bgMedium", border = "border", edgeSize = "borderSize" })
    -- held above the panel's children, so a scrollbar running up its right edge doesn't cover the right corners
    local corners = CreateFrame("Frame", nil, panel)
    lib.Pixel.SetPixelInside(corners, panel, 0, 0)
    corners:SetFrameLevel(panel:GetFrameLevel() + 50)
    local cornerTicks = lib.CreateCornerTicks(corners, panel, theme)

    local halftone = panel:CreateTexture(nil, "BACKGROUND", nil, 3)
    halftone:SetTexture(theme.halftoneTexture, "REPEAT", "CLAMP")
    lib.Pixel.SetPixelSnap(halftone)
    lib.Pixel.SetPixelPoint(halftone, "BOTTOMLEFT", panel, "BOTTOMLEFT", edge, edge)
    lib.Pixel.SetPixelPoint(halftone, "BOTTOMRIGHT", panel, "BOTTOMRIGHT", -edge, edge)

    -- one texel per physical pixel so the dots stay crisp, never taller than the texture
    local function LayoutHalftone()
        local perUnit = panel:GetEffectiveScale() / lib.Pixel.GetPerfectPixel()
        local w = (panel:GetWidth() - edge * 2) * perUnit
        local h = math.min((panel:GetHeight() - edge * 2) * perUnit, HALFTONE_ROWS)
        if w <= 0 or h <= 0 then return end

        lib.Pixel.SetPixelHeight(halftone, h / perUnit)
        halftone:SetTexCoord(0, w / HALFTONE_COLUMNS, 1 - h / HALFTONE_ROWS, 1)
    end

    panel:HookScript("OnSizeChanged", LayoutHalftone)

    local function Restyle()
        lib.RefreshBackdrop(panel)
        lib.PaintCornerTicks(cornerTicks, theme)
        local muted = theme.textMuted
        halftone:SetVertexColor(muted[1], muted[2], muted[3], theme.halftoneAlpha)
        LayoutHalftone()
    end
    Restyle()

    return Restyle
end

-- Row selection --

local SELECT_BAR = 2
local SELECT_HOVER = 0.2 -- hover previews the selection at this strength, in white
local SELECT_FADE = 0.15
local SELECT_EDGE_ALPHA = 0.6 -- the lines above and below a list row's tint, where they leave the bar

---A list row's or tab's selection in the line style, where every item stands on a track and the
---selected one lights its stretch: a 2px bar on the track's edge and a tint fading away from it.
---A list row's tint also gets a line along its top and bottom, fading out with it.
---Dark until lib.SetRowSelection lights it; move `row.selection.bar` to light a narrower stretch.
---@param row Frame
---@param theme KajiTheme
---@param edge? "left"|"bottom" the track's side: down a list's left (default) or along a tab row's foot
---@param look? boolean|"line"|"none" true or "line": just the bar, no tint; "none": neither, only the eased
---progress (lib.RowSelectionProgress) for the caller's label to fade by
function lib.CreateRowSelection(row, theme, edge, look)
    if look == true then
        look = "line"
    end
    local s = { lit = 0, hover = 0, litTo = 0, hoverTo = 0, lineOnly = look == "line", none = look == "none" }
    local bottom = edge == "bottom"
    -- the tint fades away from the bar; VERTICAL runs bottom (first colour) to top
    s.orientation = bottom and "VERTICAL" or "HORIZONTAL"

    s.bar = row:CreateTexture(nil, "OVERLAY")
    s.bar:SetTexture(WHITE)
    if bottom then
        lib.Pixel.SetPixelHeight(s.bar, SELECT_BAR)
        lib.Pixel.SetPixelPoint(s.bar, "BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        lib.Pixel.SetPixelPoint(s.bar, "BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    else
        lib.Pixel.SetPixelWidth(s.bar, SELECT_BAR)
        lib.Pixel.SetPixelPoint(s.bar, "TOPLEFT", row, "TOPLEFT", 0, 0)
        lib.Pixel.SetPixelPoint(s.bar, "BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    end
    lib.Pixel.SetPixelSnap(s.bar)

    s.tint = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    s.tint:SetTexture(WHITE)
    if bottom then
        s.tint:SetPoint("BOTTOMLEFT", s.bar, "TOPLEFT")
        s.tint:SetPoint("TOPRIGHT")
    else
        s.tint:SetPoint("TOPLEFT", s.bar, "TOPRIGHT")
        s.tint:SetPoint("BOTTOMRIGHT")

        -- above the tint, below icons and text
        s.edges = {}
        for _, side in ipairs({ "TOP", "BOTTOM" }) do
            local line = row:CreateTexture(nil, "BACKGROUND", nil, 2)
            line:SetTexture(WHITE)
            lib.Pixel.SetPixelHeight(line, theme.borderSize)
            lib.Pixel.SetPixelPoint(line, side .. "LEFT", s.bar, side .. "RIGHT", 0, 0)
            lib.Pixel.SetPixelPoint(line, side .. "RIGHT", row, side .. "RIGHT", 0, 0)
            lib.Pixel.SetPixelSnap(line)
            s.edges[#s.edges + 1] = line
        end
    end

    row.selection = s
    lib.SetRowSelection(row, theme, 0, 0, true)
end

local function Smooth(p)
    return p * p * (3 - 2 * p)
end

---The row's eased selection and hover, for painting its label alongside.
---@return number lit
---@return number hover
function lib.RowSelectionProgress(row)
    return Smooth(row.selection.lit), Smooth(row.selection.hover)
end

local function PaintRowSelection(row, theme)
    local s = row.selection
    local l, h = lib.RowSelectionProgress(row)
    local light = l + h * SELECT_HOVER
    local tinted = light > 0 and not s.none and not s.lineOnly
    for _, line in ipairs(s.edges or {}) do
        line:SetShown(tinted)
    end
    if light <= 0 or s.none then
        s.bar:Hide(); s.tint:Hide()
        return
    end

    -- a hover preview is white; the colour follows how much of the light is selection, so a click
    -- blends it into the accent
    local a, w = theme.accent, l / light
    local r, g, b = 1 + (a[1] - 1) * w, 1 + (a[2] - 1) * w, 1 + (a[3] - 1) * w
    local clear = CreateColor(r, g, b, 0)
    s.bar:SetVertexColor(r, g, b, light)
    s.tint:SetGradient(s.orientation, CreateColor(r, g, b, theme.selectionGlowAlpha * light), clear)
    for _, line in ipairs(s.edges or {}) do
        line:SetGradient("HORIZONTAL", CreateColor(r, g, b, SELECT_EDGE_ALPHA * light), clear)
    end
    s.bar:Show()
    s.tint:SetShown(not s.lineOnly)
end

---Aims a row's selection at lit (selected) and hover, crossfading there unless instant.
---@param lit number 0 or 1
---@param hover number 0 or 1
---@param instant? boolean snap, for a pooled row taking on a new entry
function lib.SetRowSelection(row, theme, lit, hover, instant)
    local s = row.selection
    s.litTo, s.hoverTo = lit, hover
    if instant then
        s.lit, s.hover = lit, hover
        PaintRowSelection(row, theme)
    end
end

---Steps a row's selection toward its aim; call from the row's OnUpdate.
---@return boolean moved repaint the label when true
function lib.StepRowSelection(row, theme, elapsed)
    local s = row.selection
    if s.lit == s.litTo and s.hover == s.hoverTo then return false end
    local step = elapsed / SELECT_FADE
    s.lit = s.litTo > s.lit and math.min(s.lit + step, s.litTo) or math.max(s.lit - step, s.litTo)
    s.hover = s.hoverTo > s.hover and math.min(s.hover + step, s.hoverTo) or math.max(s.hover - step, s.hoverTo)
    PaintRowSelection(row, theme)
    return true
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
