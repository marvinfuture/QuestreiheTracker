# Roadmap

## Current: 0.5.0 — neue Vorschläge umgesetzt

Am 11. Oktober 2026 hat der Nutzer mit „Go“ alle sechs zuletzt gesammelten Vorschläge zur Umsetzung freigegeben und anschließend Git-Push sowie ein neues Release beauftragt. Die Änderungen sind für 0.5.0 umgesetzt: vorhandene Fensterübersicht, Namenssuche, Erfolgshinweise, Funktionskommentare, Namensbereinigung und getrennte Warnungsschalter. Die Offlineprüfungen mit 152 Verhaltensfällen, 54 statischen Prüfungen und der Paketbau mit 14 Dateien sind erfolgreich. Die Freigabe umfasst Git-Push und das Release v0.5.0. Die tatsächliche Clientprüfung steht noch aus.

## Previous: 0.4.2 main-window layout

- Enlarged and underlined the main title without changing its text.
- Added thin rules after the buttons and before the quest list, plus dividers between quest rows.
- Made progress status smaller and less prominent directly below the quest title; existing status colors and quest actions are retained.
- Kept the 360 × 500 default, 320 × 300 minimum and schema 7 preferences, including saved chat warnings.
- The user authorized implementation and a new GitHub version/release as a continuation. Offline validation and the 0.4.2 package build passed; actual client layout testing remains pending.

## Previous: 0.4.1 client-test fixes

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

Run [IN_GAME_TEST.md](docs/IN_GAME_TEST.md), especially name search and achievement-based results, the two independent saved warning switches and the title/dividers at minimum/default sizes. Also check row-click navigation and subsequent **Verfolgte Quest** lookup, removal/reload and delayed names. Record actual client build, results and Lua/taint issues separately from offline tests.

Collect any remaining client fixes. The user explicitly authorized the v0.5.0 Git push and new release on 2026-10-11.

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

## Umgesetzte Layoutwünsche — 0.4.2

Der Nutzer hat die Umsetzung und eine neue GitHub-Version als Fortsetzung freigegeben. Der Screenshot aus 0.4.1 zeigt grüne abgeschlossene und gelbe angenommene Quests sowie die Beschriftung **Chatwarnung: Aus**. Daraus folgt kein Nachweis der Schalter- oder Navigationsfunktion.

1. **Haupttitel hervorheben:** Größere Schrift und eine Unterstreichung; der Titeltext bleibt gleich.
2. **Abschnitte gliedern:** Dünne Trennlinien nach den Buttons und vor der Questliste.
3. **Quests voneinander trennen:** Dezente Linien zwischen den Questzeilen.
4. **Status zurücknehmen:** Kleinere, weniger hervorgehobene Statuszeile direkt unter dem Questtitel; die bisherigen Statusfarben bleiben erhalten.

Im WoW-Client noch prüfen: Ausrichtung und Lesbarkeit bei langen Titeln, Mindestgröße und anderer UI-Skalierung; Trennlinien dürfen die Klickflächen, Scrollbar und Bedienelemente nicht überlagern. Questverfolgung, Chat-Schalter und gespeicherte Einstellungen bleiben Teil der Funktionsprüfung.

## Later, only if requested

Consider additional runtime zone selection or improved coverage of client-supplied lists. Avoid recreating a bundled quest database, settings panel or extra list modes.

## Umgesetzte neue Vorschläge — 0.5.0

Am 9. Oktober 2026 gesammelt, am 11. Oktober 2026 um die vollständige Umbenennung und den separaten Schalter für Bildschirmwarnungen ergänzt. Am 11. Oktober 2026 hat der Nutzer die Programmierung aller sechs Punkte ausdrücklich freigegeben und Git-Push sowie ein neues Release beauftragt. Alle sechs Punkte sind für 0.5.0 umgesetzt; beim Prüfauftrag zur Erfolgsauswertung bleibt die unten erläuterte API-Grenze bestehen.

1. **Fensterübersicht weiter verbessern:** Den Header groß und unterstrichen darstellen, nach den Buttons und vor den Quests dünne Trennlinien einfügen und die Quests untereinander durch Linien trennen. Questnamen und ihre bestehende Darstellung mit Grün und Gelb sollen unverändert bleiben. Den Hinweis „Abgeschlossen“ dezent unter dem Questnamen anzeigen. Die Layout-Grundwünsche sind bereits für 0.4.2 dokumentiert und umgesetzt; dieser Wunsch hält fest, dass die Übersichtlichkeit weiterhin wichtig ist.
2. **Questreihen nach Namen suchen:** Neben der Suche per Quest-ID eine Eingabe des Questreihennamens anbieten, etwa „Trauerhöhe“. Die Suche verwendet vom Client gelieferte Namen und zeigt mehrere passende Treffer zur Auswahl.
3. **Questreihennamen aus Erfolgen ermitteln:** Namen und Kriterien aus Erfolgen zur Laufzeit auswerten. Als Beispiel sollen die Voraussetzungen für die verbündeten Völker, insbesondere die Irdenen und Trauerhöhe, bei der Suche helfen. Die Prüfung der Blizzard-Quellen bestätigt verknüpfte Untererfolge, liefert aber keine verlässliche Zuordnung der übrigen Kriterien-IDs zu Quest-IDs. Deshalb erscheinen Erfolgs- und Kriteriennamen mit Erfüllungsstand als Hinweise und sind nicht als Questreihe auswählbar. Namen allein belegen weder Mitgliedschaft noch Voraussetzungen.
4. **Funktionen kommentieren:** Über jeder Addon-Lua-Funktion und jedem anonymen Callback einen englischen Kommentar ergänzen, der erklärt, was sie tut und wozu sie dient.
5. **Umbenennung vollständig abschließen:** Überall „Questreihen Tracker“ beziehungsweise `QuestreihenTracker` verwenden und die alte Bezeichnung im aktiven Projekt entfernen. Auch den verbliebenen Projekt-/Arbeitsordner, Datei- und Paketnamen, Dokumentation, Oberflächentexte und interne Referenzen prüfen und gegebenenfalls anpassen. Die Addonidentität wurde bereits in 0.4.0 geändert; dieser Vorschlag umfasst die noch verbliebenen alten Bezeichnungen und Pfade.
6. **Bildschirmwarnung separat umschalten:** Einen zusätzlichen Button **Bildschirmwarnung: An/Aus** im Hauptfenster anbieten. Er schaltet ausschließlich den eigenen Warnkasten in der Bildschirmmitte ein oder aus, unabhängig vom bestehenden Button **Chatwarnung: An/Aus**. Beide Warnungsarten sollen einzeln oder gemeinsam deaktivierbar sein. Beim Ausschalten einen bereits sichtbaren Warnkasten sofort ausblenden. Die Wahl wie bei den Chatwarnungen pro Charakter speichern und nach `/reload` beibehalten; zunächst ist die Bildschirmwarnung **An**.

Umsetzungsgrenze: Die Namenssuche durchsucht vom Client gelieferte Questreihennamen und zeigt passende Erfolgs- und Kriteriennamen als getrennte Informationen. Nur eine vom Client gelieferte Questreihe mit geladener Mitgliedschaft ist auswählbar. Blizzard stellt damit keinen zugesicherten vollständigen Katalog aller Questreihen bereit. Ob das konkrete Beispiel Trauerhöhe gefunden wird und welche Voraussetzungen der installierte Client tatsächlich liefert, bleibt Teil der Clientprüfung. Es werden keine fest eingebauten Quest- oder Erfolgsdaten ergänzt.
