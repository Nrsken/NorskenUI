---@class NRSKNUI
local NRSKNUI = select(2, ...)
local L = NRSKNUI.Libs.AL
local Theme = NRSKNUI.Theme
local CDM = NRSKNUI:GetModule('CDM')

local ipairs, pairs, tonumber, tostring = ipairs, pairs, tonumber, tostring
local tconcat = table.concat
local tContains = tContains
local format = string.format
local strtrim = strtrim
local CreateFrame = CreateFrame
local GetSpellName, GetSpellTexture = C_Spell.GetSpellName, C_Spell.GetSpellTexture
local GetItemIconByID, GetItemNameByID = C_Item.GetItemIconByID, C_Item.GetItemNameByID
local GetFileIDFromPath = GetFileIDFromPath

local GRID_TYPE = 'NUIIconGrid'
local BUTTON_SIZE = 36
local SPACING = 4
local GRID_HEIGHT = 420
local SEARCH_DELAY = 0.15
local MAX_RESULTS = 500 -- keeps a broad search responsive
local ICON_PATH = 'Interface\\Icons\\'
local QUESTION_MARK = 134400

---@class CDMIconPicker
local IconPicker = {}
NRSKNUI.CDMIconPicker = IconPicker

-- Icon names in compact form, built a few milliseconds per frame while the options are open and kept for the session.
local cache ---@type { spells: CDMIconEntry[], names: string[], spellIcons: number[], spellTexts: string[], spellFirst: string[], ready: boolean, complete: boolean }?
local loader ---@type thread?
local onLoaded ---@type fun()?

---Your own spells: the spellbook and the Cooldown Manager list, matched by spell name.
---@return CDMIconEntry[]
local function OwnSpells()
    local list, seen = {}, {}
    ---@param texture number?
    ---@param name string?
    local function Add(texture, name)
        if texture == nil or name == nil or NRSKNUI:IsSecretValue(texture) or seen[texture] then return end
        seen[texture] = true
        list[#list + 1] = { texture = texture, name = name, search = name:lower() }
    end

    local bank = Enum.SpellBookSpellBank.Player
    for line = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local info = C_SpellBook.GetSpellBookSkillLineInfo(line)
        if info and not info.shouldHide then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if item and item.itemType == Enum.SpellBookItemType.Spell then Add(item.iconID, item.name) end
            end
        end
    end
    for _, category in ipairs(CDM.Catalogue.CATEGORIES) do
        for _, cooldownID in ipairs(CDM.Catalogue:GetList(category)) do
            local entry = CDM.Catalogue:GetEntry(cooldownID)
            local spellID = entry and (entry.overrideSpellID or entry.spellID)
            if spellID then Add(GetSpellTexture(spellID), GetSpellName(spellID)) end
        end
    end
    return list
end

-- The same four lists Blizzard's IconDataProvider reads. Only named icons are kept: an ID-only one can't
-- match a word, and a number search shows any file ID directly.
local MACRO_LISTS = { GetLooseMacroIcons, GetLooseMacroItemIcons, GetMacroIcons, GetMacroItemIcons }
local CHUNK = 2000
local MACRO_BUDGET = 6  -- ms per frame for the macro lists, a moment after the page opens
local SPELL_BUDGET = 2  -- ms per frame for the spell walk, which runs for a few seconds
local SPELL_CHUNK = 250
local SPELL_MISS_LIMIT = 500000 -- empty IDs in a row before the walk ends; the widest gap today is ~380k
local MAX_NAMES_PER_ICON = 32
local GEAR_ICON = 136243 -- the placeholder icon on internal spells, never worth showing
local budget = MACRO_BUDGET

---What a field stores: a file ID, so an Icon ID box shows the number back.
---@param texture number|string
---@return number|string
local function ToFileID(texture)
    if type(texture) == 'number' then return texture end
    local fileID = GetFileIDFromPath(texture)
    return (fileID and fileID > 0) and fileID or texture
end

---Every spell in the game, one entry per icon with up to 32 of its spell names; no per-patch skip table to keep up to date.
---@param result table
local function WalkSpells(result)
    local icons, texts, firstNames, byIcon = result.spellIcons, result.spellTexts, result.spellFirst, {}
    local extra = {} -- [index] = the names after the first, joined once the walk ends
    local id, misses = 0, 0
    budget = SPELL_BUDGET
    while misses < SPELL_MISS_LIMIT do
        id = id + 1
        local name = GetSpellName(id)
        if name and name ~= '' and not NRSKNUI:IsSecretValue(name) then
            misses = 0
            local icon = GetSpellTexture(id)
            if icon and icon ~= GEAR_ICON and not NRSKNUI:IsSecretValue(icon) then
                local lower = name:lower()
                local index = byIcon[icon]
                if not index then
                    index = #icons + 1
                    byIcon[icon] = index
                    icons[index], texts[index], firstNames[index] = icon, lower, name
                elseif lower ~= texts[index] then
                    local names = extra[index]
                    if not names then
                        names = {}
                        extra[index] = names
                    end
                    if #names < MAX_NAMES_PER_ICON - 1 and not tContains(names, lower) then names[#names + 1] = lower end
                end
            end
        else
            misses = misses + 1
        end
        if id % SPELL_CHUNK == 0 then coroutine.yield() end
    end
    local joined = 0
    for index, names in pairs(extra) do
        texts[index] = texts[index] .. '\n' .. tconcat(names, '\n')
        joined = joined + 1
        if joined % CHUNK == 0 then coroutine.yield() end
    end
end

local function Load()
    local result = { spells = OwnSpells(), names = {}, spellIcons = {}, spellTexts = {}, spellFirst = {}, ready = false, complete = false }
    local names, seen = result.names, {}
    budget = MACRO_BUDGET
    coroutine.yield()
    for _, fill in ipairs(MACRO_LISTS) do
        local list = {}
        fill(list)
        coroutine.yield()
        for i, value in ipairs(list) do
            if not tonumber(value) then
                local name = value:lower() -- texture paths aren't case sensitive, so one copy serves both
                if not seen[name] then
                    seen[name] = true
                    names[#names + 1] = name
                end
            end
            if i % CHUNK == 0 then coroutine.yield() end
        end
    end
    -- File-name search works from here; spell names join as the walk goes.
    result.ready = true
    cache = result
    if onLoaded then onLoaded() end
    WalkSpells(result)
    result.complete = true
end

-- Never runs during play: it stops as soon as the options window closes or combat starts.
local driver = CreateFrame('Frame')
driver:Hide()
driver:SetScript('OnUpdate', function(self)
    local window = NRSKNUI.GUIFrame
    if NRSKNUI:InCombat() or not (window and window:IsShown()) then
        self:Hide()
        return
    end
    local start = debugprofilestop()
    while loader and debugprofilestop() - start < budget do
        local ok, err = coroutine.resume(loader)
        if not ok then
            loader = nil
            self:Hide()
            error(err)
        end
        if coroutine.status(loader) == 'dead' then
            loader = nil
            self:Hide()
            if onLoaded then onLoaded() end
        end
    end
end)

---@param callback fun()? runs once the lists are ready, now if they already are
local function EnsureLoaded(callback)
    if callback then onLoaded = callback end
    if not (cache and cache.complete) and not loader then loader = coroutine.create(Load) end
    if loader then driver:Show() end
    if callback and cache and cache.ready then callback() end
end

---Words match your spells, every spell name in the game and icon file names; a number is tried as a file, spell and item ID.
---@param text string
---@return CDMIconEntry[]
local function Search(text)
    text = strtrim(text or ''):lower()
    if text == '' or not (cache and cache.ready) then return {} end -- nothing shows until you type

    local results, seen = {}, {}
    ---@param entry CDMIconEntry
    local function Add(entry)
        if #results < MAX_RESULTS and not seen[entry.texture] then
            seen[entry.texture] = true
            results[#results + 1] = entry
        end
    end

    local number = tonumber(text)
    if number and number > 0 and number == math.floor(number) then
        Add({ texture = number, name = format(L['File ID %d'], number) })
        local spellIcon = GetSpellTexture(number)
        if spellIcon then Add({ texture = spellIcon, name = format('%s (%s %d)', GetSpellName(number) or '?', L['Spell'], number) }) end
        local itemIcon = GetItemIconByID(number)
        if itemIcon then Add({ texture = itemIcon, name = format('%s (%s %d)', GetItemNameByID(number) or '?', L['Item'], number) }) end
    end
    for _, entry in ipairs(cache.spells) do
        if entry.search:find(text, 1, true) then Add(entry) end
    end
    local icons, texts, firstNames = cache.spellIcons, cache.spellTexts, cache.spellFirst
    for i = 1, #icons do
        if #results >= MAX_RESULTS then break end
        if texts[i]:find(text, 1, true) then Add({ texture = icons[i], name = firstNames[i] }) end
    end
    for _, name in ipairs(cache.names) do
        if #results >= MAX_RESULTS then break end
        if name:find(text, 1, true) then
            -- As a file ID, so an icon a spell name already found isn't listed twice.
            Add({ texture = ToFileID(ICON_PATH .. name), name = name })
        end
    end
    return results
end

-- Grid widget --

local GridMixin = {}

---@param grid table
---@param button Button
---@param entry CDMIconEntry
local function InitButton(grid, button, entry)
    if not button.icon then
        button.icon = button:CreateTexture(nil, 'ARTWORK')
        button.icon:SetAllPoints()
        button.icon:NUISetZoom()
        button:NUIAddBorders()
        local highlight = button:CreateTexture(nil, 'HIGHLIGHT')
        highlight:NUISetPixelInside(button, 1, 1)
        highlight:SetColorTexture(1, 1, 1, 0.2)
        highlight:SetBlendMode('ADD')
        button:RegisterForClicks('LeftButtonUp')
        button:SetScript('OnClick', function(self)
            if self.grid.onPick then self.grid.onPick(ToFileID(self.entry.texture)) end
        end)
        button:SetScript('OnEnter', function(self)
            local accent, secondary = Theme.accent, Theme.textSecondary
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            GameTooltip:SetText(self.entry.name or L['Icon'], accent[1], accent[2], accent[3], 1, false) -- unwrapped, so the tooltip widens to the name
            GameTooltip:AddLine(tostring(self.entry.texture), secondary[1], secondary[2], secondary[3], false)
            GameTooltip:Show()
        end)
        button:SetScript('OnLeave', function() GameTooltip:Hide() end)
    end

    button.entry = entry
    button.grid = grid
    button.icon:SetTexture(entry.texture)
    local picked = grid.selected ~= nil and ToFileID(entry.texture) == grid.selected
    local color = picked and Theme.accent or Theme.border
    button:SetBorderColor(color[1], color[2], color[3], 1)
end

---@param icons CDMIconEntry[]
---@param searched boolean? a search ran and found nothing, rather than nothing typed yet
function GridMixin:SetIcons(icons, searched)
    self.scrollBox:SetDataProvider(CreateDataProvider(icons))
    local hint = not (cache and cache.ready) and L['Loading icons...'] or searched and L['No icons found.'] or L['Type a name or an ID to search.']
    self.hint:SetText(hint)
    self.hint:SetShown(icons[1] == nil)
end

function GridMixin:OnAcquire(parent, _, config)
    self:SetParent(parent)
    self:ClearAllPoints()
    self.onPick = config.onPick
    self.selected = config.selected
    self:Show()
    self:SetIcons(config.icons or {}, config.searched)
end

function GridMixin:OnRelease()
    self.onPick, self.selected = nil, nil
    self.scrollBox:RemoveDataProvider()
end

NRSKNUI.Libs.KAJI:RegisterWidgetType(GRID_TYPE, function()
    local frame = Mixin(CreateFrame('Frame'), GridMixin)

    local scrollBox = CreateFrame('Frame', nil, frame, 'WowScrollBoxList')
    scrollBox:SetPoint('TOPLEFT')
    scrollBox:SetPoint('BOTTOMRIGHT', -14, 0)
    frame.scrollBox = scrollBox

    local hint = frame:CreateFontString(nil, 'OVERLAY')
    NRSKNUI.GUI:ApplyFont(hint, 'normal')
    hint:SetTextColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 1)
    hint:SetPoint('TOP', frame, 'TOP', 0, -16)
    frame.hint = hint

    local scrollBar = CreateFrame('EventFrame', nil, frame, 'MinimalScrollBar')
    scrollBar:SetPoint('TOPLEFT', scrollBox, 'TOPRIGHT', 4, 0)
    scrollBar:SetPoint('BOTTOMLEFT', scrollBox, 'BOTTOMRIGHT', 4, 0)
    NRSKNUI:GetModule('Skinning'):HandleTrimScrollBar(scrollBar)

    local view = CreateScrollBoxListGridView(1, 0, 0, 0, 0, SPACING, SPACING)
    view:SetStrideExtent(BUTTON_SIZE) -- columns follow the width; the view adds the spacing itself
    view:SetElementInitializer('NRSKNUI_IconPickerButtonTemplate', function(button, entry) InitButton(frame, button, entry) end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    return frame
end)

-- Page --

IconPicker.PAGE = 'cdm:iconpicker'

local state = { search = '' } ---@type { search: string, value: number|string?, apply: fun(texture: number|string)?, returnKey: string? }

---Open the picker for one icon field; `apply` stores the pick, then the page goes back to the display.
---GUI-CDM sets `navigate` (its Reopen) and `currentKey` (the display being edited).
---@param value number|string? the field's current icon
---@param apply fun(texture: number|string)
function IconPicker:Open(value, apply)
    state.value, state.apply, state.returnKey = value, apply, self.currentKey
    state.search = ''
    self.navigate(self.PAGE)
end

local function Back()
    IconPicker.navigate(state.returnKey)
end

---The picker page is gone: a load still running finishes without refreshing it.
function IconPicker:Release()
    onLoaded = nil
end

---@param page table
function IconPicker:Build(page)
    page:SetEnabled(function() return CDM.db.Enabled end)
    local grid, timer

    local header = page:Card(L['Choose an Icon'], 'all'):HeaderButton({
        texture = 'Interface\\AddOns\\NorskenUI\\Media\\GUITextures\\right-arrow.png',
        size = 20,
        rotation = math.pi,
        tooltip = L['Back'],
        onClick = Back,
    })
    local row = header:Row(NRSKNUI.Theme.rowHeightLast, 0)
    row:EditBox(L['Search'], {
        width = 0.9,
        value = state.search,
        tooltip = L['An icon or spell name, or a file, spell or item ID.'],
        onTextChanged = function(text)
            state.search = text
            if timer then timer:Cancel() end
            timer = C_Timer.NewTimer(SEARCH_DELAY, function() grid:SetIcons(Search(state.search), strtrim(state.search) ~= '') end)
        end,
    })
    row:Icon({ width = 0.1, size = 24, yOffset = -14, texture = state.value or QUESTION_MARK })

    grid = page:Card(nil, 'all'):Row(GRID_HEIGHT, 0):Widget(GRID_TYPE, nil, {
        width = 1,
        icons = Search(state.search),
        searched = strtrim(state.search) ~= '',
        selected = state.value,
        onPick = function(texture)
            if state.apply then state.apply(texture) end
            if CDM:Get(state.returnKey) then CDM:ApplySettings(state.returnKey) end
            Back()
        end,
    })
    -- Anything typed while the lists were loading is searched as soon as they're in.
    EnsureLoaded(function() grid:SetIcons(Search(state.search), strtrim(state.search) ~= '') end)
end

---The small icon beside an Icon ID box: shows the current icon and opens the picker.
---@param row table
---@param value number|string?
---@param onClick fun()
---@param conditions string[]? the box's own page conditions, so both grey out together
function IconPicker:BrowseButton(row, value, onClick, conditions)
    row:Icon({
        width = 0.1,
        size = 24,
        yOffset = -14,
        conditions = conditions,
        texture = value or QUESTION_MARK,
        tooltip = L['Browse icons'],
        onClick = function(button) if button == 'LeftButton' then onClick() end end,
    })
end
