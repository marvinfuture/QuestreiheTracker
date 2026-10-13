# Roadmap

## Current: 0.6.0 — Cache, Fensteroptik und Suchbedienung

Am 13. Oktober 2026 hat der Nutzer die gesammelten Vorschläge und Bezeichnungen bestätigt und anschließend mit **„go mit anschließend release auf git“** die Umsetzung, Git-Push und ein neues Release freigegeben. Die folgenden Änderungen sind für 0.6.0 umgesetzt. Die integrierte Offlineprüfung besteht 223 gezählte Verhaltensfälle, vier zusätzliche Startkombinationen, die separaten Banner-/Start-/Reload-/fehlende-API-Prüfungen und 54 statische Selbsttests. Alle 15 Addon-Lua-Dateien laden unter Lua 5.1; 28 C-API-Mitglieder sind geprüft, ohne verbotene Spieländerung oder ungültige ID. Das Paket mit 18 Dateien und 83.306 Bytes ist gebaut. Die tatsächliche Clientprüfung bleibt separat offen.

1. **Nicht mehr benötigte Laufzeitdaten aufräumen:** **Suchcache leeren** beendet überholte Sucharbeit und gibt unbenutzte Suchdaten des Addons frei. Automatische Bereinigung nach Abbruch oder abgeschlossener Suche hält nur benötigte Anfrage-/Ergebnisdaten sowie die angezeigte Reihe und aktuelle beziehungsweise im Dropdown gewählte Zone vor. **Entfernen** behält seine bisherige Funktion; Cachebereinigung bewahrt die angezeigte Reihe und Einstellungen. Spätere Antworten dürfen abgebrochene Suchen nicht wiederherstellen. Das Addon verwaltet ausschließlich eigene Sitzungscaches, nicht Blizzards Clientcache.
2. **Hauptfenster an Blizzards Oberfläche anpassen:** Zahnrad/Einstellungen verwendet Blizzards `SquareIconButtonTemplate` mit dem Zahnradatlas, X den nativen `UIPanelCloseButton`. Der erste Button heißt fest **Suche** und öffnet das Such-/Auswahlfenster. **Entfernen** behält seine Bezeichnung und bestehende Funktion.
3. **Questreihennamen als Überschrift anzeigen:** Der ausgewählte Name steht als passende Überschrift vor den Quests. Reihenfolge: **Prozentbalken → Questreihenname → „0/3 Quests abgeschlossen“ → Questliste**. Lange Namen, keine Auswahl und noch ladende Daten werden bei der Anordnung berücksichtigt.
4. **Questbutton in beiden Fenstern gleich benennen:** Die bestätigte Beschriftung lautet **Questreihe zur verfolgten Quest**, sowohl im Hauptfenster als auch im Suchfenster. Er öffnet weiterhin die ganze bestätigte Reihe zur Quest mit Blizzards Navigationspfeil. Die Bedeutungsfrage ist damit geklärt.
5. **Einstellungen übersichtlicher gestalten:** Links den Einstellungsnamen anzeigen, rechts klar abgegrenzte, gegenseitig ausschließende **An | Aus**-Bedienelemente, passend zur Blizzard-Optik. Die aktive Wahl ist eindeutig erkennbar. Die drei unabhängigen gespeicherten Einstellungen bleiben inhaltlich erhalten.
6. **Suchfelder und Aktionen strukturieren:** Quest-ID und Namenssuche untereinander mit eindeutig zugehörigen Beschriftungen, Eingaben und Suchbuttons anordnen. Die bestätigte kurze Feldbeschriftung lautet **Questreihe**, mit **Handlungs- oder Geschichtsstrang** als zusätzlichem Hinweis.
7. **Suchzustand sichtbar machen:** Nach **Suchen** zeigt ein nativer `SpinnerTemplate` neben der Aktion laufende Arbeit. Bestätigte auswählbare Reihentreffer erhalten einen Haken. Für fehlende Zuordnung oder ungültige Eingabe erscheint direkt im Fenster **„Keine passende Questreihe gefunden. Bitte prüfe deine Eingabe.“** Auf Nutzerwunsch gibt es keine unterschiedliche Tippfehler-/Datenfehlermeldung. Mehrere Treffer bleiben auswählbar. Erfolgs-/Kriterienhinweise allein erhalten keinen Erfolgshaken. Die automatische Auswahl eindeutiger exakter Namen öffnet die vollständige Reihe im Hauptfenster und bestätigt den Erfolg dort.
8. **Zone per Dropdown auswählen:** Statt der bisherigen Zeile **Aktuelle Zone** und der danebenstehenden Aktion **Aktualisieren** die Beschriftung **Zone:** mit einem Dropdown einführen. Die bestätigte Voreinstellung heißt **Aktuelle Zone**. Bei Auswahlwechsel wird die betreffende Zonenliste automatisch angefordert/aktualisiert; bei aktiver Option **Aktuelle Zone** folgt sie auch dem Zonenwechsel des Spielers. Eine ausdrücklich gewählte andere Zone bleibt ausgewählt. Der Zonenwechsel im Dropdown beendet eine überholte Namenssuche, damit deren spätere Antworten die gewählte Zonenansicht nicht überschreiben.
9. **Clientzonen gruppiert anbieten:** **Aktuelle Zone** oben anzeigen, weitere vom Client gelieferte Zonen nach Kontinent gruppieren und einen Suchfilter anbieten. Die Kartenhierarchie liefert die auswählbaren Zonen; Questlisten werden erst bei Bedarf angefordert. Das bestätigt keine vollständige Quest-/Questreihenabdeckung jeder Zone. Stadt-, Unter- und Instanzkarten nach dem passenden Client-Kartentyp behandeln, statt sie ungeprüft als weitere Zonen einzutragen. Grundlage: [Blizzards Karten-API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua).
10. **Jedes Fenster schließbar machen:** Alle eigenständigen Addonfenster bekommen oben rechts ein X im passenden Blizzard-Stil, ausdrücklich Haupt-, Einstellungs-, Such- und Linkfenster. Eine eventuell als eigenes Fenster geführte Warnanzeige ebenfalls berücksichtigen. Schließen der Suche muss laufende Arbeit abbrechen; das X des Hauptfensters muss weiterhin die bewusste Schließentscheidung speichern.

Festgelegte Bezeichnungen: **Hauptfenster**, **Suche**, **Suchen**, **Entfernen**, **Suchcache leeren**, **Questreihe zur verfolgten Quest**, **Questreihe** mit dem Hinweis **Handlungs- oder Geschichtsstrang** sowie **Zone: Aktuelle Zone**. Der Auftrag umfasst die anschließende Veröffentlichung als v0.6.0.

## Previous: 0.5.2 — Questreihen per Name und Quest-ID aufrufen

Am 13. Oktober 2026 hat der Nutzer die Namenssuche mit „Go“ freigegeben und ein aktuelles GitHub-Release beauftragt. Gemeint ist die gesamte vom Client bestätigte Questreihe: Eine Quest-ID ihrer ersten oder einer anderen Quest ruft die ganze gelieferte Liste auf; der volle Questreihenname soll dieselbe Liste öffnen. Das Nutzerbeispiel ist **Trauerhöhe**, dessen erste Quest nach seiner Angabe **Zur Trauerhöhe** heißt. Der einzelne Questtitel wird nicht als Namensalias fest eingebaut.

1. **Namen dynamisch entdecken:** Die Suche liest Zonen aus der Client-Kartenhierarchie und bestätigt zusätzlich Questreihen angenommener Questlog-Einträge auch außerhalb der aktuellen Zone. Karten und Questkandidaten werden in begrenzten Paketen verarbeitet; es gibt keinen festen Quest-/Erfolgskatalog.
2. **Eindeutigen vollen Namen öffnen:** Nach Ende der begrenzten Suche öffnet ein eindeutiger exakter Questreihenname mit geladener Mitgliedschaft die ganze Questreihe. Teilnamen und mehrere exakte Reihen-IDs bleiben auswählbare Treffer. Ein passender Treffer mit noch fehlender Mitgliedschaft verhindert eine vorschnelle automatische Auswahl.
3. **Unsicherheit sichtbar halten:** Fehlende Daten und Suchgrenzen führen zu Lade-/Teilzuständen. Erfolgs- und Kriteriennamen bleiben Informationen; ihre IDs werden nicht als Quest-IDs verwendet. Eine gelieferte Questliste bestätigt keine umfassende Vorgeschichte oder Voraussetzungen über mehrere Reihen hinweg.

0.5.2 enthält außerdem die unten dokumentierten Einstellungen, das Fensterverhalten und automatische Scrollen aus dem lokalen 0.5.1-Stand. Die Offlineprüfungen mit 190 gezählten Verhaltensfällen, vier zusätzlichen Startkombinationen und 54 statischen Prüfungen sind erfolgreich; alle 13 Addon-Lua-Dateien laden unter Lua 5.1. Der Paketbau mit 16 Dateien und 75.870 Bytes ist erfolgreich. Die tatsächliche Clientprüfung, insbesondere die Namenssuche nach Trauerhöhe, steht noch aus. Git-Push und Release sind durch den aktuellen Auftrag ausdrücklich freigegeben.

## Included: 0.5.1 — Einstellungen, Fensterverhalten und automatisches Scrollen

Am 13. Oktober 2026 hat der Nutzer diese Umsetzung mit „Go“ freigegeben. Die Offlineprüfungen des damaligen lokalen Stands mit 167 gezählten Verhaltensfällen, vier zusätzlichen Startkombinationen und 54 statischen Prüfungen waren erfolgreich; alle zwölf Addon-Lua-Dateien luden unter Lua 5.1, und das lokale Paket mit 15 Dateien wurde gebaut. Die tatsächliche Clientprüfung steht noch aus. Die folgenden Änderungen werden mit 0.5.2 veröffentlicht.

1. **Fenster geöffnet lassen:** Bei aktivierter Einstellung bleibt ein bewusst geöffnetes Hauptfenster bei Teleport, Zonenwechsel, Talenten und gewöhnlichen Schließversuchen durch die Spieloberfläche offen. Auch Escape schließt das Hauptfenster dann nicht. Nach `/reload` wird der zuletzt bewusst gewählte Öffnungszustand wiederhergestellt. Schließen über X, `/qrt` oder Minimap-Linksklick bleibt möglich und wird gespeichert; ein bewusst geschlossenes Fenster bleibt geschlossen. Die Einstellung ist zunächst **An**, das Fenster einer neuen Installation zunächst geschlossen. Bei **Aus** sind normale Spiel-/Escape-Schließvorgänge möglich und es gibt keine automatische Wiederöffnung nach Reload.
2. **Einstellungen über einen Zahnradbutton öffnen:** Im Hauptfenster öffnet ein Zahnrad die Einstellungen mit **Chatwarnung**, **Bildschirmwarnung** und **Fenster geöffnet lassen**, jeweils **An/Aus**. Die bisherigen Warnungsschalter ziehen dorthin um und bleiben unabhängig voneinander pro Charakter gespeichert.
3. **Automatisch zur angenommenen Quest scrollen:** Beim Aktualisieren und Anpassen der Questzeilen wird die Scrollposition so angepasst, dass die aktive Quest in der angezeigten Questreihe sichtbar ist. Die zuletzt neu angenommene oder ausdrücklich angeklickte noch aktive Quest erhält Vorrang, andernfalls die erste aktive Quest in der gelieferten Reihenfolge. Manuelles Scrollen bleibt möglich; bei der nächsten Aktualisierung wird ein nicht mehr sichtbares Ziel wieder in den sichtbaren Bereich gebracht. Ist es bereits sichtbar, bleibt die Position erhalten. Questfortschritt und geänderte Zeilenhöhen werden berücksichtigt; die Scrollbar folgt der tatsächlichen Position.

## Previous: 0.5.0 — neue Vorschläge umgesetzt

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

Run [IN_GAME_TEST.md](docs/IN_GAME_TEST.md), especially identical full membership via first/other quest ID and exact line name, Trauerhöhe discovery from another zone, ambiguous/partial names and cancellation during delayed discovery. Also check the gear settings, persistent manual window choice during teleport/reload/talents, intentional closing, automatic scrolling, warning outputs, row-click navigation, removal/reload and delayed names. Record actual client build, results and Lua/taint issues separately from offline tests.

Also run the new 0.6.0 cache, native controls, search feedback and grouped zone-dropdown checks. Collect any remaining client fixes. The current authorization covers Git push and the v0.6.0 release.

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

Consider improved coverage of client-supplied lists only when requested. Avoid recreating a bundled quest database or extra list modes. Grouped runtime zone selection is included in 0.6.0 above.

## Umgesetzte neue Vorschläge — 0.5.0

Am 9. Oktober 2026 gesammelt, am 11. Oktober 2026 um die vollständige Umbenennung und den separaten Schalter für Bildschirmwarnungen ergänzt. Am 11. Oktober 2026 hat der Nutzer die Programmierung aller sechs Punkte ausdrücklich freigegeben und Git-Push sowie ein neues Release beauftragt. Alle sechs Punkte sind für 0.5.0 umgesetzt; beim Prüfauftrag zur Erfolgsauswertung bleibt die unten erläuterte API-Grenze bestehen.

1. **Fensterübersicht weiter verbessern:** Den Header groß und unterstrichen darstellen, nach den Buttons und vor den Quests dünne Trennlinien einfügen und die Quests untereinander durch Linien trennen. Questnamen und ihre bestehende Darstellung mit Grün und Gelb sollen unverändert bleiben. Den Hinweis „Abgeschlossen“ dezent unter dem Questnamen anzeigen. Die Layout-Grundwünsche sind bereits für 0.4.2 dokumentiert und umgesetzt; dieser Wunsch hält fest, dass die Übersichtlichkeit weiterhin wichtig ist.
2. **Questreihen nach Namen suchen:** Neben der Suche per Quest-ID eine Eingabe des Questreihennamens anbieten, etwa „Trauerhöhe“. Die Suche verwendet vom Client gelieferte Namen und zeigt mehrere passende Treffer zur Auswahl.
3. **Questreihennamen aus Erfolgen ermitteln:** Namen und Kriterien aus Erfolgen zur Laufzeit auswerten. Als Beispiel sollen die Voraussetzungen für die verbündeten Völker, insbesondere die Irdenen und Trauerhöhe, bei der Suche helfen. Die Prüfung der Blizzard-Quellen bestätigt verknüpfte Untererfolge, liefert aber keine verlässliche Zuordnung der übrigen Kriterien-IDs zu Quest-IDs. Deshalb erscheinen Erfolgs- und Kriteriennamen mit Erfüllungsstand als Hinweise und sind nicht als Questreihe auswählbar. Namen allein belegen weder Mitgliedschaft noch Voraussetzungen.
4. **Funktionen kommentieren:** Über jeder Addon-Lua-Funktion und jedem anonymen Callback einen englischen Kommentar ergänzen, der erklärt, was sie tut und wozu sie dient.
5. **Umbenennung vollständig abschließen:** Überall „Questreihen Tracker“ beziehungsweise `QuestreihenTracker` verwenden und die alte Bezeichnung im aktiven Projekt entfernen. Auch den verbliebenen Projekt-/Arbeitsordner, Datei- und Paketnamen, Dokumentation, Oberflächentexte und interne Referenzen prüfen und gegebenenfalls anpassen. Die Addonidentität wurde bereits in 0.4.0 geändert; dieser Vorschlag umfasst die noch verbliebenen alten Bezeichnungen und Pfade.
6. **Bildschirmwarnung separat umschalten:** Einen zusätzlichen Button **Bildschirmwarnung: An/Aus** im Hauptfenster anbieten. Er schaltet ausschließlich den eigenen Warnkasten in der Bildschirmmitte ein oder aus, unabhängig vom bestehenden Button **Chatwarnung: An/Aus**. Beide Warnungsarten sollen einzeln oder gemeinsam deaktivierbar sein. Beim Ausschalten einen bereits sichtbaren Warnkasten sofort ausblenden. Die Wahl wie bei den Chatwarnungen pro Charakter speichern und nach `/reload` beibehalten; zunächst ist die Bildschirmwarnung **An**.

Umsetzungsgrenze: Die Namenssuche durchsucht vom Client gelieferte Questreihennamen und zeigt passende Erfolgs- und Kriteriennamen als getrennte Informationen. Nur eine vom Client gelieferte Questreihe mit geladener Mitgliedschaft ist auswählbar. Blizzard stellt damit keinen zugesicherten vollständigen Katalog aller Questreihen bereit. Ob das konkrete Beispiel Trauerhöhe gefunden wird und welche Voraussetzungen der installierte Client tatsächlich liefert, bleibt Teil der Clientprüfung. Es werden keine fest eingebauten Quest- oder Erfolgsdaten ergänzt.
