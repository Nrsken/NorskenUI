---@meta

-- Annotations for NorskenUI addon

---@class NRSKNUI.AceHook
---@field Hook fun(self: NRSKNUI.AceHook, obj: any, method?: any, handler?: any, secure?: boolean)
---@field RawHook fun(self: NRSKNUI.AceHook, obj: any, method?: any, handler?: any, secure?: boolean)
---@field SecureHook fun(self: NRSKNUI.AceHook, obj: any, method?: any, handler?: any)
---@field HookScript fun(self: NRSKNUI.AceHook, frame: Frame, script: string, handler?: any)
---@field RawHookScript fun(self: NRSKNUI.AceHook, frame: Frame, script: string, handler?: any)
---@field SecureHookScript fun(self: NRSKNUI.AceHook, frame: Frame, script: string, handler?: any)
---@field Unhook fun(self: NRSKNUI.AceHook, obj: any, method?: string)
---@field UnhookAll fun(self: NRSKNUI.AceHook)
---@field IsHooked fun(self: NRSKNUI.AceHook, obj: any, method?: string): boolean

---AceDB-3.0 database object (fields created dynamically by AceDB, so declared here for the language server).
---@class NRSKNUI.AceDB
---@field profile table Active profile settings
---@field global table Account-wide settings
---@field char table Character-specific settings
---@field profiles table<string, table> All stored profiles
---@field defaults table|nil Registered defaults
---@field RegisterCallback fun(target: table, eventName: string, callback: function|string) CallbackHandler registration (dot-call)
---@field UnregisterCallback fun(target: table, eventName: string)
---@field CheckDualSpecState fun(db: NRSKNUI.AceDB)|nil Added by LibDualSpec-1.0
---@field SetProfile fun(self: NRSKNUI.AceDB, name: string)
---@field GetCurrentProfile fun(self: NRSKNUI.AceDB): string
---@field GetProfiles fun(self: NRSKNUI.AceDB, tbl?: table): string[], number
---@field CopyProfile fun(self: NRSKNUI.AceDB, name: string, silent?: boolean)
---@field DeleteProfile fun(self: NRSKNUI.AceDB, name: string, silent?: boolean)
---@field ResetProfile fun(self: NRSKNUI.AceDB, noChildren?: boolean, noCallbacks?: boolean)
---@field ResetDB fun(self: NRSKNUI.AceDB, defaultProfile?: string): NRSKNUI.AceDB
---@field RegisterDefaults fun(self: NRSKNUI.AceDB, defaults: table)
---@field RegisterNamespace fun(self: NRSKNUI.AceDB, name: string, defaults?: table): NRSKNUI.AceDB
---@field GetNamespace fun(self: NRSKNUI.AceDB, name: string, silent?: boolean): NRSKNUI.AceDB|nil
---@field anchorFrameType string e.g 'UIPARENT'
---@field ParentFrame string e.g 'UIParent'

---Base class for anything returned by NRSKNUI:NewModule(...).
---Covers the AceAddon module API plus the AceEvent/AceHook/AceTimer methods
---modules commonly embed, and the custom fields NUI attaches (db, frame).
---@class NRSKNUI.Module
---@field db NRSKNUI.AceDB Per-module namespaced DB (set during init)
---@field frame Frame? Primary display frame, if the module owns one
---@field enabledState boolean
--- AceAddon module methods
---@field GetName fun(self: NRSKNUI.Module): string
---@field IsEnabled fun(self: NRSKNUI.Module): boolean
---@field Enable fun(self: NRSKNUI.Module)
---@field Disable fun(self: NRSKNUI.Module)
---@field SetEnabledState fun(self: NRSKNUI.Module, state: boolean)
--- Lifecycle callbacks (define these on the module itself)
---@field OnInitialize fun(self: NRSKNUI.Module)?
---@field OnEnable fun(self: NRSKNUI.Module)?
---@field OnDisable fun(self: NRSKNUI.Module)?
--- AceEvent-3.0
---@field RegisterEvent fun(self: NRSKNUI.Module, event: string, callback?: string|fun(...), arg?: any)
---@field UnregisterEvent fun(self: NRSKNUI.Module, event: string)
---@field RegisterMessage fun(self: NRSKNUI.Module, message: string, callback?: string|fun(...), arg?: any)
---@field UnregisterMessage fun(self: NRSKNUI.Module, message: string)
---@field SendMessage fun(self: NRSKNUI.Module, message: string, ...: any)
--- AceTimer-3.0
---@field ScheduleTimer fun(self: NRSKNUI.Module, callback: string|fun(), delay: number, ...: any): table
---@field ScheduleRepeatingTimer fun(self: NRSKNUI.Module, callback: string|fun(), delay: number, ...: any): table
---@field CancelTimer fun(self: NRSKNUI.Module, id: table, silent?: boolean): boolean
--- AceHook-3.0
---@field Hook fun(self: NRSKNUI.Module, obj: any, method?: any, handler?: any, secure?: boolean)
---@field HookScript fun(self: NRSKNUI.Module, frame: Frame, script: string, handler?: any)
---@field Unhook fun(self: NRSKNUI.Module, obj: any, method?: string)

-- Skinning Toolkit

---  nil         = clear every own texture (SetTexture/SetAtlas nil) but leave regions live for state-driven frames,
---  'Keyed'     = Recurse known keyed children (NineSlice, Inset, Bg…) then clear own regions,
---  'Kill'      = hide every own texture and block re-show,
---  'Layer'     = hide own textures whose draw layer matches `a`,
---  'Atlas'     = hide own textures whose atlas matches `a`,
---  'ClearHide' = clear + force alpha 0, so state-driven frames can re-atlas but stay invisible,
---  'Alpha'     = only set alpha 0 on own textures, leaving them live.

--   'Layer'/'Atlas' -> a = layer/atlas name, or a set { name = true } of names.
--   'Keyed'         -> a = banish, hide + block re-show, b = alphaZero.

---@class SkinEntry
---@field addonName string?
---@field key string
---@field func fun(S: table)
---@field ran boolean

---@class NUIListRow : Frame
---@field NUISkinned boolean?
---@field Background Texture?
---@field icon Texture?
---@field BgTop Texture?
---@field BgMiddle Texture?
---@field BgBottom Texture?
---@field HighlightBar Texture?
---@field SelectedBar Texture?
---@field Content Frame|NUIListRow|nil
---@field ReputationBar StatusBar?
---@field CurrencyIcon Texture?
---@field Right Texture?
---@field HighlightRight Texture?
---@field ToggleCollapseButton Button?

---@class FontString ---@diagnostic disable-line: class-shadows-builtin
---@field SetFontStyle fun(self: FontString, source: any, size: number?, outline: string?, shadow: table?, skip: boolean?, setOwner: boolean?)
---@field SetFontJustify fun(self: FontString, source: table|string, parent: Frame?, offsetX: number?, offsetY: number?, skip: boolean?)

---@class Font ---@diagnostic disable-line: class-shadows-builtin
---@field SetFontStyle fun(self: Font, source: any, size: number?, outline: string?, shadow: table?, skip: boolean?, setOwner: boolean?)
---@field SetFontJustify fun(self: Font, source: table|string, parent: Frame?, offsetX: number?, offsetY: number?, skip: boolean?)

-- NorskenUI injected widget API. Full docs: Docs/API.md
-- Each method links to its section via the [Documentation] line so the editor hover
-- shows a clickable link, like the built-in WoW API annotations.

---@class Frame ---@diagnostic disable-line: class-shadows-builtin
---@field SetBackgroundColor fun(self: Frame, r: number, g: number, b: number, a: number?)
---@field UpdateBackdropFromDB fun(self: Frame, db: table)
---@field SetBorderColor fun(self: Frame, r: number, g: number, b: number, a: number?)
local Frame

---Strip textures/atlases in a controlled way. `'Keyed'` recurses keyed children then clears own regions.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#striptextures)
---@param stripType? string nil | 'Keyed' | 'Kill' | 'Layer' | 'Atlas' | 'ClearHide' | 'Alpha'
---@param a? string|string[]|boolean 'Layer'/'Atlas': layer/atlas name(s) · 'Keyed': banish (kill)
---@param b? boolean 'Keyed': alphaZero — set alpha 0 instead of clearing
function Frame:StripTextures(stripType, a, b) end

---Build a pixel-perfect backdrop (bg + 4 border edges) and mix in the backdrop API.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#createbackdrop)
---@param template? string 'BorderTemplate' for border only (no background fill)
function Frame:CreateBackdrop(template) end

---Return true if a NorskenUI backdrop was already added.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#hasbackdrop)
---@return boolean hasBackdrop
function Frame:HasBackdrop() end

---Hide safely and reparent to the shared hidden frame.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#banish)
---@param ... string? optional child keys to traverse first, e.g. 'Inset'
function Frame:Banish(...) end

---Position the frame from a config table.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#applyposition)
---@param Config table
---@param setParent? boolean also reparent
function Frame:ApplyPosition(Config, setParent) end

---Walk child FontStrings and apply a font style.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#stylechildfontstrings)
---@param source any
---@param getSize fun(fontString: FontString, parent: Frame): number?
---@param outline? string
---@param shadow? table
---@param skip? boolean
---@param setOwner? boolean
function Frame:StyleChildFontStrings(source, getSize, outline, shadow, skip, setOwner) end

---@class Button ---@diagnostic disable-line: class-shadows-builtin
---@field SetBackgroundColor fun(self: Button, r: number, g: number, b: number, a: number?)
---@field UpdateBackdropFromDB fun(self: Button, db: table)
---@field SetBorderColor fun(self: Button, r: number, g: number, b: number, a: number?)
local Button

---Strip textures/atlases in a controlled way. `'Keyed'` recurses keyed children then clears own regions.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#striptextures)
---@param stripType? string nil | 'Keyed' | 'Kill' | 'Layer' | 'Atlas' | 'ClearHide' | 'Alpha'
---@param a? string|string[]|boolean 'Layer'/'Atlas': layer/atlas name(s) · 'Keyed': banish (kill)
---@param b? boolean 'Keyed': alphaZero — set alpha 0 instead of clearing
function Button:StripTextures(stripType, a, b) end

---Build a pixel-perfect backdrop (bg + 4 border edges) and mix in the backdrop API.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#createbackdrop)
---@param template? string 'BorderTemplate' for border only (no background fill)
function Button:CreateBackdrop(template) end

---Return true if a NorskenUI backdrop was already added.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#hasbackdrop)
---@return boolean hasBackdrop
function Button:HasBackdrop() end

---Hide safely and reparent to the shared hidden frame.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#banish)
---@param ... string? optional child keys to traverse first, e.g. 'Inset'
function Button:Banish(...) end

---Position the frame from a config table.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#applyposition)
---@param Config table
---@param setParent? boolean also reparent
function Button:ApplyPosition(Config, setParent) end

---@class StatusBar ---@diagnostic disable-line: class-shadows-builtin
---@field SetBackgroundColor fun(self: StatusBar, r: number, g: number, b: number, a: number?)
---@field UpdateBackdropFromDB fun(self: StatusBar, db: table)
---@field SetBorderColor fun(self: StatusBar, r: number, g: number, b: number, a: number?)
local StatusBar

---Strip textures/atlases in a controlled way. `'Keyed'` recurses keyed children then clears own regions.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#striptextures)
---@param stripType? string nil | 'Keyed' | 'Kill' | 'Layer' | 'Atlas' | 'ClearHide' | 'Alpha'
---@param a? string|string[]|boolean 'Layer'/'Atlas': layer/atlas name(s) · 'Keyed': banish (kill)
---@param b? boolean 'Keyed': alphaZero — set alpha 0 instead of clearing
function StatusBar:StripTextures(stripType, a, b) end

---Build a pixel-perfect backdrop (bg + 4 border edges) and mix in the backdrop API.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#createbackdrop)
---@param template? string 'BorderTemplate' for border only (no background fill)
function StatusBar:CreateBackdrop(template) end

---Return true if a NorskenUI backdrop was already added.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#hasbackdrop)
---@return boolean hasBackdrop
function StatusBar:HasBackdrop() end

---Hide safely and reparent to the shared hidden frame.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#banish)
---@param ... string? optional child keys to traverse first, e.g. 'Inset'
function StatusBar:Banish(...) end

---Position the frame from a config table.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#applyposition)
---@param Config table
---@param setParent? boolean also reparent
function StatusBar:ApplyPosition(Config, setParent) end

---@class Texture ---@diagnostic disable-line: class-shadows-builtin
local Texture

---Strip this texture (clear, or per `stripType`). Same modes as the frame version.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#striptextures)
---@param stripType? string nil | 'Keyed' | 'Kill' | 'Layer' | 'Atlas' | 'ClearHide' | 'Alpha'
---@param a? string|string[]|boolean 'Layer'/'Atlas': layer/atlas name(s) · 'Keyed': banish (kill)
---@param b? boolean 'Keyed': alphaZero — set alpha 0 instead of clearing
function Texture:StripTextures(stripType, a, b) end

---Apply a zoom crop via SetTexCoord (uses NRSKNUI.GlobalZoom when omitted).
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#setzoom-texture)
---@param zoom? number
function Texture:SetZoom(zoom) end

---@class _G
---@field StaticPopup1Button1 Button

---@class SkinColors
---@field border RGBA
---@field background RGBA
---@field panel RGBA
---@field accent RGBA

---@class SkinnedBackdropMixin : PublicBackdropMixin
---@field NUIBgAlpha number?

---@class SkinnedIconBackdropMixin : Frame, PublicBackdropMixin

---@class SkinnedButtonMixin : Button
---@field NUIBackdrop Frame & PublicBackdropMixin

---@class SkinnedCloseButtonMixin : Button
---@field NUIBtnCross Texture

---@class SkinnedTabMixin : Button
---@field NUIBackdrop Frame & PublicBackdropMixin
---@field NUISelected boolean?

---@class SkinnedThumbMixin : Frame
---@field NUIBackdrop Frame & PublicBackdropMixin
---@field NUIHover boolean?
---@field NUIActive boolean?

---@class ScrollBox : Frame
---@field ForEachFrame fun(self: ScrollBox, callback: fun(child: Frame))
---@field Update fun(self: ScrollBox)
---@field NUIHooked? boolean

---@class NUIEditBox : EditBox
---@field searchIcon? Texture
---@field NUISkinned? boolean

---@class SkinnedCheckMixin : CheckButton

---@class SkinnedItemButtonMixin : Button
---@field NUIQualityShown boolean?
---@field NUISlotBg Texture
---@field SetBorderColor fun(self, r: number, g: number, b: number, a: number?) Installed by AddBorders

---@class SkinnedStatusBarMixin : StatusBar
---@field NUIKeepColor boolean?

---@class NUICollapseButtonMixin: Button
---@field __texture Texture
---@field __highlight Texture
---@field bg Frame
---@field settingTexture boolean?
---@field styled boolean?

---Blizzard ItemButton/paperdoll slot fields we touch (all optional per template)
---@class NUIItemButton : Button
---@field icon Texture?
---@field Icon Texture?
---@field IconBorder Texture?
---@field IconOverlay Texture?
---@field IconOverlay2 Texture?
---@field searchOverlay Texture?
---@field SearchOverlay Texture?
---@field ignoreTexture Texture?
---@field UpgradeIcon Texture?
---@field NewItemTexture Texture?
---@field LevelLinkLockTexture Texture?
---@field AzeriteTexture Texture
---@field RankFrame Frame|{ Texture: Texture }
---@field DisplayAsAzeriteItem function?
---@field DisplayAsAzeriteEmpoweredItem function?
---@field NUIAzeriteSkinned boolean?
---@field NUISkinned boolean?
---@field NUISlotBg Texture?


-- Character Frame Skinning

---@class NUIStatFrame : Frame
---@field Background Texture
---@field NUILeftGrad Texture?
---@field NUIRightGrad Texture?

---@class NUIStatsPane : CharacterStatsPane
---@field statsFramePool { EnumerateActive: fun(self): (fun(): NUIStatFrame?) }?

---@class NUIGearManagerBorderBox : Frame
---@field IconSelectorEditBox EditBox?
---@field OkayButton Button?
---@field CancelButton Button?

---@class NUIGearManagerPopup : Frame
---@field NUISkinned boolean?
---@field CloseButton Button?
---@field BorderBox NUIGearManagerBorderBox?
---@field IconSelector { ScrollBar: Frame? }|nil
