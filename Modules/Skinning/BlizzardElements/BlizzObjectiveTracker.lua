---@class NRSKNUI
local NRSKNUI = select(2, ...)
local Theme = NRSKNUI.Theme

---@class BlizzObjectiveTracker: AceModule, AceEvent-3.0
local BOT = NRSKNUI:NewModule("BlizzObjectiveTracker", "AceEvent-3.0")

local hooksecurefunc = hooksecurefunc
local pairs = pairs
local CreateFrame = CreateFrame
local C_ChallengeMode = C_ChallengeMode
local CHALLENGE_MODE_EXTRA_AFFIX_INFO = CHALLENGE_MODE_EXTRA_AFFIX_INFO

local BSKIN = NRSKNUI.BlizzSkin

BOT.coloredHeaders = {}
BOT.coloredProgressBars = {}

local function GetAccentColor(objDb)
    local mode = objDb.ColorMode or "Theme"
    if mode == "Class" then
        return NRSKNUI:GetPlayerClassColor()
    elseif mode == "Custom" then
        return objDb.CustomColor or { 0, 1, 0.17, 1 }
    else
        return { Theme.accent[1], Theme.accent[2], Theme.accent[3], 1 }
    end
end

function BOT:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.BlizzardElements
end

function BOT:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function BOT:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end

    self:SkinObjectiveTracker()
end

local function ReskinQuestIcon(button, skipBorder)
    if not button then return end
    if not button.SetNormalTexture then return end
    if button.styled then return end

    button:SetNormalTexture(0)
    button:SetPushedTexture(0)

    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetColorTexture(1, 1, 1, 0.25) end

    local icon = button.icon or button.Icon
    if icon and not skipBorder then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button:AddBorders()
    end

    button.styled = true
end

local function ReskinQuestIcons(_, block)
    ReskinQuestIcon(block.ItemButton)
    ReskinQuestIcon(block.rightEdgeFrame, true)
end

local function ReskinHeader(header, color)
    if not header then return end

    local r, g, b = color[1], color[2], color[3]

    if header.styled then
        if header.Text then header.Text:SetTextColor(r, g, b) end
        if header.bg then header.bg:SetVertexColor(r, g, b, 1) end
        return
    end

    header.Text:SetTextColor(r, g, b)
    header.Background:SetTexture(nil)

    -- Creates a shadow background
    local shadow = header:CreateTexture(nil, "BORDER")
    shadow:SetAtlas("UI-Journeys-Paragon-Level-divider")
    shadow:SetDesaturated(true)
    shadow:SetVertexColor(0, 0, 0, 1)
    shadow:SetPoint("CENTER", -11, -12)
    shadow:SetSize(37, 320)
    shadow:SetRotation(math.pi / 2)
    header.shadow = shadow

    local bg = header:CreateTexture(nil, "ARTWORK")
    bg:SetAtlas("UI-Journeys-Paragon-Level-divider")
    bg:SetDesaturated(true)
    bg:SetVertexColor(r, g, b, 1)
    bg:SetPoint("CENTER", -11, -12)
    bg:SetSize(31, 320)
    bg:SetRotation(math.pi / 2)
    header.bg = bg

    BOT.coloredHeaders[header] = true
    header.styled = true
end

local function ReskinProgressBar(bar, color)
    if not bar then return end

    if bar.styled then
        bar:SetStatusBarColor(color[1], color[2], color[3])
        return
    end

    NRSKNUI:HideTextures(bar)
    BSKIN:CreateStatusBarBackdrop(bar)

    bar:SetStatusBarTexture(NRSKNUI.Media.Statusbars.NorskenUI)
    bar:SetStatusBarColor(color[1], color[2], color[3])

    BOT.coloredProgressBars[bar] = true
    bar.styled = true
end

local function ApplyLabelFont(label)
    local fontDB = BOT.db.ObjectiveTracker
    if not fontDB or not fontDB.FontStyling then return end

    local fontName = NRSKNUI:GetEffectiveFont(BOT.db)
    local fontPath = NRSKNUI:GetFontPath(fontName)
    local outline = NRSKNUI:GetFontOutline(BOT.db.FontOutline) or ""

    label:SetFont(fontPath, fontDB.QuestTextSize or 12, outline)

    local shadowDb = BOT.db.FontShadow
    if shadowDb and shadowDb.Enabled then
        local c = shadowDb.Color or { 0, 0, 0, 1 }
        label:SetShadowColor(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
        label:SetShadowOffset(shadowDb.OffsetX or 1, shadowDb.OffsetY or -1)
    else
        label:SetShadowColor(0, 0, 0, 0)
        label:SetShadowOffset(0, 0)
    end
end

local function ProgressBarHook(tracker, key)
    local progressBar = tracker.usedProgressBars and tracker.usedProgressBars[key]
    local bar = progressBar and progressBar.Bar
    if bar then
        local color = GetAccentColor(BOT.db.ObjectiveTracker)
        ReskinProgressBar(bar, color)

        local icon = bar.Icon
        if icon and icon:IsShown() and not icon.styled then
            icon:SetMask("")
            BSKIN:HandleIcon(icon, true)

            icon:SetSize(24, 24)
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", bar, "RIGHT", 4, 0)

            icon.styled = true
        end

        if icon and icon.backdrop then
            icon.backdrop:SetShown(icon:IsShown() and icon:GetTexture() ~= nil)
        end

        local label = bar.Label
        if label then
            label:ClearAllPoints()
            label:SetPoint("CENTER", bar, "CENTER", 0, 1)
            ApplyLabelFont(label)
        end
    end
end

local function TimerBarHook(tracker, key)
    local timerBar = tracker.usedTimerBars and tracker.usedTimerBars[key]
    local bar = timerBar and timerBar.Bar
    if bar then
        local color = GetAccentColor(BOT.db.ObjectiveTracker)
        ReskinProgressBar(bar, color)
    end
end

function BOT:SkinObjectiveTracker()
    if self.skinned then return end
    if not ObjectiveTrackerFrame then return end

    local objDb = self.db.ObjectiveTracker
    if not objDb or not objDb.Enabled then return end

    local color = GetAccentColor(objDb)

    local mainHeader = ObjectiveTrackerFrame.Header
    if mainHeader then
        if objDb.SkinHeaders then
            for i = 1, mainHeader:GetNumRegions() do
                local region = select(i, mainHeader:GetRegions())
                if region and region:IsObjectType("Texture") then
                    region:SetTexture(nil)
                end
            end
        end

        if objDb.SkinMinimizeButton then
            local mainMinimize = mainHeader.MinimizeButton
            if mainMinimize then
                BSKIN:ReskinCollapse(mainMinimize)
                if mainHeader.SetCollapsed then
                    hooksecurefunc(mainHeader, "SetCollapsed", function(_, collapsed)
                        if mainMinimize.DoCollapse then
                            mainMinimize:DoCollapse(collapsed)
                        end
                    end)
                end
            end
        end
    end

    local trackers = {
        ScenarioObjectiveTracker,
        UIWidgetObjectiveTracker,
        CampaignQuestObjectiveTracker,
        QuestObjectiveTracker,
        AdventureObjectiveTracker,
        AchievementObjectiveTracker,
        MonthlyActivitiesObjectiveTracker,
        ProfessionsRecipeTracker,
        BonusObjectiveTracker,
        WorldQuestObjectiveTracker,
        InitiativeTasksObjectiveTracker,
    }

    for _, tracker in pairs(trackers) do
        if tracker then
            if objDb.SkinHeaders and tracker.Header then
                ReskinHeader(tracker.Header, color)
            end
            if objDb.SkinQuestIcons then
                hooksecurefunc(tracker, "AddBlock", ReskinQuestIcons)
            end
            if objDb.SkinProgressBars then
                hooksecurefunc(tracker, "GetProgressBar", ProgressBarHook)
                hooksecurefunc(tracker, "GetTimerBar", TimerBarHook)
            end
        end
    end

    if objDb.SkinProgressBars then
        self:SkinScenarioTracker()
    end

    self.skinned = true
end

function BOT:SkinScenarioTracker()
    if not ScenarioObjectiveTracker then return end

    local stageBlock = ScenarioObjectiveTracker.StageBlock
    if stageBlock then
        hooksecurefunc(stageBlock, "UpdateStageBlock", function(block)
            if block.NormalBG then
                block.NormalBG:SetTexture("")
            end
            if not block.bg and block.GlowTexture then
                local bg = CreateFrame("Frame", nil, block, "BackdropTemplate")
                bg:SetPoint("TOPLEFT", block.GlowTexture, 0, -2)
                bg:SetPoint("BOTTOMRIGHT", block.GlowTexture, 4, 2)
                bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                bg:SetBackdropColor(0, 0, 0, 0.5)
                bg:SetFrameLevel(block:GetFrameLevel() - 1)
                bg:AddBorders()
                block.bg = bg
            end
        end)

        hooksecurefunc(stageBlock, "UpdateWidgetRegistration", function(stageBlockSelf)
            local widgetContainer = stageBlockSelf.WidgetContainer
            if widgetContainer and widgetContainer.widgetFrames then
                for _, widgetFrame in pairs(widgetContainer.widgetFrames) do
                    if widgetFrame.Frame then
                        widgetFrame.Frame:SetAlpha(0)
                    end

                    local bar = widgetFrame.TimerBar
                    if bar and not bar.bg then
                        local bg = CreateFrame("Frame", nil, bar, "BackdropTemplate")
                        bg:SetAllPoints(bar)
                        bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                        bg:SetBackdropColor(0, 0, 0, 0.25)
                        bg:SetFrameLevel(bar:GetFrameLevel() - 1)
                        bar.bg = bg
                    end

                    if widgetFrame.CurrencyContainer and widgetFrame.currencyPool then
                        for currencyFrame in widgetFrame.currencyPool:EnumerateActive() do
                            if currencyFrame.Icon and not currencyFrame.styled then
                                currencyFrame.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                                currencyFrame:AddBorders()
                                currencyFrame.styled = true
                            end
                        end
                    end
                end
            end
        end)
    end

    local challengeBlock = ScenarioObjectiveTracker.ChallengeModeBlock
    if challengeBlock then
        hooksecurefunc(challengeBlock, "SetUpAffixes", function(challengeBlockSelf)
            if not challengeBlockSelf.affixPool then return end
            for frame in challengeBlockSelf.affixPool:EnumerateActive() do
                if frame.Border then
                    frame.Border:SetTexture(nil)
                end
                if frame.Portrait and not frame.styled then
                    frame.Portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    frame:AddBorders()
                    frame.styled = true
                end

                if frame.Portrait then
                    if frame.info then
                        local info = CHALLENGE_MODE_EXTRA_AFFIX_INFO[frame.info.key]
                        if info then
                            frame.Portrait:SetTexture(info.texture)
                        end
                    elseif frame.affixID then
                        local _, _, filedataid = C_ChallengeMode.GetAffixInfo(frame.affixID)
                        frame.Portrait:SetTexture(filedataid)
                    end
                end
            end
        end)

        hooksecurefunc(challengeBlock, "Activate", function(block)
            if block.styled then return end

            if block.TimerBG then block.TimerBG:Hide() end
            if block.TimerBGBack then block.TimerBGBack:Hide() end

            if block.TimerBGBack then
                local timerbg = CreateFrame("Frame", nil, block, "BackdropTemplate")
                timerbg:SetPoint("TOPLEFT", block.TimerBGBack, 6, -2)
                timerbg:SetPoint("BOTTOMRIGHT", block.TimerBGBack, -6, -5)
                timerbg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
                timerbg:SetBackdropColor(0, 0, 0, 0.3)
                timerbg:SetFrameLevel(block:GetFrameLevel() - 1)
                block.timerbg = timerbg
            end

            if block.StatusBar then
                block.StatusBar:SetStatusBarTexture(NRSKNUI.Media.Statusbars.NorskenUI)
                block.StatusBar:SetStatusBarColor(Theme.accent[1], Theme.accent[2], Theme.accent[3])
                block.StatusBar:SetHeight(10)
            end

            local region3 = select(3, block:GetRegions())
            if region3 then region3:Hide() end

            local bg = CreateFrame("Frame", nil, block, "BackdropTemplate")
            bg:SetPoint("TOPLEFT", block, 4, -2)
            bg:SetPoint("BOTTOMRIGHT", block, -4, 0)
            bg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            bg:SetBackdropColor(0, 0, 0, 0.5)
            bg:SetFrameLevel(block:GetFrameLevel() - 1)
            bg:AddBorders()
            block.bg = bg

            block.styled = true
        end)
    end

    hooksecurefunc(ScenarioObjectiveTracker, "UpdateSpellCooldowns", function(scenarioSelf)
        if not scenarioSelf.spellFramePool then return end
        for spellFrame in scenarioSelf.spellFramePool:EnumerateActive() do
            local spellButton = spellFrame.SpellButton
            if spellButton and not spellButton.styled then
                if spellButton.Icon then
                    spellButton.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    spellButton:AddBorders()
                end
                spellButton:SetNormalTexture(0)
                spellButton:SetPushedTexture(0)

                local hl = spellButton:GetHighlightTexture()
                if hl then
                    hl:SetColorTexture(1, 1, 1, 0.25)
                end

                spellButton.styled = true
            end
        end
    end)
end

function BOT:StyleFonts()
    local fontDB = self.db.ObjectiveTracker
    if not fontDB or not fontDB.Enabled or not fontDB.FontStyling then return end

    local fontName = NRSKNUI:GetEffectiveFont(self.db)
    local fontPath = NRSKNUI:GetFontPath(fontName)
    local outline = NRSKNUI:GetFontOutline(self.db.FontOutline) or ""

    local function ApplyFont(fontObject, size)
        if not fontObject then return end
        fontObject:SetFont(fontPath, size, outline)

        local shadowDb = self.db.FontShadow
        if shadowDb and shadowDb.Enabled then
            local c = shadowDb.Color or { 0, 0, 0, 1 }
            fontObject:SetShadowColor(c[1] or 0, c[2] or 0, c[3] or 0, c[4] or 1)
            fontObject:SetShadowOffset(shadowDb.OffsetX or 1, shadowDb.OffsetY or -1)
        else
            fontObject:SetShadowColor(0, 0, 0, 0)
            fontObject:SetShadowOffset(0, 0)
        end
    end

    ApplyFont(_G.ObjectiveTrackerLineFont, fontDB.QuestTextSize)
    ApplyFont(_G.ObjectiveTrackerHeaderFont, fontDB.QuestTitleSize)

    for bar in pairs(self.coloredProgressBars) do
        if bar.Label then
            ApplyFont(bar.Label, fontDB.QuestTextSize)
        end
    end
end

function BOT:UpdateColors()
    local objDb = self.db.ObjectiveTracker
    if not objDb then return end

    local color = GetAccentColor(objDb)

    for header in pairs(self.coloredHeaders) do
        if header.Text then header.Text:SetTextColor(color[1], color[2], color[3]) end
        if header.bg then header.bg:SetVertexColor(color[1], color[2], color[3], 1) end
    end

    for bar in pairs(self.coloredProgressBars) do
        bar:SetStatusBarColor(color[1], color[2], color[3])
    end

    local challengeBlock = ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock
    if challengeBlock and challengeBlock.StatusBar then
        challengeBlock.StatusBar:SetStatusBarColor(color[1], color[2], color[3])
    end
end

function BOT:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end

    self:SkinObjectiveTracker()
    self:UpdateColors()
    self:StyleFonts()
end

function BOT:OnDisable()
    -- Skinning changes are permanent once applied
end
