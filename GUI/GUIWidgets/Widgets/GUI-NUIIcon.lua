---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme

local CreateFrame = CreateFrame

local qualityAtlasPattern = "|A:(Professions%-ChatIcon%-Quality%-Tier%d):%d+:%d+"

---Create an icon widget with optional quality overlay
---@param parent Frame
---@param config table
---@return Frame icon
function GUIFrame:CreateIcon(parent, config)
    config = config or {}
    local size = config.size or 24
    local texture = config.texture
    local itemID = config.itemID
    local showQuality = config.showQuality ~= false
    local showBorder = config.showBorder ~= false

    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(size, size)
    container._isNUIWidget = true
    container._widgetType = "icon"

    local iconTexture = container:CreateTexture(nil, "ARTWORK")
    iconTexture:SetPoint("TOPLEFT", 1, -1)
    iconTexture:SetPoint("BOTTOMRIGHT", -1, 1)

    if itemID then
        local icon = C_Item.GetItemIconByID(itemID)
        iconTexture:SetTexture(icon or 134400)
    elseif texture then
        iconTexture:SetTexture(texture)
    else
        iconTexture:SetTexture(134400)
    end

    iconTexture:SetZoom()
    container.icon = iconTexture

    if showBorder then
        local border = CreateFrame("Frame", nil, container, "BackdropTemplate")
        border:SetAllPoints()
        border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        border:SetBackdropBorderColor(0, 0, 0, 1)
        container.border = border
    end

    if showQuality and itemID then
        local qualityFrame = CreateFrame("Frame", nil, container)
        qualityFrame:SetFrameLevel(container:GetFrameLevel() + 10)
        qualityFrame:SetSize(14, 14)
        qualityFrame:SetPoint("TOPLEFT", container, "TOPLEFT", -4, 4)

        local qualityTexture = qualityFrame:CreateTexture(nil, "OVERLAY")
        qualityTexture:SetAllPoints()
        qualityTexture:Hide()

        local _, itemLink = GetItemInfo(itemID)
        if itemLink then
            local atlas = itemLink:match(qualityAtlasPattern)
            if atlas then
                qualityTexture:SetAtlas(atlas, false)
                qualityTexture:Show()
            end
        end

        container.qualityFrame = qualityFrame
        container.qualityTexture = qualityTexture
    end

    function container:SetTexture(tex)
        self.icon:SetTexture(tex)
    end

    function container:SetItemID(id)
        local icon = C_Item.GetItemIconByID(id)
        self.icon:SetTexture(icon or 134400)

        if self.qualityTexture then
            self.qualityTexture:Hide()
            local _, itemLink = GetItemInfo(id)
            if itemLink then
                local atlas = itemLink:match(qualityAtlasPattern)
                if atlas then
                    self.qualityTexture:SetAtlas(atlas, false)
                    self.qualityTexture:Show()
                end
            end
        end
    end

    function container:SetEnabled(enabled)
        if enabled then
            self:SetAlpha(1)
        else
            self:SetAlpha(0.5)
        end
    end

    return container
end
