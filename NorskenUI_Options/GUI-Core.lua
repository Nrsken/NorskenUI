---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class GUIFrame
NRSKNUI.GUIFrame = NRSKNUI.GUIFrame or {}
local L = NRSKNUI.Libs.AL

-- Dropdown option lists every tab shares. Dropdown.lua reads value or key, so value serves both.
NRSKNUI.GrowthOptions = {
    { value = 'DOWN',  text = L['Down'] },
    { value = 'UP',    text = L['Up'] },
    { value = 'LEFT',  text = L['Left'] },
    { value = 'RIGHT', text = L['Right'] },
}

local LOGO = 'Interface\\AddOns\\NorskenCore\\Media\\Logo\\'
local UI_MEDIA = 'Interface\\AddOns\\NorskenUI\\Media\\Logo\\'

NRSKNUI.GUIFrame.ReloadText = L['Disabling/Enabling this requires a reload to take full effect.']

-- Fired whenever the GUI edits a position, so the live anchor overlay and its nudge panel follow the sliders.
-- The reverse direction (drag/nudge -> sliders) goes through GUI:RefreshPositionCards().
local positionSync = {
    Changed = function()
        if NRSKNUI.Anchors and NRSKNUI.Anchors:IsActive() then
            NRSKNUI.Anchors:OnExternalPositionChange()
        end
    end,
}

---Gets the GUI instance for NorskenUI, providing access to GUI creation and management functions.
---@return KajiGUIInstance
function NRSKNUI:GetGUI()
    ---@type KajiGUIInstance
    local GUI = self.GUI
    GUI.services.positionSync = positionSync
    return GUI
end

-- a function: each window paints its own copy of the layers
function NRSKNUI.GUILogoConfig()
    return {
        layers = {
            {
                texture = LOGO .. 'logocookingsPT1128x128OT.png',
                glow = LOGO .. 'logocookingsPT1128x128OT_glow.png',
                size = 64,
                anchor = { 'LEFT', 'LEFT', -10, 1 },
                color = 'accent',
                alpha = 0.7
            },
            {
                texture = UI_MEDIA .. 'logocookingsPT3128x128OT.png',
                size = 128,
                anchor = { 'LEFT', 1, 'RIGHT', -62, -4 },
                color = 'textSecondary'
            },
        },
    }
end

local GUI = NRSKNUI:GetGUI()
---@type GUIFrame
local window = GUI:CreateGUIWindow({
    name = 'NorskenUIGUIFrame',
    size = { 950, 700 },
    minSize = { 950, 700 },
    defaultPage = 'homePage',
    logo = NRSKNUI.GUILogoConfig(),
    state = {
        load = function()
            local data = NRSKNUI.db and NRSKNUI.db.global and NRSKNUI.db.global.GUIState
            if data then
                data.currentPage = nil
                data.sidebarExpanded = nil
            end
            return data
        end,
        save = function(data)
            if NRSKNUI.db and NRSKNUI.db.global then
                data.currentPage = nil
                data.sidebarExpanded = nil
                NRSKNUI.db.global.GUIState = data
            end
        end,
    },
    onShow = function()
        NRSKNUI.GUIOpen = true
        if NRSKNUI.PreviewManager then
            NRSKNUI.PreviewManager:SetGUIOpen(true)
        end
    end,
    onClose = function()
        NRSKNUI.GUIOpen = false
        NRSKNUI.ModuleHeader:OnClose()
        NRSKNUI:PromptPendingReload()
        if NRSKNUI.PreviewManager then
            NRSKNUI.PreviewManager:SetGUIOpen(false)
        end
    end,
    onCombatDefer = function()
        NRSKNUI:Print(L['Options will open after combat ends.'])
    end,
})

NRSKNUI.GUIOpen = false

---@param itemKey string? the item to open on
function window:ShowGlobalSettings(itemKey)
    self:ShowPage(NRSKNUI.GUISharedPages.GLOBAL_PAGE, itemKey and { itemKey = itemKey } or nil)
end

local SharedPages = NRSKNUI.GUISharedPages
window:AddHeaderButton(SharedPages:HeaderButton('close', function() window:Hide() end))
window:AddHeaderButton(SharedPages:HeaderButton('home', function() window:ShowPage('homePage') end))
window:AddHeaderButton(SharedPages:HeaderButton('global', function() window:ShowGlobalSettings() end))
window:AddHeaderButton(SharedPages:HeaderButton('theme', function() window:ShowGlobalSettings(SharedPages.THEME_ITEM) end))
window:AddHeaderButton(SharedPages:HeaderButton('anchors', function()
    if NRSKNUI.Anchors then
        NRSKNUI.Anchors:Toggle()
    end
end))
window:AddHeaderButton(SharedPages:HeaderButton('preview', function(btn)
    local manager = NRSKNUI.PreviewManager
    if not manager then return end

    manager:SetForceAll(not manager:IsForceAll())
    btn:SetActive(manager:IsForceAll())
end))

-- Previews follow the open page, so the manager needs to hear about every page change. The host is
-- hooked rather than window:ShowPage, since the sidebar shows pages through the host directly.
if window.content then
    window.content.onPageChanged = function(pageId, previousId)
        NRSKNUI.ModuleHeader:OnPage(pageId) -- before the page lays out, it sizes the header slot
        if NRSKNUI.PreviewManager then
            NRSKNUI.PreviewManager:SetPage(pageId)
        end
        if pageId ~= previousId then NRSKNUI:PromptPendingReload() end
    end
end

SharedPages:AddSupportFooter(window, NRSKNUI)

-- The window already provides Show/Hide/Toggle/IsShown/ShowPage, so it is the public handle.
NRSKNUI.GUIFrame = window
NRSKNUI.PageWindows = {}           -- pages living in another window than the main one
