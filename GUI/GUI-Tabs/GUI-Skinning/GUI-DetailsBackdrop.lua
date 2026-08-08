---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class DetailsBackdropModule
local DBG = NRSKNUI:GetModule('DetailsBackdrop', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local format = string.format
local tonumber = tonumber

local GLOBAL = 'global'
local MAX_BACKDROPS = 5

local function Apply(index)
    if DBG then DBG:ApplyBackdrop(index) end
end

-- Re-renders the sidebar in place, rebuilding the page would release the checkbox still in its callback.
local function RefreshSidebar()
    local window = NRSKNUI.GUIFrame
    local miniSidebar = window and window.content and window.content.miniSidebar
    if miniSidebar then miniSidebar:Render() end
end

local function SidebarItems()
    local items = { { key = GLOBAL, text = L['Global Settings'] } }
    for index = 1, MAX_BACKDROPS do
        items[#items + 1] = { key = tostring(index), text = format(L['Details Backdrop %d'], index) }
    end

    return items
end

-- Items are pooled, so both branches always set the alpha back.
local function RenderItem(itemFrame, item)
    local backdrops = NRSKNUI.db and NRSKNUI.db.profile.Skinning.DetailsBackdrop.backdrops
    local bgDB = backdrops and backdrops[tonumber(item.key)]
    itemFrame.label:SetAlpha((not bgDB or bgDB.Enabled) and 1 or 0.5)
end

local function BuildGlobalPage(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Details Backdrop'])
    local enableRow = enableCard:Row(rowH)
    enableRow:Checkbox(L['Enable Details Backdrop'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Details Backdrop'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('DetailsBackdrop', checked)
            RefreshSidebar()
            page:Refresh()
        end,
    })

    local infoRow = enableCard:Row(76, 0)
    infoRow:Text(L['About Details Backdrops'], {
        width = 1,
        master = true,
        text = {
            L['Draws a NorskenUI backdrop behind each of your Details windows'],
            L['Each backdrop is configured on its own page and can be moved with the anchors'],
            L['Auto size resizes the Details window itself to sit inside the backdrop'],
        },
        height = 76,
        bgMode = 'hide',
    })
end

-- Size Settings Tab.
local function BuildSizeTab(page, index, bgDB)
    page:SetCondition('backdrop', function() return bgDB.Enabled end)
    page:SetCondition('autoSize', function() return bgDB.autoSize end)
    page:SetCondition('manualSize', function() return not bgDB.autoSize end)

    -- Card 1: Enable
    local enableCard = page:Card(format(L['Details Backdrop %d'], index))
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable This Backdrop'], {
        width = 1,
        master = true,
        value = bgDB.Enabled,
        callback = function(checked)
            bgDB.Enabled = checked
            Apply(index)
            RefreshSidebar()
            page:Refresh()
        end,
    })

    -- Card 2: Size Mode
    local sizeCard = page:Card(L['Size Mode'], 'backdrop')
    local modeRow = sizeCard:Row(rowH)
    modeRow:Checkbox(L['Auto Size To Details Window'], {
        width = 1,
        value = bgDB.autoSize,
        callback = function(checked, revert)
            if not checked then
                bgDB.autoSize = false
                Apply(index)
                page:Refresh()
                return
            end

            NRSKNUI:CreatePrompt({
                title = L['Details Override'],
                text = L['This will override your current Details sizing. Are you sure?'],
                acceptText = L['Yes'],
                cancelText = L['Cancel'],
                onAccept = function()
                    bgDB.autoSize = true
                    Apply(index)
                    page:Refresh()
                end,
                onCancel = function() revert(true) end,
            })
        end,
    })

    local barsRow = sizeCard:Row(rowH)
    barsRow:Slider(L['Amount Of Bars To Show'], {
        width = 1,
        conditions = { 'autoSize' },
        min = 1,
        max = 25,
        step = 1,
        value = bgDB.detailsBars,
        callback = function(val)
            bgDB.detailsBars = val; Apply(index)
        end,
    })

    sizeCard:Separator()

    local manualRow = sizeCard:Row(rowHL, 0)
    manualRow:Slider(L['Backdrop Width'], {
        width = 0.5,
        conditions = { 'manualSize' },
        min = 10,
        max = 1000,
        step = 1,
        value = bgDB.width,
        callback = function(val)
            bgDB.width = val; Apply(index)
        end,
    })
    manualRow:Slider(L['Backdrop Height'], {
        width = 0.5,
        conditions = { 'manualSize' },
        min = 10,
        max = 1000,
        step = 1,
        value = bgDB.height,
        callback = function(val)
            bgDB.height = val; Apply(index)
        end,
    })
end

-- Style Settings Tab.
local function BuildStyleTab(page, index, bgDB)
    page:SetCondition('backdrop', function() return bgDB.Enabled end)

    local colorCard = page:Card(L['Colors'], 'backdrop')
    local colorRow = colorCard:Row(rowHL, 0)
    colorRow:ColorPicker(L['Backdrop Color'], {
        width = 0.5,
        value = bgDB.BackgroundColor,
        callback = function(r, g, b, a)
            bgDB.BackgroundColor = { r, g, b, a }; Apply(index)
        end,
    })
    colorRow:ColorPicker(L['Border Color'], {
        width = 0.5,
        value = bgDB.BorderColor,
        callback = function(r, g, b, a)
            bgDB.BorderColor = { r, g, b, a }; Apply(index)
        end,
    })
end

-- Position Settings Tab.
local function BuildPositionTab(page, index, bgDB)
    page:SetCondition('backdrop', function() return bgDB.Enabled end)

    page:PositionCard({
        db = bgDB,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = function() Apply(index) end,
    }, 'backdrop')
end

GUI:RegisterPage('detailsBackdrop', {
    mode = 'tabs',
    search = {},
    sidebar = {
        items = SidebarItems,
        renderItem = RenderItem,
        default = GLOBAL,
    },
    tabs = function(itemKey)
        if itemKey == GLOBAL then return {} end

        return {
            { id = 'size',     text = L['Size'] },
            { id = 'style',    text = L['Style'] },
            { id = 'position', text = L['Position Settings'] },
        }
    end,
    build = function(page, tabId, itemKey)
        local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.DetailsBackdrop
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if itemKey == GLOBAL then return BuildGlobalPage(page, db) end

        local index = tonumber(itemKey)
        local bgDB = index and db.backdrops[index]
        if not bgDB then return end

        if tabId == 'size' then
            BuildSizeTab(page, index, bgDB)
        elseif tabId == 'style' then
            BuildStyleTab(page, index, bgDB)
        elseif tabId == 'position' then
            BuildPositionTab(page, index, bgDB)
        end
    end,
})
