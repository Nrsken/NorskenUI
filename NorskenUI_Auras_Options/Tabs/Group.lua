---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local IconPicker = NRSKNUI.CDMIconPicker
local rowHL = Theme.rowHeightLast

local tostring = tostring
local tonumber = tonumber

local Shared = NRSKNUI.CDMOptions
local Applier, PositionCard, RefreshTree = Shared.Applier, Shared.PositionCard, Shared.RefreshTree

local ANCHOR_ROLES = {
    { value = 'none',      text = L['None'] },
    { value = 'primary',   text = L['Primary'] },
    { value = 'secondary', text = L['Secondary'] },
}

local function ScheduleAnchorUpdate()
    CDM:SendMessage('NRSKNUI_CDM_LAYOUT_CHANGED')
end

---@param page table
---@param id string
local function BuildGroupTab(page, id)
    local display = CDM:Get(id)
    local apply = Applier(id)

    if display.type == 'dynamicgroup' then
        page:DynamicGroupCard({ title = L['Dynamic Group Settings'], db = display.Layout, onChangeCallback = apply })
        page:Card(L['Unit Frame Anchor'], 'all'):Row(rowHL, 0):Dropdown(L['Anchor Role'], {
            width = 1,
            options = ANCHOR_ROLES,
            value = display.UFAnchor or 'none',
            tooltip = L['The unit frame anchor follows the loaded group with this role. Give one group per class or spec the Primary role.'],
            callback = function(value)
                display.UFAnchor = value ~= 'none' and value or nil
                ScheduleAnchorUpdate()
            end,
        })
    end

    local iconRow = page:Card(L['Group Icon'], 'all'):Row(rowHL, 0)
    iconRow:EditBox(L['Icon ID'], {
        width = 0.9,
        tooltip = L['The icon this group shows in the list. Empty uses its first icon.'],
        value = display.Icon and tostring(display.Icon) or '',
        callback = function(text)
            display.Icon = tonumber(text)
            RefreshTree()
        end,
    })
    IconPicker:BrowseButton(iconRow, display.Icon, function()
        IconPicker:Open(display.Icon, function(texture)
            display.Icon = texture
            RefreshTree()
        end)
    end)

    PositionCard(page, id)
end

Shared.BuildGroupTab = BuildGroupTab
Shared.ScheduleAnchorUpdate = ScheduleAnchorUpdate
