---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local select = select
local ipairs = ipairs
local unpack = unpack
local format = string.format
local Mixin = Mixin
local hooksecurefunc = hooksecurefunc

local C_Timer = C_Timer

local CHECK_INSET = 6
local PARCHMENT_ALPHA = 0.35
local RESET_BUTTON_SIZE = 14
local SEARCH_ROW_INSET = 8
local COLLAPSE_GLYPH_SIZE = 16
local RANK_BUTTON_SIZE = 18
local RANK_BUTTON_GAP = 4
local RANK_ARROW_SIZE = 11
local OUTPUT_SWEEP_DELAY = 0.4
local LINK_ICON_CROP = { 0.25, 0.7, 0.37, 0.75 }

local GEAR_SLOTS = {
    'Prof0ToolSlot', 'Prof0Gear0Slot', 'Prof0Gear1Slot',
    'Prof1ToolSlot', 'Prof1Gear0Slot', 'Prof1Gear1Slot',
    'CookingToolSlot', 'CookingGear0Slot',
    'FishingToolSlot', 'FishingGear0Slot', 'FishingGear1Slot',
}

local SLOT_ART_KEYS = { 'SlotBackground', 'CropFrame', 'ColorOverlay', 'NormalTexture', 'HighlightTexture' }

-- Slot buttons --

---Profession slot buttons substitute their own Icon for the ItemButton intrinsic's lowercase icon.
---@param S SkinningModule
---@param button NUIProfessionsSlotButton?
---@param keepArt boolean? Spare Blizzard's own art, for a button whose icon is its identity
local function SkinSlotButton(S, button, keepArt)
    if not button then return end

    -- Blizzard re-drives the slot art and the overlay glyphs per item state, so they can't ride the guard.
    if not keepArt then
        for _, key in ipairs(SLOT_ART_KEYS) do
            local region = button[key]
            if region then region:SetAlpha(0) end
        end

        local normal = button.GetNormalTexture and button:GetNormalTexture()
        if normal then normal:SetAlpha(0) end
    end

    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then highlight:SetAlpha(0) end

    button:NUIStyleButton(true) -- AddHighlight owns the hover, so only pushed and checked are ours
    if button.pushed then button.pushed:SetDrawLayer('OVERLAY') end -- an opaque icon shares ARTWORK

    if button.InputOverlay then
        local r, g, b = S:GetAccentColor()
        for _, region in ipairs({ button.InputOverlay:GetRegions() }) do
            if region:IsObjectType('Texture') then
                region:SetDesaturated(true)
                region:SetVertexColor(r, g, b)
            end
        end
    end

    if button.NUISkinned then return end

    local icon = button.Icon
    if not icon then return end
    button.NUISkinned = true

    if button.SetNormalTexture then
        button:SetNormalTexture(NRSKNUI.ClearTexture)
        button:SetDisabledTexture(NRSKNUI.ClearTexture)
        button:SetHighlightTexture(NRSKNUI.ClearTexture)
    end

    S:HandleIcon(icon, true, nil, true)
    S:AddHighlight(button, icon)

    if button.IconBorder then
        S:HandleIconBorder(button.IconBorder, icon.NUIBackdrop)
    end
end

---@param S SkinningModule
---@param button NUIProfessionsSlotButton?
local function SkinOutputIcon(S, button)
    if not button or button.NUISkinned then return end

    local icon = button.Icon
    if not icon then return end
    button.NUISkinned = true

    if button.CircleMask then button.CircleMask:Hide() end -- squares off the icon it masks
    if button.SetHighlightTexture then button:SetHighlightTexture(NRSKNUI.ClearTexture) end

    S:HandleIcon(icon, true)
    S:AddHighlight(button, icon)

    if button.IconBorder then
        S:HandleIconBorder(button.IconBorder, icon.NUIBackdrop)
    end
end

---@param S SkinningModule
---@param box NUINumericSpinner?
local function SkinInputSpinner(S, box)
    if not box then return end

    S:HandleEditBox(box)
    S:HandleNextPrevButton(box.DecrementButton, 'left')
    S:HandleNextPrevButton(box.IncrementButton, 'right')
end

-- Schematic form --

---@param S SkinningModule
---@param dialog NUIProfessionsQualityDialog?
local function SkinQualityDialog(S, dialog)
    if not dialog or dialog.NUISkinned then return end
    dialog.NUISkinned = true

    dialog:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(dialog)

    S:HandleAccentFont(dialog.TitleContainer and dialog.TitleContainer.TitleText)
    S:HandleCloseButton(dialog.ClosePanelButton, dialog)
    S:HandleButton(dialog.AcceptButton)
    S:HandleButton(dialog.CancelButton)

    for _, key in ipairs({ 'Container1', 'Container2', 'Container3' }) do
        local container = dialog[key]
        if container then
            SkinSlotButton(S, container.Button)
            SkinInputSpinner(S, container.EditBox)
        end
    end
end

---@param form NUIProfessionsSchematicForm
local function SkinSchematicSlots(form)
    local S = Skinning

    if form.reagentSlotPool then
        for slot in form.reagentSlotPool:EnumerateActive() do
            SkinSlotButton(S, slot.Button)
            S:HandleCheckBox(slot.Checkbox, CHECK_INSET)
        end
    end

    -- enchantSlot is the one Death Knight runeforging runs through.
    for _, key in ipairs({ 'salvageSlot', 'enchantSlot' }) do
        local slot = form[key]
        if slot then SkinSlotButton(S, slot.Button) end
    end

    local recraft = form.recraftSlot
    if recraft then
        SkinSlotButton(S, recraft.InputSlot)
        SkinSlotButton(S, recraft.OutputSlot)
    end

    local choices = form.Details and form.Details.CraftingChoicesContainer
    local concentrate = choices and choices.ConcentrateContainer
    SkinSlotButton(S, concentrate and concentrate.ConcentrateToggleButton, true)
end

-- Colour escapes come in a hex form and a named form; a pattern for one cannot see the other.
local COLOR_CODES = { '|c%x%x%x%x%x%x%x%x', '|cn[^:]+:' }

---@param text string
---@return string
local function StripColorCodes(text)
    for _, pattern in ipairs(COLOR_CODES) do
        text = text:gsub(pattern, '')
    end
    return (text:gsub('|r', ''))
end

---@param text string
---@return string head
local function StripLeadingColor(text)
    for _, pattern in ipairs(COLOR_CODES) do
        local head, count = text:gsub('^' .. pattern, '', 1)
        if count > 0 then return head end
    end
    return text
end

local REQUIRES_LABEL = (StripColorCodes((PROFESSIONS_REQUIRED_TOOLS:gsub('%%s.*$', ''))):gsub('%s+$', ''))

---Blizzard bakes colour codes into these strings, and an embedded code beats both the font object
---and SetTextColor, so the codes have to come out before the accent can show.
---@param S SkinningModule
---@param fontString FontString?
local function AccentEmbeddedText(S, fontString)
    if not fontString or fontString.NUISkinned then return end

    S:HandleAccentText(fontString)

    hooksecurefunc(fontString, 'SetText', function(self, text)
        if self.NUIRewriting or type(text) ~= 'string' then return end

        local body = StripColorCodes(text)
        if body == text then return end

        self.NUIRewriting = true
        self:SetText(body)
        self.NUIRewriting = nil
    end)

    local current = fontString:GetText()
    if current then fontString:SetText(current) end
end

---@class NUIRequiresLabelMixin
local RequiresLabelMixin = {}

---The accent is baked into the string, so a recolour has to run the text back through the rewrite.
function RequiresLabelMixin:NUIUpdateSkinColors()
    ---@cast self FontString
    local text = self:GetText()
    if text then self:SetText(text) end
end

---@param S SkinningModule
---@param fontString FontString?
local function AccentRequiresLabel(S, fontString)
    if not fontString or fontString.NUISkinned then return end
    fontString.NUISkinned = true

    hooksecurefunc(fontString, 'SetText', function(self, text)
        if self.NUIRewriting or type(text) ~= 'string' then return end

        local rest = StripLeadingColor(text)
        if rest == text then return end

        local stop = rest:find('|r', 1, true)
        if not stop or StripColorCodes(rest:sub(1, stop - 1)) ~= REQUIRES_LABEL then return end

        local body = format('|cFF%s%s', NRSKNUI:RGBAToHex(S:GetAccentColor()), rest)
        if body == text then return end

        self.NUIRewriting = true
        self:SetText(body)
        self.NUIRewriting = nil
    end)

    ---@cast fontString FontString & NUIRequiresLabelMixin
    Mixin(fontString, RequiresLabelMixin)
    S:RegisterSkinned(fontString)

    local current = fontString:GetText()
    if current then fontString:SetText(current) end
end

---The quality meter itself is bespoke flipbook art, so only its backing panel changes.
---@param S SkinningModule
---@param details NUIProfessionsCrafterDetails?
local function SkinCrafterDetails(S, details)
    if not details then return end

    for _, key in ipairs({ 'BackgroundTop', 'BackgroundMiddle', 'BackgroundBottom', 'BackgroundMinimized' }) do
        local texture = details[key]
        if texture then texture:SetAlpha(0) end
    end

    S:CreatePanelBackdrop(details, 'Transparent')
    S:HandleOutlineFont(details.Label)

    local lines = details.StatLines
    if not lines then return end

    for _, key in ipairs({ 'DifficultyStatLine', 'SkillStatLine', 'ConcentrationStatLine' }) do
        local line = lines[key]
        if line then
            S:HandleOutlineFont(line.LeftLabel)
            S:HandleOutlineFont(line.RightLabel)
        end
    end
end

---@param S SkinningModule
---@param form NUIProfessionsSchematicForm?
---@param noParchment boolean? Drop the profession background instead of dimming it
local function SkinSchematicForm(S, form, noParchment)
    if not form or form.NUISkinned then return end
    form.NUISkinned = true

    form:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(form)

    -- Blizzard re-drives both atlases on every Refresh, so only the alpha sticks.
    for _, key in ipairs({ 'Background', 'MinimalBackground' }) do
        local texture = form[key]
        if texture then texture:SetAlpha(noParchment and 0 or PARCHMENT_ALPHA) end
    end

    S:HandleCheckBox(form.TrackRecipeCheckbox, CHECK_INSET)
    S:HandleCheckBox(form.AllocateBestQualityCheckbox, CHECK_INSET)

    AccentEmbeddedText(S, form.OutputText)
    AccentEmbeddedText(S, form.RecraftingOutputText)
    AccentRequiresLabel(S, form.RequiredTools)
    AccentRequiresLabel(S, form.RecraftingRequiredTools)
    S:HandleAccentFont(form.OutputSubText)

    SkinOutputIcon(S, form.OutputIcon)
    SkinQualityDialog(S, form.QualityDialog)
    SkinCrafterDetails(S, form.Details)

    S:HandleDropdownButton(form.RecipeLevelDropdown)
    S:HandleStatusBar(form.RecipeLevelBar)

    SkinSchematicSlots(form)
    hooksecurefunc(form, 'Init', SkinSchematicSlots)
end

-- Item flyout --

---@param button NUIProfessionsSlotButton
local function SkinFlyoutButton(button)
    SkinSlotButton(Skinning, button)
end

---The flyout is one frame private to Blizzard_ProfessionsTemplates, reachable only off the behavior.
---@param behavior NUIProfessionsFlyoutBehavior
local function SkinItemFlyout(_anchorTo, _owner, behavior)
    local flyout = behavior and behavior.flyout
    if not flyout then return end

    local S = Skinning

    if not flyout.NUISkinned then
        flyout.NUISkinned = true

        flyout:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(flyout)

        S:HandleTrimScrollBar(flyout.ScrollBar)
        S:HandleCheckBox(flyout.HideUnownedCheckbox, CHECK_INSET)
        S:HandleButton(flyout.UndoButton, nil, nil, true)
        SkinSlotButton(S, flyout.UndoItem)

        S:HookScrollBoxChildren(flyout.ScrollBox, SkinFlyoutButton)
    end

    -- One flyout, reparented per open, so its level moves out from under the backdrop's.
    local backdrop = flyout.NUIBackdrop
    if backdrop then
        if flyout:GetFrameLevel() == 0 then flyout:SetFrameLevel(1) end
        backdrop:SetFrameLevel(flyout:GetFrameLevel() - 1)
    end
end

-- Recipe list --

local RecipeRowMixin = {}

function RecipeRowMixin:NUIUpdateSkinColors()
    local r, g, b = Skinning:GetAccentColor()

    if self.SelectedOverlay then
        self.SelectedOverlay:SetVertexColor(r, g, b)
        self.HighlightOverlay:SetVertexColor(r, g, b)
    end

    -- Only category headers carry a collapse glyph, and Init repaints their label every pass.
    if self.CollapseIcon and not self.NUIUnlearned then
        self.Label:SetVertexColor(r, g, b)
    end
end

---@param row NUIProfessionsRecipeRow
local function SkinRecipeRow(row)
    if not row.NUISkinned then
        row.NUISkinned = true

        -- Category headers wear a gold plate that reads as a seam over our fill.
        for _, key in ipairs({ 'LeftPiece', 'RightPiece', 'CenterPiece' }) do
            local piece = row[key]
            if piece then piece:SetAlpha(0) end
        end

        if row.SelectedOverlay then
            row.SelectedOverlay:SetDesaturated(true)
            row.HighlightOverlay:SetDesaturated(true)
        end

        Mixin(row, RecipeRowMixin)
        Skinning:RegisterSkinned(row)
    end

    row:NUIUpdateSkinColors()
end

---@param row NUIProfessionsRecipeRow
---@param collapsed boolean
local function SetCategoryCollapsed(row, collapsed)
    Skinning:SetPlusMinusGlyph(row.CollapseIcon, collapsed, COLLAPSE_GLYPH_SIZE)
    row.CollapseIconAlphaAdd:SetAlpha(0)
end

---Unlearned categories stay greyed, so the accent pass has to know which ones they are.
---@param row NUIProfessionsRecipeRow
---@param node table
local function InitCategory(row, node)
    row.NUIUnlearned = node:GetData().categoryInfo.unlearned
end

---@param S SkinningModule
---@param list NUIProfessionsRecipeList?
local function SkinRecipeList(S, list)
    if not list or list.NUISkinned then return end
    list.NUISkinned = true

    list:NUIStripTextures('Keyed')
    if list.BackgroundNineSlice then list.BackgroundNineSlice:NUIBanish() end

    S:HandleEditBox(list.SearchBox)
    S:HandleTrimScrollBar(list.ScrollBar)
    S:HookScrollBoxChildren(list.ScrollBox, SkinRecipeRow)

    -- WowStyle1FilterDropdownTemplate has no Arrow, so it dresses as a plain button.
    local filter = list.FilterDropdown
    if not filter then return end

    S:HandleButton(filter)
    S:HandleCloseButton(filter.ResetButton, filter, 8, 8, RESET_BUTTON_SIZE)

    local box = list.SearchBox
    if not box then return end

    local function SquareSearchRow()
        if not box.NUIArtTop then return end

        filter:ClearAllPoints()
        filter:NUISetPixelPoint('TOPRIGHT', list, 'TOPRIGHT', -SEARCH_ROW_INSET, -SEARCH_ROW_INSET + box.NUIArtTop)
        filter:NUISetPixelHeight(box:GetHeight() + box.NUIArtTop - box.NUIArtBottom)
    end

    SquareSearchRow()
    box:HookScript('OnShow', SquareSearchRow)
end

-- Rank bar --

---@param S SkinningModule
---@param bar NUIProfessionsRankBar?
local function SkinRankBar(S, bar)
    if not bar or bar.NUISkinned then return end
    bar.NUISkinned = true

    -- The Fill is a flipbook the level-up animation drives, so only the frame art comes off.
    for _, key in ipairs({ 'Border', 'Background' }) do
        local texture = bar[key]
        if texture then texture:SetAlpha(0) end
    end

    -- The frame rect is both wider and taller than the fill, so the backdrop traces the fill.
    local backdrop = S:CreatePanelBackdrop(bar, nil, nil, true)
    if backdrop and bar.Fill then
        backdrop:ClearAllPoints()
        backdrop:NUISetPixelPoint('TOPLEFT', bar.Fill, 'TOPLEFT', -1, 1)
        backdrop:NUISetPixelPoint('BOTTOMRIGHT', bar.Fill, 'BOTTOMRIGHT', 1, -1)
    end

    S:HandleOutlineFont(bar.Rank and bar.Rank.Text)

    -- A bare DropdownButton with one unnamed texture, so HandleDropdownButton has no Arrow to take.
    local expansion = bar.ExpansionDropdownButton
    if not expansion then return end

    if expansion.Texture then expansion.Texture:SetAlpha(0) end
    S:HandleButton(expansion)
    S:CreateArrowTexture(expansion, 'down', RANK_ARROW_SIZE, RANK_ARROW_SIZE, nil, nil, nil, nil, nil, true)

    -- Blizzard parks it over the fill's right end, which reads as a box inside the bar.
    expansion:NUISetPixelSize(RANK_BUTTON_SIZE, RANK_BUTTON_SIZE)
    expansion:ClearAllPoints()
    expansion:NUISetPixelPoint('LEFT', bar.Fill, 'RIGHT', RANK_BUTTON_GAP, 0)
end

-- Crafting output log --

---@param child NUIProfessionsOutputRow
local function SkinOutputRow(child)
    local S = Skinning

    local container = child.ItemContainer
    if container then
        for _, key in ipairs({ 'NameFrame', 'BorderFrame', 'HighlightNameFrame', 'PushedNameFrame' }) do
            local texture = container[key]
            -- Cleared rather than dimmed, so a state change restoring the alpha has nothing to draw.
            if texture then texture:NUIStripTextures('ClearHide') end
        end

        S:HandleItemButton(container.Item)
        S:HandleOutlineFont(container.Text)
    end

    for _, row in ipairs(child.Rows or {}) do
        if row.Bracket then row.Bracket:SetAlpha(0) end
        S:HandleItemButton(row.Item)
    end

    -- The resource and bonus rows draw their icons from a pool Init refills every time.
    if child.itemButtonPool then
        for button in child.itemButtonPool:EnumerateActive() do
            SkinSlotButton(S, button)
        end
    end
end

---@param S SkinningModule
---@param log NUIProfessionsOutputLog?
local function SkinOutputLog(S, log)
    if not log or log.NUISkinned then return end
    log.NUISkinned = true

    log:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(log)

    S:HandleAccentFont(log.TitleContainer and log.TitleContainer.TitleText)
    S:HandleCloseButton(log.ClosePanelButton, log)
    S:HandleTrimScrollBar(log.ScrollBar)
    S:HookScrollBoxChildren(log.ScrollBox, SkinOutputRow)

    hooksecurefunc(log, 'FinalizeResultData', function(self)
        C_Timer.After(OUTPUT_SWEEP_DELAY, function()
            self.ScrollBox:ForEachFrame(SkinOutputRow)
        end)
    end)
end

-- Crafting page --

---@param S SkinningModule
---@param page NUIProfessionsCraftingPage
local function SkinCraftingPage(S, page)
    S:HandleButton(page.CreateButton)
    S:HandleButton(page.CreateAllButton)
    S:HandleButton(page.ViewGuildCraftersButton)
    SkinInputSpinner(S, page.CreateMultipleInputBox)

    -- The minimized layout swaps the recipe list for a search box and its own results panel.
    S:HandleEditBox(page.MinimizedSearchBox)

    local results = page.MinimizedSearchResults
    if results then
        S:HandlePortraitFrame(results)
        S:HandleTrimScrollBar(results.ScrollBar)
    end

    if page.ConcentrationDisplay then
        S:HandleIcon(page.ConcentrationDisplay.Icon, true)
    end

    if page.TutorialButton then
        -- Hide help tip button
        page.TutorialButton:NUIBanish()
    end

    -- It hangs off the rank bar's right edge, where the expansion dropdown has just moved to.
    local link = page.LinkButton
    local expansion = page.RankBar and page.RankBar.ExpansionDropdownButton
    if link and expansion then
        S:CreatePanelBackdrop(link, nil, nil, true)
        S:AddHighlight(link)

        for _, texture in ipairs({ link:GetNormalTexture(), link:GetPushedTexture() }) do
            texture:SetTexCoord(unpack(LINK_ICON_CROP))
            texture:NUISetPixelInside()
        end

        link:NUISetPixelSize(RANK_BUTTON_SIZE, RANK_BUTTON_SIZE)
        link:ClearAllPoints()
        link:NUISetPixelPoint('LEFT', expansion, 'RIGHT', RANK_BUTTON_GAP, 0)
    end

    local guild = page.GuildFrame
    if guild then
        guild:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(guild)
        S:HandleAccentFont(guild.Title)

        local container = guild.Container
        if container then
            container:NUIStripTextures('Keyed')
            S:CreatePanelBackdrop(container)
            S:HandleTrimScrollBar(container.ScrollBar)
        end
    end

    for _, key in ipairs(GEAR_SLOTS) do
        S:HandleItemButton(page[key])
    end

    if page.GearSlotDivider then page.GearSlotDivider:NUIStripTextures() end

    SkinRecipeList(S, page.RecipeList)
    SkinSchematicForm(S, page.SchematicForm)
    SkinRankBar(S, page.RankBar)
    SkinOutputLog(S, page.CraftingOutputLog)
end

-- Specialization page --

---@param page NUIProfessionsSpecPage
local function SkinSpecTabs(page)
    if not page.tabsPool then return end

    for tab in page.tabsPool:EnumerateActive() do
        -- The lock glyph is a region on the tab, and the mixin only re-drives its shown state.
        if tab.StateIcon then tab.StateIcon.NUINoStrip = true end
        Skinning:HandleTab(tab, true)
    end
end

---@param S SkinningModule
---@param page NUIProfessionsSpecPage?
local function SkinSpecPage(S, page)
    if not page then return end

    for _, key in ipairs({
        'ApplyButton', 'UnlockTabButton', 'ViewTreeButton',
        'BackToPreviewButton', 'ViewPreviewButton', 'BackToFullTreeButton',
    }) do
        S:HandleButton(page[key])
    end

    S:HandleButton(page.UndoButton, nil, nil, true)

    if page.PanelFooter then page.PanelFooter:NUIStripTextures('Keyed') end

    local tree = page.TreeView
    if tree then
        S:CreatePanelBackdrop(tree)
        if tree.Background then tree.Background:SetAlpha(PARCHMENT_ALPHA) end
        S:HandleAccentFont(tree.TreeName)
        S:HandleOutlineFont(tree.TreeDescription)
    end

    local detail = page.DetailedView
    if detail then
        S:CreatePanelBackdrop(detail)
        if detail.Background then detail.Background:SetAlpha(PARCHMENT_ALPHA) end

        S:HandleButton(detail.UnlockPathButton)
        S:HandleButton(detail.SpendPointsButton)
        S:HandleAccentFont(detail.PathName)
        S:HandleOutlineFont(detail.PointsText)

        if detail.UnspentPoints then
            S:HandleIcon(detail.UnspentPoints.Icon, true)
        end
    end

    local preview = page.TreePreview
    if preview then
        S:CreatePanelBackdrop(preview)
        S:HandleAccentFont(preview.Title)
        S:HandleOutlineFont(preview.Description)
    end

    SkinSpecTabs(page)
    hooksecurefunc(page, 'UpdateTabs', SkinSpecTabs)
end

-- Crafting orders --

---@param S SkinningModule
---@param note NUIProfessionsNoteBox?
local function SkinNoteBox(S, note)
    if not note then return end

    local art = note.Background or note
    if art.Border then art.Border:SetAlpha(0) end

    -- ScrollingEditBoxTemplate is a Frame wrapping a ScrollBox, so it can't take HandleEditBox.
    local backdrop = S:CreatePanelBackdrop(note)
    S:HandleAccentFont(note.NoteTitle or (note.TitleBox and note.TitleBox.Title))

    -- The wrapper is padded well past the visible box, so only the field's own edges are worth tracing.
    local field = note.ScrollingEditBox
    if backdrop and field then
        backdrop:ClearAllPoints()
        backdrop:SetPoint('TOP', note, 'TOP')
        backdrop:SetPoint('BOTTOM', note, 'BOTTOM')
        backdrop:SetPoint('LEFT', field, 'LEFT', -6, 0)
        backdrop:SetPoint('RIGHT', field, 'RIGHT', 6, 0)
    end
end

---@param S SkinningModule
---@param view NUIProfessionsOrderView?
local function SkinOrderView(S, view)
    if not view then return end

    for _, key in ipairs({ 'CreateButton', 'CompleteOrderButton', 'StartRecraftButton', 'StopRecraftButton' }) do
        S:HandleButton(view[key])
    end

    if view.ConcentrationDisplay then
        S:HandleIcon(view.ConcentrationDisplay.Icon, true)
    end

    SkinRankBar(S, view.RankBar)
    SkinOutputLog(S, view.CraftingOutputLog)

    local info = view.OrderInfo
    if info then
        info:NUIStripTextures('Keyed')
        --S:CreatePanelBackdrop(info)

        S:HandleButton(info.BackButton)
        S:HandleButton(info.StartOrderButton)
        S:HandleButton(info.DeclineOrderButton)
        S:HandleButton(info.ReleaseOrderButton)
        -- Its glyph is the lowercase key, which HandleButton's keepIcon doesn't cover.
        if info.SocialDropdown and info.SocialDropdown.icon then
            info.SocialDropdown.icon.NUINoStrip = true
        end
        S:HandleButton(info.SocialDropdown)
        SkinNoteBox(S, info.NoteBox)

        local rewards = info.NPCRewardsFrame
        if rewards then
            if rewards.Background then rewards.Background:SetAlpha(0) end
            --S:CreatePanelBackdrop(rewards)
            S:HandleAccentFont(rewards.RewardText)

            for _, item in ipairs(rewards.RewardItems or {}) do
                SkinSlotButton(S, item)
            end
        end
    end

    local details = view.OrderDetails
    if details then
        if details.MinimumQualityIcon then details.MinimumQualityIcon.NUINoStrip = true end
        details:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(details)
        if details.Background then details.Background:SetAlpha(PARCHMENT_ALPHA) end

        SkinSchematicForm(S, details.SchematicForm)

        local fulfillment = details.FulfillmentForm
        if fulfillment then
            SkinOutputIcon(S, fulfillment.ItemIcon)
            SkinNoteBox(S, fulfillment.NoteEditBox)
            S:HandleOutlineFont(fulfillment.ItemName)

            local recraft = fulfillment.RecraftSlot
            if recraft then
                SkinSlotButton(S, recraft.InputSlot)
                SkinSlotButton(S, recraft.OutputSlot)
            end
        end
    end

    local decline = view.DeclineOrderDialog
    if decline then
        decline:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(decline)

        S:HandleAccentFont(decline.TitleContainer and decline.TitleContainer.TitleText)
        S:HandleAccentFont(decline.ConfirmationText)
        SkinNoteBox(S, decline.NoteEditBox)
        S:HandleButton(decline.ConfirmButton)
        S:HandleButton(decline.CancelButton)
    end
end

---Table builder columns, so the headers are anonymous children and only their plate is BACKGROUND.
---@param S SkinningModule
---@param container Frame?
local function SkinListHeaders(S, container)
    if not container then return end

    for _, header in ipairs({ container:GetChildren() }) do
        if header:IsObjectType('Button') and not header.NUISkinned then
            ---@cast header Button
            header.NUISkinned = true

            header:NUIStripTextures('Layer', 'BACKGROUND')
            S:CreatePanelBackdrop(header, nil, nil, true)
            S:AddHighlight(header)
            S:HandleOutlineFont(header:GetFontString())
        end
    end
end

---@param page NUIProfessionsOrdersPage?
local function SkinOrdersPage(S, page)
    if not page then return end

    local browse = page.BrowseFrame
    if browse then
        for _, key in ipairs({ 'PublicOrdersButton', 'GuildOrdersButton', 'NpcOrdersButton', 'PersonalOrdersButton' }) do
            S:HandleTab(browse[key], true)
        end

        S:HandleButton(browse.SearchButton)
        S:HandleButton(browse.FavoritesSearchButton, nil, nil, true)
        S:HandleNextPrevButton(browse.BackButton, 'left')

        local remaining = browse.OrdersRemainingDisplay
        if remaining then
            if remaining.Background then remaining.Background:SetAlpha(0) end
            S:CreatePanelBackdrop(remaining, nil, nil, true)
            S:HandleOutlineFont(remaining.OrdersRemaining)
        end

        SkinRecipeList(S, browse.RecipeList)

        local orders = browse.OrderList
        if orders then
            orders:NUIStripTextures('Keyed')
            --S:CreatePanelBackdrop(orders)
            S:HandleTrimScrollBar(orders.ScrollBar)

            -- The table is built when the orders land, so the columns outlive no single show.
            local function SkinHeaders() SkinListHeaders(S, orders.HeaderContainer) end

            SkinHeaders()
            if orders.ScrollBox then hooksecurefunc(orders.ScrollBox, 'Update', SkinHeaders) end
        end
    end

    SkinOrderView(S, page.OrderView)
end

Skinning:RegisterSkin('Blizzard_Professions', 'Professions', function(S)
    local ProfessionsFrame = _G.ProfessionsFrame
    if not ProfessionsFrame then return end

    S:HandlePortraitFrame(ProfessionsFrame)
    S:HandleAccentFont(ProfessionsFrame.TitleContainer and ProfessionsFrame.TitleContainer.TitleText)
    S:HandleMinMaxButton(ProfessionsFrame.MaximizeMinimize)
    S:HandleTabRow(ProfessionsFrame.TabSystem, ProfessionsFrame)

    SkinCraftingPage(S, ProfessionsFrame.CraftingPage --[[@as NUIProfessionsCraftingPage]])
    SkinSpecPage(S, ProfessionsFrame.SpecPage --[[@as NUIProfessionsSpecPage]])
    SkinOrdersPage(S, ProfessionsFrame.OrdersPage --[[@as NUIProfessionsOrdersPage]])

    local inspect = _G.InspectRecipeFrame
    if inspect then
        S:HandlePortraitFrame(inspect)
        S:HandleAccentFont(inspect.TitleContainer and inspect.TitleContainer.TitleText)
        SkinSchematicForm(S, inspect.SchematicForm --[[@as NUIProfessionsSchematicForm]], true)
    end

    hooksecurefunc('OpenProfessionsItemFlyout', SkinItemFlyout)
    hooksecurefunc(ProfessionsRecipeListCategoryMixin, 'SetCollapseState', SetCategoryCollapsed)
    hooksecurefunc(ProfessionsRecipeListCategoryMixin, 'Init', InitCategory)
end)

-- Professions book --

local BOOK_ART_ALPHA = 0.6
local COLUMN_GAP_TEXT = 2
local COLUMN_GAP_BAR = 4
local COLUMN_Y_NUDGE = 8

local BOOK_PANELS = {
    'PrimaryProfession1', 'PrimaryProfession2',
    'SecondaryProfession1', 'SecondaryProfession2', 'SecondaryProfession3',
}

---These strings carry an explicit <Color> from the XML - near black, or hardcoded gold - so they
---read on the parchment. A string's own colour beats its font object, so it has to be set here.
---@param S SkinningModule
---@param text FontString?
---@param accent boolean?
local function StyleBookText(S, text, accent)
    if not text then return end

    S:HandleOutlineFont(text)
    if accent then
        S:HandleAccentText(text)
    else
        text:SetTextColor(1, 1, 1)
    end
end

---The spell buttons are secure, so only their art is touched and nothing is re-anchored.
---@param S SkinningModule
---@param button NUIProfessionBookButton?
local function SkinBookSpellButton(S, button)
    if not button or button.NUISkinned then return end

    local icon = button.IconTexture
    if not icon then return end
    button.NUISkinned = true

    button:SetNormalTexture(NRSKNUI.ClearTexture)
    button:SetPushedTexture(NRSKNUI.ClearTexture)
    button:SetCheckedTexture(NRSKNUI.ClearTexture)
    button:SetHighlightTexture(NRSKNUI.ClearTexture)

    -- The name plate carries no parent key, so the icon is spared by identity instead.
    for _, region in ipairs({ button:GetRegions() }) do
        if region ~= icon and region:IsObjectType('Texture') then
            region:SetAlpha(0)
        end
    end

    S:HandleIcon(icon, true)
    S:AddHighlight(button, icon)

    StyleBookText(S, button.spellString, true)
    StyleBookText(S, button.subSpellString)

    hooksecurefunc(button, 'UpdateButton', function(self)
        self.spellString:NUIUpdateSkinColors()
    end)
end

---Shift the spell buttons by the nudge, from whatever Blizzard anchored them to.
---@param panel NUIProfessionBookPanel
local function NudgeSpellButtons(panel)
    if COLUMN_Y_NUDGE == 0 then return end

    local upper = panel.SpellButton2
    if not upper then return end

    if not upper.NUIBaseAnchor then
        local point, relativeTo, relativePoint, x, y = upper:GetPoint()
        if not point then return end
        upper.NUIBaseAnchor = {
            point = point,
            relativeTo = relativeTo or panel,
            relativePoint = relativePoint or point,
            x = x or 0,
            y = y or 0,
        }
    end

    local base = upper.NUIBaseAnchor
    NRSKNUI:RunWhenSafe(function()
        upper:NUISetPixelPoint(base.point, base.relativeTo, base.relativePoint, base.x, base.y + COLUMN_Y_NUDGE)
    end)
end

---Bottom edge of the lowest shown spell button, in screen coordinates.
---@param panel NUIProfessionBookPanel
---@return number? bottom
local function SpellButtonBottom(panel)
    local bottom
    for _, button in ipairs({ panel.SpellButton2, panel.SpellButton1 }) do
        if button and button:IsShown() then
            local edge = button:GetBottom()
            if edge and (not bottom or edge < bottom) then bottom = edge end
        end
    end
    return bottom
end

---@param panel NUIProfessionBookPanel
local function CentreBookColumn(panel)
    local name, bar, icon = panel.professionName, panel.statusBar, panel.icon
    if not (name and bar and icon) then return end

    local spec = panel.specialization
    if panel.rank then
        local hasSpec = spec and spec:GetText() and spec:GetText() ~= ''
        panel.rank:ClearAllPoints()
        panel.rank:NUISetPixelPoint('TOPLEFT', hasSpec and spec or name, 'BOTTOMLEFT', 0, -COLUMN_GAP_TEXT)
    end

    NudgeSpellButtons(panel)

    local top, bottom = name:GetTop(), bar:GetBottom()
    local panelTop, iconTop, iconBottom = panel:GetTop(), icon:GetTop(), icon:GetBottom()
    if not (top and bottom and panelTop and iconTop and iconBottom) then return end

    local x = select(4, name:GetPoint())
    if not x then return end

    local blockHeight = top - bottom
    local buttonBottom = SpellButtonBottom(panel)

    local blockTop = buttonBottom and (buttonBottom + blockHeight)
        or (((iconTop + iconBottom) / 2 + blockHeight / 2) + COLUMN_Y_NUDGE)

    name:NUISetPixelPoint('TOPLEFT', panel, 'TOPLEFT', x, blockTop - panelTop)
end

---@param S SkinningModule
---@param panel NUIProfessionBookPanel?
local function SkinBookPanel(S, panel)
    if not panel then return end

    StyleBookText(S, panel.professionName, true)
    StyleBookText(S, panel.missingHeader, true)
    StyleBookText(S, panel.specialization)
    StyleBookText(S, panel.missingText)
    StyleBookText(S, panel.rank)

    local icon = panel.icon
    if icon then
        -- The template's OnLoad greys the icon out and drops it to 0.6 for the etched-page look.
        icon:SetDesaturation(0)
        icon:SetAlpha(0.6)
        icon:SetBlendMode('BLEND')
    end

    if ProfessionsBookFrameTutorialButton then
        -- Hide help tip button
        ProfessionsBookFrameTutorialButton:NUIBanish()
    end

    if not panel.icon and panel.missingText and panel.missingHeader then
        panel.missingText:NUISetPixelPoint('LEFT', panel.missingHeader, 'RIGHT', 24, 0)
    end

    SkinBookSpellButton(S, panel.SpellButton1)
    SkinBookSpellButton(S, panel.SpellButton2)

    local bar = panel.statusBar
    if bar then
        S:HandleStatusBar(bar)
        -- Blizzard turns the rank red at the cap, so its colour is left alone.
        S:HandleOutlineFont(bar.rankText)

        if panel.icon then
            bar:NUISetPixelPoint('TOPLEFT', panel.rank, 'BOTTOMLEFT', 0, -COLUMN_GAP_BAR)
        elseif panel.rank then
            panel.rank:NUISetPixelPoint('BOTTOMLEFT', bar, 'TOPLEFT', 0, COLUMN_GAP_BAR)
        end

        if panel.UnlearnButton then
            panel.UnlearnButton:ClearAllPoints()
            panel.UnlearnButton:NUISetPixelPoint('LEFT', bar, 'RIGHT', 6, 1)
        end
    end
end

Skinning:RegisterSkin('Blizzard_ProfessionsBook', 'Professions', function(S)
    local frame = _G.ProfessionsBookFrame
    if not frame then return end

    for _, name in ipairs({ 'ProfessionsBookPage1', 'ProfessionsBookPage2' }) do
        local page = _G[name]
        if page then
            page.NUINoStrip = true
            page:SetAlpha(BOOK_ART_ALPHA)
        end
    end

    S:HandlePortraitFrame(frame)
    S:HandleAccentFont(frame.TitleContainer and frame.TitleContainer.TitleText)

    for _, name in ipairs(BOOK_PANELS) do
        SkinBookPanel(S, _G[name])
    end

    -- Runs per panel once its text is set, which is when the column's height is finally known.
    hooksecurefunc('FormatProfession', CentreBookColumn)
end)
