---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local Mixin = Mixin
local math_abs = math.abs
local math_max = math.max
local math_min = math.min

local SkinnedEditBoxMixin = {}

-- Input art sits on BACKGROUND/BORDER, sparing the search icon, clear button and Instructions.
local EDITBOX_ART_LAYERS = { 'BACKGROUND', 'BORDER' }
local EDITBOX_ART_LAYER_SET = {}
for _, layer in ipairs(EDITBOX_ART_LAYERS) do EDITBOX_ART_LAYER_SET[layer] = true end
local MAX_ART_OVERHANG = 20
local MIN_TEXT_INSET = 4

---Edge reads on a frame carrying protected data come back secret, so void the whole rect rather than measure it.
---@param object Frame|Texture
---@return number? left, number? right, number? top, number? bottom
local function SafeEdges(object)
    local l, r, t, b = object:GetLeft(), object:GetRight(), object:GetTop(), object:GetBottom()
    if NRSKNUI:IsSecretValue(l) or NRSKNUI:IsSecretValue(r)
        or NRSKNUI:IsSecretValue(t) or NRSKNUI:IsSecretValue(b) then
        return
    end
    return l, r, t, b
end

---Measure the union of an EditBox's art regions as offsets from its own edges, overhang varies per template.
---@param editBox EditBox
---@return number? left, number? right, number? top, number? bottom
local function MeasureInputArt(editBox)
    local boxLeft, boxRight, boxTop, boxBottom = SafeEdges(editBox)
    if not boxLeft or not boxRight or not boxTop or not boxBottom then return end

    local left, right, top, bottom

    local function Union(object)
        local l, r, t, b = SafeEdges(object)
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

---A single line of text centres on the frame rect, but the box is drawn on the art rect.
---@param editBox EditBox
---@param top number Art top as an offset from the frame's own top
---@param bottom number Art bottom as an offset from the frame's own bottom
local function CenterTextInArt(editBox, top, bottom)
    local offset = top + bottom
    if math_abs(offset) < 1 then return end

    local l, r, t, b = editBox:GetTextInsets()
    if offset > 0 then
        editBox:SetTextInsets(l, r, t, b + offset)
    else
        editBox:SetTextInsets(l, r, t - offset, b)
    end
end

---Raise the side insets to the floor. AceGUI re-asserts its own from seven call sites, so this
---has to re-run on every write rather than land once.
---@param editBox EditBox
local function ApplyTextInsetFloor(editBox)
    if editBox.NUISettingInsets then return end

    local left, right, top, bottom = editBox:GetTextInsets()
    if left >= MIN_TEXT_INSET and right >= MIN_TEXT_INSET then return end

    editBox.NUISettingInsets = true
    editBox:SetTextInsets(math_max(left, MIN_TEXT_INSET), math_max(right, MIN_TEXT_INSET), top, bottom)
    editBox.NUISettingInsets = nil
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

---Skin an EditBox/SearchBox: backdrop fitted to the input art, accent border while focused.
---@param editBox EditBox
function Skinning:HandleEditBox(editBox)
    if not editBox or editBox.NUISkinned then return end
    editBox.NUISkinned = true

    local left, right, top, bottom = MeasureInputArt(editBox)

    -- Placeholder text wraps by default, which spills out of a single-line box.
    if editBox.Instructions then editBox.Instructions:SetWordWrap(false) end

    editBox:NUIStripTextures('Layer', EDITBOX_ART_LAYERS)
    if editBox.NineSlice then editBox.NineSlice:NUIStripTextures() end

    local backdrop = self:CreatePanelBackdrop(editBox, nil, true, true)
    if not backdrop then return end

    if left then
        backdrop:ClearAllPoints()
        backdrop:SetPoint('TOPLEFT', editBox, 'TOPLEFT', left, top)
        backdrop:SetPoint('BOTTOMRIGHT', editBox, 'BOTTOMRIGHT', right, bottom)

        -- The art rarely matches the frame rect, so callers aligning or matching the box need it.
        editBox.NUIArtLeft, editBox.NUIArtRight = left, right
        editBox.NUIArtTop, editBox.NUIArtBottom = top, bottom

        CenterTextInArt(editBox, top, bottom)
    end

    hooksecurefunc(editBox, 'SetTextInsets', ApplyTextInsetFloor)
    ApplyTextInsetFloor(editBox)

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
