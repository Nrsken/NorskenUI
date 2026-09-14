---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local _G = _G
local ipairs = ipairs
local Mixin = Mixin
local hooksecurefunc = hooksecurefunc

local ADDON_NAME = 'KeystoneLoot'

local CARD_ART_LAYERS = { 'BACKGROUND', 'BORDER' }
local ARROW_LEFT, ARROW_RIGHT = 'up', 'down'
local CAROUSEL_ARROW_SIZE = 14
local DROPDOWN_ARROW_SIZE = 14

local SkinnedButtonMixin = Skinning.ButtonMixin

---@class KSLDividerMixin
local DividerMixin = {}

function DividerMixin:NUIUpdateSkinColors()
    ---@cast self Texture
    local border = Skinning.db.General.BorderColor
    self:SetVertexColor(border[1], border[2], border[3], border[4])
end

---Acquire is the one point every pooled frame passes through, whichever Refresh path asked for it.
---@param pool table?
---@param skin fun(frame: any) Guards itself, the hook has no return value to narrow the rescan
local function HookPool(pool, skin)
    if not pool or pool.NUIHooked then return end
    pool.NUIHooked = true

    local function SkinActive()
        for frame in pool:EnumerateActive() do
            skin(frame)
        end
    end

    hooksecurefunc(pool, 'Acquire', SkinActive)
    SkinActive()
end

---Replace Blizzard's quickslot ring behind an icon with our own border.
---@param icon Texture
---@param iconBorder Texture?
local function SkinIcon(icon, iconBorder)
    if iconBorder then iconBorder:Hide() end
    Skinning:HandleIcon(icon, true, nil, true)
end

---@param button KSLLootIconButton
local function SkinLootIcon(button)
    if button.NUISkinned then return end
    button.NUISkinned = true

    local content = button.Content
    content.IconEmpty:Hide()
    SkinIcon(content.Icon, content.IconBorder)

    -- The badges sit at ARTWORK/4, under the border our backdrop draws at ARTWORK/7.
    for _, badge in ipairs({
        content.FavoriteIcon,
        content.OwnedIcon,
        content.VoidcoreIcon })
    do
        badge:SetDrawLayer('OVERLAY', 1)
    end

    Skinning:AddHighlight(button, content.Icon)
end

---@param button Button
---@param direction string ARROW_LEFT or ARROW_RIGHT
local function SkinCarouselButton(button, direction)
    if button.NUISkinned then return end
    button.NUISkinned = true

    button:NUIStripTextures('Alpha')
    Skinning:CreateArrowTexture(button, direction, CAROUSEL_ARROW_SIZE, CAROUSEL_ARROW_SIZE, nil, nil, nil, nil, nil, true)
end

---@param entry KSLEntryFrame
local function SkinEntryFrame(entry)
    if entry.NUISkinned then return end
    entry.NUISkinned = true

    local teleport = entry.TeleportButton
    SkinIcon(teleport.Icon, teleport.IconBorder)
    Skinning:AddHighlight(teleport, teleport.Icon)

    local divider = entry.Divider
    ---@cast divider Texture & KSLDividerMixin
    Mixin(divider, DividerMixin)
    divider:NUIUpdateSkinColors()
    Skinning:RegisterSkinned(divider)

    SkinCarouselButton(entry.BackButton, ARROW_LEFT)
    SkinCarouselButton(entry.NextButton, ARROW_RIGHT)

    Skinning:HookScrollBoxChildren(entry.IconScrollBox, SkinLootIcon)
end

---The tiled inset and the border frame pinned over it are two frames drawing one panel.
---@param frame KSLInsetOwner
local function SkinInset(frame)
    frame.Inset:NUIStripTextures('Keyed')
    frame.BorderFrame:NUIStripTextures('Keyed')
end

---@param block KSLRaidBlock
local function SkinRaidBlock(block)
    if block.NUISkinned then return end
    block.NUISkinned = true

    SkinInset(block)
    Skinning:HandleAccentText(block.TitleText)

    local divider = block.Divider
    ---@cast divider Texture & KSLDividerMixin
    Mixin(divider, DividerMixin)
    divider:NUIUpdateSkinColors()
    Skinning:RegisterSkinned(divider)

    HookPool(block.entryPool, SkinEntryFrame)
end

---Its arrow is the NormalTexture rather than an Arrow key, so HandleDropdownButton has no hold.
---@param dropdown KSLRaidDropdown
local function SkinRaidDropdown(dropdown)
    if dropdown.NUISkinned then return end
    dropdown.NUISkinned = true

    -- OnMouseDown nudges both by their points, so they have to stay live.
    dropdown.NormalTexture:SetAlpha(0)
    dropdown.HighlightTexture:SetAlpha(0)

    Skinning:CreateArrowTexture(dropdown, 'left', DROPDOWN_ARROW_SIZE, DROPDOWN_ARROW_SIZE, 'RIGHT', dropdown, 'RIGHT', 0, 0)

    ---@cast dropdown Button & SkinnedButtonMixin
    Mixin(dropdown, SkinnedButtonMixin)

    dropdown:HookScript('OnEnter', dropdown.NUIOnEnter)
    dropdown:HookScript('OnLeave', dropdown.NUIOnLeave)

    dropdown:RegisterCallback(dropdown.Event.OnMenuOpen, function(btn)
        btn:NUISetArrowDirection('down', true)
    end, dropdown)
    dropdown:RegisterCallback(dropdown.Event.OnMenuClose, function(btn)
        btn:NUISetArrowDirection('left', false)
    end, dropdown)

    Skinning:RegisterSkinned(dropdown)
    dropdown:NUIUpdateState()
end

---A DialogBorderTemplate column hanging off the side of the main window.
---@param panel KSLSidePanel
local function SkinSidePanel(panel)
    panel:NUIStripTextures('Keyed')
    Skinning:CreatePanelBackdrop(panel)

    local point, relativeTo, relativePoint = panel:GetPoint()
    panel:SetPoint(point, relativeTo, relativePoint, 0, 0)

    HookPool(panel.iconPool, SkinLootIcon)
end

---@param frame KSLPopupFrame
local function SkinPopupShell(frame)
    frame:NUIStripTextures('Keyed')
    Skinning:CreatePanelBackdrop(frame)
    Skinning:HandleCloseButton(frame.CloseButton, frame)
    Skinning:HandleAccentText(frame.Title)
end

---The looting item card art, shared by the drop rows and the mythic plus card.
---@param card KSLItemCard
local function SkinItemCard(card)
    card:NUIStripTextures('Layer', CARD_ART_LAYERS)
    Skinning:CreatePanelBackdrop(card)

    -- Both mixins call Show() on the stroke from OnEnter, so the alpha has to carry the suppression.
    card.HighlightTexture:SetAlpha(0)
    Skinning:AddHighlight(card)
end

---@param row KSLDropRow
local function SkinDropRow(row)
    if row.NUISkinned then return end
    row.NUISkinned = true

    SkinItemCard(row)

    local iconFrame = row.IconFrame
    SkinIcon(iconFrame.Icon, iconFrame.IconBorder)
    iconFrame.FavoriteIcon:SetDrawLayer('OVERLAY', 1)
end

---@param icon KSLReminderIcon
local function SkinReminderIcon(icon)
    if icon.NUISkinned then return end
    icon.NUISkinned = true

    SkinIcon(icon.Icon, icon.IconBorder)
    Skinning:AddHighlight(icon, icon.Icon)
end

---@param card KSLSpecCard
local function SkinSpecCard(card)
    if card.NUISkinned then return end
    card.NUISkinned = true

    -- Init re-atlases Bg to the spec thumbnail after every acquire, so only the border is lost.
    card:NUIStripTextures('Keyed')
    Skinning:CreatePanelBackdrop(card)

    Skinning:HandleAccentText(card.Title)
    Skinning:HandleButton(card.LootSpecButton)

    HookPool(card.iconPool, SkinReminderIcon)
end

---@param S SkinningModule
local function SkinMainFrame(S)
    local frame = _G.KeystoneLootFrame

    S:HandlePortraitFrame(frame)

    -- The panel template moved its title into a container and both spellings are still in the wild.
    S:HandleAccentText(frame.TitleText or (frame.TitleContainer and frame.TitleContainer.TitleText))

    S:HandleTabRow(frame.TabSystem, frame)

    for _, dropdown in ipairs({
        frame.ClassDropdown,
        frame.SlotDropdown,
        frame.ItemLevelDropdown })
    do
        S:HandleDropdownButton(dropdown)
    end

    local dungeons = frame.DungeonsFrame
    SkinInset(dungeons)
    HookPool(dungeons.entryPool, SkinEntryFrame)

    local raids = frame.RaidsFrame
    SkinRaidDropdown(raids.DropdownButton)
    HookPool(raids.blockPool, SkinRaidBlock)

    SkinSidePanel(frame.CatalystFrame)
    SkinSidePanel(frame.CustomItemFrame)
end

---@param S SkinningModule
local function SkinKeystoneLoot(S)
    SkinMainFrame(S)

    local reminder = _G.KeystoneLootReminderFrame
    SkinPopupShell(reminder)
    HookPool(reminder.specPool, SkinSpecCard)

    local drops = _G.KeystoneLootDropNotificationFrame
    SkinPopupShell(drops)
    HookPool(drops.rowPool, SkinDropRow)

    local mythicPlus = _G.KeystoneLootMythicPlusNotificationFrame
    SkinPopupShell(mythicPlus)
    SkinItemCard(mythicPlus.Card)
    SkinIcon(mythicPlus.Card.Icon, mythicPlus.Card.IconBorder)

    -- The addon ships its own fork of the menu lib, so Blizzard's manager never sees these.
    S:HandleMenus(_G.KSLMenu.GetManager(), _G.KSLMenuVariants)
end

Skinning:RegisterSkin(ADDON_NAME, 'KeystoneLoot', function(S)
    local API = _G.KeystoneLootAPI
    if not API then return end

    -- Tabs, dropdowns and side panels are built from PLAYER_ENTERING_WORLD, not ADDON_LOADED.
    API:RegisterCallback('READY', function()
        SkinKeystoneLoot(S)
    end, 'NorskenUI')
end)
