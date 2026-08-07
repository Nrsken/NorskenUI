---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class AutomationModule
local Automation = NRSKNUI:GetModule('Automation')

local pcall = pcall
local hooksecurefunc = hooksecurefunc
local IsShiftKeyDown, IsAltKeyDown, IsControlKeyDown, IsMetaKeyDown = IsShiftKeyDown, IsAltKeyDown, IsControlKeyDown, IsMetaKeyDown
local CinematicFrame_CancelCinematic = CinematicFrame_CancelCinematic
local GameMovieFinished = GameMovieFinished
local ipairs = ipairs
local GetTime = GetTime
local strsplit = strsplit
local gsub = gsub
local select = select
local GetCursorInfo = GetCursorInfo

-- Loot APIs
local LootSlot = LootSlot
local IsModifiedClick = IsModifiedClick
local GetNumLootItems = GetNumLootItems
local GetMoney = GetMoney
local RepairAllItems = RepairAllItems
local CanGuildBankRepair = CanGuildBankRepair
local GetRepairAllCost = GetRepairAllCost
local CanMerchantRepair = CanMerchantRepair
local GetGuildBankWithdrawMoney = GetGuildBankWithdrawMoney
local SellAllJunkItems = C_MerchantFrame and C_MerchantFrame.SellAllJunkItems
local GetNumJunkItems = C_MerchantFrame and C_MerchantFrame.GetNumJunkItems

-- Quest APIs
local IsQuestCompletable = IsQuestCompletable
local GetNumQuestChoices = GetNumQuestChoices
local GetQuestReward = GetQuestReward
local AcceptQuest = AcceptQuest
local CompleteQuest = CompleteQuest
local GetQuestID = GetQuestID
local QuestIsDaily = QuestIsDaily
local QuestIsWeekly = QuestIsWeekly
local QuestGetAutoAccept = QuestGetAutoAccept
local CloseQuest = CloseQuest
local ConfirmAcceptQuest = ConfirmAcceptQuest
local StaticPopup_Hide = StaticPopup_Hide
local ShowQuestComplete = ShowQuestComplete
local GetQuestMoneyToGet = GetQuestMoneyToGet
local GetQuestItemInfo = GetQuestItemInfo

local IsQuestFlaggedCompleted = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
local GetLogIndexForQuestID = C_QuestLog and C_QuestLog.GetLogIndexForQuestID
local GetQuestLogInfo = C_QuestLog and C_QuestLog.GetInfo
local GetQuestIDForLogIndex = C_QuestLog and C_QuestLog.GetQuestIDForLogIndex
local SetSelectedQuest = C_QuestLog and C_QuestLog.SetSelectedQuest
local GetSelectedQuest = C_QuestLog and C_QuestLog.GetSelectedQuest

-- Gossip APIs for quest selection.
local GetActiveQuests = C_GossipInfo and C_GossipInfo.GetActiveQuests
local GetAvailableQuests = C_GossipInfo and C_GossipInfo.GetAvailableQuests
local GossipSelectAvailableQuest = C_GossipInfo and C_GossipInfo.SelectAvailableQuest
local GossipSelectActiveQuest = C_GossipInfo and C_GossipInfo.SelectActiveQuest

-- Index-based greeting APIs for quest selection.
local GetNumActiveQuests = GetNumActiveQuests
local GetNumAvailableQuests = GetNumAvailableQuests
local SelectActiveQuest = SelectActiveQuest
local GetActiveTitle = GetActiveTitle
local GetAvailableTitle = GetAvailableTitle
local SelectAvailableQuest = SelectAvailableQuest
local GetAvailableQuestInfo = GetAvailableQuestInfo

local GetItemInfo = C_Item and C_Item.GetItemInfo
local GetItemByID = C_TooltipInfo and C_TooltipInfo.GetItemByID

-- Enums
local FREQ_REGULAR = Enum.QuestFrequency.Default
local FREQ_DAILY = Enum.QuestFrequency.Daily
local FREQ_WEEKLY = Enum.QuestFrequency.Weekly
local FREQ_EVENT = Enum.QuestFrequency.ResetByScheduler

local _G = _G
local ITEM_ACCOUNTBOUND = ITEM_ACCOUNTBOUND
local ITEM_BNETACCOUNTBOUND = ITEM_BNETACCOUNTBOUND
local ITEM_BIND_TO_BNETACCOUNT = ITEM_BIND_TO_BNETACCOUNT
local ITEM_BIND_TO_ACCOUNT = ITEM_BIND_TO_ACCOUNT
local DELETE_GOOD_ITEM = DELETE_GOOD_ITEM

-- CVar APIs
local GetCVarBool = C_CVar and C_CVar.GetCVarBool
local SetCVar = C_CVar and C_CVar.SetCVar
local SetCVarBitfield = C_CVar and C_CVar.SetCVarBitfield
local RegisterCVar = C_CVar and C_CVar.RegisterCVar

--TODO: See if still needed in 12.1.0+
local BONUSROLL_GOLD_QUEST_ID = 95279
local BONUSROLL_MARL_QUEST_ID = 95290
local BONUSROLL_CREST_QUEST_ID = 95304

function Automation:UpdateDB()
    self.db = NRSKNUI.db.profile.Miscellaneous.Automation
end

function Automation:GetBonusrollMode()
    if not self.db.AutoBonusRollQuest then return nil end

    local mode = self.db.AutoBonusRollMode
    if mode == 'Gold' then
        return BONUSROLL_GOLD_QUEST_ID
    elseif mode == 'Marl' then
        return BONUSROLL_MARL_QUEST_ID
    elseif mode == 'Crest' then
        return BONUSROLL_CREST_QUEST_ID
    else
        return nil
    end
end

function Automation:ShouldSkipForBonusroll(quests)
    if not self.db.AutoBonusRollQuest then return false end
    local bonusrollID = self:GetBonusrollMode()

    -- If the bonus roll quest is already completed, we don't need to skip anything.
    if IsQuestFlaggedCompleted(bonusrollID) then return false end

    -- If there are no available quests, we cannot skip anything.
    if not quests then return false end

    -- Check if the bonus roll quest is among the available quests.
    for _, quest in ipairs(quests) do
        if quest.questID == bonusrollID then return true end
    end

    -- Bonus roll quest is not available.
    return false
end

-- Quest automation helpers --

--TODO: Add a custom user blocklist?
-- Quests that are risky to auto-accept (consume rare items) or teleport the player (waygates).
local blockedQuestIDs = {
    [43923] = true, -- Starlight Rose
    [43924] = true, -- Leyblood
    [43925] = true, -- Runescale Koi
    [71138] = true, -- Waygate: Rusza'thar Reach
    [71157] = true, -- Waygate: Skytop Observatory
    [71161] = true, -- Waygate: Vakthros
    [71162] = true, -- Waygate: Algeth'era
    [71165] = true, -- Waygate: Eon's Fringe
    [71178] = true, -- Waygate: Shady Sanctuary
}

local function IsQuestIDBlocked(questID)
    return questID ~= nil and blockedQuestIDs[questID] == true
end

-- True when the override key is currently suppressing automation.
function Automation:IsOverrideActive()
    local key = self.db.OverrideKey
    local down =
        (key == 'Shift' and IsShiftKeyDown()) or
        (key == 'Alt' and IsAltKeyDown()) or
        (key == 'Ctrl' and IsControlKeyDown()) or
        (key == 'Cmd' and IsMetaKeyDown()) or false

    -- Require, only automate while the key is held.
    -- Block, automate unless the key is held.
    if self.db.OverrideMode == 'Require' then
        return not down
    end
    return down
end

function Automation:IsAnyAcceptEnabled()
    return self.db.AutoAcceptRegular or self.db.AutoAcceptDaily or self.db.AutoAcceptWeekly or self.db.AutoAcceptEvent
end

-- Whether accepting a quest of the given frequency is allowed by the per-frequency toggles.
function Automation:IsFrequencyAllowed(frequency)
    if frequency == FREQ_DAILY then
        return self.db.AutoAcceptDaily
    elseif frequency == FREQ_WEEKLY then
        return self.db.AutoAcceptWeekly
    elseif frequency == FREQ_REGULAR then
        return self.db.AutoAcceptRegular
    elseif frequency == FREQ_EVENT then
        return self.db.AutoAcceptEvent
    end
    return false
end

-- True when handing in the current quest would cost the player gold.
function Automation:QuestRequiresGold()
    local goldRequired = GetQuestMoneyToGet()
    return goldRequired ~= nil and goldRequired > 0
end

-- True when a required turn-in item is account-bound, so it shouldn't be handed in blindly.
function Automation:IsItemAccountBound(itemID)
    if not GetItemByID then return false end
    local data = GetItemByID(itemID)
    if not data or not data.lines then return false end
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if text and (text == ITEM_ACCOUNTBOUND or text == ITEM_BNETACCOUNTBOUND
                or text == ITEM_BIND_TO_BNETACCOUNT or text == ITEM_BIND_TO_ACCOUNT) then
            return true
        end
    end
    return false
end

-- True when the current turn-in requires handing over currency, a crafting reagent, or an account-bound item.
function Automation:QuestRequiresCurrencyOrReagent()
    for i = 1, 6 do
        local progItem = _G['QuestProgressItem' .. i]
        if progItem and progItem:IsShown() and progItem.type == 'required' then
            if progItem.objectType == 'currency' then
                return true
            elseif progItem.objectType == 'item' then
                local name, _, _, _, _, itemID = GetQuestItemInfo('required', i)
                if name and itemID then
                    local isCraftingReagent = select(17, GetItemInfo(itemID))
                    if isCraftingReagent or self:IsItemAccountBound(itemID) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Event handlers --

function Automation:CINEMATIC_START()
    if NRSKNUI:IsFullyRestricted() then return end
    if not self.db.SkipCinematics then return end

    CinematicFrame_CancelCinematic()
end

function Automation:PLAY_MOVIE()
    if NRSKNUI:IsFullyRestricted() then return end
    if not self.db.SkipCinematics then return end

    pcall(GameMovieFinished)
end

function Automation:MERCHANT_SHOW()
    if NRSKNUI:IsFullyRestricted() then return end
    if not self.db.AutoRepair and not self.db.AutoSellJunk then return end

    -- The override key skips merchant automation.
    if self:IsOverrideActive() then return end

    -- Auto-sell junk items.
    if self.db.AutoSellJunk then
        if GetNumJunkItems() > 0 then
            SellAllJunkItems()
        end
    end

    -- Auto repair items, with either guild or player money.
    if self.db.AutoRepair and CanMerchantRepair() then
        local repairCost, canRepair = GetRepairAllCost()

        if repairCost and canRepair and repairCost > 0 then
            -- Use guild money.
            if self.db.UseGuildFunds and CanGuildBankRepair() then
                local guildBankMoney = GetGuildBankWithdrawMoney()

                if guildBankMoney >= repairCost then
                    RepairAllItems(true)
                    return
                end
            end

            -- Use player money.
            local playerMoney = GetMoney()
            if playerMoney >= repairCost then
                RepairAllItems(false)
            end
        end
    end
end

function Automation:LOOT_READY()
    if not self.db.AutoLoot and not self.db.FastLoot then return end

    local throttle = self._lootThrottle or 0
    if GetTime() - throttle < 0.15 then return end
    self._lootThrottle = GetTime()

    -- If auto-loot is enabled and the player is not holding the auto-loot override key, loot all items.
    if GetCVarBool('autoLootDefault') ~= IsModifiedClick('AUTOLOOTTOGGLE') then
        for i = GetNumLootItems(), 1, -1 do
            LootSlot(i)
        end
        self._lootThrottle = GetTime()
    end
end

function Automation:QUEST_COMPLETE()
    if NRSKNUI:IsFullyRestricted() then return end
    if self:IsOverrideActive() then return end
    if not self.db.AutoCompleteQuest then return end

    -- Don't hand in quests that would cost gold, currency, reagents, or account-bound items.
    if self:QuestRequiresGold() or self:QuestRequiresCurrencyOrReagent() then return end

    -- If there's only one choice, automatically select it.
    local numChoices = GetNumQuestChoices()
    if numChoices <= 1 then
        GetQuestReward(numChoices)
    end
end

-- Greeting is index-based.
function Automation:QUEST_GREETING()
    if NRSKNUI:IsFullyRestricted() then return end
    if self:IsOverrideActive() then return end
    if not self.db.AutoCompleteQuest and not self:IsAnyAcceptEnabled() then return end

    -- Auto turn in completed quests
    if self.db.AutoCompleteQuest then
        for i = 1, GetNumActiveQuests() do
            local title, isComplete = GetActiveTitle(i)
            if title and isComplete then
                return SelectActiveQuest(i)
            end
        end
    end

    -- Auto accept available quests, respecting the per-frequency toggles.
    if self:IsAnyAcceptEnabled() then
        for i = 1, GetNumAvailableQuests() do
            local title, isComplete = GetAvailableTitle(i)
            if title and not isComplete then
                local frequency = select(2, GetAvailableQuestInfo(i))

                if self:IsFrequencyAllowed(frequency) then
                    return SelectAvailableQuest(i)
                end
            end
        end
    end
end

function Automation:GOSSIP_SHOW()
    if NRSKNUI:IsFullyRestricted() then return end
    if self:IsOverrideActive() then return end
    local bonusrollID = self:GetBonusrollMode()
    if not self.db.AutoBonusRollQuest and not self.db.AutoCompleteQuest and not self:IsAnyAcceptEnabled() then return end

    -- Bonusroll quest takes priority, accept it if offered and not yet done.
    if self.db.AutoBonusRollQuest and bonusrollID and not IsQuestFlaggedCompleted(bonusrollID) then
        local quests = GetAvailableQuests()
        if quests then
            for _, quest in ipairs(quests) do
                if quest.questID == bonusrollID then
                    return GossipSelectAvailableQuest(bonusrollID)
                end
            end
        end
    end

    -- Auto turn in completed quests.
    if self.db.AutoCompleteQuest then
        local activeGossipQuests = GetActiveQuests()

        if activeGossipQuests then
            for _, quest in ipairs(activeGossipQuests) do
                if quest.title and quest.isComplete then
                    if quest.questID then
                        return GossipSelectActiveQuest(quest.questID)
                    end
                end
            end
        end
    end

    -- Auto accept available quests, respecting per-frequency toggles and the blocklist.
    if self:IsAnyAcceptEnabled() then
        local quests = GetAvailableQuests()

        if self:ShouldSkipForBonusroll(quests) then return end

        if quests then
            for _, quest in ipairs(quests) do
                if self:IsFrequencyAllowed(quest.frequency) then
                    if quest.questID and not IsQuestIDBlocked(quest.questID) then
                        return GossipSelectAvailableQuest(quest.questID)
                    end
                end
            end
        end
    end
end

function Automation:QUEST_DETAIL()
    if NRSKNUI:IsFullyRestricted() then return end
    if self:IsOverrideActive() then return end

    -- Auto accept, respecting the per-frequency toggles.
    if self:IsAnyAcceptEnabled() then
        local isDaily = QuestIsDaily()
        local isWeekly = QuestIsWeekly()
        local allowed =
            (isDaily and self.db.AutoAcceptDaily) or
            (isWeekly and self.db.AutoAcceptWeekly) or
            (not isDaily and not isWeekly and self.db.AutoAcceptRegular) or
            (not isDaily and not isWeekly and self.db.AutoAcceptEvent)

        if allowed then
            -- If Wow already auto-accepted the quest, just close the window instead of re-accepting.
            if QuestGetAutoAccept() then
                return CloseQuest()
            end
            return AcceptQuest()
        end
    end

    -- Bonusroll path when the frequency toggles didn't already accept it.
    local bonusrollID = self:GetBonusrollMode()
    if self.db.AutoBonusRollQuest and bonusrollID and not IsQuestFlaggedCompleted(bonusrollID) then
        if GetQuestID and GetQuestID() == bonusrollID then
            AcceptQuest()
        end
    end
end

-- Accept quests which require confirmation, such as shared escort quests.
function Automation:QUEST_ACCEPT_CONFIRM()
    if NRSKNUI:IsFullyRestricted() then return end
    if self:IsOverrideActive() then return end
    if not self:IsAnyAcceptEnabled() then return end

    ConfirmAcceptQuest()
    StaticPopup_Hide('QUEST_ACCEPT')
end

function Automation:QUEST_PROGRESS()
    if NRSKNUI:IsFullyRestricted() then return end
    if self:IsOverrideActive() then return end

    -- Bonusroll, complete the in-progress bonus roll quest.
    if self.db.AutoBonusRollQuest then
        local bonusrollID = self:GetBonusrollMode()
        if bonusrollID and not IsQuestFlaggedCompleted(bonusrollID)
            and GetQuestID and GetQuestID() == bonusrollID
            and IsQuestCompletable and IsQuestCompletable() then
            return CompleteQuest()
        end
    end

    -- General auto-complete: press Continue on completable quests unless they cost something.
    if self.db.AutoCompleteQuest and IsQuestCompletable and IsQuestCompletable() then
        if self:QuestRequiresGold() or self:QuestRequiresCurrencyOrReagent() then return end
        CompleteQuest()
    end
end

-- Show the completion dialog for objective-tracker quests so the normal turn-in path handles them.
function Automation:QUEST_AUTOCOMPLETE(event, questID)
    if NRSKNUI:IsFullyRestricted() then return end
    if self:IsOverrideActive() then return end
    if not self.db.AutoCompleteQuest then return end

    local index = GetLogIndexForQuestID(questID)
    if not index then return end

    local info = GetQuestLogInfo(index)
    if info and info.isAutoComplete then
        SetSelectedQuest(GetQuestIDForLogIndex(index))
        ShowQuestComplete(GetSelectedQuest())
    end
end

-- Hide leftover progress item buttons once quest interaction ends, so stale state isn't read.
function Automation:QUEST_FINISHED()
    for i = 1, 6 do
        local progItem = _G['QuestProgressItem' .. i]
        if progItem and progItem:IsShown() then
            progItem:Hide()
        end
    end
end

-- Hook-based features --

-- The GroupFinder frames are load-on-demand, so keep retrying the role check hooks as addons load until both are in place.
function Automation:ADDON_LOADED()
    self:SetupAutoRoleCheck()
end

function Automation:SetupAutoRoleCheck()
    if not self.db.AutoRoleCheck then return end

    local LFGListApplicationDialog = _G.LFGListApplicationDialog
    local LFDRoleCheckPopupAcceptButton = _G.LFDRoleCheckPopupAcceptButton
    local LFDRoleCheckPopup = _G.LFDRoleCheckPopup

    -- Auto select LFG role check if the player is not holding Shift.
    if LFGListApplicationDialog and not self._lfgHooked then
        self._lfgHooked = true

        LFGListApplicationDialog:HookScript('OnShow', function()
            if not Automation.db.AutoRoleCheck then return end
            if NRSKNUI:IsFullyRestricted() then return end

            if not Automation:IsOverrideActive() and LFGListApplicationDialog.SignUpButton then
                LFGListApplicationDialog.SignUpButton:Click()
            end
        end)
    end

    -- Auto select LFD role check if the player is not holding Shift.
    if LFDRoleCheckPopup and not self._lfdHooked then
        self._lfdHooked = true

        LFDRoleCheckPopup:HookScript('OnShow', function()
            if not Automation.db.AutoRoleCheck then return end
            if NRSKNUI:IsFullyRestricted() then return end

            if not Automation:IsOverrideActive() and LFDRoleCheckPopupAcceptButton then
                LFDRoleCheckPopupAcceptButton:Click()
            end
        end)
    end

    -- Both frames are hooked, stop watching addon loads.
    if self._lfgHooked and self._lfdHooked then
        self:UnregisterEvent('ADDON_LOADED')
    end
end

function Automation:SetupAutoFillDelete()
    if not self.db.AutoFillDelete or self._deleteHooked then return end
    self._deleteHooked = true

    -- Extract the part of the DELETE_GOOD_ITEM string that comes after the first line break.
    local DeleteLine = select(2, strsplit("@", gsub(DELETE_GOOD_ITEM, "[\r\n]", "@"), 2))

    hooksecurefunc(StaticPopupDialogs['DELETE_GOOD_ITEM'], 'OnShow', function()
        if not Automation.db.AutoFillDelete then return end

        local StaticPopup1EditBox = _G.StaticPopup1EditBox
        local StaticPopup1Button1 = _G.StaticPopup1Button1
        local StaticPopup1Text = _G.StaticPopup1Text

        if StaticPopup1EditBox:IsShown() then
            -- Hide the edit box and enable the confirmation button to allow automatic deletion without user input.
            StaticPopup1EditBox:Hide()
            StaticPopup1Button1:Enable()

            local ngt = gsub(StaticPopup1Text:GetText(), gsub(DeleteLine, "@", ""), "")
            local link = select(3, GetCursorInfo())
            StaticPopup1Text:SetText(ngt .. link)
        end
    end)
end

-- Toggle features --

function Automation:ApplyAutoLoot()
    local autoLootEnabled = self.db.AutoLoot and 1 or 0

    SetCVar('autoLootDefault', autoLootEnabled)
end

function Automation:ApplyAutoHideHelptips()
    if not self.db.AutoHideHelptips then return end

    RegisterCVar("hideHelptips", 1)

    -- Close all help tips for the current session and mark them as closed for future sessions.
    for index = 1, NUM_LE_FRAME_TUTORIALS do
        SetCVarBitfield('closedInfoFrames', index, true)
    end
    for index = 1, #Enum.FrameTutorialAccount do
        SetCVarBitfield('closedInfoFramesAccountWide', index, true)
    end
end

-- Toggle an event registration on or off.
function Automation:ToggleEvent(event, enabled)
    if enabled then
        self:RegisterEvent(event)
    else
        self:UnregisterEvent(event)
    end
end

-- Sync event registrations to the current db state.
function Automation:SetupEvents()
    if not self.db.Enabled then return end

    local anyAccept = self:IsAnyAcceptEnabled()

    self:ToggleEvent('CINEMATIC_START', self.db.SkipCinematics)
    self:ToggleEvent('PLAY_MOVIE', self.db.SkipCinematics)
    self:ToggleEvent('MERCHANT_SHOW', self.db.AutoSellJunk or self.db.AutoRepair)
    self:ToggleEvent('LOOT_READY', self.db.AutoLoot and self.db.FastLoot)
    self:ToggleEvent('GOSSIP_SHOW', self.db.AutoCompleteQuest or anyAccept or self.db.AutoBonusRollQuest)
    self:ToggleEvent('QUEST_GREETING', self.db.AutoCompleteQuest or anyAccept)
    self:ToggleEvent('QUEST_DETAIL', anyAccept or self.db.AutoBonusRollQuest)
    self:ToggleEvent('QUEST_ACCEPT_CONFIRM', anyAccept)
    self:ToggleEvent('QUEST_COMPLETE', self.db.AutoCompleteQuest)
    self:ToggleEvent('QUEST_AUTOCOMPLETE', self.db.AutoCompleteQuest)
    self:ToggleEvent('QUEST_FINISHED', self.db.AutoCompleteQuest)
    self:ToggleEvent('QUEST_PROGRESS', self.db.AutoCompleteQuest or self.db.AutoBonusRollQuest)
end

function Automation:ApplySettings()
    if not self.db.Enabled then return end

    self:SetupEvents()
    self:SetupAutoRoleCheck()
    self:SetupAutoFillDelete()
    self:ApplyAutoLoot()
    self:ApplyAutoHideHelptips()
end

function Automation:OnEnable()
    self:RegisterEvent('ADDON_LOADED')
    self:ApplySettings()
end
