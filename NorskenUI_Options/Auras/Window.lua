---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI

local PreviewManager = NRSKNUI.PreviewManager
local Shared = NRSKNUI.CDMOptions
local PAGE, SETTINGS_PAGE = Shared.PAGE, Shared.SETTINGS_PAGE

local TEX = 'Interface\\AddOns\\NorskenCore\\Media\\GUITextures\\'

local window ---@type GUIFrame declared first, onShow below refers to it
window = GUI:CreateGUIWindow({
    name = 'NorskenUICDMFrame',
    size = { 950, 700 },
    minSize = { 800, 700 },
    defaultPage = PAGE,
    logo = NRSKNUI.GUILogoConfig(),
    state = {
        load = function()
            return NRSKNUI.db.global.CDMGUIState
        end,
        save = function(data)
            data.currentPage = nil
            NRSKNUI.db.global.CDMGUIState = data
        end,
    },
    onShow = function()
        -- one settings window at a time, the previews follow a single page
        if GUIFrame:IsShown() then
            GUIFrame:Hide()
        end
        NRSKNUI.GUIOpen = true
        PreviewManager:SetGUIOpen(true)
        PreviewManager:SetPage(window.content.currentId)
    end,
    onClose = function()
        NRSKNUI.GUIOpen = false
        NRSKNUI:PromptPendingReload()
        PreviewManager:SetGUIOpen(false)
    end,
    onCombatDefer = function()
        NRSKNUI:Print(L['Options will open after combat ends.'])
    end,
})

window:AddHeaderButton({
    icon = TEX .. 'NorskenCustomCrossv3.png',
    glow = TEX .. 'NorskenCustomCrossv3_glow.png',
    size = 22,
    rotation = 45,
    onClick = function()
        window:Hide()
    end,
    tooltip = L['Close Settings'],
})
window:AddHeaderButton({
    icon = TEX .. 'cogwheel.png',
    size = 18,
    onClick = function()
        window:ShowPage(window.content.currentId == SETTINGS_PAGE and PAGE or SETTINGS_PAGE)
    end,
    tooltip = L['Cooldown & Aura Manager Settings'],
})
window:AddHeaderButton({
    icon = TEX .. 'anchor.png',
    glow = TEX .. 'anchor_glow.png',
    size = 22,
    onClick = function()
        NRSKNUI.Anchors:Enter(CDM)
    end,
    tooltip = L['Open Anchors'],
})
window:AddHeaderButton({
    icon = TEX .. 'eye.png',
    glow = TEX .. 'eye_glow.png',
    size = 24,
    onClick = function(btn)
        PreviewManager:SetForceAll(not PreviewManager:IsForceAll())
        btn:SetActive(PreviewManager:IsForceAll())
    end,
    tooltip = L['Preview Every Display'],
})

window.content.onPageChanged = function(pageId, previousId)
    PreviewManager:SetPage(pageId)
    if pageId ~= previousId then
        NRSKNUI:PromptPendingReload()
    end
end

NRSKNUI.CDMWindow = window
NRSKNUI.OptionWindows[#NRSKNUI.OptionWindows + 1] = window
NRSKNUI.PageWindows[PAGE] = window
NRSKNUI.PageWindows[SETTINGS_PAGE] = window

-- the main window's entry opens this window instead of a page of its own
GUIFrame:AddSidebarEntry({
    id = PAGE,
    order = 20,
    type = 'item',
    text = L['Cooldown & Aura Manager'],
})
GUIFrame.SidebarRedirects[PAGE] = function()
    window:Show()
end
