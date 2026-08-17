# NorskenUI Injected Widget API

Methods NorskenUI injects onto Blizzard widget metatables (see `Core/InjectAPI.lua`).
They are available on every frame/texture, e.g. `myFrame:NUIStripTextures('Keyed')`.

The hover tooltips in the editor link here via the `[Documentation]` line on each method.

---

## NUIStripTextures

```lua
frame:NUIStripTextures(stripType?, a?, b?)
```

Strip textures/atlases from a frame **or** a texture in a controlled way. Passing a
frame's global name (string) resolves it via `_G`. Passing a `Texture` strips that
single texture directly.

### `stripType`

| value        | effect |
|--------------|--------|
| `nil`        | Clear every own texture (`SetTexture(nil)` + `SetAtlas('')`) but leave the regions live, so state-driven Blizzard frames can re-drive them via `SetAtlas`. |
| `'Keyed'`    | Recurse into known keyed children (`NineSlice`, `Inset`, `Bg`, `Border`, …), giving each the same treatment, then clear this frame's own regions. |
| `'Kill'`     | Hide every own texture and block re-show (`region.Show = region.Hide`), for frames that aggressively re-`Show` their art. |
| `'Layer'`    | Hide own textures whose **draw layer** matches `a`. |
| `'Atlas'`    | Hide own textures whose **atlas** matches `a`. |
| `'ClearHide'`| Clear content **and** force alpha 0, so state-driven frames can re-atlas but stay invisible. |
| `'Alpha'`    | Only set alpha 0 on own textures, leaving the texture/atlas live. |

### `a` and `b` (mode-specific)

| mode              | `a`                                                   | `b` |
|-------------------|-------------------------------------------------------|-----|
| `'Layer'`/`'Atlas'` | draw-layer / atlas name, or a **list** of names (`{ 'ARTWORK', 'HIGHLIGHT' }`) | — |
| `'Keyed'`         | `banish` — kill (hide + block re-show), applied recursively | `alphaZero` — set alpha 0 instead of clearing, recursively |

### Examples

```lua
-- Full recurse + clear own regions
frame:NUIStripTextures('Keyed')

-- Kill, recursively
frame:NUIStripTextures('Keyed', true)

-- Alpha 0, recursively
frame:NUIStripTextures('Keyed', nil, true)

-- Surgical: hide only ARTWORK/HIGHLIGHT layer textures on this frame
AddonComp:NUIStripTextures('Layer', { 'ARTWORK', 'HIGHLIGHT' })

-- Surgical: hide the one atlas
tooltip.CompareHeader:NUIStripTextures('Atlas', 'tooltip-compare-label')
```

### Notes

- Only `'Keyed'` recurses into children. `'Kill'`/`'Layer'`/`'Atlas'`/`'ClearHide'`/`'Alpha'`
  act on the frame's own regions only.

---

## NUICreateBackdrop

```lua
frame:NUICreateBackdrop(noBorders?, inset?)
```

Mixes `PublicBackdropMixin` onto `frame` and builds a pixel-perfect backdrop:
a `BACKGROUND` fill plus four `BORDER` edge textures.

`noBorders` skips the four edges, for frames that draw their own. `inset` is how far
the fill and edges sit inside the frame's rect, in pixels; it defaults to `1`, and `0`
makes them flush with the frame.

Installs `SetBackgroundColor`, `SetBorderColor`, `UpdateBackdropFromDB`, `ToggleBackdrop`.

---

## NUIHasBackdrop

```lua
local has = frame:NUIHasBackdrop()
```

Returns `true` if a NorskenUI backdrop was already added to `frame`. Use before
`CreateBackdrop` to avoid double-adding.

---

## NUIBanish

```lua
frame:NUIBanish(...)
```

Hide an object safely and reparent it to the shared hidden frame. Optional string
args traverse the object's children by key first, e.g. `Banish(frame, 'Inset')`.
Disables mouse, unregisters events, sets `statehidden`, and respects user placement
(`SetUserPlaced`/`SetDontSavePosition`) where present. Prefer this over ad-hoc
`:Hide()` for Blizzard frames that fight back.

---

## NUIApplyPosition

```lua
frame:NUIApplyPosition(Config, setParent?)
```

Position `frame` from a config table. Pass `setParent = true` to also reparent.

---

## NUIStyleChildFontStrings

```lua
frame:NUIStyleChildFontStrings(source, getSize, outline?, shadow?, skip?, setOwner?)
```

Walk `frame`'s child `FontString`s and apply a font style. `getSize(fontString, parent)`
returns the size per string (or `nil` to leave it).

---

## SetFontStyle

```lua
fontString:SetFontStyle(source?, size?, outline?, shadow?, skip?, setOwner?)
```

Style any `FontString`, `Font`, or `EditBox` in one call. Injected onto all three metatables
(see `Core/FontCore.lua`). Resolves the font **face**, **size**, **outline**, and **shadow**,
builds/reuses a cached font object (with per-alphabet CJK substitution and the shadow-clear fix),
and points the object at it via `SetFontObject`. The object is registered so
`NRSKNUI:RefreshFontStyles` re-applies it on a profile or global-font change.

### `source`

| value | meaning |
|-------|---------|
| **table** (DB block) | Reads `FontFace`/`Font`, `FontSize`, `FontOutline`, `FontShadow`. Honors the global font (`globalMedia.profileFont`) unless the block sets `UseGlobalFont = false`. |
| **string** | An explicit LSM font name or literal font path. |
| `nil` | Falls back to the profile's global font (or the addon default). |

### Other params

| param | effect |
|-------|--------|
| `size` | Explicit size, **or** an override on top of a DB block's `FontSize`. Falls back to the default size when `nil`/non-positive. |
| `outline` | Explicit outline flags (`'OUTLINE'`, `'THICKOUTLINE,MONOCHROME'`, `'SLUG'`, `'NONE'`, …), or an override over the block's `FontOutline`. Resolved via `NRSKNUI:ResolveFlags`. |
| `shadow` | Explicit shadow block (`{ Enabled, Color, OffsetX, OffsetY }`), or an override over the block's `FontShadow`. |
| `skip` | **Internal.** Set during `RefreshFontStyles` so the re-apply pass doesn't re-register the object mid-loop. |
| `setOwner` | When the string is a `Button`/`CheckButton` label, also points the owner's normal/highlight/disabled font objects at ours so every state matches. |

Returns `true` when applied, `false` if the target has no `SetFontObject`.

---

## SetFontJustify

```lua
fontString:SetFontJustify(source, parent?, offsetX?, offsetY?, skip?, bound?, flip?)
```

Anchor a `FontString` to its config anchor and align **both** axes from that same point, then
register it so `NRSKNUI:RefreshFontStyles` re-applies it. This **must** run
after the font pass — `SetFontObject` (via `SetFontStyle`) resets `JustifyH`/`JustifyV`, so the
alignment would otherwise revert on a profile change.

`source` is either a DB block carrying `Position.AnchorFrom` or a plain anchor string. `AnchorFrom`
encodes both axes: `TOPRIGHT` → point `TOPRIGHT`, H `RIGHT`, V `TOP`. `flip` Makes the X offset flipped when
the anchor is on the right side, useful on texts with backdrops and need to have a slight inset. `parent` defaults to `self:GetParent()`, offsets default to `0`,
and `skip` is the same internal re-apply flag as `SetFontStyle`. Returns `true` when applied.

`bound` pins a second edge to another widget, giving the string a fixed width so it truncates
(`text...`) instead of overrunning its neighbour:

```lua
castText:SetFontJustify('LEFT', castBar, 4, 0, nil, {
    relTo = castTimeText, point = 'RIGHT', relPoint = 'LEFT', offsetX = -4,
})
```

Pass a **list** of those edge tables instead and they replace the anchor point entirely, which boxes
a string between two neighbours where neither edge sits on the parent. `source` then only drives
justification:

```lua
targetText:SetFontJustify(db.Target.Position, castBar, 0, 0, nil, {
    { relTo = nameText, point = 'LEFT',  relPoint = 'RIGHT', offsetX = 4 },
    { relTo = timeText, point = 'RIGHT', relPoint = 'LEFT',  offsetX = -4 },
})
```

---

## NUISetZoom (Texture)

```lua
texture:NUISetZoom(zoom?)
```

Apply a zoom crop via `SetTexCoord`, using `NRSKNUI.GlobalZoom` when `zoom` is omitted.

---

## Pixel-perfect sizing & positioning

These wrap the native `SetSize`/`SetWidth`/`SetHeight`/`SetPoint` and snap numeric
values to the physical pixel grid so edges stay crisp at any resolution. They are
injected onto every frame, texture, and font string.

Snapping is driven by `NRSKNUI.Mult` — the size of one device pixel in UI units.
`Mult` is `1` for any resolution whose perfect-pixel scale lands in `[0.4, 1.15]`
(i.e. effectively all 1080p/1440p setups), in which case values pass through
unchanged. It only diverges at extreme resolutions, where each value is rounded to
the nearest whole pixel (`floor(value / Mult + 0.5) * Mult`).

### SetPixelSize / SetPixelWidth / SetPixelHeight

```lua
frame:NUISetPixelSize(width, height?, ...)
frame:NUISetPixelWidth(width, ...)
frame:NUISetPixelHeight(height, ...)
```

Pixel-snapped equivalents of `SetSize`/`SetWidth`/`SetHeight`. `SetPixelSize` falls
back to `width` when `height` is omitted (square). Extra varargs pass through.

### SetPixelPoint

```lua
frame:NUISetPixelPoint(point, arg2?, arg3?, arg4?, arg5?, ...)
```

`SetPoint` mirror: only the **numeric** offset arguments are snapped, the `relativeTo`
frame and anchor-point strings pass through untouched. When `arg2` is omitted it
defaults to the frame's parent. Handles both the long form
(`point, relativeTo, relativePoint, x, y`) and the short form (`point, x, y`).

### SetGridPoint

```lua
frame:NUISetGridPoint(point, relativeTo?, relativePoint?, offsetX?, offsetY?)
```

Like `SetPoint`, but snaps the **resulting position** onto the pixel grid instead of the
offset. `SetPixelPoint` rounds the offset you pass, which does nothing when the frame you
anchor to is itself off-grid (e.g. a Blizzard frame whose centre lands on a half-pixel) —
the fractional origin is inherited and thin fills bleed 1px sideways. `SetGridPoint`
derives where the frame's bottom-left will land from `relativeTo`'s geometry and applies a
sub-pixel correction so the edges sit on whole device pixels. `relativeTo` accepts a frame
or global name (defaults to the parent), `relativePoint` defaults to `point`, offsets
default to `0`. Assumes `frame` and `relativeTo` share an effective scale (both under
`UIParent`); if the anchor's geometry is secret/not yet laid out it falls back to
`SetPixelPoint`. Does **not** clear existing points — call `ClearAllPoints` first if needed.

### SetPixelInside / SetPixelOutside

```lua
region:NUISetPixelInside(anchor?, xOffset?, yOffset?, anchor2?)
region:NUISetPixelOutside(anchor?, xOffset?, yOffset?, anchor2?)
```

Anchor a region a fixed pixel inset relative to `anchor` via `TOPLEFT`/`BOTTOMRIGHT`.
`SetPixelInside` sits the region **inside** the anchor; `SetPixelOutside` flips the
inset so it **frames** the anchor. `anchor` defaults to the parent, offsets default to
`1`, and `anchor2` (defaults to `anchor`) lets the bottom-right corner track a
different frame. Also calls `SetPixelSnap` on the region.

### SetPixelSnap

```lua
object:NUISetPixelSnap()
```

Turn off Blizzard's own grid snapping (`SetSnapToPixelGrid(false)` +
`SetTexelSnappingBias(0)`) so our pixel math is authoritative. Works on textures
directly and on status bars via their fill texture. Runs once per object (guarded by
`NUIPixelSnapDisabled`), and skips secret/forbidden objects.

---

## NUIStyleButton

```lua
button:NUIStyleButton(noHover?, noPushed?, noChecked?)
```

Replace a button's Blizzard highlight/pushed/checked art with flat additive color
overlays clamped inside the button (`SetPixelInside`). Pass `noHover`/`noPushed`/
`noChecked` to skip a given state. Each applied texture is cached on the button
(`.hover`/`.pushed`/`.checked`) so repeated calls are no-ops. No-ops entirely on
objects without `CreateTexture`.

| state   | color (r, g, b, a)     |
|---------|------------------------|
| hover   | `1, 1, 1, 0.3`         |
| pushed  | `0.9, 0.8, 0.1, 0.3`   |
| checked | `1, 1, 1, 0.3`         |
