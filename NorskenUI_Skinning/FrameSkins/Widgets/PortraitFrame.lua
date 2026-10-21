---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')
local Pixel = NRSKNUI.Libs.KAJI.Pixel

local Mixin = Mixin
local select = select
local ipairs = ipairs
local floor = math.floor
local tonumber = tonumber
local tinsert = table.insert
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
local SetPortraitTexture = SetPortraitTexture

local LOWER_RIGHT_VERTEX = LOWER_RIGHT_VERTEX

local DoesAddOnExist = C_AddOns and C_AddOns.DoesAddOnExist
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata

local HEADER_HEIGHT = 21
local PLATE_INSET = 2
local ICON_PAD_RATIO = 0.12
local TAB_LEVEL_OFFSET = 10

Skinning.PortraitTabSize = {
    Default = 50,
    Small = 36,
    Inline = HEADER_HEIGHT,
}

---@class NUIPortraitHeader : Frame
---@field NUITab Frame Everything that only exists while there is a portrait
---@field NUITabSize number
---@field NUIOwner Frame The skinned window, whose content the tab has to clear
---@field NUIIcon Frame & PublicBorderMixin
---@field NUIIconTexture Texture
---@field NUIFills Texture[]
---@field NUILines (Texture|Line)[]
---@field NUIBarLine Texture
local HeaderMixin = {}

function HeaderMixin:NUIUpdateSkinColors()
    local general = Skinning.db.General
    local bg, border = general.WidgetBackgroundColor, NRSKNUI:GetBorderColor(general)

    for _, fill in ipairs(self.NUIFills) do
        fill:SetVertexColor(bg[1], bg[2], bg[3], bg[4])
    end
    for _, line in ipairs(self.NUILines) do
        line:SetColorTexture(border[1], border[2], border[3], border[4])
    end
    self.NUIIcon:SetBorderColor(border[1], border[2], border[3], border[4])
end

---@param top number
---@param strata string
---@param skip Frame?
---@param ... Frame
---@return number
local function GetTopLevel(top, strata, skip, ...)
    for i = 1, select('#', ...) do
        local child = select(i, ...)
        if child ~= skip and not child:IsForbidden() then
            local childStrata, level = child:GetFrameStrata(), child:GetFrameLevel()
            if NRSKNUI:NotSecretValue(childStrata) and childStrata == strata and NRSKNUI:NotSecretValue(level) then
                if level > top then top = level end
                top = GetTopLevel(top, strata, skip, child:GetChildren())
            end
        end
    end
    return top
end

function HeaderMixin:NUIRaiseTab()
    local owner = self.NUIOwner
    local strata = owner:GetFrameStrata()
    if not NRSKNUI:NotSecretValue(strata) then return end

    self.NUITab:SetFrameLevel(GetTopLevel(self:GetFrameLevel(), strata, self:GetParent(), owner:GetChildren()) + 1)
end

---@param shown boolean
function HeaderMixin:NUISetIconShown(shown)
    self.NUITab:SetShown(shown)

    local size = self.NUITabSize
    local line = self.NUIBarLine
    line:ClearAllPoints()
    line:NUISetPixelPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 0)
    line:NUISetPixelPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', (shown and size > HEADER_HEIGHT) and size * 2 - HEADER_HEIGHT or 0, 0)
end

---@param texture string|number?
function HeaderMixin:NUISetIconTexture(texture)
    self.NUIIconTexture:SetTexture(texture)
    self.NUIIconTexture:NUISetZoom()
    self:NUISetIconShown(texture ~= nil)
end

---@param atlas string?
function HeaderMixin:NUISetIconAtlas(atlas)
    local shown = atlas ~= nil and atlas ~= ''
    -- An atlas carries its own texcoords, so no zoom here.
    if shown then self.NUIIconTexture:SetAtlas(atlas) end
    self:NUISetIconShown(shown)
end

hooksecurefunc('SetPortraitTexture', function(texture, unit)
    local header = texture and (texture --[[@as Texture & { NUIHeader: NUIPortraitHeader? }]]).NUIHeader
    if not header then return end

    -- Secret tokens only work from untainted code; hide rather than keep the last unit's face.
    if NRSKNUI:IsSecretValue(unit) then
        header:NUISetIconShown(false)
        return
    end

    SetPortraitTexture(header.NUIIconTexture, unit, true)
    header.NUIIconTexture:NUISetZoom()
    header:NUISetIconShown(true)
end)

if SetPortraitToTexture then
    hooksecurefunc('SetPortraitToTexture', function(texture, asset)
        local header = texture and (texture --[[@as Texture & { NUIHeader: NUIPortraitHeader? }]]).NUIHeader
        if header then header:NUISetIconTexture(asset) end
    end)
end

---@param frame Frame
---@return Frame?
local function FindMinMaxFrame(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.MaximizeButton and child.MinimizeButton then
            return child
        end
    end
end

---@param header NUIPortraitHeader
---@param parent Frame
---@return Texture
local function CreateFill(header, parent)
    local fill = parent:CreateTexture(nil, 'BACKGROUND')
    fill:NUISetPixelSnap()
    fill:SetColorTexture(1, 1, 1, 1)
    tinsert(header.NUIFills, fill)
    return fill
end

---@param header NUIPortraitHeader
---@param parent Frame
---@return Texture
local function CreateEdge(header, parent)
    local edge = parent:CreateTexture(nil, 'BORDER')
    edge:NUISetPixelSnap()
    tinsert(header.NUILines, edge)
    return edge
end

---@param header NUIPortraitHeader
---@param tab Frame
---@param size number
---@param cut number How far the tab reaches below the bar
local function BuildCut(header, tab, size, cut)
    local tabFill = CreateFill(header, tab)
    tabFill:NUISetPixelPoint('TOPLEFT', header, 'BOTTOMLEFT', 0, 0)
    tabFill:NUISetPixelSize(size, cut)

    -- A square with its lower-right corner pulled onto its lower-left: the triangle under the cut.
    local wedgeSize = Pixel.ToPixelGrid(cut)
    local wedge = CreateFill(header, tab)
    wedge:NUISetPixelPoint('TOPLEFT', header, 'BOTTOMLEFT', size, 0)
    wedge:SetSize(wedgeSize, wedgeSize)
    wedge:SetVertexOffset(LOWER_RIGHT_VERTEX, -wedgeSize, 0)

    local tabLine = CreateEdge(header, tab)
    tabLine:NUISetPixelHeight(1)
    tabLine:NUISetPixelWidth(size)
    tabLine:NUISetPixelPoint('BOTTOMLEFT', header, 'TOPLEFT', 0, -size)

    -- Runs through the centre of both 1px edges it joins, so the corners meet without a notch.
    local half = Pixel.ToPixelGrid(1) / 2
    local slope = tab:CreateLine(nil, 'BORDER')
    slope:SetThickness(Pixel.ToPixelGrid(1))
    slope:SetStartPoint('TOPLEFT', header, Pixel.ToPixelGrid(size), -Pixel.ToPixelGrid(size) + half)
    slope:SetEndPoint('TOPLEFT', header, Pixel.ToPixelGrid(size + cut), -Pixel.ToPixelGrid(HEADER_HEIGHT) + half)
    tinsert(header.NUILines, slope)
end

---@param header NUIPortraitHeader
---@param tab Frame
---@param size number
local function BuildTab(header, tab, size)
    local cut = size - HEADER_HEIGHT
    if cut > 0 then
        BuildCut(header, tab, size, cut)
    end

    local pad = floor(size * ICON_PAD_RATIO + 0.5)
    local icon = CreateFrame('Frame', nil, tab)
    icon:NUISetPixelPoint('TOPLEFT', header, 'TOPLEFT', pad, -pad)
    icon:NUISetPixelSize(size - pad * 2)
    icon:NUIAddBorders()
    header.NUIIcon = icon --[[@as Frame & PublicBorderMixin]]

    local iconTexture = icon:CreateTexture(nil, 'ARTWORK')
    iconTexture:NUISetPixelPoint('TOPLEFT', icon, 'TOPLEFT', 1, -1)
    iconTexture:NUISetPixelPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', -1, 1)
    header.NUIIconTexture = iconTexture
end

---@param frame PortraitFrameTemplate
---@param backdrop Frame
---@param size number
---@return NUIPortraitHeader
local function CreateHeader(frame, backdrop, size)
    local header = CreateFrame('Frame', nil, backdrop)
    ---@cast header NUIPortraitHeader
    Mixin(header, HeaderMixin)
    header.NUIFills, header.NUILines = {}, {}
    header.NUITabSize = size
    header.NUIOwner = frame
    header:NUISetPixelPoint('TOPLEFT', backdrop, 'TOPLEFT', PLATE_INSET, -PLATE_INSET)
    header:NUISetPixelPoint('TOPRIGHT', backdrop, 'TOPRIGHT', -PLATE_INSET, -PLATE_INSET)
    header:NUISetPixelHeight(HEADER_HEIGHT)
    header:SetFrameLevel(frame:GetFrameLevel() + TAB_LEVEL_OFFSET)

    CreateFill(header, header):SetAllPoints(header)

    local barLine = CreateEdge(header, header)
    barLine:NUISetPixelHeight(1)
    header.NUIBarLine = barLine

    local tab = CreateFrame('Frame', nil, header)
    tab:NUISetPixelPoint('TOPLEFT', header, 'TOPLEFT', 0, 0)
    tab:NUISetPixelSize(size * 2 - HEADER_HEIGHT, size)
    header.NUITab = tab
    header:NUIRaiseTab()
    -- Content can be built or re-levelled between shows, so measure again each time.
    frame:HookScript('OnShow', function() header:NUIRaiseTab() end)

    BuildTab(header, tab, size)

    local close = frame.CloseButton
    if close then
        close:NUISetPixelSize(HEADER_HEIGHT, HEADER_HEIGHT)
        Skinning:HandleCloseButton(close, header, 0, 0)
    end

    -- Same square as the close button, butted against its left edge.
    local minMax = FindMinMaxFrame(frame)
    if minMax then
        minMax:ClearAllPoints()
        minMax:NUISetPixelSize(HEADER_HEIGHT, HEADER_HEIGHT)
        if close then
            minMax:NUISetPixelPoint('TOPRIGHT', close, 'TOPLEFT', 0, 0)
        else
            minMax:NUISetPixelPoint('TOPRIGHT', header, 'TOPRIGHT', 0, 0)
        end
        Skinning:HandleMinMaxButton(minMax)
    end

    header:NUIUpdateSkinColors()
    Skinning:RegisterSkinned(header)

    return header
end

---@param frame PortraitFrameTemplate
---@param header NUIPortraitHeader
---@param atlas string? What the portrait showed before the strip cleared it
---@param texture string|number?
local function MirrorPortrait(frame, header, atlas, texture)
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    if not portrait then
        header:NUISetIconTexture(texture)
        return
    end

    -- Installed after the strip so its clear doesn't reach the icon; later paints arrive here.
    portrait.NUIHeader = header
    hooksecurefunc(portrait, 'SetTexture', function(_, tex) header:NUISetIconTexture(tex) end)
    hooksecurefunc(portrait, 'SetAtlas', function(_, name) header:NUISetIconAtlas(name) end)

    -- Alpha survives SetPortraitShown re-showing the container.
    frame.PortraitContainer:SetAlpha(0)

    if atlas then
        header:NUISetIconAtlas(atlas)
    else
        header:NUISetIconTexture(texture)
    end
end

---@param addonName string?
---@return string|number?
function Skinning:GetAddOnIcon(addonName)
    if not addonName or not DoesAddOnExist(addonName) then return end

    local icon = GetAddOnMetadata(addonName, 'IconTexture')
    return tonumber(icon) or icon
end

---@param frame Frame
---@param tabSize number? A Skinning.PortraitTabSize entry
---@param icon string|number? Shown in the tab; nil leaves a plain bar until NUISetIconTexture gets one
---@return NUIPortraitHeader?
function Skinning:CreatePortraitHeader(frame, tabSize, icon)
    if not frame or frame.NUIHeader then return frame and frame.NUIHeader end

    local backdrop = self:CreatePanelBackdrop(frame)
    if not backdrop then return end

    local header = CreateHeader(frame --[[@as PortraitFrameTemplate]], backdrop, tabSize or self.PortraitTabSize.Default)
    frame.NUIHeader = header
    header:NUISetIconTexture(icon)
    return header
end

---@param frame Frame
---@param tabSize number|false? Portrait tab size, a Skinning.PortraitTabSize entry; false keeps the bare shell
---@param icon string|number? Icon for a window without a portrait, or whose portrait is empty
function Skinning:HandlePortraitFrame(frame, tabSize, icon)
    if not frame or frame.NUISkinned then return end
    frame.NUISkinned = true

    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait
    local atlas, texture
    if portrait and tabSize ~= false then atlas, texture = portrait:GetAtlas(), portrait:GetTexture() end
    if not atlas and not texture then texture = icon end

    frame:NUIStripTextures('Keyed')

    local backdrop = self:CreatePanelBackdrop(frame)

    if tabSize == false or not backdrop then
        if frame.CloseButton then self:HandleCloseButton(frame.CloseButton, frame) end
        self:HandleMinMaxButton(FindMinMaxFrame(frame))
        return frame
    end

    local shell = frame --[[@as PortraitFrameTemplate]]
    local header = CreateHeader(shell, backdrop, tabSize or self.PortraitTabSize.Default)
    frame.NUIHeader = header
    MirrorPortrait(shell, header, atlas, texture)

    return frame
end
