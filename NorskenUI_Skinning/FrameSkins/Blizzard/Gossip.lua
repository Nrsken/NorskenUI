---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local pairs = pairs

---@param fontString FontString
local function PaintFontString(fontString)
    fontString:SetFixedColor(true)
    fontString:SetTextColor(1, 1, 1)
end

-- light text the way Blizzard's own dark contrast mode does it: a fixed colour ignores the titles' parchment colour codes
---@param frame table GossipFrame, the theme container's fontStrings set isn't in the stubs
local function PaintFontStrings(frame)
    for fontString in pairs(frame.fontStrings) do
        PaintFontString(fontString)
    end
end

-- BUG: a row filled by scrolling gets no theme pass and keeps QuestFont's black (Blizzard_UIPanels_Game/Shared/GossipFrameShared.lua)
-- every button path ends in Resize, the greeting in Setup
---@param _ table GossipFrame
---@param fontString FontString
local function SetupRow(_, fontString)
    local owner = fontString:GetParent()
    if owner.NUIGossipHooked then return end

    owner.NUIGossipHooked = true
    hooksecurefunc(owner, owner.Resize and 'Resize' or 'Setup', function()
        PaintFontString(fontString)
    end)
end

Skinning:RegisterSkin('Blizzard_UIPanels_Game', 'GossipFrame', function(S)
    local frame = _G.GossipFrame
    if not frame then return end

    S:HandlePortraitFrame(frame)
    S:HandleAccentFont(frame.TitleContainer and frame.TitleContainer.TitleText)

    -- the theme container re-atlases this on every show, alpha holds through that
    frame.Background:SetAlpha(0)

    local panel = frame.GreetingPanel
    panel:NUIStripTextures('ClearHide')
    S:HandleTrimScrollBar(panel.ScrollBar)
    S:HandleButton(panel.GoodbyeButton)

    -- Update fills the list, registering each option's text, then runs UpdateTheme over all of them
    hooksecurefunc(frame, 'UpdateFontStrings', PaintFontStrings)
    hooksecurefunc(frame, 'RegisterFontString', SetupRow)
    PaintFontStrings(frame)
end)
