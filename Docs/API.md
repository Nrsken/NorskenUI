# NorskenUI Injected Widget API

Methods NorskenUI injects onto Blizzard widget metatables (see `Core/InjectionAPI.lua`).
They are available on every frame/texture, e.g. `myFrame:StripTextures('Keyed')`.

The hover tooltips in the editor link here via the `[Documentation]` line on each method.

---

## StripTextures

```lua
frame:StripTextures(stripType?, a?, b?)
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
frame:StripTextures('Keyed')

-- Kill, recursively
frame:StripTextures('Keyed', true)

-- Alpha 0, recursively
frame:StripTextures('Keyed', nil, true)

-- Surgical: hide only ARTWORK/HIGHLIGHT layer textures on this frame
AddonComp:StripTextures('Layer', { 'ARTWORK', 'HIGHLIGHT' })

-- Surgical: hide the one atlas
tooltip.CompareHeader:StripTextures('Atlas', 'tooltip-compare-label')
```

### Notes

- Only `'Keyed'` recurses into children. `'Kill'`/`'Layer'`/`'Atlas'`/`'ClearHide'`/`'Alpha'`
  act on the frame's own regions only.

---

## CreateBackdrop

```lua
frame:CreateBackdrop(template?)
```

Mixes `PublicBackdropMixin` onto `frame` and builds a pixel-perfect backdrop:
a `BACKGROUND` fill plus four `BORDER` edge textures.

Installs `SetBackgroundColor`, `SetBorderColor`, `UpdateBackdropFromDB`, `ToggleBackdrop`.

---

## HasBackdrop

```lua
local has = frame:HasBackdrop()
```

Returns `true` if a NorskenUI backdrop was already added to `frame`. Use before
`CreateBackdrop` to avoid double-adding.

---

## Banish

```lua
frame:Banish(...)
```

Hide an object safely and reparent it to the shared hidden frame. Optional string
args traverse the object's children by key first, e.g. `Banish(frame, 'Inset')`.
Disables mouse, unregisters events, sets `statehidden`, and respects user placement
(`SetUserPlaced`/`SetDontSavePosition`) where present. Prefer this over ad-hoc
`:Hide()` for Blizzard frames that fight back.

---

## ApplyPosition

```lua
frame:ApplyPosition(Config, setParent?)
```

Position `frame` from a config table. Pass `setParent = true` to also reparent.

---

## StyleChildFontStrings

```lua
frame:StyleChildFontStrings(source, getSize, outline?, shadow?, skip?, setOwner?)
```

Walk `frame`'s child `FontString`s and apply a font style. `getSize(fontString, parent)`
returns the size per string (or `nil` to leave it).

---

## SetZoom (Texture)

```lua
texture:SetZoom(zoom?)
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
frame:SetPixelSize(width, height?, ...)
frame:SetPixelWidth(width, ...)
frame:SetPixelHeight(height, ...)
```

Pixel-snapped equivalents of `SetSize`/`SetWidth`/`SetHeight`. `SetPixelSize` falls
back to `width` when `height` is omitted (square). Extra varargs pass through.

### SetPixelPoint

```lua
frame:SetPixelPoint(point, arg2?, arg3?, arg4?, arg5?, ...)
```

`SetPoint` mirror: only the **numeric** offset arguments are snapped, the `relativeTo`
frame and anchor-point strings pass through untouched. When `arg2` is omitted it
defaults to the frame's parent. Handles both the long form
(`point, relativeTo, relativePoint, x, y`) and the short form (`point, x, y`).

### SetPixelInside / SetPixelOutside

```lua
region:SetPixelInside(anchor?, xOffset?, yOffset?, anchor2?)
region:SetPixelOutside(anchor?, xOffset?, yOffset?, anchor2?)
```

Anchor a region a fixed pixel inset relative to `anchor` via `TOPLEFT`/`BOTTOMRIGHT`.
`SetPixelInside` sits the region **inside** the anchor; `SetPixelOutside` flips the
inset so it **frames** the anchor. `anchor` defaults to the parent, offsets default to
`1`, and `anchor2` (defaults to `anchor`) lets the bottom-right corner track a
different frame. Also calls `SetPixelSnap` on the region.

### SetPixelSnap

```lua
object:SetPixelSnap()
```

Turn off Blizzard's own grid snapping (`SetSnapToPixelGrid(false)` +
`SetTexelSnappingBias(0)`) so our pixel math is authoritative. Works on textures
directly and on status bars via their fill texture. Runs once per object (guarded by
`NUIPixelSnapDisabled`), and skips secret/forbidden objects.

---

## StyleButton

```lua
button:StyleButton(noHover?, noPushed?, noChecked?)
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
