# Technical notes

Current build: 0.5.0. Runtime-only WoW Retail addon. TOC Interface 120100 remains based on the previously inspected 12.1.0 export; the installed client must be checked separately.

## Runtime lists

`RequestQuestLinesForMap`, `GetAvailableQuestLines` and `GetQuestLineQuests` supply map metadata and membership. A bounded parent walk prefers a zone map for submaps. Session caches retain a selected loaded list if discovery filters it or a read is briefly empty, while stale suggestions are removed.

Available map candidates are supplemented from accepted log entries and current-map POIs. `GetQuestLineInfo(..., false)` associations require exact returned membership plus normalized start/destination relevance to the current zone. `GetQuestUiMapID(questID, true)` ignores routing waypoints. Failed available-map reads preserve previous candidates and allow independently verified active additions while reporting the error. Log/data/POI events retry reads; no global catalogue is assumed.

`GetQuestLineInfo(questID, uiMapID, false)` can return nil. Lookup verifies returned membership, tries a quest-related map then current-zone request context and rereads after requests for synchronous replies. `QUESTLINE_UPDATE(requestRequired)` has no map ID: unresolved queries remain eligible for later data events until cancelled. No polling or automatic request loop is added.

Titles use `GetTitleForQuestID` / `RequestLoadQuestByID` and `QUEST_DATA_LOAD_RESULT`. Explicit refresh permits failed title retries; new lookup submission retries only its queried ID.

Line records distinguish `nameKnown` and `nameSourceAPI` from an ID fallback. Map replies supply names, including a matching hidden selected row without adding it to the chooser. If absent, `ResolveQuestLineName` reads member-quest metadata with default and selected-map contexts and accepts only a matching line ID and nonblank `questLineName`. Known names survive temporary missing data; names are session-only. Existing refresh events retry missing names without new requests, timers or polling.

## Name search and achievement information

The selector has a separate **Name** field and **Suchen** button. Search results replace the zone list until **Zur Zonenliste** is selected. Input requires at least two UTF-8 characters and at most 240 bytes. Name matching supports literal substrings, case differences and German umlauts. Runtime line results require a real known client name and loaded `GetQuestLineQuests` membership; multiple matches remain explicit choices. A known line name whose membership is still loading can appear as nonselectable information. Searching does not silently replace the displayed line or issue a gameplay mutation.

`GetCategoryList`, `GetCategoryNumAchievements`, `GetAchievementInfo`, `GetAchievementNumCriteria` and `GetAchievementCriteriaInfo` build a session-only name index. Each index continuation has budgets of 100 achievement reads, 500 criteria reads and 100 categories, with total ceilings of 6,000 achievements and 30,000 criteria. Loading and partial states remain visible; work stops after completion or cancellation. At most 200 sorted hits are returned, with additional live completion reads for those matching achievement/criteria records. A matching achievement title also exposes its direct criteria. The search does not add permanent polling or persist achievement progress.

Blizzard's native achievement UI uses criterion type 8 (`CRITERIA_TYPE_ACHIEVEMENT`) and its `assetID` to reference a subachievement. Traversal follows these links with a visited set. No reliable primary-source mapping from other criteria assets to quest IDs was found. Achievement/criteria matches therefore remain nonselectable information with parent achievement context and completion. Their names do not establish quest-line membership, dependencies or prerequisites. No arbitrary criterion asset is passed to a quest API, and no static real quest or achievement ID is introduced. Reviewed sources are listed in [DATA_SOURCES.md](docs/DATA_SOURCES.md).

## Character state

`IsQuestFlaggedCompleted` is handed-in completion; `IsOnQuest` is active membership. Both false establishes NOT_ACCEPTED; missing reads stay UNKNOWN. Objective completion alone remains ACTIVE. All supplied list entries count; no required/optional classification is invented.

NPC availability is ephemeral. Gossip supplies current offers; details require a positive quest ID, `UnitExists("questnpc") == true` and no item-start payload. Closing or switching lists clears offers. No acceptance or abandonment implementation exists.

## Activity warnings

`GetTasksTable()` and the first return of `GetTaskInfo(questID)` identify in-area quest-backed tasks, including world quests and bonus objectives; the fourth return supplies their title. Successful absence/out-of-area reads re-arm a task; unknown reads preserve prior state.

Regular/world watch getters detect additions. `QUEST_WATCH_LIST_CHANGED(questID, added)` can have nil payloads, so the adapter rereads the lists. Explicit removals are remembered even within one coalescing interval. Existing watches are baselined on startup/selection.

The current navigation target uses the same guarded `SuperTrackedQuestID` helper as lookup: quest mode, highest-priority quest type when available and a positive ID. Retained IDs behind nonquest waypoints are ignored. Unknown reads preserve previous warning state.

`QUEST_ACCEPTED(questID)` queues a warning until current active membership is confirmed by a normal event. Removal/turn-in or selection change cancels queued state. Candidates from multiple sources in one refresh produce one message per quest. No selection or loading membership suppresses warnings.

The addon-owned banner is the sole on-screen activity-warning output. No `UIErrorsFrame:AddMessage` call duplicates it. `chatWarnings` controls local activity-warning chat messages; `screenWarnings` independently controls the banner. Activity detection and deduplication remain active even when both outputs are disabled. Switching screen warnings off immediately clears any visible banner and its expiry deadline without cancelling an earlier pending refresh. Toggling either output does not re-arm or replay existing activity. Diagnostics and explicit click failure messages are independent of these preferences.

## Persistence and UI

Schema 8 SavedVariables holds selection IDs, geometry/launcher preferences and validated `chatWarnings` / `screenWarnings` booleans. Each defaults to true when missing or invalid; false survives reload independently. Existing saved chat choices are retained when the new screen preference is introduced. Removed legacy flags and static selections are discarded. Empty startup succeeds without API data. Legacy defaults 550 × 750 (schema before 5) and 440 × 500 (schema before 6) adopt 360 × 500; other valid saved dimensions remain. Removed settings/review frames are never created. The identity change in 0.4.0 used new SavedVariables; subsequent upgrades retain existing preferences. The current release preserves the established window sizes.

`ClearSelection` cancels pending lookup, closes selector/copy dialogs and applies the empty line. It clears saved selection, offers, warning banner and scroll state while retaining geometry and all game state. Queued callbacks and late data cannot restore the removed selection. The header and remove button share the existing selection row; the latter is disabled without a selection. The product is “Questreihen Tracker”; display labels use “Questreihe” and all addon paths/globals use the renamed identity.

The main window keeps **Chatwarnung: An/Aus** beside **Verfolgte Quest** and adds a full-width **Bildschirmwarnung: An/Aus** button below that row. The two warning controls reflect separate saved preferences. Selection removal retains both preferences; `/qrt reset` restores both to true along with the other addon preferences.

The 0.4.2 main window uses a larger underlined title, thin horizontal rules after the buttons and before the quest list, and dividers between quest rows. Progress status is smaller and less prominent directly below the title. These changes preserve exact quest title strings, existing status colors and row click actions; no new game API or data source is introduced. Actual layout at different sizes and UI scales must be checked in the client.

Version 0.5.0 keeps that layout and completes the active-project naming cleanup, including the project directory and documentation. The addon, installation folder, globals, workspace and package use `QuestreihenTracker`; visible product text uses “Questreihen Tracker”. Explanatory English comments precede addon Lua function declarations and anonymous callbacks to document their purpose without changing quest behavior.

All event work, warning expiry and finite active-search batches share one cancellable `C_Timer.NewTimer`; an earlier refresh cancels a later expiry timer and re-arms the remaining deadline afterward. No idle timer remains after warning expiry and search completion/cancellation. The minimap's cursor OnUpdate exists only during a drag. The banner doubles the client's visible-plus-fade duration, with a five-second fallback. It does not change global error-frame settings. API details and source links are in [DATA_SOURCES.md](docs/DATA_SOURCES.md). Offline regressions are separate from actual client loading, layout and taint results.

## Explicit watching and navigation

Only a quest-row left click can call `WoW.WatchQuest` through Core's current-membership guard. The adapter validates a positive, currently accepted regular quest ID. For an unwatched quest it checks the actual watch limit and calls `C_QuestLog.AddQuestWatch(questID)` once. An already watched quest skips watch creation and can still become the active navigation target through `C_SuperTrack.SetSuperTrackedQuestID(questID)`.

The navigation setter has no documented return value; normal nil is not a refusal. Its result must be checked through the guarded quest-navigation getter. A failed watch does not proceed to navigation; a navigation failure after a successful watch leaves that watch in place and reports the outcome. Missing APIs, refused changes and failed confirmation remain local German messages. No event, refresh or lookup invokes these setters, no watch is toggled/removed, and no deferred gameplay action is queued. Main-window **Verfolgte Quest** reads the resulting navigation target and chooses only the displayed line. Real client navigation and taint remain separate acceptance checks.

## Offline validation for 0.4.1

`scripts/check.cmd` passes 117 counted behavioral cases, separate banner-deadline/startup/reload/missing-API checks and 54 static guard cases. All 10 addon Lua files load under Lua 5.1; the boundary reviews 26 C API members. No forbidden game API attempts or invalid IDs were recorded. The 13-file v0.4.1 addon ZIP was built successfully. These results do not establish actual WoW layout, navigation or taint behavior; the client checklist remains pending.

## Offline validation for 0.4.2

`scripts/check.cmd` passes the existing 117 counted behavioral cases, separate banner-deadline/startup/reload/missing-API checks and 54 static guard cases. Relevant assertions and the text-measurement stub were adjusted for the moved control row and measured string height. All 10 addon Lua files load under Lua 5.1; the boundary reviews 26 C API members, with zero forbidden game API attempts or invalid IDs. The 13-file v0.4.2 ZIP was built successfully. These checks preserve the gameplay boundary and do not prove actual client text wrapping, spacing, layout or taint behavior.

## Validation for 0.5.0

The integrated suite passes 152 counted behavioral cases: the prior 117 plus 12 screen-warning, 13 name-search and ten UI cases. Separate banner-deadline, startup, fresh-reload and missing-API checks also pass, along with 54 static guard cases. All 11 addon Lua files load under Lua 5.1; the boundary reviews 26 C API members, with zero forbidden game API attempts or invalid IDs. `python scripts/package.py --tag v0.5.0` builds the 14-file addon ZIP successfully.

Validation covers name and ID lookup, achievement/criteria information with safe subachievement links, both warning preferences and the existing gameplay boundary. Actual WoW layout, API availability, Trauerhöhe search coverage and taint checks remain pending in [IN_GAME_TEST.md](docs/IN_GAME_TEST.md).
