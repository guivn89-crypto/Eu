--[[
    BBC HUB - ESP configuration tests
    Runs in plain Lua with small Roblox API mocks.
]]

local function rgb(r, g, b)
    return { R = r / 255, G = g / 255, B = b / 255 }
end

local loaded, ESPConfig = pcall(require, "../src/utils/esp_config")
if not loaded then
    ESPConfig = require("./src/utils/esp_config")
end
local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value")
    end
end

local function assertFalsy(value, message)
    if value then
        error(message or "expected falsy value")
    end
end

test("defaults include safe chams values", function()
    local library = { ESP = {} }
    ESPConfig.ensureDefaults(library)

    local settings = library.ESP.Jogador
    assertEquals(settings.highlight.fillTransparency, 0.55, "default fill transparency")
    assertEquals(settings.highlight.outlineTransparency, 0, "default outline transparency")
    assertEquals(settings.highlight.outlineColor.R, 0, "default outline red")
    assertEquals(settings.highlight.outlineColor.G, 0, "default outline green")
    assertEquals(settings.highlight.outlineColor.B, 0, "default outline blue")
    assertEquals(settings.maxDist, 1000, "default max distance")
    assertEquals(settings.ignoreDead, true, "dead targets ignored by default")
    assertEquals(settings.teamCheck, false, "team check disabled by default")
end)

test("ensure defaults preserves existing values", function()
    local library = {
        ESP = {
            Jogador = {
                maxDist = 2500,
                highlight = { fillTransparency = 0.25 },
            },
        },
    }
    ESPConfig.ensureDefaults(library)

    assertEquals(library.ESP.Jogador.maxDist, 2500, "existing scalar preserved")
    assertEquals(library.ESP.Jogador.highlight.fillTransparency, 0.25, "existing nested value preserved")
    assertEquals(library.ESP.Jogador.highlight.outlineTransparency, 0, "missing nested default added")
end)

test("set validates nested values and emits changes", function()
    local library = { ESP = {} }
    ESPConfig.ensureDefaults(library)

    local seen = {}
    local originalTable = library.ESP.Jogador
    local unsubscribe = ESPConfig.onChange(function(kind, path, value, oldValue)
        seen.kind = kind
        seen.path = path
        seen.value = value
        seen.oldValue = oldValue
    end)

    ESPConfig.set("Jogador", "highlight.fillTransparency", 2)
    assertEquals(seen.path, "highlight.fillTransparency", "event path")
    assertEquals(seen.value, 1, "value clamped to upper bound")
    assertEquals(seen.oldValue, 0.55, "old value reported")

    ESPConfig.set("Jogador", "highlight.fillTransparency", -1)
    assertEquals(library.ESP.Jogador.highlight.fillTransparency, 0, "value clamped to lower bound")
    assertTruthy(library.ESP.Jogador ~= originalTable, "configuration table is replaced")
    assertEquals(originalTable.highlight.fillTransparency, 0.55, "previous table remains immutable")

    assertEquals(ESPConfig.set("Jogador", "unknown.on", true), nil, "unknown path rejected")
    assertEquals(ESPConfig.set("Jogador", "box.color", { X = 1, Y = 2, Z = 3 }), nil, "non-color value rejected")
    assertEquals(ESPConfig.set("Jogador", "maxDist", 0 / 0), nil, "non-finite number rejected")

    unsubscribe()
    ESPConfig.set("Jogador", "highlight.fillTransparency", 0.3)
    assertEquals(seen.value, 0, "unsubscribed listener is not called")
end)

test("primary color updates every visual color", function()
    local library = { ESP = {} }
    ESPConfig.ensureDefaults(library)

    local primary = rgb(12, 34, 56)
    ESPConfig.applyPrimaryColor("Jogador", primary)

    local settings = library.ESP.Jogador
    assertEquals(settings.primaryColor.R, primary.R, "primary red")
    assertEquals(settings.highlight.color.R, primary.R, "highlight red")
    assertEquals(settings.box.color.G, primary.G, "box green")
    assertEquals(settings.name.color.B, primary.B, "name blue")
    assertEquals(settings.distance.color.R, primary.R, "distance red")
    assertEquals(settings.tracers.color.G, primary.G, "tracer green")
    assertEquals(settings.skeleton.color.B, primary.B, "skeleton blue")
end)

test("player-owned characters are detected as player characters", function()
    local playerCharacter = { Name = "PlayerCharacter" }
    local npcCharacter = { Name = "NpcCharacter" }
    local players = {
        GetPlayerFromCharacter = function(_, character)
            return character == playerCharacter and { Name = "Player" } or nil
        end,
    }

    assertTruthy(ESPConfig.isPlayerOwnedCharacter(playerCharacter, players), "player character detected")
    assertFalsy(ESPConfig.isPlayerOwnedCharacter(npcCharacter, players), "NPC character is not player-owned")
end)

test("target filter honors dead and team settings", function()
    local localPlayer = {
        Team = { Name = "Blue" },
    }
    local teammate = {
        Team = { Name = "Blue" },
    }
    local enemy = {
        Team = { Name = "Red" },
    }
    local deadTarget = { player = enemy, humanoid = { Health = 0 } }
    local livingEnemy = { player = enemy, humanoid = { Health = 75 } }
    local livingTeammate = { player = teammate, humanoid = { Health = 75 } }

    assertFalsy(ESPConfig.shouldIncludeTarget(deadTarget, localPlayer, { ignoreDead = true }), "dead target skipped")
    assertTruthy(ESPConfig.shouldIncludeTarget(deadTarget, localPlayer, { ignoreDead = false }), "dead target allowed")
    assertFalsy(ESPConfig.shouldIncludeTarget(livingTeammate, localPlayer, { teamCheck = true }), "teammate skipped")
    assertTruthy(ESPConfig.shouldIncludeTarget(livingEnemy, localPlayer, { teamCheck = true }), "enemy allowed")
end)

print(string.format("ESPConfig: %d passed, %d failed", passed, failed))
if failed > 0 then
    error("ESPConfig tests failed")
end
