# In-game test checklist — 0.4.0

**New build: client tests pending.** Offline results are separate from client behavior. Record date, client version/build/interface, character, zone, UI scale and Lua/taint output with the observed results.

## Existing evidence

2026-10-09, earlier static-data build: user evidence showed the tracker rendering quest rows/selection, with settings and the other-quests button still present. A screenshot showed a world-quest entry and local warnings for a quest outside the selected Trauerhöhe list. The user reported the proximity warning was intended and requested equivalent bonus/watch/navigation warnings.

2026-10-09, user test of 0.3.0: the supplied screenshot shows the simplified tracker and selector without settings/other-quests controls, localized quest titles and a 0/17 progress count. The selected header still displays the numeric fallback **Questlinie 5606**. The user requested removal, a real line name and consistent **Questreihe** labels.

Screenshots establish those visible observations only. They do not validate warning events, reload/cancellation behavior or taint. The 0.4.0 changes still require client testing.

2026-10-09, user observation before this change: while playing Trauerhöhe on the Isle of Dorn, current-zone selection displayed only Mord an einer Königin and Wichtige Quests. No actual post-change client result is available.

## Install and initial selection

1. Remove the former addon folder and install only `QuestreihenTracker` from the new package. The changed install identity starts with fresh addon preferences. Confirm `QuestData.lua` is absent. Compare the fourth `GetBuildInfo()` result with TOC 120100, enable Lua errors and `/reload`.
2. With fresh preferences or an old curated selection, open `/qrt`. Expect **Keine Questreihe ausgewählt** and no installed stories. Empty/missing zone data must remain empty/loading, not select an invented story.
3. Choose a supplied current-zone line. Confirm actual quest membership and localized titles. Complete objectives without hand-in: status remains **Angenommen**. Handed-in quests show **Abgeschlossen**.
4. Leave the zone and `/reload`. A saved runtime selection should reload its map/line from the game. No saved progress or titles may override current character state.

## Removal and line names

1. With a loaded line, click **Entfernen**. Expect an empty list, no selected map/line after `/reload` and a disabled remove button. Confirm window size/positions, minimap angle and all Blizzard quests/watches/navigation remain unchanged.
2. Repeat while a saved line is loading and while a lookup for another quest is pending. Queued or late replies must not restore the removed selection. Choose a line again normally afterward.
3. Select the previously tested line 5606. Record whether Blizzard now supplies its localized line name. Test through zone selection, tracked/manual lookup, outside the zone and after `/reload`; a delayed matching name should replace the ID fallback on a normal data refresh. A line with no supplied name must retain **Questreihe &lt;ID&gt;** without inventing a title.
4. Check long names at the minimum window width. Hover shows the full name; selector and **Entfernen** remain clickable. Title, header, selector, chat prefix, warnings and minimap tooltip use **Questreihe**.

## Warnings

Use normal gameplay. Only an explicit quest-row left click may add a watch; no automatic acceptance, abandonment or navigation change is permitted.

1. With a loaded selected line, enter an unrelated world-quest area. Expect the existing chat/on-screen warning. Stay in the area and progress it: unchanged activity must not repeatedly warn. Leave/re-enter: a new warning is allowed.
2. Repeat with an actual open-world bonus objective. Record its quest ID, task/area state and displayed title. Scenario-only bonus steps without quest IDs are outside the quest-membership comparison.
3. In the quest log, right click a different quest → **Quest beobachten**. Expect a warning. Remove/re-add the watch and test rapid toggles. Existing watches at login should not produce a flood.
4. Select an unrelated quest for the navigation arrow using Blizzard's side tracker. Expect a warning. Choose another target, then return. A nonquest waypoint/map pin with a retained quest ID must not produce a quest-navigation warning.
5. A selected-list quest must never warn. No selected list or a loading list must suppress classification. Warning wording compares the supplied membership only.
6. Observe a normal accepted unrelated quest: warn once current log membership is confirmed. Repeated/delayed acceptance events must not spam. Watch/task/navigation events in the same refresh should not duplicate the same quest.
7. Check temporary missing title data uses an ID fallback, delayed data does not imply exit/re-entry, and removal/turn-in/selection changes cancel stale pending warnings.
8. Time the prominent banner against the native error message: it should stay twice as long, remain readable with long German titles and stay visible when the tracker is hidden. Trigger a log update during display and verify prompt refresh, then expiry without repeated warnings. Changing/removing the selection clears the old banner.

## Left-click observing and current-zone coverage

1. Left-click an accepted regular member quest. It should appear in Blizzard's watched list just as with **Quest beobachten** in the quest log. A second click keeps it watched. Confirm selection/navigation/waypoint remain unchanged by the addon.
2. Test unaccepted/handed-in quests, missing data, world quests/bonus tasks and a full Blizzard watch list. Expect a German explanation and no unwanted watch. Test an accepted repeatable quest and a quest ready for hand-in. Check out/in combat with Lua/taint reporting enabled.
3. On the Isle of Dorn, keep an actual Trauerhöhe quest accepted. Open selection and **Aktualisieren**. Record the current quest ID, client line association, map context and whether Trauerhöhe now appears alongside available candidates. Also try collapsed questlog headers and delayed quest-map updates. The chooser is not a promise of every zone line.
4. Move to another zone. Unrelated active log entries must not appear merely because they are accepted. Membership remains client-supplied; no static Trauerhöhe fallback may be installed.

## Lookup and compact UI

1. Use **Verfolgte Quest** in both main window and selection. It reads the current quest navigation target; manual ID with **Anzeigen** and Enter produces the same verified line when Blizzard supplies it. Test without a navigation quest and while away from its zone; errors must be visible in the main window too.
2. Test invalid IDs and a real quest with no supplied association. Keep the previous view and show a German explanation. During delayed lookup, edit input, choose another line or close selection; late data must not overwrite that choice.
3. Check late/reordered map results and explicit retry after failed title data. There must be no idle polling or recurring request spam.
4. Confirm the background is partly transparent and the rows contain only quest title and progress status, without the availability suffix. The title/minimap/chat/addon list use **Questreihen Tracker** and selection labels use **Questreihe**.
5. Resize at minimum/default size, long German titles, differing UI scales and in/out of combat. Inspect scrollbar/resize-grip overlap. Drag tracker/selector/copy dialog; text selection and buttons remain usable.
6. Test minimap left-click toggle, right-click selector and drag without accidental click. Verify saved window/launcher positions after close, reload and restart. Default size is 360 × 500, minimum 320 × 300; check two-line German titles, status and scroll area.
7. Run `/qrt reset`: clear selection and restore compact defaults/positions. Quest watches, selected quest, waypoint and inventory must stay unchanged.
8. Check actual Lua errors and taint separately. Record results before requesting the Git push.
