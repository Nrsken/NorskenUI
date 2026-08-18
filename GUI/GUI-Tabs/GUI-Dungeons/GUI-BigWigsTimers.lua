---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local function BuildTab(page)
    -- Card 1: Enable
    local enableCard = page:Card(L['BigWigs Timers'])
    local textRowSize = 20
    local infoRow = enableCard:Row(textRowSize)
    infoRow:Text(NRSKNUI:ColorTextByTheme(L['Module Information']), {
        autoHeight = true,
        width = 1,
        height = textRowSize,
        bgMode = 'hide',
        text = NRSKNUI:ColorTextByTheme('• ') .. L['This module is currently under development and is not available at the moment.'],
    })
end

GUI:RegisterPage('bwTimers', {
    mode = 'clean',
    search = {},
    build = function(page)
        BuildTab(page)
    end,
})
