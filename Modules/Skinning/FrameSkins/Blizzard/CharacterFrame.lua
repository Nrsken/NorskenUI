---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local PaperDollFrame_UpdateSidebarTabs = PaperDollFrame_UpdateSidebarTabs
local PaperDollItemSlotButton_Update = PaperDollItemSlotButton_Update
local PaperDollFrame_UpdateStats = PaperDollFrame_UpdateStats
local hooksecurefunc = hooksecurefunc
local ipairs, pairs = ipairs, pairs
local CreateColor = CreateColor
local CreateFrame = CreateFrame
local Mixin = Mixin
local unpack = unpack
local select = select
local next = next
local _G = _G

local GetSpecialization = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo

local SLOT_NAMES = {
    'Head', 'Neck', 'Shoulder', 'Back', 'Chest', 'Shirt', 'Tabard',
    'Wrist', 'Hands', 'Waist', 'Legs', 'Feet', 'Finger0', 'Finger1', 'Trinket0',
    'Trinket1', 'MainHand', 'SecondaryHand',
}

local FLYOUT_POS = {
    [0xFFFFFFFF] = true, -- PLACEINBAGS
    [0xFFFFFFFE] = true, -- IGNORESLOT
    [0xFFFFFFFD] = true, -- UNIGNORESLOT
}

-- FileID of the '+ New Set' (Character-Plus) icon, this row never gets an icon border.
local NEW_SET_ICON = 514607

local AMOUNT_BUTTON_GAP = 2
local LONG_ARROW_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\right-arrow.png'
local LONG_ARROW_SIZE = 32

local OLD_ARROW_ATLASES = { ['Options_ListExpand_Right'] = true, ['Options_ListExpand_Right_Expanded'] = true, }
local ARROW_INSET = 6
local CHECK_INSET = 4

---@param texture Texture
---@param atlas string?
local function UpdateCollapseArrow(texture, atlas)
    if atlas and not OLD_ARROW_ATLASES[atlas] then return end

    local header = texture:GetParent()
    if not header.IsCollapsed then return end

    ---@cast texture NUICollapseArrow
    if not texture.NUIAnchored then
        texture.NUIAnchored = true

        texture:ClearAllPoints()
        texture:NUISetPixelPoint('RIGHT', header, 'RIGHT', -ARROW_INSET, 0)
    end

    Skinning:SetPlusMinusGlyph(texture, header:IsCollapsed())
end

---@param button Button
local function UpdateToggleCollapseButton(button)
    local header = button.GetHeader and button:GetHeader()
    if not header or not header.IsCollapsed then return end

    Skinning:ReskinPlusMinus(button)
    ---@cast button Button & NUIPlusMinusButtonMixin
    button:NUISetCollapsed(header:IsCollapsed())
end

-- The Character tab is left out, its name text belongs to the CharacterPanel module.
local ACCENT_TITLE_SUBFRAMES = { ReputationFrame = true, TokenFrame = true }

---@class NUITitleAccentMixin
local TitleAccentMixin = {}

function TitleAccentMixin:NUIUpdateSkinColors()
    ---@cast self FontString
    local frame = CharacterFrame --[[@as NUICharacterFrame]]
    if not ACCENT_TITLE_SUBFRAMES[frame.activeSubframe] then return end

    self:SetTextColor(Skinning:GetAccentColor())
end

---@param S SkinningModule
local function SkinTitle(S)
    local container = CharacterFrame.TitleContainer
    local title = container and container.TitleText
    if not title then return end

    Mixin(title, TitleAccentMixin)
    ---@cast title FontString & NUITitleAccentMixin
    S:RegisterSkinned(title)

    -- UpdateTitle repaints per tab, after the subframe's OnShow.
    hooksecurefunc(CharacterFrame, 'UpdateTitle', function() title:NUIUpdateSkinColors() end)
    title:NUIUpdateSkinColors()
end

---@class NUIArrowAccentMixin
local ArrowAccentMixin = {}

function ArrowAccentMixin:NUIUpdateSkinColors()
    ---@cast self Texture
    self:SetVertexColor(Skinning:GetAccentColor())
end

---@class NUICheckLabelAccentMixin
local CheckLabelAccentMixin = {}

function CheckLabelAccentMixin:NUIUpdateSkinColors()
    ---@cast self FontString & NUICheckLabelAccentMixin
    local check = self:GetParent() --[[@as CheckButton]]
    if self.NUIPainting or not check:IsEnabled() then return end

    -- Blizzard's own color carries the disabled state, so only the live one is ours to take over.
    self.NUIPainting = true
    self:SetTextColor(Skinning:GetAccentColor())
    self.NUIPainting = false
end

---@class NUIHeaderAccentMixin
local HeaderAccentMixin = {}

function HeaderAccentMixin:NUIUpdateSkinColors()
    ---@cast self NUIListHeader
    local color = CreateColor(Skinning:GetAccentColor())
    self:SetTitleColor(false, color)
    self:SetTitleColor(true, color)
    self:CheckHighlightTitle(nil)
end

---Header-row treatment shared by the Reputation and Token lists. Safe on non-header rows.
---Both branches guard on the fields that mark a header.
---@param row NUIListRow
local function SkinHeaderRow(row)
    if row.Right and row.HighlightRight then
        row:NUIStripTextures('Keyed')
        Skinning:CreatePanelBackdrop(row, nil, nil, true)

        -- ListHeaderVisualMixin re-asserts its own title color on hover, Reputation headers don't.
        if row.SetTitleColor then
            Mixin(row, HeaderAccentMixin)
            ---@cast row NUIListRow & NUIHeaderAccentMixin
            Skinning:RegisterSkinned(row)
            row:NUIUpdateSkinColors()
        else
            Skinning:HandleAccentFont(row.Name)
        end

        UpdateCollapseArrow(row.Right)
        UpdateCollapseArrow(row.HighlightRight)

        hooksecurefunc(row.Right, 'SetAtlas', UpdateCollapseArrow)
        hooksecurefunc(row.HighlightRight, 'SetAtlas', UpdateCollapseArrow)
    end

    local toggle = row.ToggleCollapseButton
    if toggle and toggle.RefreshIcon then
        hooksecurefunc(toggle, 'RefreshIcon', UpdateToggleCollapseButton)
        UpdateToggleCollapseButton(toggle)
    end
end

---@param row NUIListRow
local function SkinTitleRow(row)
    if row.NUISkinned then return end
    row.NUISkinned = true

    row:DisableDrawLayer('BACKGROUND')
end

---@param row NUIListRow
local function SkinEquipSetRow(row)
    if not row.icon then return end

    if not row.NUISkinned then
        row.NUISkinned = true
        local db = Skinning.db

        for _, key in ipairs({ 'BgTop', 'BgMiddle', 'BgBottom' }) do
            local tex = row[key]
            if tex then
                tex:SetTexture(nil)
                tex:SetAlpha(0)
            end
        end

        -- Build the icon border once and keep it on the row. Rows are pooled and
        -- recycled between gear sets and the '+ New Set' button, so its visibility
        -- is toggled per update below instead of baked in at skin time.
        local frame = CreateFrame('Frame', nil, row)
        frame:NUISetPixelPoint('TOPLEFT', row.icon, 'TOPLEFT', 0, 0)
        frame:NUISetPixelPoint('BOTTOMRIGHT', row.icon, 'BOTTOMRIGHT', 0, 0)
        frame:NUIAddBorders()
        frame:SetBorderLayer('ARTWORK', 7)
        frame:SetBorderParent(row.icon:GetParent())
        row.NUIIconBorder = frame

        for i = 1, row:GetNumRegions() do
            local region = select(i, row:GetRegions())
            if region and region:GetObjectType() == 'FontString' then
                region:SetFontStyle(db, db.FontMediumSize)
            end
        end

        row.icon:NUISetZoom()

        if row.HighlightBar then
            row.HighlightBar:SetColorTexture(unpack(NRSKNUI.Colors.highlightColor))
            row.HighlightBar:SetDrawLayer('BACKGROUND')
        end
        if row.SelectedBar then
            row.SelectedBar:SetColorTexture(unpack(NRSKNUI.Colors.selectedColor))
            row.SelectedBar:SetDrawLayer('BACKGROUND')
        end
    end

    -- Border on the spec icons, but never on the new set '+' icon.
    row.NUIIconBorder:SetBorderShown(row.icon:GetTexture() ~= NEW_SET_ICON)
end

---@param row NUIListRow
local function SkinReputationRow(row)
    if row.NUISkinned then return end
    row.NUISkinned = true

    SkinHeaderRow(row)
    local content = row.Content or row
    if content.Background then content.Background:SetAlpha(0) end
    local bar = content.ReputationBar
    if bar and bar.SetStatusBarTexture then
        Skinning:HandleStatusBar(bar, true)
    end
end

---@param row NUIListRow
local function SkinTokenRow(row)
    if row.NUISkinned then return end
    row.NUISkinned = true

    SkinHeaderRow(row)
    local content = row.Content or row
    if content.Background then content.Background:SetAlpha(0) end
    local icon = content.CurrencyIcon or content.Icon or content.icon
    if icon then Skinning:HandleIcon(icon) end
end

---@param row NUIListRow
local function SkinTransferLogRow(row)
    if row.NUISkinned then return end
    row.NUISkinned = true

    if row.CurrencyIcon then Skinning:HandleIcon(row.CurrencyIcon) end
end

local customPortrait
local function UpdateCustomPortrait()
    local index = GetSpecialization()
    local icon
    if index and index > 0 then
        icon = select(4, GetSpecializationInfo(index))
    end

    customPortrait.icon:SetTexture(icon)
end

local function SetupCustomPortrait()
    -- The sidebar tab hook that builds this fires on every paperdoll update
    if customPortrait then return end

    customPortrait = CreateFrame('Frame', nil, PaperDollFrame)
    customPortrait:NUISetPixelSize(45, 45)
    customPortrait:NUISetPixelPoint('TOPLEFT', PaperDollFrame, 'TOPLEFT', 7, -7)
    customPortrait:NUIAddBorders()

    customPortrait.icon = customPortrait:CreateTexture(nil, 'ARTWORK')
    customPortrait.icon:SetAllPoints(customPortrait)
    customPortrait.icon:NUISetZoom()

    customPortrait:RegisterUnitEvent('PLAYER_SPECIALIZATION_CHANGED', 'player')
    customPortrait:SetScript('OnEvent', UpdateCustomPortrait)

    UpdateCustomPortrait()
end

-- Current search text, lowercased. Shared between the edit box handler and the data provider filter hook below.
local titleSearchText = ''
local function FilterTitleProvider()
    if titleSearchText == '' then return end

    local scrollBox = PaperDollFrame.TitleManagerPane.ScrollBox
    local dataProvider = scrollBox and scrollBox:GetDataProvider()
    if not dataProvider then return end

    dataProvider:RemoveAllByPredicate(function(elementData)
        local title = elementData.playerTitle
        return title.id ~= -1 and not title.name:lower():find(titleSearchText, 1, true)
    end)
end

-- Title search feature.
local function TitleSearch(S)
    local scrollBox = PaperDollFrame.TitleManagerPane.ScrollBox
    if not scrollBox then return end

    local scrollParent = scrollBox:GetParent()

    scrollBox:NUISetPixelPoint('TOPLEFT', scrollParent, 'TOPLEFT', 4, -24)
    scrollBox:NUISetPixelPoint('BOTTOMRIGHT', scrollParent, 'BOTTOMRIGHT', 4, 1)

    local color = Skinning.db.General.WidgetBackgroundColor

    local frame = CreateFrame('Frame', nil, scrollParent)
    frame:NUISetPixelSize(scrollBox:GetWidth(), 24)
    frame:NUISetPixelPoint('TOPLEFT', scrollParent, 'TOPLEFT', 4, 0)
    frame:NUICreateBackdrop()
    frame:SetBackgroundColor(color[1], color[2], color[3], color[4])

    local db = Skinning.db
    local r, g, b, a = Skinning:GetAccentColor()

    local editBox = CreateFrame('EditBox', nil, frame)
    editBox:SetPoint('TOPLEFT', frame, 'TOPLEFT', 6, -4)
    editBox:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -6, 4)
    editBox:SetFontStyle(db, db.FontEditBoxSize)
    editBox:SetTextColor(r, g, b, a)
    editBox:SetAutoFocus(false)
    frame.editBox = editBox

    -- Placeholder shown whenever the box is empty.
    local hint = editBox:CreateFontString(nil, 'ARTWORK')
    hint:SetFontStyle(db, db.FontEditBoxSize)
    hint:SetTextColor(0.6, 0.6, 0.6, 0.7)
    hint:SetPoint('LEFT', editBox, 'LEFT', 0, 0)
    hint:SetText('Search Titles...')

    -- Small helper to reset the search.
    local function ClearSearch()
        editBox:ClearFocus()
        editBox:SetText('')
        titleSearchText = ''
        hint:SetShown(true)
        PaperDollTitlesPane_Update()
    end

    editBox:SetScript('OnEscapePressed', ClearSearch)
    editBox:SetScript('OnEditFocusGained', function(self) editBox:SetTextColor(r, g, b, a) end)
    editBox:SetScript('OnEditFocusLost', function(self) editBox:SetTextColor(0.6, 0.6, 0.6, 0.7) end)
    editBox:SetScript('OnTextChanged', function(self)
        local text = self:GetText() or ''
        hint:SetShown(text == '')
        titleSearchText = text:lower()
        -- Re-run Blizzard's populate, our hook re-applies the filter afterwards.
        PaperDollTitlesPane_UpdateScrollBox()
    end)

    hooksecurefunc('PaperDollTitlesPane_UpdateScrollBox', FilterTitleProvider)
    hooksecurefunc('PlayerTitleButton_OnClick', ClearSearch)
end

local function SkinShell(S)
    -- Handle the main portrait frame
    S:HandlePortraitFrame(CharacterFrame)
    SkinTitle(S)

    -- Handle textures on the right side of the characterframe.
    -- For example, backdrop for the item level, Attributes and Enhancements rows.
    local insetRight = CharacterFrame.InsetRight or _G.CharacterFrameInsetRight
    if insetRight then
        insetRight:NUIStripTextures('Keyed')
        if insetRight.NineSlice then insetRight.NineSlice:NUIStripTextures('Keyed') end
        if insetRight.Bg then insetRight.Bg:SetAlpha(0) end
    end
end

-- Skin the item slots and their popout buttons for the equipment manager.
local function SkinSlots(S)
    for _, name in ipairs(SLOT_NAMES) do
        local slot = _G['Character' .. name .. 'Slot']
        local pb = slot.popoutButton

        if slot.verticalFlyout then
            S:HandleArrowButton(pb, 'down')
            pb.NUIClosedDir, pb.NUIOpenDir = 'down', 'up'
            pb:NUISetPixelPoint('TOP', slot, 'BOTTOM', 0, 3)
        else
            S:HandleArrowButton(pb, 'right')
            pb.NUIClosedDir, pb.NUIOpenDir = 'right', 'left'
            pb:NUISetPixelPoint('LEFT', slot, 'RIGHT', -3, 0)
        end

        if slot then S:HandleItemButton(slot) end
    end
end

-- Hooks for the flyout arrows, so that they can be re-positioned and re-skinned when the flyout opens/closes.
local flyoutOpenButton
local function HookFlyoutArrows()
    local flyout = _G.EquipmentFlyoutFrame
    if not flyout or flyout.NUIArrowHooked then return end
    flyout.NUIArrowHooked = true

    flyout:HookScript('OnShow', function(f)
        flyoutOpenButton = f.button and f.button.popoutButton
        if flyoutOpenButton then
            flyoutOpenButton:NUISetArrowDirection(flyoutOpenButton.NUIOpenDir, true)
        end
    end)
    flyout:HookScript('OnHide', function()
        if flyoutOpenButton then
            flyoutOpenButton:NUISetArrowDirection(flyoutOpenButton.NUIClosedDir, false)
        end
        flyoutOpenButton = nil
    end)
end

local function SkinModelScene(S)
    local scene = CharacterModelScene
    if not scene then return end

    scene:NUIStripTextures('Keyed')

    -- Hide the model scene backdrop that has the racial specific texture.
    for _, corner in ipairs({ 'TopLeft', 'TopRight', 'BotLeft', 'BotRight' }) do
        local bg = _G['CharacterModelFrameBackground' .. corner]
        if bg then bg:SetAlpha(0) end
    end
    local overlay = _G.CharacterModelFrameBackgroundOverlay
    if overlay then overlay:Hide() end

    local controlFrame = scene.ControlFrame
    S:HandleControlButtons(controlFrame)
end

local GRAD_BRIGHT = CreateColor(0.6, 0.6, 0.6, 0.25)
local GRAD_FADE = CreateColor(0.6, 0.6, 0.6, 0)

---Center-out horizontal gradient
---@param frame NUIStatFrame
local function AddStatGradients(frame)
    local height = frame:GetHeight()

    local left = frame:CreateTexture(nil, 'BORDER')
    left:NUISetPixelSize(80, height)
    left:NUISetPixelPoint('LEFT', frame, 'CENTER')
    left:SetTexture(NRSKNUI.WhiteTexture)
    left:SetGradient('HORIZONTAL', GRAD_BRIGHT, GRAD_FADE)
    frame.NUILeftGrad = left

    local right = frame:CreateTexture(nil, 'BORDER')
    right:NUISetPixelSize(80, height)
    right:NUISetPixelPoint('RIGHT', frame, 'CENTER')
    right:SetTexture(NRSKNUI.WhiteTexture)
    right:SetGradient('HORIZONTAL', GRAD_FADE, GRAD_BRIGHT)
    frame.NUIRightGrad = right
end

local function UpdateStatFrames()
    local pane = CharacterStatsPane --[[@as NUIStatsPane]]
    if not pane or not pane.statsFramePool then return end

    for frame in pane.statsFramePool:EnumerateActive() do
        if not frame.NUILeftGrad then
            frame.Background:SetAlpha(0)
            AddStatGradients(frame)
        end
        local shown = frame.Background:IsShown()
        frame.NUILeftGrad:SetShown(shown)
        frame.NUIRightGrad:SetShown(shown)
    end
end

local function SkinStatsPane(S)
    local pane = CharacterStatsPane
    if not pane then return end

    pane:NUIStripTextures('Keyed')

    for _, key in ipairs({ 'ItemLevelCategory', 'AttributesCategory', 'EnhancementsCategory' }) do
        local category = pane[key]
        if category then
            category:NUIStripTextures('Keyed')
            -- Slim centered header plate, repositioning our own backdrop is fine
            local backdrop = S:CreatePanelBackdrop(category, nil, nil, true)
            if backdrop then
                backdrop:ClearAllPoints()
                backdrop:NUISetPixelPoint('CENTER')
                backdrop:NUISetPixelSize(150, 18)
            end
            local title = category.Title
            if title then
                S:RegisterSkinned(title)
            end
        end
    end

    local ilvl = pane.ItemLevelFrame
    if ilvl then
        if ilvl.Background then ilvl.Background:SetAlpha(0) end
        AddStatGradients(ilvl --[[@as NUIStatFrame]])
    end

    if PaperDollFrame_UpdateStats then
        hooksecurefunc('PaperDollFrame_UpdateStats', UpdateStatFrames)
    end
    UpdateStatFrames()
end

---Re-assert the 0.16-0.86 crop Blizzard keeps re-setting on the first tab's
---texture sheet. The 0.16001 sentinel stops the hook from recursing.
---@param tex Texture
---@param x1 number
local function ReassertTabTexCoord(tex, x1)
    if x1 ~= 0.16001 then
        tex:SetTexCoord(0.16001, 0.86, 0.16, 0.86)
    end
end

-- Skins the 3 topright buttons, 'Character stats', 'Titles' and 'Equipment Manager'.
local function SkinSidebarTabs(S)
    local i = 1
    local tab = _G['PaperDollSidebarTab' .. i]
    while tab do
        if not tab.NUISkinned then
            tab.NUISkinned = true

            local backdrop = S:CreatePanelBackdrop(tab, nil, nil, true)
            if backdrop then
                -- Adjust backdrop size slightly so that the borders can be seen.
                backdrop:ClearAllPoints()
                backdrop:NUISetPixelPoint('TOPLEFT', tab, 'TOPLEFT', -2, 2)
                backdrop:NUISetPixelPoint('BOTTOMRIGHT', tab, 'BOTTOMRIGHT', 2, -2)
            end

            if tab.Icon then tab.Icon:SetAllPoints(tab) end
            if tab.Highlight then
                tab.Highlight:SetColorTexture(unpack(NRSKNUI.Colors.highlightColor))
                tab.Highlight:SetAllPoints(tab)
            end
            if tab.Hider then
                tab.Hider:SetColorTexture(unpack(NRSKNUI.Colors.blackBgColor))
                tab.Hider:SetAllPoints(tab)
            end
            if tab.TabBg then tab.TabBg:SetAlpha(0) end

            if i == 1 then -- the stats icon shares a texture sheet and needs cropping
                for _, region in pairs({ tab:GetRegions() }) do
                    if region:IsObjectType('Texture') then
                        region:SetTexCoord(0.16, 0.86, 0.16, 0.86)
                        hooksecurefunc(region, 'SetTexCoord', ReassertTabTexCoord)
                    end
                end
            end
        end

        i = i + 1
        tab = _G['PaperDollSidebarTab' .. i]
    end

    _G['PaperDollSidebarTabs']:NUIStripTextures('Keyed')
end

local function SkinSidebarPane(S, pane, skinRow)
    if not pane then return end
    if pane.ScrollBar then S:HandleTrimScrollBar(pane.ScrollBar) end
    if pane.ScrollBox then S:HookScrollBoxChildren(pane.ScrollBox, skinRow) end
end

local function SkinGearManagerPopup(S)
    local popup = _G.GearManagerPopupFrame
    if not popup then return end

    popup:HookScript('OnShow', function(frame)
        ---@cast frame NUIGearManagerPopup
        if frame.NUISkinned then return end
        frame.NUISkinned = true

        frame:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(frame)
        S:HandleCloseButton(frame.CloseButton, frame)

        local borderBox = frame.BorderBox
        if borderBox then
            borderBox:NUIStripTextures('Keyed')
            S:HandleEditBox(borderBox.IconSelectorEditBox)
            S:HandleButton(borderBox.OkayButton)
            S:HandleButton(borderBox.CancelButton)
        end
        if frame.IconSelector then
            S:HandleTrimScrollBar(frame.IconSelector.ScrollBar)
        end
    end)
end

local function SkinEquipmentManager(S)
    local PaperDollFrameEquipSet = _G.PaperDollFrameEquipSet
    local PaperDollFrameSaveSet = _G.PaperDollFrameSaveSet

    S:HandleButton(PaperDollFrameEquipSet)
    S:HandleButton(PaperDollFrameSaveSet)
    SkinGearManagerPopup(S)
end

local function SkinReputation(S)
    local rep = _G.ReputationFrame
    if not rep then return end

    rep:NUIStripTextures('Keyed')
    if rep.ScrollBar then S:HandleTrimScrollBar(rep.ScrollBar) end
    if rep.ScrollBox then S:HookScrollBoxChildren(rep.ScrollBox, SkinReputationRow) end
    if rep.filterDropdown then S:HandleDropdownButton(rep.filterDropdown) end

    local detail = _G.ReputationFrame.ReputationDetailFrame
    if detail then
        detail:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(detail)
        S:HandleCloseButton(detail.CloseButton, detail)
        S:HandleCheckBox(detail.AtWarCheckbox, CHECK_INSET)
        S:HandleCheckBox(detail.MakeInactiveCheckbox, CHECK_INSET)
        S:HandleCheckBox(detail.WatchFactionCheckbox, CHECK_INSET)
        S:HandleButton(detail.ViewRenownButton)
        S:HandleTrimScrollBar(detail.ScrollingDescriptionScrollBar)
        S:HandleAccentText(detail.Title)

        -- Refresh runs from a function captured at load, so the repaint is caught on the label itself.
        local labels = { detail.AtWarCheckbox.Label, detail.MakeInactiveCheckbox.Label, detail.WatchFactionCheckbox.Label }
        for _, label in ipairs(labels) do
            Mixin(label, CheckLabelAccentMixin)
            ---@cast label FontString & NUICheckLabelAccentMixin
            S:RegisterSkinned(label)

            hooksecurefunc(label, 'SetTextColor', label.NUIUpdateSkinColors)
            label:NUIUpdateSkinColors()
        end
    end
end

local function UpdateItemButtons(S)
    local flyout = _G.EquipmentFlyoutFrame --[[@as NUIEquipmentFlyout]]
    local flyoutButtonFrame = flyout.buttonFrame

    flyoutButtonFrame:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(flyoutButtonFrame)

    local w, h = flyoutButtonFrame:GetSize()
    flyoutButtonFrame:NUISetPixelSize(w + 3, h)

    local flyoutButtons = flyout.buttons

    for _, button in next, flyoutButtons do
        S:HandleItemButton(button)

        -- Pooled buttons reused as a special action slot inherit no quality color,
        -- so re-assert the default border in case they last showed a quality item.
        if FLYOUT_POS[button.location] then
            button:NUIResetQualityColor()
        end
    end
end

local function EquipmentUpdateNavigation(S)
    local flyoutNavigationFrame = _G.EquipmentFlyoutFrame.NavigationFrame
    if not flyoutNavigationFrame then return end

    local flyoutButtons = _G.EquipmentFlyoutFrameButtons

    flyoutNavigationFrame:ClearAllPoints()
    flyoutNavigationFrame:NUISetPixelPoint('TOPLEFT', flyoutButtons, 'BOTTOMLEFT', 0, 0)
    flyoutNavigationFrame:NUISetPixelPoint('TOPRIGHT', flyoutButtons, 'BOTTOMRIGHT', 0, 0)

    flyoutNavigationFrame:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(flyoutNavigationFrame)
end

local function SkinEquipmentFlyout(S)
    local flyout = _G.EquipmentFlyoutFrame
    if not flyout then return end

    local equipmentFlyoutHighlight = _G.EquipmentFlyoutFrameHighlight
    local equipmentFlyoutFrame = _G.EquipmentFlyoutFrameButtons
    local equipmentFlyoutBg = _G.EquipmentFlyoutFrameButtons.bg1
    local prevButton = _G.EquipmentFlyoutFrame.NavigationFrame.PrevButton
    local nextButton = _G.EquipmentFlyoutFrame.NavigationFrame.NextButton

    equipmentFlyoutHighlight:NUIStripTextures('Keyed')
    equipmentFlyoutBg:SetAlpha(0)
    equipmentFlyoutFrame:DisableDrawLayer('ARTWORK')

    S:HandleNextPrevButton(prevButton)
    S:HandleNextPrevButton(nextButton)

    hooksecurefunc('EquipmentFlyout_SetBackgroundTexture', function() EquipmentUpdateNavigation(S) end)
    hooksecurefunc('EquipmentFlyout_UpdateItems', function() UpdateItemButtons(S) end)
end

Skinning:RegisterSkin('Blizzard_UIPanels_Game', 'CharacterFrame', function(S)
    if not _G.CharacterFrame then return end

    SkinShell(S)
    S:HandleTabRow('CharacterFrameTab', CharacterFrame)
    SkinSlots(S)
    HookFlyoutArrows()
    SkinModelScene(S)
    SkinStatsPane(S)
    SkinSidebarTabs(S)
    TitleSearch(S)

    -- Tabs are created lazily
    if PaperDollFrame_UpdateSidebarTabs then
        hooksecurefunc('PaperDollFrame_UpdateSidebarTabs', function()
            SkinSidebarTabs(S)
            SetupCustomPortrait()
        end)
    end

    SkinSidebarPane(S, PaperDollFrame and PaperDollFrame.TitleManagerPane, SkinTitleRow)
    SkinSidebarPane(S, PaperDollFrame and PaperDollFrame.EquipmentManagerPane, SkinEquipSetRow)
    SkinEquipmentManager(S)
    SkinReputation(S)
    SkinEquipmentFlyout(S)

    -- Blizzard re-sets the slot highlight on every update
    if PaperDollItemSlotButton_Update then
        hooksecurefunc('PaperDollItemSlotButton_Update', function(slot)
            local highlight = slot:GetHighlightTexture()
            if highlight then
                highlight:SetColorTexture(unpack(NRSKNUI.Colors.highlightColor))
            end
        end)
    end
end)

-- The currency tab lives in the LoadOnDemand Blizzard_TokenUI addon
Skinning:RegisterSkin('Blizzard_TokenUI', 'CharacterFrame', function(S)
    local token = _G.TokenFrame
    if not token then return end

    if token.ScrollBar then S:HandleTrimScrollBar(token.ScrollBar) end
    if token.ScrollBox then S:HookScrollBoxChildren(token.ScrollBox, SkinTokenRow) end
    if token.filterDropdown then S:HandleDropdownButton(token.filterDropdown) end

    local logToggle = token.CurrencyTransferLogToggleButton
    if logToggle then
        if logToggle.NormalTexture then logToggle.NormalTexture:SetDesaturated(true) end
        if logToggle.PushedTexture then logToggle.PushedTexture:SetDesaturated(true) end
    end

    -- Skins the popup window when you click on a currency.
    local popup = _G.TokenFramePopup
    if popup then
        popup:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(popup)
        S:HandleCheckBox(popup.InactiveCheckbox, CHECK_INSET)
        S:HandleCheckBox(popup.BackpackCheckbox, CHECK_INSET)
        S:HandleButton(popup.CurrencyTransferToggleButton)
        S:HandleCloseButton(popup['$parent.CloseButton'], popup)
        S:HandleAccentText(popup.Title)
    end

    -- Skins the warbound transfer log window.
    local log = _G.CurrencyTransferLog
    if log then
        S:HandlePortraitFrame(log)
        S:HandleAccentText(log.TitleContainer.TitleText)
        if log.ScrollBar then S:HandleTrimScrollBar(log.ScrollBar) end
        if log.ScrollBox then S:HookScrollBoxChildren(log.ScrollBox, SkinTransferLogRow) end
    end

    -- Skins the warbound currency transfer window.
    local menu = _G.CurrencyTransferMenu
    if menu then
        menu:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(menu)
        S:HandleCloseButton(menu.CloseButton, menu)
        Skinning:HandleAccentFont(menu.TitleContainer.TitleText)

        local content = menu.Content
        if content then
            if content.SourceSelector then
                S:HandleDropdownButton(content.SourceSelector.Dropdown)
                S:HandleAccentText(content.SourceSelector.SourceLabel)
                S:HandleAccentText(content.SourceSelector.PlayerName)

                local arrow = content.SourceSelector.Dropdown.LongArrow
                arrow:SetTexture(LONG_ARROW_TEXTURE)
                arrow:SetTexCoord(0, 1, 0, 1)
                arrow:NUISetPixelSize(LONG_ARROW_SIZE, LONG_ARROW_SIZE)
                arrow:NUISetPixelSnap()

                Mixin(arrow, ArrowAccentMixin)
                ---@cast arrow Texture & NUIArrowAccentMixin
                S:RegisterSkinned(arrow)
                arrow:NUIUpdateSkinColors()
            end
            if content.AmountSelector then
                local amount = content.AmountSelector
                local box = amount.InputBox
                local button = amount.MaxQuantityButton

                S:HandleButton(button)
                S:HandleEditBox(box)
                S:HandleAccentText(amount.TransferAmountLabel)

                local top, bottom = box.NUIArtTop or 0, box.NUIArtBottom or 0
                button:NUISetPixelHeight(box:GetHeight() + top - bottom)
                button:ClearAllPoints()
                button:NUISetPixelPoint('RIGHT', box, 'LEFT', (box.NUIArtLeft or 0) - AMOUNT_BUTTON_GAP, (top + bottom) / 2)
            end
            S:HandleButton(content.ConfirmButton)
            S:HandleButton(content.CancelButton)
            if content.SourceBalancePreview then
                S:HandleAccentText(content.SourceBalancePreview.Label)
                S:HandleIcon(content.SourceBalancePreview.BalanceInfo.CurrencyIcon)
            end
            if content.PlayerBalancePreview then
                S:HandleAccentText(content.PlayerBalancePreview.Label)
                S:HandleIcon(content.PlayerBalancePreview.BalanceInfo.CurrencyIcon)
            end
        end
    end
end)
