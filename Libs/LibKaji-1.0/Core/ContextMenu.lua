--[[
# ContextMenu

* A simple context menu that can be opened at the cursor with a list of entries. Each entry can be a clickable item or a divider line.

Access the context menu through the `InstanceMixin` of the `LibKaji-1.0` library:
* ns.GUI = _G.LibStub('LibKaji-1.0'):New()  -- Core file
* local GUI = ns.GUI                        -- Usage files calls like this

# ContextMenu APIs

A! Opens a context menu at the cursor with the given entries.
API: GUI:ShowContextMenu(entries)
* `entries`      - A list of tables, each with the following fields:
  * `text`       - The text string to display for this entry.
  * `onClick`    - Optional. A function to call when this entry is clicked.
  * `disabled`   - Optional. If true, the entry will be shown as disabled and not clickable.
  * `divider`    - Optional. If true, this entry will be shown as a divider line instead of a clickable entry.

A! Closes the open context menu, if any.
API: GUI:CloseContextMenu()

## Example

GUI:ShowContextMenu({
    { text = 'Rename', onClick = function() Rename(key) end },
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

local C_Timer = C_Timer
local UIParent = UIParent

local ITEM_HEIGHT = 24
local DIVIDER_HEIGHT = 1
local MIN_WIDTH = 180
local MAX_WIDTH = 350
local TEXT_INSET = 4

local BACKDROP = { bgFile = 'Interface\\Buttons\\WHITE8X8', edgeFile = 'Interface\\Buttons\\WHITE8X8', edgeSize = 1 }

---Lazily builds this instance's single menu frame.
---@param gui table
---@return table menu
local function EnsureMenu(gui)
    if gui._contextMenu then return gui._contextMenu end
    local theme = gui.theme

    local frame = CreateFrame('Frame', nil, UIParent, 'BackdropTemplate')
    frame:SetBackdrop(BACKDROP)
    frame:SetFrameStrata('TOOLTIP')
    frame:SetFrameLevel(100)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true) -- Without this the padding and divider rows are click-through onto whatever sits behind the menu.
    frame:Hide()

    local menu = { frame = frame, items = {} }
    gui._contextMenu = menu

    -- Match Blizzards behavior of closing the menu when clicking outside of it.
    frame:SetScript('OnShow', function(self) self:RegisterEvent('GLOBAL_MOUSE_DOWN') end)
    frame:SetScript('OnHide', function(self) self:UnregisterEvent('GLOBAL_MOUSE_DOWN') end)
    frame:SetScript('OnEvent', function(self, _, button)
        if button ~= 'LeftButton' and button ~= 'RightButton' then return end
        -- A consumer that opens on mouse-down would otherwise dismiss on that same press.
        if not menu.armed then return end
        if self:IsMouseOver() then return end
        gui:CloseContextMenu()
    end)

    ---Restyles chrome so an open menu follows a live theme change like every other widget.
    function menu:Restyle()
        frame:SetBackdropColor(theme.bgLight[1], theme.bgLight[2], theme.bgLight[3], theme.bgLight[4])
        frame:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        for _, item in ipairs(self.items) do
            if item.divider then
                item.tex:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
            else
                item.text:SetTextColor(theme.accent[1], theme.accent[2], theme.accent[3], theme.accent[4])
                item.hover:SetColorTexture(theme.accentHover[1], theme.accentHover[2], theme.accentHover[3], theme.accentHover[4])
                item.button:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 0)
                item.button:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], theme.bgMedium[4])
            end
        end
    end

    ---Acquires (or builds) the frame for row `index`, as a divider or a clickable entry.
    ---@param index number
    ---@param divider boolean
    ---@return table item
    function menu:Acquire(index, divider)
        local item = self.items[index]
        if not item then
            item = {}

            item.tex = frame:CreateTexture(nil, 'ARTWORK')
            pixel.SetPixelHeight(item.tex, theme.borderSize)

            item.button = CreateFrame('Button', nil, frame, 'BackdropTemplate')
            item.button:SetBackdrop(BACKDROP)
            pixel.SetPixelHeight(item.button, ITEM_HEIGHT)
            item.button:SetFrameLevel(frame:GetFrameLevel() + 1)

            item.hover = item.button:CreateTexture(nil, 'OVERLAY')
            item.hover:SetAllPoints()
            item.hover:Hide()

            item.text = item.button:CreateFontString(nil, 'OVERLAY')
            item.text:SetJustifyH('LEFT')
            item.text:SetWordWrap(false)
            pixel.SetPixelPoint(item.text, 'LEFT', item.button, 'LEFT', TEXT_INSET, 0)
            pixel.SetPixelPoint(item.text, 'RIGHT', item.button, 'RIGHT', -TEXT_INSET, 0)

            item.button:SetScript('OnEnter', function(self) if self:IsEnabled() then item.hover:Show() end end)
            item.button:SetScript('OnLeave', function() item.hover:Hide() end)

            self.items[index] = item
        end

        item.divider = divider
        item.tex:SetShown(divider)
        item.button:SetShown(not divider)
        item.hover:Hide()
        return item
    end

    gui:OnThemeChanged(function() menu:Restyle() end)
    return menu
end

---Opens a context menu at the cursor. Passing no entries (or an empty list) just closes any open menu.
---@param entries table[] { text: string, onClick: fun()?, disabled: boolean?, divider: boolean? }
function InstanceMixin:ShowContextMenu(entries)
    local gui = self
    local menu = EnsureMenu(gui)
    local theme = gui.theme
    local pad = 1

    gui:CloseContextMenu()
    if not entries or not entries[1] then return end

    local frame = menu.frame
    local width, y = MIN_WIDTH, pad

    for index, entry in ipairs(entries) do
        local item = menu:Acquire(index, entry.divider == true)

        if entry.divider then
            item.tex:ClearAllPoints()
            pixel.SetPixelPoint(item.tex, 'TOPLEFT', frame, 'TOPLEFT', pad, -(y + (DIVIDER_HEIGHT - theme.borderSize) / 2))
            pixel.SetPixelPoint(item.tex, 'TOPRIGHT', frame, 'TOPRIGHT', -pad, -(y + (DIVIDER_HEIGHT - theme.borderSize) / 2))
            y = y + DIVIDER_HEIGHT
        else
            gui:ApplyFont(item.text, 'normal')
            item.text:SetText(entry.text or '')
            item.button:SetEnabled(not entry.disabled)
            item.text:SetAlpha(entry.disabled and 0.4 or 1)

            local onClick = entry.onClick
            item.button:SetScript('OnClick', function()
                gui:CloseContextMenu()
                if onClick then safecall(onClick) end
            end)

            item.button:ClearAllPoints()
            pixel.SetPixelPoint(item.button, 'TOPLEFT', frame, 'TOPLEFT', 1, -y)
            pixel.SetPixelPoint(item.button, 'TOPRIGHT', frame, 'TOPRIGHT', -1, -y)

            width = max(width, item.text:GetStringWidth() + TEXT_INSET * 2)
            y = y + ITEM_HEIGHT
        end
    end

    -- Hide any rows left over from a longer previous menu.
    for index = #entries + 1, #menu.items do
        menu.items[index].tex:Hide()
        menu.items[index].button:Hide()
    end

    menu:Restyle()
    pixel.SetPixelSize(frame, min(width, MAX_WIDTH), y + pad)

    -- Cursor position is in screen pixels, so it has to be taken back into UIParent's scale.
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
