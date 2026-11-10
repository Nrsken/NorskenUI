---@class NRSKNUI
local NRSKNUI = _G.NorskenUI

local ReloadUI = ReloadUI

-- Commands --

NRSKNUI:RegisterCommands({ '/nui', '/norskenui' }, {
    guireset = function(addon) addon:ResetGUIState() end, -- the word before reset, kept for old macros
})

-- /rl instead of /reload
SLASH_NRSKNUI_RL1 = '/rl'
SlashCmdList['NRSKNUI_RL'] = function() ReloadUI() end
