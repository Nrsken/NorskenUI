---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class BlizzardMouseoverModule
local BMO = NRSKNUI:GetModule('BlizzardMouseover')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs

local function SidebarItems()
    local items = { { key = 'general', text = L['General Settings'] } }
    for _, element in ipairs(BMO.elementOrder) do
        items[#items + 1] = { key = element.key, text = element.label }
    end

    return items
end

-- Items are pooled, so both branches always set the alpha back.
local function RenderItem(itemFrame, item)
    local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.BlizzardMouseover
    local elementDB = db and db.mouseoverElements[item.key]
    itemFrame.label:SetAlpha((not elementDB or elementDB.Enabled) and 1 or 0.5)
end

local function SearchTerms()
    local terms = {
        { text = L['Alpha When Not Hovered'], itemKey = 'general' },
        { text = L['Fade In Duration'],       itemKey = 'general' },
        { text = L['Fade Out Duration'],      itemKey = 'general' },
    }
    for _, element in ipairs(BMO.elementOrder) do
        terms[#terms + 1] = { text = element.label, itemKey = element.key }
    end

    return terms
end

local function BuildGeneralPage(page, db)
    -- Card 1: Enable
    local enableCard = page:Card(L['Blizzard Mouseover'])
    local enableRow = enableCard:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Blizzard Mouseover'], {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = L['Blizzard Mouseover'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('BlizzardMouseover', checked)
            page:Refresh()
        end,
    })

    -- Card 2: Mouseover Settings
    local settingsCard = page:Card(L['Mouseover Settings'], 'all')
    local alphaRow = settingsCard:Row(rowH)
    alphaRow:Slider(L['Alpha When Not Hovered'], {
        width = 1,
        min = 0,
        max = 1,
        step = 0.05,
        value = db.Alpha,
        tooltip = L['Alpha the element rests at while the mouse is away from it.'],
        callback = function(val)
            db.Alpha = val
            BMO:ApplySettings()
        end,
    })

    local fadeRow = settingsCard:Row(rowHL, 0)
    fadeRow:Slider(L['Fade In Duration'], {
        width = 0.5,
        min = 0,
        max = 2,
        step = 0.05,
        value = db.FadeInDuration,
        callback = function(val) db.FadeInDuration = val end,
    })
    fadeRow:Slider(L['Fade Out Duration'], {
        width = 0.5,
        min = 0,
        max = 2,
        step = 0.05,
        value = db.FadeOutDuration,
        callback = function(val) db.FadeOutDuration = val end,
    })
end

local function BuildElementPage(page, element, elementDB)
    page:SetCondition('elementOn', function() return elementDB.Enabled end)

    local card = page:Card(element.label, 'all')
    local row = card:Row(rowHL, 0)
    row:Checkbox(L['Enable Mouseover'], {
        width = 0.5,
        value = elementDB.Enabled,
        callback = function(checked)
            elementDB.Enabled = checked
            BMO:ApplyElement(element.key)
            page:Refresh()
        end,
    })
    row:Checkbox(L['Hide'], {
        width = 0.5,
        conditions = { 'elementOn' },
        value = elementDB.Hide,
        tooltip = L['Fully hides the element instead of fading it in on mouseover.'],
        callback = function(checked)
            elementDB.Hide = checked
            BMO:ApplyElement(element.key)
            page:Refresh()
        end,
    })
end

GUI:RegisterPage('blizzardMouseover', {
    mode = 'tabs',
    search = SearchTerms(),
    sidebar = {
        items = SidebarItems,
        renderItem = RenderItem,
        default = 'general',
    },
    tabs = function() return {} end,
    build = function(page, _, itemKey)
        if NRSKNUI:ShouldNotLoadModule() then return end
        local db = NRSKNUI.db and NRSKNUI.db.profile.Skinning.BlizzardMouseover
        if not db then return end
        page:SetEnabled(function() return db.Enabled end)

        if itemKey == 'general' then return BuildGeneralPage(page, db) end

        local element = BMO.elements[itemKey]
        if element then BuildElementPage(page, element, db.mouseoverElements[itemKey]) end
    end,
})
