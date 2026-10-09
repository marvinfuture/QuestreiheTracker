# Project instructions

Build a small WoW Retail addon. Keep live data, pure model, game adapter and native UI separate.
Use one addon namespace. English code/comments; German user-facing strings in Locale.lua.
Do not copy another addon's implementation. Data facts must carry source references.
Do not invent real quest IDs or treat screenshot chapter names as complete prerequisite facts.
Negative IDs are exclusively synthetic demo nodes; never pass them to game APIs.
AVAILABLE requires an actual current NPC offer. Inferred next steps are explicitly uncertain.
Save preferences only; derive quest and account achievement progress from the game.
Preserve opt-in regular-NPC acceptance guards and manual Blizzard quest-abandon confirmation.
Use events plus a single coalescing timer; no permanent OnUpdate polling.
Run python scripts/test.py after meaningful code/data changes. Run python scripts/package.py before delivery.
Keep TOC/Core versions consistent. Update docs/DATA_SOURCES.md with data changes.
Document actual client tests separately; offline stubs do not prove in-game layout or taint behavior.
Do not publish, push, create a remote or a release without the user's explicit instruction.
