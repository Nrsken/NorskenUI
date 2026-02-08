-- NorskenUI namespace
local _, NRSKNUI = ...

-- Check for addon object
if not NRSKNUI.Addon then
    error("MicroMenu: Addon object not initialized. Check file load order!")
    return
end

-- Create module
local MM = NRSKNUI.Addon:NewModule("MicroMenu", "AceEvent-3.0")

-- Localization
local UIFrameFadeOut = UIFrameFadeOut
local UIFrameFadeIn = UIFrameFadeIn
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local ipairs = ipairs
local unpack = unpack
local _G = _G

-- MicroMenu buttons
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

-- Track if hooks are applied
local hooksApplied = false

-- Custom microBar references
local microBar

-- Module init
function MM:OnInitialize()
    self.db = NRSKNUI.db.profile.Skinning.MicroMenu
    self:SetEnabledState(false)
end

-- Module OnEnable
function MM:OnEnable()
    if not self.db.Enabled then return end
    C_Timer.After(0.5, function() -- Delay to ensure Blizzard frames exist
        MM:CreateMicroBarFrame()
        MM:CreateMicroBar()
        MM:ReparentButtons()
        MM:SetupMouseover()
        MM:UpdateMicroBar()

        local config = {
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

                local parent = MM:GetParentFrame()
                self.microBar:ClearAllPoints()
                self.microBar:SetPoint(pos.AnchorFrom, parent, pos.AnchorTo, pos.XOffset, pos.YOffset)
            end,
            getParentFrame = function()
                return MM:GetParentFrame()
            end,
            guiPath = "MicroMenu",
        }
        NRSKNUI.EditMode:RegisterElement(config)
    end)
end

-- Get parent frame based on anchor type
function MM:GetParentFrame()
    if not self.db.Enabled then return end
    local anchorType = self.db.anchorFrameType
    if anchorType == "SCREEN" or anchorType == "UIPARENT" then
        return UIParent
    else
        local parentName = self.db.ParentFrame
        return _G[parentName] or UIParent
    end
end

-- Create the custom microBar frame
-- Uses Elvui style patterns where we create a custom frame and re anchor MicroMenu buttons
-- Simply skinning blizzard own frame messed up pixels perma :))
function MM:CreateMicroBarFrame()
    if microBar then return end
    microBar = CreateFrame("Frame", "NRSKNUI_MicroBar", UIParent)
    microBar:SetSize(250, 40)
    MM:UpdatePosition()
    self.microBar = microBar
end

-- Create the custom microBar frame
function MM:CreateMicroBar()
    if microBar.initialized then return end

    -- Create backdrop
    local backdrop = CreateFrame("Frame", nil, microBar, "BackdropTemplate")
    backdrop:SetFrameLevel(microBar:GetFrameLevel() - 1)
    backdrop:SetAllPoints(microBar)
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    backdrop:SetBackdropColor(unpack(self.db.BackdropColor))
    microBar.backdrop = backdrop

    -- Create border container
    local borderFrame = CreateFrame("Frame", nil, backdrop)
    borderFrame:SetAllPoints(backdrop)
    borderFrame:SetFrameStrata("DIALOG")
    borderFrame:SetFrameLevel(microBar:GetFrameLevel() + 1)

    -- Create top border
    local borderTop = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderTop:SetHeight(1)
    borderTop:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
    borderTop:SetColorTexture(unpack(self.db.BackdropBorderColor))
    borderTop:SetTexelSnappingBias(0)
    borderTop:SetSnapToPixelGrid(false)

    -- Create bottom border
    local borderBottom = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderBottom:SetHeight(1)
    borderBottom:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
    borderBottom:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    borderBottom:SetColorTexture(unpack(self.db.BackdropBorderColor))
    borderBottom:SetTexelSnappingBias(0)
    borderBottom:SetSnapToPixelGrid(false)

    -- Create left border
    local borderLeft = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderLeft:SetWidth(1)
    borderLeft:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
    borderLeft:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
    borderLeft:SetColorTexture(unpack(self.db.BackdropBorderColor))
    borderLeft:SetTexelSnappingBias(0)
    borderLeft:SetSnapToPixelGrid(false)

    -- Create right border
    local borderRight = borderFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    borderRight:SetWidth(1)
    borderRight:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
    borderRight:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
    borderRight:SetColorTexture(unpack(self.db.BackdropBorderColor))
    borderRight:SetTexelSnappingBias(0)
    borderRight:SetSnapToPixelGrid(false)

    microBar.borderTop = borderTop
    microBar.borderBottom = borderBottom
    microBar.borderLeft = borderLeft
    microBar.borderRight = borderRight
    microBar.borderFrame = borderFrame
    microBar.initialized = true
end

-- Reparent all micro buttons to custom frame
function MM:ReparentButtons()
    if InCombatLockdown() then
        MM:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    for _, name in ipairs(microButtons) do
        local button = _G[name]
        if button then
            button:SetParent(microBar)
        end
    end
end

-- Function to update microbar styling
function MM:UpdateMicroBar()
    if InCombatLockdown() then
        MM:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local visibleButtons = {}

    -- Get visible buttons
    for _, name in ipairs(microButtons) do
        local button = _G[name]
        if button and button:IsShown() then
            table.insert(visibleButtons, button)

            -- Strip Blizzard textures
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
    local buttonPerRow = 15

    -- Calculate dimensions
    local cols = math.min(numButtons, buttonPerRow)
    local rows = math.ceil(numButtons / buttonPerRow)
    local width = (self.db.ButtonWidth * cols) + (self.db.ButtonSpacing * math.max(0, cols - 1)) +
        (self.db.BackdropSpacing * 2)
    local height = (self.db.ButtonHeight * rows) + (self.db.ButtonSpacing * math.max(0, rows - 1)) +
        (self.db.BackdropSpacing * 2)

    -- Set size
    microBar:SetSize(width, height)

    -- Position buttons with correct dimensions
    for i, button in ipairs(visibleButtons) do
        button:ClearAllPoints()
        button:SetSize(self.db.ButtonWidth, self.db.ButtonHeight)
        local col = (i - 1) % buttonPerRow
        local row = math.floor((i - 1) / buttonPerRow)
        if i == 1 then
            button:SetPoint("TOPLEFT", microBar, "TOPLEFT", self.db.BackdropSpacing, -self.db.BackdropSpacing)
        elseif col == 0 then
            button:SetPoint("TOPLEFT", visibleButtons[i - buttonPerRow], "BOTTOMLEFT", 0, -self.db
                .ButtonSpacing)
        else
            button:SetPoint("LEFT", visibleButtons[i - 1], "RIGHT", self.db.ButtonSpacing, 0)
        end
    end

    -- Hide performance bar
    MainMenuMicroButton.MainMenuBarPerformanceBar:SetAlpha(0)
    MainMenuMicroButton.MainMenuBarPerformanceBar:SetScale(0.0001)

    -- Update Backdrop
    if microBar and microBar.backdrop then
        microBar.backdrop:SetShown(self.db.ShowBackdrop ~= false)
        microBar.backdrop:SetBackdropColor(unpack(self.db.BackdropColor))
    end
    -- Update Backdrop Border
    if microBar and microBar.borderTop then
        microBar.borderTop:SetColorTexture(unpack(self.db.BackdropBorderColor))
        microBar.borderBottom:SetColorTexture(unpack(self.db.BackdropBorderColor))
        microBar.borderLeft:SetColorTexture(unpack(self.db.BackdropBorderColor))
        microBar.borderRight:SetColorTexture(unpack(self.db.BackdropBorderColor))
    end

    MM:UpdateAlpha()
    MM:UpdatePosition()
end

-- Mouseover handler for pooling
-- Doing it this way instead of simply checking for OnEnter and OnLeave to not get
-- flickering when hovering between different buttons, checks the whole custom MicorMenu frame.
local watcher = 0
function OnUpdate(self, elapsed)
    if watcher > 0.1 then
        if not self:IsMouseOver() then
            self.IsMouseOvered = nil
            self:SetScript('OnUpdate', nil)
            if MM.db.Mouseover.Enabled then
                UIFrameFadeOut(microBar, MM.db.Mouseover.FadeOutDuration, microBar:GetAlpha(), MM.db.Mouseover.Alpha)
            end
        end
        watcher = 0
    else
        watcher = watcher + elapsed
    end
end

-- Mouseover onEnter function
local function OnEnter()
    if MM.db.Mouseover.Enabled and not microBar.IsMouseOvered then
        microBar.IsMouseOvered = true
        microBar:SetScript('OnUpdate', OnUpdate)
        UIFrameFadeIn(microBar, MM.db.Mouseover.FadeInDuration, microBar:GetAlpha(), 1.0)
    end
end

-- Setup mouseover hooks
function MM:SetupMouseover()
    if hooksApplied then return end
    if not self.db.Mouseover.Enabled then return end
    for _, name in ipairs(microButtons) do
        local button = _G[name]
        if button then
            button:HookScript("OnEnter", OnEnter)
        end
    end
    hooksApplied = true
end

-- Update position
function MM:UpdatePosition()
    if not microBar then return end
    microBar:ClearAllPoints()
    local pos = self.db.Position
    local parent = MM:GetParentFrame()
    microBar:SetPoint(
        pos.AnchorFrom or "CENTER",
        parent,
        pos.AnchorTo or "CENTER",
        pos.XOffset or 0,
        pos.YOffset or 0
    )
    microBar:SetFrameStrata(self.db.Strata or "HIGH")
end

-- Update alpha
function MM:UpdateAlpha()
    if not microBar then return end
    if not self.db.Mouseover.Enabled then
        microBar:SetAlpha(1.0)
    else
        microBar:SetAlpha(microBar.IsMouseOvered and 1.0 or self.db.Mouseover.Alpha)
    end
end

-- Apply function
function MM:Apply()
    if not self.db.Enabled then return end
    MM:UpdatePosition()
    MM:UpdateMicroBar()
end

-- Handle combat lockdown
function MM:PLAYER_REGEN_ENABLED()
    MM:UnregisterEvent("PLAYER_REGEN_ENABLED")
    MM:ReparentButtons()
    MM:UpdateMicroBar()
end

-- Module OnDisable
function MM:OnDisable()
    if microBar then
        microBar:Hide()
        microBar:SetAlpha(1.0)
        microBar.IsMouseOvered = nil
        microBar:SetScript('OnUpdate', nil)
    end
    -- Reparent buttons back to original parent
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
