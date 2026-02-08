local _, NRSKNUI = ...

local Mixin = Mixin
local CreateFrame = CreateFrame

local widgetMixin = {}
function widgetMixin:CreateFrame(frameType, template)
    return Mixin(NRSKNUI:CreateFrame(frameType or 'Frame', nil, self, template), widgetMixin)
end

function widgetMixin:CreateBackdropFrame(frameType, template)
    local frame = self:CreateFrame(frameType, template)
    frame:AddBackdrop()
    return frame
end

do
    local statusBarMixin = {}
    function statusBarMixin:SetStatusBarColor(...)
        self:GetStatusBarTexture():SetVertexColor(...)
    end

    function statusBarMixin:SetStatusBarColorFromBoolean(...)
        self:GetStatusBarTexture():SetVertexColorFromBoolean(...)
    end

    function widgetMixin:CreateStatusBar(template)
        local statusBar = Mixin(self:CreateFrame('StatusBar', template), statusBarMixin)
        local texture = statusBar:CreateTexture()
        texture:SetTexture(NRSKNUI.TEXTURE)
        statusBar:SetStatusBarTexture(texture)

        return statusBar
    end

    function widgetMixin:CreateBackdropStatusBar(template)
        local statusBar = self:CreateStatusBar(template)
        statusBar:AddBackdrop()
        statusBar:SetBackgroundColor(0, 0, 0, 0.8)
        return statusBar
    end
end

do
    local textureMixin = {}
    function textureMixin:SetColorTextureFromBoolean(...)
        self:SetColorTexture(1, 1, 1) -- reset color texture first
        self:SetVertexColorFromBoolean(...)
    end

    local createTexture = CreateFrame('Frame').CreateTexture
    function widgetMixin:CreateTexture(layer, level)
        local texture = Mixin(createTexture(self, nil, layer, nil, level), textureMixin)
        NRSKNUI:PixelPerfect(texture)
        return texture
    end

    function widgetMixin:CreateIcon(layer, level)
        local icon = self:CreateTexture(layer, level)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return icon
    end
end

do
    local textMixin = {}
    function textMixin:SetFontSize(size)
        self:SetFont(NRSKNUI.FONT, size or 16, 'OUTLINE')
    end

    function textMixin:SetFrameLevel(level)
        self:GetParent():SetFrameLevel(level)
    end

    function widgetMixin:CreateText(size)
        if not self.overlayParent then
            -- make sure text renders above other widgets
            self.overlayParent = CreateFrame('Frame', nil, self)
            self.overlayParent:SetAllPoints() -- needs a size so children can render
        end

        local text = Mixin(self.overlayParent:CreateFontString(nil, 'OVERLAY'), textMixin)
        text:SetFontSize(size)
        text:SetWordWrap(false)
        return text
    end
end

do
    local cooldownMixin = {}
    function cooldownMixin:SetTimeFont(size)
        self:GetRegions():SetFont(NRSKNUI.FONT, size or 16, 'OUTLINE')
    end

    function cooldownMixin:ClearTimePoints()
        self:GetRegions():ClearAllPoints()
    end

    function cooldownMixin:SetTimePoint(...)
        self:GetRegions():SetPoint(...)
    end

    function cooldownMixin:SetIgnoreGlobalCooldown(state)
        self:SetMinimumCountdownDuration(state and 1500 or 0)
    end

    function widgetMixin:CreateCooldown(anchor)
        local cooldown = Mixin(NRSKNUI:CreateFrame('Cooldown', nil, self, 'CooldownFrameTemplate'), cooldownMixin)
        cooldown:SetAllPoints(anchor or self)
        cooldown:SetDrawEdge(false)
        cooldown:SetDrawBling(false)
        cooldown:SetSwipeColor(0, 0, 0, 0.9)
        cooldown:SetTimeFont()
        cooldown:SetIgnoreGlobalCooldown(true)
        return cooldown
    end

    -- expose creation globally
    function NRSKNUI:CreateCooldown(parent, anchor)
        return widgetMixin.CreateCooldown(parent, anchor)
    end
end

function widgetMixin:AddBackdrop(...)
    NRSKNUI:AddBackdrop(self, ...)
end

-- expose internally

function NRSKNUI:CreateFrame(...)
    return Mixin(CreateFrame(...), widgetMixin, NRSKNUI.eventMixin)
end

NRSKNUI.widgetMixin = widgetMixin
