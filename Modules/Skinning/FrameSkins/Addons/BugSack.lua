---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G
local ipairs = ipairs
local hooksecurefunc = hooksecurefunc

local ADDON_NAME = 'BugSack'

local PANEL_PADDING = 6
local TITLE_BAR_HEIGHT = 24
local CONTENT_GAP = 4

local BUTTON_HEIGHT = 22
local BUTTON_GAP = 4

local SCROLLBAR_INSET = 22

local TAB_OVERLAP = -1
local TAB_NAMES = { 'BugSackTabAll', 'BugSackTabSession', 'BugSackTabLast' }

local skinned = false

---The sack's only unnamed children: the filter box, the close button and the title/drag label.
---Each is matched on what it actually carries, so anything unrecognised is left alone.
---@param S SkinningModule
---@param window Frame
local function SkinAnonymousChildren(S, window)
    for _, child in ipairs({ window:GetChildren() }) do
        -- CreatePanelBackdrop has already parented our own unnamed frame here.
        if not child:GetName() and child ~= window.NUIBackdrop then
            if child:IsObjectType('EditBox') then
                -- A real BackdropTemplate backdrop, which HandleEditBox's region strip cannot reach.
                if child.SetBackdrop then child:SetBackdrop(nil) end
                S:HandleEditBox(child)
            elseif child.GetNormalTexture and child:GetNormalTexture() then
                -- UIPanelCloseButton is the only one of the three carrying button art.
                ---@cast child Button
                S:HandleCloseButton(child, window)
            elseif child.GetFontString and child:GetFontString() then
                ---@cast child Button
                local normal, highlight = child:GetNormalFontObject(), child:GetHighlightFontObject()
                if normal then child:SetNormalFontObject(S:GetAccentFont(normal)) end
                if highlight then child:SetHighlightFontObject(S:GetOutlineFont(highlight)) end
            end
        end
    end
end
    
---@param S SkinningModule
---@param window Frame
local function SkinHeaderLabels(S, window)
    for _, region in ipairs({ window:GetRegions() }) do
        if region:IsObjectType('FontString') then
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

---The sack pins its scroll child to a hardcoded 750, which no longer matches the re-anchored frame.
---@param scroll ScrollFrame
local function SyncTextAreaWidth(scroll)
    local textArea = _G.BugSackScrollText
    if not textArea then return end

    local width = scroll:GetWidth()
    if width > 0 then textArea:SetWidth(width) end
end

---@param S SkinningModule
---@param window Frame
local function SkinScroll(S, window)
    local scroll = _G.BugSackScroll
    if not scroll then return end

    S:HandleScrollBar(_G.BugSackScrollScrollBar)

    scroll:ClearAllPoints()
    scroll:NUISetPixelPoint('TOPLEFT', window, 'TOPLEFT', PANEL_PADDING, -(TITLE_BAR_HEIGHT + CONTENT_GAP))
    scroll:NUISetPixelPoint('BOTTOMRIGHT', _G.BugSackNextButton, 'TOPRIGHT', -SCROLLBAR_INSET, CONTENT_GAP)

    scroll:HookScript('OnSizeChanged', SyncTextAreaWidth)
    SyncTextAreaWidth(scroll)
end

---@param S SkinningModule
---@param window Frame
local function SkinTabs(S, window)
    local previous
    for _, name in ipairs(TAB_NAMES) do
        local tab = _G[name]
        if tab then
            S:HandleTab(tab)

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

    window:NUIStripTextures()
    S:CreatePanelBackdrop(window)

    SkinAnonymousChildren(S, window)
    SkinHeaderLabels(S, window)
    SkinNavButtons(S, window)
    SkinScroll(S, window)
    SkinTabs(S, window)
end

Skinning:RegisterSkin(ADDON_NAME, ADDON_NAME, function()
    local addon = _G.BugSack
    -- Without !BugGrabber the sack never builds, so there is nothing to hook.
    if not addon or not addon.OpenSack then return end

    -- The window is created on the first open, so the skin has to trail the call rather than run now.
    hooksecurefunc(addon, 'OpenSack', SkinBugSack)
end)
