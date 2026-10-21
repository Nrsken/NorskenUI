---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class NRSKNUI.GUIAuraCards
local AuraCards = {}
NRSKNUI.GUIAuraCards = AuraCards
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local ipairs = ipairs

-- Enum key names rather than values: the db stores the key, resolved at use time (see Defaults.lua).
AuraCards.SortMethods = {
    { value = 'ExpirationOnly',     text = L['Expiration Only'] },
    { value = 'Expiration',         text = L['Expiration'] },
    { value = 'Default',            text = L['Default'] },
    { value = 'ImportantOnly',      text = L['Important Only'] },
    { value = 'BigDefensive',       text = L['Big Defensive'] },
    { value = 'UnitFrameDebuff',    text = L['Unit Frame Debuff'] },
    { value = 'Name',               text = L['Name'] },
    { value = 'NameOnly',           text = L['Name Only'] },
    { value = 'AuraInstanceIDOnly', text = L['Aura Instance ID'] },
}

AuraCards.SortDirections = {
    { value = 'Normal',  text = L['Normal'] },
    { value = 'Reverse', text = L['Reverse'] },
}

-- Center keeps the auras centered on the anchor, growing both ways as they come and go.
AuraCards.GrowthX = {
    { value = 'RIGHT',  text = L['Right'] },
    { value = 'LEFT',   text = L['Left'] },
    { value = 'CENTER', text = L['Center'] },
}

AuraCards.GrowthY = {
    { value = 'UP',     text = L['Up'] },
    { value = 'DOWN',   text = L['Down'] },
    { value = 'CENTER', text = L['Center'] },
}

-- The stack and duration strings take the same three controls, so TextPosition builds both from this.
AuraCards.TextSlots = {
    { key = 'StackFont',    anchor = L['Stack Anchor'],    x = L['Stack X'],    y = L['Stack Y'] },
    { key = 'DurationFont', anchor = L['Duration Anchor'], x = L['Duration X'], y = L['Duration Y'] },
}

---@param page KajiGUIPage
---@param db table
---@param ctx table { Apply: fun(), filtered?: boolean }
---@return KajiGUIFluentCard
function AuraCards:Grid(page, db, ctx)
    local Apply = ctx.Apply

    local card = page:Card(L['Grid'], 'all')
    local sizeRow = card:Row(rowH)
    sizeRow:Slider(L['Size'], {
        width = 0.5,
        min = 12,
        max = 80,
        step = 1,
        value = db.size,
        callback = function(val)
            db.size = val
            Apply() -- resizes the mover host and the wrap width even though buttons keep their size
        end,
    })
    sizeRow:Slider(L['Per Row'], {
        width = 0.5,
        min = 1,
        max = 20,
        step = 1,
        value = db.perRow,
        callback = function(val)
            db.perRow = val
            Apply()
        end,
    })

    local countRow = card:Row(rowH)
    countRow:Slider(L['Max Auras'], {
        width = 0.5,
        tooltip = ctx.filtered and L['Applies per filter branch, so a filter with several branches can show more than this in total.'] or nil,
        min = 1,
        max = 40,
        step = 1,
        value = db.maxFrameCount,
        callback = function(val)
            db.maxFrameCount = val
            Apply()
        end,
    })
    countRow:Slider(L['Preview Limit'], {
        width = 0.5,
        tooltip = L['Caps how many icons the preview draws and the mover box covers. The game caps auras per filter branch and never per display, so this leaves the real auras alone.'],
        min = 1,
        max = 40,
        step = 1,
        value = db.previewLimit,
        callback = function(val)
            db.previewLimit = val
            Apply()
        end,
    })

    local spacingRow = card:Row(rowHL, 0)
    spacingRow:Slider(L['Element Spacing'], {
        width = 0.5,
        tooltip = L['Spacing between auras along the row.'],
        min = 0,
        max = 20,
        step = 1,
        value = db.elementSpacing,
        callback = function(val)
            db.elementSpacing = val
            Apply()
        end,
    })
    spacingRow:Slider(L['Line Spacing'], {
        width = 0.5,
        tooltip = L['Spacing between aura rows.'],
        min = 0,
        max = 20,
        step = 1,
        value = db.lineSpacing,
        callback = function(val)
            db.lineSpacing = val
            Apply()
        end,
    })

    return card
end

---@param page KajiGUIPage
---@param db table
---@param ctx table { Apply: fun() }
---@return KajiGUIFluentCard
function AuraCards:Growth(page, db, ctx)
    local Apply = ctx.Apply

    local card = page:Card(L['Growth'], 'all')
    local growthRow = card:Row(rowHL, 0)
    growthRow:Dropdown(L['Horizontal Growth'], {
        width = 0.5,
        options = self.GrowthX,
        value = db.horizontalGrowthDirection,
        callback = function(key)
            db.horizontalGrowthDirection = key
            Apply()
        end,
    })
    growthRow:Dropdown(L['Vertical Growth'], {
        width = 0.5,
        options = self.GrowthY,
        value = db.verticalGrowthDirection,
        callback = function(key)
            db.verticalGrowthDirection = key
            Apply()
        end,
    })

    return card
end

---@param page KajiGUIPage
---@param db table
---@param ctx table { Apply: fun() }
---@return KajiGUIFluentCard
function AuraCards:Sorting(page, db, ctx)
    local Apply = ctx.Apply

    local card = page:Card(L['Sorting'], 'all')
    local sortRow = card:Row(rowHL, 0)
    sortRow:Dropdown(L['Sort Method'], {
        width = 0.5,
        options = self.SortMethods,
        value = db.sortMethod,
        callback = function(key)
            db.sortMethod = key
            Apply()
        end,
    })
    sortRow:Dropdown(L['Sort Direction'], {
        width = 0.5,
        options = self.SortDirections,
        value = db.sortDirection,
        callback = function(key)
            db.sortDirection = key
            Apply()
        end,
    })

    return card
end

---One card per string on the button.
---@param page KajiGUIPage
---@param db table .showApplicationCount, .showDurationText, .StackFont, .DurationFont
---@param ctx table { Apply: fun() }
function AuraCards:Text(page, db, ctx)
    local Apply = ctx.Apply
    local strings = {
        { title = L['Stack Count'],   show = 'showApplicationCount', showLabel = L['Show Count'],    slot = self.TextSlots[1] },
        { title = L['Duration Text'], show = 'showDurationText',     showLabel = L['Show Duration'], slot = self.TextSlots[2] },
    }

    for _, entry in ipairs(strings) do
        local font = db[entry.slot.key]
        local position = font.Position
        local card = page:Card(entry.title, 'all')

        local headRow = card:Row(rowH)
        headRow:Checkbox(entry.showLabel, {
            width = 0.5,
            value = db[entry.show],
            callback = function(checked)
                db[entry.show] = checked
                Apply()
            end,
        })
        headRow:Slider(L['Font Size'], {
            width = 0.5,
            tooltip = L['The font face and outline come from the font settings.'],
            min = 8,
            max = 40,
            step = 1,
            value = font.FontSize,
            callback = function(val)
                font.FontSize = val
                Apply()
            end,
        })

        card:Row(rowH):Dropdown(L['Anchor'], {
            width = 1,
            options = NRSKNUI.AnchorOptions,
            value = position.AnchorFrom,
            callback = function(key)
                position.AnchorFrom = key
                Apply()
            end,
        })

        local offsetRow = card:Row(rowHL, 0)
        offsetRow:Slider(L['X Offset'], {
            width = 0.5,
            min = -40,
            max = 40,
            step = 1,
            value = position.XOffset,
            callback = function(val)
                position.XOffset = val
                Apply()
            end,
        })
        offsetRow:Slider(L['Y Offset'], {
            width = 0.5,
            min = -40,
            max = 40,
            step = 1,
            value = position.YOffset,
            callback = function(val)
                position.YOffset = val
                Apply()
            end,
        })
    end
end

---@param page KajiGUIPage
---@param db table
---@param ctx table { Apply: fun() }
---@return KajiGUIFluentCard
function AuraCards:Cooldown(page, db, ctx)
    local Apply = ctx.Apply

    local card = page:Card(L['Cooldown'], 'all')
    local swipeRow = card:Row(rowH)
    swipeRow:Checkbox(L['Draw Swipe'], {
        width = 0.5,
        value = db.drawSwipe,
        callback = function(checked)
            db.drawSwipe = checked
            Apply()
        end,
    })
    swipeRow:Checkbox(L['Reverse Swipe'], {
        width = 0.5,
        value = db.reverseSwipe,
        callback = function(checked)
            db.reverseSwipe = checked
            Apply()
        end,
    })
    card:Row(rowHL, 0):Checkbox(L['Draw Edge'], {
        width = 1,
        value = db.drawEdge,
        callback = function(checked)
            db.drawEdge = checked
            Apply()
        end,
    })

    return card
end

---Dispel border and the corner dispel type icon.
---@param page KajiGUIPage
---@param db table
---@param ctx table { Apply: fun(), dispelIconKey: string, withoutDispelType?: boolean }
---@return KajiGUIFluentCard
function AuraCards:Dispel(page, db, ctx)
    local Apply = ctx.Apply
    local iconKey = ctx.dispelIconKey
    page:SetCondition(iconKey, function() return db[iconKey] end)

    local card = page:Card(L['Dispel Indicators'], 'all')
    local borderRow = card:Row(rowH)
    borderRow:Checkbox(L['Show Border'], {
        width = ctx.withoutDispelType and 0.5 or 1,
        tooltip = L['Colors the aura border by dispel type.'],
        value = db.showBorder,
        callback = function(checked)
            db.showBorder = checked
            Apply()
        end,
    })
    if ctx.withoutDispelType then
        borderRow:Checkbox(L['Show Without Dispel Type'], {
            width = 0.5,
            tooltip = L['Keeps the border visible on auras that have no dispel type.'],
            value = db.showBorderWithoutDispelType,
            callback = function(checked)
                db.showBorderWithoutDispelType = checked
                Apply()
            end,
        })
    end

    card:Separator()

    local dispelIconRow = card:Row(rowHL, 0)
    dispelIconRow:Checkbox(L['Show Dispel Icon'], {
        width = 0.5,
        tooltip = L['Shows the dispel type icon in the corner of the aura.'],
        value = db[iconKey],
        callback = function(checked)
            db[iconKey] = checked
            Apply()
            page:Refresh()
        end,
    })
    dispelIconRow:Slider(L['Dispel Icon Size'], {
        width = 0.5,
        min = 4,
        max = 40,
        step = 1,
        value = db.dispelIconSize,
        conditions = { iconKey },
        callback = function(val)
            db.dispelIconSize = val
            Apply()
        end,
    })

    return card
end

---@param page KajiGUIPage
---@param db table
---@param ctx table { Apply: fun(), disableMouse?: boolean }
---@return KajiGUIFluentCard
function AuraCards:Tooltip(page, db, ctx)
    local Apply = ctx.Apply
    local withMouse = ctx.disableMouse

    local card = page:Card(L['Tooltip'], 'all')
    local row = card:Row(rowHL, 0)
    row:Checkbox(L['Hide Tooltip In Combat'], {
        width = withMouse and 0.5 or 1,
        value = db.tooltipHideInCombat,
        callback = function(checked)
            db.tooltipHideInCombat = checked
            Apply()
        end,
    })
    if withMouse then
        row:Checkbox(L['Disable Mouse'], {
            width = 0.5,
            tooltip = L['Drops all mouse handling, so the auras never show a tooltip and never block clicks.'],
            value = db.disableMouse,
            callback = function(checked)
                db.disableMouse = checked
                Apply()
            end,
        })
    end

    return card
end

---Anchor and offsets for the stack and duration strings inside the button.
---@param page KajiGUIPage
---@param db table
---@param ctx table { Apply: fun(), slots?: table[] } slots default to the aura stack and duration strings
---@return KajiGUIFluentCard
function AuraCards:TextPosition(page, db, ctx)
    local Apply = ctx.Apply
    local slots = ctx.slots or self.TextSlots

    local card = page:Card(L['Text Position'], 'all')
    for index, slot in ipairs(slots) do
        local last = index == #slots
        local position = db[slot.key].Position
        local row = card:Row(last and rowHL or rowH, last and 0 or nil)

        row:Dropdown(slot.anchor, {
            width = 0.4,
            options = NRSKNUI.AnchorOptions,
            value = position.AnchorFrom,
            callback = function(key)
                position.AnchorFrom = key
                Apply()
            end,
        })
        row:Slider(slot.x, {
            width = 0.3,
            min = -40,
            max = 40,
            step = 1,
            value = position.XOffset,
            callback = function(val)
                position.XOffset = val
                Apply()
            end,
        })
        row:Slider(slot.y, {
            width = 0.3,
            min = -40,
            max = 40,
            step = 1,
            value = position.YOffset,
            callback = function(val)
                position.YOffset = val
                Apply()
            end,
        })
    end

    return card
end

---@param page KajiGUIPage
---@return KajiGUIFluentCard
function AuraCards:Reload(page)
    local card = page:Card(L['Apply Changes'], 'all')
    -- Sized to its wrapped text, so a narrow window never cuts the sentence off.
    card:Row(20):Text(L['Aura Button Information'], {
        width = 1,
        text = L['Aura buttons are built once by the game and cannot be restyled in place. The preview follows these settings straight away, the real auras pick them up after a reload.'],
        bgMode = 'none',
    })
    card:Row(32):Button(L['Reload UI'], {
        width = 1,
        height = 32,
        callback = function()
            ReloadUI()
        end,
    })

    return card
end
