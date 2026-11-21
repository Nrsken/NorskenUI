---@class NorskenUI
local NRSKNUI = _G.NorskenUI

local MiscVars = NRSKNUI:GetModule('MiscVars')
MiscVars.dbKey = 'Miscellaneous.MiscVars'
MiscVars.Defaults = {
    Enabled = true,

    -- Spell Queue Window per position (these are the only persisted values)
    SpellQueueWindowMelee = nil,
    SpellQueueWindowRanged = nil,
}

local CooldownStrings = NRSKNUI:GetModule('CooldownStrings')
CooldownStrings.dbKey = 'Miscellaneous.CooldownStrings'
CooldownStrings.Defaults = {
    Enabled = true,
    Profiles = {},
}

local QuestTracker = NRSKNUI:GetModule('QuestTracker')
QuestTracker.dbKey = 'Miscellaneous.QuestTracker'
QuestTracker.Defaults = {
    Enabled = false,
    CharacterTabOnly = false,
}
