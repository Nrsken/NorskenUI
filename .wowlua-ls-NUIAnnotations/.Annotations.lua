---@meta

-- Annotations for NorskenUI addon

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

-- Font styling API injected onto FontString / Font / EditBox metatables (see Core/FontCore.lua).
---@class Font ---@diagnostic disable-line: class-shadows-builtin
local Font

---@class EditBox ---@diagnostic disable-line: class-shadows-builtin
local EditBox

---Style a FontString / Font / EditBox in one call. Resolves the font face (DB block, explicit LSM
---name/path, or the global font when `source` is nil), size, outline, and shadow, then registers the
---object so `NRSKNUI:RefreshFontStyles` re-applies it on a profile or global-font change.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#setfontstyle)
---@param source? string|table DB block, explicit LSM name / path, or nil for the global font
---@param size? number explicit size, or a size override when `source` is a DB block
---@param outline? string explicit outline, or an outline override when `source` is a DB block
---@param shadow? table explicit shadow, or a shadow override when `source` is a DB block
---@param skip? boolean internal: set during RefreshFontStyles to avoid re-registering
---@param setOwner? boolean point an owning Button/CheckButton's state font objects at ours
---@return boolean applied
function Font:SetFontStyle(source, size, outline, shadow, skip, setOwner) end

---Anchor a string to its config anchor and align both axes from that same point, then register it so
---`NRSKNUI:RefreshFontStyles` re-applies it — must run after the font pass since SetFontObject resets
---justify. AnchorFrom encodes both axes: TOPRIGHT -> point TOPRIGHT, H RIGHT, V TOP.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#setfontjustify)
---@param source table|string DB block with a Position.AnchorFrom, or a string anchor
---@param parent? Frame anchor parent, defaults to self:GetParent()
---@param offsetX? number
---@param offsetY? number
---@param skip? boolean internal: set during RefreshFontStyles to avoid re-registering
---@return boolean applied
function Font:SetFontJustify(source, parent, offsetX, offsetY, skip) end

---Style a FontString / Font / EditBox in one call. See `Font:SetFontStyle`.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#setfontstyle)
---@param source? string|table DB block, explicit LSM name / path, or nil for the global font
---@param size? number explicit size, or a size override when `source` is a DB block
---@param outline? string explicit outline, or an outline override when `source` is a DB block
---@param shadow? table explicit shadow, or a shadow override when `source` is a DB block
---@param skip? boolean internal: set during RefreshFontStyles to avoid re-registering
---@param setOwner? boolean point an owning Button/CheckButton's state font objects at ours
---@return boolean applied
function EditBox:SetFontStyle(source, size, outline, shadow, skip, setOwner) end

---Anchor a string to its config anchor and align both axes. See `Font:SetFontJustify`.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#setfontjustify)
---@param source table|string DB block with a Position.AnchorFrom, or a string anchor
---@param parent? Frame anchor parent, defaults to self:GetParent()
---@param offsetX? number
---@param offsetY? number
---@param skip? boolean internal: set during RefreshFontStyles to avoid re-registering
---@return boolean applied
function EditBox:SetFontJustify(source, parent, offsetX, offsetY, skip) end

---@class Frame ---@diagnostic disable-line: class-shadows-builtin
---@field SetBackgroundColor fun(self: Frame, r: number, g: number, b: number, a: number?)
---@field UpdateBackdropFromDB fun(self: Frame, db: table)
---@field SetBorderColor fun(self: Frame, r: number, g: number, b: number, a: number?)
---@field ToggleBackdrop fun(self: Frame, show: boolean)
---@field SetPixelSize fun(self: Frame, width: number, height?: number, ...) Pixel-snapped SetSize (falls back to width for height)
---@field SetPixelWidth fun(self: Frame, width: number, ...) Pixel-snapped SetWidth
---@field SetPixelHeight fun(self: Frame, height: number, ...) Pixel-snapped SetHeight
---@field SetPixelPoint fun(self: Frame, point: string, arg2?: any, arg3?: any, arg4?: any, arg5?: any, ...) SetPoint with numeric offsets snapped to the pixel grid
---@field SetPixelInside fun(self: Frame, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor inset to a frame's corners (defaults 1px)
---@field SetPixelOutside fun(self: Frame, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor outset from a frame's corners (defaults 1px)
---@field SetPixelSnap fun(self: Frame) Disable Blizzard's grid snapping / texel bias on this object
---@field AddBorders fun(self: Frame) Add a 1px border to all 4 edges (or custom size/color)
---@field SetBorderLayer fun(self: Frame, layer: string, sublevel?: number) Set the draw layer of all 4 edges (e.g. 'ARTWORK', 'OVERLAY')
---@field SetBorderParent fun(self: Frame, parent: Frame, sublevel?: number) Reparent all 4 edges to a new parent (e.g. the frame's texture)
---@field SetBorderShown fun(self: Frame, shown: boolean) Show/hide all 4 edges
---@field ApplyOnUpdate fun(self: Frame, throttle: number, callback: fun(self: Frame, elapsed: number)) Add a callback to run on the frame's OnUpdate script (multiple callbacks can be added)
---@field SetScheduledUpdate fun(self: Frame, callback: fun(self: Frame), whenVisible?: boolean) Install a coalesced one-shot handler; arm it with ScheduleUpdate
---@field ScheduleUpdate fun(self: Frame) Arm the SetScheduledUpdate handler to run once next frame; repeated calls coalesce
---@field SetOnUpdateMode fun(self: Frame, mode: number) Set the OnUpdateMode (Enum.OnUpdateMode) for this frame; see docs for details
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
function Frame:CreateBackdrop(noBorders) end

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
---@field ToggleBackdrop fun(self: Button, show: boolean)
---@field SetPixelSize fun(self: Button, width: number, height?: number, ...) Pixel-snapped SetSize (falls back to width for height)
---@field SetPixelWidth fun(self: Button, width: number, ...) Pixel-snapped SetWidth
---@field SetPixelHeight fun(self: Button, height: number, ...) Pixel-snapped SetHeight
---@field SetPixelPoint fun(self: Button, point: string, arg2?: any, arg3?: any, arg4?: any, arg5?: any, ...) SetPoint with numeric offsets snapped to the pixel grid
---@field SetPixelInside fun(self: Button, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor inset to a frame's corners (defaults 1px)
---@field SetPixelOutside fun(self: Button, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor outset from a frame's corners (defaults 1px)
---@field SetPixelSnap fun(self: Button) Disable Blizzard's grid snapping / texel bias on this object
---@field StyleButton fun(self: Button, noHover?: boolean, noPushed?: boolean, noChecked?: boolean) Swap Blizzard highlight/pushed/checked art for flat additive overlays
---@field AddBorders fun(self: Button) Add a 1px border to all 4 edges (or custom size/color)
---@field SetBorderLayer fun(self: Button, layer: string, sublevel?: number) Set the draw layer of all 4 edges (e.g. 'ARTWORK', 'OVERLAY')
---@field SetBorderParent fun(self: Button, parent: Frame) Reparent all 4 edges to a new parent (e.g. the frame's texture)
---@field SetBorderShown fun(self: Button, shown: boolean) Show/hide all 4 edges
---@field ApplyOnUpdate fun(self: Button, throttle: number, callback: fun(self: Button, elapsed: number)) Add a callback to run on the frame's OnUpdate script (multiple callbacks can be added)
---@field SetScheduledUpdate fun(self: Button, callback: fun(self: Button), whenVisible?: boolean) Install a coalesced one-shot handler; arm it with ScheduleUpdate
---@field ScheduleUpdate fun(self: Button) Arm the SetScheduledUpdate handler to run once next frame; repeated calls coalesce
---@field RegisterCallback fun(self: table, event: string, callback: fun(btn: any), owner: table)
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
function Button:CreateBackdrop(noBorders) end

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
---@field ToggleBackdrop fun(self: StatusBar, show: boolean)
---@field SetPixelSize fun(self: StatusBar, width: number, height?: number, ...) Pixel-snapped SetSize (falls back to width for height)
---@field SetPixelWidth fun(self: StatusBar, width: number, ...) Pixel-snapped SetWidth
---@field SetPixelHeight fun(self: StatusBar, height: number, ...) Pixel-snapped SetHeight
---@field SetPixelPoint fun(self: StatusBar, point: string, arg2?: any, arg3?: any, arg4?: any, arg5?: any, ...) SetPoint with numeric offsets snapped to the pixel grid
---@field SetPixelInside fun(self: StatusBar, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor inset to a frame's corners (defaults 1px)
---@field SetPixelOutside fun(self: StatusBar, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor outset from a frame's corners (defaults 1px)
---@field SetPixelSnap fun(self: StatusBar) Disable Blizzard's grid snapping / texel bias on this object
---@field AddBorders fun(self: StatusBar) Add a 1px border to all 4 edges (or custom size/color)
---@field SetBorderLayer fun(self: StatusBar, layer: string, sublevel?: number) Set the draw layer of all 4 edges (e.g. 'ARTWORK', 'OVERLAY')
---@field SetBorderParent fun(self: StatusBar, parent: Frame) Reparent all 4 edges to a new parent (e.g. the frame's texture)
---@field SetBorderShown fun(self: StatusBar, shown: boolean) Show/hide all 4 edges
---@field ApplyOnUpdate fun(self: StatusBar, throttle: number, callback: fun(self: StatusBar, elapsed: number)) Add a callback to run on the frame's OnUpdate script (multiple callbacks can be added)
---@field SetScheduledUpdate fun(self: StatusBar, callback: fun(self: StatusBar), whenVisible?: boolean) Install a coalesced one-shot handler; arm it with ScheduleUpdate
---@field ScheduleUpdate fun(self: StatusBar) Arm the SetScheduledUpdate handler to run once next frame; repeated calls coalesce
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
function StatusBar:CreateBackdrop(noBorders) end

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
---@field SetPixelSize fun(self: Texture, width: number, height?: number, ...) Pixel-snapped SetSize (falls back to width for height)
---@field SetPixelWidth fun(self: Texture, width: number, ...) Pixel-snapped SetWidth
---@field SetPixelHeight fun(self: Texture, height: number, ...) Pixel-snapped SetHeight
---@field SetPixelPoint fun(self: Texture, point: string, arg2?: any, arg3?: any, arg4?: any, arg5?: any, ...) SetPoint with numeric offsets snapped to the pixel grid
---@field SetPixelInside fun(self: Texture, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor inset to a frame's corners (defaults 1px)
---@field SetPixelOutside fun(self: Texture, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor outset from a frame's corners (defaults 1px)
---@field SetPixelSnap fun(self: Texture) Disable Blizzard's grid snapping / texel bias on this texture
---@field SetZoom fun(self: Texture, zoom?: number) Apply a zoom crop via SetTexCoord (uses NRSKNUI.GlobalZoom when omitted)
---@field StripTextures fun(self: Texture, stripType?: string, a?: string|string[]|boolean, b?: boolean) Strip this texture (clear, or per `stripType`). Same modes as the frame version.
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

-- FontStrings receive the pixel-perfect widget methods too (injected in InjectionAPI).
---@class FontString ---@diagnostic disable-line: class-shadows-builtin
---@field SetPixelSize fun(self: FontString, width: number, height?: number, ...) Pixel-snapped SetSize (falls back to width for height)
---@field SetPixelWidth fun(self: FontString, width: number, ...) Pixel-snapped SetWidth
---@field SetPixelHeight fun(self: FontString, height: number, ...) Pixel-snapped SetHeight
---@field SetPixelPoint fun(self: FontString, point: string, arg2?: any, arg3?: any, arg4?: any, arg5?: any, ...) SetPoint with numeric offsets snapped to the pixel grid
---@field SetPixelInside fun(self: FontString, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor inset to a frame's corners (defaults 1px)
---@field SetPixelOutside fun(self: FontString, anchor?: table, xOffset?: number, yOffset?: number, anchor2?: table) Anchor outset from a frame's corners (defaults 1px)
---@field SetPixelSnap fun(self: FontString) Disable Blizzard's grid snapping / texel bias on this object
local FontString

---Style this FontString in one call (font face, size, outline, shadow). See `Font:SetFontStyle`.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#setfontstyle)
---@param source? string|table DB block, explicit LSM name / path, or nil for the global font
---@param size? number explicit size, or a size override when `source` is a DB block
---@param outline? string explicit outline, or an outline override when `source` is a DB block
---@param shadow? table explicit shadow, or a shadow override when `source` is a DB block
---@param skip? boolean internal: set during RefreshFontStyles to avoid re-registering
---@param setOwner? boolean point an owning Button/CheckButton's state font objects at ours
---@return boolean applied
function FontString:SetFontStyle(source, size, outline, shadow, skip, setOwner) end

---Anchor this FontString to its config anchor and align both axes. See `Font:SetFontJustify`.
---
---[Documentation](https://github.com/Nrsken/NorskenUI/blob/PTR/Docs/API.md#setfontjustify)
---@param source table|string DB block with a Position.AnchorFrom, or a string anchor
---@param parent? Frame anchor parent, defaults to self:GetParent()
---@param offsetX? number
---@param offsetY? number
---@param skip? boolean internal: set during RefreshFontStyles to avoid re-registering
---@return boolean applied
function FontString:SetFontJustify(source, parent, offsetX, offsetY, skip) end

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
