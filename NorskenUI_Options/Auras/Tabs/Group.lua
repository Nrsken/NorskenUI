---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenAuras') then return end
---@class CDMModule
local CDM = NRSKNUI:GetModule('CDM')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local IconPicker = NRSKNUI.CDMIconPicker
local rowHL = Theme.rowHeightLast

local tostring = tostring
local tonumber = tonumber

local Shared = NRSKNUI.CDMOptions
local Applier, PositionConfig, RefreshTree = Shared.Applier, Shared.PositionConfig, Shared.RefreshTree

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
    local Section = NRSKNUI.CDMDisplayTab.Section
    local dynamic = display.type == 'dynamicgroup'
    local grow = dynamic and display.Layout.Grow

    page:Card(L['Group'], 'all'):Rebuild(function(card)
        if dynamic and Section(card, 'groupLayout', L['Dynamic Group Settings']) then
            card:Premade('DynamicGroupCard', {
                db = display.Layout,
                -- a chained group never reads the limit; asked on every rebuild, as switching to Grid lifts it
                limitNotice = function()
                    return CDM:WantsChain(id) and {
                        level = 'info',
                        title = L['Limit Information'],
                        text = L["Auras and texts are secret, so we can't count how many are showing. Use Grid if you need a limit."],
                    } or nil
                end,
                onChangeCallback = function()
                    -- a picked point belongs to the direction it was picked for
                    if display.Layout.Grow ~= grow then
                        grow = display.Layout.Grow
                        display.Position.SelfPoint = nil
                    end
                    apply()
                end,
            })
        end

        if dynamic and Section(card, 'groupAnchor', L['Unit Frame Anchor']) then
            card:Row(rowHL, 0):Dropdown(L['Anchor Role'], {
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

        if Section(card, 'groupIcon', L['Group Icon']) then
            local iconRow = card:Row(rowHL, 0)
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
        end

        if Section(card, 'groupPosition', L['Position and Size Settings']) then
            card:Premade('PositionCard', PositionConfig(id))
        end
    end)
end

Shared.BuildGroupTab = BuildGroupTab
Shared.ScheduleAnchorUpdate = ScheduleAnchorUpdate
