---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local Mixin = Mixin
local ipairs = ipairs
local hooksecurefunc = hooksecurefunc

local _G = _G
local LibStub = LibStub

local DROPDOWN_LIST = 'ElioteDDM_DropDownList'
local ROW_HIGHLIGHT_ALPHA = 0.25
local ROW_PUSHED_ALPHA = 0.1
local DIVIDER_HEIGHT = 1
local ROW_INSET_X, ROW_INSET_Y = 0, 1
local ROW_CHECK_INSET = 4
local LOCK_ICON_SIZE, LOCK_ICON_OFFSET = 12, 3

local skinned = false

---@class AccentTextureMixin
---@field NUIAlpha number
local AccentTextureMixin = {}

function AccentTextureMixin:NUIUpdateSkinColors()
    ---@cast self Texture & AccentTextureMixin
    local r, g, b = Skinning:GetAccentColor()
    self:SetColorTexture(r, g, b, self.NUIAlpha)
end

---Repaint one of the addon's own state textures in the accent, tracked for later color changes.
---@param texture Texture?
---@param alpha number
---@param leftAnchor Frame? Start at this element's right edge instead of the owner's own
local function SkinAccentTexture(texture, alpha, leftAnchor)
    if not texture then return end
    texture.NUIAlpha = alpha

    -- Anchored edge by edge, the left anchor is a taller element, so it must not drive the height.
    local owner = texture:GetParent()
    texture:ClearAllPoints()
    texture:SetPoint('TOP', owner, 'TOP', 0, -ROW_INSET_Y)
    texture:SetPoint('BOTTOM', owner, 'BOTTOM', 0, ROW_INSET_Y)
    texture:SetPoint('RIGHT', owner, 'RIGHT', -ROW_INSET_X, 0)
    texture:SetPoint('LEFT', leftAnchor or owner, leftAnchor and 'RIGHT' or 'LEFT', ROW_INSET_X, 0)

    ---@cast texture Texture & AccentTextureMixin
    Mixin(texture, AccentTextureMixin)
    texture:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(texture)
end

---@class DividerMixin
local DividerMixin = {}

function DividerMixin:NUIUpdateSkinColors()
    ---@cast self Texture
    local color = Skinning.db.General.BorderColor
    self:SetColorTexture(color[1], color[2], color[3], color[4])
end

---UIPanelSquareButton keeps its glyph in a plain region, which the button strip would wipe.
---@param button Button
local function SkinSquareButton(button)
    button.icon.NUINoStrip = true

    Skinning:HandleButton(button)
end

---The badge is anchored to the button, which is wider than the box our skin draws inside it.
---@param check SAMEnabledButton
local function SkinLockIcon(check)
    local lockIcon = check.LockIcon
    local backdrop = check.NUIBackdrop
    if not lockIcon or not backdrop then return end

    lockIcon:SetSize(LOCK_ICON_SIZE, LOCK_ICON_SIZE)
    lockIcon:ClearAllPoints()
    lockIcon:NUISetPixelPoint('CENTER', backdrop, 'BOTTOMRIGHT', LOCK_ICON_OFFSET, LOCK_ICON_OFFSET)
end

---A locked addon refuses the toggle but keeps its button enabled, so the fill carries the dead look.
---@param check SAMEnabledButton
local function SyncLockState(check)
    local locked = check.LockIcon ~= nil and check.LockIcon:IsShown()
    if check.NUILocked == locked then return end

    check.NUILocked = locked
    check:NUIUpdateSkinColors()
end

---@param scrollFrame SAMScrollFrame
local function SkinRows(scrollFrame)
    local buttons = scrollFrame.buttons
    if not buttons then return end

    for _, button in ipairs(buttons) do
        local check = button.EnabledButton

        if not button.NUISkinned then
            button.NUISkinned = true

            Skinning:HandleCheckBox(check, ROW_CHECK_INSET)
            SkinLockIcon(check)

            if button.ExpandOrCollapseButton then
                Skinning:ReskinCollapse(button.ExpandOrCollapseButton)
            end

            SkinAccentTexture(button.HighlightTexture, ROW_HIGHLIGHT_ALPHA, check)
            SkinAccentTexture(button.PushedTexture, ROW_PUSHED_ALPHA, check)
        end

        -- Rows are pooled, so each pass can land a different addon in this one.
        SyncLockState(check)
    end
end

---HybridScrollFrame reuses a fixed pool of rows, but only builds them once it first has data.
---@param scrollFrame SAMScrollFrame
local function SkinScrollFrame(scrollFrame)
    Skinning:HandleScrollBar(scrollFrame.ScrollBar)

    SkinRows(scrollFrame)
    hooksecurefunc(scrollFrame, 'update', function()
        SkinRows(scrollFrame)
    end)
end

---@param frame SAMProfilerFrame
local function SkinProfilerFrame(frame)
    local divider = frame.Divider
    divider:SetHeight(DIVIDER_HEIGHT)

    ---@cast divider Texture & DividerMixin
    Mixin(divider, DividerMixin)
    divider:NUIUpdateSkinColors()

    Skinning:RegisterSkinned(divider)

    for _, button in ipairs({
        frame.Left.CurrentCPUButton,
        frame.Left.AverageCPUButton,
        frame.Right.EncounterCPUButton,
        frame.Right.PeakCPUButton,
    }) do
        SkinAccentTexture(button:GetHighlightTexture(), ROW_HIGHLIGHT_ALPHA)
    end
end

---Every menu frame is created on demand and kept forever, so rescan after each growth.
---@param lib table
local function SkinDropDownLists(lib)
    for level = 1, lib.UIDROPDOWNMENU_MAXLEVELS do
        local list = _G[DROPDOWN_LIST .. level]

        if list and not list.NUISkinned then
            list.NUISkinned = true

            for _, key in ipairs({ 'Backdrop', 'MenuBackdrop' }) do
                local backdrop = _G[DROPDOWN_LIST .. level .. key]

                if backdrop then
                    backdrop:SetBackdrop(nil)
                    Skinning:CreatePanelBackdrop(backdrop)
                end
            end
        end

        for index = 1, lib.UIDROPDOWNMENU_MAXBUTTONS do
            local button = _G[DROPDOWN_LIST .. level .. 'Button' .. index]

            if button and not button.NUISkinned then
                button.NUISkinned = true
                SkinAccentTexture(button.Highlight, ROW_HIGHLIGHT_ALPHA)
            end
        end
    end
end

---@param frame SAMFrame
local function SkinSimpleAddonManager(frame)
    if skinned then return end
    skinned = true

    Skinning:HandlePortraitFrame(frame)

    -- The panel template moved its title into a container and the addon still supports both.
    Skinning:HandleAccentText(frame.TitleText or (frame.TitleContainer and frame.TitleContainer.TitleText))

    -- Header
    Skinning:HandleDropdownButton(frame.CharacterDropDown)
    Skinning:HandleButton(frame.SetsButton)
    Skinning:HandleEditBox(frame.SearchBox)

    SkinSquareButton(frame.ResultOptionsButton)
    SkinSquareButton(frame.ConfigButton)
    SkinSquareButton(frame.CategoryButton)

    local categoryFrame = frame.CategoryFrame

    for _, button in ipairs({
        frame.EnableAllButton,
        frame.DisableAllButton,
        frame.OkButton,
        frame.CancelButton,
        categoryFrame.NewButton,
        categoryFrame.SelectAllButton,
        categoryFrame.ClearSelectionButton,
    }) do
        Skinning:HandleButton(button)
    end

    SkinScrollFrame(frame.AddonListFrame.ScrollFrame)
    SkinScrollFrame(categoryFrame.ScrollFrame)
    SkinProfilerFrame(frame.ProfilerFrame)

    local EDDM = LibStub('ElioteDropDownMenu-1.0', true)
    if EDDM then
        SkinDropDownLists(EDDM)
        hooksecurefunc(EDDM, 'UIDropDownMenu_CreateFrames', function()
            SkinDropDownLists(EDDM)
        end)
    end
end

Skinning:RegisterSkin('SimpleAddonManager', 'SimpleAddonManager', function()
    local frame = _G.SimpleAddonManager
    if not frame then return end

    -- The addon builds its panels from PLAYER_LOGIN handlers, well after ADDON_LOADED.
    frame:HookScript('OnShow', SkinSimpleAddonManager)
end)
