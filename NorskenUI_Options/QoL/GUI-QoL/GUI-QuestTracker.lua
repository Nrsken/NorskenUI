---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_QoL') then return end
---@class QuestTrackerModule
local QuestTracker = NRSKNUI:GetModule('QuestTracker')
local L = NRSKNUI.Libs.AL
local GUI = NRSKNUI.GUI
local Theme = NRSKNUI.Theme
local rowH = Theme.rowHeight

local ipairs = ipairs
local tonumber = tonumber
local format = string.format

local RESET_OPTIONS = {
    { key = 'never',  text = L['Never'] },
    { key = 'daily',  text = L['Daily'] },
    { key = 'weekly', text = L['Weekly'] },
}

local CHARACTER_ROW_HEIGHT = 32
local CHARACTER_ICON_SIZE = 24
local CROSS_WIDTH = 0.06
local CROSS = NRSKNUI.Media.GUITextures .. 'NorskenCustomCrossv3.png'
local DELETE_COLOR = { 1, 0, 0 }

-- the Icon widget only takes files and class icons are atlases, so draw one onto its canvas;
-- the canvas hides its regions before every draw, one texture kept on it is enough
---@param classFile string
---@return fun(canvas: Frame): boolean
local function DrawClassIcon(classFile)
    return function(canvas)
        local texture = canvas.NUIClassIcon
        if not texture then
            texture = canvas:CreateTexture(nil, 'ARTWORK')
            texture:NCSetInside(canvas, 0, 0)
            canvas.NUIClassIcon = texture
        end
        texture:SetAtlas(GetClassAtlas(classFile:lower()))
        texture:Show()
        return true
    end
end

---@param card KajiGUIFluentCard
---@param character QuestTrackerCharacter
---@param striped boolean
---@param linkTo? KajiGUIIcon the previous row's icon, for the guide line
---@return KajiGUIIcon
local function CharacterRow(card, character, striped, linkTo)
    local guid = character.guid
    local isPlayer = QuestTracker:IsPlayer(guid)
    local row = card:Row(CHARACTER_ROW_HEIGHT, 0):Stripe(striped)

    local icon = row:Icon({
        width = isPlayer and 1 or 1 - CROSS_WIDTH,
        size = CHARACTER_ICON_SIZE,
        yOffset = -(CHARACTER_ROW_HEIGHT - CHARACTER_ICON_SIZE) / 2,
        draw = DrawClassIcon(character.classFile),
        linkTo = linkTo,
        dimmed = not character.enabled,
        text = { text = NRSKNUI:ColorTextByClass(character.name, character.classFile), description = character.realm, color = Theme.textPrimary },
        tooltip = function(tooltip)
            local muted = Theme.textMuted
            tooltip:AddLine(NRSKNUI:ColorTextByClass(character.name, character.classFile))
            tooltip:AddLine(character.realm, 1, 1, 1)
            tooltip:AddLine(character.enabled and L['Right-click to hide it from the panel'] or L['Right-click to show it on the panel'], muted[1], muted[2], muted[3])
        end,
        onClick = function(button)
            if button ~= 'RightButton' then return end
            QuestTracker:SetCharacterShown(guid, not character.enabled)
            card:Rebuild()
        end,
    })
    if not isPlayer then
        row:Button('', {
            width = CROSS_WIDTH,
            height = CHARACTER_ROW_HEIGHT,
            bare = true,
            image = CROSS,
            imageSize = 12,
            imageRotation = math.rad(45),
            imageColor = DELETE_COLOR,
            tooltip = L['Remove'],
            callback = function() QuestTracker:PromptRemoveCharacter(character, function() card:Rebuild() end) end,
        })
    end
    return icon
end

local function BuildPage(page, db)
    local data = QuestTracker.data
    page:SetEnabled(function() return db.Enabled end)

    -- Card 1: Information
    local infoCard = page:Card(L['Information'], 'all')
    local infoRowSize = 50
    infoCard:Row(infoRowSize):Text(nil, {
        width = 1,
        height = infoRowSize,
        autoHeight = true,
        bgMode = 'hide',
        text = GUI:ColorText('• ') .. L['Status saves as you play, on every character.'] .. '\n' ..
            GUI:ColorText('• ') .. L['Right-click a quest in your log to track it.'] .. '\n' ..
            GUI:ColorText('• ') .. L['Only max level characters are listed.'],
        conditions = { 'all' },
    })

    infoCard:Separator()

    infoCard:Row(rowH, 0):Checkbox(L['Character Tab Only'], {
        width = 1,
        value = db.CharacterTabOnly,
        tooltip = L['Hide the panel on the Reputation and Currency tabs.'],
        conditions = { 'all' },
        callback = function(checked)
            db.CharacterTabOnly = checked
            QuestTracker:ApplySettings()
        end,
    })

    -- Card 2: Tracked quests
    local questCard = page:Card(L['Tracked Quests'], 'all')
    questCard:Rebuild(function(card)
        card:Row(rowH):EditBox(L['Add Quest ID'], {
            width = 1,
            tooltip = L['Type a quest ID and press Enter to track it on every character.'],
            callback = function(text)
                local questID = tonumber(text)
                if not questID then return end
                QuestTracker:AddQuest(questID)
                card:Rebuild()
            end,
        })

        for _, quest in ipairs(data.quests) do
            local questID = quest.questID
            card:Separator()
            local row = card:Row(rowH)
            row:EditBox(format('%s (%d)', quest.title or L['Hidden Quest'], questID), {
                width = 0.6,
                value = quest.name,
                tooltip = L['A name of your own, shown instead of the quest title. Leave empty to use the title.'],
                callback = function(text) QuestTracker:RenameQuest(questID, text) end,
            })
            row:Dropdown(L['Resets'], {
                width = 0.4,
                options = RESET_OPTIONS,
                value = quest.reset or 'never',
                tooltip = L['A Done from before the last reset shows as not started.'],
                callback = function(key) QuestTracker:SetQuestReset(questID, key ~= 'never' and key or nil) end,
            })

            local buttons = card:Row(30)
            buttons:Button(L['Move Up'], {
                width = 1 / 3,
                callback = function()
                    QuestTracker:MoveQuest(questID, -1)
                    card:Rebuild()
                end,
            })
            buttons:Button(L['Move Down'], {
                width = 1 / 3,
                callback = function()
                    QuestTracker:MoveQuest(questID, 1)
                    card:Rebuild()
                end,
            })
            buttons:Button(L['Remove'], {
                width = 1 / 3,
                callback = function()
                    QuestTracker:RemoveQuest(questID)
                    card:Rebuild()
                end,
            })
        end
    end)

    -- Card 3: Characters, styled like the aura trigger's spell lists
    local characterCard = page:Card(L['Characters'], 'all')
    characterCard:Rebuild(function(card)
        local characters = QuestTracker:GetCharacters(true)
        if not characters[1] then
            card:Row(24):Text(nil, {
                width = 1,
                height = 24,
                bgMode = 'hide',
                text = NRSKNUI:ColorText(L['No max level characters yet'], Theme.textMuted),
            })
            return
        end

        local previous
        for index, character in ipairs(characters) do
            previous = CharacterRow(card, character, index % 2 == 0, previous)
        end
    end)
end

GUI:RegisterPage('questTracker', {
    mode = 'clean',
    search = { L['Quest Tracker'], L['Tracked Quests'], L['Characters'] },
    build = function(page)
        local db = NRSKNUI.QuestTracker.db
        if not db then return end

        BuildPage(page, db)
    end,
})
