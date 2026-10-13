# Questreihen Tracker — v0.6.0

A compact World of Warcraft Retail addon that displays one selected quest line and its character progress. **All quest lists, names and progress come from the WoW client at runtime.** No curated stories, quest database, external service or in-game library is shipped.

The German interface has a movable, resizable quest list with a partly transparent background, a search window and a draggable minimap launcher. **Suche** opens stacked quest-ID/name inputs and a zone dropdown. The selected line is a heading between the percentage bar and completed-quest count. Native Blizzard gear/close buttons and separated **An | Aus** settings organize the controls. The default tracker is 360 × 500 pixels; its minimum is 320 × 300. Left-click an accepted regular quest to observe it in Blizzard's quest tracker and make it the active navigation target. Refreshing the list keeps its active quest in view.

## Install and test

1. Use the ZIP from [GitHub release v0.6.0](https://github.com/marvinfuture/QuestreiheTracker/releases/tag/v0.6.0) or the [local package](outputs/QuestreihenTracker-v0.6.0.zip). Extract it into `World of Warcraft/_retail_/Interface/AddOns/`.
2. Confirm the result is `AddOns/QuestreihenTracker/QuestreihenTracker.toc`, without an extra nested folder.
3. Enable the addon and use `/reload`.
4. Open it with `/qrt` or the minimap logo. Click **Suche**.
5. Choose a supplied line for **Zone: Aktuelle Zone** or another zone, use **Questreihe zur verfolgten Quest** for the quest with Blizzard's navigation arrow, or enter a **Quest-ID** / **Questreihe** and click the adjacent **Suchen** button or press Enter. The name input has the hint **Handlungs- oder Geschichtsstrang**.

There is no default story. An old saved curated selection becomes **Keine Questreihe ausgewählt**. A valid saved Blizzard map/line selection is restored from live data. Missing data remains loading or unresolved; it never activates an invented fallback list.

Replace the previous addon folder when upgrading so only one copy is enabled. When upgrading from 0.3.1 or earlier, remove the previous addon folder too; the identity change in 0.4.0 starts fresh preferences. Later upgrades preserve preferences, including both saved warning choices. Each of the three settings defaults to **An** when no valid choice is saved; a fresh installation starts with the tracker closed. Only `addon/QuestreihenTracker/` belongs inside AddOns. See [the client test checklist](docs/IN_GAME_TEST.md) for this build.

The TOC targets Interface **120100**, based on the previously inspected Retail 12.1.0 export. Compare the fourth result of `GetBuildInfo()` with your actual client. Offline stubs do not verify real layout, client API behavior or taint.

## Controls

| Control | Action |
| --- | --- |
| `/qrt` / minimap left click | Show or hide the tracker |
| `/qrt zone` / minimap right click | Open selection and request current-zone lists |
| **Suche** | Open the search and zone-selection window |
| **Questreihe zur verfolgten Quest** in either window | Display the full line of the current quest navigation target |
| Gear button | Open or close the settings panel |
| **Chatwarnung**, separate **An / Aus** choices in settings | Enable or disable local activity-warning messages in chat independently of the warning box |
| **Bildschirmwarnung**, separate **An / Aus** choices in settings | Enable or disable the centered warning box independently of chat; switching off clears any visible box immediately |
| **Fenster geöffnet lassen**, separate **An / Aus** choices in settings | Keep a deliberately opened tracker visible until explicitly closed, including after reload; **Aus** permits ordinary closing and disables reload reopening |
| **Quest-ID** + **Suchen** / Enter | Display the whole supplied line containing the queried member quest |
| **Questreihe** + **Suchen** / Enter | Discover client-supplied lines by name; a unique verified full-name match opens the whole line after the finite search settles |
| **Zur Zonenliste** | Leave name-search results and return to the selected zone list |
| **Zone: Aktuelle Zone** or another dropdown choice | End a stale lookup and request that zone's list automatically; current-zone mode follows player zone changes |
| Zone filter | Filter client-supplied zone names in the grouped dropdown without loading their quest lists |
| **Suchcache leeren** | Cancel stale search work and free unused addon search caches while retaining the displayed line and settings |
| **Entfernen** | Clear the loaded line and saved selection, keeping window geometry and Blizzard tracking |
| X at the top right of each window | Close that window; the main-window X saves deliberate closure and the warning X dismisses the current banner |
| Drag title / unused background | Move tracker, selector or copy-link dialog |
| Drag bottom-right grip | Resize tracker |
| Left-click an accepted regular quest row | Add its Blizzard quest watch if needed and select it as the active navigation target |
| Right-click a quest row | Open its Wowhead URL for copying |
| `/qrt reset` | Clear addon selection, close the tracker, restore default window/launcher positions and size, and restore default settings |
| `/qrt debug` / `/qrt quest <ID>` | Print local diagnostic information |

Only an explicit quest-row left click can add a regular quest watch and select Blizzard's navigation target. Clicking an already watched quest can select it again without removing the watch. Events, refreshes and lookup do not set navigation. Other controls change only the addon's view and preferences; no quest is automatically accepted, abandoned or unwatched.

With **Fenster geöffnet lassen: An**, a deliberately opened tracker remains open through teleport, zone changes, talents and incidental UI hides. Escape leaves the main window open. Reload restores its saved manual opening choice. Use X, `/qrt` or minimap left-click to close it deliberately; it then stays closed through those transitions and reload. With the setting **Aus**, ordinary closing is allowed and reload does not reopen it automatically.

Automatic scrolling follows active quests within the displayed line. The latest newly accepted member quest or quest explicitly clicked in the addon has priority while active; otherwise the first active quest in the supplied order is used. Refreshing or laying out the rows brings that quest into view if needed, retaining the scroll position when it is already visible. Manual scrolling remains usable between refreshes; the next refresh can bring an offscreen target back. This changes the addon scroll position only and does not select a Blizzard navigation target.

## Warnings

With a loaded quest line selected, a quest outside its returned membership produces the enabled warning outputs when:

- a newly accepted quest is confirmed active;
- a world quest or quest-backed bonus objective becomes active in the player's area;
- a quest is newly watched, including **Quest beobachten**;
- a quest becomes the active navigation target, including selection in Blizzard's side tracker.

**Chatwarnung** with separate **An / Aus** choices controls only these activity-warning messages in chat; **Bildschirmwarnung** with separate **An / Aus** choices controls only the centered warning box. Both choices are saved per character and default to **An**. Either output or both outputs can be disabled. Switching screen warnings off immediately clears a visible box and its expiry deadline. Diagnostics and click-failure messages remain available. Changing either switch does not replay existing warnings. Existing watched quests are baselined at login/selection to avoid a startup flood. Current area tasks and navigation are still checked. Event bursts are coalesced, and unchanged activity does not repeat a warning. Leaving an area, removing a watch or changing navigation allows a new warning on return. Temporary failed reads do not count as leaving.

A single enabled banner remains visible for twice the native error frame's visible-plus-fade duration (five seconds if those reads are unavailable). The addon no longer also writes this warning to Blizzard's error frame. The banner stays visible when the tracker is closed. Expiry, game refreshes and finite active-search batches share one cancellable timer; other game events continue refreshing promptly.

No warning is issued without a selection or while its membership is loading. The comparison concerns the list Blizzard supplied; it does not prove that another quest is unnecessary or unrelated to every prerequisite. Scenario-only bonus steps without quest IDs cannot be matched as quests.

## Data and progress

Blizzard's APIs provide map-related lines and quest membership, not a complete global catalogue or prerequisite graph. Returned order is for display. Optionality and requirements remain unknown. The bar counts completion of the supplied list on this character; account-completed metadata cannot force it to 100%.

Rows show only **Abgeschlossen**, **Angenommen**, **Noch nicht angenommen** or **Queststand unbekannt**. Status text is smaller and less prominent below the title; the existing status colors are preserved. Finished objectives awaiting hand-in remain **Angenommen**. The availability suffix is removed. Tooltips can still show **Beim aktuellen NPC angeboten** for a real current NPC offer or **Vermuteter nächster Schritt** for an uncertain map suggestion.

Current-zone selection combines available map candidates with accepted quests whose client-supplied line associations and membership can be verified for that zone. This includes active lines that Blizzard omits from its available candidates. It remains a client-supplied subset, not a complete zone catalogue; the reported Trauerhöhe omission needs a new client check.

Below the percentage bar, a separate heading shows the localized line name supplied by Blizzard, followed by the completed-quest count and quest list. The **Suche** button retains its label. If map discovery omits the name, the adapter checks matching line metadata for known member quests. A known name survives temporary missing data within the session. If Blizzard supplies no name, **Questreihe &lt;ID&gt;** remains the fallback. Long headings remain available in the full-name tooltip.

Quest-ID lookup checks already loaded lists, then validates Blizzard's association against its returned membership. The ID may be the first quest or another member: lookup displays the whole `GetQuestLineQuests` list, not just that quest. The previous view stays visible during failure/loading. Later events can resolve a query; editing input, choosing another line, closing selection or **Entfernen** cancels it. Removing a line leaves the tracker empty after reload until another line is chosen. There is one coalescing timer and no permanent quest polling.

Name search now discovers zone lines through the client's map hierarchy and verifies accepted quest-log associations across zones, alongside session-cached lines. It supports partial names and case-insensitive German umlauts. A unique exact full-name match with loaded membership opens the whole supplied line after finite discovery settles. Partial names and several exact line IDs remain explicit choices; an incomplete matching line prevents automatic selection. Search uses the line's own supplied name: **Trauerhöhe** is the requested line-name example, while **Zur Trauerhöhe** is the user's individual first-quest title, not an installed alias.

Search results replace the zone list until a zone is selected again or **Zur Zonenliste** is used. A native loading spinner beside the submitted action indicates active work; a check marks verified selectable lines. A successful automatic full-name selection opens the main window with confirmation. An unsuccessful or invalid search displays **Keine passende Questreihe gefunden. Bitte prüfe deine Eingabe.** directly in the window, without different typo/data-failure messages. Matching achievement and criteria names remain information with context and current completion; they cannot select or construct a line or earn a successful-line check. Map, accepted-quest and achievement discovery are session-only and bounded. No full global catalogue or successful actual-client Trauerhöhe lookup is guaranteed; that example still needs a client test. A complete supplied member list does not establish prerequisites or combine separate lines into a larger story.

The zone dropdown places **Aktuelle Zone** first and groups other client-supplied zone maps by continent. A filter narrows zone names. Map metadata populates the choices; their quest lists are requested only when needed. Current-zone mode follows the player's zone changes. An explicitly selected other zone remains selected until another choice is made. Choosing a zone cancels obsolete name/ID lookup work so late responses cannot replace that view. The supplied map hierarchy can be incomplete and does not imply full quest-line coverage.

Unused addon search data is pruned after cancellation and terminal searches, retaining the selected line and data still needed for the current query/results, current zone or explicitly browsed zone. **Suchcache leeren** releases unused search caches and stops stale searches while preserving the displayed line and preferences. Later searches request data again when needed. It affects only addon-owned session data; Blizzard's client cache and quest state are untouched. **Entfernen** still clears the displayed/saved selection.

Schema 9 SavedVariables saves only selected map/line IDs, window geometry/positions, minimap position, independent `chatWarnings` / `screenWarnings` preferences, `keepWindowOpen` and the manual `windowOpen` choice. Quest lists, names, achievements and progress are not persisted. The three settings are validated booleans and default to enabled; missing or invalid `windowOpen` defaults to closed. Removed feature flags and old static selections are discarded. Prior default sizes adopt 360 × 500; other valid customized dimensions are preserved within that SavedVariables identity. `/qrt reset` restores default settings and closes the tracker; **Entfernen** preserves settings and the opening choice.

## Development

Open `QuestreihenTracker.code-workspace` in VS Code. Developer checks require Python 3.12+ and the test-only dependency:

```text
python -m pip install -r requirements-dev.txt
python scripts/test.py
python scripts/package.py
```

On this Windows workspace, `scripts/check.cmd` can use Codex's bundled Python runtime. Tests execute the actual Lua files under Lua 5.1 and guard the narrow gameplay API boundary.

| File | Responsibility |
| --- | --- |
| `LiveData.lua` | Pure conversion of client replies with source references |
| `Model.lua` | Pure membership and character-progress model |
| `WoW.lua` | Progress, NPC offers, activity warnings and explicit regular quest watching/navigation |
| `WoWQuestLines.lua` | Map discovery and session cache |
| `WoWQuestLookup.lua` | Current navigation quest and verified line lookup |
| `WoWNameDiscovery.lua` | Bounded runtime map-hierarchy and accepted-quest discovery for name search |
| `WoWNameSearch.lua` | Name matching, result states and bounded achievement/criteria reads |
| `WoWZoneCatalog.lua` | Client-supplied zone metadata, continent grouping and filtering |
| `UIHelpers.lua`, `UISelector.lua`, `UISettings.lua`, `UI.lua`, `Minimap.lua` | Compact native UI and saved settings controls |
| `Locale.lua`, `Core.lua` | German text, preferences and events |

[Data sources](docs/DATA_SOURCES.md), [gameplay action boundary](docs/GAME_ACTIONS.md) and [technical notes](TECHNICAL_NOTES.md) document the boundaries. The release ZIP contains the complete addon; local packages are also built in `outputs/`. Packaging does not publish or push. Git pushes and releases require the user's instruction; actual client results are recorded separately from offline checks.
