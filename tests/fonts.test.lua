--[[
    BBC HUB - Font Utilities Tests
    Tests for utils.fonts module
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Mock Font API for testing
local MockFont = {}
MockFont.new = function(family, weight)
    -- Simulate successful Font.new
    return { Family = family, Weight = weight, _mock = true }
end
MockFont.fromEnum = function(enum)
    return { Family = "Fallback", Weight = enum, _mock = true, _fallback = true }
end

-- Replace global Font for testing
_G.Font = MockFont

-- Load the module under test
local FontUtils = require(script.Parent.Parent.src.utils.fonts)

-- Test utilities
local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message or "Assertion failed", tostring(expected), tostring(actual)))
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "Expected truthy value")
    end
end

local function assertFalsy(value, message)
    if value then
        error(message or "Expected falsy value")
    end
end

local function assertTable(value, message)
    if type(value) ~= "table" then
        error(message or "Expected table")
    end
end

-- Test suite
local tests = {}

function tests.test_safeFontNew_returns_font_on_success()
    local font = FontUtils.safeFontNew("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Regular)
    assertTruthy(font, "Should return a font object")
    assertEquals(font.Family, "rbxasset://fonts/families/Arimo.json", "Should have correct family")
    assertEquals(font.Weight, Enum.FontWeight.Regular, "Should have correct weight")
    assertTruthy(font._mock, "Should be mock font")
    print("✓ test_safeFontNew_returns_font_on_success")
end

function tests.test_safeFontNew_fallback_on_error()
    -- Temporarily mock Font.new to throw
    local originalNew = MockFont.new
    MockFont.new = function()
        error("Font.new failed")
    end
    
    local font = FontUtils.safeFontNew("invalid://font", Enum.FontWeight.Bold)
    assertTruthy(font, "Should return fallback font")
    assertTruthy(font._fallback, "Should be fallback font")
    assertEquals(font.Family, "Fallback", "Should have fallback family")
    
    -- Restore
    MockFont.new = originalNew
    print("✓ test_safeFontNew_fallback_on_error")
end

function tests.test_safeFontNew_fallback_on_nil()
    -- Temporarily mock Font.new to return nil
    local originalNew = MockFont.new
    MockFont.new = function()
        return nil
    end
    
    local font = FontUtils.safeFontNew("invalid://font", Enum.FontWeight.Bold)
    assertTruthy(font, "Should return fallback font")
    assertTruthy(font._fallback, "Should be fallback font")
    
    -- Restore
    MockFont.new = originalNew
    print("✓ test_safeFontNew_fallback_on_nil")
end

function tests.test_initDefaultFonts_returns_all_weights()
    local fonts = FontUtils.initDefaultFonts()
    assertTable(fonts, "Should return table")
    assertTruthy(fonts.Regular, "Should have Regular")
    assertTruthy(fonts.Medium, "Should have Medium")
    assertTruthy(fonts.Bold, "Should have Bold")
    assertEquals(fonts.Regular.Weight, Enum.FontWeight.Regular, "Regular weight correct")
    assertEquals(fonts.Medium.Weight, Enum.FontWeight.Medium, "Medium weight correct")
    assertEquals(fonts.Bold.Weight, Enum.FontWeight.Bold, "Bold weight correct")
    print("✓ test_initDefaultFonts_returns_all_weights")
end

function tests.test_ensureFonts_creates_when_missing()
    local Library = {}
    FontUtils.ensureFonts(Library)
    assertTable(Library.Fonts, "Should create Fonts table")
    assertTruthy(Library.Fonts.Regular, "Should have Regular")
    assertTruthy(Library.Fonts.Medium, "Should have Medium")
    assertTruthy(Library.Fonts.Bold, "Should have Bold")
    print("✓ test_ensureFonts_creates_when_missing")
end

function tests.test_ensureFonts_preserves_existing()
    local Library = {
        Fonts = {
            Regular = { _custom = true },
            Medium = { _custom = true },
            Bold = { _custom = true },
        }
    }
    FontUtils.ensureFonts(Library)
    assertTruthy(Library.Fonts.Regular._custom, "Should preserve existing Regular")
    assertTruthy(Library.Fonts.Medium._custom, "Should preserve existing Medium")
    assertTruthy(Library.Fonts.Bold._custom, "Should preserve existing Bold")
    print("✓ test_ensureFonts_preserves_existing")
end

function tests.test_ensureFonts_fills_missing_weights()
    local Library = {
        Fonts = {
            Regular = { _custom = true },
            -- Missing Medium and Bold
        }
    }
    FontUtils.ensureFonts(Library)
    assertTruthy(Library.Fonts.Regular._custom, "Should preserve existing Regular")
    assertTruthy(Library.Fonts.Medium, "Should create missing Medium")
    assertTruthy(Library.Fonts.Bold, "Should create missing Bold")
    print("✓ test_ensureFonts_fills_missing_weights")
end

function tests.test_DEFAULT_FONT_FAMILY_constant()
    assertEquals(FontUtils.DEFAULT_FONT_FAMILY, "rbxasset://fonts/families/Arimo.json", "Default font family should match")
    print("✓ test_DEFAULT_FONT_FAMILY_constant")
end

function tests.test_DEFAULT_WEIGHTS_constant()
    assertEquals(FontUtils.DEFAULT_WEIGHTS.Regular, Enum.FontWeight.Regular, "Regular weight")
    assertEquals(FontUtils.DEFAULT_WEIGHTS.Medium, Enum.FontWeight.Medium, "Medium weight")
    assertEquals(FontUtils.DEFAULT_WEIGHTS.SemiBold, Enum.FontWeight.SemiBold, "SemiBold weight")
    assertEquals(FontUtils.DEFAULT_WEIGHTS.Bold, Enum.FontWeight.Bold, "Bold weight")
    print("✓ test_DEFAULT_WEIGHTS_constant")
end

function tests.test_FALLBACK_FONT_constant()
    assertEquals(FontUtils.FALLBACK_FONT, Enum.Font.Code, "Fallback should be Enum.Font.Code")
    print("✓ test_FALLBACK_FONT_constant")
end

-- Run tests
print("Running FontUtils tests...")
print("")

local passed = 0
local failed = 0

for name, testFn in pairs(tests) do
    local ok, err = pcall(testFn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("✗ " .. name .. ": " .. tostring(err))
    end
end

print("")
print(string.format("Results: %d passed, %d failed", passed, failed))

if failed > 0 then
    error("Some tests failed")
end