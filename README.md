# Questreihen Tracker — v0.5.0

A compact World of Warcraft Retail addon that displays one selected quest line and its character progress. **All quest lists, names and progress come from the WoW client at runtime.** No curated stories, quest database, external service or in-game library is shipped.

The German interface has a movable, resizable quest list with a partly transparent background, a quest-line selector and a draggable minimap launcher. A larger underlined title, thin section rules and dividers between quest rows organize the main window; smaller status text sits directly below each quest title. The default tracker is 360 × 500 pixels; its minimum is 320 × 300. Left-click an accepted regular quest to observe it in Blizzard's quest tracker and make it the active navigation target. Separate main-window buttons enable or disable chat warnings and the centered warning box independently.

## Install and test

1. Download [QuestreihenTracker-v0.5.0.zip from GitHub](https://github.com/marvinfuture/QuestreiheTracker/releases/download/v0.5.0/QuestreihenTracker-v0.5.0.zip) or use the [locally built ZIP](outputs/QuestreihenTracker-v0.5.0.zip). Extract it into `World of Warcraft/_retail_/Interface/AddOns/`.
2. Confirm the result is `AddOns/QuestreihenTracker/QuestreihenTracker.toc`, without an extra nested folder.
3. Enable the addon and use `/reload`.
4. Open it with `/qrt` or the minimap logo. Click **Questreihe auswählen**.
5. Choose a supplied current-zone line, click **Verfolgte Quest** for the quest with Blizzard's navigation arrow, enter a **Quest-ID** and click **Anzeigen** / press Enter, or enter a line name in **Name** and click **Suchen**.

There is no default story. An old saved curated selection becomes **Keine Questreihe ausgewählt**. A valid saved Blizzard map/line selection is restored from live data. Missing data remains loading or unresolved; it never activates an invented fallback list.

Replace the previous addon folder when upgrading so only one copy is enabled. When upgrading from 0.3.1 or earlier, remove the previous addon folder too; the identity change in 0.4.0 starts fresh preferences. Later upgrades preserve preferences, including the saved chat-warning choice. The new screen-warning switch defaults to **An** when no valid choice is saved. Only `addon/QuestreihenTracker/` belongs inside AddOns. See [the client test checklist](docs/IN_GAME_TEST.md) for this build.

The TOC targets Interface **120100**, based on the previously inspected Retail 12.1.0 export. Compare the fourth result of `GetBuildInfo()` with your actual client. Offline stubs do not verify real layout, client API behavior or taint.

## Controls

| Control | Action |
| --- | --- |
| `/qrt` / minimap left click | Show or hide the tracker |
| `/qrt zone` / minimap right click | Open selection and request current-zone lists |
| **Verfolgte Quest** in either window | Display the line of the current quest navigation target |
| **Chatwarnung: An/Aus** in the main window | Enable or disable local activity-warning messages in chat independently of the warning box |
| **Bildschirmwarnung: An/Aus** in the main window | Enable or disable the centered warning box independently of chat; switching off clears any visible box immediately |
| **Quest-ID** + **Anzeigen** / Enter | Find and verify a supplied quest-to-line association |
| **Name** + **Suchen** / Enter | Search client-supplied line names and display matching achievement/criteria information |
| **Zur Zonenliste** | Leave name-search results and return to current-zone selection |
| **Aktualisieren** | Request zone data again and retry failed titles |
| **Entfernen** | Clear the loaded line and saved selection, keeping window geometry and Blizzard tracking |
| Drag title / unused background | Move tracker, selector or copy-link dialog |
| Drag bottom-right grip | Resize tracker |
| Left-click an accepted regular quest row | Add its Blizzard quest watch if needed and select it as the active navigation target |
| Right-click a quest row | Open its Wowhead URL for copying |
| `/qrt reset` | Clear addon selection, restore default window/launcher positions and size, and enable both warning outputs |
| `/qrt debug` / `/qrt quest <ID>` | Print local diagnostic information |

Only an explicit quest-row left click can add a regular quest watch and select Blizzard's navigation target. Clicking an already watched quest can select it again without removing the watch. Events, refreshes and lookup do not set navigation. Other controls change only the addon's view and preferences; no quest is automatically accepted, abandoned or unwatched.

## Warnings

With a loaded quest line selected, a quest outside its returned membership produces the enabled warning outputs when:

- a newly accepted quest is confirmed active;
- a world quest or quest-backed bonus objective becomes active in the player's area;
- a quest is newly watched, including **Quest beobachten**;
- a quest becomes the active navigation target, including selection in Blizzard's side tracker.

**Chatwarnung: An/Aus** controls only these activity-warning messages in chat; **Bildschirmwarnung: An/Aus** controls only the centered warning box. Both choices are saved per character and default to **An**. Either output or both outputs can be disabled. Switching screen warnings off immediately clears a visible box and its expiry deadline. Diagnostics and click-failure messages remain available. Changing either switch does not replay existing warnings. Existing watched quests are baselined at login/selection to avoid a startup flood. Current area tasks and navigation are still checked. Event bursts are coalesced, and unchanged activity does not repeat a warning. Leaving an area, removing a watch or changing navigation allows a new warning on return. Temporary failed reads do not count as leaving.

A single enabled banner remains visible for twice the native error frame's visible-plus-fade duration (five seconds if those reads are unavailable). The addon no longer also writes this warning to Blizzard's error frame. The banner stays visible when the tracker is closed. Expiry, game refreshes and finite active-search batches share one cancellable timer; other game events continue refreshing promptly.

No warning is issued without a selection or while its membership is loading. The comparison concerns the list Blizzard supplied; it does not prove that another quest is unnecessary or unrelated to every prerequisite. Scenario-only bonus steps without quest IDs cannot be matched as quests.

## Data and progress

Blizzard's APIs provide map-related lines and quest membership, not a complete global catalogue or prerequisite graph. Returned order is for display. Optionality and requirements remain unknown. The bar counts completion of the supplied list on this character; account-completed metadata cannot force it to 100%.

Rows show only **Abgeschlossen**, **Angenommen**, **Noch nicht angenommen** or **Queststand unbekannt**. Status text is smaller and less prominent below the title; the existing status colors are preserved. Finished objectives awaiting hand-in remain **Angenommen**. The availability suffix is removed. Tooltips can still show **Beim aktuellen NPC angeboten** for a real current NPC offer or **Vermuteter nächster Schritt** for an uncertain map suggestion.

Current-zone selection combines available map candidates with accepted quests whose client-supplied line associations and membership can be verified for that zone. This includes active lines that Blizzard omits from its available candidates. It remains a client-supplied subset, not a complete zone catalogue; the reported Trauerhöhe omission needs a new client check.

The header shows the localized line name supplied by Blizzard. If map discovery omits it, the adapter checks matching line metadata for known member quests. A known name survives temporary missing data within the session. If Blizzard supplies no name, **Questreihe &lt;ID&gt;** remains the fallback. Hover over the selection button to see the full name.

Lookup checks already loaded lists, then validates Blizzard's association against its returned membership. The previous view stays visible during failure/loading. Later events can resolve a query; editing input, choosing another line, closing selection or **Entfernen** cancels it. Removing a line leaves the tracker empty after reload until another line is chosen. There is one coalescing timer and no permanent quest polling.

Name search supports partial names and case-insensitive German umlauts. Its result list replaces the zone chooser until **Zur Zonenliste** is clicked. Client-supplied lines with loaded membership are selectable. Matching achievement and criteria names show their context and completion as information; they cannot select a quest line. Blizzard's achievement links can lead to subachievements, but no reliable criterion-to-quest mapping was established. Matching names therefore do not establish membership or prerequisites. The session-only achievement index is built in finite batches while searching; missing APIs or scan limits are reported as partial results. A full global quest-line catalogue and a successful Trauerhöhe lookup are not guaranteed.

Schema 8 saves only selected map/line IDs, window geometry/positions, minimap position and the independent `chatWarnings` / `screenWarnings` preferences. Quest lists, names, achievements and progress are not persisted. Both warning preferences are validated booleans; missing or invalid values default to enabled. Removed feature flags and old static selections are discarded. Prior default sizes adopt 360 × 500; other valid customized dimensions are preserved within that SavedVariables identity. `/qrt reset` restores both warning outputs to **An**; **Entfernen** preserves both choices.

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
| `WoWNameSearch.lua` | Runtime name search and bounded achievement/criteria reads |
| `UIHelpers.lua`, `UI.lua`, `Minimap.lua` | Compact native UI |
| `Locale.lua`, `Core.lua` | German text, preferences and events |

[Data sources](docs/DATA_SOURCES.md), [gameplay action boundary](docs/GAME_ACTIONS.md) and [technical notes](TECHNICAL_NOTES.md) document the boundaries. The release ZIP contains the complete addon; local packages are also built in `outputs/`. Packaging does not publish or push. Git pushes and releases require the user's instruction; actual client results are recorded separately from offline checks.
