--[[
# Icon

* A square icon with an optional black border and an item-quality overlay.
* `width` is the widget's share of the row like any other widget, `size` is the icon itself
  and `align` says where the icon sits inside that share. `align = 'FILL'` drops the square
  and stretches the icon over the whole share instead, for swatches and bars.
* `text` attaches a label to one side of the icon, so an icon-plus-caption row needs one widget
  rather than an icon and a Text sharing a row. The label takes the leftover space on its side, and
  a TOP/BOTTOM label makes the widget taller instead of wider.

## Examples

    row:Icon({ width = 0.2, size = 24, align = 'RIGHT', itemID = 211878 })
    row:Icon({ width = 0.5, align = 'FILL' })
    GUI:CreateIcon(parent, { size = 32, texture = 'Interface\\Icons\\INV_Misc_QuestionMark' })

    -- A tooltip filler hands the tooltip to the game, for a real spell or item tooltip.
    row:Icon({ size = 24, texture = icon, tooltip = function(t) t:SetSpellByID(spellID) end })

    -- Icon with its caption to the right; hovering either shows the tooltip.
    row:Icon({
        width = 1,
        size = 24,
        texture = icon,
        tooltip = function(t) t:SetSpellByID(spellID) end,
        text = { text = spellName, position = 'RIGHT', size = 'small' },
    })

--]]

---@class LibKaji-1.0
local lib = _G.LibStub and _G.LibStub('LibKaji-1.0', true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local Mixin = Mixin
local C_Item = C_Item

local WIDGET_TYPE = "Icon"
local QUALITY_ATLAS_PATTERN = "|A:(Professions%-ChatIcon%-Quality%-Tier%d):%d+:%d+"
local QUESTION_MARK = 134400
local TEXT_SPACING = 6

-- Which side of the icon the label sits on, and how it reads there by default.
local TEXT_POSITIONS = {
    RIGHT = { justify = "LEFT" },
    LEFT = { justify = "RIGHT" },
    TOP = { justify = "CENTER", stacked = true },
    BOTTOM = { justify = "CENTER", stacked = true },
}

local GetItemInfo = C_Item.GetItemInfo
local GetItemIconByID = C_Item.GetItemIconByID

---@class KajiGUIIconMixin : Frame
---@field gui KajiGUIInstance
---@field iconFrame Frame the square the icon actually occupies, placed inside the widget
---@field icon Texture
---@field border Frame|BackdropTemplate
---@field qualityFrame Frame
---@field qualityTexture Texture
---@field label FontString
---@field _size number
---@field _align string
---@field _textPosition? string
---@field _textSpacing number
---@field _textColor? number[]
local IconMixin = {}

---Shows the crafting-quality pip an item link carries, if any.
---@param itemID? number
function IconMixin:UpdateQuality(itemID)
    self.qualityTexture:Hide()
    if not itemID or not self.qualityFrame:IsShown() then return end

    local _, itemLink = GetItemInfo(itemID)
    if not itemLink then return end
    local atlas = itemLink:match(QUALITY_ATLAS_PATTERN)
    if atlas then
        self.qualityTexture:SetAtlas(atlas, false)
        self.qualityTexture:Show()
    end
end

---@param tex string|number
function IconMixin:SetTexture(tex)
    self.icon:SetTexture(tex)
end

---@param id number
function IconMixin:SetItemID(id)
    self._itemID = id
    self.icon:SetTexture(GetItemIconByID(id) or QUESTION_MARK)
    self:UpdateQuality(id)
end

---@param enabled boolean
function IconMixin:SetEnabled(enabled)
    self:SetAlpha(enabled and 1 or 0.5)
end

---Places the icon square inside the widget, and the label beside or above it.
function IconMixin:LayoutIcon()
    local frame, label = self.iconFrame, self.label

    frame:ClearAllPoints()
    label:ClearAllPoints()

    if self._align == "FILL" then
        frame:SetAllPoints()
        return
    end

    pixel.SetPixelSize(frame, self._size, self._size)

    local align = self._align
    local position = self._textPosition
    local spec = position and TEXT_POSITIONS[position]

    -- A stacked label owns the full width, so the icon gives up its own side for a corner anchor.
    if spec and spec.stacked then
        local edge = position == "TOP" and "BOTTOM" or "TOP"
        local corner = align == "CENTER" and edge or edge .. align
        local labelEdge = position == "TOP" and "TOP" or "BOTTOM"

        pixel.SetPixelPoint(frame, corner, self, corner, 0, 0)
        pixel.SetPixelPoint(label, labelEdge .. "LEFT", self, labelEdge .. "LEFT", 0, 0)
        pixel.SetPixelPoint(label, labelEdge .. "RIGHT", self, labelEdge .. "RIGHT", 0, 0)

        return
    end

    if align == "RIGHT" then
        pixel.SetPixelPoint(frame, "RIGHT", self, "RIGHT", 0, 0)
    elseif align == "CENTER" then
        pixel.SetPixelPoint(frame, "CENTER", self, "CENTER", 0, 0)
    else
        pixel.SetPixelPoint(frame, "LEFT", self, "LEFT", 0, 0)
    end

    if position == "RIGHT" then
        pixel.SetPixelPoint(label, "LEFT", frame, "RIGHT", self._textSpacing, 0)
        pixel.SetPixelPoint(label, "RIGHT", self, "RIGHT", 0, 0)
    elseif position == "LEFT" then
        pixel.SetPixelPoint(label, "RIGHT", frame, "LEFT", -self._textSpacing, 0)
        pixel.SetPixelPoint(label, "LEFT", self, "LEFT", 0, 0)
    end
end

function IconMixin:UpdateColors()
    lib.RefreshBackdrop(self.border)

    local color = self._textColor or self.gui.theme.textSecondary

    self.label:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

---@param parent Frame
---@param _ any unused; Icon takes (parent, config)
---@param config table
function IconMixin:OnAcquire(parent, _, config)
    local size = config.size or 24
    local itemID = config.itemID
    local text = config.text
    local spec = text and text.enabled ~= false and TEXT_POSITIONS[text.position or "RIGHT"]

    self:SetParent(parent)
    self:ClearAllPoints()

    self._size = size
    self._align = config.align or "LEFT"
    self._textPosition = spec and (text.position or "RIGHT") or nil
    self._textSpacing = (text and text.spacing) or TEXT_SPACING
    self._textColor = text and text.color or nil

    local height = size

    if spec then
        self.gui:ApplyFont(self.label, text.size or "normal")
        self.label:SetText(text.text or "")
        self.label:SetJustifyH(text.justify or spec.justify)
        self.label:SetWordWrap(false)
        self.label:Show()

        if spec.stacked then
            height = size + self._textSpacing + self.label:GetStringHeight()
        end
    else
        self.label:SetText("")
        self.label:Hide()
    end

    pixel.SetPixelSize(self, size, height)
    self.explicitHeight = self._align ~= "FILL" or nil
    self:LayoutIcon()

    lib.SetTooltip(self, self.gui, config.tooltipTitle, config.tooltip)
    self.iconFrame:EnableMouse(config.tooltip ~= nil)

    -- With a label the icon is only part of what the reader sees, so the whole widget is the target.
    self:EnableMouse(spec ~= nil and config.tooltip ~= nil)

    self.border:SetShown(config.showBorder ~= false)
    self.qualityFrame:SetShown(config.showQuality ~= false and itemID ~= nil)

    self._itemID = itemID
    if itemID then
        self.icon:SetTexture(GetItemIconByID(itemID) or QUESTION_MARK)
    else
        self.icon:SetTexture(config.texture or QUESTION_MARK)
    end
    self:UpdateQuality(itemID)

    self:SetAlpha(1)
    self:UpdateColors()
    self:Show()
end

function IconMixin:OnRelease()
    self._itemID = nil
    self._textPosition = nil
    self._textColor = nil
    self.explicitHeight = nil
    self.icon:SetTexture(QUESTION_MARK)
    self.qualityTexture:Hide()
    self.label:SetText("")
    self.label:Hide()
    self.iconFrame:EnableMouse(false)
    self:EnableMouse(false)
    lib.ClearTooltip(self)
end

---@class KajiGUIIcon : KajiGUIIconMixin

---@class KajiGUIIconConfig
---@field size? number Icon size in pixels, independent of the widget's row width. Defaults to 24.
---@field align? 'LEFT'|'CENTER'|'RIGHT'|'FILL' Where the icon sits in the widget's width. FILL stretches it. Defaults to 'LEFT'.
---@field texture? string|number
---@field itemID? number
---@field showQuality? boolean
---@field showBorder? boolean
---@field tooltip? string|{ text?: string, default?: any }|fun(tooltip: GameTooltip, frame: Frame) Hovering the icon shows this. A function fills the tooltip itself, e.g. `function(t) t:SetSpellByID(id) end`.
---@field tooltipTitle? string Accent-colored title above a text tooltip. Ignored when `tooltip` is a filler function.
---@field text? KajiGUIIconTextConfig A label attached to one side of the icon.

---@class KajiGUIIconTextConfig
---@field text? string The label itself; colour escapes work as anywhere else.
---@field enabled? boolean Set false to keep the config but hide the label. Defaults to true.
---@field position? 'LEFT'|'RIGHT'|'TOP'|'BOTTOM' Which side of the icon it sits on. Defaults to 'RIGHT'.
---@field size? 'small'|'normal'|'large'|number Theme font size. Defaults to 'normal'.
---@field justify? 'LEFT'|'CENTER'|'RIGHT' Defaults to reading away from the icon.
---@field color? number[] Defaults to the theme's secondary text colour.
---@field spacing? number Gap between icon and label. Defaults to 6.

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local container = CreateFrame("Frame", nil, gui._poolHost)
    container.gui = gui

    local iconFrame = CreateFrame("Frame", nil, container)
    container.iconFrame = iconFrame

    local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelPoint(iconTexture, "TOPLEFT", 1, -1)
    pixel.SetPixelPoint(iconTexture, "BOTTOMRIGHT", -1, 1)
    lib.SetTextureZoom(iconTexture)
    container.icon = iconTexture

    -- The border and quality pip are always built and simply hidden when unwanted, so a
    -- recycled icon can never come back missing one.
    local border = CreateFrame("Frame", nil, iconFrame, "BackdropTemplate")
    border:SetAllPoints()
    lib.SetBackdrop(border, gui, { border = { 0, 0, 0 }, borderAlpha = 1 })
    container.border = border

    local qualityFrame = CreateFrame("Frame", nil, iconFrame)
    qualityFrame:SetFrameLevel(iconFrame:GetFrameLevel() + 10)
    pixel.SetPixelSize(qualityFrame, 14, 14)
    pixel.SetPixelPoint(qualityFrame, "TOPLEFT", iconFrame, "TOPLEFT", -4, 4)
    container.qualityFrame = qualityFrame

    local qualityTexture = qualityFrame:CreateTexture(nil, "OVERLAY")
    qualityTexture:SetAllPoints()
    container.qualityTexture = qualityTexture

    -- Given the theme font up front: an icon built without a label still has SetText called on it.
    local label = container:CreateFontString(nil, "OVERLAY")
    gui:ApplyFont(label, "normal")
    label:Hide()
    container.label = label

    -- Set once, reading the tooltip off the container, so a recycled icon can never show the
    -- previous occupant's content (see lib.SetTooltip).
    iconFrame:SetScript("OnEnter", function() lib.ShowTooltip(container) end)
    iconFrame:SetScript("OnLeave", function() lib.HideTooltip() end)
    container:SetScript("OnEnter", function() lib.ShowTooltip(container) end)
    container:SetScript("OnLeave", function() lib.HideTooltip() end)

    return Mixin(container, IconMixin)
end)

---@param parent Frame
---@param config? KajiGUIIconConfig
---@return KajiGUIIcon
function InstanceMixin:CreateIcon(parent, config)
    return self:BuildWidget(WIDGET_TYPE, parent, nil, config)
end
