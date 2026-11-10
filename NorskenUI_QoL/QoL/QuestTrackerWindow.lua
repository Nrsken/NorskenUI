---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class QuestTrackerModule
local QuestTracker = NRSKNUI:GetModule('QuestTracker')
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme

local CreateFrame = CreateFrame
local GameTooltip = GameTooltip
local ipairs = ipairs
local format = string.format

local MEDIA = NRSKNUI.Media.GUITextures
local WINDOW_NAME = 'NRSKNUI_QuestTrackerWindow'
local WIDTH = 240
local PADDING = 6
local TITLE_HEIGHT = 16
local TITLE_GAP = 6
local EYE_SIZE = 18
local COG_SIZE = 12
local BAR_HEIGHT = 20
local BAR_GAP = 3
local TEXT_INSET = 6
local FILL_ALPHA = 0.9
local BARS_Y = PADDING + TITLE_HEIGHT + TITLE_GAP
local ANCHOR_OFFSET_Y = -40

local STATES = {
    done    = { text = L['Done'], color = { 0.30, 0.85, 0.40 } },
    ready   = { text = L['Turn In'], color = { 1.00, 0.82, 0.00 } },
    active  = { text = L['In Progress'], color = { 1.00, 1.00, 1.00 } },
    none    = { text = L['Not Started'], color = Theme.textSecondary },
    unknown = { text = L['No Data'], color = Theme.textSecondary },
}

local RESET_TEXT = {
    daily = L['Resets daily'],
    weekly = L['Resets weekly'],
}

---@param fontString FontString
---@param size "small"|"normal"|"medium"|"large"
local function StyleText(fontString, size)
    NRSKNUI.GUI:ApplyFont(fontString, size)
    fontString:SetWordWrap(false)
end

---@param parent Frame
---@param texture string
---@param size number
---@param tooltip string
---@param onClick fun()
---@return Button
local function CreateTitleButton(parent, texture, size, tooltip, onClick)
    local button = CreateFrame('Button', nil, parent)
    button:NUISetPixelSize(size, size)

    local icon = button:CreateTexture(nil, 'ARTWORK')
    icon:NUISetPixelInside(button, 0, 0)
    icon:NUISetPixelSnap()
    icon:SetTexture(texture)
    icon:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    button:SetNormalTexture(icon)

    button:SetScript('OnEnter', function(self)
        icon:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
        GameTooltip:SetOwner(self, 'ANCHOR_TOP')
        GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    button:SetScript('OnLeave', function()
        icon:SetVertexColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
        GameTooltip:Hide()
    end)
    button:SetScript('OnClick', onClick)
    return button
end

-- Title buttons --

local function OpenCharactersMenu()
    local entries = {}
    for _, character in ipairs(QuestTracker:GetCharacters(true)) do
        local name = NRSKNUI:ColorTextByClass(character.name, character.classFile) .. ' - ' .. character.realm
        if not character.enabled then
            name = '|cff808080' .. character.name .. ' - ' .. character.realm .. '|r'
        end
        entries[#entries + 1] = {
            text = name,
            submenu = {
                {
                    text = character.enabled and L['Hide'] or L['Show'],
                    onClick = function() QuestTracker:SetCharacterShown(character.guid, not character.enabled) end,
                },
                {
                    text = L['Remove'],
                    disabled = QuestTracker:IsPlayer(character.guid),
                    onClick = function() QuestTracker:PromptRemoveCharacter(character) end,
                },
            },
        }
    end

    if not entries[1] then
        entries[1] = { text = L['No max level characters yet'], disabled = true }
    end
    NRSKNUI.GUI:ShowContextMenu(entries)
end

local function OpenSettings()
    NRSKNUI:OpenOptions('questTracker')
end

-- Bars --

local function ShowQuestTooltip(bar)
    local quest = bar.quest
    if not quest then return end

    local secondary = Theme.textSecondary
    GameTooltip:SetOwner(bar, 'ANCHOR_RIGHT')
    GameTooltip:SetText(QuestTracker:GetQuestName(quest), 1, 1, 1)
    GameTooltip:AddLine(format(L['Quest ID: %d'], quest.questID), secondary[1], secondary[2], secondary[3])
    if quest.reset then
        GameTooltip:AddLine(RESET_TEXT[quest.reset], secondary[1], secondary[2], secondary[3])
    end
    if quest.account then
        GameTooltip:AddLine(L['Completed on this account'], 0.40, 0.70, 1.00)
    end

    GameTooltip:AddLine(' ')
    for _, character in ipairs(QuestTracker:GetCharacters()) do
        local state = STATES[QuestTracker:GetState(character, quest) or 'unknown']
        GameTooltip:AddDoubleLine(NRSKNUI:ColorTextByClass(character.name, character.classFile), state.text, 1, 1, 1, state.color[1], state.color[2], state.color[3])
    end

    GameTooltip:AddLine(' ')
    GameTooltip:AddLine(L['Right-click to stop tracking.'], secondary[1], secondary[2], secondary[3])
    GameTooltip:Show()
end

local function OpenQuestMenu(bar, button)
    if button ~= 'RightButton' or not bar.quest then return end

    local questID = bar.quest.questID
    NRSKNUI.GUI:ShowContextMenu({
        { text = L['Stop Tracking'], onClick = function() QuestTracker:RemoveQuest(questID) end },
    })
end

---@param window Frame
---@param index number
---@return Button
local function AcquireBar(window, index)
    local bar = window.bars[index]
    if bar then
        return bar
    end

    local y = -BARS_Y - (index - 1) * (BAR_HEIGHT + BAR_GAP)
    bar = CreateFrame('Button', nil, window)
    bar:NUISetPixelHeight(BAR_HEIGHT)
    bar:NUISetPixelPoint('TOPLEFT', window, 'TOPLEFT', PADDING, y)
    bar:NUISetPixelPoint('TOPRIGHT', window, 'TOPRIGHT', -PADDING, y)
    bar:RegisterForClicks('RightButtonUp')
    bar:SetScript('OnEnter', ShowQuestTooltip)
    bar:SetScript('OnLeave', GameTooltip_Hide)
    bar:SetScript('OnClick', OpenQuestMenu)
    NRSKNUI:CreateBackdrop(bar)
    bar:SetBackgroundColor(Theme.bgDark[1], Theme.bgDark[2], Theme.bgDark[3], 0.8)
    bar:SetBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    local fill = bar:CreateTexture(nil, 'ARTWORK')
    fill:NUISetPixelInside(bar, 1, 1)
    fill:SetTexture(NRSKNUI:GetStatusbar(nil, 'NorskenUI'))
    fill:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], FILL_ALPHA)
    bar.fill = fill

    local highlight = bar:CreateTexture(nil, 'HIGHLIGHT')
    highlight:NUISetPixelInside(bar, 1, 1)
    highlight:SetColorTexture(1, 1, 1, 0.08)

    local count = bar:CreateFontString(nil, 'OVERLAY')
    count:NUISetPixelPoint('RIGHT', bar, 'RIGHT', -TEXT_INSET, 0)
    count:SetJustifyH('RIGHT')
    StyleText(count, 'small')
    bar.count = count

    local label = bar:CreateFontString(nil, 'OVERLAY')
    label:NUISetPixelPoint('LEFT', bar, 'LEFT', TEXT_INSET, 0)
    label:NUISetPixelPoint('RIGHT', count, 'LEFT', -TEXT_INSET, 0)
    label:SetJustifyH('LEFT')
    StyleText(label, 'small')
    bar.label = label

    window.bars[index] = bar
    return bar
end

-- Window --

local function LayoutWindow()
    QuestTracker:LayoutWindow()
end

---@return Frame
local function GetParentFrame()
    return QuestTracker.db.CharacterTabOnly and PaperDollFrame or CharacterFrame
end

function QuestTracker:CreateWindow()
    if self.window then
        return self.window
    end

    -- a child of the Character Frame, so it opens and closes with it without any Show/Hide from us
    local window = CreateFrame('Frame', WINDOW_NAME, GetParentFrame())
    window:EnableMouse(true)
    window:NUISetPixelSnap()
    NRSKNUI:CreateBackdrop(window)
    window:SetBackgroundColor(Theme.bgMedium[1], Theme.bgMedium[2], Theme.bgMedium[3], 0.95)
    window:SetBorderColor(Theme.border[1], Theme.border[2], Theme.border[3], Theme.border[4])

    -- anchored into the Character Frame's protected family, its OnShow can run inside ShowUIPanel's secure stack
    window:NUISetScheduledUpdate(function() NRSKNUI:RunWhenSafe(LayoutWindow) end)
    -- hidden flag quests complete without a quest event, so re-read them whenever the panel opens
    window:SetScript('OnShow', function() QuestTracker:Snapshot() end)

    local title = window:CreateFontString(nil, 'OVERLAY')
    -- a fixed row on whole pixels, the font's own line height would centre it on a half pixel
    title:NUISetPixelPoint('TOPLEFT', window, 'TOPLEFT', PADDING, -PADDING)
    title:NUISetPixelPoint('TOPRIGHT', window, 'TOPRIGHT', -PADDING, -PADDING)
    title:NUISetPixelHeight(TITLE_HEIGHT)
    title:SetJustifyH('LEFT')
    title:SetJustifyV('MIDDLE')
    title:SetTextColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    StyleText(title, 'medium')
    title:SetText(L['Quest Tracker'])

    local characters = CreateTitleButton(window, MEDIA .. 'eye.png', EYE_SIZE, L['Characters'], OpenCharactersMenu)
    characters:NUISetPixelPoint('RIGHT', window, 'TOPRIGHT', -PADDING + 1, -PADDING - TITLE_HEIGHT / 2)

    local settings = CreateTitleButton(window, MEDIA .. 'cogwheel.png', COG_SIZE, L['Settings'], OpenSettings)
    settings:NUISetPixelPoint('RIGHT', characters, 'LEFT', -PADDING + 1, 0)

    local empty = window:CreateFontString(nil, 'OVERLAY')
    empty:NUISetPixelPoint('LEFT', window, 'TOPLEFT', PADDING + TEXT_INSET, -BARS_Y - BAR_HEIGHT / 2)
    empty:SetTextColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 1)
    StyleText(empty, 'small')
    empty:SetText(L['No quests tracked yet, add them in the settings.'])
    window.empty = empty

    window.bars = {}
    self.window = window
    return window
end

function QuestTracker:LayoutWindow()
    local window = self.window
    if not (window and window:IsVisible()) then return end

    local quests = self.data.quests
    local characters = self:GetCharacters()
    local player = self:GetPlayer()

    for index, quest in ipairs(quests) do
        local bar = AcquireBar(window, index)
        local done = 0
        for _, character in ipairs(characters) do
            if self:GetState(character, quest) == 'done' then
                done = done + 1
            end
        end

        bar.quest = quest
        bar.label:SetText(self:GetQuestName(quest))
        bar.count:SetText(format('%d/%d', done, #characters))
        bar.fill:SetShown(self:GetState(player, quest) == 'done')
        bar:Show()
    end
    for index = #quests + 1, #window.bars do
        window.bars[index].quest = nil
        window.bars[index]:Hide()
    end
    window.empty:SetShown(not quests[1])

    -- sized before it is anchored, the grid snap measures the window's own height
    local rows = quests[1] and #quests or 1
    window:NUISetPixelSize(WIDTH, BARS_Y + rows * BAR_HEIGHT + (rows - 1) * BAR_GAP + PADDING)

    -- the Character Frame can sit on a half pixel, so snap the result instead of the offset
    window:ClearAllPoints()
    window:NUISetGridPoint('TOPLEFT', CharacterFrame, 'BOTTOMLEFT', 0, ANCHOR_OFFSET_Y)
end

function QuestTracker:Refresh()
    if not self.window then return end
    self.window:NUIScheduleUpdate()
end

local function ShowWindow()
    QuestTracker:CreateWindow():Show()
end

local function HideWindow()
    if QuestTracker.window then
        QuestTracker.window:Hide()
    end
end

local function ApplyParent()
    local window = QuestTracker.window
    if not window then return end

    window:SetParent(GetParentFrame())
    window:NUIScheduleUpdate()
end

function QuestTracker:ShowWindow()
    NRSKNUI:RunWhenSafe(ShowWindow)
end

function QuestTracker:HideWindow()
    NRSKNUI:RunWhenSafe(HideWindow)
end

function QuestTracker:ApplySettings()
    NRSKNUI:RunWhenSafe(ApplyParent)
end
