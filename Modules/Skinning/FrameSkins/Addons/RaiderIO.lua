---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G
local min = min
local ipairs = ipairs
local Mixin = Mixin
local hooksecurefunc = hooksecurefunc

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

-- Skin and repositions the RaiderIO button that exports info about the group members --

local BUTTON_SIZE = 20
local X_GAP = 0
local Y_GAP = 0
local ICON_INSET = 2
local ICON_TEXCOORD = 0.05

local LOGO_TEXTURE = [[Interface\AddOns\RaiderIO\icons\logo]]

local skinned = false
local function SkinExportButton()
    if skinned then return end

    local button = _G.RaiderIO_ExportButton
    if not button then return end
    skinned = true

    Skinning:HandleButton(button)
    button:NUISetPixelSize(BUTTON_SIZE, BUTTON_SIZE)

    local logo = button:CreateTexture(nil, 'ARTWORK')
    logo:NUISetPixelPoint('TOPLEFT', button, 'TOPLEFT', ICON_INSET, -ICON_INSET)
    logo:NUISetPixelPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -ICON_INSET, ICON_INSET)
    logo:SetTexture(LOGO_TEXTURE)
    logo:SetTexCoord(ICON_TEXCOORD, 1 - ICON_TEXCOORD, ICON_TEXCOORD, 1 - ICON_TEXCOORD)
    logo:NUISetPixelSnap()

    local close = _G.PVEFrame and _G.PVEFrame.CloseButton
    if not close then return end

    button:ClearAllPoints()
    button:NUISetPixelPoint('RIGHT', close, 'LEFT', X_GAP, Y_GAP)
end

Skinning:RegisterSkin('RaiderIO', 'RaiderIO', function()
    local frame = _G.LFGListFrame
    if not frame then return end

    frame:HookScript('OnShow', SkinExportButton)
    SkinExportButton()
end)

-- Skin and reposition the guild records panel RaiderIO parents to the Mythic+ tab --

local PANEL_WIDTH = 150
local PANEL_POINT, PANEL_RELATIVE_POINT = 'BOTTOMLEFT', 'BOTTOMLEFT'
local PANEL_X, PANEL_Y = 4, 100
local PANEL_INSET = 4

local TITLE_SIZE = 16
local SUBTITLE_SIZE = 12
local SUBTITLE_GAP = 2

local ROW_FONT_SIZE = 10
local ROW_HEIGHT = 14
local ROW_GAP = 1
local ROW_TOP_GAP = 4
local ROW_LEVEL_WIDTH = 34
local ROW_LEVEL_GAP = 4
local ROW_MAX_VISIBLE = 10

local CHECK_SIZE = 14
local CHECK_TEXT_GAP = 4

local TIMED_R, TIMED_G, TIMED_B = 1, 1, 1
local DEPLETED_R, DEPLETED_G, DEPLETED_B = 0.5, 0.5, 0.5

---@param self RaiderIOGuildWeeklyFrame
local function ApplyGuildWeeklyHeight(self)
    local lastShown = 0
    for index, row in ipairs(self.GuildBests) do
        if row:IsShown() then
            lastShown = index

            -- Their SetUp repaints this per refresh to mark a run that missed the timer.
            local runInfo = row.runInfo
            if runInfo and runInfo.clear_time and runInfo.upgrades == 0 then
                row.Level:SetTextColor(DEPLETED_R, DEPLETED_G, DEPLETED_B)
            else
                row.Level:SetTextColor(TIMED_R, TIMED_G, TIMED_B)
            end
        end
    end

    local body = ROW_HEIGHT
    if lastShown > 0 then
        body = lastShown * ROW_HEIGHT + (lastShown - 1) * ROW_GAP
    end

    local bottom = PANEL_INSET
    if self.SwitchGuildBest:IsShown() then
        bottom = bottom + CHECK_SIZE + PANEL_INSET
    end

    local header = PANEL_INSET + self.Title:GetHeight() + SUBTITLE_GAP + self.SubTitle:GetHeight()
    self:NUISetPixelHeight(header + ROW_TOP_GAP + body + bottom)
end

local guildWeeklySkinned = false
local function SkinGuildWeekly()
    local RaiderIOFrame = _G.RaiderIO_GuildWeeklyFrame
    if not RaiderIOFrame or guildWeeklySkinned then return end
    guildWeeklySkinned = true

    -- Handle main RaiderIOFrame. Height is left to ApplyGuildWeeklyHeight, it tracks the run count.
    RaiderIOFrame:SetScale(1)
    RaiderIOFrame:NUIStripTextures('Keyed')
    --Skinning:CreatePanelBackdrop(RaiderIOFrame, 'Transparent')
    RaiderIOFrame:NUISetPixelWidth(PANEL_WIDTH)
    RaiderIOFrame:ClearAllPoints()
    local ChallengesFrame = _G.ChallengesFrame
    RaiderIOFrame:NUISetPixelPoint(PANEL_POINT, ChallengesFrame, PANEL_RELATIVE_POINT, PANEL_X, PANEL_Y)
    RaiderIOFrame:SetFrameStrata('TOOLTIP')

    -- Handle the title text. SetFontObject clears the string's own color, so size comes first.
    RaiderIOFrame.Title:SetFontStyle(Skinning.db, TITLE_SIZE)
    Skinning:HandleAccentText(RaiderIOFrame.Title)
    RaiderIOFrame.Title:ClearAllPoints()
    RaiderIOFrame.Title:NUISetPixelPoint('TOPLEFT', RaiderIOFrame, 'TOPLEFT', PANEL_INSET, -PANEL_INSET)

    -- Handle the subtitle text.
    RaiderIOFrame.SubTitle:SetFontStyle(Skinning.db, SUBTITLE_SIZE)
    RaiderIOFrame.SubTitle:SetTextColor(1, 1, 1)
    RaiderIOFrame.SubTitle:ClearAllPoints()
    RaiderIOFrame.SubTitle:NUISetPixelPoint('TOPLEFT', RaiderIOFrame.Title, 'BOTTOMLEFT', 0, -SUBTITLE_GAP)

    -- Handle the run rows.
    local rowWidth = PANEL_WIDTH - PANEL_INSET * 2
    RaiderIOFrame.maxVisible = min(ROW_MAX_VISIBLE, #RaiderIOFrame.GuildBests)

    for index, row in ipairs(RaiderIOFrame.GuildBests) do
        row:NUISetPixelSize(rowWidth, ROW_HEIGHT)
        row:ClearAllPoints()
        if index == 1 then
            row:NUISetPixelPoint('TOPLEFT', RaiderIOFrame.SubTitle, 'BOTTOMLEFT', 0, -ROW_TOP_GAP)
        else
            row:NUISetPixelPoint('TOPLEFT', RaiderIOFrame.GuildBests[index - 1], 'BOTTOMLEFT', 0, -ROW_GAP)
        end

        row.CharacterName:SetFontStyle(Skinning.db, ROW_FONT_SIZE)
        row.CharacterName:NUISetPixelSize(rowWidth - ROW_LEVEL_WIDTH - ROW_LEVEL_GAP, ROW_HEIGHT)
        row.Level:SetFontStyle(Skinning.db, ROW_FONT_SIZE)
        row.Level:NUISetPixelSize(ROW_LEVEL_WIDTH, ROW_HEIGHT)
    end

    -- Handle the empty state, anchored to the title by RaiderIO like the first row was.
    RaiderIOFrame.GuildBestNoRun:NUISetPixelSize(rowWidth, ROW_HEIGHT)
    RaiderIOFrame.GuildBestNoRun:ClearAllPoints()
    RaiderIOFrame.GuildBestNoRun:NUISetPixelPoint('TOPLEFT', RaiderIOFrame.SubTitle, 'BOTTOMLEFT', 0, -ROW_TOP_GAP)
    RaiderIOFrame.GuildBestNoRun.Text:SetFontStyle(Skinning.db, ROW_FONT_SIZE)
    RaiderIOFrame.GuildBestNoRun.Text:SetTextColor(1, 1, 1)
    RaiderIOFrame.GuildBestNoRun.Text:NUISetPixelSize(rowWidth, ROW_HEIGHT)

    -- Handle the "Display Weekly" checkbox, only shown with desktop client data for this guild.
    RaiderIOFrame.SwitchGuildBest:NUISetPixelSize(CHECK_SIZE, CHECK_SIZE)
    Skinning:HandleCheckBox(RaiderIOFrame.SwitchGuildBest)
    RaiderIOFrame.SwitchGuildBest:ClearAllPoints()
    RaiderIOFrame.SwitchGuildBest:NUISetPixelPoint('BOTTOMLEFT', RaiderIOFrame, 'BOTTOMLEFT', PANEL_INSET, PANEL_INSET)
    RaiderIOFrame.SwitchGuildBest.text:SetFontStyle(Skinning.db, SUBTITLE_SIZE)
    RaiderIOFrame.SwitchGuildBest.text:SetTextColor(1, 1, 1)
    RaiderIOFrame.SwitchGuildBest.text:ClearAllPoints()
    RaiderIOFrame.SwitchGuildBest.text:NUISetPixelPoint('LEFT', RaiderIOFrame.SwitchGuildBest, 'RIGHT', CHECK_TEXT_GAP, 0)

    hooksecurefunc(RaiderIOFrame, 'SetUp', ApplyGuildWeeklyHeight)
    ApplyGuildWeeklyHeight(RaiderIOFrame)
end

Skinning:RegisterSkin('Blizzard_ChallengesUI', 'RaiderIO', function()
    local ChallengesFrame = _G.ChallengesFrame
    if not ChallengesFrame or not IsAddOnLoaded('RaiderIO') then return end

    ChallengesFrame:HookScript('OnShow', SkinGuildWeekly)
    SkinGuildWeekly()
end)

-- Skin the talent builds shortcut button and the frame it opens --

local SHORTCUT_HEIGHT = 22
local SHORTCUT_TEXT_PAD = 20
local SHORTCUT_GAP = 6

local ROW_BG_ALPHA = 0.5
local ROW_ARROW_SIZE = 14

local function SkinTalentShortcut()
    local button = _G.RaiderIO_TalentBuildsTalentFrameShortcut
    if not button or button.NUISkinned then return end

    Skinning:HandleButton(button)

    -- RaiderIO shrinks the button to fit Blizzard's plate, which leaves our borders off the pixel grid.
    button:SetScale(1)
    button:NUISetPixelSize(button:GetTextWidth() + SHORTCUT_TEXT_PAD, SHORTCUT_HEIGHT)

    local dropdown = button:GetParent()
    button:ClearAllPoints()
    button:NUISetPixelPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', 0, SHORTCUT_GAP)
end

---@class BuildRowMixin
---@field NUIFocused boolean?
local BuildRowMixin = {}

function BuildRowMixin:NUIUpdateSkinColors()
    ---@cast self RaiderIOTalentBuildRow
    Skinning:UpdateHighlightColor(self)

    local backdrop = self.NUIBackdrop
    local general = Skinning.db.General
    local bg = general.BackgroundColor
    backdrop:SetBackgroundColor(bg[1], bg[2], bg[3], ROW_BG_ALPHA)

    if self.NUIFocused then
        local r, g, b = Skinning:GetAccentColor()
        backdrop:SetBorderColor(r, g, b, 1)
    else
        local border = general.BorderColor
        backdrop:SetBorderColor(border[1], border[2], border[3], border[4])
    end
end

-- RaiderIO drives the row's own two setters from its enter/leave/show/hide scripts and from the
-- action menu closing, so taking them over is enough to own every state the row has.
function BuildRowMixin:SetBackdropFocus()
    self.NUIFocused = true
    self:NUIUpdateSkinColors()
end

function BuildRowMixin:ClearBackdropFocus()
    self.NUIFocused = nil
    self:NUIUpdateSkinColors()
end

---@param button RaiderIOTalentBuildRow The pooled list button RaiderIO builds each build row on
local function SkinBuildRow(button)
    -- A row the list has only just acquired has none of the parts below yet, it comes back next update.
    if button.NUISkinned or not button.isInit then return end
    button.NUISkinned = true

    button:SetBackdropColor(0, 0, 0, 0)
    button:SetBackdropBorderColor(0, 0, 0, 0)

    Skinning:CreatePanelBackdrop(button, nil, true)
    Skinning:AddHighlight(button)

    local toggle = button.ActionMenuToggle
    if toggle then
        -- useIconAsHighlight keeps re-atlasing the icon, so it has to be held at alpha 0.
        if toggle.Icon then toggle.Icon:NUIStripTextures('ClearHide') end
        Skinning:CreateArrowTexture(toggle, 'right', ROW_ARROW_SIZE, ROW_ARROW_SIZE)
    end

    ---@cast button RaiderIOTalentBuildRow & BuildRowMixin
    Mixin(button, BuildRowMixin)
    button:ClearBackdropFocus()

    Skinning:RegisterSkinned(button)
end

---The copy feedback toast is built unnamed next to the frame, and its auto close timer is the only
---field that tells it apart from the frame's other children.
---@param frame Frame
---@return Frame?
local function FindFeedbackFrame(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.autoCloseAfterSeconds then
            return child
        end
    end
end

local buildsFrameSkinned = false

---@param frame RaiderIOTalentBuildsFrame? Passed by the OnShow hook, resolved by name otherwise
local function SkinBuildsFrame(frame)
    frame = frame or _G.RaiderIO_TalentBuildsFrame
    if not frame or buildsFrameSkinned then return end
    buildsFrameSkinned = true

    Skinning:HandlePortraitFrame(frame)
    Skinning:HandleAccentFont(frame.TitleContainer and frame.TitleContainer.TitleText)

    -- The resize grip is the one piece of Blizzard art the frame keeps, so it only loses its color.
    if frame.ResizeButton then
        for _, region in ipairs({ frame.ResizeButton:GetRegions() }) do
            if region:IsObjectType('Texture') then
                region:SetDesaturated(true)
            end
        end
    end

    Skinning:HandleDropdownButton(frame.InstanceMenu)
    Skinning:HandleDropdownButton(frame.DifficultyMenu)
    Skinning:HandleDropdownButton(frame.WeaponMenu)
    Skinning:HandleDropdownButton(frame.SpeedMenu)

    Skinning:HandleTrimScrollBar(frame.ScrollBar)
    Skinning:HookScrollBoxChildren(frame.ScrollBox, SkinBuildRow)

    local empty = frame.EmptyContainer
    if empty then
        if empty.Image then empty.Image.NUINoStrip = true end
        empty:NUIStripTextures('Alpha')
        Skinning:CreatePanelBackdrop(empty, 'Transparent')
        Skinning:HandleAccentFont(empty.Text)
    end

    local feedback = FindFeedbackFrame(frame)
    if feedback then
        feedback:NUIStripTextures('Keyed', nil, true)
        Skinning:CreatePanelBackdrop(feedback)
    end
end

---@param frame Frame
local function OnPortraitHidden(frame)
    if frame ~= _G.RaiderIO_TalentBuildsFrame then return end

    -- This lands at the top of RaiderIO's setup, the menus and the list only exist by the first show.
    frame:HookScript('OnShow', SkinBuildsFrame)
end

Skinning:RegisterSkin('RaiderIO', 'RaiderIO', function()
    if _G.ButtonFrameTemplate_HidePortrait then
        hooksecurefunc('ButtonFrameTemplate_HidePortrait', OnPortraitHidden)
    end

    SkinBuildsFrame()
end)

Skinning:RegisterSkin('Blizzard_PlayerSpells', 'RaiderIO', function()
    if not IsAddOnLoaded('RaiderIO') then return end

    local talentsFrame = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame
    local dropdown = talentsFrame and talentsFrame.LoadSystem and talentsFrame.LoadSystem.Dropdown
    if not dropdown then return end

    -- RaiderIO builds the shortcut from its own load callback, which can land after this one.
    dropdown:HookScript('OnShow', SkinTalentShortcut)
    SkinTalentShortcut()
end)
