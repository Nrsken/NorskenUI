---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local ipairs = ipairs
local unpack = unpack
local hooksecurefunc = hooksecurefunc

local GetSpellTexture = C_Spell and C_Spell.GetSpellTexture

local SPELL_BOOK_ART = {
    'BookBGLeft',
    'BookBGRight',
    'BookBGHalved',
}

---@param spellButton Button
local function SetSpellBookTextColoring(spellButton)
    -- Spellname coloring
    ---@type FontString|nil
    local nameText = spellButton.TextContainer and spellButton.TextContainer.Name
    if nameText then
        nameText:SetTextColor(1, 1, 1)

        local font, size = nameText:GetFont()
        nameText:SetFont(font, size, 'OUTLINE')
    end

    -- Subname coloring, "Passive" or "Rank N" text
    ---@type FontString|nil
    local subNameText = spellButton.TextContainer and spellButton.TextContainer.SubName
    if subNameText then
        subNameText:SetTextColor(0.5, 0.5, 0.5, 1)

        local font, size = subNameText:GetFont()
        subNameText:SetFont(font, size, 'OUTLINE')
    end

    -- Class/Spec title coloring
    -- View 1 is the collapsed spellbook view, View 2 is the expanded spellbook view.
    local view = _G.PlayerSpellsFrame.SpellBookFrame.PagedSpellsFrame
    for i = 1, 2 do
        view = _G.PlayerSpellsFrame.SpellBookFrame.PagedSpellsFrame['View' .. i]
        for _, child in ipairs({ view:GetChildren() }) do
            if child.Text and child.Text.SetTextColor then
                child.Text:SetTextColor(unpack(NRSKNUI:GetPlayerClassColor()))

                local fontFace, titleSize = nameText:GetFont()
                child.Text:SetFont(fontFace, titleSize + 10, 'OUTLINE')
            end
        end
    end
end

-- Spellbook tab
local function SkinSpellBook(S)
    local SpellBookFrame = _G.PlayerSpellsFrame.SpellBookFrame
    if not SpellBookFrame then return end

    -- Hide corner flipbook effect when hovering next/prev buttons.
    if SpellBookFrame.BookCornerFlipbook then
        SpellBookFrame.BookCornerFlipbook:SetAlpha(0)
    end

    -- Handle the search abilites, keywords input box.
    if SpellBookFrame.SearchBox then
        S:HandleEditBox(SpellBookFrame.SearchBox)
    end

    local assistedButton = SpellBookFrame.AssistedCombatRotationSpellFrame.Button
    if assistedButton then
        Skinning:HandleButton(assistedButton, nil, nil, true)
    end

    S:HandleSearchPreview(SpellBookFrame.SearchPreviewContainer, SpellBookFrame.SearchBox)

    -- The category row lives at the top of the book, so it keeps Blizzard's position.
    S:HandleTabRow(SpellBookFrame.CategoryTabSystem, nil, true)

    -- Hide the top bar art of the spell book frame.
    if SpellBookFrame.TopBar then
        SpellBookFrame.TopBar:Hide()
    end

    -- Handle the min/max button for the spell book frame.
    local MaximizeMinimizeButton = _G.PlayerSpellsFrame.MaximizeMinimizeButton
    S:HandleMinMaxButton(MaximizeMinimizeButton)

    -- Hide help tip button
    SpellBookFrame.HelpPlateButton:NUIBanish()

    -- Adjust spell book art transparency
    for _, textures in ipairs(SPELL_BOOK_ART) do
        local texture = SpellBookFrame[textures]
        texture:SetAlpha(0.6)
    end

    local PagedSpellsFrame = SpellBookFrame.PagedSpellsFrame
    if PagedSpellsFrame then
        -- Style the paging controls
        local PagingControls = PagedSpellsFrame.PagingControls
        if PagingControls then
            PagingControls.PageText:SetTextColor(1, 1, 1)

            local font, size = PagingControls.PageText:GetFont()
            PagingControls.PageText:SetFont(font, size, 'OUTLINE')

            S:HandleNextPrevButton(PagingControls.PrevPageButton, 'up')
            S:HandleNextPrevButton(PagingControls.NextPageButton, 'down')
        end
    end

    -- Need to hook this, otherwise spellname coloring is not applied correctly.
    hooksecurefunc(SpellBookItemMixin, 'UpdateTextContainer', SetSpellBookTextColoring)
end

-- Talents tab
local function SkinTalents(S, talents)
    if not talents then return end

    if talents.BlackBG then talents.BlackBG:SetAlpha(0) end
    if talents.BottomBar then talents.BottomBar:SetAlpha(0) end

    if talents.SearchBox then S:HandleEditBox(talents.SearchBox) end
    if talents.ApplyButton then S:HandleButton(talents.ApplyButton) end

    local dropdown = talents.LoadSystem and talents.LoadSystem.Dropdown
    if dropdown then S:HandleDropdownButton(dropdown) end

    S:HandleSearchPreview(talents.SearchPreviewContainer, talents.SearchBox)
end

-- The spec options are pooled, so they only exist once the dialog has been built for a show.
local function SkinHeroSpecOptions()
    local container = _G.HeroTalentsSelectionDialog.SpecOptionsContainer
    if not container then return end

    for _, option in ipairs({ container:GetChildren() }) do
        ---@cast option HeroSpecOption
        Skinning:HandleOutlineFont(option.SpecName)
        Skinning:HandleOutlineFont(option.Description)

        Skinning:HandleButton(option.ActivateButton)
        Skinning:HandleButton(option.ApplyChangesButton)
    end
end

-- Hero talents select frame.
local function SkinHeroTalents(S)
    local heroTalents = _G.HeroTalentsSelectionDialog
    if not heroTalents then return end

    heroTalents:NUIStripTextures('Keyed')
    S:CreatePanelBackdrop(heroTalents)

    local dialogText = _G.HeroTalentsSelectionDialogText
    S:HandleCloseButton(heroTalents.CloseButton, heroTalents)
    S:HandleAccentText(dialogText)

    SkinHeroSpecOptions()
    heroTalents:HookScript('OnShow', SkinHeroSpecOptions)
end

local function SkinSpecContents(specFrame)
    local pool = specFrame.SpecContentFramePool
    if not pool then return end

    for content in pool:EnumerateActive() do
        ---@cast content SpecContentFrame
        Skinning:HandleOutlineFont(content.SampleAbilityText)
        Skinning:HandleButton(content.ActivateButton)

        if content.SpellButtonPool then
            for button in content.SpellButtonPool:EnumerateActive() do
                ---@cast button SpecSpellButton
                if button.Ring then button.Ring:Hide() end

                local icon = button.Icon
                if icon then
                    for i = icon:GetNumMaskTextures(), 1, -1 do
                        icon:RemoveMaskTexture(icon:GetMaskTexture(i))
                    end

                    if button.spellID then
                        local texture = GetSpellTexture(button.spellID)
                        if texture then icon:SetTexture(texture) end
                    end

                    Skinning:HandleIcon(icon, true)
                end
            end
        end
    end
end

local function SkinSpec(S, spec)
    if not spec then return end

    SkinSpecContents(spec)
    hooksecurefunc(spec, 'UpdateSpecFrame', SkinSpecContents)
end

Skinning:RegisterSkin('Blizzard_PlayerSpells', 'PlayerSpells', function(S)
    local PlayerSpellsFrame = _G.PlayerSpellsFrame
    if not PlayerSpellsFrame then return end

    S:HandlePortraitFrame(PlayerSpellsFrame)
    S:HandleAccentFont(PlayerSpellsFrame.TitleContainer and PlayerSpellsFrame.TitleContainer.TitleText)
    S:HandleTabRow(PlayerSpellsFrame.TabSystem, PlayerSpellsFrame)

    SkinSpellBook(S)
    SkinTalents(S, PlayerSpellsFrame.TalentsFrame)
    SkinHeroTalents(S)
    SkinSpec(S, PlayerSpellsFrame.SpecFrame)
end)
