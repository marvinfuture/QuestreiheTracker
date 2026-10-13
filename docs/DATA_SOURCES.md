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
- [Supertracking documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SuperTrackManagerDocumentation.lua), [shared enum](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SuperTrackManagerSharedDocumentation.lua) and [navigation frame](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_QuestNavigation/SuperTrackedFrame.lua): quest target reads and highest-priority target type. From 0.4.1, an explicit accepted-regular-quest row click may also set that quest's navigation target; events and lookup only read it.
- [Blizzard bonus-objective tracker](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_ObjectiveTracker/Blizzard_BonusObjectiveTracker.lua): `GetTasksTable()` IDs and `GetTaskInfo(questID)` area state/task title used by native world/bonus objectives. Successful in-area state supplies the activity signal; a map pin alone does not establish player proximity.

Only documented facts/API semantics are used. No other addon's implementation, library or UI is copied.

## Active zone coverage and explicit quest watches in 0.4.0

Reviewed on 2026-10-09. [Blizzard QuestLog documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) supplies `GetNumQuestLogEntries`, `GetInfo`, and `GetQuestsOnMap` candidates. Only a positive quest ID currently accepted by the character can supplement zone choices. Map POIs also cover quests absent from visible log rows.

The [quest-line contract](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLineInfoDocumentation.lua) supplies `GetQuestLineInfo(questID, mapID, false)`, `startMapID` and exact `GetQuestLineQuests` membership. A candidate is admitted only when the queried accepted quest occurs in that supplied list and the start or destination map normalizes to the current zone. Its source API is `C_QuestLine.GetQuestLineInfo`; no map suggestion or NPC offer is inferred. Existing source URLs remain attached to runtime records. [Blizzard QuestMapFrame](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua) documents the destination-versus-waypoint use of `GetQuestUiMapID(questID, true)`. Data/POI/log events retry reads through the existing timer, without a global scan or quest database.

The same [QuestLog documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua) defines `AddQuestWatch(questID)` returning `wasWatched`, and regular/world/task/watch getters. [Blizzard's track-quest menu](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua) checks `Constants.QuestWatchConsts.MAX_QUEST_WATCHES`. The addon uses those semantics only after an explicit row left click. Version 0.4.0 did not call a navigation setter; 0.4.1 adds only the explicit quest-target action described below. World-watch and watch-removal setters remain unused. A historical completed flag alone does not reject a currently accepted repeatable iteration.

[Blizzard timer documentation](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua) supplies `C_Timer.NewTimer`. One cancellable timer serves both refresh and banner-expiry deadlines. The banner reads the native frame's visible/fade duration when available and doubles their sum; five seconds is an addon fallback when those reads fail, not a claimed client default.

The user's reported Trauerhöhe omission is client evidence of an incomplete chooser, not a new curated membership fact. The coverage change handles the filtered-active-line case; it does not establish a complete catalogue or confirm the exact client's response. See the client checklist for the pending retest.

## Explicit navigation and warning-output fixes in 0.4.1

Reviewed on 2026-10-09 against Blizzard's generated API documentation and native UI source on the live export branch. No quest facts or bundled data were added.

- [QuestLog API contract](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua): regular `AddQuestWatch(questID)` takes only a quest ID and returns boolean `wasWatched`. It remains restricted to an explicit click on a currently accepted regular member quest.
- [SuperTrack API contract](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SuperTrackManagerDocumentation.lua): `SetSuperTrackedQuestID(questID)` has no documented return value; the namespace also declares `SUPER_TRACKING_CHANGED`. The addon confirms the target through its guarded getter rather than interpreting a normal nil setter return as failure. Both APIs mark secret arguments `AllowedWhenUntainted`; ordinary validated positive IDs and actual client taint checks remain required.
- [Blizzard POI click handler](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_POIButton/POIButton.lua): native quest clicking adds a watch if absent, then sets the quest navigation target even if already watched. This confirms that observing and actively navigating are separate operations; the addon uses those API semantics without copying the UI implementation. No world-watch, watch-removal or nonquest waypoint setter is introduced.

The user's 0.4.0 screenshot establishes visible duplicate warning output, not a new quest-membership fact. In 0.4.1 the addon-owned banner is retained and its `UIErrorsFrame:AddMessage` duplicate is removed. A new default-on saved chat preference affects only local activity-warning output; banner delivery, warning deduplication and existing data sources are unchanged. Successful offline stubs cannot establish real client navigation, layout or taint behavior.

## Name search and achievement information in 0.5.0

Reviewed on 2026-10-11 against the following pinned Blizzard export sources at commit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [Native achievement UI](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_AchievementUI/Mainline/Blizzard_AchievementUI.lua): category enumeration through `GetCategoryList`, `GetCategoryNumAchievements` and `GetAchievementInfo(categoryID, index)`; criteria reads through `GetAchievementNumCriteria` / `GetAchievementCriteriaInfo`; linked achievement criteria use their typed asset ID as an achievement ID. Names and completion are supplied by the client.
- [Blizzard constants](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_FrameXMLBase/Constants.lua): `CRITERIA_TYPE_ACHIEVEMENT = 8` identifies linked subachievements. Only that established type is traversed, with duplicate/cycle protection.
- [Achievement API documentation](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/AchievementInfoDocumentation.lua): achievement-list and criteria update events support refreshing session discovery and reading current completion for matching information.

The initial 0.5.0 search combined known client-supplied line names from the session cache with achievement and criteria name matches. A line result is selectable only when its client-supplied membership is loaded and nonempty. Achievement/criteria matches show parent context and completion as nonselectable information. Finding a matching achievement title or criterion does not establish that it belongs to a line, names all its quests or describes a complete prerequisite graph.

No reliable primary-source mapping from other criterion asset types to quest IDs was established. The implementation therefore never treats an arbitrary criterion asset as a quest ID or probes it through a quest API. Linked achievement IDs remain achievement IDs. No fixed real quest IDs, achievement IDs, Trauerhöhe facts or name-to-membership table are added.

Discovery is session-only and bounded: each active-search index continuation has budgets of 100 achievement reads, 500 criteria reads and 100 categories, with ceilings of 6,000 achievements and 30,000 criteria; at most 200 sorted hits are returned. Missing APIs/data or limits yield partial/unsupported results. Returned matching completion is read again through additional guarded calls rather than saved as progress. A matching achievement title also exposes its direct criteria. The finite scan stops after completion or cancellation, and no new permanent polling timer is introduced. These limits and the supplied map subset prevent a claim of complete global coverage.

The independent screen-warning switch in 0.5.0 adds no data source or gameplay action. It suppresses only the addon-owned banner; chat output, activity detection and deduplication retain their independent behavior.

## Runtime quest-line name discovery in 0.5.2

Reviewed on 2026-10-13 against the same pinned Blizzard export at commit `09b9db7948abc9b9648dedaab51eb0cf3ee67b31`:

- [Map API contract](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua): `GetFallbackWorldMapID()` supplies a runtime root candidate; `GetMapInfo(uiMapID)` supplies `mapType` and `parentMapID`; `GetMapChildrenInfo(uiMapID, mapType, allDescendants)` supplies typed descendants and may return nothing. The addon queries zone descendants using `Enum.UIMapType.Zone`, without installing fixed map IDs.
- [Quest-line API contract](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLineInfoDocumentation.lua): discovered maps feed existing map requests and reads. A `questLineName` is usable only as metadata for its supplied line ID; nonempty `GetQuestLineQuests` membership establishes the list displayed by name and member-ID lookup.
- [Quest-log API contract](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLogDocumentation.lua): accepted quest-log entries supply additional positive quest seeds. Name discovery verifies their line association and returned membership across zones rather than restricting them to the current-zone chooser.

`WoWNameDiscovery.lua` queues up to 400 current/cache/tree maps, supplemented by contexts from up to 100 accepted quests collected from at most 1,000 log entries. Each continuation advances at most six queued maps, twelve pending map reads and four quest candidates. Missing map/quest data waits at most five seconds or fifty reads; a 250-continuation aggregate cutoff ends unresolved work as partial. In 0.5.2, client-event rechecks of completed discovery were bounded and did not force requests without an explicit `requestRequired = true` update. Version 0.6.0 releases terminal discovery/index state; ordinary events update only existing retained result contexts through live membership/name/completion reads, bounded by the 200-result limit. They do not begin a fresh world scan; a new explicit search starts discovery again. These are addon limits; API support, map descendants, available lines and accepted seeds cannot guarantee every quest line. Runtime records keep the existing quest-line source URL/API provenance; no names, membership or completion are saved.

After finite discovery settles, a unique exact supplied line-name match with loaded membership can open the full list. Several exact line IDs, partial-name matches or matching incomplete membership require explicit choice or more data. This resolves a client-supplied association; it does not infer a line from an achievement criterion or a member quest's title. The user's **Trauerhöhe** / **Zur Trauerhöhe** example is a requested client acceptance case, not a newly sourced bundled quest fact. Actual-client coverage remains untested, and separate quest lines are not combined into a prerequisite story.

## Native controls and grouped zone browsing in 0.6.0

Reviewed on 2026-10-13 against Blizzard's UI export on the live branch. These references establish native widget/API contracts, not new quest facts:

- [Native close buttons](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml): `UIPanelCloseButton` supplies Blizzard's red X textures. Own click callbacks preserve the addon's main-window deliberate-close behavior and auxiliary dismissal.
- [Native icon button](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Shared/Button/IconButtonTemplate.xml): `SquareIconButtonTemplate` supplies the native gear-button surround and `Icon` region. The addon configures its existing `common-dropdown-a-button-settings-shadowless` gear atlas and opens its own settings panel.
- [Spinner template](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Spinner.xml) and [spinner mixin](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_SharedXML/Spinner.lua): `SpinnerTemplate` uses an animation group whose show/hide handlers start and stop the ring/sparks rotation. The addon does not implement a permanent animation update loop.
- [Blizzard menu implementation guide](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_Menu/11_0_0_MenuImplementationGuide.lua): `CreateFrame("DropdownButton", ..., "WowStyle1DropdownTemplate")`, `SetupMenu`, radio descriptions, nested button descriptions, menu regeneration and scroll mode provide the native zone selector. The external zone-name filter regenerates choices without requesting their quest lists.
- [Map API contract](https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/MapDocumentation.lua): runtime roots, typed zone descendants, parent IDs and names supply zone choices and continent grouping without installing map IDs. City, micro/subzone and instance map types are not treated indiscriminately as zones. An available zone choice does not establish complete line coverage for that map.

**Suchcache leeren** and automatic pruning free only unused addon-owned runtime data while preserving selected membership and records needed by current query/results/current or browsed zone. They do not invoke a Blizzard client-cache flush, quest action or external service. Later reads/requests rebuild data as needed. Cache release adds no static membership/name/achievement data source; cancelled lookups remain cancelled after delayed events.

`WoWZoneCatalog.lua` caches map names/group metadata only and has defensive caps of 10,000 zones, 20,000 supplied entries and 16 parent links. These menu caps are separate from the existing 400-map name-discovery request limit. Missing APIs, hierarchy gaps or truncation remain partial/error metadata rather than proof of a complete world catalogue. Cache release can rebuild this name-only catalogue without eagerly requesting all zone quest lists.

Search success requires a selectable loaded client line. Achievement/criteria-only information remains unresolved and never establishes line membership. The user requested a single inline unsuccessful-search message rather than separate typo/data-failure explanations; this wording is presentation, not proof that a supplied map catalogue or search was complete. Actual widget layout, client API availability and taint remain separate checks.

## Uncertainty boundaries

A returned list establishes membership and display order, not a complete prerequisite graph, optionality or global catalogue. Nodes mark requirements and optionality unknown. No dependency edges, route coordinates or mandatory classifications are created. Account-completed map metadata does not establish this character's completion.

Lookup first checks session-loaded membership, then requires the queried quest ID in the supplied association's quest list. Missing associations remain unresolved. The quest/current map may be a request context without proving the quest's location. Unlabelled `QUESTLINE_UPDATE` events can arrive out of order; later events may still resolve a query. Synchronous replies are reread; editing/selection/close cancels it.

Warnings compare activities only with the selected supplied list. They do not prove a quest lacks an external prerequisite role or is safe to abandon. Area-task warnings cover quest-backed world/bonus objectives; scenario-only bonus steps without quest IDs cannot be compared to quest membership. Missing APIs/data never justify invented IDs or negative game-API arguments.

NPC AVAILABLE comes only from actual current gossip or guarded NPC details. A map candidate is explicitly uncertain. Empty startup has no quest nodes and performs no synthetic quest query.

## Removed pack and test provenance

Trauerhöhe, Merrix und Stahlader and Zerbrochene Werkzeuge were removed at the user's request on 2026-10-09. They are not runtime defaults or lookup fallbacks. Earlier source history remains in the changelog; it no longer describes shipped data.

Offline tests use simulated map/line associations and sourced real quest-ID examples such as [78743](https://www.wowhead.com/quest=78743/before-i-depart), [78744](https://www.wowhead.com/quest=78744), [78745](https://www.wowhead.com/quest=78745), [78562](https://www.wowhead.com/quest=78562/discarded-and-broken) and [78563](https://www.wowhead.com/quest=78563). Fixture membership and names are not gameplay facts and are not packaged. Invalid/nonfinite IDs never reach game APIs.

Actual client observations and remaining acceptance checks are recorded separately in [IN_GAME_TEST.md](IN_GAME_TEST.md).
