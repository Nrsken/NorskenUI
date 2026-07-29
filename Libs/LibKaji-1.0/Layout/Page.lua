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

---@param label? string
---@param config? KajiGUIWidgetConfig
---@return Frame widget
function FluentRow:Checkbox(label, config) return self:_Add("CreateCheckbox", label, config) end

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

---Icon has a (parent, config) signature, so it gets its own method.
---@param config? KajiGUIWidgetConfig
---@return Frame widget
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
---@return KajiGUIFluentRow
function FluentCard:Row(height, spacing)
    local row = self.page.gui:CreateRow(self.real.content, height)
    self.real:AddRow(row, height, spacing)
    return setmetatable({ real = row, card = self }, FluentRowMeta)
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

---Adds a full-width separator row.
---@return self
function FluentCard:Separator()
    local sep = self.page.gui:CreateSeparator(self.real.content)
    self.real:AddRow(sep, self.page.gui.theme.rowHeightSeparator)
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

    self.real:Reset()
    if self.buildFn then self.buildFn(self) end

    -- During initial construction Finish() does the first layout/refresh, only reflow eagerly once the page is live.
    if self.page.built then
        self.page.stack:DoLayout()
        self.page:Refresh()
    end

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
function Page:TextFormatCard(config, group) return self:PremadeCard("TextFormatCard", config, group) end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:GlowSettingsCard(config, group) return self:PremadeCard("GlowSettingsCard", config, group) end

---@param config table
---@param group? string
---@return KajiGUIFluentCard
function Page:FilterCard(config, group) return self:PremadeCard("FilterCard", config, group) end

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
