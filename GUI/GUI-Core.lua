---@class NRSKNUI
---@field GUI KajiGUIInstance
---@field EditMode table?
---@field FrameChooser table?
local NRSKNUI = select(2, ...)
---@class GUIFrame : KajiGUIWindow
---@field ReloadText string
---@field RefreshContent fun(self: GUIFrame): void
---@field OpenPage fun(self: GUIFrame, itemId: string, sectionId: string?, context: any?): void
---@field ApplyThemeColors fun(self: GUIFrame): void
---@field mainFrame Frame
NRSKNUI.GUIFrame = NRSKNUI.GUIFrame or {}
local Theme = NRSKNUI.Theme

local LOGO = 'Interface\\AddOns\\NorskenUI\\Media\\Logo\\'
local TEX = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\'
local SOCIAL = 'Interface\\AddOns\\NorskenUI\\Media\\SupportLogos\\'

NRSKNUI.GUIFrame.ReloadText = 'Disabling/Enabling this requires a reload to take full effect.'

---Gets the GUI instance for NorskenUI, providing access to GUI creation and management functions.
---@return KajiGUIInstance
function NRSKNUI:GetGUI()
    ---@type KajiGUIInstance
    local GUI = self.GUI
    GUI.services.editMode = self.EditMode
    GUI.services.frameChooser = self.FrameChooser
    return GUI
end

local GUI = NRSKNUI:GetGUI()
---@type GUIFrame
local window = GUI:CreateGUIWindow({
    name = 'NorskenUIGUIFrame',
    size = { 950, 700 },
    minSize = { 950, 700 },
    defaultPage = 'homePage',
    logo = {
        layers = {
            {
                texture = LOGO .. 'logocookingsPT1128x128OT.png',
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
        version = NRSKNUI.Version,
        versionAnchor = { 'LEFT', 2, 'RIGHT', -45, -3 },
        versionColor = 'textSecondary',
    },
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
        if NRSKNUI.PreviewManager then
            NRSKNUI.PreviewManager:SetGUIOpen(false)
        end
    end,
    onCombatDefer = function()
        NRSKNUI:Print('Options will open after combat ends.')
    end,
})

NRSKNUI.GUIOpen = false

window:AddHeaderButton({
    icon = TEX .. 'NorskenCustomCrossv3.png',
    size = 22,
    rotation = 45,
    onClick = function()
        window:Hide()
    end,
    tooltip = 'Close Settings',
})
window:AddHeaderButton({
    icon = TEX .. 'HomeButtonv2.png',
    size = 18,
    onClick = function()
        window:ShowPage('homePage')
    end,
    tooltip = 'Open Home Page',
})
window:AddHeaderButton({
    icon = TEX .. 'anchor.png',
    size = 22,
    onClick = function()
        if NRSKNUI.EditMode then
            NRSKNUI.EditMode:Toggle()
        end
    end,
    tooltip = 'Open Anchors',
})
window:AddHeaderButton({
    icon = TEX .. 'fill.png',
    size = 18,
    onClick = function()
        window:ShowPage('themePage')
    end,
    tooltip = 'Open Theme Settings',
})

-- Footer socials: auto-packed left -> right. The copy prompt stays addon-side.
local function CopyPrompt(title, link, icon)
    NRSKNUI:CreatePrompt({
        title = title,
        text = link,
        editBox = true,
        editBoxLabel = 'CTRL-C to copy',
        texture = {
            path = icon,
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
    text = 'Twitch',
    width = 62,
    onClick = function()
        CopyPrompt('Support My |cff9146FFTwitch|r', 'www.twitch.tv/norskenwow', SOCIAL .. 'twitchv2W.png')
    end,
})
window:AddFooterSocial({
    icon = SOCIAL .. 'discordv2W.png',
    text = 'Discord',
    width = 68,
    onClick = function()
        CopyPrompt('Join My |cff5865F2Discord|r', 'https://discord.com/invite/23bS8pHfuX', SOCIAL .. 'discordv2W.png')
    end,
})
window:AddFooterSocial({
    icon = SOCIAL .. 'github2W.png',
    text = 'GitHub',
    width = 68,
    onClick = function()
        CopyPrompt('Support My |cffffffffGitHub|r', 'https://github.com/Nrsken/NorskenUI', SOCIAL .. 'github2W.png')
    end,
})

-- The window already provides Show/Hide/Toggle/IsShown/ShowPage, so it is the public handle.
NRSKNUI.GUIFrame = window
