---@class NRSKNUI
local NRSKNUI = select(2, ...)

local BSKIN = NRSKNUI.BlizzSkin

local _G = _G
local hooksecurefunc = hooksecurefunc
local ipairs, pairs = ipairs, pairs
local select = select
local CreateColor = CreateColor
local GetSpecializationInfoByID = GetSpecializationInfoByID
local CreateFrame = CreateFrame
local unpack = unpack
local next = next

local PaperDollFrame_UpdateStats = PaperDollFrame_UpdateStats
local PaperDollItemSlotButton_Update = PaperDollItemSlotButton_Update
local PaperDollFrame_UpdateSidebarTabs = PaperDollFrame_UpdateSidebarTabs

--[[
Note to self with taint rules for this file:
CharacterFrame is UIPanel-managed and it's slot buttons feed secure equip paths.
Never SetPoint/SetParent/Show/Hide the frame, its Insets or slot buttons textures, alpha and our own backdrop children only.
All fields we add are NUI-prefixed.
Hook bodies must stay visual-only since they can fire in combat.
]]

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

local EXPAND_BUTTON_ATLAS = 'UI-QuestTrackerButton-Secondary-Expand'
local COLLAPSE_BUTTON_ATLAS = 'UI-QuestTrackerButton-Secondary-Collapse'
local EXPAND_ARROW_ATLAS = 'Soulbinds_Collection_CategoryHeader_Expand'
local COLLAPSE_ARROW_ATLAS = 'Soulbinds_Collection_CategoryHeader_Collapse'
local OLD_ARROW_ATLASES = {
    ['Options_ListExpand_Right'] = true,
    ['Options_ListExpand_Right_Expanded'] = true,
}

---@param texture Texture
---@param atlas string?
local function UpdateCollapseArrow(texture, atlas)
    if atlas and not OLD_ARROW_ATLASES[atlas] then return end

    local header = texture:GetParent()
    if not header.IsCollapsed then return end

    texture:SetAtlas((header:IsCollapsed() and EXPAND_ARROW_ATLAS) or COLLAPSE_ARROW_ATLAS)
end

---@param button Button
local function UpdateToggleCollapseButton(button)
    local header = button.GetHeader and button:GetHeader()
    if not header or not header.IsCollapsed then return end

    local atlas = (header:IsCollapsed() and EXPAND_BUTTON_ATLAS) or COLLAPSE_BUTTON_ATLAS
    button:SetNormalAtlas(atlas)
    button:SetPushedAtlas(atlas)
end

---Header-row treatment shared by the Reputation and Token lists. Safe on non-header rows.
---Both branches guard on the fields that mark a header.
---@param row NUIListRow
local function SkinHeaderRow(row)
    if row.Right and row.HighlightRight then
        row:StripTextures('Keyed')
        BSKIN:CreatePanelBackdrop(row, 'Transparent')

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
    if row.NUISkinned or not row.icon then return end
    row.NUISkinned = true

    for _, key in ipairs({ 'BgTop', 'BgMiddle', 'BgBottom' }) do
        local tex = row[key]
        if tex then
            tex:SetTexture(nil)
            tex:SetAlpha(0)
        end
    end

    -- Add border to the spec icons, but not the new set + texture icon.
    if row.icon:GetTexture() ~= 514607 then
        local frame = CreateFrame("Frame", nil, row)
        frame:SetPixelPoint('TOPLEFT', row.icon, 'TOPLEFT', 0, 0)
        frame:SetPixelPoint('BOTTOMRIGHT', row.icon, 'BOTTOMRIGHT', 0, 0)
        NRSKNUI:AddBorders(frame, nil, row.icon:GetParent(), nil, "ARTWORK", 7)
    end

    for i = 1, row:GetNumRegions() do
        local db = BSKIN:GetDB()
        local region = select(i, row:GetRegions())
        if region and region:GetObjectType() == 'FontString' then
            region:SetFontStyle(db, db.FontMediumSize)
        end
    end

    row.icon:SetZoom()

    if row.HighlightBar then
        row.HighlightBar:SetColorTexture(unpack(NRSKNUI.HighlightColor))
        row.HighlightBar:SetDrawLayer('BACKGROUND')
    end
    if row.SelectedBar then
        row.SelectedBar:SetColorTexture(unpack(NRSKNUI.SelectedColor))
        row.SelectedBar:SetDrawLayer('BACKGROUND')
    end
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
        BSKIN:HandleStatusBar(bar, true)
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
    if icon then BSKIN:HandleIcon(icon) end
end

---@param row NUIListRow
local function SkinTransferLogRow(row)
    if row.NUISkinned then return end
    row.NUISkinned = true

    if row.CurrencyIcon then BSKIN:HandleIcon(row.CurrencyIcon) end
end

local function SetupCustomPortrait()
    local icon
    if NRSKNUI.MySpec.id ~= nil then
        icon = select(4, GetSpecializationInfoByID(NRSKNUI.MySpec.id))
    end

    local frame = CreateFrame('Frame', nil, PaperDollFrame)
    frame:SetPixelSize(45, 45)
    frame:SetPixelPoint('TOPLEFT', PaperDollFrame, 'TOPLEFT', 7, -7)
    NRSKNUI:AddBorders(frame)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints(frame)
    frame.icon:SetTexture(icon)
    frame.icon:SetZoom()
end

local function SkinShell(S)
    -- Handle the main portrait frame
    S:HandlePortraitFrame(CharacterFrame)

    -- Handle textures on the right side of the characterframe.
    -- For example, backdrop for the item level, Attributes and Enhancements rows.
    local insetRight = CharacterFrame.InsetRight or _G.CharacterFrameInsetRight
    if insetRight then
        insetRight:StripTextures('Keyed')
        if insetRight.NineSlice then insetRight.NineSlice:StripTextures('Keyed') end
        if insetRight.Bg then insetRight.Bg:SetAlpha(0) end
    end
end

-- Skin and re-position the bottom tabs.
local function SkinTabs(S)
    local i = 1
    local tab, prev = _G['CharacterFrameTab' .. i], nil
    while tab do
        S:HandleTab(tab)

        tab:ClearAllPoints()
        if prev then
            tab:SetPixelPoint('TOPLEFT', prev, 'TOPRIGHT', -1, 0)
        else
            tab:SetPixelPoint('TOPLEFT', CharacterFrame, 'BOTTOMLEFT', 0, 1)
        end
        prev = tab

        i = i + 1
        tab = _G['CharacterFrameTab' .. i]
    end
end

local function SkinSlots(S)
    for _, name in ipairs(SLOT_NAMES) do
        local slot = _G['Character' .. name .. 'Slot']
        if slot then S:HandleItemButton(slot) end
    end
end

local function SkinModelScene(S)
    local scene = CharacterModelScene
    if not scene then return end

    scene:StripTextures('Keyed')

    -- Hide the model scene backdrop that has the racial specific texture.
    for _, corner in ipairs({ 'TopLeft', 'TopRight', 'BotLeft', 'BotRight' }) do
        local bg = _G['CharacterModelFrameBackground' .. corner]
        if bg then bg:SetAlpha(0) end
    end
    local overlay = _G.CharacterModelFrameBackgroundOverlay
    if overlay then overlay:Hide() end

    local controlFrame = _G.CharacterModelScene.ControlFrame
    S:HandleControlButtons(controlFrame)
end

local GRAD_BRIGHT = CreateColor(0.6, 0.6, 0.6, 0.25)
local GRAD_FADE = CreateColor(0.6, 0.6, 0.6, 0)

---Center-out horizontal gradient
---@param frame NUIStatFrame
local function AddStatGradients(frame)
    local height = frame:GetHeight()

    local left = frame:CreateTexture(nil, 'BORDER')
    left:SetPixelSize(80, height)
    left:SetPixelPoint('LEFT', frame, 'CENTER')
    left:SetTexture(NRSKNUI.WhiteTexture)
    left:SetGradient('HORIZONTAL', GRAD_BRIGHT, GRAD_FADE)
    frame.NUILeftGrad = left

    local right = frame:CreateTexture(nil, 'BORDER')
    right:SetPixelSize(80, height)
    right:SetPixelPoint('RIGHT', frame, 'CENTER')
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

    pane:StripTextures('Keyed')

    for _, key in ipairs({ 'ItemLevelCategory', 'AttributesCategory', 'EnhancementsCategory' }) do
        local category = pane[key]
        if category then
            category:StripTextures('Keyed')
            -- Slim centered header plate, repositioning our own backdrop is fine
            local backdrop = S:CreatePanelBackdrop(category, 'Transparent')
            if backdrop then
                backdrop:ClearAllPoints()
                backdrop:SetPixelPoint('CENTER')
                backdrop:SetPixelSize(150, 18)
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

-- Skins the 3 topright buttons, "Character stats", "Titles" and "Equipment Manager".
local function SkinSidebarTabs(S)
    local i = 1
    local tab = _G['PaperDollSidebarTab' .. i]
    while tab do
        if not tab.NUISkinned then
            tab.NUISkinned = true

            local backdrop = S:CreatePanelBackdrop(tab)
            if backdrop then
                -- Adjust backdrop size slightly so that the borders can be seen.
                backdrop:ClearAllPoints()
                backdrop:SetPixelPoint('TOPLEFT', tab, 'TOPLEFT', -2, 2)
                backdrop:SetPixelPoint('BOTTOMRIGHT', tab, 'BOTTOMRIGHT', 2, -2)
            end

            if tab.Icon then tab.Icon:SetAllPoints(tab) end
            if tab.Highlight then
                tab.Highlight:SetColorTexture(unpack(NRSKNUI.HighlightColor))
                tab.Highlight:SetAllPoints(tab)
            end
            if tab.Hider then
                tab.Hider:SetColorTexture(unpack(NRSKNUI.BlackBgColor))
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

    _G['PaperDollSidebarTabs']:StripTextures('Keyed')
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

        frame:StripTextures('Keyed')
        S:CreatePanelBackdrop(frame)
        S:HandleCloseButton(frame.CloseButton, frame)

        local borderBox = frame.BorderBox
        if borderBox then
            borderBox:StripTextures('Keyed')
            S:HandleEditBox(borderBox.IconSelectorEditBox)
            S:HandleButton(borderBox.OkayButton, 'Transparent')
            S:HandleButton(borderBox.CancelButton, 'Transparent')
        end
        if frame.IconSelector then
            S:HandleTrimScrollBar(frame.IconSelector.ScrollBar)
        end
    end)
end

local function SkinEquipmentManager(S)
    local PaperDollFrameEquipSet = _G.PaperDollFrameEquipSet
    local PaperDollFrameSaveSet = _G.PaperDollFrameSaveSet

    S:HandleButton(PaperDollFrameEquipSet, 'Transparent')
    S:HandleButton(PaperDollFrameSaveSet, 'Transparent')
    SkinGearManagerPopup(S)
end

local function SkinReputation(S)
    local rep = _G.ReputationFrame
    if not rep then return end

    rep:StripTextures('Keyed')
    if rep.ScrollBar then S:HandleTrimScrollBar(rep.ScrollBar) end
    if rep.ScrollBox then S:HookScrollBoxChildren(rep.ScrollBox, SkinReputationRow) end
    if rep.filterDropdown then S:HandleDropdownButton(rep.filterDropdown) end

    local detail = _G.ReputationFrame.ReputationDetailFrame
    if detail then
        detail:StripTextures('Keyed')
        S:CreatePanelBackdrop(detail)
        S:HandleCloseButton(detail.CloseButton, detail)
        S:HandleCheckBox(detail.AtWarCheckbox)
        S:HandleCheckBox(detail.MakeInactiveCheckbox)
        S:HandleCheckBox(detail.WatchFactionCheckbox)
        S:HandleButton(detail.ViewRenownButton, 'Transparent')
        S:HandleTrimScrollBar(detail.ScrollingDescriptionScrollBar)
    end
end

local function UpdateItemButtons(S)
    local flyoutButtonFrame = _G.EquipmentFlyoutFrame.buttonFrame

    flyoutButtonFrame:StripTextures('Keyed')
    S:CreatePanelBackdrop(flyoutButtonFrame)

    local w, h = flyoutButtonFrame:GetSize()
    flyoutButtonFrame:SetPixelSize(w + 3, h)

    local flyoutButtons = _G.EquipmentFlyoutFrame.buttons

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
    flyoutNavigationFrame:SetPixelPoint('TOPLEFT', flyoutButtons, 'BOTTOMLEFT', 0, 0)
    flyoutNavigationFrame:SetPixelPoint('TOPRIGHT', flyoutButtons, 'BOTTOMRIGHT', 0, 0)

    flyoutNavigationFrame:StripTextures('Keyed')
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

    equipmentFlyoutHighlight:StripTextures('Keyed')
    equipmentFlyoutBg:SetAlpha(0)
    equipmentFlyoutFrame:DisableDrawLayer('ARTWORK')

    S:HandleNextPrevButton(prevButton)
    S:HandleNextPrevButton(nextButton)

    hooksecurefunc('EquipmentFlyout_SetBackgroundTexture', function() EquipmentUpdateNavigation(S) end)
    hooksecurefunc('EquipmentFlyout_UpdateItems', function() UpdateItemButtons(S) end)
end

BSKIN:RegisterSkin('Blizzard_UIPanels_Game', 'CharacterFrame', function(S)
    if not _G.CharacterFrame then return end

    SkinShell(S)
    SkinTabs(S)
    SkinSlots(S)
    SkinModelScene(S)
    SkinStatsPane(S)
    SkinSidebarTabs(S)

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
            if highlight then highlight:SetColorTexture(unpack(NRSKNUI.HighlightColor)) end
        end)
    end
end)

-- The currency tab lives in the LoadOnDemand Blizzard_TokenUI addon
BSKIN:RegisterSkin('Blizzard_TokenUI', 'CharacterFrame', function(S)
    local token = _G.TokenFrame
    if not token then return end

    -- Deeper changes to this scrollbar taint currency transfers
    -- HandleTrimScrollBar's alpha-only thumb treatment is the safe ceiling
    if token.ScrollBar then S:HandleTrimScrollBar(token.ScrollBar) end
    if token.ScrollBox then S:HookScrollBoxChildren(token.ScrollBox, SkinTokenRow) end
    if token.filterDropdown then S:HandleDropdownButton(token.filterDropdown) end

    -- HandleButton here taints currency transfers, just desaturate the button
    local logToggle = token.CurrencyTransferLogToggleButton
    if logToggle then
        if logToggle.NormalTexture then logToggle.NormalTexture:SetDesaturated(true) end
        if logToggle.PushedTexture then logToggle.PushedTexture:SetDesaturated(true) end
    end

    -- Skins the popup window when you click on a currency.
    local popup = _G.TokenFramePopup
    if popup then
        popup:StripTextures('Keyed')
        S:CreatePanelBackdrop(popup)
        S:HandleCheckBox(popup.InactiveCheckbox)
        S:HandleCheckBox(popup.BackpackCheckbox)
        S:HandleButton(popup.CurrencyTransferToggleButton, 'Transparent')
        S:HandleCloseButton(popup['$parent.CloseButton'], popup)
    end

    -- Skins the warbound transfer log window.
    local log = _G.CurrencyTransferLog
    if log then
        S:HandlePortraitFrame(log)
        if log.ScrollBar then S:HandleTrimScrollBar(log.ScrollBar) end
        if log.ScrollBox then S:HookScrollBoxChildren(log.ScrollBox, SkinTransferLogRow) end
    end

    -- Skins the warbound currency transfer window.
    local menu = _G.CurrencyTransferMenu
    if menu then
        menu:StripTextures('Keyed')
        S:CreatePanelBackdrop(menu)
        S:HandleCloseButton(menu.CloseButton, menu)

        local content = menu.Content
        if content then
            if content.SourceSelector then S:HandleDropdownButton(content.SourceSelector.Dropdown) end
            if content.AmountSelector then
                S:HandleButton(content.AmountSelector.MaxQuantityButton, 'Transparent')
                S:HandleEditBox(content.AmountSelector.InputBox)
            end
            S:HandleButton(content.ConfirmButton, 'Transparent')
            S:HandleButton(content.CancelButton, 'Transparent')
            if content.SourceBalancePreview and content.SourceBalancePreview.BalanceInfo then
                S:HandleIcon(content.SourceBalancePreview.BalanceInfo.CurrencyIcon)
            end
            if content.PlayerBalancePreview and content.PlayerBalancePreview.BalanceInfo then
                S:HandleIcon(content.PlayerBalancePreview.BalanceInfo.CurrencyIcon)
            end
        end
    end
end)
