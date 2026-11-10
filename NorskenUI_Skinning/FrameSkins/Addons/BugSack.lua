---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
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
local CHECK_INSET = 4
local TAB_NAMES = { 'BugSackTabAll', 'BugSackTabSession', 'BugSackTabLast', 'BugSackTabOptions' }
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

    prevButton:NCSetHeight(BUTTON_HEIGHT)
    prevButton:ClearAllPoints()
    prevButton:NCSetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', PANEL_PADDING, PANEL_PADDING)

    nextButton:NCSetHeight(BUTTON_HEIGHT)
    nextButton:ClearAllPoints()
    nextButton:NCSetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -PANEL_PADDING, PANEL_PADDING)

    -- Shown on the Options tab in place of the nav buttons, between their spots.
    local wipeButton = _G.BugSackWipeButton
    if wipeButton then
        S:HandleButton(wipeButton)
        wipeButton:NCSetHeight(BUTTON_HEIGHT)
        wipeButton:ClearAllPoints()
        wipeButton:NCSetPoint('LEFT', prevButton, 'RIGHT', BUTTON_GAP, 0)
        wipeButton:NCSetPoint('RIGHT', nextButton, 'LEFT', -BUTTON_GAP, 0)
    end

    -- Only built when AceSerializer is embedded.
    local sendButton = _G.BugSackSendButton
    if not sendButton then return end

    S:HandleButton(sendButton)
    sendButton:NCSetHeight(BUTTON_HEIGHT)
    sendButton:ClearAllPoints()
    sendButton:NCSetPoint('LEFT', prevButton, 'RIGHT', BUTTON_GAP, 0)
    sendButton:NCSetPoint('RIGHT', nextButton, 'LEFT', -BUTTON_GAP, 0)
end

---@param S SkinningModule
local function SkinScroll(S)
    local textArea = _G.BugSackScrollText
    local scroll = textArea and textArea:GetParent() --[[@as (Frame & { ScrollBar: Frame? })?]]
    if not scroll or not scroll.ScrollBar then return end

    S:HandleTrimScrollBar(scroll.ScrollBar)
end

---@param frame Frame
---@return boolean
local function HoldsCheckBox(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType('CheckButton') then return true end
    end
    return false
end

---The Options tab is an unnamed frame on the window: checkboxes, then label + dropdown rows.
---@param S SkinningModule
---@param window Frame
local function SkinOptions(S, window)
    local options
    for _, child in ipairs({ window:GetChildren() }) do
        if child:GetObjectType() == 'Frame' and HoldsCheckBox(child) then
            options = child
            break
        end
    end
    if not options then return end

    for _, child in ipairs({ options:GetChildren() }) do
        if child:IsObjectType('CheckButton') then
            local check = child --[[@as UICheckButtonTemplate]]
            S:HandleCheckBox(check, CHECK_INSET)
            S:HandleAccentFont(check.Text)
        else
            for _, rowChild in ipairs({ child:GetChildren() }) do
                if rowChild.Arrow and rowChild.SetupMenu then
                    ---@cast rowChild WowStyle1DropdownTemplate
                    S:HandleDropdownButton(rowChild)
                end
            end
            for _, region in ipairs({ child:GetRegions() }) do
                if region:IsObjectType('FontString') then
                    ---@cast region FontString
                    S:HandleAccentFont(region)
                end
            end
        end
    end
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
                tab:NCSetPoint('TOPLEFT', previous, 'TOPRIGHT', TAB_OVERLAP, 0)
            else
                tab:NCSetPoint('TOPLEFT', window, 'BOTTOMLEFT', 0, 1)
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
    SkinOptions(S, window)
    SkinTabs(S, window)
end

Skinning:RegisterSkin(ADDON_NAME, ADDON_NAME, function()
    local addon = _G.BugSack
    -- Without !BugGrabber the sack never builds, so there is nothing to hook.
    if not addon or not addon.OpenSack then return end

    -- The window is created on the first open, so the skin has to trail the call rather than run now.
    hooksecurefunc(addon, 'OpenSack', SkinBugSack)
end)
