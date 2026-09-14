---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local getmetatable = getmetatable
local setmetatable = setmetatable
local strlower = strlower
local rawget = rawget
local rawset = rawset
local ipairs = ipairs
local Mixin = Mixin
local next = next
local gsub = gsub

local LibStub = LibStub
local UIParent = UIParent

-- Older copies name their internals differently and would break rather than skin.
local MIN_GUI_MINOR, MIN_DIALOG_MINOR = 36, 76
local LIB_VERSION_SUFFIX = '%-[%d%.]+$'

-- Gold color styling stuff.
local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0
local GOLD_CODES = { fed000 = true, ffd100 = true, ffd200 = true, ffff00 = true, }
local COLOR_ESCAPE = '|c(%x%x)(%x%x%x%x%x%x)'
local AccentHex = 'FFD200' -- gsub's replacement function takes no arguments of its own

local EDITBOX_LABEL_Y = -2

local TAB_SHOULDER = 10
local TAB_TEXT_INSET = 10
local TAB_TEXT_Y = 0
local TREE_ROW_HEIGHT = 18
local TREE_TOGGLE_SIZE = 12
local TREE_TOGGLE_COLLAPSED = {
    [130838] = true,
    [130836] = true,
    [130821] = false,
    [130820] = false,
}

---@type table<string, fun(widget: table)>
local Skins = {}

-- Keyed by the type AceGUI was asked for, a decorator widget keeps its base type and never re-registers.
---@type table<string, fun(widget: table)>
local Decorations = {}

local AccentNormal = Skinning:GetAccentFont(GameFontNormal)
local AccentSmall = Skinning:GetAccentFont(GameFontNormalSmall)
local AccentLarge = Skinning:GetAccentFont(GameFontNormalLarge)
local ACCENT_FONTS = { AccentNormal, AccentSmall, AccentLarge }

---@class AccentLabelMixin
local AccentLabelMixin = {}

function AccentLabelMixin:NUIUpdateSkinColors()
    ---@cast self FontString
    local r, g, b = Skinning:GetAccentColor()
    self:SetTextColor(r, g, b)
end

---A widget that repaints its own label gold on every SetDisabled(false) overrides whatever font
---object the label inherits from, so color that FontString directly and follow each toggle back.
---@param widget table
---@param label FontString
local function SkinAccentLabel(widget, label)
    ---@cast label FontString & AccentLabelMixin
    Mixin(label, AccentLabelMixin)
    label:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(label)

    hooksecurefunc(widget, 'SetDisabled', function(_, disabled)
        if not disabled then
            label:NUIUpdateSkinColors()
        end
    end)
end

-- AceGUI detaches and reattaches every widget frame on AddChild, which re-levels our backdrop
-- above the frame's own regions, so anything that must stay visible rides on the backdrop.
---@param button Button
local function SkinButton(button)
    Skinning:HandleButton(button)
    button:SetNormalFontObject(AccentNormal)

    local text = button.GetFontString and button:GetFontString()
    if text and button.NUIBackdrop then
        text:SetParent(button.NUIBackdrop)
    end
end

---@param alpha string
---@param rgb string
---@return string?
local function ReplaceGold(alpha, rgb)
    if GOLD_CODES[strlower(rgb)] then
        return '|c' .. alpha .. AccentHex
    end
end

---@param label FontString
local function RecolorEscapes(label)
    local text = label.NUIRawText
    if not text then return end

    AccentHex = NRSKNUI:RGBAToHex(Skinning:GetAccentColor())
    label:SetText((gsub(text, COLOR_ESCAPE, ReplaceGold)))
end

---The swap is one-way and the widget is pooled, so keep the raw string from every setter call.
---@param widget table
---@param method string
---@param label FontString
local function SkinEscapes(widget, method, label)
    label.NUIUpdateSkinColors = RecolorEscapes

    hooksecurefunc(widget, method, function(_, text)
        label.NUIRawText = text
        RecolorEscapes(label)
    end)

    Skinning:RegisterSkinned(label)
end

-- Check Box --

---@class CheckBoxMixin
---@field NUICheck Texture
---@field NUIHighlight Texture
local CheckBoxMixin = {}

function CheckBoxMixin:NUIOnEnter()
    self.NUIHighlight:Show()
end

function CheckBoxMixin:NUIOnLeave()
    self.NUIHighlight:Hide()
end

function CheckBoxMixin:NUIUpdateSkinColors()
    ---@cast self Button & CheckBoxMixin
    Skinning:UpdateHighlightColor(self)

    local r, g, b = Skinning:GetAccentColor()
    self.NUICheck:SetColorTexture(r, g, b, 0.9)
end

Skins.CheckBox = function(widget)
    local frame, check, checkbg, highlight = widget.frame, widget.check, widget.checkbg, widget.highlight

    local backdrop = Skinning:CreatePanelBackdrop(frame, nil, nil, true)
    backdrop:ClearAllPoints()
    backdrop:SetPoint('TOPLEFT', checkbg, 'TOPLEFT', 3, -3)
    backdrop:SetPoint('BOTTOMRIGHT', checkbg, 'BOTTOMRIGHT', -3, 3)

    -- SetType re-applies Blizzard's art every time the widget comes back out of the pool.
    checkbg:SetTexture()
    checkbg.SetTexture = NRSKNUI.NOP
    highlight.SetTexture = NRSKNUI.NOP
    check.SetTexture = NRSKNUI.NOP

    check:SetParent(backdrop)
    check:ClearAllPoints()
    check:SetPoint('TOPLEFT', backdrop, 'TOPLEFT', 2, -2)
    check:SetPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -2, 2)

    -- A HIGHLIGHT texture only auto-shows for its own frame's mouse and the backdrop has none.
    highlight:SetParent(backdrop)
    highlight:SetDrawLayer('OVERLAY')
    highlight:Hide()
    highlight:ClearAllPoints()
    highlight:SetPoint('TOPLEFT', backdrop, 'TOPLEFT', 2, -2)
    highlight:SetPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -2, 2)

    -- Over the fill rather than replacing it, matching the Kaji toggles' knob.
    local glyph = backdrop:CreateTexture(nil, 'OVERLAY', nil, 2)
    glyph:SetTexture(NRSKNUI.Theme.checkTexture)
    glyph:SetPoint('TOPLEFT', backdrop, 'TOPLEFT', 2, -2)
    glyph:SetPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -2, 2)
    glyph:SetShown(check:IsShown())

    hooksecurefunc(check, 'Show', function() glyph:Show() end)
    hooksecurefunc(check, 'Hide', function() glyph:Hide() end)

    frame.NUICheck = check
    frame.NUIHighlight = highlight

    ---@cast frame Button & CheckBoxMixin
    Mixin(frame, CheckBoxMixin)
    frame:NUIUpdateSkinColors()

    frame:HookScript('OnEnter', frame.NUIOnEnter)
    frame:HookScript('OnLeave', frame.NUIOnLeave)

    SkinEscapes(widget, 'SetLabel', widget.text)
    Skinning:RegisterSkinned(frame)
end

-- Edit Box --

Skins.EditBox = function(widget)
    local editbox, button = widget.editbox, widget.button

    Skinning:HandleEditBox(editbox)

    SkinButton(button)
    button:ClearAllPoints()
    button:SetPoint('RIGHT', editbox, 'RIGHT', -2, 0)

    -- The template left-aligns the label to the frame, which is short of where the text starts.
    -- Reading the inset back keeps the two in step rather than repeating the floor here.
    local label = widget.label
    local textInset = editbox:GetTextInsets()
    label:ClearAllPoints()
    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', textInset, EDITBOX_LABEL_Y)
    label:SetPoint('BOTTOMRIGHT', editbox, 'TOPRIGHT', 0, EDITBOX_LABEL_Y)

    SkinAccentLabel(widget, label)
end

Skins.MultiLineEditBox = function(widget)
    local scrollBG = widget.scrollBG

    SkinButton(widget.button)
    Skinning:HandleScrollBar(widget.scrollBar)

    scrollBG:SetBackdrop(nil)
    Skinning:CreatePanelBackdrop(scrollBG, nil, nil, true)

    SkinAccentLabel(widget, widget.label)
end

-- Button --

Skins.Button = function(widget)
    SkinButton(widget.frame)
end

-- Slider --

Skins.Slider = function(widget)
    local editbox = widget.editbox

    Skinning:HandleSlider(widget.slider)

    editbox:SetBackdrop(nil)
    Skinning:HandleEditBox(editbox)

    SkinAccentLabel(widget, widget.label)
end

-- Keybinding --

Skins.Keybinding = function(widget)
    local msgframe = widget.msgframe

    SkinButton(widget.button)

    msgframe:SetBackdrop(nil)
    Skinning:CreatePanelBackdrop(msgframe)
    msgframe.msg:SetFontObject(AccentNormal)

    -- SetKey swaps the button back to Blizzard's gold every time the binding is cleared.
    hooksecurefunc(widget, 'SetKey', function(self, key)
        if (key or '') == '' then
            self.button:SetNormalFontObject(AccentNormal)
        end
    end)
end

-- Color Picker --

Skins.ColorPicker = function(widget)
    local frame, swatch = widget.frame, widget.colorSwatch

    local backdrop = Skinning:CreatePanelBackdrop(frame, nil, nil, true)
    backdrop:ClearAllPoints()
    backdrop:SetPoint('LEFT', frame, 'LEFT', 0, 0)
    backdrop:SetSize(24, 16)

    -- SetColor only tints, so a plain white fill takes the widget's color unchanged.
    swatch:SetParent(backdrop)
    swatch:SetDrawLayer('OVERLAY')
    swatch:SetColorTexture(1, 1, 1)
    swatch:ClearAllPoints()
    swatch:SetPoint('TOPLEFT', backdrop, 'TOPLEFT', 2, -2)
    swatch:SetPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -2, 2)

    swatch.background:SetColorTexture(0, 0, 0, 0)

    local checkers = swatch.checkers
    checkers:SetParent(backdrop)
    checkers:SetDrawLayer('ARTWORK')
    checkers:ClearAllPoints()
    checkers:SetAllPoints(swatch)
end

-- Icon --

---@class IconMixin
local IconMixin = {}

function IconMixin:NUIUpdateSkinColors()
    ---@cast self Button & IconMixin
    Skinning:UpdateHighlightColor(self)
end

Skins.Icon = function(widget)
    local frame = widget.frame

    -- The highlight is a bare HIGHLIGHT-layer texture the widget keeps no reference to.
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType('Texture') and region:GetDrawLayer() == 'HIGHLIGHT' then
            frame.NUIHighlight = region
        end
    end

    ---@cast frame Button & IconMixin
    Mixin(frame, IconMixin)
    frame:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(frame)
end

-- Heading --

---@class HeadingMixin
---@field NUILeft Texture
---@field NUIRight Texture
local HeadingMixin = {}

function HeadingMixin:NUIUpdateSkinColors()
    local border = Skinning.db.General.BorderColor

    self.NUILeft:SetColorTexture(border[1], border[2], border[3], border[4])
    self.NUIRight:SetColorTexture(border[1], border[2], border[3], border[4])
end

Skins.Heading = function(widget)
    local frame, left, right = widget.frame, widget.left, widget.right

    left:SetHeight(1)
    right:SetHeight(1)
    widget.label:SetFontObject(AccentNormal)

    frame.NUILeft = left
    frame.NUIRight = right

    ---@cast frame Frame & HeadingMixin
    Mixin(frame, HeadingMixin)
    frame:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(frame)
end

-- Label --

Skins.Label = function(widget)
    SkinEscapes(widget, 'SetText', widget.label)
end

Skins.Dropdown = function(widget)
    local dropdown, button, text, label = widget.dropdown, widget.button, widget.text, widget.label

    dropdown:NUIStripTextures()

    local backdrop = Skinning:CreatePanelBackdrop(dropdown, nil, nil, true)
    backdrop:ClearAllPoints()
    backdrop:SetPoint('TOPLEFT', dropdown, 'TOPLEFT', 15, -2)
    backdrop:SetPoint('BOTTOMRIGHT', dropdown, 'BOTTOMRIGHT', -21, 0)

    Skinning:HandleNextPrevButton(button, 'left')
    button:SetParent(backdrop)
    button:ClearAllPoints()
    button:SetPoint('TOPRIGHT', backdrop, 'TOPRIGHT', -2, -2)
    button:SetPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -2, 2)
    button:SetWidth(20)

    text:SetParent(backdrop)
    text:ClearAllPoints()
    text:SetJustifyH('RIGHT')
    text:SetPoint('LEFT', backdrop, 'LEFT', 3, 0)
    text:SetPoint('RIGHT', button, 'LEFT', -3, 0)

    label:ClearAllPoints()
    label:SetPoint('BOTTOMLEFT', backdrop, 'TOPLEFT', 2, 2)

    SkinAccentLabel(widget, label)
end

-- Dropdown --

-- BigWigs registers its own searchable Dropdown clone, identical down to the widget field names.
Skins.BigWigsSharedDropdown = Skins.Dropdown

---@class SurfaceMixin
local SurfaceMixin = {}

function SurfaceMixin:NUIUpdateSkinColors()
    ---@cast self Frame & PublicBackdropMixin
    local bg = Skinning.db.General.BackgroundColor
    local border = Skinning.db.General.BorderColor

    self:SetBackgroundColor(bg[1], bg[2], bg[3], bg[4])
    self:SetBorderColor(border[1], border[2], border[3], border[4])
end

---BigWigs parents a search box onto the shared pullout only after AceGUI has handed the widget
---over, so the first open is the earliest point it can be found.
---@param widget table
local function SkinPulloutChildren(widget)
    for _, child in ipairs({ widget.frame:GetChildren() }) do
        if child:IsObjectType('EditBox') then
            Skinning:HandleEditBox(child)
        end
    end
end

Skins['Dropdown-Pullout'] = function(widget)
    local frame = widget.frame
    frame:SetBackdrop(nil)

    -- Open() re-stratas frame:GetChildren(), so the backdrop goes on the frame itself to stay out of that walk.
    frame:NUICreateBackdrop()

    ---@cast frame Frame & PublicBackdropMixin & SurfaceMixin
    Mixin(frame, SurfaceMixin)
    frame:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(frame)

    Skinning:HandleSlider(widget.slider, true)

    hooksecurefunc(widget, 'Open', SkinPulloutChildren)
end

---@class DropdownItemMixin
local DropdownItemMixin = {}

function DropdownItemMixin:NUIUpdateSkinColors()
    ---@cast self Texture
    local r, g, b = Skinning:GetAccentColor()
    self:SetColorTexture(r, g, b, 0.25)
end

---Every entry type, AceGUI's own and LibDDI's, is built on the shared ItemBase and inherits its gold hover texture from there.
---@param widget table
local function SkinDropdownItem(widget)
    local highlight = widget.highlight

    ---@cast highlight Texture & DropdownItemMixin
    Mixin(highlight, DropdownItemMixin)
    highlight:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(highlight)
end

for _, itemType in ipairs({
    'Dropdown-Item-Toggle', 'Dropdown-Item-Execute', 'Dropdown-Item-Menu', 'Dropdown-Item-Separator',
    'DDI-Sound', 'DDI-Font', 'DDI-Statusbar', 'DDI-RaidIcon',
}) do
    Skins[itemType] = SkinDropdownItem
end

-- Every other entry is already white; only the header paints itself yellow.
Skins['Dropdown-Item-Header'] = function(widget)
    SkinDropdownItem(widget)
    SkinAccentLabel(widget, widget.text)
end

---The pooled media list is never registered as an AceGUI widget and ReturnDropDownFrame restores
---its Blizzard backdrop every time it closes, so restyle it on each open rather than once.
---@param button AceWidgetFrame
local function SkinMediaDropdown(button)
    local dropdown = button.obj.dropdown
    if not dropdown then return end

    dropdown:SetBackdrop(nil)
    Skinning:CreatePanelBackdrop(dropdown)
    Skinning:HandleSlider(dropdown.slider, true)

    -- Rows come from a pool of their own, carrying the same gold hover as AceGUI's own entries.
    for _, item in ipairs(dropdown.contentRepo) do
        if not item.NUISkinned then
            item.NUISkinned = true

            local highlight = item:GetHighlightTexture()

            ---@cast highlight Texture & DropdownItemMixin
            Mixin(highlight, DropdownItemMixin)
            highlight:NUIUpdateSkinColors()

            Skinning:RegisterSkinned(highlight)
        end
    end
end

local function SkinSharedMedia(widget)
    local frame = widget.frame
    local button = frame.dropButton

    if widget.bar then widget.bar.NUINoStrip = true end
    frame:NUIStripTextures()

    local backdrop = Skinning:CreatePanelBackdrop(frame, nil, nil, true)
    backdrop:ClearAllPoints()
    backdrop:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -21)
    backdrop:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -4, -1)

    frame.label:ClearAllPoints()
    frame.label:SetPoint('BOTTOMLEFT', backdrop, 'TOPLEFT', 2, 2)
    SkinAccentLabel(widget, frame.label)

    Skinning:HandleNextPrevButton(button, 'left')
    button:SetParent(backdrop)
    button:ClearAllPoints()
    button:SetPoint('TOPRIGHT', backdrop, 'TOPRIGHT', -2, -2)
    button:SetPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -2, 2)
    button:SetWidth(20)
    button:HookScript('OnClick', SkinMediaDropdown)

    frame.text:SetParent(backdrop)
    frame.text:ClearAllPoints()
    frame.text:SetPoint('LEFT', backdrop, 'LEFT', 3, 0)
    frame.text:SetPoint('RIGHT', button, 'LEFT', -3, 0)

    if widget.bar then
        widget.bar:SetParent(backdrop)
        widget.bar:ClearAllPoints()
        widget.bar:SetPoint('TOPLEFT', backdrop, 'TOPLEFT', 1, -1)
        widget.bar:SetPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -1, 1)
    end

    -- LSM30_Sound hangs its speaker off the widget rather than the frame, anchored to art we strip.
    local soundbutton = widget.soundbutton
    if soundbutton then
        soundbutton:SetParent(backdrop)
        soundbutton:ClearAllPoints()
        soundbutton:SetPoint('LEFT', backdrop, 'LEFT', 2, 0)
        frame.text:SetPoint('LEFT', soundbutton, 'RIGHT', 2, 0)
    end

    if frame.displayButton then
        frame.displayButton:SetBackdrop(nil)
        Skinning:CreatePanelBackdrop(frame.displayButton, nil, nil, true)
    end
end

Skins.LSM30_Font = SkinSharedMedia
Skins.LSM30_Sound = SkinSharedMedia
Skins.LSM30_Border = SkinSharedMedia
Skins.LSM30_Background = SkinSharedMedia
Skins.LSM30_Statusbar = SkinSharedMedia

-- Containers --

---@class PaneMixin
local PaneMixin = {}

function PaneMixin:NUIUpdateSkinColors()
    ---@cast self Frame & PublicBackdropMixin
    local color = Skinning.db.General.BorderColor
    self:SetBorderColor(color[1], color[2], color[3], color[4])
end

---@param frame Frame
local function StripPaneArt(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end
    frame:NUIStripTextures()
end

---Nested panes run several deep and every fill compounds toward opaque, so only the window carries one.
---@param frame Frame
local function SkinPane(frame)
    StripPaneArt(frame)

    local backdrop = Skinning:CreatePanelBackdrop(frame, nil, true)
    backdrop:SetBackgroundColor(0, 0, 0, 0)

    ---@cast backdrop Frame & PaneMixin
    Mixin(backdrop, PaneMixin)
    backdrop:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(backdrop)
end

---@param frame Frame
local function SkinWindow(frame)
    StripPaneArt(frame)

    Skinning:CreatePanelBackdrop(frame)
end

Skins.InlineGroup = function(widget)
    SkinPane(widget.content:GetParent())
    widget.titletext:SetFontObject(AccentNormal)
end

Skins.DropdownGroup = Skins.InlineGroup

-- BigWigs hangs its instance-export button off a plain DropdownGroup once the group is already built.
Decorations.BossDropdownGroup = function(widget)
    SkinButton(widget.exportInstanceBtn)
end

Skins.ScrollFrame = function(widget)
    Skinning:HandleScrollBar(widget.scrollbar)
end

-- The panel Blizzard's own options host draws behind it, so only the title is ours to color.
Skins.BlizOptionsGroup = function(widget)
    widget.label:SetFontObject(AccentLarge)
end

Skins.Frame = function(widget)
    SkinWindow(widget.frame)

    widget.titletext:SetFontObject(AccentNormal)
    widget.statustext:SetFontObject(AccentNormal)

    for _, child in ipairs({ widget.frame:GetChildren() }) do
        if child:IsObjectType('Button') then
            if child:GetText() then
                SkinButton(child)
            elseif child.SetBackdrop then
                child:SetBackdrop(nil)
            end
        end
    end
end

Skins.Window = function(widget)
    SkinWindow(widget.frame)
    Skinning:HandleCloseButton(widget.closebutton)

    widget.titletext:SetFontObject(AccentNormal)
end

-- SkironCooldownManager wraps Blizzard shells in container types of its own, a DefaultPanelTemplate
-- window and an icon strip riding a WowTrimHorizontalScrollBar.
Skins.SCMFrame = function(widget)
    Skinning:HandlePortraitFrame(widget.frame)

    widget.titletext:SetFontObject(AccentNormal)
end

Skins.SCMHorizontalScrollFrame = function(widget)
    Skinning:HandleTrimScrollBar(widget.scrollbar)
end

---@class TabMixin
---@field NUIBackdrop Frame & PublicBackdropMixin & SkinnedBackdropMixin
---@field NUIHighlight Texture
---@field NUISelected boolean?
local TabMixin = {}

function TabMixin:NUIUpdateSkinColors()
    ---@cast self Button & TabMixin
    Skinning:UpdateHighlightColor(self)

    local backdrop = self.NUIBackdrop
    backdrop:NUIUpdateSkinColors()

    if self.NUISelected then
        local r, g, b = Skinning:GetAccentColor()
        backdrop:SetBackgroundColor(r, g, b, 0.25)
        backdrop:SetBorderColor(r, g, b, 1)
    end
end

---@param tab Button & TabMixin
---@param selected boolean
local function TabSetSelected(tab, selected)
    tab.NUISelected = selected
    tab:NUIUpdateSkinColors()
end

---@param tab AceTabButton
local function SkinTab(tab)
    if tab.NUISkinned then return end
    tab.NUISkinned = true

    tab:NUIStripTextures()
    tab:SetNormalFontObject(AccentSmall)

    -- AceGUI drops the label to sit on the old tab art, both at creation and on every selection
    -- change, so the stored offsets are cleared rather than the anchors fought each pass.
    tab.deselectedTextY, tab.selectedTextY = TAB_TEXT_Y, TAB_TEXT_Y

    local text = tab.Text or tab:GetFontString()
    if text then
        text:ClearAllPoints()
        text:SetPoint('LEFT', tab, 'LEFT', TAB_TEXT_INSET, TAB_TEXT_Y)
        text:SetPoint('RIGHT', tab, 'RIGHT', -TAB_TEXT_INSET, TAB_TEXT_Y)
    end

    local backdrop = Skinning:CreatePanelBackdrop(tab, nil, nil, true)
    backdrop:ClearAllPoints()
    -- AceGUI overlaps neighbouring tabs by 10 to hide the old art's shoulder, so stay inside it.
    backdrop:SetPoint('TOPLEFT', tab, 'TOPLEFT', TAB_SHOULDER, -3)
    backdrop:SetPoint('BOTTOMRIGHT', tab, 'BOTTOMRIGHT', -TAB_SHOULDER, 0)

    -- The backdrop's fill and borders sit 1px inside its frame, so match AddHighlight's inset of 2.
    local highlight = tab.HighlightTexture
    highlight:ClearAllPoints()
    highlight:SetPoint('TOPLEFT', backdrop, 'TOPLEFT', 2, -2)
    highlight:SetPoint('BOTTOMRIGHT', backdrop, 'BOTTOMRIGHT', -2, 2)
    tab.NUIHighlight = highlight

    ---@cast tab Button & TabMixin
    Mixin(tab, TabMixin)

    -- AceGUI calls its own local PanelTemplates_*, so the global hooks never see these tabs.
    hooksecurefunc(tab, 'SetSelected', TabSetSelected)
    TabSetSelected(tab, tab.selected or false)

    Skinning:RegisterSkinned(tab)
end

Skins.TabGroup = function(widget)
    SkinPane(widget.content:GetParent())
    widget.titletext:SetFontObject(AccentNormal)

    widget.NUICreateTab = widget.CreateTab
    widget.CreateTab = function(self, id)
        local tab = self.NUICreateTab(self, id)
        SkinTab(tab)
        return tab
    end

    for _, tab in ipairs(widget.tabs) do
        SkinTab(tab)
    end
end

---@class TreeButtonMixin
---@field NUISelectedFill Texture
---@field NUISelectedBar Texture
local TreeButtonMixin = {}

function TreeButtonMixin:NUIUpdateSkinColors()
    ---@cast self Button & TreeButtonMixin
    Skinning:UpdateHighlightColor(self)

    local r, g, b = Skinning:GetAccentColor()
    self.NUISelectedFill:SetColorTexture(r, g, b, 0.15)
    self.NUISelectedBar:SetColorTexture(r, g, b, 1)
end

---AceGUI marks the selected row with LockHighlight, which would make it identical to a hover,
---so drive our own textures from the button.selected flag UpdateButton leaves behind.
function TreeButtonMixin:NUIUpdateSelected()
    ---@cast self AceTreeRow & TreeButtonMixin
    local selected = self.selected == true
    self.NUISelectedFill:SetShown(selected)
    self.NUISelectedBar:SetShown(selected)

    -- Our own art carries the selection now, so hand the locked highlight back to real hovers.
    if selected then self:UnlockHighlight() end
end

---@param toggle Button & NUIPlusMinusButtonMixin
---@param texture number|string|nil
local function TreeToggleTexture(toggle, texture)
    local collapsed = TREE_TOGGLE_COLLAPSED[texture]
    if collapsed ~= nil then
        toggle:NUISetCollapsed(collapsed)
    end
end

---@param button AceTreeRow
local function SkinTreeButton(button)
    if button.NUISkinned then return end
    button.NUISkinned = true

    button.icon.NUINoStrip = true
    button:NUIStripTextures()
    button:SetHeight(TREE_ROW_HEIGHT)

    -- Rows butt up against each other, so only the sides inset, clear of the treeframe border.
    local highlight = button:GetHighlightTexture()
    highlight:SetBlendMode('ADD')
    highlight:ClearAllPoints()
    highlight:SetPoint('TOPLEFT', button, 'TOPLEFT', 2, 0)
    highlight:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -2, 0)
    button.NUIHighlight = highlight

    -- The text and icon sit on ARTWORK/OVERLAY, so the selected art has to stay on BACKGROUND.
    local fill = button:CreateTexture(nil, 'BACKGROUND')
    fill:SetPoint('TOPLEFT', highlight)
    fill:SetPoint('BOTTOMRIGHT', highlight)
    button.NUISelectedFill = fill

    local bar = button:CreateTexture(nil, 'BACKGROUND', nil, 1)
    bar:SetPoint('TOPLEFT', fill)
    bar:SetPoint('BOTTOMLEFT', fill)
    bar:NUISetPixelWidth(2)
    button.NUISelectedBar = bar

    -- UpdateButton has already drawn this pass, so read the state off the art before it is cleared.
    local toggle = button.toggle
    local normal = toggle:GetNormalTexture()
    local state = normal and normal:GetTexture()

    -- AceGUI drives the toggle with file IDs, which the glyph's own name matching cannot read.
    Skinning:ReskinPlusMinus(toggle, TREE_TOGGLE_SIZE)
    hooksecurefunc(toggle, 'SetNormalTexture', TreeToggleTexture)
    TreeToggleTexture(toggle, state)

    ---@cast button Button & TreeButtonMixin
    Mixin(button, TreeButtonMixin)
    button:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(button)
end

---UpdateButton re-anchors the label 2px above centre on every refresh, so undo it after each one.
---@param text FontString
local function AlignRowText(text)
    for i = 1, text:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = text:GetPoint(i)
        if point == 'LEFT' and y ~= 0 then
            text:SetPoint(point, relativeTo, relativePoint, x, 0)
        end
    end
end

---UpdateButton rewrites the row's state from scratch on every pass, so restyle after each one.
---@param button AceTreeRow & TreeButtonMixin
local function UpdateTreeRow(button)
    SkinTreeButton(button)
    AlignRowText(button.text)
    button:NUIUpdateSelected()

    -- Only top-level rows get Blizzard's gold, the deeper ones are already white.
    if button.level == 1 then
        button:SetNormalFontObject(AccentNormal)
    end
end

local function RefreshTree(widget, scrollToSelection)
    widget.NUIRefreshTree(widget, scrollToSelection)

    for _, button in ipairs(widget.buttons) do
        UpdateTreeRow(button)
    end
end

Skins.TreeGroup = function(widget)
    SkinPane(widget.content:GetParent())
    SkinPane(widget.treeframe)

    Skinning:HandleScrollBar(widget.scrollbar)

    widget.NUIRefreshTree = widget.RefreshTree
    widget.RefreshTree = RefreshTree

    for _, button in ipairs(widget.buttons) do
        UpdateTreeRow(button)
    end
end

-- Library hooks --

local function SkinObject(obj)
    local skin = Skins[obj.type]
    if not skin or obj.NUISkinned then return end
    obj.NUISkinned = true

    skin(obj)
end

---@param widgetType string
---@param obj table?
local function SkinDecorations(widgetType, obj)
    local decorate = obj and Decorations[widgetType]
    if not decorate or obj.NUIDecorated then return end
    obj.NUIDecorated = true

    decorate(obj)
end

local function SkinPopup(popup)
    if popup.NUISkinned then return end
    popup.NUISkinned = true

    for _, child in ipairs({ popup:GetChildren() }) do
        child:NUIStripTextures()
    end

    Skinning:CreatePanelBackdrop(popup)
    SkinButton(popup.accept)
    SkinButton(popup.cancel)
end

---@param tooltip GameTooltip
---@param index number
local function RecolorTooltipLine(tooltip, index)
    local line = _G[tooltip:GetName() .. 'TextLeft' .. index]
    if not line then return end

    local r, g, b = Skinning:GetAccentColor()
    line:SetTextColor(r, g, b)
end

---Both libraries hand their tooltips Blizzard's gold as raw numbers instead of a font object, so
---match that exact color and repaint whichever line the call just wrote.
---@param tooltip GameTooltip?
local function SkinTooltip(tooltip)
    if not tooltip or tooltip.NUISkinned then return end
    tooltip.NUISkinned = true

    hooksecurefunc(tooltip, 'SetText', function(self, _, r, g, b)
        if r == GOLD_R and g == GOLD_G and b == GOLD_B then
            RecolorTooltipLine(self, 1)
        end
    end)

    hooksecurefunc(tooltip, 'AddLine', function(self, _, r, g, b)
        if r == GOLD_R and g == GOLD_G and b == GOLD_B then
            RecolorTooltipLine(self, self:NumLines())
        end
    end)
end

---@param lib table
---@param key string
---@param value any
local function OnNewIndex(lib, key, value)
    if not value then
        rawset(lib, key, value)
    elseif key == 'RegisterAsWidget' or key == 'RegisterAsContainer' then
        rawset(lib, key, function(self, obj, ...)
            SkinObject(obj)
            return value(self, obj, ...)
        end)
    elseif key == 'Create' then
        rawset(lib, key, function(self, widgetType, ...)
            local obj = value(self, widgetType, ...)
            SkinDecorations(widgetType, obj)
            return obj
        end)
    elseif key == 'popup' then
        rawset(lib, key, value)
        SkinPopup(value)
    else
        rawset(lib, key, value)
    end
end

local hooked = {}

---Route future assignments of the library's skinnable keys through OnNewIndex.
---@param lib table
local function InterceptAssignments(lib)
    local meta = getmetatable(lib)
    if meta then
        meta.__newindex = OnNewIndex
    else
        setmetatable(lib, { __newindex = OnNewIndex })
    end
end

---@param lib table?
---@param minor number?
local function HookAceGUI(lib, minor)
    if not lib or not minor or minor < MIN_GUI_MINOR or hooked[lib] then return end
    hooked[lib] = true

    -- __newindex only fires for absent keys, so clear them and let the restore run through it.
    local widget, container = rawget(lib, 'RegisterAsWidget'), rawget(lib, 'RegisterAsContainer')
    local create = rawget(lib, 'Create')
    rawset(lib, 'RegisterAsWidget', nil)
    rawset(lib, 'RegisterAsContainer', nil)
    rawset(lib, 'Create', nil)

    InterceptAssignments(lib)
    SkinTooltip(rawget(lib, 'tooltip'))

    lib.RegisterAsWidget = widget
    lib.RegisterAsContainer = container
    lib.Create = create
end

---@param lib table?
---@param minor number?
local function HookAceConfigDialog(lib, minor)
    if not lib or not minor or minor < MIN_DIALOG_MINOR or hooked[lib] then return end
    hooked[lib] = true

    InterceptAssignments(lib)
    SkinTooltip(rawget(lib, 'tooltip'))

    local popup = rawget(lib, 'popup')
    if popup then SkinPopup(popup) end
end

---@param obj table
local function SkinExisting(obj)
    SkinObject(obj)

    if obj.children then
        for _, child in ipairs(obj.children) do
            SkinExisting(child)
        end
    end
end

local function OnNewLibrary(_, major)
    local name = gsub(major, LIB_VERSION_SUFFIX, '')

    if name == 'AceGUI' then
        HookAceGUI(LibStub.libs[major], LibStub.minors[major])
    elseif name == 'AceConfigDialog' then
        HookAceConfigDialog(LibStub.libs[major], LibStub.minors[major])
    end
end

Skinning:RegisterSkin(nil, 'Ace3', function()
    for _, font in ipairs(ACCENT_FONTS) do
        font:NUIUpdateSkinColors()
    end

    for major, lib in next, LibStub.libs do
        local name = gsub(major, LIB_VERSION_SUFFIX, '')

        if name == 'AceGUI' then
            HookAceGUI(lib, LibStub.minors[major])
        elseif name == 'AceConfigDialog' then
            HookAceConfigDialog(lib, LibStub.minors[major])
        end
    end

    for _, child in ipairs({ UIParent:GetChildren() }) do
        if child.obj then SkinExisting(child.obj) end
    end

    hooksecurefunc(LibStub, 'NewLibrary', OnNewLibrary)
end)
