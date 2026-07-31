---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs
local format = string.format
local tinsert = table.insert

-- GUI-only inherit sentinel: dropdowns show it as 'Global (...)', the db stores nil.
local GLOBAL = '__GLOBAL'

local ANCHOR_POINTS = {
    { key = 'TOPLEFT',     text = L['Top Left'] },
    { key = 'TOP',         text = L['Top'] },
    { key = 'TOPRIGHT',    text = L['Top Right'] },
    { key = 'LEFT',        text = L['Left'] },
    { key = 'CENTER',      text = L['Center'] },
    { key = 'RIGHT',       text = L['Right'] },
    { key = 'BOTTOMLEFT',  text = L['Bottom Left'] },
    { key = 'BOTTOM',      text = L['Bottom'] },
    { key = 'BOTTOMRIGHT', text = L['Bottom Right'] },
}

-- Slug is a separate axis here (a checkbox globally, unavailable on specials), so it stays out.
-- globalLabel adds the inherit sentinel in front for the specials dropdown.
local function OutlineOptions(globalLabel)
    local options = NRSKNUI:GetOutlineOptions()
    if globalLabel then
        tinsert(options, 1, { value = GLOBAL, text = format('Global (%s)', globalLabel) })
    end
    return options
end

local function BuildGlobalView(page)
    local media = NRSKNUI.db.profile.globalMedia
    local fontDB = media.profileFont
    local blizzDB = media.blizzardFonts

    page:SetCondition('globFontON', function() return fontDB.Enabled end)
    page:SetCondition('blizzFontsON', function() return blizzDB.Enabled end)

    local globalCard = page:Card(L['Global Font'])
    local globalRow = globalCard:Row(rowHL, 0)
    globalRow:Checkbox(L['Use Global Font'], {
        width = 0.5,
        value = fontDB.Enabled,
        msgPopup = true,
        msgText = L['Global Font'],
        callback = function(checked)
            fontDB.Enabled = checked
            NRSKNUI:ApplyToAllModules()
            NRSKNUI:RefreshFontStyles()
            page:Refresh()
        end,
    })
    globalRow:Dropdown(L['Font'], {
        width = 0.5,
        media = 'font',
        value = fontDB.FontFace,
        searchable = true,
        conditions = { 'globFontON' },
        callback = function(key)
            fontDB.FontFace = key
            NRSKNUI:ApplyToAllModules()
            NRSKNUI:RefreshFontStyles()
            NRSKNUI:ApplyBlizzardFonts()
        end,
    })

    local blizzCard = page:Card(L['Blizzard UI Font'])
    local blizzRow1 = blizzCard:Row(rowH)
    blizzRow1:Checkbox(L['Style Blizzard Fonts'], {
        width = 0.5,
        value = blizzDB.Enabled,
        msgPopup = true,
        msgText = L['Blizzard UI Font'],
        tooltip = L["Apply your global font face across Blizzard's UI, adding an outline where it reads cleanly. Big display text and unsafe fonts keep their native outline."],
        callback = function(checked)
            blizzDB.Enabled = checked
            NRSKNUI:ApplyBlizzardFonts(true)
            page:Refresh()
        end,
    })
    blizzRow1:Dropdown(L['Outline'], {
        width = 0.5,
        options = OutlineOptions(),
        value = blizzDB.Outline,
        conditions = { 'blizzFontsON' },
        callback = function(key)
            blizzDB.Outline = key
            NRSKNUI:ApplyBlizzardFonts()
        end,
    })

    local blizzRow2 = blizzCard:Row(rowH)
    blizzRow2:Checkbox(L['Use Slug Rendering'], {
        width = 0.5,
        value = blizzDB.Slug,
        tooltip = L['Higher-quality glyph rendering on supported fonts, combined with the outline above where enabled.'],
        conditions = { 'blizzFontsON' },
        callback = function(checked)
            blizzDB.Slug = checked
            NRSKNUI:ApplyBlizzardFonts()
        end,
    })
    blizzRow2:Checkbox(L['Hide Shadows'], {
        width = 0.5,
        value = blizzDB.HideShadow,
        tooltip = L['Remove the drop shadow from styled fonts for a flatter look. Native shadows return when unchecked.'],
        conditions = { 'blizzFontsON' },
        callback = function(checked)
            blizzDB.HideShadow = checked
            NRSKNUI:ApplyBlizzardFonts()
        end,
    })

    local function FamilySlider(row, famKey, label)
        row:Slider(label, {
            width = 0.5,
            min = -8,
            max = 8,
            step = 1,
            value = blizzDB.Families[famKey] or 0,
            conditions = { 'blizzFontsON' },
            callback = function(val)
                blizzDB.Families[famKey] = val
                NRSKNUI:ApplyBlizzardFonts(true)
            end,
        })
    end

    local blizzRow3 = blizzCard:Row(rowH)
    FamilySlider(blizzRow3, 'small', L['Small Size'])
    FamilySlider(blizzRow3, 'medium', L['Medium Size'])

    local blizzRow4 = blizzCard:Row(rowHL, 0)
    FamilySlider(blizzRow4, 'large', L['Large Size'])
    FamilySlider(blizzRow4, 'huge', L['Huge Size'])
end

local function BuildSpecialView(page, entry)
    local media = NRSKNUI.db.profile.globalMedia
    local fontDB = media.profileFont
    local blizzDB = media.blizzardFonts
    local sdb = blizzDB.Specials[entry.key]
    local BM = NRSKNUI:GetModule('BlizzardMessages', true)

    local function Apply()
        NRSKNUI:ApplySpecialFonts()
        if (entry.position or entry.hideLabel) and BM then
            BM:ApplySettings()
        end
    end

    page:SetCondition('spEnabled', function() return sdb.Enabled end)

    local card = page:Card(entry.label)
    local enableRow = card:Row(rowH)
    enableRow:Checkbox(L['Enable'], {
        width = entry.preview and (2 / 3) or 1,
        value = sdb.Enabled,
        msgPopup = true,
        msgText = format('%s %s', entry.label, L['Font']),
        callback = function(checked)
            sdb.Enabled = checked
            Apply()
            page:Refresh()
        end,
    })
    if entry.preview then
        enableRow:Button(L['Preview'], {
            width = (1 / 3),
            height = 30,
            yOffset = -6,
            conditions = { 'spEnabled' },
            callback = function()
                if BM and BM[entry.preview] then BM[entry.preview](BM) end
            end,
        })
    end
    card:Separator()

    local fontRow = card:Row(rowH)
    fontRow:Dropdown(L['Font'], {
        width = entry.noOutline and 1 or 0.5,
        media = 'font',
        options = { { key = GLOBAL, text = format('Global (%s)', fontDB.FontFace) } },
        value = sdb.FontFace or GLOBAL,
        searchable = true,
        conditions = { 'spEnabled' },
        callback = function(key)
            sdb.FontFace = key ~= GLOBAL and key or nil
            Apply()
        end,
    })
    if not entry.noOutline then
        fontRow:Dropdown(L['Outline'], {
            width = 0.5,
            options = OutlineOptions(NRSKNUI:GetOutlineLabel(blizzDB.Outline)),
            value = sdb.Outline or GLOBAL,
            conditions = { 'spEnabled' },
            tooltip = L['Global follows the Blizzard UI outline and slug settings. Picking an explicit outline turns slug rendering off for this element.'],
            callback = function(key)
                sdb.Outline = key ~= GLOBAL and key or nil
                Apply()
            end,
        })
    end

    if entry.sizeRange then
        local sizeRow = card:Row(rowH)
        sizeRow:Slider(L['Font Size'], {
            width = 1,
            min = entry.sizeRange[1],
            max = entry.sizeRange[2],
            step = 1,
            value = sdb.Size,
            conditions = { 'spEnabled' },
            callback = function(val)
                sdb.Size = val
                Apply()
            end,
        })
    end

    if entry.hideLabel then
        local hideRow = card:Row(rowH)
        hideRow:Checkbox(L[entry.hideLabel], {
            width = 1,
            value = sdb.Hide,
            conditions = { 'spEnabled' },
            callback = function(checked)
                sdb.Hide = checked
                Apply()
            end,
        })
    end

    if entry.note then
        local noteHeight = 40
        local noteRow = card:Row(noteHeight, 0)
        noteRow:Text(nil, {
            width = 1,
            text = L[entry.note],
            height = noteHeight,
            bgMode = 'hide',
        })
    else
        card:Row(Theme.rowHeightSeparator, 0)
    end

    if entry.position then
        local posCard = page:Card(L['Position'], 'spEnabled')
        local anchorRow = posCard:Row(rowH)
        anchorRow:Dropdown(L['Anchor'], {
            width = 1,
            options = ANCHOR_POINTS,
            value = sdb.Position.Anchor,
            callback = function(key)
                sdb.Position.Anchor = key
                Apply()
            end,
        })
        posCard:Separator()
        local offsetRow = posCard:Row(rowHL, 0)
        offsetRow:Slider(L['X Offset'], {
            width = 0.5,
            min = -500,
            max = 500,
            step = 1,
            value = sdb.Position.X,
            callback = function(val)
                sdb.Position.X = val
                Apply()
            end,
        })
        offsetRow:Slider(L['Y Offset'], {
            width = 0.5,
            min = -500,
            max = 500,
            step = 1,
            value = sdb.Position.Y,
            callback = function(val)
                sdb.Position.Y = val
                Apply()
            end,
        })
    end
end

local items = { { key = 'globalFonts', text = L['Global Fonts'] } }
for _, entry in ipairs(NRSKNUI.SpecialFonts) do
    items[#items + 1] = { key = entry.key, text = entry.label }
end

GUI:RegisterPage('globalFonts', {
    mode = 'clean',
    search = {
        L['Use Global Font'], L['Style Blizzard Fonts'], L['Outline'], L['Use Slug Rendering'],
        L['Hide Shadows'], L['Small Size'], L['Medium Size'], L['Large Size'], L['Huge Size'], L['Font Size'],
    },
    sidebar = { items = items },
    build = function(page, _, itemKey)
        if not itemKey or itemKey == 'globalFonts' then
            BuildGlobalView(page)
            return
        end
        for _, entry in ipairs(NRSKNUI.SpecialFonts) do
            if entry.key == itemKey then
                BuildSpecialView(page, entry)
                return
            end
        end
    end,
})
