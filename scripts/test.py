"""Check actual addon files and behavioral assertions under Lua 5.1."""
from pathlib import Path
import re
import struct
import sys
from display_audit import audit_addon, self_test
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / ".tools"))
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    raise SystemExit("Install developer dependency: python -m pip install -r requirements-dev.txt")
lua = LuaRuntime(unpack_returned_tuples=True)
assert lua.eval("_VERSION") == "Lua 5.1"
lua.execute((root / "tests" / "wow_stubs.lua").read_text(encoding="utf-8"))
baseline = set(lua.globals().keys())
namespace = lua.table()
loader = lua.eval("function(source, name, ns) local fn, err=loadstring(source, '@'..name); assert(fn,err); fn('QuestreihenTracker', ns) end")
addon = root / "addon" / "QuestreihenTracker"
toc = addon / "QuestreihenTracker.toc"
listed = [line.strip() for line in toc.read_text().splitlines()
          if line.strip() and not line.startswith("#")]
assert listed and len(listed) == len(set(listed)), "Invalid TOC file list"
assert set(listed) == {p.name for p in addon.glob("*.lua")}, "TOC does not match addon files"
assert "DemoData.lua" not in listed and not (addon / "DemoData.lua").exists(), "Removed demo must not be shipped"
assert "QuestData.lua" not in listed and not (addon / "QuestData.lua").exists(), "Embedded catalogs must not be shipped"
print(f"Display-only static guard self-tests passed: {self_test()}")
audit = audit_addon(addon)
print(f"Display-only static API audit: {audit['files']} files; {len(audit['api_members'])} allowed C API members.")
for name in listed:
    loader((addon / name).read_text(encoding="utf-8"), name, namespace)

# Technical paths/namespaces use the requested install identity. User-visible locale
# strings consistently use the user's requested terminology.
for key, value in namespace.L.items():
    assert not re.search(r"quest(?:strang|linien?)|\bstrang(?:es|e)?\b", value, re.IGNORECASE), (
        f"Old user-visible terminology in Locale.lua: {key}")
toc_version = next(line.removeprefix("## Version:").strip()
                   for line in toc.read_text().splitlines() if line.startswith("## Version:"))
assert namespace.version == toc_version, "TOC and Core versions differ"
namespace.eventFrame.scripts.OnEvent(namespace.eventFrame, "ADDON_LOADED", "QuestreihenTracker")
assert namespace.initialized, "Addon initialization failed"
new_globals = set(lua.globals().keys()) - baseline
allowed = {"QuestreihenTrackerDB", "SLASH_QUESTREIHENTRACKER1", "QuestreihenTrackerFrame"}
assert new_globals <= allowed, f"Unexpected globals: {new_globals - allowed}"
texture = namespace.Minimap.button.icon.GetTexture(namespace.Minimap.button.icon)
prefix = "Interface\\AddOns\\QuestreihenTracker\\"
assert texture.startswith(prefix), "Minimap logo must reference the bundled addon asset"
logo = addon / Path(texture[len(prefix):].replace("\\", "/") + ".tga")
image = logo.read_bytes()
assert len(image) >= 18, "Truncated minimap logo TGA header"
width, height = struct.unpack_from("<HH", image, 12)
assert image[1:3] == bytes((0, 2)), "Minimap logo must be an uncompressed true-color TGA"
assert (width, height, image[16], image[17] & 15) == (128, 128, 32, 8), "Invalid minimap logo dimensions or alpha"
assert len(image) >= 18 + image[0] + width * height * 4, "Truncated minimap logo pixel data"
lua.globals().TEST_NS = namespace
lua.execute((root / "tests" / "run.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "live_questlines.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "window_size.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "panel_drag.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "minimap.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "display_only.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "quest_lookup.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "activity_warnings.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "selection_controls.lua").read_text(encoding="utf-8"))
lua.execute((root / "tests" / "warning_banner.lua").read_text(encoding="utf-8"))
assert lua.globals().Mock.mutationCount == 0, "A game mutation API was attempted during tests"
assert lua.globals().Mock.invalidIDCalls == 0, "An invalid ID was passed to a game API"

# Boot a separate addon namespace with saved identifiers and an empty API cache.
startup_lua = LuaRuntime(unpack_returned_tuples=True)
startup_lua.execute((root / "tests" / "wow_stubs.lua").read_text(encoding="utf-8"))
startup_baseline = set(startup_lua.globals().keys())
startup_namespace = startup_lua.table()
startup_loader = startup_lua.eval("function(source, name, ns) local fn, err=loadstring(source, '@'..name); assert(fn,err); fn('QuestreihenTracker', ns) end")
for name in listed:
    startup_loader((addon / name).read_text(encoding="utf-8"), name, startup_namespace)
startup_lua.globals().TEST_NS = startup_namespace
startup_lua.execute("""
local ns = TEST_NS
local key = "blizzard:2248:5506"
QuestreihenTrackerDB = { selectedChain = key,
    liveSelection = { mapID = 2248, questLineID = 5506, name = "Discarded saved fixture name" },
    size = { width = 820, height = 930 },
    minimapAngle = 135,
    position = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 42, y = -28 },
    panelPositions = {
        selector = { point = "LEFT", relativePoint = "LEFT", x = 80, y = 15 },
        options = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = -110, y = -60 },
        link = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", x = 75, y = 90 },
    },
    completed = { [78743] = true }, titles = { [78743] = "Discarded saved title" } }
Mock.mapInfos[2248] = { name = "Saved map test fixture" }
Mock.questLinesByMap[2248] = {}
Mock.onLineRequest = function(id)
    assert(id == 2248 and ns.eventFrame.events.QUESTLINE_UPDATE,
        "Quest-line events must be registered before restoration requests")
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUESTLINE_UPDATE", false)
end
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "QuestreihenTracker")
Mock.onLineRequest = nil
assert(ns.initialized and ns.chain.id == key and ns.chain.runtime and ns.chain.loading)
assert(Mock.lineRequests[2248] == 1 and ns.result.total == 0 and not ns.result.done)
assert(QuestreihenTrackerDB.liveSelection.name == nil and QuestreihenTrackerDB.completed == nil)
assert(QuestreihenTrackerDB.titles == nil and ns.result.completed == 0)
assert(ns.db.panelPositions.options == nil and ns.UI.Options == nil)
assert(ns.UI.frame:GetWidth() == 820 and ns.UI.frame:GetHeight() == 930)
local point, _, relativePoint, x, y = ns.UI.frame:GetPoint()
assert(point == "TOPLEFT" and relativePoint == "TOPLEFT" and x == 42 and y == -28)
assert(ns.db.size.width == 820 and ns.db.size.height == 930)
ns.UI.ChooseChain()
ns.UI.ShowLink(78743)
for _, name in ipairs({ "selector", "link" }) do
    local frame = ns.UI[name]
    local saved = ns.db.panelPositions[name]
    local panelPoint, _, panelRelativePoint, panelX, panelY = frame:GetPoint()
    assert(panelPoint == saved.point and panelRelativePoint == saved.relativePoint)
    assert(panelX == saved.x and panelY == saved.y)
    assert(frame.movable == true and frame.dragButtons[1] == "LeftButton")
end
assert(ns.db.minimapAngle == 135)
local minimapPoint, _, minimapRelativePoint, minimapX, minimapY = ns.Minimap.button:GetPoint()
assert(minimapPoint == "CENTER" and minimapRelativePoint == "CENTER" and minimapX < 0 and minimapY > 0)
Mock.Flush()
Mock.questLinesByMap[2248] = { { questLineID = 5506, questLineName = "Restored quest-line fixture", questID = 78745 } }
Mock.questLineQuests[5506] = { 78743, 78744, 78745 }
Mock.completed[78743], Mock.active[78744] = true, true
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUESTLINE_UPDATE", false)
assert(#Mock.timers == 1)
Mock.Flush()
assert(ns.chain.id == key and not ns.chain.loading and ns.chain.name == "Restored quest-line fixture")
assert(ns.result.total == 3 and ns.result.completed == 1 and ns.result.byID[78744].status == "ACTIVE")
assert(ns.db.selectedChain == key and ns.db.liveSelection.mapID == 2248 and ns.db.liveSelection.questLineID == 5506)
assert(Mock.lineRequests[2248] == 1 and #Mock.timers == 0)
ns.ClearSelection()
assert(ns.chain.empty and ns.db.selectedChain == "none" and ns.db.liveSelection == nil)
assert(ns.db.size.width == 820 and ns.db.size.height == 930 and ns.db.minimapAngle == 135)
assert(ns.db.position.x == 42 and ns.db.position.y == -28)
assert(not ns.UI.selector:IsShown() and not ns.UI.link:IsShown())
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUESTLINE_UPDATE", false)
Mock.Flush()
assert(ns.chain.empty and ns.db.selectedChain == "none")
for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
assert(Mock.mutationCount == 0, "Startup attempted a game mutation API")
print("Saved runtime selection, remaining window positions, geometry and minimap startup test passed.")
""")
startup_globals = set(startup_lua.globals().keys()) - startup_baseline - {"TEST_NS"}
assert startup_globals <= allowed, f"Unexpected startup globals: {startup_globals - allowed}"

# A new namespace/cache after removal must boot without restoring any line.
cleared_lua = LuaRuntime(unpack_returned_tuples=True)
cleared_lua.execute((root / "tests" / "wow_stubs.lua").read_text(encoding="utf-8"))
cleared_namespace = cleared_lua.table()
cleared_loader = cleared_lua.eval(
    "function(source, name, ns) local fn, err=loadstring(source, '@'..name); assert(fn,err); fn('QuestreihenTracker', ns) end")
for name in listed:
    cleared_loader((addon / name).read_text(encoding="utf-8"), name, cleared_namespace)
cleared_lua.globals().TEST_NS = cleared_namespace
cleared_lua.globals().QuestreihenTrackerDB = cleared_lua.table_from({
    "selectedChain": startup_namespace.db.selectedChain,
    "minimapAngle": startup_namespace.db.minimapAngle,
    "size": cleared_lua.table_from({"width": startup_namespace.db.size.width,
                                    "height": startup_namespace.db.size.height}),
    "position": cleared_lua.table_from({"point": startup_namespace.db.position.point,
                                        "relativePoint": startup_namespace.db.position.relativePoint,
                                        "x": startup_namespace.db.position.x, "y": startup_namespace.db.position.y}),
})
cleared_lua.execute("""
local ns = TEST_NS
Mock.currentMapID = 2248
Mock.mapInfos[2248] = { name = "Reloaded map fixture" }
Mock.questLinesByMap[2248] = { { questLineID = 5506, questLineName = "Reloaded line fixture" } }
Mock.questLineQuests[5506] = { 78743, 78744, 78745 }
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "QuestreihenTracker")
assert(ns.chain.empty and ns.db.selectedChain == "none" and ns.db.liveSelection == nil)
assert(ns.UI.frame:GetWidth() == 820 and ns.UI.frame:GetHeight() == 930)
assert(ns.db.minimapAngle == 135 and ns.db.position.x == 42 and ns.db.position.y == -28)
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "PLAYER_LOGIN")
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "QUESTLINE_UPDATE", false)
Mock.Flush()
local choices = ns.WoW.ZoneQuestLines()
assert(#choices == 1 and ns.chain.empty and ns.db.liveSelection == nil)
assert(ns.result.total == 0 and ns.db.selectedChain == "none" and Mock.mutationCount == 0)
print("Cleared selection survives a fresh namespace/cache reload; preferences and zone discovery remain usable.")
""")

# A first session must also work when the current client supplies no usable APIs.
unsupported_lua = LuaRuntime(unpack_returned_tuples=True)
unsupported_lua.execute((root / "tests" / "wow_stubs.lua").read_text(encoding="utf-8"))
unsupported_lua.execute("""
C_QuestLine, C_QuestLog, C_SuperTrack, C_Map, C_GossipInfo = nil, nil, nil, nil, nil
GetQuestUiMapID, GetTasksTable, GetTaskInfo = nil, nil, nil
QuestreihenTrackerDB = { schemaVersion = 4, selectedChain = "mourning-rise", warnUnrelated = false,
    autoAccept = true, autoAbandon = true, titles = { [78743] = "Discarded title" },
    completed = { [78743] = true } }
""")
unsupported_namespace = unsupported_lua.table()
unsupported_loader = unsupported_lua.eval(
    "function(source, name, ns) local fn, err=loadstring(source, '@'..name); assert(fn,err); fn('QuestreihenTracker', ns) end")
for name in listed:
    unsupported_loader((addon / name).read_text(encoding="utf-8"), name, unsupported_namespace)
unsupported_lua.globals().TEST_NS = unsupported_namespace
unsupported_lua.execute("""
local ns = TEST_NS
ns.eventFrame.scripts.OnEvent(ns.eventFrame, "ADDON_LOADED", "QuestreihenTracker")
assert(ns.initialized and ns.chain.empty and ns.chain.id == "none")
assert(ns.result.total == 0 and ns.result.completed == 0 and not ns.result.done)
assert(ns.db.selectedChain == "none" and ns.db.liveSelection == nil and ns.db.schemaVersion == 6)
assert(ns.db.completed == nil and ns.db.titles == nil and ns.db.warnUnrelated == nil)
assert(ns.db.autoAccept == nil and ns.db.autoAbandon == nil)
ns.Slash("zone"); Mock.Flush()
local choices, status = ns.WoW.ZoneQuestLines()
assert(#choices == 0 and status == "UNSUPPORTED" and ns.UI.selector:IsShown())
ns.LookupQuest(78743); Mock.Flush()
assert(ns.questLookup.status == "UNSUPPORTED" and ns.chain.id == "none")
assert(#Mock.timers == 0 and Mock.calls == 0 and Mock.mutationCount == 0 and Mock.invalidIDCalls == 0)
for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
print("Missing-API startup and legacy preference migration test passed.")
""")
print(f"Lua 5.1 syntax + TOC load: {len(listed)} files; no unexpected globals.")
