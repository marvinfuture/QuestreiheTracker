# Design decisions

Questreihen Tracker displays one selected runtime quest list. It ships no story catalogue, prerequisite graph, demo nodes or fixed quest IDs. All lists and character progress come from the WoW client.

## Data flow

`WoW events → one coalescing timer → session lists + game snapshot → pure Model.Evaluate → native UI`

Core owns preference migration, selection, explicit row-click dispatch and events. WoW owns progress, NPC offers, activity warnings and guarded regular quest watches. WoWQuestLines owns map requests, current-zone active associations and session caches; WoWQuestLookup verifies quest-to-line membership. LiveData converts actual positive IDs into sourced records. Model has no game/UI dependency.

Membership and display order do not establish prerequisites, optionality or a complete storyline. Progress counts supplied entries; account-completed map metadata does not change character completion. Unknown data never creates a synthetic quest or default story.

## Native interface

The tracker contains title/selection, a compact remove button, navigation-quest lookup, progress/count, an uncertainty notice and scrollable quest rows. The selection shows the supplied localized line name, with a full-name tooltip and an ID fallback only when the client has no name. The default is 360 × 500, minimum 320 × 300, with an 82% opaque background. Rows show progress only; left click observes an accepted regular quest, and right click opens an addon-owned copy-link dialog.

The selector contains navigation-quest lookup, manual ID lookup and current-zone lines. Minimap left click toggles the tracker; right click opens selection. Tracker, selector and copy-link dialog move independently. The minimap samples the cursor only during user dragging.

Schema 6 saves selected map/line IDs, tracker geometry, selector/link positions and minimap angle. Removed display/warning/automation switches are discarded. Legacy static selections become empty. Runtime selections restore from the game; no quest list, title or completion is saved. The renamed install uses a new SavedVariables identity; it does not silently import the former addon's file.

Removing a line clears selection, pending lookup, offers and warning state. Late replies can update session caches but cannot select a line. Window geometry and Blizzard's quest state remain unchanged. Runtime lists remain discoverable for subsequent selection.

## Progress and warning contract

Progress status is COMPLETED, ACTIVE, NOT_ACCEPTED or UNKNOWN. Only confirmed false completion and false log membership establish NOT_ACCEPTED. Hand-in is required for completion. AVAILABLE requires an actual current NPC offer. A map suggestion remains explicitly uncertain.

Warnings compare activities with loaded supplied membership. Sources are newly accepted quests, newly watched quests, in-area world/bonus tasks and the current quest navigation target. Existing watches are a silent baseline; tasks/navigation remain detectable. Event bursts are coalesced, unchanged activities deduplicated and explicit removal re-arms them. Failed reads preserve unknown source state instead of fabricating an exit.

Warnings do not establish that a quest is unnecessary or safe to abandon. No selection or incomplete membership suppresses them. Missing title data uses a local ID label.

## Gameplay action boundary

An explicit left-click on an accepted regular member quest may call `C_QuestLog.AddQuestWatch` through the game adapter. This is the only gameplay mutation. No event or lookup invokes it. No quest acceptance, abandonment, reward, gossip selection, watch removal, navigation, waypoint or inventory mutation API is called. There is no external service or in-game library. The static API audit plus mutation traps complement executed offline tests; actual layout and taint need client testing.

A separate warning banner uses twice the native error display duration. One cancellable timer handles coalesced events and warning expiry, with the earlier deadline taking priority.
