# Module folders

NorskenUI ships as one project with several addon folders. `NorskenUI` is the core; every feature lives in a module folder that depends on it, and all settings pages live in the LoadOnDemand `NorskenUI_Options`.

| Folder | Holds |
|---|---|
| `NorskenUI` | Core helpers, the aura engine, shared settings (theme, UI scale, colors, global media), profiles, `NorskenUIDB` |
| `NorskenAuras` | Cooldown & Aura Manager |
| `NorskenUI_UnitFrames` | Unit, party, raid and boss frames, plus oUF |
| `NorskenUI_Skinning` | Blizzard skins, action bars, chat, minimap, tooltips, Blizzard fonts, player buffs |
| `NorskenUI_QoL` | QoL, Combat, ClassUtility, Dungeons, BigWigsTimers, MissingBuffs |
| `NorskenUI_Options` | The settings window and every module's pages (LoadOnDemand) |

The rule that keeps this working: **Core never names a module.** Modules register with Core, and Core only goes through what they registered.

## A module folder

```
NorskenUI_Example/
    NorskenUI_Example.toc
    Example/
        Example.xml     -- loads Init.lua, Defaults.lua, then the module files
        Init.lua
        Defaults.lua
        Example.lua
```

The TOC declares `## Dependencies: NorskenUI` and `## Group: NorskenUI` (the group must match the parent folder name exactly). Add the folder to `move-folders` in `.pkgmeta` and to `## OptionalDeps` in `NorskenUI_Options.toc`.

Every file starts with the core table. Inside a split-out folder `...` is that folder's own table, so read the global:

```lua
---@class NRSKNUI
local NRSKNUI = _G.NorskenUI
```

### Init.lua

Creates the folder's modules, first, so every later file can `GetModule` them:

```lua
NRSKNUI.Example = NRSKNUI:NewModule('Example', 'AceEvent-3.0')
```

Modules start disabled. At login Core enables every module whose `db.Enabled` is true.

### Defaults.lua

A module with `Defaults` gets its own AceDB namespace inside `NorskenUIDB`, named after the module. Profile switches, copies, resets, deletes, renames and dual spec all reach it through AceDB.

```lua
local Example = NRSKNUI:GetModule('Example')
Example.Defaults = {
    Enabled = false,
}
```

Settings that used to live somewhere else in the profile name their old path with `dbKey`. Registering moves saved data from there into the namespace once, and export strings keep using that path, so old strings, WagoUI packs and older versions stay compatible:

```lua
Example.dbKey = 'Miscellaneous.Example'
```

### The module

```lua
local Example = NRSKNUI:GetModule('Example')

function Example:UpdateDB()
    self.db = self.namespace.profile
end
```

`UpdateDB` runs once at init and again for every module, enabled or not, on each profile change. Hooks the module prototype (`Core/Init.lua`) picks up when present:

| Hook | When |
|---|---|
| `UpdateDB()` | Init and every profile change |
| `UpgradeSavedProfiles(db)` | Before the namespace takes the data, to fix old formats in place |
| `IsBlocked()` | Return true to stay off whatever the profile says (unit frames when another UI owns them) |
| `ApplySettings()` | After a profile change, for modules that are running |

A module that defines its own `OnInitialize` skips the prototype, so it registers its namespace itself (`NRSKNUI.ProfileManager:RegisterNamespace(name, defaults, oldPath)`), as the CDM does.

## Options pages

Pages live in `NorskenUI_Options/<Module>/`. Every page file returns early when its module folder is disabled, before it touches the module:

```lua
local NRSKNUI = _G.NorskenUI
if not C_AddOns.IsAddOnLoaded('NorskenUI_Example') then return end
```

A `Sidebar.lua`, loaded first, adds the module's section; `order` places it among the others (Profiles 10, CDM 20, Global 30, Unit Frames 40, Combat 50, QoL 60, Skinning 70, Dungeons 80, BigWigs 90, Class 100, Missing Buffs 110):

```lua
GUIFrame:AddSidebarEntry({
    id = 'example_section',
    order = 65,
    type = 'header',
    text = L['Example'],
    items = { { id = 'example', text = L['General'] } },
})
```

Open the window from module code with `NRSKNUI:OpenOptions(pageId?, context?)` or `NRSKNUI:ToggleOptions()`; never touch `NRSKNUI.GUIFrame` directly, it only exists after the options addon has loaded.

## Talking across folders

Module folders don't depend on each other, so their load order is not fixed and any of them can be disabled.

- Never `GetModule` another folder's module at file scope. Look it up when you need it and handle it missing: `local CDM = NRSKNUI:GetModule('CDM', true)`.
- For "something changed" use AceEvent messages; sending one nobody listens to does nothing.

| Message | Sent by | When |
|---|---|---|
| `NRSKNUI_CDM_LAYOUT_CHANGED` | CDM | A display or group layout changed (unit frames re-anchor) |
| `NRSKNUI_COLORS_UPDATED` | Core | The color palette was rebuilt (unit frames push it into oUF) |
| `NRSKNUI_PROFILE_FONT_CHANGED` | Core | The global font changed or finished resolving (Blizzard fonts restyle) |
| `NRSKNUI_WORLD_READY` | Core | One second after the first world entry after login |
