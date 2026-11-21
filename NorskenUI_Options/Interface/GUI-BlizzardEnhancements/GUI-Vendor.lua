---@class NorskenUI
local NRSKNUI = _G.NorskenUI
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local Apply = NRSKNUI.Enum.Apply
local rowHL = Theme.rowHeightLast

local IsAddOnLoaded = C_AddOns.IsAddOnLoaded

if not IsAddOnLoaded('NorskenUI_Interface') then return end

---@param page table
---@param db NRSKNUI.DBProfile.Miscellaneous.Vendor
local function BuildTab(page, db)
    page:SetEnabled(function() return db.Enabled end)

    -- Card 1: Window
    local windowCard = page:Card(L['Window'], 'all')
    local blocksRow = windowCard:Row(rowHL, 0)
    blocksRow:Slider(L['Pages When Expanded'], {
        width = 0.5,
        min = 2,
        max = 4,
        step = 1,
        value = db.Blocks,
        callback = function(value)
            db.Blocks = value
            NRSKNUI.Vendor:ApplySettings(Apply.Layout)
        end
    })
end

GUI:RegisterPage('vendor', {
    mode = 'clean',
    search = {},
    build = function(page)
        local db = NRSKNUI.Vendor.db
        if not db then return end

        BuildTab(page, db)
    end,
})
