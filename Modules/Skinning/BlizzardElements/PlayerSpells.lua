---@class NRSKNUI
local NRSKNUI = select(2, ...)

local BSKIN = NRSKNUI.BlizzSkin

local ipairs = ipairs

--[[
Taint rules for this file:
Spellbook buttons feed secure cast/pickup paths and the talent tree is the
canonical addon-taint source ("can't change talents in combat"). Hard rules:
- Talent node buttons, edge/connector pools, selection frames, the commit
  flow and PvP talent slots are never touched — static frame art only.
- Spellbook item buttons keep their OnClick/OnDrag and spell data untouched.
- Textures, alpha and our own backdrop children only; hooks stay visual-only.
]]

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

    NRSKNUI:HideTextures(book)
    NRSKNUI:HideTextures(book, 'Named')
    if book.BookCornerFlipbook then book.BookCornerFlipbook:SetAlpha(0) end

    if book.SearchBox then S:HandleEditBox(book.SearchBox) end
    SkinTabSystem(S, book.CategoryTabSystem)

    local paged = book.PagedSpellsFrame
    if paged then
        local controls = paged.PagingControls
        if controls then
            if controls.BackwardButton then S:HandleNextPrevButton(controls.BackwardButton) end
            if controls.ForwardButton then S:HandleNextPrevButton(controls.ForwardButton) end
        end
        for _, view in ipairs(paged.ViewFrames or {}) do
            NRSKNUI:HideTextures(view)
        end
    end
end

local function SkinTalents(S, talents)
    if not talents then return end

    NRSKNUI:HideTextures(talents)
    if talents.BlackBG then talents.BlackBG:SetAlpha(0) end
    if talents.BottomBar then talents.BottomBar:SetAlpha(0) end

    if talents.SearchBox then S:HandleEditBox(talents.SearchBox) end
    if talents.ApplyButton then S:HandleButton(talents.ApplyButton) end
    -- UndoButton/ResetButton are IconButtonTemplate: stripping would blank their icons

    local dropdown = talents.LoadSystem and talents.LoadSystem.Dropdown
    if dropdown then S:HandleDropdownButton(dropdown) end

    if talents.HeroTalentsContainer then
        NRSKNUI:HideTextures(talents.HeroTalentsContainer)
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

    NRSKNUI:HideTextures(spec)
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
