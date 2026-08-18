---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local ipairs = ipairs

local function SkinSpellBook(S, book)
    if not book then return end

    if book.BookCornerFlipbook then book.BookCornerFlipbook:SetAlpha(0) end
    if book.SearchBox then S:HandleEditBox(book.SearchBox) end

    -- The category row lives at the top of the book, so it keeps Blizzard's position.
    S:HandleTabRow(book.CategoryTabSystem)
end

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
    spec:HookScript("OnShow", SkinSpecContents)
end

Skinning:RegisterSkin("Blizzard_PlayerSpells", "PlayerSpells", function(S)
    if not PlayerSpellsFrame then return end

    S:HandlePortraitFrame(PlayerSpellsFrame)
    S:HandleTabRow(PlayerSpellsFrame.TabSystem, PlayerSpellsFrame)

    SkinSpellBook(S, PlayerSpellsFrame.SpellBookFrame)
    SkinTalents(S, PlayerSpellsFrame.TalentsFrame)
    SkinSpec(S, PlayerSpellsFrame.SpecFrame)
end)
