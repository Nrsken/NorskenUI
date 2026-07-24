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

---Adds a premade card (constructed via a gui:Create*Card returning card, _, widgets)
---to the page and registers its widgets. When wireRebuild is true, the card can
---rebuild its body in place (e.g. on a structural dropdown change) without a full
---page refresh: drop the old inner widgets, register the new set, reflow.
---@param page KajiGUIPage
---@param real KajiGUICard
---@param widgets? Frame[]
---@param group string
---@param wireRebuild boolean
---@return KajiGUICard real
local function AddPremadeCard(page, real, widgets, group, wireRebuild)
    page.stack:Add(real)
    page.manager:Register(real, group)
    if widgets then page.manager:RegisterGroup(widgets, group) end

    if wireRebuild then
        real._onBeforeRebuild = function(oldWidgets)
            for _, widget in ipairs(oldWidgets) do page.manager:Unregister(widget) end
        end
        real._onAfterRebuild = function(newWidgets)
            page.manager:RegisterGroup(newWidgets, group)
            page.stack:DoLayout()
            page:Refresh()
        end
    end

    return real
end

---Adds a premade PositionCard to the page and registers its widgets.
---@param config table CreatePositionCard config
---@param group? string condition group (defaults to 'all')
---@return KajiGUICard real the underlying position card
function Page:PositionCard(config, group)
    group = group or "all"
    local real, _, widgets = self.gui:CreatePositionCard(self.parent, 0, config)
    return AddPremadeCard(self, real, widgets, group, true)
end

---Adds a premade DynamicGroupCard to the page and registers its widgets.
---@param config table CreateDynamicGroupCard config
---@param group? string condition group (defaults to 'all')
---@return KajiGUICard real
function Page:DynamicGroupCard(config, group)
    group = group or "all"
    local real, _, widgets = self.gui:CreateDynamicGroupCard(self.parent, 0, config)
    return AddPremadeCard(self, real, widgets, group, true)
end

---Adds a premade FontSettingsCard to the page and registers its widgets.
---@param config table CreateFontSettingsCard config
---@param group? string condition group (defaults to 'all')
---@return KajiGUICard real
function Page:FontSettingsCard(config, group)
    group = group or "all"
    local real, _, widgets = self.gui:CreateFontSettingsCard(self.parent, 0, config)
    return AddPremadeCard(self, real, widgets, group, false)
end

---Adds a premade TextFormatCard to the page and registers its widgets.
---@param config table CreateTextFormatCard config
---@param group? string condition group (defaults to 'all')
---@return KajiGUICard real
function Page:TextFormatCard(config, group)
    group = group or "all"
    local real, _, widgets = self.gui:CreateTextFormatCard(self.parent, 0, config)
    return AddPremadeCard(self, real, widgets, group, false)
end

---Adds a premade GlowSettingsCard to the page and registers its widgets.
---The card rebuilds its body in place when the glow type changes.
---@param config table CreateGlowSettingsCard config
---@param group? string condition group (defaults to 'all')
---@return KajiGUICard real
function Page:GlowSettingsCard(config, group)
    group = group or "all"
    local real, _, widgets = self.gui:CreateGlowSettingsCard(self.parent, 0, config)
    return AddPremadeCard(self, real, widgets, group, true)
end

---Adds a premade LoadConditionsCard to the page and registers its widgets.
---The card rebuilds its body in place when enable or the category changes.
---@param config table CreateLoadConditionsCard config
---@param group? string condition group (defaults to 'all')
---@return KajiGUICard real
function Page:LoadConditionsCard(config, group)
    group = group or "all"
    local real, _, widgets = self.gui:CreateLoadConditionsCard(self.parent, 0, config)
    return AddPremadeCard(self, real, widgets, group, true)
end

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
