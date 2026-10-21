---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowHL = Theme.rowHeightLast

local function BuildGlobalView(page)
    local fontDB = NRSKNUI.db.profile.globalMedia.profileFont

    page:SetCondition('globFontON', function() return fontDB.Enabled end)

    local globalCard = page:Card(L['Global Font'])
    local globalRow = globalCard:Row(rowHL, 0)
    globalRow:Checkbox(L['Use Global Font'], {
        width = 0.5,
        value = fontDB.Enabled,
        msgPopup = true,
        msgText = L['Global Font'],
        callback = function(checked)
            fontDB.Enabled = checked
            NRSKNUI:ApplyToAllModules()
            NRSKNUI:RefreshFontStyles()
            page:Refresh()
        end,
    })
    globalRow:Dropdown(L['Font'], {
        width = 0.5,
        media = 'font',
        value = fontDB.FontFace,
        searchable = true,
        conditions = { 'globFontON' },
        callback = function(key)
            fontDB.FontFace = key
            NRSKNUI:ApplyToAllModules()
            NRSKNUI:RefreshFontStyles()
            NRSKNUI:SendMessage('NRSKNUI_PROFILE_FONT_CHANGED')
        end,
    })

    globalCard:Separator()

    local infoHeight = 50
    globalCard:Row(infoHeight, 0):Text(NRSKNUI:ColorTextByTheme(L['Global Font Info']), {
        width = 1,
        height = infoHeight,
        autoHeight = true,
        bgMode = 'hide',
        text = {
            L['Font selected above is applied to all modules and blizzard texts that support it.'],
            L['Each module can override the global font with its own font face.'],
        },
    })
end

GUI:RegisterPage('globalFonts', {
    mode = 'clean',
    search = { L['Use Global Font'] },
    build = function(page) BuildGlobalView(page) end,
})
