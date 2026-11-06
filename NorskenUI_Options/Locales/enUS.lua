-- English enUS and enGB localization file.
local L = _G.NorskenUI:NewLocale('enUS')

-- General GUI
L['General Settings'] = true
L['Color Mode'] = true
L['Load Condition'] = true
L['Test'] = true
L['Always'] = true
L['Any Group'] = true
L['In Party'] = true
L['In Raid'] = true
L['Information'] = true
L['Discord'] = true
L['GitHub'] = true
L['Support'] = true
L['Timer'] = true
L['Format Text'] = true
L['Background Color'] = true
L['Widget Glow'] = true
L['Widget Background Color'] = true
L['Widget Border Color'] = true
L['Padding X'] = true
L['Padding Y'] = true
L['Color Settings'] = true
L['Backdrop Settings'] = true

-- Home Page
L['Hello, '] = true
L['Version: '] = true
L['Active Profile: '] = true
L['Hide Minimap Icon'] = true
L['Hide Login Message'] = true
L['Toggle Anchors'] = true
L['Reload UI'] = true
L['ElvUI Integration'] = true
L['Use ElvUI Skinning'] = true
L['Disables all skinning modules when ElvUI is loaded.\n  This way you can still use the non skinning features of the addon without conflict.'] = true
L['Found a bug or have a suggestion?'] = true
L['Join the '] = true
L[' or open an issue on '] = true

-- Combat Modules --
-- Combat Cross
L['Cross'] = true
L['Dot'] = true
L['Diamond'] = true
L['Center Gap'] = true
L['Center Dot'] = true
L['Because of pixel alignment, I recommend using even numbers (2,4,6 etc.) for thickness when using the center dot.'] = true
L['Dot Size'] = true
L['Diamond Size'] = true
L['Range Warning'] = true
L['Enable for melee specs'] = true
L['Enable for ranged specs'] = true
L['Out of Range Color'] = true

-- Combat Message
L['Combat Message'] = true
L['Message Duration'] = true
L['Message Types'] = true
L['Enter Combat'] = true
L['Enter Combat Color'] = true
L['Enter Combat Message'] = true
L['Exit Combat'] = true
L['Exit Combat Color'] = true
L['Exit Combat Message'] = true
L['No Target'] = true
L['No Target Color'] = true
L['No Target Message'] = true
L['Group Member Died'] = true
L['Group Member Died Color'] = true
L['Group Member Died Message'] = true
L['Class Colored Name'] = true
L['Use |cffffffff%name|r to insert the name of the player who died and |cffffffff{rt1} - {rt8}|r to insert raid target icons.'] = true

-- Combat Res Tracker
L['Combat Res Tracker'] = true
L['Available Tokens'] = true
L['Battle res charges'] = true
L['Separator (chosen below)'] = true
L['Cooldown timer'] = true
L['Separator Type'] = true
L['Timer Format'] = true
L['Charges Available'] = true
L['Charges Unavailable'] = true

-- Sidebar
L['Profile Settings'] = true
L['Global Settings'] = true
L['Combat Util'] = true
L['Quality of Life'] = true
L['Class Utility'] = true
L['CVars'] = true

-- Global Page / UI Scale
L['1080p Scale'] = true
L['1440p Scale'] = true
L['Auto (Pixel Perfect)'] = true
L['Automatically match your resolution (768 / screen height).'] = true
L['Castbar Spark'] = true
L['Disable scaling in other addons to avoid conflicts.'] = true
L['Display Size'] = true
L['Enable UI Scale'] = true
L['Hide Shadows'] = true
L['Huge Size'] = true
L['Large Size'] = true
L['Medium Size'] = true
L['Scales the spark against the bar height. Art sparks keep their own proportions.'] = true
L['Set UI scale for 1080p resolution.'] = true
L['Set UI scale for 1440p resolution.'] = true
L['Small Size'] = true
L['Spark'] = true
L['Class Colored'] = true
L['Fade frames of units that are too far away to heal or attack.'] = true
L['Placed between two values in tags that show both, like current and max health.'] = true
L['How often, in seconds, texts on units without their own events (like target of target) refresh.'] = true
L['Dispel highlight style changes show after a reload.'] = true
L['Frame Colors'] = true
L['Editbox'] = true
L['Texture for the empty part of the bar, tinted by the backdrop color. Flat keeps a plain fill.'] = true
L['Borders & Backdrops'] = true
L['Used by every module set to follow the global border.'] = true
L['Used by every module set to follow the global backdrop.'] = true
L['Used by every castbar set to follow the global spark.'] = true
L['Used by every module set to follow the global texture.'] = true
L['Textures'] = true
L['Tiny Size'] = true
L['UI Scale'] = true
L['Use Global Bar Texture'] = true
L['Use Slug Rendering'] = true

-- Global Page / Duration Formatter
L['Breakpoint Colors'] = true
L['Curve Colors'] = true
L['Single Color'] = true
L['Duration text changes show on auras after a reload.'] = true
L['Color fades smoothly between breakpoints.'] = true
L['Color changes instantly at each breakpoint.'] = true
L['Hours (2h)'] = true
L['Looks Like'] = true
L['Minutes (3m)'] = true
L['Minutes and Seconds (2:10)'] = true
L['One color for everything.'] = true
L['Seconds (7)'] = true
L['Seconds with s (7s)'] = true
L['Shown As'] = true
L['Starts At'] = true
L['Tenths (2.4)'] = true
L['Tenths with s (2.4s)'] = true
L['Breakpoints'] = true
L['Start Time'] = true

-- Global Fonts
L['Anchor'] = true
L['Blizzard UI Font'] = true
L['Global'] = true
L['Global Font'] = true
L['Global follows the Blizzard UI outline and slug settings. Picking an explicit outline turns slug rendering off for this element.'] = true
L['Higher-quality glyph rendering on supported fonts, combined with the outline above where enabled.'] = true
L['Preview'] = true
L['Remove the drop shadow from styled fonts for a flatter look. Native shadows return when unchecked.'] = true

-- Profiles
L['(Active)'] = true
L['Active Profile'] = true
L['Copy Profile'] = true
L['Copy the string above (Ctrl+C)'] = true
L['Delete Profile'] = true
L['Enter profile name (leave empty for original)'] = true
L['Export Current Profile'] = true
L['Export Profile'] = true
L['Import'] = true
L['Import Profile'] = true
L['Import from String'] = true
L['Import/Export'] = true
L['New Name'] = true
L['Next'] = true
L['Paste import string'] = true
L['Profile Name'] = true
L['Rename Profile'] = true
L['This Character'] = true
L['Per Specialization'] = true
L['This character uses one profile in every specialization.'] = true
L['Changing specialization switches to its profile.'] = true
L['Every character uses the same profile.'] = true
L['Use %s on every character?\nOther characters switch the next time they log in.'] = true
L['Turn off the global profile?\nEvery character goes back to its own choice.'] = true
L['Profile for All Characters'] = true
L['Start From'] = true
L['Create Profile'] = true
L['Copy Into'] = true
L['In use by:'] = true
L["Copy all settings from '%s' into '%s'?\nThis overwrites every setting in '%s'."] = true
L["Reset all settings in '%s' to defaults?\nThis cannot be undone."] = true
L['Defaults'] = true
L['Reset Profile'] = true

-- Theme Page
L["Accent colors will match your character's class color."] = true
L['Background colors will use the Dark theme.'] = true
L['Class Color Mode'] = true
L['The class color above is used for accents and selections.'] = true
L['Copy From'] = true
L['Copy colors from a preset theme as a starting point.'] = true
L['Fully customize every color in the theme.'] = true
L['Preset Theme'] = true
L['Quick Setup'] = true
L['Reset All Theme Settings'] = true
L['Reset Custom'] = true
L['Theme Mode'] = true
L["This will reset theme mode to 'Preset' with the NUI v2 theme."] = true
L['Use one of the pre-made color themes.'] = true

-- Home Page
L['Welcome to NorskenUI'] = true

-- Combat Cross

-- Combat Message
L['DPS Sound'] = true
L['Healer Sound'] = true
L['Layout & Position'] = true
L['Tank Sound'] = true

-- Combat Timer
L['Background Height'] = true
L['Background Width'] = true
L['Combat Only'] = true
L['Print Duration to Chat'] = true

-- Range Checker
L['Close (0-10)'] = true
L['Color Gradient'] = true
L['Far (40+ yards)'] = true
L['Mid-Close (10-20)'] = true
L['Mid-Far (20-40)'] = true
L['Range Checker'] = true
L['Show In Combat Only'] = true
L['Update Throttle'] = true

-- Cursor Circle
L['Cursor Circle'] = true
L['GCD Mode'] = true
L['GCD Ring'] = true
L['GCD Settings'] = true
L['Main Ring'] = true
L['Main Ring Settings'] = true
L['Only In Combat'] = true
L['Reverse Swipe'] = true
L['Ring Color Mode'] = true
L['Ring Size'] = true
L['Swipe Color Mode'] = true
L['Visibility'] = true

-- Focus Castbar
L['Bar Appearance'] = true
L['Bar Texture'] = true
L['Colors & Indicators'] = true
L['Height'] = true
L['Hold Timer'] = true
L['Important Spell Glow'] = true
L['Interrupted'] = true
L['Kick Indicator'] = true
L['Not Ready'] = true
L['Raid Marker'] = true
L['Spell Name'] = true
L['Target Name'] = true
L['Target Names'] = true
L['Tick'] = true
L['Tick Width'] = true
L['Uninterruptible'] = true
L['Use Global Bar'] = true
L['Width'] = true

-- Potion Ready
L['Alert Color'] = true
L['Alert Text'] = true
L['Potion Ready'] = true

-- Gateway Alert
L['Gateway Usable Alert'] = true

-- Missing Buffs
L['Click to Cast'] = true
L['Raid Buff Mode'] = true
L['Count Anchor'] = true
L['Count X'] = true
L['Count Y'] = true
L['Timer Anchor'] = true
L['Timer X'] = true
L['Timer Y'] = true
L['Personal'] = true
L['Item Picker Direction'] = true
L['Which way the item picker opens from the icon.'] = true
L['Empty Bags'] = true
L['Preferred Runes'] = true
L['Weapon'] = true
L['2H'] = true
L['Whether your weapon has one of the runes ticked below, or any rune if you leave a column empty.'] = true
L['Show Normally'] = true
L['Show Desaturated'] = true
L['What the icon does when you have none of the item in your bags.'] = true
L['Click an icon out of combat to cast the buff or use the consumable.'] = true
L['Whether you have the buff, when someone in the group can cast it.'] = true
L['Group Presence'] = true
L['Targeted Buffs'] = true
L['Self Buffs'] = true
L['Consumables'] = true
L['Whether you have the buff. Pick the zones under Load Conditions, Zone.'] = true
L['Your own cast, on any group member.'] = true
L['Tracked everywhere, including combat.'] = true
L['Falls back to the action bar glow in combat, Mythic+ and encounters.'] = true
L['Hidden in combat, Mythic+ and encounters, the game keeps it secret there.'] = true
L['Display only.'] = true
L['Casts %s when you know it.'] = true
L['Checks: '] = true
L['Combat: '] = true
L['Click: '] = true
L['Enable %s'] = true
L['Warn When Under (Minutes)'] = true
L['Show the icon again once the buff has this many minutes left, 0 turns it off.'] = true
L['Item Picker Modifier'] = true
L['Hold this and click a flask, rune, food or weapon oil icon to pick which item to use. The pick is remembered for your current spec.'] = true
L['Behaviour (All Groups)'] = true
L['Every group member the buff helps, from any caster.'] = true
L['Anyone in the group, one copy covers the whole group.'] = true
L['Whether you have the buff or weapon enchant.'] = true
L['Shown for a moment after entering a dungeon or raid, while the spell is ready.'] = true
L['All classes'] = true
L['Uses a cauldron flask when you have one, otherwise the flask this spec last picked.'] = true
L['Uses the oil or stone this spec last picked that fits your weapon.'] = true
L['Uses the one this spec last picked.'] = true
L['%s-click to pick another.'] = true
L['Whether you have the buff.'] = true
L['Whether you carry one in your bags.'] = true
L['Whether the weapon has an oil or stone on it.'] = true
L['Only during a ready check.'] = true

-- Pet Status Texts
L['Dead Color'] = true
L['Missing Color'] = true
L['Passive Color'] = true
L['Pet Dead Text'] = true
L['Pet Missing Text'] = true
L['Pet Passive Text'] = true
L['Pet Status Texts'] = true
L['State Settings'] = true

-- XP Bar
L['Bar Height'] = true
L['Bar Settings'] = true
L['Bar Size'] = true
L['Bar Width'] = true
L['Custom Foreground Color'] = true
L['Custom Quest Color'] = true
L['Custom Rested Color'] = true
L['Foreground Color Mode'] = true
L['Progress Texture'] = true
L['Quest Color Mode'] = true
L['Quest Texture'] = true
L['Rested Color Mode'] = true
L['Rested Texture'] = true
L['Show Quest Bar'] = true
L['Show Rested Bar'] = true
L['Text Color'] = true
L['XP Bar'] = true

-- QoL CVars
L['CVar Browser'] = true
L['Dev CVars'] = true
L['General CVars'] = true
L['Learn More'] = true
L['Open Guide'] = true
L['SQW CVar'] = true
L['Spell Queue Window'] = true

-- Global Page: color categories & status
L['Power Colors'] = true
L['Reaction Colors'] = true
L['Class Colors'] = true
L['Tapped'] = true
L['Disconnected'] = true
L['Dead'] = true

-- Profile messages & dialogs
L['Unknown error'] = true
L['Failed to create profile: %s'] = true
L['Failed to copy profile: %s'] = true
L['Failed to rename: %s'] = true
L["Are you sure you want to delete '%s'?\nThis cannot be undone."] = true
L['Failed to delete profile: %s'] = true
L['Export Success'] = true
L['Export failed: %s'] = true
L['Imported profile: %s'] = true
L['Import failed: %s'] = true
L['Profile manager is not available.'] = true

-- Tooltips Skinning
L['Tooltip Skinning'] = true
L['Hide Threat Line'] = true
L['Hides the current threat line on tooltips for units that you are in combat with.'] = true
L['Show Mount'] = true
L['Shows the mount a player is currently riding on their tooltip when holding shift.'] = true
L['Item Quality Borders'] = true
L['Color tooltip borders by item quality, falls back to the border color for everything else.'] = true
L['StatusBar Settings'] = true
L['Show StatusBar'] = true
L['Toggles health statusbar on unit tooltips.'] = true
L['Combat Visibility'] = true
L['Hide Tooltips in Combat'] = true
L['Hides the selected tooltip types during combat. Hold the override key to temporarily show them.'] = true
L['Override Key'] = true
L['Includes toys and equipment sets.'] = true
L['Includes mounts, macros and flyouts.'] = true
L['Header Text'] = true
L['Normal Text'] = true
L['Small Text'] = true

-- Minimap Skinning
L['Mouse Middle-click: Opens calendar.'] = true
L['Mouse Right-click: Opens tracking menu.'] = true
L['Minimap Settings'] = true
L['Minimap Size'] = true
L['Minimap Scale'] = true
L['Border Size'] = true
L['Anchorpoint'] = true
L['Buttons'] = true
L['Mail Icon Settings'] = true
L['Show Mail Icon'] = true
L['Instance Difficulty Settings'] = true
L['Show Instance Difficulty'] = true
L['Queue Icon Settings'] = true
L['Show Queue Icon'] = true
L['BugSack Settings'] = true
L['Toggle BugSack Frame'] = true
L['BugSack Size'] = true
L['Landing Page Button Settings'] = true
L['Show Landing Page Button'] = true
L['AddOn Compartment Settings'] = true
L['Show AddOn Compartment'] = true

-- QoL: Copy Anything
L['Copy Anything'] = true
L['Functionality Info'] = true
L['Copies SpellID, ItemID, AuraID, MacroID and Unitnames on mouseover'] = true
L['Limited functionality in certain environments because of secret values.'] = true
L['Keybind Settings'] = true
L['Copy Modifier Key(s)'] = true
L['Ctrl + Shift'] = true
L['Ctrl + Alt'] = true
L['Ctrl + Shift + Alt'] = true
L['Copy Keybind, Single Letter Only'] = true

-- QoL: Tweaks
L['Hide Misc Elements'] = true
L['Hide Talking Head Frame'] = true
L['Hide Boss Banner'] = true
L['Misc Tweaks'] = true
L['Confirm Popups with Enter'] = true

-- QoL: Recuperate Button
L['Because of restrictions i cannot fully hide the button when loaded and at '] = true
L['|cffFFFFFFfull health|r'] = true
L['|cffFFFFFFnot in combat.|r'] = true
L['This means that the button is invisible but is still clickable.'] = true
L['Load in Raid'] = true
L['Load in Party'] = true
L['Button Size'] = true

-- QoL: Automation
L['Override Behaviour'] = true
L['Hold to Skip'] = true
L['Hold to Enable'] = true
L['Override Info'] = true
L['Automation features that has override support are marked with'] = true
L['Cinematics & Dialogs'] = true
L['Auto Skip Cinematics & Movies'] = true
L['Auto Hide Spammy Tutorial Helptips'] = true
L['Merchant'] = true
L['Merchant Automation'] = true
L['Auto Sell Junk/Grey Items'] = true
L['Auto Repair Gear'] = true
L['Use Guild Funds for Repair'] = true
L['Group Finder'] = true
L['Auto Accept Group Finder Role Check'] = true
L['Role based on selected roles in the Group Finder.'] = true
L['Convenience'] = true
L['Auto-Fill DELETE Text'] = true
L['Auto Loot'] = true
L['Fast Loot'] = true
L['Quests'] = true
L['Auto Accept Regular Quests'] = true
L['Auto Accept Event Quests'] = true
L['Auto Accept Daily Quests'] = true
L['Auto Accept Weekly Quests'] = true
L['Auto Complete Quests'] = true
L['Auto Bonus Roll Quest'] = true
L['Automatically complete and turn in quests when there is no reward choice.'] = true
L['Automatically accept and complete the weekly |cffffffffBonus Roll|r quest from Decimus.'] = true
L['Auto Bonus Roll Mode'] = true

-- QoL: Quest Tracker
L['A name of your own, shown instead of the quest title. Leave empty to use the title.'] = true
L['Add Quest ID'] = true
L['Hidden Quest'] = true
L['Tracked Quests'] = true
L['Type a quest ID and press Enter to track it on every character.'] = true
L['A Done from before the last reset shows as not started.'] = true
L['Character Tab Only'] = true
L['Daily'] = true
L['Hide the panel on the Reputation and Currency tabs.'] = true
L['Never'] = true
L['Never load this, whatever the conditions below say. A group takes everything inside it along.'] = true
L['Only max level characters are listed.'] = true
L['Resets'] = true
L['Right-click a quest in your log to track it.'] = true
L['Status saves as you play, on every character.'] = true
L['Weekly'] = true
L['Right-click to hide it from the panel'] = true
L['Right-click to show it on the panel'] = true

-- QoL: Auction House Filter
L['Auction House Filter'] = true
L['Blizzard Auction House'] = true
L['Current Expansion Only'] = true
L['Auto Focus Search Bar'] = true
L['Crafting Orders'] = true
L['Auctionator, '] = true
L['Loaded'] = true
L['Not Loaded'] = true

-- QoL: Durability Util
L['Durability Util'] = true
L['Durability Low Warning'] = true
L['Low Threshold Text'] = true
L['Low Threshold Color'] = true
L['Broken Text'] = true
L['Broken Color'] = true
L['Threshold %'] = true

-- QoL: Character Panel
L['Character Panel'] = true
L['Gear'] = true
L['Panel Texts'] = true
L['Adds upgrade track letters to the character panel gear slots.'] = true
L['Adds a bar next to the character tabs for socketing gems and applying enchants from your bags.'] = true
L['Item Track Indicators'] = true
L['Show Item Track Letters'] = true
L['Shows |cffFF8000M|r / |cffC74DC7H|r / |cff00B3FFC|r / |cff00CC00V|r / |cffFFFFFFA|r on the equipped gear slots for the Myth, Hero, Champion, Veteran and Adventurer tracks.'] = true
L['Gem Sockets'] = true
L['Enable Gem Socket Helper'] = true
L['Shows the sockets of your equipped gear, click one to pick a gem from your bags.'] = true
L['Show Only Empty Sockets'] = true
L['Hide sockets that already have a gem in them.'] = true
L['Enable Enchant Helper'] = true
L['Item Level'] = true
L['Show Decimal Item Level'] = true
L['Shows your average item level with 2 decimals instead of a rounded value.'] = true
L['Name & Level'] = true
L['Show Faction Tag'] = true
L['Appends |cff3399ff(A)|r or |cffe63333(H)|r to the level text.'] = true
L['Show Realm & Race'] = true
L['Adds a line with your realm and race under the level text.'] = true
L['Category Titles'] = true
L['Colors the Item Level, Attributes and Enhancements headers in the stats pane.'] = true
L['Name Text Size'] = true
L['Level Text Size'] = true
L['Category Size'] = true
L['Item Level Size'] = true
L['Stats Size'] = true
L['Adds a button to the socket bar that applies enchants from your bags, highlighting the slots each one fits.'] = true

-- QoL: Skyriding UI
L['Show Vigor'] = true
L['Show Whirling Surge'] = true
L['Show Second Wind'] = true
L['Recolor On Thrill Of The Skies'] = true
L['Pill Spacing'] = true
L['Bar Colors'] = true
L['Vigor Color Mode'] = true
L['Custom Vigor Color'] = true
L['Thrill Color Mode'] = true
L['Custom Thrill Color'] = true
L['Whirling Surge Color Mode'] = true
L['Custom Whirling Surge Color'] = true
L['Second Wind Color Mode'] = true
L['Custom Second Wind Color'] = true
L['Speed Text'] = true
L['Show Speed Text'] = true
L['Speed Text Font'] = true

-- QoL: Spell Alerts
L['Spell Alerts'] = true
L['Alert Settings'] = true
L['Alert Scale'] = true
L['Alert Opacity'] = true
L['Settings Scope'] = true
L['Scales and fades the spell activation overlays, the glow that frames your screen when a proc lights up.'] = true
L['While enabled it takes over the Blizzard overlay CVars, your own values are stored and put back when you turn it off.'] = true
L['One set of values, shared by every specialization.'] = true
L['A separate set of values for this specialization only.'] = true
L['Only %s uses these values. Your other specializations keep their own.'] = true

-- QoL: CDM Profiles
L['Backs up Cooldown Manager layouts as profile strings you can restore later.'] = true
L['Layouts from your other characters are snapshotted on logout, so they stay available here.'] = true
L['Capture from CDM'] = true
L['Paste String'] = true
L['Paste Profile String'] = true
L['Cooldown Manager export string'] = true
L['Imported Profile'] = true
L['Backup'] = true
L['Actions'] = true
L['Save'] = true
L['Help'] = true
L['Specialization'] = true
L['Unknown Spec'] = true
L['Captured from'] = true
L['Last updated'] = true
L['Profile String'] = true
L['Copy String'] = true
L['Adds this backup to the CDM'] = true
L['Re-read this backup from the CDM layout of the same name and syncs it.'] = true
L['CTRL+V to paste, CTRL+A to select all'] = true
L['Matches the live layout'] = true
L['Differs from the live layout'] = true
L['No layout of this name on this character'] = true
L['Open the Cooldown Manager to compare'] = true
L['Capture a layout out of the Cooldown Manager, or paste a string, using the buttons on the left.'] = true
L['No Cooldown Manager layouts found. Open the Cooldown Manager once first.'] = true
L['Could not read the spec out of that string, pick one on the profile page.'] = true

-- Unit Frames GUI
L['Unit Frames'] = true
L['General'] = true
L['Defer To %s'] = true
L['%s is loaded and brings its own unit frames. Running both sets at once crashes the client, so keep this on unless you have turned that addon\'s unit frames off.'] = true
L['Unit frame ownership only changes on a fresh load.'] = true
L['Behaviour'] = true
L['Smooth Bars'] = true
L['Hide Blizzard Raid Frames'] = true
L["Takes Blizzard's compact raid frames and the raid utility off screen. The party ones already go with the party header, and only the raid half is left."] = true
L['Blizzard only builds its raid frames once, so handing them back needs a reload.'] = true
L['Range Fade'] = true
L['Enable Range Fade'] = true
L['In Range Alpha'] = true
L['Out of Range Alpha'] = true
L['Class Colored Health'] = true
L['Color health bars by class for players and by reaction for NPCs.'] = true
L['Foreground'] = true
L['Class Colored Castbar'] = true
L['Castbar Color'] = true
L['Absorbs'] = true
L['Use the shared bar texture from the Global Settings page.'] = true
L['Foreground Texture'] = true
L['Match Foreground'] = true
L['Use the foreground texture for the missing-health background.'] = true
L['Background Texture'] = true
L['Enable Highlight'] = true
L['Use the shared font from the Global Settings page.'] = true
L['Update Interval'] = true

-- NRSKNUI.FontOutlines
L['Group Growth Direction'] = true
L['Group Spacing'] = true
L['Which way each subgroup sits from the one before it.'] = true
L['Gap between one subgroup and the next.'] = true
L['Grouping & Sorting'] = true
L['Visibility Macro'] = true
L['Restore Default'] = true
L['Display Player'] = true
L['Start Near Center'] = true
L['Group By'] = true
L['Sort Method'] = true
L['Sort Direction'] = true
L['Role Order'] = true
L['Ascending'] = true
L['Descending'] = true
L['Index'] = true
L['Macro conditionals deciding when these frames are shown.'] = true
L['Growth Direction'] = true
L['Gap between each boss frame and the one before it.'] = true
L['Which way the chain grows away from the first boss frame.'] = true
L['Indicator'] = true
L['Anchor To'] = true
L['Override Texture'] = true
L['Inverse Fill'] = true
L['Use Global Colors'] = true
L['Class Color Alpha'] = true
L['Background (Class Colored)'] = true
L['Enable Power Bar'] = true
L['Mode'] = true
L['Docked'] = true
L['Undocked'] = true
L['Docked sits inside the frame along its bottom, the health bar making room. Undocked hangs below the frame.'] = true
L['Damage'] = true
L['Roles'] = true
L['Classes'] = true
L['Show For'] = true
L['Members whose role is picked get a power bar.'] = true
L['Only these classes get a power bar. Pick none for every class. Tank + Death Knight shows Blood runic power.'] = true
L['Color By Power Type'] = true
L['Enable Castbar'] = true
L['Show Icon'] = true
L['Show Spell Name'] = true
L['Show Cast Time'] = true
L['Non-Interruptible'] = true
L['Interrupted / Failed'] = true
L['Tag'] = true
L['Tag Text'] = true
L['Any oUF tag string, e.g. [NUF:name] or [perhp]%.'] = true
L['Bound To'] = true
L['Pins the far edge so long text truncates instead of overflowing.'] = true
L['Tank and Healer Only'] = true
L['Hide the role icon on damage dealers.'] = true
L['Which artwork the indicator draws.'] = true
L['Animate health and power bar changes. Units following the global setting inherit this.'] = true
L['Use Global Settings'] = true
L['Power Color'] = true
L['Color the bar by the power type (mana, rage, energy...). Uncheck to use a flat color.'] = true
L['Hold After Interrupt'] = true
L['Seconds the bar lingers after an interrupted or failed cast. Completed casts always hide immediately.'] = true
L['Safe Zone'] = true
L['Enable Safe Zone'] = true
L['Safe Zone Color'] = true
L['Shows your latency at the end of the cast, on the player frame only.'] = true
L['Enable Heal Absorb'] = true
L['Enable Heal Prediction'] = true
L['Max Health Reduction'] = true
L['Enable Max Health Reduction'] = true
L['Spell Cost'] = true
L['Show Spell Cost'] = true
L['Fix Blizzard Bugs'] = true
L['On login, untracks hidden quests and completed achievements stuck in the tracker, and keeps the dressing room maximized after a reset.'] = true
L['Greys out buttons while their action is on cooldown, ignoring the global cooldown.'] = true
L['Cooldown desaturation changes show after a reload.'] = true
L['Show Cast Target'] = true
L['Adds who the spell is being cast on after the spell name.'] = true
L['Show Interrupter'] = true
L['Names who interrupted the cast.'] = true
L['Color Important Casts'] = true
L['Casts the game flags as important, such as ones that are lethal if not interrupted.'] = true
L['Shades the part of the bar the spell you are casting will spend.'] = true
L['Enable Damage Absorb'] = true
L['Follow the shared absorb settings from the general settings.'] = true
L['Follow the safe zone settings from the general settings.'] = true

-- Aura Filter Builder --
L['Tracker'] = true
L['Trigger %d'] = true
L['Show Glow'] = true
L['Shows the glow all the time. Leave it off and let a condition show it, like Proc Glow.'] = true
L['Add Glow'] = true
L['Has Target'] = true
L['Attackable Target'] = true
L['Pixel Glow'] = true
L['Action Button Glow'] = true
L['Auto-Cast Shine'] = true
L['GCD Glow'] = true
L['Modern WoW Glow'] = true
L['Classic WoW Glow'] = true
L["Plays Blizzard's proc burst when the glow starts."] = true
L['A dark band behind the lines.'] = true
L['On Cooldown'] = true
L['On Global Cooldown'] = true
L['Recharging'] = true
L['Waiting'] = true
L['Supercharged'] = true
L['No Charges Left'] = true
L['Usable'] = true
L['Not Enough Resources'] = true
L['In Range'] = true
L['Proc Glow'] = true
L['Spell Overridden'] = true
L['Remaining Time'] = true
L['Count'] = true
L['True'] = true
L['False'] = true
L['Icon Color'] = true
L['Show Swipe'] = true
L['Inverse Swipe'] = true
L['Play Sound'] = true
L['%s Visible'] = true
L['%s Color'] = true
L['Glow Type'] = true
L['Sound'] = true
L['Else If'] = true
L['If'] = true
L['Operator'] = true
L['Then'] = true
L['Is Up'] = true
L['In Pandemic'] = true
L['While %s is up'] = true
L['While %s is in pandemic'] = true
L["The game hides whether an aura is up, so this check can't be combined with others and only changes the aura's own button."] = true
L['Aura Icon Texture'] = true
L['Aura Icon Color'] = true
L['Aura Icon Desaturate'] = true
L['Aura Icon Swipe'] = true
L['Aura Icon Inverse Swipe'] = true
L['Fill Overlay'] = true
L['Missing Overlay'] = true
L['Bar Overlay'] = true
L['Pandemic Border'] = true
L['Not %s'] = true
L['And'] = true
L['Glow Color'] = true
L['Add Property Change'] = true
L['Remove this property'] = true
L['If %s'] = true
L['Else If %s'] = true
L['ON'] = true
L['OFF'] = true
L['Global Conditions'] = true
L['Combinations'] = true
L['All of'] = true
L['Any of'] = true
L['and %s'] = true
L['or %s'] = true
L['and'] = true
L['or'] = true
L['Only checked when the condition above it does not match.'] = true
L["Else If doesn't work next to aura checks, the game keeps them secret."] = true
L["This can't change an aura's icon, the game locks it."] = true
L['Add Condition'] = true
L['Hide Passive Trinkets'] = true
L['Ignore Override'] = true
L['When Ready'] = true
L['Aura Overlay'] = true
L['Cooldown & Aura Manager Settings'] = true
L['Spell or aura'] = true
L['Timer bar'] = true
L['Any image'] = true
L["Your spec's resource"] = true
L['Move together'] = true
L['Auto layout'] = true
L['Rows above draw under its Aura Icon.'] = true
L['%s on Overlay'] = true
L['%s Color on Overlay'] = true
L['Cooldown & Aura Manager'] = true
L['Enable Cooldown & Aura Manager'] = true
L['Aura Group'] = true
L['New Aura Group'] = true
L['The icon this aura group shows in the list. Empty uses its first spell.'] = true
L["Keep tracking this spell's own cooldown and charges while another spell replaces it."] = true
L['A trinket without an on-use effect is not tracked.'] = true
L['Trinket Blacklist'] = true
L['Trinkets that are never tracked, for on-use effects that only switch a mode.'] = true
L['Back to %s'] = true
L['Click to remove it from the blacklist.'] = true
L['Add Trinket'] = true
L["An item ID. Trinkets on this list are never tracked, for on-use effects that only switch the trinket's mode."] = true
L['Aura'] = true
L['Cast Timer'] = true
L['Totem'] = true
L['A Tracked Bar from the Cooldown Manager, mirrored onto this bar. For entries that are not real auras, like Crusading Strikes.'] = true

-- CDM bars
L['Class in Group'] = true
L['Player/Unit Conditions'] = true
L['%s (%d picked)'] = true
L['Offset'] = true
L['Show When Not in Bags'] = true
L['In Bags'] = true
L['Show Display'] = true
L['New Progress Bar'] = true
L['Progress Bar'] = true
L['Days (3d)'] = true
L['Kicks in when this much time is left. Type 90, 5m, 1h or 1d.'] = true
L['Ease the bar to a new value or a new cast instead of jumping.'] = true
L['Blood'] = true
L['Unholy'] = true
L['Light Stagger'] = true
L['Moderate Stagger'] = true
L['Heavy Stagger'] = true
L['Rune Colors'] = true
L['Stagger Colors'] = true
L['Dispel Colors'] = true
L['Below'] = true
L['Above'] = true
L['Match Width'] = true
L["Take a dynamic group's width and sit against it. The width follows the group as icons come and go."] = true
L['Attach'] = true
L['Gap'] = true
L['Keep the bar up this long after the cast ends, for the Succeeded / Interrupted / Failed conditions. 0 hides it at once.'] = true
L['At Value'] = true
L['At Percent'] = true
L['Power Color follows the power type of a power trigger. Conditions can colour the bar per state, like a channel or an interrupted cast.'] = true
L["Shown while the cast trigger's Show Latency is on."] = true
L['Hidden while the bar is empty or full.'] = true
L["The bar's spell or item; power bars have none."] = true
L['The spark from the General page.'] = true
L['%s Settings'] = true
L['Show Tick'] = true
L['Placement'] = true
L['Automatic splits combo points, chi and other point resources into segments, and marks channel ticks and empower stages. At Value counts power, or seconds into a cast.'] = true
L['Placements'] = true
L['One or more values, comma separated.'] = true
L['Automatic Length'] = true
L['Spans the whole bar.'] = true
L['Add Tick'] = true
L['Empowering'] = true
L['Empower Stage'] = true
L['Succeeded'] = true
L['Failed'] = true
L['Cast'] = true
L['Power Type'] = true
L['Primary Power follows your form and spec.'] = true
L['All Casts'] = true
L['Specific Casts'] = true
L['Hold Time'] = true
L['Show Latency'] = true
L['Latency Color'] = true
L['Tick Color'] = true
L["Aura triggers aren't part of the combination system, the game keeps them secret."] = true
L['Icons (%d)'] = true
L['Bars (%d)'] = true
L['Texts (%d)'] = true
L['All (%d)'] = true
L['Hide Blizzard Player Cast Bar'] = true
L["For a cast bar of your own. Showing Blizzard's again takes a reload."] = true
L["Blizzard's cast bar comes back after a reload. Reload now?"] = true
L['Bar Color'] = true
L['Orientation'] = true
L['Right to Left'] = true
L['Left to Right'] = true
L['Bottom to Top'] = true
L['Top to Bottom'] = true
L['Smooth'] = true
L['Show Spark'] = true
L['Icon Side'] = true
L['Trinket 1'] = true
L['Trinket 2'] = true
L['Combat Potion'] = true
L['Custom Item'] = true
L['Source'] = true
L["Auras Blizzard's Cooldown Manager tracks for your current spec."] = true
L['Cast by Me'] = true
L['Item ID'] = true
L['Left-click to change its spell ID'] = true
L['Only casting this spell starts the timer, not a spell that replaces it, and its own icon is kept.'] = true
L['The spell that summons the totem.'] = true
L['Add Trigger'] = true
L['Load Preset'] = true
L['Replace the triggers with a preset, as a starting point to edit.'] = true
L['Replace every trigger with %s?\nThis cannot be undone.'] = true
L['Every trigger in this display watches this unit.'] = true
L['Each trigger is its own group of auras, shown together in this display.'] = true
L['Delete Trigger'] = true
L['Delete Trigger %d and everything set on it?\nThis cannot be undone.'] = true
L['Editing'] = true
L['Aura Type'] = true
L['Max Duration (seconds)'] = true
L['Cancelable'] = true
L['External Defensive'] = true
L['Raid In Combat'] = true
L['Raid Player Dispellable'] = true
L['Big Defensive'] = true
L['Dispellable'] = true
L['Include Nameplate Only'] = true
L['Boss Aura'] = true
L['Boss or Role Aura'] = true
L['Role Aura'] = true
L['Priority Aura'] = true
L['Stealable'] = true
L['From Player or Pet'] = true
L['Can Apply Aura'] = true
L['Ignore Dispel Types'] = true
L['Debuffs of these types never light the frame, but another debuff on the same unit still does. For example Bleed, when a fight puts one on everyone.'] = true
L['Stealth'] = true
L['Special'] = true
L['Blacklist'] = true
L['Whitelist'] = true
L['All Spells'] = true
L['Spell ID'] = true
L['Add'] = true
L['Important'] = true

-- Aura Displays (Advanced Debuffs / Defensives / Standard Buffs / Standard Debuffs) --
L['Buffs & Debuffs'] = true

-- Layout tab
L['Max Auras'] = true
L['Per Row'] = true
L['Element Spacing'] = true
L['Spacing between auras along the row.'] = true
L['Line Spacing'] = true
L['Spacing between aura rows.'] = true
L['Growth'] = true
L['Horizontal Growth'] = true
L['Vertical Growth'] = true
L['Weapon Enchants'] = true
L['Show Weapon Enchants'] = true
L['Flows the temporary main and off-hand enchants in front of the buffs.'] = true
L['Adding or removing the weapon enchants requires a reload to take full effect.'] = true
L['Spacing at the seam between the weapon enchants and the buffs.'] = true
L['Group Line Spacing'] = true
L['Spacing between the weapon enchant rows and the buff rows.'] = true

-- Filter tab
L['Applies per filter branch, so a filter with several branches can show more than this in total.'] = true

-- Aura indicator library (UnitFrames sidebar)
L['Stack Font Size'] = true
L['Duration Font Size'] = true
L["The text is colored by the indicator itself, on the Aura Indicators page."] = true
L['Every indicator that can fill this spot. Assign one per spec and the same spot works on all of them.'] = true
L['What to call this spot in the tab strip. Leave empty to number it.'] = true
L['Add Indicator'] = true
L['Nothing placed on this unit yet. Use Add Indicator below.'] = true
L["Multiplies the indicator's own color alpha, so 100% is exactly the color it carries."] = true
L['Dispellable by Anyone'] = true
L['Dispellable by You'] = true
L['Leave empty for a flat color. The color itself is set on the indicator.'] = true
L['Draw the tint over the bar instead of adding to it, so alpha reads as real opacity.'] = true
L['Style Settings'] = true
L['Style Type'] = true
L['Used by every style that draws its own artwork. The dispel styles are colored by the game instead.'] = true
L["Delete the indicator '%s'? This cannot be undone."] = true
L['An indicator with that name already exists'] = true
L['Attach To'] = true
L['Aura Icon'] = true
L['Aura Indicators'] = true
L['The preview follows straight away. Aura buttons are built once by the game, so the real indicator only picks a new style up after a reload.'] = true
L['Cooldown Spiral'] = true
L['Copied %d aura indicators from %s'] = true
L['Copy Aura Indicators'] = true
L['Create Indicator'] = true
L["Put '%s' back to how it shipped, its triggers and color included?"] = true
L['Reset %s to Default'] = true
L['Put every %s indicator back to how it shipped, triggers and colors included?'] = true
L['Your Indicators'] = true
L['Presets'] = true
L['Other Bars'] = true
L['Zone Names'] = true
L['Messages'] = true
L['In World'] = true
L['Delete Indicator'] = true
L['Dispel Colored Border'] = true
L['Duration Text'] = true
L['Health Bar'] = true
L['Health Fill'] = true
L['Indicator Name'] = true
L['Layer %d'] = true
L['Layers'] = true
L['Aura indicator layer changes show after a reload.'] = true
L['Put every layer back where it shipped?'] = true
L['Shared Layer %s'] = true
L['Draw Order'] = true
L['New Indicator'] = true
L['Overlay Tint'] = true
L['Paste Aura Indicators'] = true
L['Paste from %s'] = true
L['Paste from %s (Add)'] = true
L['Please enter an indicator name'] = true
L['Replace the %d aura indicators on %s with the %d copied from %s?'] = true
L['Square Texture'] = true
L['Stack Count'] = true
L['Which aura wins the slot when several match at once.'] = true

-- Dispel highlight (UnitFrames General + per unit)
L['Enable Dispel Highlight'] = true
L['Dispellable By'] = true
L['Use Global Dispel Settings'] = true
L['Colors the unit frame by the dispel type of a debuff on it. Only ever drawn on units you can help.'] = true
L['Follow the dispel highlight from the general settings.'] = true
L['The game answers this for your whole group, so Dispellable by You means anyone in it can remove the debuff. By Anyone is every debuff that carries a dispel type at all.'] = true
L['Keep the highlight up for matching auras that have no dispel type at all. The game colors these by dispel type, so they draw in its no-type color.'] = true
L['Solid tints the whole target evenly, Gradient fades it out across the target.'] = true
L['Pixels of dispel-colored border drawn around the target, on top of whichever style is set. 0 turns the border off.'] = true
L['Dispel Icon'] = true
L['Icon Size'] = true
L['Anchor Point'] = true
L["The game's own icon for the dispel type, drawn over the highlight."] = true
L['Which corner of the highlight the icon sits in.'] = true

-- Sorting (AuraContainerSortMethod / AuraContainerSortDirection)
L['Sorting'] = true
L['Expiration Only'] = true
L['Expiration'] = true
L['Important Only'] = true
L['Unit Frame Debuff'] = true
L['Name Only'] = true
L['Aura Instance ID'] = true
L['Reverse'] = true

-- Appearance tab
L['Aura Button Information'] = true
L['Aura buttons are built once by the game and cannot be restyled in place. The preview follows these settings straight away, the real auras pick them up after a reload.'] = true
L['Preview Limit'] = true
L['Caps how many icons the preview draws and the mover box covers. The game caps auras per filter branch and never per display, so this leaves the real auras alone.'] = true
L['Icons'] = true
L['Show Count'] = true
L['Show Duration'] = true
L['Draw Swipe'] = true
L['Draw Edge'] = true
L['Dispel Indicators'] = true
L['Show Border'] = true
L['Colors the aura border by dispel type.'] = true
L['Show Without Dispel Type'] = true
L['Keeps the border visible on auras that have no dispel type.'] = true
L['Show Dispel Icon'] = true
L['Shows the dispel type icon in the corner of the aura.'] = true
L['Dispel Icon Size'] = true
L['Hide Tooltip In Combat'] = true
L['Disable Mouse'] = true
L['Drops all mouse handling, so the auras never show a tooltip and never block clicks.'] = true
L['Apply Changes'] = true

-- Font tab
L['Stack Size'] = true
L['Duration Size'] = true
L['Text Position'] = true
L['Stack Anchor'] = true
L['Stack X'] = true
L['Stack Y'] = true
L['Duration Anchor'] = true
L['Duration X'] = true
L['Duration Y'] = true

-- Unit Frame Auras (per-unit buff/debuff containers) --
L['Groups Shown'] = true
L['Auto shows only the subgroups the raid actually fills, updated when you leave combat.'] = true
L['Include yourself in the party frames.'] = true
L['Groups Per Line'] = true
L['How many subgroups fit before the layout wraps onto a new line.'] = true
L['How members are ordered inside each group.'] = true
L['Role Priority %d'] = true
L['Gap between one frame and the next.'] = true
L['Keep the frames centered on the group, growing out from the middle as members join.'] = true
L['Following the safe zone in Unit Frames > General.'] = true
L['Shows your latency at the end of the cast.'] = true
L['Smoothing'] = true
L['Use Global'] = true
L['Use Global follows the smoothing setting from the general settings.'] = true
L['Use Global follows the smoothing setting from the general settings. Power smoothing only applies to the player frame.'] = true
L['Following the colors in Unit Frames > General.'] = true
L['Following the absorb settings in Unit Frames > General.'] = true
L['Edit Global Dispel Settings'] = true
L['Insert Tag'] = true
L['Misc'] = true
L['Prefix'] = true
L['Adds the picked tag to the end of the tag text. A prefix colors what follows it; close it with ||r.'] = true
L['What to call this tag in the tab strip. Leave empty to number it.'] = true
L['Remove Spot'] = true
L['The font face and outline come from the font settings.'] = true
L['Font Sizes'] = true

-- Aura Triggers & Displays --
L['Displays'] = true
L['New Display'] = true
L['Please enter a name'] = true
L['Trigger Type'] = true
L['Unit'] = true
L['Add to %s'] = true
L['Create New Group'] = true
L['Group Name'] = true
L['Remove from Group'] = true

-- Skinning: Action Bars --
L['Action Bars'] = true
L['Bar'] = true
L['Enable Bar'] = true
L['Bar Enable/Disable'] = true
L['Hide Profession Texture'] = true
L['Hide Macro Text'] = true
L['Hide Keybind Text'] = true
L['Hide Charge Text'] = true
L['Range Overlay'] = true
L['Tint drawn over buttons whose action is out of range.'] = true
L['Global Font Settings'] = true
L['Keybind Size'] = true
L['Cooldown Size'] = true
L['Charge Size'] = true
L['Macro Size'] = true
L['Global Mouseover Settings'] = true
L['Enable Global Mouseover'] = true
L['Override When Mounted/Vehicle'] = true
L['Keeps the bar visible while an override bar is active, such as while dragonriding.'] = true
L['Fade Out Alpha'] = true
L['Fade In Duration'] = true
L['Fade Out Duration'] = true
L['Total Buttons'] = true
L['Buttons Per Line'] = true
L['Layout Direction'] = true
L['Horizontal'] = true
L['Vertical'] = true
L['Grow Left'] = true
L['Grow Right'] = true
L['Flyout Direction'] = true
L['Auto'] = true
L['Screen Anchor'] = true
L['Mouseover'] = true
L['Use Global Mouseover Settings'] = true
L['Enable Mouseover'] = true
L['Use Global Font Sizes'] = true
L['Text Positions'] = true
L['Use Global Text Positions'] = true
L['Keybind Anchor'] = true
L['Charge Anchor'] = true
L['Macro Anchor'] = true
L['Text Visibility'] = true
L['Use Global Text Visibility'] = true
L['Hide Empty Backdrops'] = true
L['Hides the backdrop behind buttons that hold no action.'] = true

-- Skinning: Chat --
L['Chat'] = true
L['Chat Module Disabled'] = true
L['The chat module has been disabled.'] = true
L['A UI reload is recommended to fully restore the default chat.'] = true
L['Panel Size'] = true
L['Editbox & History'] = true
L['Editbox Position'] = true
L['Below Chat'] = true
L['Below Chat (Inside)'] = true
L['Above Chat'] = true
L['Above Chat (Inside)'] = true
L['Max Lines'] = true
L['Scroll Step'] = true
L['Number of messages scrolled per mouse wheel tick.'] = true
L['Text Settings'] = true
L['Channel Settings'] = true
L['Short Channel Names'] = true
L['Text Fading'] = true
L['Fade Chat Text'] = true
L['Fade Time (seconds)'] = true
L['Timestamps'] = true
L['Timestamp Format'] = true
L['Use Local Time'] = true
L['Custom Timestamp Color'] = true
L['Tab Font Size'] = true
L['Tab Settings'] = true
L['Tab Text Colors'] = true
L['Custom Selected Tab Color'] = true
L['Inactive Tab Color Mode'] = true
L['Tab Selector'] = true
L['Selector Style'] = true
L['Selector Color'] = true
L['Tab Backdrop'] = true
L['Enable Tab Backdrop'] = true

-- Skinning: Micro Menu --
L['Micro Menu Skinning'] = true
L['Button Settings'] = true
L['Button Width'] = true
L['Button Height'] = true
L['Button Spacing'] = true
L['Backdrop Spacing'] = true
L['Mouseover Settings'] = true
L['Enable Micro Menu Mouseover'] = true
L['Alpha When No Mouseover'] = true

-- QoL: Whisper Sounds
L['Whisper Sounds'] = true
L['Whisper Sound Alerts'] = true
L['Enable Whisper Sounds'] = true
L['Sound Selection'] = true
L['Whisper Sound'] = true
L['Battle.net Whisper Sound'] = true

-- Skinning: Details Backdrop --
L['Details Backdrop'] = true
L['Enable This Backdrop'] = true
L['Size Mode'] = true
L['Auto Size To Details Window'] = true
L['Amount Of Bars To Show'] = true
L['Backdrop Width'] = true
L['Backdrop Height'] = true
L['Details Override'] = true
L['This will override your current Details sizing. Are you sure?'] = true
L['Yes'] = true

-- Dungeons: Dungeon Casts --
L['Dungeons'] = true
L['Hide Un-Pulled Mobs'] = true
L['Casting'] = true
L['Channeling'] = true
L['Display Settings'] = true
L['Icon & Timer'] = true
L['Show Spell Icon'] = true
L['Show Cast Timer'] = true
L['Show Raid Marker'] = true
L['Spell Target'] = true
L['Show Spell Target'] = true
L['Class Color Target'] = true
L['After Spell Name'] = true
L['Before Timer'] = true

-- Dungeons: Reroll Keystone --
L['Text Size'] = true
L['Key Text Color'] = true
L['Key Text Size'] = true

-- Skinning: Frames --
L['Frames'] = true
L['Frame Skinning'] = true
L['Skin Colors'] = true
L['Accent Mode'] = true
L['Custom Accent'] = true
L['Color used for the highlights and accents on the skinned frames.'] = true
L['Blizzard Frames'] = true
L['Addons'] = true
L['Ace3 Config Windows'] = true
L['BigWigs Keystones'] = true
L['BigWigs Popups'] = true
L['Character Frame'] = true
L['Game Menu'] = true
L['Inspect Frame'] = true
L['Gossip Frame'] = true
L['Quest Frame'] = true
L['Right-Click Menus'] = true
L['Raider.IO'] = true
L['Simple Addon Manager'] = true
L['Spellbook & Talents'] = true
L['Runecarver'] = true
L['Static Popups'] = true
L['Talent Loadout Ex'] = true
L['Teleport Menu'] = true
L['Tab Text'] = true
L['Panel Text'] = true
L['Search Box'] = true

-- Skinning: Objective Tracker --
L['Objective Tracker'] = true
L['Objective Tracker Skinning'] = true
L['Font Styling'] = true
L['Enable Font Styling'] = true
L['The font face and shadow are taken from Skinning > Frames > Font Settings.'] = true
L['Quest Title Size'] = true
L['Quest Text Size'] = true

-- Skinning: Blizzard Mouseover --
L['Blizzard Mouseover'] = true
L['Alpha When Not Hovered'] = true
L['Alpha the element rests at while the mouse is away from it.'] = true
L['Fully hides the element instead of fading it in on mouseover.'] = true
L['Show Side Panel'] = true
L['Show Leader Score'] = true
L['Score Colors'] = true
L['Role Icons'] = true
L['Class Bar'] = true
L['Class Circle'] = true
L['Sort Order'] = true
L['Panel Width'] = true
L['Side Panel'] = true
L['Search Results'] = true
L['Requires the RaiderIO addon.'] = true

-- Aura trackers
L['Add Spell'] = true
L['Delete Group'] = true
L['Duplicate as Custom'] = true
L['No spell found'] = true
L["Put '%s' back to how it shipped, spells, layout and position included?"] = true
L['Remove the spells you added and switch every default spell back on?'] = true
L['Reset Everything to Default'] = true
L['Reset Spells to Default'] = true
L['Reset to Default'] = true
L['Reset all %s to their defaults?'] = true
L['Reaction'] = true
L['Unknown spell %d'] = true
L['%s is already listed'] = true
L['Add %s to %s'] = true
L['Add %s'] = true
L['A spell ID, or the name of a spell you know.'] = true
L['No spells yet.'] = true
L['No'] = true
L['Aura Filters'] = true
L['The tags Blizzard puts on the aura. Yes needs the tag, No hides auras that have it.'] = true
L['Candidate Filters'] = true
L['Checked after the aura filters, every one that is set has to match.'] = true
L['Dispel Types'] = true
L['Yes shows only these types, No hides them.'] = true
L['Aura Properties'] = true
L['What the aura is and what can be done with it.'] = true
L['Nameplate: Show All'] = true
L['Nameplate: Personal'] = true
L['Hide from the list until Reset'] = true
L['Right-click to switch it off'] = true
L['Right-click to switch it on'] = true
L['The group the list shows, and where an added spell goes.'] = true
L['No spells in this group yet.'] = true

-- Cooldown Manager
L['Cooldown Manager'] = true
L['New Group'] = true
L['New Icon'] = true
L['Ungroup'] = true
L["Delete '%s'? This cannot be undone."] = true
L["Delete '%s' and the %d displays inside it? This cannot be undone."] = true
L['Spell'] = true
L["Spells Blizzard's Cooldown Manager tracks for your current spec."] = true
L['Swipe Color'] = true
L['Show Global Cooldown'] = true
L['Run the swipe for the global cooldown too.'] = true
L["Hide this group's children"] = true
L["Show this group's children"] = true
L["Move this display down in its group's order"] = true
L["Move this display up in its group's order"] = true
L['Remove this display from its group'] = true
L['Animations'] = true
L['Custom Options'] = true
L['Expansion is disabled because this group has no children'] = true
L['Icon Settings'] = true
L['Dynamic Group Settings'] = true
L['Position and Size Settings'] = true
L['Group Icon'] = true
L['Icon ID'] = true
L['The icon this group shows in the list. Empty uses its first icon.'] = true
L['No Children'] = true
L['Displays inside with warnings: %d'] = true
L['ID'] = true
L['UID'] = true
L['Children'] = true
L['Displays Inside'] = true
L['Metadata'] = true
L['Debug'] = true
L['Create Debug Report'] = true
L['Sends a report of what this display is doing right now to BugSack, or to chat without it.'] = true
L['Export %s'] = true
L['Import a String'] = true
L['Add displays someone shared, or update the ones you have.'] = true
L['Import String'] = true
L['Contents'] = true
L['Paste a string to see what it adds.'] = true
L['Importing:'] = true
L['Made with NorskenUI %s'] = true
L['1 display'] = true
L['%d displays'] = true
L['You have this under another display type, so it can only be imported as a copy.'] = true
L['You already have this.'] = true
L['This is a changed version of your %s.'] = true
L['What do you want to do?'] = true
L['Update Displays'] = true
L['Choose an Icon'] = true
L['Browse icons'] = true
L['No icons found.'] = true
L['Loading icons...'] = true
L['Type a name or an ID to search.'] = true
L['File ID %d'] = true
L['An icon or spell name, or a file, spell or item ID.'] = true
L['Categories to Update'] = true
L['Added'] = true
L['Modified'] = true
L['Removed'] = true
L['Create a Copy'] = true
L['Import as Copy'] = true
L['Drag to move'] = true
L['Right-click for more options'] = true
L['Loaded/Standby'] = true
L['Standby'] = true
L['This display is currently loaded'] = true
L['This display is not currently loaded'] = true
L['This display is on standby, it will be loaded when needed.'] = true
L['Show or hide the loaded displays'] = true
L['Show or hide the displays that are not loaded'] = true
L['Toggle the visibility of all loaded displays'] = true
L['Toggle the visibility of all displays that are not loaded'] = true
L['Toggle the visibility of this display'] = true
L['Pinned: shown while the options are open. Click to hide.'] = true
L['Click to keep this display shown while the options are open.'] = true
L["Remove the group '%s'? Everything inside it stays."] = true
L['Delete Group and Contents'] = true
L['Delete All'] = true
L['Delete %d displays? This cannot be undone.'] = true
L['%d Displays'] = true
L['Static Single Bar'] = true
L['Static Segments'] = true
L['Recharging Segments'] = true
L['One bar for all your %s.'] = true
L['One segment each, filled while it is ready, empty otherwise.'] = true
L['Like Static Segments but each one fills up as it recharges.'] = true
L['Progress Source'] = true
L['A Cooldown Manager bar that fills the next %s, like Crusading Strikes.'] = true
L['Each %s'] = true
L['Repeat the text on every %s.'] = true
L['Outline every %s instead of the whole bar.'] = true
L['Resource Bar'] = true
L['Copy settings...'] = true
L['Paste Settings'] = true
L['Paste Group Settings'] = true
L['Paste Display Settings'] = true
L['Paste Trigger Settings'] = true
L['Paste Condition Settings'] = true
L['Paste Load Settings'] = true
L['This group has no icons yet.'] = true
L['New Dynamic Group'] = true
L['An icon file ID.'] = true
L['An icon file ID. Automatic uses it for triggers without an icon of their own, such as Player Stat.'] = true
L['Add Border'] = true
L['Add Text'] = true
L['New Text'] = true
L['The side the text grows from, and how its lines line up.'] = true
L['%s Font Size'] = true
L['%s Display Text'] = true
L['Bar Shows'] = true
L['Duration drains with the time left; Stacks fills with the stack count. %p and %s work in both.'] = true
L['Stacks'] = true
L['Max Stacks'] = true
L['The stack count of a full bar.'] = true
L['Placeholder'] = true
L['Stat'] = true
L['Player Stat'] = true
L['Player/Unit Info'] = true
L["Group Type"] = true
L['Loot Specialization'] = true
L['Is Current Spec'] = true
L['Current Spec'] = true
L['Not Current Spec'] = true
L['Quest Title'] = true
L['Progress State'] = true
L['In Hunt Zone'] = true
L['Hunt Hint'] = true
L['What %n shows. The state and hint are only known inside the hunt zone.'] = true
L['Current Specialization'] = true
L['Active while the loot specialization is one of these. None picked is any.'] = true
L['Whether loot goes to the spec you are playing. Loot set to Current Specialization always is.'] = true
L['%p is the percent, %t the rating, as the character sheet shows them. Versatility is its rating part.'] = true
L['Number Format'] = true
L['Hide Zero'] = true
L['%s shows nothing instead of 0.'] = true
L['Name Format'] = true
L["Trigger 2's name, e.g. the highest stat"] = true
L['First Letter'] = true
L['How %n reads. First Letter turns Mastery into M, Uppercase into MASTERY.'] = true
L['Uppercase'] = true
L['Name Color'] = true
L["The colour of %n. Custom uses the text's Color."] = true
L['How a Power or Stat value reads. Automatic: whole numbers, as the character sheet shows them.'] = true
L['How a Power value reads. Automatic: whole numbers. Percent: %p as a share of the max, like Stagger against your health.'] = true
L['Percent'] = true
L['Decimals'] = true
L['Short'] = true
L['Short (Large)'] = true
L['Separated (12,345)'] = true
L['Full'] = true
L['Value'] = true
L["The game reads this in combat, so it only colours a text showing this trigger's %p and can't be combined with others."] = true
L["The game reads this in combat, so it only colours a text showing this aura's %s and can't be combined with others."] = true
L['Spell icon'] = true
L["Trigger 2's icon"] = true
L['A percent sign'] = true
L['New line'] = true
L['Raid marker 1 to 8'] = true
L['On Power, %p is the value and %t the max; on Player Stat, %p is the percent and %t the rating.'] = true
L['Keep the empty bar and its border up while the aura is missing. Its look is the While Missing condition.'] = true
L['Keep the icon up while the aura is missing. Its look is the While Missing condition.'] = true
L['Is Missing'] = true
L['While %s is missing'] = true
L["The game hides whether an aura is up, so this check can't be combined with others and only changes the placeholder."] = true
L['Automatic'] = true
L['Border Offset'] = true
L['Crop the icon to the frame shape instead of stretching it.'] = true
L['Off leaves only the texts, borders and glows, such as an aura shown as just its stacks.'] = true
L['Desaturate'] = true
L['Display Text'] = true
L['Enable Swipe'] = true
L['Show Timer Text'] = true
L['Timer Text Settings'] = true
L["Whose countdown shows: Automatic is the icon's own, never an aura overlay's; a picked trigger's shows only while its layer does."] = true
L['Icon Source'] = true
L['Inverse'] = true
L['Keep Aspect Ratio'] = true
L['Manual Icon'] = true
L['Manual'] = true
L['Shadow'] = true
L['Show Edge'] = true
L['Show Text'] = true
L['Sub Elements'] = true
L['Integration'] = true
L['Unit Frame Anchor Minimum Width'] = true
L['The unit frame anchor is never narrower than this, so frames beside it keep their distance from a short group.'] = true
L['Unit Frame Anchor'] = true
L['Anchor Role'] = true
L['Primary'] = true
L['Secondary'] = true
L['The unit frame anchor follows the loaded group with this role. Give one group per class or spec the Primary role.'] = true
L['Limit Information'] = true
L["Auras and texts are secret, so we can't count how many are showing. Use Grid if you need a limit."] = true
L['These icons have different sub elements; edit them per icon.'] = true
L['Tooltip on Mouseover'] = true
L['Zoom'] = true
L["%p and %t can't share a text with %s."] = true
L["%s is dropped here: a time and a charge count can't share one text. Add a second text for it."] = true
L["The cooldown's own countdown, as the action bar shows it; unlike %p it speeds up with recovery-rate buffs."] = true
L['Charges'] = true
L['Swipe Settings'] = true
L['Any Triggers'] = true
L['All Triggers'] = true
L['Trigger Combination'] = true
L['Required for Activation'] = true
L['Dynamic information from first active trigger'] = true
L['Dynamic information from Trigger %d'] = true
L['Dynamic Information'] = true
L['%2.p, %2.t or %2.s read Trigger 2 instead of the shown trigger. A text reads one trigger.'] = true
L["There's no Trigger %d, so this text stays empty."] = true
L['Only shows on the Trigger %d overlay.'] = true
L["An aura can only show one timer and one stack count. An earlier text already shows it, so this one stays empty."] = true
L['Fixed'] = true
L['Time Format'] = true
L['Global uses the duration breakpoints from the global settings.'] = true
L['Increase Precision Below'] = true
L['Seconds left at which the time shows decimals. 0 never shows them.'] = true
L['Precision'] = true
L['Font Flags'] = true
L['Rotate Text'] = true
L['Automatic aligns the text to the side it is anchored on.'] = true
L['Fixed Width'] = true
L['Word Wrap'] = true
L['Off cuts a text longer than the width short instead of wrapping it.'] = true
L["The text's own point. Automatic keeps the text inside the icon at the frame's point."] = true
L['Format Options'] = true
L['Shadow %s with offset %d/%d'] = true
L["Anchored to frame's %s"] = true
L['%s with offset %d/%d'] = true
L['Spell name'] = true
L['Time left'] = true
L['Total time'] = true
L['Frame Strata'] = true
L['Inherited'] = true

-- ActionBars
L['Desaturate On Cooldown'] = true

-- AuctionHouseFilter
L["|cff00FF00Loaded|r"] = true
L["|cffFF0000Not Loaded|r"] = true

-- BigWigsTimers
L['About'] = true
L['Bar Text'] = true
L['Boss Mod Timer'] = true

-- BigWigsTimerTriggers
L['%n bar text, %t time left, %c count, %i icon, %s spell ID'] = true
L['Added to the time left before every test. Positive keeps the display up past the bar, negative fires it early.'] = true
L['Below (seconds)'] = true
L['BigWigs has no spells for this boss.'] = true
L['BigWigs sends a cast bar alongside the cooldown timer for the same spell.'] = true
L['BigWigs Spells'] = true
L['BigWigs Timers'] = true
L['Browse BigWigs Spells'] = true
L['Casts'] = true
L["Delete the timer '%s'? This cannot be undone."] = true
L['Delete Timer'] = true
L['How long the display stays up after the announce fires.'] = true
L['Left Text'] = true
L['Match'] = true
L['Matched against the announce text BigWigs shows.'] = true
L['Matched against the bar text BigWigs shows.'] = true
L['Message'] = true
L['No BigWigs data for this instance. Make sure BigWigs is installed and its module for this instance is available.'] = true
L['No spell selected'] = true
L['No spells match your search.'] = true
L['No Timer Selected'] = true
L['Offset Timer'] = true
L['On Hide'] = true
L['On Show'] = true
L['Only bars from this encounter can match the timer.'] = true
L['Only show while the time left passes this test.'] = true
L['Raids'] = true
L['Rename Timer'] = true
L['Right Text'] = true
L['Pick an instance on the left to add timers to it, or pick an existing timer.'] = true
L['Season %d Dungeons'] = true
L['Enable All'] = true
L['Disable All'] = true
L['Timers'] = true
L['Search spells'] = true
L['Seconds'] = true
L['Show Decimals'] = true
L['Sync With BigWigs Bar Coloring'] = true
L['Text Only'] = true
L['The BigWigs option key, usually a spell ID. Leave empty to match on message instead.'] = true
L['Timer Name'] = true
L['Unassigned'] = true
L['Use'] = true

-- BlizzardFonts
L['Blizzard Font Info'] = true
L['by default all families are set to 0, this means they use native size.'] = true
L['Changing the value either adds or subtracts from native size, e.g a native size of 16 with slider value of 2, becomes 18.'] = true
L['Font sizes have been split into 6 different size families, tiny, small, medium, large, huge and display.'] = true
L['native sizes 10 to 11'] = true
L['native sizes 12 to 14'] = true
L['native sizes 15 to 18'] = true
L['native sizes 19 to 24'] = true
L['native sizes 9 and below'] = true
L['native sizes above 24'] = true

-- CDMStrings
L["Delete the saved profile '%s'? This cannot be undone."] = true
L['Open Cooldown Manager Settings'] = true

-- FocusCastbar
L['Hide Uninterruptible Casts'] = true
L['Interruptible / Kick Ready'] = true

-- GlobalFonts
L['Each module can override the global font with its own font face.'] = true
L['Font selected above is applied to all modules and blizzard texts that support it.'] = true
L['Global Font Info'] = true

-- MiscVars
L['Combat Text CVars'] = true

-- MissingBuffs
L['Group shows a raid buff when anyone it helps is missing it. Personal shows it only when you are missing it and someone in the group can cast it. A buff you cast yourself always uses Group.'] = true
L['Needs %s'] = true
L['Needs a %s in the group'] = true
L['Not with %s'] = true

-- Pages / New
L['Groups & Premade Trackers'] = true
L['Multiple auras'] = true
L['Words or timers'] = true

-- PetTexts
L['Demo Warlock Wrong Pet Text'] = true
L['Wrong Color'] = true

-- Sidebar
L['CDM Profile Backup'] = true

-- SpellAlert
L['Every specialization uses these values baseline. Pick %s to give it a set of its own.'] = true
L['Select Scope'] = true

-- Tooltips
L['Aura container spell IDs while holding the key.'] = true
L['Mount tooltips on mounted players'] = true
L['Show Spell ID On Aura Container Tooltips'] = true
L['Show Spell ID On Aura Container Tooltips when holding the override key.'] = true
L['Skin Aura Container Tooltips'] = true
L['The key that must be held down to temporarily show tooltips while in combat.'] = true
L['This key is used to temporarily show: '] = true
L['Tooltips in combat'] = true

-- Triggers / Cast
L['Shades the end of the bar by the time your cast took to reach the server. Its color is on the Display tab.'] = true

-- Triggers / Item
L["Keep showing the item even when not in bags."] = true

-- UFUnits
L['-- Select --'] = true
L['Baseline Color'] = true
L['The color of the text, unless a tag overrides it.'] = true

-- ActionBars
L['Enabling bars requires a reload to take full effect.'] = true
L['Enabling/Disabling Action Bars requires a reload to take full effect.'] = true

-- BigWigsTimerTriggers
L['every 2nd'] = true
L['every 3rd from the 2nd to the 11th'] = true
L['every 3rd starting from the 2nd'] = true
L['Leave empty to match every occurrence.'] = true
L['the 2nd through 6th'] = true
L['the 2nd, 5th and 6th'] = true
L['Which occurrences of the bar to match, using the count BigWigs shows in brackets.'] = true

-- BlizzardFonts
L['Global (%s)'] = true

-- CDMStrings
L['CooldownViewerSettings not found. Make sure Cooldown Manager is enabled in Edit Mode.'] = true

-- FrameSkins
L['Restoring the default %s requires a reload to take full effect.'] = true
L['Restoring the default frames requires a reload to take full effect.'] = true

-- MicroMenu
L['Enabling/Disabling this UI element requires a reload to take full effect.'] = true

-- MiscVars
L['(Inactive)'] = true
L['Copy to clipboard by pressing CTRL + C'] = true
L['Spell Queue Window Guide'] = true
L["The spell queue window determines how early you can\nqueue your next ability before your current cast finishes.\nVisit |cff8788EEXerwo|r's maxroll guide for more information."] = true

-- NorskenUI_Options / Core
L['Close Settings'] = true
L['Disabling/Enabling this requires a reload to take full effect.'] = true
L['Join My %s'] = true
L['Open Anchors'] = true
L['Open Home Page'] = true
L['Open Theme Settings'] = true
L['Preview Every Display'] = true
L['Support My %s'] = true

-- ObjectiveTracker
L['Restoring the default Objective Tracker requires a reload to take full effect.'] = true

-- Tooltips
L['Changing the aura container skin requires a reload to take full effect.'] = true
L['Enabling Blizzard UI elements requires a reload to take full effect.'] = true

-- Tweaks
L['Disabling this setting requires a UI reload to take effect. Reload now?'] = true

-- GlobalLanguage
L['Auto (%s)'] = true
L['Auto follows the game client. Used on every character.'] = true
L['Fonts must include the characters of the picked language, or those letters show as boxes.'] = true
L['Language'] = true
L['Language Info'] = true
L['Text without a translation in the picked language shows in English.'] = true
L['The new language shows after a reload.'] = true

-- BigWigsTimerTriggers
L['B%d %s'] = true

-- CursorCircle
L['Circle %d'] = true

-- Role settings
L['All Roles'] = true
L['Reset Everything'] = true
L['Reset %s'] = true
L['Reset only the %s settings for %s, or everything including the role settings?'] = true
L['Show %s on every one of its pages, or hide it on its own'] = true
L['Move %s, with every other anchor hidden'] = true
L['Put %s back to its defaults'] = true
L['Give a role its own settings'] = true
L['Remove %s settings'] = true
L['Remove the %s settings?'] = true
L['%s specs go back to the %s settings.'] = true
L['Elements'] = true
L['Backdrops'] = true
