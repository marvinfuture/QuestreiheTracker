# Changelog

## 0.4.0 — 2026-10-09

- Added explicit left-click observing for accepted regular quests through Blizzard's quest-watch API, with membership/ID/kind/limit checks and local failure messages. Repeated clicks keep existing watches; navigation is not set.
- Made the background partly transparent, narrowed the tracker to 360 × 500 (minimum 320 × 300), removed availability suffixes from status rows, and allowed two-line titles.
- Renamed the product to Questreihen Tracker and updated install folder, TOC, SavedVariables, globals, assets, workspace, commands and package identity. Replacing the former install starts fresh preferences.
- Added “Verfolgte Quest” to the main window with visible lookup results.
- Supplemented current-zone available candidates with accepted log/map-POI quests, requiring verified line membership and zone relevance. Preserved candidates on transient map failures; no curated facts or complete catalogue claims were added.
- Added a prominent warning banner with twice the native error display duration and one shared cancellable timer for refresh/expiry.

Validation: offline Lua 5.1 and static API-boundary checks; actual client layout, Trauerhöhe coverage, quest watching and taint remain pending in docs/IN_GAME_TEST.md. No publishing performed.

## 0.3.1 — 2026-10-09

- Added a compact **Entfernen** button beside the selected line. It clears the display and saved selection, cancels pending lookup and prevents late replies from restoring it. Window geometry and Blizzard quests/tracking remain unchanged.
- Shows the supplied localized line name directly in the header, with a full-name tooltip. Missing names can be recovered from matching member-quest metadata, including filtered lines or failed map discovery; known names survive temporary missing data. No static names or IDs were added.
- Changed visible German terminology and the display title to **Questreihe** / **Questreihen Tracker**. Technical addon paths and SavedVariables remain compatible.

Verification: 92 offline behavioral cases, separate startup/reload checks and 37 static guard cases pass with zero attempted game mutations or invalid API IDs. Coverage includes selection/removal, delayed names, metadata matching, persistence and compact-header wiring. GitHub CI also passes. Actual 0.3.1 client removal, name availability, layout and taint checks are pending in docs/IN_GAME_TEST.md.

## 0.3.0 — 2026-10-09

- Removed the three installed stories and QuestData.lua. Quest lines, membership, names and character progress now come exclusively from the client at runtime. Fresh/legacy static selections start empty; valid runtime selections still reload from their saved map/line IDs.
- Removed settings, the other-quests view and its toggle. The smaller tracker contains selection, progress and quest rows, without duplicate start/current/next summaries. Minimap right click opens selection; movement, resizing and copy links remain.
- Extended local warnings to in-area world quests and quest-backed bonus objectives, newly watched quests and the active quest navigation target. Existing watches are silently baselined; duplicate event bursts and transient missing data do not create repeated warnings. Acceptance warnings wait for current log membership.
- Reduced saved preferences to display geometry and selection IDs; removed feature flags, unused achievement/prerequisite adapters, static defaults and obsolete strings. The former default window size migrates to the compact size while customized dimensions remain.

Verification: 81 offline behavioral cases, saved/missing-API startup checks and 37 static guard cases pass with zero attempted game mutations or invalid API IDs. Actual client layout, bonus/watch/navigation warnings and taint checks are pending in docs/IN_GAME_TEST.md. No push or release performed; the user's client test comes next.

## 0.2.4 — 2026-10-09

- Added quest-to-line lookup inside the existing selector: **Verfolgte Quest** reads Blizzard's current navigation quest; the adjacent quest-ID field supports **Anzeigen** and Enter.
- Checks exact membership in installed stories and session-loaded lines before requesting Blizzard's association and verifying the returned quest list. Missing associations remain unresolved; no quest facts, IDs or dependencies were added.
- Preserves the displayed selection during loading or failure. New input, manual line selection or closing the selector cancels pending lookup work. A successful requested lookup changes only the addon's display, with no quest-watch, navigation-target or waypoint setters.
- Handles synchronous data replies, keeps unresolved lookups eligible for late data events, cancels on ID-field editing and retries the queried ID's failed metadata on explicit resubmission.

Verification: offline regressions cover tracked/manual lookup, verified membership, delayed and synchronous replies, cancellation, failures and read-only behavior. Actual client coverage, delayed lookup responses, navigation-target reads and selector layout remain pending in docs/IN_GAME_TEST.md. Offline checks do not establish those client results.

## 0.2.3 — 2026-10-09

- Made all four addon windows movable: tracker, quest-line selector, settings and Wowhead-link copy dialog. Drag a title or unused background area; buttons and URL text selection retain their normal behavior.
- Saved each popup position in validated addon preferences, alongside the existing tracker geometry. Positions survive closing, `/reload` and the next session; `/qrt reset` restores all window positions.

Verification: client dragging, saved popup placement and copy-field interaction remain unchecked in docs/IN_GAME_TEST.md. Offline checks cannot establish real client layout or taint behavior.

## 0.2.2 — 2026-10-09

- Removed the demonstration, its data file, controls, commands and simulated game snapshots.
- Reduced installed stories to Trauerhöhe, Merrix und Stahlader and Zerbrochene Werkzeuge: 36 included real quests (35 required and one optional breadcrumb), with existing source references and dependencies preserved.
- Added a smaller inset minimap icon, native border and hover highlight. The launcher can be dragged around the minimap and remembers its angular position across sessions.
- Confined the minimap's cursor update handler to active dragging and suppressed accidental clicks on drag release. No idle polling or quest action was added.
- Preserved the display-only audit, saved resizable window and runtime Blizzard quest-line discovery; removed selections fall back to Trauerhöhe.

Verification: offline regressions cover the three-story scope, positive-ID guards, launcher geometry/drag persistence and read-only interactions. A user screenshot shows the preceding version rendering in a client; the new minimap behavior still needs client verification.

## 0.2.1 — 2026-10-09

- Audited the addon for display-only use and removed Blizzard quest-detail navigation, including its indirect selected-quest/map-focus changes.
- Removed non-functional automatic acceptance/abandonment placeholders and abandonment-oriented wording. Quest rows only display information and optionally a copyable URL.
- Added a bottom-right resize grip and adaptable window layout. Position and window dimensions are saved as addon preferences and restored across sessions; the existing minimap launcher remains available.
- Added an explicit read-only game API audit and mutation-trap regression tests covering events, UI controls, resize persistence and startup.

Verification is offline only. Real WoW resize, layout and taint checks remain pending.

## 0.2.0 — 2026-10-09

- Added current-zone quest-line discovery through Blizzard's Retail Lua API and `/qrt zone`.
- Kept the chooser small: runtime lines first, existing curated stories below, with one refresh button.
- Added event-driven quest-line and localized-title loading, loading/empty/error states and session-only API caches.
- Persisted only selected map/line IDs as preferences; a selected line survives zone changes and map filtering.
- Kept runtime list order, prerequisites and optionality explicitly uncertain. Runtime counts use returned quests; map suggestions never establish NPC availability.
- Added offline regression coverage for asynchronous loading, request coalescing, restoration, API failures, source references and demo isolation.

Verification is offline only. Actual client tests remain pending in docs/IN_GAME_TEST.md.

## 0.1.0 — 2026-10-08

- Created a native German quest-chain tracker with saved position and scale.
- Added 14 independently selectable quest stories from the initial Wowhead Earthen-guide source pack: 170 unique real quest IDs, including 158 counted common quests and 12 optional breadcrumbs or alternative variants.
- Made the main bar measure required-quest completion in the selected story on this character. The legacy 35-side-quest guide overview remains selectable, with achievement 40307 shown only as account context.
- Added a scrolling quest-line selector, with The Mourning Rise as the default story.
- Preserved parallel quest dependencies and isolated the synthetic demo graph.
- Added event-driven character status, optional-quest exclusion, start/next hints and copyable Wowhead links.
- Added explicit quest progress labels: “Abgeschlossen”, “Angenommen” and “Noch nicht angenommen”, with “Queststand unbekannt” for unresolved API data. NPC availability and prerequisites remain additional information.
- Added passive ordinary NPC hints and a non-destructive other-quest review list.
- Added an enabled-by-default warning after accepting a quest outside the selected story and its known external gates, with live-membership checks and session deduplication.
- Added an original logo and native minimap launcher: left-click toggles the tracker; right-click opens settings.
- Fixed false NPC availability for item-started quests and missing NPC contexts.
- Removed automatic acceptance; automatic acceptance and abandonment now have grey, unchecked, non-interactive settings placeholders with no saved values. Legacy `autoAccept` values are discarded on load.
- Added data validation, debug/reset/quest/demo commands and strict offline Lua 5.1 tests.
- Added VS Code workspace, local Git preparation, CI and tag-based ZIP release workflow.

Verification: nine addon files parse and initialize under Lua 5.1; 37 behavioral tests pass. Real WoW layout, minimap texture, accepted-quest warning, NPC hint and taint checks and hosted GitHub workflow execution are not yet verified.
