---@class NorskenUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
---@class GUIFrame
local GUIFrame = NRSKNUI.GUIFrame
local L = NRSKNUI.Libs.AL

GUIFrame:AddSidebarEntry({
    id = 'qol_section',
    order = 80,
    type = 'header',
    text = L['Quality of Life'],
    defaultExpanded = false,
    items = {
        { id = 'copyAnything',       text = L['Copy Anything'],        module = 'CopyAnything' },
        { id = 'automation',         text = L['Automation'],           module = 'Automation' },
        { id = 'tweaks',             text = L['Tweaks'],               module = 'Tweaks' },
        { id = 'auctionHouseFilter', text = L['Auction House Filter'], module = 'AuctionHouseFilter' },
    }
})
