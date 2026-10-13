# Technical notes

Current build: 0.5.2. Runtime-only WoW Retail addon. TOC Interface 120100 remains based on the previously inspected 12.1.0 export; the installed client must be checked separately.

## Runtime lists

`RequestQuestLinesForMap`, `GetAvailableQuestLines` and `GetQuestLineQuests` supply map metadata and membership. A bounded parent walk prefers a zone map for submaps. Session caches retain a selected loaded list if discovery filters it or a read is briefly empty, while stale suggestions are removed.

Available map candidates are supplemented from accepted log entries and current-map POIs. `GetQuestLineInfo(..., false)` associations require exact returned membership plus normalized start/destination relevance to the current zone. `GetQuestUiMapID(questID, true)` ignores routing waypoints. Failed available-map reads preserve previous candidates and allow independently verified active additions while reporting the error. Log/data/POI events retry reads; no global catalogue is assumed.

`GetQuestLineInfo(questID, uiMapID, false)` can return nil. Lookup verifies returned membership, tries a quest-related map then current-zone request context and rereads after requests for synchronous replies. `QUESTLINE_UPDATE(requestRequired)` has no map ID: unresolved queries remain eligible for later data events until cancelled. No polling or automatic request loop is added.

Titles use `GetTitleForQuestID` / `RequestLoadQuestByID` and `QUEST_DATA_LOAD_RESULT`. Explicit refresh permits failed title retries; new lookup submission retries only its queried ID.

Line records distinguish `nameKnown` and `nameSourceAPI` from an ID fallback. Map replies supply names, including a matching hidden selected row without adding it to the chooser. If absent, `ResolveQuestLineName` reads member-quest metadata with default and selected-map contexts and accepts only a matching line ID and nonblank `questLineName`. Known names survive temporary missing data; names are session-only. Existing refresh events retry missing names without new requests, timers or polling.

## Name search and achievement information

Version 0.5.2 implements lookup by the supplied quest-line name so it can display the same complete `GetQuestLineQuests` membership as quest-ID lookup. An ID lookup may begin with the first or any other member quest; both paths select a verified line, not an individual quest or a combined prerequisite story.

The selector has a separate **Reihe** field and **Suchen** button. Search results replace the zone list until **Zur Zonenliste** is selected. Input requires at least two UTF-8 characters and at most 240 bytes. Name matching supports literal substrings, case differences and German umlauts. Runtime line results require a real known client name and loaded, nonempty `GetQuestLineQuests` membership. Once finite discovery settles, a unique exact full-name match opens automatically; partial names and several exact line IDs remain explicit choices. A matching known name with unavailable membership remains nonselectable and blocks automatic selection. Quest titles and achievement names do not become line-name aliases. Searching issues no gameplay mutation.

`WoWNameDiscovery.lua` walks runtime map context and uses `C_Map.GetFallbackWorldMapID`, `GetMapInfo` and `GetMapChildrenInfo(root, Enum.UIMapType.Zone, true)` to discover zone map IDs. It queues at most 400 maps from current/cache/tree discovery, then supplements them with request contexts from up to 100 accepted quest seeds through `FindQuestLine` and exact membership verification across zones. Log collection examines at most 1,000 entries. Each continuation advances at most six queued maps, twelve pending map reads and four quest candidates. Pending map/quest waits stop after five seconds or fifty reads; an aggregate 250-continuation cutoff marks remaining discovery partial. These are addon budgets, not promises about Blizzard's data completeness.

Client events can recheck completed discovery in bounded batches; rechecks do not force requests unless `QUESTLINE_UPDATE` explicitly supplies `requestRequired = true`. Discovery, requests and progress remain runtime-only and use the existing coalescing timer. Editing input, closing selection, returning to the zone list, selecting/removing a line or superseding a search cancels pending work; late replies cannot replace that newer choice.

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

Schema 9 SavedVariables holds selection IDs, geometry/launcher preferences, validated `chatWarnings` / `screenWarnings` / `keepWindowOpen` booleans and the manual `windowOpen` choice. The three settings default to true when missing or invalid; false survives reload independently. `windowOpen` defaults to false, so a fresh installation begins closed. Existing warning choices survive the upgrade. Removed legacy flags and static selections are discarded. Empty startup succeeds without API data. Legacy defaults 550 × 750 (schema before 5) and 440 × 500 (schema before 6) adopt 360 × 500; other valid saved dimensions remain. The settings panel introduced in 0.5.1 is addon-owned, draggable and saves its position; the removed other-quests view remains absent. The identity change in 0.4.0 used new SavedVariables; subsequent upgrades retain existing preferences. The current build preserves the established window sizes.

`ClearSelection` cancels pending lookup, closes selector/copy dialogs and applies the empty line. It clears saved selection, offers, warning banner and scroll state while retaining geometry and all game state. Queued callbacks and late data cannot restore the removed selection. The header and remove button share the existing selection row; the latter is disabled without a selection. The product is “Questreihen Tracker”; display labels use “Questreihe” and all addon paths/globals use the renamed identity.

The main window's gear opens a settings panel containing **Chatwarnung: An/Aus**, **Bildschirmwarnung: An/Aus** and **Fenster geöffnet lassen: An/Aus**. The two warning controls retain their separate saved preferences and existing immediate banner-dismissal behavior. Selection removal retains settings and opening choice; `/qrt reset` restores defaults and closes the main window through `UI.Restore` with `windowOpen = false`.

When `keepWindowOpen` is enabled and `windowOpen` records an explicit open choice, incidental main-window hides are restored and reload restores that open choice. The tracker is excluded from ordinary Escape closing in this mode. A close-button, slash-toggle or minimap-toggle action saves `windowOpen = false`; incidental events cannot undo that explicit close. Disabling keep-open permits ordinary closing and prevents reload reopening. This policy concerns only the main addon frame and does not hook or alter Blizzard's talent frame or other panels. Settings and auxiliary dialogs can still close normally.

Active-quest scrolling uses confirmed current acceptance from the live snapshot, preferring the latest newly accepted or explicitly clicked member while active, otherwise the first active member in supplied order. Current repeatable iterations remain eligible even when historical completion gives the row its existing completed progress/color. Every row refresh/reflow brings the measured target into the viewport using a clamped scroll offset; when it is already visible, the current position is retained. Manual scrolling remains possible between refreshes. Accepted/turned-in/removed quests can change the target, and delayed title loads or resizing can change row geometry. No active member creates no target. Scrolling invokes no gameplay mutation and requires no permanent update handler or second event timer.

The native UI source review on 2026-10-13 uses the pinned export `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`. Blizzard's [UIParentPanelManager](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua) closes registered `UISpecialFrames` during ordinary window/panel closing. Keep-open removes only this addon's main-frame name from that list; disabling it restores registration. The native [scroll template XML](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedXML/SecureScrollTemplates.xml) and [scroll handlers](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedXML/SecureScrollTemplates.lua) establish the `.ScrollBar` child and vertical-scroll synchronization. The addon updates the child rectangle, calls `SetVerticalScroll` and synchronizes the native scrollbar, without Blizzard hooks or a permanent `OnUpdate`.

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

## Validation for 0.5.1

`python scripts/test.py` passes 167 counted behavioral cases: the existing 152 plus 15 new window/settings/scroll cases. Four additional fresh-namespace startup visibility combinations pass, along with the existing banner-deadline/startup/reload/missing-API checks and 54 static guard selftests. All 12 addon Lua files load under Lua 5.1. The boundary audits 26 C API members, with zero forbidden mutations or invalid IDs. The new regressions cover explicit closing during a pending lookup and scrolling to a currently accepted repeatable quest independently of historical progress colors.

`python scripts/package.py --tag v0.5.1` successfully builds the 15-file addon ZIP, 72,260 bytes. The actual client test remains pending. [IN_GAME_TEST.md](docs/IN_GAME_TEST.md) includes persistent opening through teleport, talents and reload, intentional close/reload, the three settings and automatic scrolling at long/wrapped/minimum-size layouts. Offline results do not establish actual game-frame visibility or taint behavior. Implementation was initially authorized on 2026-10-13; the subsequent request authorizes publication of these changes with 0.5.2.

## Validation for 0.5.2

`python scripts/test.py` passes 190 counted behavioral cases: the prior 167 plus 23 new discovery/name-search cases. Four fresh-namespace startup visibility combinations, the separate banner/startup/reload/missing-API checks and 54 static selftests also pass. All 13 addon Lua files load under Lua 5.1; the boundary reviews 28 C API members, with zero forbidden mutations or invalid IDs. Coverage includes uncached cross-zone line discovery, exact-name automatic opening, partial/ambiguous/incomplete matching, finite limits/waiting and cancellation without stale selection or gameplay mutations.

`python scripts/package.py --tag v0.5.2` builds the 16-file addon ZIP successfully, 75,870 bytes.

The user authorized implementation, Git push and a current GitHub release on 2026-10-13. Actual-client Trauerhöhe discovery, equivalence with first/other member quest-ID lookup, API availability, layout and Lua/taint checks remain pending in [IN_GAME_TEST.md](docs/IN_GAME_TEST.md).
