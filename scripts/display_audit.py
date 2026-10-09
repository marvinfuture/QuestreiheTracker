"""Static regression guard for this addon's small display-only API surface.

This token check complements executed Lua tests and human review. It is not a
complete Lua analyzer or proof of behavior in a real WoW client.
"""
from dataclasses import dataclass
from pathlib import Path
import re


API_MEMBERS = {
    "C_QuestLog.IsQuestFlaggedCompleted", "C_QuestLog.IsOnQuest",
    "C_QuestLog.GetTitleForQuestID", "C_QuestLog.RequestLoadQuestByID",
    "C_QuestLog.GetNumQuestWatches", "C_QuestLog.GetQuestIDForQuestWatchIndex",
    "C_QuestLog.GetNumWorldQuestWatches", "C_QuestLog.GetQuestIDForWorldQuestWatchIndex",
    "C_QuestLine.RequestQuestLinesForMap", "C_QuestLine.GetAvailableQuestLines",
    "C_QuestLine.GetQuestLineQuests", "C_Map.GetBestMapForUnit",
    "C_QuestLine.GetQuestLineInfo", "C_SuperTrack.GetSuperTrackedQuestID",
    "C_SuperTrack.IsSuperTrackingQuest", "C_SuperTrack.GetHighestPrioritySuperTrackingType",
    "C_Map.GetMapInfo", "C_GossipInfo.GetAvailableQuests", "C_Timer.After",
}
API_NAMESPACES = {member.split(".")[0] for member in API_MEMBERS}
SAFE_GLOBALS = {
    "CreateFrame", "UIParent", "Minimap", "GameTooltip", "UISpecialFrames",
    "DEFAULT_CHAT_FRAME", "UIErrorsFrame", "SlashCmdList", "Enum",
    "QuestStrangTrackerDB", "SLASH_QUESTSTRANGTRACKER1", "UnitFactionGroup",
    "UnitExists", "GetQuestID", "GetBuildInfo", "InCombatLockdown",
    "GetAchievementInfo", "GetAchievementNumCriteria", "GetAchievementCriteriaInfo",
    "GetCursorPosition",
    "GetQuestUiMapID",
    "GetTasksTable", "GetTaskInfo",
}
FORBIDDEN_IDENTIFIERS = {
    "_G", "_ENV", "load", "loadstring", "loadfile", "dofile", "require",
    "getfenv", "setfenv", "rawget", "rawset", "getmetatable", "setmetatable",
    "debug", "io", "os", "package", "newproxy", "hooksecurefunc",
    "AcceptQuest", "ConfirmAcceptQuest", "AcknowledgeAutoAcceptQuest",
    "AbandonQuest", "SetAbandonQuest", "CompleteQuest", "GetQuestReward",
    "SelectAvailableQuest", "SelectActiveQuest", "SelectGossipOption",
    "SelectGossipAvailableQuest", "SelectGossipActiveQuest",
    "AddQuestWatch", "RemoveQuestWatch", "AddWorldQuestWatch", "RemoveWorldQuestWatch",
    "SetSelectedQuest", "SetSuperTrackedQuestID", "AddTrackedAchievement",
    "RemoveTrackedAchievement", "QuestMapFrame_OpenToQuestDetails",
    "QuestMapFrame_ShowQuestDetails", "QuestLogPopupDetailFrame_Show",
    "DeleteCursorItem", "PickupContainerItem", "PickupInventoryItem",
    "UseContainerItem", "UseInventoryItem", "UseItemByName", "EquipItemByName",
    "RunMacro", "RunMacroText", "RunScript", "ExecuteSlashCommand",
    "SendChatMessage", "SendAddonMessage", "SendAddonMessageLogged", "SendMail",
    "SetCVar", "SetBinding", "SetOverrideBinding", "SetAttribute",
    "SecureHandlerExecute",
}
KEYWORDS = set("and break do else elseif end false for function if in local nil not or repeat return then true until while".split())
LONG_OPEN = re.compile(r"\[(=*)\[")
IDENTIFIER = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


@dataclass(frozen=True)
class Token:
    value: str
    kind: str
    line: int


def _tokens(source, name):
    """Keep literal boundaries so comments and source URLs cannot mimic code."""
    result, offset, line = [], 0, 1
    while offset < len(source):
        char = source[offset]
        if char.isspace():
            line += char == "\n"
            offset += 1
            continue
        comment = source.startswith("--", offset)
        start = offset + 2 if comment else offset
        opening = LONG_OPEN.match(source, start)
        if opening:
            closing = "]" + opening.group(1) + "]"
            end = source.find(closing, opening.end())
            assert end >= 0, f"{name}:{line}: unterminated long literal/comment"
            end += len(closing)
            if not comment:
                result.append(Token(source[opening.end():end-len(closing)], "string", line))
            line += source[offset:end].count("\n")
            offset = end
            continue
        if comment:
            end = source.find("\n", offset)
            offset = len(source) if end < 0 else end
            continue
        if char in "\"'":
            end = offset + 1
            while end < len(source):
                if source[end] == "\\":
                    end += 2
                elif source[end] == char:
                    break
                else:
                    end += 1
            assert end < len(source), f"{name}:{line}: unterminated string"
            result.append(Token(source[offset+1:end], "string", line))
            line += source[offset:end+1].count("\n")
            offset = end + 1
            continue
        identifier = IDENTIFIER.match(source, offset)
        if identifier:
            value = identifier.group()
            result.append(Token(value, "keyword" if value in KEYWORDS else "identifier", line))
            offset = identifier.end()
            continue
        operator = next((op for op in ("...", "..", "==", "~=", "<=", ">=")
                         if source.startswith(op, offset)), char)
        result.append(Token(operator, "symbol", line))
        offset += len(operator)
    return result


def _local_identifiers(tokens):
    """Collect declared names; this intentionally does not infer Lua scope."""
    names = set()
    for index, token in enumerate(tokens):
        if token.value == "local":
            cursor = index + 1
            if tokens[cursor].value == "function":
                cursor += 1
                names.add(tokens[cursor].value)
            else:
                while cursor < len(tokens) and tokens[cursor].kind == "identifier":
                    names.add(tokens[cursor].value)
                    cursor += 1
                    if cursor >= len(tokens) or tokens[cursor].value != ",":
                        break
                    cursor += 1
        elif token.value == "for":
            cursor = index + 1
            while cursor < len(tokens) and tokens[cursor].kind == "identifier":
                names.add(tokens[cursor].value)
                cursor += 1
                if cursor >= len(tokens) or tokens[cursor].value != ",":
                    break
                cursor += 1
        elif token.value == "function":
            cursor = index + 1
            while cursor < len(tokens) and tokens[cursor].value != "(":
                cursor += 1
            cursor += 1
            while cursor < len(tokens) and tokens[cursor].value != ")":
                if tokens[cursor].kind == "identifier":
                    names.add(tokens[cursor].value)
                cursor += 1
    return names


def _audit_source(source, name):
    tokens = _tokens(source, name)
    locals_ = _local_identifiers(tokens)
    members, globals_ = set(), set()
    for index, token in enumerate(tokens):
        value = token.value
        previous = tokens[index-1].value if index else None
        following = tokens[index+1].value if index + 1 < len(tokens) else None
        if token.kind == "string":
            assert not re.search(r"Secure\w*Template|\|H", value), f"{name}:{token.line}: executable template/hyperlink"
            continue
        if token.kind != "identifier":
            continue
        assert value not in FORBIDDEN_IDENTIFIERS, f"{name}:{token.line}: forbidden action/indirection {value}"
        if value.startswith("C_"):
            assert value in API_NAMESPACES, f"{name}:{token.line}: unreviewed API namespace {value}"
            assert following in {".", "and"}, f"{name}:{token.line}: indirect API access {value}"
            if following == ".":
                member = value + "." + tokens[index+2].value
                assert member in API_MEMBERS, f"{name}:{token.line}: unreviewed API member {member}"
                assert index + 3 >= len(tokens) or tokens[index+3].value != "=", f"{name}:{token.line}: API replacement {member}"
                members.add(member)
        elif (value[0].isupper() and value not in locals_
              and previous not in {".", ":"}
              and not (following == "=" and previous in {"{", ","})):
            assert value in SAFE_GLOBALS, f"{name}:{token.line}: unreviewed global reference {value}"
            globals_.add(value)
        if value in SAFE_GLOBALS and previous not in {".", ":"}:
            globals_.add(value)
            if following == "=":
                assert value in {"QuestStrangTrackerDB", "SLASH_QUESTSTRANGTRACKER1"}, f"{name}:{token.line}: global replacement {value}"
    return members, globals_


def audit_addon(addon_path):
    """Raise on unreviewed API/code paths; return a compact audit inventory."""
    addon = Path(addon_path)
    paths = sorted(addon.glob("*.lua"))
    assert paths, f"No addon Lua files found in {addon}"
    members, globals_ = set(), set()
    for path in paths:
        found_members, found_globals = _audit_source(path.read_text(encoding="utf-8"), path.name)
        members.update(found_members)
        globals_.update(found_globals)
    return {"files": len(paths), "api_members": sorted(members), "global_references": sorted(globals_)}


def self_test():
    """Exercise the guard's meaningful accept/reject cases without file writes."""
    allowed = [
        "local state = C_QuestLog.IsOnQuest(78743)",
        "local fn = C_QuestLog and C_QuestLog.RequestLoadQuestByID; pcall(fn, 78743)",
        "if C_QuestLine and type(C_QuestLine.GetQuestLineQuests) == 'function' then end",
        "local id = C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID()",
        "local quest = C_SuperTrack.IsSuperTrackingQuest(); local kind = C_SuperTrack.GetHighestPrioritySuperTrackingType()",
        "local info = C_QuestLine.GetQuestLineInfo(78743, nil, false); local map = GetQuestUiMapID(78743)",
        "local tasks = GetTasksTable(); local inArea = GetTaskInfo(78743)",
        "local count = C_QuestLog.GetNumQuestWatches(); local id = C_QuestLog.GetQuestIDForQuestWatchIndex(1)",
        "local UI = {}; UI.Render = function() end; UI.Render()",
        "QuestStrangTrackerDB = {}; SLASH_QUESTSTRANGTRACKER1 = '/qst'",
        "local text = 'AcceptQuest _G C_QuestLog.AbandonQuest'; -- RunMacroText()\n"
        "--[=[ C_GossipInfo.SelectAvailableQuest(78743) ]=] local number = 1",
        "local text = [=[RequestLoadQuestByID and AbandonQuest are distinct]=]",
        "local text = 'escaped \\' string'; local value = C_Map.GetBestMapForUnit('player')",
    ]
    forbidden = [
        "AcceptQuest()", "local action = AcceptQuest; pcall(action)",
        "pcall(C_QuestLog.AbandonQuest)", "C_QuestLog.SetAbandonQuest()",
        "C_QuestLog.SetSelectedQuest(78743)", "C_GossipInfo.SelectAvailableQuest(78743)",
        "C_QuestLog.GetQuestUiMapID(78743)",
        "C_SuperTrack.SetSuperTrackedQuestID(78743)", "C_Container.DeleteCursorItem()",
        "C_QuestLog['AbandonQuest']()", "local api = C_QuestLog; api.AbandonQuest()",
        "local action = _G['AcceptQuest']; action()", "getfenv()['AcceptQuest']()",
        "loadstring('AcceptQuest()')()", "RunMacroText('/abandon')",
        "frame:SetAttribute('type', 'macro')", "SetBindingClick('F1', 'quest')",
        "CreateFrame('Button', nil, UIParent, 'SecureActionButtonTemplate')",
        "C_ChatInfo.SendAddonMessage('QST', 'test', 'GUILD')", "SendChatMessage('test')",
        "QuestMapFrame_OpenToQuestDetails(78743)", "local fn = SomeNewGameAPI; fn()",
        "C_QuestLog.GetInfo = function() end", "CreateFrame = function() end",
    ]
    for source in allowed:
        _audit_source(source, "allowed fixture")
    for source in forbidden:
        try:
            _audit_source(source, "forbidden fixture")
        except AssertionError:
            pass
        else:
            raise AssertionError(f"Static audit accepted forbidden fixture: {source}")
    return len(allowed) + len(forbidden)


if __name__ == "__main__":
    count = self_test()
    summary = audit_addon(Path(__file__).resolve().parents[1] / "addon" / "QuestStrangTracker")
    print(f"Display-only static guard self-tests passed: {count}")
    print(f"Display-only static API audit: {summary['files']} Lua files; {len(summary['api_members'])} allowed C API members.")
