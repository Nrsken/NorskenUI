---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BlizzardMouseoverModule
local BMO = NRSKNUI:GetModule('BlizzardMouseover')
local L = NRSKNUI.Libs.AL

BMO:RegisterElement('Bags', {
    label = L['Bag Bar'],
    hoverPad = 4,
    frame = function() return BagsBar end,
})
