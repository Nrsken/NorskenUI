---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local Shared = NRSKNUI.GUISharedPages
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

---@param page table
local function BuildUIScalePage(page)
    local db = NRSKNUI.db.profile.UIScale
    page:SetCondition('uiScaleOn', function() return db.Enabled end)

    local uiScaleCard = page:Card(L['UI Scale'])
    local uiScaleRow1 = uiScaleCard:Row(rowH)
    uiScaleRow1:Checkbox(L['Enable UI Scale'], {
        width = 0.5,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['UI Scale'],
        tooltip = L['Disable scaling in other addons to avoid conflicts.'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:SetUIScale()
            page:Refresh()
        end,
    })

    uiScaleRow1:Slider(L['Scale'], {
        width = 0.5,
        min = 0.1,
        max = 2,
        step = 0.01,
        value = db.Scale,
        conditions = { 'uiScaleOn' },
        callback = function(val)
            db.Scale = val
            NRSKNUI:SetScaleValue(db.Scale)
        end,
        callbackOnRelease = true,
    })

    uiScaleCard:Separator()

    local buttonH = 36
    local buttonOffset = -2
    local uiScaleRow2 = uiScaleCard:Row(rowHL, 0)
    uiScaleRow2:Button(L['Auto (Pixel Perfect)'], {
        width = (1 / 3),
        height = buttonH,
        yOffset = buttonOffset,
        tooltip = L['Automatically match your resolution (768 / screen height).'],
        conditions = { 'uiScaleOn' },
        callback = function()
            NRSKNUI:SetScaleValue()
            page:Refresh()
        end,
    })

    uiScaleRow2:Button(L['1080p Scale'], {
        width = (1 / 3),
        height = buttonH,
        yOffset = buttonOffset,
        tooltip = L['Set UI scale for 1080p resolution.'],
        conditions = { 'uiScaleOn' },
        callback = function()
            NRSKNUI:SetScaleValue(NRSKNUI.TenEigthyPixel)
            page:Refresh()
        end,
    })

    uiScaleRow2:Button(L['1440p Scale'], {
        width = (1 / 3),
        height = buttonH,
        yOffset = buttonOffset,
        tooltip = L['Set UI scale for 1440p resolution.'],
        conditions = { 'uiScaleOn' },
        callback = function()
            NRSKNUI:SetScaleValue(NRSKNUI.FourteenFortyPixel)
            page:Refresh()
        end,
    })
end

Shared:RegisterGlobalPage(GUI, NRSKNUI, function(itemKey) NRSKNUI.GUIFrame:ShowGlobalSettings(itemKey) end, {
    {
        key = 'globalUIScale',
        text = L['UI Scale'],
        build = BuildUIScalePage,
    },
})
