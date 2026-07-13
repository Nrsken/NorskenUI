---@class NRSKNUI
local NRSKNUI = select(2, ...)

NRSKNUI.BlizzSkin = NRSKNUI.BlizzSkin or {}
local BSKIN = NRSKNUI.BlizzSkin

local hooksecurefunc = hooksecurefunc
local strfind = string.find
local Mixin = Mixin
local CreateFrame = CreateFrame
local pairs = pairs
local ipairs = ipairs
local math_max = math.max
local math_rad = math.rad
local unpack = unpack

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

-- Mixins for skinned frames, buttons, tabs, scrollbars, and item buttons.
-- These are applied to the frame after creating a backdrop and stripping textures.
local SkinnedBackdropMixin = {}
local SkinnedIconBackdropMixin = {}
local SkinnedButtonMixin = {}
local SkinnedCloseButtonMixin = {}
local SkinnedTabMixin = {}
local SkinnedThumbMixin = {}
local SkinnedCheckMixin = {}
local SkinnedItemButtonMixin = {}
local SkinnedStatusBarMixin = {}
local NUICollapseButtonMixin = {}

---@param colors SkinColors
function SkinnedBackdropMixin:NUIUpdateSkinColors(colors)
    local bg, border = colors.background, colors.border
    self:SetBackgroundColor(bg[1], bg[2], bg[3], self.NUIBgAlpha or bg[4])
    self:SetBorderColor(border[1], border[2], border[3], border[4])
end

---Create a pixel-perfect backdrop child frame colored from the Blizzard Elements db
---@param frame Frame
---@param template string? 'Transparent' halves the background alpha
---@param skipRegister boolean? Skip recolor registration (caller owns coloring)
---@return Frame|nil backdrop
function BSKIN:CreatePanelBackdrop(frame, template, skipRegister)
    if not frame then return end
    if frame.NUIBackdrop then return frame.NUIBackdrop end

    local backdrop = CreateFrame('Frame', nil, frame)
    backdrop:SetAllPoints(frame)
    backdrop:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))
    backdrop:CreateBackdrop()

    ---@cast backdrop Frame & PublicBackdropMixin & SkinnedBackdropMixin
    Mixin(backdrop, SkinnedBackdropMixin)

    if template == 'Transparent' then
        backdrop.NUIBgAlpha = 0.5
    end

    backdrop:NUIUpdateSkinColors(self:GetColors())

    if not skipRegister then
        self:RegisterSkinned(backdrop)
    end

    frame.NUIBackdrop = backdrop
    return backdrop
end

---@param bar StatusBar
---@param template string? 'Transparent' halves the background alpha
function BSKIN:CreateStatusBarBackdrop(bar, template)
    if not bar or bar.backdrop then return end

    local backdrop = CreateFrame('Frame', nil, bar)
    backdrop:SetPoint('TOPLEFT', bar, -1, 1)
    backdrop:SetPoint('BOTTOMRIGHT', bar, 1, -1)
    backdrop:SetFrameLevel(math_max(0, bar:GetFrameLevel() - 1))
    backdrop:CreateBackdrop()

    ---@cast backdrop Frame & PublicBackdropMixin & SkinnedBackdropMixin
    Mixin(backdrop, SkinnedBackdropMixin)

    if template == 'Transparent' then
        backdrop.NUIBgAlpha = 0.5
    end

    backdrop:NUIUpdateSkinColors(self:GetColors())

    self:RegisterSkinned(backdrop)

    bar.backdrop = backdrop
    return backdrop
end

---@param colors SkinColors
function SkinnedIconBackdropMixin:NUIUpdateSkinColors(colors)
    local border = colors.border
    self:SetBorderColor(border[1], border[2], border[3], border[4])
end

---@param icon Texture
---@param createBackdrop boolean? Create a border frame behind the icon
function BSKIN:HandleIcon(icon, createBackdrop)
    if not icon then return end

    icon:SetZoom()

    if createBackdrop and not icon.backdrop then
        local parent = icon:GetParent()
        local backdrop = CreateFrame('Frame', nil, parent)
        backdrop:SetPoint('TOPLEFT', icon, -1, 1)
        backdrop:SetPoint('BOTTOMRIGHT', icon, 1, -1)
        NRSKNUI:AddBorders(backdrop, self:GetBorderColor())

        ---@cast backdrop Frame & PublicBackdropMixin & SkinnedIconBackdropMixin
        Mixin(backdrop, SkinnedIconBackdropMixin)

        self:RegisterSkinned(backdrop)
        icon.backdrop = backdrop
    end
end

-- Arrow buttons --

local ARROW_ROTATION = {
    left  = 0,
    up    = math_rad(-90),
    down  = math_rad(90),
    right = math_rad(180),
}

local function CreateArrowTexture(button, direction, sizeX, sizeY, point, relativeTo, relativePoint, xOffset, yOffset)
    if button.NUIArrow then return end

    local arrow = button:CreateTexture(nil, 'ARTWORK')
    arrow:SetPixelPoint(point or 'CENTER', relativeTo or button, relativePoint or 'CENTER', xOffset or 0, yOffset or 0)
    arrow:SetPixelSize(sizeX, sizeY)
    arrow:SetAtlas(ARROW_ATLAS)
    arrow:SetPixelSnap()
    arrow:SetDesaturated(true)

    -- Store the arrow texture on the button for later access
    button.NUIArrow = arrow
    function button:NUISetArrowDirection(dir, open)
        self.NUIArrow:SetRotation(ARROW_ROTATION[dir] or 0)
        if open then
            self.NUIColorR, self.NUIColorG, self.NUIColorB = BSKIN:GetAccentColor()
        else
            self.NUIColorR, self.NUIColorG, self.NUIColorB = 1, 1, 1
        end
        -- Keep the hover color while the cursor is over the button so closing the
        -- menu mid-hover doesn't slam the arrow back to its resting color.
        if self:IsMouseOver() then
            self.NUIArrow:SetVertexColor(BSKIN:GetAccentColor())
        else
            self.NUIArrow:SetVertexColor(self.NUIColorR, self.NUIColorG, self.NUIColorB)
        end
    end

    -- Set the initial direction and color of the arrow.
    button:NUISetArrowDirection(direction)

    button:HookScript('OnEnter', function()
        arrow:SetVertexColor(BSKIN:GetAccentColor())
    end)
    button:HookScript('OnLeave', function()
        arrow:SetVertexColor(button.NUIColorR, button.NUIColorG, button.NUIColorB)
    end)
end

---@param button Button
---@param direction string 'left'|'right'|'up'|'down'
function BSKIN:HandleArrowButton(button, direction)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    local sizeX, sizeY = 14, 38
    button:StripTextures()
    CreateArrowTexture(button, direction, sizeX, sizeY)
end

-- Buttons --

---Explicit SetTextColor overrides the font object in every state, so the mixin
---owns the disabled/hover look. The backdrop is dimmed via alpha rather than
---recolored so the theme recolor system keeps sole ownership of its colors.
---@param hovered boolean?
function SkinnedButtonMixin:NUIUpdateState(hovered)
    local disabled = self.IsEnabled and not self:IsEnabled()
    local color = BSKIN:GetColors()
    self.NUIBackdrop:SetAlpha(disabled and color.disabled[4] or 1)

    local text = self.Text or (self.GetFontString and self:GetFontString())
    if not text then return end

    if disabled then
        text:SetTextColor(color.disabled[4], color.disabled[4], color.disabled[4])
    elseif hovered then
        local r, g, b = BSKIN:GetAccentColor()
        text:SetTextColor(r, g, b)
    else
        text:SetTextColor(1, 1, 1)
    end
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
---@param template string? 'Transparent' halves the background alpha
---@param skipRegister boolean? Skip recolor registration (caller owns coloring)
function BSKIN:HandleButton(button, template, skipRegister)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true
    local db = BSKIN:GetDB()

    if button.ClearNormalTexture then
        button:ClearNormalTexture()
        button:ClearPushedTexture()
        button:ClearDisabledTexture()
        button:ClearHighlightTexture()
    end

    button:StripTextures('ClearHide')

    local backdrop = self:CreatePanelBackdrop(button, template, skipRegister)

    for _, region in pairs({ button:GetRegions() }) do
        if region and region:IsObjectType('FontString') then
            if backdrop then
                region:SetPoint('CENTER', backdrop, 'CENTER', 0, 0)
            end
        end
    end

    -- Highlight texture
    button.highlight = button:CreateTexture(nil, 'HIGHLIGHT')
    button.highlight:SetPoint('TOPLEFT', button, 'TOPLEFT', 2, -2)
    button.highlight:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -2, 2)
    button.highlight:SetColorTexture(unpack(db.General.HighlightColor))
    button.highlight:SetBlendMode('ADD')

    ---@cast button Button & SkinnedButtonMixin
    Mixin(button, SkinnedButtonMixin)

    button:HookScript('OnEnter', button.NUIOnEnter)
    button:HookScript('OnLeave', button.NUIOnLeave)

    hooksecurefunc(button, 'Enable', UpdateButtonState)
    hooksecurefunc(button, 'Disable', UpdateButtonState)
    hooksecurefunc(button, 'SetEnabled', UpdateButtonState)

    button:NUIUpdateState()
end

function SkinnedCloseButtonMixin:NUIOnEnter()
    local r, g, b = BSKIN:GetAccentColor()
    self.NUIBtnCross:SetVertexColor(r, g, b)
end

function SkinnedCloseButtonMixin:NUIOnLeave()
    self.NUIBtnCross:SetVertexColor(0.9, 0.9, 0.9)
end

---Skin a close button: strips the round art, draws a plain cross with accent hover
---@param button Button
function BSKIN:HandleCloseButton(button, relativeTo, xOffset, yOffset)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    if button.ClearNormalTexture then
        button:ClearNormalTexture()
        button:ClearPushedTexture()
        button:ClearDisabledTexture()
        button:ClearHighlightTexture()
    end
    button:StripTextures()

    if relativeTo then
        button:SetPixelPoint('TOPRIGHT', relativeTo, 'TOPRIGHT', xOffset or -2, yOffset or -2)
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
function BSKIN:HandlePortraitFrame(frame)
    if not frame or frame.NUISkinned then return end
    frame.NUISkinned = true

    frame:StripTextures('Keyed')

    self:CreatePanelBackdrop(frame)
    if frame.CloseButton then self:HandleCloseButton(frame.CloseButton, frame) end

    return frame
end

-- Tabs --

---@param selected boolean
function SkinnedTabMixin:NUISetTabSelected(selected, disabled)
    self.NUISelected = selected
    local text = self.Text or (self.GetFontString and self:GetFontString())

    -- Style tab text, blizzard moves it a lot on the Y axis for selected tabs so take control and center it.
    if text then
        local db = BSKIN:GetDB()
        text:ClearAllPoints()
        text:SetPoint('CENTER', self.NUIBackdrop, 'CENTER', 0, 0)
        text:SetFontStyle(db, db.FontTabSize, nil, nil, nil, true)
    end

    -- Selected tabs have their text colored in accent, non selected have white color.
    if disabled then
        local disabledColor = BSKIN:GetDisabledColor()
        text:SetTextColor(disabledColor[4], disabledColor[4], disabledColor[4])
    elseif selected then
        local r, g, b = BSKIN:GetAccentColor()
        if text then text:SetTextColor(r, g, b) end
    else
        if text then text:SetTextColor(1, 1, 1) end
    end
end

---@param colors SkinColors
function SkinnedTabMixin:NUIUpdateSkinColors(colors)
    self:NUISetTabSelected(self.NUISelected or false)
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
function BSKIN:HandleTab(tab)
    if not tab or tab.NUISkinned then return end
    tab.NUISkinned = true
    local db = BSKIN:GetDB()

    tab:StripTextures()
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

    -- Highlight texture
    tab.highlight = tab:CreateTexture(nil, 'HIGHLIGHT')
    tab.highlight:SetPoint('TOPLEFT', tab, 'TOPLEFT', 2, -2)
    tab.highlight:SetPoint('BOTTOMRIGHT', tab, 'BOTTOMRIGHT', -2, 2)
    tab.highlight:SetColorTexture(unpack(db.General.HighlightColor))
    tab.highlight:SetBlendMode('ADD')

    tab:NUISetTabSelected(tab.isSelected or false)
    self:RegisterSkinned(tab)
end

-- Scrollbars / scrollboxes --

function SkinnedThumbMixin:NUIUpdateThumbColor()
    if self.NUIActive then
        local r, g, b = BSKIN:GetAccentColor()
        self.NUIBackdrop:SetBackgroundColor(r, g, b, 0.8)
    elseif self.NUIHover then
        local r, g, b = BSKIN:GetAccentColor()
        self.NUIBackdrop:SetBackgroundColor(r, g, b, 0.5)
    else
        local bg = BSKIN:GetPanelColor()
        self.NUIBackdrop:SetBackgroundColor(bg[1], bg[2], bg[3], bg[4])
    end
end

---@param colors SkinColors
function SkinnedThumbMixin:NUIUpdateSkinColors(colors)
    self:NUIUpdateThumbColor()
    local border = colors.border
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
function BSKIN:HandleTrimScrollBar(scrollBar)
    if not scrollBar or scrollBar.NUISkinned then return end
    scrollBar.NUISkinned = true

    scrollBar:StripTextures()
    if scrollBar.Background then scrollBar.Background:StripTextures() end
    if scrollBar.Track then scrollBar.Track:StripTextures() end

    if scrollBar.Back and scrollBar.Back.Texture then
        scrollBar.Back.Texture:SetDesaturated(true)
    end
    if scrollBar.Forward and scrollBar.Forward.Texture then
        scrollBar.Forward.Texture:SetDesaturated(true)
    end

    local thumb = scrollBar.GetThumb and scrollBar:GetThumb()
    if not thumb and scrollBar.Track then thumb = scrollBar.Track.Thumb end
    if thumb then
        -- Alpha only: the thumb re-sets its atlases on state changes and reads
        -- GetAtlasInfo(Middle:GetAtlas()) in OnSizeChanged, so atlases must stay valid
        thumb:StripTextures('Alpha')
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
---skinChild must carry its own per-child NUISkinned guard.
---@param scrollBox ScrollBox
---@param skinChild fun(child: Frame)
function BSKIN:HookScrollBoxChildren(scrollBox, skinChild)
    if not scrollBox or not scrollBox.ForEachFrame or scrollBox.NUIHooked then return end
    scrollBox.NUIHooked = true

    hooksecurefunc(scrollBox, 'Update', function(sb)
        sb:ForEachFrame(skinChild)
    end)

    scrollBox:ForEachFrame(skinChild)
end

-- Inputs --

---Skin an EditBox/SearchBox, strips box art (keeps the search icon) and adds a backdrop.
---@param editBox NUIEditBox
function BSKIN:HandleEditBox(editBox)
    if not editBox or editBox.NUISkinned then return end
    editBox.NUISkinned = true

    local searchIcon = editBox.searchIcon
    local iconAtlas = searchIcon and searchIcon.GetAtlas and searchIcon:GetAtlas()

    editBox:StripTextures()
    if editBox.NineSlice then editBox.NineSlice:StripTextures() end
    if searchIcon and iconAtlas then searchIcon:SetAtlas(iconAtlas) end

    self:CreatePanelBackdrop(editBox)
end

---@param colors SkinColors
function SkinnedCheckMixin:NUIUpdateSkinColors(colors)
    local accent = colors.accent
    local checked = self:GetCheckedTexture()

    if checked then checked:SetColorTexture(accent[1], accent[2], accent[3], 0.9) end
end

---Skin a CheckButton: box backdrop with an accent-colored fill when checked
---@param check CheckButton
function BSKIN:HandleCheckBox(check)
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

---Skin a modern dropdown button (WowStyle1DropdownTemplate/DropdownButton).
---Hides the box art via alpha (survives state-driven atlas swaps) and replaces
---the native arrow with ours, flipping it left/down as the menu opens/closes.
---@param dropdown Button
---@param template string? 'Transparent' halves the background alpha
function BSKIN:HandleDropdownButton(dropdown, template)
    if not dropdown or dropdown.NUISkinned then return end
    dropdown.NUISkinned = true

    dropdown.Arrow:StripTextures('Alpha')

    local sizeX, sizeY = 22, 22
    CreateArrowTexture(dropdown, 'left', sizeX, sizeY, 'RIGHT', dropdown, 'RIGHT', -2, 0)

    if dropdown.Background then dropdown.Background:SetAlpha(0) end
    self:CreatePanelBackdrop(dropdown, template)

    ---@cast dropdown Button & SkinnedButtonMixin
    Mixin(dropdown, SkinnedButtonMixin)

    local function UpdateText()
        dropdown:NUIUpdateState(dropdown.NUIMenuOpen or dropdown:IsMouseOver())
    end

    if dropdown.OnButtonStateChanged then
        hooksecurefunc(dropdown, 'OnButtonStateChanged', UpdateText)
    end

    dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, function(btn)
        btn.NUIMenuOpen = true
        btn:NUISetArrowDirection('down', true)
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
    local border = BSKIN:GetBorderColor()
    self:SetBorderColor(border[1], border[2], border[3], border[4])
end

---@param colors SkinColors
function SkinnedItemButtonMixin:NUIUpdateSkinColors(colors)
    local bg = colors.background
    self.NUISlotBg:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    if self.NUIQualityShown then return end
    local border = colors.border
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
function BSKIN:HandleItemButton(button)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    local icon = button.icon or button.Icon
    if icon then
        icon:SetPixelInside()
        icon:SetZoom()
    end

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then normal:SetAlpha(0) end

    button:StyleButton()

    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()

    -- Strip the slot ring/background art.
    -- Keep-set by reference, regions Blizzard drives per item state must survive (a blanket HideTextures would kill the icon)
    local keep = {}
    for _, region in pairs({
        icon, normal, highlight, pushed, checked,
        button.IconBorder, button.IconOverlay, button.IconOverlay2,
        button.searchOverlay, button.SearchOverlay, button.ignoreTexture,
        button.UpgradeIcon, button.NewItemTexture, button.LevelLinkLockTexture,
    }) do keep[region] = true end

    for _, region in pairs({ button:GetRegions() }) do
        if region:IsObjectType('Texture') and not keep[region] then
            region:SetTexture(nil)
            region:SetAtlas('')
            region:SetAlpha(0)
        end
    end

    local bg = self:GetBackgroundColor()
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

    button:AddBorders()

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
function BSKIN:HandleIconBorder(iconBorder, owner)
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

    -- Sync current state: Blizzard has usually already colored + shown the border
    -- for the equipped item before we hooked, so our hooks missed that first pass.
    -- IsShown is a plain bool and the vertex color isn't a secret, so this is safe.
    if iconBorder:IsShown() then
        owner:NUISetQualityColor(iconBorder:GetVertexColor())
    else
        owner:NUIResetQualityColor()
    end
end

-- Status bars --

---@param colors SkinColors
function SkinnedStatusBarMixin:NUIUpdateSkinColors(colors)
    if self.NUIKeepColor then return end
    local accent = colors.accent
    self:SetStatusBarColor(accent[1], accent[2], accent[3])
end

---Skin a StatusBar: strips art, applies our statusbar texture and a backdrop
---@param bar StatusBar
---@param keepColor boolean? Keep Blizzard's bar color (e.g. faction reputation colors)
function BSKIN:HandleStatusBar(bar, keepColor)
    if not bar or bar.NUISkinned then return end
    bar.NUISkinned = true

    bar:StripTextures()
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
function BSKIN:HandleNextPrevButton(button)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    local textures = {
        button.GetNormalTexture and button:GetNormalTexture(),
        button.GetPushedTexture and button:GetPushedTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(),
        button.GetDisabledTexture and button:GetDisabledTexture(),
    }
    for _, tex in ipairs(textures) do
        if tex then tex:SetDesaturated(true) end
    end
end

-- Collapse button mixins and styling

---@param collapsed boolean
function NUICollapseButtonMixin:DoCollapse(collapsed)
    if collapsed then
        self.__texture:SetAtlas(EXPAND_ATLAS, true)
    else
        self.__texture:SetAtlas(COLLAPSE_ATLAS, true)
    end
end

---@param texture string?
function NUICollapseButtonMixin:ResetTexture(texture)
    if self.settingTexture then return end
    self.settingTexture = true
    self:ClearNormalTexture()

    if texture and texture ~= '' then
        if strfind(texture, 'Plus') or strfind(texture, '[Cc]losed') then
            self:DoCollapse(true)
        elseif strfind(texture, 'Minus') or strfind(texture, '[Oo]pen') then
            self:DoCollapse(false)
        end
    end
    self.settingTexture = nil
end

---@param atlas string?
function NUICollapseButtonMixin:ResetAtlas(atlas)
    if self.settingTexture then return end
    self.settingTexture = true
    self:ClearNormalTexture()

    if atlas and atlas ~= '' then
        if strfind(atlas, 'Plus') or strfind(atlas, '[Cc]losed') or strfind(atlas, 'Expand') then
            self:DoCollapse(true)
        elseif strfind(atlas, 'Minus') or strfind(atlas, '[Oo]pen') or strfind(atlas, 'Collapse') then
            self:DoCollapse(false)
        end
    end
    self.settingTexture = nil
end

function NUICollapseButtonMixin:OnEnter()
    if self:IsEnabled() and self.__highlight then
        self.__highlight:Show()
    end
end

function NUICollapseButtonMixin:OnLeave()
    if self.__highlight then
        self.__highlight:Hide()
    end
end

---@param button Button
---@param isAtlas boolean?
function BSKIN:ReskinCollapse(button, isAtlas)
    if not button or button.styled then return end

    ---@cast button Button & NUICollapseButtonMixin
    Mixin(button, NUICollapseButtonMixin)

    button:ClearNormalTexture()
    button:ClearHighlightTexture()
    button:ClearPushedTexture()

    local container = CreateFrame('Frame', nil, button)
    container:SetAllPoints(button)
    container:SetFrameLevel(button:GetFrameLevel() + 1)
    button.bg = container

    local texture = container:CreateTexture(nil, 'OVERLAY', nil, 6)
    texture:SetPoint('CENTER')
    texture:SetAtlas(COLLAPSE_ATLAS, true)
    button.__texture = texture

    local highlight = container:CreateTexture(nil, 'OVERLAY', nil, 7)
    highlight:SetPoint('CENTER')
    highlight:SetAtlas(HIGHTLIGHT_ATLAS, true)
    highlight:Hide()
    button.__highlight = highlight

    button:HookScript('OnEnter', button.OnEnter)
    button:HookScript('OnLeave', button.OnLeave)


    if isAtlas then
        hooksecurefunc(button, 'SetNormalAtlas', button.ResetAtlas)
    else
        hooksecurefunc(button, 'SetNormalTexture', button.ResetTexture)
    end

    button.styled = true
end

-- Control buttons --

local CONTROL_BUTTONS = {
    { buttonName = 'zoomInButton',      rotation = 0,   size = 0.5, atlasName = PLUS_ATLAS },
    { buttonName = 'zoomOutButton',     rotation = 0,   size = 0.5, atlasName = MINUS_ATLAS },
    { buttonName = 'rotateLeftButton',  rotation = 0,   size = 0.8, atlasName = ARROW_ATLAS },
    { buttonName = 'rotateRightButton', rotation = 180, size = 0.8, atlasName = ARROW_ATLAS },
    { buttonName = 'resetButton',       rotation = 0,   size = 0.8, atlasName = RESET_ATLAS },
}

---@param frame Frame
local function StyleControlButtons(frame)
    local lastButton
    for k, v in pairs(CONTROL_BUTTONS) do
        local button = frame[v.buttonName]
        if button then
            if not button.IsSkinned then
                BSKIN:HandleButton(button)
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
                if button.Icon then BSKIN:HandleIcon(button.Icon) end
            end

            if button:IsShown() then
                button:ClearAllPoints()

                if lastButton then
                    button:SetPixelPoint('LEFT', lastButton, 'RIGHT', 1, 0)
                else
                    button:SetPixelPoint('LEFT', 6, 0)
                end

                lastButton = button
            end
        end
    end
end

---@param frame Frame
function BSKIN:HandleControlButtons(frame)
    if not frame.NUISkinned then
        frame.NUISkinned = true
        hooksecurefunc(frame, 'UpdateLayout', StyleControlButtons)
    end
end
