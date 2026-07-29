--[[
# Icon

* A square icon with an optional black border and an item-quality overlay.

## Examples

    row:Icon({ width = 0.2, size = 24, itemID = 211878 })
    GUI:CreateIcon(parent, { size = 32, texture = 'Interface\\Icons\\INV_Misc_QuestionMark' })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
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

local GetItemInfo = C_Item.GetItemInfo
local GetItemIconByID = C_Item.GetItemIconByID

---@class KajiGUIIconMixin : Frame
---@field gui KajiGUIInstance
---@field icon Texture
---@field border Frame|BackdropTemplate
---@field qualityFrame Frame
---@field qualityTexture Texture
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

function IconMixin:UpdateColors()
    lib.RefreshBackdrop(self.border)
end

---@param parent Frame
---@param _ any unused; Icon takes (parent, config)
---@param config table
function IconMixin:OnAcquire(parent, _, config)
    local size = config.size or 24
    local itemID = config.itemID

    self:SetParent(parent)
    self:ClearAllPoints()
    pixel.SetPixelSize(self, size, size)

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
    self.icon:SetTexture(QUESTION_MARK)
    self.qualityTexture:Hide()
end

---@class KajiGUIIcon : KajiGUIIconMixin

---@class KajiGUIIconConfig
---@field size? number
---@field texture? string|number
---@field itemID? number
---@field showQuality? boolean
---@field showBorder? boolean

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local container = CreateFrame("Frame", nil, gui._poolHost)
    container.gui = gui

    local iconTexture = container:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelPoint(iconTexture, "TOPLEFT", 1, -1)
    pixel.SetPixelPoint(iconTexture, "BOTTOMRIGHT", -1, 1)
    -- Crop the default 1px border out of a square icon (matches a zoom of 1).
    iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    container.icon = iconTexture

    -- The border and quality pip are always built and simply hidden when unwanted, so a
    -- recycled icon can never come back missing one.
    local border = CreateFrame("Frame", nil, container, "BackdropTemplate")
    border:SetAllPoints()
    lib.SetBackdrop(border, gui, { border = { 0, 0, 0 }, borderAlpha = 1 })
    container.border = border

    local qualityFrame = CreateFrame("Frame", nil, container)
    qualityFrame:SetFrameLevel(container:GetFrameLevel() + 10)
    pixel.SetPixelSize(qualityFrame, 14, 14)
    pixel.SetPixelPoint(qualityFrame, "TOPLEFT", container, "TOPLEFT", -4, 4)
    container.qualityFrame = qualityFrame

    local qualityTexture = qualityFrame:CreateTexture(nil, "OVERLAY")
    qualityTexture:SetAllPoints()
    container.qualityTexture = qualityTexture

    return Mixin(container, IconMixin)
end)

---@param parent Frame
---@param config? KajiGUIIconConfig
---@return KajiGUIIcon
function InstanceMixin:CreateIcon(parent, config)
    return self:BuildWidget(WIDGET_TYPE, parent, nil, config)
end
