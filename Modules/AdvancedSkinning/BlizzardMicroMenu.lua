---@class NRSKNUI
local NRSKNUI = select(2, ...)

---@class MicroMenu: AceModule, AceEvent-3.0
local MM = NRSKNUI:NewModule("MicroMenu", "AceEvent-3.0")

local UIFrameFadeOut = UIFrameFadeOut
local UIFrameFadeIn = UIFrameFadeIn
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local unpack = unpack
local _G = _G

local microButtons = {
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "GuildMicroButton",
    "LFDMicroButton",
    "CollectionsMicroButton",
    "EJMicroButton",
    "StoreMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "ProfessionMicroButton",
    "PlayerSpellsMicroButton",
    "HousingMicroButton"
}

local hooksApplied = false
local microBar

function MM:UpdateDB()
    self.db = NRSKNUI.db.profile.Skinning.MicroMenu
end

function MM:OnInitialize()
    self:UpdateDB()
    self:SetEnabledState(false)
end

function MM:OnEnable()
    if NRSKNUI:ShouldNotLoadModule() then return end
    if not self.db.Enabled then return end

    C_Timer.After(0.5, function()
        if InCombatLockdown() then
            NRSKNUI:DeferUntilUnrestricted(0, function() MM:InitializeMicroBar() end)
            return
        end
        MM:InitializeMicroBar()
    end)
end

function MM:InitializeMicroBar()
    if InCombatLockdown() then
        NRSKNUI:DeferUntilUnrestricted(0, function() MM:InitializeMicroBar() end)
        return
    end

    self:CreateMicroBar()
    self:ReparentButtons()
    self:SetupMouseover()
    self:UpdateMicroBar()

    NRSKNUI.EditMode:RegisterElement({
        key = "MicroBarModule",
        displayName = "Microbar",
        frame = self.microBar,
        getPosition = function()
            return self.db.Position
        end,
        setPosition = function(pos)
            self.db.Position.AnchorFrom = pos.AnchorFrom
            self.db.Position.AnchorTo = pos.AnchorTo
            self.db.Position.XOffset = pos.XOffset
            self.db.Position.YOffset = pos.YOffset

            self.microBar:ClearAllPoints()
            self.microBar:SetPoint(pos.AnchorFrom, MM:GetParentFrame(), pos.AnchorTo, pos.XOffset, pos.YOffset)
        end,
        getParentFrame = function()
            return MM:GetParentFrame()
        end,
        guiPath = "MicroMenu",
    })
end

function MM:GetParentFrame()
    if not self.db.Enabled then return UIParent end

    local anchorType = self.db.anchorFrameType
    if anchorType == "SCREEN" or anchorType == "UIPARENT" then
        return UIParent
    end
    return _G[self.db.ParentFrame] or UIParent
end

function MM:CreateMicroBar()
    if microBar then return end

    microBar = CreateFrame("Frame", "NRSKNUI_MicroBar", UIParent)
    microBar:SetSize(250, 40)
    self.microBar = microBar

    local backdrop = CreateFrame("Frame", nil, microBar, "BackdropTemplate")
    backdrop:SetFrameLevel(microBar:GetFrameLevel() - 1)
    backdrop:SetAllPoints(microBar)
    backdrop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    backdrop:SetBackdropColor(unpack(self.db.BackdropColor))
    microBar.backdrop = backdrop

    local borderFrame = CreateFrame("Frame", nil, backdrop)
    borderFrame:SetAllPoints(backdrop)
    borderFrame:SetFrameStrata("DIALOG")
    borderFrame:SetFrameLevel(microBar:GetFrameLevel() + 1)
    NRSKNUI:AddBorders(backdrop, self.db.BackdropBorderColor, borderFrame)
    microBar.borderFrame = borderFrame

    self:ApplySettings()
end

function MM:ReparentButtons()
    if InCombatLockdown() then
        NRSKNUI:DeferUntilUnrestricted(0, function() MM:ReparentButtons() end)
        return
    end

    for _, name in ipairs(microButtons) do
        local button = _G[name]
        if button then
            button:SetParent(microBar)
        end
    end
end

function MM:UpdateMicroBar()
    if not microBar then return end
    if InCombatLockdown() then
        NRSKNUI:DeferUntilUnrestricted(0, function() MM:UpdateMicroBar() end)
        return
    end

    local visibleButtons = {}
    local buttonPerRow = 15

    for _, name in ipairs(microButtons) do
        local button = _G[name]
        if button and button:IsShown() then
            table.insert(visibleButtons, button)

            if button.Background then
                button.Background:SetTexture(nil)
                button.Background:Hide()
            end
            if button.PushedBackground then
                button.PushedBackground:SetTexture(nil)
                button.PushedBackground:Hide()
            end
        end
    end

    local numButtons = #visibleButtons
    if numButtons == 0 then
        microBar:SetSize(100, 40)
        return
    end

    local cols = math.min(numButtons, buttonPerRow)
    local rows = math.ceil(numButtons / buttonPerRow)
    local width = (self.db.ButtonWidth * cols) + (self.db.ButtonSpacing * math.max(0, cols - 1)) + (self.db.BackdropSpacing * 2)
    local height = (self.db.ButtonHeight * rows) + (self.db.ButtonSpacing * math.max(0, rows - 1)) + (self.db.BackdropSpacing * 2)
    microBar:SetSize(width, height)

    for i, button in ipairs(visibleButtons) do
        button:ClearAllPoints()
        button:SetSize(self.db.ButtonWidth, self.db.ButtonHeight)

        local col = (i - 1) % buttonPerRow
        if i == 1 then
            button:SetPoint("TOPLEFT", microBar, "TOPLEFT", self.db.BackdropSpacing, -self.db.BackdropSpacing)
        elseif col == 0 then
            button:SetPoint("TOPLEFT", visibleButtons[i - buttonPerRow], "BOTTOMLEFT", 0, -self.db.ButtonSpacing)
        else
            button:SetPoint("LEFT", visibleButtons[i - 1], "RIGHT", self.db.ButtonSpacing, 0)
        end
    end

    MainMenuMicroButton.MainMenuBarPerformanceBar:SetAlpha(0)
    MainMenuMicroButton.MainMenuBarPerformanceBar:SetScale(0.0001)
end

local mouseoverElapsed = 0
local function OnUpdate(self, elapsed)
    mouseoverElapsed = mouseoverElapsed + elapsed
    if mouseoverElapsed < 0.1 then return end

    mouseoverElapsed = 0
    if self:IsMouseOver() then return end

    self.IsMouseOvered = nil
    self:SetScript("OnUpdate", nil)
    if MM.db.Mouseover.Enabled then
        UIFrameFadeOut(microBar, MM.db.Mouseover.FadeOutDuration, microBar:GetAlpha(), MM.db.Mouseover.Alpha)
    end
end

local function OnEnter()
    if not MM.db.Mouseover.Enabled or microBar.IsMouseOvered then return end

    microBar.IsMouseOvered = true
    microBar:SetScript("OnUpdate", OnUpdate)
    UIFrameFadeIn(microBar, MM.db.Mouseover.FadeInDuration, microBar:GetAlpha(), 1.0)
end

function MM:SetupMouseover()
    if hooksApplied or not self.db.Mouseover.Enabled then return end

    for _, name in ipairs(microButtons) do
        local button = _G[name]
        if button then
            button:HookScript("OnEnter", OnEnter)
        end
    end
    hooksApplied = true
end

function MM:ApplySettings()
    if NRSKNUI:ShouldNotLoadModule() or not self.db.Enabled or not microBar then return end

    if self.db.Mouseover.Enabled then
        microBar:SetAlpha(microBar.IsMouseOvered and 1.0 or self.db.Mouseover.Alpha)
    else
        microBar:SetAlpha(1.0)
    end

    local pos = self.db.Position
    microBar:ClearAllPoints()
    microBar:SetPoint(pos.AnchorFrom, self:GetParentFrame(), pos.AnchorTo, pos.XOffset, pos.YOffset)
    microBar:SetFrameStrata(self.db.Strata)

    if microBar.backdrop then
        microBar.backdrop:SetShown(self.db.ShowBackdrop)
        microBar.backdrop:SetBackdropColor(unpack(self.db.BackdropColor))
        local borderColor = self.db.BackdropBorderColor
        microBar.backdrop:SetBorderColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4])
    end

    self:SetupMouseover()
    self:UpdateMicroBar()
end

function MM:OnDisable()
    if microBar then
        microBar:Hide()
        microBar:SetAlpha(1.0)
        microBar.IsMouseOvered = nil
        microBar:SetScript("OnUpdate", nil)
    end

    if not InCombatLockdown() then
        for _, name in ipairs(microButtons) do
            local button = _G[name]
            if button then
                button:SetParent(UIParent)
            end
        end
    end
    hooksApplied = false
end
