# Runtime data sources

Version 0.3.0 removes all bundled quest stories and `QuestData.lua`. No fixed real quest IDs, prerequisites, NPC routes or static story names remain in the addon. Names, membership and character progress are supplied by the game; saved selection IDs are user preferences.

Version 0.3.1 additionally recovers missing selected-line names from client metadata. Names are never inferred from screenshot labels, member quest titles or a bundled ID-to-name table.

## Quest lists and progress

The retained quest-line conversion source is Blizzard's generated documentation at commit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [Quest-line API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLineInfoDocumentation.lua): map requests, returned line lists, `GetQuestLineInfo` and `GetQuestLineQuests`. Each runtime line/node carries its source URL and source API.
- [Map API](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua): current map and parent metadata.
- [Blizzard map provider](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_SharedMapDataProviders/QuestOfferDataProvider.lua): map-cache request/update handling.
- [Quest map](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua): quest-related `GetQuestUiMapID` request context.

Additional live Blizzard exports were reviewed 2026-10-09; live links identify the reviewed branch rather than a pinned revision:

- [Quest-line documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLineInfoDocumentation.lua): `GetQuestLineInfo(questID, uiMapID, false)` accepts an optional map context; returned `questLineName` is used only when `questLineID` matches the selected line. Matching map rows can also supply a name even if hidden from the chooser. `nameKnown` and `nameSourceAPI` record actual metadata provenance; an ID fallback is not a known name.
- [Quest log documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua): character completion/active/title reads, title requests, regular/world watch getters and quest/watch/task/data events.
- [Supertracking documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SuperTrackManagerDocumentation.lua), [shared enum](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SuperTrackManagerSharedDocumentation.lua) and [navigation frame](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.lua): quest target reads and highest-priority target type. The addon never sets navigation.
- [Blizzard bonus-objective tracker](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_BonusObjectiveTracker.lua): `GetTasksTable()` IDs and `GetTaskInfo(questID)` area state/task title used by native world/bonus objectives. Successful in-area state supplies the activity signal; a map pin alone does not establish player proximity.

Only documented facts/API semantics are used. No other addon's implementation, library or UI is copied.

## Active zone coverage and explicit quest watches in 0.4.0

Reviewed on 2026-10-09. [Blizzard QuestLog documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) supplies `GetNumQuestLogEntries`, `GetInfo`, and `GetQuestsOnMap` candidates. Only a positive quest ID currently accepted by the character can supplement zone choices. Map POIs also cover quests absent from visible log rows.

The [quest-line contract](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLineInfoDocumentation.lua) supplies `GetQuestLineInfo(questID, mapID, false)`, `startMapID` and exact `GetQuestLineQuests` membership. A candidate is admitted only when the queried accepted quest occurs in that supplied list and the start or destination map normalizes to the current zone. Its source API is `C_QuestLine.GetQuestLineInfo`; no map suggestion or NPC offer is inferred. Existing source URLs remain attached to runtime records. [Blizzard QuestMapFrame](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua) documents the destination-versus-waypoint use of `GetQuestUiMapID(questID, true)`. Data/POI/log events retry reads through the existing timer, without a global scan or quest database.

The same [QuestLog documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) defines `AddQuestWatch(questID)` returning `wasWatched`, and regular/world/task/watch getters. [Blizzard's track-quest menu](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua) checks `Constants.QuestWatchConsts.MAX_QUEST_WATCHES`. The addon uses those semantics only after an explicit row left click. It does not call world-watch, watch-removal or navigation setters. A historical completed flag alone does not reject a currently accepted repeatable iteration.

[Blizzard timer documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua) supplies `C_Timer.NewTimer`. One cancellable timer serves both refresh and banner-expiry deadlines. The banner reads the native frame's visible/fade duration when available and doubles their sum; five seconds is an addon fallback when those reads fail, not a claimed client default.

The user's reported Trauerhöhe omission is client evidence of an incomplete chooser, not a new curated membership fact. The coverage change handles the filtered-active-line case; it does not establish a complete catalogue or confirm the exact client's response. See the client checklist for the pending retest.

## Uncertainty boundaries

A returned list establishes membership and display order, not a complete prerequisite graph, optionality or global catalogue. Nodes mark requirements and optionality unknown. No dependency edges, route coordinates or mandatory classifications are created. Account-completed map metadata does not establish this character's completion.

Lookup first checks session-loaded membership, then requires the queried quest ID in the supplied association's quest list. Missing associations remain unresolved. The quest/current map may be a request context without proving the quest's location. Unlabelled `QUESTLINE_UPDATE` events can arrive out of order; later events may still resolve a query. Synchronous replies are reread; editing/selection/close cancels it.

Warnings compare activities only with the selected supplied list. They do not prove a quest lacks an external prerequisite role or is safe to abandon. Area-task warnings cover quest-backed world/bonus objectives; scenario-only bonus steps without quest IDs cannot be compared to quest membership. Missing APIs/data never justify invented IDs or negative game-API arguments.

NPC AVAILABLE comes only from actual current gossip or guarded NPC details. A map candidate is explicitly uncertain. Empty startup has no quest nodes and performs no synthetic quest query.

## Removed pack and test provenance

Trauerhöhe, Merrix und Stahlader and Zerbrochene Werkzeuge were removed at the user's request on 2026-10-09. They are not runtime defaults or lookup fallbacks. Earlier source history remains in the changelog; it no longer describes shipped data.

Offline tests use simulated map/line associations and sourced real quest-ID examples such as [78743](https://www.wowhead.com/quest=78743/before-i-depart), [78744](https://www.wowhead.com/quest=78744), [78745](https://www.wowhead.com/quest=78745), [78562](https://www.wowhead.com/quest=78562/discarded-and-broken) and [78563](https://www.wowhead.com/quest=78563). Fixture membership and names are not gameplay facts and are not packaged. Invalid/nonfinite IDs never reach game APIs.

Actual client observations and remaining acceptance checks are recorded separately in [IN_GAME_TEST.md](IN_GAME_TEST.md).
