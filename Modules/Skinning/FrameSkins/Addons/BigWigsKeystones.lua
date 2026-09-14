---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local ipairs = ipairs
local hooksecurefunc = hooksecurefunc
local UIParent = UIParent

local ADDON_NAME = 'BigWigs'

---The panel is a file local with no name, so its own keys are the only way in.
---@return BWKeystonePanel?
local function FindPanel()
    for _, child in ipairs({ UIParent:GetChildren() }) do
        if not child:IsForbidden() and child.PortraitContainer and child.tip and child.teleportBar then
            return child --[[@as BWKeystonePanel]]
        end
    end
end

---@param tab BWKeystoneTab
---@return fun() sync Repaint from the tab's own active art, which is all BigWigs updates
local function SkinTab(tab)
    Skinning:HandleTab(tab, true)

    -- BigWigs drives the active art from its own locals, PanelTemplates_SelectTab is never called.
    local function Sync()
        tab:NUISetTabSelected(tab.LeftActive:IsShown())
    end

    hooksecurefunc(tab.LeftActive, 'Show', Sync)
    hooksecurefunc(tab.LeftActive, 'Hide', Sync)
    Sync()

    return Sync
end

---@param button BWTeleportButton
local function SkinTeleportButton(button)
    if button.NUISkinned then return end
    button.NUISkinned = true

    -- The fill is the one region with no key, so this must precede AddHighlight's own texture.
    for _, region in ipairs({ button:GetRegions() }) do
        if region:IsObjectType('Texture') and region ~= button.icon and region ~= button.cdbar then
            region:Hide()
        end
    end

    Skinning:CreatePanelBackdrop(button, nil, nil, true)
    Skinning:HandleIcon(button.icon, true, nil, true)
    Skinning:AddHighlight(button)
end

---@param cell BWKeystoneCell
local function SkinCell(cell)
    if cell.NUISkinned then return end
    cell.NUISkinned = true

    cell.bg:Hide()
    Skinning:CreatePanelBackdrop(cell, nil, nil, true)

    -- Names arrive pre-decorated, whose escape sequence outranks the accent we set here.
    Skinning:HandleAccentText(cell.text)
end

---@param button Button
local function SkinRefreshButton(button)
    if button.NUISkinned then return end
    button.NUISkinned = true

    Skinning:CreatePanelBackdrop(button, nil, nil, true)
    Skinning:AddHighlight(button)
end

---@param scrollChild Frame
local function SkinScrollChild(scrollChild)
    for _, child in ipairs({ scrollChild:GetChildren() }) do
        if child.cdbar then
            SkinTeleportButton(child --[[@as BWTeleportButton]])
        elseif child.bg then
            SkinCell(child --[[@as BWKeystoneCell]])
        else
            SkinRefreshButton(child --[[@as Button]])
        end
    end

    for _, region in ipairs({ scrollChild:GetRegions() }) do
        if region:IsObjectType('FontString') then
            Skinning:HandleAccentText(region)
        end
    end
end

---The teleport hint hangs a GlowBoxArrowTemplate under the box, which the keyed strip cannot reach.
---@param tip Frame
local function SkinTip(tip)
    tip:NUIStripTextures('Keyed')

    for _, child in ipairs({ tip:GetChildren() }) do
        child:NUIStripTextures('Keyed')
    end

    Skinning:CreatePanelBackdrop(tip)
end

Skinning:RegisterSkin(ADDON_NAME, 'BigWigsKeystones', function(S)
    local panel = FindPanel()
    if not panel then return end

    S:HandlePortraitFrame(panel)
    S:HandleAccentText(panel.TitleText or (panel.TitleContainer and panel.TitleContainer.TitleText))
    SkinTip(panel.tip)

    local scrollArea
    local tabSyncs = {}
    for _, child in ipairs({ panel:GetChildren() }) do
        if child.LeftActive then
            tabSyncs[#tabSyncs + 1] = SkinTab(child --[[@as BWKeystoneTab]])
        elseif child.GetScrollChild then
            scrollArea = child
        end
    end

    if not scrollArea then return end

    -- ScrollFrameTemplate carries a MinimalScrollBar, not the legacy Slider a UIPanel one has.
    S:HandleTrimScrollBar(scrollArea.ScrollBar)

    -- Rows and headers arrive late, and the tabs repaint themselves on the panel's first show.
    local scrollChild = scrollArea:GetScrollChild()
    local function Refresh()
        for _, Sync in ipairs(tabSyncs) do Sync() end
        SkinScrollChild(scrollChild)
    end

    panel:HookScript('OnShow', Refresh)
    if panel:IsShown() then Refresh() end
end)
