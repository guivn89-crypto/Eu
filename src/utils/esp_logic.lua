--!strict
--[[
    BBC HUB - Pure ESP candidate logic
    Keeps deduplication, ordering and feature-state transitions independent
    from Roblox instances so they can be tested headlessly.
]]

local ESPLogic = {}

local FEATURE_KEYS = {
    highlight = true,
    box = true,
    name = true,
    healthbar = true,
    health = true,
    distance = true,
    tracers = true,
    skeleton = true,
}

local function cloneValue(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, item in pairs(value) do
        copy[key] = cloneValue(item)
    end
    return copy
end

local function stableId(candidate)
    if type(candidate) ~= "table" then
        return ""
    end
    if type(candidate.stableId) == "string" then
        return candidate.stableId
    end
    local model = candidate.model
    if type(model) == "table" and type(model.Name) == "string" then
        return model.Name
    end
    return tostring(model)
end

function ESPLogic.setEspFlag(config, key, enabled)
    if type(config) ~= "table" or type(key) ~= "string" then
        return nil
    end

    local updated = cloneValue(config)
    if key == "enabled" then
        updated.enabled = enabled == true
        return updated
    end

    if not FEATURE_KEYS[key] or type(updated[key]) ~= "table" then
        return nil
    end
    updated[key].on = enabled == true
    return updated
end

function ESPLogic.reconcileCandidates(playerCandidates, npcCandidates, localCharacter)
    local byModel = {}
    local order = {}

    local function add(candidate, kind)
        if type(candidate) ~= "table" then
            return
        end
        local model = candidate.model
        if model == nil or model == localCharacter then
            return
        end

        local existing = byModel[model]
        if existing == nil then
            order[#order + 1] = model
            byModel[model] = { kind = kind, candidate = candidate }
        elseif kind == "Jogador" then
            -- Player classification always wins over an NPC classification.
            existing.kind = kind
            existing.candidate = candidate
        end
    end

    for _, candidate in ipairs(npcCandidates or {}) do
        add(candidate, "NPCs")
    end
    for _, candidate in ipairs(playerCandidates or {}) do
        add(candidate, "Jogador")
    end

    local result = {}
    for _, model in ipairs(order) do
        result[#result + 1] = byModel[model]
    end
    return result
end

function ESPLogic.scaledTextSize(settings, featureSize)
    local baseSize = tonumber(type(settings) == "table" and settings.textSize or nil) or 12
    local size = tonumber(featureSize) or baseSize
    local scaled = size * (baseSize / 12)
    return math.max(8, math.min(24, scaled))
end

function ESPLogic.selectTargets(candidates, limit)
    local selected = {}
    for _, candidate in ipairs(candidates or {}) do
        selected[#selected + 1] = candidate
    end

    table.sort(selected, function(left, right)
        local leftDistance = tonumber(left.distance)
            or tonumber(left.m)
            or tonumber(left.studs)
            or math.huge
        local rightDistance = tonumber(right.distance)
            or tonumber(right.m)
            or tonumber(right.studs)
            or math.huge
        if leftDistance ~= rightDistance then
            return leftDistance < rightDistance
        end
        return stableId(left) < stableId(right)
    end)

    local maximum = math.max(0, math.floor(tonumber(limit) or 0))
    local result = {}
    for index = 1, math.min(#selected, maximum) do
        result[#result + 1] = selected[index]
    end
    return result
end

ESPLogic.FEATURE_KEYS = FEATURE_KEYS

return ESPLogic
