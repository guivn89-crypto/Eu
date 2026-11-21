-- Funções puras compartilhadas pela interface. Normalização é limitada aos
-- alfabetos necessários para os idiomas disponíveis, não é Unicode completo.
Library.UISupport = {}
function Library.UISupport.normalize(text)
    text = tostring(text or "")
    local result = {}
    local ok = pcall(function()
        for _, cp in utf8.codes(text) do
            if cp >= 65 and cp <= 90 then cp += 32
            elseif cp == 0x401 then cp = 0x451
            elseif cp >= 0x410 and cp <= 0x42F then cp += 32
            elseif cp >= 0xC0 and cp <= 0xDE and cp ~= 0xD7 then cp += 32 end
            result[#result + 1] = utf8.char(cp)
        end
    end)
    return ok and table.concat(result) or string.lower(text)
end
function Library.UISupport.contrast(a, b)
    local function component(v)
        if type(v) ~= "number" or v ~= v or v < 0 or v > 1 then return nil end
        return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
    end
    local function luminance(c)
        if not c then return nil end
        local r, g, b = component(c.R), component(c.G), component(c.B)
        if not r or not g or not b then return nil end
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    end
    local x, y = luminance(a), luminance(b)
    if not x or not y then return nil end
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05)
end
function Library.UISupport.compact(width, height, touch)
    return touch == true and type(width) == "number" and type(height) == "number" and width > 0 and height > 0 and (width < 620 or width < height)
end
