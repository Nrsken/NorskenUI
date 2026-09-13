---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local ipairs = ipairs
local select = select
local unpack = unpack
local hooksecurefunc = hooksecurefunc
local _G = _G

local ROW_FILTERED_COLOR = { 0.70, 0.10, 0.10, 0.25 }
local ROW_APPLIED_COLOR = { 0.10, 0.70, 0.25, 0.22 }
local ROW_BG_COLOR = { 1, 1, 1, 0.03 }
local ROW_RIGHT_NUDGE = 3
local CATEGORY_SELECTED_ALPHA = 0.15
local CATEGORY_ART_INSET = 2
local COVER_DIM_ALPHA = 0.5

local ROLE_CHECK_SIZE = 18
local LIST_CHECK_INSET = 3
local REFRESH_BUTTON_SIZE = 24
local INSET_LEFT_NUDGE = 2
local SEARCH_ROW_HEIGHT = 22
local SEARCH_ROW_GAP = 1
local SEARCH_ROW_EDGE_GAP = 0
local CATEGORY_NAME_GAP = 4
local GROUP_BUTTON_ICON_SIZE = 40
local GROUP_BUTTON_ICON_GAP = 10
local GROUP_BUTTON_TEXT_GAP = 10

local RESET_ATLAS = 'GM-raidMarker-reset'

---@param button NUIIconButton?
---@param size number? Square size to force once the button art is gone
local function SkinIconButton(S, button, size)
    if not button or button.NUISkinned then return end

    S:HandleButton(button, nil, nil, true)

    if size then
        button:NUISetPixelSize(size, size)
    end
end

-- The role atlas and its plate stay Blizzard's, only the tick box and incentive border are ours.
---@param button NUIRoleButton?
local function SkinRoleButton(S, button)
    if not button then return end

    if button.shortageBorder then button.shortageBorder:NUIStripTextures() end

    local incentive = button.incentiveIcon
    if incentive and not incentive.NUISkinned then
        incentive.NUISkinned = true

        if incentive.border then incentive.border:NUIStripTextures() end
        if incentive.CircleMask then incentive.CircleMask:Hide() end
        S:HandleIcon(incentive.texture, true)
    end

    -- Some templates run the box at scale 0.7, which would land our border on a half pixel.
    local check = button.CheckButton or button.checkButton
    if not check or check.NUISkinned then return end

    check:SetScale(1)
    check:NUISetPixelSize(ROLE_CHECK_SIZE, ROLE_CHECK_SIZE)
    check:ClearAllPoints()
    check:NUISetPixelPoint('BOTTOMLEFT', button, 'BOTTOMLEFT', 0, 0)
    check:SetFrameLevel(button:GetFrameLevel() + 2)
    S:HandleCheckBox(check)
end

---@param check CheckButton?
local function ReapplyCheckBox(check)
    if check and check.NUIApplyCheckTextures then
        check:NUIApplyCheckTextures()
    end
end

-- Varargs rather than a table: a nil hole would cut an ipairs walk short.
local function SkinRoleButtons(S, ...)
    for i = 1, select('#', ...) do
        SkinRoleButton(S, (select(i, ...)))
    end
end

-- Only the icon gets a border, the template's name plate would put the quality ring over it.
---@param button NUIIconButton?
local function SkinRewardItem(S, button)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    if button.NameFrame then button.NameFrame:NUIStripTextures() end
    if button.shortageBorder then button.shortageBorder:NUIStripTextures() end
    if button.IconBorder then button.IconBorder:SetAlpha(0) end

    S:HandleIcon(button.Icon, true)
end

-- Reward rows are built on demand, so the item buttons are skinned from Blizzard's setter.
local function UpdateRewardItem(parentFrame, _, index)
    local name = parentFrame:GetName()
    if not name then return end

    SkinRewardItem(Skinning, _G[name .. 'Item' .. index])
end

-- The money button sits outside the item loop, so a gold-only dungeon never reaches the setter.
---@param scrollFrame NUIScrollFrame?
local function SkinRewardsPanel(S, scrollFrame)
    local rewards = scrollFrame and scrollFrame:GetScrollChild() --[[@as NUIRewardsFrame?]]
    if not rewards then return end

    SkinRewardItem(S, rewards.MoneyReward)

    S:HandleAccentFont(rewards.title)
    S:HandleAccentFont(rewards.rewardsLabel)
end

-- Search panel --

local function SkinAutoCompleteButton(button)
    if not button or button.NUISkinned then return end
    button.NUISkinned = true

    if button.SetNormalTexture then
        button:SetNormalTexture(NRSKNUI.ClearTexture)
        button:SetPushedTexture(NRSKNUI.ClearTexture)
    end

    local highlight = button:GetHighlightTexture()
    if highlight then highlight:SetColorTexture(unpack(NRSKNUI.Colors.highlightColor)) end
    if button.Selected then button.Selected:SetColorTexture(unpack(NRSKNUI.Colors.selectedColor)) end
end

local function SkinAutoComplete(S, frame)
    if not frame then return end

    frame:NUIStripTextures('ClearHide')
    S:CreatePanelBackdrop(frame)

    for _, button in ipairs(frame.Results or {}) do
        SkinAutoCompleteButton(button)
    end
end

---@param region Frame|Texture
---@param point string
---@return ScriptRegion? relativeTo, string? relativePoint, number? x, number? y
local function GetAnchor(region, point)
    for i = 1, region:GetNumPoints() do
        local anchor, relativeTo, relativePoint, x, y = region:GetPoint(i)
        if anchor == point then
            return relativeTo, relativePoint, x, y
        end
    end
end

-- Every row fill is inset three a side, but the row already ends where the list does on the right.
---@param texture Texture?
local function NudgeRowRight(texture)
    if not texture then return end

    local relativeTo, relativePoint, x, y = GetAnchor(texture, 'BOTTOMRIGHT')
    if not relativePoint then return end

    texture:NUISetPixelPoint('BOTTOMRIGHT', relativeTo or texture:GetParent(), relativePoint, x + ROW_RIGHT_NUDGE, y)
end

-- Blizzard leaves both insets two pixels right of the button sitting under them.
---@param inset Frame
local function NudgeInsetLeft(inset)
    local relativeTo, relativePoint, x, y = GetAnchor(inset, 'TOPLEFT')
    if not relativePoint then return end

    inset:NUISetPixelPoint('TOPLEFT', relativeTo or inset:GetParent(), relativePoint, x - INSET_LEFT_NUDGE, y)
end

-- The category atlas sizes InfoBackground, so its right edge stops wherever the art happens to end.
-- Both hang off the same panel corner, so the difference in their offsets is the gap to keep.
---@param info Texture
---@param inset Frame
local function MatchInfoToInset(info, inset)
    local _, _, _, infoY = GetAnchor(info, 'TOPLEFT')
    local _, _, _, insetY = GetAnchor(inset, 'TOPLEFT')
    if not infoY or not insetY then return end

    local gap = infoY - insetY

    info:ClearAllPoints()
    info:NUISetPixelPoint('TOPLEFT', inset, 'TOPLEFT', 0, gap)
    info:NUISetPixelPoint('TOPRIGHT', inset, 'TOPRIGHT', 0, gap)
end

---@param row NUISearchEntry
local function SkinSearchEntry(S, row)
    row.NUISkinned = true

    if row.ResultBG then
        row.ResultBG:SetColorTexture(unpack(ROW_BG_COLOR))
        NudgeRowRight(row.ResultBG)
    end

    if row.Highlight then
        row.Highlight:SetColorTexture(unpack(NRSKNUI.Colors.highlightColor))
        NudgeRowRight(row.Highlight)
    end

    NudgeRowRight(row.BackgroundTexture)

    S:HandleAccentFont(row.Name)

    SkinIconButton(S, row.CancelButton) -- Cancel application button
end

-- Blizzard re-drives the state atlas on every pass, so the flat fill has to be re-applied there.
---@param row NUISearchEntry
local function UpdateSearchEntry(row)
    if not row.NUISkinned then SkinSearchEntry(Skinning, row) end

    local background = row.BackgroundTexture
    if not background or not background:IsShown() then return end

    if row.isNowFilteredOut then
        background:SetColorTexture(unpack(ROW_FILTERED_COLOR))
    elseif row.isApplication then
        background:SetColorTexture(unpack(ROW_APPLIED_COLOR))
    else
        local r, g, b = Skinning:GetAccentColor()
        background:SetColorTexture(r, g, b, 0.22)
    end
end

-- Blizzard appends its own "Start a Group" row to the result list from an unnamed template with no
-- initializer, so it is skinned as the list hands it out; the button is the row's only child.
---@param row Frame
---@param elementData table?
local function UpdateStartGroupRow(row, elementData)
    if not elementData or not elementData.startGroup then return end

    local button = row:GetChildren()
    ---@cast button Button
    Skinning:HandleButton(button)
end

local function SkinSearchPanel(S, panel)
    if not panel then return end

    S:HandleAccentText(panel.CategoryName)
    S:HandleEditBox(panel.SearchBox)

    -- WowStyle1FilterDropdownTemplate has no Arrow, so it dresses as a plain button.
    if panel.FilterButton then
        S:HandleButton(panel.FilterButton)
        S:HandleCloseButton(panel.FilterButton.ResetButton, panel.FilterButton, 8, 8, 14)
    end

    S:HandleButton(panel.BackButton)
    S:HandleButton(panel.BackToGroupButton)
    S:HandleButton(panel.SignUpButton)

    -- Search again button, sized off the box's visible art rather than its frame, which is taller.
    local box = panel.SearchBox
    local visibleHeight = SEARCH_ROW_HEIGHT + (box and box.NUIArtTop or 0) - (box and box.NUIArtBottom or 0)

    SkinIconButton(S, panel.RefreshButton, visibleHeight)
    panel.RefreshButton.Icon:SetAtlas(RESET_ATLAS)
    panel.RefreshButton.Icon:SetDesaturated(true)

    local inset = panel.ResultsInset
    if inset then
        inset:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(inset, 'Transparent')

        NudgeInsetLeft(inset)

        local rowTop = SEARCH_ROW_GAP + SEARCH_ROW_HEIGHT

        if panel.SearchBox then
            local overhang = panel.SearchBox.NUIArtLeft or 0

            panel.SearchBox:NUISetPixelHeight(SEARCH_ROW_HEIGHT)
            panel.SearchBox:NUISetPixelPoint('TOPLEFT', inset, 'TOPLEFT', SEARCH_ROW_EDGE_GAP - overhang, rowTop)

            if panel.CategoryName then
                panel.CategoryName:ClearAllPoints()
                panel.CategoryName:NUISetPixelPoint('BOTTOMLEFT', panel.SearchBox, 'TOPLEFT', overhang + 2, CATEGORY_NAME_GAP)
            end
        end

        if panel.FilterButton then
            panel.FilterButton:NUISetPixelHeight(REFRESH_BUTTON_SIZE)
            panel.FilterButton:NUISetPixelPoint('TOPRIGHT', inset, 'TOPRIGHT', 0, rowTop + 1)
        end
    end

    S:HandleTrimScrollBar(panel.ScrollBar)
    SkinAutoComplete(S, panel.AutoCompleteFrame)

    if panel.ScrollBox then
        S:HandleButton(panel.ScrollBox.StartGroupButton)
        S:HookScrollBoxChildren(panel.ScrollBox, UpdateStartGroupRow)
    end
end

-- Category selection --

-- Art and state fills all land smaller than the button, so stretch each to the same rect.
---@param texture Texture?
---@param button Button
local function FillCategoryRow(texture, button)
    if not texture then return end

    texture:ClearAllPoints()
    texture:NUISetPixelPoint('TOPLEFT', button, 'TOPLEFT', CATEGORY_ART_INSET, -CATEGORY_ART_INSET)
    texture:NUISetPixelPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', -CATEGORY_ART_INSET, CATEGORY_ART_INSET)
end

-- Blizzard drives SelectedTexture's visibility, so recoloring it is all the selected state needs.
local function UpdateCategoryButton(selection, btnIndex)
    local button = selection.CategoryButtons and selection.CategoryButtons[btnIndex]
    if not button then return end

    local S = Skinning

    if not button.NUISkinned then
        button.NUISkinned = true
        S:CreatePanelBackdrop(button)

        if button.Cover then button.Cover:SetAlpha(0) end
        if button.Icon then
            button.Icon:SetDrawLayer('BACKGROUND', 2)
            FillCategoryRow(button.Icon, button)
        end

        if button.HighlightTexture then
            button.HighlightTexture:SetColorTexture(unpack(NRSKNUI.Colors.highlightColor))
            FillCategoryRow(button.HighlightTexture, button)
        end
        FillCategoryRow(button.SelectedTexture, button)
    end

    -- AddButton re-sets the atlas on every pass, which takes the crop with it.
    if button.Icon then button.Icon:NUISetZoom() end

    local label = button.Label
    if label then
        local base = button:GetNormalFontObject() or label:GetFontObject() or GameFontNormal
        button.NUIOutlineFont = button.NUIOutlineFont or S:GetOutlineFont(base)

        button:SetNormalFontObject(button.NUIOutlineFont)
        label:SetFontObject(button.NUIOutlineFont)
    end

    -- Re-tinted on every pass so an accent change is picked up the next time the list is built.
    if button.SelectedTexture then
        local r, g, b = S:GetAccentColor()
        button.SelectedTexture:SetColorTexture(r, g, b, CATEGORY_SELECTED_ALPHA)
    end
end

local function SkinCategorySelection(S, selection)
    if not selection then return end

    S:HandleAccentText(selection.Label)

    if selection.Inset then
        selection.Inset:NUIStripTextures('Keyed')
    end

    S:HandleButton(selection.FindGroupButton)
    S:HandleButton(selection.StartGroupButton)
end

-- Entry creation --

---@param requirement NUIRequirementRow?
local function SkinRequirement(S, requirement)
    if not requirement then return end

    S:HandleCheckBox(requirement.CheckButton)
    S:HandleEditBox(requirement.EditBox)
end

-- A ScrollFrame rather than an EditBox, so HandleEditBox cannot own it.
---@param scrollFrame NUIScrollFrame?
local function SkinInputScroll(S, scrollFrame)
    if not scrollFrame or scrollFrame.NUISkinned then return end
    scrollFrame.NUISkinned = true

    scrollFrame:NUIStripTextures('Layer', 'BACKGROUND')

    -- Matches HandleEditBox, these are inputs rather than panels.
    local backdrop = S:CreatePanelBackdrop(scrollFrame, nil, nil, true)
    if backdrop then
        backdrop:ClearAllPoints()
        backdrop:NUISetPixelPoint('TOPLEFT', scrollFrame, 'TOPLEFT', -5, 5)
        backdrop:NUISetPixelPoint('BOTTOMRIGHT', scrollFrame, 'BOTTOMRIGHT', 5, -5)
    end

    S:HandleTrimScrollBar(scrollFrame.ScrollBar)
end

local function SkinEntryCreation(S, creation)
    if not creation then return end

    S:HandleAccentText(creation.Label)
    S:HandleAccentFont(creation.NameLabel)
    S:HandleAccentFont(creation.DescriptionLabel)

    if creation.Inset then
        creation.Inset:NUIStripTextures('Keyed')
    end

    S:HandleEditBox(creation.Name)
    SkinInputScroll(S, creation.Description)

    S:HandleDropdownButton(creation.GroupDropdown)
    S:HandleDropdownButton(creation.ActivityDropdown)
    S:HandleDropdownButton(creation.PlayStyleDropdown)

    SkinRequirement(S, creation.ItemLevel)
    SkinRequirement(S, creation.PvpItemLevel)
    SkinRequirement(S, creation.PVPRating)
    SkinRequirement(S, creation.MythicPlusRating)
    SkinRequirement(S, creation.VoiceChat)

    if creation.CrossFactionGroup then
        S:HandleCheckBox(creation.CrossFactionGroup.CheckButton)
    end
    if creation.PrivateGroup then
        S:HandleCheckBox(creation.PrivateGroup.CheckButton)
    end

    S:HandleButton(creation.ListGroupButton)
    S:HandleButton(creation.CancelButton)

    local finder = creation.ActivityFinder
    local dialog = finder and finder.Dialog
    if dialog then
        dialog:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(dialog)

        S:HandleEditBox(dialog.EntryBox)
        S:HandleTrimScrollBar(dialog.ScrollBar)
        S:HandleButton(dialog.SelectButton)
        S:HandleButton(dialog.CancelButton)
    end
end

-- Application viewer --

---@param applicant NUIApplicantRow
local function UpdateApplicant(applicant)
    local S = Skinning

    SkinIconButton(S, applicant.DeclineButton)
    SkinIconButton(S, applicant.InviteButtonSmall)
    S:HandleButton(applicant.InviteButton)
end

-- LFGListColumnHeaderTemplate disables itself on load, these sort nothing and are never pressed.
---@param header Button?
local function SkinColumnHeader(S, header)
    if not header then return end

    S:HandleButton(header, nil, nil, nil, true)
end

-- The forming/unempowered cover washes the applicant list in Blizzard navy, which reads as
-- unskinned over our panel. Only the hue changes, the dim keeps Blizzard's own weight.
---@param background Texture
local function UpdateCoverBackground(background)
    local color = Skinning.db.General.BackgroundColor

    background:SetColorTexture(color[1], color[2], color[3], COVER_DIM_ALPHA)
end

local function SkinApplicationViewer(S, viewer)
    if not viewer then return end

    S:HandleAccentText(viewer.EntryName)

    local inset = viewer.Inset
    if inset then
        inset:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(inset, 'Transparent')
        NudgeInsetLeft(inset)
    end

    -- UpdateInfo re-picks a category atlas on every pass.
    local info = viewer.InfoBackground
    if info then
        info:NUIStripTextures('ClearHide')

        if inset then MatchInfoToInset(info, inset) end

        -- A bare texture can't own a backdrop, so it hangs off the viewer and takes the info rect.
        local backdrop = S:CreatePanelBackdrop(viewer, 'Transparent')
        if backdrop then
            backdrop:ClearAllPoints()
            backdrop:NUISetPixelPoint('TOPLEFT', info, 'TOPLEFT', 0, 0)
            backdrop:NUISetPixelPoint('BOTTOMRIGHT', info, 'BOTTOMRIGHT', 0, 0)
        end
    end

    S:HandleCheckBox(viewer.AutoAcceptButton)

    -- Sits over the list whenever the group is forming or the player can't manage applicants.
    local cover = viewer.UnempoweredCover
    if cover then
        S:HandleAccentFont(cover.Label)

        local background = cover.Background
        if background then
            background.NUIUpdateSkinColors = UpdateCoverBackground
            UpdateCoverBackground(background)
            S:RegisterSkinned(background)
        end
    end

    SkinColumnHeader(S, viewer.NameColumnHeader)
    SkinColumnHeader(S, viewer.RoleColumnHeader)
    SkinColumnHeader(S, viewer.ItemLevelColumnHeader)
    SkinColumnHeader(S, viewer.RatingColumnHeader)

    local refresh = viewer.RefreshButton
    if refresh then
        SkinIconButton(S, refresh, REFRESH_BUTTON_SIZE)
        refresh.Icon:SetAtlas(RESET_ATLAS)
        refresh.Icon:SetDesaturated(true)

        -- Blizzard hangs it 21px past the inset, clear of art the strip has already taken off.
        if inset then
            refresh:ClearAllPoints()
            refresh:NUISetPixelPoint('BOTTOMRIGHT', inset, 'TOPRIGHT', 0, 0)
        end
    end

    S:HandleButton(viewer.RemoveEntryButton)
    S:HandleButton(viewer.EditButton)
    S:HandleButton(viewer.BrowseGroupsButton)

    S:HandleTrimScrollBar(viewer.ScrollBar)
end

-- Queue frames --

---@param row NUIDungeonListRow
local function SkinDungeonListRow(row)
    local S = Skinning

    S:HandleCheckBox(row.enableButton, LIST_CHECK_INSET)
    ReapplyCheckBox(row.enableButton)

    S:ReskinCollapse(row.expandOrCollapseButton)
end

local function SkinDungeonFinder(S)
    local parent = _G.LFDParentFrame
    local queue = _G.LFDQueueFrame
    if not parent or not queue then return end

    parent:NUIStripTextures('Keyed')
    -- Each LFDQueueFrame_SetType* re-textures the background.
    queue:NUIStripTextures('ClearHide')

    SkinRoleButtons(S,
        _G.LFDQueueFrameRoleButtonTank,
        _G.LFDQueueFrameRoleButtonHealer,
        _G.LFDQueueFrameRoleButtonDPS,
        _G.LFDQueueFrameRoleButtonLeader)

    S:HandleDropdownButton(queue.TypeDropdown)
    -- The dropdown's caption carries no parentKey, unlike the dropdown itself.
    S:HandleAccentFont(_G.LFDQueueFrameTypeDropdownName)
    S:HandleButton(_G.LFDQueueFrameFindGroupButton)

    local random = _G.LFDQueueFrameRandomScrollFrame --[[@as NUIScrollFrame]]
    if random then
        S:HandleTrimScrollBar(random.ScrollBar)
        SkinRewardsPanel(S, random)
    end

    if queue.Specific then
        S:HandleTrimScrollBar(queue.Specific.ScrollBar)
        S:HookScrollBoxChildren(queue.Specific.ScrollBox, SkinDungeonListRow)
    end
    if queue.Follower then
        S:HandleTrimScrollBar(queue.Follower.ScrollBar)
        S:HookScrollBoxChildren(queue.Follower.ScrollBox, SkinDungeonListRow)

        -- The header carries no parentKey, unlike the panel's other pieces.
        S:HandleAccentFont(_G.LFDQueueFrameFollowerTitle)
    end

    S:HandleButton(_G.LFDQueueFramePartyBackfillBackfillButton)
    S:HandleButton(_G.LFDQueueFramePartyBackfillNoBackfillButton)
end

local function SkinRaidFinder(S)
    local frame = _G.RaidFinderFrame
    local queue = _G.RaidFinderQueueFrame
    if not frame or not queue then return end

    frame:NUIStripTextures('Keyed')
    queue:NUIStripTextures()

    SkinRoleButtons(S,
        _G.RaidFinderQueueFrameRoleButtonTank,
        _G.RaidFinderQueueFrameRoleButtonHealer,
        _G.RaidFinderQueueFrameRoleButtonDPS,
        _G.RaidFinderQueueFrameRoleButtonLeader)

    S:HandleDropdownButton(queue.SelectionDropdown)
    S:HandleAccentFont(_G.RaidFinderQueueFrameSelectionDropdownName)

    local scroll = _G.RaidFinderQueueFrameScrollFrame --[[@as NUIScrollFrame]]
    if scroll then
        S:HandleTrimScrollBar(scroll.ScrollBar)
        SkinRewardsPanel(S, scroll)
    end

    S:HandleButton(_G.RaidFinderFrameFindRaidButton)
    S:HandleButton(_G.RaidFinderQueueFramePartyBackfillBackfillButton)
    S:HandleButton(_G.RaidFinderQueueFramePartyBackfillNoBackfillButton)
end

local function SkinScenarioFinder(S)
    local frame = _G.ScenarioFinderFrame
    local queue = _G.ScenarioQueueFrame
    if not frame or not queue then return end

    frame:NUIStripTextures('Keyed')
    -- ScenarioQueueFrame_SetType re-textures Bg the same way.
    queue:NUIStripTextures('ClearHide')

    S:HandleDropdownButton(queue.Dropdown)
    S:HandleAccentFont(_G.ScenarioQueueFrameTypeDropdownName)
    S:HandleButton(_G.ScenarioQueueFrameFindGroupButton)

    local random = queue.Random and queue.Random.ScrollFrame --[[@as NUIScrollFrame]]
    if random then
        S:HandleTrimScrollBar(random.ScrollBar)
        SkinRewardsPanel(S, random)
    end
    if queue.Specific and queue.Specific.ScrollFrame then
        queue.Specific.ScrollFrame:NUIStripTextures()
        S:HandleTrimScrollBar(queue.Specific.ScrollBar)
        S:HookScrollBoxChildren(queue.Specific.ScrollFrame, SkinDungeonListRow)
    end
end

-- Dialogs and popups --

---@param frame Frame? A DialogBorderTemplate window
local function SkinDialog(S, frame)
    if not frame then return end

    frame:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(frame)
end

local function SkinDialogs(S)
    local application = _G.LFGListApplicationDialog
    if application then
        SkinDialog(S, application)
        SkinInputScroll(S, application.Description --[[@as NUIScrollFrame]])
        S:HandleButton(application.SignUpButton)
        S:HandleButton(application.CancelButton)
        SkinRoleButtons(S, application.TankButton, application.HealerButton, application.DamagerButton)
    end

    local invite = _G.LFGListInviteDialog
    if invite then
        SkinDialog(S, invite)
        S:HandleButton(invite.AcceptButton)
        S:HandleButton(invite.DeclineButton)
        S:HandleButton(invite.AcknowledgeButton)
    end

    local popup = _G.LFGInvitePopup
    if popup then
        SkinDialog(S, popup)
        for _, roleButton in ipairs(popup.RoleButtons or {}) do
            SkinRoleButton(S, roleButton --[[@as NUIRoleButton]])
        end
        S:HandleButton(_G.LFGInvitePopupAcceptButton)
        S:HandleButton(_G.LFGInvitePopupDeclineButton)
    end

    local rolePoll = _G.RolePollPopup
    if rolePoll then
        SkinDialog(S, rolePoll)
        SkinRoleButtons(S,
            _G.RolePollPopupRoleButtonTank,
            _G.RolePollPopupRoleButtonHealer,
            _G.RolePollPopupRoleButtonDPS)
        S:HandleButton(rolePoll.acceptButton)
        S:HandleCloseButton(_G.RolePollPopupCloseButton, rolePoll)
    end

    local status = _G.LFGDungeonReadyStatus
    if status then
        SkinDialog(S, status)
        S:HandleCloseButton(_G.LFGDungeonReadyStatusCloseButton, status)
    end

    local ready = _G.LFGDungeonReadyDialog
    if ready then
        SkinDialog(S, ready)
        -- Every proposal swaps in that dungeon's art.
        if ready.background then ready.background:NUIStripTextures('ClearHide') end
        S:HandleButton(ready.enterButton)
        S:HandleButton(ready.leaveButton)
        S:HandleCloseButton(_G.LFGDungeonReadyDialogCloseButton, ready)
    end

    -- Brawl and Solo Shuffle share the PvP ready popup.
    local pvpStatus = _G.ReadyStatus
    if pvpStatus then
        SkinDialog(S, pvpStatus)
        S:HandleCloseButton(pvpStatus.CloseButton, pvpStatus)
    end
end

-- PVEFrame shell --

-- HandleButton clears the bg texcoords Blizzard marks the active button with, so the label carries it.
local selectedGroupIndex

local function UpdateGroupButtonLabels()
    local groupFinder = _G.GroupFinderFrame
    if not groupFinder then return end

    local r, g, b = Skinning:GetAccentColor()
    local dim = Skinning.db.General.DisabledColor[4]

    local index = 1
    local button = groupFinder['groupButton' .. index]
    while button do
        if button.name then
            -- SetEnabled swaps the font object, which an explicit text color would mask.
            if not button:IsEnabled() then
                button.name:SetTextColor(dim, dim, dim)
            elseif index == selectedGroupIndex then
                button.name:SetTextColor(r, g, b)
            else
                button.name:SetTextColor(1, 1, 1)
            end
        end

        index = index + 1
        button = groupFinder['groupButton' .. index]
    end
end

---@param index number
local function OnGroupButtonSelected(index)
    selectedGroupIndex = index
    UpdateGroupButtonLabels()
end

local function SkinShell(S)
    local frame = _G.PVEFrame
    if not frame then return end

    S:HandlePortraitFrame(frame)
    S:HandleAccentFont(frame.TitleContainer and frame.TitleContainer.TitleText)

    -- The shadows come back whenever the Mythic+ tab is toggled, so clearing is not enough.
    if frame.shadows then
        frame.shadows:NUIStripTextures('Kill')
    end

    S:HandleTabRow('PVEFrameTab', frame)

    local groupFinder = _G.GroupFinderFrame
    if not groupFinder then return end

    local index = 1
    local button = groupFinder['groupButton' .. index]
    while button do
        -- HandleButton clears the icon along with the ring and plate, so it has to come back.
        local icon = button.icon
        local texture = icon and icon:GetTexture()

        if button.CircleMask then button.CircleMask:Hide() end
        S:HandleButton(button)

        if icon then
            icon:SetTexture(texture)
            icon:SetAlpha(1)
            icon:NUISetPixelSize(GROUP_BUTTON_ICON_SIZE, GROUP_BUTTON_ICON_SIZE)
            icon:ClearAllPoints()
            icon:NUISetPixelPoint('LEFT', button, 'LEFT', GROUP_BUTTON_ICON_GAP, 0)
            S:HandleIcon(icon, true)

            -- The label hung off the ring HandleButton strips, so it rides the icon instead.
            if button.name then
                button.name:ClearAllPoints()
                button.name:NUISetPixelPoint('LEFT', icon, 'RIGHT', GROUP_BUTTON_TEXT_GAP, 0)
            end
        end
        index = index + 1
        button = groupFinder['groupButton' .. index]
    end

    -- The labels are plain regions, so the button mixin never sees them, recolor via the parent.
    groupFinder.NUIUpdateSkinColors = UpdateGroupButtonLabels
    S:RegisterSkinned(groupFinder)

    selectedGroupIndex = groupFinder.selectionIndex
    UpdateGroupButtonLabels()
    hooksecurefunc('GroupFinderFrame_SelectGroupButton', OnGroupButtonSelected)
    hooksecurefunc('GroupFinderFrameButton_SetEnabled', UpdateGroupButtonLabels)
end

Skinning:RegisterSkin(nil, 'GroupFinder', function(S)
    SkinShell(S)

    SkinDungeonFinder(S)
    SkinRaidFinder(S)
    SkinScenarioFinder(S)
    SkinDialogs(S)

    local frame = _G.LFGListFrame
    if frame then
        SkinCategorySelection(S, frame.CategorySelection)
        SkinEntryCreation(S, frame.EntryCreation)
        SkinApplicationViewer(S, frame.ApplicationViewer)
        SkinSearchPanel(S, frame.SearchPanel)

        local nothing = frame.NothingAvailable and frame.NothingAvailable.Inset
        if nothing then
            nothing:NUIStripTextures('Keyed')
            S:CreatePanelBackdrop(nothing, 'Transparent')
        end

        hooksecurefunc('LFGListCategorySelection_AddButton', UpdateCategoryButton)
        hooksecurefunc('LFGListApplicationViewer_UpdateApplicant', UpdateApplicant)
        hooksecurefunc('LFGListSearchEntry_Update', UpdateSearchEntry)
    end

    -- Shared by the dungeon, raid and scenario reward panels.
    hooksecurefunc('LFGRewardsFrame_SetItemButton', UpdateRewardItem)

    -- LFGInvitePopup_Update re-textures its role boxes on every invite, undoing the skin.
    hooksecurefunc('SetCheckButtonIsRadio', ReapplyCheckBox)
end)

-- Mythic+ tab --

---@param frame NUIAffixHolder Affix holder, either the keystone frame or the weekly info child
local function SkinAffixes(S, frame)
    local container = frame.AffixesContainer or frame
    local affixes = container.Affixes
    if not affixes then return end

    for _, affix in ipairs(affixes) do
        if not affix.NUISkinned then
            affix.NUISkinned = true

            if affix.Border then affix.Border:NUIStripTextures() end
            if affix.CircleMask then affix.CircleMask:Hide() end

            S:HandleIcon(affix.Portrait, true)
        end
    end
end

local function UpdateDungeonIcons(frame)
    local S = Skinning

    for _, icon in ipairs(frame.DungeonIcons or {}) do
        if not icon.NUISkinned then
            icon.NUISkinned = true

            icon:NUIStripTextures('Atlas', 'ChallengeMode-DungeonIconFrame')
            S:HandleIcon(icon.Icon, true)
        end
    end
end

Skinning:RegisterSkin('Blizzard_ChallengesUI', 'GroupFinder', function(S)
    local frame = _G.ChallengesFrame
    if not frame then return end

    -- Update re-textures Background from the season's first map.
    frame:NUIStripTextures('ClearHide')

    local inset = _G.ChallengesFrameInset
    if inset then
        inset:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(inset, 'Transparent')
    end

    local keystone = _G.ChallengesKeystoneFrame
    if keystone then
        keystone:NUIStripTextures()
        S:CreatePanelBackdrop(keystone, 'Transparent')

        S:HandleButton(keystone.StartButton)
        S:HandleCloseButton(keystone.CloseButton, keystone)
        if keystone.KeystoneSlot then
            S:HandleIcon(keystone.KeystoneSlot.Texture, true)
        end

        hooksecurefunc(keystone, 'OnKeystoneSlotted', function(self) SkinAffixes(S, self) end)
    end

    local notice = frame.SeasonChangeNoticeFrame
    if notice then
        notice:NUIStripTextures()
        S:CreatePanelBackdrop(notice)
        S:HandleButton(notice.Leave)

        -- The notice affix adds its own popup ring over the keystone template's, so both go.
        local affix = notice.Affix
        if affix then
            if affix.Border then affix.Border:NUIStripTextures() end
            if affix.AffixBorder then affix.AffixBorder:NUIStripTextures() end
            if affix.CircleMask then affix.CircleMask:Hide() end
            S:HandleIcon(affix.Portrait, true)
        end
    end

    hooksecurefunc(frame, 'Update', UpdateDungeonIcons)
    UpdateDungeonIcons(frame)

    if _G.ChallengesFrameWeeklyInfoMixin then
        hooksecurefunc(_G.ChallengesFrameWeeklyInfoMixin, 'SetUp', function(info)
            SkinAffixes(S, info.Child)
        end)
    end
end)
