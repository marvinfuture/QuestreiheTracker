# Roadmap

## Current: 0.4.1 client-test fixes

- Removed the duplicate addon warning in Blizzard's error frame; retained the prominent warning box.
- Added the functional, saved **Chatwarnung: An/Aus** button in the main window, enabled by default.
- Corrected explicit row clicks to watch and actively navigate to accepted regular quests, including already watched quests.
- The user authorized implementation and a GitHub release on 2026-10-09. Offline checks and the 0.4.1 package build passed; the actual client retest remains pending.

## Previous: 0.4.0 requested improvements

- Removed all installed stories and their static data file.
- Simplified the interface to selection, progress and quest list.
- Removed settings and the other-quests view.
- Added activity warnings for quest-backed bonus objectives, watched quests and quest navigation, alongside world quests and acceptance.
- Preserved runtime lookup, geometry persistence, a draggable launcher and display-only behavior.
- Added selection removal, runtime name recovery and consistent German “Questreihe” labels.
- Implemented the seven collected user requests: explicit observing, transparency, full naming update, narrower progress-only rows, better active-zone coverage, a longer warning banner and main-window tracked lookup.

## Next: user's client test

Run [IN_GAME_TEST.md](docs/IN_GAME_TEST.md), especially the single warning box, saved chat toggle, row-click navigation and subsequent **Verfolgte Quest** lookup. Also check removal/reload, delayed names, world/bonus/watch/navigation warnings and compact layout. Record actual client build, results and Lua/taint issues separately from offline tests.

Collect any remaining client fixes. Future publishing requires the user's instruction; the 0.4.1 push and release are explicitly authorized.

## Umgesetzte Änderungsvorschläge

Aufgenommen und am 9. Oktober 2026 zur Umsetzung beauftragt. Alle sieben Punkte sind im Code umgesetzt; die Prüfung im WoW-Client steht noch aus, insbesondere das Beispiel Trauerhöhe auf der Insel von Dorn. Offlineprüfungen und Paketbau sind Teil der Lieferung.

1. **Quest per Linksklick beobachten:** Angenommene reguläre Quests lassen sich im Blizzard-Questtracker beobachten. Bereits beobachtete Quests bleiben beobachtet; Fehler und ein volles Beobachtungslimit werden abgefangen.
2. **Hintergrund transparenter machen:** Der Fensterhintergrund hat 82 Prozent Deckkraft; Texte bleiben deckend.
3. **Benennung konsequent ändern:** „Questreihe“ wird konsequent verwendet; Produktname, Installationsordner, Paket und interne Bezeichner heißen „Questreihen Tracker“ beziehungsweise `QuestreihenTracker`.
4. **Hauptfenster schmaler machen:** Standardbreite 360, Mindestbreite 320 Pixel. Statuszeilen zeigen nur den Questfortschritt. Verfügbarkeitszusätze entfallen; Questtitel können zwei Zeilen nutzen.
5. **Questreihen der aktuellen Zone prüfen:** Die Auswahl ergänzte bisher nur verfügbare Kartenkandidaten. Nun ergänzen angenommene Quests aus Questlog und Karte die Liste, wenn Blizzard die Zugehörigkeit und den Zonenbezug bestätigt. Beobachtung des Nutzers: Bei Trauerhöhe auf der Insel von Dorn erschienen nur „Mord an einer Königin“ und „Wichtige Quests“. Dieses konkrete Beispiel bleibt im Client nachzuprüfen; eine vollständige Zonenliste wird nicht behauptet.
6. **Warnung länger und deutlicher anzeigen:** Ein deutliches eigenes Banner bleibt doppelt so lange wie die native Meldung sichtbar; bei fehlender Zeitabfrage fünf Sekunden. Warnablauf und Aktualisierung teilen einen Timer.
7. **„Verfolgte Quest“ im Hauptfenster anbieten:** Der Button ist zusätzlich im Hauptfenster vorhanden; Suchfehler sind dort ebenfalls sichtbar.

## Umgesetzte Ideen aus dem Clienttest — 0.4.1

Am 9. Oktober 2026 aufgenommen und anschließend vom Nutzer zur Umsetzung sowie Veröffentlichung als GitHub-Release freigegeben. Die drei Änderungen sind für 0.4.1 umgesetzt; der Test im echten WoW-Client steht noch aus.

1. **Doppelte Bildschirmwarnung entfernt:** Der 0.4.0-Screenshot zeigt dieselbe Addonwarnung über dem orange eingerahmten Warnkasten und darin. 0.4.1 behält den Warnkasten und entfernt die zusätzliche Ausgabe über Blizzards Fehlerframe.
2. **Chatwarnungen im Hauptfenster umschaltbar:** Der Button **Chatwarnung: An/Aus** schaltet die Aktivitätswarnungen im Chat tatsächlich ein und aus. Der Zustand wird pro Charakter gespeichert und ist zunächst **An**; der Warnkasten bleibt unabhängig davon aktiv. **Entfernen** behält die Wahl, `/qrt reset` stellt **An** wieder her.
3. **Questverfolgung per Linksklick korrigiert:** Für angenommene reguläre Quests ergänzt der Klick bei Bedarf die Beobachtung im Blizzard-Questtracker und setzt die Quest als aktives Navigationsziel für **Verfolgte Quest**. Bereits beobachtete Quests lassen sich erneut auswählen, ohne die Beobachtung zu entfernen. Fehlende APIs, abgelehnte Beobachtung oder nicht bestätigte Navigation liefern eine deutsche Rückmeldung. Ereignisse und Aktualisierungen setzen kein Navigationsziel.

Im Client prüfen: nur ein Warnkasten, funktionierender Chat-Schalter mit Speicherung nach `/reload` und Linksklick mit anschließendem Abruf über **Verfolgte Quest**. Die bisherigen Offlineprüfungen von v0.4.0 bestätigen diese gemeldeten Clientprobleme nicht als behoben. Offlineprüfungen von 0.4.1 ersetzen den tatsächlichen Clienttest ebenfalls nicht.

## Later, only if requested

Consider additional runtime zone selection or improved coverage of client-supplied lists. Avoid recreating a bundled quest database, settings panel or extra list modes.
