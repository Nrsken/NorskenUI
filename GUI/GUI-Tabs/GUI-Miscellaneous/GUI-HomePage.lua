---@class NRSKNUI
local NRSKNUI = select(2, ...)
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

        local function toggleAnchors()
            if NRSKNUI.Anchors then
                NRSKNUI.Anchors:Toggle()
            end
        end
        local function reloadUI() ReloadUI() end

        local playerNameColored = NRSKNUI:ColorTextByClass(NRSKNUI.MyName, NRSKNUI.MyClass)
        local versionLine = L['Version: '] .. NRSKNUI:ColorTextByTheme(NRSKNUI.Version)
        local profileLine = L['Active Profile: '] .. NRSKNUI:ColorTextByTheme(NRSKNUI.db:GetCurrentProfile())

        -- Card 1: Welcome
        local welcomeCard = page:Card(L['Welcome to NorskenUI'])
        local welcomeRow = welcomeCard:Row(60, 0)
        welcomeRow:Text(L['Hello, '] .. playerNameColored .. '!', {
            width = 1,
            text = { versionLine, profileLine },
            height = 60,
            bgMode = 'hide',
        })

        welcomeCard:Separator()

        local mapIconRow = welcomeCard:Row(rowH)
        mapIconRow:Checkbox(L['Hide Minimap Icon'], {
            width = 1,
            value = db.Minimap.hide,
            msgPopup = true,
            msgText = L['Hide Minimap Icon'],
            callback = function(checked)
                db.Minimap.hide = checked
            end,
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

        welcomeCard:Separator()

        local quickActionRow = welcomeCard:Row(32)
        quickActionRow:Button(L['Toggle Anchors'], { width = 0.5, height = 32, callback = toggleAnchors, })
        quickActionRow:Button(L['Reload UI'], { width = 0.5, height = 32, callback = reloadUI })

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
            bgMode = "hide"
        })

        -- Card 3: Support
        local supportRowH = 34
        local discordText = NRSKNUI:ColorTextByTheme(L['Discord'])
        local githubText = NRSKNUI:ColorTextByTheme(L['GitHub'])
        local supportCard = page:Card(L['Support'])
        local supportInfoRow = supportCard:Row(supportRowH)
        supportInfoRow:Text(NRSKNUI:ColorTextByTheme(L['Found a bug or have a suggestion?']), {
            width = 1,
            text = NRSKNUI:ColorTextByTheme("• ") ..
                L['Join the '] .. discordText .. L[' or open an issue on '] .. githubText .. ".",
            height = supportRowH,
            bgMode = "hide"
        })
    end,
})
