---@class NRSKNUI
local NRSKNUI = select(2, ...)
local BSKIN = NRSKNUI.BlizzSkin

local ipairs = ipairs

local function SkinTabSystem(S, tabSystem)
    if not tabSystem then return end
    if tabSystem.tabPool and tabSystem.tabPool.EnumerateActive then
        for tab in tabSystem.tabPool:EnumerateActive() do
            S:HandleTab(tab)
        end
    end
end

local function SkinSpellBook(S, book)
    if not book then return end


    if book.BookCornerFlipbook then book.BookCornerFlipbook:SetAlpha(0) end

    if book.SearchBox then S:HandleEditBox(book.SearchBox) end
    SkinTabSystem(S, book.CategoryTabSystem)
end

local function SkinTalents(S, talents)
    if not talents then return end

    if talents.BlackBG then talents.BlackBG:SetAlpha(0) end
    if talents.BottomBar then talents.BottomBar:SetAlpha(0) end

    if talents.SearchBox then S:HandleEditBox(talents.SearchBox) end
    if talents.ApplyButton then S:HandleButton(talents.ApplyButton) end
    -- UndoButton/ResetButton are IconButtonTemplate: stripping would blank their icons

    local dropdown = talents.LoadSystem and talents.LoadSystem.Dropdown
    if dropdown then S:HandleDropdownButton(dropdown) end


    -- Hero talents select frame.
    local heroTalents = _G.HeroTalentsSelectionDialog
    if heroTalents then
        heroTalents:NUIStripTextures('Keyed')
        S:CreatePanelBackdrop(heroTalents)
    end
end

local function SkinSpecContents(specFrame)
    for _, child in ipairs({ specFrame:GetChildren() }) do
        if child.ActivateButton then
            BSKIN:HandleButton(child.ActivateButton)
        end
    end
end

local function SkinSpec(S, spec)
    if not spec then return end

    SkinSpecContents(spec)
    spec:HookScript("OnShow", SkinSpecContents)
end

BSKIN:RegisterSkin("Blizzard_PlayerSpells", "PlayerSpells", function(S)
    if not PlayerSpellsFrame then return end

    S:HandlePortraitFrame(PlayerSpellsFrame)
    SkinTabSystem(S, PlayerSpellsFrame.TabSystem)

    SkinSpellBook(S, PlayerSpellsFrame.SpellBookFrame)
    SkinTalents(S, PlayerSpellsFrame.TalentsFrame)
    SkinSpec(S, PlayerSpellsFrame.SpecFrame)
end)
