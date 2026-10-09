-- Native widgets and timer time are simulated; this does not establish client layout.
local ns, UI = TEST_NS, TEST_NS.UI
local saved = { errors = UIErrorsFrame, chain = ns.chain, db = ns.db,
    refresh = ns.Refresh, warnings = ns.WoW.WarnActivities, shown = ns.UI.frame:IsShown() }
Mock.Flush()
local refreshes = 0
ns.Refresh = function() refreshes = refreshes + 1 end
ns.WoW.WarnActivities = function() end

UI.ShowWarning("Warning timing fixture")
local start = GetTime()
assert(UI.warning:IsShown() and UI.warningDuration == 5)
assert(#Mock.timers == 1)
ns.UI.frame:Hide()
Mock.Advance(1)
assert(UI.warning:IsShown(), "Closing the tracker must not hide its warning")
for index = 1, 12 do ns.ScheduleRefresh() end
assert(#Mock.timers == 1, "Refresh must preempt the expiry with one live timer")
Mock.Advance(0.1)
assert(refreshes == 1 and UI.warning:IsShown() and #Mock.timers == 1)
Mock.Advance(3.8)
assert(UI.warning:IsShown() and GetTime() < start + 5)
Mock.Advance(0.2)
assert(not UI.warning:IsShown() and #Mock.timers == 0 and refreshes == 1)

UI.ShowWarning("First warning fixture")
Mock.Advance(3)
UI.ShowWarning("Replacement warning fixture")
assert(#Mock.timers == 1 and UI.warning.message:GetText() == "Replacement warning fixture")
Mock.Advance(4.9)
assert(UI.warning:IsShown())
Mock.Advance(0.2)
assert(not UI.warning:IsShown() and #Mock.timers == 0)

UIErrorsFrame = { GetTimeVisible = function() return 4 end, GetFadeDuration = function() return 1 end }
UI.ShowWarning("Client duration fixture")
assert(UI.warningDuration == 10)
Mock.Advance(9.9); assert(UI.warning:IsShown())
Mock.Advance(0.2); assert(not UI.warning:IsShown())
UIErrorsFrame = { GetTimeVisible = function() error("Missing client duration") end }
UI.ShowWarning("Fallback duration fixture")
assert(UI.warningDuration == 5)
Mock.Flush()
assert(not UI.warning:IsShown() and #Mock.timers == 0)

ns.Refresh, ns.WoW.WarnActivities = saved.refresh, saved.warnings
UIErrorsFrame = saved.errors
UI.ShowWarning("Selection cancellation fixture")
ns.ClearSelection()
assert(not UI.warning:IsShown() and UI.warningExpires == nil and #Mock.timers == 0)
ns.chain, ns.db = saved.chain, saved.db
QuestreihenTrackerDB = ns.db
UI.frame:SetShown(saved.shown)
Mock.Flush()
for _, frame in ipairs(Mock.frames) do assert(frame.scripts.OnUpdate == nil) end
assert(Mock.mutationCount == 0 and Mock.invalidIDCalls == 0)
print("Warning banner deadline, replacement, refresh preemption and cancellation tests passed.")
