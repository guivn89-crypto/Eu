--!strict
--[[
    BBC HUB - ESP configuration
    Defaults, validation, change events and pure target-filter helpers.
]]

local ESPConfig = {}

local KINDS = { "Jogador", "NPCs", "Corpo", "Recipiente", "Item no chão", "Itens de missão" }
local listeners = {}
local activeLibrary = nil

local function rgb(red, green, blue)
    if type(Color3) == "table" and type(Color3.fromRGB) == "function" then
        return Color3.fromRGB(red, green, blue)
    end
    return { R = red / 255, G = green / 255, B = blue / 255 }
end

local ORANGE = rgb(255, 130, 0)
local BLACK = rgb(0, 0, 0)
local WHITE = rgb(242, 242, 242)
local CYAN = rgb(45, 205, 190)
local GREEN = rgb(70, 220, 90)

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

local function mergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            mergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = cloneValue(value)
        end
    end
    return target
end

local function needsDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" or needsDefaults(target[key], value) then
                return true
            end
        elseif target[key] == nil then
            return true
        end
    end
    return false
end

local function newDefaults()
    return {
        enabled = false,
        maxDist = 1000,
        teamCheck = false,
        ignoreDead = true,
        rainbow = false,
        primaryColor = ORANGE,
        textSize = 12,
        prevDist = 1133,
        prevHp = 100,
        frozen = false,
        locked = false,
        highlight = {
            on = false,
            color = ORANGE,
            fillTransparency = 0.55,
            outlineTransparency = 0,
            outlineColor = BLACK,
        },
        box = {
            on = false,
            color = WHITE,
            thick = 1,
            style = "Completa",
            corner = 14,
            alpha = 0.5,
        },
        name = {
            on = false,
            color = WHITE,
            size = 12,
            outline = true,
        },
        healthbar = {
            on = false,
            auto = true,
            color = CYAN,
            width = 4,
            side = "Esquerda",
        },
        health = {
            on = false,
            color = GREEN,
            size = 11,
        },
        distance = {
            on = false,
            color = WHITE,
            unit = "m",
            size = 12,
            outline = true,
        },
        tracers = {
            on = false,
            color = WHITE,
            thick = 1,
            origin = "Baixo",
        },
        skeleton = {
            on = false,
            color = WHITE,
            thick = 1.5,
        },
        lod = {
            on = true,
            near = 150,
        },
        nearest = {
            on = false,
            color = rgb(255, 60, 60),
        },
    }
end

local NUMBER_LIMITS = {
    maxDist = { 100, 5000 },
    textSize = { 8, 20 },
    prevDist = { 10, 5000 },
    prevHp = { 0, 100 },
    fillTransparency = { 0, 1 },
    outlineTransparency = { 0, 1 },
    alpha = { 0, 1 },
    thick = { 1, 4 },
    corner = { 4, 30 },
    width = { 2, 10 },
    size = { 8, 20 },
    near = { 20, 1000 },
}

local BOOLEAN_KEYS = {
    enabled = true,
    on = true,
    auto = true,
    teamCheck = true,
    ignoreDead = true,
    rainbow = true,
    frozen = true,
    locked = true,
}

local ALLOWED_VALUES = {
    style = { Completa = true, Cantos = true },
    side = { Esquerda = true, Direita = true },
    unit = { m = true, studs = true },
    origin = { Baixo = true, Centro = true, Topo = true, Cima = true },
}

local ALLOWED_PATHS = {}
local function allow(path)
    ALLOWED_PATHS[path] = true
end

for _, path in ipairs({
    "enabled", "maxDist", "teamCheck", "ignoreDead", "rainbow", "primaryColor",
    "textSize", "prevDist", "prevHp", "frozen", "locked",
}) do
    allow(path)
end

for _, group in ipairs({
    { "highlight", { "on", "color", "fillTransparency", "outlineTransparency", "outlineColor" } },
    { "box", { "on", "color", "thick", "style", "corner", "alpha" } },
    { "name", { "on", "color", "size", "outline" } },
    { "healthbar", { "on", "auto", "color", "width", "side" } },
    { "health", { "on", "color", "size" } },
    { "distance", { "on", "color", "unit", "size", "outline" } },
    { "tracers", { "on", "color", "thick", "origin" } },
    { "skeleton", { "on", "color", "thick" } },
    { "lod", { "on", "near" } },
    { "nearest", { "on", "color" } },
}) do
    for _, key in ipairs(group[2]) do
        allow(group[1] .. "." .. key)
    end
end

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function isColor(value)
    local valueType = type(value)
    if valueType ~= "table" and valueType ~= "userdata" then
        return false
    end
    return type(value.R) == "number"
        and type(value.G) == "number"
        and type(value.B) == "number"
end

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function colorsEqual(left, right)
    if left == right then return true end
    if not isColor(left) or not isColor(right) then return false end
    return math.abs(left.R - right.R) < 0.0001
        and math.abs(left.G - right.G) < 0.0001
        and math.abs(left.B - right.B) < 0.0001
end

local function valuesEqual(left, right)
    if type(left) == "number" and type(right) == "number" then
        return math.abs(left - right) < 0.000001
    end
    if isColor(left) and isColor(right) then
        return colorsEqual(left, right)
    end
    return left == right
end

local function pathParts(path)
    local parts = {}
    for part in string.gmatch(tostring(path or ""), "[^%.]+") do
        parts[#parts + 1] = part
    end
    return parts
end

local function readPath(root, parts)
    local current = root
    for _, part in ipairs(parts) do
        if type(current) ~= "table" then
            return nil
        end
        current = current[part]
        if current == nil then
            return nil
        end
    end
    return current
end

local function writePath(root, parts, value)
    local current = root
    for index = 1, #parts - 1 do
        local part = parts[index]
        if type(current[part]) ~= "table" then
            current[part] = {}
        end
        current = current[part]
    end
    current[parts[#parts]] = value
end

local function validateValue(parts, value)
    local path = table.concat(parts, ".")
    local key = parts[#parts]

    -- `outline` is numeric only for the legacy Chams thickness field. On name
    -- and distance labels it is a boolean outline switch.
    if path == "name.outline" or path == "distance.outline" then
        return type(value) == "boolean" and value or nil
    end

    if BOOLEAN_KEYS[key] then
        return type(value) == "boolean" and value or nil
    end

    local limits = NUMBER_LIMITS[key]
    if limits then
        if not isFiniteNumber(value) then
            return nil
        end
        return clamp(value, limits[1], limits[2])
    end

    local allowed = ALLOWED_VALUES[key]
    if allowed then
        return type(value) == "string" and allowed[value] and value or nil
    end

    if key == "color" or key == "outlineColor" or key == "primaryColor" then
        return isColor(value) and value or nil
    end

    return value
end

local function emit(kind, path, value, oldValue)
    for index = #listeners, 1, -1 do
        local listener = listeners[index]
        if listener then
            local ok, err = pcall(listener.callback, kind, path, value, oldValue)
            if not ok then
                warn("[BBC][ESPConfig] listener failed: " .. tostring(err))
            end
        end
    end
end

function ESPConfig.ensureDefaults(library)
    library = library or (type(BBC) == "table" and BBC.Library or nil)
    if type(library) ~= "table" then
        return {}
    end
    activeLibrary = library

    if type(library.ESP) ~= "table" then
        library.ESP = {}
        if type(BBC) == "table" then
            BBC.ESP = library.ESP
        end
    end

    for _, kind in ipairs(KINDS) do
        local current = type(library.ESP[kind]) == "table" and library.ESP[kind] or {}
        if needsDefaults(current, newDefaults()) then
            library.ESP[kind] = mergeDefaults(cloneValue(current), newDefaults())
        end
    end

    return library.ESP
end

function ESPConfig.get(kind, path, fallback)
    local library = activeLibrary or (type(BBC) == "table" and BBC.Library or nil)
    local settings = library and library.ESP and library.ESP[kind]
    if type(settings) ~= "table" then
        return fallback
    end
    local value = readPath(settings, pathParts(path))
    if value == nil then
        return fallback
    end
    return value
end

function ESPConfig.set(kind, path, value)
    local library = activeLibrary or (type(BBC) == "table" and BBC.Library or nil)
    local settings = library and library.ESP and library.ESP[kind]
    if type(settings) ~= "table" then
        return nil
    end

    local parts = pathParts(path)
    if #parts == 0 then
        return nil
    end

    local normalizedPath = table.concat(parts, ".")
    if not ALLOWED_PATHS[normalizedPath] then
        return nil
    end

    local validated = validateValue(parts, value)
    if validated == nil then
        return nil
    end

    local oldValue = readPath(settings, parts)
    if oldValue ~= nil and valuesEqual(oldValue, validated) then
        return validated
    end

    local updated = cloneValue(settings)
    writePath(updated, parts, validated)
    library.ESP[kind] = updated
    emit(kind, normalizedPath, validated, oldValue)
    return validated
end

function ESPConfig.setMany(kind, values)
    if type(values) ~= "table" then
        return
    end

    local library = activeLibrary or (type(BBC) == "table" and BBC.Library or nil)
    local settings = library and library.ESP and library.ESP[kind]
    if type(settings) ~= "table" then
        return
    end

    local paths = {}
    for path in pairs(values) do
        paths[#paths + 1] = path
    end
    table.sort(paths)

    local updated = cloneValue(settings)
    local changes = {}
    for _, path in ipairs(paths) do
        local parts = pathParts(path)
        local normalizedPath = table.concat(parts, ".")
        if #parts > 0 and ALLOWED_PATHS[normalizedPath] then
            local validated = validateValue(parts, values[path])
            if validated ~= nil then
                local oldValue = readPath(updated, parts)
                if oldValue == nil or not valuesEqual(oldValue, validated) then
                    writePath(updated, parts, validated)
                    changes[#changes + 1] = { path = normalizedPath, value = validated, oldValue = oldValue }
                end
            end
        end
    end

    if #changes == 0 then
        return
    end
    library.ESP[kind] = updated
    for _, change in ipairs(changes) do
        emit(kind, change.path, change.value, change.oldValue)
    end
end

function ESPConfig.onChange(callback)
    if type(callback) ~= "function" then
        return function() end
    end

    local listener = { callback = callback }
    listeners[#listeners + 1] = listener
    return function()
        for index = #listeners, 1, -1 do
            if listeners[index] == listener then
                table.remove(listeners, index)
                break
            end
        end
    end
end

function ESPConfig.applyPrimaryColor(kind, color)
    if not isColor(color) then
        return false
    end

    ESPConfig.setMany(kind, {
        ["primaryColor"] = color,
        ["highlight.color"] = color,
        ["box.color"] = color,
        ["name.color"] = color,
        ["distance.color"] = color,
        ["tracers.color"] = color,
        ["skeleton.color"] = color,
    })
    return true
end

function ESPConfig.snapshot(kind)
    local library = activeLibrary or (type(BBC) == "table" and BBC.Library or nil)
    local settings = library and library.ESP and library.ESP[kind]
    return type(settings) == "table" and cloneValue(settings) or {}
end

function ESPConfig.isPlayerOwnedCharacter(character, players)
    if character == nil or type(players) ~= "table" then
        return false
    end
    local ok, player = pcall(function()
        return players:GetPlayerFromCharacter(character)
    end)
    return ok and player ~= nil
end

function ESPConfig.shouldIncludeTarget(target, localPlayer, settings)
    if type(target) ~= "table" or type(settings) ~= "table" then
        return false
    end

    local humanoid = target.humanoid or target.hum
    if humanoid == nil then
        return false
    end

    if settings.ignoreDead and humanoid.Health <= 0 then
        return false
    end

    if settings.teamCheck then
        local targetPlayer = target.player
        local localTeam = localPlayer and localPlayer.Team
        local targetTeam = targetPlayer and targetPlayer.Team
        if localTeam ~= nil and targetTeam ~= nil then
            local sameTeam = localTeam == targetTeam
            if not sameTeam and type(localTeam.Name) == "string" and type(targetTeam.Name) == "string" then
                sameTeam = localTeam.Name == targetTeam.Name
            end
            if sameTeam then
                return false
            end
        end
    end

    return true
end

ESPConfig.KINDS = KINDS
ESPConfig.defaults = newDefaults

if type(BBC) == "table" and type(BBC.Library) == "table" then
    ESPConfig.ensureDefaults(BBC.Library)
end

return ESPConfig
