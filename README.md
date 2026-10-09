# Questreihe Tracker — v0.3.1

A compact World of Warcraft Retail addon that displays one selected quest line and its character progress. **All quest lists, names and progress come from the WoW client at runtime.** No curated stories, quest database, external service or in-game library is shipped.

The German interface has a movable, resizable quest list, a small quest-line selector and a draggable minimap launcher. Settings and the other-quests view have been removed. The default tracker is 440 × 500 pixels; its minimum is 360 × 300.

## Install and test

1. Extract `outputs/QuestStrangTracker-v0.3.1.zip` into `World of Warcraft/_retail_/Interface/AddOns/`.
2. Confirm the result is `AddOns/QuestStrangTracker/QuestStrangTracker.toc`, without an extra nested folder.
3. Enable the addon and use `/reload`.
4. Open it with `/qst` or the minimap logo. Click **Questreihe auswählen**.
5. Choose a supplied current-zone line, click **Verfolgte Quest** for the quest with Blizzard's navigation arrow, or enter a **Quest-ID** and click **Anzeigen** / press Enter.

There is no default story. An old saved curated selection becomes **Keine Questreihe ausgewählt**. A valid saved Blizzard map/line selection is restored from live data. Missing data remains loading or unresolved; it never activates an invented fallback list.

Replace the existing addon folder completely when upgrading so old files such as `QuestData.lua` are removed. Only `addon/QuestStrangTracker/` belongs inside AddOns. See [the client test checklist](docs/IN_GAME_TEST.md) for this build.

The TOC targets Interface **120100**, based on the previously inspected Retail 12.1.0 export. Compare the fourth result of `GetBuildInfo()` with your actual client. Offline stubs do not verify real layout, client API behavior or taint.

## Controls

| Control | Action |
| --- | --- |
| `/qst` / minimap left click | Show or hide the tracker |
| `/qst zone` / minimap right click | Open selection and request current-zone lists |
| **Verfolgte Quest** | Display the line of the current quest navigation target |
| **Quest-ID** + **Anzeigen** / Enter | Find and verify a supplied quest-to-line association |
| **Aktualisieren** | Request zone data again and retry failed titles |
| **Entfernen** | Clear the loaded line and saved selection, keeping window geometry and Blizzard tracking |
| Drag title / unused background | Move tracker, selector or copy-link dialog |
| Drag bottom-right grip | Resize tracker |
| Right-click a quest row | Open its Wowhead URL for copying |
| `/qst reset` | Clear addon selection and restore default window/launcher positions and size |
| `/qst debug` / `/qst quest <ID>` | Print local diagnostic information |

Quest rows only display information. Addon controls never change Blizzard's quest selection, watches, navigation arrow or waypoint.

## Warnings

With a loaded quest line selected, a quest outside its returned membership produces a local chat and on-screen warning when:

- a newly accepted quest is confirmed active;
- a world quest or quest-backed bonus objective becomes active in the player's area;
- a quest is newly watched, including **Quest beobachten**;
- a quest becomes the active navigation target, including selection in Blizzard's side tracker.

Warnings are always enabled. Existing watched quests are baselined at login/selection to avoid a startup flood. Current area tasks and navigation are still checked. Event bursts are coalesced, and unchanged activity does not repeat a warning. Leaving an area, removing a watch or changing navigation allows a new warning on return. Temporary failed reads do not count as leaving.

No warning is issued without a selection or while its membership is loading. The comparison concerns the list Blizzard supplied; it does not prove that another quest is unnecessary or unrelated to every prerequisite. Scenario-only bonus steps without quest IDs cannot be matched as quests.

## Data and progress

Blizzard's APIs provide map-related lines and quest membership, not a complete global catalogue or prerequisite graph. Returned order is for display. Optionality and requirements remain unknown. The bar counts completion of the supplied list on this character; account-completed metadata cannot force it to 100%.

Rows show **Abgeschlossen**, **Angenommen**, **Noch nicht angenommen** or **Queststand unbekannt**. Finished objectives awaiting hand-in remain **Angenommen**. **Beim aktuellen NPC angeboten** requires a real current NPC offer. A supplied map suggestion is labelled **Vermuteter nächster Schritt**.

The header shows the localized line name supplied by Blizzard. If map discovery omits it, the adapter checks matching line metadata for known member quests. A known name survives temporary missing data within the session. If Blizzard supplies no name, **Questreihe &lt;ID&gt;** remains the fallback. Hover over the selection button to see the full name.

Lookup checks already loaded lists, then validates Blizzard's association against its returned membership. The previous view stays visible during failure/loading. Later events can resolve a query; editing input, choosing another line, closing selection or **Entfernen** cancels it. Removing a line leaves the tracker empty after reload until another line is chosen. There is one coalescing timer and no permanent quest polling.

Only selected map/line IDs, window geometry/positions and minimap position are saved. Quest lists, names, achievements and progress are not persisted. Removed feature settings and old static selections are discarded. A legacy saved default 550 × 750 window adopts the new compact size; other saved dimensions are preserved.

## Development

Open `QuestStrangTracker.code-workspace` in VS Code. Developer checks require Python 3.12+ and the test-only dependency:

```text
python -m pip install -r requirements-dev.txt
python scripts/test.py
python scripts/package.py
```

On this Windows workspace, `scripts/check.cmd` can use Codex's bundled Python runtime. Tests execute the actual Lua files under Lua 5.1 and guard the display-only API boundary.

| File | Responsibility |
| --- | --- |
| `LiveData.lua` | Pure conversion of client replies with source references |
| `Model.lua` | Pure membership and character-progress model |
| `WoW.lua` | Read-only progress, NPC offers and activity warnings |
| `WoWQuestLines.lua` | Map discovery and session cache |
| `WoWQuestLookup.lua` | Current navigation quest and verified line lookup |
| `UIHelpers.lua`, `UI.lua`, `Minimap.lua` | Compact native UI |
| `Locale.lua`, `Core.lua` | German text, preferences and events |

[Data sources](docs/DATA_SOURCES.md), [display-only contract](docs/DISPLAY_ONLY.md) and [technical notes](TECHNICAL_NOTES.md) document the boundaries. The local ZIP is an installable test build. The user's client test precedes any Git push; no remote, push or release is performed by packaging.
