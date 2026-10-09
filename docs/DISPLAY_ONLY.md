# Display-only contract

Version 0.3.1 displays one runtime quest list, character progress and local warnings. No gameplay action is performed.

## Read-only API boundary

| API | Purpose |
| --- | --- |
| `C_Map.GetBestMapForUnit`, `GetMapInfo` | Current zone and parent metadata |
| `C_QuestLine.GetAvailableQuestLines`, `GetQuestLineQuests`, `GetQuestLineInfo` | Supplied lists and verified associations |
| `C_QuestLine.RequestQuestLinesForMap` | Request client cache data |
| `C_QuestLog.IsQuestFlaggedCompleted`, `IsOnQuest` | Character progress |
| `C_QuestLog.GetTitleForQuestID`, `RequestLoadQuestByID` | Read/request names |
| Regular/world watch count/index getters | Detect observed quests without changing watches |
| `C_SuperTrack.IsSuperTrackingQuest`, `GetHighestPrioritySuperTrackingType`, `GetSuperTrackedQuestID` | Read current quest navigation |
| `GetTasksTable`, `GetTaskInfo` | In-area world quests and quest-backed bonus objectives |
| `C_GossipInfo.GetAvailableQuests`, `GetQuestID`, `UnitExists` | Current NPC offer context |
| `GetQuestUiMapID`, `GetBuildInfo`, `GetCursorPosition` | Map request context, diagnostics, launcher drag |
| `C_Timer.After` | One coalescing refresh timer |

Requesting missing client data does not accept/complete a quest. The addon never uses acceptance/abandon/hand-in/reward APIs, gossip selection, quest-watch/supertrack/waypoint setters, inventory operations, chat-send APIs, macros or CVars.

## Addon-owned state

The tracker, selector and copy-link dialog can move; the tracker can resize. The minimap launcher can move during a user drag. Its temporary cursor handler is removed after drag/hide.

Lookup chooses only the addon's displayed list. Quest rows remain informational; right click shows an addon-owned URL copy field. Chat/on-screen warnings are local and do not send messages to other players.

**Entfernen** clears addon selection and pending lookup, including the saved selection. It neither abandons quests nor changes quest watches, selected quests, navigation or waypoints. Runtime name recovery only reads matching client metadata.

Settings and other-quests views have no frames, controls or implementation. Removed flags are discarded. SavedVariables holds only selection IDs and geometry/launcher preferences; no quest/title/progress data is stored. Reset affects only addon state.

## Verification limits

`python scripts/test.py` combines a static API allowlist with executed Lua 5.1 tests. Mutation traps record attempted game changes before raising, so pcall cannot hide them. Tests cover runtime restoration, lookup, movement/resize/minimap, NPC offers and activity warnings.

These checks do not prove actual client API behavior, layout or taint. Record those results in [IN_GAME_TEST.md](IN_GAME_TEST.md) before considering a push/release.
