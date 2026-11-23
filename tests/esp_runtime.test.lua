--[[
    BBC HUB - Pure ESP runtime registry tests
]]

local loaded, ESPRuntime = pcall(require, "../src/utils/esp_runtime")
if not loaded then
    ESPRuntime = require("./src/utils/esp_runtime")
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

local function newDrawing()
    local drawing = {
        hidden = false,
        hiddenFeature = nil,
        destroyed = false,
        hideAll = function(self)
            self.hidden = true
        end,
        hideFeature = function(self, feature)
            self.hiddenFeature = feature
        end,
        destroy = function(self)
            self.destroyed = true
        end,
    }
    return drawing
end

test("registering the same model returns one drawing", function()
    local runtime = ESPRuntime.new()
    local model = { Name = "Character" }
    local first = newDrawing()
    local second = newDrawing()

    local registered, created = runtime:register(model, "Jogador", first)
    assertTruthy(registered, "drawing registered")
    assertTruthy(created, "first drawing created")
    local duplicate, duplicateCreated = runtime:register(model, "NPCs", second)
    assertEquals(duplicate, first, "same drawing returned")
    assertFalsy(duplicateCreated, "duplicate not created")
    assertEquals(runtime:count(), 1, "one model record")
end)

test("highlight acquisition is idempotent per model", function()
    local runtime = ESPRuntime.new()
    local model = { Name = "Character" }
    local created = 0
    local factory = function()
        created = created + 1
        return { destroyed = false }
    end

    local first = runtime:ensureHighlight(model, factory)
    local second = runtime:ensureHighlight(model, factory)
    assertEquals(first, second, "same highlight returned")
    assertEquals(created, 1, "highlight created once")
    assertEquals(runtime:highlightCount(), 1, "one highlight record")
end)

test("master off hides every drawing for that kind synchronously", function()
    local runtime = ESPRuntime.new()
    local playerDrawing = newDrawing()
    local npcDrawing = newDrawing()
    runtime:register({ Name = "Player" }, "Jogador", playerDrawing)
    runtime:register({ Name = "NPC" }, "NPCs", npcDrawing)

    runtime:hideKind("Jogador")
    assertTruthy(playerDrawing.hidden, "player drawing hidden")
    assertFalsy(npcDrawing.hidden, "NPC drawing untouched")
end)

test("subfeature off hides only that feature", function()
    local runtime = ESPRuntime.new()
    local drawing = newDrawing()
    runtime:register({ Name = "Player" }, "Jogador", drawing)

    runtime:hideFeature("Jogador", "highlight")
    assertEquals(drawing.hiddenFeature, "highlight", "feature hidden")
    assertFalsy(drawing.hidden, "master drawing remains visible")
end)

test("release destroys drawing and highlight exactly once", function()
    local runtime = ESPRuntime.new()
    local model = { Name = "Character" }
    local drawing = newDrawing()
    local highlight = {
        destroyed = false,
        destroy = function(self)
            self.destroyed = true
        end,
    }
    runtime:register(model, "Jogador", drawing)
    runtime:ensureHighlight(model, function() return highlight end)

    runtime:release(model)
    assertTruthy(drawing.destroyed, "drawing destroyed")
    assertTruthy(highlight.destroyed, "highlight destroyed")
    assertEquals(runtime:count(), 0, "record removed")
    assertEquals(runtime:highlightCount(), 0, "highlight removed")

    runtime:release(model)
    assertEquals(runtime:count(), 0, "release is idempotent")
end)

test("destroy all clears every record", function()
    local runtime = ESPRuntime.new()
    local drawing = newDrawing()
    runtime:register({ Name = "Character" }, "Jogador", drawing)
    runtime:destroyAll()
    assertEquals(runtime:count(), 0, "records cleared")
    assertTruthy(drawing.destroyed, "drawing destroyed")
end)

print(string.format("ESPRuntime: %d passed, %d failed", passed, failed))
if failed > 0 then error("ESPRuntime tests failed") end
