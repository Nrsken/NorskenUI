---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

GUI:RegisterPage('homePage', {
    mode = 'clean',
    search = {},
    build = function(page)
        local db = NRSKNUI.db.profile
        if not db then return end

        -- Card 1: Welcome
        local welcomeCard = NRSKNUI.GUISharedPages:WelcomeCard(page, NRSKNUI, L['Welcome to NorskenUI'], {
            L['Active Profile: '] .. NRSKNUI:ColorTextByTheme(NRSKNUI.db:GetCurrentProfile()),
        })

        local loginMsgRow = welcomeCard:Row(rowH)
        loginMsgRow:Checkbox(L['Hide Login Message'], {
            width = 1,
            value = db.Minimap.hideMessage,
            msgPopup = true,
            msgText = L['Hide Login Message'],
            callback = function(checked)
                db.Minimap.hideMessage = checked
            end,
        })

        NRSKNUI.GUISharedPages:QuickActions(welcomeCard, NRSKNUI)

        -- Card 2: ElvUI Integration
        local elvuiCard = page:Card(L['ElvUI Integration'])
        local elvuiRow = elvuiCard:Row(rowH)
        elvuiRow:Checkbox(L['Use ElvUI Skinning'], {
            width = 1,
            value = db.UseElvUI.Enabled,
            msgPopup = true,
            msgText = L['Use ElvUI Skinning'],
            callback = function(checked)
                db.UseElvUI.Enabled = checked
                NRSKNUI:CreateReloadPrompt(NRSKNUI.GUIFrame.ReloadText)
            end,
        })

        elvuiCard:Separator()

        local infoRowH = 50
        local infoRow = elvuiCard:Row(infoRowH)
        infoRow:Text(NRSKNUI:ColorTextByTheme(L['Information']), {
            width = 1,
            text = NRSKNUI:ColorTextByTheme("• ") ..
                L['Disables all skinning modules when ElvUI is loaded.\n  This way you can still use the non skinning features of the addon without conflict.'],
            height = infoRowH,
            autoHeight = true,
            bgMode = "hide"
        })

        -- Card 3: Support
        NRSKNUI.GUISharedPages:SupportCard(page, NRSKNUI)
    end,
})
