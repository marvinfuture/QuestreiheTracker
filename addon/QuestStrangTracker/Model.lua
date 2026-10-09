local _, ns = ...
local Model = {}
ns.Model = Model

local function isID(value)
    return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
end

function Model.Flatten(chain)
    local quests, byID = {}, {}
    for _, section in ipairs(chain.sections or {}) do
        for _, quest in ipairs(section.quests or {}) do
            quests[#quests + 1] = quest
            if isID(quest.questID) then byID[quest.questID] = quest end
        end
    end
    return quests, byID
end

function Model.Contains(chain, questID)
    local _, byID = Model.Flatten(chain)
    return byID[questID] ~= nil
end

function Model.Validate(chain)
    if type(chain) ~= "table" or type(chain.id) ~= "string"
        or type(chain.name) ~= "string" or type(chain.sections) ~= "table" then
        return { "Invalid quest line" }
    end
    local errors, seen, count = {}, {}, 0
    for _, section in ipairs(chain.sections) do
        if type(section) ~= "table" or type(section.quests) ~= "table" then
            errors[#errors + 1] = "Invalid section"
        else
            for _, quest in ipairs(section.quests) do
                if type(quest) ~= "table" or not isID(quest.questID) then
                    errors[#errors + 1] = "Invalid quest ID"
                elseif seen[quest.questID] then
                    errors[#errors + 1] = "Duplicate quest ID"
                else
                    seen[quest.questID], count = true, count + 1
                end
            end
        end
    end
    if not chain.empty and not chain.loading and count == 0 then errors[#errors + 1] = "Empty quest list" end
    return errors
end

function Model.ProgressStatus(completed, active)
    if completed == true then return "COMPLETED" end
    if active == true then return "ACTIVE" end
    if completed == false and active == false then return "NOT_ACCEPTED" end
    return "UNKNOWN"
end

-- Runtime membership and order never establish prerequisites or optionality.
function Model.Evaluate(chain, snapshot)
    local result = { rows = {}, byID = {}, active = {}, next = {}, completed = 0, total = 0 }
    snapshot = snapshot or {}
    local completed, active, offered = snapshot.completed or {}, snapshot.active or {}, snapshot.offered or {}
    for _, quest in ipairs(Model.Flatten(chain)) do
        local id = quest.questID
        local progress = Model.ProgressStatus(completed[id], active[id])
        local status = progress == "NOT_ACCEPTED" and "UNKNOWN" or progress
        if status == "UNKNOWN" and offered[id] == true then status = "AVAILABLE" end
        local inferred = status == "UNKNOWN" and id == chain.suggestedQuestID
            and completed[id] == false and active[id] == false
        local row = { quest = quest, questID = id, status = status, progressStatus = progress, inferredNext = inferred }
        result.rows[#result.rows + 1], result.byID[id] = row, row
        if status == "ACTIVE" then result.active[#result.active + 1] = row end
        if inferred then result.next[#result.next + 1] = row end
        result.total = result.total + 1
        if status == "COMPLETED" then result.completed = result.completed + 1 end
    end
    result.percent = result.total > 0 and result.completed / result.total * 100 or 0
    result.done = result.total > 0 and result.completed == result.total
    return result
end
