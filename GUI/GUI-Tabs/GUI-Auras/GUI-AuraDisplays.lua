---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local AuraFilters = NRSKNUI.AuraFilters
local AuraCards = NRSKNUI.GUIAuraCards
local AF = AuraUtil.AuraFilters

local ipairs = ipairs

--[[
Every aura display is the same page, driven by one descriptor per sidebar item:

* filtered - the advanced displays resolve a named filter from db.global.AuraFilters, so they get the Aura Filter card and keep Sorting beside it on a Filter tab.
* The standard displays run a hardcoded HELPFUL/HARMFUL group, so they lose the tab and Sorting moves to Layout.
* harmful  - only harmful displays get the dispel border/icon toggles.
* enchants - standard buffs additionally flow the temporary weapon enchants.

The cards themselves live in GUI/GUI-AuraCards.lua, shared with the per-unit containers under GUI-UnitFrames.
--]]

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

    ---@class PlayerAurasModule
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
        pageId = 'speed',
        moduleName = 'Speed',
        title = L['Speed'],
        enableText = L['Enable Speed'],
        harmful = true,
        filtered = true,
        GetDB = function() return NRSKNUI.db.profile.Speed end,
        Toggle = function(checked) NRSKNUI:ToggleModule('Speed', checked) end,
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

-- Filter Tab
local function BuildFilterTab(page, display, db, ctx)
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
            ---@type NRSKNUI.AuraModule
            local module = NRSKNUI:GetModule(display.moduleName, true)
            if module then module:ApplyFilter() end
        end,
    })

    -- Card 2
    AuraCards:Sorting(page, db, ctx)
end

-- Layout Tab
local function BuildLayoutTab(page, display, db, ctx)
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
    AuraCards:Grid(page, db, ctx)

    -- Card 3
    AuraCards:Growth(page, db, ctx)

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
        AuraCards:Sorting(page, db, ctx)
    end
end

-- Appearance Tab
local function BuildAppearanceTab(page, display, db, ctx)
    -- Card 1
    AuraCards:Icons(page, db, ctx)

    -- Card 2
    AuraCards:Text(page, db, ctx)

    -- Card 3
    AuraCards:Cooldown(page, db, ctx)

    -- Card 4
    if display.harmful then
        AuraCards:Dispel(page, db, ctx)
    end

    -- Card 5
    AuraCards:Tooltip(page, db, ctx)

    -- Card 6
    AuraCards:Reload(page)
end

-- Font Settings Tab
local function BuildFontTab(page, display, db, ctx)
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
    AuraCards:TextPosition(page, db, ctx)

    -- Card 3
    AuraCards:Reload(page)
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

            local ctx = {
                Apply = function() Apply(display) end,
                filtered = display.filtered,
                dispelIconKey = 'showDebuffDispelIcon',
                withoutDispelType = true,
            }

            if tabId == 'layout' then
                BuildLayoutTab(page, display, db, ctx)
            elseif tabId == 'filter' then
                BuildFilterTab(page, display, db, ctx)
            elseif tabId == 'appearance' then
                BuildAppearanceTab(page, display, db, ctx)
            elseif tabId == 'font' then
                BuildFontTab(page, display, db, ctx)
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
