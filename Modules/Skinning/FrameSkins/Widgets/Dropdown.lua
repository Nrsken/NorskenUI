---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local Mixin = Mixin
local strfind = string.find

local SkinnedButtonMixin = Skinning.ButtonMixin

---Read the menu's own anchor, which MenuMixin:FlipPositionIfOffscreen has already corrected.
---@param dropdown DropdownButton
---@return string direction
local function GetMenuOpenDirection(dropdown)
    local menu = dropdown.menu
    if not menu or not menu.GetPoint or menu:IsAnchoringRestricted() then return 'down' end

    -- relativePoint is the dropdown's own edge the menu hangs off, so a TOP edge means it opened upward.
    local _, _, relativePoint = menu:GetPoint(1)
    if relativePoint and strfind(relativePoint, '^TOP') then return 'up' end
    return 'down'
end

---Skin a modern dropdown button (WowStyle1DropdownTemplate/DropdownButton).
---@param dropdown WowStyle1DropdownTemplate
---@param template string? 'Transparent' pins the background alpha at 0.5
function Skinning:HandleDropdownButton(dropdown, template)
    if not dropdown or dropdown.NUISkinned then return end
    dropdown.NUISkinned = true

    dropdown.Arrow:NUIStripTextures('Alpha')

    local sizeX, sizeY = 22, 22
    self:CreateArrowTexture(dropdown, 'left', sizeX, sizeY, 'RIGHT', dropdown, 'RIGHT', -2, 0)

    if dropdown.Background then dropdown.Background:SetAlpha(0) end
    self:CreatePanelBackdrop(dropdown, template, nil, true)

    ---@cast dropdown Button & SkinnedButtonMixin
    Mixin(dropdown, SkinnedButtonMixin)

    -- IsOver is the flag ButtonStateBehaviorMixin just set, a cursor test disagrees with it.
    local function UpdateText()
        dropdown:NUIUpdateState(dropdown.NUIMenuOpen or dropdown:IsOver())
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
