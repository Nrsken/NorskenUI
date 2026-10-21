--[[
# Page

* The fluent authoring layer over CardStack + StateManager.
* Creates a page bound to a scroll child, then lets you add cards and widgets in a fluent style.
* The page tracks all widgets and cards, registers them with the manager and handles reflow and refresh when cards are rebuilt.

## Example

    local page = GUI:CreatePage(scrollChild, yOffset, { enabled = function() return db.Enabled end })
    page:SetCondition('custom', function() return db.Mode == 'custom' end)

    local AppearancePage = page:Card('Appearance', 'all')
    AppearancePage:Rebuild(function(card)
        local row = card:Row(40)
        row:Dropdown('Style', {
            width = 0.5,
            options = opts,
            value = db.Mode,
            callback = function(v)
                db.Mode = v
                card:Rebuild()
            end,
        })
    end)

    return page:Finish()

--]]

local lib = LibStub and LibStub("LibKaji-1.0", true)
if not lib then return end
---@class KajiGUIInstanceMixin
local InstanceMixin = lib.InstanceMixin

local ipairs = ipairs
local pairs = pairs
local pi = math.pi
local wipe = wipe
local unpack = unpack
local setmetatable = setmetatable

---Widget config for fluent card methods. All fields are optional, defaults are applied in the fluent layer.
---@class KajiGUIWidgetConfig
---@field width? number widthPct passed to AddWidget (defaults to 0.5)
---@field spacing? number
---@field xOffset? number
---@field yOffset? number
---@field conditions? string[] extra condition groups on top of the card's group
---@field master? boolean if true the widget is left ungated (never disabled)

-- Fluent Row --

---@class KajiGUIFluentRow
---@field real KajiGUIRow the underlying row frame
---@field card KajiGUIFluentCard owning card
local FluentRow = {}
local FluentRowMeta = { __index = FluentRow }

---Adds a widget to the row and registers it with the manager.
---@param constructor string GUI:Create* method name
---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:_Add(constructor, label, config)
    config = config or {}
    local gui = self.card.page.gui
    local widget = gui[constructor](gui, self.real, label, config)
    self.real:AddWidget(widget, config.width or config.widthPct, config.spacing, config.xOffset, config.yOffset)
    self.card:_Track(widget, config)
    return widget
end

---Adds a widget of any registered type, for host widgets with no fluent shortcut.
---@param widgetType string
---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:Widget(widgetType, label, config)
    config = config or {}
    local gui = self.card.page.gui
    local widget = gui:BuildWidget(widgetType, self.real, label, config)
    self.real:AddWidget(widget, config.width or config.widthPct, config.spacing, config.xOffset, config.yOffset)
    self.card:_Track(widget, config)
    return widget
end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:Checkbox(label, config) return self:_Add("CreateCheckbox", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:SlimCheckbox(label, config) return self:_Add("CreateSlimCheckbox", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig|KajiGUIRadioConfig
---@return Frame widget
function FluentRow:Radio(label, config) return self:_Add("CreateRadio", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:Slider(label, config) return self:_Add("CreateSlider", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:Dropdown(label, config) return self:_Add("CreateDropdown", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:Button(label, config) return self:_Add("CreateButton", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:ColorPicker(label, config) return self:_Add("CreateColorPicker", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:EditBox(label, config) return self:_Add("CreateEditBox", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:MultiLineEditBox(label, config) return self:_Add("CreateMultiLineEditBox", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:Text(label, config) return self:_Add("CreateText", label, config) end

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return KajiGUIAnchorPicker widget
function FluentRow:AnchorPicker(label, config) return self:_Add("CreateAnchorPicker", label, config) end

---Equal shares come out equally wide (a grid of tiles), instead of starting each widget at its share of the row.
---@return self
function FluentRow:Even()
    self.real._even = true
    return self
end

---Draws a thin rule along the row's bottom edge, for table-like lists.
---@return KajiGUIFluentRow
function FluentRow:Divider()
    self.real:SetDivider(true)
    return self
end

---Puts a light band behind the row; give it to every other row of a long list.
---@param shown? boolean defaults to true
---@return KajiGUIFluentRow
function FluentRow:Stripe(shown)
    self.real:SetStripe(shown ~= false)
    return self
end

---Icon has a (parent, config) signature, so it gets its own method.
---@param config? KajiGUIWidgetConfig|KajiGUIIconConfig
---@return KajiGUIIcon widget
function FluentRow:Icon(config)
    config = config or {}
    local gui = self.card.page.gui
    local widget = gui:CreateIcon(self.real, config)
    self.real:AddWidget(widget, config.width or config.widthPct, config.spacing, config.xOffset, config.yOffset)
    self.card:_Track(widget, config)
    return widget
end

-- Fluent Card --

---@class KajiGUIFluentCard
---@field real KajiGUICard the underlying card
---@field page KajiGUIPage owning page
---@field defaultGroup? string condition group every widget in this card inherits
---@field widgets Frame[] manager-registered widgets, cleared on rebuild
---@field buildFn? fun(card: KajiGUIFluentCard)
local FluentCard = {}
local FluentCardMeta = { __index = FluentCard }

---Tracks a widget with the page's manager, unless config.master is true. The widget inherits the card's defaultGroup and any extra groups in config.conditions.
---@param widget Frame
---@param config table
function FluentCard:_Track(widget, config)
    if config.master then return end

    local groups = {}
    if self.defaultGroup then groups[#groups + 1] = self.defaultGroup end
    if config.conditions then
        for _, condition in ipairs(config.conditions) do
            groups[#groups + 1] = condition
        end
    end

    if #groups > 0 then
        self.page.manager:Register(widget, unpack(groups))
        self.widgets[#self.widgets + 1] = widget
    end
end

---Adds a row to the card.
---@param height number
---@param spacing? number trailing spacing; pass 0 for the last row in a card
---@param indent? number left inset; the widgets share the width that is left
---@return KajiGUIFluentRow
function FluentCard:Row(height, spacing, indent)
    local row = self.page.gui:CreateRow(self.real.content, height, indent)
    self.real:AddRow(row, height, spacing)
    return setmetatable({ real = row, card = self }, FluentRowMeta)
end

---Changes the card's title.
---@param title string
---@return self
function FluentCard:SetTitle(title)
    self.real:SetTitle(title)
    return self
end

---Gives the card its own enable logic, for cards whose controls gate each other.
---The card is deferred in the state manager, so `fn(enabled)` runs after every plain
---widget has been set and its derivation wins. Stored as a field, not a script, so a
---rebuild replaces it cleanly.
---@param fn fun(enabled: boolean)
---@return self
function FluentCard:SetEnabledHandler(fn)
    self.real._hasInternalWidgetState = true
    self.real._enabledHandler = fn
    return self
end

---Registers a callback the host can invoke to re-read outside state back into this card,
---e.g. GUI:RefreshPositionCards after a mover drag. Stored on the frame as a field, so a
---rebuild replaces it and a release drops it with the card. A no-op on the frameless
---search collector.
---@param fn fun()
---@return self
function FluentCard:OnExternalRefresh(fn)
    self.real._refreshPositions = fn
    return self
end

---Adds a collapsible section header and reports whether its body should be built.
---
---A section owns no rows: the header is a plain row in the card's flow, and collapsing is this
---returning false so the caller simply does not emit the body. That keeps repeating lists working
---with :Rebuild and needs nothing from the card's layout.
---
---    if card:Section('1. Buffs', { collapsed = state.closed, onToggle = Toggle, onDelete = Delete }) then
---        card:Row(rowH):Dropdown('Base', {...})
---    end
---
---The body animates and runs until the next Section, a Separator or :EndSection.
---@param title string
---@param config? { key?: any, collapsed?: boolean, onToggle?: fun(), onMoveUp?: fun(), onMoveDown?: fun(), onDuplicate?: fun(), onDelete?: fun() }
---@return boolean expanded
---@return KajiGUISectionHeader header for SetTitle/SetSummary while its settings change
function FluentCard:Section(title, config)
    config = config or {}
    local real = self.real
    real:EndBody()

    -- Sections are told apart by their place in the card unless given a key: titles carry counts that change.
    self._sectionCount = (self._sectionCount or 0) + 1
    local key = config.key or self._sectionCount

    local header
    local headerConfig = {}
    for k, v in pairs(config) do headerConfig[k] = v end
    headerConfig.onToggle = config.onToggle and function()
        local running = real:GetSectionAnim(key)
        if running and running.to == 0 then
            -- Turned round while closing: the section never closed, so the caller is not told.
            real:AnimateSection(key, 1).header = header
        elseif config.collapsed then
            real:AnimateSection(key, 1).header = header
            config.onToggle()
        else
            -- The arrow turns with the body; a rebuild hands the new header over.
            real:AnimateSection(key, 0, config.onToggle).header = header
        end
    end

    header = self.page.gui:CreateSectionHeader(real.content, title, headerConfig)
    header._layoutIndent = nil -- a pooled header may last have been a sub-section's
    real:AddRow(header, header.layoutHeight)

    local anim = real:GetSectionAnim(key)
    if anim then
        anim.header = header
        header.arrow:SetRotation((1 - anim.p) * pi / 2)
    end

    if not config.collapsed then real:BeginBody(key) end
    return not config.collapsed, header
end

---Ends the current section's body, for rows after it that belong to the card itself.
---@return self
function FluentCard:EndSection()
    self.real:EndBody()
    return self
end

---A collapsible header inside an open section, with its own animated body, for the less used settings
---of that section. Runs until the next SubSection, :EndSubSection, or the section's end.
---@param title string
---@param config { key: any, collapsed?: boolean, summary?: string, onToggle?: fun(), indent?: number }
---@return boolean expanded
---@return KajiGUISectionHeader header for SetSummary while its settings change
function FluentCard:SubSection(title, config)
    local real = self.real
    real:EndNestedBody()
    local key = config.key

    local header
    local headerConfig = { collapsed = config.collapsed, summary = config.summary }
    headerConfig.onToggle = config.onToggle and function()
        local running = real:GetSectionAnim(key)
        if running and running.to == 0 then
            real:AnimateSection(key, 1).header = header
        elseif config.collapsed then
            real:AnimateSection(key, 1).header = header
            config.onToggle()
        else
            real:AnimateSection(key, 0, config.onToggle).header = header
        end
    end

    header = self.page.gui:CreateSectionHeader(real.content, title, headerConfig)
    header._layoutIndent = config.indent
    real:AddRow(header, header.layoutHeight)

    local anim = real:GetSectionAnim(key)
    if anim then
        anim.header = header
        header.arrow:SetRotation((1 - anim.p) * pi / 2)
    end

    if not config.collapsed then real:BeginBody(key, true) end
    return not config.collapsed, header
end

---Ends the current sub-section's body; rows after it belong to the section around it again.
---@return self
function FluentCard:EndSubSection()
    self.real:EndNestedBody()
    return self
end

---Adds a full-width separator row; with config.useLabel it is a labelled heading with its own rule.
---config.inSection keeps it inside the open section instead of ending it; height and spacing
---override the theme's row height and the gap after it.
---@param label? string
---@param config? { useLabel?: boolean, centered?: boolean, height?: number, spacing?: number, inSection?: boolean }
---@return self
---An icon action at the right end of the card's header.
---
---    page:Card('New', 'all'):HeaderButton({ atlas = 'questlog-icon-setting', tooltip = 'Settings', onClick = OpenSettings })
---@param config { atlas?: string, texture?: string|number, size?: number, rotation?: number, tooltip?: string, onClick: fun() }
---@return self
function FluentCard:HeaderButton(config)
    self.real:SetHeaderButton(config)
    return self
end

function FluentCard:Separator(label, config)
    local theme = self.page.gui.theme
    if config and config.inSection then
        self.real:EndNestedBody()
    else
        self.real:EndBody()
    end
    local sep = self.page.gui:CreateSeparator(self.real.content, label, config)
    local height = config and config.height or (config and config.useLabel and theme.rowHeightLabelSeparator or theme.rowHeightSeparator)
    self.real:AddRow(sep, height, config and config.spacing)
    return self
end

---Rebuilds the card by clearing all widgets and calling the buildFn again. If a new buildFn is provided, it replaces the old one.
---@param buildFn? fun(card: KajiGUIFluentCard)
---@return self
function FluentCard:Rebuild(buildFn)
    if buildFn then self.buildFn = buildFn end

    for _, widget in ipairs(self.widgets) do
        self.page.manager:Unregister(widget)
    end
    wipe(self.widgets)

    local function Build()
        self._sectionCount = 0
        self.real:Reset()
        if self.buildFn then self.buildFn(self) end
        self.real:EndBody()
    end

    -- During initial construction Finish() does the first layout/refresh, only reflow eagerly once the page is live.
    if not self.page.built then
        Build()
        return self
    end

    -- Laid out once at the end: a pass over the half-built card would cost the reader their scroll position.
    self.page.stack:Batch(Build)
    self.page:Refresh()

    return self
end

-- Page --

---@class KajiGUIPage
---@field gui KajiGUIInstance
---@field parent Frame scroll child
---@field manager KajiGUIStateManager
---@field stack KajiGUICardStack
---@field enabledFn? fun(): boolean
---@field cards KajiGUIFluentCard[]
---@field built boolean
local Page = {}
local PageMeta = { __index = Page }

---Sets a named condition on the underlying manager.
---@param name string
---@param fn fun(): boolean
---@return self
function Page:SetCondition(name, fn)
    self.manager:SetCondition(name, fn)
    return self
end

---Sets the predicate that gates every widget on the page. Call inside a page build before Finish.
---@param fn fun(): boolean
---@return self
function Page:SetEnabled(fn)
    self.enabledFn = fn
    return self
end

---@return boolean
function Page:IsEnabled()
    if self.enabledFn then return self.enabledFn() and true or false end
    return true
end

---Re-applies enabled/disabled state to every registered widget.
function Page:Refresh()
    self.manager:UpdateAll(self:IsEnabled())
end

---Creates a card in the page.
---@param title string
---@param group? string condition group the card and its widgets inherit (e.g. 'all')
---@return KajiGUIFluentCard
function Page:Card(title, group)
    local real = self.gui:CreateCard(self.parent, title, 0)
    self.stack:Add(real)
    if group then self.manager:Register(real, group) end

    local card = setmetatable({
        real = real,
        page = self,
        defaultGroup = group,
        widgets = {},
    }, FluentCardMeta)
    self.cards[#self.cards + 1] = card
    return card
end

-- Premade cards --

--[[
Premade cards are ordinary fluent builds. Each Widgets/*Card.lua registers
`lib.premadeCards[name] = { title = …, build = function(card, config, gui) … end }`
and the build runs through `card:Rebuild`, so widget tracking, condition groups,
in-place rebuilds and the frameless search collector all work with no special
casing. `card:Rebuild()` with no argument re-runs the stored builder.
--]]

---Builds a registered premade card into the page.
---@param name string key in lib.premadeCards
---@param config? table card config, `title` overrides the card's default
---@param group? string condition group (defaults to 'all')
---@return KajiGUIFluentCard
function Page:PremadeCard(name, config, group)
    local def = lib.premadeCards and lib.premadeCards[name]
    if not def then error("Unknown premade card '" .. tostring(name) .. "'", 2) end

    config = config or {}
    local gui = self.gui
    local card = self:Card(config.title or def.title, group or "all")
    return card:Rebuild(function(fluent) def.build(fluent, config, gui) end)
end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:PositionCard(config, group) return self:PremadeCard("PositionCard", config, group) end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:DynamicGroupCard(config, group) return self:PremadeCard("DynamicGroupCard", config, group) end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:FontSettingsCard(config, group) return self:PremadeCard("FontSettingsCard", config, group) end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:SparkSettingsCard(config, group) return self:PremadeCard("SparkSettingsCard", config, group) end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:BackdropColorsCard(config, group) return self:PremadeCard("BackdropColorsCard", config, group) end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:TextFormatCard(config, group) return self:PremadeCard("TextFormatCard", config, group) end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:GlowSettingsCard(config, group) return self:PremadeCard("GlowSettingsCard", config, group) end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:LoadConditionsCard(config, group) return self:PremadeCard("LoadConditionsCard", config, group) end

---Finalizes the page, performs the first layout and refresh and returns the total height of the page.
---@return number height
function Page:Finish()
    self.built = true
    local height = self.stack:DoLayout()
    self:Refresh()
    return height
end

---Creates a page bound to a scroll child.
---@param scrollChild Frame
---@param topOffset number initial y offset
---@param opts? { enabled?: fun(): boolean, onLayout?: fun(height: number) }
---@return KajiGUIPage
function InstanceMixin:CreatePage(scrollChild, topOffset, opts)
    opts = opts or {}
    return setmetatable({
        gui = self,
        parent = scrollChild,
        manager = self:CreateStateManager(),
        stack = self:CreateCardStack(scrollChild, topOffset, opts.onLayout),
        enabledFn = opts.enabled,
        cards = {},
        built = false,
    }, PageMeta)
end
