---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G
local ipairs = ipairs
local hooksecurefunc = hooksecurefunc

local ADDON_NAME = 'BugSack'
local PANEL_PADDING = 6
local BUTTON_HEIGHT = 22
local BUTTON_GAP = 4
local TAB_OVERLAP = -1
local TAB_NAMES = { 'BugSackTabAll', 'BugSackTabSession', 'BugSackTabLast' }
local skinned = false

---@param S SkinningModule
---@param container Frame
local function SkinTitleBar(S, container)
    for _, child in ipairs({ container:GetChildren() }) do
        if child:IsObjectType('EditBox') then
            ---@cast child EditBox
            S:HandleEditBox(child)
        elseif child.GetFontString and child:GetFontString() then
            ---@cast child Button
            local normal, highlight = child:GetNormalFontObject(), child:GetHighlightFontObject()
            if normal then child:SetNormalFontObject(S:GetAccentFont(normal)) end
            if highlight then child:SetHighlightFontObject(S:GetOutlineFont(highlight)) end
        end
    end

    for _, region in ipairs({ container:GetRegions() }) do
        if region:IsObjectType('FontString') then
            ---@cast region FontString
            S:HandleOutlineFont(region)
        end
    end
end

---@param S SkinningModule
---@param window Frame
local function SkinNavButtons(S, window)
    local prevButton, nextButton = _G.BugSackPrevButton, _G.BugSackNextButton

    S:HandleButton(prevButton)
    S:HandleButton(nextButton)

    prevButton:NUISetPixelHeight(BUTTON_HEIGHT)
    prevButton:ClearAllPoints()
    prevButton:NUISetPixelPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', PANEL_PADDING, PANEL_PADDING)

    nextButton:NUISetPixelHeight(BUTTON_HEIGHT)
    nextButton:ClearAllPoints()
    nextButton:NUISetPixelPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -PANEL_PADDING, PANEL_PADDING)

    -- Only built when AceSerializer is embedded.
    local sendButton = _G.BugSackSendButton
    if not sendButton then return end

    S:HandleButton(sendButton)
    sendButton:NUISetPixelHeight(BUTTON_HEIGHT)
    sendButton:ClearAllPoints()
    sendButton:NUISetPixelPoint('LEFT', prevButton, 'RIGHT', BUTTON_GAP, 0)
    sendButton:NUISetPixelPoint('RIGHT', nextButton, 'LEFT', -BUTTON_GAP, 0)
end

---@param S SkinningModule
local function SkinScroll(S)
    local textArea = _G.BugSackScrollText
    local scroll = textArea and textArea:GetParent() --[[@as (Frame & { ScrollBar: Frame? })?]]
    if not scroll or not scroll.ScrollBar then return end

    S:HandleTrimScrollBar(scroll.ScrollBar)
end

---@param S SkinningModule
---@param window Frame
local function SkinTabs(S, window)
    local previous
    for _, name in ipairs(TAB_NAMES) do
        local tab = _G[name]
        if tab then
            S:HandleTab(tab, true)

            tab:ClearAllPoints()
            if previous then
                tab:NUISetPixelPoint('TOPLEFT', previous, 'TOPRIGHT', TAB_OVERLAP, 0)
            else
                tab:NUISetPixelPoint('TOPLEFT', window, 'BOTTOMLEFT', 0, 1)
            end
            previous = tab
        end
    end
end

local function SkinBugSack()
    if skinned then return end

    local window = _G.BugSackFrame
    if not window then return end
    skinned = true

    local S = Skinning
    S:HandlePortraitFrame(window, S.PortraitTabSize.Small)

    if window.TitleContainer then SkinTitleBar(S, window.TitleContainer) end
    SkinNavButtons(S, window)
    SkinScroll(S)
    SkinTabs(S, window)
end

Skinning:RegisterSkin(ADDON_NAME, ADDON_NAME, function()
    local addon = _G.BugSack
    -- Without !BugGrabber the sack never builds, so there is nothing to hook.
    if not addon or not addon.OpenSack then return end

    -- The window is created on the first open, so the skin has to trail the call rather than run now.
    hooksecurefunc(addon, 'OpenSack', SkinBugSack)
end)
