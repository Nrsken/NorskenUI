---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local strfind = string.find
local strlower = strlower
local Mixin = Mixin
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local setmetatable = setmetatable
local xpcall = xpcall
local geterrorhandler = geterrorhandler
local math_max = math.max
local math_min = math.min
local math_rad = math.rad
local type = type

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

local PanelTemplates_SelectTab = PanelTemplates_SelectTab
local PanelTemplates_DeselectTab = PanelTemplates_DeselectTab
local PanelTemplates_SetDisabledTabState = PanelTemplates_SetDisabledTabState

-- Normal Textures
local CROSS_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\NorskenCustomCrossv3.png'
local TRANSPARENT_TEXTURE = 'Interface\\PaperDollInfoFrame\\UI-GearManager-LeaveItem-Transparent'

-- Atlas Textures
local EXPAND_ATLAS = 'UI-QuestTrackerButton-Secondary-Expand'
local COLLAPSE_ATLAS = 'UI-QuestTrackerButton-Secondary-Collapse'
local HIGHTLIGHT_ATLAS = 'UI-QuestTrackerButton-Yellow-Highlight'

local PLUS_ATLAS = 'common-button-list-plus'
local MINUS_ATLAS = 'common-icon-minus'
local ARROW_ATLAS = 'CovenantSanctum-Renown-Arrow-Depressed'
local RESET_ATLAS = 'GM-raidMarker-reset'

local AZERITE_ICON_ATLAS = 'AzeriteIconFrame'

-- Skin registry --

---@type SkinEntry[]
Skinning.skins = {}
---@type table<string, SkinEntry[]>
Skinning.addonIndex = {}
-- Weak-keyed set of skinned widgets implementing NUIUpdateSkinColors()
Skinning.skinned = setmetatable({}, { __mode = 'k' })

---Register a skin function, run once its Blizzard addon is loaded (or at enable for base UI).
---Safe to call at file scope: before enable it only queues, after enable it runs right away.
---@param addonName string? Blizzard addon that must load first; nil = always-loaded base UI
---@param key string Toggle key under db.Frames
---@param func fun(S: SkinningModule) Skin function; receives the Skinning module
function Skinning:RegisterSkin(addonName, key, func)
    local entry = { addonName = addonName, key = key, func = func, ran = false }
    self.skins[#self.skins + 1] = entry
    if addonName then
        local list = self.addonIndex[addonName]
        if not list then
            list = {}
            self.addonIndex[addonName] = list
        end
        list[#list + 1] = entry
    end

    -- A file loading after OnEnable would otherwise sit unran until the next ApplySettings.
    if self.db and self:IsEnabled() and (not addonName or IsAddOnLoaded(addonName)) then
        self:RunSkin(entry)
    end
end

---Track a widget for live recoloring, it must implement NUIUpdateSkinColors()
---@param widget Frame|Button|StatusBar
function Skinning:RegisterSkinned(widget)
    self.skinned[widget] = true
end

---Resolve the accent from the mode picked in the db: theme, class or custom.
---@return number r, number g, number b, number a
function Skinning:GetAccentColor()
    return NRSKNUI:GetAccentColor(self.db.General.AccentMode, self.db.General.CustomAccentColor)
end

-- Widget toolkit --

local SkinnedBackdropMixin = {}
local SkinnedIconBackdropMixin = {}
local SkinnedButtonMixin = {}
local SkinnedCloseButtonMixin = {}
local SkinnedTabMixin = {}
local SkinnedThumbMixin = {}
local SkinnedCheckMixin = {}
local SkinnedEditBoxMixin = {}
---@class SkinnedItemButtonMixin
local SkinnedItemButtonMixin = {}
local SkinnedStatusBarMixin = {}
local NUICollapseButtonMixin = {}

function SkinnedBackdropMixin:NUIUpdateSkinColors()
    local bg, border = Skinning.db.General.BackgroundColor, Skinning.db.General.BorderColor

    self:SetBackgroundColor(bg[1], bg[2], bg[3], self.NUIBgAlpha or bg[4])
    self:SetBorderColor(border[1], border[2], border[3], border[4])
end

---Create a pixel-perfect backdrop child frame colored from the Blizzard Elements db
---@param frame Frame
---@param template string? 'Transparent' pins the background alpha at 0.5
---@param skipRegister boolean? Skip recolor registration (caller owns coloring)
---@return Frame|nil backdrop
function Skinning:CreatePanelBackdrop(frame, template, skipRegister)
    if not frame then return end
    if frame.NUIBackdrop then return frame.NUIBackdrop end

    local backdrop = CreateFrame('Frame', nil, frame)
    backdrop:SetAllPoints(frame)
    backdrop:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))
    backdrop:NUICreateBackdrop()

    ---@cast backdrop Frame & PublicBackdropMixin & SkinnedBackdropMixin
    Mixin(backdrop, SkinnedBackdropMixin)

    if template == 'Transparent' then
        backdrop.NUIBgAlpha = 0.5
    end

    backdrop:NUIUpdateSkinColors()

    if not skipRegister then
        self:RegisterSkinned(backdrop)
    end

    frame.NUIBackdrop = backdrop
    return backdrop
end

---@param bar StatusBar
---@param template string? 'Transparent' pins the background alpha at 0.5
---@return Frame|nil backdrop
function Skinning:CreateStatusBarBackdrop(bar, template)
    if not bar then return end
    if bar.NUIBackdrop then return bar.NUIBackdrop end

    local backdrop = CreateFrame('Frame', nil, bar)
    backdrop:SetPoint('TOPLEFT', bar, -1, 1)
    backdrop:SetPoint('BOTTOMRIGHT', bar, 1, -1)
    backdrop:SetFrameLevel(math_max(0, bar:GetFrameLevel() - 1))
    backdrop:NUICreateBackdrop()

    ---@cast backdrop Frame & PublicBackdropMixin & SkinnedBackdropMixin
    Mixin(backdrop, SkinnedBackdropMixin)

    if template == 'Transparent' then
        backdrop.NUIBgAlpha = 0.5
    end

    backdrop:NUIUpdateSkinColors()

    self:RegisterSkinned(backdrop)

    bar.NUIBackdrop = backdrop
    return backdrop
end

function SkinnedIconBackdropMixin:NUIUpdateSkinColors()
    local border = Skinning.db.General.BorderColor
    self:SetBorderColor(border[1], border[2], border[3], border[4])
end

---@param icon Texture
---@param createBackdrop boolean? Create a border frame behind the icon
function Skinning:HandleIcon(icon, createBackdrop)
    if not icon then return end

    icon:NUISetZoom()

    if createBackdrop and not icon.NUIBackdrop then
        local parent = icon:GetParent()
        local backdrop = CreateFrame('Frame', nil, parent)
        backdrop:SetPoint('TOPLEFT', icon, -1, 1)
        backdrop:SetPoint('BOTTOMRIGHT', icon, 1, -1)
        backdrop:NUIAddBorders()
        local border = self.db.General.BorderColor
        backdrop:SetBorderColor(border[1], border[2], border[3], border[4])

        ---@cast backdrop Frame & PublicBackdropMixin & SkinnedIconBackdropMixin
        Mixin(backdrop, SkinnedIconBackdropMixin)

        self:RegisterSkinned(backdrop)
        icon.NUIBackdrop = backdrop
    end
end

-- Highlight overlay --

---@param widget Button
local function UpdateHighlightColor(widget)
    if not widget.NUIHighlight then return end
    local highlight = Skinning.db.General.HighlightColor
    widget.NUIHighlight:SetColorTexture(highlight[1], highlight[2], highlight[3], highlight[4])
end

---Inset ADD-blended highlight, recolored on every theme/color change.
---@param widget Button
local function AddHighlight(widget)
    local highlight = widget:CreateTexture(nil, 'HIGHLIGHT')
    highlight:SetPoint('TOPLEFT', widget, 'TOPLEFT', 2, -2)
    highlight:SetPoint('BOTTOMRIGHT', widget, 'BOTTOMRIGHT', -2, 2)
    highlight:SetBlendMode('ADD')
    widget.NUIHighlight = highlight

    UpdateHighlightColor(widget)
end

-- Arrow buttons --

local ARROW_ROTATION = { left = 0, up = math_rad(-90), down = math_rad(90), right = math_rad(180), }
local function CreateArrowTexture(button, direction, sizeX, sizeY, point, relativeTo, relativePoint, xOffset, yOffset)
    if button.NUIArrow then return end

    local arrow = button:CreateTexture(nil, 'ARTWORK')
    arrow:NUISetPixelPoint(point or 'CENTER', relativeTo or button, relativePoint or 'CENTER', xOffset or 0, yOffset or 0)
    arrow:NUISetPixelSize(sizeX, sizeY)
    arrow:SetAtlas(ARROW_ATLAS)
    arrow:NUISetPixelSnap()
    arrow:SetDesaturated(true)

    button.NUIArrow = arrow
    function button:NUISetArrowDirection(dir, open)
        self.NUIArrow:SetRotation(ARROW_ROTATION[dir] or 0)
        if open then
            self.NUIColorR, self.NUIColorG, self.NUIColorB = Skinning:GetAccentColor()
        else
            self.NUIColorR, self.NUIColorG, self.NUIColorB = 1, 1, 1
        end
        -- Closing the menu mid-hover must not slam the arrow back to its resting color.
        if self:IsMouseOver() then
            self.NUIArrow:SetVertexColor(Skinning:GetAccentColor())
        else
            self.NUIArrow:SetVertexColor(self.NUIColorR, self.NUIColorG, self.NUIColorB)
        end
    end

    button:NUISetArrowDirection(direction)

    button:HookScript('OnEnter', function()
        arrow:SetVertexColor(Skinning:GetAccentColor())
    end)
    button:HookScript('OnLeave', function()
        arrow:SetVertexColor(button.NUIColorR, button.NUIColorG, button.NUIColorB)
    end)
end

---@param button Button
---@param direction string 'left'|'right'|'up'|'down'
function Skinning:HandleArrowButton(button, direction)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    local sizeX, sizeY = 14, 38
    button:NUIStripTextures()
    CreateArrowTexture(button, direction, sizeX, sizeY)
end

-- Buttons --

---Explicit SetTextColor overrides the font object in every state, so the mixin owns the disabled/hover look.
---@param hovered boolean?
function SkinnedButtonMixin:NUIUpdateState(hovered)
    local disabled = self.IsEnabled and not self:IsEnabled()
    local dim = Skinning.db.General.DisabledColor[4]
    if self.NUIBackdrop then
        self.NUIBackdrop:SetAlpha(disabled and dim or 1)
    end

    local text = self.Text or (self.GetFontString and self:GetFontString())
    if not text then return end

    if disabled then
        text:SetTextColor(dim, dim, dim)
    elseif hovered then
        local r, g, b = Skinning:GetAccentColor()
        text:SetTextColor(r, g, b)
    else
        text:SetTextColor(1, 1, 1)
    end
end

---Resting state only, a hovered button repaints on the next OnEnter.
function SkinnedButtonMixin:NUIUpdateSkinColors()
    UpdateHighlightColor(self)
    self:NUIUpdateState()
end

function SkinnedButtonMixin:NUIOnEnter()
    if self.IsEnabled and not self:IsEnabled() then return end
    self:NUIUpdateState(true)
end

function SkinnedButtonMixin:NUIOnLeave()
    self:NUIUpdateState()
end

---Wrapper so SetEnabled's boolean argument isn't mistaken for the hovered flag
---@param button Button & SkinnedButtonMixin
local function UpdateButtonState(button)
    button:NUIUpdateState()
end

---Skin a text button (UIPanelButtonTemplate style). Strips button art, keeps the text.
---@param button Button
---@param template string? 'Transparent' pins the background alpha at 0.5
---@param skipRegister boolean? Skip recolor registration (caller owns coloring)
function Skinning:HandleButton(button, template, skipRegister)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    if button.ClearNormalTexture then
        button:ClearNormalTexture()
        button:ClearPushedTexture()
        button:ClearDisabledTexture()
        button:ClearHighlightTexture()
    end

    button:NUIStripTextures('ClearHide')

    local backdrop = self:CreatePanelBackdrop(button, template, skipRegister)

    if backdrop then
        for _, region in ipairs({ button:GetRegions() }) do
            if region:IsObjectType('FontString') then
                region:SetPoint('CENTER', backdrop, 'CENTER', 0, 0)
            end
        end
    end

    AddHighlight(button)

    ---@cast button Button & SkinnedButtonMixin
    Mixin(button, SkinnedButtonMixin)

    button:HookScript('OnEnter', button.NUIOnEnter)
    button:HookScript('OnLeave', button.NUIOnLeave)

    hooksecurefunc(button, 'Enable', UpdateButtonState)
    hooksecurefunc(button, 'Disable', UpdateButtonState)
    hooksecurefunc(button, 'SetEnabled', UpdateButtonState)

    button:NUIUpdateState()

    if not skipRegister then
        self:RegisterSkinned(button)
    end
end

function SkinnedCloseButtonMixin:NUIOnEnter()
    local r, g, b = Skinning:GetAccentColor()
    self.NUIBtnCross:SetVertexColor(r, g, b)
end

function SkinnedCloseButtonMixin:NUIOnLeave()
    self.NUIBtnCross:SetVertexColor(0.9, 0.9, 0.9)
end

---Skin a close button: strips the round art, draws a plain cross with accent hover
---@param button Button
---@param relativeTo Frame? Re-anchor the button to this frame's TOPRIGHT
---@param xOffset number? Defaults to -2
---@param yOffset number? Defaults to -2
function Skinning:HandleCloseButton(button, relativeTo, xOffset, yOffset)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    if button.ClearNormalTexture then
        button:ClearNormalTexture()
        button:ClearPushedTexture()
        button:ClearDisabledTexture()
        button:ClearHighlightTexture()
    end
    button:NUIStripTextures()

    if relativeTo then
        button:NUISetPixelPoint('TOPRIGHT', relativeTo, 'TOPRIGHT', xOffset or -2, yOffset or -2)
    end

    local size = math_max(8, button:GetWidth() * 0.8)
    local cross = button:CreateTexture(nil, 'OVERLAY')
    cross:SetPoint('CENTER')
    cross:SetSize(size, size)
    cross:SetTexture(CROSS_TEXTURE)
    cross:SetRotation(math_rad(45))
    cross:SetTexelSnappingBias(0)
    cross:SetSnapToPixelGrid(true)

    ---@cast button Button & SkinnedCloseButtonMixin
    Mixin(button, SkinnedCloseButtonMixin)

    button.NUIBtnCross = cross
    button:HookScript('OnEnter', button.NUIOnEnter)
    button:HookScript('OnLeave', button.NUIOnLeave)
end

---Skin a ButtonFrameTemplate/PortraitFrameTemplate window shell
---@param frame Frame
function Skinning:HandlePortraitFrame(frame)
    if not frame or frame.NUISkinned then return end
    frame.NUISkinned = true

    frame:NUIStripTextures('Keyed')

    self:CreatePanelBackdrop(frame)
    if frame.CloseButton then self:HandleCloseButton(frame.CloseButton, frame) end

    return frame
end

-- Tabs --

---@param selected boolean
---@param disabled boolean?
function SkinnedTabMixin:NUISetTabSelected(selected, disabled)
    self.NUISelected = selected
    self.NUIDisabled = disabled
    local text = self.Text or (self.GetFontString and self:GetFontString())
    if not text then return end

    -- Style tab text, blizzard moves it a lot on the Y axis for selected tabs so take control and center it.
    text:ClearAllPoints()
    text:SetPoint('CENTER', self.NUIBackdrop, 'CENTER', 0, 0)
    text:SetFontStyle(Skinning.db, Skinning.db.FontTabSize, nil, nil, nil, true)

    -- Selected tabs have their text colored in accent, non selected have white color.
    if disabled then
        local dim = Skinning.db.General.DisabledColor[4]
        text:SetTextColor(dim, dim, dim)
    elseif selected then
        local r, g, b = Skinning:GetAccentColor()
        text:SetTextColor(r, g, b)
    else
        text:SetTextColor(1, 1, 1)
    end
end

function SkinnedTabMixin:NUIUpdateSkinColors()
    UpdateHighlightColor(self)
    self:NUISetTabSelected(self.NUISelected or false, self.NUIDisabled)
end

local panelTabsHooked = false
local function EnsurePanelTabHooks()
    if panelTabsHooked then return end
    panelTabsHooked = true

    if PanelTemplates_SelectTab then
        hooksecurefunc('PanelTemplates_SelectTab', function(tab)
            if tab.NUISkinned and tab.NUISetTabSelected then tab:NUISetTabSelected(true) end
        end)
    end
    if PanelTemplates_DeselectTab then
        hooksecurefunc('PanelTemplates_DeselectTab', function(tab)
            if tab.NUISkinned and tab.NUISetTabSelected then tab:NUISetTabSelected(false) end
        end)
    end
    if PanelTemplates_SetDisabledTabState then
        hooksecurefunc('PanelTemplates_SetDisabledTabState', function(tab)
            if tab.NUISkinned and tab.NUISetTabSelected then
                tab:NUISetTabSelected(tab.NUISelected or false, tab.isDisabled)
            end
        end)
    end
end

---Skin a panel tab (bottom PanelTabButtonTemplate or top TabSystem tab)
---@param tab Button
function Skinning:HandleTab(tab)
    if not tab or tab.NUISkinned then return end
    tab.NUISkinned = true

    tab:NUIStripTextures()
    local backdrop = self:CreatePanelBackdrop(tab)
    if backdrop then
        backdrop:ClearAllPoints()
        backdrop:SetPoint('TOPLEFT', tab, 0, 0)
        backdrop:SetPoint('BOTTOMRIGHT', tab, 0, 1)
    end

    ---@cast tab Button & SkinnedTabMixin
    Mixin(tab, SkinnedTabMixin)

    if tab.SetTabSelected then
        hooksecurefunc(tab, 'SetTabSelected', SkinnedTabMixin.NUISetTabSelected)
    else
        EnsurePanelTabHooks()
    end

    AddHighlight(tab)

    tab:NUISetTabSelected(tab.isSelected or false)
    self:RegisterSkinned(tab)
end

---Skin a row of tabs, optionally moving the row under the anchor's bottom edge.
---@param source string|NUITabSystem|Frame Global name prefix, or a TabSystemTemplate frame
---@param anchor Frame? Frame to hang the row under, omit to skin the tabs where Blizzard put them
function Skinning:HandleTabRow(source, anchor)
    if not source then return end

    if type(source) == 'string' then
        local prev
        local i = 1
        local tab = _G[source .. i]
        while tab do
            self:HandleTab(tab)

            if anchor then
                tab:ClearAllPoints()
                if prev then
                    tab:NUISetPixelPoint('TOPLEFT', prev, 'TOPRIGHT', -1, 0)
                else
                    tab:NUISetPixelPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, 1)
                end
                prev = tab
            end

            i = i + 1
            tab = _G[source .. i]
        end
        return
    end

    if not source.tabs then return end
    for _, tab in ipairs(source.tabs) do
        self:HandleTab(tab)
    end

    -- Hidden tabs drop out of the layout on their own, so there are no gaps to chain around.
    source.spacing = -1
    if anchor then
        source:ClearAllPoints()
        source:NUISetPixelPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, 1)
    end
    source:MarkDirty()
end

-- Scrollbars / scrollboxes --

function SkinnedThumbMixin:NUIUpdateThumbColor()
    if self.NUIActive then
        local r, g, b = Skinning:GetAccentColor()
        self.NUIBackdrop:SetBackgroundColor(r, g, b, 0.8)
    elseif self.NUIHover then
        local r, g, b = Skinning:GetAccentColor()
        self.NUIBackdrop:SetBackgroundColor(r, g, b, 0.5)
    else
        local bg = Skinning.db.General.PanelColor
        self.NUIBackdrop:SetBackgroundColor(bg[1], bg[2], bg[3], bg[4])
    end
end

function SkinnedThumbMixin:NUIUpdateSkinColors()
    self:NUIUpdateThumbColor()
    local border = Skinning.db.General.BorderColor
    self.NUIBackdrop:SetBorderColor(border[1], border[2], border[3], border[4])
end

function SkinnedThumbMixin:NUIOnEnter()
    self.NUIHover = true
    self:NUIUpdateThumbColor()
end

function SkinnedThumbMixin:NUIOnLeave()
    self.NUIHover = nil
    self:NUIUpdateThumbColor()
end

function SkinnedThumbMixin:NUIOnMouseDown()
    self.NUIActive = true
    self:NUIUpdateThumbColor()
end

function SkinnedThumbMixin:NUIOnMouseUp()
    self.NUIActive = nil
    self:NUIUpdateThumbColor()
end

---Skin a modern WowTrimScrollBar/MinimalScrollBar
---@param scrollBar Frame
function Skinning:HandleTrimScrollBar(scrollBar)
    if not scrollBar or scrollBar.NUISkinned then return end
    scrollBar.NUISkinned = true

    scrollBar:NUIStripTextures()
    if scrollBar.Background then scrollBar.Background:NUIStripTextures() end
    if scrollBar.Track then scrollBar.Track:NUIStripTextures() end

    if scrollBar.Back and scrollBar.Back.Texture then
        scrollBar.Back.Texture:SetDesaturated(true)
    end
    if scrollBar.Forward and scrollBar.Forward.Texture then
        scrollBar.Forward.Texture:SetDesaturated(true)
    end

    local thumb = scrollBar.GetThumb and scrollBar:GetThumb()
    if not thumb and scrollBar.Track then thumb = scrollBar.Track.Thumb end
    if thumb then
        -- Alpha only: the thumb re-reads its own atlases on state changes, so they must stay valid.
        thumb:NUIStripTextures('Alpha')
        self:CreatePanelBackdrop(thumb, nil, true)

        ---@cast thumb Frame & SkinnedThumbMixin
        Mixin(thumb, SkinnedThumbMixin)

        thumb:NUIUpdateThumbColor()

        thumb:HookScript('OnEnter', thumb.NUIOnEnter)
        thumb:HookScript('OnLeave', thumb.NUIOnLeave)
        thumb:HookScript('OnMouseDown', thumb.NUIOnMouseDown)
        thumb:HookScript('OnMouseUp', thumb.NUIOnMouseUp)

        self:RegisterSkinned(thumb)
    end
end

---Skin dynamically created ScrollBox children now and on every ScrollBox update.
---@param scrollBox ScrollBox|Frame
---@param skinChild fun(child: Frame)
function Skinning:HookScrollBoxChildren(scrollBox, skinChild)
    if not scrollBox or not scrollBox.ForEachFrame or scrollBox.NUIHooked then return end
    scrollBox.NUIHooked = true

    hooksecurefunc(scrollBox, 'Update', function(sb)
        sb:ForEachFrame(skinChild)
    end)

    scrollBox:ForEachFrame(skinChild)
end

-- Inputs --

-- Input art always sits on BACKGROUND/BORDER; the search icon (OVERLAY), the clear
-- button (a child frame) and the Instructions FontString are left alone by stripping these.
local EDITBOX_ART_LAYERS = { 'BACKGROUND', 'BORDER' }
local EDITBOX_ART_LAYER_SET = {}
for _, layer in ipairs(EDITBOX_ART_LAYERS) do EDITBOX_ART_LAYER_SET[layer] = true end
local MAX_ART_OVERHANG = 20

---Measure the union of an EditBox's art regions as offsets from the EditBox's own edges.
---InputBoxVisualTemplate hangs 5px off the left, IconSelectorEditBox 11px off the left and
---9px taller than its frame, so the geometry has to be read rather than assumed.
---@param editBox EditBox
---@return number? left, number? right, number? top, number? bottom
local function MeasureInputArt(editBox)
    local boxLeft, boxRight = editBox:GetLeft(), editBox:GetRight()
    local boxTop, boxBottom = editBox:GetTop(), editBox:GetBottom()
    if not boxLeft or not boxRight or not boxTop or not boxBottom then return end

    local left, right, top, bottom

    local function Union(object)
        local l, r, t, b = object:GetLeft(), object:GetRight(), object:GetTop(), object:GetBottom()
        if not (l and r and t and b) or r <= l or t <= b then return end

        left = left and math_min(left, l) or l
        right = right and math_max(right, r) or r
        top = top and math_max(top, t) or t
        bottom = bottom and math_min(bottom, b) or b
    end

    for _, region in ipairs({ editBox:GetRegions() }) do
        if region:IsObjectType('Texture') and EDITBOX_ART_LAYER_SET[region:GetDrawLayer()] then
            Union(region)
        end
    end

    -- NineSlice inputs carry their art on a child frame, so the frame's rect is the reference.
    if editBox.NineSlice then Union(editBox.NineSlice) end

    if not left then return end

    return math_max(-MAX_ART_OVERHANG, left - boxLeft),
        math_min(MAX_ART_OVERHANG, right - boxRight),
        math_min(MAX_ART_OVERHANG, top - boxTop),
        math_max(-MAX_ART_OVERHANG, bottom - boxBottom)
end

---Focus drives the border accent, so it repaints on every color update as well.
function SkinnedEditBoxMixin:NUIUpdateSkinColors()
    local backdrop = self.NUIBackdrop
    if not backdrop then return end

    backdrop:NUIUpdateSkinColors()

    local disabled = not self:IsEnabled()
    backdrop:SetAlpha(disabled and Skinning.db.General.DisabledColor[4] or 1)

    if self.NUIFocused and not disabled then
        local r, g, b = Skinning:GetAccentColor()
        backdrop:SetBorderColor(r, g, b, 1)
    end
end

function SkinnedEditBoxMixin:NUIOnEditFocusGained()
    self.NUIFocused = true
    self:NUIUpdateSkinColors()
end

function SkinnedEditBoxMixin:NUIOnEditFocusLost()
    self.NUIFocused = nil
    self:NUIUpdateSkinColors()
end

---Wrapper so SetEnabled's boolean argument isn't forwarded as a colour argument
---@param editBox EditBox & SkinnedEditBoxMixin
local function UpdateEditBoxState(editBox)
    editBox:NUIUpdateSkinColors()
end

---Skin an EditBox/SearchBox: fits a backdrop to the input art it replaces, keeps the search
---icon and clear button, and accents the border while the box has focus.
---@param editBox EditBox
function Skinning:HandleEditBox(editBox)
    if not editBox or editBox.NUISkinned then return end
    editBox.NUISkinned = true

    local left, right, top, bottom = MeasureInputArt(editBox)

    editBox:NUIStripTextures('Layer', EDITBOX_ART_LAYERS)
    if editBox.NineSlice then editBox.NineSlice:NUIStripTextures() end

    local backdrop = self:CreatePanelBackdrop(editBox, nil, true)
    if not backdrop then return end

    if left then
        backdrop:ClearAllPoints()
        backdrop:SetPoint('TOPLEFT', editBox, 'TOPLEFT', left, top)
        backdrop:SetPoint('BOTTOMRIGHT', editBox, 'BOTTOMRIGHT', right, bottom)
    end

    ---@cast editBox EditBox & SkinnedEditBoxMixin
    Mixin(editBox, SkinnedEditBoxMixin)

    editBox:HookScript('OnEditFocusGained', editBox.NUIOnEditFocusGained)
    editBox:HookScript('OnEditFocusLost', editBox.NUIOnEditFocusLost)

    hooksecurefunc(editBox, 'Enable', UpdateEditBoxState)
    hooksecurefunc(editBox, 'Disable', UpdateEditBoxState)
    hooksecurefunc(editBox, 'SetEnabled', UpdateEditBoxState)

    editBox:NUIUpdateSkinColors()

    self:RegisterSkinned(editBox)
end

function SkinnedCheckMixin:NUIUpdateSkinColors()
    local checked = self:GetCheckedTexture()
    if not checked then return end

    local r, g, b = Skinning:GetAccentColor()
    checked:SetColorTexture(r, g, b, 0.9)
end

---Skin a CheckButton: box backdrop with an accent-colored fill when checked
---@param check CheckButton
function Skinning:HandleCheckBox(check)
    if not check or check.NUISkinned or not check.GetCheckedTexture then return end
    check.NUISkinned = true

    if check.ClearNormalTexture then
        check:ClearNormalTexture()
        check:ClearPushedTexture()
        check:ClearHighlightTexture()
    end

    self:CreatePanelBackdrop(check)

    local r, g, b = self:GetAccentColor()
    local checked = check:GetCheckedTexture()
    if checked then
        checked:SetColorTexture(r, g, b, 0.9)
        checked:ClearAllPoints()
        checked:SetPoint('TOPLEFT', 4, -4)
        checked:SetPoint('BOTTOMRIGHT', -4, 4)
    end

    local disabledChecked = check.GetDisabledCheckedTexture and check:GetDisabledCheckedTexture()
    if disabledChecked then
        disabledChecked:SetColorTexture(0.5, 0.5, 0.5, 0.75)
        disabledChecked:ClearAllPoints()
        disabledChecked:SetPoint('TOPLEFT', 4, -4)
        disabledChecked:SetPoint('BOTTOMRIGHT', -4, 4)
    end

    ---@cast check CheckButton & SkinnedCheckMixin
    Mixin(check, SkinnedCheckMixin)

    self:RegisterSkinned(check)
end

---Menus parent to UIParent, so cross-frame comparisons need screen space.
---@param frame Frame
---@return number?
local function ScreenCenterY(frame)
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not (top and bottom) then return nil end
    return (top + bottom) * 0.5 * frame:GetEffectiveScale()
end

---DropdownButtonMixin anchors the menu and stores it on .menu before firing OnMenuOpen.
---@param dropdown DropdownButton
---@return string direction
local function GetMenuOpenDirection(dropdown)
    local menu = dropdown.menu
    local menuY = menu and ScreenCenterY(menu)
    local buttonY = ScreenCenterY(dropdown)

    return (menuY and buttonY and menuY > buttonY) and 'up' or 'down'
end

---Skin a modern dropdown button (WowStyle1DropdownTemplate/DropdownButton).
---@param dropdown WowStyle1DropdownTemplate
---@param template string? 'Transparent' pins the background alpha at 0.5
function Skinning:HandleDropdownButton(dropdown, template)
    if not dropdown or dropdown.NUISkinned then return end
    dropdown.NUISkinned = true

    dropdown.Arrow:NUIStripTextures('Alpha')

    local sizeX, sizeY = 22, 22
    CreateArrowTexture(dropdown, 'left', sizeX, sizeY, 'RIGHT', dropdown, 'RIGHT', -2, 0)

    if dropdown.Background then dropdown.Background:SetAlpha(0) end
    self:CreatePanelBackdrop(dropdown, template)

    ---@cast dropdown Button & SkinnedButtonMixin
    Mixin(dropdown, SkinnedButtonMixin)

    local function UpdateText()
        dropdown:NUIUpdateState(dropdown.NUIMenuOpen or dropdown:IsMouseOver())
    end

    -- Recolors keep the open/hovered look instead of dropping back to the resting state.
    dropdown.NUIUpdateSkinColors = UpdateText
    self:RegisterSkinned(dropdown)

    if dropdown.OnButtonStateChanged then
        hooksecurefunc(dropdown, 'OnButtonStateChanged', UpdateText)
    end

    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, function(btn)
        btn.NUIMenuOpen = true
        btn:NUISetArrowDirection(GetMenuOpenDirection(btn), true)
        UpdateText()
    end, dropdown)
    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, function(btn)
        btn.NUIMenuOpen = false
        btn:NUISetArrowDirection('left', false)
        UpdateText()
    end, dropdown)

    UpdateText()
end

-- Item buttons and quality borders --

---Forward Blizzard IconBorder quality colors onto our borders.
---r/g/b may be secret values: passed straight through, never compared or branched on.
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

---Route a Blizzard IconBorder texture's quality color onto a skinned item button.
---The border itself is kept alpha-0 but never Hide()n so Blizzard's state machine is untouched.
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

-- Status bars --

function SkinnedStatusBarMixin:NUIUpdateSkinColors()
    if self.NUIKeepColor then return end
    local r, g, b = Skinning:GetAccentColor()
    self:SetStatusBarColor(r, g, b)
end

---Skin a StatusBar: strips art, applies our statusbar texture and a backdrop
---@param bar StatusBar
---@param keepColor boolean? Keep Blizzard's bar color (e.g. faction reputation colors)
function Skinning:HandleStatusBar(bar, keepColor)
    if not bar or bar.NUISkinned then return end
    bar.NUISkinned = true

    bar:NUIStripTextures()
    bar:SetStatusBarTexture(NRSKNUI.Media.Statusbars.NorskenUI)
    self:CreateStatusBarBackdrop(bar)

    ---@cast bar StatusBar & SkinnedStatusBarMixin
    Mixin(bar, SkinnedStatusBarMixin)

    bar.NUIKeepColor = keepColor or nil
    if not keepColor then
        local r, g, b = self:GetAccentColor()
        bar:SetStatusBarColor(r, g, b)
    end
    self:RegisterSkinned(bar)
end

---Tone down next/prev paging buttons to fit the dark look
---@param button Button
function Skinning:HandleNextPrevButton(button)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    -- Listed out rather than table-collected: a nil hole would cut an ipairs walk short.
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    local disabled = button.GetDisabledTexture and button:GetDisabledTexture()

    if normal then normal:SetDesaturated(true) end
    if pushed then pushed:SetDesaturated(true) end
    if highlight then highlight:SetDesaturated(true) end
    if disabled then disabled:SetDesaturated(true) end
end

-- Collapse button mixins and styling --

---@param collapsed boolean
function NUICollapseButtonMixin:NUIDoCollapse(collapsed)
    if collapsed then
        self.NUICollapseIcon:SetAtlas(EXPAND_ATLAS, true)
    else
        self.NUICollapseIcon:SetAtlas(COLLAPSE_ATLAS, true)
    end
end

---@param texture string?
function NUICollapseButtonMixin:NUIResetTexture(texture)
    if self.NUISettingTexture then return end
    self.NUISettingTexture = true
    self:ClearNormalTexture()

    if texture and texture ~= '' then
        if strfind(texture, 'Plus') or strfind(texture, '[Cc]losed') then
            self:NUIDoCollapse(true)
        elseif strfind(texture, 'Minus') or strfind(texture, '[Oo]pen') then
            self:NUIDoCollapse(false)
        end
    end
    self.NUISettingTexture = nil
end

---@param atlas string?
function NUICollapseButtonMixin:NUIResetAtlas(atlas)
    if self.NUISettingTexture then return end
    self.NUISettingTexture = true
    self:ClearNormalTexture()

    if atlas and atlas ~= '' then
        if strfind(atlas, 'Plus') or strfind(atlas, '[Cc]losed') or strfind(atlas, 'Expand') then
            self:NUIDoCollapse(true)
        elseif strfind(atlas, 'Minus') or strfind(atlas, '[Oo]pen') or strfind(atlas, 'Collapse') then
            self:NUIDoCollapse(false)
        end
    end
    self.NUISettingTexture = nil
end

function NUICollapseButtonMixin:NUIOnEnter()
    if self:IsEnabled() and self.NUICollapseHighlight then
        self.NUICollapseHighlight:Show()
    end
end

function NUICollapseButtonMixin:NUIOnLeave()
    if self.NUICollapseHighlight then
        self.NUICollapseHighlight:Hide()
    end
end

---@param button Button
---@param isAtlas boolean?
function Skinning:ReskinCollapse(button, isAtlas)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    ---@cast button Button & NUICollapseButtonMixin
    Mixin(button, NUICollapseButtonMixin)

    button:ClearNormalTexture()
    button:ClearHighlightTexture()
    button:ClearPushedTexture()

    local container = CreateFrame('Frame', nil, button)
    container:SetAllPoints(button)
    container:SetFrameLevel(button:GetFrameLevel() + 1)
    button.NUIContainer = container

    local texture = container:CreateTexture(nil, 'OVERLAY', nil, 6)
    texture:SetPoint('CENTER')
    texture:SetAtlas(COLLAPSE_ATLAS, true)
    button.NUICollapseIcon = texture

    local highlight = container:CreateTexture(nil, 'OVERLAY', nil, 7)
    highlight:SetPoint('CENTER')
    highlight:SetAtlas(HIGHTLIGHT_ATLAS, true)
    highlight:Hide()
    button.NUICollapseHighlight = highlight

    button:HookScript('OnEnter', button.NUIOnEnter)
    button:HookScript('OnLeave', button.NUIOnLeave)

    if isAtlas then
        hooksecurefunc(button, 'SetNormalAtlas', button.NUIResetAtlas)
    else
        hooksecurefunc(button, 'SetNormalTexture', button.NUIResetTexture)
    end
end

-- Control buttons --

local CONTROL_BUTTONS = {
    { buttonName = 'zoomInButton',      rotation = 0,   size = 0.5, atlasName = PLUS_ATLAS },
    { buttonName = 'zoomOutButton',     rotation = 0,   size = 0.5, atlasName = MINUS_ATLAS },
    { buttonName = 'rotateLeftButton',  rotation = 0,   size = 0.8, atlasName = ARROW_ATLAS },
    { buttonName = 'rotateRightButton', rotation = 180, size = 0.8, atlasName = ARROW_ATLAS },
    { buttonName = 'resetButton',       rotation = 0,   size = 0.8, atlasName = RESET_ATLAS },
}

-- Runs on every UpdateLayout: the per-button guard stops icons stacking up.
---@param frame Frame
local function StyleControlButtons(frame)
    local lastButton
    for _, v in ipairs(CONTROL_BUTTONS) do
        local button = frame[v.buttonName]
        if button then
            if not button.NUIControlSkinned then
                button.NUIControlSkinned = true
                Skinning:HandleButton(button)
                button:SetSize(22, 22)

                local textureSize = math_max(8, button:GetWidth() * v.size)
                local tex = button:CreateTexture(nil, 'ARTWORK')
                tex:SetPoint('CENTER')
                tex:SetSize(textureSize, textureSize)
                tex:SetAtlas(v.atlasName)
                tex:SetTexelSnappingBias(0)
                tex:SetSnapToPixelGrid(true)
                tex:SetDesaturated(true)

                if v.rotation > 0 then tex:SetRotation(math_rad(v.rotation)) end
                if button.Icon then Skinning:HandleIcon(button.Icon) end
            end

            if button:IsShown() then
                button:ClearAllPoints()

                if lastButton then
                    button:NUISetPixelPoint('LEFT', lastButton, 'RIGHT', 1, 0)
                else
                    button:NUISetPixelPoint('LEFT', 6, 0)
                end

                lastButton = button
            end
        end
    end
end

---@param frame Frame
function Skinning:HandleControlButtons(frame)
    if not frame.NUISkinned then
        frame.NUISkinned = true
        hooksecurefunc(frame, 'UpdateLayout', StyleControlButtons)
    end
end

-- Module lifecycle --

function Skinning:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.BlizzardElements

    -- Profiles from before the modes were lowercased still hold 'Theme'/'Class'/'Custom'.
    local general = self.db.General
    general.AccentMode = strlower(general.AccentMode)
    local objDb = self.db.ObjectiveTracker
    objDb.ColorMode = strlower(objDb.ColorMode)
end

---@param entry SkinEntry
function Skinning:RunSkin(entry)
    if entry.ran then return end
    if not self.db.Enabled then return end
    if self.db.Frames[entry.key] == false then return end
    -- Flagged before the call so a skin that errors doesn't re-fire on every ADDON_LOADED.
    entry.ran = true
    xpcall(entry.func, geterrorhandler(), Skinning)
end

function Skinning:RunPendingSkins()
    for _, entry in ipairs(self.skins) do
        if not entry.ran and (not entry.addonName or IsAddOnLoaded(entry.addonName)) then
            self:RunSkin(entry)
        end
    end
end

function Skinning:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    self:UpdateDB()

    self:RunPendingSkins()

    self:RegisterEvent('ADDON_LOADED', 'OnAddonLoaded')

    self.themeSub = NRSKNUI.GUI:OnThemeChanged(function()
        if self.db.General.AccentMode ~= 'theme' then return end
        self:UpdateColors()
    end)
end

function Skinning:OnDisable()
    self:UnregisterEvent('ADDON_LOADED')
    if self.themeSub then
        self.themeSub()
        self.themeSub = nil
    end
end

function Skinning:OnAddonLoaded(_, addonName)
    local list = self.addonIndex[addonName]
    if not list then return end
    for _, entry in ipairs(list) do
        self:RunSkin(entry)
    end
end

function Skinning:UpdateColors()
    if not self.db.Enabled then return end

    for widget in pairs(self.skinned) do
        if widget.NUIUpdateSkinColors then
            xpcall(widget.NUIUpdateSkinColors, geterrorhandler(), widget)
        end
    end
end

function Skinning:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    self:UpdateDB()
    if not self.db.Enabled then return end

    self:RunPendingSkins()
    self:UpdateColors()
end
