---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ReloadUI = ReloadUI
local ipairs = ipairs

local function ApplySettings() UF:ApplySettings() end

local STYLE_OPTIONS = {
    { value = 'Overlay',  text = L['Solid'] },
    { value = 'Gradient', text = L['Gradient'] },
}

local ANCHOR_OPTIONS = NRSKNUI.AnchorOptions

local SOURCE_OPTIONS = {
    { value = 'raid', text = L['Dispellable by You'] },
    { value = 'any',  text = L['Dispellable by Anyone'] },
}

---Which settings only take effect on the next reload, since the game builds an aura button once.
---@param page KajiGUIPage
---@param group string
local function BuildReloadCard(page, group)
    local card = page:Card(L['Apply Changes'], group)
    card:Row(56):Text(L['Dispel Highlight'], {
        width = 1,
        text = L['Style, border, icon, alpha and layer are read when the highlight is built, so they take a reload. Turning it on or off, the dispel source and what it attaches to apply straight away.'],
        height = 56,
        bgMode = 'none',
    })
    card:Row(32):Button(L['Reload UI'], {
        width = 1,
        height = 32,
        callback = function()
            ReloadUI()
        end,
    })
end

---@param page KajiGUIPage
---@param dDB table the Dispel block being edited
---@param ctx table { group: string, conditions: string[]?, useGlobal: table? the unit block, when this is a unit's section }
local function BuildDispelCards(page, dDB, ctx)
    local group, conditions = ctx.group, ctx.conditions
    if dDB.Style ~= 'Overlay' and dDB.Style ~= 'Gradient' then dDB.Style = 'Overlay' end
    page:SetCondition('dispelIcon', function() return dDB.ShowIcon end)
    page:SetCondition('ownEnabled', function() return dDB.Enabled end)

    -- The icon is the game's own artwork, one per dispel type, so there is nothing to pick or color.
    local ownConditions = { 'ownEnabled' }
    for _, condition in ipairs(conditions or {}) do
        ownConditions[#ownConditions + 1] = condition
    end

    local card = page:Card(L['Dispel Highlight'], group)
    if ctx.useGlobal then
        local unitDB = ctx.useGlobal
        card:Row(rowH):Checkbox(L['Use Global Dispel Settings'], {
            width = 1,
            tooltip = L['Follow the dispel highlight from the general settings.'],
            value = unitDB.UseGlobal,
            callback = function(checked)
                unitDB.UseGlobal = checked
                ApplySettings()
                page:Refresh()
            end,
        })

        card:Separator()
    end

    local enableRow = card:Row(rowHL, 0)
    enableRow:Checkbox(L['Enable Dispel Highlight'], {
        width = 0.5,
        conditions = conditions,
        tooltip = L['Colors the unit frame by the dispel type of a debuff on it. Only ever drawn on units you can help.'],
        value = dDB.Enabled,
        callback = function(checked)
            dDB.Enabled = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    enableRow:Dropdown(L['Dispellable By'], {
        width = 0.5,
        conditions = ownConditions,
        options = SOURCE_OPTIONS,
        tooltip = L['The game answers this for your whole group, so Dispellable by You means anyone in it can remove the debuff. By Anyone is every debuff that carries a dispel type at all.'],
        value = dDB.Source,
        callback = function(value)
            dDB.Source = value
            ApplySettings()
        end,
    })

    local styleCard = page:Card(L['Style Settings'], group)
    local styleRow = styleCard:Row(rowH)
    styleRow:Dropdown(L['Style'], {
        width = 0.5,
        conditions = ownConditions,
        options = STYLE_OPTIONS,
        tooltip = L['Solid tints the whole target evenly, Gradient fades it out across the target.'],
        value = dDB.Style,
        callback = function(value)
            dDB.Style = value
            ApplySettings()
        end,
    })
    styleRow:Slider(L['Border Size'], {
        width = 0.5,
        min = 0,
        max = 5,
        step = 1,
        conditions = ownConditions,
        tooltip = L['Pixels of dispel-colored border drawn around the target, on top of whichever style is set. 0 turns the border off.'],
        value = dDB.BorderSize,
        callback = function(value)
            dDB.BorderSize = value
            ApplySettings()
        end,
    })

    local placeRow = styleCard:Row(rowH)
    placeRow:Dropdown(L['Attach To'], {
        width = 0.5,
        conditions = ownConditions,
        options = UF.GUIAttachOptions,
        value = dDB.Attach,
        callback = function(value)
            dDB.Attach = value
            ApplySettings()
        end,
    })
    placeRow:Dropdown(L['Layer'], {
        width = 0.5,
        conditions = ownConditions,
        options = UF.GUILayerOptions(),
        tooltip = L['Higher layers draw over lower ones. Damage absorb sits on 4 and heal absorb on 5 by default.'],
        value = dDB.Layer,
        callback = function(value)
            dDB.Layer = value
            ApplySettings()
        end,
    })

    local lastRow = styleCard:Row(rowHL, 0)
    lastRow:Slider(L['Alpha'], {
        width = 0.5,
        min = 0,
        max = 1,
        step = 0.05,
        conditions = ownConditions,
        callbackOnRelease = true,
        value = dDB.Alpha,
        callback = function(value)
            dDB.Alpha = value
            ApplySettings()
        end,
    })
    lastRow:Checkbox(L['Show Without Dispel Type'], {
        width = 0.5,
        conditions = ownConditions,
        tooltip = L['Keep the highlight up for matching auras that have no dispel type at all. The game colors these by dispel type, so they draw in its no-type color.'],
        value = dDB.ShowWithoutDispelType,
        callback = function(checked)
            dDB.ShowWithoutDispelType = checked
            ApplySettings()
        end,
    })

    -- The icon is the game's own artwork, one per dispel type, so there is nothing to pick or color.
    local iconConditions = { 'dispelIcon' }
    for _, condition in ipairs(conditions or {}) do
        iconConditions[#iconConditions + 1] = condition
    end

    local iconCard = page:Card(L['Dispel Icon'], group)
    local iconRow = iconCard:Row(rowH)
    iconRow:Checkbox(L['Show Dispel Icon'], {
        width = 0.5,
        conditions = conditions,
        tooltip = L["The game's own icon for the dispel type, drawn over the highlight."],
        value = dDB.ShowIcon,
        callback = function(checked)
            dDB.ShowIcon = checked
            ApplySettings()
            page:Refresh()
        end,
    })
    iconRow:Slider(L['Icon Size'], {
        width = 0.5,
        min = 8,
        max = 32,
        step = 1,
        conditions = iconConditions,
        value = dDB.IconSize,
        callback = function(value)
            dDB.IconSize = value
            ApplySettings()
        end,
    })

    iconCard:Row(rowH):Dropdown(L['Anchor Point'], {
        width = 1,
        conditions = iconConditions,
        options = ANCHOR_OPTIONS,
        tooltip = L['Which corner of the highlight the icon sits in.'],
        value = dDB.IconPosition.AnchorFrom,
        callback = function(value)
            dDB.IconPosition.AnchorFrom = value
            dDB.IconPosition.AnchorTo = value
            ApplySettings()
        end,
    })

    local offsetRow = iconCard:Row(rowHL, 0)
    offsetRow:Slider(L['X Offset'], {
        width = 0.5,
        min = -50,
        max = 50,
        step = 1,
        conditions = iconConditions,
        callbackOnRelease = true,
        value = dDB.IconPosition.XOffset,
        callback = function(value)
            dDB.IconPosition.XOffset = value
            ApplySettings()
        end,
    })
    offsetRow:Slider(L['Y Offset'], {
        width = 0.5,
        min = -50,
        max = 50,
        step = 1,
        conditions = iconConditions,
        callbackOnRelease = true,
        value = dDB.IconPosition.YOffset,
        callback = function(value)
            dDB.IconPosition.YOffset = value
            ApplySettings()
        end,
    })

    BuildReloadCard(page, group)
end

---The shared block, on Unit Frames -> General.
---@param page KajiGUIPage
---@param db table db.profile.UnitFrames
function UF.GUIDispelTab(page, db)
    BuildDispelCards(page, db.General.Dispel, { group = 'all' })
end

---Builds the dispel section for a unit.
---@param page KajiGUIPage
---@param uDB table
local function BuildUnitSection(page, uDB)
    local dDB = uDB.Dispel
    page:SetCondition('ownDispel', function() return not dDB.UseGlobal end)

    BuildDispelCards(page, dDB, { group = 'unitOn', conditions = { 'ownDispel' }, useGlobal = dDB, })
end

UF.GUISections.dispel = BuildUnitSection
