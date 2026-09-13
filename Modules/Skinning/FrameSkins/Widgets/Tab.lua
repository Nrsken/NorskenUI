---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local type = type
local Mixin = Mixin

local PanelTemplates_SelectTab = PanelTemplates_SelectTab
local PanelTemplates_DeselectTab = PanelTemplates_DeselectTab
local PanelTemplates_SetDisabledTabState = PanelTemplates_SetDisabledTabState

local SkinnedTabMixin = {}

---@param selected boolean
---@param disabled boolean?
function SkinnedTabMixin:NUISetTabSelected(selected, disabled)
    self.NUISelected = selected
    self.NUIDisabled = disabled
    local text = self.Text or (self.GetFontString and self:GetFontString())
    if not text then return end

    -- Style tab text, blizzard moves it a lot on the Y axis for selected tabs so take control and center it.
    text:ClearAllPoints()
    text:SetPoint('CENTER', self.NUIBackdrop, 'CENTER', 0, 0)
    text:SetFontStyle(Skinning.db, Skinning.db.FontTabSize, nil, nil, nil, true)

    -- Selected tabs have their text colored in accent, non selected have white color.
    if disabled then
        local dim = Skinning.db.General.DisabledColor[4]
        text:SetTextColor(dim, dim, dim)
    elseif selected then
        local r, g, b = Skinning:GetAccentColor()
        text:SetTextColor(r, g, b)
    else
        text:SetTextColor(1, 1, 1)
    end
end

function SkinnedTabMixin:NUIUpdateSkinColors()
    Skinning:UpdateHighlightColor(self)
    self:NUISetTabSelected(self.NUISelected or false, self.NUIDisabled)
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
---@param isWidget boolean? Color it from the Widget palette and give it the widget glow
function Skinning:HandleTab(tab, isWidget)
    if not tab or tab.NUISkinned then return end
    tab.NUISkinned = true

    tab:NUIStripTextures()
    local backdrop = self:CreatePanelBackdrop(tab, nil, nil, isWidget)
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

    self:AddHighlight(tab)

    tab:NUISetTabSelected(tab.isSelected or false)
    self:RegisterSkinned(tab)
end

---Skin a row of tabs, optionally moving the row under the anchor's bottom edge.
---@param source string|NUITabSystem|Frame Global name prefix, or a TabSystemTemplate frame
---@param anchor Frame? Frame to hang the row under, omit to skin the tabs where Blizzard put them
---@param isWidget boolean? Color the tabs from the Widget palette and give them the widget glow
function Skinning:HandleTabRow(source, anchor, isWidget)
    if not source then return end

    if type(source) == 'string' then
        local prev
        local i = 1
        local tab = _G[source .. i]
        while tab do
            self:HandleTab(tab, isWidget)

            if anchor then
                tab:ClearAllPoints()
                if prev then
                    tab:NUISetPixelPoint('TOPLEFT', prev, 'TOPRIGHT', -1, 0)
                else
                    tab:NUISetPixelPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, 1)
                end
                prev = tab
            end

            i = i + 1
            tab = _G[source .. i]
        end
        return
    end

    if not source.tabs then return end
    for _, tab in ipairs(source.tabs) do
        self:HandleTab(tab, isWidget)
    end

    -- Hidden tabs drop out of the layout on their own, so there are no gaps to chain around.
    source.spacing = -1
    if anchor then
        source:ClearAllPoints()
        source:NUISetPixelPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, 1)
    end
    source:MarkDirty()
end
