--[[
# LibKaji-1.0

* A GUI/utility library for WoW addons by Norsken: windows, sidebars, pages, cards and widgets with consistent theming and behavior.
* Also exposes a standalone set of pixel-snapping utilities (`lib.Pixel`), usable without the GUI.
* Every consumer gets its own instance, so two addons embedding the library never share theme or state.

## Example

    local GUI = LibStub('LibKaji-1.0'):New({
        store = function() return MyAddonDB.theme end,
        classColorProvider = function() return MyAddon:GetClassColor() end
    })

    local window = GUI:CreateGUIWindow({ name = 'MyAddonGUI', defaultPage = 'general' })

    GUI:RegisterPage('general', {
        build = function(page)
            page:Card('Options', 'all'):Row(40):Checkbox('Enable', {
                value = db.Enabled,
                callback = function(v) db.Enabled = v end
            })
        end
    })

--]]

local addonName = ...
local MAJOR, MINOR = "LibKaji-1.0", 1
assert(LibStub, MAJOR .. " requires LibStub")
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end -- a newer or equal version is already loaded

-- Base path for this lib's bundled textures.
lib.mediaBase = "Interface\\AddOns\\" .. addonName .. "\\Libs\\" .. MAJOR .. "\\Media\\"

local Mixin = Mixin

-- Method table shared by every instance.
lib.InstanceMixin = lib.InstanceMixin or {}
local InstanceMixin = lib.InstanceMixin

---Systems that can be provided by the consuming addon to extend the library's functionality.
---@class KajiGUIServices
---@field editMode? table the addon's edit-mode system (for PositionCard)
---@field frameChooser? table the addon's frame picker (for PositionCard)
---@field registerSearchable? fun(widget: Frame, label: string) host search-index hook

---@class KajiGUIOptions
---@field theme? table overrides merged over the library's default theme
---@field editMode? table
---@field frameChooser? table
---@field registerSearchable? fun(widget: Frame, label: string)
---@field overlay? Frame high-strata frame open dropdowns reparent to (defaults to UIParent)
---@field store? fun(): table? accessor to the host's persisted theme table (mode/selectedPreset/customColors/fonts)
---@field classColorProvider? fun(): number[] returns the active class color {r,g,b} for class mode
---@field presets? table override the bundled preset set (defaults to lib.THEME_PRESETS)
---@field presetNames? string[] override the ordered preset name list (defaults to lib.THEME_PRESET_NAMES)
---@field colorKeys? table[] override the color-key editor metadata (defaults to lib.THEME_COLOR_KEYS)
---@field defaultPreset? string preset used before the store exists / on reset (defaults to "NUI v2")

---Creates an isolated GUI instance for a consuming addon.
---@param opts? KajiGUIOptions
---@return KajiGUIInstance
function lib:New(opts)
    opts = opts or {}

    ---@class KajiGUIInstance : KajiGUIInstanceMixin
    local instance = Mixin({}, InstanceMixin)

    ---@type KajiGUIServices
    instance.services = {
        editMode = opts.editMode,
        frameChooser = opts.frameChooser,
        registerSearchable = opts.registerSearchable,
    }
    instance.overlay = opts.overlay

    -- Theme engine wiring.
    instance.presets            = opts.presets or lib.THEME_PRESETS
    instance.presetNames        = opts.presetNames or lib.THEME_PRESET_NAMES
    instance.colorKeys          = opts.colorKeys or lib.THEME_COLOR_KEYS
    instance.defaultPreset      = opts.defaultPreset or "NUI v2"
    instance._storeAccessor     = opts.store
    instance.classColorProvider = opts.classColorProvider

    instance:_InitTheme(opts.theme)

    return instance
end

---@class KajiGUIInstanceMixin
---@field CreateGUIWindow fun(self: KajiGUIInstance, opts?: KajiGUIWindowOptions): KajiGUIWindow
---@field RegisterPage fun(self: KajiGUIInstance, id: string, descriptor: table): void
---@field GetTheme fun(self: KajiGUIInstance): table
---@field ApplyTheme fun(self: KajiGUIInstance): KajiGUIInstance
---@field OnThemeChanged fun(self: KajiGUIInstance, callback: fun()): void
---@field GetMode fun(self: KajiGUIInstance): string
---@field SetMode fun(self: KajiGUIInstance, mode: string): KajiGUIInstance
---@field GetPresetNames fun(self: KajiGUIInstance): string[]
---@field GetSelectedPreset fun(self: KajiGUIInstance): string
---@field SetPreset fun(self: KajiGUIInstance, name: string): KajiGUIInstance
---@field GetPreset fun(self: KajiGUIInstance, name: string): table|nil
---@field GetColorKeys fun(self: KajiGUIInstance): table[]
---@field GetCustomColor fun(self: KajiGUIInstance, key: string): number, number, number, number
---@field SetCustomColor fun(self: KajiGUIInstance, key: string, r: number, g: number, b: number, a?: number): KajiGUIInstance
---@field CopyPresetToCustom fun(self: KajiGUIInstance, name: string): KajiGUIInstance
---@field ResetCustomColors fun(self: KajiGUIInstance): KajiGUIInstance
---@field ResetTheme fun(self: KajiGUIInstance): KajiGUIInstance
---@field Color fun(self: KajiGUIInstance, key: string): number, number, number, number
---@field RGBAToHex fun(self: KajiGUIInstance, r: number, g: number, b: number): string
---@field ColorText fun(self: KajiGUIInstance, text: string): string
---@field FlashMessage fun(self: KajiGUIInstance, text: string, opts?: table): Frame
---@field Prompt fun(self: KajiGUIInstance, opts: KajiPromptOptions): Frame
---@field CopyDialog fun(self: KajiGUIInstance, title: string, text: string, label?: string): Frame
---@field ShowContextMenu fun(self: KajiGUIInstance, entries: table[]): void
