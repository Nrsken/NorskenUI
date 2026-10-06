--[[
# SortableStack

* An ordered, drag-sortable list of icon rows in groups, joined by one spine through the icons.
* A group of several shares a slot: a caption opens it and its rows step in on elbows.
* Dropping on a row's top or bottom edge is `before` / `after`, its middle is `into`; the host moves its
  data and rebuilds.
* Sizes itself to its rows and pushes that height up through its row.

## Example

    row:Widget('SortableStack', nil, {
        width = 1,
        id = 'layers',
        groups = {
            { label = '2', items = { { key = 'tags', text = 'Tags', description = 'Layer 2' } } },
            { label = '1', items = { { key = 'buffs', text = 'Buffs' }, { key = 'debuffs', text = 'Debuffs' } } },
        },
        sharedCaption = 'Shared layer %s',
        onMove = function(key, targetKey, position) end,
    })

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin
local pixel = lib.Pixel
local safecall = lib.safecall
local Animations = lib.Animations

local CreateFrame = CreateFrame
local GetCursorPosition = GetCursorPosition
local InCombatLockdown = InCombatLockdown
local SetCursor, SetCursorByMode, ResetCursor = SetCursor, SetCursorByMode, ResetCursor
local type = type
local UIParent = UIParent
local Mixin = Mixin
local ipairs, pairs = ipairs, pairs
local select = select
local format = string.format
local strupper = string.upper
local mpi = math.pi
local min, abs = math.min, math.abs
local C_Timer = C_Timer
local GetTime = GetTime

local WIDGET_TYPE = "SortableStack"
local ROW_HEIGHT = 32
local ICON_SIZE = 24
local ICON_CROP = 0.08
local TEXT_GAP = 8
local CAPTION_HEIGHT = 22
local SPINE_X = ICON_SIZE / 2 -- the spine runs through the centre of the top-level icons
local CHILD_INDENT = 28 -- a shared group's rows step in this far
local STEP_SIZE = 12
local STEP_BUTTON = STEP_SIZE + 8
local STRIPE_ALPHA = 0.05 -- the same wash a striped card row uses
local STRIPE_BLEED = 4 -- the wash reaches past the rows, into the card's padding
local DROP_LINE = 2
local EDGE = 0.25 -- the share of a row, top and bottom, that drops before / after rather than into
local INTO_ALPHA = 0.14
local DRAG_ALPHA = 0.25
local BLUR_DELAY = 0.08 -- seconds a stack waits after a row's OnLeave before it lets go of the focus
local MOVE_TIME = 0.22 -- a row's glide to its new place
local SETTLE_TIME = MOVE_TIME + 0.08 -- hover waits out the glide, or names flicker as the page rebuilds
local FLASH_TIME = 0.8 -- the moved row's accent wash fading out
local FADE_TIME = 0.25 -- lines and captions fading back in after a move
local LINE_SPEED = 18 -- how fast the drop line slides to a new seam, per second as a share of the distance
local GHOST_ALPHA = 0.95
local GHOST_BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 }

-- Where each named list drew its rows last, and the row moved last, kept across pooled rebuilds.
local memory = {}

---@param cursor number|string Enum.CursorMode value or built-in cursor name
local function ApplyCursor(cursor)
    if type(cursor) == "number" and SetCursorByMode then
        SetCursorByMode(cursor)
    else
        SetCursor(cursor)
    end
end

local function EaseOut(t)
    return 1 - (1 - t) * (1 - t) * (1 - t)
end

---@class KajiGUISortableStackMixin : Frame
---@field gui KajiGUIInstance
---@field rows table[] pooled row buttons, in display order
---@field captions table[] pooled caption rows
---@field lines table<string, Texture[]> pooled spine segments and elbows
---@field overlay Frame
---@field dropLine Texture
---@field intoMark Texture
---@field ghost Frame|BackdropTemplate
---@field ghostLabel FontString
---@field dragFrame Frame
---@field drag? { key: any, target: any, position: string?, started: boolean? }
---@field _config table
---@field _enabled boolean
---@field _blurToken number?
---@field _lineY number?
---@field _lineTargetY number?
---@field _settleUntil number? GetTime() until which a fresh move keeps the hover colour off
local StackMixin = {}

---@return boolean
function StackMixin:IsSettling()
    return self._settleUntil ~= nil and GetTime() < self._settleUntil
end

---Starts the hold on the hover colour for a list that is about to rebuild after a move.
function StackMixin:Settle()
    if self._config.id then memory[self._config.id].settle = GetTime() + SETTLE_TIME end
end

---Tracked from OnEnter/OnLeave, IsMouseOver is true for both rows on a shared seam.
---@param row table
---@return boolean
local function IsRowHovered(row)
    return row.hovered or row.steps[1].hovered or row.steps[2].hovered
end

---@param row table
function StackMixin:PaintRow(row)
    local theme = self.gui.theme
    local item = row.item
    local selected = item.key == self._config.highlight
    local settled = not self.drag and not self:IsSettling()
    local hovered = settled and not item.locked and IsRowHovered(row)

    local name = selected and theme.accent or (item.locked and theme.textMuted or theme.textPrimary)
    row.nameColor(hovered and theme.accent or name)
    row.description:SetTextColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 1)
    row.stripe:SetColorTexture(1, 1, 1, STRIPE_ALPHA)

    for _, step in ipairs(row.steps) do
        step.tint(settled and step.hovered and theme.accent or theme.textMuted)
    end

    row:SetAlpha(self.drag and self.drag.key == row.key and DRAG_ALPHA or 1)
end

---A tween for one value, driven by its own frame while it runs.
---@param frame Frame
---@param apply fun(value: number)
---@param duration number
---@return fun(to: number, from: number?)
local function Tween(frame, apply, duration)
    local driver = CreateFrame("Frame", nil, frame)
    local from, to, elapsed = 0, 0, 0
    local current = 0
    driver:Hide()
    driver:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local t = min(elapsed / duration, 1)
        current = from + (to - from) * EaseOut(t)
        apply(current)
        if t >= 1 then self:Hide() end
    end)
    return function(target, start)
        from, to, elapsed = start or current, target, 0
        if from == to then
            current = to
            apply(to)
            driver:Hide()
            return
        end
        driver:Show()
    end
end

---@return table row
function StackMixin:AcquireRow(index)
    local row = self.rows[index]
    if row then return row end
    local gui = self.gui
    local theme = gui.theme

    row = CreateFrame("Button", nil, self)
    pixel.SetPixelHeight(row, ROW_HEIGHT)
    row.stack = self

    local stripe = row:CreateTexture(nil, "BACKGROUND")
    pixel.SetPixelPoint(stripe, "TOPLEFT", row, "TOPLEFT", -STRIPE_BLEED, 0)
    pixel.SetPixelPoint(stripe, "BOTTOMRIGHT", row, "BOTTOMRIGHT", STRIPE_BLEED, 0)
    row.stripe = stripe

    -- Hover leaves the background alone, so the zebra never breaks; only a moved row washes, briefly.
    local flash = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    flash:SetAllPoints(stripe)
    flash:SetColorTexture(theme.accent[1], theme.accent[2], theme.accent[3], 0)
    row.flash = Tween(row, function(a)
        local ac = gui.theme.accent
        flash:SetColorTexture(ac[1], ac[2], ac[3], a)
    end, FLASH_TIME)

    local iconBorder = row:CreateTexture(nil, "ARTWORK", nil, 1)
    pixel.SetPixelSize(iconBorder, ICON_SIZE, ICON_SIZE)
    pixel.SetPixelPoint(iconBorder, "LEFT", row, "LEFT", 0, 0)
    iconBorder:SetColorTexture(0, 0, 0, 1)
    row.iconBorder = iconBorder

    local icon = row:CreateTexture(nil, "ARTWORK", nil, 2)
    row.icon = icon

    local label = row:CreateFontString(nil, "OVERLAY")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    gui:ApplyFont(label, "normal")
    row.label = label
    local nameColor = Animations:CreateColorAnimator(row, function(r, g, b, a) label:SetTextColor(r, g, b, a) end, theme.textPrimary, 0.12)
    row.nameColor = function(color) nameColor(color[1], color[2], color[3], color[4] or 1) end

    local description = row:CreateFontString(nil, "OVERLAY")
    description:SetJustifyH("LEFT")
    description:SetWordWrap(false)
    gui:ApplyFont(description, "small")
    row.description = description

    -- Up then down at the right edge, always shown; the arrow art points down, so up turns it over.
    row.steps = {}
    for i, dir in ipairs({ 1, -1 }) do
        local step = CreateFrame("Button", nil, row)
        pixel.SetPixelSize(step, STEP_BUTTON, ROW_HEIGHT)
        pixel.SetPixelPoint(step, "RIGHT", row, "RIGHT", -(2 - i) * STEP_BUTTON, 0)
        local stepIcon = step:CreateTexture(nil, "ARTWORK")
        pixel.SetPixelSize(stepIcon, STEP_SIZE, STEP_SIZE)
        stepIcon:SetPoint("CENTER")
        stepIcon:SetTexture(theme.stepperTexture)
        stepIcon:SetRotation(dir > 0 and mpi or 0)
        step.icon = stepIcon
        local tint = Animations:CreateColorAnimator(step, function(r, g, b, a) stepIcon:SetVertexColor(r, g, b, a) end, theme.textMuted, 0.12)
        step.tint = function(color) tint(color[1], color[2], color[3], color[4] or 1) end
        step:SetScript("OnClick", function()
            local onStep = self._config.onStep
            if not onStep then return end
            if self._config.id then memory[self._config.id].moved = row.key end
            self:Settle()
            safecall(onStep, row.key, dir)
        end)
        step:SetScript("OnEnter", function()
            step.hovered = true
            self:PaintRow(row)
        end)
        step:SetScript("OnLeave", function()
            step.hovered = false
            self:PaintRow(row)
            self:QueueBlur()
        end)
        row.steps[i] = step
    end

    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(r) r.stack:BeginDrag(r) end)
    row:SetScript("OnClick", function(r)
        local onClick = r.stack._config.onClick
        if onClick and not r.stack.drag then safecall(onClick, r.key) end
    end)
    row:SetScript("OnEnter", function(r)
        local stack = r.stack
        r.hovered = true
        stack._blurToken = (stack._blurToken or 0) + 1 -- a pending blur from the row just left is void
        stack:PaintRow(r)
        if not r.item.locked and not stack.drag then ApplyCursor(stack.gui.theme.dragCursor) end
        if not stack.drag and stack._config.onFocus then safecall(stack._config.onFocus, r.key) end
    end)
    row:SetScript("OnLeave", function(r)
        local stack = r.stack
        r.hovered = false
        if not stack.drag then ResetCursor() end
        stack:PaintRow(r)
        stack:QueueBlur()
    end)

    row.glide = CreateFrame("Frame", nil, row)
    row.glide:Hide()
    row.glide:SetScript("OnUpdate", function(driver, dt)
        driver.elapsed = driver.elapsed + dt
        local t = min(driver.elapsed / MOVE_TIME, 1)
        local e = EaseOut(t)
        local x = driver.fromX + (driver.toX - driver.fromX) * e
        local y = driver.fromY + (driver.toY - driver.fromY) * e
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
        row:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -y)
        if t >= 1 then
            driver:Hide()
            row:ClearAllPoints()
            pixel.SetPixelPoint(row, "TOPLEFT", self, "TOPLEFT", driver.toX, -driver.toY)
            pixel.SetPixelPoint(row, "TOPRIGHT", self, "TOPRIGHT", 0, -driver.toY)
        end
    end)

    self.rows[index] = row
    return row
end

---@return table caption
function StackMixin:AcquireCaption(index)
    local caption = self.captions[index]
    if caption then return caption end

    caption = CreateFrame("Frame", nil, self)
    pixel.SetPixelHeight(caption, CAPTION_HEIGHT)
    local text = caption:CreateFontString(nil, "OVERLAY")
    text:SetJustifyH("LEFT")
    pixel.SetPixelPoint(text, "LEFT", caption, "LEFT", CHILD_INDENT, 0)
    self.gui:ApplyFont(text, "small")
    caption.text = text

    local rule = caption:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelHeight(rule, 1)
    pixel.SetPixelPoint(rule, "LEFT", text, "RIGHT", TEXT_GAP, 0)
    pixel.SetPixelPoint(rule, "RIGHT", caption, "RIGHT", 0, 0)
    pixel.SetPixelSnap(rule)
    caption.rule = rule

    self.captions[index] = caption
    return caption
end

---One of the pooled line textures. Kinds: spine, elbow.
---@param kind string
---@param index number
---@return Texture
function StackMixin:AcquireLine(kind, index)
    local pool = self.lines[kind]
    local tex = pool[index]
    if tex then return tex end

    tex = self:CreateTexture(nil, "ARTWORK")
    pixel.SetPixelSnap(tex)
    pool[index] = tex
    return tex
end

---Places one row, with its icon, name and description, gliding it there from where it was last drawn.
---@param row table
---@param item table
---@param x number left inset
---@param y number top offset
---@param striped boolean
---@param last table? the list's positions from its previous render
function StackMixin:PlaceRow(row, item, x, y, striped, last)
    row.item, row.key = item, item.key

    local hasIcon = item.icon ~= nil
    local bare = item.iconBare == true
    row.iconBorder:SetShown(hasIcon and not bare)
    row.icon:SetShown(hasIcon)
    if hasIcon then
        local inset = bare and 0 or 1
        row.icon:ClearAllPoints()
        pixel.SetPixelPoint(row.icon, "TOPLEFT", row.iconBorder, "TOPLEFT", inset, -inset)
        pixel.SetPixelPoint(row.icon, "BOTTOMRIGHT", row.iconBorder, "BOTTOMRIGHT", -inset, inset)
        row.icon:SetTexture(item.icon)
        local coords, tint = item.iconCoords, item.iconColor
        if coords then
            row.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        else
            row.icon:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
        end
        row.icon:SetVertexColor(tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1, tint and (tint[4] or 1) or 1)
    end

    local textX = hasIcon and (ICON_SIZE + TEXT_GAP) or 0
    local stepping = self._config.onStep ~= nil and not item.locked
    local textRight = stepping and -(STEP_BUTTON * 2 + 4) or 0
    local hasDescription = item.description ~= nil and item.description ~= ""
    row.label:ClearAllPoints()
    row.description:ClearAllPoints()
    if hasDescription then
        pixel.SetPixelPoint(row.label, "BOTTOMLEFT", row, "LEFT", textX, 1)
        pixel.SetPixelPoint(row.label, "RIGHT", row, "RIGHT", textRight, 0)
        pixel.SetPixelPoint(row.description, "TOPLEFT", row, "LEFT", textX, -1)
        pixel.SetPixelPoint(row.description, "RIGHT", row, "RIGHT", textRight, 0)
    else
        pixel.SetPixelPoint(row.label, "LEFT", row, "LEFT", textX, 0)
        pixel.SetPixelPoint(row.label, "RIGHT", row, "RIGHT", textRight, 0)
    end
    row.label:SetText(item.text or "")
    row.description:SetText(hasDescription and item.description or "")
    row.description:SetShown(hasDescription)
    row.stripe:SetShown(striped)
    for _, step in ipairs(row.steps) do step:SetShown(stepping) end

    row:Show()
    self:PaintRow(row)

    local was = last and last[item.key]
    if was and (abs(was.x - x) > 0.5 or abs(was.y - y) > 0.5) then
        local glide = row.glide
        glide.fromX, glide.fromY, glide.toX, glide.toY, glide.elapsed = was.x, was.y, x, y, 0
        glide:Show()
        glide:GetScript("OnUpdate")(glide, 0)
    else
        row.glide:Hide()
        row:ClearAllPoints()
        pixel.SetPixelPoint(row, "TOPLEFT", self, "TOPLEFT", x, -y)
        pixel.SetPixelPoint(row, "TOPRIGHT", self, "TOPRIGHT", 0, -y)
    end
end

---Lays every group out top to bottom and reports the height up to the row.
function StackMixin:Render()
    local theme = self.gui.theme
    local config = self._config
    local used = { spine = 0, elbow = 0 }
    local rowCount, captionCount = 0, 0
    local y = 0
    local lineColor = theme.widgetBorder

    local store = config.id and memory[config.id]
    if config.id and not store then
        store = { positions = {} }
        memory[config.id] = store
    end
    local last = store and store.positions
    local now = {}
    local moved = false

    local function Line(kind)
        used[kind] = used[kind] + 1
        local tex = self:AcquireLine(kind, used[kind])
        tex:ClearAllPoints()
        tex:SetColorTexture(lineColor[1], lineColor[2], lineColor[3], 1)
        tex:Show()
        return tex
    end

    -- Spine stops: top-level icons leave a gap, elbow junctions are points.
    local stops = {}
    local function Place(item, x, top)
        rowCount = rowCount + 1
        local row = self:AcquireRow(rowCount)
        self:PlaceRow(row, item, x, top, rowCount % 2 == 0, last)
        now[item.key] = { x = x, y = top }
        if last and last[item.key] and (last[item.key].x ~= x or last[item.key].y ~= top) then moved = true end
        return row
    end

    for _, group in ipairs(config.groups or {}) do
        local items = group.items
        if #items == 1 then
            local item = items[1]
            Place(item, 0, y)
            stops[#stops + 1] = { y = y + ROW_HEIGHT / 2, half = item.icon and ICON_SIZE / 2 or 0, spine = item.icon ~= nil }
            y = y + ROW_HEIGHT
        else
            captionCount = captionCount + 1
            local caption = self:AcquireCaption(captionCount)
            caption:ClearAllPoints()
            pixel.SetPixelPoint(caption, "TOPLEFT", self, "TOPLEFT", 0, -y)
            pixel.SetPixelPoint(caption, "TOPRIGHT", self, "TOPRIGHT", 0, -y)
            local text = config.sharedCaption and format(config.sharedCaption, group.label or "") or (group.label or "")
            caption.text:SetText(strupper(text))
            caption.text:SetTextColor(theme.textMuted[1], theme.textMuted[2], theme.textMuted[3], 1)
            caption.rule:SetColorTexture(theme.widgetBorder[1], theme.widgetBorder[2], theme.widgetBorder[3], 1)
            caption:Show()
            y = y + CAPTION_HEIGHT

            for _, item in ipairs(items) do
                Place(item, CHILD_INDENT, y)
                local middle = y + ROW_HEIGHT / 2
                local elbow = Line("elbow")
                pixel.SetPixelHeight(elbow, 1)
                pixel.SetPixelPoint(elbow, "LEFT", self, "TOPLEFT", SPINE_X, -middle)
                pixel.SetPixelPoint(elbow, "RIGHT", self, "TOPLEFT", CHILD_INDENT - 3, -middle)
                stops[#stops + 1] = { y = middle, half = 0, spine = true }
                y = y + ROW_HEIGHT
            end
        end
    end

    -- The spine, in segments between stops, so it never shows through an icon's own transparency.
    if config.spine ~= false then
        for i = 2, #stops do
            local a, b = stops[i - 1], stops[i]
            if a.spine and b.spine then
                local top, bottom = a.y + a.half, b.y - b.half
                if bottom > top then
                    local seg = Line("spine")
                    pixel.SetPixelWidth(seg, 1)
                    pixel.SetPixelPoint(seg, "TOP", self, "TOPLEFT", SPINE_X, -top)
                    pixel.SetPixelHeight(seg, bottom - top)
                end
            end
        end
    end

    for i = rowCount + 1, #self.rows do self.rows[i]:Hide() end
    for i = captionCount + 1, #self.captions do self.captions[i]:Hide() end
    for kind, pool in pairs(self.lines) do
        for i = used[kind] + 1, #pool do pool[i]:Hide() end
    end

    local fadeTargets = {}
    for _, pool in pairs(self.lines) do
        for _, tex in ipairs(pool) do fadeTargets[#fadeTargets + 1] = tex end
    end
    for _, caption in ipairs(self.captions) do fadeTargets[#fadeTargets + 1] = caption end
    if moved then
        self.lineFade(1, 0)
    else
        self.lineFade(1, 1)
    end
    self._fadeTargets = fadeTargets

    if store then
        store.positions = now
        self._settleUntil = store.settle
        local remaining = store.settle and (store.settle - GetTime())
        if remaining and remaining > 0 then
            local config = self._config
            C_Timer.After(remaining, function()
                if self._config ~= config then return end -- rebuilt or released meanwhile
                for _, row in ipairs(self.rows) do
                    if row:IsShown() then self:PaintRow(row) end
                end
            end)
        end
        local key = store.moved
        store.moved = nil
        if key then
            for _, row in ipairs(self.rows) do
                if row:IsShown() and row.key == key then row.flash(0, 0.35) end
            end
        end
    end

    local height = y > 0 and y or ROW_HEIGHT
    pixel.SetPixelHeight(self, height)
    local owner = self:GetParent()
    if owner and owner.SetWidgetHeight then owner:SetWidgetHeight(self, height) end
end

---Deferred: the old row's OnLeave fires before the next one's OnEnter, which flashed the focus.
function StackMixin:QueueBlur()
    self._blurToken = (self._blurToken or 0) + 1
    local token = self._blurToken
    C_Timer.After(BLUR_DELAY, function()
        if token ~= self._blurToken or self.drag then return end
        for _, row in ipairs(self.rows) do
            if row:IsShown() then self:PaintRow(row) end
        end
        if not self._config.onFocus then return end
        for _, row in ipairs(self.rows) do
            if row:IsShown() and IsRowHovered(row) then return end
        end
        safecall(self._config.onFocus, nil)
    end)
end

-- Drag and drop --

---The row under the cursor and where on it the drop would go, or nil when no spot is allowed.
---@return table? row, string? position
function StackMixin:FindDropTarget()
    local drag = self.drag
    local canDrop = self._config.canDrop
    for _, row in ipairs(self.rows) do
        if row:IsShown() and row.key ~= drag.key and row:IsMouseOver() then
            local _, cursorY = GetCursorPosition()
            local share = (row:GetTop() - cursorY / row:GetEffectiveScale()) / row:GetHeight()
            local position = share < EDGE and "before" or (share > 1 - EDGE and "after" or "into")
            if not canDrop or select(2, safecall(canDrop, drag.key, row.key, position)) == true then
                return row, position
            end
            return nil
        end
    end
    return nil
end

---@param row? table
function StackMixin:ShowDropMark(row)
    local drag = self.drag
    if not row then
        self.dropLine:Hide()
        self.intoFade(0)
        self._lineY = nil
        return
    end

    if drag.position == "into" then
        self.dropLine:Hide()
        self._lineY = nil
        self.intoMark:ClearAllPoints()
        pixel.SetPixelPoint(self.intoMark, "TOPLEFT", row, "TOPLEFT", -STRIPE_BLEED, 0)
        pixel.SetPixelPoint(self.intoMark, "BOTTOMRIGHT", row, "BOTTOMRIGHT", STRIPE_BLEED, 0)
        self.intoFade(INTO_ALPHA, 0)
        return
    end

    self.intoFade(0)
    local accent = self.gui.theme.accent
    self.dropLine:SetColorTexture(accent[1], accent[2], accent[3], 1)
    local seam = (self:GetTop() - (drag.position == "before" and row:GetTop() or row:GetBottom()))
    self._lineTargetY = seam
    if not self._lineY then self._lineY = seam end
    self.dropLine:Show()
end

---@param commit boolean drop on the current spot rather than cancel
function StackMixin:StopDrag(commit)
    local drag = self.drag
    if not drag then return end

    self.drag = nil
    self.dragFrame:SetScript("OnUpdate", nil)
    self.dragFrame:UnregisterEvent("GLOBAL_MOUSE_UP")
    self.ghost:EnableKeyboard(false)
    self.ghost:Hide()
    self.dropLine:Hide()
    self._lineY = nil
    self.intoFade(0)
    ResetCursor()
    for _, r in ipairs(self.rows) do
        if r:IsShown() then self:PaintRow(r) end
    end

    -- The preview goes back first, so a drop applies on top of the real state.
    local config = self._config
    if config.onHover then safecall(config.onHover, nil) end
    if commit and drag.target ~= nil and config.onMove then
        if config.id then memory[config.id].moved = drag.key end
        self:Settle()
        safecall(config.onMove, drag.key, drag.target, drag.position)
    end
end

---@param elapsed number
function StackMixin:StepDrag(elapsed)
    local drag = self.drag
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self.ghost:ClearAllPoints()
    self.ghost:SetPoint("LEFT", UIParent, "BOTTOMLEFT", x / scale + 12, y / scale)
    ApplyCursor(self.gui.theme.dragCursorHeld)

    if self._lineY and self._lineTargetY then
        self._lineY = self._lineY + (self._lineTargetY - self._lineY) * min(1, (elapsed or 0) * LINE_SPEED)
        self.dropLine:ClearAllPoints()
        self.dropLine:SetPoint("LEFT", self, "TOPLEFT", -STRIPE_BLEED, -self._lineY)
        self.dropLine:SetPoint("RIGHT", self, "TOPRIGHT", STRIPE_BLEED, -self._lineY)
    end

    local row, position = self:FindDropTarget()
    local target = row and row.key
    if drag.started and target == drag.target and position == drag.position then return end

    drag.started = true
    drag.target, drag.position = target, position
    self:ShowDropMark(row)

    -- Fires with the dragged key throughout, the target nil while nothing would take the drop.
    local onHover = self._config.onHover
    if onHover then safecall(onHover, drag.key, target, position) end
end

---@param row table
function StackMixin:BeginDrag(row)
    if not self._enabled or row.item.locked or self.drag then return end
    local theme = self.gui.theme

    self.drag = { key = row.key }
    self.ghost:SetBackdropColor(theme.bgMedium[1], theme.bgMedium[2], theme.bgMedium[3], 0.95)
    self.ghost:SetBackdropBorderColor(theme.accent[1], theme.accent[2], theme.accent[3], 1)
    pixel.SetPixelWidth(self.ghost, row:GetWidth())
    self.gui:ApplyFont(self.ghostLabel, "normal")
    self.ghostLabel:SetText(row.item.text or "")
    self.ghostLabel:SetTextColor(theme.textPrimary[1], theme.textPrimary[2], theme.textPrimary[3], 1)
    self.ghost:Show()
    self.ghostFade(GHOST_ALPHA, 0)
    -- Keyboard capture is protected in combat; Escape simply does not cancel there.
    if not InCombatLockdown() then self.ghost:EnableKeyboard(true) end

    for _, r in ipairs(self.rows) do
        if r:IsShown() then self:PaintRow(r) end
    end
    self.dragFrame:RegisterEvent("GLOBAL_MOUSE_UP")
    self.dragFrame:SetScript("OnUpdate", function(_, elapsed) self:StepDrag(elapsed) end)
    self:StepDrag(0)
end

-- Lifecycle --

---@param enabled boolean
function StackMixin:SetEnabled(enabled)
    self._enabled = enabled and true or false
    if not enabled then self:StopDrag(false) end
    self:SetAlpha(enabled and 1 or 0.4)
end

function StackMixin:UpdateColors()
    self:Render()
end

---@param parent Frame
---@param _ any unused, the stack has no title
---@param config table
function StackMixin:OnAcquire(parent, _, config)
    self._config = config
    self._settleUntil = nil
    self._enabled = true
    self:SetParent(parent)
    self:ClearAllPoints()
    -- Keeps the row from stamping its own height back over the measured one.
    self.explicitHeight = true
    self:SetAlpha(1)
    self:Show()
    self:Render()
end

function StackMixin:OnRelease()
    self:StopDrag(false)
    self._config = {}
    self.explicitHeight = nil
    for _, row in ipairs(self.rows) do
        row:Hide(); row.item = nil; row.key = nil
        row.hovered = nil
        for _, step in ipairs(row.steps) do step.hovered = nil end
        row.glide:Hide()
    end
    for _, caption in ipairs(self.captions) do caption:Hide() end
    for _, pool in pairs(self.lines) do
        for _, tex in ipairs(pool) do tex:Hide() end
    end
end

---@class KajiGUISortableStack : KajiGUISortableStackMixin

---@class KajiGUISortableStackItem
---@field key any
---@field text string
---@field description? string a muted line under the name
---@field icon? string|number
---@field iconColor? number[] tints the icon
---@field iconCoords? number[] crops the icon, for one cell of a sprite sheet
---@field iconBare? boolean no black border, for art with a shape of its own
---@field locked? boolean

---@class KajiGUISortableStackConfig
---@field groups { label?: string, items: KajiGUISortableStackItem[] }[] top to bottom
---@field id? string names the list across rebuilds, so rows glide and the moved row flashes
---@field sharedCaption? string format for a shared group's caption, given its label
---@field spine? boolean false leaves out the line through the icons
---@field onMove? fun(key: any, targetKey: any, position: "before"|"after"|"into")
---@field onHover? fun(key: any?, targetKey: any?, position: string?) a nil key when the drag ends
---@field onStep? fun(key: any, dir: number) up / down arrows on every row; dir 1 is up
---@field onFocus? fun(key: any?) the row under the cursor outside a drag, nil once it has left them all
---@field onClick? fun(key: any) a click on a row that was not a drag
---@field canDrop? fun(key: any, targetKey: any, position: string): boolean
---@field highlight? any the key of a row to draw selected

lib:RegisterWidgetType(WIDGET_TYPE, function(gui)
    local stack = CreateFrame("Frame", nil, gui._poolHost)
    stack.gui = gui
    stack.rows, stack.captions = {}, {}
    stack.lines = { spine = {}, elbow = {} }
    stack._config = {}
    stack._fadeTargets = {}

    stack.lineFade = Tween(stack, function(a)
        for _, region in ipairs(stack._fadeTargets) do region:SetAlpha(a) end
    end, FADE_TIME)

    -- Above the rows, so the drop marks are never covered by a row.
    local overlay = CreateFrame("Frame", nil, stack)
    overlay:SetAllPoints(stack)
    overlay:SetFrameLevel(stack:GetFrameLevel() + 20)
    stack.overlay = overlay

    local dropLine = overlay:CreateTexture(nil, "OVERLAY")
    pixel.SetPixelHeight(dropLine, DROP_LINE)
    dropLine:Hide()
    stack.dropLine = dropLine

    local intoMark = overlay:CreateTexture(nil, "ARTWORK")
    intoMark:SetColorTexture(1, 1, 1, 0)
    stack.intoMark = intoMark
    stack.intoFade = Tween(stack, function(a)
        local ac = gui.theme.accent
        intoMark:SetColorTexture(ac[1], ac[2], ac[3], a)
        dropLine:SetColorTexture(ac[1], ac[2], ac[3], 1)
    end, 0.12)

    local ghost = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetBackdrop(GHOST_BACKDROP)
    pixel.SetPixelHeight(ghost, ROW_HEIGHT)
    ghost:Hide()
    stack.ghost = ghost
    stack.ghostFade = Tween(ghost, function(a) ghost:SetAlpha(a) end, 0.12)

    local ghostLabel = ghost:CreateFontString(nil, "OVERLAY")
    ghostLabel:SetJustifyH("LEFT")
    ghostLabel:SetWordWrap(false)
    pixel.SetPixelPoint(ghostLabel, "LEFT", ghost, "LEFT", 10, 0)
    pixel.SetPixelPoint(ghostLabel, "RIGHT", ghost, "RIGHT", -6, 0)
    stack.ghostLabel = ghostLabel

    local dragFrame = CreateFrame("Frame", nil, stack)
    dragFrame:SetScript("OnEvent", function(_, _, button)
        if button == "LeftButton" then stack:StopDrag(true) end
    end)
    stack.dragFrame = dragFrame

    ghost:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            stack:StopDrag(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)

    Mixin(stack, StackMixin)
    return stack
end)

---@param parent Frame
---@param config KajiGUISortableStackConfig
---@return KajiGUISortableStack
function InstanceMixin:CreateSortableStack(parent, config)
    return self:BuildWidget(WIDGET_TYPE, parent, nil, config)
end
