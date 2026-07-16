---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class CombatMessage
local CombatMessage = NRSKNUI:GetModule('CombatMessage')
local GUIFrame = NRSKNUI.GUIFrame
local Theme = NRSKNUI.Theme
local LSM = NRSKNUI.Libs.LSM

local ipairs, pairs = ipairs, pairs

GUIFrame:RegisterContent('combatMessage', function(scrollChild, yOffset)
    local db = NRSKNUI.db and NRSKNUI.db.profile.CombatMessage
    if not db then return GUIFrame:ShowDBError(scrollChild, yOffset) end

    local manager = GUIFrame:CreateWidgetStateManager()
    local function ApplySettings() CombatMessage:ApplySettings() end
    local function UpdateAllWidgetStates() manager:UpdateAll(db.Enabled) end
    manager:SetCondition('enter', function() return db.EnterCombat.Enabled end)
    manager:SetCondition('exit', function() return db.ExitCombat.Enabled end)
    manager:SetCondition('noTarget', function() return db.NoTarget.Enabled end)
    manager:SetCondition('partyDeath', function() return db.PartyDeath.Enabled end)

    -- Card 1
    local card1 = GUIFrame:CreateCard(scrollChild, 'Combat Messages', yOffset)

    local row1 = GUIFrame:CreateRow(card1.content, Theme.rowHeightLast)
    local enableCheck = GUIFrame:CreateCheckbox(row1, 'Enable Combat Messages', {
        value = db.Enabled,
        callback = function(checked)
            db.Enabled = checked
            if checked then
                NRSKNUI:EnableModule('CombatMessage')
            else
                NRSKNUI:DisableModule('CombatMessage')
            end
            UpdateAllWidgetStates()
        end,
        msgPopup = true,
        msgText = 'Combat Messages',
    })
    row1:AddWidget(enableCheck, 1)
    card1:AddRow(row1, Theme.rowHeightLast, 0)

    yOffset = card1:GetNextOffset()

    -- Card 5
    local card5 = GUIFrame:CreateCard(scrollChild, 'General Settings', yOffset)
    manager:Register(card5, 'all')

    local row5b = GUIFrame:CreateRow(card5.content, Theme.rowHeightLast)
    local durationSlider = GUIFrame:CreateSlider(row5b, 'Message Duration', {
        min = 1,
        max = 10,
        step = 0.5,
        value = db.Duration,
        callback = function(val)
            db.Duration = val
            ApplySettings()
        end
    })
    row5b:AddWidget(durationSlider, 1)
    manager:Register(durationSlider, 'all')
    card5:AddRow(row5b, Theme.rowHeightLast, 0)

    yOffset = card5:GetNextOffset()

    -- Card 2
    local card2 = GUIFrame:CreateCard(scrollChild, 'Message Types', yOffset)
    manager:Register(card2, 'all')

    local row2a = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local enterEnableCheck = GUIFrame:CreateCheckbox(row2a, 'Enter Combat', {
        value = db.EnterCombat.Enabled,
        callback = function(checked)
            db.EnterCombat.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2a:AddWidget(enterEnableCheck, 0.25)
    manager:Register(enterEnableCheck, 'all')

    local enterColorPicker = GUIFrame:CreateColorPicker(row2a, 'Color', {
        color = db.EnterCombat.Color,
        callback = function(r, g, b, a)
            db.EnterCombat.Color = { r, g, b, a }
            ApplySettings()
        end
    })
    row2a:AddWidget(enterColorPicker, 0.25)
    manager:Register(enterColorPicker, 'all', 'enter')

    local enterTextInput = GUIFrame:CreateEditBox(row2a, 'Text', {
        value = db.EnterCombat.Text,
        callback = function(val)
            db.EnterCombat.Text = val
            ApplySettings()
        end
    })
    row2a:AddWidget(enterTextInput, 0.5)
    manager:Register(enterTextInput, 'all', 'enter')
    card2:AddRow(row2a, Theme.rowHeight)

    local sep1 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep1, Theme.rowHeightSeparator)

    local row2b = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local exitEnableCheck = GUIFrame:CreateCheckbox(row2b, 'Exit Combat', {
        value = db.ExitCombat.Enabled,
        callback = function(checked)
            db.ExitCombat.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2b:AddWidget(exitEnableCheck, 0.25)
    manager:Register(exitEnableCheck, 'all')

    local exitColorPicker = GUIFrame:CreateColorPicker(row2b, 'Color', {
        color = db.ExitCombat.Color,
        callback = function(r, g, b, a)
            db.ExitCombat.Color = { r, g, b, a }
            ApplySettings()
        end
    })
    row2b:AddWidget(exitColorPicker, 0.25)
    manager:Register(exitColorPicker, 'all', 'exit')

    local exitTextInput = GUIFrame:CreateEditBox(row2b, 'Text', {
        value = db.ExitCombat.Text,
        callback = function(val)
            db.ExitCombat.Text = val
            ApplySettings()
        end
    })
    row2b:AddWidget(exitTextInput, 0.5)
    manager:Register(exitTextInput, 'all', 'exit')
    card2:AddRow(row2b, Theme.rowHeight)

    local sep2 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep2, Theme.rowHeightSeparator)

    local row2c = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local noTargetEnableCheck = GUIFrame:CreateCheckbox(row2c, 'No Target', {
        value = db.NoTarget.Enabled,
        callback = function(checked)
            db.NoTarget.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2c:AddWidget(noTargetEnableCheck, 0.25)
    manager:Register(noTargetEnableCheck, 'all')

    local noTargetColorPicker = GUIFrame:CreateColorPicker(row2c, 'Color', {
        color = db.NoTarget.Color,
        callback = function(r, g, b, a)
            db.NoTarget.Color = { r, g, b, a }
            ApplySettings()
        end
    })
    row2c:AddWidget(noTargetColorPicker, 0.25)
    manager:Register(noTargetColorPicker, 'all', 'noTarget')

    local noTargetTextInput = GUIFrame:CreateEditBox(row2c, 'Text', {
        value = db.NoTarget.Text,
        callback = function(val)
            db.NoTarget.Text = val
            ApplySettings()
        end
    })
    row2c:AddWidget(noTargetTextInput, 0.5)
    manager:Register(noTargetTextInput, 'all', 'noTarget')
    card2:AddRow(row2c, Theme.rowHeight)

    local sep3 = GUIFrame:CreateSeparator(card2.content)
    card2:AddRow(sep3, Theme.rowHeightSeparator)

    local row2e = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local deathEnableCheck = GUIFrame:CreateCheckbox(row2e, 'Group Member Died', {
        value = db.PartyDeath.Enabled,
        callback = function(checked)
            db.PartyDeath.Enabled = checked
            ApplySettings()
            UpdateAllWidgetStates()
        end
    })
    row2e:AddWidget(deathEnableCheck, 0.25)
    manager:Register(deathEnableCheck, 'all')

    local deathTextColor = GUIFrame:CreateColorPicker(row2e, 'Text Color', {
        color = db.PartyDeath.Color,
        callback = function(r, g, b, a)
            db.PartyDeath.Color = { r, g, b, a }
            ApplySettings()
        end
    })
    row2e:AddWidget(deathTextColor, 0.25)
    manager:Register(deathTextColor, 'all', 'partyDeath')

    local deathFormatInput = GUIFrame:CreateEditBox(row2e, 'Text Format', {
        tooltip = 'Use |cffffffff%name|r to insert the name of the player who died and |cffffffff{rt1} - {rt8}|r to insert raid target icons.',
        value = db.PartyDeath.Text,
        callback = function(val)
            db.PartyDeath.Text = val
            ApplySettings()
        end
    })
    row2e:AddWidget(deathFormatInput, 0.5)
    manager:Register(deathFormatInput, 'all', 'partyDeath')
    card2:AddRow(row2e, Theme.rowHeight)

    local row2f = GUIFrame:CreateRow(card2.content, Theme.rowHeight)
    local deathClassColorCheck = GUIFrame:CreateCheckbox(row2f, 'Class Colored Name', {
        value = db.PartyDeath.UseClassColor,
        callback = function(checked)
            db.PartyDeath.UseClassColor = checked
            ApplySettings()
        end
    })
    row2f:AddWidget(deathClassColorCheck, 0.5)
    manager:Register(deathClassColorCheck, 'all', 'partyDeath')

    local deathLoadDropdown = GUIFrame:CreateDropdown(row2f, 'Load', {
        options = {
            { key = 'ALWAYS',   text = 'Always' },
            { key = 'ANYGROUP', text = 'Any Group' },
            { key = 'PARTY',    text = 'In Party' },
            { key = 'RAID',     text = 'In Raid' },
        },
        value = db.PartyDeath.LoadCondition,
        callback = function(key)
            db.PartyDeath.LoadCondition = key
            ApplySettings()
        end
    })
    row2f:AddWidget(deathLoadDropdown, 0.5)
    manager:Register(deathLoadDropdown, 'all', 'partyDeath')
    card2:AddRow(row2f, Theme.rowHeight)

    local soundList = { ['None'] = 'None' }
    if LSM then
        for name in pairs(LSM:HashTable('sound')) do
            soundList[name] = name
        end
    end

    local roleSounds = {
        { label = 'Tank Sound',   dbKey = 'SoundTank',    last = false },
        { label = 'Healer Sound', dbKey = 'SoundHealer',  last = false },
        { label = 'DPS Sound',    dbKey = 'SoundDamager', last = true },
    }

    for _, role in ipairs(roleSounds) do
        local rowHeight = role.last and Theme.rowHeightLast or Theme.rowHeight
        local soundRow = GUIFrame:CreateRow(card2.content, rowHeight)

        local soundDropdown = GUIFrame:CreateDropdown(soundRow, role.label, {
            options = soundList,
            value = db.PartyDeath[role.dbKey] or 'None',
            callback = function(key)
                db.PartyDeath[role.dbKey] = key
            end,
            searchable = true
        })
        soundRow:AddWidget(soundDropdown, 0.5)
        manager:Register(soundDropdown, 'all', 'partyDeath')

        local testBtn = GUIFrame:CreateButton(soundRow, 'Test', {
            width = 60,
            height = 24,
            callback = function()
                local soundName = db.PartyDeath[role.dbKey]
                if soundName and soundName ~= 'None' and LSM then
                    NRSKNUI:PlaySound(LSM:Fetch('sound', soundName))
                end
            end,
        })
        soundRow:AddWidget(testBtn, 0.5, nil, 0, -14)
        manager:Register(testBtn, 'all', 'partyDeath')

        card2:AddRow(soundRow, rowHeight, role.last and 0 or nil)
    end

    yOffset = card2:GetNextOffset()

    -- Card 4
    local layoutCard, layoutOffset, layoutWidgets = GUIFrame:CreateDynamicGroupCard(scrollChild, yOffset, {
        title = 'Layout',
        db = db.Config,
        onChangeCallback = ApplySettings,
    })
    manager:Register(layoutCard, 'all')
    manager:RegisterGroup(layoutWidgets, 'all')

    yOffset = layoutOffset

    -- Card 5
    local fontCard, fontOffset, fontWidgets = GUIFrame:CreateFontSettingsCard(scrollChild, yOffset, {
        title = 'Font Settings',
        db = db,
        dbKeys = { fontFace = 'FontFace', fontOutline = 'FontOutline', shadow = 'FontShadow' },
        fontSizes = {
            { label = 'Enter Combat',      dbKey = 'EnterCombat.FontSize' },
            { label = 'Exit Combat',       dbKey = 'ExitCombat.FontSize' },
            { label = 'No Target',         dbKey = 'NoTarget.FontSize' },
            { label = 'Group Member Died', dbKey = 'PartyDeath.FontSize' },
        },
        includeSoftOutline = true,
        onChangeCallback = ApplySettings,
        globalOverride = {},
    })
    manager:Register(fontCard, 'all')
    manager:RegisterGroup(fontWidgets, 'all')

    yOffset = fontOffset

    -- Card 6
    local posCard, posOffset, posWidgets = GUIFrame:CreatePositionCard(scrollChild, yOffset, {
        db = db,
        showAnchorFrameType = true,
        showStrata = true,
        onChangeCallback = ApplySettings,
    })
    manager:Register(posCard, 'all')
    manager:RegisterGroup(posWidgets, 'all')

    yOffset = posOffset

    UpdateAllWidgetStates()

    return yOffset
end)
