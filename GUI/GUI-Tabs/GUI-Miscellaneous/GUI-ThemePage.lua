---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs
local min = math.min

local MODE_OPTIONS = {
    { key = 'preset', text = L['Preset Theme'] },
    { key = 'class',  text = L['Class Color'] },
    { key = 'custom', text = L['Custom'] },
}

local MODE_DESCRIPTIONS = {
    preset = L['Use one of the pre-made color themes.'],
    class  = L["Accent colors will match your character's class color."],
    custom = L['Fully customize every color in the theme.'],
}

local CATEGORY_ORDER = {
    'Backgrounds', 'Borders', 'Accent Colors', 'Text Colors', 'Selection Colors', 'Status Colors',
}

local PREVIEW_KEYS = { 'bgDark', 'bgMedium', 'bgLight', 'accent', 'selectedBg' }

local function PresetOptions()
    local options = {}
    for _, name in ipairs(GUI:GetPresetNames()) do
        options[#options + 1] = { key = name, text = name }
    end
    return options
end

local function ReloadPage()
    local window = NRSKNUI.GUIFrame --[[@as KajiGUIWindow]]
    window:ShowPage('themePage')
end

local function BuildModeCard(page, mode)
    local card = page:Card(L['Theme Mode'])
    card:Row(rowH):Dropdown(L['Theme Mode'], {
        width = 1,
        options = MODE_OPTIONS,
        value = mode,
        callback = function(key)
            GUI:SetMode(key)
            ReloadPage()
        end,
    })
    card:Row(20, 0):Text(nil, {
        width = 1,
        text = MODE_DESCRIPTIONS[mode],
        height = 20,
        bgMode = 'hide',
    })
end

local function BuildPresetCard(page)
    local card = page:Card(L['Preset Theme'])
    card:Row(rowH):Dropdown(L['Theme'], {
        width = 1,
        options = PresetOptions(),
        value = GUI:GetSelectedPreset(),
        callback = function(key)
            GUI:SetPreset(key)
            ReloadPage()
        end,
    })

    card:Separator()

    local preset = GUI:GetPreset(GUI:GetSelectedPreset())
    local swatchRow = card:Row(28)
    for _, key in ipairs(PREVIEW_KEYS) do
        local color = preset[key]
        local swatch = swatchRow:Icon({ width = 1 / #PREVIEW_KEYS, align = 'FILL' })
        swatch.icon:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

local function BuildClassCard(page)
    local card = page:Card(L['Class Color Mode'])
    local color = NRSKNUI:GetPlayerClassColor()
    local swatch = card:Row(18):Icon({ width = 1, align = 'FILL' })
    swatch.icon:SetColorTexture(color[1], color[2], color[3], 1)
    card:Row(40, 0):Text(nil, {
        width = 1,
        text = {
            L['The class color above is used for accents and selections.'],
            L['Background colors will use the Dark theme.'],
        },
        height = 40,
        bgMode = 'hide',
    })
end

local function BuildCustomCards(page)
    local categories = {}
    for _, def in ipairs(GUI:GetColorKeys()) do
        local list = categories[def.category]
        if not list then
            list = {}
            categories[def.category] = list
        end
        list[#list + 1] = def
    end

    for _, catName in ipairs(CATEGORY_ORDER) do
        local defs = categories[catName]
        if defs then
            local card = page:Card(L[catName])
            for i = 1, #defs, 2 do
                local isLast = i + 2 > #defs
                local row = card:Row(isLast and rowHL or rowH, isLast and 0 or nil)
                for j = i, min(i + 1, #defs) do
                    local def = defs[j]
                    row:ColorPicker(def.name, {
                        width = 0.5,
                        value = GUI:GetCustomColor(def.key),
                        callback = function(r, g, b, a)
                            GUI:SetCustomColor(def.key, r, g, b, a)
                        end,
                    })
                end
            end
        end
    end

    local quickCard = page:Card(L['Quick Setup'])
    quickCard:Row(20):Text(nil, {
        width = 1,
        text = L['Copy colors from a preset theme as a starting point.'],
        height = 20,
        bgMode = 'hide',
    })
    local quickRow = quickCard:Row(rowHL, 0)
    quickRow:Dropdown(L['Copy From'], {
        width = 0.5,
        options = PresetOptions(),
        value = '',
        callback = function(key)
            GUI:CopyPresetToCustom(key)
            ReloadPage()
        end,
    })
    quickRow:Button(L['Reset Custom'], {
        width = 0.5,
        height = 24,
        yOffset = -14,
        callback = function()
            GUI:ResetCustomColors()
            ReloadPage()
        end,
    })
end

local function BuildResetCard(page)
    local card = page:Card(L['Reset'])
    card:Row(rowHL - 9):Button(L['Reset All Theme Settings'], {
        width = 1,
        height = 30,
        yOffset = -2,
        callback = function()
            GUI:ResetTheme()
            ReloadPage()
        end,
    })
    card:Row(20, 0):Text(nil, {
        width = 1,
        text = L["This will reset theme mode to 'Preset' with the NUI v2 theme."],
        height = 20,
        bgMode = 'hide',
    })
end

GUI:RegisterPage('themePage', {
    mode = 'clean',
    search = { L['Theme Mode'], L['Theme'], L['Copy From'], L['Reset Custom'] },
    build = function(page)
        local mode = GUI:GetMode()

        BuildModeCard(page, mode)

        if mode == 'preset' then
            BuildPresetCard(page)
        elseif mode == 'class' then
            BuildClassCard(page)
        elseif mode == 'custom' then
            BuildCustomCards(page)
        end

        BuildResetCard(page)
    end,
})
