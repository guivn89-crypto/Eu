--[[
    BBC HUB - Theme & Library Core
    Biblioteca principal: fontes, temas, bindings, loop de FPS, API de servidores.
]]

local Library = BBC.Library or {}
BBC.Library = Library

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

Library.Windows = {}
Library.Registry = {}
Library._themeListeners = {}
Library._bindings = {}
Library.ThemeName = "Orange"
Library.Theme = {}
Library.Access = "FREE"
Library.Keybinds = {}
Library._kbListeners = {}
Library._toggleBinds = {}
Library.Tr = function(t) return t end

-- Initialize feature/option tables early (before features modules load)
Library.FO = {}
Library.Features = {}
Library.FS = {}
Library.SV = {}
Library.ESP = {}
Library.LootCfg = {}
Library.RadarCfg = {}
Library.keys = { menu = "RightShift", cursor = "LeftAlt", zoom = "N" }

-- Terrain color helper (define BEFORE exposing to BBC)
Library.TerrainColor = function(mat, c)
    pcall(function()
        local Workspace = game:GetService("Workspace")
        if mat == "Water" then Workspace.Terrain.WaterColor = c else Workspace.Terrain:SetMaterialColor(mat, c) end
    end)
end

-- Notify wrapper (uses Utils.notify internally)
Library.Notify = function(opts)
    local Utils = BBC.Utils
    if Utils and Utils.notify then return Utils.notify(opts) end
    -- Fallback if Utils not ready
    warn("[BBC] Notify called but Utils not ready: " .. tostring(opts and opts.Content or opts))
end

-- Expose on BBC table for cross-module access
BBC.FO = Library.FO
BBC.Features = Library.Features
BBC.FS = Library.FS
BBC.SV = Library.SV
BBC.ESP = Library.ESP
BBC.LootCfg = Library.LootCfg
BBC.RadarCfg = Library.RadarCfg
BBC.keys = Library.keys

-- Expose methods on BBC table
BBC.TerrainColor = Library.TerrainColor
BBC.Notify = Library.Notify
BBC.notify = Library.Notify  -- alias lowercase for compatibility

function Library:_kbChanged()
    for _, fn in ipairs(Library._kbListeners) do pcall(fn) end
end

-- ---------- Fontes ----------
Library.Fonts = {
    Regular = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Regular),
    Medium = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Medium),
    Bold = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold),
}
local FONT_WEIGHTS = {
    Regular = { 400, Enum.FontWeight.Regular }, Medium = { 500, Enum.FontWeight.Medium },
    SemiBold = { 600, Enum.FontWeight.SemiBold }, Bold = { 700, Enum.FontWeight.Bold },
}
function Library:LoadFont(opts)
    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[BBC] fontes personalizadas precisam de writefile, isfile e getcustomasset")
        return false
    end
    local name = opts.Name or "CustomFont"
    local weights = opts.Weights
    if type(weights) ~= "table" then return false end
    local folder = "BBC_HUB_Fontes"
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then makefolder(folder) end
    end)
    local faces = {}
    for weightName, url in pairs(weights) do
        local info = FONT_WEIGHTS[weightName]
        if info then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true
            if not isfile(path) then ok = pcall(function() writefile(path, game:HttpGet(url)) end) end
            if ok then table.insert(faces, { name = weightName, weight = info[1], style = "normal", assetId = getcustomasset(path) }) end
        end
    end
    if #faces == 0 then return false end
    local familyPath = folder .. "/" .. name .. ".json"
    if not pcall(function() writefile(familyPath, HttpService:JSONEncode({ name = name, faces = faces })) end) then return false end
    local family = getcustomasset(familyPath)
    local function face(w, fallback)
        local info = FONT_WEIGHTS[w]
        if info and weights[w] then return Font.new(family, info[2]) end
        return fallback
    end
    Library.Fonts.Regular = face("Regular", Library.Fonts.Regular)
    Library.Fonts.Medium = face("Medium", face("Regular", Library.Fonts.Medium))
    Library.Fonts.Bold = face("Bold", face("SemiBold", Library.Fonts.Bold))
    return true
end

-- ---------- Temas ----------
local function preset(accent, mode, bgOverride)
    local h = accent:ToHSV()
    local function d(sat, val)
        if mode == "neutral" then return Color3.fromHSV(0, 0, val) end
        return Color3.fromHSV(h, sat, val)
    end
    local p = {
        Accent = accent,
        Background = d(0.55, 0.04), Surface = d(0.55, 0.055), Surface2 = d(0.5, 0.08),
        Surface3 = d(0.45, 0.125), Stroke = d(0.45, 0.2),
        Text = Color3.fromRGB(242, 242, 242), Muted = Color3.fromRGB(150, 150, 150),
        Warning = Color3.fromRGB(240, 176, 108), Error = Color3.fromRGB(240, 100, 100),
    }
    if bgOverride then for k, v in pairs(bgOverride) do p[k] = v end end
    return p
end
Library.ThemeOrder = { "Gold", "Purple", "Yellow", "Red", "Blue", "Orange", "Green", "Halloween", "Ocean", "Mono", "Cyan", "Pink", "Copper" }
Library.ThemePresets = {
    Gold = preset(Color3.fromRGB(255, 192, 40), "neutral"),
    Purple = preset(Color3.fromRGB(150, 100, 255), "tint"),
    Yellow = preset(Color3.fromRGB(240, 232, 60), "neutral"),
    Red = preset(Color3.fromRGB(240, 52, 72), "tint"),
    Blue = preset(Color3.fromRGB(80, 125, 255), "tint"),
    Orange = preset(Color3.fromRGB(255, 130, 25), "neutral"),
    Green = preset(Color3.fromRGB(45, 215, 105), "tint"),
    Halloween = preset(Color3.fromRGB(255, 120, 10), "tint", {
        Background = Color3.fromRGB(14, 8, 22), Surface = Color3.fromRGB(19, 11, 30), Surface2 = Color3.fromRGB(27, 16, 42),
        Surface3 = Color3.fromRGB(40, 26, 60), Stroke = Color3.fromRGB(58, 38, 84) }),
    Cyan = preset(Color3.fromRGB(30, 175, 245), "tint"),
    Mono = preset(Color3.fromRGB(235, 235, 235), "neutral"),
    Pink = preset(Color3.fromRGB(242, 85, 175), "tint"),
    Ocean = preset(Color3.fromRGB(40, 120, 255), "tint"),
    Copper = preset(Color3.fromRGB(222, 150, 62), "neutral"),
}
for k, v in pairs(Library.ThemePresets.Orange) do Library.Theme[k] = v end

-- ---------- Bindings ----------
local function bind(inst, prop, key)
    local fn = type(key) == "function" and key or function() return Library.Theme[key] end
    inst[prop] = fn()
    Library._bindings[#Library._bindings + 1] = { inst, prop, fn }
end
Library.Bind = bind

function Library:SetTheme(name)
    local p = Library.ThemePresets[name]
    if not p then return end
    Library.ThemeName = name
    for k, v in pairs(p) do Library.Theme[k] = v end
    for i = #Library._bindings, 1, -1 do
        local b = Library._bindings[i]
        if b[1] and b[1].Parent then pcall(function() b[1][b[2]] = b[3]() end) else table.remove(Library._bindings, i) end
    end
    for _, fn in ipairs(Library._themeListeners) do pcall(fn) end
end

-- ---------- FPS compartilhado ----------
Library._fps = 60
do
    local frames, last = 0, os.clock()
    RunService.RenderStepped:Connect(function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then Library._fps = math.floor(frames / (now - last) + 0.5); frames = 0; last = now end
    end)
end

-- ---------- API de Servidores ----------
function Library:FetchServers(order, cursor)
    local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=%s&limit=100%s",
        game.PlaceId, order or "Desc", cursor and ("&cursor=" .. cursor) or "")
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if not ok or type(body) ~= "string" then return nil end
    local decoded, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then return nil end
    return data.data, data.nextPageCursor
end
function Library:JoinServer(jobId)
    return pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer) end)
end

-- ---------- ParseKey ----------
Library.ParseKey = BBC.Utils.parseKey

-- ---------- MakeIcon ----------
function Library.MakeIcon(...)
    return BBC.Utils.icon(...)
end

-- Expor Library globalmente para compatibilidade
if type(getgenv) == "function" then
    pcall(function()
        getgenv().BBCLib = Library
    end)
end

return Library