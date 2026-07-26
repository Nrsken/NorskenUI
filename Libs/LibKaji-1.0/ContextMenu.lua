--[[
# ContextMenu

* A small themed popup list, opened at the cursor, for right-click actions.
* Entries are plain data: { text, onClick, disabled?, divider? }. A divider entry needs nothing else.
* One menu per GUI instance is open at a time; opening a second closes the first.
* Clicking anywhere outside closes it, via a fullscreen catcher behind the menu rather than polling.

## Examples

    gui:ShowContextMenu({
        { text = "Rename", onClick = function() Rename(key) end },
        { divider = true },
        { text = "Delete", onClick = function() Delete(key) end },
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
local InstanceMixin = lib.InstanceMixin
local safecall = lib.safecall
local pixel = lib.Pixel

local CreateFrame = CreateFrame
local UIParent = UIParent
local GetCursorPosition = GetCursorPosition
local C_Timer = C_Timer
local ipairs = ipairs
local max, min = math.max, math.min

local ITEM_HEIGHT = 22
local DIVIDER_HEIGHT = 5
local MIN_WIDTH = 120
local MAX_WIDTH = 320
local TEXT_INSET = 10
local HOVER_ALPHA = 0.08

local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

---Lazily builds this instance's single menu frame.
---@param gui table
---@return table menu
local function EnsureMenu(gui)
    if gui._contextMenu then return gui._contextMenu end

    local theme = gui.theme

    -- Sits behind the menu and swallows the click that dismisses it, so no OnUpdate polling is needed.
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("TOOLTIP")
    catcher:RegisterForClicks("AnyUp")
    catcher:Hide()

    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:SetBackdrop(BACKDROP)
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(catcher:GetFrameLevel() + 10)
    frame:SetClampedToScreen(true)
    frame:Hide()

    local menu = { frame = frame, catcher = catcher, items = {} }
    gui._contextMenu = menu

    -- The button-up that opened the menu can still be in flight when the catcher shows, which would
    -- dismiss the menu on the same click. Ignore anything that arrives before the next frame.
    catcher:SetScript("OnClick", function()
        if menu.armed then gui:CloseContextMenu() end
    end)

    ---Restyles chrome so an open menu follows a live theme change like every other widget.
    function menu:Restyle()
        frame:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 1)
        frame:SetBackdropBorderColor(theme.border[1], theme.border[2], theme.border[3], theme.border[4])
        for _, item in ipairs(self.items) do
            if item.divider then
                item.tex:SetColorTexture(theme.border[1], theme.border[2], theme.border[3], 1)
            else
                item.text:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
                item.hover:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], HOVER_ALPHA)
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

            item.tex = frame:CreateTexture(nil, "ARTWORK")
            pixel.SetPixelHeight(item.tex, theme.borderSize)

            item.button = CreateFrame("Button", nil, frame)
            pixel.SetPixelHeight(item.button, ITEM_HEIGHT)
            item.button:SetFrameLevel(frame:GetFrameLevel() + 1)

            item.hover = item.button:CreateTexture(nil, "BACKGROUND")
            item.hover:SetAllPoints()
            item.hover:Hide()

            item.text = item.button:CreateFontString(nil, "OVERLAY")
            item.text:SetJustifyH("LEFT")
            item.text:SetWordWrap(false)
            pixel.SetPixelPoint(item.text, "LEFT", item.button, "LEFT", TEXT_INSET, 0)
            pixel.SetPixelPoint(item.text, "RIGHT", item.button, "RIGHT", -TEXT_INSET, 0)

            item.button:SetScript("OnEnter", function(self) if self:IsEnabled() then item.hover:Show() end end)
            item.button:SetScript("OnLeave", function() item.hover:Hide() end)

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
    local pad = theme.paddingSmall

    gui:CloseContextMenu()
    if not entries or not entries[1] then return end

    local frame = menu.frame
    local width, y = MIN_WIDTH, pad

    for index, entry in ipairs(entries) do
        local item = menu:Acquire(index, entry.divider == true)

        if entry.divider then
            item.tex:ClearAllPoints()
            pixel.SetPixelPoint(item.tex, "TOPLEFT", frame, "TOPLEFT", pad, -(y + (DIVIDER_HEIGHT - theme.borderSize) / 2))
            pixel.SetPixelPoint(item.tex, "TOPRIGHT", frame, "TOPRIGHT", -pad, -(y + (DIVIDER_HEIGHT - theme.borderSize) / 2))
            y = y + DIVIDER_HEIGHT
        else
            gui:ApplyFont(item.text, "normal")
            item.text:SetText(entry.text or "")
            item.button:SetEnabled(not entry.disabled)
            item.text:SetAlpha(entry.disabled and 0.4 or 1)

            local onClick = entry.onClick
            item.button:SetScript("OnClick", function()
                gui:CloseContextMenu()
                if onClick then safecall(onClick) end
            end)

            item.button:ClearAllPoints()
            pixel.SetPixelPoint(item.button, "TOPLEFT", frame, "TOPLEFT", 0, -y)
            pixel.SetPixelPoint(item.button, "TOPRIGHT", frame, "TOPRIGHT", 0, -y)

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
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)

    menu.armed = false
    menu.catcher:Show()
    frame:Show()
    C_Timer.After(0, function() menu.armed = true end)
end

---Closes the open context menu, if any.
function InstanceMixin:CloseContextMenu()
    local menu = self._contextMenu
    if not menu then return end
    menu.armed = false
    menu.frame:Hide()
    menu.catcher:Hide()
end
