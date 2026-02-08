-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("UICleanup: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local UIC = NRSKNUI.Addon:NewModule("UICleanup", "AceEvent-3.0")

-- Localization Setup
local ipairs = ipairs
local ObjectiveTrackerFrame = ObjectiveTrackerFrame
local QuestObjectiveTracker = QuestObjectiveTracker
local WorldQuestObjectiveTracker = WorldQuestObjectiveTracker
local ScenarioObjectiveTracker = ScenarioObjectiveTracker
local MonthlyActivitiesObjectiveTracker = MonthlyActivitiesObjectiveTracker
local BonusObjectiveTracker = BonusObjectiveTracker
local ProfessionsRecipeTracker = ProfessionsRecipeTracker
local AchievementObjectiveTracker = AchievementObjectiveTracker
local CampaignQuestObjectiveTracker = CampaignQuestObjectiveTracker

-- Module init
function UIC:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.UICleanup
    self:SetEnabledState(false)
end

-- Elements to hide
local hiddenElements = {
    { name = "Objective Tracker Background", frame = ObjectiveTrackerFrame and ObjectiveTrackerFrame.Header and ObjectiveTrackerFrame.Header.Background },
    { name = "Quest Tracker Background", frame = QuestObjectiveTracker and QuestObjectiveTracker.Header and QuestObjectiveTracker.Header.Background },
    { name = "World Quest Tracker Background", frame = WorldQuestObjectiveTracker and WorldQuestObjectiveTracker.Header and WorldQuestObjectiveTracker.Header.Background },
    { name = "Scenario Tracker Background", frame = ScenarioObjectiveTracker and ScenarioObjectiveTracker.Header and ScenarioObjectiveTracker.Header.Background },
    { name = "Monthly Activities Tracker Background", frame = MonthlyActivitiesObjectiveTracker and MonthlyActivitiesObjectiveTracker.Header and MonthlyActivitiesObjectiveTracker.Header.Background },
    { name = "Bonus Objective Tracker Background", frame = BonusObjectiveTracker and BonusObjectiveTracker.Header and BonusObjectiveTracker.Header.Background },
    { name = "Professions Tracker Background", frame = ProfessionsRecipeTracker and ProfessionsRecipeTracker.Header and ProfessionsRecipeTracker.Header.Background },
    { name = "Achievement Tracker Background", frame = AchievementObjectiveTracker and AchievementObjectiveTracker.Header and AchievementObjectiveTracker.Header.Background },
    { name = "Campaign Tracker Background", frame = CampaignQuestObjectiveTracker and CampaignQuestObjectiveTracker.Header and CampaignQuestObjectiveTracker.Header.Background },
}

-- Hide blizzard textures/Clutter
local function SetupHideBlizzardClutter()
    if not UIC.db.Enabled then return end
    -- Hide frames
    for _, entry in ipairs(hiddenElements) do
        if entry.frame then
            entry.frame:Hide()
        end
    end
end

-- Module OnEnable
function UIC:OnEnable()
    if not self.db.Enabled then return end
    C_Timer.After(1.0, function() -- Wait for frames to be ready
        SetupHideBlizzardClutter()
    end)
end
