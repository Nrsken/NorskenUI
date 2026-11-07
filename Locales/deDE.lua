-- German deDE localization file.
local L = select(2, ...):NewLocale('deDE')

-- General GUI
L['Layout'] = "Layout"
L['Backdrop'] = "Hintergrund"

-- Sidebar
L['Defensives'] = "Defensivzauber"

-- Profiles
L['Create'] = "Erstellen"
L['Global Profile'] = "Globales Profil"
L['Profiles'] = "Profile"

-- Theme Page
L['Custom'] = "Benutzerdefiniert"
L['Theme'] = "Design"

-- Missing Buffs
L['Display'] = "Anzeige"
L['Healthstone'] = "Gesundheitsstein"
L['Runeforge'] = "Runenschmiede"
L['Glow'] = "Leuchten"

-- Profile messages & dialogs
L['Profile changed. A UI reload is recommended to fully apply all settings.'] = "Profil gewechselt. Ein Neuladen der UI wird empfohlen, damit alle Einstellungen vollständig übernommen werden."

-- Modifier Keys (shared)
L['Shift'] = "Umschalt"
L['Ctrl'] = "STRG"
L['Alt'] = "ALT"

-- Skinning Sidebar
L['Skinning'] = "Skins"

-- Tooltips Skinning
L['Auras'] = "Auren"

-- Minimap Skinning
L['Indicators'] = "Indikatoren"

-- QoL: Skyriding UI
L['Bars'] = "Balken"

-- NRSKNUI.FontOutlines
L['Focus'] = "Fokus"
L['Boss'] = "Boss"
L['Class'] = "Klasse"
L['Power'] = "Ressource"
L['Ready Check'] = "Bereitschaftscheck"
L['Blizzard'] = "Blizzard"

-- Aura Filter Builder --
L['Active'] = "Aktiv"
L['Back'] = "Zurück"
L['Item'] = "Gegenstand"

-- CDM bars
L['Stagger'] = "Staffelung"
L['Combo Points'] = "Combopunkte"
L['Holy Power'] = "Heilige Kraft"
L['Soul Shards'] = "Seelensplitter"
L['Chi'] = "Chi"
L['Arcane Charges'] = "Arkane Aufladungen"
L['Essence'] = "Essenz"
L['Runes'] = "Runen"
L['Any'] = "Beliebig"
L['Exclude'] = "Ausgeschlossen"
L['Require'] = "Erforderlich"
L['Remove'] = "Entfernen"

-- Aura indicator library (UnitFrames sidebar)
L['Indicator %d'] = "Indikator %d"
L['Replace'] = "Ersetzen"

-- Dispel highlight (UnitFrames General + per unit)
L['Dispel'] = "Bannen"

-- Sorting (AuraContainerSortMethod / AuraContainerSortDirection)
L['Default'] = "Standard"
L['Normal'] = "Normal"

-- Statuses --
L['Status'] = "Status"

-- Aura Triggers & Displays --
L['Trigger'] = "Auslöser"

-- Skinning: Action Bars --
L['Texts'] = "Texte"

-- Skinning: Blizzard Mouseover --
L['Hide'] = "Verbergen"
L['Filters'] = "Filter"
L['Search'] = "Suchen"

-- Aura trackers
L['%s (Copy)'] = "%s (Kopie)"
L['%s (Copy %d)'] = "%s (Kopie %d)"
L['Disable'] = "Deaktivieren"

-- Cooldown Manager
L['Show'] = "Anzeigen"
L['Collapse'] = "Einklappen"
L['Expand'] = "Erweitern"
L['Update'] = "Aktualisieren"
L['View'] = "Sichtbarkeit"

-- Anchors
L["Anchor '%s' has %d anchor points and cannot be dragged."] = "Anker „%s“ hat %d Ankerpunkte und kann nicht gezogen werden."
L['Anchors closed due to entering combat.'] = "Anker wurden wegen Kampfbeginn geschlossen."
L['Cannot open Anchors during combat.'] = "Anker können im Kampf nicht geöffnet werden."
L['Click to select'] = "Zum Auswählen klicken"
L['No anchor selected.'] = "Kein Anker ausgewählt."
L['No anchor selected. Click an overlay to select it.'] = "Kein Anker ausgewählt. Klicke auf ein Overlay, um es auszuwählen."
L['Nudge Tool'] = "Feinjustierung"
L['Open Settings'] = "Einstellungen öffnen"
L['X Offset:'] = "X-Versatz:"
L['Y Offset:'] = "Y-Versatz:"

-- Commands
L['%s is missing, reinstall NorskenUI.'] = "%s fehlt, installiere NorskenUI neu."
L['%s is version %s but NorskenUI is %s, update both.'] = "%s hat Version %s, NorskenUI aber %s. Aktualisiere beide."
L['GUI position and size reset to defaults.'] = "Position und Größe des Optionsfensters auf Standard zurückgesetzt."
L['Options will open after combat ends.'] = "Die Optionen werden nach dem Kampf geöffnet."

-- Core / Main
L['%s to open the configuration window.'] = "Gib %s ein, um das Konfigurationsfenster zu öffnen."
L['Left-Click to open options'] = "Linksklick: Optionen öffnen"
L['Middle-Click to reset the options window position'] = "Mittelklick: Position des Optionsfensters zurücksetzen"
L['Right-Click to toggle anchors'] = "Rechtsklick: Anker umschalten"

-- Dialog
L["Reset %s settings to defaults?"] = "Einstellungen von %s auf Standard zurücksetzen?"
L["Reset Module"] = "Modul zurücksetzen"

-- ProfileManager
L['Cannot delete the active profile'] = "Das aktive Profil kann nicht gelöscht werden"
L['Current name cannot be empty'] = "Der aktuelle Name darf nicht leer sein"
L['Database not initialized'] = "Datenbank nicht initialisiert"
L['Decoding failed'] = "Dekodierung fehlgeschlagen"
L['Decompression failed'] = "Dekomprimierung fehlgeschlagen"
L['Deserialization failed: %s'] = "Deserialisierung fehlgeschlagen: %s"
L['Export failed'] = "Export fehlgeschlagen"
L['Import string is empty'] = "Importstring ist leer"
L['Invalid data structure'] = "Ungültige Datenstruktur"
L['Invalid format (missing or wrong prefix)'] = "Ungültiges Format (Präfix fehlt oder ist falsch)"
L['Invalid profile name'] = "Ungültiger Profilname"
L['Names are identical'] = "Die Namen sind identisch"
L['New name cannot be empty'] = "Der neue Name darf nicht leer sein"
L['Profile name cannot be empty'] = "Der Profilname darf nicht leer sein"
L['Profile: %s, already exists'] = "Profil %s existiert bereits"
L['Profile: %s, does not exist'] = "Profil %s existiert nicht"
L['Profile: %s, not found'] = "Profil %s nicht gefunden"
L['Fonts, textures and colors now apply to every profile. Yours differed, so check them in Global Settings.'] = "Schriftarten, Texturen und Farben gelten jetzt für jedes Profil. Deine waren unterschiedlich, prüfe sie in den Globalen Einstellungen."
L['Source profile name cannot be empty'] = "Der Name des Quellprofils darf nicht leer sein"
L['Source profile: %s, does not exist'] = "Quellprofil %s existiert nicht"

-- LibKaji (its strings resolve from Core: the library runs outside the options window too)
L['Combat'] = "Kampf"
L['Out of Combat'] = "Außerhalb des Kampfes"

-- Core / Init
L['Space'] = "Leertaste"

-- Shared with the options pages
L['Development Version'] = "Entwicklungsversion"
