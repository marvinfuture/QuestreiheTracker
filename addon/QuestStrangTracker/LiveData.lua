local _, ns = ...
local LiveData = {}
ns.LiveData = LiveData

-- Blizzard-generated documentation, not another addon's implementation.
LiveData.source = "https://github.com/Gethe/wow-ui-source/blob/09b9db7948abc9b9648dedaab51eb0cf3ee67b31/Interface/AddOns/Blizzard_APIDocumentationGenerated/QuestLineInfoDocumentation.lua"

function LiveData.IsID(value)
    return type(value) == "number" and value > 0 and value < math.huge and value == math.floor(value)
end

function LiveData.Key(mapID, questLineID)
    return "blizzard:" .. mapID .. ":" .. questLineID
end

function LiveData.Empty()
    return { id = "none", empty = true, name = ns.L.NO_SELECTION, sections = {} }
end

function LiveData.IsName(value)
    return type(value) == "string" and value:find("%S") ~= nil
end

function LiveData.Pending(mapID, questLineID, name)
    if not LiveData.IsID(mapID) or not LiveData.IsID(questLineID) then return nil end
    local nameKnown = LiveData.IsName(name)
    return {
        id = LiveData.Key(mapID, questLineID), runtime = true, loading = true,
        mapID = mapID, questLineID = questLineID,
        name = nameKnown and name or string.format(ns.L.BLIZZARD_LINE_NAME, questLineID), nameKnown = nameKnown,
        nameSourceAPI = nameKnown and "C_QuestLine.GetAvailableQuestLines" or nil,
        source = LiveData.source, sourceAPI = "C_QuestLine.GetAvailableQuestLines",
        sections = { { name = ns.L.BLIZZARD_SECTION, quests = {} } },
    }
end

-- Membership and display order do not prove prerequisites or optionality.
function LiveData.Build(mapID, info, questIDs)
    if not LiveData.IsID(mapID) or type(info) ~= "table" or not LiveData.IsID(info.questLineID)
        or type(questIDs) ~= "table" or #questIDs == 0 then return nil end
    local count = 0
    for index, id in pairs(questIDs) do
        if not LiveData.IsID(index) or index > #questIDs or not LiveData.IsID(id) then return nil end
        count = count + 1
    end
    if count ~= #questIDs then return nil end
    local chain = LiveData.Pending(mapID, info.questLineID, info.questLineName)
    local quests, seen = chain.sections[1].quests, {}
    for _, id in ipairs(questIDs) do
        if not LiveData.IsID(id) then return nil end
        if not seen[id] then
            quests[#quests + 1] = { questID = id, title = string.format(ns.L.UNKNOWN_TITLE, id),
                requirementsKnown = false, optionalityKnown = false,
                source = LiveData.source, sourceAPI = "C_QuestLine.GetQuestLineQuests" }
            seen[id] = true
        end
    end
    chain.loading = false
    if LiveData.IsID(info.questID) and seen[info.questID] then chain.suggestedQuestID = info.questID end
    return chain
end
