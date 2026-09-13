---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local pairs = pairs
local Mixin = Mixin

local TRANSPARENT_TEXTURE = 'Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent'
local AZERITE_ICON_ATLAS = 'AzeriteIconFrame'

---@class SkinnedItemButtonMixin
local SkinnedItemButtonMixin = {}

---Forward Blizzard IconBorder quality colors onto our borders, r/g/b may be secret so never compare them.
---@param r number
---@param g number
---@param b number
function SkinnedItemButtonMixin:NUISetQualityColor(r, g, b)
    self.NUIQualityShown = true
    self:SetBorderColor(r, g, b, 1)
end

function SkinnedItemButtonMixin:NUIResetQualityColor()
    self.NUIQualityShown = nil
    local border = Skinning.db.General.BorderColor
    self:SetBorderColor(border[1], border[2], border[3], border[4])
end

function SkinnedItemButtonMixin:NUIUpdateSkinColors()
    local general = Skinning.db.General
    local bg = general.BackgroundColor
    self.NUISlotBg:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    if self.NUIQualityShown then return end
    local border = general.BorderColor
    self:SetBorderColor(border[1], border[2], border[3], border[4])
end

---@param item NUIItemButton
local function UpdateAzeriteItem(item)
    if item.NUIAzeriteSkinned then return end
    item.NUIAzeriteSkinned = true
    item.AzeriteTexture:SetAlpha(0)
    item.RankFrame.Texture:SetTexture(nil)
end

---@param item NUIItemButton
local function UpdateAzeriteEmpoweredItem(item)
    item.AzeriteTexture:SetAtlas(AZERITE_ICON_ATLAS)
    item.AzeriteTexture:SetTexCoord(0, 1, 0, 1)
    item.AzeriteTexture:SetDrawLayer('BORDER', 1)
end

---Skin an item slot button (paperdoll/inspect slots, flyout buttons)
---@param button NUIItemButton
function Skinning:HandleItemButton(button)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    local icon = button.icon or button.Icon
    if icon then
        icon:NUISetPixelInside()
        icon:NUISetZoom()
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end

    button:NUIStyleButton()

    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()

    -- Keep-set by reference: regions Blizzard drives per item state must survive the strip.
    local keep = {}
    for _, region in pairs({
        icon, normal, highlight, pushed, checked,
        button.IconBorder, button.IconOverlay, button.IconOverlay2,
        button.searchOverlay, button.SearchOverlay, button.ignoreTexture,
        button.UpgradeIcon, button.NewItemTexture, button.LevelLinkLockTexture,
    }) do keep[region] = true end

    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType('Texture') and not keep[region] then
            region:SetTexture(nil)
            region:SetAtlas('')
            region:SetAlpha(0)
        end
    end

    local bg = self.db.General.BackgroundColor
    local slotBg = button:CreateTexture(nil, 'BACKGROUND', nil, -8)
    slotBg:SetAllPoints(button)
    slotBg:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    button.NUISlotBg = slotBg

    if button.ignoreTexture then
        button.ignoreTexture:SetTexture(TRANSPARENT_TEXTURE)
    end

    if button.DisplayAsAzeriteItem then
        hooksecurefunc(button, 'DisplayAsAzeriteItem', UpdateAzeriteItem)
        hooksecurefunc(button, 'DisplayAsAzeriteEmpoweredItem', UpdateAzeriteEmpoweredItem)
    end

    button:NUIAddBorders()

    ---@cast button Button & SkinnedItemButtonMixin
    Mixin(button, SkinnedItemButtonMixin)

    self:RegisterSkinned(button)

    if button.IconBorder then
        self:HandleIconBorder(button.IconBorder, button)
    end
end

---Route a Blizzard IconBorder's quality color onto a skinned item button, kept alpha-0 rather than hidden.
---@param iconBorder Texture
---@param owner Button Skinned via HandleItemButton
function Skinning:HandleIconBorder(iconBorder, owner)
    if not iconBorder or iconBorder.NUIHooked then return end
    iconBorder.NUIHooked = true

    ---@cast owner Button & SkinnedItemButtonMixin

    iconBorder:SetAlpha(0)
    hooksecurefunc(iconBorder, 'SetVertexColor', function(_, r, g, b)
        owner:NUISetQualityColor(r, g, b)
    end)
    hooksecurefunc(iconBorder, 'Show', function()
        iconBorder:SetAlpha(0)
    end)
    hooksecurefunc(iconBorder, 'Hide', function()
        owner:NUIResetQualityColor()
    end)
    hooksecurefunc(iconBorder, 'SetShown', function(_, shown)
        if not shown then owner:NUIResetQualityColor() end
    end)

    -- Blizzard usually colored the border before we hooked, so sync that missed first pass.
    if iconBorder:IsShown() then
        owner:NUISetQualityColor(iconBorder:GetVertexColor())
    else
        owner:NUIResetQualityColor()
    end
end
