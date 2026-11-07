---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowHL = Theme.rowHeightLast

local format = string.format

local function BuildLanguageView(page)
    local db = NRSKNUI:GetSharedSettings()

    -- languages keep their own names so a reader can always find theirs
    local byKey, options = {}, {}
    for _, language in ipairs(NRSKNUI.LANGUAGES) do
        byKey[language.key] = language
    end
    local client = byKey[NRSKNUI:GetClientLanguage()]
    options[1] = { key = 'auto', text = format(L['Auto (%s)'], client and client.text or NRSKNUI:GetClientLanguage()), font = client and client.font }
    for _, language in ipairs(NRSKNUI.LANGUAGES) do
        options[#options + 1] = { key = language.key, text = language.text, font = language.font }
    end

    local card = page:Card(L['Language'])
    card:Row(rowHL, 0):Dropdown(L['Language'], {
        width = 0.5,
        options = options,
        value = db.Language,
        tooltip = L['Auto follows the game client. Used on every character.'],
        callback = function(key)
            db.Language = key
            NRSKNUI:CreateReloadPrompt(L['The new language shows after a reload.'])
        end,
    })

    card:Separator()

    local infoHeight = 50
    card:Row(infoHeight, 0):Text(NRSKNUI:ColorTextByTheme(L['Language Info']), {
        width = 1,
        height = infoHeight,
        autoHeight = true,
        bgMode = 'hide',
        text = {
            L['Text without a translation in the picked language shows in English.'],
            L['Fonts must include the characters of the picked language, or those letters show as boxes.'],
        },
    })
end

GUI:RegisterPage('globalLanguage', {
    mode = 'clean',
    search = { L['Language'] },
    build = function(page) BuildLanguageView(page) end,
})
