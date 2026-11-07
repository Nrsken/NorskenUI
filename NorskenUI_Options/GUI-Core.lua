---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class GUIFrame
NRSKNUI.GUIFrame = NRSKNUI.GUIFrame or {}
local Theme = NRSKNUI.Theme
local L = NRSKNUI.Libs.AL

-- Dropdown option lists every tab shares. Dropdown.lua reads value or key, so value serves both.
NRSKNUI.GrowthOptions = {
    { value = 'DOWN',  text = L['Down'] },
    { value = 'UP',    text = L['Up'] },
    { value = 'LEFT',  text = L['Left'] },
    { value = 'RIGHT', text = L['Right'] },
}

local LOGO = 'Interface\\AddOns\\NorskenUI\\Media\\Logo\\'
local TEX = 'Interface\\AddOns\\NorskenCore\\Media\\GUITextures\\'
local SOCIAL = 'Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\'
local LUCIDE = 'Interface\\AddOns\\NorskenCore\\Media\\Lucide\\'

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
                texture = LOGO .. 'logocookingsPT3128x128OT.png',
                size = 128,
                anchor = { 'LEFT', 1, 'RIGHT', -62, -4 },
                color = 'textSecondary'
            },
        },
        -- the raw value stays English, exports and the version check carry it
        version = NRSKNUI.Version == 'Development Version' and L['Development Version'] or NRSKNUI.Version,
        versionAnchor = { 'LEFT', 2, 'RIGHT', -45, -3 },
        versionColor = 'textSecondary',
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
        -- one settings window at a time, the previews follow a single page
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

window:AddHeaderButton({
    icon = LUCIDE .. 'x.png',
    --glow = TEX .. 'NorskenCustomCrossv3_glow.png',
    size = 32,
    --rotation = 45,
    onClick = function()
        window:Hide()
    end,
    tooltip = L['Close Settings'],
})
window:AddHeaderButton({
    icon = LUCIDE .. 'house.png',
    --glow = TEX .. 'HomeButtonv2_glow.png',
    size = 32,
    onClick = function()
        window:ShowPage('homePage')
    end,
    tooltip = L['Open Home Page'],
})
window:AddHeaderButton({
    icon = LUCIDE .. 'anchor.png',
    --glow = TEX .. 'anchor_glow.png',
    size = 32,
    onClick = function()
        if NRSKNUI.Anchors then
            NRSKNUI.Anchors:Toggle()
        end
    end,
    tooltip = L['Open Anchors'],
})
window:AddHeaderButton({
    icon = LUCIDE .. 'paint-bucket.png',
    --glow = TEX .. 'fill_glow.png',
    size = 32,
    onClick = function()
        window:ShowPage('themePage')
    end,
    tooltip = L['Open Theme Settings'],
})
window:AddHeaderButton({
    icon = LUCIDE .. 'eye.png',
    --glow = TEX .. 'eye_glow.png',
    size = 32,
    onClick = function(btn)
        local manager = NRSKNUI.PreviewManager
        if not manager then return end

        manager:SetForceAll(not manager:IsForceAll())
        btn:SetActive(manager:IsForceAll())
    end,
    tooltip = L['Preview Every Display'],
})

--[[ window:AddHeaderButton({
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
    icon = TEX .. 'HomeButtonv2.png',
    glow = TEX .. 'HomeButtonv2_glow.png',
    size = 18,
    onClick = function()
        window:ShowPage('homePage')
    end,
    tooltip = L['Open Home Page'],
})
window:AddHeaderButton({
    icon = TEX .. 'anchor.png',
    glow = TEX .. 'anchor_glow.png',
    size = 22,
    onClick = function()
        if NRSKNUI.Anchors then
            NRSKNUI.Anchors:Toggle()
        end
    end,
    tooltip = L['Open Anchors'],
})
window:AddHeaderButton({
    icon = TEX .. 'fill.png',
    glow = TEX .. 'fill_glow.png',
    size = 18,
    onClick = function()
        window:ShowPage('themePage')
    end,
    tooltip = L['Open Theme Settings'],
})
window:AddHeaderButton({
    icon = TEX .. 'eye.png',
    glow = TEX .. 'eye_glow.png',
    size = 24,
    onClick = function(btn)
        local manager = NRSKNUI.PreviewManager
        if not manager then return end

        manager:SetForceAll(not manager:IsForceAll())
        btn:SetActive(manager:IsForceAll())
    end,
    tooltip = L['Preview Every Display'],
}) ]]

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

-- Footer socials: auto-packed left -> right. The copy prompt stays addon-side.
local function CopyPrompt(title, link, icon, glow)
    NRSKNUI:CreatePrompt({
        title = title,
        text = link,
        editBox = true,
        editBoxLabel = L['CTRL-C to copy'],
        texture = {
            path = icon,
            glow = glow,
            width = 21,
            height = 21,
            color = {
                r = Theme.accent[1],
                g = Theme.accent[2],
                b = Theme.accent[3]
            },
        },
    })
end
window:AddFooterSocial({
    icon = SOCIAL .. 'twitchv2W.png',
    glow = SOCIAL .. 'twitchv2W_glow.png',
    text = 'Twitch',
    width = 62,
    onClick = function()
        CopyPrompt(format(L['Support My %s'], '|cff9146FFTwitch|r'), 'www.twitch.tv/norskenwow', SOCIAL .. 'twitchv2W.png', SOCIAL .. 'twitchv2W_glow.png')
    end,
})
window:AddFooterSocial({
    icon = SOCIAL .. 'discordv2W.png',
    glow = SOCIAL .. 'discordv2W_glow.png',
    text = 'Discord',
    width = 68,
    onClick = function()
        CopyPrompt(format(L['Join My %s'], '|cff5865F2Discord|r'), 'https://discord.com/invite/23bS8pHfuX', SOCIAL .. 'discordv2W.png', SOCIAL .. 'discordv2W_glow.png')
    end,
})
window:AddFooterSocial({
    icon = SOCIAL .. 'github2W.png',
    glow = SOCIAL .. 'github2W_glow.png',
    text = 'GitHub',
    width = 68,
    onClick = function()
        CopyPrompt(format(L['Support My %s'], '|cffffffffGitHub|r'), 'https://github.com/Nrsken/NorskenUI', SOCIAL .. 'github2W.png', SOCIAL .. 'github2W_glow.png')
    end,
})

-- The window already provides Show/Hide/Toggle/IsShown/ShowPage, so it is the public handle.
NRSKNUI.GUIFrame = window
NRSKNUI.OptionWindows = { window } -- every window the anchors step around
NRSKNUI.PageWindows = {}           -- pages living in another window than the main one
