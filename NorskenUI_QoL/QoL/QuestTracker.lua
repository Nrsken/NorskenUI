---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class QuestTrackerModule
local QuestTracker = NRSKNUI:GetModule('QuestTracker')
local L = NRSKNUI.Libs.AL

local GetMaxLevelForPlayerExpansion = GetMaxLevelForPlayerExpansion
local tremove, tsort = table.remove, table.sort
local GetServerTime = GetServerTime
local ipairs, pairs = ipairs, pairs
local GetRealmName = GetRealmName
local CreateFrame = CreateFrame
local GetQuestID = GetQuestID
local format = string.format
local UnitLevel = UnitLevel
local UnitGUID = UnitGUID
local next = next

local GetSecondsUntilWeeklyReset = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
local GetSecondsUntilDailyReset = C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset
local IsQuestFlaggedCompletedOnAccount = C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount
local IsQuestFlaggedCompleted = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
local RequestLoadQuestByID = C_QuestLog and C_QuestLog.RequestLoadQuestByID
local GetTitleForQuestID = C_QuestLog and C_QuestLog.GetTitleForQuestID
local ReadyForTurnIn = C_QuestLog and C_QuestLog.ReadyForTurnIn
local IsOnQuest = C_QuestLog and C_QuestLog.IsOnQuest
local After = C_Timer and C_Timer.After

-- quest log updates come in bursts, one snapshot after they settle covers the lot
local SNAPSHOT_DELAY = 1

local RESET_PERIOD = { daily = 86400, weekly = 604800 }
local RESET_TIMER = { daily = GetSecondsUntilDailyReset, weekly = GetSecondsUntilWeeklyReset }

function QuestTracker:UpdateDB()
    self.db = self.namespace.profile
    self.data = NRSKNUI.db.global.QuestTracker --[[@as QuestTrackerData]]
end

-- Quests --

---@param questID number
---@return QuestTrackerQuest? quest
---@return number? index
function QuestTracker:GetQuest(questID)
    for index, quest in ipairs(self.data.quests) do
        if quest.questID == questID then
            return quest, index
        end
    end
end

---@param quest QuestTrackerQuest
---@return string
function QuestTracker:GetQuestName(quest)
    return quest.name or quest.title or format(L['Quest %d'], quest.questID)
end

---@param questID number
---@return boolean added false when it was already tracked
function QuestTracker:AddQuest(questID)
    if self:GetQuest(questID) then return false end

    self.data.quests[#self.data.quests + 1] = { questID = questID }
    self:LoadTitle(questID)
    self:Snapshot()
    return true
end

---@param questID number
function QuestTracker:RemoveQuest(questID)
    local _, index = self:GetQuest(questID)
    if not index then return end

    tremove(self.data.quests, index)
    for _, character in pairs(self.data.characters) do
        character.quests[questID] = nil
    end
    self:Refresh()
end

---@param questID number
---@param name string? nil or empty goes back to the quest's own title
function QuestTracker:RenameQuest(questID, name)
    local quest = self:GetQuest(questID)
    if not quest then return end

    quest.name = name ~= '' and name or nil
    self:Refresh()
end

---@param questID number
---@param offset number -1 moves it up, 1 down
function QuestTracker:MoveQuest(questID, offset)
    local quests = self.data.quests
    local _, index = self:GetQuest(questID)
    local target = index and index + offset
    if not target or not quests[target] then return end

    quests[index], quests[target] = quests[target], quests[index]
    self:Refresh()
end

---@param questID number
---@param reset QuestTrackerReset?
function QuestTracker:SetQuestReset(questID, reset)
    local quest = self:GetQuest(questID)
    if not quest then return end

    quest.reset = reset
    self:Refresh()
end

-- a Done saved before the quest last reset is stale, that character can do it again
---@param character QuestTrackerCharacter
---@param quest QuestTrackerQuest
---@return QuestTrackerState?
function QuestTracker:GetState(character, quest)
    local state = character.quests[quest.questID]
    if state ~= 'done' or not quest.reset then
        return state
    end

    local lastReset = GetServerTime() + RESET_TIMER[quest.reset]() - RESET_PERIOD[quest.reset]
    if (character.lastUpdate or 0) < lastReset then
        return 'none'
    end
    return state
end

-- titles are cached so the window can name quests this character has no data for
---@param questID number
function QuestTracker:LoadTitle(questID)
    local quest = self:GetQuest(questID)
    if not quest then return end

    local title = GetTitleForQuestID(questID)
    if title then
        quest.title = title
        return
    end
    RequestLoadQuestByID(questID)
end

function QuestTracker:QUEST_DATA_LOAD_RESULT(_, questID, success)
    if not success then return end
    local quest = self:GetQuest(questID)
    if not quest or quest.title then return end

    quest.title = GetTitleForQuestID(questID)
    self:Refresh()
end

-- Characters --

---@return QuestTrackerCharacter
function QuestTracker:GetPlayer()
    local guid = UnitGUID('player')
    local character = self.data.characters[guid]
    if not character then
        character = { guid = guid, enabled = true, quests = {} }
        self.data.characters[guid] = character
    end

    character.name = NRSKNUI.MyName
    character.realm = GetRealmName()
    character.classFile = NRSKNUI.MyClass
    character.level = UnitLevel('player')
    return character
end

---@param guid string
---@return boolean
function QuestTracker:IsPlayer(guid)
    return guid == UnitGUID('player')
end

---Max level characters only, sorted by realm then name.
---@param includeHidden? boolean
---@return QuestTrackerCharacter[]
function QuestTracker:GetCharacters(includeHidden)
    local maxLevel = GetMaxLevelForPlayerExpansion()
    local list = {}
    for _, character in pairs(self.data.characters) do
        if character.level >= maxLevel and (includeHidden or character.enabled) then
            list[#list + 1] = character
        end
    end

    tsort(list, function(a, b)
        if a.realm ~= b.realm then
            return a.realm < b.realm
        end
        return a.name < b.name
    end)
    return list
end

---@param guid string
---@param shown boolean
function QuestTracker:SetCharacterShown(guid, shown)
    local character = self.data.characters[guid]
    if not character then return end

    character.enabled = shown
    self:Refresh()
end

-- the current character is never removed, its next snapshot would add it straight back
---@param guid string
function QuestTracker:RemoveCharacter(guid)
    if self:IsPlayer(guid) then return end

    self.data.characters[guid] = nil
    self:Refresh()
end

---@param character QuestTrackerCharacter
---@param onRemoved? fun()
function QuestTracker:PromptRemoveCharacter(character, onRemoved)
    local name = NRSKNUI:ColorTextByClass(character.name, character.classFile)
    NRSKNUI:CreatePrompt({
        title = L['Remove Character'],
        text = format(L['Remove %s - %s from the Quest Tracker? Logging in on them adds them back.'], name, character.realm),
        acceptText = L['Remove'],
        cancelText = L['Cancel'],
        onAccept = function()
            self:RemoveCharacter(character.guid)
            if onRemoved then
                onRemoved()
            end
        end,
    })
end

-- Snapshot --

---@param questID number
---@return QuestTrackerState
local function GetQuestState(questID)
    if IsQuestFlaggedCompleted(questID) then
        return 'done'
    elseif ReadyForTurnIn(questID) then
        return 'ready'
    elseif IsOnQuest(questID) then
        return 'active'
    end
    return 'none'
end

function QuestTracker:Snapshot()
    local character = self:GetPlayer()
    for _, quest in ipairs(self.data.quests) do
        character.quests[quest.questID] = GetQuestState(quest.questID)
        -- kept apart from the character's own state, a warbound quest can still be open on this one
        quest.account = IsQuestFlaggedCompletedOnAccount(quest.questID)
    end
    character.lastUpdate = GetServerTime()
    self:Refresh()
end

function QuestTracker:QueueSnapshot()
    if self.snapshotQueued then return end
    if not next(self.data.quests) then return end

    self.snapshotQueued = true
    After(SNAPSHOT_DELAY, self.RunQueuedSnapshot)
end

-- Quest log menu --

local function AddQuestLogEntry(owner, rootDescription)
    local questID = owner.questID
    if not questID then return end

    rootDescription:CreateDivider()
    if QuestTracker:GetQuest(questID) then
        rootDescription:CreateButton(L['Remove from Quest Tracker'], function() QuestTracker:RemoveQuest(questID) end)
    else
        rootDescription:CreateButton(L['Add to Quest Tracker'], function() QuestTracker:AddQuest(questID) end)
    end
end

-- Quest dialog --

local QUEST_BUTTON_WIDTH = 90

local function UpdateQuestButton()
    local button = QuestTracker.questButton
    if not button then return end

    local questID = QuestTracker.dialogQuestID
    button:SetShown(questID ~= nil)
    if not questID then return end

    button:SetText(QuestTracker:GetQuest(questID) and L['Untrack'] or L['Track'])
end

local function ShowQuestButtonTooltip(button)
    GameTooltip:SetOwner(button, 'ANCHOR_TOP')
    GameTooltip:SetText(L['Quest Tracker'], 1, 1, 1)
    GameTooltip:AddLine(L['Follow this quest on every character.'], nil, nil, nil, true)
    GameTooltip:Show()
end

local function ToggleDialogQuest()
    local questID = QuestTracker.dialogQuestID
    if not questID then return end

    if QuestTracker:GetQuest(questID) then
        QuestTracker:RemoveQuest(questID)
    else
        QuestTracker:AddQuest(questID)
    end
    UpdateQuestButton()
end

-- between Accept/Complete and Decline/Goodbye, which every quest panel keeps in its bottom corners
function QuestTracker:CreateQuestButton()
    local button = CreateFrame('Button', nil, QuestFrame, 'UIPanelButtonTemplate')
    button:NUISetPixelSize(QUEST_BUTTON_WIDTH, 22)
    button:NUISetPixelPoint('BOTTOM', QuestFrame, 'BOTTOM', 0, 4)
    button:SetScript('OnClick', ToggleDialogQuest)
    button:SetScript('OnEnter', ShowQuestButtonTooltip)
    button:SetScript('OnLeave', GameTooltip_Hide)
    button:Hide()

    -- match Accept/Decline when the quest frame skin ran
    if QuestFrame.NUISkinned then
        NRSKNUI.Skinning:HandleButton(button)
    end
    self.questButton = button
end

-- driven by the quest events, a hook on QuestFrame would run inside ShowUIPanel's secure stack
---@param event string
function QuestTracker:QuestDialogChanged(event)
    local questID = event ~= 'QUEST_GREETING' and GetQuestID() or 0
    self.dialogQuestID = questID ~= 0 and questID or nil
    if not self.questButton then
        self:CreateQuestButton()
    end
    NRSKNUI:RunWhenSafe(UpdateQuestButton)
end

-- Module --

function QuestTracker.RunQueuedSnapshot()
    QuestTracker.snapshotQueued = nil
    if not QuestTracker:IsEnabled() then return end
    QuestTracker:Snapshot()
end

function QuestTracker:OnEnable()
    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'Snapshot')
    self:RegisterEvent('QUEST_LOG_UPDATE', 'QueueSnapshot')
    self:RegisterEvent('QUEST_TURNED_IN', 'QueueSnapshot')
    self:RegisterEvent('QUEST_DATA_LOAD_RESULT')
    self.questLogMenu = Menu.ModifyMenu('MENU_QUEST_MAP_LOG_TITLE', AddQuestLogEntry)
    self:RegisterEvent('QUEST_DETAIL', 'QuestDialogChanged')
    self:RegisterEvent('QUEST_PROGRESS', 'QuestDialogChanged')
    self:RegisterEvent('QUEST_COMPLETE', 'QuestDialogChanged')
    self:RegisterEvent('QUEST_GREETING', 'QuestDialogChanged')

    for _, quest in ipairs(self.data.quests) do
        if not quest.title then
            self:LoadTitle(quest.questID)
        end
    end

    -- turned on from the GUI, so PLAYER_ENTERING_WORLD already went by
    if NRSKNUI.enteredWorld then
        self:Snapshot()
    end

    self:ShowWindow()
end

function QuestTracker:OnDisable()
    self.snapshotQueued = nil
    if self.questLogMenu then
        self.questLogMenu:Unregister()
        self.questLogMenu = nil
    end
    self.dialogQuestID = nil
    NRSKNUI:RunWhenSafe(UpdateQuestButton)
    self:HideWindow()
end
