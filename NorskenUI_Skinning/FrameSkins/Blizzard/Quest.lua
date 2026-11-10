---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local hooksecurefunc = hooksecurefunc
local ipairs = ipairs
local strmatch = string.match
local format = string.format
local _G = _G

local PANELS = { 'QuestFrameDetailPanel', 'QuestFrameProgressPanel', 'QuestFrameRewardPanel', 'QuestFrameGreetingPanel' }
local SCROLL_FRAMES = { 'QuestDetailScrollFrame', 'QuestProgressScrollFrame', 'QuestRewardScrollFrame', 'QuestGreetingScrollFrame' }
local BUTTONS = {
    'QuestFrameAcceptButton', 'QuestFrameDeclineButton',
    'QuestFrameCompleteButton', 'QuestFrameGoodbyeButton',
    'QuestFrameCompleteQuestButton', 'QuestFrameGreetingGoodbyeButton',
}
local REWARD_FRAMES = { 'HonorFrame', 'SkillPointFrame', 'ArtifactXPFrame', 'WarModeBonusFrame' }

-- faction seals colour their text for parchment, the light twins read on a dark panel
local SEAL_COLORS = {
    ['480404'] = 'c20606',
    ['042c54'] = '1c86ee',
}
local SEAL_FALLBACK = '99ccff'

local infoTitles, infoTexts
local recolored = false -- the shared quest text currently carries our colours

---@param fontString FontString
local function SetTitleColor(fontString)
    local r, g, b = Skinning:GetAccentColor()
    fontString:SetTextColor(r, g, b)
end

---@param fontString FontString
local function SetBodyColor(fontString)
    fontString:SetTextColor(1, 1, 1)
end

-- Rewards --

---@param button table? a reward or required-item button, Blizzard's own fields aren't in the stubs
local function SkinRewardButton(button)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    local icon = button.Icon
    if icon then
        Skinning:HandleIcon(icon, true)
        if button.IconBorder then
            Skinning:HandleIconBorder(button.IconBorder, icon.NUIBackdrop)
        end
    end
    -- the brown name plate is parchment art, the name reads fine without it
    if button.NameFrame then
        button.NameFrame:SetAlpha(0)
    end
end

---@param rewardsFrame table QuestInfoRewardsFrame, its pools aren't in the stubs
local function SkinRewards(rewardsFrame)
    for _, button in ipairs(rewardsFrame.RewardButtons) do
        SkinRewardButton(button)
        button.Name:SetTextColor(1, 1, 1)
    end
    for button in rewardsFrame.spellRewardPool:EnumerateActive() do
        SkinRewardButton(button)
    end
    for button in rewardsFrame.reputationRewardPool:EnumerateActive() do
        SkinRewardButton(button)
    end
    for header in rewardsFrame.spellHeaderPool:EnumerateActive() do
        header:SetVertexColor(1, 1, 1)
    end
end

-- Quest text --

local function RecolorSeal()
    local seal = _G.QuestInfoSealFrame
    if not (seal and seal:IsShown()) then return end

    local color, text = strmatch(seal.Text:GetText() or '', '|c[fF][fF](%x%x%x%x%x%x)(.-)|r')
    if not color then return end

    seal.Text:SetText(format('|cff%s%s|r', SEAL_COLORS[color:lower()] or SEAL_FALLBACK, text))
end

---@param r number
---@param g number
---@param b number
---@param tr number
---@param tg number
---@param tb number
local function PaintInfo(r, g, b, tr, tg, tb)
    for _, fontString in ipairs(infoTitles) do
        fontString:SetTextColor(r, g, b)
    end
    for _, fontString in ipairs(infoTexts) do
        fontString:SetTextColor(tr, tg, tb)
    end
end

-- QuestInfoFrame is shared with the world map and quest log popup, so only the dialog (questLog nil) gets our colours
local function OnQuestInfoDisplay()
    local infoFrame = _G.QuestInfoFrame
    if infoFrame.questLog then
        -- Blizzard only recolours when the material changes, so hand its colours back itself
        if not recolored then return end
        recolored = false

        local textColor, titleColor = GetMaterialTextColors(infoFrame.material)
        if QuestTextContrast.UseLightText() then
            textColor, titleColor = GetMaterialTextColors('Stone')
        end
        PaintInfo(titleColor[1], titleColor[2], titleColor[3], textColor[1], textColor[2], textColor[3])
        return
    end

    recolored = true
    local r, g, b = Skinning:GetAccentColor()
    PaintInfo(r, g, b, 1, 1, 1)
    SetBodyColor(_G.QuestInfoQuestType)
    RecolorSeal()
    SkinRewards(_G.QuestInfoRewardsFrame)
end

-- the greeting titles carry colour codes for parchment, a fixed colour ignores them as Blizzard's dark mode does
local function PaintGreetingTitles()
    local panel = _G.QuestFrameGreetingPanel --[[@as table]]
    for button in panel.titleButtonPool:EnumerateActive() do
        local text = button:GetFontString()
        text:SetFixedColor(true)
        text:SetTextColor(1, 1, 1)
    end
end

local function PaintProgressMoney()
    SetBodyColor(_G.QuestProgressRequiredMoneyText)
end

-- Skin --

---@param S SkinningModule
local function SkinModelScene(S)
    local scene = _G.QuestModelScene
    if not scene then return end

    scene:NCStripTextures('Keyed')
    S:CreatePanelBackdrop(scene)
    if scene.ModelTextFrame then
        scene.ModelTextFrame:NCStripTextures('Keyed')
        S:CreatePanelBackdrop(scene.ModelTextFrame)
    end
end

Skinning:RegisterSkin('Blizzard_UIPanels_Game', 'QuestFrame', function(S)
    local frame = _G.QuestFrame
    if not frame then return end

    S:HandlePortraitFrame(frame)
    S:HandleAccentFont(frame.TitleContainer and frame.TitleContainer.TitleText)

    -- every panel re-atlases its parchment on show, ClearHide keeps it at alpha 0 through that
    for _, name in ipairs(PANELS) do
        _G[name]:NCStripTextures('ClearHide')
    end
    for _, name in ipairs(SCROLL_FRAMES) do
        local scroll = _G[name]
        scroll:NCStripTextures('ClearHide')
        S:HandleTrimScrollBar(scroll.ScrollBar)
    end
    for _, name in ipairs(BUTTONS) do
        S:HandleButton(_G[name])
    end
    _G.QuestGreetingFrameHorizontalBreak:SetAlpha(0)

    for index = 1, 6 do
        SkinRewardButton(_G['QuestProgressItem' .. index])
    end
    local rewardsFrame = _G.QuestInfoRewardsFrame
    for _, key in ipairs(REWARD_FRAMES) do
        SkinRewardButton(rewardsFrame[key])
    end

    SkinModelScene(S)

    infoTitles = {
        _G.QuestInfoTitleHeader, _G.QuestInfoDescriptionHeader, _G.QuestInfoObjectivesHeader, rewardsFrame.Header,
    }
    infoTexts = {
        _G.QuestInfoDescriptionText, _G.QuestInfoObjectivesText, _G.QuestInfoGroupSize, _G.QuestInfoRewardText,
        _G.QuestInfoTimerText, _G.QuestInfoSpellObjectiveLearnLabel,
        rewardsFrame.ItemChooseText, rewardsFrame.ItemReceiveText, rewardsFrame.PlayerTitleText,
        rewardsFrame.QuestSessionBonusReward, rewardsFrame.XPFrame.ReceiveText,
    }

    -- only QuestFrame.lua calls these two, so they never reach text outside the dialog
    hooksecurefunc('QuestFrame_SetTitleTextColor', SetTitleColor)
    hooksecurefunc('QuestFrame_SetTextColor', SetBodyColor)
    hooksecurefunc('QuestFrameProgressItems_Update', PaintProgressMoney)
    hooksecurefunc('QuestInfo_Display', OnQuestInfoDisplay)

    -- OnShow is bound in XML, the global hook only sees the QUEST_LOG_UPDATE refresh
    _G.QuestFrameGreetingPanel:HookScript('OnShow', PaintGreetingTitles)
    hooksecurefunc('QuestFrameGreetingPanel_OnShow', PaintGreetingTitles)
end)
