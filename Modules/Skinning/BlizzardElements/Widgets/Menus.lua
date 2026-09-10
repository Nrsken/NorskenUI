---@class NRSKNUI
local NRSKNUI = select(2, ...)
---@class SkinningModule
local Skinning = NRSKNUI:GetModule('Skinning')

local math_rad = math.rad
local math_max = math.max
local setmetatable = setmetatable
local hooksecurefunc = hooksecurefunc

local ARROW_TEXTURE = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\collapse.tga'

-- Closing a menu releases every attachment with a SetToDefaults(), so styling is reapplied per open.
local menuBackdrops = setmetatable({}, { __mode = 'k' })
local skinnedMenuDescriptions = setmetatable({}, { __mode = 'k' })

---@param frame MenuElement
local function UpdateMenuHighlight(frame)
    local highlight = frame.highlight
    if not highlight then return end

    local color = Skinning.db.General.HighlightColor
    highlight:SetColorTexture(color[1], color[2], color[3], color[4])
end

---@param frame MenuElement
local function UpdateMenuArrow(frame)
    local arrow = frame.arrow
    if not arrow then return end

    arrow:SetTexture(ARROW_TEXTURE)
    arrow:SetRotation(math_rad(90))
    arrow:SetVertexColor(Skinning:GetAccentColor())
    arrow:NUISetPixelSize(12, 12)
end

---@param frame MenuElement
local function UpdateMenuDivider(frame)
    local attachments = frame.attachments
    local divider = attachments and attachments[#attachments] -- frame.divider is set after this hook
    if not divider then return end

    local border = Skinning.db.General.BorderColor
    divider:SetVertexColor(border[1], border[2], border[3], border[4]) -- tinted, its soft edges carry the row spacing
end

---@param menu MenuFrame
local function SkinMenuFrame(menu)
    if not menu then return end

    menu:NUIStripTextures()

    local backdrop = menuBackdrops[menu]
    if backdrop then
        menu.NUIBackdrop = backdrop
    else
        backdrop = Skinning:CreatePanelBackdrop(menu)
        if not backdrop then return end
        menuBackdrops[menu] = backdrop

        Skinning:HandleTrimScrollBar(menu.ScrollBar) -- built once in OnLoad, outlives the pooling
    end

    backdrop:SetFrameLevel(math_max(0, menu:GetFrameLevel() - 1)) -- levels are reassigned per open

    -- MenuStyle1 pads the bottom to 15 against a decorated atlas, a flat backdrop just shows the gap.
    local inset = menu:GetInset()
    backdrop:ClearAllPoints()
    backdrop:SetPoint('TOPLEFT', menu)
    backdrop:NUISetPixelPoint('BOTTOMRIGHT', menu, 'BOTTOMRIGHT', 0, inset.bottom - inset.top)
end

---@param manager table Menu manager proxy
---@param _ownerRegion Frame
---@param menuDescription table Root menu description proxy
local function SkinOpenMenu(manager, _ownerRegion, menuDescription)
    local menu = manager:GetOpenMenu()
    if not menu then return end

    SkinMenuFrame(menu)

    -- Submenus arrive later, and the callback list has no dedup of its own.
    if not skinnedMenuDescriptions[menuDescription] then
        skinnedMenuDescriptions[menuDescription] = true
        menuDescription:AddMenuAcquiredCallback(SkinMenuFrame)
    end
end

---Skin Blizzard's context and dropdown menus, hooks installed once.
function Skinning:HandleMenus()
    if self.NUIMenusSkinned then return end

    local manager = Menu and Menu.GetManager and Menu.GetManager() -- Blizzard_Menu may load after us
    if not (manager and MenuVariants) then return end
    self.NUIMenusSkinned = true

    hooksecurefunc(manager, 'OpenMenu', SkinOpenMenu)
    hooksecurefunc(manager, 'OpenContextMenu', SkinOpenMenu)
    hooksecurefunc(MenuVariants, 'CreateHighlight', UpdateMenuHighlight)
    hooksecurefunc(MenuVariants, 'CreateSubmenuArrow', UpdateMenuArrow)
    hooksecurefunc(MenuVariants, 'CreateDivider', UpdateMenuDivider)
end

Skinning:RegisterSkin(nil, 'Menus', function(S) S:HandleMenus() end)
