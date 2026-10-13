# Design decisions

Questreihen Tracker displays one selected runtime quest list. It ships no story catalogue, prerequisite graph, demo nodes or fixed quest IDs. All lists and character progress come from the WoW client.

## Data flow

`WoW events → one coalescing timer → session lists + game snapshot → pure Model.Evaluate → native UI`

Core owns preference migration, selection, explicit row-click dispatch and events. WoW owns progress, NPC offers, activity warnings and guarded regular quest watches/navigation. WoWQuestLines owns map requests, current-zone active associations and session caches; WoWQuestLookup verifies quest-to-line membership. WoWNameDiscovery discovers runtime zone lines from the client map hierarchy and accepted quest-log associations across zones. WoWNameSearch matches those names and reads achievement/criteria information in bounded session-only batches. LiveData converts actual positive IDs into sourced records. Model has no game/UI dependency.

Membership and display order do not establish prerequisites, optionality or a complete storyline. Progress counts supplied entries; account-completed map metadata does not change character completion. Unknown data never creates a synthetic quest or default story.

## Native interface

The tracker contains title/selection, a compact remove button, navigation-quest lookup, a settings gear, progress/count, an uncertainty notice and scrollable quest rows. The gear opens independent chat/screen warning switches and **Fenster geöffnet lassen**. The selection shows the supplied localized line name, with a full-name tooltip and an ID fallback only when the client has no name. The default is 360 × 500, minimum 320 × 300, with an 82% opaque background. The main title is larger and underlined; thin section rules and quest dividers organize the view. Smaller status text sits directly below each title while existing green/yellow quest colors remain. Left click watches and navigates to an accepted regular quest; right click opens an addon-owned copy-link dialog.

The selector contains navigation-quest lookup, manual ID lookup, name search and current-zone lines. Submitted name search replaces the zone list until **Zur Zonenliste** is selected. Only supplied runtime lines with loaded, nonempty membership are selectable. Achievement/criteria names and documented subachievement links provide information without establishing quest membership or prerequisites. Minimap left click toggles the tracker; right click opens selection. Tracker, selector and copy-link dialog move independently. The minimap samples the cursor only during user dragging.

Schema 9 saves selected map/line IDs, tracker geometry, selector/link/settings positions, minimap angle, independent default-on `chatWarnings` / `screenWarnings` / `keepWindowOpen` booleans and the manual `windowOpen` choice, initially false. Removed legacy display/automation switches are discarded. Legacy static selections become empty. Runtime selections restore from the game; no quest list, title, achievement index or completion is saved. The identity change in 0.4.0 used new SavedVariables; later upgrades retain preferences within that identity.

With keep-open enabled, the main window retains the user's explicit opening choice across incidental game/UI hides and reload. It stays outside ordinary Escape closing while this setting is enabled. X, slash-toggle and minimap-toggle close it deliberately and save that choice; no game event can reopen a deliberately closed tracker. With the setting disabled, normal closing is allowed and reload does not restore an open window. Only the main window follows this policy; settings and auxiliary dialogs remain dismissible.

Automatic scrolling targets the latest newly accepted or explicitly clicked selected-line quest while still active, otherwise the first active quest in supplied order. It uses measured row positions/heights and the actual viewport, including wrapped titles. Each row refresh/reflow brings an offscreen active target into view; if the row is already visible, the current position is retained. Manual scrolling remains usable between refreshes. No active member means no fabricated scrolling target. The feature changes only addon UI state and does not call watch/navigation setters.

Quest-ID lookup displays the full supplied membership of a verified line containing that ID, including when the queried quest is not the first member. Name search resolves that same membership from the supplied line name. After finite discovery settles, a unique exact full-name match with loaded membership opens automatically. Partial-name matches and several exact line IDs require explicit selection; an incomplete matching line blocks automatic selection. A quest title such as the user's **Zur Trauerhöhe** is not an inferred alias for **Trauerhöhe**. Achievement information does not establish a line association.

Discovery reads client-supplied zone descendants and accepted quest seeds in bounded batches, without a fixed map/story catalogue or arbitrary achievement-asset probes. Search state, names, membership and progress remain runtime-only. Cancelling or superseding a search prevents late replies from replacing the user's choice. Supplied lists can remain incomplete or unavailable, so actual Trauerhöhe coverage and client behavior require testing.

Removing a line clears selection, pending lookup, offers and warning state. Late replies can update session caches but cannot select a line. Window geometry and Blizzard's quest state remain unchanged. Runtime lists remain discoverable for subsequent selection.

Selection removal retains the three settings and opening choice; `/qrt reset` restores defaults and closes the tracker. Switching screen warnings off immediately clears a visible box. Changing either warning switch does not replay old activity.

## Progress and warning contract

Progress status is COMPLETED, ACTIVE, NOT_ACCEPTED or UNKNOWN. Only confirmed false completion and false log membership establish NOT_ACCEPTED. Hand-in is required for completion. AVAILABLE requires an actual current NPC offer. A map suggestion remains explicitly uncertain.

Warnings compare activities with loaded supplied membership. Sources are newly accepted quests, newly watched quests, in-area world/bonus tasks and the current quest navigation target. Existing watches are a silent baseline; tasks/navigation remain detectable. Event bursts are coalesced, unchanged activities deduplicated and explicit removal re-arms them. Failed reads preserve unknown source state instead of fabricating an exit.

Warnings do not establish that a quest is unnecessary or safe to abandon. No selection or incomplete membership suppresses them. Missing title data uses a local ID label.

## Gameplay action boundary

An explicit left-click on an accepted regular member quest may call `C_QuestLog.AddQuestWatch` when needed and `C_SuperTrack.SetSuperTrackedQuestID` through the game adapter. This click is the only gameplay-action entry point; already watched quests can be selected for navigation again. No event or lookup invokes these setters. No quest acceptance, abandonment, reward, gossip selection, watch removal, nonquest waypoint or inventory mutation API is called. There is no external service or in-game library. The static API audit plus mutation traps complement executed offline tests; actual layout and taint need client testing.

A separate enabled warning banner uses twice the native error display duration. One cancellable timer handles coalesced events, warning expiry and finite active-search batches, with the earlier deadline taking priority. No permanent quest or achievement polling is added.
