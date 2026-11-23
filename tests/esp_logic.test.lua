--[[
    BBC HUB - Pure ESP candidate logic tests
]]

local loaded, ESPLogic = pcall(require, "../src/utils/esp_logic")
if not loaded then
    ESPLogic = require("./src/utils/esp_logic")
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
    if not value then error(message or "expected truthy value") end
end

local function assertFalsy(value, message)
    if value then error(message or "expected falsy value") end
end

test("duplicate model is reconciled with player priority", function()
    local model = { Name = "SharedCharacter" }
    local playerCandidate = { model = model, player = { Name = "Player" }, name = "Player" }
    local npcCandidate = { model = model, name = "NPC" }

    local result = ESPLogic.reconcileCandidates({ playerCandidate }, { npcCandidate }, nil)
    assertEquals(#result, 1, "one candidate")
    assertEquals(result[1].kind, "Jogador", "player classification wins")
    assertEquals(result[1].candidate.player.Name, "Player", "player data preserved")
end)

test("local character and player-owned reclassified models are excluded", function()
    local localModel = { Name = "Local" }
    local localCandidate = { model = localModel, player = { Name = "LocalPlayer" } }
    local result = ESPLogic.reconcileCandidates({ localCandidate }, {}, localModel)
    assertEquals(#result, 0, "local model excluded")
end)

test("display names do not collapse distinct models", function()
    local first = { model = { Name = "First" }, player = { Name = "Same" }, name = "Same" }
    local second = { model = { Name = "Second" }, player = { Name = "Same" }, name = "Same" }
    local result = ESPLogic.reconcileCandidates({ first, second }, {}, nil)
    assertEquals(#result, 2, "distinct models preserved")
end)

test("global target limit is deterministic", function()
    local candidates = {}
    for index = 1, 5 do
        candidates[index] = {
            model = { Name = "Model" .. index },
            distance = index,
            stableId = tostring(index),
        }
    end

    local selected = ESPLogic.selectTargets(candidates, 3)
    assertEquals(#selected, 3, "limit applied")
    assertEquals(selected[1].distance, 1, "closest selected first")
    assertEquals(selected[3].distance, 3, "third closest selected")
end)

test("engine distance fields are accepted for closest-first ordering", function()
    local candidates = {
        { model = { Name = "Far" }, m = 90, stableId = "far" },
        { model = { Name = "Near" }, m = 10, stableId = "near" },
        { model = { Name = "Middle" }, m = 50, stableId = "middle" },
    }

    local selected = ESPLogic.selectTargets(candidates, 2)
    assertEquals(selected[1].stableId, "near", "nearest candidate selected first")
    assertEquals(selected[2].stableId, "middle", "second-nearest candidate selected")
end)

test("equal distances use a stable identity tie breaker", function()
    local first = { model = { Name = "A" }, distance = 10, stableId = "A" }
    local second = { model = { Name = "B" }, distance = 10, stableId = "B" }
    local selected = ESPLogic.selectTargets({ second, first }, 2)
    assertEquals(selected[1].stableId, "A", "stable tie breaker")
    assertEquals(selected[2].stableId, "B", "stable tie breaker second")
end)

test("global text size scales feature text sizes", function()
    local settings = { textSize = 18 }
    assertEquals(ESPLogic.scaledTextSize(settings, 12), 18, "twelve point base scales to eighteen")
    assertEquals(ESPLogic.scaledTextSize({ textSize = 6 }, 12), 8, "scaled text has a readable minimum")
    assertEquals(ESPLogic.scaledTextSize({ textSize = 20 }, 20), 24, "scaled text has a safe maximum")
end)

test("feature flag updates reject unknown keys", function()
    local original = { enabled = true, highlight = { on = false } }
    local updated = ESPLogic.setEspFlag(original, "highlight", true)
    assertEquals(updated.highlight.on, true, "known feature updated")
    assertEquals(original.highlight.on, false, "input remains immutable")
    assertEquals(ESPLogic.setEspFlag(original, "unknown", true), nil, "unknown key rejected")
end)

test("master toggle preserves subfeature state", function()
    local original = { enabled = true, highlight = { on = true }, box = { on = false } }
    local updated = ESPLogic.setEspFlag(original, "enabled", false)
    assertEquals(updated.enabled, false, "master disabled")
    assertEquals(updated.highlight.on, true, "highlight state preserved")
    assertEquals(updated.box.on, false, "box state preserved")
end)

print(string.format("ESPLogic: %d passed, %d failed", passed, failed))
if failed > 0 then error("ESPLogic tests failed") end
