-- English enUS and enGB localization file.
local L = LibStub('AceLocale-3.0'):NewLocale('NorskenUI', 'enUS', true, true)

-- General --

-- NRSKNUI.ColorModeOptions
L['Class Color'] = true
L['Custom Color'] = true
L['Theme Color'] = true

-- General GUI
L['General Settings'] = true
L['Outline'] = true
L['Thickness'] = true
L['Length'] = true
L['Color'] = true
L['Colors'] = true
L['Color Mode'] = true
L['Appearance'] = true
L['Layout'] = true
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
L['Separator'] = true
L['Format Text'] = true
L['Backdrop'] = true
L['Background Color'] = true
L['Border Color'] = true
L['Padding X'] = true
L['Padding Y'] = true
L['Color Settings'] = true
L['Backdrop Settings'] = true
L['Font Settings'] = true
L['Position Settings'] = true

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
L['Combat Cross'] = true
L['Style'] = true
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
L['Enable Combat Message'] = true
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
L['Enable Combat Res Tracker'] = true
L['Text Format'] = true
L['Format'] = true
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
L['Aura Filters'] = true
L['Defensives'] = true
L['Class Utility'] = true
L['CVars'] = true

-- Global Page / UI Scale
L['1080p Scale'] = true
L['1440p Scale'] = true
L['Auto (Pixel Perfect)'] = true
L['Automatically match your resolution (768 / screen height).'] = true
L['Castbar Spark'] = true
L['Disable scaling in other addons to avoid conflicts.'] = true
L['Enable UI Scale'] = true
L['Enable this to use the same bar texture across all modules.'] = true
L['Enable this to use the same spark texture across all castbars.'] = true
L['Font Size'] = true
L['Global Bar'] = true
L['Global Bar Texture'] = true
L['Global Spark'] = true
L['Global Spark Texture'] = true
L['Global Textures'] = true
L['Hide Shadows'] = true
L['Huge Size'] = true
L['Large Size'] = true
L['Medium Size'] = true
L['Only the solid spark can be widened, art sparks keep their own proportions.'] = true
L['Scale'] = true
L['Scales the spark against the bar height. Art sparks keep their own proportions.'] = true
L['Set UI scale for 1080p resolution.'] = true
L['Set UI scale for 1440p resolution.'] = true
L['Small Size'] = true
L['Spark'] = true
L['Spark Color'] = true
L['Spark Scale'] = true
L['Spark Texture'] = true
L['Spark Width'] = true
L['Style Blizzard Fonts'] = true
L['UI Scale'] = true
L['UI Scale Settings'] = true
L['Use Global Bar Texture'] = true
L['Use Global Spark'] = true
L['Use Global Spark Texture'] = true
L['Use Global Font'] = true
L['Use Slug Rendering'] = true

-- Global Fonts
L['Anchor'] = true
L["Apply your global font face across Blizzard's UI, adding an outline where it reads cleanly. Big display text and unsafe fonts keep their native outline."] = true
L['Blizzard UI Font'] = true
L['Enable'] = true
L['Font'] = true
L['Global'] = true
L['Global Font'] = true
L['Global follows the Blizzard UI outline and slug settings. Picking an explicit outline turns slug rendering off for this element.'] = true
L['Higher-quality glyph rendering on supported fonts, combined with the outline above where enabled.'] = true
L['Position'] = true
L['Preview'] = true
L['Remove the drop shadow from styled fonts for a flatter look. Native shadows return when unchecked.'] = true
L['X Offset'] = true
L['Y Offset'] = true

-- Profiles
L['(Active)'] = true
L['Active Profile'] = true
L['Cancel'] = true
L['Copy'] = true
L['Copy Profile'] = true
L['Copy the string above (Ctrl+C)'] = true
L['Create'] = true
L['Create New Profile'] = true
L['Current Profile'] = true
L['Current Profile: '] = true
L['Delete'] = true
L['Delete Profile'] = true
L['Enable Spec Profiles'] = true
L['Enter profile name (leave empty for original)'] = true
L['Error'] = true
L['Export Current Profile'] = true
L['Export Profile'] = true
L['Global Profile'] = true
L['Global Profile Changed'] = true
L['Global Profile Enabled'] = true
L['Import'] = true
L['Import Profile'] = true
L['Import from String'] = true
L['Import/Export'] = true
L['Later'] = true
L['Manage'] = true
L['New Name'] = true
L['Next'] = true
L['Paste import string'] = true
L['Profile Changed'] = true
L['Profile Name'] = true
L['Profile to Delete'] = true
L['Profile to Rename'] = true
L['Profiles'] = true
L['Reload Now'] = true
L['Rename'] = true
L['Rename Profile'] = true
L['Reset'] = true
L['Reset Profile'] = true
L['Reset to Defaults'] = true
L['Source Profile'] = true
L['Specialization Profiles'] = true
L['Use Global Profile'] = true

-- Theme Page
L["Accent colors will match your character's class color."] = true
L['Background colors will use the Dark theme.'] = true
L['Class Color Mode'] = true
L['Copy From'] = true
L['Copy colors from a preset theme as a starting point.'] = true
L['Custom'] = true
L['Fully customize every color in the theme.'] = true
L['Preset Theme'] = true
L['Quick Setup'] = true
L['Reset All Theme Settings'] = true
L['Reset Custom'] = true
L['The class color above is used for accents and selections.'] = true
L['Theme'] = true
L['Theme Mode'] = true
L["This will reset theme mode to 'Preset' with the NUI v2 theme."] = true
L['Use one of the pre-made color themes.'] = true

-- Home Page
L['Welcome to NorskenUI'] = true

-- Combat Cross
L['Enable Combat Cross'] = true

-- Combat Message
L['DPS Sound'] = true
L['Healer Sound'] = true
L['Layout & Position'] = true
L['Tank Sound'] = true

-- Combat Timer
L['Background Height'] = true
L['Background Width'] = true
L['Combat Only'] = true
L['Combat Timer'] = true
L['Enable Combat Timer'] = true
L['In Combat'] = true
L['Options'] = true
L['Out of Combat'] = true
L['Print Duration to Chat'] = true

-- Range Checker
L['Close (0-10)'] = true
L['Color Gradient'] = true
L['Enable Range Checker'] = true
L['Far (40+ yards)'] = true
L['Mid-Close (10-20)'] = true
L['Mid-Far (20-40)'] = true
L['Range Checker'] = true
L['Show In Combat Only'] = true
L['Update Throttle'] = true

-- Cursor Circle
L['Cursor Circle'] = true
L['Enable Cursor Circle'] = true
L['GCD Mode'] = true
L['GCD Ring'] = true
L['GCD Settings'] = true
L['Main Ring'] = true
L['Main Ring Settings'] = true
L['Only In Combat'] = true
L['Reverse Swipe'] = true
L['Ring Color Mode'] = true
L['Ring Size'] = true
L['Size'] = true
L['Swipe Color Mode'] = true
L['Texture'] = true
L['Visibility'] = true

-- Focus Castbar
L['Background'] = true
L['Bar Appearance'] = true
L['Bar Texture'] = true
L['Border'] = true
L['Cast / Kick Ready'] = true
L['Center'] = true
L['Colors & Indicators'] = true
L['Duration'] = true
L['Enable Focus Castbar'] = true
L['Focus Castbar'] = true
L['Glow Settings'] = true
L['Height'] = true
L['Hide Uninterruptible'] = true
L['Hold Timer'] = true
L['Important Spell Glow'] = true
L['Interrupted'] = true
L['Kick Indicator'] = true
L['Left'] = true
L['Not Ready'] = true
L['Raid Marker'] = true
L['Right'] = true
L['Spell Name'] = true
L['Success'] = true
L['Target Name'] = true
L['Target Names'] = true
L['Text'] = true
L['Tick'] = true
L['Tick Width'] = true
L['Uninterruptible'] = true
L['Use Global Bar'] = true
L['Width'] = true

-- Potion Ready
L['Alert Color'] = true
L['Alert Text'] = true
L['Enable Potion Ready'] = true
L['Load Conditions'] = true
L['Potion Ready'] = true

-- Gateway Alert
L['Enable Gateway Alert'] = true
L['Gateway Alert'] = true
L['Gateway Usable Alert'] = true

-- Pet Status Texts
L['Dead Color'] = true
L['Enable Pet Status Texts'] = true
L['Missing Color'] = true
L['Passive Color'] = true
L['Pet Dead Text'] = true
L['Pet Missing Text'] = true
L['Pet Passive Text'] = true
L['Pet Status Texts'] = true
L['State Settings'] = true

-- XP Bar
L['Backdrop Color'] = true
L['Bar Height'] = true
L['Bar Settings'] = true
L['Bar Size'] = true
L['Bar Width'] = true
L['Custom Foreground Color'] = true
L['Custom Quest Color'] = true
L['Custom Rested Color'] = true
L['Enable XP Bar'] = true
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
L['Status Colors'] = true
L['Tapped'] = true
L['Disconnected'] = true
L['Dead'] = true

-- Anchor Points
L['Top Left'] = true
L['Top'] = true
L['Top Right'] = true
L['Bottom Left'] = true
L['Bottom'] = true
L['Bottom Right'] = true

-- Profile messages & dialogs
L['A UI reload is recommended to fully apply all settings.'] = true
L['Unknown error'] = true
L['Failed to switch profile: %s'] = true
L["Profile switched to '%s'."] = true
L['Global profile mode enabled.'] = true
L['Global profile mode disabled'] = true
L['Failed to set global profile: %s'] = true
L["Global profile switched to '%s'."] = true
L['Global profile set to: %s'] = true
L['Reset all settings in current profile to defaults?\nThis cannot be undone.'] = true
L['Failed to reset profile'] = true
L['Please enter a profile name'] = true
L['Created profile: %s'] = true
L['Failed to create profile: %s'] = true
L['Please select a source profile'] = true
L["Copy all settings from '%s' to current profile?\nThis will overwrite your current settings."] = true
L['Failed to copy profile: %s'] = true
L['Please select a profile to rename'] = true
L['Please enter a new name'] = true
L["Renamed '%s' to '%s'"] = true
L['Failed to rename: %s'] = true
L['Please select a profile to delete'] = true
L['Cannot delete the active profile'] = true
L["Are you sure you want to delete '%s'?\nThis cannot be undone."] = true
L['Deleted profile: %s'] = true
L['Failed to delete profile: %s'] = true
L['Export Success'] = true
L['Export failed: %s'] = true
L['Imported profile: %s'] = true
L['Import failed: %s'] = true
L['Profile manager is not available.'] = true

-- Modifier Keys (shared)
L['Shift'] = true
L['Ctrl'] = true
L['Alt'] = true
L['Cmd'] = true

-- Skinning Sidebar
L['Skinning'] = true
L['Tooltips'] = true
L['Minimap'] = true

-- Tooltips Skinning
L['Tooltip Skinning'] = true
L['Enable Tooltip Skinning'] = true
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
L['Units'] = true
L['Items'] = true
L['Includes toys and equipment sets.'] = true
L['Spells'] = true
L['Includes mounts, macros and flyouts.'] = true
L['Auras'] = true
L['Header Text'] = true
L['Normal Text'] = true
L['Small Text'] = true

-- Minimap Skinning
L['Enable Minimap'] = true
L['Mouse Middle-click: Opens calendar.'] = true
L['Mouse Right-click: Opens tracking menu.'] = true
L['Minimap Settings'] = true
L['Minimap Size'] = true
L['Minimap Scale'] = true
L['Border Size'] = true
L['Anchorpoint'] = true
L['Indicators'] = true
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
L['Enable Copy Anything'] = true
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
L['Tweaks'] = true
L['Enable Tweaks'] = true
L['Hide Misc Elements'] = true
L['Hide Talking Head Frame'] = true
L['Hide Boss Banner'] = true
L['Misc Tweaks'] = true
L['Confirm Popups with Enter'] = true

-- QoL: Recuperate Button
L['Recuperate Button'] = true
L['Enable Recuperate Button'] = true
L['Because of restrictions i cannot fully hide the button when loaded and at '] = true
L['|cffFFFFFFfull health|r'] = true
L['|cffFFFFFFnot in combat.|r'] = true
L['This means that the button is invisible but is still clickable.'] = true
L['Load in Raid'] = true
L['Load in Party'] = true
L['Button Size'] = true

-- QoL: Automation
L['Automation'] = true
L['Enable Automation'] = true
L['Override Behaviour'] = true
L['Hold to Skip'] = true
L['Hold to Enable'] = true
L['Override Info'] = true
L['Automation features that has override support are marked with '] = true
L['Cinematics & Dialogs'] = true
L['Auto Skip Cinematics & Movies'] = true
L['Auto Hide Spammy Tutorial Helptips'] = true
L['Merchant'] = true
L['Merchant Automation'] = true
L['Auto Sell Junk/Grey Items '] = true
L['Auto Repair Gear '] = true
L['Use Guild Funds for Repair'] = true
L['Group Finder'] = true
L['Auto Accept Group Finder Role Check'] = true
L['Role based on selected roles in the Group Finder.'] = true
L['Convenience'] = true
L['Auto-Fill DELETE Text'] = true
L['Auto Loot'] = true
L['Fast Loot'] = true
L['Quests'] = true
L['Automatically complete and turn in quests when there is no reward choice.'] = true
L['Automatically accept and complete the weekly |cffffffffBonus Roll|r quest from Decimus.'] = true
L['Auto Bonus Roll Mode'] = true
L['Gold'] = true
L['Marl'] = true
L['Crest'] = true

-- QoL: Auction House Filter
L['Auction House Filter'] = true
L['Enable Auction House Filter'] = true
L['Blizzard Auction House'] = true
L['Current Expansion Only'] = true
L['Auto Focus Search Bar'] = true
L['Crafting Orders'] = true
L['Auctionator, '] = true
L['|cff00FF00Loaded|r'] = true
L['|cffFF0000Not Loaded|r'] = true

-- QoL: Durability Util
L['Durability Util'] = true
L['Enable Durability Low Warning'] = true
L['Durability Low Warning'] = true
L['Low Threshold Text'] = true
L['Low Threshold Color'] = true
L['Broken Text'] = true
L['Broken Color'] = true
L['Threshold %'] = true

-- Unit Frames GUI
L['Unit Frames'] = true
L['General'] = true
L['Enable Unit Frames'] = true
L['Behaviour'] = true
L['Smooth Bars'] = true
L['Range Fade'] = true
L['Enable Range Fade'] = true
L['In Range Alpha'] = true
L['Out of Range Alpha'] = true
L['Health'] = true
L['Class Colored Health'] = true
L['Color health bars by class for players and by reaction for NPCs.'] = true
L['Foreground'] = true
L['Castbar'] = true
L['Class Colored Castbar'] = true
L['Castbar Color'] = true
L['Absorbs'] = true
L['Heal Absorb'] = true
L['Damage Absorb'] = true
L['Use the shared bar texture from the Global Settings page.'] = true
L['Foreground Texture'] = true
L['Match Foreground'] = true
L['Use the foreground texture for the missing-health background.'] = true
L['Background Texture'] = true
L['Mouseover Highlight'] = true
L['Enable Highlight'] = true
L['Highlight Color'] = true
L['Highlight Texture'] = true
L['Use the shared font from the Global Settings page.'] = true
L['Texture Settings'] = true
L['Tag Settings'] = true
L['Separator used by tags that join two values.'] = true
L['Update Interval'] = true
L['How often timer-driven units (target of target etc.) refresh their texts.'] = true
L['None'] = true
L['Thick Outline'] = true
L['Mono Outline'] = true
L['Player'] = true
L['Target'] = true
L['Target of Target'] = true
L['Focus'] = true
L['Focus Target'] = true
L['Pet'] = true
L['Pet Target'] = true
L['Frame'] = true
L['Power'] = true
L['Tags'] = true
L['Indicator'] = true
L['Miscellaneous'] = true
L['Anchor From'] = true
L['Anchor To'] = true
L['Override Texture'] = true
L['Smooth'] = true
L['Inverse Fill'] = true
L['Use Global Colors'] = true
L['Class Color Alpha'] = true
L['Background (Class Colored)'] = true
L['Textures'] = true
L['Enable Power Bar'] = true
L['Color By Power Type'] = true
L['Enable Castbar'] = true
L['Show Icon'] = true
L['Show Spell Name'] = true
L['Show Cast Time'] = true
L['Non-Interruptible'] = true
L['Interrupted / Failed'] = true
L['Tag'] = true
L['Tag Text'] = true
L['Any oUF tag string, e.g. [nrsknuf:name] or [perhp]%.'] = true
L['Bound To'] = true
L['Pins the far edge so long text truncates instead of overflowing.'] = true
L['Raid Icon'] = true
L['Enable Raid Icon'] = true
L['Leader Indicator'] = true
L['Enable Leader Indicator'] = true
L['Insert Tag'] = true
L['Appends the picked tag to the tag text above.'] = true
L['Name'] = true
L['Smart Color'] = true
L['Health + Percent'] = true
L['Power Percent (Colored)'] = true
L['Current Health'] = true
L['Health Percent'] = true
L['Current Power'] = true
L['Power Percent'] = true
L['Resting'] = true
L['Combat'] = true
L['Ready Check'] = true
L['Summon'] = true
L['Resurrect'] = true
L['Quest'] = true
L['PvP'] = true
L['Phase'] = true
L['Use Global Smoothing'] = true
L['Follow the smoothing setting from the general settings.'] = true
L['Animate health and power bar changes. Units following the global setting inherit this.'] = true
L['Use Global Settings'] = true
L['Power Color'] = true
L['Color the bar by the power type (mana, rage, energy...). Uncheck to use a flat color.'] = true
L['Power smoothing only applies to the player frame.'] = true
L['Hold After Interrupt'] = true
L['Seconds the bar lingers after an interrupted or failed cast. Completed casts always hide immediately.'] = true
L['Safe Zone'] = true
L['Enable Safe Zone'] = true
L['Safe Zone Color'] = true
L['Shows your latency at the end of the cast, on the player frame only.'] = true
L['Enable Heal Absorb'] = true
L['Enable Damage Absorb'] = true
L['Follow the shared absorb settings from the general settings.'] = true
L['Follow the safe zone settings from the general settings.'] = true

-- Aura Filter Builder --

L['Filter Builder'] = true
L['No filters yet. Use New Filter to create one.'] = true
L['New List'] = true
L['Rename List'] = true
L["List '%s' not found."] = true
L['No lists yet. Use New List to create one.'] = true
L['A whitelist shows only these spells, a blacklist hides them.'] = true
L['No spells yet'] = true
L['%d spells'] = true
L['%d of %d spells enabled'] = true
L['Nameplate-only auras are included.'] = true
L['Only Torghast auras are shown.'] = true
L['Manage Filters'] = true
L['SpellID Filters'] = true
L['Create Filter'] = true
L['New Filter'] = true
L['Filter Name'] = true
L['Please enter a filter name'] = true
L['A filter with that name already exists'] = true
L['Rename Filter'] = true
L['Please enter a new name'] = true
L['Delete Filter'] = true
L["Delete the filter '%s'? This cannot be undone."] = true
L["Filter '%s' not found."] = true
L['Filter: %s'] = true
L['Branch %d'] = true
L['Add Branch'] = true
L['Delete Branch'] = true
L['Delete branch %d? This cannot be undone.'] = true
L['Adds another set of conditions. An aura is shown when it matches any branch.'] = true
L['Aura Type'] = true
L['Add Condition'] = true
L['Conditions'] = true
L['No conditions yet. Add one above to start narrowing this branch.'] = true
L['Token'] = true
L['Aura Flag'] = true
L['Dispel Type'] = true
L['Spell List'] = true
L['Max Duration (seconds)'] = true
L['Any'] = true
L['Buffs (Helpful)'] = true
L['Debuffs (Harmful)'] = true
L['Include'] = true
L['Exclude'] = true
L['Require'] = true
L['Cancelable'] = true
L['External Defensive'] = true
L['Crowd Control'] = true
L['Raid In Combat'] = true
L['Raid Player Dispellable'] = true
L['Big Defensive'] = true
L['Dispellable'] = true
L['Include Nameplate Only'] = true
L['Maw (Torghast Only)'] = true
L['Boss Aura'] = true
L['Boss or Role Aura'] = true
L['Role Aura'] = true
L['Priority Aura'] = true
L['Stealable'] = true
L['From Player or Pet'] = true
L['Can Apply Aura'] = true
L['Nameplate Show All'] = true
L['Nameplate Show Personal'] = true
L['Include Dispel Types'] = true
L['Exclude Dispel Types'] = true
L['Magic'] = true
L['Poison'] = true
L['Disease'] = true
L['Curse'] = true
L['Stealth'] = true
L['Special'] = true
L['Enrage'] = true
L['Duration'] = true
L['Create SpellID List'] = true
L['List Name'] = true
L['Please enter a list name'] = true
L['A list with that name already exists'] = true
L['Blacklist'] = true
L['Whitelist'] = true
L['Delete List'] = true
L["Delete the list '%s'? This cannot be undone."] = true
L['Spell ID'] = true
L['Enter a numeric spell ID'] = true
L['No spell found for ID %d'] = true
L['Protected Spell'] = true
L["'%s' (%d) is protected and cannot be used in aura filters."] = true
L['No spells in this list yet.'] = true
L['Type'] = true
L['Add'] = true
L['Remove'] = true
L['OK'] = true
L['Raid'] = true
L['Important'] = true

-- Aura Displays (Advanced Debuffs / Defensives / Standard Buffs / Standard Debuffs) --
L['Advanced Debuffs'] = true
L['Enable Advanced Debuffs'] = true
L['Enable Defensives'] = true
L['Standard Buffs'] = true
L['Standard Debuffs'] = true
L['Enable Standard Buffs'] = true
L['Enable Standard Debuffs'] = true
L['Restoring the Blizzard aura frame requires a reload to take full effect.'] = true

-- Layout tab
L['Grid'] = true
L['Max Auras'] = true
L['Per Row'] = true
L['Element Spacing'] = true
L['Spacing between auras along the row.'] = true
L['Line Spacing'] = true
L['Spacing between aura rows.'] = true
L['Growth'] = true
L['Horizontal Growth'] = true
L['Vertical Growth'] = true
L['Up'] = true
L['Down'] = true
L['Weapon Enchants'] = true
L['Show Weapon Enchants'] = true
L['Flows the temporary main and off-hand enchants in front of the buffs.'] = true
L['Adding or removing the weapon enchants requires a reload to take full effect.'] = true
L['Group Spacing'] = true
L['Spacing at the seam between the weapon enchants and the buffs.'] = true
L['Group Line Spacing'] = true
L['Spacing between the weapon enchant rows and the buff rows.'] = true

-- Filter tab
L['Aura Filter'] = true
L['Filter'] = true
L['None (all harmful)'] = true
L['None (all helpful)'] = true
L['Resolves To'] = true
L['No filters defined yet. Create one under Aura Filters.'] = true
L['No filter selected, every harmful aura is shown.'] = true
L["Filter '%s' no longer exists."] = true
L['Branch %d: %s'] = true
L['Including %s'] = true
L['Excluding %s'] = true
L['Included spell IDs: %d'] = true
L['Excluded spell IDs: %d'] = true
L['Included dispel types: %d'] = true
L['Excluded dispel types: %d'] = true
L['Max duration: %ds'] = true
L['Uses ProcessAura classification.'] = true
L['Matches auras in the branch:'] = true
L['Matches auras in any of %d branches, shown once per branch:'] = true
L['Applies per filter branch, so a filter with several branches can show more than this in total.'] = true

-- Sorting (AuraContainerSortMethod / AuraContainerSortDirection)
L['Sorting'] = true
L['Sort Method'] = true
L['Sort Direction'] = true
L['Expiration Only'] = true
L['Expiration'] = true
L['Default'] = true
L['Important Only'] = true
L['Unit Frame Debuff'] = true
L['Name Only'] = true
L['Aura Instance ID'] = true
L['Normal'] = true
L['Reverse'] = true

-- Appearance tab
L['Aura Button Information'] = true
L['Aura buttons are built once by the game and cannot be restyled in place. These settings are saved immediately but only take effect after a reload.'] = true
L['Icons'] = true
L['Show Count'] = true
L['Show Duration'] = true
L['Cooldown'] = true
L['Draw Swipe'] = true
L['Draw Edge'] = true
L['Dispel Indicators'] = true
L['Show Border'] = true
L['Colors the aura border by dispel type.'] = true
L['Show Dispel Icon'] = true
L['Shows the dispel type icon in the corner of the aura.'] = true
L['Tooltip'] = true
L['Hide Tooltip In Combat'] = true
L['Apply Changes'] = true
L['Reload now to apply the appearance changes?'] = true

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
