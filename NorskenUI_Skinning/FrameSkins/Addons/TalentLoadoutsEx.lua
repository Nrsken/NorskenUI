---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local Mixin = Mixin
local ipairs = ipairs
local select = select
local _G = _G

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

local ADDON_NAME = 'TalentLoadoutsEx'

local CHECK_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\check.png'

local ROW_HIGHLIGHT_ALPHA = 0.25
local ROW_SELECTED_ALPHA = 0.35

local PANEL_INSET_X = -1
local PANEL_OVERHANG_Y = 0

local POPUP_GAP = 0
local POPUP_PADDING = 6
local TALENT_TEXT_HEIGHT = 44

local PANEL_BUTTON_KEYS = {
    'ImportButton', 'ExportButton', 'PresetButton',
    'LoadButton', 'SaveButton', 'EditButton',
    'DeleteButton', 'UpButton', 'DownButton',
}

local skinned = false

---@class TLEAccentTextureMixin
---@field NUIAlpha number
local AccentTextureMixin = {}

function AccentTextureMixin:NUIUpdateSkinColors()
    ---@cast self Texture & TLEAccentTextureMixin
    local r, g, b = Skinning:GetAccentColor()
    self:SetColorTexture(r, g, b, self.NUIAlpha)
end

---Repaint one of the addon's own state bars as a flat accent fill.
---@param texture Texture?
---@param alpha number
local function SkinAccentTexture(texture, alpha)
    if not texture then return end
    texture.NUIAlpha = alpha

    -- The XML bars ship their own alpha and an ADD blend, which would compound with ours.
    texture:SetAlpha(1)
    texture:SetBlendMode('BLEND')

    ---@cast texture Texture & TLEAccentTextureMixin
    Mixin(texture, AccentTextureMixin)
    texture:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(texture)
end

---@class TLEAccentTintMixin
local AccentTintMixin = {}

function AccentTintMixin:NUIUpdateSkinColors()
    ---@cast self Texture
    self:SetVertexColor(Skinning:GetAccentColor())
end

-- Loadout list --

---The template re-applies its own art and the expanded flag on every show.
---@param toggle Button & NUIPlusMinusButtonMixin & { isExpanded: boolean? }
local function SyncToggle(toggle)
    toggle:NUISetCollapsed(not toggle.isExpanded)
end

---Config rows only; groups and the add rows keep the addon's own blue and green.
---@param button TLEListButton
local function RecolorRowText(button)
    if button.addDataType or not (button.data and button.data.text) then return end

    button.Text:SetTextColor(Skinning:GetAccentColor())
end

---@param button TLEListButton
local function SkinListButton(button)
    if not button.NUISkinned then
        button.NUISkinned = true

        -- Set in XML and never re-shown; a blanket strip would take the icon and stripes too.
        button.BgTop:Hide()
        button.BgBottom:Hide()
        button.BgMiddle:Hide()

        SkinAccentTexture(button.SelectedBar, ROW_SELECTED_ALPHA)
        SkinAccentTexture(button:GetHighlightTexture(), ROW_HIGHLIGHT_ALPHA)

        local check = button.Check
        check:SetTexture(CHECK_TEXTURE)
        check:NUISetPixelSnap()
        ---@cast check Texture & TLEAccentTintMixin
        Mixin(check, AccentTintMixin)
        check:NUIUpdateSkinColors()
        Skinning:RegisterSkinned(check)

        local toggle = button.ToggleButton
        Skinning:ReskinPlusMinus(toggle)
        toggle:HookScript('OnShow', SyncToggle)
        SyncToggle(toggle)

        -- A hero talent row calls SetAtlas, which resets our zoom rather than cropping the atlas.
        Skinning:HandleIcon(button.Icon, true)

        button.NUIUpdateSkinColors = RecolorRowText
        Skinning:RegisterSkinned(button)
    end

    -- Rows are pooled and InitListButton repaints the label on every pass.
    RecolorRowText(button)
end

-- Popups --

---@param S SkinningModule
---@param frame Frame? A DialogBorderTemplate window
local function SkinDialog(S, frame)
    if not frame then return end

    frame:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(frame)
end

---@param S SkinningModule
---@param popup TLEEditPopupFrame?
local function SkinEditPopup(S, popup)
    if not popup then return end

    popup:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(popup)
    S:HandleCloseButton(popup.CloseButton, popup)

    local borderBox = popup.BorderBox
    if borderBox then
        borderBox:NUIStripTextures('Keyed')
        S:HandleEditBox(borderBox.IconSelectorEditBox)
        S:HandleButton(borderBox.OkayButton, 'Transparent')
        S:HandleButton(borderBox.CancelButton, 'Transparent')

        S:HandleDropdownButton(borderBox.IconTypeDropdown)

        local selectedArea = borderBox.SelectedIconArea
        if selectedArea then
            local selectedButton = selectedArea.SelectedIconButton
            if selectedButton then
                -- Filled in long after this pass, so the icon has to survive the strip untouched.
                selectedButton.Icon.NUINoStrip = true
                selectedButton:NUIStripTextures()
                S:HandleIcon(selectedButton.Icon, true)
            end

            -- Every label but the description, which the addon re-fonts on each icon pick.
            local selectedText = selectedArea.SelectedIconText
            local description = selectedText and selectedText.SelectedIconDescription

            for _, host in ipairs({ selectedArea, selectedText }) do
                for _, region in ipairs({ host:GetRegions() }) do
                    if region:IsObjectType('FontString') and region ~= description then
                        S:HandleAccentText(region --[[@as FontString]])
                    end
                end
            end
        end
    end

    if popup.IconSelector then
        S:HandleTrimScrollBar(popup.IconSelector.ScrollBar)
    end

    -- Only present with LargerMacroIconSelection installed.
    S:HandleEditBox(popup.SearchBox)

    local talentText = popup.TalentTextFrame
    if talentText then
        SkinDialog(S, talentText)
        talentText:ClearAllPoints()
        talentText:NUISetPixelHeight(TALENT_TEXT_HEIGHT)
        talentText:NUISetPixelPoint('BOTTOMLEFT', popup, 'TOPLEFT', 0, POPUP_GAP)
        talentText:NUISetPixelPoint('BOTTOMRIGHT', popup, 'TOPRIGHT', 0, POPUP_GAP)

        local main = talentText.Main
        main:NUIStripTextures('Keyed')
        main:ClearAllPoints()
        main:NUISetPixelPoint('TOPLEFT', talentText, 'TOPLEFT', POPUP_PADDING, -POPUP_PADDING)
        main:NUISetPixelPoint('BOTTOMRIGHT', talentText, 'BOTTOMRIGHT', -POPUP_PADDING, POPUP_PADDING)

        local editBox = main.EditBox
        editBox:ClearAllPoints()
        editBox:SetAllPoints(main)
        S:HandleEditBox(editBox)
    end

    local iconList = popup.IconListFrame
    if not iconList then return end

    SkinDialog(S, iconList)
    iconList:ClearAllPoints()
    iconList:NUISetPixelPoint('TOPLEFT', popup, 'BOTTOMLEFT', 0, -POPUP_GAP)
    iconList:NUISetPixelPoint('TOPRIGHT', popup, 'BOTTOMRIGHT', 0, -POPUP_GAP)

    for _, child in ipairs({ iconList:GetChildren() }) do
        ---@cast child TLEIconButton
        local texture = child.texture

        if texture then
            -- Atlased at creation, before this pass, so zooming would crop the art.
            S:HandleIcon(texture, true, texture:GetAtlas() ~= nil)
            SkinAccentTexture(child:GetHighlightTexture(), ROW_HIGHLIGHT_ALPHA)
        end
    end
end

---@param S SkinningModule
---@param popup TLETextPopupFrame?
local function SkinTextPopup(S, popup)
    if not popup then return end

    SkinDialog(S, popup)
    popup.Header:NUIStripTextures()
    S:HandleAccentText(popup.Header.Text)

    local main = popup.Main
    main:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(main, 'Transparent')

    local scrollFrame = main.ScrollFrame
    -- The Common-Input-Border slices sit on the scroll frame's own BACKGROUND layer.
    scrollFrame:NUIStripTextures()

    -- Widget palette rather than panel, so the export box reads as an input like the other fields.
    S:CreatePanelBackdrop(scrollFrame, nil, nil, true)

    -- UIPanelScrollFrameTemplate still carries the legacy Slider bar, not a WowTrimScrollBar.
    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        if scrollBar:GetObjectType() == 'Slider' then
            S:HandleScrollBar(scrollBar --[[@as NUILegacyScrollBar]])
        else
            S:HandleTrimScrollBar(scrollBar)
        end
    end

    S:HandleButton(main.ImportButton)
    S:HandleButton(main.CancelButton)
    S:HandleButton(main.CloseButton)
end

---@param S SkinningModule
---@param popup TLEPresetPopupFrame?
local function SkinPresetPopup(S, popup)
    if not popup then return end

    SkinDialog(S, popup)
    popup.Header:NUIStripTextures()
    S:HandleAccentText(popup.Header.Text)

    local main = popup.Main
    main:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(main, 'Transparent')
    S:HandleCheckBox(main.CombineCheckButton)

    for _, presetFrame in ipairs(main.PresetAddons) do
        S:HandleAccentText(presetFrame.Title)

        for _, checkButton in ipairs(presetFrame.CategoryCheckButtons) do
            S:HandleCheckBox(checkButton)
        end
    end
end

-- Panel --

---@param S SkinningModule
---@param talentsFrame PlayerSpellsFrame_TalentsFrame|TLETalentsFrame
local function SkinInspectImportButton(S, talentsFrame)
    local copyButton = talentsFrame.InspectCopyButton
    if not copyButton then return end

    -- The addon creates it anonymously, so its anchor is the only thing identifying it.
    for _, child in ipairs({ talentsFrame:GetChildren() }) do
        if child ~= copyButton and child:IsObjectType('Button') and select(2, child:GetPoint(1)) == copyButton then
            S:HandleButton(child --[[@as Button]])
        end
    end
end

local function SkinTalentLoadoutsEx()
    if skinned then return end

    local frame = _G.TalentLoadoutExMainFrame
    if not frame then return end
    skinned = true

    local S = Skinning

    frame:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(frame)
    S:HandleAccentText(frame.Title)

    for _, key in ipairs(PANEL_BUTTON_KEYS) do
        S:HandleButton(frame[key])
    end

    local pvpFrame = frame.PvpFrame
    pvpFrame:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(pvpFrame, 'Transparent')
    S:HandleCheckBox(pvpFrame.CheckButton)
    pvpFrame.CheckButton:SetSize(28, 28)

    S:HandleTrimScrollBar(frame.ScrollBar)
    S:HookScrollBoxChildren(frame.ScrollBox, SkinListButton)

    SkinEditPopup(S, frame.EditPopupFrame)
    SkinTextPopup(S, frame.TextPopupFrame)
    SkinPresetPopup(S, frame.PresetPopupFrame)

    SkinInspectImportButton(S, _G.PlayerSpellsFrame.TalentsFrame)

    NRSKNUI:RunWhenSafe(function()
        local parent = frame:GetParent()
        frame:ClearAllPoints()
        frame:NUISetPixelPoint('TOPLEFT', parent, 'TOPRIGHT', PANEL_INSET_X, PANEL_OVERHANG_Y)
        frame:NUISetPixelPoint('BOTTOMLEFT', parent, 'BOTTOMRIGHT', PANEL_INSET_X, -PANEL_OVERHANG_Y)
    end)
end

-- The addon builds the panel from its own Blizzard_PlayerSpells handler, which may run after this.
Skinning:RegisterSkin('Blizzard_PlayerSpells', ADDON_NAME, function()
    if not IsAddOnLoaded(ADDON_NAME) then return end

    local parent = _G.PlayerSpellsFrame
    if not parent then return end

    parent:HookScript('OnShow', SkinTalentLoadoutsEx)
    SkinTalentLoadoutsEx()
end)
