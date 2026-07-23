--[[
# Icon

* A square icon with an optional black border and an item-quality overlay.
* Feed it a raw texture, or an itemID to auto-resolve icon + quality tier.

## Examples

?   row:Icon({ texture = 134400, size = 28 })
?   row:Icon({ itemID = 210796 })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local C_Item = C_Item

local QUALITY_ATLAS_PATTERN = "|A:(Professions%-ChatIcon%-Quality%-Tier%d):%d+:%d+"
local QUESTION_MARK = 134400

local GetItemInfo = C_Item.GetItemInfo
local GetItemIconByID = C_Item.GetItemIconByID

-- Crop the default 1px border out of a square icon (matches a zoom of 1).
local function ZoomTexture(texture)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local function ResolveQuality(qualityTexture, itemID)
    qualityTexture:Hide()
    local _, itemLink = GetItemInfo(itemID)
    if not itemLink then return end
    local atlas = itemLink:match(QUALITY_ATLAS_PATTERN)
    if atlas then
        qualityTexture:SetAtlas(atlas, false)
        qualityTexture:Show()
    end
end

---@class KajiGUIIcon : Frame
---@field icon Texture
---@field border? Frame
---@field qualityTexture? Texture
---@field SetTexture fun(self: KajiGUIIcon, tex: string|number)
---@field SetItemID fun(self: KajiGUIIcon, id: number)
---@field SetEnabled fun(self: KajiGUIIcon, enabled: boolean)

---@class KajiGUIIconConfig
---@field size? number
---@field texture? string|number
---@field itemID? number
---@field showQuality? boolean
---@field showBorder? boolean

---@param parent Frame
---@param config? KajiGUIIconConfig
---@return KajiGUIIcon
function InstanceMixin:CreateIcon(parent, config)
    config = config or {}
    local size = config.size or 24
    local itemID = config.itemID
    local showQuality = config.showQuality ~= false
    local showBorder = config.showBorder ~= false

    local container = CreateFrame("Frame", nil, parent)
    pixel.SetPixelSize(container, size, size)

    -- Icon texture
    local iconTexture = container:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelPoint(iconTexture, "TOPLEFT", 1, -1)
    pixel.SetPixelPoint(iconTexture, "BOTTOMRIGHT", -1, 1)
    if itemID then
        iconTexture:SetTexture(GetItemIconByID(itemID) or QUESTION_MARK)
    else
        iconTexture:SetTexture(config.texture or QUESTION_MARK)
    end
    ZoomTexture(iconTexture)
    container.icon = iconTexture

    -- Border
    if showBorder then
        local border = CreateFrame("Frame", nil, container, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        border:SetBackdropBorderColor(0, 0, 0, 1)
        container.border = border
    end

    -- Quality overlay
    if showQuality and itemID then
        local qualityFrame = CreateFrame("Frame", nil, container)
        qualityFrame:SetFrameLevel(container:GetFrameLevel() + 10)
        pixel.SetPixelSize(qualityFrame, 14, 14)
        pixel.SetPixelPoint(qualityFrame, "TOPLEFT", container, "TOPLEFT", -4, 4)

        local qualityTexture = qualityFrame:CreateTexture(nil, "OVERLAY")
        qualityTexture:SetAllPoints()
        ResolveQuality(qualityTexture, itemID)

        container.qualityFrame = qualityFrame
        container.qualityTexture = qualityTexture
    end

    function container:SetTexture(tex)
        self.icon:SetTexture(tex)
    end

    function container:SetItemID(id)
        self.icon:SetTexture(GetItemIconByID(id) or QUESTION_MARK)
        if self.qualityTexture then
            ResolveQuality(self.qualityTexture, id)
        end
    end

    function container:SetEnabled(enabled)
        self:SetAlpha(enabled and 1 or 0.5)
    end

    ---@cast container KajiGUIIcon
    return container
end
