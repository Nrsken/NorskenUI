-- English enUS and enGB localization file.
local L = select(2, ...):NewLocale('enUS')

-- General --
-- NRSKNUI.ColorModeOptions
L['Class Color'] = true
L['Custom Color'] = true
L['Theme Color'] = true

-- General GUI
L['Outline'] = true
L['Color'] = true
L['Colors'] = true
L['Layout'] = true
L['Backdrop'] = true

-- Combat Modules --
-- Combat Cross
L['Style'] = true

-- Sidebar
L['Defensives'] = true

-- Global Fonts
L['Enable'] = true
L['Position'] = true

-- Profiles
L['Cancel'] = true
L['Create'] = true
L['Global Profile'] = true
L['Later'] = true
L['Profiles'] = true
L['Reload Now'] = true
L['Reset'] = true

-- Theme Page
L['Custom'] = true
L['Theme'] = true

-- Cursor Circle
L['Texture'] = true

-- Focus Castbar
L['Background'] = true
L['Border'] = true
L['Center'] = true
L['Duration'] = true
L['Left'] = true
L['Right'] = true

-- Missing Buffs
L['Display'] = true
L['Healthstone'] = true
L['Runeforge'] = true
L['Glow'] = true

-- Profile messages & dialogs
L['Profile changed. A UI reload is recommended to fully apply all settings.'] = true

-- Modifier Keys (shared)
L['Shift'] = true
L['Ctrl'] = true
L['Alt'] = true

-- Skinning Sidebar
L['Skinning'] = true

-- Tooltips Skinning
L['Spells'] = true
L['Auras'] = true

-- Minimap Skinning
L['Indicators'] = true

-- QoL: Character Panel
L['Fonts'] = true

-- QoL: Skyriding UI
L['Bars'] = true

-- QoL: CDM Profiles
L['Profile'] = true

-- NRSKNUI.FontOutlines
L['None'] = true
L['Thick'] = true
L['Mono'] = true
L['Mono Outline'] = true
L['Mono Thick'] = true
L['Slug'] = true
L['Slug Outline'] = true
L['Player'] = true
L['Target'] = true
L['Focus'] = true
L['Boss'] = true
L['Group'] = true
L['Class'] = true
L['Frame'] = true
L['Power'] = true
L['Name'] = true
L['Ready Check'] = true
L['Blizzard'] = true
L['Boss / Role Debuffs'] = true
L['Enemy Buffs'] = true

-- Aura Filter Builder --
L['Active'] = true
L['Back'] = true
L['General Buffs'] = true
L['Item'] = true

-- CDM bars
L['Stagger'] = true
L['Combo Points'] = true
L['Holy Power'] = true
L['Soul Shards'] = true
L['Chi'] = true
L['Arcane Charges'] = true
L['Essence'] = true
L['Runes'] = true
L['Load'] = true
L['Any'] = true
L['Exclude'] = true
L['Require'] = true
L['Crowd Control'] = true
L['Magic'] = true
L['Poison'] = true
L['Disease'] = true
L['Curse'] = true
L['Bleed'] = true
L['Enrage'] = true
L['Remove'] = true
L['Raid'] = true

-- Aura Displays (Advanced Debuffs / Defensives / Standard Buffs / Standard Debuffs) --
L['Advanced Debuffs'] = true

-- Layout tab
L['Grid'] = true
L['Up'] = true
L['Down'] = true

-- Filter tab
L['Branch %d: %s'] = true
L['Included spell IDs: %d'] = true
L['Excluded spell IDs: %d'] = true
L['Included dispel types: %d'] = true
L['Excluded dispel types: %d'] = true
L['Max duration: %ds'] = true
L['Uses ProcessAura classification.'] = true
L['Spell IDs are ignored for debuffs on you and units you can assist.'] = true
L['Spell IDs are ignored for buffs on units you cannot assist.'] = true
L['Spell IDs are ignored for debuffs on friendly units and buffs on hostile units.'] = true
L['Matches auras in the branch:'] = true
L['Matches auras in any of %d branches, shown once per branch:'] = true

-- Aura indicators
L['This indicator no longer exists.'] = true

-- Aura indicator library (UnitFrames sidebar)
L['Indicator %d'] = true
L['Big Defensives'] = true
L['Boss Debuffs'] = true
L['External Defensives'] = true
L['Shows while a matching aura is up:'] = true
L['This indicator matches nothing yet.'] = true
L['Icon'] = true
L['Layer'] = true
L['Replace'] = true

-- Dispel highlight (UnitFrames General + per unit)
L['Alpha'] = true
L['Dispel'] = true
L['Solid'] = true

-- Sorting (AuraContainerSortMethod / AuraContainerSortDirection)
L['Default'] = true
L['Normal'] = true

-- Appearance tab
L['Cooldown'] = true

-- Unit Frame Auras (per-unit buff/debuff containers) --
L['Buffs'] = true
L['Debuffs'] = true

-- Statuses --
L['Status'] = true

-- Premade Aura Filters --
L['Defensive Buffs'] = true
L['Speed Buffs'] = true
L['Target Buffs'] = true
L['Target Debuffs'] = true
L['Boss Buffs'] = true
L['Party Buffs'] = true
L['Party Debuffs'] = true
L['Raid Buffs'] = true
L['Raid Debuffs'] = true

-- Aura Triggers & Displays --
L['This trigger matches nothing yet.'] = true
L['Trigger'] = true

-- Skinning: Action Bars --
L['Texts'] = true

-- Skinning: Blizzard Mouseover --
L['Hide'] = true
L['Filters'] = true
L['Search'] = true

-- Aura trackers
L['%s (Copy)'] = true
L['%s (Copy %d)'] = true
L['Debuffs (No Bloodlust)'] = true
L['Disable'] = true
L['Externals'] = true
L['Healer HoTs'] = true
L['Bloodlust'] = true
L['Lockouts'] = true
L['Other'] = true
L['Racials'] = true
L['Raid Cooldowns'] = true
L['Trinkets'] = true

-- Cooldown Manager
L['Show'] = true
L['Collapse'] = true
L['Expand'] = true
L['Update'] = true
L['View'] = true

-- Anchors
L["Anchor '%s' has %d anchor points and cannot be dragged."] = true
L['Anchors closed due to entering combat.'] = true
L['Cannot open Anchors during combat.'] = true
L['Click to select'] = true
L['No anchor selected.'] = true
L['No anchor selected. Click an overlay to select it.'] = true
L['Nudge Tool'] = true
L['Open Settings'] = true
L['X Offset:'] = true
L['Y Offset:'] = true

-- BackdropColorsCard
L["Use Global Backdrop"] = true
L["Use Global Border"] = true

-- Checkbox
L["Disabled"] = true
L["Enabled"] = true

-- Commands
L['%s is missing, reinstall NorskenUI.'] = true
L['%s is version %s but NorskenUI is %s, update both.'] = true
L['GUI position and size reset to defaults.'] = true
L['Options will open after combat ends.'] = true

-- Core / Main
L['%s to open the configuration window.'] = true
L['Left-Click to open options'] = true
L['Middle-Click to reset the options window position'] = true
L['Right-Click to toggle anchors'] = true

-- Core / Util
L["Default: %s"] = true

-- Dialog
L['Accept'] = true
L['Copied to clipboard'] = true
L['CTRL-C to copy'] = true
L["Reload Required"] = true
L["Reset %s settings to defaults?"] = true
L["Reset failed: %s"] = true
L["Reset Module"] = true
L["Settings reset. Reload to apply all changes."] = true
L["unknown error"] = true
L["Would you like to reload your UI now?"] = true

-- Dropdown
L["Multiple Selected"] = true
L["No matches found"] = true
L["Select..."] = true

-- DynamicGroupCard
L["Down then Left"] = true
L["Down then Right"] = true
L["Grid Fill"] = true
L["Grid Width"] = true
L["Horizontal (centered)"] = true
L["Left then Down"] = true
L["Left then Up"] = true
L["Limit"] = true
L["Right then Down"] = true
L["Right then Up"] = true
L["Up then Left"] = true
L["Up then Right"] = true
L["Use Limit"] = true
L["Vertical (centered)"] = true

-- FontSettingsCard
L["Font Shadow"] = true
L["Soft"] = true

-- FrameChooser
L['%s or %s to cancel'] = true
L['%s to select the highlighted frame'] = true
L['Esc'] = true
L['Frame Chooser'] = true
L['Left-click'] = true
L['Right-click'] = true

-- GlowSettingsCard
L["Always Glow"] = true
L["Autocast"] = true
L["Button"] = true
L["Enable Glow"] = true
L["Expiration Glow"] = true
L["Particles"] = true
L["Pixel"] = true
L["Proc"] = true
L["When to Glow"] = true

-- LoadConditionsCard
L["A map"] = true
L["A map and every map inside it"] = true
L["Add Current Zone: %s (%d)"] = true
L["All floors"] = true
L["An instance"] = true
L["Arena"] = true
L["Battleground"] = true
L["Category"] = true
L["Clear"] = true
L["Click to load in this spec."] = true
L["Current Instance"] = true
L["Current Season Dungeons"] = true
L["Current Season Raids"] = true
L["Current Zone"] = true
L["Dungeon"] = true
L["Every floor of a map group"] = true
L["How To Write Them"] = true
L["Instance"] = true
L["Leave a map out, works with any prefix"] = true
L["Loads in this spec. Click to remove it."] = true
L["Map IDs"] = true
L["Melee"] = true
L["Open World"] = true
L["Parent Zone"] = true
L["Pick exactly one spec under Spec to filter by talents."] = true
L["Ranged"] = true
L["Scenario"] = true
L["Select My Class"] = true
L["Separate entries with commas."] = true
L["Solo"] = true
L["Spec"] = true
L["Zone"] = true

-- PositionCard
L["Anchored To"] = true
L["Configure For"] = true
L["Screen (UIParent)"] = true
L["Screen Center"] = true
L["Select Frame"] = true
L["Split Positioning"] = true
L["Strata"] = true
L["To Screen's"] = true

-- ProfileManager
L['Cannot delete the active profile'] = true
L['Current name cannot be empty'] = true
L['Database not initialized'] = true
L['Decoding failed'] = true
L['Decompression failed'] = true
L['Default settings not found for: %s'] = true
L['Defaults not found'] = true
L['Deserialization failed: %s'] = true
L['Export failed'] = true
L['Import string is empty'] = true
L['Invalid data structure'] = true
L['Invalid format (missing or wrong prefix)'] = true
L['Invalid path'] = true
L['Invalid profile name'] = true
L['Names are identical'] = true
L['New name cannot be empty'] = true
L['Path not found: %s'] = true
L['Profile name cannot be empty'] = true
L['Profile: %s, already exists'] = true
L['Profile: %s, does not exist'] = true
L['Profile: %s, not found'] = true
L['Source profile name cannot be empty'] = true
L['Source profile: %s, does not exist'] = true

-- Search
L["Search..."] = true

-- Sidebar
L["No results found"] = true

-- TalentTree
L["Ignored"] = true
L["Left-click: next state, right-click: previous"] = true
L["Must be talented"] = true
L["Must not be talented"] = true

-- TextFormatCard
L["Align"] = true

-- LibKaji (its strings resolve from Core: the library runs outside the options window too)
L['%d active'] = true
L['Accent'] = true
L['Accent Dim'] = true
L['Accent Hover'] = true
L['Alignment'] = true
L['Anchor From'] = true
L['Apex Talents'] = true
L['Backdrop Color'] = true
L['Background Dark'] = true
L['Background Hover'] = true
L['Background Light'] = true
L['Background Medium'] = true
L['Border Color'] = true
L['Bottom'] = true
L['Bottom Left'] = true
L['Bottom Right'] = true
L['Class & Spec Talents'] = true
L['Combat'] = true
L['Confirm'] = true
L['Delete'] = true
L['Dialog'] = true
L['DPS'] = true
L['Duplicate'] = true
L['Dynamic Group'] = true
L['Enable Backdrop'] = true
L['Error'] = true
L['Font'] = true
L['Font Settings'] = true
L['Font Size'] = true
L['Format'] = true
L['Fullscreen'] = true
L['Fullscreen Dialog'] = true
L['Glow Settings'] = true
L['Grow Direction'] = true
L['Healer'] = true
L['Hero Talents'] = true
L['High'] = true
L['In Combat'] = true
L['Length'] = true
L['Lines'] = true
L['Load Conditions'] = true
L['Low'] = true
L['Medium'] = true
L['Move Down'] = true
L['Move Up'] = true
L['Off'] = true
L['On'] = true
L['Out of Combat'] = true
L['Party'] = true
L['Position Settings'] = true
L['Role'] = true
L['Row Spacing'] = true
L['Scale'] = true
L['Selected Background'] = true
L['Selected Text'] = true
L['Shadow Color'] = true
L['Shadow X'] = true
L['Shadow Y'] = true
L['Size'] = true
L['Spacing'] = true
L['Spark Color'] = true
L['Spark Scale'] = true
L['Spark Settings'] = true
L['Spark Texture'] = true
L['Spark Width'] = true
L['Speed'] = true
L['Start Animation'] = true
L['Success'] = true
L['Talent'] = true
L['Tank'] = true
L['Text Format'] = true
L['Text Muted'] = true
L['Text Primary'] = true
L['Text Secondary'] = true
L['Thickness'] = true
L["To Frame's"] = true
L['Tooltip'] = true
L['Top'] = true
L['Top Left'] = true
L['Top Right'] = true
L['Type'] = true
L['Use Global Font'] = true
L['Use Global Spark'] = true
L['Warning'] = true
L['Widget Border'] = true
L['X Offset'] = true
L['Y Offset'] = true

-- Shared with the options pages
L['Appearance'] = true
L['Separator'] = true
L['Combat Cross'] = true
L['Flat'] = true
L['Copy'] = true
L['Rename'] = true
L['Options'] = true
L['Text'] = true
L['Backgrounds'] = true
L['Status Colors'] = true
L['Frost'] = true
L['Export'] = true
L['Everything'] = true
L['Anchors'] = true
L['Sounds'] = true
L['Accent Colors'] = true
L['Borders'] = true
L['Selection Colors'] = true
L['Text Colors'] = true
L['Conditions'] = true
L['Tags'] = true
L['New'] = true
L['Settings'] = true
L['%dm'] = true

-- Core / Init
L['Space'] = true

-- Shared with the options pages
L['Development Version'] = true
