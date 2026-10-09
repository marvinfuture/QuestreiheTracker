# Roadmap

## Current: 0.4.0 requested improvements

- Removed all installed stories and their static data file.
- Simplified the interface to selection, progress and quest list.
- Removed settings and the other-quests view.
- Added activity warnings for quest-backed bonus objectives, watched quests and quest navigation, alongside world quests and acceptance.
- Preserved runtime lookup, geometry persistence, a draggable launcher and display-only behavior.
- Added selection removal, runtime name recovery and consistent German “Questreihe” labels.
- Implemented the seven collected user requests: explicit observing, transparency, full naming update, narrower progress-only rows, better active-zone coverage, a longer warning banner and main-window tracked lookup.

## Next: user's client test

Run [IN_GAME_TEST.md](docs/IN_GAME_TEST.md), especially removal/reload, delayed names and lookup, world/bonus/watch/navigation warnings and compact layout. Record actual client build, results and Lua/taint issues separately from offline tests.

Collect any remaining fixes, test them, then prepare the Git push with the user. No automatic publish, push or release.

## Umgesetzte Änderungsvorschläge

Aufgenommen und am 9. Oktober 2026 zur Umsetzung beauftragt. Alle sieben Punkte sind im Code umgesetzt; die Prüfung im WoW-Client steht noch aus, insbesondere das Beispiel Trauerhöhe auf der Insel von Dorn. Offlineprüfungen und Paketbau sind Teil der Lieferung.

1. **Quest per Linksklick beobachten:** Angenommene reguläre Quests lassen sich im Blizzard-Questtracker beobachten. Bereits beobachtete Quests bleiben beobachtet; Fehler und ein volles Beobachtungslimit werden abgefangen.
2. **Hintergrund transparenter machen:** Der Fensterhintergrund hat 82 Prozent Deckkraft; Texte bleiben deckend.
3. **Benennung konsequent ändern:** „Questreihe“ wird konsequent verwendet; Produktname, Installationsordner, Paket und interne Bezeichner heißen „Questreihen Tracker“ beziehungsweise `QuestreihenTracker`.
4. **Hauptfenster schmaler machen:** Standardbreite 360, Mindestbreite 320 Pixel. Statuszeilen zeigen nur den Questfortschritt. Verfügbarkeitszusätze entfallen; Questtitel können zwei Zeilen nutzen.
5. **Questreihen der aktuellen Zone prüfen:** Die Auswahl ergänzte bisher nur verfügbare Kartenkandidaten. Nun ergänzen angenommene Quests aus Questlog und Karte die Liste, wenn Blizzard die Zugehörigkeit und den Zonenbezug bestätigt. Beobachtung des Nutzers: Bei Trauerhöhe auf der Insel von Dorn erschienen nur „Mord an einer Königin“ und „Wichtige Quests“. Dieses konkrete Beispiel bleibt im Client nachzuprüfen; eine vollständige Zonenliste wird nicht behauptet.
6. **Warnung länger und deutlicher anzeigen:** Ein deutliches eigenes Banner bleibt doppelt so lange wie die native Meldung sichtbar; bei fehlender Zeitabfrage fünf Sekunden. Warnablauf und Aktualisierung teilen einen Timer.
7. **„Verfolgte Quest“ im Hauptfenster anbieten:** Der Button ist zusätzlich im Hauptfenster vorhanden; Suchfehler sind dort ebenfalls sichtbar.

## Later, only if requested

Consider additional runtime zone selection or improved coverage of client-supplied lists. Avoid recreating a bundled quest database, settings panel or extra list modes.
