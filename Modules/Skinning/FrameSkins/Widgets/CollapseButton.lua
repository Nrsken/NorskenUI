---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local Mixin = Mixin
local strfind = string.find

local EXPAND_ATLAS = 'UI-QuestTrackerButton-Secondary-Expand'
local COLLAPSE_ATLAS = 'UI-QuestTrackerButton-Secondary-Collapse'
local HIGHTLIGHT_ATLAS = 'UI-QuestTrackerButton-Yellow-Highlight'

---@class NUICollapseButtonMixin
local NUICollapseButtonMixin = {}

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
    self:SetNormalTexture(NRSKNUI.ClearTexture)

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
    self:SetNormalTexture(NRSKNUI.ClearTexture)

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

    button:SetNormalTexture(NRSKNUI.ClearTexture)
    button:SetHighlightTexture(NRSKNUI.ClearTexture)
    button:SetPushedTexture(NRSKNUI.ClearTexture)

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
