# Technical notes

Current build: 0.4.1. Runtime-only WoW Retail addon. TOC Interface 120100 remains based on the previously inspected 12.1.0 export; the installed client must be checked separately.

## Runtime lists

`RequestQuestLinesForMap`, `GetAvailableQuestLines` and `GetQuestLineQuests` supply map metadata and membership. A bounded parent walk prefers a zone map for submaps. Session caches retain a selected loaded list if discovery filters it or a read is briefly empty, while stale suggestions are removed.

Available map candidates are supplemented from accepted log entries and current-map POIs. `GetQuestLineInfo(..., false)` associations require exact returned membership plus normalized start/destination relevance to the current zone. `GetQuestUiMapID(questID, true)` ignores routing waypoints. Failed available-map reads preserve previous candidates and allow independently verified active additions while reporting the error. Log/data/POI events retry reads; no global catalogue is assumed.

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

The addon-owned banner is the sole on-screen activity-warning output. No `UIErrorsFrame:AddMessage` call duplicates it. `chatWarnings` controls only local activity-warning chat messages; banner delivery and the adapter's warning state remain active while chat output is disabled. Toggling chat does not re-arm or replay existing activity. Diagnostics and explicit click failure messages are independent of the preference.

## Persistence and UI

Schema 7 saves selection IDs, geometry/launcher preferences and a validated `chatWarnings` boolean, which defaults to true when missing or invalid. False survives reload. Removed legacy flags and static selections are discarded. Empty startup succeeds without API data. Legacy defaults 550 × 750 (schema before 5) and 440 × 500 (schema before 6) adopt 360 × 500; other valid saved dimensions remain. Removed settings/review frames are never created. The identity change in 0.4.0 used new SavedVariables; 0.4.0-to-0.4.1 upgrades retain existing preferences.

`ClearSelection` cancels pending lookup, closes selector/copy dialogs and applies the empty line. It clears saved selection, offers, warning banner and scroll state while retaining geometry and all game state. Queued callbacks and late data cannot restore the removed selection. The header and remove button share the existing selection row; the latter is disabled without a selection. The product is “Questreihen Tracker”; display labels use “Questreihe” and all addon paths/globals use the renamed identity.

The main-window chat toggle and **Verfolgte Quest** share one horizontal control row. The toggle reflects the saved preference, not merely its label. Selection removal retains that preference; `/qrt reset` restores the default true along with other addon preferences.

All event work and warning expiry share one cancellable `C_Timer.NewTimer`; an earlier refresh cancels a later expiry timer and re-arms the remaining deadline afterward. No idle timer remains after expiry. The minimap's cursor OnUpdate exists only during a drag. The banner doubles the client's visible-plus-fade duration, with a five-second fallback. It does not change global error-frame settings. API details and source links are in [DATA_SOURCES.md](docs/DATA_SOURCES.md). Offline regressions are separate from actual client loading, layout and taint results.

## Explicit watching and navigation

Only a quest-row left click can call `WoW.WatchQuest` through Core's current-membership guard. The adapter validates a positive, currently accepted regular quest ID. For an unwatched quest it checks the actual watch limit and calls `C_QuestLog.AddQuestWatch(questID)` once. An already watched quest skips watch creation and can still become the active navigation target through `C_SuperTrack.SetSuperTrackedQuestID(questID)`.

The navigation setter has no documented return value; normal nil is not a refusal. Its result must be checked through the guarded quest-navigation getter. A failed watch does not proceed to navigation; a navigation failure after a successful watch leaves that watch in place and reports the outcome. Missing APIs, refused changes and failed confirmation remain local German messages. No event, refresh or lookup invokes these setters, no watch is toggled/removed, and no deferred gameplay action is queued. Main-window **Verfolgte Quest** reads the resulting navigation target and chooses only the displayed line. Real client navigation and taint remain separate acceptance checks.

## Offline validation for 0.4.1

`scripts/check.cmd` passes 117 counted behavioral cases, separate banner-deadline/startup/reload/missing-API checks and 54 static guard cases. All 10 addon Lua files load under Lua 5.1; the boundary reviews 26 C API members. No forbidden game API attempts or invalid IDs were recorded. The 13-file v0.4.1 addon ZIP was built successfully. These results do not establish actual WoW layout, navigation or taint behavior; the client checklist remains pending.
