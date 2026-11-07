---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Skinning') then return end
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast
---@class BlizzardMessagesModule
local BlizzardMessages = NRSKNUI:GetModule('BlizzardMessages')
local function ApplySettings()
    BlizzardMessages:ApplySettings()
end

local ipairs = ipairs
local format = string.format
local tinsert = table.insert

-- GUI-only inherit sentinel: dropdowns show it as 'Global (...)', the db stores nil.
local GLOBAL = '__GLOBAL'

local ANCHOR_POINTS = NRSKNUI.AnchorOptions

-- Slug is a separate axis here (a checkbox globally, unavailable on specials), so it stays out.
-- globalLabel adds the inherit sentinel in front for the specials dropdown.
local function OutlineOptions(globalLabel)
    local options = NRSKNUI:GetOutlineOptions()
    if globalLabel then
        tinsert(options, 1, { value = GLOBAL, text = format(L['Global (%s)'], globalLabel) })
    end
    return options
end

local function BuildBlizzardView(page)
    local blizzDB = BlizzardMessages.db

    local blizzCard = page:Card(L['Blizzard UI Font'], 'all')
    blizzCard:Row(rowH):Checkbox(L['Hide Shadows'], {
        width = 1,
        value = blizzDB.HideShadow,
        tooltip = L['Remove the drop shadow from styled fonts for a flatter look. Native shadows return when unchecked.'],
        callback = function(checked)
            blizzDB.HideShadow = checked
            BlizzardMessages:ApplyBlizzardFonts()
        end,
    })

    local outlineRow = blizzCard:Row(rowH)
    outlineRow:Dropdown(L['Outline'], {
        width = 0.5,
        options = OutlineOptions(),
        value = blizzDB.Outline,
        callback = function(key)
            blizzDB.Outline = key
            BlizzardMessages:ApplyBlizzardFonts()
        end,
    })

    outlineRow:Checkbox(L['Use Slug Rendering'], {
        width = 0.5,
        value = blizzDB.Slug,
        tooltip = L['Higher-quality glyph rendering on supported fonts, combined with the outline above where enabled.'],
        callback = function(checked)
            blizzDB.Slug = checked
            BlizzardMessages:ApplyBlizzardFonts()
        end,
    })

    blizzCard:Separator()

    local function FamilySlider(row, famKey, label, tooltip)
        row:Slider(label, {
            width = 0.5,
            min = -8,
            max = 8,
            step = 1,
            value = blizzDB.Families[famKey] or 0,
            tooltip = tooltip,
            callback = function(val)
                blizzDB.Families[famKey] = val
                BlizzardMessages:ApplyBlizzardFonts(true)
            end,
        })
    end

    local blizzRow3 = blizzCard:Row(rowH)
    FamilySlider(blizzRow3, 'tiny', L['Tiny Size'], L['native sizes 9 and below'])
    FamilySlider(blizzRow3, 'small', L['Small Size'], L['native sizes 10 to 11'])

    local blizzRow4 = blizzCard:Row(rowH)
    FamilySlider(blizzRow4, 'medium', L['Medium Size'], L['native sizes 12 to 14'])
    FamilySlider(blizzRow4, 'large', L['Large Size'], L['native sizes 15 to 18'])

    local blizzRow5 = blizzCard:Row(rowHL, 0)
    FamilySlider(blizzRow5, 'huge', L['Huge Size'], L['native sizes 19 to 24'])
    FamilySlider(blizzRow5, 'display', L['Display Size'], L['native sizes above 24'])

    blizzCard:Separator()

    blizzCard:Row(22, 0):Text(NRSKNUI:ColorTextByTheme(L['Blizzard Font Info']), {
        width = 1,
        height = 22,
        autoHeight = true,
        bgMode = 'hide',
        text = {
            L['Font sizes have been split into 6 different size families, tiny, small, medium, large, huge and display.'],
            L['by default all families are set to 0, this means they use native size.'],
            L['Changing the value either adds or subtracts from native size, e.g a native size of 16 with slider value of 2, becomes 18.'],
        },
    })
end

local function BuildSpecialView(page, entry)
    local fontDB = NRSKNUI:GetSharedSettings().globalMedia.profileFont
    local blizzDB = BlizzardMessages.db
    local sdb = blizzDB.Specials[entry.key]

    local function Apply()
        BlizzardMessages:ApplySpecialFonts()
        if (entry.position or entry.hideLabel) then
            ApplySettings()
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
                if BlizzardMessages[entry.preview] then
                    BlizzardMessages[entry.preview](BlizzardMessages)
                end
            end,
        })
    end
    card:Separator()

    local fontRow = card:Row(rowH)
    fontRow:Dropdown(L['Font'], {
        width = entry.noOutline and 1 or 0.5,
        media = 'font',
        options = { { key = GLOBAL, text = format(L['Global (%s)'], fontDB.FontFace) } },
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
        hideRow:Checkbox(entry.hideLabel, {
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
        local noteHeight = 20
        local noteRow = card:Row(noteHeight, 0)
        noteRow:Text(nil, {
            width = 1,
            text = entry.note,
            height = noteHeight,
            autoHeight = true,
            bgMode = 'hide',
        })
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

-- the special fonts captioned by where they show up, in the order they're listed in
local GROUPS = {
    { key = 'zones',    text = L['Zone Names'], fonts = { ZoneText = true, SubZoneText = true, PvPZoneText = true } },
    { key = 'messages', text = L['Messages'],   fonts = { ErrorText = true, ActionStatus = true } },
    { key = 'world',    text = L['In World'],   fonts = { ChatBubbles = true, Nameplates = true, CombatText = true, CombatFont = true, NameFont = true } },
}

local items = {
    { type = 'label', key = 'general', text = L['General'] },
    { key = 'blizzardFonts', text = L['Blizzard UI Font'] },
}
for _, group in ipairs(GROUPS) do
    items[#items + 1] = { type = 'label', key = group.key, text = group.text }
    for _, entry in ipairs(BlizzardMessages.SpecialFonts) do
        if group.fonts[entry.key] then
            items[#items + 1] = { key = entry.key, text = entry.label }
        end
    end
end

GUI:RegisterPage('blizzardFonts', {
    mode = 'clean',
    search = {
        L['Outline'], L['Use Slug Rendering'],
        L['Hide Shadows'], L['Tiny Size'], L['Small Size'], L['Medium Size'], L['Large Size'],
        L['Huge Size'], L['Display Size'], L['Font Size'],
    },
    sidebar = { items = items },
    build = function(page, _, itemKey)
        -- the header's switch is every font's parent, the special ones' own toggles included
        page:SetEnabled(function() return BlizzardMessages.db.Enabled end)

        if not itemKey or itemKey == 'blizzardFonts' then
            BuildBlizzardView(page)
            return
        end
        for _, entry in ipairs(BlizzardMessages.SpecialFonts) do
            if entry.key == itemKey then
                BuildSpecialView(page, entry)
                return
            end
        end
    end,
})

-- the fonts restyle or go back to Blizzard's at once, the special frames with them
NRSKNUI.ModuleHeader:OnToggle('BlizzardMessages', function()
    BlizzardMessages:ApplyBlizzardFonts(true)
    ApplySettings()
end)
