---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local AuraFilters = NRSKNUI.AuraFilters
local AF = AuraUtil.AuraFilters

local ipairs = ipairs

--[[
Every aura display is the same page, driven by one descriptor per sidebar item:

* filtered - the advanced displays resolve a named filter from db.global.AuraFilters, so they get the Aura Filter card and keep Sorting beside it on a Filter tab.
* The standard displays run a hardcoded HELPFUL/HARMFUL group, so they lose the tab and Sorting moves to Layout.
* harmful  - only harmful displays get the dispel border/icon toggles.
* enchants - standard buffs additionally flow the temporary weapon enchants.
--]]

-- Enum key names rather than values: the db stores the key, resolved at use time (see Defaults.lua).
local SORT_METHODS = {
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

local SORT_DIRECTIONS = {
    { value = 'Normal',  text = L['Normal'] },
    { value = 'Reverse', text = L['Reverse'] },
}

local GROWTH_X = {
    { value = 'RIGHT', text = L['Right'] },
    { value = 'LEFT',  text = L['Left'] },
}

local GROWTH_Y = {
    { value = 'UP',   text = L['Up'] },
    { value = 'DOWN', text = L['Down'] },
}

local TEXT_ANCHORS = {
    { value = 'TOPLEFT',     text = L['Top Left'] },
    { value = 'TOP',         text = L['Top'] },
    { value = 'TOPRIGHT',    text = L['Top Right'] },
    { value = 'LEFT',        text = L['Left'] },
    { value = 'CENTER',      text = L['Center'] },
    { value = 'RIGHT',       text = L['Right'] },
    { value = 'BOTTOMLEFT',  text = L['Bottom Left'] },
    { value = 'BOTTOM',      text = L['Bottom'] },
    { value = 'BOTTOMRIGHT', text = L['Bottom Right'] },
}

-- The stack and duration strings take the same three controls, so the font tab builds both from this.
local TEXT_SLOTS = {
    { key = 'StackFont',    anchor = L['Stack Anchor'],    x = L['Stack X'],    y = L['Stack Y'] },
    { key = 'DurationFont', anchor = L['Duration Anchor'], x = L['Duration X'], y = L['Duration Y'] },
}

local function Apply(display)
    local module = NRSKNUI:GetModule(display.moduleName, true)
    if module then module:ApplySettings() end
end

---Both standard displays live on PlayerAuras, so the module stays on while either one is enabled and
---Auras.Enabled has to track that, it is what Main.lua's bootstrap reads.
---@param checked boolean
local function TogglePlayerAuras(checked)
    local auras = NRSKNUI.db.profile.Auras
    local anyEnabled = auras.Buffs.Enabled or auras.Debuffs.Enabled

    auras.Enabled = anyEnabled
    NRSKNUI:ToggleModule('PlayerAuras', anyEnabled)

    local module = NRSKNUI:GetModule('PlayerAuras', true)
    if module and module:IsEnabled() then module:ApplySettings() end

    -- Blizzard's own frame is reparented away for good once banished, so giving it back needs a reload.
    if not checked then
        NRSKNUI:CreateReloadPrompt(L['Restoring the Blizzard aura frame requires a reload to take full effect.'])
    end
end

local DISPLAYS = {
    {
        pageId = 'advancedDebuffs',
        moduleName = 'AdvancedDebuffs',
        title = L['Advanced Debuffs'],
        enableText = L['Enable Advanced Debuffs'],
        harmful = true,
        filtered = true,
        GetDB = function() return NRSKNUI.db.profile.AdvancedDebuffs end,
        Toggle = function(checked) NRSKNUI:ToggleModule('AdvancedDebuffs', checked) end,
    },
    {
        pageId = 'defensives',
        moduleName = 'Defensives',
        title = L['Defensives'],
        enableText = L['Enable Defensives'],
        harmful = false,
        filtered = true,
        GetDB = function() return NRSKNUI.db.profile.Defensives end,
        Toggle = function(checked) NRSKNUI:ToggleModule('Defensives', checked) end,
    },
    {
        pageId = 'standardBuffs',
        moduleName = 'PlayerAuras',
        title = L['Standard Buffs'],
        enableText = L['Enable Standard Buffs'],
        harmful = false,
        filtered = false,
        enchants = true,
        GetDB = function() return NRSKNUI.db.profile.Auras.Buffs end,
        Toggle = TogglePlayerAuras,
    },
    {
        pageId = 'standardDebuffs',
        moduleName = 'PlayerAuras',
        title = L['Standard Debuffs'],
        enableText = L['Enable Standard Debuffs'],
        harmful = true,
        filtered = false,
        GetDB = function() return NRSKNUI.db.profile.Auras.Debuffs end,
        Toggle = TogglePlayerAuras,
    },
}

local function CreateReloadCard(page)
    local reloadCard = page:Card(L['Apply Changes'], 'all')
    reloadCard:Row(56):Text(L['Aura Button Information'], {
        width = 1,
        text = L['Aura buttons are built once by the game and cannot be restyled in place. These settings are saved immediately but only take effect after a reload.'],
        height = 56,
        bgMode = 'none',
    })
    reloadCard:Row(32):Button(L['Reload UI'], {
        width = 1,
        height = 32,
        callback = function()
            ReloadUI()
        end,
    })
end

local function CreateSortingCard(page, display, db)
    local sortCard = page:Card(L['Sorting'], 'all')
    local sortRow = sortCard:Row(rowHL, 0)
    sortRow:Dropdown(L['Sort Method'], {
        width = 0.5,
        options = SORT_METHODS,
        value = db.sortMethod,
        callback = function(key)
            db.sortMethod = key
            Apply(display)
        end,
    })
    sortRow:Dropdown(L['Sort Direction'], {
        width = 0.5,
        options = SORT_DIRECTIONS,
        value = db.sortDirection,
        callback = function(key)
            db.sortDirection = key
            Apply(display)
        end,
    })
end

-- Filter Tab
local function BuildFilterTab(page, display, db)
    -- Card 1
    page:FilterCard({
        title = L['Aura Filter'],
        label = L['Filter'],
        db = db,
        dbKey = 'Filter',
        filters = function() return AuraFilters:GetList() end,
        noneText = display.harmful and L['None (all harmful)'] or L['None (all helpful)'],
        noneValue = display.harmful and AF.Harmful or AF.Helpful,
        summaryTitle = NRSKNUI:ColorTextByTheme(L['Resolves To']),
        emptyText = L['No filters defined yet. Create one under Aura Filters.'],
        describe = function(name) return AuraFilters:Describe(name) end,
        manageText = L['Manage Filters'],
        onManage = function()
            local window = NRSKNUI.GUIFrame
            if window and window.content then window.content:ShowPage('filterBuilder') end
        end,
        onChangeCallback = function()
            local module = NRSKNUI:GetModule(display.moduleName, true)
            if module then module:ApplyFilter() end
        end,
    })

    -- Card 2
    CreateSortingCard(page, display, db)
end

-- Layout Tab
local function BuildLayoutTab(page, display, db)
    -- Card 1
    local enableCard = page:Card(display.title)
    enableCard:Row(rowHL, 0):Checkbox(display.enableText, {
        width = 1,
        master = true,
        value = db.Enabled,
        msgPopup = true,
        msgText = display.title,
        callback = function(checked)
            db.Enabled = checked
            display.Toggle(checked)
            page:Refresh()
        end,
    })

    -- Card 2
    local gridCard = page:Card(L['Grid'], 'all')
    local countRow = gridCard:Row(rowH)
    countRow:Slider(L['Max Auras'], {
        width = 0.5,
        tooltip = display.filtered and L['Applies per filter branch, so a filter with several branches can show more than this in total.'] or nil,
        min = 1,
        max = 40,
        step = 1,
        value = db.maxFrameCount,
        callback = function(val)
            db.maxFrameCount = val
            Apply(display)
        end,
    })
    countRow:Slider(L['Per Row'], {
        width = 0.5,
        min = 1,
        max = 20,
        step = 1,
        value = db.perRow,
        callback = function(val)
            db.perRow = val
            Apply(display)
        end,
    })

    local spacingRow = gridCard:Row(rowHL, 0)
    spacingRow:Slider(L['Element Spacing'], {
        width = 0.5,
        tooltip = L['Spacing between auras along the row.'],
        min = 0,
        max = 20,
        step = 1,
        value = db.elementSpacing,
        callback = function(val)
            db.elementSpacing = val
            Apply(display)
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
            Apply(display)
        end,
    })

    -- Card 3
    local growthCard = page:Card(L['Growth'], 'all')
    local growthRow = growthCard:Row(rowHL, 0)
    growthRow:Dropdown(L['Horizontal Growth'], {
        width = 0.5,
        options = GROWTH_X,
        value = db.horizontalGrowthDirection,
        callback = function(key)
            db.horizontalGrowthDirection = key
            Apply(display)
        end,
    })
    growthRow:Dropdown(L['Vertical Growth'], {
        width = 0.5,
        options = GROWTH_Y,
        value = db.verticalGrowthDirection,
        callback = function(key)
            db.verticalGrowthDirection = key
            Apply(display)
        end,
    })

    -- Card 4
    if display.enchants then
        local enchantCard = page:Card(L['Weapon Enchants'], 'all')
        enchantCard:Row(rowH):Checkbox(L['Show Weapon Enchants'], {
            width = 1,
            tooltip = L['Flows the temporary main and off-hand enchants in front of the buffs.'],
            value = db.showWeaponEnchants,
            callback = function(checked)
                db.showWeaponEnchants = checked
                NRSKNUI:CreateReloadPrompt(L['Adding or removing the weapon enchants requires a reload to take full effect.'])
            end,
        })

        local groupRow = enchantCard:Row(rowHL, 0)
        groupRow:Slider(L['Group Spacing'], {
            width = 0.5,
            tooltip = L['Spacing at the seam between the weapon enchants and the buffs.'],
            min = 0,
            max = 40,
            step = 1,
            value = db.groupSpacing,
            callback = function(val)
                db.groupSpacing = val
                Apply(display)
            end,
        })
        groupRow:Slider(L['Group Line Spacing'], {
            width = 0.5,
            tooltip = L['Spacing between the weapon enchant rows and the buff rows.'],
            min = 0,
            max = 40,
            step = 1,
            value = db.groupLineSpacing,
            callback = function(val)
                db.groupLineSpacing = val
                Apply(display)
            end,
        })
    end

    -- Card 5: no Filter tab to host it on the standard displays.
    if not display.filtered then
        CreateSortingCard(page, display, db)
    end
end

-- Appearance Tab
local function BuildAppearanceTab(page, display, db)
    -- Card 1
    local sizeCard = page:Card(L['Icons'], 'all')
    sizeCard:Row(rowHL, 0):Slider(L['Size'], {
        width = 1,
        min = 12,
        max = 80,
        step = 1,
        value = db.size,
        callback = function(val)
            db.size = val
            Apply(display) -- resizes the mover host and the wrap width even though buttons keep their size
        end,
    })

    -- Card 2
    local textCard = page:Card(L['Text'], 'all')
    local textRow = textCard:Row(rowHL, 0)
    textRow:Checkbox(L['Show Count'], {
        width = 0.5,
        value = db.showApplicationCount,
        callback = function(checked) db.showApplicationCount = checked end,
    })
    textRow:Checkbox(L['Show Duration'], {
        width = 0.5,
        value = db.showDurationText,
        callback = function(checked) db.showDurationText = checked end,
    })

    -- Card 3
    local cooldownCard = page:Card(L['Cooldown'], 'all')
    local swipeRow = cooldownCard:Row(rowH)
    swipeRow:Checkbox(L['Draw Swipe'], {
        width = 0.5,
        value = db.drawSwipe,
        callback = function(checked) db.drawSwipe = checked end,
    })
    swipeRow:Checkbox(L['Reverse Swipe'], {
        width = 0.5,
        value = db.reverseSwipe,
        callback = function(checked) db.reverseSwipe = checked end,
    })
    cooldownCard:Row(rowHL, 0):Checkbox(L['Draw Edge'], {
        width = 1,
        value = db.drawEdge,
        callback = function(checked) db.drawEdge = checked end,
    })

    -- Card 4
    if display.harmful then
        local dispelCard = page:Card(L['Dispel Indicators'], 'all')
        local dispelRow = dispelCard:Row(rowH)
        dispelRow:Checkbox(L['Show Border'], {
            width = 1,
            tooltip = L['Colors the aura border by dispel type.'],
            value = db.showBorder,
            callback = function(checked) db.showBorder = checked end,
        })

        dispelCard:Separator()

        local dispelIconRow = dispelCard:Row(rowHL, 0)
        dispelIconRow:Checkbox(L['Show Dispel Icon'], {
            width = 0.5,
            tooltip = L['Shows the dispel type icon in the corner of the aura.'],
            value = db.showDebuffDispelIcon,
            callback = function(checked)
                db.showDebuffDispelIcon = checked
                page:Refresh()
            end,
        })
        dispelIconRow:Slider(L['Dispel Icon Size'], {
            width = 0.5,
            min = 4,
            max = 40,
            step = 1,
            value = db.dispelIconSize,
            conditions = { 'showDebuffDispelIcon' },
            callback = function(val) db.dispelIconSize = val end,
        })
    end

    -- Card 5
    local tooltipCard = page:Card(L['Tooltip'], 'all')
    tooltipCard:Row(rowHL, 0):Checkbox(L['Hide Tooltip In Combat'], {
        width = 1,
        value = db.tooltipHideInCombat,
        callback = function(checked) db.tooltipHideInCombat = checked end,
    })

    -- Card 6
    CreateReloadCard(page)
end

-- Font Settings Tab
local function BuildFontTab(page, display, db)
    -- Card 1
    page:FontSettingsCard({
        db = db,
        includeSoftOutline = true,
        globalOverride = {},
        fontSizes = {
            { label = L['Stack Size'],    dbKey = 'StackFont.FontSize' },
            { label = L['Duration Size'], dbKey = 'DurationFont.FontSize' },
        },
        onChangeCallback = function() Apply(display) end,
    })

    -- Card 2
    local textCard = page:Card(L['Text Position'], 'all')
    for index, slot in ipairs(TEXT_SLOTS) do
        local last = index == #TEXT_SLOTS
        local position = db[slot.key].Position
        local row = textCard:Row(last and rowHL or rowH, last and 0 or nil)

        row:Dropdown(slot.anchor, {
            width = 0.4,
            options = TEXT_ANCHORS,
            value = position.AnchorFrom,
            callback = function(key) position.AnchorFrom = key end,
        })
        row:Slider(slot.x, {
            width = 0.3,
            min = -40,
            max = 40,
            step = 1,
            value = position.XOffset,
            callback = function(val) position.XOffset = val end,
        })
        row:Slider(slot.y, {
            width = 0.3,
            min = -40,
            max = 40,
            step = 1,
            value = position.YOffset,
            callback = function(val) position.YOffset = val end,
        })
    end

    -- Card 3
    CreateReloadCard(page)
end

for _, display in ipairs(DISPLAYS) do
    local tabs = { { id = 'layout', text = L['Layout'] } }
    if display.filtered then
        tabs[#tabs + 1] = { id = 'filter', text = L['Filter'] }
    end
    tabs[#tabs + 1] = { id = 'appearance', text = L['Appearance'] }
    tabs[#tabs + 1] = { id = 'font', text = L['Font Settings'] }
    tabs[#tabs + 1] = { id = 'position', text = L['Position Settings'] }

    GUI:RegisterPage(display.pageId, {
        mode = 'tabs',
        search = {},
        tabs = tabs,
        build = function(page, tabId)
            local db = display.GetDB()
            if not db then return end
            page:SetEnabled(function() return db.Enabled end)
            page:SetCondition('showDebuffDispelIcon', function() return db.showDebuffDispelIcon end)

            if tabId == 'layout' then
                BuildLayoutTab(page, display, db)
            elseif tabId == 'filter' then
                BuildFilterTab(page, display, db)
            elseif tabId == 'appearance' then
                BuildAppearanceTab(page, display, db)
            elseif tabId == 'font' then
                BuildFontTab(page, display, db)
            elseif tabId == 'position' then
                page:PositionCard({
                    db = db,
                    showAnchorFrameType = true,
                    showStrata = true,
                    onChangeCallback = function() Apply(display) end,
                })
            end
        end,
    })
end
