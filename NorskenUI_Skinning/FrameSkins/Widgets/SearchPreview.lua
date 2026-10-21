---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc

local LIST_GAP = 2

local resultMixinHooked

---Both row templates are buttons sharing the _search-rowbg art, which the panel behind them replaces.
---@param row SearchPreviewEntry
local function StripRowArt(row)
    if row.NUISkinned then return end
    row.NUISkinned = true

    row:SetNormalTexture(NRSKNUI.ClearTexture)
    row:SetPushedTexture(NRSKNUI.ClearTexture)
end

---A search result, rebound to fresh data on every keystroke.
---@param row SearchPreviewEntry
local function SkinResultRow(row)
    StripRowArt(row)

    -- IconFrame is a ring atlas drawn over the icon, HandleIcon's own border replaces it.
    if row.IconFrame then row.IconFrame:Hide() end

    Skinning:HandleIcon(row.Icon, true)
    Skinning:HandleOutlineFont(row.Name)
end

---The fallback rows, shown only when a search has no results at all.
---@param container SearchPreviewContainer
local function SkinSuggestedRows(container)
    local pool = container.suggestedResultButtonsPool
    if not pool then return end

    for row in pool:EnumerateActive() do
        ---@cast row SearchPreviewEntry
        StripRowArt(row)
        Skinning:HandleOutlineFont(row.Text)
    end
end

---Skin one search autocomplete dropdown, the match list under a search box.
---@param container SearchPreviewContainer? The owning frame's SearchPreviewContainer
---@param searchBox NUISkinnedEditBox? Line the list up under this box, HandleEditBox it first
function Skinning:HandleSearchPreview(container, searchBox)
    if not container or container.NUISkinned then return end
    container.NUISkinned = true

    container:NUIStripTextures('Keyed')
    self:CreatePanelBackdrop(container)
    self:HandleOutlineFont(container.OverflowCount and container.OverflowCount.Text)

    if searchBox then
        local top = (searchBox.NUIArtBottom or 0) - LIST_GAP
        container:ClearAllPoints()
        container:NUISetPixelPoint('TOPLEFT', searchBox, 'BOTTOMLEFT', searchBox.NUIArtLeft or 0, top)
        container:NUISetPixelPoint('TOPRIGHT', searchBox, 'BOTTOMRIGHT', searchBox.NUIArtRight or 0, top)
    end

    SkinSuggestedRows(container)
    hooksecurefunc(container, 'UpdateResultsDisplay', SkinSuggestedRows)

    if not resultMixinHooked then
        resultMixinHooked = true
        hooksecurefunc(SpellSearchPreviewResultMixin, 'Init', SkinResultRow)
    end
end
