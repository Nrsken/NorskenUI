---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class MissingBuffsModule
local MissingBuffs = NRSKNUI:GetModule('MissingBuffs', true)
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local AuraCards = NRSKNUI.GUIAuraCards
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight
local rowHL = Theme.rowHeightLast

local type = type
local select = select
local ipairs = ipairs
local format = string.format
local concat = table.concat
local GetSpecializationInfoByID = GetSpecializationInfoByID

local GetSpellName = C_Spell and C_Spell.GetSpellName
local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture

local GENERAL = 'general'
local QUESTION_MARK = 134400

local MODIFIER_OPTIONS = {
    { key = 'shift', text = L['Shift'] },
    { key = 'alt',   text = L['Alt'] },
    { key = 'ctrl',  text = L['Ctrl'] },
}
local FLYOUT_DIRECTION_OPTIONS = {
    { key = 'UP',    text = L['Up'] },
    { key = 'DOWN',  text = L['Down'] },
    { key = 'LEFT',  text = L['Left'] },
    { key = 'RIGHT', text = L['Right'] },
}
local TEXT_SLOTS = {
    { key = 'CountText', anchor = L['Count Anchor'], x = L['Count X'], y = L['Count Y'] },
    { key = 'TimerText', anchor = L['Timer Anchor'], x = L['Timer X'], y = L['Timer Y'] },
}
local RAID_MODE_OPTIONS = {
    { key = 'group',    text = L['Group'] },
    { key = 'personal', text = L['Personal'] },
}
local EMPTY_BAG_OPTIONS = {
    { key = 'normal',     text = L['Show Normally'] },
    { key = 'desaturate', text = L['Show Desaturated'] },
    { key = 'hide',       text = L['Hide'] },
}
-- One column per spec and weapon slot, only Frost dual wields.
local RUNEFORGE_COLUMNS = {
    { specID = 250, slot = 'TwoHand',  slotText = L['2H'] },
    { specID = 251, slot = 'TwoHand',  slotText = L['2H'] },
    { specID = 251, slot = 'MainHand', slotText = L['MH'] },
    { specID = 251, slot = 'OffHand',  slotText = L['OH'] },
    { specID = 252, slot = 'TwoHand',  slotText = L['2H'] },
}
for _, column in ipairs(RUNEFORGE_COLUMNS) do
    column.specName = select(2, GetSpecializationInfoByID(column.specID))
end
local RUNE_NAME_WIDTH = 0.45
local RUNE_COLUMN_WIDTH = (1 - RUNE_NAME_WIDTH) / #RUNEFORGE_COLUMNS
local RUNE_HEADER_HEIGHT = 32
local RUNE_ROW_HEIGHT = 22
local MODIFIER_TEXT = { shift = L['Shift'], alt = L['Alt'], ctrl = L['Ctrl'] }

local CATEGORIES = {
    Raid = { text = L['Raid Buffs'], tracked = L['Every group member the buff helps, from any caster.'] },
    Presence = { text = L['Group Presence'], tracked = L['Anyone in the group, one copy covers the whole group.'] },
    Targeted = { text = L['Targeted Buffs'], tracked = L['Your own cast, on any group member.'] },
    Self = { text = L['Self Buffs'], tracked = L['Whether you have the buff or weapon enchant.'] },
    Consumable = { text = L['Consumables'], tracked = L['Whether you have the buff.'] },
    Utility = { text = L['Utility'], tracked = L['Shown for a moment after entering a dungeon or raid, while the spell is ready.'] },
}

local GROUP_PAGES = {
    { page = 'missingBuffsRaid',     group = 'Raid',     text = L['Buffs'],          categories = { 'Raid', 'Presence', 'Self', 'Consumable', 'Utility' } },
    { page = 'missingBuffsTargeted', group = 'Targeted', text = L['Targeted Buffs'], categories = { 'Targeted' } },
}

local GENERAL_TABS = {
    { id = 'general', text = L['General'] },
    { id = 'font',    text = L['Font Settings'] },
    { id = 'layout',  text = L['Layout & Position'] },
}
local BUFF_TABS = {
    { id = 'settings', text = L['Settings'] },
    { id = 'glow',     text = L['Glow'] },
    { id = 'load',     text = L['Load Conditions'] },
}

local function ApplySettings()
    if MissingBuffs and MissingBuffs:IsEnabled() then MissingBuffs:ApplySettings() end
end

-- Entries --

---@param entry MissingBuffs.Entry
---@return number?
local function GetEntrySpell(entry)
    local spell = entry.castSpellID or entry.spellID
    if type(spell) == 'table' then return spell[1] end
    return spell
end

local GetEntryName = MissingBuffs.GetEntryName

---@param entry MissingBuffs.Entry
---@return number
local function GetEntryIcon(entry)
    local spell = GetEntrySpell(entry)
    return entry.icon or (spell and GetSpellTexture(spell)) or QUESTION_MARK
end

---@param groupPage table
---@param key string?
---@return MissingBuffs.Entry?, string?
local function FindEntry(groupPage, key)
    for _, category in ipairs(groupPage.categories) do
        for _, entry in ipairs(MissingBuffs.Data[category]) do
            if entry.key == key then return entry, category end
        end
    end
end

-- Sidebar --

---@param groupPage table
---@return fun(): table[]
local function SidebarItems(groupPage)
    return function()
        local buffs = NRSKNUI.db.profile.MissingBuffs.Buffs
        local items = {}

        for _, category in ipairs(groupPage.categories) do
            items[#items + 1] = { type = 'label', key = 'category:' .. category, text = CATEGORIES[category].text }
            for _, entry in ipairs(MissingBuffs.Data[category]) do
                -- An entry sharing another's settings is configured on that entry's page.
                if not entry.settingsKey then
                    items[#items + 1] = {
                        key = entry.key,
                        text = GetEntryName(entry),
                        icon = GetEntryIcon(entry),
                        accent = entry.class and NRSKNUI:GetClassColor(entry.class) or nil,
                        disabled = not buffs[entry.key].Enabled,
                    }
                end
            end
        end

        return items
    end
end

---@param groupPage table
local function RefreshSidebar(groupPage)
    local window = NRSKNUI.GUIFrame
    local sidebar = window and window.content and window.content.miniSidebar
    if not sidebar then return end

    local selected = sidebar:GetSelected()
    sidebar:SetItems(groupPage.items())
    sidebar:SetSelected(selected)
end

-- General Tab --

local function BuildModuleCards(page, db)
    local enableCard = page:Card(L['Missing Buffs'])
    enableCard:Row(rowH):Checkbox(L['Enable Missing Buffs'], {
        width = 1,
        master = true,
        value = db.Enabled == true,
        msgPopup = true,
        msgText = L['Missing Buffs'],
        callback = function(checked)
            db.Enabled = checked
            NRSKNUI:ToggleModule('MissingBuffs', checked)
            page:Refresh()
            if checked and MissingBuffs then MissingBuffs:ShowPreview() end
        end,
    })

    enableCard:Separator()

    local dropdownRow = enableCard:Row(rowHL, 0)
    dropdownRow:Dropdown(L['Raid Buff Mode'], {
        width = 1,
        options = RAID_MODE_OPTIONS,
        value = db.RaidBuffMode,
        tooltip = L['Group shows a raid buff when anyone it helps is missing it. Personal shows it only when you are missing it and someone in the group can cast it. A buff you cast yourself always uses Group.'],
        callback = function(key)
            db.RaidBuffMode = key
            ApplySettings()
        end,
    })

    local behaviourCard = page:Card(L['Behaviour (All Groups)'], 'all')
    behaviourCard:Row(rowH):Checkbox(L['Click to Cast'], {
        width = 1,
        value = db.ClickToCast,
        tooltip = L['Click an icon out of combat to cast the buff or use the consumable.'],
        callback = function(checked)
            db.ClickToCast = checked
            ApplySettings()
        end,
    })

    local itemPickerCard = behaviourCard:Row(rowHL, 0)
    itemPickerCard:Dropdown(L['Item Picker Modifier'], {
        width = 0.5,
        options = MODIFIER_OPTIONS,
        value = db.FlyoutModifier,
        tooltip = L['Hold this and click a flask, rune, food or weapon oil icon to pick which item to use. The pick is remembered for your current spec.'],
        callback = function(key)
            db.FlyoutModifier = key
            ApplySettings()
        end,
    })

    itemPickerCard:Dropdown(L['Item Picker Direction'], {
        width = 0.5,
        options = FLYOUT_DIRECTION_OPTIONS,
        value = db.FlyoutDirection,
        tooltip = L['Which way the item picker opens from the icon.'],
        callback = function(key)
            db.FlyoutDirection = key
            ApplySettings()
        end,
    })
end

local function BuildAppearanceCard(page, db)
    local card = page:Card(L['Appearance'], 'all')
    local row = card:Row(rowHL, 0)
    row:Slider(L['Icon Size'], {
        width = 0.5,
        min = 16,
        max = 80,
        step = 1,
        value = db.IconSize,
        callback = function(val)
            db.IconSize = val
            ApplySettings()
        end,
    })
    row:ColorPicker(L['Border Color'], {
        width = 0.5,
        value = db.BorderColor,
        callback = function(r, g, b, a)
            db.BorderColor = { r, g, b, a }
            ApplySettings()
        end,
    })
end

-- Buff Tabs --

---@param entry MissingBuffs.Entry
---@return string
local function DescribeRequirements(entry)
    local parts = {}
    if entry.class then parts[#parts + 1] = NRSKNUI:ColorTextByClass(LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class, entry.class) end
    if entry.specID then parts[#parts + 1] = select(2, GetSpecializationInfoByID(entry.specID)) end
    if entry.requiresSpellID then parts[#parts + 1] = format(L['Needs %s'], GetSpellName(entry.requiresSpellID) or entry.requiresSpellID) end
    if entry.excludeSpellID then parts[#parts + 1] = format(L['Not with %s'], GetSpellName(entry.excludeSpellID) or entry.excludeSpellID) end
    if entry.casterClass then parts[#parts + 1] = format(L['Needs a %s in the group'], LOCALIZED_CLASS_NAMES_MALE[entry.casterClass] or entry.casterClass) end
    return #parts > 0 and concat(parts, ' · ') or L['All classes']
end

---@param entry MissingBuffs.Entry
---@param info table
---@return string
local function DescribeTracked(entry, info)
    if entry.itemID then return L['Whether you carry one in your bags.'] end
    if entry.itemList == 'WeaponOil' then return L['Whether the weapon has an oil or stone on it.'] end
    if entry.check == 'Runeforge' then return L['Whether your weapon has one of the runes ticked below, or any rune if you leave a column empty.'] end
    if entry.itemList == 'InkyBlackPotion' then return L['Whether you have the buff. Pick the zones under Load Conditions, Zone.'] end
    if info == CATEGORIES.Raid and NRSKNUI.db.profile.MissingBuffs.RaidBuffMode == 'personal'
        and entry.class ~= NRSKNUI.MyClass then
        return L['Whether you have the buff, when someone in the group can cast it.']
    end
    return info.tracked
end

---@param entry MissingBuffs.Entry
---@return string
local function DescribeCombat(entry)
    if MissingBuffs.IsEntryTrackable(entry) then
        return NRSKNUI:ColorText(L['Tracked everywhere, including combat.'], Theme.success)
    elseif entry.glowDetectable then
        return NRSKNUI:ColorText(L['Falls back to the action bar glow in combat, Mythic+ and encounters.'], Theme.warning)
    end
    return NRSKNUI:ColorText(L['Hidden in combat, Mythic+ and encounters, the game keeps it secret there.'], Theme.error)
end

---@param entry MissingBuffs.Entry
---@return string
local function DescribeClick(entry)
    if entry.noClick then return L['Display only.'] end
    if entry.itemList then
        local modifier = MODIFIER_TEXT[NRSKNUI.db.profile.MissingBuffs.FlyoutModifier]
        local picked = entry.itemList == 'Flask' and L['Uses a cauldron flask when you have one, otherwise the flask this spec last picked.']
            or entry.itemList == 'WeaponOil' and L['Uses the oil or stone this spec last picked that fits your weapon.']
            or L['Uses the one this spec last picked.']
        return picked .. ' ' .. format(L['%s-click to pick another.'], modifier)
    end
    local spell = GetEntrySpell(entry)
    local name = spell and GetSpellName(spell)
    if not name then return L['Display only.'] end
    return format(L['Casts %s when you know it.'], name)
end

-- Every spec's runes on one card: runes down the side, each spec and weapon slot a column.
local function BuildRuneforgeCard(page)
    local runeforge = NRSKNUI.db.profile.MissingBuffs.Runeforge
    local runes = MissingBuffs.Runeforges
    local card = page:Card(L['Preferred Runes'], 'all')

    local header = card:Row(RUNE_HEADER_HEIGHT)
    -- The corner reads as a key for the two header lines.
    header:Text('', {
        width = RUNE_NAME_WIDTH,
        height = RUNE_HEADER_HEIGHT,
        text = NRSKNUI:ColorTextByTheme(L['Specialization']) .. '\n' .. L['Weapon'],
    })
    for _, column in ipairs(RUNEFORGE_COLUMNS) do
        header:Text('', {
            width = RUNE_COLUMN_WIDTH,
            height = RUNE_HEADER_HEIGHT,
            justify = 'CENTER',
            text = NRSKNUI:ColorTextByTheme(column.specName) .. '\n' .. column.slotText,
        })
    end
    card:Separator()

    for i, rune in ipairs(runes) do
        local name = GetSpellName(rune.spellID)
        local row = i == #runes and card:Row(RUNE_ROW_HEIGHT + 4, 0) or card:Row(RUNE_ROW_HEIGHT)
        row:Icon({
            width = RUNE_NAME_WIDTH,
            size = 18,
            texture = GetSpellTexture(rune.spellID),
            tooltip = function(tooltip) tooltip:SetSpellByID(rune.spellID) end,
            text = { text = name, position = 'RIGHT' },
        })

        for _, column in ipairs(RUNEFORGE_COLUMNS) do
            local accepted = runeforge[column.specID][column.slot]
            row:SlimCheckbox(nil, {
                width = RUNE_COLUMN_WIDTH,
                align = 'CENTER',
                value = accepted[rune.enchantID] == true,
                tooltip = format('%s, %s: %s', column.specName, column.slotText, name),
                callback = function(checked)
                    -- Written as false rather than cleared, so an unpicked default stays unpicked.
                    accepted[rune.enchantID] = checked
                    ApplySettings()
                end,
            })
        end
    end
end

local function BuildBuffSettingsTab(page, groupPage, entry, category, settings)
    local info = CATEGORIES[category]
    local infoCard = page:Card(GetEntryName(entry))
    infoCard:Row(40):Icon({
        width = 1,
        size = 40,
        texture = GetEntryIcon(entry),
        tooltip = GetEntrySpell(entry) and function(tooltip) tooltip:SetSpellByID(GetEntrySpell(entry)) end or nil,
        text = { text = DescribeRequirements(entry), position = 'RIGHT' },
    })

    infoCard:Separator()

    infoCard:Row(rowHL, 0):Text('', {
        width = 1,
        autoHeight = true,
        bgMode = 'hide',
        text = concat({
            NRSKNUI:ColorTextByTheme(L['Checks: ']) .. DescribeTracked(entry, info),
            NRSKNUI:ColorTextByTheme(L['Combat: ']) .. DescribeCombat(entry),
            NRSKNUI:ColorTextByTheme(L['Click: ']) .. DescribeClick(entry),
        }, '\n'),
    })

    -- No card group, it would grey out the enable toggle with the rest.
    local settingsCard = page:Card(L['Settings'])
    local settingsRow = entry.itemList and settingsCard:Row(rowH) or settingsCard:Row(rowHL, 0)
    settingsRow:Checkbox(format(L['Enable %s'], GetEntryName(entry)), {
        width = 1,
        master = true,
        value = settings.Enabled,
        callback = function(checked)
            settings.Enabled = checked
            page:Refresh()
            RefreshSidebar(groupPage)
            ApplySettings()
        end,
    })

    if not entry.noExpiry or entry.itemList then
        settingsCard:Separator()

        local itemTimerRow = settingsCard:Row(rowHL, 0)
        local warningWidth = entry.itemList and 0.5 or 1

        if not entry.noExpiry then
            itemTimerRow:Slider(L['Warn When Under (Minutes)'], {
                width = warningWidth,
                conditions = { 'all' },
                min = 0,
                max = 60,
                step = 1,
                value = settings.Expiring,
                tooltip = L['Show the icon again once the buff has this many minutes left, 0 turns it off.'],
                callback = function(val)
                    settings.Expiring = val
                    ApplySettings()
                end,
            })
        end

        if entry.itemList then
            itemTimerRow:Dropdown(L['Empty Bags'], {
                width = 0.5,
                conditions = { 'all' },
                options = EMPTY_BAG_OPTIONS,
                value = settings.EmptyBagMode,
                tooltip = L['What the icon does when you have none of the item in your bags.'],
                callback = function(key)
                    settings.EmptyBagMode = key
                    ApplySettings()
                end,
            })
        end
    end

    if entry.check == 'Runeforge' then BuildRuneforgeCard(page) end
end

-- Pages --

for _, groupPage in ipairs(GROUP_PAGES) do
    groupPage.items = SidebarItems(groupPage)

    GUI:RegisterPage(groupPage.page, {
        mode = 'tabs',
        search = { L['Missing Buffs'], groupPage.text },
        sidebar = {
            buttons = { { text = L['General Settings'], key = GENERAL } },
            items = groupPage.items,
            width = 210,
            default = GENERAL,
        },
        tabs = function(itemKey)
            return itemKey == GENERAL and GENERAL_TABS or BUFF_TABS
        end,
        build = function(page, tabId, itemKey)
            local db = NRSKNUI.db.profile.MissingBuffs
            if not db then return end
            page:SetEnabled(function() return db.Enabled == true end)

            if itemKey == GENERAL then
                local groupDb = db.Groups[groupPage.group]
                if tabId == 'general' then
                    BuildModuleCards(page, db)
                    BuildAppearanceCard(page, groupDb)
                elseif tabId == 'font' then
                    page:FontSettingsCard({ db = groupDb, includeSoftOutline = true, onChangeCallback = ApplySettings, globalOverride = {} })
                    AuraCards:TextPosition(page, groupDb, { Apply = ApplySettings, slots = TEXT_SLOTS })
                elseif tabId == 'layout' then
                    page:DynamicGroupCard({ title = L['Layout'], db = groupDb.Config, showLimit = false, onChangeCallback = ApplySettings })
                    page:PositionCard({ db = groupDb, showAnchorFrameType = true, showStrata = true, onChangeCallback = ApplySettings })
                end
                return
            end

            local entry, category = FindEntry(groupPage, itemKey)
            if not entry or not category then return end
            local settings = db.Buffs[entry.key]
            page:SetEnabled(function() return db.Enabled == true and settings.Enabled == true end)

            if tabId == 'settings' then
                BuildBuffSettingsTab(page, groupPage, entry, category, settings)
            elseif tabId == 'glow' then
                page:GlowSettingsCard({
                    db = settings,
                    showGlowMode = true,
                    onChangeCallback = function()
                        if MissingBuffs and MissingBuffs:IsEnabled() then MissingBuffs:RefreshGlow(entry.key) end
                    end,
                })
            elseif tabId == 'load' then
                page:LoadConditionsCard({
                    db = settings.LoadConditions,
                    onChangeCallback = function()
                        if MissingBuffs and MissingBuffs:IsEnabled() then MissingBuffs:RequestUpdate() end
                    end,
                })
            end
        end,
    })
end
