--[[
    BBC HUB - Theme / Core Library
    Fonte única de verdade do estado da biblioteca: fontes, temas, bindings,
    registro de controles, keybinds e ciclo de FPS.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Library = {
    Windows = {},
    Registry = {},
    _themeListeners = {},
    _bindings = {},
    ThemeName = "Orange",
    Theme = {},
    Access = "FREE",
    Keybinds = {},
    _kbListeners = {},
    Tr = function(text)
        return text
    end,
}

function Library:_kbChanged()
    for _, callback in ipairs(Library._kbListeners) do
        pcall(callback)
    end
end

-- ---------- Fontes ----------
Library.Fonts = {
    Regular = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Regular),
    Medium = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Medium),
    Bold = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold),
}

local FONT_WEIGHTS = {
    Regular = { 400, Enum.FontWeight.Regular },
    Medium = { 500, Enum.FontWeight.Medium },
    SemiBold = { 600, Enum.FontWeight.SemiBold },
    Bold = { 700, Enum.FontWeight.Bold },
}

function Library:LoadFont(opts)
    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[BBC] fontes personalizadas precisam de writefile, isfile e getcustomasset")
        return false
    end
    local name = opts.Name or "CustomFont"
    local weights = opts.Weights
    if type(weights) ~= "table" then
        return false
    end
    local folder = "BBC_HUB_Fontes"
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
            makefolder(folder)
        end
    end)
    local faces = {}
    for weightName, url in pairs(weights) do
        local info = FONT_WEIGHTS[weightName]
        if info then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true
            if not isfile(path) then
                ok = pcall(function()
                    writefile(path, game:HttpGet(url))
                end)
            end
            if ok then
                table.insert(faces, {
                    name = weightName,
                    weight = info[1],
                    style = "normal",
                    assetId = getcustomasset(path),
                })
            end
        end
    end
    if #faces == 0 then
        return false
    end
    local familyPath = folder .. "/" .. name .. ".json"
    if not pcall(function()
        writefile(familyPath, HttpService:JSONEncode({ name = name, faces = faces }))
    end) then
        return false
    end
    local family = getcustomasset(familyPath)
    local function face(weightName, fallback)
        local info = FONT_WEIGHTS[weightName]
        if info and weights[weightName] then
            return Font.new(family, info[2])
        end
        return fallback
    end
    Library.Fonts.Regular = face("Regular", Library.Fonts.Regular)
    Library.Fonts.Medium = face("Medium", face("Regular", Library.Fonts.Medium))
    Library.Fonts.Bold = face("Bold", face("SemiBold", Library.Fonts.Bold))
    return true
end

-- ---------- Temas ----------
local function preset(accent, mode, backgroundOverride)
    local hue = accent:ToHSV()
    local function derive(saturation, value)
        if mode == "neutral" then
            return Color3.fromHSV(0, 0, value)
        end
        return Color3.fromHSV(hue, saturation, value)
    end
    local theme = {
        Accent = accent,
        Background = derive(0.55, 0.04),
        Surface = derive(0.55, 0.055),
        Surface2 = derive(0.5, 0.08),
        Surface3 = derive(0.45, 0.125),
        Stroke = derive(0.45, 0.2),
        Text = Color3.fromRGB(242, 242, 242),
        Muted = Color3.fromRGB(150, 150, 150),
        Warning = Color3.fromRGB(240, 176, 108),
        Error = Color3.fromRGB(240, 100, 100),
    }
    if backgroundOverride then
        for key, value in pairs(backgroundOverride) do
            theme[key] = value
        end
    end
    return theme
end

Library.ThemeOrder = {
    "Gold", "Purple", "Yellow", "Red", "Blue", "Orange", "Green",
    "Halloween", "Ocean", "Mono", "Cyan", "Pink", "Copper",
}

Library.ThemePresets = {
    Gold = preset(Color3.fromRGB(255, 192, 40), "neutral"),
    Purple = preset(Color3.fromRGB(150, 100, 255), "tint"),
    Yellow = preset(Color3.fromRGB(240, 232, 60), "neutral"),
    Red = preset(Color3.fromRGB(240, 52, 72), "tint"),
    Blue = preset(Color3.fromRGB(80, 125, 255), "tint"),
    Orange = preset(Color3.fromRGB(255, 130, 25), "neutral"),
    Green = preset(Color3.fromRGB(45, 215, 105), "tint"),
    Halloween = preset(Color3.fromRGB(255, 120, 10), "tint", {
        Background = Color3.fromRGB(14, 8, 22),
        Surface = Color3.fromRGB(19, 11, 30),
        Surface2 = Color3.fromRGB(27, 16, 42),
        Surface3 = Color3.fromRGB(40, 26, 60),
        Stroke = Color3.fromRGB(58, 38, 84),
    }),
    Cyan = preset(Color3.fromRGB(30, 175, 245), "tint"),
    Mono = preset(Color3.fromRGB(235, 235, 235), "neutral"),
    Pink = preset(Color3.fromRGB(242, 85, 175), "tint"),
    Ocean = preset(Color3.fromRGB(40, 120, 255), "tint"),
    Copper = preset(Color3.fromRGB(222, 150, 62), "neutral"),
}

for key, value in pairs(Library.ThemePresets.Orange) do
    Library.Theme[key] = value
end

local function bind(instance, property, key)
    local resolver = type(key) == "function" and key or function()
        return Library.Theme[key]
    end
    instance[property] = resolver()
    Library._bindings[#Library._bindings + 1] = { instance, property, resolver }
end

function Library:SetTheme(name)
    local palette = Library.ThemePresets[name]
    if not palette then
        return
    end
    Library.ThemeName = name
    for key, value in pairs(palette) do
        Library.Theme[key] = value
    end
    for index = #Library._bindings, 1, -1 do
        local binding = Library._bindings[index]
        if binding[1] and binding[1].Parent then
            pcall(function()
                binding[1][binding[2]] = binding[3]()
            end)
        else
            table.remove(Library._bindings, index)
        end
    end
    for _, callback in ipairs(Library._themeListeners) do
        pcall(callback)
    end
end

-- ---------- Servidores ----------
function Library:FetchServers(order, cursor)
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100%s",
        game.PlaceId,
        order or "Desc",
        cursor and ("&cursor=" .. cursor) or ""
    )
    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)
    if not ok or type(body) ~= "string" then
        return nil
    end
    local decoded, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then
        return nil
    end
    return data.data, data.nextPageCursor
end

function Library:JoinServer(jobId)
    return pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    end)
end

-- ---------- FPS compartilhado ----------
Library._fps = 60
do
    local frames, last = 0, os.clock()
    RunService.RenderStepped:Connect(function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then
            Library._fps = math.floor(frames / (now - last) + 0.5)
            frames = 0
            last = now
        end
    end)
end

-- ---------- Integração com a camada de desenho ----------
function Library:Notify(opts)
    return BBC.Utils.notify(opts)
end

function Library.MakeIcon(...)
    return BBC.Utils.icon(...)
end

Library.ParseKey = function(value)
    return BBC.Utils.parseKey(value)
end

BBC.Library = Library
BBC.Theme = Library.Theme
BBC.Utils.bind = bind
BBC.Utils.safeCall = BBC.Security.safeCall
BBC.Utils.LocalPlayer = LocalPlayer

if type(getgenv) == "function" then
    pcall(function()
        getgenv().BBCLib = Library
    end)
end

return Library
