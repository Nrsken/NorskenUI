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
a `BACKGROUND` fill plus four `BORDER` edge textures. Pass `template = 'BorderTemplate'`
to create **only** the border (no background fill).

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
