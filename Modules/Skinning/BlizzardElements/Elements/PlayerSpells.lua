---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local ipairs = ipairs
local unpack = unpack
local hooksecurefunc = hooksecurefunc

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

    -- Hero talents select frame.
    local heroTalents = _G.HeroTalentsSelectionDialog
    if heroTalents then
        heroTalents:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(heroTalents)
    end
end

-- Specialization tab
local function SkinSpecContents(specFrame)
    for _, child in ipairs({ specFrame:GetChildren() }) do
        if child.ActivateButton then
            Skinning:HandleButton(child.ActivateButton)
        end
    end
end

local function SkinSpec(S, spec)
    if not spec then return end

    SkinSpecContents(spec)
    spec:HookScript('OnShow', SkinSpecContents)
end

Skinning:RegisterSkin('Blizzard_PlayerSpells', 'PlayerSpells', function(S)
    local PlayerSpellsFrame = _G.PlayerSpellsFrame
    if not PlayerSpellsFrame then return end

    S:HandlePortraitFrame(PlayerSpellsFrame)
    S:HandleTabRow(PlayerSpellsFrame.TabSystem, PlayerSpellsFrame)

    SkinSpellBook(S)
    SkinTalents(S, PlayerSpellsFrame.TalentsFrame)
    SkinSpec(S, PlayerSpellsFrame.SpecFrame)
end)
