--[[
    BBC HUB - Font Utilities
    Shared font loading with fallback for executor compatibility (Delta, etc.)
]]

local FontUtils = {}

-- Default font configuration
FontUtils.DEFAULT_FONT_FAMILY = "rbxasset://fonts/families/Arimo.json"
FontUtils.DEFAULT_WEIGHTS = {
    Regular = Enum.FontWeight.Regular,
    Medium = Enum.FontWeight.Medium,
    SemiBold = Enum.FontWeight.SemiBold,
    Bold = Enum.FontWeight.Bold,
}

-- Fallback font (works in all executors including Delta)
FontUtils.FALLBACK_FONT = Enum.Font.Code

--[[
    Safely create a Font object with fallback.
    @param fontFamily string - Font family path (e.g., "rbxasset://fonts/families/Arimo.json")
    @param fontWeight Enum.FontWeight - Font weight
    @return Font - Created font or fallback
]]
function FontUtils.safeFontNew(fontFamily, fontWeight)
    local ok, font = pcall(function()
        return Font.new(fontFamily, fontWeight)
    end)
    if ok and font then return font end
    warn("[BBC] Font.new failed for " .. tostring(fontFamily) .. " weight " .. tostring(fontWeight) .. ", using fallback")
    return Font.fromEnum(FontUtils.FALLBACK_FONT)
end

--[[
    Initialize default Arimo fonts (Regular, Medium, Bold).
    @return table - Fonts table with Regular, Medium, Bold keys
]]
function FontUtils.initDefaultFonts()
    return {
        Regular = FontUtils.safeFontNew(FontUtils.DEFAULT_FONT_FAMILY, FontUtils.DEFAULT_WEIGHTS.Regular),
        Medium = FontUtils.safeFontNew(FontUtils.DEFAULT_FONT_FAMILY, FontUtils.DEFAULT_WEIGHTS.Medium),
        Bold = FontUtils.safeFontNew(FontUtils.DEFAULT_FONT_FAMILY, FontUtils.DEFAULT_WEIGHTS.Bold),
    }
end

--[[
    Ensure Library.Fonts exists with valid fonts (defensive initialization).
    Should only be called if theme.lua hasn't initialized fonts yet.
    @param Library table - BBC.Library table
    @return table - Library.Fonts table
]]
function FontUtils.ensureFonts(Library)
    if not Library.Fonts or not Library.Fonts.Bold then
        warn("[BBC] Library.Fonts not yet available, creating fallback fonts")
        Library.Fonts = Library.Fonts or {}
        Library.Fonts.Regular = Library.Fonts.Regular or FontUtils.safeFontNew(FontUtils.DEFAULT_FONT_FAMILY, FontUtils.DEFAULT_WEIGHTS.Regular)
        Library.Fonts.Medium = Library.Fonts.Medium or FontUtils.safeFontNew(FontUtils.DEFAULT_FONT_FAMILY, FontUtils.DEFAULT_WEIGHTS.Medium)
        Library.Fonts.Bold = Library.Fonts.Bold or FontUtils.safeFontNew(FontUtils.DEFAULT_FONT_FAMILY, FontUtils.DEFAULT_WEIGHTS.Bold)
    end
    return Library.Fonts
end

--[[
    Load custom fonts from URLs (used by Library:LoadFont).
    @param weights table - { weightName = url } mapping
    @return table - { weightName = Font } mapping or nil on failure
]]
function FontUtils.loadCustomFonts(weights)
    if type(weights) ~= "table" then return nil end
    
    local faces = {}
    for weightName, url in pairs(weights) do
        local weightInfo = FontUtils.DEFAULT_WEIGHTS[weightName]
        if weightInfo then
            -- This would need writefile/isfile/getcustomasset which aren't available here
            -- Implementation delegated to Library:LoadFont in theme.lua
        end
    end
    return faces
end

return FontUtils