# Roadmap

## Current: 0.3.1 compact runtime tracker

- Removed all installed stories and their static data file.
- Simplified the interface to selection, progress and quest list.
- Removed settings and the other-quests view.
- Added activity warnings for quest-backed bonus objectives, watched quests and quest navigation, alongside world quests and acceptance.
- Preserved runtime lookup, geometry persistence, a draggable launcher and display-only behavior.
- Added selection removal, runtime name recovery and consistent German “Questreihe” labels.

## Next: user's client test

Run [IN_GAME_TEST.md](docs/IN_GAME_TEST.md), especially removal/reload, delayed names and lookup, world/bonus/watch/navigation warnings and compact layout. Record actual client build, results and Lua/taint issues separately from offline tests.

Collect any remaining fixes, test them, then prepare the Git push with the user. No automatic publish, push or release.

## Later, only if requested

Consider additional runtime zone selection or improved coverage of client-supplied lists. Avoid recreating a bundled quest database, settings panel or extra list modes.
