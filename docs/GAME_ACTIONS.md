# Gameplay action boundary

Version 0.4.0 displays one runtime quest list, character progress and local warnings. An explicit left-click on an accepted regular member quest can add its Blizzard quest watch. This is the sole gameplay action.

## Read-only API boundary

| API | Purpose |
| --- | --- |
| `C_Map.GetBestMapForUnit`, `GetMapInfo` | Current zone and parent metadata |
| `C_QuestLine.GetAvailableQuestLines`, `GetQuestLineQuests`, `GetQuestLineInfo` | Supplied lists and verified associations |
| `C_QuestLine.RequestQuestLinesForMap` | Request client cache data |
| `C_QuestLog.IsQuestFlaggedCompleted`, `IsOnQuest` | Character progress |
| `C_QuestLog.GetTitleForQuestID`, `RequestLoadQuestByID` | Read/request names |
| `C_QuestLog.GetNumQuestLogEntries`, `GetInfo`, `GetQuestsOnMap` | Accepted quest candidates for current-zone line coverage |
| `C_QuestLog.IsWorldQuest`, `IsQuestTask` | Restrict left-click watching to regular quests |
| Regular/world watch count/index getters | Detect observed quests without changing watches |
| `C_SuperTrack.IsSuperTrackingQuest`, `GetHighestPrioritySuperTrackingType`, `GetSuperTrackedQuestID` | Read current quest navigation |
| `GetTasksTable`, `GetTaskInfo` | In-area world quests and quest-backed bonus objectives |
| `C_GossipInfo.GetAvailableQuests`, `GetQuestID`, `UnitExists` | Current NPC offer context |
| `GetQuestUiMapID`, `GetBuildInfo`, `GetCursorPosition` | Map request context, diagnostics, launcher drag |
| `C_Timer.NewTimer`, `GetTime` | One cancellable timer for coalesced refreshes and warning expiry |

Requesting missing client data does not accept/complete a quest. The addon never uses acceptance/abandon/hand-in/reward APIs, gossip selection, watch removal, world-quest-watch/supertrack/waypoint setters, inventory operations, chat-send APIs, macros or CVars.

## Explicit regular quest watches

`UI.Row` dispatches a left click to `Core.TrackQuest`, which verifies current selected membership and calls `WoW.WatchQuest`. The adapter validates the positive ID, active regular quest, existing watches, and the client-supplied watch limit before its one direct `C_QuestLog.AddQuestWatch(questID)` call. Missing reads, errors and refused watches produce a German explanation. Already watched quests remain watched. Current repeatable iterations can be watched despite historical completion.

No event, refresh, lookup, right click, minimap action, removal or reset invokes this action. The watch does not set the navigation target, quest-log selection or waypoint. No automatic acceptance or abandonment exists; normal Blizzard confirmations remain authoritative.

## Addon-owned state

The tracker, selector and copy-link dialog can move; the tracker can resize. The minimap launcher can move during a user drag. Its temporary cursor handler is removed after drag/hide.

Lookup chooses only the addon's displayed list. Right click shows an addon-owned URL copy field. Chat/on-screen warnings are local and do not send messages to other players. Banner expiry shares the event timer and does not change Blizzard's error-frame settings.

**Entfernen** clears addon selection and pending lookup, including the saved selection. It neither abandons quests nor changes quest watches, selected quests, navigation or waypoints. Runtime name recovery only reads matching client metadata.

Settings and other-quests views have no frames, controls or implementation. Removed flags are discarded. SavedVariables holds only selection IDs and geometry/launcher preferences; no quest/title/progress data is stored. Reset affects only addon state.

## Verification limits

`python scripts/test.py` combines a static API allowlist with executed Lua 5.1 tests. The sole watch mutation is permitted only as a direct call inside the reviewed adapter. Forbidden-action traps record attempted game changes before raising, so pcall cannot hide them; expected explicit watches have a separate counter. Tests cover watch validation/failure/idempotence, restoration, zone coverage, lookup, UI controls, NPC offers, activity warnings and timer deadlines.

These checks do not prove actual client API behavior, layout or taint. Record those results in [IN_GAME_TEST.md](IN_GAME_TEST.md) before considering a push/release.
