--[[
# Util

* Helpers for the library and its consumers.
* A safe call wrapper, a pixel-perfect scaling helper, a media resolver, and the two
  shared primitives every widget is built from: the standard backdrop and the standard
  tooltip.

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local LSM = LibStub("LibSharedMedia-3.0", true)

local geterrorhandler = geterrorhandler
local xpcall = xpcall
local type = type
local tostring = tostring

-- Every backdrop in the library is the same flat white fill with an optional 1px edge;
-- only the colors differ.
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

---Registers a widget with the host's search index, if the host injected one.
---The library has no search UI of its own, this is a no-op without the hook.
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

---Re-applies a frame's backdrop from the spec recorded by SetBackdrop. Theme colors are
---resolved on each call, so this is all a widget's UpdateColors needs to do for its
---backdrop after a theme change.
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

---Applies the library's standard backdrop and records the spec so RefreshBackdrop can
---re-tint it later without the caller restating anything.
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

---Points a frame at the standard widget tooltip. Content lives in fields rather than in
---a closure, and the frame's own OnEnter calls ShowTooltip - nothing is hooked or
---wrapped, so re-pointing a recycled widget can never stack a second handler.
---@param frame Frame
---@param gui KajiGUIInstance
---@param title? string shown in the accent color
---@param tooltip? string|{ text?: string, default?: any } body, and an optional default line
---@param opts? { anchor?: string, x?: number, y?: number, owner?: Frame }
function lib.SetTooltip(frame, gui, title, tooltip, opts)
    opts = opts or {}
    local text, default
    if type(tooltip) == "table" then
        text, default = tooltip.text, tooltip.default
    else
        text = tooltip
    end

    frame._kajiGui = gui
    frame._tooltipTitle = title
    frame._tooltipText = text
    frame._tooltipDefault = default ~= nil and
        (type(default) == "boolean" and (default and "On" or "Off") or tostring(default)) or nil
    frame._tooltipOwner = opts.owner
    frame._tooltipAnchor = opts.anchor
    frame._tooltipX = opts.x
    frame._tooltipY = opts.y
end

---Clears a frame's tooltip content. The scripts stay put; there is simply nothing to show.
---@param frame Frame
function lib.ClearTooltip(frame)
    frame._tooltipTitle = nil
    frame._tooltipText = nil
    frame._tooltipDefault = nil
end

---Shows the tooltip configured by SetTooltip. Call from the widget's own OnEnter.
---@param frame Frame
function lib.ShowTooltip(frame)
    local title, text = frame._tooltipTitle, frame._tooltipText
    if not title and not text then return end

    local theme = frame._kajiGui.theme
    GameTooltip:SetOwner(frame._tooltipOwner or frame, frame._tooltipAnchor or "ANCHOR_CURSOR_RIGHT",
        frame._tooltipX or 30, frame._tooltipY or 0)
    GameTooltip:SetText(title or text, theme.accent[1], theme.accent[2], theme.accent[3], 1, false)
    if title and text then
        GameTooltip:AddLine(text, theme.textSecondary[1], theme.textSecondary[2], theme.textSecondary[3], false)
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
