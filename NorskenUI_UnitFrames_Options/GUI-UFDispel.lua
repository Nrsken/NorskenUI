---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class UnitFramesModule
local UF = NRSKNUI:GetModule('UnitFrames')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs

local STYLE_OPTIONS = {
    { value = 'Overlay',  text = L['Solid'] },
    { value = 'Gradient', text = L['Gradient'] },
}

local ANCHOR_OPTIONS = NRSKNUI.AnchorOptions

-- Dispel type names as the game reports them; the labels are the same words, translated.
local IGNORE_OPTIONS = {
    { value = 'Magic',   text = L['Magic'] },
    { value = 'Curse',   text = L['Curse'] },
    { value = 'Disease', text = L['Disease'] },
    { value = 'Poison',  text = L['Poison'] },
    { value = 'Bleed',   text = L['Bleed'] },
}

local SOURCE_OPTIONS = {
    { value = 'raid', text = L['Dispellable by You'] },
    { value = 'any',  text = L['Dispellable by Anyone'] },
}

-- Style, border, icon, alpha and layer are only read when the highlight is built.
local function NeedsReload()
    NRSKNUI:RequestReload(L['Dispel highlight style changes show after a reload.'])
end

---@param page KajiGUIPage
---@param dDB table the Dispel block being edited
---@param ctx table { group: string, conditions: string[]?, useGlobal: table? the unit's Dispel block, when this is a unit's section }
local function BuildDispelCards(page, dDB, ctx)
    local group, conditions = ctx.group, ctx.conditions
    if dDB.Style ~= 'Overlay' and dDB.Style ~= 'Gradient' then dDB.Style = 'Overlay' end
    page:SetCondition('dispelIcon', function() return dDB.ShowIcon end)
    page:SetCondition('ownEnabled', function() return dDB.Enabled end)

    local ownConditions = { 'ownEnabled' }
    for _, condition in ipairs(conditions or {}) do
        ownConditions[#ownConditions + 1] = condition
    end

    local card = page:Card(L['Dispel Highlight'], group)
    if ctx.useGlobal then
        local unitDB = ctx.useGlobal
        local globalRow = card:Row(unitDB.UseGlobal and rowHL or rowH, unitDB.UseGlobal and 0 or nil)
        globalRow:Checkbox(L['Use Global Dispel Settings'], {
            width = 0.5,
            tooltip = L['Follow the dispel highlight from the general settings.'],
            value = unitDB.UseGlobal,
            callback = function(checked)
                unitDB.UseGlobal = checked
                ctx.Apply()
                ctx.reload() -- the unit's own settings come and go with this
            end,
        })

        -- Following the global block, there is nothing of the unit's own to edit, so none of it is drawn.
        if unitDB.UseGlobal then
            globalRow:Button(L['Edit Global Dispel Settings'], {
                width = 0.5,
                height = 24,
                yOffset = -14,
                callback = function()
                    NRSKNUI.GUIFrame:ShowPage('unitFramesGeneral', { itemKey = 'dispel' })
                end,
            })
            return
        end

        card:Separator()
    end

    local toggleRow = card:Row(rowH)
    toggleRow:Checkbox(L['Enable Dispel Highlight'], {
        width = 0.5,
        conditions = conditions,
        tooltip = L['Colors the unit frame by the dispel type of a debuff on it. Only ever drawn on units you can help.'],
        value = dDB.Enabled,
        callback = function(checked)
            dDB.Enabled = checked
            ctx.Apply()
            page:Refresh()
        end,
    })
    toggleRow:Checkbox(L['Show Without Dispel Type'], {
        width = 0.5,
        conditions = ownConditions,
        tooltip = L['Keep the highlight up for matching auras that have no dispel type at all. The game colors these by dispel type, so they draw in its no-type color.'],
        value = dDB.ShowWithoutDispelType,
        callback = function(checked)
            dDB.ShowWithoutDispelType = checked
            ctx.Apply()
        end,
    })
    card:Separator()

    local sourceRow = card:Row(rowHL, 0)
    sourceRow:Dropdown(L['Dispellable By'], {
        width = 0.5,
        conditions = ownConditions,
        options = SOURCE_OPTIONS,
        tooltip = L['The game answers this for your whole group, so Dispellable by You means anyone in it can remove the debuff. By Anyone is every debuff that carries a dispel type at all.'],
        value = dDB.Source,
        callback = function(value)
            dDB.Source = value
            ctx.Apply()
        end,
    })
    sourceRow:Dropdown(L['Ignore Dispel Types'], {
        width = 0.5,
        multiSelect = true,
        conditions = ownConditions,
        options = IGNORE_OPTIONS,
        tooltip = L['Debuffs of these types never light the frame, but another debuff on the same unit still does. For example Bleed, when a fight puts one on everyone.'],
        value = dDB.IgnoreTypes,
        callback = function() ctx.Apply() end,
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
            ctx.Apply()
            NeedsReload()
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
            ctx.Apply()
            NeedsReload()
        end,
    })

    local placeRow = styleCard:Row(rowHL, 0)
    placeRow:Dropdown(L['Attach To'], {
        width = 0.5,
        conditions = ownConditions,
        options = UF.GUIAttachOptions,
        value = dDB.Attach,
        callback = function(value)
            dDB.Attach = value
            ctx.Apply()
        end,
    })
    placeRow:Slider(L['Alpha'], {
        width = 0.5,
        min = 0,
        max = 1,
        step = 0.05,
        conditions = ownConditions,
        callbackOnRelease = true,
        value = dDB.Alpha,
        callback = function(value)
            dDB.Alpha = value
            ctx.Apply()
            NeedsReload()
        end,
    })

    -- The icon is the game's own artwork, one per dispel type, so there is nothing to pick or color.
    local iconConditions = { 'dispelIcon' }
    for _, condition in ipairs(conditions or {}) do
        iconConditions[#iconConditions + 1] = condition
    end

    local iconCard = page:Card(L['Dispel Icon'], group)
    iconCard:Row(rowH):Checkbox(L['Show Dispel Icon'], {
        width = 1,
        conditions = conditions,
        tooltip = L["The game's own icon for the dispel type, drawn over the highlight."],
        value = dDB.ShowIcon,
        callback = function(checked)
            dDB.ShowIcon = checked
            ctx.Apply()
            NeedsReload()
            page:Refresh()
        end,
    })
    iconCard:Separator()

    local sizeRow = iconCard:Row(rowH)
    sizeRow:Slider(L['Icon Size'], {
        width = 0.5,
        min = 8,
        max = 32,
        step = 1,
        conditions = iconConditions,
        value = dDB.IconSize,
        callback = function(value)
            dDB.IconSize = value
            ctx.Apply()
            NeedsReload()
        end,
    })
    sizeRow:Dropdown(L['Anchor Point'], {
        width = 0.5,
        conditions = iconConditions,
        options = ANCHOR_OPTIONS,
        tooltip = L['Which corner of the highlight the icon sits in.'],
        value = dDB.IconPosition.AnchorFrom,
        callback = function(value)
            dDB.IconPosition.AnchorFrom = value
            dDB.IconPosition.AnchorTo = value
            ctx.Apply()
            NeedsReload()
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
            ctx.Apply()
            NeedsReload()
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
            ctx.Apply()
            NeedsReload()
        end,
    })
end

---The shared block, on Unit Frames -> General.
---@param page KajiGUIPage
---@param db table UF.db
function UF.GUIDispelTab(page, db)
    -- The shared block really does reach every unit, so this pass stays unscoped.
    BuildDispelCards(page, db.General.Dispel, { group = 'all', Apply = function() UF:ApplySettings() end })
end

---Builds the dispel section for a unit.
---@param page KajiGUIPage
---@param uDB table
---@param unit string config key
local function BuildUnitSection(page, uDB, unit)
    local dDB = uDB.Dispel
    page:SetCondition('ownDispel', function() return not dDB.UseGlobal end)

    BuildDispelCards(page, dDB, {
        group = 'unitOn',
        conditions = { 'ownDispel' },
        useGlobal = dDB,
        -- Scoped to this unit: an unscoped pass reconfigures every other unit's frames as well.
        Apply = function() UF:ApplySettings(unit) end,
        reload = function() NRSKNUI.GUIFrame.content:ShowPage(UF.GUIPageID(unit), { itemKey = 'dispel' }) end,
    })
end

UF.GUISections.dispel = BuildUnitSection
