--[[
# ContextMenu

* A simple context menu that can be opened at the cursor with a list of entries. Each entry can be a clickable item, a submenu or a divider line.

Access the context menu through the `InstanceMixin` of the `LibKaji-1.0` library:
* ns.GUI = _G.LibStub('LibKaji-1.0'):New()  -- Core file
* local GUI = ns.GUI                        -- Usage files calls like this

# ContextMenu APIs

A! Opens a context menu at the cursor with the given entries.
API: GUI:ShowContextMenu(entries)
* `entries`      - A list of tables, each with the following fields:
  * `text`       - The text string to display for this entry.
  * `onClick`    - Optional. A function to call when this entry is clicked.
  * `submenu`    - Optional. A list of entries opened beside this one on hover; `onClick` is ignored.
  * `disabled`   - Optional. If true, the entry will be shown as disabled and not clickable.
  * `divider`    - Optional. If true, this entry will be shown as a divider line instead of a clickable entry.

A! Closes the open context menu, if any.
API: GUI:CloseContextMenu()

## Example

GUI:ShowContextMenu({
    { text = 'Rename', onClick = function() Rename(key) end },
    { text = 'Copy...', submenu = {
        { text = 'Everything', onClick = function() Copy(key, 'all') end },
    } },
    { divider = true },
    { text = 'Delete', onClick = function() Delete(key) end },
})

--]]

---@class LibKaji-1.0
local lib = _G.LibStub and _G.LibStub('LibKaji-1.0', true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local RunNextFrame = RunNextFrame
local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local ipairs = ipairs
local max, min = math.max, math.min
local pi = math.pi

local UIParent = UIParent

local ITEM_HEIGHT = 24
local DIVIDER_HEIGHT = 1
local MIN_WIDTH = 180
local MAX_WIDTH = 350
local TEXT_INSET = 4
local DISABLED_ALPHA = 0.4
local HOVER_BAR_WIDTH = 2
local ARROW_SIZE = 12
local CHILD_LEVEL_STEP = 10

local BACKDROP = { bgFile = 'Interface\\Buttons\\WHITE8X8', edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 }

---One menu panel; submenus are child panels parented to it, so hiding the root hides them all.
---@param gui table
---@param parent Frame?
---@return table panel
local function NewPanel(gui, parent)
    local theme = gui.theme

    local frame = CreateFrame('Frame', nil, parent or UIParent, 'BackdropTemplate')
    frame:SetBackdrop(BACKDROP)
    frame:SetFrameStrata('TOOLTIP')
    frame:SetFrameLevel(parent and parent:GetFrameLevel() + CHILD_LEVEL_STEP or 100)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true) -- Without this the padding and divider rows are click-through onto whatever sits behind the menu.
    frame:Hide()

    local panel = { frame = frame, items = {} }
    local restylePopup = lib.StylePopup(frame, gui)

    -- Rows read white; only the hovered one takes the accent.
    local function SetHovered(item, hovered)
        local c = hovered and theme.accent or theme.textPrimary
        item.text:SetTextColor(c[1], c[2], c[3], item.disabled and DISABLED_ALPHA or 1)
        item.arrow:SetVertexColor(c[1], c[2], c[3], item.disabled and DISABLED_ALPHA or 1)
        item.hover:SetShown(hovered)
        item.bar:SetShown(hovered)
    end

    frame:SetScript('OnHide', function(self)
        self:UnregisterEvent('GLOBAL_MOUSE_DOWN')
        panel:CloseChild()
    end)

    ---Restyles chrome so an open menu follows a live theme change like every other widget.
    function panel:Restyle()
        frame:SetBackdropColor(theme.bgLight[1], theme.bgLight[2], theme.bgLight[3], theme.bgLight[4])
        restylePopup()
        for _, item in ipairs(self.items) do
            if item.divider then
                item.tex:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
            else
                SetHovered(item, self.child ~= nil and self.child.owner == item)
                local a = theme.accent
                item.hover:SetGradient('HORIZONTAL', CreateColor(a[1], a[2], a[3], theme.selectionGlowAlpha), CreateColor(a[1], a[2], a[3], 0))
                item.bar:SetColorTexture(a[1], a[2], a[3], 1)
                item.button:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0)
                item.button:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], theme.bgMedium[4])
            end
        end
    end

    ---Acquires (or builds) the frame for row `index`, as a divider or a clickable entry.
    ---@param index number
    ---@param divider boolean
    ---@return table item
    function panel:Acquire(index, divider)
        local item = self.items[index]
        if not item then
            item = {}

            item.tex = frame:CreateTexture(nil, 'ARTWORK')
            pixel.SetPixelHeight(item.tex, theme.borderSize)

            item.button = CreateFrame('Button', nil, frame, 'BackdropTemplate')
            item.button:SetBackdrop(BACKDROP)
            pixel.SetPixelHeight(item.button, ITEM_HEIGHT)
            item.button:SetFrameLevel(frame:GetFrameLevel() + 1)

            item.hover = item.button:CreateTexture(nil, 'BACKGROUND', nil, 1)
            item.hover:SetAllPoints()
            item.hover:SetTexture('Interface\\Buttons\\WHITE8X8')
            item.hover:Hide()
            item.bar = item.button:CreateTexture(nil, 'ARTWORK')
            pixel.SetPixelWidth(item.bar, HOVER_BAR_WIDTH)
            pixel.SetPixelPoint(item.bar, 'TOPLEFT', item.button, 'TOPLEFT', 0, 0)
            pixel.SetPixelPoint(item.bar, 'BOTTOMLEFT', item.button, 'BOTTOMLEFT', 0, 0)
            item.bar:Hide()

            item.arrow = item.button:CreateTexture(nil, 'ARTWORK')
            pixel.SetPixelSize(item.arrow, ARROW_SIZE, ARROW_SIZE)
            pixel.SetPixelPoint(item.arrow, 'RIGHT', item.button, 'RIGHT', -TEXT_INSET, 0)
            item.arrow:SetTexture(theme.stepperTexture)
            item.arrow:SetRotation(pi / 2) -- the texture points down at rotation 0
            pixel.SetPixelSnap(item.arrow)

            item.text = item.button:CreateFontString(nil, 'OVERLAY')
            item.text:SetJustifyH('LEFT')
            item.text:SetWordWrap(false)
            pixel.SetPixelPoint(item.text, 'LEFT', item.button, 'LEFT', TEXT_INSET, 0)

            item.button:SetScript('OnEnter', function(self)
                if item.submenu and self:IsEnabled() then
                    panel:OpenChild(item)
                else
                    panel:CloseChild()
                end
                if self:IsEnabled() then SetHovered(item, true) end
            end)
            item.button:SetScript('OnLeave', function()
                if panel.child and panel.child.owner == item then return end -- stays lit while its submenu is open
                SetHovered(item, false)
            end)

            self.items[index] = item
        end

        item.divider = divider
        item.tex:SetShown(divider)
        item.button:SetShown(not divider)
        item.hover:Hide()
        item.bar:Hide()
        return item
    end

    ---Lays the entries out and sizes the panel; the caller places it.
    ---@param entries table[]
    function panel:Fill(entries)
        self:CloseChild()
        local pad = 1
        local width, y = MIN_WIDTH, pad

        for index, entry in ipairs(entries) do
            local item = self:Acquire(index, entry.divider == true)

            if entry.divider then
                item.tex:ClearAllPoints()
                pixel.SetPixelPoint(item.tex, 'TOPLEFT', frame, 'TOPLEFT', pad, -(y + (DIVIDER_HEIGHT - theme.borderSize) / 2))
                pixel.SetPixelPoint(item.tex, 'TOPRIGHT', frame, 'TOPRIGHT', -pad, -(y + (DIVIDER_HEIGHT - theme.borderSize) / 2))
                y = y + DIVIDER_HEIGHT
            else
                gui:ApplyFont(item.text, 'normal')
                item.text:SetText(entry.text or '')
                item.button:SetEnabled(not entry.disabled)

                -- Restyle repaints the label below, and SetTextColor's alpha overrides SetAlpha on a
                -- FontString, so the dim has to ride the color rather than sit beside it.
                item.disabled = entry.disabled == true
                item.submenu = entry.submenu
                item.arrow:SetShown(entry.submenu ~= nil)
                local rightInset = TEXT_INSET + (entry.submenu and ARROW_SIZE + TEXT_INSET or 0)
                pixel.SetPixelPoint(item.text, 'RIGHT', item.button, 'RIGHT', -rightInset, 0)

                local onClick = entry.onClick
                item.button:SetScript('OnClick', function()
                    if item.submenu then
                        panel:OpenChild(item)
                        return
                    end
                    gui:CloseContextMenu()
                    if onClick then safecall(onClick) end
                end)

                item.button:ClearAllPoints()
                pixel.SetPixelPoint(item.button, 'TOPLEFT', frame, 'TOPLEFT', 1, -y)
                pixel.SetPixelPoint(item.button, 'TOPRIGHT', frame, 'TOPRIGHT', -1, -y)

                width = max(width, item.text:GetStringWidth() + TEXT_INSET + rightInset)
                y = y + ITEM_HEIGHT
            end
        end

        -- Hide any rows left over from a longer previous menu.
        for index = #entries + 1, #self.items do
            self.items[index].tex:Hide()
            self.items[index].button:Hide()
        end

        self:Restyle()
        pixel.SetPixelSize(frame, min(width, MAX_WIDTH), y + pad)
    end

    ---Opens a row's submenu beside it, on the left when the right side has no room.
    ---@param item table
    function panel:OpenChild(item)
        local child = self.child
        if child and child.owner == item and child.frame:IsShown() then return end
        self:CloseChild()

        child = child or NewPanel(gui, frame)
        self.child = child
        child:Fill(item.submenu)
        child.owner = item

        local childFrame = child.frame
        childFrame:ClearAllPoints()
        local right = item.button:GetRight()
        if right and right + childFrame:GetWidth() > UIParent:GetRight() then
            pixel.SetPixelPoint(childFrame, 'TOPRIGHT', item.button, 'TOPLEFT', -1, 1)
        else
            pixel.SetPixelPoint(childFrame, 'TOPLEFT', item.button, 'TOPRIGHT', 1, 1)
        end
        childFrame:Show()
    end

    function panel:CloseChild()
        local child = self.child
        if not child then return end
        local owner = child.owner
        child.owner = nil
        child.frame:Hide()
        if owner then SetHovered(owner, false) end
    end

    ---@return boolean
    function panel:ContainsMouse()
        if frame:IsMouseOver() then return true end
        local child = self.child
        return child ~= nil and child.frame:IsShown() and child:ContainsMouse()
    end

    gui:OnThemeChanged(function() panel:Restyle() end)
    return panel
end

---Lazily builds this instance's single root menu.
---@param gui table
---@return table menu
local function EnsureMenu(gui)
    if gui._contextMenu then return gui._contextMenu end

    local menu = NewPanel(gui)
    gui._contextMenu = menu

    -- Match Blizzards behavior of closing the menu when clicking outside of it.
    local frame = menu.frame
    frame:SetScript('OnShow', function(self) self:RegisterEvent('GLOBAL_MOUSE_DOWN') end)
    frame:SetScript('OnEvent', function(_, _, button)
        if button ~= 'LeftButton' and button ~= 'RightButton' then return end
        -- A consumer that opens on mouse-down would otherwise dismiss on that same press.
        if not menu.armed then return end
        if menu:ContainsMouse() then return end
        gui:CloseContextMenu()
    end)

    return menu
end

---Opens a context menu at the cursor. Passing no entries (or an empty list) just closes any open menu.
---@param entries table[] { text: string, onClick: fun()?, submenu: table[]?, disabled: boolean?, divider: boolean? }
function InstanceMixin:ShowContextMenu(entries)
    local gui = self
    local menu = EnsureMenu(gui)

    gui:CloseContextMenu()
    if not entries or not entries[1] then return end

    menu:Fill(entries)

    -- Cursor position is in screen pixels, so it has to be taken back into UIParent's scale.
    local frame = menu.frame
    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    frame:ClearAllPoints()
    frame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', cursorX / scale, cursorY / scale)

    menu.armed = false
    frame:Show()
    RunNextFrame(function() menu.armed = true end)
end

---Closes the open context menu, if any.
function InstanceMixin:CloseContextMenu()
    local menu = self._contextMenu
    if not menu then return end
    menu.armed = false
    menu.frame:Hide()
end
