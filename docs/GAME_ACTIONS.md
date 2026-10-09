# Gameplay action boundary

Version 0.4.1 displays one runtime quest list, character progress and local warnings. An explicit left-click on an accepted regular member quest can add its Blizzard quest watch and select it as the active quest navigation target. This user click is the sole gameplay-action entry point.

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

Requesting missing client data does not accept/complete a quest. The addon never uses acceptance/abandon/hand-in/reward APIs, gossip selection, watch removal, world-quest-watch or nonquest supertrack/waypoint setters, inventory operations, chat-send APIs, macros or CVars.

## Explicit regular quest watches and navigation

`UI.Row` dispatches a left click to `Core.TrackQuest`, which verifies current selected membership and calls `WoW.WatchQuest`. The adapter validates the positive ID and active regular quest. It reads existing watches and, when a new watch is needed, checks the client-supplied watch limit before its one direct `C_QuestLog.AddQuestWatch(questID)` call. After confirming the watch it calls `C_SuperTrack.SetSuperTrackedQuestID(questID)` and verifies the active quest target through the guarded getter. The setter's normal nil return is not a failure signal.

Already watched quests remain watched and can be selected as the navigation target again. Missing reads/APIs, errors and refused or unconfirmed changes produce a German explanation. A navigation failure does not remove a successfully added watch. Current repeatable iterations can be tracked despite historical completion.

No event, refresh, lookup, right click, minimap action, removal or reset invokes this action. Explicit row clicks can change quest navigation; no quest-log selection or nonquest waypoint setter is called. No automatic acceptance or abandonment exists; normal Blizzard confirmations remain authoritative.

## Addon-owned state

The tracker, selector and copy-link dialog can move; the tracker can resize. The minimap launcher can move during a user drag. Its temporary cursor handler is removed after drag/hide.

Lookup chooses only the addon's displayed list. Right click shows an addon-owned URL copy field. Chat/on-screen warnings are local and do not send messages to other players. The sole on-screen activity warning is the addon-owned banner; the addon does not duplicate it with `UIErrorsFrame:AddMessage`. Banner expiry shares the event timer and does not change Blizzard's error-frame settings. **Chatwarnung: An/Aus** controls only local activity-warning messages in chat; the banner and warning deduplication stay active.

**Entfernen** clears addon selection and pending lookup, including the saved selection. It neither abandons quests nor changes quest watches, selected quests, navigation or waypoints. Runtime name recovery only reads matching client metadata.

Settings and other-quests views have no frames, controls or implementation. Removed legacy flags are discarded. SavedVariables holds only selection IDs, geometry/launcher preferences and the default-on `chatWarnings` boolean; no quest/title/progress data is stored. **Entfernen** preserves the chat choice. Reset affects only addon state and restores chat warnings to **An**.

## Verification limits

`python scripts/test.py` combines a static API allowlist with executed Lua 5.1 tests. The watch and quest-navigation mutations are permitted only as direct calls inside the reviewed adapter. Forbidden-action traps record attempted game changes before raising, so pcall cannot hide them; expected explicit watches and quest-navigation changes have separate counters. Tests cover explicit-click validation/failure/reselection, restoration, zone coverage, lookup, UI controls, NPC offers, activity warnings and timer deadlines. The 0.4.1 checks also cover chat preference persistence, independent banner output and absence of native-frame duplication.

These checks do not prove actual client API behavior, layout or taint. Record those results separately in [IN_GAME_TEST.md](IN_GAME_TEST.md). The user explicitly authorized the 0.4.1 push and release while the client retest remains pending.
