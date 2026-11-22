--[[
    BBC HUB - Shared Initialization Utilities
    Common setup functions used across modules.
]]

local InitUtils = {}

--[[
    Ensures Library.Fonts is initialized with fallback fonts.
    Call this at the top of any module that accesses Library.Fonts.
    @param library table - BBC.Library table (or any table with Fonts field)
    @return table - Library.Fonts table
]]
function InitUtils.ensureFonts(library)
    local FontUtils = BBC.Modules["utils.fonts"]
    if FontUtils and FontUtils.ensureFonts then
        FontUtils.ensureFonts(library)
    end
    return library.Fonts
end

--[[
    Ensures a module is loaded and returns it, with optional fallback.
    @param modulePath string - Path like "utils.fonts"
    @param fallback any - Optional fallback value if module not found
    @return any - The module or fallback
]]
function InitUtils.getModule(modulePath, fallback)
    return BBC.Modules[modulePath] or fallback
end

return InitUtils