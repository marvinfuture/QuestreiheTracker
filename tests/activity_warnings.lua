-- Simulated API activities, unrelated to real quest-line facts.
-- IDs: https://www.wowhead.com/quest=78562, /quest=78563, /quest=78564 and /quest=78743.
local ns, passed = TEST_NS, 0
local questID, otherID, memberID = 78562, 78563, 78743
local chain = assert(ns.LiveData.Build(2248, { questLineID = 5506,
    questLineName = "Activity warning fixture" }, { 78743, 78744, 78745 }))
local saved = { questLog = C_QuestLog, superTrack = C_SuperTrack,
    tasks = GetTasksTable, taskInfo = GetTaskInfo, enum = Enum,
    showWarning = ns.UI.ShowWarning, errors = UIErrorsFrame }
local nativeWarnings = 0
UIErrorsFrame = { AddMessage = function() nativeWarnings = nativeWarnings + 1 end }
ns.UI.ShowWarning = function(message)
    Mock.warningCount = Mock.warningCount + 1
    Mock.warnings[#Mock.warnings + 1] = message
    return saved.showWarning(message)
end
local function clone(value)
    local result = {}; for key, item in pairs(value) do result[key] = item end; return result
end
local function event(name, ...)
    ns.eventFrame.scripts.OnEvent(ns.eventFrame, name, ...)
end
local function flush(name, ...)
    event(name or "QUEST_LOG_UPDATE", ...); Mock.Flush()
end
local function reset()
    Mock.Flush()
    C_QuestLog, C_SuperTrack = clone(saved.questLog), clone(saved.superTrack)
    GetTasksTable, GetTaskInfo = saved.tasks, saved.taskInfo
    Enum = { SuperTrackingType = { Quest = 0, UserWaypoint = 1 } }
    for _, key in ipairs({ "tasks", "taskInfo", "watched", "worldWatched", "offers", "active",
        "completed", "warnings", "messages", "requests" }) do Mock[key] = {} end
    Mock.warningCount = 0
    Mock.titles = { [78743] = "Member title fixture", [78744] = "Member title fixture",
        [78745] = "Member title fixture", [questID] = "Other activity fixture", [otherID] = "Second activity fixture" }
    Mock.superTrackedQuestID, Mock.highestPrioritySuperTrackingType = nil, nil
    Mock.isSuperTrackingQuest = false
    for _, key in ipairs({ "failWatchRead", "failTasksRead", "failTaskInfo", "failTrackedRead",
        "failTrackingKindRead", "failPriorityRead" }) do Mock[key] = nil end
    ns.chain = chain
    ns.WoW.RegisterQuestLine(chain)
    ns.db = ns.ReadConfig({ selectedChain = chain.id,
        liveSelection = { mapID = chain.mapID, questLineID = chain.questLineID } })
    QuestreihenTrackerDB = ns.db
    ns.WoW.requested, ns.WoW.failedRequests = {}, {}
    ns.WoW.ResetWarnings()
    ns.Refresh()
end
local function test(name, fn)
    reset()
    local ok, message = pcall(fn)
    assert(ok, "Activity warnings / " .. name .. ": " .. tostring(message))
    assert(Mock.mutationCount == 0 and Mock.invalidIDCalls == 0)
    assert(nativeWarnings == 0, "Addon warnings must use only the warning banner")
    assert(#Mock.timers == 0, "Warnings must not leave a retry timer")
    for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
    passed = passed + 1
end
local function task(id, inArea, bonus)
    Mock.tasks = { id }
    Mock.taskInfo[id] = { inArea = inArea, onMap = true, title = "Task activity fixture",
        displayAsObjective = bonus == true }
end
local function navigation(id)
    Mock.isSuperTrackingQuest = true
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.Quest
    Mock.superTrackedQuestID = id
end

test("warning events are registered and a burst shares the refresh timer", function()
    for _, name in ipairs({ "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "TASK_PROGRESS_UPDATE",
        "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN" }) do
        assert(ns.eventFrame.events[name], "Missing warning event: " .. name)
        for index = 1, 5 do event(name) end
    end
    assert(#Mock.timers == 1); Mock.Flush()
end)

test("nearby world quests and active bonus objectives both warn once", function()
    for _, bonus in ipairs({ false, true }) do
        task(questID, true, bonus); ns.WoW.ResetWarnings()
        local before = Mock.warningCount
        flush("TASK_PROGRESS_UPDATE")
        assert(Mock.warningCount == before + 1 and #Mock.messages == Mock.warningCount)
        assert(Mock.warnings[#Mock.warnings]:find("Task activity fixture", 1, true))
        for index = 1, 5 do flush() end
        assert(Mock.warningCount == before + 1)
    end
end)

test("tasks only on the map stay silent and leaving then re-entering rearms", function()
    task(questID, false, true); flush("TASK_PROGRESS_UPDATE")
    assert(Mock.warningCount == 0)
    Mock.taskInfo[questID].inArea = true; flush(); assert(Mock.warningCount == 1)
    Mock.taskInfo[questID].inArea = false; flush()
    Mock.taskInfo[questID].inArea = true; flush(); assert(Mock.warningCount == 2)
end)

test("old watches are a silent baseline but newly observed quests warn", function()
    Mock.watched = { questID }; ns.WoW.ResetWarnings(); flush()
    assert(Mock.warningCount == 0)
    Mock.watched = { questID, otherID }
    flush("QUEST_WATCH_LIST_CHANGED", otherID, true)
    assert(Mock.warningCount == 1 and Mock.warnings[1]:find(tostring(otherID), 1, true))
    flush("QUEST_WATCH_LIST_CHANGED", otherID, true); assert(Mock.warningCount == 1)
    event("QUEST_WATCH_LIST_CHANGED", otherID, false)
    event("QUEST_WATCH_LIST_CHANGED", otherID, true); Mock.Flush()
    assert(Mock.warningCount == 2)
    Mock.worldWatched = { questID }; flush("QUEST_WATCH_LIST_CHANGED", questID, true)
    assert(Mock.warningCount == 2, "Moving an already observed ID between watch lists should stay silent")
    Mock.watched, Mock.worldWatched = {}, {}; flush()
    Mock.worldWatched = { questID }; flush("QUEST_WATCH_LIST_CHANGED", questID, true)
    assert(Mock.warningCount == 3)
end)

test("task watch navigation and acceptance in one burst emit one warning per ID", function()
    task(questID, true, true)
    Mock.watched, Mock.active[questID] = { questID }, true
    navigation(questID)
    event("QUEST_ACCEPTED", questID)
    event("QUEST_WATCH_LIST_CHANGED", questID, true)
    event("SUPER_TRACKING_CHANGED")
    event("TASK_PROGRESS_UPDATE")
    assert(#Mock.timers == 1); Mock.Flush(); assert(Mock.warningCount == 1)
    flush(); assert(Mock.warningCount == 1)
end)

test("quest navigation rejects stale IDs while a waypoint is selected", function()
    Mock.superTrackedQuestID = questID
    flush("SUPER_TRACKING_CHANGED"); assert(Mock.warningCount == 0)
    Mock.isSuperTrackingQuest = true
    Mock.highestPrioritySuperTrackingType = Enum.SuperTrackingType.UserWaypoint
    flush("SUPER_TRACKING_CHANGED"); assert(Mock.warningCount == 0)
    navigation(questID); flush("SUPER_TRACKING_CHANGED"); assert(Mock.warningCount == 1)
    flush("SUPER_TRACKING_CHANGED"); assert(Mock.warningCount == 1)
    navigation(otherID); event("SUPER_TRACKING_CHANGED")
    navigation(questID); event("SUPER_TRACKING_CHANGED"); Mock.Flush()
    assert(Mock.warningCount == 2, "Switching away and back is a new navigation choice")
end)

test("selected members stay silent for every activity source", function()
    task(memberID, true, true)
    navigation(memberID)
    Mock.watched, Mock.active[memberID] = { memberID }, true
    event("QUEST_ACCEPTED", memberID); event("QUEST_WATCH_LIST_CHANGED", memberID, true)
    event("SUPER_TRACKING_CHANGED"); Mock.Flush()
    assert(Mock.warningCount == 0)
end)

test("accepted progress may arrive later and removal cancels pending work", function()
    flush("QUEST_ACCEPTED", questID); assert(Mock.warningCount == 0)
    Mock.active[questID] = true; flush(); assert(Mock.warningCount == 1)
    flush("QUEST_ACCEPTED", questID); assert(Mock.warningCount == 1)
    event("QUEST_REMOVED", questID); event("QUEST_ACCEPTED", questID); Mock.Flush()
    assert(Mock.warningCount == 2)
    event("QUEST_ACCEPTED", otherID); event("QUEST_REMOVED", otherID); Mock.Flush()
    Mock.active[otherID] = true; flush(); assert(Mock.warningCount == 2)
end)

test("empty loading and changed selections suppress stale accepted warnings", function()
    event("QUEST_ACCEPTED", questID)
    ns.chain = ns.LiveData.Empty(); Mock.active[questID] = true; Mock.Flush()
    assert(Mock.warningCount == 0)
    task(questID, true, true)
    ns.chain = ns.LiveData.Pending(2214, 5507); flush(); assert(Mock.warningCount == 0)
    ns.chain = chain; ns.WoW.ResetWarnings(); flush(); assert(Mock.warningCount == 1)
    task(otherID, false, true); Mock.active[otherID] = false
    event("QUEST_ACCEPTED", otherID)
    local other = assert(ns.LiveData.Build(2214, { questLineID = 5507,
        questLineName = "Replacement story fixture" }, { 78743 }))
    ns.WoW.RegisterQuestLine(other); ns.Select(other.id)
    Mock.active[otherID] = true; Mock.Flush(); assert(Mock.warningCount == 1)
end)

test("title cache failures use a stable fallback without request loops", function()
    Mock.titles[questID] = nil
    Mock.watched = { questID }; flush("QUEST_WATCH_LIST_CHANGED", questID, true)
    assert(Mock.warningCount == 1 and Mock.warnings[1]:find(tostring(questID), 1, true))
    for index = 1, 5 do flush("QUEST_DATA_LOAD_RESULT", questID, false) end
    assert(Mock.warningCount == 1 and Mock.requests[questID] == nil)
end)

test("invalid activity IDs never reach quest APIs", function()
    for _, id in ipairs({ -101, 0, 1.5, "78562", math.huge, 0 / 0 }) do
        Mock.tasks, Mock.watched, Mock.worldWatched = { id }, { id }, { id }
        Mock.superTrackedQuestID = id
        event("QUEST_ACCEPTED", id); event("QUEST_WATCH_LIST_CHANGED", id, true)
        event("TASK_PROGRESS_UPDATE"); Mock.Flush()
    end
    assert(Mock.warningCount == 0 and Mock.invalidIDCalls == 0)
end)

test("missing and thrown activity APIs remain safe", function()
    C_QuestLog.GetNumQuestWatches, C_QuestLog.GetNumWorldQuestWatches = nil, nil
    C_SuperTrack.IsSuperTrackingQuest = nil
    GetTasksTable, GetTaskInfo = nil, nil
    flush(); assert(Mock.warningCount == 0)
    C_QuestLog, C_SuperTrack = clone(saved.questLog), clone(saved.superTrack)
    GetTasksTable, GetTaskInfo = saved.tasks, saved.taskInfo
    Mock.failWatchRead, Mock.failTasksRead, Mock.failTrackedRead = true, true, true
    navigation(questID); flush(); assert(Mock.warningCount == 0)
end)

test("temporary watch or task cache failures do not rearm unchanged activities", function()
    task(questID, true, true); Mock.watched = { otherID }
    flush(); assert(Mock.warningCount == 2)
    Mock.failWatchRead, Mock.failTasksRead = true, true; flush()
    Mock.failWatchRead, Mock.failTasksRead = nil, nil; flush()
    assert(Mock.warningCount == 2, "Cache failure recovery repeated an unchanged warning")
    Mock.failTaskInfo = true; flush()
    Mock.failTaskInfo = nil; flush()
    assert(Mock.warningCount == 2, "Task-info recovery repeated an unchanged warning")
end)

C_QuestLog, C_SuperTrack, GetTasksTable, GetTaskInfo, Enum = saved.questLog, saved.superTrack,
    saved.tasks, saved.taskInfo, saved.enum
ns.UI.ShowWarning, UIErrorsFrame = saved.showWarning, saved.errors
Mock.tasks, Mock.taskInfo, Mock.watched, Mock.worldWatched = {}, {}, {}, {}
Mock.superTrackedQuestID, Mock.isSuperTrackingQuest = nil, false
ns.WoW.ResetWarnings()
print("Activity warning tests passed: " .. passed)
