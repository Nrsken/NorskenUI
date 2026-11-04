---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_UnitFrames') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'unitframes_section',
    order = 40,
    type = 'header',
    text = L['Unit Frames'],
    module = 'UnitFrames',
    roles = true,
    defaultExpanded = false,
    items = {
        { id = 'unitFramesGeneral',       text = L['General'] },
        { id = 'unitFramesIndicators',    text = L['Aura Indicators'] },
        { id = 'unitFrames_player',       text = L['Player'] },
        { id = 'unitFrames_target',       text = L['Target'] },
        { id = 'unitFrames_targettarget', text = L['Target of Target'] },
        { id = 'unitFrames_focus',        text = L['Focus'] },
        { id = 'unitFrames_focustarget',  text = L['Focus Target'] },
        { id = 'unitFrames_pet',          text = L['Pet'] },
        { id = 'unitFrames_pettarget',    text = L['Pet Target'] },
        { id = 'unitFrames_boss',         text = L['Boss'] },
        { id = 'unitFrames_party',        text = L['Party'] },
        { id = 'unitFrames_raid1',        text = L['Raid 1'] },
        { id = 'unitFrames_raid2',        text = L['Raid 2'] },
        { id = 'unitFrames_raid3',        text = L['Raid 3'] },
    }
})
