# Technical notes

Current build: 0.3.1. Runtime-only WoW Retail addon. TOC Interface 120100 remains based on the previously inspected 12.1.0 export; the installed client must be checked separately.

## Runtime lists

`RequestQuestLinesForMap`, `GetAvailableQuestLines` and `GetQuestLineQuests` supply map metadata and membership. A bounded parent walk prefers a zone map for submaps. Session caches retain a selected loaded list if discovery filters it or a read is briefly empty, while stale suggestions are removed.

`GetQuestLineInfo(questID, uiMapID, false)` can return nil. Lookup verifies returned membership, tries a quest-related map then current-zone request context and rereads after requests for synchronous replies. `QUESTLINE_UPDATE(requestRequired)` has no map ID: unresolved queries remain eligible for later data events until cancelled. No polling or automatic request loop is added.

Titles use `GetTitleForQuestID` / `RequestLoadQuestByID` and `QUEST_DATA_LOAD_RESULT`. Explicit refresh permits failed title retries; new lookup submission retries only its queried ID.

Line records distinguish `nameKnown` and `nameSourceAPI` from an ID fallback. Map replies supply names, including a matching hidden selected row without adding it to the chooser. If absent, `ResolveQuestLineName` reads member-quest metadata with default and selected-map contexts and accepts only a matching line ID and nonblank `questLineName`. Known names survive temporary missing data; names are session-only. Existing refresh events retry missing names without new requests, timers or polling.

## Character state

`IsQuestFlaggedCompleted` is handed-in completion; `IsOnQuest` is active membership. Both false establishes NOT_ACCEPTED; missing reads stay UNKNOWN. Objective completion alone remains ACTIVE. All supplied list entries count; no required/optional classification is invented.

NPC availability is ephemeral. Gossip supplies current offers; details require a positive quest ID, `UnitExists("questnpc") == true` and no item-start payload. Closing or switching lists clears offers. No acceptance or abandonment implementation exists.

## Activity warnings

`GetTasksTable()` and the first return of `GetTaskInfo(questID)` identify in-area quest-backed tasks, including world quests and bonus objectives; the fourth return supplies their title. Successful absence/out-of-area reads re-arm a task; unknown reads preserve prior state.

Regular/world watch getters detect additions. `QUEST_WATCH_LIST_CHANGED(questID, added)` can have nil payloads, so the adapter rereads the lists. Explicit removals are remembered even within one coalescing interval. Existing watches are baselined on startup/selection.

The current navigation target uses the same guarded `SuperTrackedQuestID` helper as lookup: quest mode, highest-priority quest type when available and a positive ID. Retained IDs behind nonquest waypoints are ignored. Unknown reads preserve previous warning state.

`QUEST_ACCEPTED(questID)` queues a warning until current active membership is confirmed by a normal event. Removal/turn-in or selection change cancels queued state. Candidates from multiple sources in one refresh produce one message per quest. No selection or loading membership suppresses warnings.

## Persistence and UI

Schema 5 saves only selection IDs and geometry/launcher preferences. No static selections or feature switches survive migration. Empty startup succeeds without API data. The former default 550 × 750 migrates to 440 × 500; other valid saved dimensions remain. Removed settings/review frames are never created.

`ClearSelection` cancels pending lookup, closes selector/copy dialogs and applies the empty line. It clears saved selection, offers, warnings and scroll state while retaining geometry and all game state. Queued callbacks and late data cannot restore the removed selection. The header and remove button share the existing selection row; the latter is disabled without a selection. Display labels use “Questreihe”; addon paths, namespace globals and SavedVariables retain their technical identity for compatibility.

All event work uses the existing single pending timer. The minimap's cursor OnUpdate exists only during a drag. API details and source links are in [DATA_SOURCES.md](docs/DATA_SOURCES.md). Offline regressions are separate from actual client loading, layout and taint results.
