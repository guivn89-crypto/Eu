-- ============================================================
--  BBC_HUB.luau - GERADO por build.py (nao edite este arquivo)
--  Fonte: src/  ·  Reconstrua com:  python3 build.py
-- ============================================================
-- ============ 00_head.luau :: Cabeçalho, biblioteca base (fontes, tema, utilidades, Registry, atalhos) ============
-- ============================================================
--  BBCLib - biblioteca própria do BBC HUB
--  (a AirFlow serviu só de exemplo de estrutura)
--
--  Mapa do arquivo (monolito, na ordem em que aparece):
--   1. Biblioteca base ... fontes, tema, utilidades, Registry, atalhos de tecla
--   2. Elementos de UI ... Toggle, Slider, Dropdown, Button, Keybind, Input, cor
--   3. Layout ............ Window, abas, Groupbox, modais, tooltip, busca
--   4. Menu .............. abas e opções, temas, idiomas, perfis, marca d'água
--   5. Painéis ........... ESP (prévia Chams), radar, busca de saque, servidores
--   6. Motor ............. ESP no jogo, radar, loot, zona do modo pânico
--   7. Entrada ........... intro, FinishLoading, autocontrole, aviso final
-- ============================================================
local Library = (function()
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer

local Library = {
    Windows = {}, Registry = {}, _themeListeners = {}, _bindings = {},
    ThemeName = "Orange", Theme = {}, Access = "FREE", Keybinds = {}, _kbListeners = {},
    Tr = function(t) return t end, ESPMaster = {},
}
-- Eventos da biblioteca também são desconectados no fechamento e param após
-- erros consecutivos, sem deixar um callback defeituoso repetindo para sempre.
Library._running, Library._uiConnections = true, {}
local function safeConnect(signal, callback)
    local failures, conn = 0, nil
    conn = signal:Connect(function(...)
        if not Library._running then return end
        local ok, err = pcall(callback, ...)
        if ok then failures = 0; return end
        failures += 1
        if failures == 1 then
            warn("[BBC] Evento da interface: " .. tostring(err))
            if Library.Diagnostics then Library.Diagnostics:record("interface", err) end
        end
        if failures >= 5 then
            if conn then pcall(function() conn:Disconnect() end) end
            warn("[BBC] Evento da interface interrompido após erros.")
        end
    end)
    for old in pairs(Library._uiConnections) do if not old.Connected then Library._uiConnections[old] = nil end end
    Library._uiConnections[conn] = true
    return conn
end
function Library:_kbChanged() for _, fn in ipairs(Library._kbListeners) do pcall(fn) end end
-- uma escuta de tecla por vez: começar um atalho cancela o anterior e evita
-- o estado "escutando" ficar travado para sempre
Library._kbOwner, Library._kbCancel = nil, nil
function Library:_kbListen(owner, cancelFn)
    if Library._kbOwner ~= nil and Library._kbOwner ~= owner and Library._kbCancel then pcall(Library._kbCancel) end
    Library._kbOwner, Library._kbCancel = owner, cancelFn
    Library._listening = true
end
function Library:_kbDone()
    Library._kbOwner, Library._kbCancel = nil, nil
    Library._listening = false
    Library._lastBind = os.clock()
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
    if type(opts) ~= "table" then return false end
    if type(writefile) ~= "function" or type(isfile) ~= "function" or typeof(getcustomasset) ~= "function" then
        warn("[BBC] fontes personalizadas precisam de writefile, isfile e getcustomasset")
        return false
    end
    local name = opts.Name or "CustomFont"
    if type(name) ~= "string" or #name > 64 or not name:match("^[%w_%-]+$") then return false end
    local weights = opts.Weights
    if type(weights) ~= "table" then return false end
    local folder = "BBC_HUB_Fontes"
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then makefolder(folder) end
    end)
    local faces = {}
    for weightName, url in pairs(weights) do
        local info = FONT_WEIGHTS[weightName]
        if info and type(url) == "string" and #url <= 2048 and url:match("^https://") then
            local path = folder .. "/" .. name .. "-" .. weightName .. ".ttf"
            local ok = true
            if not isfile(path) then
                ok = pcall(function()
                    local data = game:HttpGet(url)
                    assert(type(data) == "string" and #data > 0 and #data <= 8 * 1024 * 1024, "fonte inválida ou muito grande")
                    writefile(path, data)
                end)
            end
            if ok then
                local valid, asset = pcall(getcustomasset, path)
                if valid and type(asset) == "string" then table.insert(faces, { name = weightName, weight = info[1], style = "normal", assetId = asset }) end
            end
        end
    end
    if #faces == 0 then return false end
    local familyPath = folder .. "/" .. name .. ".json"
    if not pcall(function() writefile(familyPath, HttpService:JSONEncode({ name = name, faces = faces })) end) then return false end
    local okFamily, family = pcall(getcustomasset, familyPath)
    if not okFamily or type(family) ~= "string" then return false end
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
Library.MakeTheme = preset
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

-- ---------- Utilidades ----------
-- Algumas bibliotecas usam uma API opcional do executor para proteger GUIs
-- antes de inseri-las. A chamada não comprova invisibilidade ou segurança.
Library.GuiProtection = { attempted = 0, succeeded = 0, failed = 0, unavailable = 0, _tracked = setmetatable({}, { __mode = "k" }) }
function Library:ProtectGui(gui)
    local state = self.GuiProtection
    if state._tracked[gui] then return true end
    local protect, unprotect
    if type(protectgui) == "function" then
        protect, unprotect = protectgui, type(unprotectgui) == "function" and unprotectgui or nil
    elseif type(syn) == "table" and type(syn.protect_gui) == "function" then
        protect, unprotect = syn.protect_gui, type(syn.unprotect_gui) == "function" and syn.unprotect_gui or nil
    end
    if not protect then
        state.unavailable += 1
        if not state._warnedUnavailable then
            state._warnedUnavailable = true
            warn("[BBC] Executor sem API de proteção de GUI; interface pode ser detectada.")
        end
        return false
    end
    state.attempted += 1
    local ok, result = pcall(protect, gui)
    if not ok or result == false then
        state.failed += 1
        if not state._warnedFailure then
            state._warnedFailure = true
            warn("[BBC] API de proteção de GUI falhou; interface pode ser detectada.")
        end
        return false
    end
    state.succeeded += 1
    state._tracked[gui] = { unprotect = unprotect }
    -- A notificação é melhor esforço; nem todos os executores expõem Destroying.
    pcall(function() safeConnect(gui.Destroying, function() self:UnprotectGui(gui) end) end)
    return true
end
function Library:UnprotectGui(gui)
    local entry = self.GuiProtection._tracked[gui]
    if not entry then return end
    self.GuiProtection._tracked[gui] = nil
    if entry.unprotect then pcall(entry.unprotect, gui) end
end
function Library:UnprotectAllGuis()
    for gui in pairs(self.GuiProtection._tracked) do self:UnprotectGui(gui) end
end
local function create(class, props, parent)
    local i = Instance.new(class)
    for k, v in pairs(props or {}) do i[k] = v end
    if class == "ScreenGui" or class == "BillboardGui" then Library:ProtectGui(i) end
    if parent then i.Parent = parent end
    return i
end
local function corner(parent, r) return create("UICorner", { CornerRadius = UDim.new(0, r or 4) }, parent) end
local function stroke(parent, key, transparency, thickness)
    local s = create("UIStroke", { Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
    bind(s, "Color", key or "Stroke")
    return s
end
local function pad(parent, l, r, t, b)
    return create("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0) }, parent)
end
local function listLayout(parent, padding, dir)
    return create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, padding or 0), FillDirection = dir or Enum.FillDirection.Vertical }, parent)
end
local function tween(inst, props, t, style)
    local tw = TweenService:Create(inst, TweenInfo.new(Library.ReduceMotion and 0 or (t or 0.15), style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function safeCall(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[BBC] " .. tostring(err)) end
end
local function label(parent, text, size, key, bold, props)
    local l = create("TextLabel", {
        BackgroundTransparency = 1, Text = text or "", TextSize = size or 13, FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, (size or 13) + 4),
    }, parent)
    bind(l, "TextColor3", key or "Text")
    for k, v in pairs(props or {}) do l[k] = v end
    return l
end

-- ---------- Ícones (Lucide) ----------
-- IDs Lucide: Footagesus/Icons, MIT, commit 46d30c19ba7bc601d6ec794a48dc3a89568b1eec.
-- Licença completa: THIRD_PARTY_LICENSES/Footagesus-Icons-MIT.txt
--[[
MIT License

Copyright (c) 2025 Footages

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
local lucide = {
	["a-arrow-down"] = "rbxassetid://92867583610071",
	["a-arrow-up"] = "rbxassetid://132318504999733",
	["a-large-small"] = "rbxassetid://111491496660216",
	["accessibility"] = "rbxassetid://114029945302017",
	["activity"] = "rbxassetid://94212016861936",
	["air-vent"] = "rbxassetid://81517226012329",
	["airplay"] = "rbxassetid://115020759309179",
	["alarm-clock-check"] = "rbxassetid://76437352099157",
	["alarm-clock-minus"] = "rbxassetid://77364179863205",
	["alarm-clock-off"] = "rbxassetid://97904885874823",
	["alarm-clock-plus"] = "rbxassetid://80468822979214",
	["alarm-clock"] = "rbxassetid://126259032907535",
	["alarm-smoke"] = "rbxassetid://96965448419685",
	["album"] = "rbxassetid://127358331163602",
	["align-center-horizontal"] = "rbxassetid://81570549209434",
	["align-center-vertical"] = "rbxassetid://118470463752466",
	["align-end-horizontal"] = "rbxassetid://139502909745427",
	["align-end-vertical"] = "rbxassetid://96528869059554",
	["align-horizontal-distribute-center"] = "rbxassetid://97220086126656",
	["align-horizontal-distribute-end"] = "rbxassetid://106128590702022",
	["align-horizontal-distribute-start"] = "rbxassetid://76074660002997",
	["align-horizontal-justify-center"] = "rbxassetid://75732302772427",
	["align-horizontal-justify-end"] = "rbxassetid://129167626402283",
	["align-horizontal-justify-start"] = "rbxassetid://130161830325281",
	["align-horizontal-space-around"] = "rbxassetid://91646106782950",
	["align-horizontal-space-between"] = "rbxassetid://103886093046990",
	["align-start-horizontal"] = "rbxassetid://125674804697729",
	["align-start-vertical"] = "rbxassetid://105020230154823",
	["align-vertical-distribute-center"] = "rbxassetid://93791183635525",
	["align-vertical-distribute-end"] = "rbxassetid://139354223511433",
	["align-vertical-distribute-start"] = "rbxassetid://74961997822126",
	["align-vertical-justify-center"] = "rbxassetid://134754696166569",
	["align-vertical-justify-end"] = "rbxassetid://92569381441969",
	["align-vertical-justify-start"] = "rbxassetid://99692844572718",
	["align-vertical-space-around"] = "rbxassetid://96206012459190",
	["align-vertical-space-between"] = "rbxassetid://124998077349706",
	["ambulance"] = "rbxassetid://78599995190651",
	["ampersand"] = "rbxassetid://75272915739209",
	["ampersands"] = "rbxassetid://126947193455996",
	["amphora"] = "rbxassetid://137370389604364",
	["anchor"] = "rbxassetid://92181172123618",
	["angry"] = "rbxassetid://74237056000103",
	["annoyed"] = "rbxassetid://80064369052011",
	["antenna"] = "rbxassetid://99628923540956",
	["anvil"] = "rbxassetid://100203029845919",
	["aperture"] = "rbxassetid://83396154449972",
	["app-window-mac"] = "rbxassetid://79587216113811",
	["app-window"] = "rbxassetid://93142176757189",
	["apple"] = "rbxassetid://104349242902442",
	["archive-restore"] = "rbxassetid://78956681942188",
	["archive-x"] = "rbxassetid://75830115088395",
	["archive"] = "rbxassetid://122180020814574",
	["armchair"] = "rbxassetid://105384358373973",
	["arrow-big-down-dash"] = "rbxassetid://137987229582002",
	["arrow-big-down"] = "rbxassetid://81081164158885",
	["arrow-big-left-dash"] = "rbxassetid://97827621354677",
	["arrow-big-left"] = "rbxassetid://85973092492641",
	["arrow-big-right-dash"] = "rbxassetid://117825834972403",
	["arrow-big-right"] = "rbxassetid://82960676755590",
	["arrow-big-up-dash"] = "rbxassetid://99260194327483",
	["arrow-big-up"] = "rbxassetid://93136954756149",
	["arrow-down-0-1"] = "rbxassetid://120961896217875",
	["arrow-down-1-0"] = "rbxassetid://93474255891850",
	["arrow-down-a-z"] = "rbxassetid://99554596207900",
	["arrow-down-from-line"] = "rbxassetid://132045845807798",
	["arrow-down-left"] = "rbxassetid://102899325237364",
	["arrow-down-narrow-wide"] = "rbxassetid://129105261655061",
	["arrow-down-right"] = "rbxassetid://123109928624974",
	["arrow-down-to-dot"] = "rbxassetid://101675355931221",
	["arrow-down-to-line"] = "rbxassetid://87050478931254",
	["arrow-down-up"] = "rbxassetid://85780258549577",
	["arrow-down-wide-narrow"] = "rbxassetid://88461733425991",
	["arrow-down-z-a"] = "rbxassetid://76115279362232",
	["arrow-down"] = "rbxassetid://98764963621439",
	["arrow-left-from-line"] = "rbxassetid://87857914437603",
	["arrow-left-right"] = "rbxassetid://131324733048447",
	["arrow-left-to-line"] = "rbxassetid://118645136026970",
	["arrow-left"] = "rbxassetid://102531941843733",
	["arrow-right-from-line"] = "rbxassetid://74073639809355",
	["arrow-right-left"] = "rbxassetid://77015754304300",
	["arrow-right-to-line"] = "rbxassetid://78632510329852",
	["arrow-right"] = "rbxassetid://113692007244654",
	["arrow-up-0-1"] = "rbxassetid://105257823943016",
	["arrow-up-1-0"] = "rbxassetid://134175521693798",
	["arrow-up-a-z"] = "rbxassetid://77763416595160",
	["arrow-up-down"] = "rbxassetid://81019887641527",
	["arrow-up-from-dot"] = "rbxassetid://124408496673275",
	["arrow-up-from-line"] = "rbxassetid://95777664626453",
	["arrow-up-left"] = "rbxassetid://123490598231261",
	["arrow-up-narrow-wide"] = "rbxassetid://73006024672636",
	["arrow-up-right"] = "rbxassetid://129280608535523",
	["arrow-up-to-line"] = "rbxassetid://108818207813537",
	["arrow-up-wide-narrow"] = "rbxassetid://87437426951568",
	["arrow-up-z-a"] = "rbxassetid://107546173611884",
	["arrow-up"] = "rbxassetid://89282378235317",
	["arrows-up-from-line"] = "rbxassetid://133710016938621",
	["asterisk"] = "rbxassetid://88552752106723",
	["at-sign"] = "rbxassetid://79059152889146",
	["atom"] = "rbxassetid://73167696981648",
	["audio-lines"] = "rbxassetid://70930641819242",
	["audio-waveform"] = "rbxassetid://86462036665209",
	["award"] = "rbxassetid://132740088158419",
	["axe"] = "rbxassetid://132405197863294",
	["axis-3d"] = "rbxassetid://122438676546804",
	["baby"] = "rbxassetid://93472926933440",
	["backpack"] = "rbxassetid://140420225386018",
	["badge-alert"] = "rbxassetid://101829200081951",
	["badge-cent"] = "rbxassetid://133345018873154",
	["badge-check"] = "rbxassetid://76078495178149",
	["badge-dollar-sign"] = "rbxassetid://127139803581141",
	["badge-euro"] = "rbxassetid://120016477674659",
	["badge-indian-rupee"] = "rbxassetid://75659682309981",
	["badge-info"] = "rbxassetid://131995373201472",
	["badge-japanese-yen"] = "rbxassetid://99081574588615",
	["badge-minus"] = "rbxassetid://140321561183881",
	["badge-percent"] = "rbxassetid://121359224294885",
	["badge-plus"] = "rbxassetid://100325578561866",
	["badge-pound-sterling"] = "rbxassetid://119688217279444",
	["badge-question-mark"] = "rbxassetid://121464963737502",
	["badge-russian-ruble"] = "rbxassetid://108839463659864",
	["badge-swiss-franc"] = "rbxassetid://91447608372740",
	["badge-turkish-lira"] = "rbxassetid://137839965873529",
	["badge-x"] = "rbxassetid://122931434733842",
	["badge"] = "rbxassetid://116620312917084",
	["baggage-claim"] = "rbxassetid://86922213051957",
	["ban"] = "rbxassetid://90767043015246",
	["banana"] = "rbxassetid://140713420056179",
	["bandage"] = "rbxassetid://129660129590770",
	["banknote-arrow-down"] = "rbxassetid://139366449345199",
	["banknote-arrow-up"] = "rbxassetid://133758343082529",
	["banknote-x"] = "rbxassetid://95348701438065",
	["banknote"] = "rbxassetid://104840231536668",
	["barcode"] = "rbxassetid://118473018143689",
	["barrel"] = "rbxassetid://130647115622774",
	["baseline"] = "rbxassetid://124677132511270",
	["bath"] = "rbxassetid://76031400297942",
	["battery-charging"] = "rbxassetid://80139357470047",
	["battery-full"] = "rbxassetid://70906718268972",
	["battery-low"] = "rbxassetid://139659256984314",
	["battery-medium"] = "rbxassetid://105934079398915",
	["battery-plus"] = "rbxassetid://91931341486966",
	["battery-warning"] = "rbxassetid://115230083817257",
	["battery"] = "rbxassetid://70765800346189",
	["beaker"] = "rbxassetid://80902539995520",
	["bean-off"] = "rbxassetid://98164436608714",
	["bean"] = "rbxassetid://89491967076869",
	["bed-double"] = "rbxassetid://73820193212911",
	["bed-single"] = "rbxassetid://113423940880634",
	["bed"] = "rbxassetid://97726529032925",
	["beef"] = "rbxassetid://105850162318915",
	["beer-off"] = "rbxassetid://120333134736361",
	["beer"] = "rbxassetid://116404978807744",
	["bell-dot"] = "rbxassetid://93161277118810",
	["bell-electric"] = "rbxassetid://100277767266983",
	["bell-minus"] = "rbxassetid://126334890449727",
	["bell-off"] = "rbxassetid://78560046118930",
	["bell-plus"] = "rbxassetid://77014333795836",
	["bell-ring"] = "rbxassetid://94612128913941",
	["bell"] = "rbxassetid://97392696311902",
	["between-horizontal-end"] = "rbxassetid://81602774794322",
	["between-horizontal-start"] = "rbxassetid://76112384929846",
	["between-vertical-end"] = "rbxassetid://72817612571631",
	["between-vertical-start"] = "rbxassetid://85278312190301",
	["biceps-flexed"] = "rbxassetid://82004462003936",
	["bike"] = "rbxassetid://102930322246035",
	["binary"] = "rbxassetid://91751953950088",
	["binoculars"] = "rbxassetid://101460003267896",
	["biohazard"] = "rbxassetid://95956532900432",
	["bird"] = "rbxassetid://132284145117371",
	["birdhouse"] = "rbxassetid://83999157401433",
	["bitcoin"] = "rbxassetid://95459240442938",
	["blend"] = "rbxassetid://111679612185257",
	["blinds"] = "rbxassetid://71164165283925",
	["blocks"] = "rbxassetid://72212693357737",
	["bluetooth-connected"] = "rbxassetid://96315134002985",
	["bluetooth-off"] = "rbxassetid://80600044218117",
	["bluetooth-searching"] = "rbxassetid://100673019606426",
	["bluetooth"] = "rbxassetid://90506573139443",
	["bold"] = "rbxassetid://116141470019166",
	["bolt"] = "rbxassetid://102881251417484",
	["bomb"] = "rbxassetid://139223800924636",
	["bone"] = "rbxassetid://111242153474115",
	["book-a"] = "rbxassetid://104067275658465",
	["book-alert"] = "rbxassetid://124159928044853",
	["book-audio"] = "rbxassetid://109208148317037",
	["book-check"] = "rbxassetid://115999656081696",
	["book-copy"] = "rbxassetid://108543407492005",
	["book-dashed"] = "rbxassetid://127430784795958",
	["book-down"] = "rbxassetid://101011730128222",
	["book-headphones"] = "rbxassetid://108670200799574",
	["book-heart"] = "rbxassetid://112788845135284",
	["book-image"] = "rbxassetid://80808285757226",
	["book-key"] = "rbxassetid://116024426170705",
	["book-lock"] = "rbxassetid://118765061220571",
	["book-marked"] = "rbxassetid://73211024251780",
	["book-minus"] = "rbxassetid://112724962046282",
	["book-open-check"] = "rbxassetid://130848362492667",
	["book-open-text"] = "rbxassetid://100629528672195",
	["book-open"] = "rbxassetid://129845326810392",
	["book-plus"] = "rbxassetid://140267785051233",
	["book-text"] = "rbxassetid://94011772484232",
	["book-type"] = "rbxassetid://97817304725443",
	["book-up-2"] = "rbxassetid://130161620853665",
	["book-up"] = "rbxassetid://98640174079190",
	["book-user"] = "rbxassetid://128489189240523",
	["book-x"] = "rbxassetid://118754548186537",
	["book"] = "rbxassetid://125383279695672",
	["bookmark-check"] = "rbxassetid://93940443347986",
	["bookmark-minus"] = "rbxassetid://96807096039910",
	["bookmark-plus"] = "rbxassetid://121469724491615",
	["bookmark-x"] = "rbxassetid://112272342584706",
	["bookmark"] = "rbxassetid://121093149326239",
	["boom-box"] = "rbxassetid://99901322535868",
	["bot-message-square"] = "rbxassetid://96145330292478",
	["bot-off"] = "rbxassetid://140417690560013",
	["bot"] = "rbxassetid://80451686744860",
	["bottle-wine"] = "rbxassetid://131675403196921",
	["bow-arrow"] = "rbxassetid://124089655150375",
	["box"] = "rbxassetid://101768155599700",
	["boxes"] = "rbxassetid://136372617578355",
	["braces"] = "rbxassetid://117761094704041",
	["brackets"] = "rbxassetid://74368995728099",
	["brain-circuit"] = "rbxassetid://70547962410202",
	["brain-cog"] = "rbxassetid://132039205501538",
	["brain"] = "rbxassetid://92424107303177",
	["brick-wall-fire"] = "rbxassetid://92980588705520",
	["brick-wall-shield"] = "rbxassetid://75954432775071",
	["brick-wall"] = "rbxassetid://112878522258821",
	["briefcase-business"] = "rbxassetid://129135125207283",
	["briefcase-conveyor-belt"] = "rbxassetid://108665725653714",
	["briefcase-medical"] = "rbxassetid://119917756334087",
	["briefcase"] = "rbxassetid://96754188164225",
	["bring-to-front"] = "rbxassetid://132975903553748",
	["brush-cleaning"] = "rbxassetid://71728977448805",
	["brush"] = "rbxassetid://127035535799640",
	["bubbles"] = "rbxassetid://106183424168227",
	["bug-off"] = "rbxassetid://88020025049245",
	["bug-play"] = "rbxassetid://80107955888092",
	["bug"] = "rbxassetid://83626408925438",
	["building-2"] = "rbxassetid://77873775611951",
	["building"] = "rbxassetid://110616258983082",
	["bus-front"] = "rbxassetid://89863432456045",
	["bus"] = "rbxassetid://133798469717463",
	["cable-car"] = "rbxassetid://128643682205596",
	["cable"] = "rbxassetid://128449944504901",
	["cake-slice"] = "rbxassetid://136769828413242",
	["cake"] = "rbxassetid://103131590503275",
	["calculator"] = "rbxassetid://74915716529646",
	["calendar-1"] = "rbxassetid://98458364171044",
	["calendar-arrow-down"] = "rbxassetid://108415736543437",
	["calendar-arrow-up"] = "rbxassetid://70574654109118",
	["calendar-check-2"] = "rbxassetid://120231170248276",
	["calendar-check"] = "rbxassetid://71551019465748",
	["calendar-clock"] = "rbxassetid://119132152594595",
	["calendar-cog"] = "rbxassetid://122402172360287",
	["calendar-days"] = "rbxassetid://99072017568595",
	["calendar-fold"] = "rbxassetid://117368871270394",
	["calendar-heart"] = "rbxassetid://88839008103676",
	["calendar-minus-2"] = "rbxassetid://98846170279891",
	["calendar-minus"] = "rbxassetid://137354318924383",
	["calendar-off"] = "rbxassetid://109726151749217",
	["calendar-plus-2"] = "rbxassetid://112264562093883",
	["calendar-plus"] = "rbxassetid://125266115249843",
	["calendar-range"] = "rbxassetid://103641849247576",
	["calendar-search"] = "rbxassetid://92010083223634",
	["calendar-sync"] = "rbxassetid://78082218499697",
	["calendar-x-2"] = "rbxassetid://107518051061147",
	["calendar-x"] = "rbxassetid://106703374806500",
	["calendar"] = "rbxassetid://114792700814035",
	["camera-off"] = "rbxassetid://81057636835256",
	["camera"] = "rbxassetid://79950339943067",
	["candy-cane"] = "rbxassetid://71689468772492",
	["candy-off"] = "rbxassetid://110232752314832",
	["candy"] = "rbxassetid://107812129154678",
	["cannabis"] = "rbxassetid://98792006538601",
	["captions-off"] = "rbxassetid://105223545364193",
	["captions"] = "rbxassetid://104960225031445",
	["car-front"] = "rbxassetid://87380942739063",
	["car-taxi-front"] = "rbxassetid://122455403384057",
	["car"] = "rbxassetid://121065933462582",
	["caravan"] = "rbxassetid://120070979471783",
	["card-sim"] = "rbxassetid://134490550095771",
	["carrot"] = "rbxassetid://119118221444304",
	["case-lower"] = "rbxassetid://129303130603241",
	["case-sensitive"] = "rbxassetid://125410273293056",
	["case-upper"] = "rbxassetid://111633433531325",
	["cassette-tape"] = "rbxassetid://137065788934157",
	["cast"] = "rbxassetid://98202245922071",
	["castle"] = "rbxassetid://119275077187784",
	["cat"] = "rbxassetid://124252153404931",
	["cctv"] = "rbxassetid://99979894766624",
	["chart-area"] = "rbxassetid://123446436762366",
	["chart-bar-big"] = "rbxassetid://72336824986044",
	["chart-bar-decreasing"] = "rbxassetid://107217459044963",
	["chart-bar-increasing"] = "rbxassetid://88268905998571",
	["chart-bar-stacked"] = "rbxassetid://98478751113024",
	["chart-bar"] = "rbxassetid://105389816384108",
	["chart-candlestick"] = "rbxassetid://125676898615697",
	["chart-column-big"] = "rbxassetid://98598733210787",
	["chart-column-decreasing"] = "rbxassetid://73586137373563",
	["chart-column-increasing"] = "rbxassetid://120421615068601",
	["chart-column-stacked"] = "rbxassetid://86031449675105",
	["chart-column"] = "rbxassetid://97915995538580",
	["chart-gantt"] = "rbxassetid://88811660555940",
	["chart-line"] = "rbxassetid://101833156055618",
	["chart-network"] = "rbxassetid://104027882693561",
	["chart-no-axes-column-decreasing"] = "rbxassetid://123371717192542",
	["chart-no-axes-column-increasing"] = "rbxassetid://140383830943049",
	["chart-no-axes-column"] = "rbxassetid://94078751170351",
	["chart-no-axes-combined"] = "rbxassetid://121424233161912",
	["chart-no-axes-gantt"] = "rbxassetid://131936541106368",
	["chart-pie"] = "rbxassetid://113412261630136",
	["chart-scatter"] = "rbxassetid://108217585014571",
	["chart-spline"] = "rbxassetid://90307460742494",
	["check-check"] = "rbxassetid://95183312173858",
	["check-line"] = "rbxassetid://115122343485290",
	["check"] = "rbxassetid://93898873302694",
	["chef-hat"] = "rbxassetid://121744015002573",
	["cherry"] = "rbxassetid://139519182403183",
	["chess-bishop"] = "rbxassetid://121701705580238",
	["chess-king"] = "rbxassetid://90885687223462",
	["chess-knight"] = "rbxassetid://96467707042169",
	["chess-pawn"] = "rbxassetid://111318574652751",
	["chess-queen"] = "rbxassetid://98304702099749",
	["chess-rook"] = "rbxassetid://76223925830262",
	["chevron-down"] = "rbxassetid://134243273101015",
	["chevron-first"] = "rbxassetid://105243363790238",
	["chevron-last"] = "rbxassetid://89268452603731",
	["chevron-left"] = "rbxassetid://73780377692148",
	["chevron-right"] = "rbxassetid://92473583511724",
	["chevron-up"] = "rbxassetid://122444883127455",
	["chevrons-down-up"] = "rbxassetid://139404716013205",
	["chevrons-down"] = "rbxassetid://100524612205956",
	["chevrons-left-right-ellipsis"] = "rbxassetid://125035817741526",
	["chevrons-left-right"] = "rbxassetid://87910685945204",
	["chevrons-left"] = "rbxassetid://82617201744347",
	["chevrons-right-left"] = "rbxassetid://87149546686569",
	["chevrons-right"] = "rbxassetid://139121276490483",
	["chevrons-up-down"] = "rbxassetid://131833120209646",
	["chevrons-up"] = "rbxassetid://100467452364672",
	["chromium"] = "rbxassetid://128165143739006",
	["church"] = "rbxassetid://113714744350666",
	["cigarette-off"] = "rbxassetid://77797883078452",
	["circle-alert"] = "rbxassetid://83898160590116",
	["circle-arrow-down"] = "rbxassetid://95901860261344",
	["circle-arrow-left"] = "rbxassetid://102148876968988",
	["circle-arrow-out-down-left"] = "rbxassetid://140598097856694",
	["circle-arrow-out-down-right"] = "rbxassetid://119952801379305",
	["circle-arrow-out-up-left"] = "rbxassetid://132858212688303",
	["circle-arrow-out-up-right"] = "rbxassetid://81783743753173",
	["circle-arrow-right"] = "rbxassetid://70786767999559",
	["circle-arrow-up"] = "rbxassetid://84395128546494",
	["circle-check-big"] = "rbxassetid://93202927221730",
	["circle-check"] = "rbxassetid://85262178816537",
	["circle-chevron-down"] = "rbxassetid://137069490345718",
	["circle-chevron-left"] = "rbxassetid://130250009740827",
	["circle-chevron-right"] = "rbxassetid://125943696958495",
	["circle-chevron-up"] = "rbxassetid://111223574026321",
	["circle-dashed"] = "rbxassetid://126799443883746",
	["circle-divide"] = "rbxassetid://106398997754208",
	["circle-dollar-sign"] = "rbxassetid://91106238890387",
	["circle-dot-dashed"] = "rbxassetid://111451232827180",
	["circle-dot"] = "rbxassetid://82947033619201",
	["circle-ellipsis"] = "rbxassetid://91687150884779",
	["circle-equal"] = "rbxassetid://95133963751438",
	["circle-fading-arrow-up"] = "rbxassetid://104648212910336",
	["circle-fading-plus"] = "rbxassetid://91847890443490",
	["circle-gauge"] = "rbxassetid://108157549473765",
	["circle-minus"] = "rbxassetid://133556159576809",
	["circle-off"] = "rbxassetid://97923456918886",
	["circle-parking-off"] = "rbxassetid://128369410981252",
	["circle-parking"] = "rbxassetid://124034962915196",
	["circle-pause"] = "rbxassetid://139337739700879",
	["circle-percent"] = "rbxassetid://133311912860256",
	["circle-play"] = "rbxassetid://120408917249739",
	["circle-plus"] = "rbxassetid://113157136350384",
	["circle-pound-sterling"] = "rbxassetid://105476153083828",
	["circle-power"] = "rbxassetid://140676030155098",
	["circle-question-mark"] = "rbxassetid://97516698664325",
	["circle-slash-2"] = "rbxassetid://136766902186549",
	["circle-slash"] = "rbxassetid://125206439913049",
	["circle-small"] = "rbxassetid://73685402843600",
	["circle-star"] = "rbxassetid://120318414957104",
	["circle-stop"] = "rbxassetid://87400503942659",
	["circle-user-round"] = "rbxassetid://95489465399880",
	["circle-user"] = "rbxassetid://136220511671311",
	["circle-x"] = "rbxassetid://76821953846248",
	["circle"] = "rbxassetid://130359823580534",
	["circuit-board"] = "rbxassetid://107695264369312",
	["citrus"] = "rbxassetid://139018222976433",
	["clapperboard"] = "rbxassetid://132660667070200",
	["clipboard-check"] = "rbxassetid://92649798577170",
	["clipboard-clock"] = "rbxassetid://123957515687745",
	["clipboard-copy"] = "rbxassetid://125851897718493",
	["clipboard-list"] = "rbxassetid://96460215958908",
	["clipboard-minus"] = "rbxassetid://107968008485671",
	["clipboard-paste"] = "rbxassetid://74382068849983",
	["clipboard-pen-line"] = "rbxassetid://77711589791615",
	["clipboard-pen"] = "rbxassetid://75290966822953",
	["clipboard-plus"] = "rbxassetid://134285318675662",
	["clipboard-type"] = "rbxassetid://89949374318028",
	["clipboard-x"] = "rbxassetid://102222456890103",
	["clipboard"] = "rbxassetid://89601995828423",
	["clock-1"] = "rbxassetid://129363225422045",
	["clock-10"] = "rbxassetid://104332695855541",
	["clock-11"] = "rbxassetid://119023205186105",
	["clock-12"] = "rbxassetid://117789618723068",
	["clock-2"] = "rbxassetid://134710777209413",
	["clock-3"] = "rbxassetid://136385631189327",
	["clock-4"] = "rbxassetid://121808839832144",
	["clock-5"] = "rbxassetid://85082019959457",
	["clock-6"] = "rbxassetid://71009733505593",
	["clock-7"] = "rbxassetid://103111188546225",
	["clock-8"] = "rbxassetid://110059272125337",
	["clock-9"] = "rbxassetid://77610027126437",
	["clock-alert"] = "rbxassetid://97157344465162",
	["clock-arrow-down"] = "rbxassetid://92349314416042",
	["clock-arrow-up"] = "rbxassetid://111484286332629",
	["clock-check"] = "rbxassetid://85231630218857",
	["clock-fading"] = "rbxassetid://93205297285245",
	["clock-plus"] = "rbxassetid://93367709263150",
	["clock"] = "rbxassetid://121808839832144",
	["closed-caption"] = "rbxassetid://99832644030788",
	["cloud-alert"] = "rbxassetid://91967273658626",
	["cloud-check"] = "rbxassetid://97318598202432",
	["cloud-cog"] = "rbxassetid://96497764065749",
	["cloud-download"] = "rbxassetid://121435581993566",
	["cloud-drizzle"] = "rbxassetid://139525315752605",
	["cloud-fog"] = "rbxassetid://76650233148776",
	["cloud-hail"] = "rbxassetid://72320462748242",
	["cloud-lightning"] = "rbxassetid://133517088924849",
	["cloud-moon-rain"] = "rbxassetid://127667837827018",
	["cloud-moon"] = "rbxassetid://71938114737914",
	["cloud-off"] = "rbxassetid://131907154501444",
	["cloud-rain-wind"] = "rbxassetid://107414583736721",
	["cloud-rain"] = "rbxassetid://105547081967408",
	["cloud-snow"] = "rbxassetid://72307126270226",
	["cloud-sun-rain"] = "rbxassetid://99041604425705",
	["cloud-sun"] = "rbxassetid://86114208148727",
	["cloud-upload"] = "rbxassetid://93307473217005",
	["cloud"] = "rbxassetid://121226497050352",
	["cloudy"] = "rbxassetid://105360479023346",
	["clover"] = "rbxassetid://74925550436750",
	["club"] = "rbxassetid://108490365816628",
	["code-xml"] = "rbxassetid://130150477351734",
	["code"] = "rbxassetid://107380207681249",
	["codepen"] = "rbxassetid://135643965971885",
	["codesandbox"] = "rbxassetid://106911852964823",
	["coffee"] = "rbxassetid://106864403231093",
	["cog"] = "rbxassetid://116544501716299",
	["coins"] = "rbxassetid://116510979641930",
	["columns-2"] = "rbxassetid://113004100221850",
	["columns-3-cog"] = "rbxassetid://121589691981064",
	["columns-3"] = "rbxassetid://115223357399375",
	["columns-4"] = "rbxassetid://130807991968419",
	["combine"] = "rbxassetid://79908476334048",
	["command"] = "rbxassetid://93648221906330",
	["compass"] = "rbxassetid://115123411028382",
	["component"] = "rbxassetid://110027788875080",
	["computer"] = "rbxassetid://77480056459407",
	["concierge-bell"] = "rbxassetid://140384259310436",
	["cone"] = "rbxassetid://97759550688437",
	["construction"] = "rbxassetid://106539489968173",
	["contact-round"] = "rbxassetid://71907624112229",
	["contact"] = "rbxassetid://75868297719012",
	["container"] = "rbxassetid://91507237573499",
	["contrast"] = "rbxassetid://112796643981497",
	["cookie"] = "rbxassetid://73159504540002",
	["cooking-pot"] = "rbxassetid://94959783129799",
	["copy-check"] = "rbxassetid://91177247988892",
	["copy-minus"] = "rbxassetid://109524509933035",
	["copy-plus"] = "rbxassetid://113618379616952",
	["copy-slash"] = "rbxassetid://93805787810390",
	["copy-x"] = "rbxassetid://106557557978061",
	["copy"] = "rbxassetid://78979572434545",
	["copyleft"] = "rbxassetid://78559055698593",
	["copyright"] = "rbxassetid://129433635747111",
	["corner-down-left"] = "rbxassetid://90473561177832",
	["corner-down-right"] = "rbxassetid://86512767702085",
	["corner-left-down"] = "rbxassetid://139876989150630",
	["corner-left-up"] = "rbxassetid://126228268096099",
	["corner-right-down"] = "rbxassetid://89237035551302",
	["corner-right-up"] = "rbxassetid://112851237026705",
	["corner-up-left"] = "rbxassetid://84669279763024",
	["corner-up-right"] = "rbxassetid://115099889693145",
	["cpu"] = "rbxassetid://77549309870247",
	["creative-commons"] = "rbxassetid://90408210735312",
	["credit-card"] = "rbxassetid://99163352872346",
	["croissant"] = "rbxassetid://130710485559420",
	["crop"] = "rbxassetid://116344601101413",
	["cross"] = "rbxassetid://101833377863588",
	["crosshair"] = "rbxassetid://134242818164054",
	["crown"] = "rbxassetid://127843403295538",
	["cuboid"] = "rbxassetid://75618807946111",
	["cup-soda"] = "rbxassetid://121098640829562",
	["currency"] = "rbxassetid://90551250119972",
	["cylinder"] = "rbxassetid://90569677179169",
	["dam"] = "rbxassetid://76874486231393",
	["database-backup"] = "rbxassetid://103403210984699",
	["database-zap"] = "rbxassetid://131199921258418",
	["database"] = "rbxassetid://126791525623846",
	["decimals-arrow-left"] = "rbxassetid://120198500638749",
	["decimals-arrow-right"] = "rbxassetid://118263047146797",
	["delete"] = "rbxassetid://126279426372342",
	["dessert"] = "rbxassetid://71508133278830",
	["diameter"] = "rbxassetid://97429051503783",
	["diamond-minus"] = "rbxassetid://128989071438290",
	["diamond-percent"] = "rbxassetid://107717860105959",
	["diamond-plus"] = "rbxassetid://134701163723675",
	["diamond"] = "rbxassetid://105846996304890",
	["dice-1"] = "rbxassetid://112650149591038",
	["dice-2"] = "rbxassetid://112278274566793",
	["dice-3"] = "rbxassetid://118526270626312",
	["dice-4"] = "rbxassetid://113365650364004",
	["dice-5"] = "rbxassetid://72768312430593",
	["dice-6"] = "rbxassetid://85376239182543",
	["dices"] = "rbxassetid://81268120302865",
	["diff"] = "rbxassetid://135052708609715",
	["disc-2"] = "rbxassetid://91419420404185",
	["disc-3"] = "rbxassetid://135470554736048",
	["disc-album"] = "rbxassetid://74693460404344",
	["disc"] = "rbxassetid://101908120120777",
	["divide"] = "rbxassetid://136678191878278",
	["dna-off"] = "rbxassetid://89612426361540",
	["dna"] = "rbxassetid://74007982981741",
	["dock"] = "rbxassetid://121997427160252",
	["dog"] = "rbxassetid://71920105558570",
	["dollar-sign"] = "rbxassetid://127320961224019",
	["donut"] = "rbxassetid://72204922742657",
	["door-closed-locked"] = "rbxassetid://74027613267551",
	["door-closed"] = "rbxassetid://136249099949073",
	["door-open"] = "rbxassetid://91306356501736",
	["dot"] = "rbxassetid://137321056643916",
	["download"] = "rbxassetid://134814648082393",
	["drafting-compass"] = "rbxassetid://99701976182841",
	["drama"] = "rbxassetid://110297795801577",
	["dribbble"] = "rbxassetid://80231809663849",
	["drill"] = "rbxassetid://108644821412796",
	["drone"] = "rbxassetid://117299095794783",
	["droplet-off"] = "rbxassetid://119365002225172",
	["droplet"] = "rbxassetid://100597455015098",
	["droplets"] = "rbxassetid://140111846025180",
	["drum"] = "rbxassetid://136979060344890",
	["drumstick"] = "rbxassetid://104662462521709",
	["dumbbell"] = "rbxassetid://80277236776212",
	["ear-off"] = "rbxassetid://87421916192807",
	["ear"] = "rbxassetid://121894949934209",
	["earth-lock"] = "rbxassetid://88814147073745",
	["earth"] = "rbxassetid://76231597751076",
	["eclipse"] = "rbxassetid://114829622118222",
	["egg-fried"] = "rbxassetid://90622538210545",
	["egg-off"] = "rbxassetid://92288321309285",
	["egg"] = "rbxassetid://117851493400222",
	["ellipsis-vertical"] = "rbxassetid://117978708573781",
	["ellipsis"] = "rbxassetid://140019550645825",
	["equal-approximately"] = "rbxassetid://105382689698323",
	["equal-not"] = "rbxassetid://76864449458032",
	["equal"] = "rbxassetid://123467780715624",
	["eraser"] = "rbxassetid://133957773112410",
	["ethernet-port"] = "rbxassetid://75391715149314",
	["euro"] = "rbxassetid://72229646524456",
	["ev-charger"] = "rbxassetid://97906158859623",
	["expand"] = "rbxassetid://137492887754537",
	["external-link"] = "rbxassetid://129331830773832",
	["eye-closed"] = "rbxassetid://111063268625789",
	["eye-off"] = "rbxassetid://135928786788378",
	["eye"] = "rbxassetid://100033680381365",
	["facebook"] = "rbxassetid://72098528632192",
	["factory"] = "rbxassetid://102170024318039",
	["fan"] = "rbxassetid://78391400440696",
	["fast-forward"] = "rbxassetid://121615540167909",
	["feather"] = "rbxassetid://91872927606406",
	["fence"] = "rbxassetid://123451565578029",
	["ferris-wheel"] = "rbxassetid://79729205796176",
	["figma"] = "rbxassetid://134182122852301",
	["file-archive"] = "rbxassetid://77018106869967",
	["file-axis-3d"] = "rbxassetid://133912328009885",
	["file-badge"] = "rbxassetid://74564895394477",
	["file-box"] = "rbxassetid://119264004071690",
	["file-braces-corner"] = "rbxassetid://77253337986109",
	["file-braces"] = "rbxassetid://95314128621234",
	["file-chart-column-increasing"] = "rbxassetid://134449481172067",
	["file-chart-column"] = "rbxassetid://82048481252560",
	["file-chart-line"] = "rbxassetid://71954360551345",
	["file-chart-pie"] = "rbxassetid://81072193564497",
	["file-check-corner"] = "rbxassetid://76295552859171",
	["file-check"] = "rbxassetid://82604001452455",
	["file-clock"] = "rbxassetid://102325208830990",
	["file-code-corner"] = "rbxassetid://78293841184371",
	["file-code"] = "rbxassetid://130978036895504",
	["file-cog"] = "rbxassetid://101385347151368",
	["file-diff"] = "rbxassetid://96147216772241",
	["file-digit"] = "rbxassetid://89220220354580",
	["file-down"] = "rbxassetid://120650154178290",
	["file-exclamation-point"] = "rbxassetid://102821865889635",
	["file-headphone"] = "rbxassetid://100533735901986",
	["file-heart"] = "rbxassetid://132214916401696",
	["file-image"] = "rbxassetid://123334057511782",
	["file-input"] = "rbxassetid://124728604166044",
	["file-key"] = "rbxassetid://118790255921100",
	["file-lock"] = "rbxassetid://72170228691242",
	["file-minus-corner"] = "rbxassetid://119263271735124",
	["file-minus"] = "rbxassetid://111014798459222",
	["file-music"] = "rbxassetid://134948051536671",
	["file-output"] = "rbxassetid://92146832572911",
	["file-pen-line"] = "rbxassetid://104622936345006",
	["file-pen"] = "rbxassetid://79556179730240",
	["file-play"] = "rbxassetid://89006821567838",
	["file-plus-corner"] = "rbxassetid://76544604043974",
	["file-plus"] = "rbxassetid://78881710800060",
	["file-question-mark"] = "rbxassetid://127617422859576",
	["file-scan"] = "rbxassetid://129480105228213",
	["file-search-corner"] = "rbxassetid://90974165234008",
	["file-search"] = "rbxassetid://97780235974933",
	["file-signal"] = "rbxassetid://122070252538165",
	["file-sliders"] = "rbxassetid://85787771732439",
	["file-spreadsheet"] = "rbxassetid://134501869359270",
	["file-stack"] = "rbxassetid://138929929862605",
	["file-symlink"] = "rbxassetid://91865722036510",
	["file-terminal"] = "rbxassetid://116757454755476",
	["file-text"] = "rbxassetid://90496405707281",
	["file-type-corner"] = "rbxassetid://124902230275209",
	["file-type"] = "rbxassetid://115272552799361",
	["file-up"] = "rbxassetid://131173039312748",
	["file-user"] = "rbxassetid://99552018455009",
	["file-video-camera"] = "rbxassetid://81719056173960",
	["file-volume"] = "rbxassetid://111264764438958",
	["file-x-corner"] = "rbxassetid://87554136773609",
	["file-x"] = "rbxassetid://107333775515154",
	["file"] = "rbxassetid://74748492079329",
	["files"] = "rbxassetid://102806336233202",
	["film"] = "rbxassetid://120978945609706",
	["fingerprint"] = "rbxassetid://112173305232811",
	["fire-extinguisher"] = "rbxassetid://111643493006960",
	["fish-off"] = "rbxassetid://89756724887508",
	["fish-symbol"] = "rbxassetid://118475177681618",
	["fish"] = "rbxassetid://124360663785796",
	["flag-off"] = "rbxassetid://112944528856799",
	["flag-triangle-left"] = "rbxassetid://88045221285272",
	["flag-triangle-right"] = "rbxassetid://108292480304566",
	["flag"] = "rbxassetid://78183383236196",
	["flame-kindling"] = "rbxassetid://139728976917928",
	["flame"] = "rbxassetid://98218034436456",
	["flashlight-off"] = "rbxassetid://79780362871740",
	["flashlight"] = "rbxassetid://100286985600444",
	["flask-conical-off"] = "rbxassetid://112597970025298",
	["flask-conical"] = "rbxassetid://128406680901165",
	["flask-round"] = "rbxassetid://127508287324940",
	["flip-horizontal-2"] = "rbxassetid://103726993598186",
	["flip-horizontal"] = "rbxassetid://122937530107837",
	["flip-vertical-2"] = "rbxassetid://103836358956328",
	["flip-vertical"] = "rbxassetid://108003917346888",
	["flower-2"] = "rbxassetid://72934574245145",
	["flower"] = "rbxassetid://86129438272762",
	["focus"] = "rbxassetid://87493973153317",
	["fold-horizontal"] = "rbxassetid://92835712442240",
	["fold-vertical"] = "rbxassetid://108873727253656",
	["folder-archive"] = "rbxassetid://97312009460206",
	["folder-check"] = "rbxassetid://128492920904557",
	["folder-clock"] = "rbxassetid://111964836738545",
	["folder-closed"] = "rbxassetid://118286209350843",
	["folder-code"] = "rbxassetid://70624096349370",
	["folder-cog"] = "rbxassetid://85299519462846",
	["folder-dot"] = "rbxassetid://138687772725278",
	["folder-down"] = "rbxassetid://118044108459225",
	["folder-git-2"] = "rbxassetid://101394054141166",
	["folder-git"] = "rbxassetid://121885778095158",
	["folder-heart"] = "rbxassetid://79104747211105",
	["folder-input"] = "rbxassetid://90699920697871",
	["folder-kanban"] = "rbxassetid://78313285104072",
	["folder-key"] = "rbxassetid://85270407596791",
	["folder-lock"] = "rbxassetid://119201572260567",
	["folder-minus"] = "rbxassetid://85648718999010",
	["folder-open-dot"] = "rbxassetid://74741494767354",
	["folder-open"] = "rbxassetid://76018996254888",
	["folder-output"] = "rbxassetid://101532447937612",
	["folder-pen"] = "rbxassetid://112770491173911",
	["folder-plus"] = "rbxassetid://91865663406119",
	["folder-root"] = "rbxassetid://103333751154693",
	["folder-search-2"] = "rbxassetid://71276453442655",
	["folder-search"] = "rbxassetid://110568075123861",
	["folder-symlink"] = "rbxassetid://127485747227189",
	["folder-sync"] = "rbxassetid://91544602659796",
	["folder-tree"] = "rbxassetid://85577554337861",
	["folder-up"] = "rbxassetid://72008269765857",
	["folder-x"] = "rbxassetid://91699618247635",
	["folder"] = "rbxassetid://80846616596607",
	["folders"] = "rbxassetid://110351216219061",
	["footprints"] = "rbxassetid://139192589041315",
	["forklift"] = "rbxassetid://72030930983101",
	["forward"] = "rbxassetid://97545944739523",
	["frame"] = "rbxassetid://109080612832751",
	["framer"] = "rbxassetid://108384807262391",
	["frown"] = "rbxassetid://124407301067982",
	["fuel"] = "rbxassetid://106447647274511",
	["fullscreen"] = "rbxassetid://77793665526178",
	["funnel-plus"] = "rbxassetid://100780233821928",
	["funnel-x"] = "rbxassetid://70984385812555",
	["funnel"] = "rbxassetid://108829540827529",
	["gallery-horizontal-end"] = "rbxassetid://74672430161161",
	["gallery-horizontal"] = "rbxassetid://80004001442122",
	["gallery-thumbnails"] = "rbxassetid://136219289862706",
	["gallery-vertical-end"] = "rbxassetid://106461402088317",
	["gallery-vertical"] = "rbxassetid://119299431466725",
	["gamepad-2"] = "rbxassetid://92483947987410",
	["gamepad-directional"] = "rbxassetid://84342305212226",
	["gamepad"] = "rbxassetid://121607283959010",
	["gauge"] = "rbxassetid://110273524101447",
	["gavel"] = "rbxassetid://78952298198456",
	["gem"] = "rbxassetid://112904952151156",
	["georgian-lari"] = "rbxassetid://98084432591687",
	["ghost"] = "rbxassetid://113822048130017",
	["gift"] = "rbxassetid://109855212076373",
	["git-branch-minus"] = "rbxassetid://97385010649411",
	["git-branch-plus"] = "rbxassetid://125944221134316",
	["git-branch"] = "rbxassetid://90490195516649",
	["git-commit-horizontal"] = "rbxassetid://133646041800147",
	["git-commit-vertical"] = "rbxassetid://122098032990350",
	["git-compare-arrows"] = "rbxassetid://84874426520216",
	["git-compare"] = "rbxassetid://91945124438792",
	["git-fork"] = "rbxassetid://89954992404765",
	["git-graph"] = "rbxassetid://86166832019304",
	["git-merge"] = "rbxassetid://131833355158059",
	["git-pull-request-arrow"] = "rbxassetid://94507974577439",
	["git-pull-request-closed"] = "rbxassetid://78070600389091",
	["git-pull-request-create-arrow"] = "rbxassetid://127422677061091",
	["git-pull-request-create"] = "rbxassetid://105929577383926",
	["git-pull-request-draft"] = "rbxassetid://76173459869943",
	["git-pull-request"] = "rbxassetid://138463010991471",
	["github"] = "rbxassetid://120349554354380",
	["gitlab"] = "rbxassetid://114054627192933",
	["glass-water"] = "rbxassetid://115526102400988",
	["glasses"] = "rbxassetid://87936407455373",
	["globe-lock"] = "rbxassetid://134065526704402",
	["globe"] = "rbxassetid://114238209622913",
	["goal"] = "rbxassetid://120517954878160",
	["gpu"] = "rbxassetid://95577823614219",
	["graduation-cap"] = "rbxassetid://93771896340220",
	["grape"] = "rbxassetid://134760640415561",
	["grid-2x2-check"] = "rbxassetid://138468840220821",
	["grid-2x2-plus"] = "rbxassetid://91811610580247",
	["grid-2x2-x"] = "rbxassetid://72407303981388",
	["grid-2x2"] = "rbxassetid://99050491897640",
	["grid-3x2"] = "rbxassetid://95528684210010",
	["grid-3x3"] = "rbxassetid://70419024781206",
	["grip-horizontal"] = "rbxassetid://136255899715930",
	["grip-vertical"] = "rbxassetid://137183678565296",
	["grip"] = "rbxassetid://109058783556768",
	["group"] = "rbxassetid://107643418926671",
	["guitar"] = "rbxassetid://75915531867926",
	["ham"] = "rbxassetid://74465607934635",
	["hamburger"] = "rbxassetid://93086916815495",
	["hammer"] = "rbxassetid://83545120140895",
	["hand-coins"] = "rbxassetid://126990543175462",
	["hand-fist"] = "rbxassetid://83341608917591",
	["hand-grab"] = "rbxassetid://88867162163985",
	["hand-heart"] = "rbxassetid://117507367668412",
	["hand-helping"] = "rbxassetid://89897738419446",
	["hand-metal"] = "rbxassetid://113619498548713",
	["hand-platter"] = "rbxassetid://88594727743168",
	["hand"] = "rbxassetid://130703864968637",
	["handbag"] = "rbxassetid://135675846264061",
	["handshake"] = "rbxassetid://78442115255814",
	["hard-drive-download"] = "rbxassetid://73913801230614",
	["hard-drive-upload"] = "rbxassetid://85762133615118",
	["hard-drive"] = "rbxassetid://88183305858463",
	["hard-hat"] = "rbxassetid://128050846767382",
	["hash"] = "rbxassetid://82890331678520",
	["hat-glasses"] = "rbxassetid://101165538224815",
	["haze"] = "rbxassetid://108857561768901",
	["hdmi-port"] = "rbxassetid://103693661037020",
	["heading-1"] = "rbxassetid://118129315662110",
	["heading-2"] = "rbxassetid://110209069670094",
	["heading-3"] = "rbxassetid://90267885237062",
	["heading-4"] = "rbxassetid://129625620307602",
	["heading-5"] = "rbxassetid://120386663181267",
	["heading-6"] = "rbxassetid://90959079775093",
	["heading"] = "rbxassetid://129254312067735",
	["headphone-off"] = "rbxassetid://85038251615641",
	["headphones"] = "rbxassetid://118833729589183",
	["headset"] = "rbxassetid://129269236787694",
	["heart-crack"] = "rbxassetid://110987638564119",
	["heart-handshake"] = "rbxassetid://111483078692002",
	["heart-minus"] = "rbxassetid://96827380163326",
	["heart-off"] = "rbxassetid://89748414415617",
	["heart-plus"] = "rbxassetid://94877796283249",
	["heart-pulse"] = "rbxassetid://129352925579546",
	["heart"] = "rbxassetid://116559368303288",
	["heater"] = "rbxassetid://140478466880916",
	["helicopter"] = "rbxassetid://111557171735930",
	["hexagon"] = "rbxassetid://127592089339199",
	["highlighter"] = "rbxassetid://77411555641113",
	["history"] = "rbxassetid://123980022019922",
	["hop-off"] = "rbxassetid://103386036934034",
	["hop"] = "rbxassetid://82778923997672",
	["hospital"] = "rbxassetid://105868763850707",
	["hotel"] = "rbxassetid://132283390859718",
	["hourglass"] = "rbxassetid://86160434939203",
	["house-heart"] = "rbxassetid://136054771868597",
	["house-plug"] = "rbxassetid://71438263712075",
	["house-plus"] = "rbxassetid://118495165208309",
	["house-wifi"] = "rbxassetid://126495519725698",
	["house"] = "rbxassetid://98755624629571",
	["ice-cream-bowl"] = "rbxassetid://124867218454386",
	["ice-cream-cone"] = "rbxassetid://90751397288639",
	["id-card-lanyard"] = "rbxassetid://90761480469224",
	["id-card"] = "rbxassetid://75354294622640",
	["image-down"] = "rbxassetid://78972295741235",
	["image-minus"] = "rbxassetid://101066016918565",
	["image-off"] = "rbxassetid://81934811700938",
	["image-play"] = "rbxassetid://129501806784210",
	["image-plus"] = "rbxassetid://70391970623917",
	["image-up"] = "rbxassetid://126610009605241",
	["image-upscale"] = "rbxassetid://106963545024679",
	["images"] = "rbxassetid://79350649395557",
	["import"] = "rbxassetid://116545008906029",
	["inbox"] = "rbxassetid://112591360302868",
	["indian-rupee"] = "rbxassetid://113038778381805",
	["infinity"] = "rbxassetid://98083086936965",
	["info"] = "rbxassetid://124560466474914",
	["inspection-panel"] = "rbxassetid://70905313146088",
	["instagram"] = "rbxassetid://119864798614855",
	["italic"] = "rbxassetid://96220378864282",
	["iteration-ccw"] = "rbxassetid://140221832794083",
	["iteration-cw"] = "rbxassetid://95534489554662",
	["japanese-yen"] = "rbxassetid://106362863465813",
	["joystick"] = "rbxassetid://99416790224739",
	["kanban"] = "rbxassetid://125934100055431",
	["kayak"] = "rbxassetid://136107544609389",
	["key-round"] = "rbxassetid://83619031955390",
	["key-square"] = "rbxassetid://94621420033649",
	["key"] = "rbxassetid://96510194465420",
	["keyboard-music"] = "rbxassetid://121058541758636",
	["keyboard-off"] = "rbxassetid://92466375369772",
	["keyboard"] = "rbxassetid://121474456068237",
	["lamp-ceiling"] = "rbxassetid://80032758469141",
	["lamp-desk"] = "rbxassetid://85290686983238",
	["lamp-floor"] = "rbxassetid://104585881375892",
	["lamp-wall-down"] = "rbxassetid://91271394132073",
	["lamp-wall-up"] = "rbxassetid://132141464337445",
	["lamp"] = "rbxassetid://110730830653382",
	["land-plot"] = "rbxassetid://96449039620294",
	["landmark"] = "rbxassetid://76885079756393",
	["languages"] = "rbxassetid://90816903776498",
	["laptop-minimal-check"] = "rbxassetid://114352019833865",
	["laptop-minimal"] = "rbxassetid://136705765566068",
	["laptop"] = "rbxassetid://111387063244975",
	["lasso-select"] = "rbxassetid://105609719912753",
	["lasso"] = "rbxassetid://121072936884007",
	["laugh"] = "rbxassetid://104491311361166",
	["layers-2"] = "rbxassetid://70536710516357",
	["layers"] = "rbxassetid://81973586053257",
	["layout-dashboard"] = "rbxassetid://139929981863901",
	["layout-grid"] = "rbxassetid://81344910161871",
	["layout-list"] = "rbxassetid://87462136296578",
	["layout-panel-left"] = "rbxassetid://125092469751491",
	["layout-panel-top"] = "rbxassetid://91943941515944",
	["layout-template"] = "rbxassetid://115564446417985",
	["leaf"] = "rbxassetid://119951075637174",
	["leafy-green"] = "rbxassetid://105146290493154",
	["lectern"] = "rbxassetid://106166425183862",
	["library-big"] = "rbxassetid://106794530191412",
	["library"] = "rbxassetid://114334671982047",
	["life-buoy"] = "rbxassetid://81168450671956",
	["ligature"] = "rbxassetid://111397873269411",
	["lightbulb-off"] = "rbxassetid://83795722296178",
	["lightbulb"] = "rbxassetid://103871245626488",
	["line-squiggle"] = "rbxassetid://109555164424447",
	["link-2-off"] = "rbxassetid://76885956296867",
	["link-2"] = "rbxassetid://86072351557466",
	["link"] = "rbxassetid://131607023382430",
	["linkedin"] = "rbxassetid://132842789255788",
	["list-check"] = "rbxassetid://72374358471156",
	["list-checks"] = "rbxassetid://99809353635593",
	["list-chevrons-down-up"] = "rbxassetid://137409641500711",
	["list-chevrons-up-down"] = "rbxassetid://81825351389084",
	["list-collapse"] = "rbxassetid://124505247702401",
	["list-end"] = "rbxassetid://77650610048119",
	["list-filter-plus"] = "rbxassetid://96385120752336",
	["list-filter"] = "rbxassetid://103321376129527",
	["list-indent-decrease"] = "rbxassetid://137879979228193",
	["list-indent-increase"] = "rbxassetid://79051053161201",
	["list-minus"] = "rbxassetid://138507965142671",
	["list-music"] = "rbxassetid://126380635781840",
	["list-ordered"] = "rbxassetid://83212528113913",
	["list-plus"] = "rbxassetid://112384738137814",
	["list-restart"] = "rbxassetid://91703153577421",
	["list-start"] = "rbxassetid://84828348299727",
	["list-todo"] = "rbxassetid://132980603752108",
	["list-tree"] = "rbxassetid://97685396239010",
	["list-video"] = "rbxassetid://93648525452489",
	["list-x"] = "rbxassetid://113025303988861",
	["list"] = "rbxassetid://113179976918783",
	["loader-circle"] = "rbxassetid://116535712789945",
	["loader-pinwheel"] = "rbxassetid://108513357940900",
	["loader"] = "rbxassetid://78408734580845",
	["locate-fixed"] = "rbxassetid://137367361548433",
	["locate-off"] = "rbxassetid://73729216338137",
	["locate"] = "rbxassetid://84467676590391",
	["lock-keyhole-open"] = "rbxassetid://110863509313073",
	["lock-keyhole"] = "rbxassetid://78672912777756",
	["lock-open"] = "rbxassetid://93597915325122",
	["lock"] = "rbxassetid://134724289526879",
	["log-in"] = "rbxassetid://103768533135201",
	["log-out"] = "rbxassetid://84895399304975",
	["logs"] = "rbxassetid://89772091251787",
	["lollipop"] = "rbxassetid://84681611583044",
	["luggage"] = "rbxassetid://76619236486400",
	["magnet"] = "rbxassetid://135162361226972",
	["mail-check"] = "rbxassetid://86921536259917",
	["mail-minus"] = "rbxassetid://81989813236553",
	["mail-open"] = "rbxassetid://122785416858638",
	["mail-plus"] = "rbxassetid://104886401588341",
	["mail-question-mark"] = "rbxassetid://126540170949819",
	["mail-search"] = "rbxassetid://135616173775287",
	["mail-warning"] = "rbxassetid://81495303676089",
	["mail-x"] = "rbxassetid://74607841705644",
	["mail"] = "rbxassetid://103945161245599",
	["mailbox"] = "rbxassetid://82765503320335",
	["mails"] = "rbxassetid://90673453450080",
	["map-minus"] = "rbxassetid://129525760577747",
	["map-pin-check-inside"] = "rbxassetid://107130529843809",
	["map-pin-check"] = "rbxassetid://118110914690154",
	["map-pin-house"] = "rbxassetid://80546885029816",
	["map-pin-minus-inside"] = "rbxassetid://79005529692964",
	["map-pin-minus"] = "rbxassetid://74518762643623",
	["map-pin-off"] = "rbxassetid://82474689391020",
	["map-pin-pen"] = "rbxassetid://113515395277504",
	["map-pin-plus-inside"] = "rbxassetid://134639656514430",
	["map-pin-plus"] = "rbxassetid://91875228967029",
	["map-pin-x-inside"] = "rbxassetid://126235934252379",
	["map-pin-x"] = "rbxassetid://101085273547316",
	["map-pin"] = "rbxassetid://84279202219901",
	["map-pinned"] = "rbxassetid://103963788475034",
	["map-plus"] = "rbxassetid://129388826743495",
	["map"] = "rbxassetid://95107167260947",
	["mars-stroke"] = "rbxassetid://131973193186828",
	["mars"] = "rbxassetid://111287112372511",
	["martini"] = "rbxassetid://82977695401058",
	["maximize-2"] = "rbxassetid://73085922906397",
	["maximize"] = "rbxassetid://76045941763188",
	["medal"] = "rbxassetid://79016002264450",
	["megaphone-off"] = "rbxassetid://124280774193935",
	["megaphone"] = "rbxassetid://118759541854879",
	["meh"] = "rbxassetid://132197867028557",
	["memory-stick"] = "rbxassetid://93212591343119",
	["menu"] = "rbxassetid://77021539815611",
	["merge"] = "rbxassetid://126201866476775",
	["message-circle-code"] = "rbxassetid://112865244991651",
	["message-circle-dashed"] = "rbxassetid://81525157881897",
	["message-circle-heart"] = "rbxassetid://101990756073677",
	["message-circle-more"] = "rbxassetid://92856823884663",
	["message-circle-off"] = "rbxassetid://134955643890328",
	["message-circle-plus"] = "rbxassetid://106562979649273",
	["message-circle-question-mark"] = "rbxassetid://107700302759934",
	["message-circle-reply"] = "rbxassetid://137071749508334",
	["message-circle-warning"] = "rbxassetid://119020096067894",
	["message-circle-x"] = "rbxassetid://126843387725536",
	["message-circle"] = "rbxassetid://127255077587058",
	["message-square-code"] = "rbxassetid://110968863152123",
	["message-square-dashed"] = "rbxassetid://107653455516238",
	["message-square-diff"] = "rbxassetid://75472190472625",
	["message-square-dot"] = "rbxassetid://127806382463916",
	["message-square-heart"] = "rbxassetid://75612811742074",
	["message-square-lock"] = "rbxassetid://81268215619563",
	["message-square-more"] = "rbxassetid://120139782405970",
	["message-square-off"] = "rbxassetid://99961019005789",
	["message-square-plus"] = "rbxassetid://76934450256199",
	["message-square-quote"] = "rbxassetid://116670768629340",
	["message-square-reply"] = "rbxassetid://130985622754637",
	["message-square-share"] = "rbxassetid://131017005324026",
	["message-square-text"] = "rbxassetid://94899503194205",
	["message-square-warning"] = "rbxassetid://138432903962261",
	["message-square-x"] = "rbxassetid://137285463279462",
	["message-square"] = "rbxassetid://83881670383280",
	["messages-square"] = "rbxassetid://97532166733358",
	["mic-off"] = "rbxassetid://82123034444822",
	["mic-vocal"] = "rbxassetid://99082286164362",
	["mic"] = "rbxassetid://89640799126523",
	["microchip"] = "rbxassetid://73937907669903",
	["microscope"] = "rbxassetid://116875530102782",
	["microwave"] = "rbxassetid://108411735353008",
	["milestone"] = "rbxassetid://101618292325920",
	["milk-off"] = "rbxassetid://72388480962742",
	["milk"] = "rbxassetid://96221903896918",
	["minimize-2"] = "rbxassetid://116269596042539",
	["minimize"] = "rbxassetid://121304296213645",
	["minus"] = "rbxassetid://118026365011536",
	["monitor-check"] = "rbxassetid://86651948439229",
	["monitor-cloud"] = "rbxassetid://85931096038318",
	["monitor-cog"] = "rbxassetid://94345128715799",
	["monitor-dot"] = "rbxassetid://130394010063680",
	["monitor-down"] = "rbxassetid://97466933743423",
	["monitor-off"] = "rbxassetid://74395526657953",
	["monitor-pause"] = "rbxassetid://76002184067562",
	["monitor-play"] = "rbxassetid://133018824306217",
	["monitor-smartphone"] = "rbxassetid://84335680433378",
	["monitor-speaker"] = "rbxassetid://81744810060380",
	["monitor-stop"] = "rbxassetid://98708958984757",
	["monitor-up"] = "rbxassetid://96035360858377",
	["monitor-x"] = "rbxassetid://126265210441423",
	["monitor"] = "rbxassetid://72664649203050",
	["moon-star"] = "rbxassetid://82782200506348",
	["moon"] = "rbxassetid://83380517901735",
	["motorbike"] = "rbxassetid://94580787368233",
	["mountain-snow"] = "rbxassetid://105315495740588",
	["mountain"] = "rbxassetid://73269957566415",
	["mouse-off"] = "rbxassetid://75267871697595",
	["mouse-pointer-2-off"] = "rbxassetid://104701076865632",
	["mouse-pointer-2"] = "rbxassetid://117093892862228",
	["mouse-pointer-ban"] = "rbxassetid://106849413057133",
	["mouse-pointer-click"] = "rbxassetid://107150227368485",
	["mouse-pointer"] = "rbxassetid://72322454962935",
	["mouse"] = "rbxassetid://73096068864710",
	["move-3d"] = "rbxassetid://103365982054003",
	["move-diagonal-2"] = "rbxassetid://117298577948096",
	["move-diagonal"] = "rbxassetid://101433481954184",
	["move-down-left"] = "rbxassetid://102819433534567",
	["move-down-right"] = "rbxassetid://101479760041877",
	["move-down"] = "rbxassetid://70510115135583",
	["move-horizontal"] = "rbxassetid://88513523439149",
	["move-left"] = "rbxassetid://137614740247980",
	["move-right"] = "rbxassetid://132455779472989",
	["move-up-left"] = "rbxassetid://139079815540148",
	["move-up-right"] = "rbxassetid://105885140592646",
	["move-up"] = "rbxassetid://84505444262658",
	["move-vertical"] = "rbxassetid://86234730730899",
	["move"] = "rbxassetid://116138709011735",
	["music-2"] = "rbxassetid://134397426600888",
	["music-3"] = "rbxassetid://94466120066498",
	["music-4"] = "rbxassetid://132459323665838",
	["music"] = "rbxassetid://113343203848535",
	["navigation-2-off"] = "rbxassetid://116569611780763",
	["navigation-2"] = "rbxassetid://81889066747907",
	["navigation-off"] = "rbxassetid://87003270290777",
	["navigation"] = "rbxassetid://79308213542922",
	["network"] = "rbxassetid://127410729922644",
	["newspaper"] = "rbxassetid://123479530460544",
	["nfc"] = "rbxassetid://76822396542242",
	["non-binary"] = "rbxassetid://78442360386235",
	["notebook-pen"] = "rbxassetid://140380614761023",
	["notebook-tabs"] = "rbxassetid://127371085570083",
	["notebook-text"] = "rbxassetid://93061585217270",
	["notebook"] = "rbxassetid://136132108664987",
	["notepad-text-dashed"] = "rbxassetid://135793446376219",
	["notepad-text"] = "rbxassetid://93404682958966",
	["nut-off"] = "rbxassetid://78795397311573",
	["nut"] = "rbxassetid://127146410705656",
	["octagon-alert"] = "rbxassetid://140438367956051",
	["octagon-minus"] = "rbxassetid://74720436795421",
	["octagon-pause"] = "rbxassetid://103161463909039",
	["octagon-x"] = "rbxassetid://90498161006311",
	["octagon"] = "rbxassetid://120803515514852",
	["omega"] = "rbxassetid://70414080018786",
	["option"] = "rbxassetid://100776883894054",
	["orbit"] = "rbxassetid://108926136860562",
	["origami"] = "rbxassetid://136020626667101",
	["package-2"] = "rbxassetid://70394974762575",
	["package-check"] = "rbxassetid://102374216055130",
	["package-minus"] = "rbxassetid://114492858789692",
	["package-open"] = "rbxassetid://132890233237818",
	["package-plus"] = "rbxassetid://129261988138366",
	["package-search"] = "rbxassetid://95465120894145",
	["package-x"] = "rbxassetid://70818501607442",
	["package"] = "rbxassetid://97261141732706",
	["paint-bucket"] = "rbxassetid://124275586663284",
	["paint-roller"] = "rbxassetid://115248074358348",
	["paintbrush-vertical"] = "rbxassetid://105151296591292",
	["paintbrush"] = "rbxassetid://125572663700289",
	["palette"] = "rbxassetid://86350350950064",
	["panda"] = "rbxassetid://132509022802512",
	["panel-bottom-close"] = "rbxassetid://74287004071159",
	["panel-bottom-dashed"] = "rbxassetid://131084651621603",
	["panel-bottom-open"] = "rbxassetid://107768659586540",
	["panel-bottom"] = "rbxassetid://132127145048511",
	["panel-left-close"] = "rbxassetid://126579818823552",
	["panel-left-dashed"] = "rbxassetid://75536606374585",
	["panel-left-open"] = "rbxassetid://111075816195767",
	["panel-left-right-dashed"] = "rbxassetid://110100707973959",
	["panel-left"] = "rbxassetid://97419752870313",
	["panel-right-close"] = "rbxassetid://139528655524132",
	["panel-right-dashed"] = "rbxassetid://94959793877311",
	["panel-right-open"] = "rbxassetid://118114419142794",
	["panel-right"] = "rbxassetid://116365035443156",
	["panel-top-bottom-dashed"] = "rbxassetid://134737235653344",
	["panel-top-close"] = "rbxassetid://83578325777808",
	["panel-top-dashed"] = "rbxassetid://70522913169237",
	["panel-top-open"] = "rbxassetid://137959875507454",
	["panel-top"] = "rbxassetid://75838479462875",
	["panels-left-bottom"] = "rbxassetid://72996856149149",
	["panels-right-bottom"] = "rbxassetid://90659068960726",
	["panels-top-left"] = "rbxassetid://79858853850600",
	["paperclip"] = "rbxassetid://92088291163453",
	["parentheses"] = "rbxassetid://78950955173096",
	["parking-meter"] = "rbxassetid://84652733960568",
	["party-popper"] = "rbxassetid://111626795712193",
	["pause"] = "rbxassetid://74873705394436",
	["paw-print"] = "rbxassetid://112218825427601",
	["pc-case"] = "rbxassetid://122978648019101",
	["pen-line"] = "rbxassetid://109108135755303",
	["pen-off"] = "rbxassetid://84807123119438",
	["pen-tool"] = "rbxassetid://106145404953445",
	["pen"] = "rbxassetid://72037878096321",
	["pencil-line"] = "rbxassetid://88392917053533",
	["pencil-off"] = "rbxassetid://103330927652832",
	["pencil-ruler"] = "rbxassetid://110120288284597",
	["pencil"] = "rbxassetid://137986121120732",
	["pentagon"] = "rbxassetid://79184802179890",
	["percent"] = "rbxassetid://130155041032013",
	["person-standing"] = "rbxassetid://125020872044147",
	["philippine-peso"] = "rbxassetid://91173798254675",
	["phone-call"] = "rbxassetid://70555587592860",
	["phone-forwarded"] = "rbxassetid://113269614319737",
	["phone-incoming"] = "rbxassetid://82863576359288",
	["phone-missed"] = "rbxassetid://130156165198376",
	["phone-off"] = "rbxassetid://133318623553383",
	["phone-outgoing"] = "rbxassetid://104576478735825",
	["phone"] = "rbxassetid://128804946640049",
	["pi"] = "rbxassetid://74936036243146",
	["piano"] = "rbxassetid://85008880789520",
	["pickaxe"] = "rbxassetid://105888023317688",
	["picture-in-picture-2"] = "rbxassetid://112803319544468",
	["picture-in-picture"] = "rbxassetid://80579597835123",
	["piggy-bank"] = "rbxassetid://79498575790721",
	["pilcrow-left"] = "rbxassetid://103803000849583",
	["pilcrow-right"] = "rbxassetid://104881733911870",
	["pilcrow"] = "rbxassetid://139512780392871",
	["pill-bottle"] = "rbxassetid://118394692404597",
	["pill"] = "rbxassetid://73280534813448",
	["pin-off"] = "rbxassetid://127696372451750",
	["pin"] = "rbxassetid://120978111007514",
	["pipette"] = "rbxassetid://133167932934404",
	["pizza"] = "rbxassetid://126964453193501",
	["plane-landing"] = "rbxassetid://122555692211889",
	["plane-takeoff"] = "rbxassetid://117179478829575",
	["plane"] = "rbxassetid://126985561580989",
	["play"] = "rbxassetid://135609604299893",
	["plug-2"] = "rbxassetid://97912386476366",
	["plug-zap"] = "rbxassetid://74506269884055",
	["plug"] = "rbxassetid://99782373064495",
	["plus"] = "rbxassetid://111774323017047",
	["pocket-knife"] = "rbxassetid://134075428063965",
	["pocket"] = "rbxassetid://136686762542964",
	["podcast"] = "rbxassetid://109577075549215",
	["pointer-off"] = "rbxassetid://95488389312794",
	["pointer"] = "rbxassetid://92615117311099",
	["popcorn"] = "rbxassetid://139446511232750",
	["popsicle"] = "rbxassetid://112696318077073",
	["pound-sterling"] = "rbxassetid://127482649469130",
	["power-off"] = "rbxassetid://118768311012214",
	["power"] = "rbxassetid://96479131758775",
	["presentation"] = "rbxassetid://106134583757890",
	["printer-check"] = "rbxassetid://130273549443689",
	["printer"] = "rbxassetid://76080649734247",
	["projector"] = "rbxassetid://103281856385283",
	["proportions"] = "rbxassetid://130046855997237",
	["puzzle"] = "rbxassetid://136837798892463",
	["pyramid"] = "rbxassetid://107811442374127",
	["qr-code"] = "rbxassetid://105329945723350",
	["quote"] = "rbxassetid://103271711590001",
	["rabbit"] = "rbxassetid://98580518804206",
	["radar"] = "rbxassetid://138528222906635",
	["radiation"] = "rbxassetid://104499586848433",
	["radical"] = "rbxassetid://132758286926047",
	["radio-receiver"] = "rbxassetid://129598303378835",
	["radio-tower"] = "rbxassetid://93958663130054",
	["radio"] = "rbxassetid://85611589536956",
	["radius"] = "rbxassetid://89814505307129",
	["rail-symbol"] = "rbxassetid://134295386306962",
	["rainbow"] = "rbxassetid://132488862841895",
	["rat"] = "rbxassetid://127400975953159",
	["ratio"] = "rbxassetid://126369423897295",
	["receipt-cent"] = "rbxassetid://91557573925201",
	["receipt-euro"] = "rbxassetid://94015722210295",
	["receipt-indian-rupee"] = "rbxassetid://89718170439990",
	["receipt-japanese-yen"] = "rbxassetid://132472560758851",
	["receipt-pound-sterling"] = "rbxassetid://73934967569625",
	["receipt-russian-ruble"] = "rbxassetid://105164576936853",
	["receipt-swiss-franc"] = "rbxassetid://72503668620116",
	["receipt-text"] = "rbxassetid://138483536013737",
	["receipt-turkish-lira"] = "rbxassetid://91950765836342",
	["receipt"] = "rbxassetid://77877895901792",
	["rectangle-circle"] = "rbxassetid://100642423153903",
	["rectangle-ellipsis"] = "rbxassetid://112919953980965",
	["rectangle-goggles"] = "rbxassetid://98605436666727",
	["rectangle-horizontal"] = "rbxassetid://90224199814966",
	["rectangle-vertical"] = "rbxassetid://117277050590967",
	["recycle"] = "rbxassetid://140417023381961",
	["redo-2"] = "rbxassetid://70451039017914",
	["redo-dot"] = "rbxassetid://94252981719732",
	["redo"] = "rbxassetid://116150342119054",
	["refresh-ccw-dot"] = "rbxassetid://106702246753270",
	["refresh-ccw"] = "rbxassetid://117913330389477",
	["refresh-cw-off"] = "rbxassetid://140179498843054",
	["refresh-cw"] = "rbxassetid://138133190015277",
	["refrigerator"] = "rbxassetid://102614042652753",
	["regex"] = "rbxassetid://100727200791841",
	["remove-formatting"] = "rbxassetid://112833162022628",
	["repeat-1"] = "rbxassetid://130144534857095",
	["repeat-2"] = "rbxassetid://85927537182704",
	["repeat"] = "rbxassetid://121886242955173",
	["replace-all"] = "rbxassetid://127862728198635",
	["replace"] = "rbxassetid://128404082279430",
	["reply-all"] = "rbxassetid://71723137343562",
	["reply"] = "rbxassetid://109788633497028",
	["rewind"] = "rbxassetid://95205297521988",
	["ribbon"] = "rbxassetid://94265331526851",
	["rocket"] = "rbxassetid://87412317685854",
	["rocking-chair"] = "rbxassetid://110420269495360",
	["roller-coaster"] = "rbxassetid://112426178972099",
	["rose"] = "rbxassetid://126336840238769",
	["rotate-3d"] = "rbxassetid://76300551576392",
	["rotate-ccw-key"] = "rbxassetid://74976035240976",
	["rotate-ccw-square"] = "rbxassetid://90515853170424",
	["rotate-ccw"] = "rbxassetid://110116685948665",
	["rotate-cw-square"] = "rbxassetid://77095448159303",
	["rotate-cw"] = "rbxassetid://84183336178654",
	["route-off"] = "rbxassetid://106350402024079",
	["route"] = "rbxassetid://89968303228953",
	["router"] = "rbxassetid://102130331994471",
	["rows-2"] = "rbxassetid://112556185960101",
	["rows-3"] = "rbxassetid://117215586961375",
	["rows-4"] = "rbxassetid://125646021959055",
	["rss"] = "rbxassetid://131789058984793",
	["ruler-dimension-line"] = "rbxassetid://70673861371412",
	["ruler"] = "rbxassetid://81432445547423",
	["russian-ruble"] = "rbxassetid://126357936542156",
	["sailboat"] = "rbxassetid://87110567187540",
	["salad"] = "rbxassetid://128864507821603",
	["sandwich"] = "rbxassetid://104573187458917",
	["satellite-dish"] = "rbxassetid://136742443888305",
	["satellite"] = "rbxassetid://134967053164645",
	["saudi-riyal"] = "rbxassetid://102282769104635",
	["save-all"] = "rbxassetid://116946975799440",
	["save-off"] = "rbxassetid://87085435778560",
	["save"] = "rbxassetid://126116963775616",
	["scale-3d"] = "rbxassetid://72414199620352",
	["scale"] = "rbxassetid://108203682317477",
	["scaling"] = "rbxassetid://122360365318466",
	["scan-barcode"] = "rbxassetid://96889457154761",
	["scan-eye"] = "rbxassetid://99244790601968",
	["scan-face"] = "rbxassetid://109959345069668",
	["scan-heart"] = "rbxassetid://106280819776142",
	["scan-line"] = "rbxassetid://126544908146540",
	["scan-qr-code"] = "rbxassetid://105409149549927",
	["scan-search"] = "rbxassetid://80009010551347",
	["scan-text"] = "rbxassetid://73702396787766",
	["scan"] = "rbxassetid://123104789658180",
	["school"] = "rbxassetid://76351530290068",
	["scissors-line-dashed"] = "rbxassetid://122237447974173",
	["scissors"] = "rbxassetid://118665510911274",
	["screen-share-off"] = "rbxassetid://107677572669805",
	["screen-share"] = "rbxassetid://85137895705653",
	["scroll-text"] = "rbxassetid://97321022666868",
	["scroll"] = "rbxassetid://74072101474951",
	["search-check"] = "rbxassetid://75442076191356",
	["search-code"] = "rbxassetid://117114794592802",
	["search-slash"] = "rbxassetid://96483932261041",
	["search-x"] = "rbxassetid://137319957522951",
	["search"] = "rbxassetid://121018724060431",
	["section"] = "rbxassetid://91732188298948",
	["send-horizontal"] = "rbxassetid://111734392411664",
	["send-to-back"] = "rbxassetid://75340312862253",
	["send"] = "rbxassetid://127751956873796",
	["separator-horizontal"] = "rbxassetid://84864453699927",
	["separator-vertical"] = "rbxassetid://84031801478581",
	["server-cog"] = "rbxassetid://138470287250966",
	["server-crash"] = "rbxassetid://132810618000212",
	["server-off"] = "rbxassetid://114048751507723",
	["server"] = "rbxassetid://92188766517878",
	["settings-2"] = "rbxassetid://135684703553372",
	["settings"] = "rbxassetid://80758916183665",
	["shapes"] = "rbxassetid://129989433311409",
	["share-2"] = "rbxassetid://71210767962065",
	["share"] = "rbxassetid://87340985053299",
	["sheet"] = "rbxassetid://134902122480171",
	["shell"] = "rbxassetid://140212943563599",
	["shield-alert"] = "rbxassetid://114995877719925",
	["shield-ban"] = "rbxassetid://108765041044649",
	["shield-check"] = "rbxassetid://87354736164608",
	["shield-ellipsis"] = "rbxassetid://114794739892123",
	["shield-half"] = "rbxassetid://117842634172647",
	["shield-minus"] = "rbxassetid://89965059528921",
	["shield-off"] = "rbxassetid://133426959132690",
	["shield-plus"] = "rbxassetid://100664857995498",
	["shield-question-mark"] = "rbxassetid://135722075265150",
	["shield-user"] = "rbxassetid://124832775645347",
	["shield-x"] = "rbxassetid://73370117343811",
	["shield"] = "rbxassetid://110987169760162",
	["ship-wheel"] = "rbxassetid://130797795829448",
	["ship"] = "rbxassetid://83995100553930",
	["shirt"] = "rbxassetid://106579555405966",
	["shopping-bag"] = "rbxassetid://71885477293226",
	["shopping-basket"] = "rbxassetid://138646411956433",
	["shopping-cart"] = "rbxassetid://128420521375441",
	["shovel"] = "rbxassetid://102465000512056",
	["shower-head"] = "rbxassetid://75884944024117",
	["shredder"] = "rbxassetid://122125164414463",
	["shrimp"] = "rbxassetid://102625900815307",
	["shrink"] = "rbxassetid://90953687918880",
	["shrub"] = "rbxassetid://127326280714343",
	["shuffle"] = "rbxassetid://132382786975101",
	["sigma"] = "rbxassetid://126884244870899",
	["signal-high"] = "rbxassetid://130436670012270",
	["signal-low"] = "rbxassetid://73674683500458",
	["signal-medium"] = "rbxassetid://125003021367019",
	["signal-zero"] = "rbxassetid://130045332414754",
	["signal"] = "rbxassetid://78424889355261",
	["signature"] = "rbxassetid://114402748013000",
	["signpost-big"] = "rbxassetid://115780185675001",
	["signpost"] = "rbxassetid://106584743791433",
	["siren"] = "rbxassetid://134210267818039",
	["skip-back"] = "rbxassetid://70466132711334",
	["skip-forward"] = "rbxassetid://124844823753990",
	["skull"] = "rbxassetid://137726256442333",
	["slack"] = "rbxassetid://96089719516736",
	["slash"] = "rbxassetid://117792185664263",
	["slice"] = "rbxassetid://95810504278179",
	["sliders-horizontal"] = "rbxassetid://85538382643347",
	["sliders-vertical"] = "rbxassetid://101190569086853",
	["smartphone-charging"] = "rbxassetid://102837532613995",
	["smartphone-nfc"] = "rbxassetid://82326425754446",
	["smartphone"] = "rbxassetid://96623008834511",
	["smile-plus"] = "rbxassetid://131981881472144",
	["smile"] = "rbxassetid://105880397565283",
	["snail"] = "rbxassetid://70904536548363",
	["snowflake"] = "rbxassetid://101235206534566",
	["soap-dispenser-droplet"] = "rbxassetid://77258480479465",
	["sofa"] = "rbxassetid://114427687218324",
	["solar-panel"] = "rbxassetid://132448188047921",
	["soup"] = "rbxassetid://115092551871618",
	["space"] = "rbxassetid://87072088914178",
	["spade"] = "rbxassetid://131444449466462",
	["sparkle"] = "rbxassetid://111044800239623",
	["sparkles"] = "rbxassetid://138635884129147",
	["speaker"] = "rbxassetid://96227183003618",
	["speech"] = "rbxassetid://87013139446349",
	["spell-check-2"] = "rbxassetid://81556731785534",
	["spell-check"] = "rbxassetid://91913483031334",
	["spline-pointer"] = "rbxassetid://84842840956804",
	["spline"] = "rbxassetid://129406685807412",
	["split"] = "rbxassetid://105112438805988",
	["spool"] = "rbxassetid://124541981347743",
	["spotlight"] = "rbxassetid://77571742539344",
	["spray-can"] = "rbxassetid://128372039366326",
	["sprout"] = "rbxassetid://100091687832508",
	["square-activity"] = "rbxassetid://89496630185293",
	["square-arrow-down-left"] = "rbxassetid://108194680296901",
	["square-arrow-down-right"] = "rbxassetid://99403846801050",
	["square-arrow-down"] = "rbxassetid://135962519626588",
	["square-arrow-left"] = "rbxassetid://111671474549238",
	["square-arrow-out-down-left"] = "rbxassetid://125714881756353",
	["square-arrow-out-down-right"] = "rbxassetid://89971003001390",
	["square-arrow-out-up-left"] = "rbxassetid://103759986579087",
	["square-arrow-out-up-right"] = "rbxassetid://91221896066807",
	["square-arrow-right"] = "rbxassetid://113920471701361",
	["square-arrow-up-left"] = "rbxassetid://112424670290693",
	["square-arrow-up-right"] = "rbxassetid://76602291406940",
	["square-arrow-up"] = "rbxassetid://106998604646718",
	["square-asterisk"] = "rbxassetid://89186832353625",
	["square-bottom-dashed-scissors"] = "rbxassetid://79076980104803",
	["square-chart-gantt"] = "rbxassetid://104034017316411",
	["square-check-big"] = "rbxassetid://115320390907184",
	["square-check"] = "rbxassetid://134682053539509",
	["square-chevron-down"] = "rbxassetid://91032307924592",
	["square-chevron-left"] = "rbxassetid://73143404829510",
	["square-chevron-right"] = "rbxassetid://90612077729930",
	["square-chevron-up"] = "rbxassetid://85565910197337",
	["square-code"] = "rbxassetid://81604576616881",
	["square-dashed-bottom-code"] = "rbxassetid://100354801563230",
	["square-dashed-bottom"] = "rbxassetid://101102319625624",
	["square-dashed-kanban"] = "rbxassetid://90388067649847",
	["square-dashed-mouse-pointer"] = "rbxassetid://121016142178467",
	["square-dashed-top-solid"] = "rbxassetid://117157577548540",
	["square-dashed"] = "rbxassetid://136905537847606",
	["square-divide"] = "rbxassetid://99894657101970",
	["square-dot"] = "rbxassetid://116613421354866",
	["square-equal"] = "rbxassetid://110283363706707",
	["square-function"] = "rbxassetid://86075219551088",
	["square-kanban"] = "rbxassetid://114537101260131",
	["square-library"] = "rbxassetid://73810931222081",
	["square-m"] = "rbxassetid://117662700410577",
	["square-menu"] = "rbxassetid://104067089444415",
	["square-minus"] = "rbxassetid://116764432015770",
	["square-mouse-pointer"] = "rbxassetid://76141850603920",
	["square-parking-off"] = "rbxassetid://100857293535141",
	["square-parking"] = "rbxassetid://133116656122387",
	["square-pause"] = "rbxassetid://86608552787615",
	["square-pen"] = "rbxassetid://120239476110475",
	["square-percent"] = "rbxassetid://87111930314567",
	["square-pi"] = "rbxassetid://75383328781618",
	["square-pilcrow"] = "rbxassetid://131854284699367",
	["square-play"] = "rbxassetid://108186325238481",
	["square-plus"] = "rbxassetid://114713264461873",
	["square-power"] = "rbxassetid://129240437805187",
	["square-radical"] = "rbxassetid://132645931868292",
	["square-round-corner"] = "rbxassetid://104592745113567",
	["square-scissors"] = "rbxassetid://110601255612411",
	["square-sigma"] = "rbxassetid://113231244246816",
	["square-slash"] = "rbxassetid://105477013908757",
	["square-split-horizontal"] = "rbxassetid://76095370148660",
	["square-split-vertical"] = "rbxassetid://88589192032058",
	["square-square"] = "rbxassetid://136555087357875",
	["square-stack"] = "rbxassetid://100463396619394",
	["square-star"] = "rbxassetid://94506958703720",
	["square-stop"] = "rbxassetid://80018708472943",
	["square-terminal"] = "rbxassetid://83969264476798",
	["square-user-round"] = "rbxassetid://86484997229302",
	["square-user"] = "rbxassetid://70771214183445",
	["square-x"] = "rbxassetid://125136183850190",
	["square"] = "rbxassetid://86304921356806",
	["squares-exclude"] = "rbxassetid://102345385822324",
	["squares-intersect"] = "rbxassetid://120869602570119",
	["squares-subtract"] = "rbxassetid://131484650948795",
	["squares-unite"] = "rbxassetid://96673080107843",
	["squircle-dashed"] = "rbxassetid://129936702532522",
	["squircle"] = "rbxassetid://82426632573807",
	["squirrel"] = "rbxassetid://112864252085343",
	["stamp"] = "rbxassetid://92370779813368",
	["star-half"] = "rbxassetid://117449275562979",
	["star-off"] = "rbxassetid://75742832732503",
	["star"] = "rbxassetid://136141469398409",
	["step-back"] = "rbxassetid://108672750005121",
	["step-forward"] = "rbxassetid://126131872136145",
	["stethoscope"] = "rbxassetid://122331031702148",
	["sticker"] = "rbxassetid://79938203791608",
	["sticky-note"] = "rbxassetid://111894074643919",
	["store"] = "rbxassetid://90338129673705",
	["stretch-horizontal"] = "rbxassetid://87665042192343",
	["stretch-vertical"] = "rbxassetid://95265463417122",
	["strikethrough"] = "rbxassetid://103417324549613",
	["subscript"] = "rbxassetid://74553514785183",
	["sun-dim"] = "rbxassetid://129141645592715",
	["sun-medium"] = "rbxassetid://130278807964710",
	["sun-moon"] = "rbxassetid://75752898854559",
	["sun-snow"] = "rbxassetid://112791898014579",
	["sun"] = "rbxassetid://110150589884127",
	["sunrise"] = "rbxassetid://134705665494098",
	["sunset"] = "rbxassetid://75904872203588",
	["superscript"] = "rbxassetid://96887696590118",
	["swatch-book"] = "rbxassetid://126786244872453",
	["swiss-franc"] = "rbxassetid://113497920041625",
	["switch-camera"] = "rbxassetid://76841154349737",
	["sword"] = "rbxassetid://124448418211665",
	["swords"] = "rbxassetid://81872698913435",
	["syringe"] = "rbxassetid://123891270479254",
	["table-2"] = "rbxassetid://95751552281545",
	["table-cells-merge"] = "rbxassetid://95363715175258",
	["table-cells-split"] = "rbxassetid://114799086088649",
	["table-columns-split"] = "rbxassetid://111011625447949",
	["table-of-contents"] = "rbxassetid://135044763275414",
	["table-properties"] = "rbxassetid://125062886015372",
	["table-rows-split"] = "rbxassetid://96443733673997",
	["table"] = "rbxassetid://109109148250737",
	["tablet-smartphone"] = "rbxassetid://133680859813404",
	["tablet"] = "rbxassetid://128403991264386",
	["tablets"] = "rbxassetid://80835787970735",
	["tag"] = "rbxassetid://129104970103940",
	["tags"] = "rbxassetid://107179263080798",
	["tally-1"] = "rbxassetid://115301298241643",
	["tally-2"] = "rbxassetid://110363186864027",
	["tally-3"] = "rbxassetid://97655344572540",
	["tally-4"] = "rbxassetid://102633494371890",
	["tally-5"] = "rbxassetid://88031817475886",
	["tangent"] = "rbxassetid://123263132981724",
	["target"] = "rbxassetid://87563802520297",
	["telescope"] = "rbxassetid://91755049143647",
	["tent-tree"] = "rbxassetid://76698322463977",
	["tent"] = "rbxassetid://109779587826330",
	["terminal"] = "rbxassetid://106783148545356",
	["test-tube-diagonal"] = "rbxassetid://75662704378840",
	["test-tube"] = "rbxassetid://98801015650164",
	["test-tubes"] = "rbxassetid://92555361447433",
	["text-align-center"] = "rbxassetid://84051028246390",
	["text-align-end"] = "rbxassetid://130041738343555",
	["text-align-justify"] = "rbxassetid://80279880143030",
	["text-align-start"] = "rbxassetid://134489585487649",
	["text-cursor-input"] = "rbxassetid://107551944047171",
	["text-cursor"] = "rbxassetid://115984654447300",
	["text-initial"] = "rbxassetid://129458097472087",
	["text-quote"] = "rbxassetid://139278366448736",
	["text-search"] = "rbxassetid://92345384671606",
	["text-select"] = "rbxassetid://117087320884956",
	["text-wrap"] = "rbxassetid://114804318314018",
	["theater"] = "rbxassetid://108558145549163",
	["thermometer-snowflake"] = "rbxassetid://121876188028425",
	["thermometer-sun"] = "rbxassetid://106693240074310",
	["thermometer"] = "rbxassetid://106546011492311",
	["thumbs-down"] = "rbxassetid://87794009914015",
	["thumbs-up"] = "rbxassetid://111137070767020",
	["ticket-check"] = "rbxassetid://105428777212507",
	["ticket-minus"] = "rbxassetid://78966299769328",
	["ticket-percent"] = "rbxassetid://80834774406405",
	["ticket-plus"] = "rbxassetid://110086734392189",
	["ticket-slash"] = "rbxassetid://89045681172265",
	["ticket-x"] = "rbxassetid://88674114109926",
	["ticket"] = "rbxassetid://126527071492145",
	["tickets-plane"] = "rbxassetid://100367018248695",
	["tickets"] = "rbxassetid://135268612687833",
	["timer-off"] = "rbxassetid://110916370767271",
	["timer-reset"] = "rbxassetid://110052125369932",
	["timer"] = "rbxassetid://85473888890506",
	["toggle-left"] = "rbxassetid://85887872573050",
	["toggle-right"] = "rbxassetid://90411952142550",
	["toilet"] = "rbxassetid://80930782432931",
	["tool-case"] = "rbxassetid://87533537832522",
	["tornado"] = "rbxassetid://88358291515768",
	["torus"] = "rbxassetid://70855707283051",
	["touchpad-off"] = "rbxassetid://78784008075456",
	["touchpad"] = "rbxassetid://74882354908014",
	["tower-control"] = "rbxassetid://95937619060532",
	["toy-brick"] = "rbxassetid://86293483924633",
	["tractor"] = "rbxassetid://103376704722051",
	["traffic-cone"] = "rbxassetid://74110220470369",
	["train-front-tunnel"] = "rbxassetid://105194827005114",
	["train-front"] = "rbxassetid://125237934215370",
	["train-track"] = "rbxassetid://77451032453723",
	["tram-front"] = "rbxassetid://93315182364998",
	["transgender"] = "rbxassetid://135530817673639",
	["trash-2"] = "rbxassetid://109843431391323",
	["trash"] = "rbxassetid://106723740584310",
	["tree-deciduous"] = "rbxassetid://123124389219004",
	["tree-palm"] = "rbxassetid://103846705893963",
	["tree-pine"] = "rbxassetid://124662547202594",
	["trees"] = "rbxassetid://121203841375919",
	["trello"] = "rbxassetid://130987241149527",
	["trending-down"] = "rbxassetid://139309232226438",
	["trending-up-down"] = "rbxassetid://85083293981691",
	["trending-up"] = "rbxassetid://81819858538839",
	["triangle-alert"] = "rbxassetid://125920361880643",
	["triangle-dashed"] = "rbxassetid://124324079103935",
	["triangle-right"] = "rbxassetid://116930791412791",
	["triangle"] = "rbxassetid://126330486745540",
	["trophy"] = "rbxassetid://131545003268773",
	["truck-electric"] = "rbxassetid://111873446387359",
	["truck"] = "rbxassetid://86662707764771",
	["turkish-lira"] = "rbxassetid://114589876174070",
	["turntable"] = "rbxassetid://129870346487856",
	["turtle"] = "rbxassetid://118295081560334",
	["tv-minimal-play"] = "rbxassetid://99201833426972",
	["tv-minimal"] = "rbxassetid://100382201729427",
	["tv"] = "rbxassetid://135687724791776",
	["twitch"] = "rbxassetid://71383308134888",
	["twitter"] = "rbxassetid://88791703276842",
	["type-outline"] = "rbxassetid://80108627791690",
	["type"] = "rbxassetid://133543553793564",
	["umbrella-off"] = "rbxassetid://72395143739955",
	["umbrella"] = "rbxassetid://127502210274589",
	["underline"] = "rbxassetid://123709229216544",
	["undo-2"] = "rbxassetid://113885292059932",
	["undo-dot"] = "rbxassetid://132055277744844",
	["undo"] = "rbxassetid://111258459077271",
	["unfold-horizontal"] = "rbxassetid://117128358526398",
	["unfold-vertical"] = "rbxassetid://116593025265499",
	["ungroup"] = "rbxassetid://106674800451003",
	["university"] = "rbxassetid://84652528263642",
	["unlink-2"] = "rbxassetid://128131898892572",
	["unlink"] = "rbxassetid://139835795227752",
	["unplug"] = "rbxassetid://90171381619874",
	["upload"] = "rbxassetid://138212042425501",
	["usb"] = "rbxassetid://117230058949613",
	["user-check"] = "rbxassetid://81775205032725",
	["user-cog"] = "rbxassetid://92795491530865",
	["user-lock"] = "rbxassetid://78892639693821",
	["user-minus"] = "rbxassetid://126976941957511",
	["user-pen"] = "rbxassetid://87445472574836",
	["user-plus"] = "rbxassetid://118514469915884",
	["user-round-check"] = "rbxassetid://118794737621941",
	["user-round-cog"] = "rbxassetid://78239503290053",
	["user-round-minus"] = "rbxassetid://98944176636447",
	["user-round-pen"] = "rbxassetid://108155244324878",
	["user-round-plus"] = "rbxassetid://113301899567470",
	["user-round-search"] = "rbxassetid://71565774381870",
	["user-round-x"] = "rbxassetid://122367980560930",
	["user-round"] = "rbxassetid://136485052187963",
	["user-search"] = "rbxassetid://101335649828115",
	["user-star"] = "rbxassetid://98777846316000",
	["user-x"] = "rbxassetid://139748155894754",
	["user"] = "rbxassetid://81589895647169",
	["users-round"] = "rbxassetid://103005444008339",
	["users"] = "rbxassetid://115398113982385",
	["utensils-crossed"] = "rbxassetid://109520762270383",
	["utensils"] = "rbxassetid://139952569804235",
	["utility-pole"] = "rbxassetid://101965541238242",
	["variable"] = "rbxassetid://104743088438151",
	["vault"] = "rbxassetid://108049164599845",
	["vector-square"] = "rbxassetid://86713728565344",
	["vegan"] = "rbxassetid://119489190688082",
	["venetian-mask"] = "rbxassetid://102636443033920",
	["venus-and-mars"] = "rbxassetid://120227752103771",
	["venus"] = "rbxassetid://82891342220859",
	["vibrate-off"] = "rbxassetid://113446447326246",
	["vibrate"] = "rbxassetid://108330910738733",
	["video-off"] = "rbxassetid://132239189859305",
	["video"] = "rbxassetid://107587444636945",
	["videotape"] = "rbxassetid://114816894323398",
	["view"] = "rbxassetid://118717253976805",
	["voicemail"] = "rbxassetid://134313454010227",
	["volleyball"] = "rbxassetid://83889351124153",
	["volume-1"] = "rbxassetid://98514588731639",
	["volume-2"] = "rbxassetid://89344380902620",
	["volume-off"] = "rbxassetid://103047478058767",
	["volume-x"] = "rbxassetid://139252359189540",
	["volume"] = "rbxassetid://103236289817396",
	["vote"] = "rbxassetid://89409762851246",
	["wallet-cards"] = "rbxassetid://129728715308337",
	["wallet-minimal"] = "rbxassetid://137800448816116",
	["wallet"] = "rbxassetid://132331555762628",
	["wallpaper"] = "rbxassetid://74682121235494",
	["wand-sparkles"] = "rbxassetid://82546429942392",
	["wand"] = "rbxassetid://114580617777835",
	["warehouse"] = "rbxassetid://78388887451080",
	["washing-machine"] = "rbxassetid://104194127573858",
	["watch"] = "rbxassetid://130544621618405",
	["waves-ladder"] = "rbxassetid://101808619355514",
	["waves"] = "rbxassetid://96340135183647",
	["waypoints"] = "rbxassetid://102450133666017",
	["webcam"] = "rbxassetid://104148487911129",
	["webhook-off"] = "rbxassetid://96370548093471",
	["webhook"] = "rbxassetid://112812457747322",
	["weight"] = "rbxassetid://103860559844854",
	["wheat-off"] = "rbxassetid://133294844612307",
	["wheat"] = "rbxassetid://85261952080359",
	["whole-word"] = "rbxassetid://90111083954485",
	["wifi-cog"] = "rbxassetid://110500263326209",
	["wifi-high"] = "rbxassetid://81954601342139",
	["wifi-low"] = "rbxassetid://138217335635913",
	["wifi-off"] = "rbxassetid://74113634330106",
	["wifi-pen"] = "rbxassetid://91290205064712",
	["wifi-sync"] = "rbxassetid://84043971055177",
	["wifi-zero"] = "rbxassetid://124286465246123",
	["wifi"] = "rbxassetid://104669375183960",
	["wind-arrow-down"] = "rbxassetid://127753987414870",
	["wind"] = "rbxassetid://114551690399915",
	["wine-off"] = "rbxassetid://108294164302317",
	["wine"] = "rbxassetid://115743721332829",
	["workflow"] = "rbxassetid://99186544029189",
	["worm"] = "rbxassetid://115752311548091",
	["wrench"] = "rbxassetid://112148279212860",
	["x"] = "rbxassetid://110786993356448",
	["youtube"] = "rbxassetid://123663668456341",
	["zap-off"] = "rbxassetid://81385483183652",
	["zap"] = "rbxassetid://130551565616516",
	["zoom-in"] = "rbxassetid://127956924984803",
	["zoom-out"] = "rbxassetid://108334162607319",
	["balloon"] = "rbxassetid://97489111621526",
	["beef-off"] = "rbxassetid://99869959725200",
	["book-search"] = "rbxassetid://132585409504950",
	["calendars"] = "rbxassetid://130944763042289",
	["cannabis-off"] = "rbxassetid://101938500363812",
	["cctv-off"] = "rbxassetid://75925370187295",
	["cigarette"] = "rbxassetid://137149549886852",
	["circle-pile"] = "rbxassetid://116353155251541",
	["cloud-backup"] = "rbxassetid://111649579696132",
	["cloud-sync"] = "rbxassetid://79393911188593",
	["database-search"] = "rbxassetid://92017137080138",
	["ellipse"] = "rbxassetid://71559658267482",
	["fingerprint-pattern"] = "rbxassetid://80934710831288",
	["fishing-hook"] = "rbxassetid://121038780855899",
	["fishing-rod"] = "rbxassetid://71754848048049",
	["form"] = "rbxassetid://72999643971000",
	["git-merge-conflict"] = "rbxassetid://85677801675703",
	["globe-off"] = "rbxassetid://77775243585824",
	["globe-x"] = "rbxassetid://109268097029296",
	["hd"] = "rbxassetid://71682790698278",
	["image"] = "rbxassetid://112751259236831",
	["layers-plus"] = "rbxassetid://77587765623057",
	["lens-concave"] = "rbxassetid://94819631937027",
	["lens-convex"] = "rbxassetid://74736504195474",
	["line-dot-right-horizontal"] = "rbxassetid://104718593155221",
	["line-style"] = "rbxassetid://90176717785772",
	["map-pin-search"] = "rbxassetid://89065012915078",
	["message-circle-check"] = "rbxassetid://132772297689418",
	["message-square-check"] = "rbxassetid://125789987055668",
	["metronome"] = "rbxassetid://101991829345965",
	["mirror-rectangular"] = "rbxassetid://109046769760336",
	["mirror-round"] = "rbxassetid://121534049429097",
	["mouse-left"] = "rbxassetid://99144293708743",
	["mouse-right"] = "rbxassetid://88331710212594",
	["printer-x"] = "rbxassetid://103002721801548",
	["radio-off"] = "rbxassetid://80359258046586",
	["road"] = "rbxassetid://120251329173530",
	["scooter"] = "rbxassetid://100035452787934",
	["search-alert"] = "rbxassetid://127597984617505",
	["shelving-unit"] = "rbxassetid://80116568514793",
	["shield-cog-corner"] = "rbxassetid://111694066132698",
	["shield-cog"] = "rbxassetid://129235695057857",
	["sport-shoe"] = "rbxassetid://120495992692630",
	["square-arrow-right-enter"] = "rbxassetid://138867831495334",
	["square-arrow-right-exit"] = "rbxassetid://133688575845430",
	["square-centerline-dashed-horizontal"] = "rbxassetid://77780104374341",
	["square-centerline-dashed-vertical"] = "rbxassetid://107878435803525",
	["stone"] = "rbxassetid://135161057497830",
	["toolbox"] = "rbxassetid://85341033903792",
	["towel-rack"] = "rbxassetid://125223915620991",
	["user-key"] = "rbxassetid://105403041782190",
	["user-round-key"] = "rbxassetid://124547549008939",
	["van"] = "rbxassetid://122066377022942",
	["waves-arrow-down"] = "rbxassetid://129215220911792",
	["waves-arrow-up"] = "rbxassetid://102314705716217",
	["weight-tilde"] = "rbxassetid://112081212176951",
	["x-line-top"] = "rbxassetid://140592656289509",
	["zodiac-aquarius"] = "rbxassetid://74560047770362",
	["zodiac-aries"] = "rbxassetid://73255859670234",
	["zodiac-cancer"] = "rbxassetid://131985162532947",
	["zodiac-capricorn"] = "rbxassetid://97859568140652",
	["zodiac-gemini"] = "rbxassetid://80997588122992",
	["zodiac-leo"] = "rbxassetid://75509406718106",
	["zodiac-libra"] = "rbxassetid://113222735060218",
	["zodiac-ophiuchus"] = "rbxassetid://129180108892480",
	["zodiac-pisces"] = "rbxassetid://95845819440327",
	["zodiac-sagittarius"] = "rbxassetid://82651026742181",
	["zodiac-scorpio"] = "rbxassetid://113640924054631",
	["zodiac-taurus"] = "rbxassetid://123053219704400",
	["zodiac-virgo"] = "rbxassetid://99462994613661",
}

lucide["filter"] = lucide["funnel"]
lucide["align-left"] = lucide["text-align-start"]
local iconsGaveUp = true
local allIcons = {}
local GLYPHS = {
    ["eye"] = "◉", ["user"] = "☺", ["crosshair"] = "⌖", ["globe"] = "◍", ["layout-grid"] = "▦", ["package-search"] = "▣",
    ["server"] = "▤", ["palette"] = "✎", ["scroll-text"] = "☰", ["shopping-cart"] = "▲", ["settings"] = "⚙", ["search"] = "⌕",
    ["flame"] = "♨", ["save"] = "▣", ["box"] = "◆", ["sliders-horizontal"] = "≡", ["message-circle"] = "✉", ["lock"] = "⚿", ["snowflake"] = "❄", ["x"] = "✕",
}
local function resolveIcon(name)
    if not lucide then return nil end
    local entry = (lucide.Icons and lucide.Icons[name]) or lucide[name]
    if type(entry) == "string" then return entry end
    if type(entry) ~= "table" then return nil end
    local image = entry.Image
    if type(image) == "number" then image = "rbxassetid://" .. tostring(image) end
    local sheet = (lucide.Spritesheets and lucide.Spritesheets[tostring(image)]) or image
    return sheet, entry.ImageRectPosition, entry.ImageRectSize
end
local function showGlyph(rec)
    if rec.glyph or not rec.img.Parent then return end
    rec.img.Image = ""
    local g = create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = GLYPHS[rec.name] or "•", TextSize = 15, FontFace = Library.Fonts.Bold }, rec.img)
    bind(g, "TextColor3", function() return rec.img.ImageColor3 end)
    rec.glyph = g
end
local function applyIconNow(rec)
    local sheet, pos, size = resolveIcon(rec.name)
    if not sheet then showGlyph(rec) return end
    rec.img.Image = sheet
    if pos then rec.img.ImageRectOffset = pos end
    if size then rec.img.ImageRectSize = size end
    if rec.glyph then rec.glyph:Destroy(); rec.glyph = nil end
end
local function setIcon(img, name)
    if type(name) == "string" and (name:match("^%d+$") or name:find("^rbxassetid://")) then
        img.Image = name:match("^%d+$") and ("rbxassetid://" .. name) or name
        return
    end
    local rec = { img = img, name = name }
    allIcons[#allIcons + 1] = rec
    if lucide then applyIconNow(rec) elseif iconsGaveUp then showGlyph(rec) end
end
-- Ícones locais: não executa Lua remoto nem cacheado.

local icon
function icon(parent, name, size, key, props)
    local img = create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size or 16, size or 16), ScaleType = Enum.ScaleType.Fit }, parent)
    bind(img, "ImageColor3", key or "Text")
    for k, v in pairs(props or {}) do img[k] = v end
    setIcon(img, name)
    return img
end
Library.MakeIcon = icon

-- ---------- Servidores ----------
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

-- ---------- FPS compartilhado ----------
Library._fps = 60
do
    local frames, last = 0, os.clock()
    safeConnect(RunService.RenderStepped, function()
        frames += 1
        local now = os.clock()
        if now - last >= 0.5 then Library._fps = math.floor(frames / (now - last) + 0.5); frames = 0; last = now end
    end)
end

-- ---------- Raiz da interface ----------
-- Testa a atribuição de Parent, não só a obtenção do serviço: alguns
-- executores retornam CoreGui/gethui mas não permitem inserir objetos nele.
function Library:ParentGui(gui)
    local seen = {}
    local function attempt(getParent, label)
        local ok, parent = pcall(getParent)
        if not ok or not parent then return nil end
        for _, previous in ipairs(seen) do if previous == parent then return nil end end
        table.insert(seen, parent)
        local assigned, same = pcall(function()
            gui.Parent = parent
            return gui.Parent == parent
        end)
        if assigned and same then
            self.GuiProtection.lastParent = label
            return parent
        end
        return nil
    end
    local root = attempt(function() if type(gethui) == "function" then return gethui() end end, "gethui")
        or attempt(function() return game:GetService("CoreGui") end, "CoreGui")
        or attempt(function()
            if not LocalPlayer then return nil end
            return LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:WaitForChild("PlayerGui", 5)
        end, "PlayerGui")
    if not root then error("BBC: não foi possível inserir a interface em gethui, CoreGui ou PlayerGui") end
    return root
end
function Library:CreateRootGui(class, props)
    local gui = create(class, props)
    local ok, root = pcall(function() return self:ParentGui(gui) end)
    if not ok then
        self:UnprotectGui(gui)
        pcall(function() gui:Destroy() end)
        error(root)
    end
    return gui
end

-- ---------- Notificações ----------
local notifyGui, notifyHolder
function Library:Notify(opts)
    if not Library._running then return end
    opts = opts or {}
    if Library.Panic then return end   -- no modo pânico nada aparece
    if not notifyGui or not notifyGui.Parent then
        notifyGui = Library:CreateRootGui("ScreenGui", { Name = "BBCNotify", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000 })
        notifyHolder = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(250, 400), BackgroundTransparency = 1 }, notifyGui)
        create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6) }, notifyHolder)
    end
    local active = 0
    for _, child in ipairs(notifyHolder:GetChildren()) do if child:IsA("Frame") then active += 1 end end
    if active >= 8 then return end
    for i = #Library._bindings, 1, -1 do
        if not Library._bindings[i][1].Parent then table.remove(Library._bindings, i) end
    end
    local card = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, BackgroundTransparency = 1 }, notifyHolder)
    bind(card, "BackgroundColor3", "Surface")
    corner(card, 5); stroke(card, "Stroke")
    local bar = create("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 }, card)
    bind(bar, "BackgroundColor3", "Accent"); corner(bar, 2)
    local inner = create("Frame", { Size = UDim2.new(1, -14, 0, 0), Position = UDim2.fromOffset(12, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, card)
    pad(inner, 0, 6, 7, 8); listLayout(inner, 2)
    if opts.Title then label(inner, opts.Title, 13, "Text", true, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 17) }) end
    if opts.Content then
        label(inner, opts.Content, 12, "Muted", false, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 16) })
    end
    card.BackgroundTransparency = 1
    tween(card, { BackgroundTransparency = 0 }, 0.2)
    local duration = tonumber(opts.Duration) or 3
    if duration ~= duration or duration == math.huge or duration == -math.huge then duration = 3 end
    task.delay(math.clamp(duration, 0.2, 30), function()
        if card.Parent then
            tween(card, { BackgroundTransparency = 1 }, 0.25)
            task.wait(0.27)
            card:Destroy()
        end
    end)
end

-- ============================================================
--  Elementos (compartilhados por abas, grupos e submenus)
-- ============================================================
local Container = {}
Container.__index = Container
function Container:_nextOrder()
    self._order = (self._order or 0) + 1
    return self._order
end
local function register(self, name, getter, setter, validate)
    Library.Registry[(self._path or "") .. "/" .. tostring(name)] = { name = tostring(name), get = getter, set = setter, validate = validate }
end
local function separator(parent)
    local s = create("Frame", { Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 1, -1), BorderSizePixel = 0, BackgroundTransparency = 0.5 }, parent)
    bind(s, "BackgroundColor3", "Stroke")
end
local function newOuter(self, name)
    local outer = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self:_nextOrder() }, self.List)
    outer:SetAttribute("SearchName", name or "")
    outer:SetAttribute("SearchTab", string.match(self._path or "", "^[^/]+") or "")
    outer:SetAttribute("SearchPath", self._path or "")
    outer:SetAttribute("SearchKey", (self._path or "") .. "/" .. tostring(name or ""))
    -- a busca usa esta lista em vez de varrer a GUI inteira a cada tecla
    if self.Window then
        local list = self.Window._search or {}
        self.Window._search = list
        list[#list + 1] = outer
    end
    listLayout(outer, 0)
    return outer
end
local function chipBox(parent)
    local c = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(0, 24),
        AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundTransparency = 0 }, parent)
    bind(c, "BackgroundColor3", "Surface2")
    corner(c, 4)
    local st = stroke(c, "Stroke", 0)
    return c, st
end

-- bandeiras desenhadas com quadrados (sem depender de imagens)
local function makeFlag(parent, code, props)
    local f = create("Frame", { Size = UDim2.fromOffset(22, 15), BorderSizePixel = 0, ClipsDescendants = true, BackgroundColor3 = Color3.new(1, 1, 1) }, parent)
    for k, v in pairs(props or {}) do f[k] = v end
    corner(f, 2)
    local function rect(x, y, w, h, col, rot)
        return create("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = col, BorderSizePixel = 0, Rotation = rot or 0 }, f)
    end
    if code == "pt" then
        f.BackgroundColor3 = Color3.fromRGB(0, 155, 58)
        rect(6, 2.5, 10, 10, Color3.fromRGB(255, 222, 0), 45)
        local c = rect(7.5, 4.5, 7, 7, Color3.fromRGB(0, 39, 118)); corner(c, 4)
    elseif code == "en" then
        f.BackgroundColor3 = Color3.fromRGB(1, 33, 105)
        rect(-3, 6, 28, 3, Color3.new(1, 1, 1), 33); rect(-3, 6, 28, 3, Color3.new(1, 1, 1), -33)
        rect(0, 5, 22, 5, Color3.new(1, 1, 1)); rect(8.5, 0, 5, 15, Color3.new(1, 1, 1))
        rect(0, 6, 22, 3, Color3.fromRGB(200, 16, 46)); rect(9.5, 0, 3, 15, Color3.fromRGB(200, 16, 46))
    elseif code == "es" then
        f.BackgroundColor3 = Color3.fromRGB(170, 21, 27)
        rect(0, 4, 22, 7, Color3.fromRGB(241, 191, 0))
    elseif code == "zh" then
        f.BackgroundColor3 = Color3.fromRGB(222, 41, 16)
        local st = create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(2, -1), Size = UDim2.fromOffset(10, 10), Text = "★", TextSize = 10, TextColor3 = Color3.fromRGB(255, 222, 0), FontFace = Library.Fonts.Bold }, f)
        create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 1), Size = UDim2.fromOffset(6, 6), Text = "★", TextSize = 5, TextColor3 = Color3.fromRGB(255, 222, 0) }, f)
    elseif code == "ru" then
        rect(0, 5, 22, 5, Color3.fromRGB(0, 57, 166)); rect(0, 10, 22, 5, Color3.fromRGB(213, 43, 30))
    end
    return f
end
local function textWidth(text, size)
    local ok, b = pcall(function() return TextService:GetTextSize(tostring(text), size or 12, Enum.Font.Arimo, Vector2.new(1000, 60)) end)
    return ok and b.X or (#tostring(text) * 7)
end
-- segurar (toque) ou parar o mouse sobre uma linha mostra o nome e o que ela faz
-- TIPS é declarado aqui e preenchido mais abaixo, com a descrição de cada opção do menu
local TIPS = {}
local tipFor = nil   -- definido junto com o idioma; devolve a descrição no idioma atual
local function attachTip(self, row, name, tip, stateFn, extras, more)
    if not tip then
        local e = TIPS[name]
        if type(e) == "string" then tip = e elseif e then tip = (tipFor and tipFor(name)) or e.pt end
    end
    if (not tip or tip == "") and not stateFn then return end
    local win = self.Window
    local desc = (tip and tip ~= "") and tip or nil
    local function resolveDesc()
        if type(desc) == "function" then
            local ok, value = pcall(desc)
            return ok and value or nil
        end
        return desc
    end
    local token, hoverCount, shown, startPos = 0, 0, false, nil
    local isTouch = UserInputService.TouchEnabled and not (UserInputService.MouseEnabled or UserInputService.KeyboardEnabled)
    -- a linha e os objetos interativos dela (botão, campo, chip): assim o cartão
    -- abre também quando o mouse/toque está sobre o nome ou sobre o controle
    local targets = { row }
    if more then for _, o in ipairs(more) do if o then targets[#targets + 1] = o end end end
    for _, o in ipairs(targets) do
        safeConnect(o.InputBegan, function(i)
            local t = i.UserInputType
            if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                token += 1
                local my = token
                shown, startPos = false, i.Position
                task.delay(0.45, function()
                    if token == my and row.Parent then
                        shown = true
                        row:SetAttribute("TipHeld", true)   -- o toque de soltar não alterna a opção
                        win:_tip(name, resolveDesc(), row, stateFn, extras)
                    end
                end)
            end
        end)
        safeConnect(o.InputChanged, function(i)
            local t = i.UserInputType
            if startPos and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseMovement) and (i.Position - startPos).Magnitude > 10 then token += 1 end
        end)
        safeConnect(o.InputEnded, function(i)
            local t = i.UserInputType
            if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then
                token += 1; startPos = nil
                if shown then
                    shown = false
                    win:_hideTip(extras and 4 or 0.9)
                    task.delay(0.25, function() row:SetAttribute("TipHeld", nil) end)
                end
            end
        end)
        safeConnect(o.MouseEnter, function()
            if isTouch then return end
            hoverCount += 1
            task.delay(0.8, function() if hoverCount > 0 and row.Parent then win:_tip(name, resolveDesc(), row, stateFn, extras) end end)
        end)
        safeConnect(o.MouseLeave, function()
            if isTouch then return end
            hoverCount = math.max(0, hoverCount - 1)
            if hoverCount == 0 then win:_hideTip(0.1) end
        end)
    end
end

-- rastro de luz na cor do menu quando uma opção é ativada (some sozinho)
Library.Effects = true
Library.MenuAnim = true
Library.AutoSave = true
Library.Panic = false
Library._panicListeners = {}
Library._panicGuis = {}
Library._toggleBinds = {}
local function activationFx(row, pill)
    if not Library.Effects or Library.ReduceMotion or not row.Parent then return end
    row.ClipsDescendants = true
    -- 1) feixe de luz atravessando a linha
    local beam = create("Frame", { Position = UDim2.new(-0.45, 0, 0, 0), Size = UDim2.new(0.45, 0, 1, 0), BorderSizePixel = 0,
        BackgroundColor3 = Library.Theme.Accent, ZIndex = 2 }, row)
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.62), NumberSequenceKeypoint.new(1, 1) }) }, beam)
    local head = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0,
        BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0.2, ZIndex = 2 }, beam)
    tween(beam, { Position = UDim2.new(1, 0, 0, 0) }, 0.7, Enum.EasingStyle.Quad)
    tween(head, { BackgroundTransparency = 1 }, 0.7)
    task.delay(0.8, function() beam:Destroy() end)
    -- 2) cópias do botão que ficam para trás e somem
    for i = 1, 4 do
        local ghost = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0,
            BackgroundColor3 = Library.Theme.Accent, BackgroundTransparency = 0.25 + i * 0.12, ZIndex = 0 }, pill)
        corner(ghost, 6)
        task.delay(i * 0.03, function()
            tween(ghost, { Position = UDim2.new(1, -15, 0.5, 0) }, 0.16, Enum.EasingStyle.Quad)
            task.delay(0.16, function() tween(ghost, { BackgroundTransparency = 1 }, 0.28) end)
        end)
        task.delay(0.65, function() ghost:Destroy() end)
    end
    -- 3) anel de luz em volta do botão
    local ring = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -29, 0.5, 0), Size = UDim2.fromOffset(34, 18), BackgroundTransparency = 1, ZIndex = 2 }, row)
    corner(ring, 9)
    local rs = create("UIStroke", { Thickness = 2, Transparency = 0.15, Color = Library.Theme.Accent }, ring)
    tween(ring, { Size = UDim2.fromOffset(54, 28) }, 0.5, Enum.EasingStyle.Quad)
    tween(rs, { Transparency = 1 }, 0.5)
    task.delay(0.55, function() ring:Destroy() end)
end
local function subPanel(self, parentOuter, order, stableName)
    local panel = create("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Visible = false, LayoutOrder = order }, parentOuter)
    bind(panel, "BackgroundColor3", "Surface2")
    panel:SetAttribute("SearchPanel", true)
    corner(panel, 4); stroke(panel, "Stroke", 0.3)
    local inner = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, panel)
    pad(inner, 0, 0, 3, 3); listLayout(inner, 0)
    -- cada submenu precisa de um caminho próprio: antes todos usavam ".../sub" e
    -- as opções de ajustes de opções diferentes colidiam no mesmo registro
    local path
    if stableName then
        path = (self._path or "") .. "/settings/" .. stableName
    else
        local n = (self._subN or 0) + 1
        self._subN = n
        path = (self._path or "") .. "/sub" .. (n > 1 and n or "")
    end
    local sub = setmetatable({ List = inner, _order = 0, Window = self.Window, _path = path, Frame = panel }, Container)
    return sub, panel
end

-- ---------- Toggle ----------
function Container:Toggle(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    outer:SetAttribute("SearchKind", "Toggle")
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    local locked = (opts.Premium and Library.Access ~= "VIP") or opts.Disabled == true
    outer:SetAttribute("Unavailable", locked)
    if self.Window and self.Window._hideUnavailable then self.Window:_filter(self.Window._filterQuery) end
    if self.Window and self.Window._touchTarget then self.Window:_touchTarget(row, 30) end
    local nameRow = create("Frame", { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0), BackgroundTransparency = 1 }, row)
    local nl = listLayout(nameRow, 6, Enum.FillDirection.Horizontal)
    nl.VerticalAlignment = Enum.VerticalAlignment.Center
    label(nameRow, opts.Name, 13, locked and "Muted" or "Text", false, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Center })
    if opts.Premium then
        local st = label(nameRow, "★", 13, "Text", true, { LayoutOrder = 2, Size = UDim2.fromOffset(14, 18), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
        st.TextColor3 = Color3.fromRGB(80, 170, 255)
        bind(st, "TextColor3", function() return Color3.fromRGB(80, 170, 255) end)
    end
    if opts.Warning then
        local w = label(nameRow, "⚠", 13, "Warning", true, { LayoutOrder = 3, Size = UDim2.fromOffset(14, 18), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
    end
    local state = opts.Default == true and not locked
    if state and opts.CanSet then
        local ok, allowed = pcall(opts.CanSet, true)
        if not ok or not allowed then state = false end
    end
    local pill = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(34, 18), BorderSizePixel = 0 }, row)
    corner(pill, 9); stroke(pill, "Stroke", 0.2)
    bind(pill, "BackgroundColor3", function() return state and Library.Theme.Accent or Library.Theme.Surface3 end)
    local knob = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, BackgroundTransparency = locked and 0.55 or 0 }, pill)
    corner(knob, 6)
    local function paint(instant)
        local target = state and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        local col = state and Library.Theme.Accent or Library.Theme.Surface3
        if instant then
            knob.Position = target; pill.BackgroundColor3 = col
        else
            tween(knob, { Position = target }, 0.12); tween(pill, { BackgroundColor3 = col }, 0.12)
        end
    end
    paint(true)
    local obj = { Value = state, Frame = outer }
    function obj:Set(v, silent)
        if locked then return v ~= true end
        if opts.CanSet then
            local ok, allowed = pcall(opts.CanSet, v == true)
            if not ok or not allowed then return false end
        end
        local previous = state
        state = v == true
        self.Value = state
        paint()
        if not silent and type(opts.Callback) == "function" then
            local ok, err = pcall(opts.Callback, state)
            if not ok then
                warn("[BBC] " .. tostring(opts.Name) .. ": " .. tostring(err))
                state, self.Value = previous, previous
                pcall(opts.Callback, previous)
                paint(true)
                if self._onChange then self._onChange(state) end
                return false
            end
        end
        if self._onChange then self._onChange(state) end
        return true
    end
    function obj:Get() return state end
    safeConnect(row.MouseButton1Click, function()
        if row:GetAttribute("TipHeld") then return end   -- foi um "segurar" para ver a ajuda
        if locked then
            Library:Notify({ Title = "BBC HUB", Content = Library.Tr(opts.Disabled and "Indisponível: implementação pendente." or "Recurso exclusivo VIP."), Duration = 2 })
            return
        end
        obj:Set(not state)
        if state then activationFx(row, pill) end
    end)
    if not (opts.NoSave or opts.NoPersist) then register(self, opts.Name, function() return state end, function(v) return obj:Set(v) end) end
    -- atalho de teclado (PC) e botão fixo na tela (celular); ambos entram no perfil salvo
    local extras, pinObj, bindKey = nil, nil, nil
    if not opts.NoSave then
        local win = self.Window
        local function adopt(pin) pinObj = pin; if pin then pin.OnRemoved = function() pinObj = nil end end end
        extras = {
            getKey = function() return bindKey end,
            setKey = function(k) bindKey = k; Library:_kbChanged() end,
            isPinned = function() return pinObj ~= nil end,
            setPinned = function(v)
                adopt(win:_setPin(opts.Name, obj, v))
                if v then Library:Notify({ Title = opts.Name, Content = "Fixado: aparece na tela com o menu fechado. Segure o botão para tirar.", Duration = 3 }) end
            end,
        }
        obj._onChange = function() if pinObj then pinObj.Refresh() end end
        table.insert(Library._toggleBinds, { key = function() return bindKey end, fire = function()
            if locked then return end
            if obj:Set(not state) then
                Library:Notify({ Title = opts.Name, Content = state and "Ativado" or "Desativado", Duration = 1.2 })
            end
        end })
        table.insert(Library.Keybinds, { name = opts.Name, get = function() return bindKey end, listening = function() return false end,
            begin = function() Library:Notify({ Title = opts.Name, Content = "Segure a opção no menu e toque em Atalho para trocar.", Duration = 3 }) end })
        register(self, opts.Name .. "#tecla", function() return bindKey and bindKey.Name or nil end,
            function(v) bindKey = Library.ParseKey(v); Library:_kbChanged() end,
            function(v) return type(v) == "string" and Library.ParseKey(v) ~= nil end)
        register(self, opts.Name .. "#fixado", function()
            if not pinObj then return nil end
            local pp = pinObj.btn.Position
            return { x = pp.X.Scale, y = pp.Y.Scale }
        end, function(v)
            if type(v) == "table" and type(v.x) == "number" then adopt(win:_setPin(opts.Name, obj, true, v))
            else adopt(win:_setPin(opts.Name, obj, false)) end
        end, function(v) return type(v) == "table" and type(v.x) == "number" and type(v.y) == "number" and v.x >= 0 and v.x <= 1 and v.y >= 0 and v.y <= 1 end)
    end
    local function tipStatus()
        if opts.Disabled then return "pending" end
        if opts.Premium and Library.Access ~= "VIP" then return "vip" end
        local policy = Library.Safety
        if policy and policy.blocked[opts.Name] and policy.panic then return "blocked" end
        return state
    end
    local function tipDescription()
        local tip = opts.Tooltip
        if type(tip) == "function" then local ok, value = pcall(tip); tip = ok and value or nil end
        if not tip then
            local e = TIPS[opts.Name]
            if type(e) == "string" then tip = e elseif e then tip = (tipFor and tipFor(opts.Name)) or e.pt end
        end
        local status = tipStatus()
        local reason = status == "pending" and "Indisponível: implementação pendente." or status == "vip" and "Recurso exclusivo VIP." or status == "blocked" and "Indisponível durante o modo pânico." or nil
        return (tip and tostring(tip) or "") .. (reason and ("\n" .. Library.Tr(reason)) or "")
    end
    if Library.Favorites and not opts.NoSave then
        extras = (not locked and extras) or {}
        local key = (self._path or "") .. "/" .. tostring(opts.Name)
        extras.isFavorite = function() return Library.Favorites:contains(key) end
        extras.toggleFavorite = function() return Library.Favorites:toggle(key) end
    elseif locked then extras = nil end
    attachTip(self, row, opts.Name, tipDescription, tipStatus, extras)
    bind(row, "BackgroundColor3", "Accent")
    safeConnect(row.MouseEnter, function() if not locked then tween(row, { BackgroundTransparency = 0.93 }, 0.12) end end)
    safeConnect(row.MouseLeave, function() tween(row, { BackgroundTransparency = 1 }, 0.18) end)

    -- painel grande (abre por cima do conteúdo, com pré-visualização)
    if type(opts.Modal) == "function" then
        local gear = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(12 + 34 + 6), 0.5, 0), Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, row)
        local gi = icon(gear, "sliders-horizontal", 17, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
        local key = (self._path or "") .. "/" .. tostring(opts.Name)
        local hooked = false
        safeConnect(gear.MouseButton1Click, function()
            local m = self.Window:_getModal(key, opts.ModalTitles, opts.Modal)
            if not hooked then
                hooked = true
                safeConnect(m.Overlay:GetPropertyChangedSignal("Visible"), function()
                    gi.ImageColor3 = m.Overlay.Visible and Library.Theme.Accent or Library.Theme.Text
                end)
            end
            m.Overlay.Visible = not m.Overlay.Visible
        end)
        -- monta o painel já no começo: as opções valem (e são salvas) mesmo sem abrir o painel
        if opts.Prebuild then
            local win = self.Window
            win._pendingPrebuild = (win._pendingPrebuild or 0) + 1
            task.defer(function()
                local ok, err = pcall(function()
                    if not win._destroyed then win:_getModal(key, opts.ModalTitles, opts.Modal) end
                end)
                win._pendingPrebuild = math.max(0, (win._pendingPrebuild or 1) - 1)
                if not ok then
                    win._prebuildFailed = true
                    warn("[BBC] Painel: " .. tostring(err))
                    if Library.Diagnostics then Library.Diagnostics:record("painel", err) end
                end
            end)
        end
    end

    -- submenu (ícone de ajustes ao lado do botão)
    if type(opts.Settings) == "function" then
        local gear = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -(12 + 34 + 6), 0.5, 0), Size = UDim2.fromOffset(26, 26),
            BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, row)
        local gi = icon(gear, opts.SettingsIcon or "sliders-horizontal", 17, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
        local sub, panel = subPanel(self, outer, 2, opts.SettingsPath)
        local open = false
        local function setOpen(value)
            open = value == true
            local tracked = self.Window._searchPanelState
            local forced = tracked and tracked[panel] ~= nil
            if forced then tracked[panel] = open end
            panel.Visible = forced or open
        end
        self.Window._panelOpeners = self.Window._panelOpeners or {}
        self.Window._panelOpeners[panel] = function() setOpen(true) end
        safeConnect(panel:GetPropertyChangedSignal("Visible"), function()
            gi.ImageColor3 = panel.Visible and Library.Theme.Accent or Library.Theme.Text
        end)
        safeConnect(gear.MouseButton1Click, function() setOpen(not open) end)
        obj.SettingsPanel = sub
        safeCall(opts.Settings, sub)
    end
    if state and type(opts.Callback) == "function" then
        local ok, err = pcall(opts.Callback, true)
        if not ok then
            warn("[BBC] " .. tostring(opts.Name) .. ": " .. tostring(err))
            pcall(opts.Callback, false)
            state, obj.Value = false, false
            paint(true)
        end
    end
    return obj
end

-- ---------- Slider ----------
function Container:Slider(opts)
    opts = opts or {}
    local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
    local min, max = opts.Min or 0, opts.Max or 100
    if not finite(min) or not finite(max) or max < min then min, max = 0, 100 end
    local step = opts.Step or 1
    if not finite(step) or step <= 0 then step = 1 end
    local suffix = opts.Suffix or ""
    local decimals = 0
    if step < 1 then decimals = #(string.match(tostring(step), "%.(%d+)") or "") end
    local value = finite(opts.Default) and math.clamp(opts.Default, min, max) or min
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    local nameL = label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -90, 0, 18) })
    local valueL = label(row, "", 13, "Muted", false, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 4), Size = UDim2.fromOffset(80, 18), TextXAlignment = Enum.TextXAlignment.Right })
    local track = create("Frame", { Position = UDim2.fromOffset(18, 29), Size = UDim2.new(1, -36, 0, 5), BorderSizePixel = 0 }, row)
    bind(track, "BackgroundColor3", "Surface3"); corner(track, 3)
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
    bind(fill, "BackgroundColor3", "Accent"); corner(fill, 3)
    local knob = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(13, 13), BorderSizePixel = 0, ZIndex = 2 }, track)
    bind(knob, "BackgroundColor3", "Background"); corner(knob, 7)
    local ks = create("UIStroke", { Thickness = 2 }, knob); bind(ks, "Color", "Accent")
    local function fmt(v)
        if decimals > 0 then return string.format("%." .. decimals .. "f", v) end
        return tostring(math.floor(v + 0.5))
    end
    local function paint()
        local frac = (max > min) and (value - min) / (max - min) or 0
        fill.Size = UDim2.fromScale(frac, 1)
        knob.Position = UDim2.fromScale(frac, 0.5)
        valueL.Text = fmt(value) .. suffix
    end
    paint()
    local obj = { Value = value, Frame = outer }
    function obj:Set(v, silent)
        v = tonumber(v) or min
        if v ~= v or v == math.huge or v == -math.huge then v = min end
        v = math.clamp(v, min, max)
        v = math.floor((v - min) / step + 0.5) * step + min
        v = math.clamp(v, min, max)
        value = v; self.Value = v
        paint()
        if not silent then safeCall(opts.Callback, v) end
    end
    local hit = create("TextButton", { Position = UDim2.fromOffset(6, 18), Size = UDim2.new(1, -12, 0, 26), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, row)
    local dragging = false
    local function fromInput(pos)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        local rel = math.clamp((pos.X - track.AbsolutePosition.X) / w, 0, 1)
        obj:Set(min + rel * (max - min))
    end
    safeConnect(hit.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromInput(i.Position)
        end
    end)
    self.Window:_connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromInput(i.Position) end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    register(self, opts.Name, function() return value end, function(v) obj:Set(v) end)
    attachTip(self, row, opts.Name, opts.Tooltip, nil, nil, { hit, nameL })
    return obj
end

-- ---------- Dropdown ----------
function Container:Dropdown(opts)
    opts = opts or {}
    local options = opts.Options or {}
    local flags = opts.Flags
    local multi = opts.Multi == true
    local selected = {}
    local function setDefault(d)
        selected = {}
        if type(d) == "table" then for _, v in ipairs(d) do selected[v] = true end
        elseif d ~= nil then selected[d] = true end
    end
    setDefault(opts.Default)
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -150, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local chip = chipBox(row)
    pad(chip, 7, 6, 0, 0)
    local cl = listLayout(chip, 6, Enum.FillDirection.Horizontal)
    cl.VerticalAlignment = Enum.VerticalAlignment.Center
    local flagHolder
    if flags then flagHolder = create("Frame", { Size = UDim2.fromOffset(22, 15), BackgroundTransparency = 1, LayoutOrder = 0 }, chip) end
    local valueL = label(chip, "", 12, "Text", false, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Center })
    local arrow = label(chip, "▶", 9, "Text", false, { LayoutOrder = 2, Size = UDim2.fromOffset(10, 24), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
    local list = create("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.fromOffset(8, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Visible = false, LayoutOrder = 2 }, outer)
    bind(list, "BackgroundColor3", "Surface2"); corner(list, 4); stroke(list, "Stroke", 0.3)
    pad(list, 4, 4, 4, 4); listLayout(list, 2)
    local buttons = {}
    local function ordered()
        local out = {}
        for _, o in ipairs(options) do if selected[o] then table.insert(out, o) end end
        return out
    end
    local function text()
        local o = ordered()
        if #o == 0 then return multi and "—" or "" end
        if multi and #o > 1 then return o[1] .. " +" .. (#o - 1) end
        return o[1]
    end
    local function paint()
        valueL.Text = text()
        if flagHolder then
            for _, c in ipairs(flagHolder:GetChildren()) do c:Destroy() end
            local o = ordered()[1]
            if o and flags[o] then makeFlag(flagHolder, flags[o]) end
        end
        for o, b in pairs(buttons) do
            local on = selected[o] == true
            b.BackgroundTransparency = on and 0.15 or 1
            b.TextColor3 = on and Color3.new(1, 1, 1) or Library.Theme.Text
        end
    end
    local function current()
        if multi then return ordered() end
        return ordered()[1]
    end
    local function validChoice(v)
        if multi then
            if type(v) ~= "table" then return false end
            local count = 0
            for k, item in pairs(v) do
                count += 1
                if type(k) ~= "number" or k < 1 or k % 1 ~= 0 or not table.find(options, item) then return false end
            end
            return count == #v
        end
        return v == nil or (type(v) == "string" and table.find(options, v) ~= nil)
    end
    local obj = { Frame = outer }
    local function closeList() list.Visible = false; arrow.Text = "▶" end
    function obj:Set(v, silent)
        if not validChoice(v) then return false end
        setDefault(v)
        paint()
        if not silent then safeCall(opts.Callback, current()) end
    end
    function obj:Get() return current() end
    function obj:SetOptions(newOptions)
        options = newOptions
        for value in pairs(selected) do if not table.find(options, value) then selected[value] = nil end end
        for _, b in pairs(buttons) do b:Destroy() end
        buttons = {}
        for i, o in ipairs(options) do
            local b = create("TextButton", { Size = UDim2.new(1, 0, 0, flags and 28 or 26), BackgroundTransparency = 1, Text = o, TextSize = 13, FontFace = Library.Fonts.Regular,
                TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, LayoutOrder = i, BorderSizePixel = 0 }, list)
            bind(b, "BackgroundColor3", "Accent")
            corner(b, 3)
            pad(b, flags and 38 or 14, 6, 0, 0)
            if flags and flags[o] then makeFlag(b, flags[o], { Position = UDim2.new(0, -28, 0.5, -7.5) }) end
            buttons[o] = b
            safeConnect(b.MouseButton1Click, function()
                if multi then
                    selected[o] = not selected[o] or nil
                else
                    selected = { [o] = true }
                    closeList()
                end
                paint()
                safeCall(opts.Callback, current())
            end)
        end
        paint()
    end
    obj:SetOptions(options)
    local function toggleList()
        list.Visible = not list.Visible
        arrow.Text = list.Visible and "▼" or "▶"
    end
    local function guardedToggle()
        if row:GetAttribute("TipHeld") then return end
        toggleList()
    end
    safeConnect(row.MouseButton1Click, guardedToggle)
    safeConnect(chip.MouseButton1Click, guardedToggle)
    if not opts.NoPersist then register(self, opts.Name, current, function(v) return obj:Set(v) end, validChoice) end
    attachTip(self, row, opts.Name, opts.Tooltip, nil, nil, { chip })
    return obj
end

-- ---------- Keybind ----------
local KEY_SHORT = {
    RightShift = "RShift", LeftShift = "LShift", RightControl = "RCtrl", LeftControl = "LCtrl", RightAlt = "RAlt", LeftAlt = "LAlt",
    MouseButton3 = "MB3", MouseButton2 = "MB2", Backspace = "Bksp", Return = "Enter",
}
local function keyText(v) if not v then return "None" end return KEY_SHORT[v.Name] or v.Name end
local function parseKey(v)
    if typeof(v) == "EnumItem" then return v end
    if type(v) ~= "string" then return nil end
    if v == "MB3" or v == "MouseButton3" then return Enum.UserInputType.MouseButton3 end
    if v == "MB2" or v == "MouseButton2" then return Enum.UserInputType.MouseButton2 end
    local ok, k = pcall(function() return Enum.KeyCode[v] end)
    return ok and k or nil
end
Library.ParseKey = parseKey
function Container:Keybind(opts)
    opts = opts or {}
    local value = parseKey(opts.Default)
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -110, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local chip, chipStroke = chipBox(row)
    chip.AutomaticSize = Enum.AutomaticSize.None
    local cl = label(chip, keyText(value), 12, "Text", false, { Size = UDim2.fromScale(1, 1), TextTruncate = Enum.TextTruncate.None, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center })
    local function fit(text) chip.Size = UDim2.fromOffset(math.max(46, textWidth(text, 12) + 22), 24) end
    fit(cl.Text)
    local listening = false
    local obj = { Frame = outer }
    local function show(text) cl.Text = text; fit(text) end
    function obj:Set(v, silent)
        value = parseKey(v)
        self.Value = value
        show(keyText(value))
        Library:_kbChanged()
        if not silent then safeCall(opts.OnChanged, value) end
    end
    function obj:Get() return value end
    obj.Value = value
    local function cancelListen()
        if not listening then return end
        listening = false
        if Library._kbOwner == obj then Library:_kbDone() end
        chipStroke.Color = Library.Theme.Stroke
        show(keyText(value))
        Library:_kbChanged()
    end
    local function beginListen()
        Library:_kbListen(obj, cancelListen)   -- cancela outro atalho que esteja escutando
        listening = true
        chipStroke.Color = Library.Theme.Accent
        show("...")
        Library:_kbChanged()
    end
    table.insert(Library.Keybinds, { name = opts.Name, get = function() return value end, begin = beginListen, listening = function() return listening end })
    safeConnect(chip.MouseButton1Click, function() if row:GetAttribute("TipHeld") then return end; beginListen() end)
    self.Window:_connect(UserInputService.InputBegan, function(input, processed)
        local t = input.UserInputType
        local isMouse = t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3
        if t ~= Enum.UserInputType.Keyboard and not isMouse then return end
        local code = isMouse and t or input.KeyCode
        if listening then
            listening = false
            if Library._kbOwner == obj then Library:_kbDone() end
            chipStroke.Color = Library.Theme.Stroke
            if code == Enum.KeyCode.Escape then show(keyText(value)); Library:_kbChanged() else obj:Set(code) end
            return
        end
        if not processed and value ~= nil and code == value then safeCall(opts.Callback, code) end
    end)
    register(self, opts.Name, function() return value and value.Name or "None" end, function(v) obj:Set(v) end,
        function(v) return v == "None" or (type(v) == "string" and Library.ParseKey(v) ~= nil) end)
    attachTip(self, row, opts.Name, opts.Tooltip, nil, nil, { chip })
    return obj
end

-- ---------- Botão ----------
function Container:Button(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1, BorderSizePixel = 0 }, outer)
    if self.Window and self.Window._touchTarget then self.Window:_touchTarget(row, 30) end
    bind(row, "BackgroundColor3", "Accent")
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    if opts.Arrow then label(row, "▶", 11, "Text", false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(14, 16), TextXAlignment = Enum.TextXAlignment.Right }) end
    safeConnect(row.MouseButton1Click, function()
        if row:GetAttribute("TipHeld") then return end
        row.BackgroundTransparency = 0.8
        tween(row, { BackgroundTransparency = 1 }, 0.25)
        safeCall(opts.Callback)
    end)
    attachTip(self, row, opts.Name, opts.Tooltip)
    return { Frame = outer }
end

-- ---------- Input ----------
function Container:Input(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    if self.Window and self.Window._touchTarget then self.Window:_touchTarget(row, 30) end
    separator(row)
    local nameL = label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -130, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local box = create("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(100, 22), Text = opts.Default or "",
        PlaceholderText = opts.Placeholder or "", ClearTextOnFocus = false, TextSize = 12, FontFace = Library.Fonts.Regular, BorderSizePixel = 0, BackgroundTransparency = 0.2 }, row)
    bind(box, "BackgroundColor3", "Background"); bind(box, "TextColor3", "Text"); bind(box, "PlaceholderColor3", "Muted")
    corner(box, 3); stroke(box, "Stroke", 0.1)
    safeConnect(box.FocusLost, function() safeCall(opts.Callback, box.Text) end)
    if not opts.NoPersist then register(self, opts.Name, function() return box.Text end, function(v) box.Text = tostring(v) end) end
    attachTip(self, row, opts.Name, opts.Tooltip, nil, nil, { box, nameL })
    return { Frame = outer, Box = box }
end

-- ---------- Seletor de cor (quadro de saturação, barra de matiz, hex e paleta) ----------
local PALETTE = {
    Color3.fromRGB(255, 255, 255), Color3.fromRGB(160, 160, 160), Color3.fromRGB(30, 30, 30), Color3.fromRGB(240, 52, 72),
    Color3.fromRGB(255, 130, 25), Color3.fromRGB(255, 205, 40), Color3.fromRGB(45, 215, 105), Color3.fromRGB(30, 175, 245),
    Color3.fromRGB(110, 90, 255), Color3.fromRGB(242, 85, 175),
}
function Container:ColorPicker(opts)
    opts = opts or {}
    local color = opts.Default or Color3.fromRGB(255, 255, 255)
    local h, s, v = color:ToHSV()
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -120, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local arrow = label(row, "▶", 9, "Text", false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(10, 16), TextXAlignment = Enum.TextXAlignment.Center })
    local sw = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -28, 0.5, 0), Size = UDim2.fromOffset(32, 18), BackgroundColor3 = color, BorderSizePixel = 0 }, row)
    corner(sw, 4); stroke(sw, "Stroke", 0.1)
    local panel = create("Frame", { Size = UDim2.new(1, -16, 0, 150), BorderSizePixel = 0, Visible = false, LayoutOrder = 2 }, outer)
    bind(panel, "BackgroundColor3", "Surface2"); corner(panel, 4); stroke(panel, "Stroke", 0.3)
    -- quadro S/V
    local sv = create("TextButton", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 84), Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = Color3.fromHSV(h, 1, 1) }, panel)
    corner(sv, 4)
    local white = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, sv)
    corner(white, 4)
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }) }, white)
    local black = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundColor3 = Color3.new(0, 0, 0) }, sv)
    corner(black, 4)
    create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }) }, black)
    local svKnob = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3 }, sv)
    corner(svKnob, 6)
    create("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }, svKnob)
    -- barra de matiz
    local hue = create("TextButton", { Position = UDim2.fromOffset(8, 100), Size = UDim2.new(1, -16, 0, 12), Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1) }, panel)
    corner(hue, 6)
    local seq = {}
    for i = 0, 6 do seq[#seq + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1 == 0 and (i == 6 and 0.9999 or 0) or i / 6, 1, 1)) end
    create("UIGradient", { Color = ColorSequence.new(seq) }, hue)
    local hueKnob = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(6, 16), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 }, hue)
    corner(hueKnob, 3); create("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.4 }, hueKnob)
    -- hex + paleta
    local hex = create("TextBox", { Position = UDim2.fromOffset(8, 120), Size = UDim2.fromOffset(70, 22), Text = "", TextSize = 12, FontFace = Library.Fonts.Regular, ClearTextOnFocus = false, BorderSizePixel = 0 }, panel)
    bind(hex, "BackgroundColor3", "Background"); bind(hex, "TextColor3", "Text"); corner(hex, 3); stroke(hex, "Stroke", 0.1)
    local obj = { Frame = outer }
    local function apply(silent)
        color = Color3.fromHSV(h, s, v)
        sw.BackgroundColor3 = color
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svKnob.Position = UDim2.fromScale(s, 1 - v)
        hueKnob.Position = UDim2.fromScale(h, 0.5)
        hex.Text = "#" .. color:ToHex():upper()
        obj.Value = color
        if not silent then safeCall(opts.Callback, color) end
    end
    local px = 84
    for i, c in ipairs(PALETTE) do
        local b = create("TextButton", { Position = UDim2.fromOffset(px + (i - 1) * 19, 122), Size = UDim2.fromOffset(16, 16), Text = "", AutoButtonColor = false, BackgroundColor3 = c, BorderSizePixel = 0 }, panel)
        corner(b, 8); create("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.7 }, b)
        safeConnect(b.MouseButton1Click, function() h, s, v = c:ToHSV(); apply() end)
    end
    safeConnect(row.MouseButton1Click, function()
        if row:GetAttribute("TipHeld") then return end
        panel.Visible = not panel.Visible
        arrow.Text = panel.Visible and "▼" or "▶"
    end)
    local dragSV, dragHue = false, false
    local function fromSV(p)
        local sz = sv.AbsoluteSize
        if sz.X <= 0 or sz.Y <= 0 then return end
        s = math.clamp((p.X - sv.AbsolutePosition.X) / sz.X, 0, 1)
        v = 1 - math.clamp((p.Y - sv.AbsolutePosition.Y) / sz.Y, 0, 1)
        apply()
    end
    local function fromHue(p)
        local w = hue.AbsoluteSize.X
        if w <= 0 then return end
        h = math.clamp((p.X - hue.AbsolutePosition.X) / w, 0, 0.999)
        apply()
    end
    local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
    safeConnect(sv.InputBegan, function(i) if isPress(i) then dragSV = true; fromSV(i.Position) end end)
    safeConnect(hue.InputBegan, function(i) if isPress(i) then dragHue = true; fromHue(i.Position) end end)
    self.Window:_connect(UserInputService.InputChanged, function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            if dragSV then fromSV(i.Position) elseif dragHue then fromHue(i.Position) end
        end
    end)
    self.Window:_connect(UserInputService.InputEnded, function(i) if isPress(i) then dragSV, dragHue = false, false end end)
    safeConnect(hex.FocusLost, function()
        local t = string.gsub(hex.Text, "#", "")
        local ok, c = pcall(Color3.fromHex, t)
        if ok and c then h, s, v = c:ToHSV() end
        apply()
    end)
    function obj:Set(c, silent) h, s, v = c:ToHSV(); apply(silent) end
    apply(true)
    if not opts.NoPersist then register(self, opts.Name, function() return { color.R, color.G, color.B } end, function(t) obj:Set(Color3.new(t[1], t[2], t[3])) end,
        function(t)
            if type(t) ~= "table" or #t ~= 3 then return false end
            for k, v in pairs(t) do
                if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > 3 or type(v) ~= "number" or v < 0 or v > 1 then return false end
            end
            return true
        end) end
    attachTip(self, row, opts.Name, opts.Tooltip)
    return obj
end

-- ---------- Seção que abre (▶) ----------
function Container:Foldout(opts)
    opts = opts or {}
    local outer = newOuter(self, opts.Name)
    local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = 1 }, outer)
    separator(row)
    label(row, opts.Name, 13, "Text", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -40, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local arrow = label(row, "▶", 11, "Text", false, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(14, 16), TextXAlignment = Enum.TextXAlignment.Right })
    local sub, panel = subPanel(self, outer, 2)
    local open = false
    local function setOpen(v)
        open = v == true
        local tracked = self.Window._searchPanelState
        local forced = tracked and tracked[panel] ~= nil
        if forced then tracked[panel] = open end
        panel.Visible = forced or open
    end
    self.Window._panelOpeners = self.Window._panelOpeners or {}
    self.Window._panelOpeners[panel] = function() setOpen(true) end
    safeConnect(panel:GetPropertyChangedSignal("Visible"), function() arrow.Text = panel.Visible and "▼" or "▶" end)
    safeConnect(row.MouseButton1Click, function() if row:GetAttribute("TipHeld") then return end; setOpen(not open) end)
    safeCall(opts.Build, sub)
    attachTip(self, row, opts.Name, opts.Tooltip)
    return { Frame = outer, Panel = sub, Set = setOpen, IsOpen = function() return open end }
end

-- ---------- Botões lado a lado (ex.: Silencioso / Fixar / Agressivo) ----------
function Container:Segmented(opts)
    opts = opts or {}
    local options, icons = opts.Options or {}, opts.Icons or {}
    local selected = opts.Default or options[1]
    local outer = newOuter(self, opts.Name)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1 }, outer)
    separator(row)
    local holder = create("Frame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 28), BackgroundTransparency = 1 }, row)
    listLayout(holder, 4, Enum.FillDirection.Horizontal)
    local n = math.max(#options, 1)
    local items = {}
    local obj = { Frame = outer }
    local function paint()
        for o, it in pairs(items) do
            local on = o == selected
            it.stroke.Color = on and Library.Theme.Accent or Library.Theme.Stroke
            it.stroke.Thickness = on and 1.5 or 1
            it.btn.BackgroundColor3 = on and Library.Theme.Surface3 or Library.Theme.Surface2
            it.text.TextColor3 = on and Library.Theme.Text or Library.Theme.Muted
            if it.icon then it.icon.ImageColor3 = on and Library.Theme.Accent or Library.Theme.Muted end
        end
    end
    for i, o in ipairs(options) do
        local b = create("TextButton", { Size = UDim2.new(1 / n, -4 * (n - 1) / n, 1, 0), Text = "", AutoButtonColor = false, LayoutOrder = i, BorderSizePixel = 0 }, holder)
        corner(b, 4)
        local st = create("UIStroke", { Thickness = 1 }, b)
        local ic = icons[i] and icon(b, icons[i], 14, "Muted", { Position = UDim2.new(0, 7, 0.5, -7) }) or nil
        local tx = label(b, o, 12, "Muted", false, { Position = UDim2.fromOffset(ic and 24 or 6, 0), Size = UDim2.new(1, ic and -28 or -12, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, TextXAlignment = ic and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center })
        items[o] = { btn = b, stroke = st, text = tx, icon = ic }
        safeConnect(b.MouseButton1Click, function()
            if b:GetAttribute("TipHeld") then return end
            if opts.CanSelect and not opts.CanSelect(o) then return end
            selected = o
            paint()
            safeCall(opts.Callback, o)
        end)
        attachTip(self, b, opts.Name, opts.Tooltip)
    end
    paint()
    table.insert(Library._themeListeners, paint)
    function obj:Set(v, silent)
        if not table.find(options, v) or (opts.CanSelect and not opts.CanSelect(v)) then return false end
        selected = v; paint(); if not silent then safeCall(opts.Callback, v) end
        return true
    end
    register(self, opts.Name, function() return selected end, function(v) return obj:Set(v) end,
        function(v) return type(v) == "string" and table.find(options, v) ~= nil and (not opts.CanSelect or opts.CanSelect(v, true)) end)
    return obj
end

-- ---------- Texto ----------
function Container:Label(opts)
    opts = type(opts) == "table" and opts or { Text = opts }
    local outer = newOuter(self, opts.Text)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, outer)
    local l = label(row, opts.Text, 12, "Muted", false, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    return { Frame = outer, Label = l, Set = function(_, t) l.Text = t end }
end
function Container:Section(text)
    local outer = newOuter(self, text)
    local row = create("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 }, outer)
    label(row, string.upper(text or ""), 12, "Muted", true, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 18) })
    return { Frame = outer }
end
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
-- ============ 10_ui.luau :: Elementos de UI: Toggle, Slider, Dropdown, Button, Keybind, Input, cor, Foldout, Segmented ============
-- ============================================================
--  Aba, grupo e janela
-- ============================================================
local Tab = setmetatable({}, { __index = Container })
Tab.__index = Tab
local Window = {}
Window.__index = Window

function Window:_connect(signal, fn)
    local c = safeConnect(signal, fn)
    table.insert(self._conns, c)
    return c
end

function Window:_touchTarget(row, baseline)
    self._touchRows = self._touchRows or {}
    self._touchRows[#self._touchRows + 1] = { row = row, baseline = baseline }
    local vp = self.Gui.AbsoluteSize
    local compact = Library.UISupport.compact(vp.X, vp.Y, UserInputService.TouchEnabled)
    row.Size = UDim2.new(1, 0, 0, compact and math.max(40, baseline) or baseline)
end

-- colunas com rolagem independente (criadas na primeira vez que se usa Groupbox)
function Tab:_column(side)
    if not self._cols then
        self.List.Visible = false
        local holder = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, self.Page)
        self._cols = {}
        for i, nm in ipairs({ "Left", "Right" }) do
            local sf = create("ScrollingFrame", {
                Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(i == 1 and 0 or 0.5, i == 1 and 0 or 4, 0, 0),
                BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
            }, holder)
            bind(sf, "ScrollBarImageColor3", "Accent")
            pad(sf, 1, 6, 1, 10); listLayout(sf, 8)
            self._cols[nm] = sf
        end
    end
    if side ~= "Left" and side ~= "Right" then
        local l, r = #self._cols.Left:GetChildren(), #self._cols.Right:GetChildren()
        side = l <= r and "Left" or "Right"
    end
    return self._cols[side]
end

-- Em toque/portrait, mantém os mesmos objetos e troca duas colunas por uma.
function Tab:_layoutColumns()
    if not self._cols then return end
    local vp = self.Window.Gui.AbsoluteSize
    local compact = Library.UISupport.compact(vp.X, vp.Y, UserInputService.TouchEnabled)
    local left, right = self._cols.Left, self._cols.Right
    left.Size = compact and UDim2.fromScale(1, 1) or UDim2.new(0.5, -4, 1, 0)
    right.Visible = not compact
    for _, item in ipairs(self._groupBoxes or {}) do
        local dest = compact and left or self._cols[item.side]
        if item.box.Parent ~= dest then item.box.Parent = dest end
    end
end

function Tab:Groupbox(opts)
    opts = opts or {}
    local col = self:_column(opts.Side)
    self._groupBoxes = self._groupBoxes or {}
    local originalSide = col == self._cols.Right and "Right" or "Left"
    local box = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = #self._groupBoxes + 1 }, col)
    table.insert(self._groupBoxes, { box = box, side = originalSide })
    self:_layoutColumns()
    bind(box, "BackgroundColor3", "Surface"); corner(box, 4)
    local bs = create("UIStroke", { Thickness = 1, Transparency = 0.2 }, box); bind(bs, "Color", "Accent")
    listLayout(box, 0)
    local head = create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 1 }, box)
    local x = 10
    if opts.Icon then icon(head, opts.Icon, 15, "Text", { Position = UDim2.fromOffset(10, 6.5) }); x = 31 end
    label(head, opts.Name, 13, "Muted", false, { Position = UDim2.fromOffset(x, 0), Size = UDim2.new(1, -x - (opts.Checkbox and 62 or 34), 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local cbObj
    if opts.Checkbox then
        local on = opts.Default ~= false
        if on and opts.CanSet then
            local ok, allowed = pcall(opts.CanSet, true)
            if not ok or not allowed then on = false end
        end
        local cb = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(24, 24), Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, head)
        corner(cb, 4); stroke(cb, "Accent", 0.1)
        bind(cb, "BackgroundColor3", function() return on and Library.Theme.Accent or Library.Theme.Surface3 end)
        local mark = label(cb, "✓", 13, "Text", true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Visible = on })
        cbObj = {}
        function cbObj:Set(v, silent)
            if opts.CanSet then
                local ok, allowed = pcall(opts.CanSet, v == true)
                if not ok or not allowed then return false end
            end
            local previous = on
            on = v == true
            if not silent and type(opts.Callback) == "function" then
                local ok, err = pcall(opts.Callback, on)
                if not ok then
                    warn("[BBC] " .. tostring(opts.Name) .. ": " .. tostring(err))
                    on = previous
                    pcall(opts.Callback, previous)
                    cb.BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Surface3
                    mark.Visible = on
                    return false
                end
            end
            cb.BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Surface3
            mark.Visible = on
            return true
        end
        function cbObj:Get() return on end
        safeConnect(cb.MouseButton1Click, function() cbObj:Set(not on) end)
        register(self, tostring(opts.Name) .. "#ativo", function() return on end, function(v) return cbObj:Set(v) end)
        if on then safeCall(opts.Callback, true) end
    end
    local ln = create("Frame", { Size = UDim2.new(1, -16, 0, 1), Position = UDim2.new(0, 8, 1, -1), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, head)
    bind(ln, "BackgroundColor3", "Stroke")
    local body = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, box)
    listLayout(body, 0)
    local fold = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, opts.Checkbox and -36 or -6, 0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Text = "▼", TextSize = 14, AutoButtonColor = false }, head)
    bind(fold, "TextColor3", "Text")
    local expanded = true
    local function showGroup() body.Visible = expanded or (self.Window._filterQuery or "") ~= ""; fold.Text = body.Visible and "▼" or "▶" end
    safeConnect(fold.MouseButton1Click, function() expanded = not expanded; showGroup() end)
    self.Window._groupOpeners = self.Window._groupOpeners or {}
    self.Window._groupOpeners[body] = function() expanded = true; showGroup() end
    self.Window._groups = self.Window._groups or {}
    table.insert(self.Window._groups, showGroup)
    return setmetatable({ List = body, _order = 0, Window = self.Window, _path = self._path .. "/" .. tostring(opts.Name), Frame = box, Checkbox = cbObj }, Container)
end

local function fmtLeft(sec)
    sec = math.max(math.floor(sec), 0)
    local d, h, m = math.floor(sec / 86400), math.floor(sec % 86400 / 3600), math.floor(sec % 3600 / 60)
    if d > 0 then return d .. "d " .. h .. "h" end
    return h .. "h " .. m .. "m"
end

function Window:_getModal(key, titles, build)
    self._modals = self._modals or {}
    local m = self._modals[key]
    if m then return m end
    local overlay = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 20 }, self._content)
    overlay:SetAttribute("SearchModal", key)
    bind(overlay, "BackgroundColor3", "Background")
    local function makeBox(left, title)
        local f = create("Frame", { Position = UDim2.new(left and 0 or 0.5, left and 0 or 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), BorderSizePixel = 0 }, overlay)
        bind(f, "BackgroundColor3", "Surface"); corner(f, 4)
        local st = create("UIStroke", { Thickness = 1, Transparency = 0.15 }, f); bind(st, "Color", "Accent")
        label(f, title or "", 12, "Muted", true, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -50, 0, 28), TextYAlignment = Enum.TextYAlignment.Center })
        local ln = create("Frame", { Position = UDim2.fromOffset(8, 28), Size = UDim2.new(1, -16, 0, 1), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, f)
        bind(ln, "BackgroundColor3", "Stroke")
        return f
    end
    local lb, rb = makeBox(true, titles and titles.Left), makeBox(false, titles and titles.Right)
    local close = create("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 2), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false }, rb)
    icon(close, "x", 16, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    safeConnect(close.MouseButton1Click, function() overlay.Visible = false end)
    local lbody = create("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1 }, lb)
    local rs = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -72), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2,
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, rb)
    bind(rs, "ScrollBarImageColor3", "Accent")
    listLayout(rs, 0); pad(rs, 4, 6, 0, 4)
    m = { Overlay = overlay, Left = lbody, LeftBox = lb, RightBox = rb, RightScroll = rs, Close = function() overlay.Visible = false end }
    m.Right = setmetatable({ List = rs, _order = 0, Window = self, _path = key .. "/painel" }, Container)
    self._modals[key] = m
    if type(build) == "function" then
        local ok, err = pcall(build, m)
        if not ok then
            self._modals[key] = nil
            overlay:Destroy()
            error(err)
        end
    end
    return m
end

function Window:_select(tab)
    if not tab then return end
    local switching = self.Current ~= nil and self.Current ~= tab and not self._introActive
    for _, m in pairs(self._modals or {}) do m.Overlay.Visible = false end
    for _, t in ipairs(self.Tabs) do
        t.Page.Visible = (t == tab)
        if t.TabBtn then
            local on = t == tab
            t.Sel.BackgroundTransparency = on and 0 or 1
            t.Text.TextColor3 = on and Library.Theme.Text or Library.Theme.Muted
            t.IconImg.ImageColor3 = on and Library.Theme.Text or Library.Theme.Muted
            t.Active = on
        end
    end
    if self.HomeTab then
        self.HomeTab.Page.Visible = (tab == self.HomeTab)
    end
    if switching and tab.Page and not Library.ReduceMotion then
        tab.Page.Position = UDim2.fromOffset(0, 12)
        tween(tab.Page, { Position = UDim2.fromOffset(0, 0) }, 0.22, Enum.EasingStyle.Quint)
    end
    self.Current = tab
    if self._flameBtn then
        local home = tab == self.HomeTab
        self._flameStroke.Color = home and Library.Theme.Accent or Library.Theme.Stroke
        self._flameIcon.ImageColor3 = home and Library.Theme.Accent or Library.Theme.Text
    end
    if self._gearBtn then
        local g = tab and tab.IsSettings
        self._gearStroke.Color = g and Library.Theme.Accent or Library.Theme.Stroke
        self._gearIcon.ImageColor3 = g and Library.Theme.Accent or Library.Theme.Text
    end
end

function Window:Tab(opts)
    opts = opts or {}
    local tab = setmetatable({ Name = opts.Name, Window = self, _order = 0, _path = tostring(opts.Name), IsSettings = (opts.Name == "CONFIGURAÇÕES") or opts.IsSettings }, Tab)
    tab.Page = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, self._content)
    tab.List = create("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y }, tab.Page)
    bind(tab.List, "ScrollBarImageColor3", "Accent")
    pad(tab.List, 1, 6, 1, 10); listLayout(tab.List, 8)
    tab.Frame = tab.Page
    if opts.Hidden then
        if opts.Name == "Home" then self.HomeTab = tab end
        table.insert(self.Tabs, tab)
        return tab
    end
    local btn = create("TextButton", { Size = UDim2.new(1, 0, 0, 27), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, LayoutOrder = #self.Tabs + 1 }, self._tabList)
    tab.TabBtn = btn
    tab._searchCount = label(btn, "", 11, "Text", true, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.fromOffset(24, 18), TextXAlignment = Enum.TextXAlignment.Right })
    tab.Sel = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1 }, btn)
    bind(tab.Sel, "BackgroundColor3", "Accent"); corner(tab.Sel, 4)
    create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }) }, tab.Sel)
    tab.IconImg = icon(btn, opts.Icon or "circle", 16, "Muted", { Position = UDim2.fromOffset(12, 5.5) })
    tab.Text = label(btn, string.upper(opts.Name or ""), 13, "Muted", false, { Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -66, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    table.insert(self.Tabs, tab)
    safeConnect(btn.MouseButton1Click, function() self:_select(tab) end)
    if not self.Current or self.Current == self.HomeTab then self:_select(tab) end
    -- a barra da intro avança a cada aba montada (e cede um quadro para ela desenhar)
    if self._introProgress then
        self._tabCount = (self._tabCount or 0) + 1
        self._introProgress(2 / 3, Library.Tr("Montando o menu") .. " · " .. string.upper(Library.Tr(tostring(opts.Name or ""))))
        task.wait()
    end
    return tab
end

-- ---------- Configurações salvas (perfis) ----------
local CFG_FOLDER = "BBC_HUB/configs"
local AUTOLOAD_FILE = "BBC_HUB/autoload.txt"
local function canFS() return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" end
local function ensureFolders()
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" then
            if not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
            if not isfolder(CFG_FOLDER) then makefolder(CFG_FOLDER) end
        end
    end)
end
local function cleanName(n)
    n = string.gsub(tostring(n or ""), "[^%w _%-]", "")
    n = string.gsub(n, "^%s+", "")
    n = string.gsub(n, "%s+$", "")
    return string.sub(n, 1, 24)
end
Library.CleanName = cleanName
-- texto estável (chaves em ordem) só para saber se algo mudou
local function stable(v)
    local kind = type(v)
    if kind ~= "table" then
        local text = tostring(v)
        return kind .. ":" .. #text .. ":" .. text
    end
    local items = {}
    for k, x in pairs(v) do items[#items + 1] = { stable(k), x } end
    table.sort(items, function(a, b) return a[1] < b[1] end)
    for i, it in ipairs(items) do items[i] = it[1] .. stable(it[2]) end
    return "table:" .. #items .. ":{" .. table.concat(items) .. "}"
end
local function endsWith(key, tail) return string.sub(key, -#tail) == tail end

function Window:_snapshot()
    local data = {}
    for key, r in pairs(Library.Registry) do
        local ok, val = pcall(r.get)
        if ok and val ~= nil then data[key] = val end
    end
    return data
end
function Window:_applyData(decoded)
    local policy = Library.Safety
    local blocked = (policy and policy.panic) and policy.blocked or {}
    local operations, err, skipped, unknown = Library.ProfileGuard:prepare(decoded, Library.Registry, blocked)
    if not operations then return false, err end
    local ok, key = Library.ProfileGuard:apply(operations)
    if not ok then return false, "falha ao aplicar: " .. tostring(key) end
    return true, nil, skipped, unknown
end
local function decodeProfile(text)
    if type(text) ~= "string" or #text > Library.ProfileGuard.MAX_BYTES then return nil end
    local ok, decoded = pcall(function() return HttpService:JSONDecode(text) end)
    if not ok or type(decoded) ~= "table" then return nil end
    return decoded
end
-- Backup somente de um arquivo decodificável. A escrita não é atômica em
-- executores genéricos; se o backup falhar, não sobrescrevemos o original.
local function writeConfigWithBackup(path, json)
    local ok, err = pcall(function()
        if isfile(path) then
            local previous = readfile(path)
            local decoded = decodeProfile(previous)
            assert(decoded and Library.ProfileGuard:validateTree(decoded), "arquivo anterior inválido; não será sobrescrito")
            assert(writefile(path .. ".bak", previous) ~= false, "falha ao gravar backup")
        end
        assert(writefile(path, json) ~= false, "falha ao gravar perfil")
    end)
    return ok, err
end
function Window:SaveConfig(name, quiet)
    name = cleanName(name)
    if name == "" then name = "default" end
    if not canFS() then Library:Notify({ Title = "BBC HUB", Content = "Salvar precisa de writefile no executor." }); return false end
    ensureFolders()
    local snap = self:_snapshot()
    if not Library.ProfileGuard:validateTree(snap) then return false end
    local ok, failure = pcall(function()
        local json = HttpService:JSONEncode({ v = 2, name = name, data = snap })
        assert(#json <= Library.ProfileGuard.MAX_BYTES, "perfil grande demais")
        local written, err = writeConfigWithBackup(CFG_FOLDER .. "/" .. name .. ".json", json)
        assert(written, err)
    end)
    if ok then
        self._cfgName = name
        self._autoSaveBlocked = false
        self._lastState = stable(snap)
        if self._cfgBox then self._cfgBox.Text = name end
        if self._configChanged then pcall(self._configChanged) end
    end
    if not ok then
        warn("[BBC] Falha ao salvar configuração: " .. tostring(failure))
        if Library.Diagnostics then Library.Diagnostics:record("configuração", failure) end
    end
    if not quiet then Library:Notify({ Title = "BBC HUB", Content = ok and ("Configuração salva: " .. name) or "Falha ao salvar; veja o console." }) end
    return ok
end
-- Confirmação apenas para o botão manual; a API e o autosave permanecem separados.
function Window:RequestSaveConfig(name)
    name = cleanName(name)
    if name == "" then name = "default" end
    if not canFS() then return false, "arquivos indisponíveis" end
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    local ok, exists, raw = pcall(function()
        local present = isfile(path)
        return present, present and readfile(path) or nil
    end)
    if not ok then return false, "não foi possível verificar o arquivo" end
    if not exists then
        local staged = self._savePreview
        self._savePreview = nil
        if staged and staged.name == name then return false, "alterado" end
        return self:SaveConfig(name), "salvo"
    end
    local decoded = decodeProfile(raw)
    if not decoded or not Library.ProfileGuard:validateTree(decoded) then self._savePreview = nil; return false, "arquivo anterior inválido; preservado" end
    local snapshot = self:_snapshot()
    if not Library.ProfileGuard:validateTree(snapshot) then return false, "ajustes inválidos" end
    local signature = stable(snapshot)
    local staged = self._savePreview
    if not staged or staged.name ~= name or os.clock() > staged.expires then
        self._savePreview = { name = name, raw = raw, signature = signature, expires = os.clock() + 30 }
        return false, "confirmar"
    end
    self._savePreview = nil
    if staged.raw ~= raw or staged.signature ~= signature then return false, "alterado" end
    local versionOK = self:CreateConfigVersion(name)
    if not versionOK then Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Histórico não criado; backup normal continua disponível.") }) end
    return self:SaveConfig(name), "salvo"
end
function Window:LoadConfig(name, quiet)
    if not canFS() then
        if not quiet then Library:Notify({ Title = "BBC HUB", Content = "Carregar precisa de acesso a arquivos no executor." }) end
        return false
    end
    name = cleanName(name)
    if name == "" then name = "default" end
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    local ok, raw = pcall(function() if isfile(path) then return readfile(path) end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded then
        if Library.Diagnostics then Library.Diagnostics:record("carregamento", "arquivo ausente, inválido ou grande demais") end
        if not quiet then Library:Notify({ Title = "BBC HUB", Content = "Perfil inválido ou grande demais." }) end
        return false
    end
    local applied, err, skipped, unknown = self:_applyData(decoded)
    if not applied then
        if Library.Diagnostics then Library.Diagnostics:record("carregamento", err) end
        if not quiet then Library:Notify({ Title = "BBC HUB", Content = "Perfil rejeitado: " .. tostring(err) }) end
        return false
    end
    self._cfgName = name
    self._autoSaveBlocked = false
    self._lastState = stable(self:_snapshot())
    if self._cfgBox then self._cfgBox.Text = name end
    if skipped > 0 or unknown > 0 or not quiet then
        Library:Notify({ Title = "BBC HUB", Content = "Configuração carregada: " .. name .. (skipped > 0 and (" · " .. skipped .. " opções bloqueadas") or "") .. (unknown > 0 and (" · " .. unknown .. " ajustes desconhecidos ignorados") or "") })
    end
    if self._configChanged then pcall(self._configChanged) end
    return true
end
-- A prévia só lê e valida; não chama setters. A confirmação relê o arquivo
-- e invalida a prévia se o conteúdo, os valores atuais ou a política mudarem.
function Window:PreviewConfig(name)
    if not canFS() then return nil, "acesso a arquivos indisponível" end
    name = cleanName(name)
    if name == "" then name = "default" end
    local ok, raw = pcall(function() if isfile(CFG_FOLDER .. "/" .. name .. ".json") then return readfile(CFG_FOLDER .. "/" .. name .. ".json") end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded then return nil, "perfil ausente, inválido ou grande demais" end
    local policy = Library.Safety
    local blocked = (policy and policy.panic) and policy.blocked or {}
    local operations, err, skipped, unknown = Library.ProfileGuard:prepare(decoded, Library.Registry, blocked)
    if not operations then return nil, err end
    local changes, fingerprint = {}, { skipped = skipped, unknown = unknown, panic = policy and policy.panic == true, blocked = blocked, operations = {} }
    local function display(v)
        if v == nil then return "—" end
        if type(v) == "table" then
            local pieces, n = {}, 0
            for k, value in pairs(v) do
                n += 1
                if n <= 6 then pieces[#pieces + 1] = string.sub(tostring(k), 1, 16) .. "=" .. string.sub(type(value) == "table" and "{…}" or tostring(value), 1, 24) end
            end
            table.sort(pieces)
            return "{" .. table.concat(pieces, ", ") .. (n > 6 and ", …" or "") .. "}"
        end
        return string.sub(tostring(v), 1, 60)
    end
    for _, op in ipairs(operations) do
        fingerprint.operations[op.key] = { before = op.old, after = op.value }
        if stable(op.old) ~= stable(op.value) then
            changes[#changes + 1] = { key = op.key, before = display(op.old), after = display(op.value) }
        end
    end
    return { name = name, raw = raw, signature = stable(fingerprint), changes = changes, skipped = skipped, unknown = unknown, operations = operations }
end
function Window:StageConfigPreview(name)
    self._configPreview = nil
    local preview, err = self:PreviewConfig(name)
    if not preview then return nil, err end
    preview.expires = os.clock() + 60
    self._configPreview = preview
    return preview
end
function Window:ConfirmConfigPreview(name)
    local staged = self._configPreview
    self._configPreview = nil
    name = cleanName(name)
    if name == "" then name = "default" end
    if not staged or staged.name ~= name or os.clock() > staged.expires then return false, "prévia ausente ou expirada" end
    local current, err = self:PreviewConfig(name)
    if not current then return false, err end
    if current.raw ~= staged.raw or current.signature ~= staged.signature then return false, "perfil, ajustes ou política mudaram; revise novamente" end
    local applied, key = Library.ProfileGuard:apply(current.operations)
    if not applied then
        if Library.Diagnostics then Library.Diagnostics:record("carregamento", key) end
        return false, "falha ao aplicar: " .. tostring(key)
    end
    self._cfgName, self._autoSaveBlocked = name, false
    self._lastState = stable(self:_snapshot())
    if self._cfgBox then self._cfgBox.Text = name end
    if self._configChanged then pcall(self._configChanged) end
    Library:Notify({ Title = "BBC HUB", Content = "Configuração carregada: " .. name .. (current.skipped > 0 and (" · opções bloqueadas: " .. current.skipped) or "") .. (current.unknown > 0 and (" · ajustes desconhecidos: " .. current.unknown) or "") })
    return true
end
-- Recupera em outro arquivo: nunca modifica o original ou o backup.
function Window:RestoreConfigBackup(name)
    name = cleanName(name)
    if name == "" then name = "default" end
    if not canFS() then return false, "acesso a arquivos indisponível" end
    local source = CFG_FOLDER .. "/" .. name .. ".json.bak"
    local ok, raw = pcall(function() if isfile(source) then return readfile(source) end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded then return false, "backup ausente ou inválido" end
    local policy = Library.Safety
    local blocked = (policy and policy.panic) and policy.blocked or {}
    local operations, err = Library.ProfileGuard:prepare(decoded, Library.Registry, blocked)
    if not operations then return false, err end
    local recovery
    for i = 1, 99 do
        local suffix = "-rec" .. i
        local candidate = string.sub(name, 1, 24 - #suffix) .. suffix
        local existsOK, exists = pcall(isfile, CFG_FOLDER .. "/" .. candidate .. ".json")
        if not existsOK then return false, "não foi possível verificar o arquivo de destino" end
        if not exists then recovery = candidate; break end
    end
    if not recovery then return false, "sem nome disponível para recuperação" end
    ensureFolders()
    local written, writeErr = pcall(writefile, CFG_FOLDER .. "/" .. recovery .. ".json", raw)
    if not written then return false, "não foi possível criar cópia: " .. tostring(writeErr) end
    if not self:LoadConfig(recovery) then return false, "cópia criada, mas não pôde ser carregada: " .. recovery end
    return true, recovery
end
-- Até três cópias independentes, sem rotação destrutiva nem sobrescrita.
function Window:ListConfigVersions(name)
    name = cleanName(name); if name == "" then name = "default" end
    local out = {}
    if not canFS() then return out end
    for i = 1, 3 do
        local ok, exists = pcall(isfile, CFG_FOLDER .. "/" .. name .. ".json.version" .. i)
        if ok and exists then out[#out + 1] = tostring(i) end
    end
    return out
end
function Window:CreateConfigVersion(name)
    name = cleanName(name); if name == "" then name = "default" end
    if not canFS() then return false, "arquivos indisponíveis" end
    local source = CFG_FOLDER .. "/" .. name .. ".json"
    local ok, raw = pcall(function() if isfile(source) then return readfile(source) end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded or not Library.ProfileGuard:validateTree(decoded) then return false, "perfil inválido ou ausente" end
    for i = 1, 3 do
        local dest = source .. ".version" .. i
        local checked, exists = pcall(isfile, dest)
        if not checked then return false, "não foi possível verificar o destino" end
        if not exists then
            local written, result = pcall(writefile, dest, raw)
            if not written or result == false then return false, "falha ao gravar versão" end
            return true, tostring(i)
        end
    end
    return false, "limite de versões atingido"
end
function Window:RestoreConfigVersion(name, version)
    name = cleanName(name); if name == "" then name = "default" end
    local n = tonumber(version)
    if not canFS() or not n or n % 1 ~= 0 or n < 1 or n > 3 then return false, "versão indisponível" end
    local path = CFG_FOLDER .. "/" .. name .. ".json.version" .. n
    local ok, raw = pcall(function() if isfile(path) then return readfile(path) end end)
    local decoded = ok and decodeProfile(raw)
    if not decoded then return false, "versão inválida ou ausente" end
    local policy = Library.Safety
    local blocked = (policy and policy.panic) and policy.blocked or {}
    local operations, err = Library.ProfileGuard:prepare(decoded, Library.Registry, blocked)
    if not operations then return false, err end
    for i = 1, 99 do
        local suffix = "-hist" .. i
        local candidate = string.sub(name, 1, 24 - #suffix) .. suffix
        local dest = CFG_FOLDER .. "/" .. candidate .. ".json"
        local checked, exists = pcall(isfile, dest)
        if not checked then return false, "não foi possível verificar o destino" end
        if not exists then
            local written, result = pcall(writefile, dest, raw)
            if not written or result == false then return false, "falha ao criar cópia" end
            return true, candidate
        end
    end
    return false, "sem nome disponível para recuperação"
end
function Window:ListConfigs()
    local out = {}
    if type(listfiles) ~= "function" then return out end
    pcall(function()
        for _, path in ipairs(listfiles(CFG_FOLDER)) do
            local n = string.match(path, "([^/\\]+)%.json$")
            if n and n ~= "" and cleanName(n) == n then table.insert(out, n) end
        end
    end)
    table.sort(out, function(a, b) return string.lower(a) < string.lower(b) end)
    while #out > 100 do table.remove(out) end
    return out
end
function Window:DeleteConfig(name)
    name = cleanName(name)
    local path = CFG_FOLDER .. "/" .. name .. ".json"
    if type(delfile) ~= "function" or not canFS() or not isfile(path) then
        Library:Notify({ Title = "BBC HUB", Content = "Não foi possível apagar este perfil." }); return false
    end
    local ok = pcall(delfile, path)
    if ok and self:GetAutoload() == name then self:SetAutoload(false) end
    Library:Notify({ Title = "BBC HUB", Content = ok and ("Perfil apagado: " .. name) or "Falha ao apagar." })
    return ok
end
-- perfil carregado ao iniciar: nome, "none" (desligado) ou, sem arquivo, o perfil "default" se existir
function Window:GetAutoload()
    if not canFS() then return nil end
    local _, raw = pcall(function() if isfile(AUTOLOAD_FILE) then return readfile(AUTOLOAD_FILE) end end)
    local n = type(raw) == "string" and cleanName(raw) or ""
    if n == "none" then return nil end
    if n == "" then n = "default" end
    local ok, exists = pcall(isfile, CFG_FOLDER .. "/" .. n .. ".json")
    if ok and exists then return n end
    return nil
end
function Window:SetAutoload(name)
    if not canFS() then return end
    ensureFolders()
    local value = name and cleanName(name) or "none"
    if name and (value == "" or value == "none") then return false end
    local ok = pcall(writefile, AUTOLOAD_FILE, value)
    return ok
end
function Window:ExportConfig()
    local ok, json = pcall(function()
        local snap = self:_snapshot()
        assert(Library.ProfileGuard:validateTree(snap), "perfil inválido")
        local encoded = HttpService:JSONEncode({ v = 2, data = snap })
        assert(#encoded <= Library.ProfileGuard.MAX_BYTES, "perfil grande demais")
        return encoded
    end)
    local copy = setclipboard or toclipboard
    if ok and type(copy) == "function" and pcall(copy, json) then
        Library:Notify({ Title = "BBC HUB", Content = "Código do perfil copiado." })
    else
        Library:Notify({ Title = "BBC HUB", Content = "Seu executor não permite copiar para a área de transferência." })
    end
end
function Window:ImportConfig(text, saveAs)
    local decoded = decodeProfile(text)
    if not decoded then Library:Notify({ Title = "BBC HUB", Content = "Código inválido ou grande demais." }); return false end
    local applied, err, skipped = self:_applyData(decoded)
    if not applied then Library:Notify({ Title = "BBC HUB", Content = "Perfil rejeitado: " .. tostring(err) }); return false end
    -- senão o autocontrole acha que nada mudou e o perfil importado nunca é gravado
    self._lastState = stable(self:_snapshot())
    if self._cfgBox then self._cfgBox.Text = self._cfgName or "" end
    Library:Notify({ Title = "BBC HUB", Content = "Perfil importado." .. (skipped > 0 and (" Opções bloqueadas: " .. skipped) or "") })
    if saveAs and not self:SaveConfig(saveAs, true) then
        Library:Notify({ Title = "BBC HUB", Content = "Importado, mas não foi possível salvar." })
        return false
    end
    return true
end
-- guarda os valores iniciais para o "Resetar tudo"
function Window:CaptureDefaults()
    for _, r in pairs(Library.Registry) do
        local ok, v = pcall(r.get)
        r.has = ok and v ~= nil
        if r.has then r.default = v end
    end
end
function Window:ResetConfig()
    for key, r in pairs(Library.Registry) do
        if r.has then pcall(r.set, r.default)
        elseif endsWith(key, "#tecla") or endsWith(key, "#fixado") then pcall(r.set, nil) end
    end
    Library:Notify({ Title = "BBC HUB", Content = "Tudo voltou ao padrão." })
end
-- salva sozinho o que você ligou/mexeu no menu (e carrega na próxima vez que executar)
function Window:_autoSaveNow()
    if not canFS() or self._introActive or not self._ready or self._autoSaveBlocked then return end
    local snap = self:_snapshot()
    if not Library.ProfileGuard:validateTree(snap) then return end
    local state = stable(snap)
    if state == self._lastState then return end
    ensureFolders()
    local name = self._cfgName or "default"
    local ok, failure = pcall(function()
        local json = HttpService:JSONEncode({ v = 2, name = name, data = snap })
        assert(#json <= Library.ProfileGuard.MAX_BYTES, "perfil grande demais")
        local written, err = writeConfigWithBackup(CFG_FOLDER .. "/" .. name .. ".json", json)
        assert(written, err)
    end)
    if ok then
        local firstConfig = self._cfgName == nil
        self._cfgName = name
        self._lastState = state
        self._autoSaveWarned = false
        if firstConfig and self._configChanged then pcall(self._configChanged) end
    elseif not self._autoSaveWarned then
        self._autoSaveWarned = true
        warn("[BBC] Salvamento automático falhou: " .. tostring(failure))
        if Library.Diagnostics then Library.Diagnostics:record("salvamento automático", failure) end
        Library:Notify({ Title = "BBC HUB", Content = "Falha no salvamento automático; tentando novamente. Veja o console." })
    end
end
function Window:StartAutoSave()
    if self._autoSaveOn then return end
    self._autoSaveOn = true
    if self._lastState == nil then self._lastState = stable(self:_snapshot()) end
    task.spawn(function()
        while self.Gui and self.Gui.Parent do
            task.wait(3)
            if self.Gui and self.Gui.Parent then safeCall(function() self:_autoSaveNow() end) end
        end
    end)
end

-- ---------- Identidade ----------
function Window:SetHideName(h) self._hideName = h == true; self:_renderIdentity() end
function Window:SetHideAvatar(h) self._hideAvatar = h == true; self:_renderIdentity() end
function Window:_renderIdentity()
    if not self._pName then return end
    self._pName.Text = self._hideName and "••••••" or LocalPlayer.DisplayName
    self._pAvatar.Image = self._hideAvatar and "" or (self._thumb or "")
end

-- ---------- Visibilidade e botão flutuante ----------
function Window:_updateIsland()
    if self._island then self._island.Visible = (self._islandOn ~= false) and not self._main.Visible and not self._introActive end
    self:_updatePins()
end

-- botões fixos na tela (aparecem com o menu fechado): toque liga/desliga, arraste move, segure remove
-- modo pânico: esconde menu, ESP, radar e botões fixos de uma vez; o menu volta como estava
function Library:OnPanic(fn) table.insert(Library._panicListeners, fn) end
function Window:SetPanic(on)
    on = on == true
    if Library.Panic == on then return end
    Library.Panic = on
    if self.Gui then self.Gui.Enabled = not on end
    if notifyGui then notifyGui.Enabled = not on end
    for _, g in ipairs(Library._panicGuis) do pcall(function() g.Enabled = not on end) end
    if Library._panicToggle then pcall(function() Library._panicToggle:Set(on, true) end) end
    if Library._panicZone then Library._panicZone.Visible = on end
    for _, fn in ipairs(Library._panicListeners) do pcall(fn, on) end
end

function Window:_updatePins()
    local show = not self._main.Visible and not self._introActive
    for _, pin in pairs(self._pins or {}) do pin.btn.Visible = show end
end
function Window:_setPin(name, obj, on, pos)
    self._pins = self._pins or {}
    local old = self._pins[name]
    if old then old.Destroy(); self._pins[name] = nil end
    if not on then return nil end
    local count = 0
    for _ in pairs(self._pins) do count += 1 end
    local btn = create("TextButton", { Name = "BBCPin", Size = UDim2.fromOffset(46, 46), AnchorPoint = Vector2.new(0.5, 0.5), Text = "", AutoButtonColor = false,
        BorderSizePixel = 0, ZIndex = 40, Visible = false,
        Position = pos and UDim2.fromScale(pos.x, pos.y) or UDim2.fromScale(0.06, math.min(0.22 + count * 0.1, 0.85)) }, self.Gui)
    corner(btn, 10)
    stroke(btn, "Accent", 0.2)
    local function color() return obj:Get() and Library.Theme.Accent or Library.Theme.Surface end
    bind(btn, "BackgroundColor3", color)
    local words, abbr = {}, ""
    for w in string.gmatch(tostring(name), "%S+") do table.insert(words, w) end
    if #words >= 2 then abbr = string.upper(string.sub(words[1], 1, 1) .. string.sub(words[2], 1, 1)) else abbr = string.upper(string.sub(tostring(name), 1, 3)) end
    label(btn, abbr, 14, "Text", true, { Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 41 })
    label(btn, tostring(name), 9, "Muted", false, { Position = UDim2.fromOffset(2, 27), Size = UDim2.new(1, -4, 0, 12), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 41 })
    local pin = { btn = btn }
    local dragging, moved, startIn, startPos, tok = false, false, nil, nil, 0
    local c1, c2
    function pin.Refresh() btn.BackgroundColor3 = color() end
    function pin.Destroy()
        if c1 then c1:Disconnect() end
        if c2 then c2:Disconnect() end
        btn:Destroy()
    end
    safeConnect(btn.InputBegan, function(i)
        local t = i.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then return end
        dragging, moved, startIn, startPos = true, false, i.Position, btn.Position
        tok += 1
        local my = tok
        task.delay(0.8, function()   -- segurar parado remove o botão
            if tok == my and dragging and not moved and btn.Parent then
                self._pins[name] = nil
                if pin.OnRemoved then pin.OnRemoved() end
                pin.Destroy()
                Library:Notify({ Title = tostring(name), Content = "Botão removido da tela.", Duration = 1.5 })
            end
        end)
    end)
    c1 = safeConnect(UserInputService.InputChanged, function(i)
        if not dragging then return end
        local t = i.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseMovement then return end
        local d = i.Position - startIn
        if d.Magnitude > 8 then moved = true end
        if moved then btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
    end)
    c2 = safeConnect(UserInputService.InputEnded, function(i)
        local t = i.UserInputType
        if not dragging or (t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1) then return end
        dragging = false
        tok += 1
        if moved then
            local vp = self.Gui.AbsoluteSize
            local c = btn.AbsolutePosition + btn.AbsoluteSize / 2
            if vp.X > 0 and vp.Y > 0 then
                local hx, hy = math.min(0.5, 23 / vp.X), math.min(0.5, 23 / vp.Y)
                btn.Position = UDim2.fromScale(math.clamp(c.X / vp.X, hx, 1 - hx), math.clamp(c.Y / vp.Y, hy, 1 - hy))
            end
        else
            obj:Set(not obj:Get())
            local ring = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(46, 46), BackgroundTransparency = 1, ZIndex = 41 }, btn)
            corner(ring, 10)
            local rs = create("UIStroke", { Thickness = 2, Transparency = 0.1, Color = Library.Theme.Accent }, ring)
            tween(ring, { Size = UDim2.fromOffset(66, 66) }, 0.4, Enum.EasingStyle.Quad)
            tween(rs, { Transparency = 1 }, 0.4)
            task.delay(0.45, function() ring:Destroy() end)
        end
    end)
    self._pins[name] = pin
    if self._fit then self._fit() end
    btn.Visible = not self._main.Visible and not self._introActive
    return pin
end
function Window:SetIsland(on)
    self._islandOn = on == true
    self:_updateIsland()
end
-- abrir/fechar com um "pop" (escala), sem precisar de transparência nos filhos
function Window:_setOpen(v)
    if self._introActive or Library.Panic then return end
    local main, scale = self._main, self._scale
    local was = self._wantOpen ~= false
    self._wantOpen = v
    if v == was and main.Visible == v then return end
    self._animToken = (self._animToken or 0) + 1
    local my = self._animToken
    if not (Library.MenuAnim and scale) or Library.ReduceMotion then
        main.Visible = v; if not v then self:_autoSaveNow() end; self:_updateIsland(); return
    end
    local fit = self._fitScale or scale.Scale
    if v then
        main.Visible = true
        scale.Scale = fit * 0.92
        tween(scale, { Scale = fit }, 0.3, Enum.EasingStyle.Back)
        self:_updateIsland()
    else
        self:_hideTip()
        self:_autoSaveNow()
        tween(scale, { Scale = fit * 0.92 }, 0.14, Enum.EasingStyle.Quad)
        task.delay(0.15, function()
            if self._animToken ~= my then return end
            main.Visible = false
            scale.Scale = self._fitScale or fit
            self:_updateIsland()
        end)
    end
end
function Window:SetVisible(v) self:_setOpen(v) end
function Window:SetLogo(v) self._logo.Visible = v == true end
function Window:SetBorderAccent(v)
    self._accentBorder = v == true
    self._mainStroke.Color = self._accentBorder and Library.Theme.Accent or Library.Theme.Stroke
end
function Window:SetBackgroundTransparency(t) self._main.BackgroundTransparency = math.clamp(t or 0, 0, 0.85) end
function Window:SetShadow(v)
    self._mainStroke.Thickness = v and 3 or 1
    self._mainStroke.Transparency = v and 0.45 or 0
end
function Window:Toggle() self:_setOpen(self._wantOpen == false) end
function Window:SetKeybind(k) self._key = parseKey(k) end
function Window:SetIslandDraggable(enabled) self._btnDraggable = enabled == true end
function Window:SetToggleButton(enabled)
    if not enabled then
        if self._toggleBtn then self._toggleBtn:Destroy(); self._toggleBtn = nil end
        return
    end
    if self._toggleBtn then return end
    local b = create("TextButton", { Name = "BBCToggle", Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 14, 0.38, 0), Text = "BBC", TextSize = 15,
        FontFace = Library.Fonts.Bold, AutoButtonColor = false, BorderSizePixel = 0, Visible = not self._introActive }, self.Gui)
    bind(b, "BackgroundColor3", "Surface"); bind(b, "TextColor3", "Text"); corner(b, 8); stroke(b, "Accent", 0.2)
    self._toggleBtn = b
    if self._fit then self._fit() end
    local dragging, moved, startPos, startInput = false, false, nil, nil
    safeConnect(b.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, moved, startInput, startPos = true, false, i.Position, b.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(i)
        if dragging and self._btnDraggable ~= false and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            if d.Magnitude > 6 then moved = true end
            if moved then
                local vp, size = self.Gui.AbsoluteSize, b.AbsoluteSize
                local x = startPos.X.Scale * vp.X + startPos.X.Offset + d.X
                local y = startPos.Y.Scale * vp.Y + startPos.Y.Offset + d.Y
                b.Position = UDim2.fromOffset(math.clamp(x, 0, math.max(0, vp.X - size.X)), math.clamp(y, 0, math.max(0, vp.Y - size.Y)))
            end
        end
    end)
    self:_connect(UserInputService.InputEnded, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
            dragging = false
            if not moved then self:Toggle() end
        end
    end)
end

function Window:_hideTip(delay)
    if Library._kbOwner == "tip" and Library._kbCancel then pcall(Library._kbCancel) end
    local f = self._tipFrame
    if not f then return end
    task.delay(delay or 0, function()
        if self._tipFrame ~= f or self._tipHover then return end
        self._tipFrame = nil
        tween(f, { GroupTransparency = 1 }, 0.15)
        task.delay(0.2, function() f:Destroy() end)
    end)
end

-- cartão de ajuda: nome, estado (ATIVO/INATIVO) e o que a opção faz, perto da linha
function Window:_tip(title, text, row, stateFn, extras)
    if Library._kbOwner == "tip" and Library._kbCancel then pcall(Library._kbCancel) end
    if self._tipFrame then self._tipFrame:Destroy(); self._tipFrame = nil end
    self._tipHover = false
    local main = self._main
    local sc = (self._scale and self._scale.Scale) or 1
    local f = create("CanvasGroup", { Size = UDim2.fromOffset(236, 0), AutomaticSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, ZIndex = 50, GroupTransparency = 1 }, main)
    bind(f, "BackgroundColor3", "Surface3"); corner(f, 7); stroke(f, "Accent", 0.1)
    pad(f, 11, 11, 8, 9); listLayout(f, 3)
    local head = create("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = 1 }, f)
    label(head, Library.Tr(tostring(title)), 13, "Accent", true, { Size = UDim2.new(1, -62, 1, 0), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 51 })
    if stateFn then
        local state = stateFn()
        local on = state == true
        local chip = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(56, 16), BorderSizePixel = 0, ZIndex = 51 }, head)
        corner(chip, 8)
        chip.BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Surface
        local txt = label(chip, Library.Tr(state == "pending" and "PENDENTE" or state == "vip" and "VIP" or state == "blocked" and "BLOQUEADO" or (on and "ATIVO" or "INATIVO")), 10, "Text", true, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 52 })
        if not on then txt.TextColor3 = Library.Theme.Muted end
    end
    label(f, text and tostring(text) or "Toque para ativar ou desativar.", 12, text and "Text" or "Muted", false, { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y,
        TextWrapped = true, TextTruncate = Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 16), ZIndex = 51 })
    if extras then
        local actions = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3 }, f)
        local al = listLayout(actions, 6, Enum.FillDirection.Horizontal)
        -- Versões antigas podem não expor Wraps; empilhar evita cortar ações.
        if not pcall(function() al.Wraps = true end) then al.FillDirection = Enum.FillDirection.Vertical end
        al.VerticalAlignment = Enum.VerticalAlignment.Center
        local function chipBtn(text, order)
            local b = create("TextButton", { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 11, FontFace = Library.Fonts.Bold,
                AutoButtonColor = false, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 51 }, actions)
            bind(b, "BackgroundColor3", "Surface"); bind(b, "TextColor3", "Text")
            corner(b, 5); stroke(b, "Stroke", 0.2); pad(b, 8, 8, 0, 0)
            return b
        end
        local function keep() self._tipToken = (self._tipToken or 0) + 1; self._tipHover = false; self:_hideTip(2.5) end
        if UserInputService.KeyboardEnabled and extras.getKey then
            local function keyLabel() local k = extras.getKey(); return "Atalho: " .. (k and keyText(k) or "—") end
            local kb = chipBtn(keyLabel(), 1)
            safeConnect(kb.MouseButton1Click, function()
                local c
                local function cancel()
                    if c then c:Disconnect(); c = nil end
                    kb.Text = keyLabel()
                    Library:_kbDone()
                    keep()
                end
                Library:_kbListen("tip", cancel)
                kb.Text = "Pressione uma tecla…"
                c = safeConnect(UserInputService.InputBegan, function(input)
                    local t = input.UserInputType
                    local isMouse = t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3
                    if t ~= Enum.UserInputType.Keyboard and not isMouse then return end
                    local code = isMouse and t or input.KeyCode
                    c:Disconnect(); c = nil
                    Library:_kbDone()
                    if code == Enum.KeyCode.Escape or code == Enum.KeyCode.Backspace then extras.setKey(nil) else extras.setKey(code) end
                    kb.Text = keyLabel()
                    keep()
                end)
            end)
        end
        if extras.isPinned then
            local pb = chipBtn(extras.isPinned() and "Desafixar" or "Fixar na tela", 2)
            safeConnect(pb.MouseButton1Click, function()
                local v = not extras.isPinned()
                extras.setPinned(v)
                pb.Text = v and "Desafixar" or "Fixar na tela"
                keep()
            end)
        end
        if extras.isFavorite then
            local fb = chipBtn(Library.Tr(extras.isFavorite() and "Remover favorito" or "Favoritar"), 3)
            safeConnect(fb.MouseButton1Click, function()
                if not extras.toggleFavorite() then Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Limite de favoritos atingido.") }) end
                fb.Text = Library.Tr(extras.isFavorite() and "Remover favorito" or "Favoritar")
                keep()
            end)
        end
    end
    self._tipFrame = f
    safeConnect(f.MouseEnter, function() self._tipHover = true end)
    safeConnect(f.MouseLeave, function() self._tipHover = false; self:_hideTip(0.3) end)
    local W = main.AbsoluteSize.X / sc
    local x, y, anchor
    if row and row.Parent then
        local mp, rp, rsz = main.AbsolutePosition, row.AbsolutePosition, row.AbsoluteSize
        x = math.clamp((rp.X - mp.X + rsz.X / 2) / sc, 126, math.max(126, W - 126))
        local top, bottom = (rp.Y - mp.Y) / sc, (rp.Y + rsz.Y - mp.Y) / sc
        if top > 110 then anchor, y = Vector2.new(0.5, 1), top - 6 else anchor, y = Vector2.new(0.5, 0), bottom + 6 end
    else
        anchor, x, y = Vector2.new(1, 1), W - 12, main.AbsoluteSize.Y / sc - 12
    end
    f.AnchorPoint = anchor
    f.Position = UDim2.fromOffset(x, y + (anchor.Y == 1 and 6 or -6))
    tween(f, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) }, 0.18, Enum.EasingStyle.Quint)
    self._tipToken = (self._tipToken or 0) + 1
    local my = self._tipToken
    task.delay(extras and 6 or 3.4, function() if self._tipToken == my then self:_hideTip() end end)
end

function Window:_filter(q)
    q = Library.UISupport.normalize(q or "")
    self._filterQuery = q
    local matched, counts = {}, {}
    -- Restaura a abertura anterior dos submenus antes de calcular o novo filtro.
    for panel, wasVisible in pairs(self._searchPanelState or {}) do
        if panel.Parent then panel.Visible = wasVisible end
    end
    self._searchPanelState = {}
    for _, d in ipairs(self._search or {}) do
        if d.Parent then
            local n = d:GetAttribute("SearchName") or ""
            local translated = Library.Tr and Library.Tr(n) or n
            local hit = q == "" or string.find(Library.UISupport.normalize(n), q, 1, true) ~= nil or string.find(Library.UISupport.normalize(translated), q, 1, true) ~= nil
            local blocked = self._hideUnavailable and d:GetAttribute("Unavailable")
            local parent = d.Parent
            while not blocked and parent and type(parent) ~= "boolean" do
                if self._hideUnavailable and parent:GetAttribute("Unavailable") then blocked = true end
                parent = parent.Parent
            end
            d.Visible = not blocked and hit
            if q ~= "" and d.Visible then
                matched[#matched + 1] = d
                local tab = d:GetAttribute("SearchTab") or ""
                counts[tab] = (counts[tab] or 0) + 1
            end
        end
    end
    for _, d in ipairs(matched) do
        local parent = d.Parent
        while parent and type(parent) ~= "boolean" do
            if parent:GetAttribute("SearchName") ~= nil then parent.Visible = true end
            if parent:GetAttribute("SearchPanel") then
                if self._searchPanelState[parent] == nil then self._searchPanelState[parent] = parent.Visible end
                parent.Visible = true
            end
            parent = parent.Parent
        end
    end
    self._searchMatches = matched
    if self._renderSearchResults then self:_renderSearchResults() end
    for _, show in ipairs(self._groups or {}) do show() end
    for _, tab in ipairs(self.Tabs or {}) do
        if tab.TabBtn then
            local count = counts[tab.Name] or 0
            tab.TabBtn:SetAttribute("SearchMatches", count)
            if tab._searchCount then tab._searchCount.Text = count > 0 and tostring(count) or "" end
        end
    end
end
function Window:_openSearchResult(target)
    if not target or not target.Parent then return end
    local node = target.Parent
    while node do
        local openGroup = self._groupOpeners and self._groupOpeners[node]
        local openPanel = self._panelOpeners and self._panelOpeners[node]
        if openGroup then openGroup() end
        if openPanel then openPanel() end
        node = node.Parent
    end
    local tabName = target:GetAttribute("SearchTab")
    for _, tab in ipairs(self.Tabs) do if tab.Name == tabName then self:_select(tab); break end end
    local parent, modal = target.Parent, nil
    while parent do
        local key = parent:GetAttribute("SearchModal")
        if key then modal = self._modals and self._modals[key]; break end
        parent = parent.Parent
    end
    if modal then modal.Overlay.Visible = true end
    if self._searchPopup then self._searchPopup.Visible = false end
    if Library.RecentNavigation and target:GetAttribute("SearchKind") == "Toggle" then
        Library.RecentNavigation:add(target:GetAttribute("SearchKey"))
    end
    task.defer(function()
        task.wait() -- aguarda o layout dos grupos que a busca abriu
        if self._destroyed or not target.Parent then return end
        local scrolls, node = {}, target.Parent
        while node do
            if node:IsA("ScrollingFrame") then scrolls[#scrolls + 1] = node end
            node = node.Parent
        end
        for i = #scrolls, 1, -1 do
            local scroll = scrolls[i]
            local y = scroll.CanvasPosition.Y + target.AbsolutePosition.Y - scroll.AbsolutePosition.Y - 8
            local maxY = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y)
            scroll.CanvasPosition = Vector2.new(scroll.CanvasPosition.X, math.clamp(y, 0, maxY))
        end
    end)
end
function Window:OpenFavorite(key)
    if self._searchBox and self._searchBox.Text ~= "" then self._searchBox.Text = "" end
    for _, d in ipairs(self._search or {}) do
        if d.Parent and d:GetAttribute("SearchKey") == key and d:GetAttribute("SearchKind") == "Toggle" then
            if self._hideUnavailable then
                local current = d
                while current do
                    if current:GetAttribute("Unavailable") then
                        Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Opção oculta por indisponibilidade.") }); return false
                    end
                    current = current.Parent
                end
            end
            self:_openSearchResult(d); return true
        end
    end
    Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Favorito não encontrado nesta sessão.") })
    return false
end
function Window:SetHideUnavailable(value)
    self._hideUnavailable = value == true
    self:_filter(self._filterQuery)
end

function Window:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self._animToken = (self._animToken or 0) + 1
    local isHub = self == Library._hubWindow
    if isHub then
        if Library._stopEngine then pcall(Library._stopEngine) end
        Library:UnprotectAllGuis()
        Library._running = false
        for conn in pairs(Library._uiConnections) do pcall(function() conn:Disconnect() end) end
        table.clear(Library._uiConnections)
        if notifyGui then pcall(function() notifyGui:Destroy() end); notifyGui = nil end
        Library._hubWindow = nil
    end
    for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
    self._groupOpeners, self._panelOpeners, self._groups = {}, {}, {}
    self._search, self._searchMatches, self._searchPanelState, self._touchRows = {}, {}, {}, {}
    self._refreshHomeFavorites = nil
    if self.Gui then pcall(function() self.Gui:Destroy() end) end
    for i, w in ipairs(Library.Windows) do if w == self then table.remove(Library.Windows, i) break end end
    -- sem a janela, o registro de opções e os atalhos não servem para nada
    if isHub then
        for k in pairs(Library.Registry) do Library.Registry[k] = nil end
        table.clear(Library.Keybinds)
        table.clear(Library._toggleBinds)
        table.clear(Library._kbListeners)
        table.clear(Library._themeListeners)
        table.clear(Library._bindings)
        if Library.Appearance then table.clear(Library.Appearance.colorListeners) end
        if Library.Favorites then table.clear(Library.Favorites.listeners) end
        if Library.RecentNavigation then table.clear(Library.RecentNavigation.listeners); table.clear(Library.RecentNavigation.items) end
        table.clear(Library._panicListeners)
        Library._panicZone = nil
    end
end

-- ---------- Ilha: pílula no topo que aparece quando o menu está fechado ----------
function Window:_buildIsland()
    local gui = self.Gui
    local MarketplaceService = game:GetService("MarketplaceService")
    local StatsService = game:GetService("Stats")
    local W0, H0, W1, H1 = 196, 34, 306, 116
    local started = os.clock()
    local island = create("TextButton", { Name = "Island", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(W0, H0),
        BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 30, ClipsDescendants = true }, gui)
    local cr = corner(island, 17)
    stroke(island, "Stroke", 0.2)
    local disc = create("Frame", { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 31 }, island)
    bind(disc, "BackgroundColor3", "Accent"); corner(disc, 12)
    icon(disc, "box", 14, "Accent", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 32 })
    label(island, "BBC HUB", 13, "Text", true, { Position = UDim2.fromOffset(37, 0), Size = UDim2.fromOffset(72, 34), TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 31 })
    local dot = create("Frame", { Position = UDim2.new(1, -82, 0, 14), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0, ZIndex = 31 }, island)
    corner(dot, 3)
    local fpsL = label(island, "60 FPS", 12, "Text", true, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(66, 34), TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 31 })
    local l1 = label(island, "", 13, "Text", true, { Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 17), ZIndex = 31 })
    local l2 = label(island, "", 12, "Muted", false, { Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 0, 16), ZIndex = 31 })
    local l3 = label(island, "", 12, "Muted", false, { Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 16), ZIndex = 31 })
    local l4 = label(island, "", 12, "Accent", true, { Position = UDim2.fromOffset(16, 94), Size = UDim2.new(1, -32, 0, 16), ZIndex = 31 })
    local gameName = "Roblox"
    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then gameName = info.Name end
    end)
    local function fmtClock(t)
        t = math.floor(t)
        local h, m, sec = math.floor(t / 3600), math.floor(t % 3600 / 60), t % 60
        if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
        return string.format("%02d:%02d", m, sec)
    end
    local function update()
        local fps = Library._fps or 60
        fpsL.Text = fps .. " FPS"
        local col = fps >= 50 and Color3.fromRGB(70, 210, 110) or (fps >= 30 and Color3.fromRGB(240, 176, 108) or Color3.fromRGB(240, 100, 100))
        dot.BackgroundColor3 = col
        local ok, ping = pcall(function() return math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        l1.Text = self._hideName and "••••••" or LocalPlayer.DisplayName
        l2.Text = gameName
        l3.Text = Library.Tr("Sessão") .. " " .. fmtClock(os.clock() - started) .. "   ·   " .. (ok and (ping .. " ms") or "— ms") .. "   ·   " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
        l4.Text = (self._key and keyText(self._key) or "—") .. "  ·  " .. Library.Tr("Toque para abrir")
    end
    update()
    local expanded, longPressed = false, false
    local function setExpanded(v)
        if expanded == v then return end
        expanded = v
        tween(island, { Size = UDim2.fromOffset(v and W1 or W0, v and H1 or H0) }, 0.22, Enum.EasingStyle.Quint)
        tween(cr, { CornerRadius = UDim.new(0, v and 20 or 17) }, 0.22, Enum.EasingStyle.Quint)
    end
    safeConnect(island.MouseEnter, function()
        if UserInputService.TouchEnabled and not (UserInputService.MouseEnabled or UserInputService.KeyboardEnabled) then return end
        setExpanded(true)
    end)
    safeConnect(island.MouseLeave, function() setExpanded(false) end)
    safeConnect(island.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            longPressed = false
            task.delay(0.45, function()
                if island.Parent and island.Visible then
                    longPressed = true
                    setExpanded(true)
                    task.delay(3.5, function() setExpanded(false) end)
                end
            end)
        end
    end)
    safeConnect(island.MouseButton1Click, function()
        if longPressed then longPressed = false return end
        self:SetVisible(true)
    end)
    task.spawn(function()
        while gui.Parent do
            task.wait(0.5)
            if gui.Parent and island.Visible then safeCall(update) end
        end
    end)
    self._island = island
    self:_updateIsland()
end

-- ---------- Janela ----------
-- ---------- Logo: cubo 3D girando (ViewportFrame) ----------
local CUBE_GLYPH = {
    B = { "1111.", "1...1", "1...1", "1111.", "1...1", "1...1", "1111." },
    C = { ".111.", "1...1", "1....", "1....", "1....", "1...1", ".111." },
}
local CUBE_FACES = {   -- direção da face, "para cima" da face, letra
    { Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), "B" }, { Vector3.new(1, 0, 0), Vector3.new(0, 1, 0), "B" },
    { Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), "C" }, { Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0), "B" },
    { Vector3.new(0, 1, 0), Vector3.new(0, 0, -1), "C" }, { Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), "B" },
}
local function buildCubeLogo(parent, props, active)
    local vp = create("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(44, 44), Ambient = Color3.fromRGB(170, 170, 170),
        LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-0.6, -1, -0.8) }, parent)
    for k, v in pairs(props or {}) do vp[k] = v end
    local cam = create("Camera", { FieldOfView = 28, CFrame = CFrame.new(0, 0, 8.6) })
    cam.Parent = vp
    vp.CurrentCamera = cam
    local model = create("Model", {}, vp)
    local tint = {}
    local function part(size, cf, color, material, accent)
        local p = create("Part", { Anchored = true, CanCollide = false, CastShadow = false, Size = size, CFrame = cf, Color = color,
            Material = material, TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth }, model)
        if accent then tint[#tint + 1] = p end
        return p
    end
    local body = part(Vector3.new(2, 2, 2), CFrame.new(), Library.Theme.Surface2, Enum.Material.SmoothPlastic, false)
    model.PrimaryPart = body
    local E = 0.1
    for _, a in ipairs({ -1, 1 }) do
        for _, b in ipairs({ -1, 1 }) do   -- as 12 arestas brilhando na cor do tema
            part(Vector3.new(2.1, E, E), CFrame.new(0, a, b), Library.Theme.Accent, Enum.Material.Neon, true)
            part(Vector3.new(E, 2.1, E), CFrame.new(a, 0, b), Library.Theme.Accent, Enum.Material.Neon, true)
            part(Vector3.new(E, E, 2.1), CFrame.new(a, b, 0), Library.Theme.Accent, Enum.Material.Neon, true)
        end
    end
    local cell = 0.25
    for _, face in ipairs(CUBE_FACES) do   -- letras B / C feitas de pequenos blocos em cada face
        local fcf = CFrame.lookAt(face[1], Vector3.zero, face[2])
        local rows = CUBE_GLYPH[face[3]]
        for r = 1, #rows do
            for c = 1, 5 do
                if string.sub(rows[r], c, c) == "1" then
                    part(Vector3.new(cell * 0.92, cell * 0.92, 0.08), fcf * CFrame.new((c - 3) * cell, (4 - r) * cell, 0.04), Library.Theme.Accent, Enum.Material.Neon, true)
                end
            end
        end
    end
    table.insert(Library._themeListeners, function()
        if not vp.Parent then return end
        body.Color = Library.Theme.Surface2
        for _, p in ipairs(tint) do p.Color = Library.Theme.Accent end
    end)
    local t, conn = 0, nil
    conn = safeConnect(RunService.RenderStepped, function(dt)
        if not vp.Parent then conn:Disconnect() return end
        if active and not active() then return end
        if Library.ReduceMotion then return end
        t += dt
        model:PivotTo(CFrame.Angles(math.rad(-22), 0, math.rad(8)) * CFrame.Angles(0, t * 0.9, 0))
    end)
    return vp
end

-- ---------- Intro: cartão de carregamento que vira a janela ----------
-- Aparece assim que o loadstring roda: logo, passos com check, barra de progresso
-- e no final o cartão "se abre" e vira o menu. Window:FinishLoading() avisa que
-- o script terminou de montar as abas (sem isso ele espera no máx. 12s).
function Window:FinishLoading()
    task.spawn(function()
        local waitStart = os.clock()
        while not self._destroyed and (self._pendingPrebuild or 0) > 0 and os.clock() - waitStart < 8 do task.wait(0.05) end
        if self._destroyed then return end
        if self._prebuildFailed or (self._pendingPrebuild or 0) > 0 then
            self._autoSaveBlocked = true
            if Library.Diagnostics then Library.Diagnostics:record("inicialização", "painel incompleto; autoload e autosave suspensos") end
            Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Painel incompleto; carregamento automático suspenso."), Duration = 8 })
            return
        end
        self._loaded = true
        local t0 = os.clock()
        while self._introActive and os.clock() - t0 < 20 do task.wait(0.1) end
        self:CaptureDefaults()
        local auto = self:GetAutoload()
        if auto and not self:LoadConfig(auto, true) then
            Library:Notify({ Title = "BBC HUB", Content = "Não foi possível carregar a configuração inicial; arquivo preservado." })
            -- Não permitir que o autosave substitua um arquivo que falhou ao carregar.
            self._autoSaveBlocked = true
        elseif not auto and canFS() then
            local ok, exists = pcall(isfile, CFG_FOLDER .. "/default.json")
            if not ok or exists then
                self._autoSaveBlocked = true
                Library:Notify({ Title = "BBC HUB", Content = "Configuração existente preservada; carregue ou salve uma configuração para ativar o salvamento automático." })
            end
        end
        self._ready = true
        self:StartAutoSave()
    end)
end

function Window:_startIntro(opts, W, H)
    local gui, main = self.Gui, self._main
    local steps = { "Preparando interface", "Carregando ícones", "Montando o menu" }
    local WIDTH, PAD, STEP, listTop = 340, 22, 24, 80
    local height = listTop + #steps * STEP + 18
    self._introActive = true
    self._loaded = false

    local loader = create("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 12), Size = UDim2.fromOffset(WIDTH, height),
        BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 60 }, gui)
    bind(loader, "BackgroundColor3", "Background")
    local loaderCorner = corner(loader, 12)
    local loaderStroke = stroke(loader, "Stroke", 0)
    local loaderScale = create("UIScale", { Scale = 0.96 }, loader)
    local content = create("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, loader)

    -- logo (respira enquanto carrega) + título + status + porcentagem
    local logoHolder = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(PAD + 15, PAD + 15), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1 }, content)
    local logoScale = create("UIScale", { Scale = 1 }, logoHolder)
    icon(logoHolder, "box", 30, "Accent", { Size = UDim2.fromScale(1, 1) })
    if not Library.ReduceMotion then TweenService:Create(logoScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.14 }):Play() end
    local TEXT_X = PAD + 42
    label(content, opts.Title or "BBC HUB", 15, "Text", true, { Position = UDim2.fromOffset(TEXT_X, PAD - 2), Size = UDim2.new(1, -(TEXT_X + 70), 0, 18) })
    local statusLabel = label(content, "Iniciando", 12, "Muted", false, { Position = UDim2.fromOffset(TEXT_X, PAD + 17), Size = UDim2.new(1, -(TEXT_X + 70), 0, 15) })
    local percentLabel = label(content, "0%", 13, "Muted", false, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -PAD, 0, PAD + 6),
        Size = UDim2.fromOffset(56, 16), TextXAlignment = Enum.TextXAlignment.Right })
    local hair = create("Frame", { Position = UDim2.fromOffset(PAD, listTop - 14), Size = UDim2.new(1, -PAD * 2, 0, 1), BorderSizePixel = 0 }, content)
    bind(hair, "BackgroundColor3", "Stroke")

    -- cada passo: ponto apagado (espera) -> arco girando (rodando) -> ✓ (feito)
    local rows = {}
    for index, text in ipairs(steps) do
        local row = create("Frame", { Position = UDim2.fromOffset(PAD, listTop + (index - 1) * STEP), Size = UDim2.new(1, -PAD * 2, 0, STEP), BackgroundTransparency = 1 }, content)
        local dot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0 }, row)
        bind(dot, "BackgroundColor3", "Surface3"); corner(dot, 3)
        local spinner = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Visible = false }, row)
        corner(spinner, 6)
        local spStroke = create("UIStroke", { Thickness = 2 }, spinner)
        bind(spStroke, "Color", "Accent")
        create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) }) }, spStroke)
        local check = label(row, "✓", 14, "Accent", true, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 7, 0.5, 0), Size = UDim2.fromOffset(16, 16),
            TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, TextTransparency = 1 })
        local stepLabel = label(row, Library.Tr(text), 13, "Muted", false, { Position = UDim2.fromOffset(24, 0), Size = UDim2.new(1, -24, 1, 0),
            TextYAlignment = Enum.TextYAlignment.Center, TextTransparency = 1 })
        rows[index] = { Dot = dot, Spinner = spinner, Check = check, Label = stepLabel, Text = text, State = "pending" }
        task.delay(0.15 + index * 0.06, function()   -- os passos entram um atrás do outro
            if loader.Parent and rows[index].State == "pending" then tween(stepLabel, { TextTransparency = 0.45 }, 0.3) end
        end)
    end
    local function setStep(index, state)
        local row = rows[index]
        if not row or row.State == state then return end
        row.State = state
        row.Dot.Visible = state == "pending"
        row.Spinner.Visible = state == "active"
        local mark = state == "done" or state == "warn"
        row.Check.Text = state == "warn" and "⚠" or "✓"
        row.Check.TextColor3 = state == "warn" and Library.Theme.Warning or Library.Theme.Accent
        tween(row.Check, { TextTransparency = mark and 0 or 1 }, 0.2)
        tween(row.Label, { TextTransparency = state == "pending" and 0.45 or 0,
            TextColor3 = state == "active" and Library.Theme.Text or Library.Theme.Muted }, 0.2)
        if state == "active" then statusLabel.Text = Library.Tr(row.Text) end
    end

    -- barra fina de progresso na borda de baixo
    local track = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0 }, content)
    bind(track, "BackgroundColor3", "Surface3")
    local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
    bind(fill, "BackgroundColor3", "Accent")
    local curP = 0
    local function progress(v, t)
        if v < curP then return end
        curP = v
        tween(fill, { Size = UDim2.fromScale(v, 1) }, t or 0.4, Enum.EasingStyle.Quart)
    end
    self._introProgress = function(v, text)
        progress(v, 0.3)
        if text and rows[3] and rows[3].State == "active" then statusLabel.Text = text end
    end

    local stepConn
    stepConn = safeConnect(RunService.RenderStepped, function(dt)
        if not loader.Parent then stepConn:Disconnect() return end
        percentLabel.Text = math.floor(fill.Size.X.Scale * 100 + 0.5) .. "%"
        for _, row in ipairs(rows) do
            if row.State == "active" then row.Spinner.Rotation = (row.Spinner.Rotation + dt * 360) % 360 end
        end
    end)

    -- entrada do cartão
    tween(loader, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) }, 0.45, Enum.EasingStyle.Quint)
    tween(loaderScale, { Scale = 1 }, 0.45, Enum.EasingStyle.Quint)

    local function cleanup()
        if not self._introActive or self._destroyed then return end
        pcall(function() stepConn:Disconnect() end)
        if loader.Parent then loader:Destroy() end
        main.Visible = true
        self._introActive = false
        self._introProgress = nil
        self._wantOpen = true
        if self._toggleBtn then self._toggleBtn.Visible = true end
        self:_updateIsland()
    end

    local skip = create("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -5), Size = UDim2.fromOffset(76, 24), BackgroundTransparency = 1, Text = Library.Tr("Pular intro"), TextSize = 12, FontFace = Library.Fonts.Bold, AutoButtonColor = false, ZIndex = 63 }, content)
    bind(skip, "TextColor3", "Text")
    safeConnect(skip.MouseButton1Click, cleanup)

    -- final: o cartão cresce até o tamanho do menu, o menu aparece e o cartão some
    local function finish()
        if not self._introActive or self._destroyed then return end
        for i, r in ipairs(rows) do if r.State ~= "warn" then setStep(i, "done") end end
        progress(1, 0.25)
        statusLabel.Text = Library.Tr("Menu montado")
        task.wait(0.35)
        tween(content, { GroupTransparency = 1 }, 0.18)
        local fit = self._fitScale or 1
        tween(loader, { Size = UDim2.fromOffset(W * fit, H * fit) }, 0.5, Enum.EasingStyle.Quint)
        tween(loaderCorner, { CornerRadius = UDim.new(0, 6) }, 0.5, Enum.EasingStyle.Quint)
        task.wait(0.28)
        main.Visible = true
        if self._scale then
            self._scale.Scale = fit * 0.96
            tween(self._scale, { Scale = fit }, 0.35, Enum.EasingStyle.Quint)
        end
        tween(loader, { GroupTransparency = 1 }, 0.25)
        tween(loaderStroke, { Transparency = 1 }, 0.2)
        task.wait(0.3)
        cleanup()
    end

    task.spawn(function()
        local ok, err = pcall(function()
            setStep(1, "active"); progress(0, 0)
            task.wait(Library.ReduceMotion and 0 or 0.15)
            if not self._introActive then return end
            setStep(1, "done")
            setStep(2, "active"); progress(1 / 3, 0.3)
            -- Os símbolos locais estão prontos; não há download remoto de ícones.
            rows[2].Label.Text = Library.Tr("Símbolos locais prontos")
            setStep(2, "done")
            setStep(3, "active"); progress(2 / 3, 0.3)
            local t2 = os.clock()
            while self._introActive and not self._loaded and os.clock() - t2 < 12 do task.wait(0.05) end
            if not self._introActive then return end
            if not self._loaded then
                rows[3].Label.Text = Library.Tr("Montagem ainda em andamento")
                setStep(3, "warn")
                statusLabel.Text = Library.Tr("Montagem ainda em andamento")
                task.wait(1)
                cleanup()
                Library:Notify({ Title = "BBC HUB", Content = Library.Tr("Montagem ainda em andamento"), Duration = 5 })
                return
            end
            task.wait(Library.ReduceMotion and 0 or 0.2)
            finish()
        end)
        if not ok then
            warn("[BBC] intro: " .. tostring(err))
            cleanup()   -- se algo falhar, abre o menu direto
        end
    end)
end

function Window:SetScaleFactor(factor)
    if type(factor) ~= "number" or factor ~= factor or factor == math.huge or factor == -math.huge then return false end
    self._scaleFactor = math.clamp(factor, 0.7, 1.3)
    if self._fit then self._fit() end
    return true
end

function Library:Window(opts)
    opts = opts or {}
    if opts.Theme and Library.ThemePresets[opts.Theme] and not Library.Appearance then Library:SetTheme(opts.Theme) end
    local self = setmetatable({ Tabs = {}, _conns = {}, _hideName = false, _hideAvatar = false, _btnDraggable = true }, Window)
    local W = (opts.Size and opts.Size.X.Offset > 0) and opts.Size.X.Offset or 640
    local H = (opts.Size and opts.Size.Y.Offset > 0) and opts.Size.Y.Offset or 360
    local intro = opts.Intro ~= false and not (Library.Appearance and Library.Appearance.skipIntro)
    local gui = Library:CreateRootGui("ScreenGui", { Name = "BBCHub", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
    self.Gui = gui
    local main = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BorderSizePixel = 0, Visible = not intro }, gui)
    bind(main, "BackgroundColor3", "Background"); corner(main, 6)
    self._mainStroke = stroke(main, "Stroke", 0)
    bind(self._mainStroke, "Color", function() return self._accentBorder and Library.Theme.Accent or Library.Theme.Stroke end)
    self._main = main
    local scale = create("UIScale", {}, main)
    self._scale = scale
    local function fit()
        local vp = gui.AbsoluteSize
        if vp.X <= 0 or vp.Y <= 0 then return end
        scale.Scale = Library.fitScale(vp.X, vp.Y, W, H, self._scaleFactor or 1)
        self._fitScale = scale.Scale
        local halfX, halfY = W * scale.Scale / 2, H * scale.Scale / 2
        local x = main.Position.X.Scale * vp.X + main.Position.X.Offset
        local y = main.Position.Y.Scale * vp.Y + main.Position.Y.Offset
        main.Position = UDim2.fromOffset(math.clamp(x, halfX, math.max(halfX, vp.X - halfX)), math.clamp(y, halfY, math.max(halfY, vp.Y - halfY)))
        if self._toggleBtn then
            local b = self._toggleBtn
            local bx = b.Position.X.Scale * vp.X + b.Position.X.Offset
            local by = b.Position.Y.Scale * vp.Y + b.Position.Y.Offset
            b.Position = UDim2.fromOffset(math.clamp(bx, 0, math.max(0, vp.X - 46)), math.clamp(by, 0, math.max(0, vp.Y - 46)))
        end
        for _, tab in ipairs(self.Tabs) do tab:_layoutColumns() end
        local compact = Library.UISupport.compact(vp.X, vp.Y, UserInputService.TouchEnabled)
        for i = #(self._touchRows or {}), 1, -1 do
            local entry = self._touchRows[i]
            if entry.row.Parent then entry.row.Size = UDim2.new(1, 0, 0, compact and math.max(40, entry.baseline) or entry.baseline)
            else table.remove(self._touchRows, i) end
        end
        for _, pin in pairs(self._pins or {}) do
            local b = pin.btn
            local px = (b.Position.X.Scale * vp.X + b.Position.X.Offset) / vp.X
            local py = (b.Position.Y.Scale * vp.Y + b.Position.Y.Offset) / vp.Y
            local hx, hy = math.min(0.5, 23 / vp.X), math.min(0.5, 23 / vp.Y)
            b.Position = UDim2.fromScale(math.clamp(px, hx, 1 - hx), math.clamp(py, hy, 1 - hy))
        end
    end
    self._fit = fit
    fit()
    self:_connect(gui:GetPropertyChangedSignal("AbsoluteSize"), fit)
    -- intro de carregamento (aparece na hora em que o loadstring executa)
    if intro then self:_startIntro(opts, W, H) end
    -- espera os ícones carregarem (até 25s) para a janela já nascer completa
    local t0 = os.clock()
    while not lucide and not iconsGaveUp and os.clock() - t0 < 25 do task.wait(0.1) end
    if not lucide then
        iconsGaveUp = true -- símbolos de texto por enquanto; se o download terminar depois, os ícones reais entram sozinhos
        for _, rec in ipairs(allIcons) do showGlyph(rec) end
    end
    self._key = parseKey(opts.Keybind or "RightShift")
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if processed or Library._listening or os.clock() - (Library._lastBind or 0) < 0.25 then return end
        local t = input.UserInputType
        local code = t == Enum.UserInputType.Keyboard and input.KeyCode or t
        if self._key and code == self._key then self:Toggle() end
        for _, b in ipairs(Library._toggleBinds) do
            local k = b.key()
            if k and code == k then task.spawn(function() safeCall(b.fire) end) end
        end
    end)

    -- cabeçalho
    local header = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1 }, main)
    do
        local okc, vp = pcall(buildCubeLogo, header, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(44, 44) }, function() return main.Visible end)
        self._logo = (okc and vp) or icon(header, "box", 30, "Accent", { Position = UDim2.fromOffset(12, 11) })
    end
    label(header, "BBC", 17, "Accent", true, { Position = UDim2.fromOffset(50, 6), Size = UDim2.fromOffset(70, 20) })
    label(header, "HUB", 17, "Text", true, { Position = UDim2.fromOffset(50, 25), Size = UDim2.fromOffset(70, 20) })
    local dragging, dragStart, startPos = false, nil, nil
    safeConnect(header.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, i.Position, main.Position
        end
    end)
    self:_connect(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            local vp = gui.AbsoluteSize
            local half = main.AbsoluteSize / 2
            local x = startPos.X.Scale * vp.X + startPos.X.Offset + d.X
            local y = startPos.Y.Scale * vp.Y + startPos.Y.Offset + d.Y
            main.Position = UDim2.fromOffset(math.clamp(x, half.X, math.max(half.X, vp.X - half.X)), math.clamp(y, half.Y, math.max(half.Y, vp.Y - half.Y)))
        end
    end)
    self:_connect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)

    -- Barra original de perfil, preservando confirmação para sobrescrita e carga.
    local cfgBar = create("Frame", { Position = UDim2.fromOffset(130, 11), Size = UDim2.new(1, -330, 0, 30), BorderSizePixel = 0 }, header)
    bind(cfgBar, "BackgroundColor3", "Surface2"); corner(cfgBar, 3); stroke(cfgBar, "Stroke", 0.1)
    local saveBtn = create("TextButton", { Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, cfgBar)
    icon(saveBtn, "save", 18, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
    local cfgBox = create("TextBox", { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -38, 1, 0), BackgroundTransparency = 1, Text = "default", TextSize = 14,
        FontFace = Library.Fonts.Regular, ClearTextOnFocus = false, PlaceholderText = "default" }, cfgBar)
    bind(cfgBox, "TextColor3", "Text"); bind(cfgBox, "PlaceholderColor3", "Muted")
    self._headerCfgBox = cfgBox
    safeConnect(saveBtn.MouseButton1Click, function()
        local ok, reason = self:RequestSaveConfig(cfgBox.Text)
        if ok then self:SetAutoload(self._cfgName or "default") end
        Library:Notify({ Title = "BBC HUB", Content = ok and "Configuração salva." or ("Salvar: " .. tostring(reason) .. ". Confirme novamente se solicitado."), Duration = 4 })
    end)
    safeConnect(cfgBox.FocusLost, function(enter)
        if not enter then return end
        local name = cleanName(cfgBox.Text); if name == "" then name = "default" end
        if self._configPreview and self._configPreview.name == name then
            local ok, err = self:ConfirmConfigPreview(name)
            if ok then self:SetAutoload(name) end
            Library:Notify({ Title = "BBC HUB", Content = ok and "Configuração carregada." or ("Carregamento: " .. tostring(err)), Duration = 4 })
        else
            local report, err = self:StageConfigPreview(name)
            Library:Notify({ Title = "BBC HUB", Content = report and ("Prévia: " .. #report.changes .. " alterações. Veja Configurações ou pressione Enter novamente para confirmar.") or ("Prévia: " .. tostring(err)), Duration = 5 })
        end
    end)
    -- busca
    local searchBox = create("TextBox", { Position = UDim2.fromOffset(130, 11), Size = UDim2.new(1, -330, 0, 30), Text = "", PlaceholderText = Library.Tr("Buscar por nome"), TextSize = 14,
        FontFace = Library.Fonts.Regular, ClearTextOnFocus = false, Visible = false, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left }, header)
    bind(searchBox, "BackgroundColor3", "Surface2"); bind(searchBox, "TextColor3", "Text"); bind(searchBox, "PlaceholderColor3", "Muted")
    corner(searchBox, 3); stroke(searchBox, "Accent", 0.2); pad(searchBox, 10, 8, 0, 0)
    self._searchBox = searchBox
    self._refreshSearchLanguage = function() searchBox.PlaceholderText = Library.Tr("Buscar por nome") end
    safeConnect(searchBox:GetPropertyChangedSignal("Text"), function() self:_filter(searchBox.Text) end)
    -- botões do canto
    local function headerBtn(iconName, offset)
        local b = create("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -offset, 0, 11), Size = UDim2.fromOffset(30, 30), Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, header)
        bind(b, "BackgroundColor3", "Surface2"); corner(b, 3)
        local st = stroke(b, "Stroke", 0.05)
        local ic = icon(b, iconName, 16, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
        return b, ic, st
    end
    local searchBtn = headerBtn("search", 12 + 36 + 36)
    local flameBtn, flameIcon, flameStroke = headerBtn("flame", 12 + 36)
    local gearBtn, gearIcon, gearStroke = headerBtn("settings", 12)
    self._flameBtn, self._flameIcon, self._flameStroke = flameBtn, flameIcon, flameStroke
    self._gearBtn, self._gearIcon, self._gearStroke = gearBtn, gearIcon, gearStroke
    safeConnect(searchBtn.MouseButton1Click, function()
        local on = not searchBox.Visible
        searchBox.Visible = on; cfgBar.Visible = not on
        if on then searchBox:CaptureFocus() else searchBox.Text = ""; if self._searchPopup then self._searchPopup.Visible = false end end
    end)
    -- Atalho convencional, apenas com menu visível e sem outro campo em foco.
    self:_connect(UserInputService.InputBegan, function(input, processed)
        if input.UserInputType ~= Enum.UserInputType.Keyboard or Library._listening or self._introActive or Library.Panic or not main.Visible then return end
        local focus = UserInputService:GetFocusedTextBox()
        if input.KeyCode == Enum.KeyCode.Escape and focus == searchBox then
            searchBox:ReleaseFocus(); searchBox.Visible = false; searchBox.Text = ""
            if self._searchPopup then self._searchPopup.Visible = false end
        elseif not processed and not focus and input.KeyCode == Enum.KeyCode.F and
            (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            searchBox.Visible = true; searchBox:CaptureFocus()
        end
    end)
    safeConnect(flameBtn.MouseButton1Click, function() self:_select(self.HomeTab) end)
    safeConnect(gearBtn.MouseButton1Click, function()
        for _, t in ipairs(self.Tabs) do if t.IsSettings then self:_select(t) break end end
    end)

    -- barra lateral
    local side = create("Frame", { Position = UDim2.fromOffset(0, 52), Size = UDim2.new(0, 152, 1, -52), BackgroundTransparency = 1 }, main)
    self._tabList = create("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -54), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y }, side)
    pad(self._tabList, 6, 4, 2, 2); listLayout(self._tabList, 2)
    local div = create("Frame", { Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 1, 1, -6), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, side)
    bind(div, "BackgroundColor3", "Stroke")
    -- cartão do jogador
    local card = create("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -6), Size = UDim2.new(1, -12, 0, 44), Text = "", AutoButtonColor = false, BorderSizePixel = 0 }, side)
    bind(card, "BackgroundColor3", "Surface2"); corner(card, 4); stroke(card, "Accent", 0.15)
    self._pAvatar = create("ImageLabel", { Position = UDim2.fromOffset(6, 7), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 0, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop }, card)
    bind(self._pAvatar, "BackgroundColor3", "Surface3"); corner(self._pAvatar, 15)
    self._pName = label(card, LocalPlayer.DisplayName, 13, "Text", false, { Position = UDim2.fromOffset(42, 5), Size = UDim2.new(1, -46, 0, 17) })
    local pSub = label(card, "", 11, "Muted", false, { Position = UDim2.fromOffset(42, 23), Size = UDim2.new(1, -46, 0, 15) })
    task.spawn(function()
        local ok, img = pcall(function() return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
        if ok and Library._running and self.Gui and self.Gui.Parent then
            self._thumb = img
            safeCall(function() self:_renderIdentity() end)
        end
    end)
    local home = type(opts.Home) == "table" and opts.Home or {}
    local function subText()
        local e = home.Expiry
        if type(e) == "function" then local ok, r = pcall(e); e = ok and r or nil end
        if type(e) == "number" then
            local left = e - os.time()
            return left > 0 and (fmtLeft(left) .. " left") or "Expired"
        end
        return "Ilimitado"
    end
    pSub.Text = subText()
    task.spawn(function() while gui.Parent do task.wait(20); if gui.Parent then safeCall(function() pSub.Text = subText() end) end end end)
    safeConnect(card.MouseButton1Click, function() self:_select(self.HomeTab) end)

    -- conteúdo
    self._content = create("Frame", { Position = UDim2.fromOffset(160, 54), Size = UDim2.new(1, -168, 1, -62), BackgroundTransparency = 1, ClipsDescendants = true }, main)

    -- Lista de resultados: os botões são reutilizados, sem criar conexões a cada tecla.
    do
        local popup = create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 30 }, self._content)
        bind(popup, "BackgroundColor3", "Surface"); corner(popup, 4); stroke(popup, "Accent", 0.2)
        local summary = label(popup, "", 12, "Text", true, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 26), ZIndex = 31 })
        local results = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 31 }, popup)
        bind(results, "ScrollBarImageColor3", "Accent"); pad(results, 6, 8, 0, 6); listLayout(results, 3)
        local slots = {}
        for i = 1, 40 do
            local b = create("TextButton", { Size = UDim2.new(1, 0, 0, 36), BorderSizePixel = 0, Text = "", TextSize = 12,
                FontFace = Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                AutoButtonColor = false, LayoutOrder = i, Visible = false, ZIndex = 32 }, results)
            bind(b, "BackgroundColor3", "Surface2"); bind(b, "TextColor3", "Text"); corner(b, 4); pad(b, 8, 8, 0, 0)
            local slot = { button = b }
            slots[i] = slot
            safeConnect(b.MouseButton1Click, function() self:_openSearchResult(slot.target) end)
        end
        self._searchPopup = popup
        function self:_renderSearchResults()
            local query, hits = self._filterQuery or "", self._searchMatches or {}
            popup.Visible = searchBox.Visible and query ~= ""
            if not popup.Visible then return end
            summary.Text = #hits == 0 and Library.Tr("Nenhum resultado") or (Library.Tr("Resultados") .. ": " .. #hits .. (#hits > #slots and " · 40" or ""))
            results.CanvasPosition = Vector2.new(0, 0)
            for i, slot in ipairs(slots) do
                local d = hits[i]
                slot.target, slot.button.Visible = d, d ~= nil
                if d then
                    local path, pieces = d:GetAttribute("SearchPath") or "", {}
                    for part in string.gmatch(path, "[^/]+") do pieces[#pieces + 1] = Library.Tr(part) end
                    slot.button.Text = table.concat(pieces, " › ") .. " · " .. Library.Tr(d:GetAttribute("SearchName") or "")
                end
            end
        end
        safeConnect(searchBox.FocusLost, function(enter)
            if enter and popup.Visible and slots[1].target then self:_openSearchResult(slots[1].target) end
        end)
    end

    -- página inicial (perfil), escondida da barra lateral
    if opts.Home ~= false then
        local homeTab = self:Tab({ Name = "Home", Hidden = true })
        if type(home.Build) == "function" then safeCall(home.Build, self, homeTab, homeTab.List) end
    end
    self:_buildIsland()
    table.insert(Library.Windows, self)
    table.insert(Library._themeListeners, function()
        if gui.Parent and self.Current then self:_select(self.Current) end
    end)
    self:_renderIdentity()
    return self
end

-- Utilitários necessários ao código do hub fora desta biblioteca.
Library.Internal = { create = create, bind = bind, corner = corner, stroke = stroke, tips = TIPS, setTipResolver = function(fn) tipFor = fn end }
return Library
end)()
-- ============ 20_config.luau :: Perfil, idiomas, configuração, persistência ============


pcall(function() if type(getgenv) == "function" then getgenv().BBCLib = Library end end)


-- ============================================================
--  BBC HUB - interface (somente visual, callbacks vazios)
-- ============================================================

-- ============================================================
--  PAINEL DE PERFIL (dados reais do aparelho, da conta e do jogo)
-- ============================================================

-- ============================================================
--  IDIOMAS (English / Español / Português / 简体中文 / Русский)
-- ============================================================
local LangUIS = game:GetService("UserInputService")
local LANG_CODES = { ["English"] = "en", ["Español"] = "es", ["Português (Brasil)"] = "pt", ["简体中文"] = "zh", ["Русский"] = "ru" }
local LANG_NAMES = { en = "English", es = "Español", pt = "Português (Brasil)", zh = "简体中文", ru = "Русский" }
local DICT = {}
do
    local RAW = [==[
Menu montado|Menu built|Menú construido|菜单已构建|Меню создано
Escolha uma cor na amostra; aplique depois para mudar o menu.|Choose a color in the preview, then apply it to the menu.|Elige un color en la muestra y aplícalo después al menú.|在预览中选择颜色，然后应用到菜单。|Выберите цвет в образце и затем примените его к меню.
Aumenta o contraste da superfície e do texto; cores escolhidas podem variar.|Increases surface and text contrast; chosen colors may vary.|Aumenta el contraste de la superficie y el texto; los colores elegidos pueden variar.|提高背景和文字对比度；所选颜色可能影响效果。|Повышает контраст фона и текста; выбранные цвета могут влиять на результат.
Reduz transições e animações visuais do menu e da prévia.|Reduces menu and preview transitions and visual animations.|Reduce las transiciones y animaciones visuales del menú y la vista previa.|减少菜单和预览的过渡及动画。|Уменьшает переходы и анимацию меню и предпросмотра.
Abre o menu sem o cartão de carregamento na próxima inicialização.|Opens the menu without the loading card on the next launch.|Abre el menú sin la tarjeta de carga al iniciar la próxima vez.|下次启动时不显示加载卡片。|При следующем запуске открывает меню без экрана загрузки.
Tempo médio do motor visual|Average visual engine time|Tiempo medio del motor visual|视觉引擎平均耗时|Среднее время визуального движка
Painel incompleto; carregamento automático suspenso.|Panel incomplete; automatic loading suspended.|Panel incompleto; carga automática suspendida.|面板未完成；已暂停自动加载。|Панель не завершена; автозагрузка приостановлена.
Ajustes pendentes|Pending settings|Ajustes pendientes|待实现设置|Ожидающие настройки
Mochila nativa: sem ajustes específicos.|Native backpack: no specific settings.|Mochila nativa: sin ajustes específicos.|原生背包：没有特定设置。|Стандартный рюкзак: специальных настроек нет.
Recentes nesta sessão|Recent in this session|Recientes en esta sesión|本次最近访问|Недавние в этом сеансе
Navegue pela busca ou favoritos para ver opções recentes.|Navigate using search or favorites to see recent options.|Navega mediante búsqueda o favoritos para ver opciones recientes.|通过搜索或收藏导航，即可查看最近选项。|Используйте поиск или избранное, чтобы увидеть недавние пункты.
Favoritos|Favorites|Favoritos|收藏|Избранное
Favoritar|Favorite|Añadir a favoritos|收藏|В избранное
Remover favorito|Remove favorite|Quitar de favoritos|取消收藏|Убрать из избранного
Limite de favoritos atingido.|Favorites limit reached.|Se alcanzó el límite de favoritos.|已达到收藏数量上限。|Достигнут предел избранного.
Segure uma opção e toque em Favoritar.|Hold an option and tap Favorite.|Mantén pulsada una opción y toca Favoritos.|按住选项并点击收藏。|Удерживайте опцию и нажмите «В избранное».
Configuração ativa|Active configuration|Configuración activa|当前配置|Активная конфигурация
Opção oculta por indisponibilidade.|Option hidden because it is unavailable.|Opción oculta por no estar disponible.|不可用选项已隐藏。|Недоступная опция скрыта.
Favorito não encontrado nesta sessão.|Favorite not found in this session.|Favorito no encontrado en esta sesión.|本次会话中找不到收藏。|Избранное не найдено в этой сессии.
FAVORITOS|FAVORITES|FAVORITOS|收藏|ИЗБРАННОЕ
Página anterior da prévia|Previous preview page|Página anterior de la vista|预览上一页|Предыдущая страница
Próxima página da prévia|Next preview page|Siguiente página de la vista|预览下一页|Следующая страница
Versão do histórico|History version|Versión del historial|历史版本|Версия истории
Atualizar histórico|Refresh history|Actualizar historial|刷新历史|Обновить историю
Criar versão|Create version|Crear versión|创建版本|Создать версию
Restaurar versão em cópia|Restore version to a copy|Restaurar versión en copia|将版本恢复到副本|Восстановить версию в копию
Versão criada|Version created|Versión creada|版本已创建|Версия создана
Não foi possível criar versão|Could not create version|No se pudo crear la versión|无法创建版本|Не удалось создать версию
Cópia criada; revise antes de carregar|Copy created; review before loading|Copia creada; revisa antes de cargar|已创建副本；加载前请检查|Копия создана; проверьте перед загрузкой
Não foi possível recuperar a versão|Could not recover the version|No se pudo recuperar la versión|无法恢复版本|Не удалось восстановить версию
Histórico não criado; backup normal continua disponível.|History not created; the regular backup remains available.|No se creó el historial; la copia normal sigue disponible.|未创建历史版本；普通备份仍可用。|История не создана; обычная резервная копия доступна.
Toque em Salvar novamente em até 30 segundos para confirmar.|Tap Save again within 30 seconds to confirm.|Toca Guardar de nuevo en 30 segundos para confirmar.|请在 30 秒内再次点击保存以确认。|Нажмите «Сохранить» ещё раз в течение 30 секунд для подтверждения.
Arquivo ou ajustes mudaram; confirme novamente.|File or settings changed; confirm again.|El archivo o los ajustes cambiaron; confirma de nuevo.|文件或设置已更改，请重新确认。|Файл или настройки изменились; подтвердите снова.
Falha ao salvar; veja o diagnóstico.|Save failed; check diagnostics.|Error al guardar; consulta el diagnóstico.|保存失败；请查看诊断。|Ошибка сохранения; проверьте диагностику.
Montagem|Setup|Montaje|构建|Сборка
Falhou|Failed|Falló|失败|Ошибка
Concluída|Completed|Completada|已完成|Завершена
Pendente|Pending|Pendiente|待处理|Ожидание
Salvamento automático|Autosave|Guardado automático|自动保存|Автосохранение
Suspenso|Suspended|Suspendido|已暂停|Приостановлено
Disponível|Available|Disponible|可用|Доступно
Prévia do tema|Theme preview|Vista previa del tema|主题预览|Предпросмотр темы
Exemplo|Example|Ejemplo|示例|Пример
Nenhum resultado|No results|Sin resultados|没有结果|Нет результатов
Resultados|Results|Resultados|结果|Результаты
Revisar configuração|Review configuration|Revisar configuración|检查配置|Проверить конфигурацию
Confirmar carregamento|Confirm load|Confirmar carga|确认加载|Подтвердить загрузку
Prévia indisponível|Preview unavailable|Vista previa no disponible|无法预览|Предпросмотр недоступен
Alterações|Changes|Cambios|更改|Изменения
Bloqueadas|Blocked|Bloqueadas|已阻止|Заблокировано
Desconhecidas|Unknown|Desconocidas|未知|Неизвестно
Não foi possível confirmar|Could not confirm|No se pudo confirmar|无法确认|Не удалось подтвердить
A prévia mostra apenas as primeiras 100 alterações.|The preview shows only the first 100 changes.|La vista previa muestra solo los primeros 100 cambios.|预览仅显示前 100 项更改。|Предпросмотр показывает только первые 100 изменений.
Mostra alterações sem aplicá-las; a prévia expira em 60 segundos.|Shows changes without applying them; preview expires in 60 seconds.|Muestra cambios sin aplicarlos; la vista previa vence en 60 segundos.|显示更改但不应用；预览在 60 秒后过期。|Показывает изменения без применения; срок действия предпросмотра — 60 секунд.
Aplica a prévia se o arquivo, os ajustes e a política não mudaram.|Applies the preview if the file, settings and policy have not changed.|Aplica la vista previa si el archivo, los ajustes y la política no cambiaron.|如果文件、设置和策略未更改，则应用预览。|Применяет предпросмотр, если файл, настройки и политика не изменились.
PENDENTE|PENDING|PENDIENTE|待实现|ОЖИДАЕТ
Indisponível durante o modo pânico.|Unavailable during panic mode.|No disponible durante el modo pánico.|恐慌模式下不可用。|Недоступно в режиме паники.
Cor/fundo|Color/background|Color/fondo|颜色/背景|Цвет/фон
Branco/cor|White/color|Blanco/color|白色/颜色|Белый/цвет
Contraste baixo em uma combinação.|Low contrast in one combination.|Contraste bajo en una combinación.|其中一种组合对比度较低。|Низкий контраст в одном сочетании.
Contraste adequado nestas combinações.|Adequate contrast in these combinations.|Contraste adecuado en estas combinaciones.|这些组合的对比度足够。|Достаточный контраст в этих сочетаниях.
Pular intro|Skip intro|Saltar intro|跳过开场|Пропустить заставку
Símbolos locais prontos|Local symbols ready|Símbolos locales listos|本地符号已就绪|Локальные символы готовы
Montagem ainda em andamento|Menu is still being built|El menú aún se está preparando|菜单仍在构建|Меню ещё создаётся
Alto contraste|High contrast|Alto contraste|高对比度|Высокая контрастность
Reduzir movimento|Reduce motion|Reducir movimiento|减少动态效果|Уменьшить движение
Pular intro na próxima vez|Skip intro next time|Omitir intro la próxima vez|下次跳过开场|Пропускать заставку в следующий раз
Cor personalizada|Custom color|Color personalizado|自定义颜色|Свой цвет
Aplicar cor personalizada|Apply custom color|Aplicar color personalizado|应用自定义颜色|Применить свой цвет
Prévia da cor|Color preview|Vista previa del color|颜色预览|Предпросмотр цвета
Copiar erros recentes|Copy recent errors|Copiar errores recientes|复制最近错误|Копировать последние ошибки
Nenhuma falha registrada|No recorded errors|No hay errores registrados|没有记录的错误|Нет записанных ошибок
Cópia indisponível ou falhou.|Clipboard unavailable or failed.|Portapapeles no disponible o falló.|剪贴板不可用或复制失败。|Буфер обмена недоступен или произошла ошибка.
Erros copiados.|Errors copied.|Errores copiados.|错误已复制。|Ошибки скопированы.
ATIVO|ON|ACTIVO|开启|ВКЛ
INATIVO|OFF|INACTIVO|关闭|ВЫКЛ
BLOQUEADO|BLOCKED|BLOQUEADO|已阻止|ЗАБЛОКИРОВАНО
API de prompt|Prompt API|API de prompt|交互提示API|API подсказок
Não implementado|Not implemented|No implementado|尚未实现|Не реализовано
Depende do jogo|Game-dependent|Depende del juego|取决于游戏|Зависит от игры
Ligado|On|Activado|开启|Включено
Desligado|Off|Desactivado|关闭|Выключено
Alcance para ignorar obstáculos|Obstacle-ignore range|Alcance para ignorar obstáculos|忽略障碍物距离|Дальность игнорирования препятствий
Transparência em primeira pessoa|First-person transparency|Transparencia en primera persona|第一人称透明度|Прозрачность от первого лица
Intervalo dos três toques|Three-tap interval|Intervalo de tres toques|三次点击间隔|Интервал трёх касаний
Largura da área de retorno|Return area width|Ancho del área de retorno|返回区域宽度|Ширина области возврата
Tempo para retomar a mira|Aim resume delay|Tiempo para reanudar la mira|恢复瞄准延迟|Задержка возобновления прицела
Duração do efeito de acerto|Hit effect duration|Duración del efecto de impacto|命中效果时长|Длительность эффекта попадания
Transparência do efeito|Effect transparency|Transparencia del efecto|效果透明度|Прозрачность эффекта
Distância máxima do saque|Maximum loot distance|Distancia máxima de botín|最大拾取距离|Максимальная дистанция добычи
Intervalo do saque|Loot interval|Intervalo de botín|拾取间隔|Интервал добычи
Intervalo da recarga|Reload interval|Intervalo de recarga|装填间隔|Интервал перезарядки
Valor local de munição|Local ammunition value|Valor local de munición|本地弹药值|Локальное значение боеприпасов
Atraso para renascer|Respawn delay|Retraso para reaparecer|重生延迟|Задержка возрождения
Alcance local da aura|Local aura range|Alcance local del aura|本地光环范围|Локальный радиус ауры
Transparência dos chefes|Boss transparency|Transparencia de jefes|首领透明度|Прозрачность боссов
Transparência das saídas|Exit transparency|Transparencia de salidas|出口透明度|Прозрачность выходов
Número de estrelas|Number of stars|Número de estrellas|星星数量|Количество звёзд
Intensidade da tonalidade|Tint intensity|Intensidad del tono|色调强度|Интенсивность оттенка
Transparência da água|Water transparency|Transparencia del agua|水透明度|Прозрачность воды
Tamanho do painel|Panel text size|Tamaño del texto del panel|面板文字大小|Размер текста панели
Intervalo do painel|Panel interval|Intervalo del panel|面板更新间隔|Интервал панели
Transparência do personagem|Character transparency|Transparencia del personaje|角色透明度|Прозрачность персонажа
Transparência das mãos|Hand transparency|Transparencia de las manos|手部透明度|Прозрачность рук
Transparência do item|Item transparency|Transparencia del objeto|物品透明度|Прозрачность предмета
Ativa|Active|Activa|当前|Активная
Configurações disponíveis|Available configurations|Configuraciones disponibles|可用配置|Доступные конфигурации
Atualizar lista|Refresh list|Actualizar lista|刷新列表|Обновить список
Seleciona um arquivo existente sem carregá-lo.|Selects an existing file without loading it.|Selecciona un archivo existente sin cargarlo.|选择现有文件而不加载。|Выбирает существующий файл без загрузки.
Lista arquivos de configuração disponíveis no executor.|Lists configuration files available in the executor.|Lista archivos de configuración disponibles en el ejecutor.|列出执行器中可用的配置文件。|Показывает доступные файлы конфигурации.
Listagem indisponível neste executor.|Listing is unavailable in this executor.|El listado no está disponible en este ejecutor.|此执行器不支持列出文件。|Список недоступен в этом исполнителе.
Recuperar backup|Restore backup|Recuperar copia|恢复备份|Восстановить резервную копию
Cria uma cópia do backup e a carrega sem alterar os arquivos antigos.|Creates and loads a copy of the backup without changing old files.|Crea y carga una copia sin alterar los archivos antiguos.|创建并加载备份副本，不更改原文件。|Создаёт и загружает копию резервного файла, не изменяя старые файлы.
Não foi possível recuperar o backup.|Could not restore the backup.|No se pudo recuperar la copia.|无法恢复备份。|Не удалось восстановить резервную копию.
Escala do menu|Menu scale|Escala del menú|菜单缩放|Масштаб меню
Ajusta o tamanho do menu, limitado ao espaço disponível na tela.|Adjusts menu size within the available screen space.|Ajusta el tamaño del menú al espacio disponible en pantalla.|调整菜单大小，不超出屏幕空间。|Изменяет размер меню в пределах экрана.
Atualizações do ESP|ESP updates|Actualizaciones del ESP|ESP更新频率|Обновления ESP
Limita a frequência de atualização visual do ESP, radar e busca de saque.|Limits visual updates for ESP, radar and loot search.|Limita las actualizaciones visuales del ESP, radar y búsqueda de botín.|限制ESP、雷达和物品搜索的视觉更新频率。|Ограничивает частоту обновления ESP, радара и поиска добычи.
DIAGNÓSTICO|DIAGNOSTICS|DIAGNÓSTICO|诊断|ДИАГНОСТИКА
Arquivos|Files|Archivos|文件|Файлы
APIs presentes|APIs present|API presentes|API存在|API доступны
APIs ausentes|APIs missing|API ausentes|API缺失|API отсутствуют
Entrada|Input|Entrada|输入|Ввод
Recarga configurada|Reload configured|Recarga configurada|装填已配置|Перезарядка настроена
Saque configurado|Loot configured|Botín configurado|拾取已配置|Добыча настроена
Sim|Yes|Sí|是|Да
Não|No|No|否|Нет
Última falha registrada|Last recorded failure|Último fallo registrado|最近记录的故障|Последняя ошибка
Nenhuma|None|Ninguna|无|Нет
Atualizar diagnóstico|Refresh diagnostics|Actualizar diagnóstico|刷新诊断|Обновить диагностику
Atualiza as capacidades locais e a última falha registrada.|Refreshes local capabilities and the last recorded failure.|Actualiza capacidades locales y el último fallo registrado.|刷新本地功能和最近记录的故障。|Обновляет локальные возможности и последнюю ошибку.
APIs presentes não garantem funcionamento.|API presence does not guarantee functionality.|La presencia de API no garantiza su funcionamiento.|API存在不保证功能正常。|Наличие API не гарантирует работу.
CONFIGURAÇÃO DO MENU|MENU CONFIGURATION|CONFIGURACIÓN DEL MENÚ|菜单设置|НАСТРОЙКИ МЕНЮ
Nome da configuração|Configuration name|Nombre de la configuración|配置名称|Имя конфигурации
Salvar configuração|Save configuration|Guardar configuración|保存配置|Сохранить конфигурацию
Carregar configuração|Load configuration|Cargar configuración|加载配置|Загрузить конфигурацию
Escolha um nome para salvar ou carregar os ajustes do menu.|Choose a name to save or load menu settings.|Elige un nombre para guardar o cargar los ajustes del menú.|选择名称以保存或加载菜单设置。|Выберите имя для сохранения или загрузки настроек меню.
Salva os ajustes atuais e seleciona este arquivo para iniciar.|Saves current settings and selects this file at startup.|Guarda los ajustes actuales y selecciona este archivo al iniciar.|保存当前设置并选择此文件用于启动。|Сохраняет текущие настройки и выбирает файл для запуска.
Carrega os ajustes salvos com este nome.|Loads the settings saved under this name.|Carga los ajustes guardados con este nombre.|加载以此名称保存的设置。|Загружает настройки, сохранённые под этим именем.
Salvo, mas não foi possível selecionar o carregamento inicial.|Saved, but startup loading could not be selected.|Guardado, pero no se pudo seleccionar la carga inicial.|已保存，但无法选择启动加载。|Сохранено, но не удалось выбрать загрузку при запуске.
Carregado, mas não foi possível selecionar o carregamento inicial.|Loaded, but startup loading could not be selected.|Cargado, pero no se pudo seleccionar la carga inicial.|已加载，但无法选择启动加载。|Загружено, но не удалось выбрать загрузку при запуске.
Zoom máximo|Maximum zoom|Zoom máximo|最大缩放|Максимальный зум
Distância de deslocamento|Offset distance|Distancia de desplazamiento|偏移距离|Дистанция смещения
Altura do quadril|Hip height|Altura de cadera|髋部高度|Высота бёдер
Rotação por quadro|Rotation per frame|Rotación por cuadro|每帧旋转|Поворот за кадр
Duração do aviso|Notification duration|Duración del aviso|通知时长|Длительность уведомления
Tamanho dos dados|Target data size|Tamaño de datos del objetivo|目标数据大小|Размер данных цели
Tamanho dos números|Damage number size|Tamaño de números de daño|伤害数字大小|Размер чисел урона
Tamanho da retícula|Reticle size|Tamaño de la retícula|准星大小|Размер прицела
Espessura do círculo|Circle thickness|Grosor del círculo|圆圈粗细|Толщина круга
Duração do rastro|Trail duration|Duración de la estela|轨迹时长|Длительность следа
Número de espaços|Number of slots|Número de espacios|栏位数量|Количество ячеек
Volume|Volume|Volumen|音量|Громкость
Multiplicador|Multiplier|Multiplicador|倍率|Множитель
Velocidade de voo|Flight speed|Velocidad de vuelo|飞行速度|Скорость полёта
Velocidade de subida|Climb speed|Velocidad de subida|攀爬速度|Скорость подъёма
Distância da câmera|Camera distance|Distancia de cámara|相机距离|Дистанция камеры
Intervalo da troca|Swap interval|Intervalo de cambio|切换间隔|Интервал смены
Profundidade da câmera|Camera depth|Profundidad de cámara|相机深度|Глубина камеры
Alcance da trajetória|Trajectory range|Alcance de trayectoria|轨迹距离|Дальность траектории
Duração da marca|Marker duration|Duración de marca|标记时长|Длительность маркера
Brilho|Brightness|Brillo|亮度|Яркость
Suavidade das sombras|Shadow softness|Suavidad de sombras|阴影柔和度|Мягкость теней
Densidade da neblina|Fog density|Densidad de niebla|雾密度|Плотность тумана
Névoa da atmosfera|Atmosphere haze|Bruma atmosférica|大气霾度|Атмосферная дымка
Cobertura das nuvens|Cloud cover|Cobertura de nubes|云层覆盖|Облачность
Intensidade do florescer|Bloom intensity|Intensidad de brillo|泛光强度|Интенсивность свечения
Tamanho do desfoque|Blur size|Tamaño de desenfoque|模糊大小|Размер размытия
Saturação|Saturation|Saturación|饱和度|Насыщенность
Contraste|Contrast|Contraste|对比度|Контрастность
Distância de foco|Focus distance|Distancia de enfoque|焦距|Дистанция фокусировки
Desfoque distante|Far blur|Desenfoque lejano|远处模糊|Дальнее размытие
Intensidade dos raios|Sun ray intensity|Intensidad de rayos solares|阳光强度|Интенсивность солнечных лучей
Dispersão dos raios|Sun ray spread|Dispersión de rayos solares|阳光散布|Рассеивание солнечных лучей
Ajustes específicos ainda indisponíveis.|Specific settings are not available yet.|Los ajustes específicos aún no están disponibles.|具体设置尚不可用。|Специальные настройки пока недоступны.
OCULTAR|HIDE|OCULTAR|隐藏|СКРЫТЬ
Ilimitado|Unlimited|Ilimitado|无限|Безлимит
Expirado|Expired|Expirado|已过期|Истёк
Celular|Mobile|Móvil|手机|Телефон
Console|Console|Consola|主机|Консоль
Servidor local|Local server|Servidor local|本地服务器|Локальный сервер
dias|days|días|天|дн.
Menu|Menu|Menú|菜单|Меню
Cursor|Cursor|Cursor|光标|Курсор
Modo|Mode|Modo|模式|Режим
Intensidade|Intensity|Intensidad|强度|Интенсивность
Distância|Distance|Distancia|距离|Дистанция
Notificar|Notify|Notificar|通知|Уведомлять
Indisponível: implementação pendente.|Unavailable: implementation pending.|No disponible: implementación pendiente.|不可用：功能尚未实现。|Недоступно: реализация ожидается.
VISUAIS|VISUALS|VISUALES|视觉|ВИЗУАЛ
INTERFACE DO JOGO|GAME INTERFACE|INTERFAZ DEL JUEGO|游戏界面|ИНТЕРФЕЙС ИГРЫ
LOCAL|LOCAL|LOCAL|本地|ЛОКАЛЬНО
JOGADOR|PLAYER|JUGADOR|玩家|ИГРОК
MOVIMENTO|MOVEMENT|MOVIMIENTO|移动|ДВИЖЕНИЕ
CÂMERA|CAMERA|CÁMARA|相机|КАМЕРА
SAQUE|LOOT|BOTÍN|战利品|ЛУТ
MÃOS E ARMA|HANDS AND WEAPON|MANOS Y ARMA|手和武器|РУКИ И ОРУЖИЕ
CAMPO DE VISÃO|FIELD OF VIEW|CAMPO DE VISIÓN|视野|УГОЛ ОБЗОРА
Campo de visão|Field of view|Campo de visión|视野|Угол обзора
Visão com zoom|Zoom view|Visión con zoom|缩放视野|Обзор с зумом
Zoom|Zoom|Zoom|缩放|Зум
ANIMAÇÕES|ANIMATIONS|ANIMACIONES|动画|АНИМАЦИИ
Animação|Animation|Animación|动画|Анимация
Velocidade|Speed|Velocidad|速度|Скорость
Peso|Weight|Peso|权重|Вес
Reproduzir|Play|Reproducir|播放|Играть
RECURSOS|FEATURES|RECURSOS|功能|ФУНКЦИИ
COMBATE|COMBAT|COMBATE|战斗|БОЙ
MIRA|AIM|PUNTERÍA|瞄准|ПРИЦЕЛ
Ativação|Activation|Activación|触发|Активация
Suavização|Smoothing|Suavizado|平滑|Сглаживание
ALVOS|TARGETS|OBJETIVOS|目标|ЦЕЛИ
Raio da mira|Aim radius|Radio de puntería|瞄准半径|Радиус прицела
Limite de verificações|Check limit|Límite de verificaciones|检查上限|Лимит проверок
Ponto de mira|Aim point|Punto de mira|瞄准点|Точка прицела
Partes do corpo|Body parts|Partes del cuerpo|身体部位|Части тела
Adicionar amigo|Add friend|Añadir amigo|添加好友|Добавить друга
ESPIADA|PEEK|ASOMARSE|探头|ВЫГЛЯДЫВАНИЕ
CORPO A CORPO|MELEE|CUERPO A CUERPO|近战|БЛИЖНИЙ БОЙ
ARMA|WEAPON|ARMA|武器|ОРУЖИЕ
Manuseio da arma|Weapon handling|Manejo del arma|武器操作|Управление оружием
EFEITOS DE COMBATE|COMBAT EFFECTS|EFECTOS DE COMBATE|战斗特效|БОЕВЫЕ ЭФФЕКТЫ
ANTI AIM|ANTI AIM|ANTI AIM|反瞄准|АНТИ АИМ
GRANADAS|GRENADES|GRANADAS|手雷|ГРАНАТЫ
MUNDO|WORLD|MUNDO|世界|МИР
Cores do terreno|Terrain colors|Colores del terreno|地形颜色|Цвета местности
Folhas|Leaves|Hojas|树叶|Листва
Troncos|Trunks|Troncos|树干|Стволы
Cor da água|Water color|Color del agua|水的颜色|Цвет воды
ILUMINAÇÃO|LIGHTING|ILUMINACIÓN|光照|ОСВЕЩЕНИЕ
EXTRAS|MISC|EXTRAS|杂项|ДОПОЛНИТЕЛЬНО
Atravessar porta|Pass through door|Atravesar puerta|穿过门|Проход через дверь
SONS|SOUNDS|SONIDOS|声音|ЗВУКИ
Adicionar ID de som|Add sound ID|Añadir ID de sonido|添加声音ID|Добавить ID звука
DETECÇÃO|DETECTION|DETECCIÓN|检测|ОБНАРУЖЕНИЕ
ORDENAR DEPÓSITO|SORT STORAGE|ORDENAR ALMACÉN|整理仓库|СОРТИРОВКА СКЛАДА
Por valor|By value|Por valor|按价值|По цене
Por tipo|By type|Por tipo|按类型|По типу
Por nome|By name|Por nombre|按名称|По имени
VER INVENTÁRIO|VIEW INVENTORY|VER INVENTARIO|查看背包|ПРОСМОТР ИНВЕНТАРЯ
Ver inventário|View inventory|Ver inventario|查看背包|Смотреть инвентарь
Mostrar|Show|Mostrar|显示|Показать
BUSCAR SAQUE|LOOTFINDER|BUSCAR BOTÍN|搜索战利品|ПОИСК ЛУТА
Resultados da busca aparecerão aqui.|Search results will appear here.|Los resultados aparecerán aquí.|搜索结果将显示在这里。|Результаты поиска появятся здесь.
SERVIDORES|SERVER|SERVIDORES|服务器|СЕРВЕРЫ
Trocar de servidor|Switch server|Cambiar de servidor|切换服务器|Сменить сервер
SKINS|SKINCHANGER|SKINS|换肤|СКИНЧЕНДЖЕР
MISSÕES|QUESTS|MISIONES|任务|МИССИИ
COMERCIANTES|MERCHANTS|COMERCIANTES|商人|ТОРГОВЦЫ
CONFIGURAÇÕES|SETTINGS|AJUSTES|设置|НАСТРОЙКИ
GERAL|GENERAL|GENERAL|通用|ОБЩЕЕ
Idioma|Language|Idioma|语言|Язык
Tecla do menu|Menu key|Tecla del menú|菜单键|Клавиша меню
Tecla do cursor|Cursor key|Tecla del cursor|光标键|Клавиша курсора
Rever tutorial|Review tutorial|Ver tutorial|重看教程|Повторить обучение
Sair|Exit|Salir|退出|Выход
APARÊNCIA|APPEARANCE|APARIENCIA|外观|ВНЕШНИЙ ВИД
Tema (cores)|Theme (colors)|Tema (colores)|主题(颜色)|Тема (цвета)
Fonte|Font|Fuente|字体|Шрифт
MARCA D'ÁGUA|WATERMARK|MARCA DE AGUA|水印|ВОДЯНОЙ ЗНАК
Ativar|Enable|Activar|启用|Включить
Campos visíveis|Visible fields|Campos visibles|可见字段|Видимые поля
LISTA DE ATALHOS|KEYBIND LIST|LISTA DE ATAJOS|快捷键列表|СПИСОК КЛАВИШ
Exibir|Display|Mostrar|显示方式|Показ
Interface carregada.|Interface loaded.|Interfaz cargada.|界面已加载。|Интерфейс загружен.
Recarga: caminho do RemoteEvent não encontrado na ferramenta.|Reload: RemoteEvent path not found in the tool.|Recarga: no se encontró la ruta del RemoteEvent en la herramienta.|装填：工具中未找到 RemoteEvent 路径。|Перезарядка: путь RemoteEvent не найден в инструменте.
Recarga bloqueada: configure um caminho de RemoteEvent conhecido.|Reload blocked: configure a known RemoteEvent path.|Recarga bloqueada: configura una ruta de RemoteEvent conocida.|装填已阻止：请配置已知的 RemoteEvent 路径。|Перезарядка заблокирована: настройте известный путь RemoteEvent.
Ação interrompida após falha; veja o console.|Action stopped after an error; see the console.|Acción detenida tras un error; consulta la consola.|操作出错后已停止；请查看控制台。|Действие остановлено после ошибки; проверьте консоль.
Proteção de interface indisponível ou falhou; o menu pode ser detectado.|Interface protection unavailable or failed; the menu may be detected.|La protección de la interfaz no está disponible o falló; el menú puede ser detectado.|界面保护不可用或失败；菜单可能被检测到。|Защита интерфейса недоступна или не сработала; меню может быть обнаружено.
Tamanho|Size|Tamaño|大小|Размер
Largura|Width|Anchura|宽度|Ширина
Altura máxima|Max height|Altura máxima|最大高度|Макс. высота
Transp. fundo|Bg. transparency|Transp. fondo|背景透明度|Прозр. фона
Transp. do texto|Text transparency|Transp. del texto|文字透明度|Прозр. текста
Transp. da borda|Border transparency|Transp. del borde|边框透明度|Прозр. границы
Raio dos cantos|Corner radius|Radio de esquinas|圆角半径|Радиус углов
Mochila personalizada|Custom backpack|Mochila personalizada|自定义背包|Свой рюкзак
Mochila|Backpack|Mochila|背包|Рюкзак
Barra rápida|Hotbar|Barra rápida|快捷栏|Панель быстрого доступа
Hack de velocidade|Speed hack|Hack de velocidad|速度修改|Спидхак
Sprint automático|Auto sprint|Sprint automático|自动冲刺|Авто-спринт
Pulos seguidos|Bunny hop|Saltos seguidos|连续跳跃|Серия прыжков
Controle no ar|Air control|Control en el aire|空中控制|Контроль в воздухе
Voar|Fly|Volar|飞行|Полёт
Sem dano de queda|No fall damage|Sin daño por caída|无坠落伤害|Без урона от падения
Sempre no chão|Always grounded|Siempre en el suelo|始终在地面|Всегда на земле
Jesus|Jesus|Jesús|水上行走|Хождение по воде
Aranha|Spider|Araña|蜘蛛攀爬|Паук
Terceira pessoa|Third person|Tercera persona|第三人称|Третье лицо
Câmera livre|Free camera|Cámara libre|自由相机|Свободная камера
Saque automático|Auto loot|Botín automático|自动拾取|Авто-лут
Repetir|Repeat|Repetir|重复|Повтор
Painel do jogador|Player panel|Panel del jugador|玩家面板|Панель игрока
Anti AFK|Anti AFK|Anti AFK|防挂机|Анти АФК
Renascer automático|Auto respawn|Reaparición automática|自动重生|Авто-возрождение
Remover água|Remove water|Quitar agua|移除水|Убрать воду
Não se afogar|No drowning|No ahogarse|不会溺水|Не тонуть
Mapa e navegação|Map and navigation|Mapa y navegación|地图和导航|Карта и навигация
Alvo fixo|Fixed target|Objetivo fijo|固定目标|Фиксированная цель
Previsão|Prediction|Predicción|预测|Упреждение
Pausa inteligente|Smart pause|Pausa inteligente|智能暂停|Умная пауза
FOV dinâmico|Dynamic FOV|FOV dinámico|动态视野|Динамический FOV
Alternativa visível|Visible fallback|Alternativa visible|可见备选|Видимая альтернатива
Mirar em NPCs|Target NPCs|Apuntar a NPCs|瞄准NPC|Целиться в NPC
Ignorar obstáculos na mira|Ignore obstacles when aiming|Ignorar obstáculos al apuntar|瞄准时忽略障碍物|Игнорировать препятствия при прицеливании
Espiada subterrânea|Underground peek|Asomarse bajo tierra|地下探头|Подземное выглядывание
Aura letal|Lethal aura|Aura letal|致命光环|Смертельная аура
Recarga automática|Auto reload|Recarga automática|自动换弹|Авто-перезарядка
Abastecer cargadores|Refill magazines|Rellenar cargadores|补充弹匣|Пополнение магазинов
Mira falsa|Fake aim|Punto de mira falso|假瞄准|Ложный прицел
Retícula|Reticle|Retícula|准星|Сетка прицела
Círculo da mira|Aim circle|Círculo de puntería|瞄准圈|Круг прицела
Rastro personalizado|Custom trail|Rastro personalizado|自定义轨迹|Свой след
Rastros do jogo|Game trails|Rastros del juego|游戏轨迹|Следы игры
Marca de acerto|Hit marker|Marca de impacto|命中标记|Маркер попадания
Números de dano|Damage numbers|Números de daño|伤害数字|Числа урона
Efeitos de acerto|Hit effects|Efectos de impacto|命中特效|Эффекты попадания
Efeitos de eliminação|Kill effects|Efectos de eliminación|击杀特效|Эффекты убийства
Dados do alvo|Target data|Datos del objetivo|目标数据|Данные цели
Só acertos confirmados|Confirmed hits only|Solo impactos confirmados|仅确认命中|Только подтверждённые попадания
Anti aim|Anti aim|Anti aim|反瞄准|Анти аим
Sob o chão|Under the ground|Bajo el suelo|地面之下|Под землёй
Fantasma|Ghost|Fantasma|幽灵|Призрак
Trajetória do arremesso|Throw trajectory|Trayectoria del lanzamiento|投掷轨迹|Траектория броска
Sem tremor|No shake|Sin temblor|无抖动|Без тряски
Sem grama|No grass|Sin hierba|无草地|Без травы
Desativar minas|Disable mines|Desactivar minas|禁用地雷|Отключить мины
Carregar jogadores|Load players|Cargar jugadores|加载玩家|Загрузить игроков
Buscar chefes|Find bosses|Buscar jefes|查找首领|Поиск боссов
Pontos de saída|Exit points|Puntos de salida|撤离点|Точки выхода
Radar|Radar|Radar|雷达|Радар
Troca rápida|Quick swap|Cambio rápido|快速切换|Быстрая смена
Modo pânico|Panic mode|Modo pánico|紧急模式|Режим паники
Remover efeitos|Remove effects|Quitar efectos|移除特效|Убрать эффекты
Avisos de entrada|Join alerts|Avisos de entrada|进入提醒|Уведомления о входе
Criador|Creator|Creador|创作者|Создатель
Testador|Tester|Probador|测试员|Тестер
Moderador|Moderator|Moderador|管理员|Модератор
Trapaceiro|Cheater|Tramposo|作弊者|Читер
Sempre mostrar|Always show|Mostrar siempre|始终显示|Всегда показывать
Cursor livre|Free cursor|Cursor libre|自由光标|Свободный курсор
Ocultar indisponíveis|Hide unavailable|Ocultar no disponibles|隐藏不可用|Скрыть недоступное
Fixar botão móvel|Lock floating button|Fijar botón móvil|固定悬浮按钮|Закрепить кнопку
Cubo|Cube|Cubo|立方体|Куб
Bordas estáticas|Static borders|Bordes estáticos|静态边框|Статичные границы
Fundo|Background|Fondo|背景|Фон
Sombra|Shadow|Sombra|阴影|Тень
Fixar|Pin|Fijar|固定|Закрепить
Destaque próprio|Highlight self|Resaltarme|突出自己|Выделить себя
Abates|Kills|Bajas|击杀|Убийства
Mortes|Deaths|Muertes|死亡|Смерти
Tempo jogado|Time played|Tiempo jugado|游戏时长|Время в игре
Dano recebido|Damage taken|Daño recibido|受到伤害|Полученный урон
ESTATÍSTICAS|STATISTICS|ESTADÍSTICAS|统计|СТАТИСТИКА
SESSÃO|SESSION|SESIÓN|会话|СЕССИЯ
CONTA|ACCOUNT|CUENTA|账号|АККАУНТ
Ping|Ping|Ping|延迟|Пинг
Tempo da sessão|Session time|Tiempo de sesión|会话时长|Время сессии
Jogadores|Players|Jugadores|玩家数|Игроки
Dispositivo|Device|Dispositivo|设备|Устройство
Resolução|Resolution|Resolución|分辨率|Разрешение
Idade da conta|Account age|Edad de la cuenta|账号年龄|Возраст аккаунта
ID do usuário|User ID|ID de usuario|用户ID|ID пользователя
Execuções|Executions|Ejecuciones|执行次数|Запуски
Acesso|Access|Acceso|权限|Доступ
Tempo restante|Time left|Tiempo restante|剩余时间|Осталось времени
Versão do script|Script version|Versión del script|脚本版本|Версия скрипта
ID do mapa|Map ID|ID del mapa|地图ID|ID карты
Versão do mapa|Map version|Versión del mapa|地图版本|Версия карты
ID do servidor|Server ID|ID del servidor|服务器ID|ID сервера
Sempre|Always|Siempre|始终|Всегда
Ao segurar|While holding|Al mantener|按住时|При удержании
Alternar|Toggle|Alternar|切换|Переключить
Padrão|Default|Predeterminado|默认|По умолчанию
Silencioso|Silent|Silencioso|静默|Тихий
Agressivo|Aggressive|Agresivo|激进|Агрессивный
Ao mirar|On aim|Al apuntar|瞄准时|При прицеливании
Partes selecionadas|Selected parts|Partes seleccionadas|选定部位|Выбранные части
Mais próximo|Closest|Más cercano|最近|Ближайший
Cabeça|Head|Cabeza|头部|Голова
Corpo|Body|Cuerpo|身体|Тело
Braços|Arms|Brazos|手臂|Руки
Pernas|Legs|Piernas|腿部|Ноги
Todos|All|Todos|全部|Все
Nome|Name|Nombre|名称|Имя
Hora|Time|Hora|时间|Время
Mostrar tudo|Show all|Mostrar todo|显示全部|Показать всё
Ocultar|Hide|Ocultar|隐藏|Скрыть
Jogador|Player|Jugador|玩家|Игрок
Recipiente|Container|Contenedor|容器|Контейнер
Item no chão|Item on ground|Objeto en el suelo|地上物品|Предмет на земле
Itens de missão|Quest items|Objetos de misión|任务物品|Предметы заданий
Aura|Aura|Aura|光环|Аура
Círculo de salto|Jump circle|Círculo de salto|跳跃圈|Круг прыжка
Auréola|Halo|Aureola|光晕|Нимб
Rastro estelar|Star trail|Rastro estelar|星光轨迹|Звёздный след
Deslocamento|Offset|Desplazamiento|偏移|Смещение
Trocar personagem|Swap character|Cambiar personaje|更换角色|Сменить персонажа
Personagem|Character|Personaje|角色|Персонаж
Corpo em 1ª pessoa|First-person body|Cuerpo en 1ª persona|第一人称身体|Тело от первого лица
Mãos|Hands|Manos|双手|Руки
Item na mão|Held item|Objeto en mano|手持物品|Предмет в руке
Luz|Light|Luz|光|Свет
Hora e sol|Time and sun|Hora y sol|时间和太阳|Время и солнце
Sombras|Shadows|Sombras|阴影|Тени
Renderização|Rendering|Renderizado|渲染|Рендеринг
Neblina|Fog|Niebla|雾|Туман
Atmosfera|Atmosphere|Atmósfera|大气|Атмосфера
Céu|Sky|Cielo|天空|Небо
Nuvens|Clouds|Nubes|云|Облака
Florescer|Bloom|Resplandor|泛光|Свечение
Desfoque|Blur|Desenfoque|模糊|Размытие
Ajuste de cor|Color correction|Ajuste de color|色彩校正|Цветокоррекция
Profundidade|Depth|Profundidad|景深|Глубина
Raios de sol|Sun rays|Rayos de sol|阳光射线|Лучи солнца
Tonalidade|Tint|Tonalidad|色调|Оттенок
Jump|Jump|Salto|跳跃|Прыжок
Pegadas|Footsteps|Pasos|脚步声|Шаги
Pouso|Landing|Aterrizaje|落地|Приземление
Capacete|Helmet|Casco|头盔|Шлем
Tiro na cabeça|Headshot|Disparo a la cabeza|爆头|Выстрел в голову
Tiro no corpo|Body shot|Disparo al cuerpo|命中身体|Выстрел в тело
Abate|Kill|Baja|击杀|Убийство
Disparo|Shot|Disparo|射击|Выстрел
Acerto com sangue|Blood hit|Impacto con sangre|流血命中|Попадание с кровью
Histórico|History|Historial|历史|История
Filtros|Filters|Filtros|筛选|Фильтры
Atualizar|Refresh|Actualizar|刷新|Обновить
Buscar mapa, nome ou ID do servidor|Search map, name or server ID|Buscar mapa, nombre o ID del servidor|搜索地图、名称或服务器ID|Поиск по карте, имени или ID сервера
Ordenar|Sort|Ordenar|排序|Сортировка
Servidor|Server|Servidor|服务器|Сервер
Detalhes|Details|Detalles|详情|Детали
Entrar|Join|Unirse|加入|Войти
Pronto para entrar|Ready to join|Listo para unirse|可以加入|Готов к входу
Carregando servidores...|Loading servers...|Cargando servidores...|正在加载服务器...|Загрузка серверов...
Nenhum servidor encontrado|No servers found|No se encontraron servidores|未找到服务器|Серверы не найдены
Ocultar cheios|Hide full|Ocultar llenos|隐藏已满|Скрыть полные
Ocultar meu servidor|Hide my server|Ocultar mi servidor|隐藏我的服务器|Скрыть мой сервер
Copiar ID|Copy ID|Copiar ID|复制ID|Копировать ID
Seu servidor|Your server|Tu servidor|你的服务器|Ваш сервер
Histórico vazio|History is empty|Historial vacío|历史为空|История пуста
Entrando no servidor...|Joining server...|Uniéndose al servidor...|正在加入服务器...|Вход на сервер...
Falha ao carregar a lista|Could not load the list|No se pudo cargar la lista|无法加载列表|Не удалось загрузить список
servidores|servers|servidores|服务器|серверов
Mais vagos primeiro|Emptiest first|Más vacíos primero|空闲优先|Сначала пустые
Cor do tema|Theme color|Color del tema|主题颜色|Цвет темы
HOME|HOME|INICIO|首页|ГЛАВНАЯ
Grama|Grass|Hierba|草地|Трава
Areia|Sand|Arena|沙子|Песок
Rocha|Rock|Roca|岩石|Камень
Terra|Dirt|Tierra|泥土|Земля
Cor das folhas|Leaf color|Color de las hojas|树叶颜色|Цвет листьев
Cor dos troncos|Trunk color|Color de los troncos|树干颜色|Цвет стволов
Transparência|Transparency|Transparencia|透明度|Прозрачность
Recurso exclusivo VIP.|VIP-only feature.|Función exclusiva VIP.|仅限VIP功能。|Только для VIP.
Lista de atalhos|Keybind list|Lista de atajos|快捷键列表|Список клавиш
Ilha de FPS|FPS island|Isla de FPS|FPS 灵动岛|Остров FPS
Toque para abrir|Tap to open|Toca para abrir|点击打开|Нажмите, чтобы открыть
Sessão|Session|Sesión|会话|Сессия
Idioma alterado|Language changed|Idioma cambiado|语言已更改|Язык изменён
Atalhos|Keybinds|Atajos|快捷键|Горячие клавиши
PRÉ-VISUALIZAÇÃO|PREVIEW|VISTA PREVIA|预览|ПРЕДПРОСМОТР
CONFIGURAÇÕES DO JOGADOR|PLAYER SETTINGS|AJUSTES DEL JUGADOR|玩家设置|НАСТРОЙКИ ИГРОКА
CONFIGURAÇÕES DO NPC|NPC SETTINGS|AJUSTES DE NPC|NPC设置|НАСТРОЙКИ NPC
CONFIGURAÇÕES DO CORPO|CORPSE SETTINGS|AJUSTES DEL CUERPO|尸体设置|НАСТРОЙКИ ТЕЛА
Destaque|Highlight|Resaltado|高亮|Подсветка
Caixa|Box|Caja|方框|Бокс
Barra de vida|Health Bar|Barra de vida|血条|Полоса здоровья
Vida|Health|Vida|生命值|Здоровье
Linhas|Tracers|Líneas|射线|Линии
Linhas até alvos|Lines to targets|Líneas a objetivos|目标连线|Линии до целей
SEGURANÇA|SECURITY|SEGURIDAD|安全|БЕЗОПАСНОСТЬ
Modo pânico|Panic mode|Modo pánico|紧急模式|Режим паники
Tecla de pânico|Panic key|Tecla de pánico|紧急键|Клавиша паники
Só detalhes de perto|Details only when close|Detalles solo de cerca|仅近处显示细节|Детали только вблизи
Detalhes até|Details up to|Detalles hasta|细节距离|Детали до
Destacar mais próximo|Highlight nearest|Resaltar el más cercano|突出最近目标|Выделять ближайшего
Mostrar NPCs|Show NPCs|Mostrar NPCs|显示NPC|Показывать NPC
Alcance|Range|Alcance|范围|Дальность
Tamanho|Size|Tamaño|大小|Размер
FILTROS|FILTERS|FILTROS|筛选|ФИЛЬТРЫ
RESULTADOS|RESULTS|RESULTADOS|结果|РЕЗУЛЬТАТЫ
Raridade|Rarity|Rareza|稀有度|Редкость
Buscar por nome|Search by name|Buscar por nombre|按名称搜索|Поиск по имени
Marcar na tela|Mark on screen|Marcar en pantalla|屏幕标记|Метки на экране
Buscar agora|Search now|Buscar ahora|立即搜索|Искать сейчас
Toque em Buscar agora para listar o saque por perto.|Tap Search now to list nearby loot.|Toca Buscar ahora para listar el botín cercano.|点击立即搜索列出附近战利品。|Нажмите «Искать сейчас», чтобы увидеть лут рядом.
PERFIS|PROFILES|PERFILES|配置文件|ПРОФИЛИ
Perfil|Profile|Perfil|配置|Профиль
Nome do perfil|Profile name|Nombre del perfil|配置名称|Имя профиля
Salvar perfil|Save profile|Guardar perfil|保存配置|Сохранить профиль
Carregar perfil|Load profile|Cargar perfil|加载配置|Загрузить профиль
Apagar perfil|Delete profile|Borrar perfil|删除配置|Удалить профиль
Salvar automaticamente|Auto-save|Guardar automáticamente|自动保存|Автосохранение
Carregar ao iniciar|Load on start|Cargar al iniciar|启动时加载|Загружать при запуске
Exportar perfil (copiar)|Export profile (copy)|Exportar perfil (copiar)|导出配置(复制)|Экспорт профиля (копия)
Código para importar|Code to import|Código para importar|导入代码|Код для импорта
Importar código|Import code|Importar código|导入代码|Импортировать код
Resetar tudo|Reset all|Restablecer todo|全部重置|Сбросить всё
Fixar na tela|Pin to screen|Fijar en pantalla|固定到屏幕|Закрепить на экране
Desafixar|Unpin|Desfijar|取消固定|Открепить
Toque de novo para apagar|Tap again to delete|Toca de nuevo para borrar|再次点击删除|Нажмите ещё раз для удаления
Toque de novo para resetar|Tap again to reset|Toca de nuevo para restablecer|再次点击重置|Нажмите ещё раз для сброса
Perfil não encontrado|Profile not found|Perfil no encontrado|未找到配置|Профиль не найден
Esqueleto|Skeleton|Esqueleto|骨骼|Скелет
Rastro ao ativar|Activation trail|Rastro al activar|激活拖尾|Шлейф при включении
Animação do menu|Menu animation|Animación del menú|菜单动画|Анимация меню
TOQUE: ALTERNAR · SEGURE: O QUE É|TAP: TOGGLE · HOLD: WHAT IT IS|TOQUE: ACTIVAR · MANTÉN: QUÉ ES|点击:切换 · 长按:说明|НАЖАТЬ: ВКЛ · УДЕРЖАТЬ: ОПИСАНИЕ
ATIVO|ON|ACTIVO|开启|ВКЛ
INATIVO|OFF|INACTIVO|关闭|ВЫКЛ
Toque para ativar ou desativar.|Tap to turn on or off.|Toca para activar o desactivar.|点击开启或关闭。|Нажмите, чтобы включить или выключить.
Configurações gerais|General Settings|Ajustes generales|通用设置|Общие настройки
Cor|Color|Color|颜色|Цвет
Espessura|Thickness|Grosor|粗细|Толщина
Opacidade|Opacity|Opacidad|不透明度|Непрозрачность
Distância máx.|Max distance|Distancia máx.|最大距离|Макс. дистанция
Tamanho do texto|Text size|Tamaño del texto|文字大小|Размер текста
TOQUE NA LINHA: ALTERNAR|TAP A ROW: TOGGLE|TOCA UNA FILA: ALTERNAR|点击一行：开关|НАЖМИТЕ НА СТРОКУ: ВКЛ/ВЫКЛ
TOQUE NO ÍCONE: AJUSTES|TAP THE ICON: SETTINGS|TOCA EL ICONO: AJUSTES|点击图标：设置|НАЖМИТЕ НА ЗНАЧОК: НАСТРОЙКИ
Cantos|Corners|Esquinas|边角|Углы
Completa|Full|Completa|完整|Полная
Esquerda|Left|Izquierda|左|Слева
Direita|Right|Derecha|右|Справа
Baixo|Bottom|Abajo|底部|Снизу
Cima|Top|Arriba|顶部|Сверху
Estilo|Style|Estilo|样式|Стиль
Origem|Origin|Origen|起点|Начало
Posição|Position|Posición|位置|Позиция
Cor automática|Auto color|Color automático|自动颜色|Авто-цвет
Contorno|Outline|Contorno|轮廓|Контур
Preenchimento|Fill|Relleno|填充|Заливка
Unidade|Unit|Unidad|单位|Единица
Distância da prévia|Preview distance|Distancia de la vista|预览距离|Дистанция превью
Vida da prévia|Preview health|Vida de la vista|预览生命|Здоровье превью
Fora do alcance|Out of range|Fuera de alcance|超出范围|Вне зоны
Tamanho do canto|Corner size|Tamaño de esquina|边角大小|Размер угла
Largura da barra|Bar width|Ancho de barra|血条宽度|Ширина полосы
Em breve|Coming soon|Próximamente|即将推出|Скоро
Pressione a tecla do menu para abrir ou fechar.|Press the menu key to open or close.|Pulsa la tecla del menú para abrir o cerrar.|按菜单键打开或关闭。|Нажмите клавишу меню, чтобы открыть или закрыть.
Toque no botão flutuante para abrir o menu.|Tap the floating button to open the menu.|Toca el botón flotante para abrir el menú.|点击悬浮按钮打开菜单。|Нажмите на плавающую кнопку, чтобы открыть меню.
]==]
    for line in string.gmatch(RAW, "[^\n]+") do
        local p = string.split(line, "|")
        if #p >= 5 then DICT[p[1]] = { en = p[2], es = p[3], zh = p[4], ru = p[5] } end
    end
end
local currentLang = "pt"
local notify = function(text) pcall(function() Library:Notify({ Title = "BBC HUB", Content = text, Duration = 2 }) end) end
local keys = { menu = "RightShift", cursor = "LeftAlt", zoom = "N" }
local refreshPanels = function() end
local LANG_FILE = "BBC_HUB/idioma.txt"
pcall(function()
    if type(isfile) == "function" and isfile(LANG_FILE) then
        local c = string.gsub(readfile(LANG_FILE), "%s", "")
        if LANG_NAMES[c] then currentLang = c end
    end
end)
local function tr(text)
    if currentLang == "pt" then return text end
    local e = DICT[text]
    return e and e[currentLang] or text
end
Library.Tr = tr
-- descrição das opções no idioma atual (TIPS guarda os 5 idiomas)
Library.Internal.tipFor = function(name)
    local e = Library.Internal.tips[name]
    if not e then return nil end
    if type(e) == "string" then return e end
    return e[currentLang] or e.pt
end
Library.Internal.setTipResolver(Library.Internal.tipFor)
-- textos de dica soltos (passados direto como Tooltip) também nos 5 idiomas
local TIPX = {}
local tipText = function(s)
    local e = TIPX[s]
    if not e then return s end
    return e[currentLang] or s
end
for k, v in pairs({
    ["Longe, mostra só um ponto e a distância. Perto, mostra tudo."] = {
        en = "Far away shows only a dot and the distance. Close up, shows everything.",
        es = "Lejos muestra solo un punto y la distancia. De cerca, muestra todo.",
        zh = "远处只显示一个点和距离；近处显示全部。",
        ru = "Вдали показывает только точку и дистанцию. Вблизи — всё." },
    ["O alvo mais perto de você ganha outra cor."] = {
        en = "The closest target is shown in a different color.",
        es = "El objetivo más cercano aparece con otro color.",
        zh = "最近的目标以不同颜色显示。",
        ru = "Ближайшая цель отображается другим цветом." },
    ["Mini mapa redondo com os jogadores ao redor. Arraste para mover."] = {
        en = "Round mini map with players around you. Drag to move.",
        es = "Minimapa redondo con los jugadores alrededor. Arrástralo para moverlo.",
        zh = "显示周围玩家的圆形小地图，可拖动移动。",
        ru = "Круглая миникарта с игроками вокруг. Перетащите, чтобы двигать." },
    ["Mostra o nome e a distância dos itens encontrados direto no jogo, na cor da raridade."] = {
        en = "Shows the name and distance of found items right in the game, in the rarity color.",
        es = "Muestra el nombre y la distancia de los objetos encontrados en el juego, con el color de la rareza.",
        zh = "在游戏中直接显示找到物品的名称和距离，使用稀有度颜色。",
        ru = "Показывает имя и дистанцию найденных предметов прямо в игре, цветом редкости." },
    ["Esconde menu, ESP, radar e botões fixos de uma vez. Para voltar, toque 3 vezes no topo da tela (ou use a tecla de pânico)."] = {
        en = "Hides menu, ESP, radar and pinned buttons at once. To return, tap the top of the screen 3 times (or use the panic key).",
        es = "Oculta menú, ESP, radar y botones fijos de una vez. Para volver, toca 3 veces la parte superior de la pantalla (o usa la tecla de pánico).",
        zh = "一次性隐藏菜单、ESP、雷达和固定按钮。要恢复，点击屏幕顶部 3 次（或使用恐慌键）。",
        ru = "Сразу скрывает меню, ESP, радар и закреплённые кнопки. Чтобы вернуться, коснитесь верха экрана 3 раза (или используйте клавишу паники)." },
    ["Mostra um rastro de luz na cor do menu quando você ativa uma opção."] = {
        en = "Shows a light trail in the menu color when you enable an option.",
        es = "Muestra un rastro de luz del color del menú al activar una opción.",
        zh = "启用选项时显示菜单颜色的光轨。",
        ru = "Показывает светящийся след цвета меню при включении опции." },
    ["Abre e fecha o menu com um efeito suave."] = {
        en = "Opens and closes the menu with a smooth effect.",
        es = "Abre y cierra el menú con un efecto suave.",
        zh = "以平滑效果打开和关闭菜单。",
        ru = "Плавно открывает и закрывает меню." },
}) do TIPX[k] = v end
local function trKey(text)
    text = string.gsub(text, "&apos;", "'")
    text = string.gsub(text, "&amp;", "&")
    return text
end
local function translateInstance(inst)
    if not (inst:IsA("TextLabel") or inst:IsA("TextButton")) then return end
    local cur = inst.Text
    local orig, last = inst:GetAttribute("pt"), inst:GetAttribute("tx")
    if orig ~= nil and cur ~= last then orig = nil end
    if orig == nil then
        local key = trKey(cur)
        if DICT[key] then orig = key else return end
    end
    local t = tr(orig)
    inst:SetAttribute("pt", orig)
    inst:SetAttribute("tx", t)
    if cur ~= t then inst.Text = t end
end
local onLanguageChanged = {}
local function setLanguage(code, silent)
    if not LANG_NAMES[code] or code == currentLang then return end
    currentLang = code
    pcall(function()
        if type(writefile) == "function" then
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
            writefile(LANG_FILE, code)
        end
    end)
    for _, fn in ipairs(onLanguageChanged) do pcall(fn) end
    if Library._hubWindow then
        if Library._hubWindow._refreshSearchLanguage then Library._hubWindow._refreshSearchLanguage() end
        Library._hubWindow:_filter(Library._hubWindow._filterQuery)
    end
end

local Config = (function()
    local ok, cfg = pcall(function() return type(getgenv) == "function" and getgenv().BBC_CONFIG end)
    return ok and type(cfg) == "table" and cfg or {}
end)()
Library.Access = Config.Access or "FREE"
-- Opcional, antes de carregar:  getgenv().BBC_CONFIG = { Access = "VIP", Expiry = os.time() + 12*3600, Version = "0.0.8.2" }
-- Preferências somente visuais, lidas antes da intro. Nunca aplicam opções de jogo.
Library.Appearance = { theme = "Orange", color = {1, 130 / 255, 25 / 255}, contrast = false, motion = false, skipIntro = false, writable = true }
do
    local A = Library.Appearance
    local path = "BBC_HUB/appearance.json"
    A.colorListeners = {}
    local function validColor(t)
        if type(t) ~= "table" or #t ~= 3 then return false end
        for k, v in pairs(t) do
            if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > 3 or type(v) ~= "number" or v ~= v or v < 0 or v > 1 then return false end
        end
        return true
    end
    local function valid(data)
        if type(data) ~= "table" then return false end
        local allowed = { theme = true, color = true, contrast = true, motion = true, skipIntro = true, v = true }
        for k in pairs(data) do if not allowed[k] then return false end end
        if data.v ~= 1 or type(data.theme) ~= "string" or (data.theme ~= "Custom" and not Library.ThemePresets[data.theme]) then return false end
        return validColor(data.color) and type(data.contrast) == "boolean" and type(data.motion) == "boolean" and type(data.skipIntro) == "boolean"
    end
    function A:load()
        if type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
        local ok, exists = pcall(isfile, path)
        if not ok then self.writable = false; return false end
        if not exists then return false end
        local readOK, raw = pcall(readfile, path)
        local parseOK, data = false, nil
        if readOK and type(raw) == "string" and #raw <= 8192 then parseOK, data = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end) end
        if not parseOK or not valid(data) then
            self.writable = false
            warn("[BBC] Preferências visuais inválidas; arquivo preservado.")
            return false
        end
        self.theme, self.color, self.contrast, self.motion, self.skipIntro = data.theme, data.color, data.contrast, data.motion, data.skipIntro
        return true
    end
    function A:save()
        if not self.writable or type(writefile) ~= "function" or type(readfile) ~= "function" or type(isfile) ~= "function" then return false end
        local data = { v = 1, theme = self.theme, color = self.color, contrast = self.contrast, motion = self.motion, skipIntro = self.skipIntro }
        if not valid(data) then return false end
        local ok, err = pcall(function()
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
            if isfile(path) then
                local previous = readfile(path)
                assert(type(previous) == "string" and #previous <= 8192, "preferências visuais inválidas")
                local decoded = game:GetService("HttpService"):JSONDecode(previous)
                assert(valid(decoded), "preferências visuais inválidas")
                writefile(path .. ".bak", previous)
            end
            writefile(path, game:GetService("HttpService"):JSONEncode(data))
        end)
        if not ok then
            warn("[BBC] Falha ao salvar aparência: " .. tostring(err))
            if Library.Diagnostics then Library.Diagnostics:record("aparência", err) end
        end
        return ok
    end
    function A:applyTheme()
        local base = self.theme == "Custom" and Library.MakeTheme(Color3.new(self.color[1], self.color[2], self.color[3]), "neutral") or Library.ThemePresets[self.theme]
        if not base then return false end
        Library.ThemeName = self.theme
        for k, v in pairs(base) do Library.Theme[k] = v end
        if self.contrast then
            Library.Theme.Background = Color3.fromRGB(0, 0, 0)
            Library.Theme.Surface = Color3.fromRGB(15, 15, 15)
            Library.Theme.Surface2 = Color3.fromRGB(30, 30, 30)
            Library.Theme.Surface3 = Color3.fromRGB(46, 46, 46)
            Library.Theme.Stroke = Color3.fromRGB(145, 145, 145)
            Library.Theme.Text = Color3.fromRGB(255, 255, 255)
            Library.Theme.Muted = Color3.fromRGB(210, 210, 210)
        end
        for i = #Library._bindings, 1, -1 do
            local b = Library._bindings[i]
            if b[1] and b[1].Parent then pcall(function() b[1][b[2]] = b[3]() end) else table.remove(Library._bindings, i) end
        end
        for _, fn in ipairs(Library._themeListeners) do pcall(fn) end
        return true
    end
    function Library:SetTheme(name, noSave)
        if type(name) ~= "string" or (name ~= "Custom" and not self.ThemePresets[name]) then return false end
        A.theme = name
        A:applyTheme()
        if not noSave then A:save() end
        return true
    end
    function A:setColor(t, noSave)
        if not validColor(t) then return false end
        self.color = {t[1], t[2], t[3]}
        for _, fn in ipairs(self.colorListeners) do pcall(fn, self.color) end
        if self.theme == "Custom" then self:applyTheme() end
        if not noSave then self:save() end
        return true
    end
    function A:setFlag(key, value, noSave)
        if (key ~= "contrast" and key ~= "motion" and key ~= "skipIntro") or type(value) ~= "boolean" then return false end
        self[key] = value
        Library.ReduceMotion = self.motion
        if key == "contrast" then self:applyTheme() end
        if not noSave then self:save() end
        return true
    end
    A:load()
    Library.ReduceMotion = A.motion
    A:applyTheme()
    -- Chaves estáveis incluem aparência na configuração do menu. O arquivo
    -- separado é apenas o espelho visual para a próxima intro.
    Library.Registry["__appearance/color"] = { name = "Cor personalizada", get = function() return {A.color[1], A.color[2], A.color[3]} end, set = function(v) return A:setColor(v) end, validate = validColor }
    Library.Registry["__appearance/theme"] = { name = "Tema", get = function() return A.theme end, set = function(v) return Library:SetTheme(v) end,
        validate = function(v) return type(v) == "string" and (v == "Custom" or Library.ThemePresets[v] ~= nil) end }
end
-- Diagnóstico local limitado; não detecta anticheat e não testa APIs do executor.
Library.Diagnostics = { recent = {}, MAX = 8 }
function Library.Diagnostics:record(context, detail)
    local message = string.sub(tostring(context or "evento"), 1, 40) .. ": " .. string.sub(tostring(detail or "erro"), 1, 120)
    self.recent[#self.recent + 1] = message
    while #self.recent > self.MAX do table.remove(self.recent, 1) end
end
function Library.Diagnostics:last()
    return self.recent[#self.recent]
end
-- Média móvel aproximada do tempo gasto no callback do motor visual; não mede GPU.
function Library.Diagnostics:sampleEngine(seconds)
    if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 or seconds == math.huge then return end
    local sample = math.min(seconds * 1000, 60000)
    local m = self.engine or { count = 0, average = 0, last = 0 }
    m.count = math.min(m.count + 1, 60)
    m.average += (sample - m.average) / m.count
    m.last = sample
    self.engine = m
end
-- Calcula a escala sem exceder os limites da tela. Valores inválidos usam padrão.
function Library.fitScale(width, height, windowWidth, windowHeight, factor)
    local function positiveFinite(n) return type(n) == "number" and n == n and n > 0 and n < math.huge end
    if not positiveFinite(width) or not positiveFinite(height) or not positiveFinite(windowWidth) or not positiveFinite(windowHeight) then return nil end
    if type(factor) ~= "number" or factor ~= factor or factor == math.huge or factor == -math.huge then factor = 1 end
    factor = math.clamp(factor, 0.7, 1.3)
    local ceiling = math.min(width * 0.96 / windowWidth, height * 0.96 / windowHeight, 1.5)
    local base = math.min(width * 0.8 / windowWidth, height * 0.92 / windowHeight, 1.3)
    return math.min(base * factor, ceiling)
end

-- Caminhada incremental: não materializa todos os descendentes num único array.
-- O chamador registra os eventos antes de iniciar e valida objetos que saíram.
Library.StreamScan = {}
function Library.StreamScan.run(root, alive, visit, yieldEvery)
    local stack, processed = { root }, 0
    yieldEvery = math.clamp(tonumber(yieldEvery) or 200, 1, 1000)
    while #stack > 0 and alive() do
        local node = table.remove(stack)
        if node ~= root then
            local ok, err = pcall(visit, node)
            if not ok and Library.Diagnostics then Library.Diagnostics:record("varredura", err) end
        end
        local ok, children = pcall(function() return node:GetChildren() end)
        if ok and type(children) == "table" then
            for i, child in ipairs(children) do
                if not alive() then return end
                stack[#stack + 1] = child
                if i % yieldEvery == 0 then task.wait() end
            end
        elseif not ok and Library.Diagnostics then
            Library.Diagnostics:record("varredura", children)
        end
        processed += 1
        if processed % yieldEvery == 0 then task.wait() end
    end
end
function Library.StreamScan.start(root, alive, visit)
    task.spawn(function() Library.StreamScan.run(root, alive, visit) end)
end
-- Controles rastreados apenas para interrupção por pânico, erro ou respawn.
-- Não há bloqueio preventivo automático nem detecção de anticheat.
Library.Safety = {
    blocked = {
        ["MIRA"] = true, ["Hack de velocidade"] = true, ["Sprint automático"] = true,
        ["Pulos seguidos"] = true, ["Controle no ar"] = true, ["Voar"] = true,
        ["Sem dano de queda"] = true, ["Sempre no chão"] = true, ["Jesus"] = true,
        ["Aranha"] = true, ["Não se afogar"] = true, ["Renascer automático"] = true, ["Anti AFK"] = true,
        ["Saque automático"] = true, ["Atravessar porta"] = true,
        ["Deslocamento"] = true, ["Troca rápida"] = true, ["Carregar jogadores"] = true,
        ["Desativar minas"] = true, ["Sem grama"] = true, ["Remover efeitos"] = true,
        ["Aura letal"] = true, ["Espiada subterrânea"] = true, ["Anti aim"] = true,
        ["Sob o chão"] = true, ["Recarga automática"] = true, ["Abastecer cargadores"] = true,
        ["Trajetória do arremesso"] = true,
    },
    controls = {},
    stoppers = {},
}
function Library.Safety:allow(name, value)
    if value ~= true then return true end
    return not (self.panic and self.blocked[name])
end
function Library.Safety:track(name, control)
    self.controls[#self.controls + 1] = { name = name, control = control }
end
function Library.Safety:disable(name)
    for _, item in ipairs(self.controls) do
        if item.name == name then
            pcall(function() if item.control:Get() then item.control:Set(false) end end)
        end
    end
end
function Library.Safety:trackStopper(callback)
    assert(type(callback) == "function", "stopper inválido")
    self.stoppers[#self.stoppers + 1] = callback
end
function Library.Safety:disableTracked()
    for _, item in ipairs(self.controls) do
        if self.blocked[item.name] then
            pcall(function() if item.control:Get() then item.control:Set(false) end end)
        end
    end
    for _, stop in ipairs(self.stoppers) do pcall(stop) end
end
-- Impede reativação durante pânico e chamadas após encerramento. Não bloqueia
-- ações durante uso normal; dados por jogo continuam sujeitos à validação.
function Library.Safety:guardActions(actions, isAlive)
    for name, callback in pairs(actions) do
        if self.blocked[name] and type(callback) == "function" then
            actions[name] = function(value, ...)
                if type(value) ~= "boolean" or not isAlive() or not self:allow(name, value) then return false end
                return callback(value, ...)
            end
        end
    end
end
-- Proteção de eventos locais: erros consecutivos interrompem só a conexão
-- defeituosa. O chamador controla a vida útil e o aviso ao usuário.
Library.Guards = {}
function Library.Guards.connect(signal, callback, alive, report, limit)
    assert(type(callback) == "function", "callback inválido")
    limit = math.max(1, math.min(tonumber(limit) or 5, 20))
    local failures, connection = 0, nil
    connection = signal:Connect(function(...)
        if not alive() then return end
        local ok, err = pcall(callback, ...)
        if ok then failures = 0; return end
        failures += 1
        if failures == 1 then pcall(report, "erro", tostring(err)) end
        if failures >= limit then
            if connection then pcall(function() connection:Disconnect() end) end
            pcall(report, "interrompido", tostring(err))
        end
    end)
    return connection
end

-- Passo de laço periódico. Um sucesso zera a contagem de falhas consecutivas.
function Library.Guards.step(state, callback, report, limit)
    if state.stopped then return false end
    limit = math.max(1, math.min(tonumber(limit) or 5, 20))
    local ok, err = pcall(callback)
    if ok then state.failures = 0; return true end
    state.failures = (state.failures or 0) + 1
    if state.failures == 1 then pcall(report, "erro", tostring(err)) end
    if state.failures >= limit then
        state.stopped = true
        pcall(report, "interrompido", tostring(err))
        return false
    end
    return true
end
-- Validação de perfis não confiáveis antes de chamar callbacks do menu.
-- Não protege contra um executor ou cliente comprometido.
Library.ProfileGuard = { MAX_BYTES = 256 * 1024, MAX_NODES = 20000, MAX_DEPTH = 8, MAX_STRING = 4096 }

function Library.ProfileGuard:validateTree(root)
    local seen, nodes = {}, 0
    local function walk(value, depth)
        nodes += 1
        if nodes > self.MAX_NODES or depth > self.MAX_DEPTH then return false end
        local kind = type(value)
        if kind == "boolean" then return true end
        if kind == "number" then return value == value and value ~= math.huge and value ~= -math.huge end
        if kind == "string" then return #value <= self.MAX_STRING end
        if kind ~= "table" or seen[value] then return false end
        seen[value] = true
        for key, item in pairs(value) do
            local kt = type(key)
            if kt ~= "string" and kt ~= "number" then return false end
            if kt == "string" and #key > 512 then return false end
            if kt == "number" and (key ~= key or key == math.huge or key == -math.huge) then return false end
            if not walk(item, depth + 1) then return false end
        end
        seen[value] = nil
        return true
    end
    return type(root) == "table" and walk(root, 0)
end

function Library.ProfileGuard:prepare(decoded, registry, blocked)
    if not self:validateTree(decoded) then return nil, "perfil inválido ou excede os limites" end
    local data = decoded
    if decoded.v ~= nil then
        if (decoded.v ~= 1 and decoded.v ~= 2) or type(decoded.data) ~= "table" then return nil, "versão de perfil não suportada" end
        data = decoded.data
    end
    local operations, skipped, unknown = {}, 0, 0
    for key, value in pairs(data) do
        if type(key) ~= "string" then return nil, "chave de perfil inválida" end
        local entry = registry[key]
        if entry then
            -- O contorno do ESP era booleano em perfis anteriores e agora é
            -- slider. Migra somente as seis chaves conhecidas, sem alterar o arquivo.
            if type(value) == "boolean" and string.match(key, "^VISUAIS/ESP/[^/]+/painel/sub2/Contorno$") then
                local kind = string.match(key, "^VISUAIS/ESP/([^/]+)/")
                local espKinds = { Jogador = true, NPCs = true, Corpo = true, Recipiente = true, ["Item no chão"] = true, ["Itens de missão"] = true }
                if espKinds[kind] then value = value and 1.5 or 0 end
            end
            local ok, current = pcall(entry.get)
            if not ok then return nil, "não foi possível ler uma opção" end
            if entry.validate then
                local valid, result = pcall(entry.validate, value)
                if not valid or result ~= true then return nil, "valor inválido: " .. key end
            elseif current ~= nil and type(value) ~= type(current) then
                return nil, "tipo inválido: " .. key
            elseif current == nil and type(value) ~= "string" and type(value) ~= "table" then
                return nil, "tipo inválido: " .. key
            end
            local name = entry.name and string.gsub(entry.name, "#ativo$", "")
            if value == true and name and blocked[name] then
                skipped += 1
            else
                operations[#operations + 1] = { key = key, entry = entry, value = value, old = current }
            end
        else
            unknown += 1
        end
    end
    -- Ausência de atalhos/fixos no perfil remove esses registros como antes.
    for key, entry in pairs(registry) do
        if data[key] == nil and (string.sub(key, -6) == "#tecla" or string.sub(key, -7) == "#fixado") then
            local ok, old = pcall(entry.get)
            if not ok then return nil, "não foi possível ler um atalho" end
            operations[#operations + 1] = { key = key, entry = entry, old = old }
        end
    end
    table.sort(operations, function(a, b) return a.key < b.key end)
    return operations, nil, skipped, unknown
end

function Library.ProfileGuard:apply(operations)
    local applied = {}
    for _, operation in ipairs(operations) do
        local ok, result = pcall(operation.entry.set, operation.value)
        if not ok or result == false then
            -- Melhor esforço: callbacks podem ter efeitos irreversíveis no servidor.
            pcall(operation.entry.set, operation.old)
            for i = #applied, 1, -1 do pcall(applied[i].entry.set, applied[i].old) end
            return false, operation.key
        end
        applied[#applied + 1] = operation
    end
    return true
end
-- Limites locais para reduzir chamadas repetidas. Não são regras do jogo e
-- não garantem aceitação, segurança ou ausência de detecção no servidor.
Library.OperationGuard = { limits = {
    loot = { interval = 2, window = 60, max = 10 },
    reload = { interval = 5, window = 60, max = 6 },
}, history = {} }

function Library.OperationGuard:take(kind, now)
    local rule = self.limits[kind]
    if not rule or type(now) ~= "number" or now ~= now or now == math.huge or now == -math.huge then return false end
    local times = self.history[kind] or {}
    self.history[kind] = times
    -- Um relógio inesperadamente regressivo não deve abrir a trava.
    if #times > 0 and now < times[#times] then return false end
    while #times > 0 and now - times[1] >= rule.window do table.remove(times, 1) end
    if #times >= rule.max or (#times > 0 and now - times[#times] < rule.interval) then return false end
    times[#times + 1] = now
    return true
end

function Library.OperationGuard:validPath(path)
    if type(path) ~= "table" or #path < 1 or #path > 8 then return false end
    local count = 0
    for key, value in pairs(path) do
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #path then return false end
        if type(value) ~= "string" or #value < 1 or #value > 80 then return false end
        count += 1
    end
    return count == #path
end

-- Não procura remotes por palavras-chave; o caminho deve ser informado pelo
-- usuário, relativo à ferramenta equipada. Duplicatas tornam o alvo ambíguo.
function Library.OperationGuard:resolveRemote(tool, path)
    if not tool or not self:validPath(path) then return nil end
    local ok, remote = pcall(function()
        local node = tool
        for _, name in ipairs(path) do
            local match = nil
            for _, child in ipairs(node:GetChildren()) do
                if child.Name == name then
                    if match then return nil end
                    match = child
                end
            end
            if not match then return nil end
            node = match
        end
        if not node:IsA("RemoteEvent") or not node:IsDescendantOf(tool) then return nil end
        return node
    end)
    return ok and remote or nil
end

-- Listas de caminhos explícitos, relativas ao Workspace e vinculadas ao PlaceId.
-- As informações locais não comprovam autorização no servidor.
function Library.OperationGuard:validLootConfig(placeId, paths, actualPlaceId)
    if type(placeId) ~= "number" or placeId ~= actualPlaceId or placeId <= 0 or placeId % 1 ~= 0 then return false end
    if type(paths) ~= "table" or #paths < 1 or #paths > 20 then return false end
    local count = 0
    for k, path in pairs(paths) do
        if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > #paths or not self:validPath(path) then return false end
        count += 1
    end
    return count == #paths
end

function Library.OperationGuard:resolvePrompt(root, path)
    if not root or not self:validPath(path) then return nil end
    local ok, result = pcall(function()
        local node = root
        for _, name in ipairs(path) do
            local found
            for _, child in ipairs(node:GetChildren()) do
                if child.Name == name then
                    if found then return nil end
                    found = child
                end
            end
            if not found then return nil end
            node = found
        end
        if not node:IsA("ProximityPrompt") or not node:IsDescendantOf(root) then return nil end
        return node
    end)
    return ok and result or nil
end
-- Favoritos são apenas atalhos de navegação; nunca ativam controles por si.
Library.Favorites = { items = {}, listeners = {}, MAX = 12 }
do
    local F = Library.Favorites
    local function validate(list)
        if type(list) ~= "table" or #list > F.MAX then return false end
        local seen, count = {}, 0
        for k, v in pairs(list) do
            if type(k) ~= "number" or k % 1 ~= 0 or k < 1 or k > #list then return false end
            if type(v) ~= "string" or #v == 0 or #v > 512 or seen[v] then return false end
            count += 1; seen[v] = true
        end
        return count == #list
    end
    function F:get()
        local result = {}; for i, v in ipairs(self.items) do result[i] = v end; return result
    end
    function F:set(list)
        if not validate(list) then return false end
        self.items = {}; for i, v in ipairs(list) do self.items[i] = v end
        for _, f in ipairs(self.listeners) do pcall(f) end
        return true
    end
    function F:contains(key) return table.find(self.items, key) ~= nil end
    function F:toggle(key)
        local items = self:get()
        local i = table.find(items, key)
        if i then table.remove(items, i) else
            if #items >= self.MAX then return false end
            items[#items + 1] = key
        end
        return self:set(items)
    end
    Library.Registry["__favorites/list"] = { name = "Favoritos", get = function() return F:get() end,
        set = function(v) return F:set(v) end, validate = validate }
end

-- Histórico local à sessão de navegações pela busca/favoritos, sem ativar opções.
Library.RecentNavigation = {items = {}, listeners = {}, MAX = 5}
function Library.RecentNavigation:add(key)
    if type(key) ~= "string" or #key == 0 or #key > 512 then return end
    local i = table.find(self.items, key)
    if i then table.remove(self.items, i) end
    table.insert(self.items, 1, key)
    if #self.items > self.MAX then table.remove(self.items) end
    for _, f in ipairs(self.listeners) do pcall(f) end
end
function Library.RecentNavigation:get()
    local result = {}; for i, key in ipairs(self.items) do result[i] = key end; return result
end
-- ============ 30_actions.luau :: Lógica de movimento, mundo, extras, combate e servidores ============
local buildProfile
local Actions = {}
-- Inicialização isolada da função principal: o compilador do loadstring não
-- precisa manter os locais dos módulos anteriores no mesmo quadro de registros.
local function initializeActions()
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local StatsService = game:GetService("Stats")
    local LP = Players.LocalPlayer
    local VERSION = Config.Version or "0.0.8.2"
    local ACCESS = Config.Access or "FREE"

    -- limpeza: o "Sair" e o stopEngine chamam estas funções
    local CLEANUPS = {}
    Actions.alive = true
    Actions.connections = {}
    Actions.tracked = {}
    function Actions.trackConn(conn)
        if not Actions.alive then pcall(function() conn:Disconnect() end)
        else
            if Actions.tracked[conn] then return conn end
            for old in pairs(Actions.tracked) do if not old.Connected then Actions.tracked[old] = nil end end
            Actions.tracked[conn] = true
        end
        return conn
    end
    function Actions.connect(signal, callback)
        local conn = Library.Guards.connect(signal, callback,
            function() return Actions.alive end,
            function(stage, err)
                warn("[BBC] Evento " .. stage .. ": " .. err)
                if Library.Diagnostics then Library.Diagnostics:record("evento " .. stage, err) end
                if stage == "interrompido" then
                    pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = "Evento interrompido após erros; veja o console.", Duration = 5 }) end)
                end
            end)
        return Actions.trackConn(conn)
    end
    function Actions.guardStep(name, state, callback, stop)
        return Library.Guards.step(state, callback, function(stage, err)
            warn("[BBC] " .. name .. " " .. stage .. ": " .. err)
            if Library.Diagnostics then Library.Diagnostics:record(name .. " " .. stage, err) end
            if stage == "interrompido" then
                if stop then pcall(stop) end
                Library.Safety:disable(name)
                pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = name .. " interrompido após erros; veja o console.", Duration = 5 }) end)
            end
        end)
    end
    Actions.originals = setmetatable({}, { __mode = "k" })
    function Actions.setProperty(obj, prop, value)
        if not obj then return false end
        local saved = Actions.originals[obj]
        if not saved then saved = {}; Actions.originals[obj] = saved end
        local entry = saved[prop]
        if not entry then
            local ok, old = pcall(function() return obj[prop] end)
            if not ok then return false end
            entry = { value = old }
            saved[prop] = entry
        end
        local ok = pcall(function() obj[prop] = value end)
        if ok then entry.last, entry.applied = value, true end
        return ok
    end
    function Actions.restoreProperty(obj, prop)
        local saved = obj and Actions.originals[obj]
        local entry = saved and saved[prop]
        if not entry then return end
        -- Não sobrescrever uma alteração mais recente do próprio jogo.
        pcall(function()
            if entry.applied and obj[prop] == entry.last then obj[prop] = entry.value end
        end)
        saved[prop] = nil
    end
    local function onCleanup(fn) CLEANUPS[#CLEANUPS + 1] = fn end

    -- Ajustes limitados também quando aplicados por perfil, não apenas pelo slider.
    Actions.adjustments = {
        speed = {2.2, 1, 4}, sprint = {1.6, 1, 4}, fly = {60, 10, 120}, climb = {40, 5, 80}, cameraDistance = {12, 3, 40},
        brightness = {5, 0, 10}, clockTime = {14, 0, 24}, shadowSoftness = {0.5, 0, 1}, fogDensity = {0.6, 0, 1}, haze = {0.4, 0, 10},
        cloudCover = {0.5, 0, 1}, bloom = {0.8, 0, 5}, blur = {12, 0, 56}, saturation = {0.25, -1, 1}, contrast = {0.1, -1, 1},
        focus = {60, 0, 500}, farIntensity = {0.4, 0, 1}, rays = {0.25, 0, 1}, raysSpread = {0.6, 0, 1},
        swapInterval = {0.35, 0.2, 5}, peekDepth = {4, 0, 10}, ghostTransparency = {0.5, 0, 1},
        throwRange = {60, 10, 100}, hitDuration = {0.12, 0.05, 1}, hotbarSlots = {8, 1, 8},
        reticleSize = {5, 2, 30}, ringThickness = {1.5, 0.5, 5}, trailLifetime = {0.5, 0.1, 3},
        thirdZoom = {300, 10, 500}, offsetDistance = {3, 0, 10}, undergroundHeight = {-6, -10, 0}, spinDegrees = {6, 0, 15},
        lootDistance = {14, 1, 14}, lootInterval = {2, 2, 10}, reloadInterval = {5, 5, 30},
        refillValue = {999, 0, 999}, respawnDelay = {0.5, 0.5, 10}, auraRange = {12, 1, 12},
        bossOpacity = {60, 0, 100}, exitOpacity = {60, 0, 100}, skyStars = {3000, 0, 5000},
        shadowGearSoftness = {0.5, 0, 1}, toneWarmth = {100, 0, 100}, waterTransparency = {1, 0, 1},
        panelTextSize = {11, 8, 24}, panelInterval = {0.8, 0.5, 5}, charTransparency = {0, 0, 1}, handTransparency = {0, 0, 1}, heldTransparency = {0, 0, 1},
        firstPersonTransparency = {0, 0, 1}, ignoreObstacleDistance = {10000, 0, 10000}, panicTapWindow = {1.2, 0.8, 3}, panicZoneWidth = {140, 100, 300}, pauseResume = {0, 0, 1}, hitFxDuration = {0.3, 0.1, 1}, hitFxTransparency = {0.4, 0, 1},
        roleCriador = {4, 1, 10}, roleTestador = {4, 1, 10}, roleModerador = {4, 1, 10}, roleTrapaceiro = {4, 1, 10},
        joinDuration = {3, 1, 10}, targetDuration = {1.2, 1, 10}, killDuration = {2, 1, 10}, targetTextSize = {11, 8, 24}, damageTextSize = {14, 8, 30},
    }
    function Actions.setAdjustment(key, value)
        local entry = Actions.adjustments[key]
        if not entry or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
        value = math.clamp(value, entry[2], entry[3])
        entry[1] = (key == "hotbarSlots" or key == "refillValue" or key == "skyStars") and math.floor(value) or value
        if Actions.refreshAdjustment then Actions.refreshAdjustment(key) end
        return true
    end
    function Actions.getAdjustment(key)
        local entry = Actions.adjustments[key]
        return entry and entry[1]
    end

    -- ---------- Movimento / jogador: lógica de verdade para os botões ----------
    local MV = {
        speed = false, sprint = false, jumps = false, air = false, fly = false,
        noFall = false, ground = false, spider = false, jesus = false,
        third = false, camFree = false, antiAfk = false, respawn = false, noDrown = false,
    }
    local baseWalk, baseJump = 16, 50
    local flyLV, afkOn = nil, false
    local lastJump, preFallHealth = 0, nil
    local freeYaw, freePitch = 0, 0.3

    function Actions.restoreWalk()
        local hum, original, lastApplied = Actions.walkHum, Actions.walkOriginal, Actions.walkApplied
        if hum and original ~= nil and lastApplied ~= nil then
            pcall(function() if hum.Parent and hum.WalkSpeed == lastApplied then hum.WalkSpeed = original end end)
        end
        Actions.walkHum, Actions.walkOriginal, Actions.walkApplied = nil, nil, nil
    end
    function Actions.restoreSwim()
        local hum, original = Actions.swimHum, Actions.swimOriginal
        if hum and original ~= nil then
            pcall(function()
                if hum.Parent and not hum:GetStateEnabled(Enum.HumanoidStateType.Swimming) then
                    hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, original)
                end
            end)
        end
        Actions.swimHum, Actions.swimOriginal = nil, nil
    end
    local function mvHum()
        local ch = LP.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        return ch, hum, hrp
    end
    local function stopFly()
        if flyLV then pcall(function() flyLV:Destroy() end); flyLV = nil end
        if Actions.flyAttachment then pcall(function() Actions.flyAttachment:Destroy() end); Actions.flyAttachment = nil end
    end
    local function startFly()
        stopFly()
        local ch, hum, hrp = mvHum()
        if not (hum and hrp) then return end
        local ok, lv = pcall(function()
            local att = Instance.new("Attachment")
            Actions.flyAttachment = att
            att.Name = "BBCFlyAtt"; att.Parent = hrp
            local o = Instance.new("LinearVelocity")
            o.Name = "BBCFly"; o.Attachment0 = att; o.MaxForce = math.huge; o.VectorVelocity = Vector3.zero
            o.Parent = hrp
            return o
        end)
        flyLV = ok and lv or nil
        if not ok then stopFly() end
    end
    local function applyCamera()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        pcall(function()
            if MV.third then Actions.setProperty(LP, "CameraMaxZoomDistance", Actions.getAdjustment("thirdZoom"))
            else Actions.restoreProperty(LP, "CameraMaxZoomDistance") end
            if MV.camFree then Actions.setProperty(cam, "CameraType", Enum.CameraType.Scriptable)
            else Actions.restoreProperty(cam, "CameraType") end
        end)
    end
    local VirtualUser = nil
    pcall(function() VirtualUser = game:GetService("VirtualUser") end)
    local function afkLoop()
        if not MV.antiAfk or afkOn or not VirtualUser or not Library.Safety:allow("Anti AFK", true) then return end
        afkOn = true
        task.spawn(function()
            pcall(function() VirtualUser:CaptureController() end)
            while Actions.alive and MV.antiAfk and Library.Safety:allow("Anti AFK", true) do
                pcall(function()
                    VirtualUser:Button2Down(Vector2.new(), Workspace.CurrentCamera)
                    task.wait(0.2)
                    VirtualUser:Button2Up(Vector2.new(), Workspace.CurrentCamera)
                end)
                task.wait(60)
            end
            afkOn = false
        end)
    end

    Actions.connections.movement = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
        local ok, err = pcall(function()
            local ch, hum, hrp = mvHum()
            if not (ch and hum and hrp) then
                Actions.restoreWalk(); Actions.restoreSwim(); stopFly()
                return
            end
            local st = hum:GetState()

            -- velocidade / sprint
            if MV.speed or MV.sprint then
                if Actions.walkHum ~= hum then
                    Actions.restoreWalk()
                    Actions.walkHum, Actions.walkOriginal = hum, hum.WalkSpeed
                end
                local original = Actions.walkOriginal
                local ws = original
                if MV.speed then ws = original * Actions.getAdjustment("speed") end
                if MV.sprint then ws = math.max(ws, original * Actions.getAdjustment("sprint")) end
                if hum.WalkSpeed ~= ws then hum.WalkSpeed = ws end
                Actions.walkApplied = ws
            elseif Actions.walkHum then
                Actions.restoreWalk()
            end

            -- pulo duplo (pulos seguidos)
            if MV.jumps and st == Enum.HumanoidStateType.Freefall and os.clock() - lastJump > 0.25 then
                lastJump = os.clock()
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + baseJump, v.Z)
            end
            -- controle no ar: mantém o movimento horizontal
            if MV.air and st == Enum.HumanoidStateType.Freefall then
                local dir = hum.MoveDirection
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(dir.X * hum.WalkSpeed, v.Y, dir.Z * hum.WalkSpeed)
            end
            -- aranha: segura a subida encostado na parede
            if MV.spider and st == Enum.HumanoidStateType.Freefall and hum.MoveDirection.Magnitude > 0.1 then
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(v.X, Actions.getAdjustment("climb"), v.Z)
            end
            -- jesus: não nada, fica em cima da água
            if MV.jesus and st == Enum.HumanoidStateType.Swimming then
                hum:ChangeState(Enum.HumanoidStateType.Landed)
            end
            -- voar
            if MV.fly then
                if flyLV and flyLV.Parent ~= hrp then stopFly() end
                if not flyLV then startFly() end
                if flyLV then
                    local dir = hum.MoveDirection
                    local v = Vector3.new(dir.X, 0, dir.Z) * Actions.getAdjustment("fly")
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v += Vector3.new(0, Actions.getAdjustment("fly"), 0) end
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v += Vector3.new(0, -Actions.getAdjustment("fly"), 0) end
                    flyLV.VectorVelocity = v
                end
                if st ~= Enum.HumanoidStateType.Flying then hum:ChangeState(Enum.HumanoidStateType.Flying) end
            else
                stopFly()
            end
            -- sempre no chão
            if MV.ground and st == Enum.HumanoidStateType.Freefall then
                hum:ChangeState(Enum.HumanoidStateType.Landed)
            end
            -- sem dano de queda (guarda a vida antes de cair)
            if MV.noFall then
                if st == Enum.HumanoidStateType.Freefall then
                    if preFallHealth == nil then preFallHealth = hum.Health end
                elseif st == Enum.HumanoidStateType.Landed and preFallHealth ~= nil then
                    if hum.Health < preFallHealth then hum.Health = preFallHealth end
                    preFallHealth = nil
                end
            else
                preFallHealth = nil
            end
            -- não se afogar
            if MV.noDrown then
                if Actions.swimHum ~= hum then
                    Actions.restoreSwim()
                    Actions.swimHum, Actions.swimOriginal = hum, hum:GetStateEnabled(Enum.HumanoidStateType.Swimming)
                end
                hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
            elseif Actions.swimHum then
                Actions.restoreSwim()
            end
            -- câmera livre (mouse gira em volta do personagem)
            if MV.camFree then
                local md = UserInputService:GetMouseDelta()
                freeYaw += md.X * 0.02
                freePitch = math.clamp(freePitch + md.Y * 0.02, -1.2, 1.2)
                local head = hrp.Position + Vector3.new(0, 2, 0)
                local off = Vector3.new(math.sin(freeYaw) * math.cos(freePitch), math.sin(freePitch), math.cos(freeYaw) * math.cos(freePitch)) * Actions.getAdjustment("cameraDistance")
                Workspace.CurrentCamera.CFrame = CFrame.new(head + off, head)
            end
        end)
        if ok then
            Actions.movementErrors = 0
        else
            Actions.movementErrors = (Actions.movementErrors or 0) + 1
            if Actions.movementErrors == 1 then warn("[BBC] Movimento: " .. tostring(err)) end
            if Actions.movementErrors >= 5 then
                Actions.connections.movement:Disconnect()
                stopFly()
                Actions.restoreWalk(); Actions.restoreSwim()
                Library.Safety:disableTracked()
                pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = "Movimento interrompido após erros; veja o console.", Duration = 5 }) end)
            end
        end
    end))

    local PLAYER_ACTIONS = {
        ["Hack de velocidade"] = function(v) MV.speed = v; if not MV.speed and not MV.sprint then Actions.restoreWalk() end end,
        ["Sprint automático"] = function(v) MV.sprint = v; if not MV.speed and not MV.sprint then Actions.restoreWalk() end end,
        ["Pulos seguidos"] = function(v) MV.jumps = v end,
        ["Controle no ar"] = function(v) MV.air = v end,
        ["Voar"] = function(v) MV.fly = v; if not v then stopFly() end end,
        ["Sem dano de queda"] = function(v) MV.noFall = v end,
        ["Sempre no chão"] = function(v) MV.ground = v end,
        ["Jesus"] = function(v) MV.jesus = v end,
        ["Aranha"] = function(v) MV.spider = v end,
        ["Terceira pessoa"] = function(v) MV.third = v; applyCamera() end,
        ["Câmera livre"] = function(v) MV.camFree = v; applyCamera() end,
        ["Anti AFK"] = function(v) MV.antiAfk = v; afkLoop() end,
        ["Renascer automático"] = function(v) MV.respawn = v end,
        ["Não se afogar"] = function(v) MV.noDrown = v; if not v then Actions.restoreSwim() end end,
    }

    -- ---------- Mundo / iluminação: lógica de verdade para os botões ----------
    local Lighting = game:GetService("Lighting")
    local Terrain = Workspace.Terrain
    local WORLD = {
        grama = false, minas = false, jogadores = false, chefes = false, saida = false,
        luz = false, sol = false, sombras = false, render = false, neblina = false,
        atmosfera = false, ceu = false, nuvens = false, florescer = false, desfoque = false,
        cor = false, profundidade = false, raios = false, tonalidade = false, master = true,
    }
    local WORLD_COLORS = {
        grama = Color3.fromRGB(72, 160, 76), areia = Color3.fromRGB(214, 190, 120),
        rocha = Color3.fromRGB(120, 120, 126), terra = Color3.fromRGB(110, 78, 52),
        agua = Color3.fromRGB(40, 70, 75), folhas = Color3.fromRGB(70, 150, 70),
        troncos = Color3.fromRGB(100, 70, 45),
    }
    local FX = {}
    local function mkFx(class, name, parent, disabled)
        local instance
        local ok, o = pcall(function()
            instance = Instance.new(class)
            instance.Name = name
            -- Clouds e os efeitos começam desligados antes de serem associados:
            -- evita uma ativação transitória e conflito na criação da interface.
            if disabled then instance.Enabled = false end
            instance.Parent = parent
            return instance
        end)
        if not ok and instance then pcall(function() instance:Destroy() end) end
        FX[name] = ok and o or nil
        return FX[name]
    end
    mkFx("BloomEffect", "BBC_Bloom", Lighting, true)
    mkFx("BlurEffect", "BBC_Blur", Lighting, true)
    mkFx("ColorCorrectionEffect", "BBC_CorAjuste", Lighting, true)
    mkFx("ColorCorrectionEffect", "BBC_CorTon", Lighting, true)
    mkFx("DepthOfFieldEffect", "BBC_Profundidade", Lighting, true)
    mkFx("SunRaysEffect", "BBC_Raios", Lighting, true)
    -- Atmosphere e Sky não possuem Enabled: ficam fora da árvore até o uso.
    mkFx("Atmosphere", "BBC_Atmosfera", nil)
    mkFx("Sky", "BBC_Ceu", nil)

    -- Reutiliza as nuvens do jogo, se existirem, para não disputar com uma
    -- segunda instância. Apenas a instância criada pelo hub é destruída.
    local cloudTarget
    local function applyClouds(enabled, cover)
        if cloudTarget and (not enabled or cloudTarget.Parent ~= Terrain) then
            Actions.restoreProperty(cloudTarget, "Cover")
            Actions.restoreProperty(cloudTarget, "Enabled")
            if cloudTarget == FX.BBC_Nuvens then
                pcall(function() cloudTarget:Destroy() end)
                FX.BBC_Nuvens = nil
            end
            cloudTarget = nil
        end
        if not enabled then return end
        if not cloudTarget then
            local ok, children = pcall(function() return Terrain:GetChildren() end)
            if not ok then return end -- não criar uma duplicata se não pudermos verificar
            local first
            for _, child in ipairs(children) do
                if child:IsA("Clouds") then
                    first = first or child
                    if child.Enabled then cloudTarget = child; break end
                end
            end
            cloudTarget = cloudTarget or first
            if not cloudTarget then
                cloudTarget = mkFx("Clouds", "BBC_Nuvens", nil, true)
                if not cloudTarget then return end
                local parented = pcall(function() cloudTarget.Parent = Terrain end)
                if not parented then
                    pcall(function() cloudTarget:Destroy() end)
                    FX.BBC_Nuvens, cloudTarget = nil, nil
                    return
                end
            end
        end
        Actions.setProperty(cloudTarget, "Cover", cover)
        Actions.setProperty(cloudTarget, "Enabled", true)
    end

    local function applyLighting()
        pcall(function()
            local m = WORLD.master
            local function override(prop, enabled, value)
                if enabled then Actions.setProperty(Lighting, prop, value)
                else Actions.restoreProperty(Lighting, prop) end
            end
            override("Brightness", m and WORLD.luz, Actions.getAdjustment("brightness"))
            override("Ambient", m and WORLD.luz, Color3.fromRGB(110, 110, 110))
            override("OutdoorAmbient", m and WORLD.luz, Color3.fromRGB(110, 110, 110))
            override("ClockTime", m and WORLD.sol, Actions.getAdjustment("clockTime"))
            override("GeographicLatitude", m and WORLD.sol, 0)
            override("GlobalShadows", m and WORLD.sombras, true)
            override("ShadowSoftness", m and (WORLD.render or WORLD.sombras), Actions.getAdjustment(WORLD.sombras and "shadowGearSoftness" or "shadowSoftness"))

            local atmo = FX.BBC_Atmosfera
            if atmo then
                atmo.Parent = (m and (WORLD.atmosfera or WORLD.neblina)) and Lighting or nil
                atmo.Density = (m and WORLD.neblina) and Actions.getAdjustment("fogDensity") or 0.35
                atmo.Color = Color3.fromRGB(188, 200, 220)
                atmo.Decay = Color3.fromRGB(90, 110, 140)
                atmo.Glare = 0.2
                atmo.Haze = Actions.getAdjustment("haze")
            end
            if FX.BBC_Ceu then
                FX.BBC_Ceu.StarCount = Actions.getAdjustment("skyStars")
                FX.BBC_Ceu.Parent = (m and WORLD.ceu) and Lighting or nil
            end
            applyClouds(m and WORLD.nuvens, Actions.getAdjustment("cloudCover"))
            if FX.BBC_Bloom then
                FX.BBC_Bloom.Enabled = m and WORLD.florescer
                FX.BBC_Bloom.Intensity = Actions.getAdjustment("bloom")
                FX.BBC_Bloom.Size = 24
                FX.BBC_Bloom.Threshold = 2
            end
            if FX.BBC_Blur then
                FX.BBC_Blur.Enabled = m and WORLD.desfoque
                FX.BBC_Blur.Size = Actions.getAdjustment("blur")
            end
            if FX.BBC_CorAjuste then
                FX.BBC_CorAjuste.Enabled = m and WORLD.cor
                FX.BBC_CorAjuste.Saturation = Actions.getAdjustment("saturation")
                FX.BBC_CorAjuste.Contrast = Actions.getAdjustment("contrast")
            end
            if FX.BBC_CorTon then
                FX.BBC_CorTon.Enabled = m and WORLD.tonalidade
                local warmth = Actions.getAdjustment("toneWarmth") / 100
                FX.BBC_CorTon.TintColor = Color3.new(1, 1 - (20 / 255) * warmth, 1 - (45 / 255) * warmth)
            end
            if FX.BBC_Profundidade then
                FX.BBC_Profundidade.Enabled = m and WORLD.profundidade
                FX.BBC_Profundidade.FarIntensity = Actions.getAdjustment("farIntensity")
                FX.BBC_Profundidade.FocusDistance = Actions.getAdjustment("focus")
                FX.BBC_Profundidade.InFocusRadius = 40
            end
            if FX.BBC_Raios then
                FX.BBC_Raios.Enabled = m and WORLD.raios
                FX.BBC_Raios.Intensity = Actions.getAdjustment("rays")
                FX.BBC_Raios.Spread = Actions.getAdjustment("raysSpread")
            end
        end)
    end

    -- terreno: cores de material de verdade
    local TERRAIN_MATS = {
        grama = Enum.Material.Grass, areia = Enum.Material.Sand,
        rocha = Enum.Material.Rock, terra = Enum.Material.Ground,
    }
    local function paintTerrain(key, c)
        pcall(function()
            if key == "agua" then
                Actions.setProperty(Terrain, "WaterColor", c)
            else
                local mat = TERRAIN_MATS[key]
                if mat then
                    Actions.terrainColors = Actions.terrainColors or {}
                    if Actions.terrainColors[mat] == nil then Actions.terrainColors[mat] = Terrain:GetMaterialColor(mat) end
                    Terrain:SetMaterialColor(mat, c)
                end
            end
        end)
    end

    -- folhas / troncos: pinta as partes com o material correspondente
    local plantLeaf, plantTrunk = {}, {}
    local function scanPlants()
        plantLeaf, plantTrunk = {}, {}
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local m = d.Material
                if m == Enum.Material.LeafyGrass or m == Enum.Material.Grass then
                    plantLeaf[#plantLeaf + 1] = d
                elseif m == Enum.Material.Wood or m == Enum.Material.WoodPlanks then
                    plantTrunk[#plantTrunk + 1] = d
                end
            end
        end
    end
    local function paintPlants(key, c)
        local list = key == "folhas" and plantLeaf or plantTrunk
        if #list == 0 then scanPlants(); list = key == "folhas" and plantLeaf or plantTrunk end
        for _, d in ipairs(list) do Actions.setProperty(d, "Color", c) end
    end

    -- Guardar objetos locais em vez de destruí-los, para poder restaurá-los.
    Actions.hidden = { grass = {}, mines = {} }
    function Actions.hideNamed(kind, d, patterns)
        if not (d:IsA("BasePart") or d:IsA("Model")) or not d.Parent or not d:IsDescendantOf(Workspace) then return end
        if LP.Character and d:IsDescendantOf(LP.Character) then return end
        local low = string.lower(d.Name)
        for _, pattern in ipairs(patterns) do
            if string.find(low, pattern, 1, true) then
                Actions.hidden[kind][d] = d.Parent
                d.Parent = nil
                return
            end
        end
    end
    function Actions.restoreHidden(kind)
        for obj, parent in pairs(Actions.hidden[kind]) do
            pcall(function() if obj.Parent == nil and parent.Parent then obj.Parent = parent end end)
        end
        table.clear(Actions.hidden[kind])
    end
    -- Evento primeiro, varredura incremental depois: cancelar invalida tanto
    -- callbacks pendentes quanto o restante da caminhada antes de restaurar.
    Actions.hiddenTokens, Actions.hiddenConns = {}, {}
    function Actions.setHiddenScan(kind, enabled, patterns)
        local token = (Actions.hiddenTokens[kind] or 0) + 1
        Actions.hiddenTokens[kind] = token
        local previous = Actions.hiddenConns[kind]
        if previous then previous:Disconnect(); Actions.hiddenConns[kind] = nil end
        if not enabled then Actions.restoreHidden(kind); return end
        local function active()
            return Actions.alive and not Library.Panic and Actions.hiddenTokens[kind] == token
        end
        local function visit(d)
            if active() then Actions.hideNamed(kind, d, patterns) end
        end
        Actions.hiddenConns[kind] = Actions.connect(Workspace.DescendantAdded, visit)
        Library.StreamScan.start(Workspace, active, visit)
    end
    local function applyGrama(v)
        Actions.setHiddenScan("grass", v, { "grass", "grama" })
    end
    local function applyMinas(v)
        Actions.setHiddenScan("mines", v, { "mine", "mina", "landmine", "tnt", "explosive" })
    end
    local function applyJogadores(v)
        if not v then return end
        pcall(function() Players.CharacterAutoLoads = true end)
        pcall(function() if LP.Character then LP:LoadCharacter() end end)
        Library:Notify({ Title = "MUNDO", Content = "Personagem recarregado (" .. #Players:GetPlayers() .. " jogadores).", Duration = 4 })
    end

    local bossHigh, exitHigh = {}, {}
    local function clearHigh(list)
        for _, h in ipairs(list) do pcall(function() h:Destroy() end) end
        for i = 1, #list do list[i] = nil end
    end
    local function markHigh(list, found, color, transparency)
        for _, d in ipairs(found) do
            pcall(function()
                local h = Instance.new("Highlight")
                h.Name = "BBC_HL"
                h.FillColor = color
                h.FillTransparency = transparency
                h.OutlineColor = Color3.fromRGB(22, 18, 18)
                h.OutlineTransparency = 0.1
                h.Enabled = not Library.Panic
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent = d
                list[#list + 1] = h
            end)
        end
    end
    function Actions.scanNamedMarks(v, list, patterns, color, adjustment, tokenKey, title)
        Actions[tokenKey] = (Actions[tokenKey] or 0) + 1
        local token = Actions[tokenKey]
        clearHigh(list)
        if not v then return end
        task.spawn(function()
            Library.StreamScan.run(Workspace, function()
                return Actions.alive and Actions[tokenKey] == token
            end, function(d)
                if #list >= 100 or not d:IsDescendantOf(Workspace) or not (d:IsA("Model") or d:IsA("BasePart")) then return end
                local low = string.lower(d.Name)
                for _, pattern in ipairs(patterns) do
                    if string.find(low, pattern, 1, true) then
                        markHigh(list, {d}, color, Actions.getAdjustment(adjustment) / 100)
                        break
                    end
                end
            end)
            if Actions.alive and Actions[tokenKey] == token and not Library.Panic then
                Library:Notify({ Title = "MUNDO", Content = #list .. " " .. title .. (#list >= 100 and " (limite)" or "") .. ".", Duration = 5 })
            end
        end)
    end
    local function applyChefes(v)
        Actions.scanNamedMarks(v, bossHigh, { "boss", "chefe", "chefao", "champion" }, Color3.fromRGB(255, 120, 30), "bossOpacity", "bossToken", "chefes marcados")
    end
    local function applySaida(v)
        Actions.scanNamedMarks(v, exitHigh, { "exit", "saida", "portal" }, Color3.fromRGB(70, 220, 90), "exitOpacity", "exitToken", "saídas marcadas")
    end

    local WORLD_ACTIONS = {
        ["Sem grama"] = function(v) WORLD.grama = v; applyGrama(v) end,
        ["Desativar minas"] = function(v) WORLD.minas = v; applyMinas(v) end,
        ["Carregar jogadores"] = function(v) WORLD.jogadores = v; applyJogadores(v) end,
        ["Buscar chefes"] = function(v) WORLD.chefes = v; applyChefes(v) end,
        ["Pontos de saída"] = function(v) WORLD.saida = v; applySaida(v) end,
        ["Luz"] = function(v) WORLD.luz = v; applyLighting() end,
        ["Hora e sol"] = function(v) WORLD.sol = v; applyLighting() end,
        ["Sombras"] = function(v) WORLD.sombras = v; applyLighting() end,
        ["Renderização"] = function(v) WORLD.render = v; applyLighting() end,
        ["Neblina"] = function(v) WORLD.neblina = v; applyLighting() end,
        ["Atmosfera"] = function(v) WORLD.atmosfera = v; applyLighting() end,
        ["Céu"] = function(v) WORLD.ceu = v; applyLighting() end,
        ["Nuvens"] = function(v) WORLD.nuvens = v; applyLighting() end,
        ["Florescer"] = function(v) WORLD.florescer = v; applyLighting() end,
        ["Desfoque"] = function(v) WORLD.desfoque = v; applyLighting() end,
        ["Ajuste de cor"] = function(v) WORLD.cor = v; applyLighting() end,
        ["Profundidade"] = function(v) WORLD.profundidade = v; applyLighting() end,
        ["Raios de sol"] = function(v) WORLD.raios = v; applyLighting() end,
        ["Tonalidade"] = function(v) WORLD.tonalidade = v; applyLighting() end,
        ["Remover água"] = function(v)
            WORLD.aguaOff = v
            pcall(function()
                if v then
                    Actions.setProperty(Terrain, "WaterTransparency", Actions.getAdjustment("waterTransparency"))
                    Actions.setProperty(Terrain, "WaterWaveSize", 0)
                    Actions.setProperty(Terrain, "WaterWaveSpeed", 0)
                else
                    for _, prop in ipairs({ "WaterTransparency", "WaterWaveSize", "WaterWaveSpeed" }) do
                        Actions.restoreProperty(Terrain, prop)
                    end
                end
            end)
        end,
    }

    -- ---------- Extras: lógica de verdade para os botões ----------
    local StarterGui = game:GetService("StarterGui")
    local SoundService = game:GetService("SoundService")
    local EXTRA = { swap = false, effects = false, joinConn = nil, panicFn = nil }
    local function say(text)
        pcall(function() Library:Notify({ Title = "BBC HUB", Content = text, Duration = 3 }) end)
    end

    -- ===== sons (IDs definidos na aba SONS) =====
    local SOUND_TOGGLES = { Jump = false, Pegadas = false, Pouso = false, Capacete = false,
        ["Tiro na cabeça"] = false, ["Tiro no corpo"] = false, Abate = false, Disparo = false, ["Acerto com sangue"] = false }
    local SOUND_IDS, soundObjs, soundVolumes = {}, {}, {}
    function Actions.setSoundVolume(name, value)
        if SOUND_TOGGLES[name] == nil or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
        soundVolumes[name] = math.clamp(value, 0, 100) / 100
        local sound = soundObjs[name]
        if sound then pcall(function() sound.Volume = soundVolumes[name] end) end
        return true
    end
    local SOUND_NAMES = { "Jump", "Pegadas", "Pouso", "Capacete", "Tiro na cabeça", "Tiro no corpo", "Abate", "Disparo", "Acerto com sangue" }
    local function getSound(name)
        local id = SOUND_IDS[name]
        if not id then return nil end
        local s = soundObjs[name]
        if not s then
            local ok, o = pcall(function()
                local i = Instance.new("Sound")
                i.Name = "BBC_SND"
                i.SoundId = "rbxassetid://" .. tostring(id)
                i.Volume = soundVolumes[name] or 0.6
                i.Parent = SoundService
                return i
            end)
            s = ok and o or nil
            soundObjs[name] = s
        end
        return s
    end
    local function playSound(name)
        if not SOUND_TOGGLES[name] then return end
        local s = getSound(name)
        if s then pcall(function() s:Play() end) end
    end
    local function setSoundId(text)
        local name, id = string.match(tostring(text or ""), "^%s*(.-)%s+([0-9]+)%s*$")
        if not id then id = string.match(tostring(text or ""), "^%s*([0-9]+)%s*$") end
        if not id then say("Use: Nome ID  ou  ID"); return end
        if name and name ~= "" then SOUND_IDS[name] = id else for _, n in ipairs(SOUND_NAMES) do SOUND_IDS[n] = id end end
        for _, sound in pairs(soundObjs) do pcall(function() sound:Destroy() end) end
        soundObjs = {}
        say("Som definido: " .. ((name and name ~= "") and name or "todos"))
    end
    local function hookCharSounds(char)
        local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
        if not Actions.alive or LP.Character ~= char or not hum or not hum:IsA("Humanoid") then return end
        if Actions.charSoundConn then Actions.charSoundConn:Disconnect() end
        Actions.charSoundConn = Actions.connect(hum.StateChanged, function(_, new)
            if new == Enum.HumanoidStateType.Jumping then playSound("Jump")
            elseif new == Enum.HumanoidStateType.Landed then playSound("Pouso") end
        end)
        task.spawn(function()
            while Actions.alive and LP.Character == char and char.Parent and hum.Parent do
                if SOUND_TOGGLES["Pegadas"] and hum.MoveDirection.Magnitude > 0.1 and hum:GetState() == Enum.HumanoidStateType.Running then
                    playSound("Pegadas")
                    task.wait(math.clamp(30 / math.max(hum.WalkSpeed, 1), 0.15, 0.8))
                else
                    task.wait(0.2)
                end
            end
        end)
    end
    Actions.soundToolConns = setmetatable({}, { __mode = "k" })
    local function hookTool(tool)
        if not tool:IsA("Tool") or Actions.soundToolConns[tool] then return end
        local conns = {}
        Actions.soundToolConns[tool] = conns
        conns[#conns + 1] = Actions.connect(tool.Activated, function()
            if tool.Parent == LP.Character then playSound("Disparo") end
        end)
        conns[#conns + 1] = Actions.connect(tool.Equipped, function()
            local low = string.lower(tool.Name)
            if string.find(low, "helmet", 1, true) or string.find(low, "capacete", 1, true) or string.find(low, "hat", 1, true) then
                playSound("Capacete")
            end
        end)
        local function unhook()
            for _, conn in ipairs(conns) do conn:Disconnect() end
            Actions.soundToolConns[tool] = nil
        end
        conns[#conns + 1] = Actions.connect(tool.Destroying, unhook)
        conns[#conns + 1] = Actions.connect(tool.AncestryChanged, function()
            task.defer(function()
                if not Actions.alive or Actions.soundToolConns[tool] ~= conns then return end
                if tool.Parent ~= LP.Character and tool.Parent ~= LP:FindFirstChildOfClass("Backpack") then unhook() end
            end)
        end)
    end
    local function hookCharTools(char)
        if not Actions.alive or LP.Character ~= char then return end
        if Actions.soundCharConn then Actions.soundCharConn:Disconnect(); Actions.soundCharConn = nil end
        if Actions.soundBackpackConn then Actions.soundBackpackConn:Disconnect(); Actions.soundBackpackConn = nil end
        local function scan(parent)
            if not parent then return end
            for _, t in ipairs(parent:GetChildren()) do if t:IsA("Tool") then hookTool(t) end end
        end
        scan(char); scan(LP:FindFirstChild("Backpack"))
        Actions.soundCharConn = Actions.connect(char.ChildAdded, function(c) if c:IsA("Tool") then hookTool(c) end end)
        local bp = LP:FindFirstChild("Backpack")
        if bp then Actions.soundBackpackConn = Actions.connect(bp.ChildAdded, function(c) if c:IsA("Tool") then hookTool(c) end end) end
    end
    local function hookCharExtra(char)
        hookCharSounds(char)
        hookCharTools(char)
    end
    if LP.Character then task.spawn(hookCharExtra, LP.Character) end
    Actions.trackConn(Actions.connect(LP.CharacterAdded, hookCharExtra))
    Actions.connect(LP.ChildAdded, function(child)
        if child:IsA("Backpack") and LP.Character then hookCharTools(LP.Character) end
    end)
    local function hookVictimSounds(plr)
        local charConn, addedConn, removingConn, ancestryConn
        local function disconnectCharacter()
            if charConn then charConn:Disconnect(); charConn = nil end
        end
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if not Actions.alive or plr.Parent ~= Players or plr.Character ~= char or not hum then return end
            disconnectCharacter()
            charConn = Actions.connect(hum.HealthChanged,  function(h)
                local tag = hum:FindFirstChild("creator")
                if not (tag and tag.Value == LP) then return end
                if h <= 0 then playSound("Abate"); return end
                playSound("Acerto com sangue")
                local cam = Workspace.CurrentCamera
                local hit
                if cam then
                    local ok, res = pcall(function() return Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 1000) end)
                    if ok and res and res.Instance then hit = res.Instance end
                end
                if hit and hit:IsDescendantOf(char) then
                    playSound(string.find(string.lower(hit.Name), "head", 1, true) and "Tiro na cabeça" or "Tiro no corpo")
                end
            end)
        end
        if plr.Character then task.spawn(onChar, plr.Character) end
        addedConn = Actions.connect(plr.CharacterAdded, onChar)
        removingConn = Actions.connect(plr.CharacterRemoving, disconnectCharacter)
        ancestryConn = Actions.connect(plr.AncestryChanged, function(_, parent)
            if parent then return end
            disconnectCharacter()
            if addedConn then addedConn:Disconnect() end
            if removingConn then removingConn:Disconnect() end
            if ancestryConn then ancestryConn:Disconnect() end
        end)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookVictimSounds(p) end
    Actions.trackConn(Actions.connect(Players.PlayerAdded, hookVictimSounds))

    -- ===== troca rápida: equipa a próxima ferramenta em loop =====
    local swapOn = false
    local function applySwap(v)
        swapOn = v == true
        Actions.swapToken = (Actions.swapToken or 0) + 1
        local token = Actions.swapToken
        if not v then return end
        task.spawn(function()
            local guard = {}
            while Actions.alive and swapOn and Actions.swapToken == token do
                if not Actions.guardStep("Troca rápida", guard, function()
                local ch, hum = LP.Character, LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if ch and hum then
                    local tools = {}
                    local bp = LP:FindFirstChild("Backpack")
                    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then tools[#tools + 1] = t end end end
                    local equipped = ch:FindFirstChildOfClass("Tool")
                    if #tools > 0 then
                        local idx = 1
                        for i, t in ipairs(tools) do if t == equipped then idx = i; break end end
                        local nxt = tools[(idx % #tools) + 1]
                        if nxt and nxt ~= equipped then hum:EquipTool(nxt) end
                    end
                end
                end, function() swapOn = false end) then break end
                task.wait(Actions.getAdjustment("swapInterval"))
            end
        end)
    end

    -- ===== atravessar porta: alguns segundos sem colisão =====
    local noclipParts = {}
    local function stopNoclip()
        Actions.noclipToken = (Actions.noclipToken or 0) + 1
        for d, v in pairs(noclipParts) do pcall(function() if d.Parent and d.CanCollide == false then d.CanCollide = v end end) end
        table.clear(noclipParts)
    end
    Library.Safety:trackStopper(stopNoclip)
    local function noclipPulse()
        if not Actions.alive or not Library.Safety:allow("Atravessar porta", true) then return false end
        local ch = LP.Character
        if not ch then return end
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("BasePart") then
                if noclipParts[d] == nil then noclipParts[d] = d.CanCollide end
                pcall(function() d.CanCollide = false end)
            end
        end
        Actions.noclipToken = (Actions.noclipToken or 0) + 1
        local token = Actions.noclipToken
        say("Atravessando por 3s.")
        task.delay(3, function()
            if token ~= Actions.noclipToken then return end
            stopNoclip()
        end)
    end

    -- ===== remover efeitos =====
    local EFFECT_CLASSES = { "ParticleEmitter", "Trail", "Beam", "PointLight", "SpotLight", "SurfaceLight", "Fire", "Smoke", "Sparkles" }
    Actions.effects = setmetatable({}, { __mode = "k" })
    local function removeEffects(v)
        EXTRA.effects = v == true
        Actions.effectsToken = (Actions.effectsToken or 0) + 1
        local token = Actions.effectsToken
        if not v then
            for obj, enabled in pairs(Actions.effects) do
                pcall(function() if obj.Enabled == false then obj.Enabled = enabled end end)
            end
            table.clear(Actions.effects)
            return
        end
        task.spawn(function()
            local n = 0
            local function active() return Actions.alive and EXTRA.effects and not Library.Panic and Actions.effectsToken == token end
            Library.StreamScan.run(Workspace, active, function(d)
                if not active() or not d:IsDescendantOf(Workspace) then return end
                for _, class in ipairs(EFFECT_CLASSES) do
                    if d:IsA(class) then
                        local ok = pcall(function()
                            if Actions.effects[d] == nil then Actions.effects[d] = d.Enabled end
                            d.Enabled = false
                        end)
                        if ok then n += 1 end
                        break
                    end
                end
            end)
            if active() then say(n .. " efeitos desativados localmente.") end
        end)
    end

    -- ===== avisos de entrada =====
    local function applyJoinAlerts(v)
        if v and not EXTRA.joinConn then
            EXTRA.joinConn = Actions.trackConn(Actions.connect(Players.PlayerAdded, function(pl)
                pcall(function() Library:Notify({ Title = "EXTRAS", Content = pl.Name .. " entrou.", Duration = Actions.getAdjustment("joinDuration") }) end)
            end))
        elseif not v and EXTRA.joinConn then
            EXTRA.joinConn:Disconnect(); EXTRA.joinConn = nil
        end
    end
    -- ===== detecção de cargos =====
    local ROLE_KW = {
        Criador = { "creator", "criador", "owner", "dono", "founder", "fundador" },
        Testador = { "tester", "testador", "beta", "trial" },
        Moderador = { "mod", "moderador", "admin", "administrador", "staff" },
        Trapaceiro = { "cheat", "trapace", "banned", "banido", "suspect" },
    }
    local roleConns = {}
    local function roleTexts(pl)
        local texts = {}
        for _, a in ipairs({ "Role", "Cargo", "GroupRole", "Rank", "Title", "Tag" }) do
            local v = pl:GetAttribute(a)
            if v ~= nil then texts[#texts + 1] = string.lower(tostring(v)) end
        end
        local gid = pl:GetAttribute("GroupId") or pl:GetAttribute("Group")
        if gid then
            local ok, role = pcall(function() return pl:GetRoleInGroup(tonumber(gid)) end)
            if ok and role then texts[#texts + 1] = string.lower(role) end
        end
        texts[#texts + 1] = string.lower(pl.Name)
        texts[#texts + 1] = string.lower(pl.DisplayName)
        return texts
    end
    local function checkRole(pl, role)
        local texts = roleTexts(pl)
        for _, kw in ipairs(ROLE_KW[role] or {}) do
            for _, t in ipairs(texts) do if string.find(t, kw, 1, true) then return true end end
        end
        return false
    end
    local function applyRole(role, v)
        if v and not roleConns[role] then
            local function scan()
                if not Actions.alive or Library.Panic then return end
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= LP and checkRole(pl, role) then
                        pcall(function() Library:Notify({ Title = "DETECÇÃO", Content = role .. ": " .. pl.Name, Duration = Actions.getAdjustment("role" .. role) }) end)
                    end
                end
            end
            scan()
            roleConns[role] = {
                Actions.trackConn(Actions.connect(Players.PlayerAdded, function()
                    task.delay(1, function() if Actions.alive and roleConns[role] then scan() end end)
                end)),
                Actions.trackConn(Actions.connect(Players.PlayerRemoving, scan)),
            }
        elseif not v and roleConns[role] then
            for _, c in ipairs(roleConns[role]) do c:Disconnect() end
            roleConns[role] = nil
        end
    end

    -- ===== ordenar depósito (mochila) =====
    local function sortBackpack(mode)
        local bp = LP:FindFirstChild("Backpack")
        if not bp then say("Sem mochila."); return end
        local items = {}
        for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") or t:IsA("HopperBin") then items[#items + 1] = t end end
        local function val(t)
            local v = t:GetAttribute("Value") or t:GetAttribute("Price") or t:GetAttribute("Rarity")
            return tonumber(v) or 0
        end
        if mode == "valor" then table.sort(items, function(a, b) return val(a) > val(b) end)
        elseif mode == "tipo" then table.sort(items, function(a, b) return a.ClassName < b.ClassName end)
        else table.sort(items, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end) end
        for _, t in ipairs(items) do pcall(function() t.Parent = nil end); pcall(function() t.Parent = bp end) end
        say(#items .. " itens ordenados (" .. mode .. ").")
    end

    -- ===== ver inventário =====
    local INV = { on = false, mode = "Jogadores", always = false }
    local invGui, invLabel
    local function ensureInvGui()
        if invGui and invGui.Parent then return end
        invGui = Library:CreateRootGui("ScreenGui", { Name = "BBCInv", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900, Enabled = false })
        local f = Library.Internal.create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(280, 220), BorderSizePixel = 0 }, invGui)
        Library.Internal.bind(f, "BackgroundColor3", "Surface"); Library.Internal.corner(f, 5); Library.Internal.stroke(f, "Stroke", 0.3)
        local title = Library.Internal.create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 4), Text = "INVENTÁRIO", TextSize = 12, FontFace = Library.Fonts.Bold }, f)
        Library.Internal.bind(title, "TextColor3", "Text")
        invLabel = Library.Internal.create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 1, -30), Text = "", TextSize = Actions.getAdjustment("panelTextSize"), FontFace = Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, f)
        Library.Internal.bind(invLabel, "TextColor3", "Text")
    end
    local function nearestNpc()
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local my = hrp and hrp.Position or Workspace.CurrentCamera.CFrame.Position
        local best, bd = nil, math.huge
        for _, m in ipairs(Workspace:GetDescendants()) do
            if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and not Players:GetPlayerFromCharacter(m) and m ~= ch then
                local p = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
                if p and p:IsA("BasePart") then
                    local d = (p.Position - my).Magnitude
                    if d < bd then bd = d; best = m end
                end
            end
        end
        return best
    end
    local function toolLines(pl)
        local lines = {}
        local function add(parent)
            if not parent then return end
            for _, t in ipairs(parent:GetChildren()) do if t:IsA("Tool") then lines[#lines + 1] = t.Name end end
        end
        add(pl:FindFirstChild("Backpack"))
        if pl.Character then add(pl.Character) end
        return lines
    end
    local function refreshInv()
        if not INV.on then if invGui then invGui.Enabled = false end; return end
        ensureInvGui()
        invGui.Enabled = true
        local lines = {}
        if INV.mode == "Jogadores" then
            lines[#lines + 1] = "Você:"
            for _, l in ipairs(toolLines(LP)) do lines[#lines + 1] = "  " .. l end
        elseif INV.mode == "NPCs" then
            local n = nearestNpc()
            lines[#lines + 1] = n and ("NPC: " .. n.Name) or "Nenhum NPC por perto."
            if n then for _, t in ipairs(n:GetChildren()) do if t:IsA("Tool") then lines[#lines + 1] = "  " .. t.Name end end end
        else
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ls = toolLines(pl)
                    if #ls > 0 then lines[#lines + 1] = pl.Name .. ":"; for _, l in ipairs(ls) do lines[#lines + 1] = "  " .. l end end
                end
            end
        end
        invLabel.Text = table.concat(lines, "\n")
    end
    task.spawn(function()
        local guard = {}
        while Actions.alive do
            if INV.on and not Library.Panic then
                Actions.guardStep("Ver inventário", guard, refreshInv, function()
                    INV.on = false
                    if invGui then invGui.Enabled = false end
                end)
            else
                guard = {}
            end
            task.wait(0.8)
        end
    end)
    local function setBackpackEnabled(v)
        pcall(function()
            if Actions.backpackOriginal == nil then
                Actions.backpackOriginal = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
            end
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, v)
        end)
    end
    -- Barra local genérica para Tools; não representa inventários próprios do jogo.
    local hotbar = { on = false, slots = {}, tools = {}, sources = {} }
    local function hotbarRefresh()
        if not hotbar.gui or not Actions.alive then return end
        local tools, seen = {}, {}
        for _, parent in pairs({ LP.Character, LP:FindFirstChildOfClass("Backpack") }) do
            if parent then
                for _, item in ipairs(parent:GetChildren()) do
                    if item:IsA("Tool") and not seen[item] then seen[item] = true; tools[#tools + 1] = item end
                end
            end
        end
        table.sort(tools, function(a, b) return string.lower(a.Name) < string.lower(b.Name) end)
        hotbar.tools = tools
        for i, button in ipairs(hotbar.slots) do
            local tool = tools[i]
            button.Visible = tool ~= nil and i <= Actions.getAdjustment("hotbarSlots")
            button.Text = tool and (tostring(i) .. "  " .. tool.Name) or ""
            button.BackgroundColor3 = tool and tool.Parent == LP.Character and Color3.fromRGB(130, 65, 20) or Color3.fromRGB(35, 35, 35)
        end
    end
    local function hotbarSources()
        for _, conn in ipairs(hotbar.sources) do conn:Disconnect() end
        table.clear(hotbar.sources)
        local function watch(parent)
            if parent then
                for _, sig in ipairs({ parent.ChildAdded, parent.ChildRemoved }) do
                    hotbar.sources[#hotbar.sources + 1] = Actions.connect(sig, function() task.defer(hotbarRefresh) end)
                end
            end
        end
        watch(LP.Character); watch(LP:FindFirstChildOfClass("Backpack"))
        hotbarRefresh()
    end
    local function applyHotbar(value)
        hotbar.on = value == true
        if hotbar.on and not hotbar.gui then
            hotbar.gui = Library:CreateRootGui("ScreenGui", { Name = "BBC_Hotbar", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900 })
            local bar = Instance.new("ScrollingFrame")
            bar.AnchorPoint = Vector2.new(0.5, 1); bar.Position = UDim2.new(0.5, 0, 1, -12)
            bar.Size = UDim2.new(0.8, 0, 0, 48); bar.BackgroundTransparency = 1; bar.BorderSizePixel = 0
            bar.ScrollingDirection = Enum.ScrollingDirection.X; bar.ScrollBarThickness = 3
            bar.CanvasSize = UDim2.fromOffset(8 * 78, 0); bar.Parent = hotbar.gui
            local layout = Instance.new("UIListLayout"); layout.FillDirection = Enum.FillDirection.Horizontal
            layout.Padding = UDim.new(0, 4); layout.Parent = bar
            for i = 1, 8 do
                local button = Instance.new("TextButton")
                button.LayoutOrder = i; button.Size = UDim2.fromOffset(74, 42); button.TextSize = 11
                button.TextColor3 = Color3.new(1, 1, 1); button.TextWrapped = true; button.Parent = bar
                hotbar.slots[i] = button
                Actions.connect(button.MouseButton1Click, function()
                    local tool = hotbar.tools[i]
                    local character = LP.Character
                    local hum = character and character:FindFirstChildOfClass("Humanoid")
                    local bp = LP:FindFirstChildOfClass("Backpack")
                    if not hotbar.on or Library.Panic or not hum or not tool then return end
                    if tool.Parent == character then hum:UnequipTools()
                    elseif tool.Parent == bp then hum:EquipTool(tool) end
                end)
            end
            Actions.connect(LP.CharacterAdded, function() task.defer(hotbarSources) end)
            Actions.connect(LP.ChildAdded, function(child) if child:IsA("Backpack") then task.defer(hotbarSources) end end)
            Actions.connect(LP.ChildRemoved, function(child) if child:IsA("Backpack") then task.defer(hotbarSources) end end)
            hotbarSources()
        end
        if hotbar.gui then hotbar.gui.Enabled = hotbar.on and not Library.Panic; hotbarRefresh() end
    end
    onCleanup(function()
        for _, conn in ipairs(hotbar.sources) do pcall(function() conn:Disconnect() end) end
        if hotbar.gui then pcall(function() hotbar.gui:Destroy() end) end
    end)
    local function toggleInv()
        INV.on = not INV.on
        if INV.on then refreshInv() else if invGui then invGui.Enabled = false end; setBackpackEnabled(INV.always) end
        say(INV.on and ("Inventário: " .. INV.mode) or "Inventário fechado.")
    end

    -- Saque só usa caminhos de prompt explícitos e autorizados para este PlaceId.
    local autoLoot = false
    function Actions.getLootConfig()
        local ok, id, paths = pcall(function()
            local env = type(getgenv) == "function" and getgenv() or nil
            local cfg = type(env) == "table" and env.BBC_CONFIG or nil
            if type(cfg) ~= "table" then return nil, nil end
            return cfg.LootPlaceId, cfg.LootPromptPaths
        end)
        if ok and Library.OperationGuard:validLootConfig(id, paths, game.PlaceId) then return paths end
        return nil
    end
    local function applyAutoLoot(v)
        if v and (not Actions.alive or not Library.Safety:allow("Saque automático", true)) then return false end
        if v and type(fireproximityprompt) ~= "function" then
            error("Saque automático requer suporte a fireproximityprompt no executor.")
        end
        if v and not Actions.getLootConfig() then
            error("Saque automático exige LootPlaceId e LootPromptPaths autorizados; consulte o README.")
        end
        autoLoot = v == true
        Actions.lootToken = (Actions.lootToken or 0) + 1
        local token = Actions.lootToken
        if not v then return end
        task.spawn(function()
            local guard = {}
            while Actions.alive and autoLoot and Actions.lootToken == token do
                if not Actions.guardStep("Saque automático", guard, function()
                    local paths = Actions.getLootConfig()
                    if not paths then error("configuração de saque inválida ou alterada") end
                    local ch = LP.Character
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local best, bestPart, bd = nil, nil, Actions.getAdjustment("lootDistance")
                    for _, path in ipairs(paths) do
                        local prompt = Library.OperationGuard:resolvePrompt(Workspace, path)
                        if prompt and prompt.Enabled then
                            local part = prompt.Parent
                            if part and part:IsA("Attachment") then part = part.Parent end
                            if part and part:IsA("Model") then part = part.PrimaryPart end
                            if part and part:IsA("BasePart") then
                                local dist = (part.Position - hrp.Position).Magnitude
                                if dist < bd and dist <= prompt.MaxActivationDistance then bd = dist; best, bestPart = prompt, part end
                            end
                        end
                    end
                    if best and best.Parent and best.Enabled and bestPart and bestPart.Parent
                        and (bestPart.Position - hrp.Position).Magnitude <= best.MaxActivationDistance
                        and Actions.alive and autoLoot and Actions.lootToken == token and Library.Safety:allow("Saque automático", true)
                        and Library.OperationGuard:take("loot", os.clock()) then
                        local ok, err = pcall(fireproximityprompt, best)
                        if not ok then
                            autoLoot = false
                            Library.Safety:disable("Saque automático")
                            warn("[BBC] Saque automático interrompido: " .. tostring(err))
                            say(tr("Ação interrompida após falha; veja o console."))
                        end
                    end
                end, function() autoLoot = false end) then break end
                task.wait(Actions.getAdjustment("lootInterval"))
            end
        end)
    end

    -- ===== campo de visão / zoom =====
    local CAM = { fov = 120, zoom = 5, zoomHeld = false }
    local zoomKeyName = "N"
    local function applyFov()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        Actions.setProperty(cam, "FieldOfView", CAM.zoomHeld and CAM.zoom or CAM.fov)
    end
    Actions.connections.zoom = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
        local kc = Enum.KeyCode[zoomKeyName]
        if not kc then return end
        local down = UserInputService:IsKeyDown(kc)
        if down ~= CAM.zoomHeld then CAM.zoomHeld = down; applyFov() end
    end))

    -- ===== painel do jogador =====
    local PANEL = { on = false }
    local panelGui, panelLabel
    local function ensurePanelGui()
        if panelGui and panelGui.Parent then return end
        panelGui = Library:CreateRootGui("ScreenGui", { Name = "BBCPlayers", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 900, Enabled = false })
        local f = Library.Internal.create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(260, 200), BorderSizePixel = 0 }, panelGui)
        Library.Internal.bind(f, "BackgroundColor3", "Surface"); Library.Internal.corner(f, 5); Library.Internal.stroke(f, "Stroke", 0.3)
        local title = Library.Internal.create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 4), Text = "JOGADORES", TextSize = 12, FontFace = Library.Fonts.Bold }, f)
        Library.Internal.bind(title, "TextColor3", "Text")
        panelLabel = Library.Internal.create("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 26), Size = UDim2.new(1, -16, 1, -30), Text = "", TextSize = Actions.getAdjustment("panelTextSize"), FontFace = Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, f)
        Library.Internal.bind(panelLabel, "TextColor3", "Text")
    end
    local function refreshPanel()
        if not PANEL.on then if panelGui then panelGui.Enabled = false end; return end
        ensurePanelGui()
        panelGui.Enabled = true
        local cam = Workspace.CurrentCamera
        local lines = {}
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local d = hrp and math.floor((hrp.Position - cam.CFrame.Position).Magnitude * 0.28) or 0
                lines[#lines + 1] = pl.Name .. "  " .. d .. "m"
            end
        end
        panelLabel.Text = table.concat(lines, "\n")
    end
    task.spawn(function()
        local guard = {}
        while Actions.alive do
            if PANEL.on and not Library.Panic then
                Actions.guardStep("Painel do jogador", guard, refreshPanel, function()
                    PANEL.on = false
                    if panelGui then panelGui.Enabled = false end
                end)
            else
                guard = {}
            end
            task.wait(Actions.getAdjustment("panelInterval"))
        end
    end)

    local EXTRA_ACTIONS = {
        ["Troca rápida"] = function(v) applySwap(v) end,
        ["Modo pânico"] = function(v) if EXTRA.panicFn then EXTRA.panicFn(v) else Library.Panic = (v == true) end end,
        ["Remover efeitos"] = function(v) removeEffects(v) end,
        ["Avisos de entrada"] = function(v) applyJoinAlerts(v) end,
        ["Criador"] = function(v) applyRole("Criador", v) end,
        ["Testador"] = function(v) applyRole("Testador", v) end,
        ["Moderador"] = function(v) applyRole("Moderador", v) end,
        ["Trapaceiro"] = function(v) applyRole("Trapaceiro", v) end,
        ["Jump"] = function(v) SOUND_TOGGLES["Jump"] = v end,
        ["Pegadas"] = function(v) SOUND_TOGGLES["Pegadas"] = v end,
        ["Pouso"] = function(v) SOUND_TOGGLES["Pouso"] = v end,
        ["Capacete"] = function(v) SOUND_TOGGLES["Capacete"] = v end,
        ["Tiro na cabeça"] = function(v) SOUND_TOGGLES["Tiro na cabeça"] = v end,
        ["Tiro no corpo"] = function(v) SOUND_TOGGLES["Tiro no corpo"] = v end,
        ["Abate"] = function(v) SOUND_TOGGLES["Abate"] = v end,
        ["Disparo"] = function(v) SOUND_TOGGLES["Disparo"] = v end,
        ["Acerto com sangue"] = function(v) SOUND_TOGGLES["Acerto com sangue"] = v end,
        ["Saque automático"] = function(v) applyAutoLoot(v) end,
        ["Painel do jogador"] = function(v) PANEL.on = v == true; if not v and panelGui then panelGui.Enabled = false end end,
        ["Sempre mostrar"] = function(v) INV.always = v == true; if v then setBackpackEnabled(true) end end,
        ["Mochila"] = function(v) setBackpackEnabled(v) end,
        ["Barra rápida"] = function(v) applyHotbar(v) end,
    }

    -- ===== aparência do personagem (MÃOS E ARMA) =====
    local CHAR = { offset = nil, first = false, anim = "Swish", charVisible = false, handsVisible = false, heldVisible = false }
    local function charParts(char, filter)
        local t = {}
        if not char then return t end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") and (not filter or filter(d)) then t[#t + 1] = d end
        end
        return t
    end
    local function applyCharVisible(v)
        CHAR.charVisible = v == true
        for _, d in ipairs(charParts(LP.Character, function(d) return d.Name ~= "HumanoidRootPart" end)) do
            pcall(function() Actions.setProperty(d, "Transparency", v and Actions.getAdjustment("charTransparency") or 1) end)
        end
    end
    local function applyHands(v)
        CHAR.handsVisible = v == true
        for _, d in ipairs(charParts(LP.Character, function(d)
            local n = string.lower(d.Name)
            return string.find(n, "arm", 1, true) or string.find(n, "hand", 1, true) or string.find(n, "bra", 1, true)
        end)) do
            pcall(function() Actions.setProperty(d, "Transparency", v and Actions.getAdjustment("handTransparency") or 1) end)
        end
    end
    local function applyHeld(v)
        CHAR.heldVisible = v == true
        local ch = LP.Character
        local tool = ch and ch:FindFirstChildOfClass("Tool")
        if not tool then return end
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("BasePart") then pcall(function() Actions.setProperty(d, "Transparency", v and Actions.getAdjustment("heldTransparency") or 1) end) end
        end
    end
    local function stopOffset()
        if CHAR.offset then pcall(function() CHAR.offset:Destroy() end); CHAR.offset = nil end
    end
    local function applyOffset(v)
        stopOffset()
        if not v then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local ok, bp = pcall(function()
            local o = Instance.new("BodyPosition")
            o.Name = "BBC_Offset"
            o.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            o.P = 10000; o.D = 500
            o.Parent = hrp
            return o
        end)
        CHAR.offset = ok and bp or nil
        if CHAR.offset then
            local current = CHAR.offset
            task.spawn(function()
                local guard = {}
                while Actions.alive and CHAR.offset == current and current.Parent do
                    if not Actions.guardStep("Deslocamento", guard, function()
                        local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                        if h then current.Position = h.Position + h.CFrame.LookVector * Actions.getAdjustment("offsetDistance") end
                    end, stopOffset) then break end
                    task.wait()
                end
            end)
        end
    end
    -- Mostra somente partes corporais reconhecidas no cliente. Não interfere
    -- com cabeça, HumanoidRootPart, acessórios ou ferramentas.
    local function applyFirst(v)
        CHAR.first = v == true
        for _, conn in ipairs(CHAR.firstConns or {}) do pcall(function() conn:Disconnect() end) end
        CHAR.firstConns = {}
        if CHAR.firstDescConn then CHAR.firstDescConn:Disconnect(); CHAR.firstDescConn = nil end
        for part in pairs(CHAR.firstParts or {}) do Actions.restoreProperty(part, "LocalTransparencyModifier") end
        CHAR.firstParts = {}
        pcall(function()
            if CHAR.first then Actions.setProperty(LP, "CameraMode", Enum.CameraMode.LockFirstPerson)
            else Actions.restoreProperty(LP, "CameraMode") end
        end)
        if not CHAR.first or not Actions.alive then return end
        local names = { Torso = true, UpperTorso = true, LowerTorso = true,
            ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
            LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true, RightHand = true,
            LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true }
        local function attach(char)
            if not Actions.alive or not CHAR.first or LP.Character ~= char then return end
            if CHAR.firstDescConn then CHAR.firstDescConn:Disconnect(); CHAR.firstDescConn = nil end
            for part in pairs(CHAR.firstParts) do Actions.restoreProperty(part, "LocalTransparencyModifier") end
            CHAR.firstParts = {}
            local function add(part)
                if part.Parent == char and part:IsA("BasePart") and names[part.Name] then CHAR.firstParts[part] = true end
            end
            CHAR.firstDescConn = Actions.connect(char.ChildAdded, add)
            for _, part in ipairs(char:GetChildren()) do add(part) end
        end
        if LP.Character then attach(LP.Character) end
        CHAR.firstConns[#CHAR.firstConns + 1] = Actions.connect(LP.CharacterAdded, attach)
        CHAR.firstConns[#CHAR.firstConns + 1] = Actions.connect(RunService.RenderStepped, function()
            if not CHAR.first or Library.Panic then return end
            for part in pairs(CHAR.firstParts) do
                if part.Parent ~= LP.Character then
                    Actions.restoreProperty(part, "LocalTransparencyModifier")
                    CHAR.firstParts[part] = nil
                else
                    Actions.setProperty(part, "LocalTransparencyModifier", Actions.getAdjustment("firstPersonTransparency"))
                end
            end
        end)
    end
    local function playAnim()
        local ch = LP.Character
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not hum then say("Sem personagem."); return end
        local anim
        local animate = ch:FindFirstChild("Animate")
        local idle = animate and animate:FindFirstChild("idle")
        local searchRoot = CHAR.anim == "Padrão" and idle or ch
        if searchRoot then
            for _, item in ipairs(searchRoot:GetDescendants()) do
                if item:IsA("Animation") and item.AnimationId ~= "" and
                    (CHAR.anim == "Padrão" or string.lower(item.Name) == "swish") then
                    anim = item; break
                end
            end
        end
        if not anim then say("Animação selecionada não encontrada no personagem."); return end
        if CHAR.track then pcall(function() CHAR.track:Stop() end) end
        local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
        if not ok or not track then say("Não foi possível reproduzir."); return end
        local played = pcall(function() track:Play(0.1, CHAR.weight / 100, CHAR.speed) end)
        if not played then say("Não foi possível reproduzir a animação."); return end
        CHAR.track = track
        if CHAR.repeating then
            pcall(function()
                Actions.trackConn(Actions.connect(track.Ended, function()
                    if CHAR.repeating and CHAR.track == track then playAnim() end
                end))
            end)
        end
    end
    local CHAR_ACTIONS = {
        ["Personagem"] = function(v) applyCharVisible(v) end,
        ["Mãos"] = function(v) applyHands(v) end,
        ["Item na mão"] = function(v) applyHeld(v) end,
        ["Corpo em 1ª pessoa"] = function(v) applyFirst(v) end,
        ["Deslocamento"] = function(v) applyOffset(v) end,
        ["Reproduzir"] = function() playAnim() end,
        ["Repetir"] = function(v) CHAR.repeating = v == true end,
    }
    CHAR.speed, CHAR.weight, CHAR.repeating = 1, 100, false

    -- ===== COMBATE (mira, alvos, efeitos, anti-aim, granadas) =====
    -- Cada lógica tem sua trava: valores limitados, pcall em tudo que toca o
    -- jogo, verificação de pânico e desconexão ao desligar.
    local WEAPON = { recoil = 0.2 }
    local COMBAT = {
        on = false, activation = "Ao mirar", lock = false, predict = false,
        smooth = 0.08, smartPause = false, notify = true,
        radius = 70, fovDyn = true, aimPoint = "Partes selecionadas", parts = { ["Cabeça"] = true },
        npcs = true, throughWalls = true, maxChecks = 7, friends = {},
        reticle = false, circle = true, trail = false, gameTrails = false,
        hitMark = true, hitFx = true, dmgNumbers = true, killFx = false, targetData = true, confirmedOnly = true,
        antiAim = false, underGround = false, ghost = false,
        throwLine = false, noShake = true, reload = false, refill = false,
        peek = false, aura = false,
    }
    local AIM = { conn = nil, target = nil, lastKey = nil, sg = nil, ring = nil, mark = nil, label = nil, dmg = {} }
    local function clampCfg()
        COMBAT.radius = math.clamp(tonumber(COMBAT.radius) or 70, 10, 500)
        COMBAT.maxChecks = math.clamp(tonumber(COMBAT.maxChecks) or 7, 1, 20)
        COMBAT.smooth = math.clamp(tonumber(COMBAT.smooth) or 0.08, 0, 1)
    end
    clampCfg()

    local function ensureAimGui()
        if AIM.sg and AIM.sg.Parent then return end
        AIM.sg = Library:CreateRootGui("ScreenGui", { Name = "BBC_Aim", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 950, Enabled = true })
        local c = Library.Internal.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(Actions.getAdjustment("reticleSize"), Actions.getAdjustment("reticleSize")), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Visible = false }, AIM.sg)
        Library.Internal.corner(c, 3)
        AIM.dot = c
        AIM.ring = Library.Internal.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(140, 140), BackgroundTransparency = 1, Visible = false }, AIM.sg)
        Library.Internal.create("UICorner", { CornerRadius = UDim.new(1, 0) }, AIM.ring)
        AIM.ringStroke = Library.Internal.create("UIStroke", { Thickness = Actions.getAdjustment("ringThickness"), Transparency = 0.2, Color = Color3.fromRGB(255, 120, 30) }, AIM.ring)
        AIM.label = Library.Internal.create("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 110), Size = UDim2.fromOffset(220, 30), BackgroundTransparency = 1, Text = "", TextSize = Actions.getAdjustment("targetTextSize"), FontFace = Library.Fonts.Bold }, AIM.sg)
        Library.Internal.bind(AIM.label, "TextColor3", "Text")
        AIM.mark = Library.Internal.create("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Text = "✕", TextSize = 26, Visible = false, FontFace = Library.Fonts.Bold }, AIM.sg)
        Library.Internal.bind(AIM.mark, "TextColor3", "Accent")
    end

    local aimNpcs, aimNpcScan = {}, false
    local function aimNpcAdd(h)
        if Actions.alive and h:IsA("Humanoid") and h:IsDescendantOf(Workspace) then
            local m = h.Parent
            if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) and m ~= LP.Character then aimNpcs[m] = h end
        end
    end
    local function startAimNpcScan()
        if aimNpcScan then return end
        aimNpcScan = true
        Actions.trackConn(Actions.connect(Workspace.DescendantAdded, function(d) if d:IsA("Humanoid") then task.defer(aimNpcAdd, d) end end))
        Actions.trackConn(Actions.connect(Workspace.DescendantRemoving, function(d)
            aimNpcs[d] = nil
            if d:IsA("Humanoid") and d.Parent then aimNpcs[d.Parent] = nil end
        end))
        Library.StreamScan.start(Workspace, function() return Actions.alive end, aimNpcAdd)
    end
    local function aimTargets(cam, vp)
        local out = {}
        local n = 0
        local function add(m, hum, hrp, name, plr)
            if n >= COMBAT.maxChecks then return end
            if not (m and hum and hrp) then return end
            if hum.Health <= 0 then return end
            if plr and COMBAT.friends[plr] then return end
            n += 1
            out[#out + 1] = { m = m, hum = hum, hrp = hrp, name = name, plr = plr }
        end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                add(pl.Character, hum, hrp, (pl.DisplayName ~= "" and pl.DisplayName) or pl.Name, pl)
            end
            if n >= COMBAT.maxChecks then break end
        end
        if COMBAT.npcs then
            startAimNpcScan()
            for m, hum in pairs(aimNpcs) do
                if n >= COMBAT.maxChecks then break end
                if m.Parent and hum.Health > 0 and m ~= LP.Character then
                    local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    add(m, hum, hrp, m.Name, nil)
                end
            end
        end
        return out
    end
    local function partPosition(t)
        local m = t.m
        local function find(...)
            for _, n in ipairs({ ... }) do
                local p = m:FindFirstChild(n)
                if p and p:IsA("BasePart") then return p end
            end
            return nil
        end
        local p
        if COMBAT.aimPoint == "Mais próximo" then
            local best, bd = nil, math.huge
            local camPos = Workspace.CurrentCamera.CFrame.Position
            for _, d in ipairs(m:GetDescendants()) do
                if d:IsA("BasePart") and not d.Name:lower():find("root") then
                    local dist = (d.Position - camPos).Magnitude
                    if dist < bd then bd = dist; best = d end
                end
            end
            p = best
        else
            if COMBAT.parts["Cabeça"] then p = find("Head", "head") end
            if not p and COMBAT.parts["Corpo"] then p = find("UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart") end
            if not p and COMBAT.parts["Braços"] then p = find("LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm") end
            if not p and COMBAT.parts["Pernas"] then p = find("LeftUpperLeg", "RightUpperLeg", "Left Leg", "Right Leg") end
            if not p then p = find("HumanoidRootPart", "UpperTorso", "Torso", "Head") end
        end
        return p
    end
    local function isVisible(from, to, target)
        if COMBAT.throughWalls and (to - from).Magnitude <= Actions.getAdjustment("ignoreObstacleDistance") then return true end
        local ok, res = pcall(function()
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = { LP.Character }
            return Workspace:Raycast(from, to - from, rp)
        end)
        if not ok then
            if not Actions.raycastWarned then
                Actions.raycastWarned = true
                warn("[BBC] Verificação de obstáculos falhou; mira pausada enquanto estiver indisponível.")
            end
            return false
        end
        Actions.raycastWarned = false
        if not res then return true end
        return res.Instance ~= nil and res.Instance:IsDescendantOf(target.m)
    end
    -- Escala em pixels para manter aproximadamente o mesmo ângulo ao alterar o FOV.
    local function aimRadius(cam)
        if not COMBAT.fovDyn then return COMBAT.radius end
        local fov = math.clamp(tonumber(cam.FieldOfView) or 70, 1, 120)
        return math.clamp(COMBAT.radius * math.tan(math.rad(70 / 2)) / math.tan(math.rad(fov / 2)), 1, 2000)
    end
    local function pickTarget(cam, vp)
        local list = aimTargets(cam, vp)
        local cx, cy = vp.X / 2, vp.Y / 2
        local best, bestScore = nil, math.huge
        for _, t in ipairs(list) do
            local p = partPosition(t)
            if p then
                local sp = cam:WorldToViewportPoint(p.Position)
                if sp.Z > 0 then
                    local d = math.sqrt((sp.X - cx) ^ 2 + (sp.Y - cy) ^ 2)
                    local score = d
                    if d <= aimRadius(cam) and score < bestScore then
                        if COMBAT.smartPause and not isVisible(cam.CFrame.Position, p.Position, t) then continue end
                        bestScore = score; best = { t = t, pos = p.Position, dist = d }
                    end
                end
            end
        end
        return best
    end
    local function active()
        if not COMBAT.on or Library.Panic or not Actions.alive or not Library.Safety:allow("MIRA", true) then return false end
        if COMBAT.activation == "Ao mirar" then
            return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
        end
        return true
    end
    local function aimStep(dt)
        local camera = Workspace.CurrentCamera
        if AIM.ring and camera then
            local diameter = aimRadius(camera) * 2
            AIM.ring.Size = UDim2.fromOffset(diameter, diameter)
        end
        if not active() then
            AIM.visibleSince, AIM.visibleTarget = nil, nil
            AIM.target = nil
            if AIM.label then AIM.label.Text = "" end
            return
        end
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local cur = AIM.target
        if COMBAT.lock and cur and cur.t.hum.Health > 0 and cur.t.m.Parent then
            local p = partPosition(cur.t)
            if p then cur.pos = p.Position end
        else
            cur = pickTarget(cam, vp)
            local key = cur and cur.t.m or nil
            if COMBAT.notify and cur and key ~= AIM.lastKey then
                AIM.lastKey = key
                pcall(function() Library:Notify({ Title = "MIRA", Content = cur.t.name, Duration = Actions.getAdjustment("targetDuration") }) end)
            end
            AIM.target = cur
        end
        if not cur then AIM.visibleSince, AIM.visibleTarget = nil, nil; return end
        local p = partPosition(cur.t)
        if not p then return end
        local pos = p.Position
        if COMBAT.predict then
            local vel = cur.t.hrp.AssemblyLinearVelocity
            pos = pos + vel * math.clamp((pos - cam.CFrame.Position).Magnitude / 800, 0, 0.25)
        end
        -- compensação de recuo: mira um pouco acima conforme o ajuste
        if WEAPON.recoil > 0 then
            pos = pos + Vector3.new(0, WEAPON.recoil * math.clamp((pos - cam.CFrame.Position).Magnitude * 0.01, 0, 1.5), 0)
        end
        if COMBAT.smartPause then
            if not isVisible(cam.CFrame.Position, pos, cur.t) then AIM.visibleSince, AIM.visibleTarget = nil, nil; return end
            if AIM.visibleTarget ~= cur.t.m then AIM.visibleTarget = cur.t.m; AIM.visibleSince = os.clock() end
            if os.clock() - (AIM.visibleSince or os.clock()) < Actions.getAdjustment("pauseResume") then return end
        else
            AIM.visibleSince, AIM.visibleTarget = nil, nil
        end
        local look = (pos - cam.CFrame.Position).Unit
        local now = cam.CFrame.LookVector
        local alpha = math.clamp((1 - COMBAT.smooth) * (dt * 60), 0.01, 0.3)
        local newLook = now:Lerp(look, alpha).Unit
        pcall(function()
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + newLook)
        end)
        if AIM.label then
            AIM.label.Text = COMBAT.targetData and (cur.t.name .. "  " .. math.floor((pos - cam.CFrame.Position).Magnitude * 0.28) .. "m") or ""
        end
    end
    local function applyAimState()
        if AIM.conn then AIM.conn:Disconnect(); AIM.conn = nil end
        if not COMBAT.on or not Actions.alive or not Library.Safety:allow("MIRA", true) then
            COMBAT.on = false
            if AIM.dot then AIM.dot.Visible = false end
            if AIM.ring then AIM.ring.Visible = false end
            if AIM.label then AIM.label.Text = "" end
            return
        end
        ensureAimGui()
        if AIM.dot then AIM.dot.Visible = COMBAT.reticle end
        if AIM.ring then AIM.ring.Visible = COMBAT.circle end
        Actions.aimErrors = 0
        AIM.conn = Actions.trackConn(Actions.connect(RunService.RenderStepped, function(dt)
            local ok, err = pcall(aimStep, math.min(dt, 0.05))
            if ok then Actions.aimErrors = 0; return end
            Actions.aimErrors += 1
            if Actions.aimErrors == 1 then
                warn("[BBC] Mira: " .. tostring(err))
                if Library.Diagnostics then Library.Diagnostics:record("mira", err) end
            end
            if Actions.aimErrors >= 5 then
                Library.Safety:disableTracked()
                pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = "Mira interrompida após erros; veja o console.", Duration = 5 }) end)
            end
        end))
    end

    -- efeitos de combate na tela
    local function flashMark()
        if not Actions.alive or Library.Panic or not COMBAT.hitMark then return end
        ensureAimGui()
        AIM.markToken = (AIM.markToken or 0) + 1
        local token = AIM.markToken
        AIM.mark.Visible = true
        task.delay(Actions.getAdjustment("hitDuration"), function()
            if AIM.mark and AIM.markToken == token then AIM.mark.Visible = false end
        end)
    end
    local function spawnDmg(part, amount)
        if not COMBAT.dmgNumbers or not part then return end
        pcall(function()
            local item = table.remove(AIM.dmg)
            if not item then
                local gui = Instance.new("BillboardGui")
                Library:ProtectGui(gui)
                gui.Size = UDim2.fromOffset(90, 28)
                gui.StudsOffset = Vector3.new(0, 2, 0)
                gui.AlwaysOnTop = true
                gui.LightInfluence = 0
                local l = Instance.new("TextLabel")
                l.BackgroundTransparency = 1
                l.Size = UDim2.fromScale(1, 1)
                l.FontFace = Library.Fonts.Bold
                l.TextSize = Actions.getAdjustment("damageTextSize")
                l.TextColor3 = Color3.fromRGB(255, 80, 60)
                l.TextStrokeTransparency = 0.4
                l.Parent = gui
                item = { gui = gui, label = l }
            end
            item.label.Text = "-" .. tostring(math.floor(amount))
            item.label.TextTransparency = 0
            item.label.TextStrokeTransparency = 0.4
            item.gui.Adornee = part
            item.gui.Enabled = true
            Library:ParentGui(item.gui)
            game:GetService("TweenService"):Create(item.label, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
            task.delay(0.75, function()
                pcall(function() item.gui:Destroy() end)
            end)
        end)
    end

    -- Realce local temporário; não afirma que o servidor confirmou um acerto.
    Actions.hitFxObjects = {}
    function Actions.clearHitEffects()
        for object in pairs(Actions.hitFxObjects) do pcall(function() object:Destroy() end) end
        table.clear(Actions.hitFxObjects)
    end
    local function showHitEffect(character)
        if not Actions.alive or Library.Panic or not COMBAT.hitFx or not character or not character.Parent then return end
        local count = 0
        for _ in pairs(Actions.hitFxObjects) do count += 1 end
        if count >= 8 then return end
        local ok, object = pcall(function()
            local h = Instance.new("Highlight")
            h.Name = "BBC_HitEffect"
            h.FillColor = Color3.fromRGB(255, 120, 30)
            h.FillTransparency = Actions.getAdjustment("hitFxTransparency")
            h.OutlineTransparency = 1
            h.DepthMode = Enum.HighlightDepthMode.Occluded
            h.Parent = character
            return h
        end)
        if not ok or not object then return end
        Actions.hitFxObjects[object] = true
        task.delay(Actions.getAdjustment("hitFxDuration"), function()
            Actions.hitFxObjects[object] = nil
            pcall(function() object:Destroy() end)
        end)
    end

    -- acerto/eliminação: marca, efeito e número de dano
    local dmgLast = setmetatable({}, { __mode = "k" })
    local function hookCombatFx(plr)
        local charConn, addedConn, removingConn, ancestryConn
        local function disconnectCharacter()
            if charConn then charConn:Disconnect(); charConn = nil end
        end
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if not Actions.alive or plr.Parent ~= Players or plr.Character ~= char or not hum then return end
            dmgLast[hum] = hum.Health
            disconnectCharacter()
            charConn = Actions.connect(hum.HealthChanged,  function(h)
                local tag = hum:FindFirstChild("creator")
                if COMBAT.confirmedOnly and not (tag and tag.Value == LP) then dmgLast[hum] = h; return end
                if h >= (dmgLast[hum] or h) then dmgLast[hum] = h; return end
                if Library.Panic then dmgLast[hum] = h; return end
                showHitEffect(char)
                if h <= 0 then
                    if COMBAT.killFx then pcall(function() Library:Notify({ Title = "COMBATE", Content = "Eliminação: " .. plr.Name, Duration = Actions.getAdjustment("killDuration") }) end) end
                    dmgLast[hum] = h
                    return
                end
                local dmg = math.max((dmgLast[hum] or h) - h, 0)
                dmgLast[hum] = h
                if COMBAT.hitMark then flashMark() end
                local part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
                spawnDmg(part, dmg)
            end)
        end
        if plr.Character then task.spawn(onChar, plr.Character) end
        addedConn = Actions.connect(plr.CharacterAdded, onChar)
        removingConn = Actions.connect(plr.CharacterRemoving, disconnectCharacter)
        ancestryConn = Actions.connect(plr.AncestryChanged, function(_, parent)
            if parent then return end
            disconnectCharacter()
            if addedConn then addedConn:Disconnect() end
            if removingConn then removingConn:Disconnect() end
            if ancestryConn then ancestryConn:Disconnect() end
        end)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookCombatFx(p) end
    Actions.trackConn(Actions.connect(Players.PlayerAdded, hookCombatFx))

    -- aura letal
    local auraConn = nil
    local function auraStep()
        if not Actions.alive or not Library.Safety:allow("Aura letal", true) then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character and not COMBAT.friends[pl] then
                local h = pl.Character:FindFirstChildOfClass("Humanoid")
                local p = pl.Character:FindFirstChild("HumanoidRootPart")
                if h and p and h.Health > 0 then
                    local d = (p.Position - hrp.Position).Magnitude
                    if d <= Actions.getAdjustment("auraRange") then pcall(function() h:TakeDamage(4) end) end
                end
            end
        end
    end
    local function applyAura(v)
        Actions.auraToken = (Actions.auraToken or 0) + 1
        local token = Actions.auraToken
        if not v then COMBAT.aura = false; return end
        auraConn = task.spawn(function()
            local guard = {}
            while Actions.alive and COMBAT.aura and Actions.auraToken == token do
                if not Library.Panic and not Actions.guardStep("Aura letal", guard, auraStep, function() COMBAT.aura = false end) then break end
                task.wait(0.5)
            end
        end)
    end

    -- espiada subterrânea / anti-aim / sob o chão / fantasma / sem tremor
    local camConn, charConn = nil, nil
    local function applyPeek(v)
        COMBAT.peek = v == true
        if COMBAT.peek then
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.setProperty(hum, "CameraOffset", Vector3.new(0, -Actions.getAdjustment("peekDepth"), 0)) end
            end)
        else
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.restoreProperty(hum, "CameraOffset") end
            end)
        end
    end
    local function applyGhost(v)
        COMBAT.ghost = v == true
        local ch = LP.Character
        if not ch then return end
        for _, d in ipairs(ch:GetDescendants()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                if COMBAT.ghost then Actions.setProperty(d, "Transparency", Actions.getAdjustment("ghostTransparency"))
                else Actions.restoreProperty(d, "Transparency") end
            end
        end
    end
    local function applyAntiAim(v)
        COMBAT.antiAim = v == true
        if camConn then camConn:Disconnect(); camConn = nil end
        if not v then return end
        camConn = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
            if not COMBAT.antiAim or Library.Panic then return end
            pcall(function()
                local ch = LP.Character
                local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, 0, math.rad(Actions.getAdjustment("spinDegrees"))) end
            end)
        end))
    end
    local function applyUnderGround(v)
        COMBAT.underGround = v == true
        if charConn then charConn:Disconnect(); charConn = nil end
        if not v then
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.restoreProperty(hum, "HipHeight") end
            end)
            return
        end
        charConn = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
            if not COMBAT.underGround or Library.Panic then return end
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.setProperty(hum, "HipHeight", Actions.getAdjustment("undergroundHeight")) end
            end)
        end))
    end
    local function applyNoShake(v)
        COMBAT.noShake = v == true
        if COMBAT.noShake then
            pcall(function()
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then Actions.setProperty(hum, "CameraOffset", Vector3.zero) end
            end)
        end
    end

    -- recarga / cargadores
    local function equippedTool()
        local ch = LP.Character
        return ch and ch:FindFirstChildOfClass("Tool")
    end
    -- Apenas um caminho exato configurado para este jogo pode ser usado; nomes
    -- parecidos podem apontar para remotes não relacionados ou iscas.
    function Actions.getReloadPath()
        local ok, path = pcall(function()
            local env = type(getgenv) == "function" and getgenv() or nil
            local cfg = type(env) == "table" and env.BBC_CONFIG or nil
            return type(cfg) == "table" and cfg.ReloadRemotePath or nil
        end)
        if ok and Library.OperationGuard:validPath(path) then return path end
        return nil
    end
    local function doReload()
        if not Actions.alive or not Library.Safety:allow("Recarga automática", true) then return false end
        local tool = equippedTool()
        if not tool then return false end
        local remote = Library.OperationGuard:resolveRemote(tool, Actions.getReloadPath())
        if not remote then
            if not Actions.reloadPathWarned then
                Actions.reloadPathWarned = true
                say(tr("Recarga: caminho do RemoteEvent não encontrado na ferramenta."))
            end
            return false
        end
        Actions.reloadPathWarned = false
        if not Library.OperationGuard:take("reload", os.clock()) then return false end
        local ok, err = pcall(function() remote:FireServer() end)
        if not ok then
            COMBAT.reload = false
            Library.Safety:disable("Recarga automática")
            warn("[BBC] Recarga automática interrompida: " .. tostring(err))
            say(tr("Ação interrompida após falha; veja o console."))
        end
        return ok
    end
    local function doRefill()
        if not Actions.alive or not Library.Safety:allow("Abastecer cargadores", true) then return 0 end
        local n = 0
        local ch = LP.Character
        local bp = LP:FindFirstChild("Backpack")
        local function scan(parent)
            if not parent then return end
            for _, d in ipairs(parent:GetDescendants()) do
                if d:IsA("IntValue") or d:IsA("NumberValue") then
                    local low = string.lower(d.Name)
                    if string.find(low, "ammo", 1, true) or string.find(low, "mag", 1, true) or string.find(low, "clip", 1, true) then
                        pcall(function() d.Value = Actions.getAdjustment("refillValue") end); n += 1
                    end
                end
            end
        end
        scan(ch); scan(bp)
        return n
    end
    task.spawn(function()
        local guard = {}
        while Actions.alive do
            if COMBAT.reload and not Library.Panic then
                Actions.guardStep("Recarga automática", guard, doReload, function() COMBAT.reload = false end)
            else
                guard = {}
            end
            task.wait(Actions.getAdjustment("reloadInterval"))
        end
    end)

    -- trajetória do arremesso: linha de blocos à frente
    local throwParts = {}
    local function applyThrowLine(v)
        COMBAT.throwLine = v == true
        Actions.throwToken = (Actions.throwToken or 0) + 1
        local token = Actions.throwToken
        if not v then
            for _, p in ipairs(throwParts) do pcall(function() p:Destroy() end) end
            for i = 1, #throwParts do throwParts[i] = nil end
            return
        end
        task.spawn(function()
            local guard = {}
            while Actions.alive and COMBAT.throwLine and Actions.throwToken == token do
                if not Actions.guardStep("Trajetória do arremesso", guard, function()
                    for _, p in ipairs(throwParts) do pcall(function() p:Destroy() end) end
                    for i = 1, #throwParts do throwParts[i] = nil end
                    local ch = LP.Character
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local dir = hrp.CFrame.LookVector
                        for i = 1, 10 do
                            local p = Instance.new("Part")
                            throwParts[#throwParts + 1] = p
                            p.Name = "BBC_Throw"
                            p.Anchored = true; p.CanCollide = false; p.CanQuery = false
                            p.Size = Vector3.new(0.3, 0.3, 0.3)
                            p.Material = Enum.Material.Neon
                            p.Color = Color3.fromRGB(255, 200, 90)
                            p.Transparency = 0.4
                            local t = i / 10
                            p.Position = hrp.Position + dir * (i * Actions.getAdjustment("throwRange") / 10) + Vector3.new(0, 2 - 6 * t * t, 0)
                            p.Parent = Workspace
                        end
                    end
                end, function() COMBAT.throwLine = false end) then break end
                task.wait(0.2)
            end
        end)
    end

    -- rastros do jogo: esconde trilhas/feixes do mundo
    local trailFx = { built = false, a0 = nil, a1 = nil, t = nil }
    local function applyTrail(v)
        COMBAT.trail = v == true
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        if not (ch and hrp) then return end
        if not trailFx.built then
            trailFx.built = true
            trailFx.a0 = Instance.new("Attachment"); trailFx.a1 = Instance.new("Attachment")
            trailFx.a0.Position = Vector3.new(0, 1.5, 0); trailFx.a1.Position = Vector3.new(0, -1.5, 0)
            trailFx.t = Instance.new("Trail")
            trailFx.t.Lifetime = Actions.getAdjustment("trailLifetime")
            trailFx.t.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90))
            trailFx.t.WidthScale = NumberSequence.new(1)
            Actions.trackConn(Actions.connect(LP.CharacterAdded, function()
                task.defer(function()
                    local h = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if h then trailFx.a0.Parent = h; trailFx.a1.Parent = h; trailFx.t.Parent = h end
                end)
            end))
        end
        trailFx.a0.Parent = hrp; trailFx.a1.Parent = hrp; trailFx.t.Parent = hrp
        trailFx.t.Enabled = COMBAT.trail
    end
    local savedTrails = {}
    local function applyGameTrails(v)
        COMBAT.gameTrails = v == true
        pcall(function()
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("Trail") or d:IsA("Beam") then
                    if v then
                        if savedTrails[d] == nil then savedTrails[d] = d.Enabled end
                        d.Enabled = false
                    elseif savedTrails[d] ~= nil then
                        d.Enabled = savedTrails[d]
                    end
                end
            end
        end)
    end

    local COMBAT_ACTIONS = {
        ["Alvo fixo"] = function(v) COMBAT.lock = v end,
        ["Previsão"] = function(v) COMBAT.predict = v end,
        ["Pausa inteligente"] = function(v) COMBAT.smartPause = v end,
        ["Notificar"] = function(v) COMBAT.notify = v end,
        ["FOV dinâmico"] = function(v) COMBAT.fovDyn = v end,
        ["Mirar em NPCs"] = function(v) COMBAT.npcs = v end,
        ["Ignorar obstáculos na mira"] = function(v) COMBAT.throughWalls = v end,
        ["Espiada subterrânea"] = function(v) applyPeek(v) end,
        ["Aura letal"] = function(v) COMBAT.aura = v; applyAura(v) end,
        ["Recarga automática"] = function(v)
            if v and not Actions.getReloadPath() then
                say(tr("Recarga bloqueada: configure um caminho de RemoteEvent conhecido."))
                error("Recarga automática requer BBC_CONFIG.ReloadRemotePath; verifique o README.")
            end
            COMBAT.reload = v
        end,
        ["Abastecer cargadores"] = function(v) COMBAT.refill = v; if v then local n = doRefill(); say("Cargadores: " .. n) end end,
        ["Retícula"] = function(v) COMBAT.reticle = v; if AIM.dot then AIM.dot.Visible = v end end,
        ["Círculo da mira"] = function(v) COMBAT.circle = v; if AIM.ring then AIM.ring.Visible = v end end,
        ["Rastro personalizado"] = function(v) applyTrail(v) end,
        ["Rastros do jogo"] = function(v) applyGameTrails(v) end,
        ["Marca de acerto"] = function(v)
            COMBAT.hitMark = v
            if not v then AIM.markToken = (AIM.markToken or 0) + 1; if AIM.mark then AIM.mark.Visible = false end end
        end,
        ["Números de dano"] = function(v) COMBAT.dmgNumbers = v end,
        ["Efeitos de acerto"] = function(v) COMBAT.hitFx = v == true; if not v then Actions.clearHitEffects() end end,
        ["Efeitos de eliminação"] = function(v) COMBAT.killFx = v end,
        ["Dados do alvo"] = function(v) COMBAT.targetData = v end,
        ["Só acertos confirmados"] = function(v) COMBAT.confirmedOnly = v end,
        ["Anti aim"] = function(v) applyAntiAim(v) end,
        ["Sob o chão"] = function(v) applyUnderGround(v) end,
        ["Fantasma"] = function(v) applyGhost(v) end,
        ["Trajetória do arremesso"] = function(v) applyThrowLine(v) end,
        ["Sem tremor"] = function(v) applyNoShake(v) end,
    }

    -- limpeza total: chamada pelo "Sair" (stopEngine)
    onCleanup(function()
        Actions.clearHitEffects()
        applyFirst(false)
        COMBAT.on = false
        CHAR.repeating = false
        if CHAR.track then pcall(function() CHAR.track:Stop() end) end
        stopOffset()
        COMBAT.reload = false
        COMBAT.aura = false
        COMBAT.antiAim = false
        COMBAT.underGround = false
        COMBAT.throwLine = false
        COMBAT.peek = false
        COMBAT.trail = false
        if AIM.conn then pcall(function() AIM.conn:Disconnect() end); AIM.conn = nil end
        if AIM.sg then pcall(function() AIM.sg:Destroy() end); AIM.sg = nil end
        if camConn then pcall(function() camConn:Disconnect() end); camConn = nil end
        if charConn then pcall(function() charConn:Disconnect() end); charConn = nil end
        for _, item in pairs(trailFx) do if typeof(item) == "Instance" then pcall(function() item:Destroy() end) end end
        for _, p in ipairs(throwParts) do pcall(function() p:Destroy() end) end
        for i = 1, #throwParts do throwParts[i] = nil end
        INV.on = false
        PANEL.on = false
        if invGui then pcall(function() invGui:Destroy() end); invGui = nil end
        if panelGui then pcall(function() panelGui:Destroy() end); panelGui = nil end
        stopFly()
    end)

    -- ===== efeitos locais (aba VISUAIS > LOCAL) =====
    local LOCALFX = { aura = false, circle = false, halo = false, trail = false, master = true, ready = false, intensity = { aura = 50, circle = 50, halo = 50, trail = 50 } }
    local fx = { built = false }
    local function attachLocalFx()
        if not Actions.alive then return end
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local head = ch and ch:FindFirstChild("Head")
        if not (ch and hrp) then return end
        if fx.aura then fx.aura.Parent = hrp; fx.aura.Enabled = LOCALFX.master and LOCALFX.aura and not Library.Panic end
        if fx.halo then fx.halo.Parent = head or hrp; fx.halo.Enabled = LOCALFX.master and LOCALFX.halo and not Library.Panic end
        if fx.trail then fx.trailA0.Parent = hrp; fx.trailA1.Parent = hrp; fx.trail.Parent = hrp; fx.trail.Enabled = LOCALFX.master and LOCALFX.trail and not Library.Panic end
    end
    function Actions.setLocalFxIntensity(key, value)
        if LOCALFX.intensity[key] == nil or type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return false end
        value = math.clamp(value, 0, 100)
        LOCALFX.intensity[key] = value
        if key == "aura" and fx.aura then fx.aura.Brightness = 4 * value / 100 end
        if key == "halo" and fx.halo then fx.halo.Brightness = 3 * value / 100 end
        if key == "trail" and fx.trail then fx.trail.Lifetime = 0.1 + value / 100 end
        return true
    end
    local function ensureLocalFx()
        if fx.built then attachLocalFx(); return end
        fx.built = true
        fx.aura = Instance.new("PointLight")
        fx.aura.Color = Color3.fromRGB(255, 150, 60); fx.aura.Range = 14; fx.aura.Brightness = 2
        fx.halo = Instance.new("PointLight")
        fx.halo.Color = Color3.fromRGB(255, 220, 120); fx.halo.Range = 8; fx.halo.Brightness = 1.5
        fx.circle = Instance.new("Part")
        fx.circle.Name = "BBC_Circle"; fx.circle.Anchored = true; fx.circle.CanCollide = false; fx.circle.CanQuery = false
        fx.circle.Shape = Enum.PartType.Cylinder
        fx.circle.Size = Vector3.new(0.2, 10, 10); fx.circle.Material = Enum.Material.Neon
        fx.circle.Color = Color3.fromRGB(255, 170, 60); fx.circle.Transparency = 1
        fx.circle.Parent = Workspace
        fx.trailA0 = Instance.new("Attachment"); fx.trailA0.Position = Vector3.new(0, 1, 0)
        fx.trailA1 = Instance.new("Attachment"); fx.trailA1.Position = Vector3.new(0, -1, 0)
        fx.trail = Instance.new("Trail")
        fx.trail.Attachment0 = fx.trailA0; fx.trail.Attachment1 = fx.trailA1
        fx.trail.Lifetime = 0.6; fx.trail.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90))
        fx.trail.WidthScale = NumberSequence.new(1)
        for key, intensity in pairs(LOCALFX.intensity) do Actions.setLocalFxIntensity(key, intensity) end
        attachLocalFx()
        local function watchJump(ch)
            if Actions.fxJumpConn then pcall(function() Actions.fxJumpConn:Disconnect() end); Actions.fxJumpConn = nil end
            task.spawn(function()
                local hum = ch:FindFirstChildOfClass("Humanoid") or ch:WaitForChild("Humanoid", 5)
                if not Actions.alive or LP.Character ~= ch or not hum or not hum:IsA("Humanoid") then return end
                Actions.fxJumpConn = Actions.connect(hum.StateChanged, function(_, newState)
                    if newState == Enum.HumanoidStateType.Jumping and LOCALFX.master and LOCALFX.circle and not Library.Panic then
                        LOCALFX.jumpUntil = os.clock() + 0.65
                    end
                end)
            end)
        end
        if LP.Character then watchJump(LP.Character) end
        Actions.trackConn(Actions.connect(LP.CharacterAdded, function(ch) task.defer(attachLocalFx); watchJump(ch) end))
    end
    local function applyLocalFx(name, v)
        LOCALFX[name] = v == true
        ensureLocalFx()
        attachLocalFx()
    end
    Actions.connections.localFx = Actions.trackConn(Actions.connect(RunService.Heartbeat, function()
        if not fx.circle then return end
        if LOCALFX.master and LOCALFX.circle and not Library.Panic and os.clock() < (LOCALFX.jumpUntil or 0) then
            local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                fx.circle.CFrame = CFrame.new(hrp.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
                fx.circle.Transparency = math.clamp(1 - 0.011 * LOCALFX.intensity.circle, 0, 1)
            else
                fx.circle.Transparency = 1
            end
        else
            fx.circle.Transparency = 1
        end
    end))
    local LOCALFX_ACTIONS = {
        ["Aura"] = function(v) applyLocalFx("aura", v) end,
        ["Círculo de salto"] = function(v) applyLocalFx("circle", v) end,
        ["Auréola"] = function(v) applyLocalFx("halo", v) end,
        ["Rastro estelar"] = function(v) applyLocalFx("trail", v) end,
    }
    local function applyLocalFxAll(v)
        LOCALFX.master = v == true
        if not LOCALFX.ready then return end   -- ainda não havia as opções criadas
        if fx.built then attachLocalFx() end
    end

    -- A Home conserva seu estado em closures próprias, sem ocupar os registros
    -- usados pelo restante da inicialização das ações.
    local function initializeProfile()
        -- ---------- Persistência (executor com writefile) ----------
        local FOLDER = "BBC_HUB"
        local FILE = FOLDER .. "/perfil_" .. LP.UserId .. ".json"
        local data = { kills = 0, deaths = 0, damage = 0, played = 0, runs = 0 }
        local canFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
        if canFS then
            pcall(function()
                if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(FOLDER) then makefolder(FOLDER) end
            end)
            pcall(function()
                if isfile(FILE) then
                    for k, v in pairs(HttpService:JSONDecode(readfile(FILE))) do data[k] = v end
                end
            end)
        end
        data.runs = (tonumber(data.runs) or 0) + 1
        local function save()
            if canFS then pcall(writefile, FILE, HttpService:JSONEncode(data)) end
        end
        save()

        -- ---------- Rastreamento real ----------
        local function hookCharacter(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if not Actions.alive or LP.Character ~= char or not hum then return end
            local last = hum.Health
            Actions.trackConn(Actions.connect(hum.HealthChanged, function(h)
                if h < last then data.damage += last - h end
                last = h
            end))
            Actions.trackConn(Actions.connect(hum.Died, function()
                data.deaths += 1
                if MV.respawn then task.delay(Actions.getAdjustment("respawnDelay"), function() if Actions.alive and MV.respawn and not Library.Panic and LP.Character == char and hum.Health <= 0 then pcall(function() LP:LoadCharacter() end) end end) end
            end))
        end
        if LP.Character then task.spawn(hookCharacter, LP.Character) end
        Actions.trackConn(Actions.connect(LP.CharacterAdded, hookCharacter))

        -- Abates por tag "creator" (jogos que usam essa convenção)
        local function hookVictim(plr)
            if plr == LP then return end
            local charConn, addedConn, removingConn, ancestryConn
            local function disconnectCharacter()
                if charConn then charConn:Disconnect(); charConn = nil end
            end
            local function onChar(char)
                local hum = char:WaitForChild("Humanoid", 10)
                if not Actions.alive or plr.Parent ~= Players or plr.Character ~= char or not hum then return end
                disconnectCharacter()
                charConn = Actions.connect(hum.Died,  function()
                    local tag = hum:FindFirstChild("creator")
                    if tag and tag.Value == LP then data.kills += 1 end
                end)
            end
            if plr.Character then task.spawn(onChar, plr.Character) end
            addedConn = Actions.connect(plr.CharacterAdded, onChar)
            removingConn = Actions.connect(plr.CharacterRemoving, disconnectCharacter)
            ancestryConn = Actions.connect(plr.AncestryChanged, function(_, parent)
                if parent then return end
                disconnectCharacter()
                if addedConn then addedConn:Disconnect() end
                if removingConn then removingConn:Disconnect() end
                if ancestryConn then ancestryConn:Disconnect() end
            end)
        end
        for _, p in ipairs(Players:GetPlayers()) do hookVictim(p) end
        Actions.trackConn(Actions.connect(Players.PlayerAdded, hookVictim))

        local function leaderStat(patterns)
            local ls = LP:FindFirstChild("leaderstats")
            if not ls then return nil end
            for _, v in ipairs(ls:GetChildren()) do
                if v:IsA("ValueBase") then
                    local n = string.lower(v.Name)
                    for _, p in ipairs(patterns) do
                        if string.find(n, p, 1, true) then return tonumber(v.Value) end
                    end
                end
            end
            return nil
        end

        -- ---------- Leituras ----------
        local function fmtDuration(sec, withSeconds)
            sec = math.max(math.floor(sec), 0)
            local d = math.floor(sec / 86400)
            local h = math.floor(sec % 86400 / 3600)
            local m = math.floor(sec % 3600 / 60)
            local r = sec % 60
            if d > 0 then return d .. "d " .. h .. "h" end
            if h > 0 then return h .. "h " .. m .. "m" end
            if withSeconds then return m .. "m " .. r .. "s" end
            return m .. "m"
        end
        local function fmtBig(n)
            n = tonumber(n) or 0
            if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
            if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
            return tostring(math.floor(n))
        end
        local function getPing()
            local ok, v = pcall(function() return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() end)
            if ok and v then return math.floor(v) end
            local ok2, p = pcall(function() return LP:GetNetworkPing() * 1000 end)
            return ok2 and math.floor(p) or 0
        end
        local function getDevice()
            local kb = UserInputService.KeyboardEnabled
            if UserInputService.TouchEnabled and not kb then return tr("Celular") end
            if UserInputService.GamepadEnabled and not kb then return tr("Console") end
            return "PC"
        end
        local frames, fps = 0, 0
        Actions.trackConn(Actions.connect(RunService.RenderStepped, function() frames += 1 end))

        -- ---------- UI ----------
        local themed = {}
        local function th(inst, prop, key)
            themed[#themed + 1] = { inst, prop, key }
            inst[prop] = Library.Theme[key]
        end
        table.insert(Library._themeListeners, function()
            for _, t in ipairs(themed) do
                if t[1].Parent then t[1][t[2]] = Library.Theme[t[3]] end
            end
        end)
        local function mk(class, props, parent)
            local i = Instance.new(class)
            for k, v in pairs(props) do i[k] = v end
            i.Parent = parent
            return i
        end
        local function txt(parent, text, size, key, bold, extra)
            local l = mk("TextLabel", {
                BackgroundTransparency = 1, Text = text, TextSize = size,
                FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                Size = UDim2.new(1, 0, 0, size + 4),
            }, parent)
            th(l, "TextColor3", key or "Text")
            for k, v in pairs(extra or {}) do l[k] = v end
            return l
        end
        local function decorate(f, key, radius)
            th(f, "BackgroundColor3", key)
            f.BorderSizePixel = 0
            mk("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, f)
            th(mk("UIStroke", {}, f), "Color", "Stroke")
        end
        local function box(parent, title, order, size)
            local f = mk("Frame", { Size = size or UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, parent)
            decorate(f, "Surface2", 8)
            mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, f)
            mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
            local titleLabel = txt(f, string.upper(title), 12, "Muted", false, { LayoutOrder = 0 })
            return f, titleLabel
        end
        local function grid(parent, cols, order)
            local g = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order }, parent)
            mk("UIGridLayout", {
                CellPadding = UDim2.fromOffset(6, 6), CellSize = UDim2.new(1 / cols, -(6 * (cols - 1) / cols), 0, 46),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }, g)
            return g
        end
        local function cell(parent, title, order, big)
            local c = mk("Frame", { LayoutOrder = order }, parent)
            decorate(c, "Background", 6)
            txt(c, title, 12, "Muted", false, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 15) })
            local v = txt(c, "…", big or 16, "Text", true, { Position = UDim2.fromOffset(8, 20), Size = UDim2.new(1, -16, 0, 22) })
            return v, c
        end
        local function spark(parent)
            local W, H, N = 56, 22, 20
            local holder = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.fromOffset(W, H), ClipsDescendants = true }, parent)
            local segs, samples = {}, {}
            for i = 1, N - 1 do
                local sg = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Size = UDim2.fromOffset(0, 2), Visible = false }, holder)
                th(sg, "BackgroundColor3", "Accent")
                segs[i] = sg
            end
            return function(v)
                table.insert(samples, v)
                if #samples > N then table.remove(samples, 1) end
                local lo, hi = math.huge, -math.huge
                for _, x in ipairs(samples) do lo = math.min(lo, x); hi = math.max(hi, x) end
                if hi - lo < 1 then hi = lo + 1 end
                local off, step, pts = N - #samples, W / (N - 1), {}
                for i, x in ipairs(samples) do
                    pts[i] = Vector2.new((off + i - 1) * step, H - 2 - ((x - lo) / (hi - lo)) * (H - 4))
                end
                for i = 1, N - 1 do
                    local a, b = pts[i - off], pts[i - off + 1]
                    local sg = segs[i]
                    if a and b then
                        local d = b - a
                        sg.Visible = true
                        sg.Size = UDim2.fromOffset(d.Magnitude + 1, 2)
                        sg.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                        sg.Rotation = math.deg(math.atan2(d.Y, d.X))
                    else
                        sg.Visible = false
                    end
                end
            end
        end

        buildProfile = function(win, page, list)
            local root = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, list)
            mk("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, root)

            -- Identidade
            local idc = mk("Frame", { Size = UDim2.new(1, 0, 0, 78), LayoutOrder = 1 }, root)
            decorate(idc, "Surface2", 8)
            local avatar = mk("ImageLabel", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 0, BorderSizePixel = 0, ScaleType = Enum.ScaleType.Crop }, idc)
            th(avatar, "BackgroundColor3", "Surface3")
            mk("UICorner", { CornerRadius = UDim.new(0, 6) }, avatar)
            local thumb
            task.spawn(function()
                local ok, img = pcall(function()
                    return Players:GetUserThumbnailAsync(LP.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
                end)
                if ok and Actions.alive and avatar.Parent then thumb = img; avatar.Image = img end
            end)
            local nameL = txt(idc, LP.DisplayName, 20, "Text", true, { Position = UDim2.fromOffset(82, 12), Size = UDim2.new(1, -230, 0, 26) })
            local userL = txt(idc, "@" .. LP.Name, 15, "Muted", false, { Position = UDim2.fromOffset(82, 42), Size = UDim2.new(1, -230, 0, 20) })
            local badge = mk("TextLabel", {
                AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromOffset(0, 16), Size = UDim2.fromOffset(46, 20),
                BackgroundTransparency = 0.6, Text = ACCESS, TextSize = 12, FontFace = Library.Fonts.Bold,
            }, idc)
            decorate(badge, "Surface3", 4); th(badge, "TextColor3", "Text")
            local function placeBadge()
                badge.Position = UDim2.fromOffset(82 + nameL.TextBounds.X + 8, 15)
            end
            Actions.trackConn(Actions.connect(nameL:GetPropertyChangedSignal("TextBounds"), placeBadge)); placeBadge()
            local hidden = false
            local spy = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(44, 44), Text = "OCULTAR", TextSize = 9, AutoButtonColor = false, FontFace = Library.Fonts.Bold }, idc)
            decorate(spy, "Background", 6); th(spy, "TextColor3", "Text")
            Actions.trackConn(Actions.connect(spy.MouseButton1Click, function()
                hidden = not hidden
                pcall(function() win:SetHideName(hidden); win:SetHideAvatar(hidden) end)
                nameL.Text = hidden and "••••••" or LP.DisplayName
                userL.Text = hidden and "@••••••" or ("@" .. LP.Name)
                avatar.Image = hidden and "" or (thumb or "")
                th(spy, "TextColor3", hidden and "Accent" or "Text")
            end))

            -- Estatísticas
            local st = box(root, "Estatísticas", 2)
            local sg = grid(st, 6, 1)
            local vKills = cell(sg, "Abates", 1, 15)
            local vDeaths = cell(sg, "Mortes", 2, 15)
            local vKD = cell(sg, "Proporção K/D", 3, 15)
            local vRep = cell(sg, "Denúncias", 4, 15)
            local vPlayed = cell(sg, "Tempo jogado", 5, 15)
            local vDmg = cell(sg, "Dano recebido", 6, 15)
            th(vKD, "TextColor3", "Accent"); vRep.Text = "—"

            -- Sessão e Conta lado a lado
            local row = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3 }, root)
            mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, row)
            local ses = box(row, "Sessão", 1, UDim2.new(0.5, -5, 0, 0))
            local acc = box(row, "Conta", 2, UDim2.new(0.5, -5, 0, 0))
            local sgrid, agrid = grid(ses, 2, 1), grid(acc, 2, 1)
            local vFps, fpsCell = cell(sgrid, "FPS", 1)
            local vPing, pingCell = cell(sgrid, "Ping", 2)
            local vSess = cell(sgrid, "Tempo da sessão", 3)
            local vPlayers = cell(sgrid, "Jogadores", 4)
            local vDev = cell(sgrid, "Dispositivo", 5)
            local vRes = cell(sgrid, "Resolução", 6)
            local pushFps, pushPing = spark(fpsCell), spark(pingCell)
            local vAge = cell(agrid, "Idade da conta", 1)
            local vUid = cell(agrid, "ID do usuário", 2)
            local vRuns = cell(agrid, "Execuções", 3)
            local vAccess = cell(agrid, "Acesso", 4)
            local vLeft = cell(agrid, "Tempo restante", 5)
            local vVer = cell(agrid, "Versão do script", 6)

            -- Servidores
            local sv = box(root, "Servidores", 4)
            local svg = grid(sv, 3, 1)
            local vMap = cell(svg, "ID do mapa", 1)
            local vMapVer = cell(svg, "Versão do mapa", 2)
            local vJob = cell(svg, "ID do servidor", 3, 14)

            -- Acesso rápido é apenas navegação: não ativa uma função ao abrir.
            do
                local favorites = box(root, "Favoritos", 5)
                local description = txt(favorites, tr("Segure uma opção e toque em Favoritar."), 12, "Muted", false, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20) })
                local current = txt(favorites, "", 12, "Muted", false, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 20) })
                local slots = {}
                for i = 1, Library.Favorites.MAX do
                    local b = mk("TextButton", { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i + 2, Visible = false,
                        Text = "", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                        AutoButtonColor = false, FontFace = Library.Fonts.Regular }, favorites)
                    decorate(b, "Background", 4); th(b, "TextColor3", "Text")
                    local padding = mk("UIPadding", {}, b); padding.PaddingLeft = UDim.new(0, 8); padding.PaddingRight = UDim.new(0, 8)
                    local slot = { button = b }; slots[i] = slot
                    Actions.connect(b.MouseButton1Click, function() if slot.key then win:OpenFavorite(slot.key) end end)
                end
                local function renderFavorites()
                    if not root.Parent then return end
                    local items = Library.Favorites:get()
                    description.Visible = #items == 0
                    description.Text = tr("Segure uma opção e toque em Favoritar.")
                    current.Text = tr("Configuração ativa") .. ": " .. (win._cfgName or "—")
                    for i, slot in ipairs(slots) do
                        local key = items[i]
                        slot.key, slot.button.Visible = key, key ~= nil
                        if key then
                            local labelText = key
                            for _, d in ipairs(win._search or {}) do
                                if d.Parent and d:GetAttribute("SearchKey") == key and d:GetAttribute("SearchKind") == "Toggle" then
                                    labelText = tr(d:GetAttribute("SearchTab") or "") .. " · " .. tr(d:GetAttribute("SearchName") or "")
                                    break
                                end
                            end
                            slot.button.Text = labelText
                        end
                    end
                end
                win._refreshHomeFavorites = renderFavorites
                table.insert(Library.Favorites.listeners, renderFavorites)
                table.insert(onLanguageChanged, renderFavorites)
                renderFavorites()
            end
            do
                local recent, title = box(root, tr("Recentes nesta sessão"), 6)
                local empty = txt(recent, tr("Navegue pela busca ou favoritos para ver opções recentes."), 12, "Muted", false,
                    { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 20) })
                local slots = {}
                for i = 1, Library.RecentNavigation.MAX do
                    local b = mk("TextButton", { Size = UDim2.new(1, 0, 0, 32), LayoutOrder = i + 1, Visible = false,
                        Text = "", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                        AutoButtonColor = false, FontFace = Library.Fonts.Regular }, recent)
                    decorate(b, "Background", 4); th(b, "TextColor3", "Text")
                    local padding = mk("UIPadding", {}, b); padding.PaddingLeft = UDim.new(0, 8); padding.PaddingRight = UDim.new(0, 8)
                    local slot = { button = b }; slots[i] = slot
                    Actions.connect(b.MouseButton1Click, function() if slot.key then win:OpenFavorite(slot.key) end end)
                end
                local function renderRecent()
                    if not root.Parent then return end
                    local items = Library.RecentNavigation:get()
                    title.Text = string.upper(tr("Recentes nesta sessão"))
                    empty.Visible = #items == 0
                    empty.Text = tr("Navegue pela busca ou favoritos para ver opções recentes.")
                    for i, slot in ipairs(slots) do
                        local key = items[i]
                        slot.key, slot.button.Visible = key, key ~= nil
                        if key then
                            local text = key
                            for _, d in ipairs(win._search or {}) do
                                if d.Parent and d:GetAttribute("SearchKey") == key and d:GetAttribute("SearchKind") == "Toggle" then
                                    text = tr(d:GetAttribute("SearchTab") or "") .. " · " .. tr(d:GetAttribute("SearchName") or ""); break
                                end
                            end
                            slot.button.Text = text
                        end
                    end
                end
                table.insert(Library.RecentNavigation.listeners, renderRecent)
                table.insert(onLanguageChanged, renderRecent)
                renderRecent()
            end

            -- Valores estáticos (reais)
            vUid.Text = tostring(LP.UserId)
            vAge.Text = LP.AccountAge .. " " .. tr("dias")
            vAccess.Text = ACCESS
            vVer.Text = VERSION
            vDev.Text = getDevice()
            table.insert(onLanguageChanged, function() vDev.Text = getDevice(); vAge.Text = LP.AccountAge .. " " .. tr("dias") end)
            vMap.Text = tostring(game.PlaceId)
            vMapVer.Text = tostring(game.PlaceVersion)
            vJob.Text = (game.JobId ~= "" and game.JobId) or tr("Servidor local")
            vRuns.Text = tostring(data.runs)

            local started, lastSave, lastTick = os.clock(), os.clock(), os.clock()
            local function refresh()
                local now = os.clock()
                data.played += now - lastTick
                lastTick = now
                fps = frames; frames = 0
                local ping = getPing()
                vFps.Text = tostring(fps); pushFps(fps)
                vPing.Text = ping .. " ms"; pushPing(ping)
                vFps.TextColor3 = fps >= 50 and Library.Theme.Text or (fps >= 30 and Library.Theme.Warning or Library.Theme.Error)
                vPing.TextColor3 = ping <= 90 and Library.Theme.Text or (ping <= 180 and Library.Theme.Warning or Library.Theme.Error)
                vSess.Text = fmtDuration(now - started, true)
                vPlayers.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
                local cam = workspace.CurrentCamera
                if cam then vRes.Text = math.floor(cam.ViewportSize.X) .. " x " .. math.floor(cam.ViewportSize.Y) end
                local kills = leaderStat({ "kill", "abate", "elimin" }) or data.kills
                local deaths = leaderStat({ "death", "morte", "died" }) or data.deaths
                vKills.Text = tostring(kills)
                vDeaths.Text = tostring(deaths)
                vKD.Text = string.format("%.2f", kills / math.max(deaths, 1))
                vPlayed.Text = fmtDuration(data.played)
                vDmg.Text = fmtBig(data.damage)
                local expiry = Config.Expiry
                if type(expiry) == "function" then local ok, r = pcall(expiry); expiry = ok and r or nil end
                if type(expiry) == "number" then
                    local left = expiry - os.time()
                    vLeft.Text = left > 0 and fmtDuration(left) or tr("Expirado")
                else
                    vLeft.Text = tr("Ilimitado")
                end
                if now - lastSave >= 30 then lastSave = now; save() end
            end
            refresh()
            task.spawn(function()
                while Actions.alive and list.Parent do
                    task.wait(1)
                    if Actions.alive and list.Parent then pcall(refresh) end
                end
            end)
            Actions.trackConn(Actions.connect(Players.PlayerRemoving, function(p) if p == LP then save() end end))
        end
    end
    initializeProfile()

    -- Expor somente as referências utilizadas pelos módulos seguintes; os locais
    -- acima pertencem ao bloco e não ficam disponíveis fora dele automaticamente.
    -- Fallback independente dos toggles: se um callback de UI falhar ao
    -- desligar, ainda tentamos interromper estados, tarefas e efeitos locais.
    function Actions.stopRiskyWork()
        MV.speed, MV.sprint, MV.jumps, MV.air, MV.fly = false, false, false, false, false
        MV.noFall, MV.ground, MV.jesus, MV.spider = false, false, false, false
        MV.noDrown, MV.antiAfk, MV.respawn = false, false, false
        preFallHealth = nil
        swapOn, autoLoot = false, false
        Actions.swapToken = (Actions.swapToken or 0) + 1
        Actions.lootToken = (Actions.lootToken or 0) + 1
        COMBAT.on, COMBAT.reload, COMBAT.refill, COMBAT.aura = false, false, false, false
        COMBAT.antiAim, COMBAT.underGround, COMBAT.peek, COMBAT.throwLine = false, false, false, false
        WORLD.grama, WORLD.minas, WORLD.jogadores = false, false, false
        pcall(stopFly)
        pcall(Actions.restoreWalk)
        pcall(Actions.restoreSwim)
        pcall(stopOffset)
        pcall(applyAimState)
        pcall(applyAntiAim, false)
        pcall(applyUnderGround, false)
        pcall(applyPeek, false)
        pcall(applyThrowLine, false)
        pcall(applyGrama, false)
        pcall(applyMinas, false)
        pcall(removeEffects, false)
    end
    Library.Safety:trackStopper(Actions.stopRiskyWork)
    Actions.connect(LP.CharacterRemoving, function()
        if Actions.charSoundConn then Actions.charSoundConn:Disconnect(); Actions.charSoundConn = nil end
        Library.Safety:disableTracked()
    end)
    Actions.isAlive = function() return Actions.alive end
    Library.Safety:guardActions(PLAYER_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(WORLD_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(EXTRA_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(CHAR_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(LOCALFX_ACTIONS, Actions.isAlive)
    Library.Safety:guardActions(COMBAT_ACTIONS, Actions.isAlive)
    Actions.player, Actions.world, Actions.extra = PLAYER_ACTIONS, WORLD_ACTIONS, EXTRA_ACTIONS
    Actions.character, Actions.localfx, Actions.combat = CHAR_ACTIONS, LOCALFX_ACTIONS, COMBAT_ACTIONS
    Actions.EXTRA, Actions.LOCALFX, Actions.CAM, Actions.CHAR = EXTRA, LOCALFX, CAM, CHAR
    Actions.COMBAT, Actions.WEAPON, Actions.AIM, Actions.INV = COMBAT, WEAPON, AIM, INV
    Actions.WORLD, Actions.WORLD_COLORS = WORLD, WORLD_COLORS
    Actions.applyLocalFxAll, Actions.applyFov, Actions.playAnim = applyLocalFxAll, applyFov, playAnim
    Actions.applyAimState, Actions.clampCfg, Actions.say = applyAimState, clampCfg, say
    Actions.refreshAdjustment = function(key)
        if not Actions.alive then return end
        if key == "hotbarSlots" then hotbarRefresh() end
        if key == "panicZoneWidth" and Library._panicZone then Library._panicZone.Size = UDim2.fromOffset(Actions.getAdjustment(key), 56) end
        if key == "panelTextSize" and panelLabel then panelLabel.TextSize = Actions.getAdjustment(key) end
        if key == "bossOpacity" then for _, h in ipairs(bossHigh) do pcall(function() h.FillTransparency = Actions.getAdjustment(key) / 100 end) end end
        if key == "exitOpacity" then for _, h in ipairs(exitHigh) do pcall(function() h.FillTransparency = Actions.getAdjustment(key) / 100 end) end end
        if key == "waterTransparency" and WORLD.aguaOff then Actions.setProperty(Terrain, "WaterTransparency", Actions.getAdjustment(key)) end
        if key == "charTransparency" and CHAR.charVisible then applyCharVisible(true) end
        if key == "handTransparency" and CHAR.handsVisible then applyHands(true) end
        if key == "heldTransparency" and CHAR.heldVisible then applyHeld(true) end
        if key == "thirdZoom" and MV.third then applyCamera() end
        if key == "targetTextSize" and AIM.label then AIM.label.TextSize = Actions.getAdjustment(key) end
        if key == "reticleSize" and AIM.dot then
            local size = Actions.getAdjustment(key); AIM.dot.Size = UDim2.fromOffset(size, size)
        end
        if key == "ringThickness" and AIM.ringStroke then AIM.ringStroke.Thickness = Actions.getAdjustment(key) end
        if key == "trailLifetime" and trailFx.t then trailFx.t.Lifetime = Actions.getAdjustment(key) end
        if key == "ghostTransparency" and COMBAT.ghost then applyGhost(true) end
        if key == "peekDepth" and COMBAT.peek then applyPeek(true) end
        if key == "brightness" or key == "clockTime" or key == "shadowSoftness" or key == "fogDensity" or key == "haze"
            or key == "cloudCover" or key == "bloom" or key == "blur" or key == "saturation" or key == "contrast"
            or key == "focus" or key == "farIntensity" or key == "rays" or key == "raysSpread" or key == "shadowGearSoftness" or key == "skyStars" or key == "toneWarmth" then applyLighting() end
    end
    Actions.paintTerrain, Actions.paintPlants, Actions.applyLighting = paintTerrain, paintPlants, applyLighting
    Actions.setPanicVisuals = function(on)
        for _, h in ipairs(bossHigh) do pcall(function() h.Enabled = not on end) end
        for _, h in ipairs(exitHigh) do pcall(function() h.Enabled = not on end) end
        if on then
            AIM.markToken = (AIM.markToken or 0) + 1
            if AIM.mark then AIM.mark.Visible = false end
            Actions.clearHitEffects()
            for part in pairs(CHAR.firstParts or {}) do Actions.restoreProperty(part, "LocalTransparencyModifier") end
        end
        if invGui then invGui.Enabled = not on and INV.on end
        if panelGui then panelGui.Enabled = not on and PANEL.on end
        if hotbar.gui then hotbar.gui.Enabled = not on and hotbar.on end
        if trailFx.t then trailFx.t.Enabled = not on and COMBAT.trail end
        if fx.built then attachLocalFx() end
        if on and fx.circle then fx.circle.Transparency = 1 end
    end
    Actions.toggleInv, Actions.refreshInv, Actions.cleanups = toggleInv, refreshInv, CLEANUPS
    Actions.noclipPulse, Actions.setSoundId, Actions.sortBackpack = noclipPulse, setSoundId, sortBackpack
    Actions.setZoomKey = function(name) if type(name) == "string" and Enum.KeyCode[name] then zoomKeyName = name end end
    onCleanup(function()
        Actions.alive = false
        for conn in pairs(Actions.tracked) do pcall(function() conn:Disconnect() end) end
        table.clear(Actions.tracked)
        MV.antiAfk = false
        swapOn, autoLoot = false, false
        for _, conn in pairs(Actions.connections) do pcall(function() conn:Disconnect() end) end
        pcall(applyGameTrails, false)
        pcall(applyGrama, false)
        pcall(applyMinas, false)
        pcall(removeEffects, false)
        clearHigh(bossHigh); clearHigh(exitHigh)
        stopNoclip()
        if Actions.backpackOriginal ~= nil then
            pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, Actions.backpackOriginal) end)
        end
        for _, sound in pairs(soundObjs) do pcall(function() sound:Destroy() end) end
        for _, obj in pairs(FX) do pcall(function() obj:Destroy() end) end
        for mat, color in pairs(Actions.terrainColors or {}) do pcall(function() Terrain:SetMaterialColor(mat, color) end) end
        for obj, saved in pairs(Actions.originals) do
            for prop in pairs(saved) do Actions.restoreProperty(obj, prop) end
        end
        for _, obj in pairs(fx) do
            if typeof(obj) == "Instance" then pcall(function() obj:Destroy() end) end
        end
        Actions.restoreWalk(); Actions.restoreSwim()
    end)
end
initializeActions()


-- ============================================================
--  SERVIDORES (lista real da API pública do Roblox)
-- ============================================================
local buildServers
do
    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")
    local MarketplaceService = game:GetService("MarketplaceService")
    local LP = Players.LocalPlayer
    local themed = {}
    local function th(inst, prop, key) themed[#themed + 1] = { inst, prop, key }; inst[prop] = Library.Theme[key] end
    table.insert(Library._themeListeners, function()
        for _, t in ipairs(themed) do if t[1].Parent then t[1][t[2]] = Library.Theme[t[3]] end end
    end)
    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        i.Parent = parent
        return i
    end
    local function txt(parent, text, size, key, bold, extra)
        local l = mk("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size,
            FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Size = UDim2.new(1, 0, 0, size + 4) }, parent)
        th(l, "TextColor3", key or "Text")
        for k, v in pairs(extra or {}) do l[k] = v end
        return l
    end
    local function decorate(f, key, radius)
        th(f, "BackgroundColor3", key); f.BorderSizePixel = 0
        mk("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, f)
        th(mk("UIStroke", {}, f), "Color", "Stroke")
    end
    local function btn(parent, text, w, onClick, order)
        local b = mk("TextButton", { Size = UDim2.fromOffset(w, 28), Text = text, TextSize = 13, AutoButtonColor = false,
            FontFace = Library.Fonts.Bold, LayoutOrder = order or 0 }, parent)
        decorate(b, "Surface3", 6); th(b, "TextColor3", "Text")
        Actions.connect(b.MouseButton1Click, onClick)
        return b
    end

    local HIST_FILE = "BBC_HUB/historico_servidores.json"
    local history = {}
    pcall(function()
        if type(isfile) == "function" and isfile(HIST_FILE) then history = HttpService:JSONDecode(readfile(HIST_FILE)) end
    end)
    local function saveHistory()
        pcall(function()
            if type(writefile) == "function" then
                if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
                writefile(HIST_FILE, HttpService:JSONEncode(history))
            end
        end)
    end
    local mapName = "Servidor"
    task.spawn(function()
        local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
        if ok and info and info.Name then mapName = info.Name end
    end)

    buildServers = function(tab)
        local list = tab.List
        local root = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, list)
        mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, root)

        local state = { all = {}, sort = "players", desc = true, query = "", hideFull = true, hideMine = false, showHistory = false, selected = nil, loading = false, failed = false }

        -- Cabeçalho
        local head = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 }, root)
        local title = txt(head, "", 15, "Text", true, { Size = UDim2.new(0.5, 0, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
        local right = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.6, 0, 1, 0) }, head)
        mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, right)
        local bRefresh, bHistory, bFilters
        local filtersFrame

        -- Busca + ordenação
        local bar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2 }, root)
        local box = mk("TextBox", { Size = UDim2.new(1, -190, 1, 0), Text = "", TextSize = 13, ClearTextOnFocus = false,
            TextXAlignment = Enum.TextXAlignment.Left, FontFace = Library.Fonts.Regular }, bar)
        decorate(box, "Surface2", 6); th(box, "TextColor3", "Text"); th(box, "PlaceholderColor3", "Muted")
        mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, box)
        local sortBtn = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -34, 0, 0), Size = UDim2.fromOffset(150, 30), TextSize = 13,
            AutoButtonColor = false, FontFace = Library.Fonts.Bold, Text = "" }, bar)
        decorate(sortBtn, "Surface2", 6); th(sortBtn, "TextColor3", "Text")
        local dirBtn = mk("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(28, 30), TextSize = 16,
            AutoButtonColor = false, FontFace = Library.Fonts.Bold, Text = "↓" }, bar)
        decorate(dirBtn, "Surface2", 6); th(dirBtn, "TextColor3", "Accent")

        -- Colunas
        local cols = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4 }, root)
        local cName = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.34, 0, 1, 0), Position = UDim2.fromOffset(10, 0) })
        local cPing = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.15, 0, 1, 0), Position = UDim2.new(0.37, 0, 0, 0) })
        local cPl = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.17, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0) })
        local cFps = txt(cols, "", 12, "Muted", false, { Size = UDim2.new(0.12, 0, 1, 0), Position = UDim2.new(0.69, 0, 0, 0) })

        -- Lista com rolagem própria
        local scroller = mk("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 220), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
            CanvasSize = UDim2.new(), LayoutOrder = 5, ScrollingDirection = Enum.ScrollingDirection.Y }, root)
        th(scroller, "ScrollBarImageColor3", "Accent")
        local rowLayout = mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, scroller)
        mk("UIPadding", { PaddingRight = UDim.new(0, 8) }, scroller)
        Actions.connect(rowLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
            local sc = scroller.AbsoluteSize.Y > 0 and (scroller.AbsoluteSize.Y / 220) or 1
            scroller.CanvasSize = UDim2.fromOffset(0, rowLayout.AbsoluteContentSize.Y / math.max(sc, 0.05) + 4)
        end)

        -- Cartão de detalhes
        local det = mk("Frame", { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 6 }, root)
        decorate(det, "Surface2", 8)
        local detName = txt(det, "", 15, "Text", true, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -190, 0, 20) })
        local detSub = txt(det, "", 12, "Muted", false, { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -190, 0, 18) })
        local detBtns = mk("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(170, 28) }, det)
        mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, detBtns)
        local bDetails, bJoin

        local function shortId(id) return string.sub(id or "", 1, 13) end

        local function visibleList()
            local out = {}
            if state.showHistory then
                for _, h in ipairs(history) do table.insert(out, { id = h.id, playing = h.playing, maxPlayers = h.maxPlayers, ping = h.ping, fps = h.fps, when = h.when }) end
                return out
            end
            local q = string.lower(state.query)
            for _, sv in ipairs(state.all) do
                local pass = true
                if state.hideFull and sv.playing >= sv.maxPlayers then pass = false end
                if state.hideMine and sv.id == game.JobId then pass = false end
                if pass and q ~= "" then
                    local hay = string.lower(mapName .. " " .. sv.id .. " " .. sv.playing .. "/" .. sv.maxPlayers)
                    if not string.find(hay, q, 1, true) then pass = false end
                end
                if pass then table.insert(out, sv) end
            end
            local key = state.sort == "ping" and "ping" or (state.sort == "fps" and "fps" or "playing")
            table.sort(out, function(a, b)
                local x, y = tonumber(a[key]) or 0, tonumber(b[key]) or 0
                if x == y then return a.id < b.id end
                if state.desc then return x > y end
                return x < y
            end)
            return out
        end

        local function joinServer(sv)
            if not sv then return end
            table.insert(history, 1, { id = sv.id, playing = sv.playing, maxPlayers = sv.maxPlayers, ping = sv.ping, fps = sv.fps, when = os.time() })
            while #history > 30 do table.remove(history) end
            saveHistory()
            notify(tr("Entrando no servidor..."))
            Library:JoinServer(sv.id)
        end

        local function renderDetails()
            local sv = state.selected
            if not sv then
                detName.Text = mapName
                detSub.Text = tr("Pronto para entrar")
                return
            end
            detName.Text = mapName .. (sv.id == game.JobId and ("  •  " .. tr("Seu servidor")) or "")
            detSub.Text = tr("Pronto para entrar") .. "  ·  " .. string.sub(sv.id or "", 1, 22)
        end

        local render
        local function selectServer(sv) state.selected = sv; renderDetails(); render() end

        render = function()
            for _, c in ipairs(scroller:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
            for i = #themed, 1, -1 do if not themed[i][1].Parent then table.remove(themed, i) end end
            local items = visibleList()
            local total = #state.all
            title.Text = string.upper(tr("Servidor")) .. "   " .. #items .. " / " .. total .. " " .. tr("servidores")
            cName.Text = tr("Servidor"); cPing.Text = "Ping"; cPl.Text = tr("Jogadores"); cFps.Text = "FPS"
            sortBtn.Text = tr("Ordenar") .. ": " .. (state.sort == "players" and tr("Jogadores") or (state.sort == "ping" and "Ping" or "FPS"))
            dirBtn.Text = state.desc and "↓" or "↑"
            box.PlaceholderText = tr("Buscar mapa, nome ou ID do servidor")
            bRefresh.Text = tr("Atualizar"); bHistory.Text = tr("Histórico"); bFilters.Text = tr("Filtros")
            bDetails.Text = tr("Detalhes"); bJoin.Text = tr("Entrar")
            if state.loading then
                txt(scroller, tr("Carregando servidores..."), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
            elseif state.failed and not state.showHistory then
                txt(scroller, tr("Falha ao carregar a lista"), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
            elseif #items == 0 then
                txt(scroller, tr(state.showHistory and "Histórico vazio" or "Nenhum servidor encontrado"), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
            end
            for i, sv in ipairs(items) do
                if i > 150 then break end
                local row = mk("TextButton", { Size = UDim2.new(1, 0, 0, 44), Text = "", AutoButtonColor = false, LayoutOrder = i }, scroller)
                decorate(row, "Surface2", 6)
                local selected = state.selected and state.selected.id == sv.id
                if selected then th(row:FindFirstChildOfClass("UIStroke"), "Color", "Accent") end
                txt(row, mapName, 14, "Text", true, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.34, -10, 0, 18) })
                txt(row, (sv.id == game.JobId and (tr("Seu servidor") .. " · ") or "") .. shortId(sv.id), 11, "Muted", false, { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(0.34, -10, 0, 16) })
                local ping = tonumber(sv.ping)
                txt(row, ping and (math.floor(ping) .. " ms") or "—", 13, "Text", false, { Position = UDim2.new(0.37, 0, 0, 12), Size = UDim2.new(0.15, 0, 0, 18) })
                txt(row, (sv.playing or 0) .. "/" .. (sv.maxPlayers or 0), 13, "Text", false, { Position = UDim2.new(0.52, 0, 0, 12), Size = UDim2.new(0.17, 0, 0, 18) })
                local fps = tonumber(sv.fps)
                txt(row, fps and tostring(math.floor(fps)) or "—", 13, "Text", false, { Position = UDim2.new(0.69, 0, 0, 12), Size = UDim2.new(0.12, 0, 0, 18) })
                local full = (sv.playing or 0) >= (sv.maxPlayers or 0) and (sv.maxPlayers or 0) > 0
                local joinB = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(62, 28), Text = tr("Entrar"), TextSize = 13,
                    AutoButtonColor = false, FontFace = Library.Fonts.Bold, BorderSizePixel = 0, ZIndex = 3 }, row)
                th(joinB, "BackgroundColor3", full and "Surface3" or "Accent")
                th(joinB, "TextColor3", "Text")
                mk("UICorner", { CornerRadius = UDim.new(0, 5) }, joinB)
                Actions.connect(joinB.MouseButton1Click, function() state.selected = sv; renderDetails(); joinServer(sv) end)
                Actions.connect(row.MouseButton1Click, function() selectServer(sv) end)
            end
        end

        local function load()
            if state.loading then return end
            state.loading, state.failed = true, false
            render()
            task.spawn(function()
                local all, cursor = {}, nil
                for _ = 1, 3 do
                    if not Actions.alive then return end
                    local page, nextCursor = Library:FetchServers("Desc", cursor)
                    if not page then if #all == 0 then state.failed = true end break end
                    for _, sv in ipairs(page) do
                        if type(sv) == "table" and sv.id then
                            table.insert(all, { id = sv.id, playing = tonumber(sv.playing) or 0, maxPlayers = tonumber(sv.maxPlayers) or 0, ping = sv.ping, fps = sv.fps })
                        end
                    end
                    cursor = nextCursor
                    if not cursor then break end
                end
                if not Actions.alive then return end
                state.all, state.loading = all, false
                pcall(render)
            end)
        end

        bRefresh = btn(right, "", 88, function() state.showHistory = false; load() end, 3)
        bHistory = btn(right, "", 88, function() state.showHistory = not state.showHistory; render() end, 2)
        bFilters = btn(right, "", 78, function() filtersFrame.Visible = not filtersFrame.Visible end, 1)
        bDetails = btn(detBtns, "", 80, function()
            local sv = state.selected
            if not sv then return end
            local info = string.format("%s | %d/%d | %s ms | %s fps", sv.id, sv.playing or 0, sv.maxPlayers or 0, tostring(sv.ping and math.floor(sv.ping) or "—"), tostring(sv.fps and math.floor(sv.fps) or "—"))
            if not pcall(function() setclipboard(sv.id) end) then notify(info) else notify(tr("Copiar ID") .. ": " .. string.sub(sv.id, 1, 13)) end
        end, 1)
        bJoin = btn(detBtns, "", 80, function() joinServer(state.selected) end, 2)

        -- Filtros
        filtersFrame = mk("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, LayoutOrder = 3 }, root)
        decorate(filtersFrame, "Surface2", 6)
        mk("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, filtersFrame)
        mk("UIListLayout", { Padding = UDim.new(0, 6), FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder }, filtersFrame)
        local function filterToggle(key, label, order)
            local b = mk("TextButton", { Size = UDim2.fromOffset(150, 26), TextSize = 13, AutoButtonColor = false, FontFace = Library.Fonts.Regular, LayoutOrder = order, Text = "" }, filtersFrame)
            decorate(b, "Surface3", 6); th(b, "TextColor3", "Text")
            local function paint() b.Text = (state[key] and "● " or "○ ") .. tr(label) end
            paint()
            Actions.connect(b.MouseButton1Click, function() state[key] = not state[key]; paint(); render() end)
            table.insert(onLanguageChanged, paint)
        end
        filterToggle("hideFull", "Ocultar cheios", 1)
        filterToggle("hideMine", "Ocultar meu servidor", 2)

        Actions.connect(box:GetPropertyChangedSignal("Text"), function() state.query = box.Text; render() end)
        Actions.connect(sortBtn.MouseButton1Click, function()
            state.sort = state.sort == "players" and "ping" or (state.sort == "ping" and "fps" or "players")
            render()
        end)
        Actions.connect(dirBtn.MouseButton1Click, function() state.desc = not state.desc; render() end)
        table.insert(onLanguageChanged, function() renderDetails(); render() end)
        renderDetails()
        load()
    end
end
-- ============ 40_menu.luau :: Janela, registro de opções e auxiliares T/S ============
local Window = Library:Window({
    Title = "BBC HUB",
    Subtitle = "v0.0.8.2",
    Size = UDim2.fromOffset(640, 388),
    Keybind = "RightShift",
    Theme = "Orange",
    Home = { Build = buildProfile, Expiry = Config.Expiry },
})
Library._hubWindow = Window
if Library.Appearance and not Library.Appearance.writable then
    if Library.Diagnostics then Library.Diagnostics:record("aparência", "arquivo inválido preservado; salvamento visual bloqueado") end
    Library:Notify({ Title = "BBC HUB", Content = "Preferências visuais inválidas; arquivo preservado. Veja o diagnóstico.", Duration = 5 })
end
local IS_MOBILE = LangUIS.TouchEnabled and not (LangUIS.MouseEnabled or LangUIS.KeyboardEnabled)
if Actions.EXTRA and Actions.EXTRA.panicFn == nil then Actions.EXTRA.panicFn = function(v) Window:SetPanic(v) end end
Library:OnPanic(function(on)
    Library.Safety.panic = on
    if on then Library.Safety:disableTracked() end
    if Actions.AIM.sg then pcall(function() Actions.AIM.sg.Enabled = not on end) end
    pcall(Actions.setPanicVisuals, on)
end)
pcall(function() Window:SetToggleButton(true) end) -- botão flutuante para abrir/fechar (celular)

-- tradução automática de tudo que aparece na janela
do
    local gui = Window.Gui or Window.ScreenGui or Window.Root
    if gui then
        for _, d in ipairs(gui:GetDescendants()) do translateInstance(d) end
        Actions.connect(gui.DescendantAdded, function(d) task.defer(translateInstance, d) end)
        table.insert(onLanguageChanged, function()
            for _, d in ipairs(gui:GetDescendants()) do translateInstance(d) end
        end)
    else
        warn("[BBC HUB] não achei a ScreenGui da janela para traduzir")
    end
end

-- Engrenagens históricas permanecem acessíveis. Ajustes indisponíveis são
-- apresentados como pendentes, em vez de aceitar valores sem efeito.
local GEARS = {}
for _, name in ipairs({
    "Mochila personalizada", "Mochila", "Barra rápida", "Aura", "Círculo de salto", "Auréola", "Rastro estelar",
    "Hack de velocidade", "Sprint automático", "Voar", "Aranha", "Deslocamento", "Trocar personagem", "Personagem",
    "Corpo em 1ª pessoa", "Mãos", "Item na mão", "Terceira pessoa", "Câmera livre", "Saque automático", "Painel do jogador",
    "Renascer automático", "Remover água", "Pausa inteligente", "Ignorar obstáculos na mira", "Aura letal", "Espiada subterrânea",
    "Anti aim", "Sob o chão", "Fantasma", "Trajetória do arremesso", "Recarga automática", "Abastecer cargadores",
    "Mira falsa", "Retícula", "Círculo da mira", "Rastro personalizado", "Marca de acerto", "Números de dano", "Efeitos de acerto",
    "Efeitos de eliminação", "Dados do alvo", "Luz", "Hora e sol", "Sombras", "Renderização", "Neblina", "Atmosfera", "Céu", "Nuvens",
    "Florescer", "Desfoque", "Ajuste de cor", "Profundidade", "Raios de sol", "Tonalidade", "Buscar chefes", "Pontos de saída",
    "Modo pânico", "Avisos de entrada", "Avisos de denúncias", "Tiro por paredes", "Notificar", "Criador", "Testador", "Moderador", "Trapaceiro", "Jump", "Pegadas", "Pouso",
    "Capacete", "Tiro na cabeça", "Tiro no corpo", "Abate", "Disparo", "Acerto com sangue",
}) do GEARS[name] = true end

-- Cada ajuste é consumido pela respectiva lógica. Sem ajuste aplicável, não
-- criamos widgets fictícios. Valores são limitados de novo no setter.
local SETTINGS = {
    ["Corpo em 1ª pessoa"] = {{"firstPersonTransparency", "Transparência em primeira pessoa", 0, 1, 0, 0.05, ""}},
    ["Modo pânico"] = {{"panicTapWindow", "Intervalo dos três toques", 0.8, 3, 1.2, 0.1, " s"}, {"panicZoneWidth", "Largura da área de retorno", 100, 300, 140, 10, " px"}},
    ["Ignorar obstáculos na mira"] = {{"ignoreObstacleDistance", "Alcance para ignorar obstáculos", 0, 10000, 10000, 100, " st"}},
    ["Pausa inteligente"] = {{"pauseResume", "Tempo para retomar a mira", 0, 1, 0, 0.1, " s"}},
    ["Efeitos de acerto"] = {{"hitFxDuration", "Duração do efeito de acerto", 0.1, 1, 0.3, 0.1, " s"}, {"hitFxTransparency", "Transparência do efeito", 0, 1, 0.4, 0.05, ""}},
    ["Saque automático"] = {{"lootDistance", "Distância máxima do saque", 1, 14, 14, 1, " st"}, {"lootInterval", "Intervalo do saque", 2, 10, 2, 0.5, " s"}},
    ["Recarga automática"] = {{"reloadInterval", "Intervalo da recarga", 5, 30, 5, 1, " s"}},
    ["Abastecer cargadores"] = {{"refillValue", "Valor local de munição", 0, 999, 999, 1, ""}},
    ["Renascer automático"] = {{"respawnDelay", "Atraso para renascer", 0.5, 10, 0.5, 0.5, " s"}},
    ["Aura letal"] = {{"auraRange", "Alcance local da aura", 1, 12, 12, 1, " st"}},
    ["Buscar chefes"] = {{"bossOpacity", "Transparência dos chefes", 0, 100, 60, 5, "%"}},
    ["Pontos de saída"] = {{"exitOpacity", "Transparência das saídas", 0, 100, 60, 5, "%"}},
    ["Céu"] = {{"skyStars", "Número de estrelas", 0, 5000, 3000, 100, ""}},
    ["Sombras"] = {{"shadowGearSoftness", "Suavidade das sombras", 0, 1, 0.5, 0.05, ""}},
    ["Tonalidade"] = {{"toneWarmth", "Intensidade da tonalidade", 0, 100, 100, 5, "%"}},
    ["Remover água"] = {{"waterTransparency", "Transparência da água", 0, 1, 1, 0.05, ""}},
    ["Painel do jogador"] = {{"panelTextSize", "Tamanho do painel", 8, 24, 11, 1, ""}, {"panelInterval", "Intervalo do painel", 0.5, 5, 0.8, 0.1, " s"}},
    ["Personagem"] = {{"charTransparency", "Transparência do personagem", 0, 1, 0, 0.05, ""}},
    ["Mãos"] = {{"handTransparency", "Transparência das mãos", 0, 1, 0, 0.05, ""}},
    ["Item na mão"] = {{"heldTransparency", "Transparência do item", 0, 1, 0, 0.05, ""}},
    ["Criador"] = {{"roleCriador", "Duração do aviso", 1, 10, 4, 0.5, " s"}},
    ["Testador"] = {{"roleTestador", "Duração do aviso", 1, 10, 4, 0.5, " s"}},
    ["Moderador"] = {{"roleModerador", "Duração do aviso", 1, 10, 4, 0.5, " s"}},
    ["Trapaceiro"] = {{"roleTrapaceiro", "Duração do aviso", 1, 10, 4, 0.5, " s"}},
    ["Barra rápida"] = {{"hotbarSlots", "Número de espaços", 1, 8, 8, 1, ""}},
    ["Hack de velocidade"] = {{"speed", "Multiplicador", 1, 4, 2.2, 0.1, "x"}},
    ["Sprint automático"] = {{"sprint", "Multiplicador", 1, 4, 1.6, 0.1, "x"}},
    ["Voar"] = {{"fly", "Velocidade de voo", 10, 120, 60, 1, ""}},
    ["Aranha"] = {{"climb", "Velocidade de subida", 5, 80, 40, 1, ""}},
    ["Terceira pessoa"] = {{"thirdZoom", "Zoom máximo", 10, 500, 300, 10, ""}},
    ["Deslocamento"] = {{"offsetDistance", "Distância de deslocamento", 0, 10, 3, 0.5, ""}},
    ["Sob o chão"] = {{"undergroundHeight", "Altura do quadril", -10, 0, -6, 0.5, ""}},
    ["Anti aim"] = {{"spinDegrees", "Rotação por quadro", 0, 15, 6, 1, "°"}},
    ["Avisos de entrada"] = {{"joinDuration", "Duração do aviso", 1, 10, 3, 0.5, " s"}},
    ["Notificar"] = {{"targetDuration", "Duração do aviso", 1, 10, 1.2, 0.1, " s"}},
    ["Efeitos de eliminação"] = {{"killDuration", "Duração do aviso", 1, 10, 2, 0.5, " s"}},
    ["Dados do alvo"] = {{"targetTextSize", "Tamanho dos dados", 8, 24, 11, 1, ""}},
    ["Números de dano"] = {{"damageTextSize", "Tamanho dos números", 8, 30, 14, 1, ""}},
    ["Câmera livre"] = {{"cameraDistance", "Distância da câmera", 3, 40, 12, 1, ""}},
    ["Troca rápida"] = {{"swapInterval", "Intervalo da troca", 0.2, 5, 0.35, 0.05, " s"}},
    ["Espiada subterrânea"] = {{"peekDepth", "Profundidade da câmera", 0, 10, 4, 0.5, ""}},
    ["Fantasma"] = {{"ghostTransparency", "Transparência", 0, 1, 0.5, 0.05, ""}},
    ["Trajetória do arremesso"] = {{"throwRange", "Alcance da trajetória", 10, 100, 60, 5, ""}},
    ["Retícula"] = {{"reticleSize", "Tamanho da retícula", 2, 30, 5, 1, ""}},
    ["Círculo da mira"] = {{"ringThickness", "Espessura do círculo", 0.5, 5, 1.5, 0.5, ""}},
    ["Rastro personalizado"] = {{"trailLifetime", "Duração do rastro", 0.1, 3, 0.5, 0.1, " s"}},
    ["Marca de acerto"] = {{"hitDuration", "Duração da marca", 0.05, 1, 0.12, 0.01, " s"}},
    ["Luz"] = {{"brightness", "Brilho", 0, 10, 5, 0.5, ""}},
    ["Hora e sol"] = {{"clockTime", "Hora", 0, 24, 14, 0.5, " h"}},
    ["Renderização"] = {{"shadowSoftness", "Suavidade das sombras", 0, 1, 0.5, 0.05, ""}},
    ["Neblina"] = {{"fogDensity", "Densidade da neblina", 0, 1, 0.6, 0.05, ""}},
    ["Atmosfera"] = {{"haze", "Névoa da atmosfera", 0, 10, 0.4, 0.1, ""}},
    ["Nuvens"] = {{"cloudCover", "Cobertura das nuvens", 0, 1, 0.5, 0.05, ""}},
    ["Florescer"] = {{"bloom", "Intensidade do florescer", 0, 5, 0.8, 0.1, ""}},
    ["Desfoque"] = {{"blur", "Tamanho do desfoque", 0, 56, 12, 1, ""}},
    ["Ajuste de cor"] = {{"saturation", "Saturação", -1, 1, 0.25, 0.05, ""}, {"contrast", "Contraste", -1, 1, 0.1, 0.05, ""}},
    ["Profundidade"] = {{"focus", "Distância de foco", 0, 500, 60, 5, ""}, {"farIntensity", "Desfoque distante", 0, 1, 0.4, 0.05, ""}},
    ["Raios de sol"] = {{"rays", "Intensidade dos raios", 0, 1, 0.25, 0.05, ""}, {"raysSpread", "Dispersão dos raios", 0, 1, 0.6, 0.05, ""}},
}
GEARS["Troca rápida"] = true
local function notify(text)
    pcall(function() Library:Notify({ Title = "BBC HUB", Content = text, Duration = 2 }) end)
end

local function buildSettings(name)
    if name == "Aura" or name == "Auréola" or name == "Círculo de salto" or name == "Rastro estelar" then
        local key = ({ ["Aura"] = "aura", ["Auréola"] = "halo", ["Círculo de salto"] = "circle", ["Rastro estelar"] = "trail" })[name]
        return function(p)
            p:Slider({ Name = "Intensidade", Min = 0, Max = 100, Default = 50, Suffix = "%", Step = 1,
                Tooltip = Library.Internal.tipFor("Intensidade"), Callback = function(v) Actions.setLocalFxIntensity(key, v) end })
        end
    end
    local soundNames = { Jump = true, Pegadas = true, Pouso = true, Capacete = true, ["Tiro na cabeça"] = true,
        ["Tiro no corpo"] = true, Abate = true, Disparo = true, ["Acerto com sangue"] = true }
    if soundNames[name] then
        return function(p)
            p:Slider({ Name = "Volume", Min = 0, Max = 100, Default = 60, Step = 5, Suffix = "%",
                Tooltip = function() return Library.Internal.tipFor("Volume") end, Callback = function(v) Actions.setSoundVolume(name, v) end })
        end
    end
    return function(p)
        local options = SETTINGS[name]
        if not options then
            p:Label({ Text = name == "Mochila" and "Mochila nativa: sem ajustes específicos." or "Ajustes específicos ainda indisponíveis." })
            return
        end
        for _, spec in ipairs(options) do
            local key, label, min, max, default, step, suffix = table.unpack(spec)
            p:Slider({ Name = label, Min = min, Max = max, Default = default, Step = step, Suffix = suffix,
                Tooltip = function() return Library.Internal.tipFor(label) end, Callback = function(v) Actions.setAdjustment(key, v) end })
        end
    end
end

local PREMIUM = { ["Anti aim"] = true, ["Sob o chão"] = true, ["Espiada subterrânea"] = true, ["Saque automático"] = true, ["Sem dano de queda"] = true }
-- descrição de cada opção do menu nos 5 idiomas: aparece ao segurar (toque) ou passar o mouse
for k, v in pairs({
    ["Jogador"] = { pt = "ESP — silhueta laranja/vermelha de jogadores, com caixa fina, barra de vida e distância.", en = "ESP — orange/red silhouette of players, with a thin box, health bar and distance.", es = "ESP — silueta naranja/roja de jugadores, con caja fina, barra de vida y distancia.", zh = "ESP — 玩家橙色/红色轮廓，带细框、血条和距离。", ru = "ESP — оранжево-красный силуэт игроков с тонкой рамкой, полосой здоровья и дистанцией." },
    ["NPCs"] = { pt = "ESP — silhueta laranja/vermelha de NPCs, com caixa fina, barra de vida e distância.", en = "ESP — orange/red silhouette of NPCs, with a thin box, health bar and distance.", es = "ESP — silueta naranja/roja de NPCs, con caja fina, barra de vida y distancia.", zh = "ESP — NPC 橙色/红色轮廓，带细框、血条和距离。", ru = "ESP — оранжево-красный силуэт NPC с тонкой рамкой, полосой здоровья и дистанцией." },
    ["Corpo"] = { pt = "ESP — silhueta de corpos de jogadores mortos, com caixa fina e distância.", en = "ESP — silhouette of dead players' bodies, with a thin box and distance.", es = "ESP — silueta de cuerpos de jugadores muertos, con caja fina y distancia.", zh = "ESP — 死亡玩家尸体的轮廓，带细框和距离。", ru = "ESP — силуэт тел погибших игроков с тонкой рамкой и дистанцией." },
    ["Recipiente"] = { pt = "ESP — silhueta de recipientes e baús, com caixa fina, nome e distância.", en = "ESP — silhouette of containers and chests, with a thin box, name and distance.", es = "ESP — silueta de contenedores y cofres, con caja fina, nombre y distancia.", zh = "ESP — 容器和箱子的轮廓，带细框、名称和距离。", ru = "ESP — силуэт контейнеров и сундуков с тонкой рамкой, именем и дистанцией." },
    ["Item no chão"] = { pt = "ESP — silhueta de itens largados no chão, com caixa fina, nome e distância.", en = "ESP — silhouette of items dropped on the ground, with a thin box, name and distance.", es = "ESP — silueta de objetos en el suelo, con caja fina, nombre y distancia.", zh = "ESP — 地上掉落物品的轮廓，带细框、名称和距离。", ru = "ESP — силуэт предметов на земле с тонкой рамкой, именем и дистанцией." },
    ["Itens de missão"] = { pt = "ESP — silhueta dos itens de missão, com caixa fina, nome e distância.", en = "ESP — silhouette of quest items, with a thin box, name and distance.", es = "ESP — silueta de objetos de misión, con caja fina, nombre y distancia.", zh = "ESP — 任务物品的轮廓，带细框、名称和距离。", ru = "ESP — силуэт квестовых предметов с тонкой рамкой, именем и дистанцией." },
    ["Destaque"] = { pt = "Preenchimento laranja/vermelho translúcido da silhueta.", en = "Translucent orange/red fill of the silhouette.", es = "Relleno naranja/rojo translúcido de la silueta.", zh = "轮廓的半透明橙/红填充。", ru = "Полупрозрачная оранжево-красная заливка силуэта." },
    ["Caixa"] = { pt = "Caixa retangular fina em volta da silhueta.", en = "Thin rectangular box around the silhouette.", es = "Caja rectangular fina alrededor de la silueta.", zh = "轮廓周围的细矩形框。", ru = "Тонкая прямоугольная рамка вокруг силуэта." },
    ["Nome"] = { pt = "Mostra o nome do alvo em cima da caixa.", en = "Shows the target's name above the box.", es = "Muestra el nombre del objetivo sobre la caja.", zh = "在框上方显示目标名称。", ru = "Показывает имя цели над рамкой." },
    ["Barra de vida"] = { pt = "Barra de vida vertical no lado da caixa.", en = "Vertical health bar on the side of the box.", es = "Barra de vida vertical al lado de la caja.", zh = "框侧面的垂直血条。", ru = "Вертикальная полоса здоровья сбоку от рамки." },
    ["Vida"] = { pt = "Mostra o número da vida ao lado da barra.", en = "Shows the health number next to the bar.", es = "Muestra el número de vida junto a la barra.", zh = "在血条旁显示生命值。", ru = "Показывает число здоровья рядом с полосой." },
    ["Distância"] = { pt = "Mostra a distância do alvo embaixo da caixa.", en = "Shows the target's distance below the box.", es = "Muestra la distancia del objetivo bajo la caja.", zh = "在框下方显示目标距离。", ru = "Показывает дистанцию до цели под рамкой." },
    ["Linhas até alvos"] = { pt = "Desenha uma linha do ponto de origem até cada alvo.", en = "Draws a line from the origin point to each target.", es = "Dibuja una línea desde el punto de origen hasta cada objetivo.", zh = "从原点向每个目标画一条线。", ru = "Рисует линию от точки начала к каждой цели." },
    ["Esqueleto"] = { pt = "Desenha o esqueleto do alvo por cima da silhueta.", en = "Draws the target's skeleton over the silhouette.", es = "Dibuja el esqueleto del objetivo sobre la silueta.", zh = "在轮廓上绘制目标的骨骼。", ru = "Рисует скелет цели поверх силуэта." },
    ["Distância máx."] = { pt = "Distância máxima em que o alvo aparece.", en = "Maximum distance at which the target appears.", es = "Distancia máxima a la que aparece el objetivo.", zh = "目标出现的最大距离。", ru = "Максимальная дистанция появления цели." },
    ["Tamanho do texto"] = { pt = "Tamanho do texto do ESP.", en = "ESP text size.", es = "Tamaño del texto del ESP.", zh = "ESP 文字大小。", ru = "Размер текста ESP." },
    ["Distância da prévia"] = { pt = "Distância simulada na prévia do ESP.", en = "Simulated distance in the ESP preview.", es = "Distancia simulada en la vista previa del ESP.", zh = "ESP 预览中的模拟距离。", ru = "Симулируемая дистанция в предпросмотре ESP." },
    ["Vida da prévia"] = { pt = "Vida simulada na prévia do ESP.", en = "Simulated health in the preview.", es = "Vida simulada en la vista previa.", zh = "预览中的模拟生命值。", ru = "Симулируемое здоровье в предпросмотре." },
    ["Detalhes até"] = { pt = "Até que distância mostra todos os detalhes.", en = "Up to which distance it shows all details.", es = "Hasta qué distancia muestra todos los detalles.", zh = "至多远的距离显示全部细节。", ru = "До какой дистанции показываются все детали." },
    ["Só detalhes de perto"] = { pt = "Longe mostra só um ponto; perto mostra tudo.", en = "Far away shows only a dot; close up shows everything.", es = "Lejos muestra solo un punto; de cerca muestra todo.", zh = "远处只显示一个点；近处显示全部。", ru = "Вдали — только точка; вблизи — всё." },
    ["Destacar mais próximo"] = { pt = "O alvo mais próximo ganha outra cor e um marcador.", en = "The nearest target gets another color and a marker.", es = "El objetivo más cercano recibe otro color y un marcador.", zh = "最近的目标会获得另一种颜色和标记。", ru = "Ближайшая цель получает другой цвет и маркер." },
    ["Estilo"] = { pt = "Estilo da caixa do ESP (cantos ou completa).", en = "ESP box style (corners or full).", es = "Estilo de la caja del ESP (esquinas o completa).", zh = "ESP 框样式（角落或完整）。", ru = "Стиль рамки ESP (углы или полная)." },
    ["Espessura"] = { pt = "Espessura da linha da caixa ou do esqueleto.", en = "Thickness of the box or skeleton line.", es = "Grosor de la línea de la caja o del esqueleto.", zh = "框或骨骼线的粗细。", ru = "Толщина линии рамки или скелета." },
    ["Tamanho do canto"] = { pt = "Tamanho dos cantos da caixa.", en = "Size of the box corners.", es = "Tamaño de las esquinas de la caja.", zh = "框角的大小。", ru = "Размер углов рамки." },
    ["Preenchimento"] = { pt = "Preenchimento da silhueta do ESP, em porcentagem.", en = "ESP silhouette fill, as a percentage.", es = "Relleno de la silueta del ESP, en porcentaje.", zh = "ESP 轮廓填充，按百分比。", ru = "Заливка силуэта ESP в процентах." },
    ["Contorno"] = { pt = "Espessura do contorno escuro da silhueta.", en = "Thickness of the dark outline of the silhouette.", es = "Grosor del contorno oscuro de la silueta.", zh = "轮廓深色描边的粗细。", ru = "Толщина тёмного контура силуэта." },
    ["Cor do contorno"] = { pt = "Cor do contorno escuro da silhueta.", en = "Color of the dark outline of the silhouette.", es = "Color del contorno oscuro de la silueta.", zh = "轮廓深色描边的颜色。", ru = "Цвет тёмного контура силуэта." },
    ["Cor automática"] = { pt = "Barra de vida muda de cor conforme a vida.", en = "Health bar changes color based on health.", es = "La barra de vida cambia de color según la vida.", zh = "血条根据生命值改变颜色。", ru = "Полоса здоровья меняет цвет по мере здоровья." },
    ["Posição"] = { pt = "Lado em que a barra de vida aparece.", en = "Side where the health bar appears.", es = "Lado donde aparece la barra de vida.", zh = "血条出现的一侧。", ru = "Сторона, где появляется полоса здоровья." },
    ["Largura da barra"] = { pt = "Largura da barra de vida.", en = "Width of the health bar.", es = "Ancho de la barra de vida.", zh = "血条宽度。", ru = "Ширина полосы здоровья." },
    ["Unidade"] = { pt = "Unidade da distância (metros ou studs).", en = "Distance unit (meters or studs).", es = "Unidad de distancia (metros o studs).", zh = "距离单位（米或 studs）。", ru = "Единица дистанции (метры или studs)." },
    ["Origem"] = { pt = "De onde a linha do alvo parte.", en = "Where the target line starts.", es = "Dónde comienza la línea del objetivo.", zh = "目标线的起点。", ru = "Где начинается линия к цели." },
    ["Cor"] = { pt = "Escolhe a cor do elemento.", en = "Chooses the element's color.", es = "Elige el color del elemento.", zh = "选择元素的颜色。", ru = "Выбирает цвет элемента." },
    ["Mochila personalizada"] = { pt = "Abre o editor para montar o visual da sua mochila.", en = "Opens the editor to build your backpack's look.", es = "Abre el editor para crear el aspecto de tu mochila.", zh = "打开编辑器，自定义背包外观。", ru = "Открывает редактор внешнего вида рюкзака." },
    ["Mochila"] = { pt = "Mostra ou oculta a mochila nativa do Roblox.", en = "Shows or hides the native Roblox backpack.", es = "Muestra u oculta la mochila nativa de Roblox.", zh = "显示或隐藏 Roblox 原生背包。", ru = "Показывает или скрывает стандартный рюкзак Roblox." },
    ["Barra rápida"] = { pt = "Barra local com até oito ferramentas Roblox; toque para equipar ou guardar.", en = "Local bar for up to eight Roblox tools; tap to equip or unequip.", es = "Barra local de hasta ocho herramientas Roblox; toca para equipar o guardar.", zh = "最多显示八件 Roblox 工具；点击装备或卸下。", ru = "Локальная панель до восьми инструментов Roblox; нажмите для экипировки." },
    ["Aura"] = { pt = "Desenha um círculo de luz ao redor do seu personagem.", en = "Draws a circle of light around your character.", es = "Dibuja un círculo de luz alrededor de tu personaje.", zh = "在角色周围画一个光圈。", ru = "Рисует круг света вокруг персонажа." },
    ["Círculo de salto"] = { pt = "Mostra a área de salto ao redor de você.", en = "Shows the jump area around you.", es = "Muestra el área de salto a tu alrededor.", zh = "显示你周围的跳跃区域。", ru = "Показывает область прыжка вокруг вас." },
    ["Auréola"] = { pt = "Coloca uma auréola brilhante sobre a cabeça.", en = "Puts a glowing halo over the head.", es = "Coloca una auréola brillante sobre la cabeza.", zh = "在头顶放一个发亮的光环。", ru = "Над головой появляется светящийся ореол." },
    ["Rastro estelar"] = { pt = "Deixa um rastro de partículas estreladas ao se mover.", en = "Leaves a trail of star particles when moving.", es = "Deja un rastro de partículas estelares al moverte.", zh = "移动时留下星尘轨迹。", ru = "Оставляет след звёздных частиц при движении." },
    ["Hack de velocidade"] = { pt = "Aumenta a velocidade de movimento do personagem.", en = "Increases the character's movement speed.", es = "Aumenta la velocidad de movimiento del personaje.", zh = "提高角色的移动速度。", ru = "Ускоряет передвижение персонажа." },
    ["Sprint automático"] = { pt = "Corre automaticamente, sem segurar o botão de correr.", en = "Runs automatically without holding the run button.", es = "Corre automáticamente sin mantener el botón de correr.", zh = "无需按住奔跑键即可自动奔跑。", ru = "Автоматический бег без удержания кнопки." },
    ["Pulos seguidos"] = { pt = "Permite pular várias vezes seguidas no ar.", en = "Allows jumping several times in a row in the air.", es = "Permite saltar varias veces seguidas en el aire.", zh = "允许在空中连续跳跃多次。", ru = "Позволяет прыгать несколько раз подряд в воздухе." },
    ["Controle no ar"] = { pt = "Dá controle total do personagem enquanto está no ar.", en = "Gives full control of the character while in the air.", es = "Da control total del personaje mientras está en el aire.", zh = "在空中时完全控制角色。", ru = "Полный контроль персонажа в воздухе." },
    ["Voar"] = { pt = "Permite voar livremente pelo mapa.", en = "Allows flying freely around the map.", es = "Permite volar libremente por el mapa.", zh = "可以自由在地图上空飞行。", ru = "Позволяет свободно летать по карте." },
    ["Sem dano de queda"] = { pt = "Elimina o dano ao cair de lugares altos.", en = "Removes fall damage.", es = "Elimina el daño por caída.", zh = "移除坠落伤害。", ru = "Убирает урон от падения." },
    ["Sempre no chão"] = { pt = "Mantém o personagem sempre no chão, sem cair.", en = "Keeps the character on the ground, never falling.", es = "Mantiene al personaje siempre en el suelo, sin caer.", zh = "让角色始终站在地面上。", ru = "Персонаж всегда на земле, не падает." },
    ["Jesus"] = { pt = "Permite andar sobre a água.", en = "Allows walking on water.", es = "Permite caminar sobre el agua.", zh = "允许在水上行走。", ru = "Позволяет ходить по воде." },
    ["Aranha"] = { pt = "Permite escalar paredes como uma aranha.", en = "Allows climbing walls like a spider.", es = "Permite escalar paredes como una araña.", zh = "允许像蜘蛛一样爬墙。", ru = "Позволяет карабкаться по стенам, как паук." },
    ["Terceira pessoa"] = { pt = "Coloca a câmera em terceira pessoa.", en = "Switches the camera to third person.", es = "Cambia la cámara a tercera persona.", zh = "将视角切换到第三人称。", ru = "Переключает камеру на третье лицо." },
    ["Câmera livre"] = { pt = "Libera a câmera para olhar ao redor sem mover o personagem.", en = "Frees the camera to look around without moving the character.", es = "Libera la cámara para mirar alrededor sin mover al personaje.", zh = "解放视角环顾四周，不移动角色。", ru = "Освобождает камеру для обзора без движения персонажа." },
    ["Saque automático"] = { pt = "Tenta acionar prompts próximos com limite de frequência; pode ser detectado.", en = "Attempts to trigger nearby prompts with a rate limit; detection remains possible.", es = "Intenta activar prompts cercanos con límite de frecuencia; puede detectarse.", zh = "限频尝试触发附近的交互提示；仍可能被检测。", ru = "Пытается активировать ближайшие подсказки с ограничением частоты; обнаружение возможно." },
    ["Campo de visão"] = { pt = "Ajusta o campo de visão (FOV) da câmera.", en = "Adjusts the camera's field of view (FOV).", es = "Ajusta el campo de visión (FOV) de la cámara.", zh = "调整视角（FOV）。", ru = "Настраивает поле зрения камеры (FOV)." },
    ["Visão com zoom"] = { pt = "Ajusta o zoom aplicado ao usar a tecla de zoom.", en = "Adjusts the zoom applied when using the zoom key.", es = "Ajusta el zoom aplicado al usar la tecla de zoom.", zh = "调整使用缩放键时的缩放。", ru = "Настраивает зум при использовании клавиши зума." },
    ["Repetir"] = { pt = "Repete a animação selecionada em loop.", en = "Repeats the selected animation in a loop.", es = "Repite la animación seleccionada en bucle.", zh = "循环重复所选动画。", ru = "Повторяет выбранную анимацию по кругу." },
    ["Velocidade"] = { pt = "Velocidade da animação.", en = "Animation speed.", es = "Velocidad de la animación.", zh = "动画速度。", ru = "Скорость анимации." },
    ["Peso"] = { pt = "Peso/influência da animação.", en = "Animation weight/influence.", es = "Peso/influencia de la animación.", zh = "动画权重/影响。", ru = "Вес/влияние анимации." },
    ["Painel do jogador"] = { pt = "Mostra um painel com os dados do jogador.", en = "Shows a panel with the player's data.", es = "Muestra un panel con los datos del jugador.", zh = "显示玩家数据面板。", ru = "Показывает панель с данными игрока." },
    ["Anti AFK"] = { pt = "Impede que você seja expulso por inatividade.", en = "Prevents you from being kicked for inactivity.", es = "Evita que te expulsen por inactividad.", zh = "防止因挂机被踢出。", ru = "Защищает от кика за бездействие." },
    ["Renascer automático"] = { pt = "Renasce sozinho ao morrer.", en = "Respawns automatically on death.", es = "Reaparece automáticamente al morir.", zh = "死亡后自动重生。", ru = "Автоматический респавн после смерти." },
    ["Remover água"] = { pt = "Remove a água do mapa.", en = "Removes water from the map.", es = "Elimina el agua del mapa.", zh = "移除地图中的水。", ru = "Убирает воду с карты." },
    ["Não se afogar"] = { pt = "Impede o dano por afogamento.", en = "Prevents drowning damage.", es = "Evita el daño por ahogamiento.", zh = "防止溺水伤害。", ru = "Предотвращает урон от утопления." },
    ["Mapa e navegação"] = { pt = "Mostra o mapa e rotas de navegação.", en = "Shows the map and navigation routes.", es = "Muestra el mapa y rutas de navegación.", zh = "显示地图和导航路线。", ru = "Показывает карту и маршруты." },
    ["Alvo fixo"] = { pt = "Trava a mira em um alvo específico.", en = "Locks the aim on a specific target.", es = "Fija la mira en un objetivo específico.", zh = "将自瞄准定在特定目标上。", ru = "Фиксирует прицел на конкретной цели." },
    ["Previsão"] = { pt = "Prevê a trajetória do alvo para acertar melhor.", en = "Predicts the target's trajectory to hit better.", es = "Predice la trayectoria del objetivo para acertar mejor.", zh = "预测目标轨迹以更好命中。", ru = "Предсказывает траекторию цели для точного попадания." },
    ["Suavização"] = { pt = "Quanto maior, mais suave o movimento da mira.", en = "The higher, the smoother the aim movement.", es = "Cuanto mayor, más suave el movimiento de la mira.", zh = "数值越高，自瞄移动越平滑。", ru = "Чем выше, тем плавнее движение прицела." },
    ["Pausa inteligente"] = { pt = "Pausa a mira quando o alvo está obstruído; requer verificação de obstáculos.", en = "Pauses aim at an obstructed target when obstacle checks are enabled.", es = "Pausa la mira si el objetivo está obstruido y la comprobación está activa.", zh = "启用障碍物检查时，目标被阻挡会暂停瞄准。", ru = "Останавливает прицел при препятствии, если проверка включена." },
    ["Notificar"] = { pt = "Mostra um aviso quando o alvo é atingido ou eliminado.", en = "Shows a notice when the target is hit or eliminated.", es = "Muestra un aviso cuando el objetivo es alcanzado o eliminado.", zh = "目标被击中或淘汰时显示通知。", ru = "Показывает уведомление при попадании или устранении." },
    ["Raio da mira"] = { pt = "Alcance do círculo da mira.", en = "Range of the aim circle.", es = "Alcance del círculo de la mira.", zh = "自瞄圈的范围。", ru = "Радиус круга прицела." },
    ["FOV dinâmico"] = { pt = "Ajusta o campo de visão da mira dinamicamente.", en = "Dynamically adjusts the aim field of view.", es = "Ajusta dinámicamente el campo de visión de la mira.", zh = "动态调整自瞄视野。", ru = "Динамически меняет поле зрения прицела." },
    ["Alternativa visível"] = { pt = "Mostra uma alternativa visual para a mira.", en = "Shows a visual alternative for the aim.", es = "Muestra una alternativa visual para la mira.", zh = "显示自瞄的视觉替代方案。", ru = "Показывает визуальную альтернативу прицела." },
    ["Mirar em NPCs"] = { pt = "Permite a mira mirar em NPCs.", en = "Allows the aim to target NPCs.", es = "Permite que la mira apunte a NPCs.", zh = "允许自瞄瞄准 NPC。", ru = "Позволяет прицелу наводиться на NPC." },
    ["Ignorar obstáculos na mira"] = { pt = "Ignora obstáculos na seleção de mira; não faz disparos atravessarem paredes.", en = "Ignores obstacles when aiming; it does not make shots penetrate walls.", es = "Ignora obstáculos al apuntar; no hace que los disparos atraviesen paredes.", zh = "瞄准时忽略障碍物；不使子弹穿墙。", ru = "Игнорирует препятствия при прицеливании; пули не проходят сквозь стены." },
    ["Limite de verificações"] = { pt = "Quantas checagens de alvo por quadro.", en = "How many target checks per frame.", es = "Cuántas comprobaciones de objetivo por cuadro.", zh = "每帧目标检查次数。", ru = "Сколько проверок цели на кадр." },
    ["Espiada subterrânea"] = { pt = "Mostra o que está escondido sob o chão.", en = "Shows what is hidden under the ground.", es = "Muestra lo que está escondido bajo el suelo.", zh = "显示地下隐藏的事物。", ru = "Показывает скрытое под землёй." },
    ["Aura letal"] = { pt = "Desenha uma aura em alvos letais.", en = "Draws an aura on lethal targets.", es = "Dibuja una aura en objetivos letales.", zh = "在致命目标上绘制光环。", ru = "Рисует ауру на смертоносных целях." },
    ["Recarga automática"] = { pt = "Tenta recarregar com o RemoteEvent configurado; consulte o README. Há limite de frequência e risco de detecção.", en = "Attempts to reload using the configured RemoteEvent; see README. Rate-limited; detection remains possible.", es = "Intenta recargar con el RemoteEvent configurado; consulta el README. Tiene límite de frecuencia y riesgo de detección.", zh = "使用配置的 RemoteEvent 尝试装填；请参阅 README。有频率限制，仍可能被检测。", ru = "Пытается перезарядить через настроенный RemoteEvent; см. README. Частота ограничена, обнаружение возможно." },
    ["Abastecer cargadores"] = { pt = "Reabastece os cargadores automaticamente.", en = "Refills magazines automatically.", es = "Recarga los cargadores automáticamente.", zh = "自动装填弹匣。", ru = "Автоматически пополняет магазины." },
    ["Mira falsa"] = { pt = "Mostra uma mira falsa para confundir os adversários.", en = "Shows a fake aim to confuse opponents.", es = "Muestra una mira falsa para confundir a los rivales.", zh = "显示假自瞄迷惑对手。", ru = "Показывает ложный прицел, чтобы запутать врагов." },
    ["Retícula"] = { pt = "Mostra uma retícula no centro da tela.", en = "Shows a crosshair in the center of the screen.", es = "Muestra una retícula en el centro de la pantalla.", zh = "在屏幕中心显示准星。", ru = "Показывает перекрестие в центре экрана." },
    ["Círculo da mira"] = { pt = "Mostra um círculo na mira.", en = "Shows a circle on the aim.", es = "Muestra un círculo en la mira.", zh = "在自瞄上显示一个圈。", ru = "Показывает круг на прицеле." },
    ["Rastro personalizado"] = { pt = "Personaliza o rastro do tiro.", en = "Customizes the shot trail.", es = "Personaliza el rastro del disparo.", zh = "自定义射击轨迹。", ru = "Настраивает след выстрела." },
    ["Rastros do jogo"] = { pt = "Mostra os rastros do jogo.", en = "Shows the game's trails.", es = "Muestra los rastros del juego.", zh = "显示游戏的轨迹。", ru = "Показывает следы игры." },
    ["Marca de acerto"] = { pt = "Marca onde o tiro acertou.", en = "Marks where the shot hit.", es = "Marca dónde acertó el tiro.", zh = "标记射击命中的位置。", ru = "Отмечает место попадания." },
    ["Números de dano"] = { pt = "Mostra os números de dano.", en = "Shows damage numbers.", es = "Muestra los números de daño.", zh = "显示伤害数字。", ru = "Показывает числа урона." },
    ["Efeitos de acerto"] = { pt = "Mostra efeitos ao acertar um tiro.", en = "Shows effects when a shot hits.", es = "Muestra efectos al acertar un tiro.", zh = "命中时显示效果。", ru = "Показывает эффекты при попадании." },
    ["Efeitos de eliminação"] = { pt = "Mostra efeitos ao eliminar um alvo.", en = "Shows effects when a target is eliminated.", es = "Muestra efectos al eliminar un objetivo.", zh = "淘汰时显示效果。", ru = "Показывает эффекты при устранении." },
    ["Dados do alvo"] = { pt = "Mostra dados do alvo.", en = "Shows target data.", es = "Muestra los datos del objetivo.", zh = "显示目标数据。", ru = "Показывает данные цели." },
    ["Só acertos confirmados"] = { pt = "Exige marcador creator local para efeitos; nem todos os jogos o usam.", en = "Requires a local creator tag for effects; not every game uses it.", es = "Exige una etiqueta creator local para efectos; no todos los juegos la usan.", zh = "效果需要本地 creator 标记；并非所有游戏都使用。", ru = "Для эффектов требуется локальная метка creator; не все игры её используют." },
    ["Anti aim"] = { pt = "Recurso VIP: anti-aim.", en = "VIP feature: anti-aim.", es = "Recurso VIP: anti-aim.", zh = "VIP 功能：反自瞄。", ru = "VIP-функция: анти-аим." },
    ["Sob o chão"] = { pt = "Recurso VIP: mover sob o chão.", en = "VIP feature: move under the ground.", es = "Recurso VIP: moverse bajo el suelo.", zh = "VIP 功能：在地下移动。", ru = "VIP-функция: движение под землёй." },
    ["Fantasma"] = { pt = "Recurso VIP: fantasma.", en = "VIP feature: ghost.", es = "Recurso VIP: fantasma.", zh = "VIP 功能：幽灵。", ru = "VIP-функция: призрак." },
    ["Trajetória do arremesso"] = { pt = "Mostra a trajetória do arremesso.", en = "Shows the throw trajectory.", es = "Muestra la trayectoria del lanzamiento.", zh = "显示投掷轨迹。", ru = "Показывает траекторию броска." },
    ["Sem tremor"] = { pt = "Remove o tremor da câmera.", en = "Removes camera shake.", es = "Elimina el temblor de la cámara.", zh = "移除镜头抖动。", ru = "Убирает тряску камеры." },
    ["Ativação"] = { pt = "Como a mira é ativada.", en = "How the aim is activated.", es = "Cómo se activa la mira.", zh = "自瞄的激活方式。", ru = "Как активируется прицел." },
    ["Ponto de mira"] = { pt = "Onde a mira trava.", en = "Where the aim locks.", es = "Dónde se fija la mira.", zh = "自瞄锁定的位置。", ru = "Где фиксируется прицел." },
    ["Partes do corpo"] = { pt = "Quais partes do corpo a mira prioriza.", en = "Which body parts the aim prioritizes.", es = "Qué partes del cuerpo prioriza la mira.", zh = "自瞄优先选择哪些身体部位。", ru = "Какие части тела приоритетны для прицела." },
    ["Zoom"] = { pt = "Tecla de zoom da câmera.", en = "Camera zoom key.", es = "Tecla de zoom de la cámara.", zh = "视角缩放键。", ru = "Клавиша зума камеры." },
    ["Luz"] = { pt = "Ajusta a iluminação do mundo.", en = "Adjusts the world's lighting.", es = "Ajusta la iluminación del mundo.", zh = "调整世界光照。", ru = "Настраивает освещение мира." },
    ["Hora e sol"] = { pt = "Define a hora do dia e o sol.", en = "Sets the time of day and the sun.", es = "Define la hora del día y el sol.", zh = "设置白天时间和太阳。", ru = "Задаёт время суток и солнце." },
    ["Sombras"] = { pt = "Liga ou desliga as sombras.", en = "Toggles shadows.", es = "Activa o desactiva las sombras.", zh = "切换阴影。", ru = "Включает или выключает тени." },
    ["Renderização"] = { pt = "Ajusta a qualidade de renderização.", en = "Adjusts rendering quality.", es = "Ajusta la calidad de renderizado.", zh = "调整渲染质量。", ru = "Настраивает качество рендера." },
    ["Neblina"] = { pt = "Ajusta a neblina do mundo.", en = "Adjusts the world's fog.", es = "Ajusta la niebla del mundo.", zh = "调整世界雾效。", ru = "Настраивает туман мира." },
    ["Atmosfera"] = { pt = "Ajusta a atmosfera do céu.", en = "Adjusts the sky's atmosphere.", es = "Ajusta la atmósfera del cielo.", zh = "调整天空氛围。", ru = "Настраивает атмосферу неба." },
    ["Céu"] = { pt = "Muda o céu do jogo.", en = "Changes the game's sky.", es = "Cambia el cielo del juego.", zh = "更改游戏天空。", ru = "Меняет небо игры." },
    ["Nuvens"] = { pt = "Ajusta as nuvens.", en = "Adjusts the clouds.", es = "Ajusta las nubes.", zh = "调整云。", ru = "Настраивает облака." },
    ["Florescer"] = { pt = "Ajusta o florescimento (bloom).", en = "Adjusts bloom.", es = "Ajusta el florecimiento (bloom).", zh = "调整泛光。", ru = "Настраивает bloom." },
    ["Desfoque"] = { pt = "Ajusta o desfoque de fundo.", en = "Adjusts background blur.", es = "Ajusta el desenfoque de fondo.", zh = "调整背景模糊。", ru = "Настраивает размытие фона." },
    ["Ajuste de cor"] = { pt = "Ajusta as cores da tela.", en = "Adjusts the screen colors.", es = "Ajusta los colores de la pantalla.", zh = "调整屏幕颜色。", ru = "Настраивает цвета экрана." },
    ["Profundidade"] = { pt = "Ajusta a profundidade de campo.", en = "Adjusts depth of field.", es = "Ajusta la profundidad de campo.", zh = "调整景深。", ru = "Настраивает глубину резкости." },
    ["Raios de sol"] = { pt = "Ajusta os raios de sol.", en = "Adjusts sun rays.", es = "Ajusta los rayos de sol.", zh = "调整阳光射线。", ru = "Настраивает лучи солнца." },
    ["Tonalidade"] = { pt = "Ajusta a tonalidade das cores.", en = "Adjusts color tone.", es = "Ajusta el tono de color.", zh = "调整色调。", ru = "Настраивает оттенок цвета." },
    ["Sem grama"] = { pt = "Remove a grama do mapa.", en = "Removes grass from the map.", es = "Elimina la hierba del mapa.", zh = "移除地图中的草。", ru = "Убирает траву с карты." },
    ["Desativar minas"] = { pt = "Desativa as minas do mapa.", en = "Disables mines on the map.", es = "Desactiva las minas del mapa.", zh = "禁用地图中的地雷。", ru = "Отключает мины на карте." },
    ["Carregar jogadores"] = { pt = "Mostra os jogadores carregados.", en = "Shows loaded players.", es = "Muestra los jugadores cargados.", zh = "显示已加载的玩家。", ru = "Показывает загруженных игроков." },
    ["Buscar chefes"] = { pt = "Procura chefes no mapa.", en = "Searches for bosses on the map.", es = "Busca jefes en el mapa.", zh = "在地图上搜索首领。", ru = "Ищет боссов на карте." },
    ["Pontos de saída"] = { pt = "Mostra os pontos de saída do mapa.", en = "Shows the map's exit points.", es = "Muestra los puntos de salida del mapa.", zh = "显示地图出口点。", ru = "Показывает точки выхода с карты." },
    ["Grama"] = { pt = "Cor da grama.", en = "Grass color.", es = "Color de la hierba.", zh = "草的颜色。", ru = "Цвет травы." },
    ["Areia"] = { pt = "Cor da areia.", en = "Sand color.", es = "Color de la arena.", zh = "沙子的颜色。", ru = "Цвет песка." },
    ["Rocha"] = { pt = "Cor da rocha.", en = "Rock color.", es = "Color de la roca.", zh = "岩石的颜色。", ru = "Цвет камня." },
    ["Terra"] = { pt = "Cor da terra.", en = "Dirt color.", es = "Color de la tierra.", zh = "泥土的颜色。", ru = "Цвет земли." },
    ["Cor da água"] = { pt = "Cor da água.", en = "Water color.", es = "Color del agua.", zh = "水的颜色。", ru = "Цвет воды." },
    ["Cor das folhas"] = { pt = "Cor das folhas.", en = "Leaves color.", es = "Color de las hojas.", zh = "树叶的颜色。", ru = "Цвет листьев." },
    ["Cor dos troncos"] = { pt = "Cor dos troncos.", en = "Trunks color.", es = "Color de los troncos.", zh = "树干的颜色。", ru = "Цвет стволов." },
    ["Radar"] = { pt = "Mostra o radar de jogadores.", en = "Shows the players radar.", es = "Muestra el radar de jugadores.", zh = "显示玩家雷达。", ru = "Показывает радар игроков." },
    ["Mostrar NPCs"] = { pt = "Inclui NPCs no radar.", en = "Includes NPCs on the radar.", es = "Incluye NPCs en el radar.", zh = "在雷达中包含 NPC。", ru = "Показывает NPC на радаре." },
    ["Alcance"] = { pt = "Alcance do radar.", en = "Radar range.", es = "Alcance del radar.", zh = "雷达范围。", ru = "Дальность радара." },
    ["Mostrar"] = { pt = "O que mostrar no radar.", en = "What to show on the radar.", es = "Qué mostrar en el radar.", zh = "雷达上显示什么。", ru = "Что показывать на радаре." },
    ["Raridade"] = { pt = "Filtra os itens por raridade.", en = "Filters items by rarity.", es = "Filtra los objetos por rareza.", zh = "按稀有度筛选物品。", ru = "Фильтрует предметы по редкости." },
    ["Marcar na tela"] = { pt = "Mostra nome e distância dos itens no jogo.", en = "Shows name and distance of items in the game.", es = "Muestra nombre y distancia de los objetos en el juego.", zh = "在游戏中显示物品名称和距离。", ru = "Показывает имя и дистанцию предметов в игре." },
    ["Buscar por nome"] = { pt = "Digite o nome do item para buscar.", en = "Type the item name to search.", es = "Escribe el nombre del objeto a buscar.", zh = "输入要搜索的物品名称。", ru = "Введите имя предмета для поиска." },
    ["Buscar agora"] = { pt = "Executa a busca de itens agora.", en = "Runs the item search now.", es = "Ejecuta la búsqueda de objetos ahora.", zh = "立即执行物品搜索。", ru = "Запускает поиск предметов сейчас." },
    ["Sempre mostrar"] = { pt = "Mantém os resultados sempre visíveis.", en = "Keeps results always visible.", es = "Mantiene los resultados siempre visibles.", zh = "始终显示结果。", ru = "Всегда держит результаты видимыми." },
    ["Criador"] = { pt = "Filtra jogadores com cargo de criador.", en = "Filters players with the creator role.", es = "Filtra jugadores con rol de creador.", zh = "筛选具有创建者身份的玩家。", ru = "Фильтрует игроков с ролью создателя." },
    ["Testador"] = { pt = "Filtra jogadores com cargo de testador.", en = "Filters players with the tester role.", es = "Filtra jugadores con rol de tester.", zh = "筛选具有测试者身份的玩家。", ru = "Фильтрует игроков с ролью тестера." },
    ["Moderador"] = { pt = "Filtra jogadores com cargo de moderador.", en = "Filters players with the moderator role.", es = "Filtra jugadores con rol de moderador.", zh = "筛选具有管理员身份的玩家。", ru = "Фильтрует игроков с ролью модератора." },
    ["Trapaceiro"] = { pt = "Filtra jogadores marcados como trapaceiros.", en = "Filters players marked as cheaters.", es = "Filtra jugadores marcados como tramposos.", zh = "筛选被标记为作弊者的玩家。", ru = "Фильтрует игроков, отмеченных как читеры." },
    ["Por valor"] = { pt = "Ordena a lista por valor.", en = "Sorts the list by value.", es = "Ordena la lista por valor.", zh = "按价值排序列表。", ru = "Сортирует список по ценности." },
    ["Por tipo"] = { pt = "Ordena a lista por tipo.", en = "Sorts the list by type.", es = "Ordena la lista por tipo.", zh = "按类型排序列表。", ru = "Сортирует список по типу." },
    ["Por nome"] = { pt = "Ordena a lista por nome.", en = "Sorts the list by name.", es = "Ordena la lista por nombre.", zh = "按名称排序列表。", ru = "Сортирует список по имени." },
    ["Troca rápida"] = { pt = "Troca de arma ou item rapidamente.", en = "Quickly swaps weapon or item.", es = "Cambia rápido de arma u objeto.", zh = "快速切换武器或物品。", ru = "Быстро меняет оружие или предмет." },
    ["Modo pânico"] = { pt = "Esconde menu, ESP, radar e botões fixos de uma vez.", en = "Hides menu, ESP, radar and pinned buttons at once.", es = "Oculta menú, ESP, radar y botones fijos de una vez.", zh = "一次性隐藏菜单、ESP、雷达和固定按钮。", ru = "Сразу скрывает меню, ESP, радар и закреплённые кнопки." },
    ["Atravessar porta"] = { pt = "Atravessa a porta mais próxima.", en = "Walks through the nearest door.", es = "Atraviesa la puerta más cercana.", zh = "穿过最近的门。", ru = "Проходит сквозь ближайшую дверь." },
    ["Remover efeitos"] = { pt = "Remove os efeitos visuais do jogo.", en = "Removes the game's visual effects.", es = "Elimina los efectos visuales del juego.", zh = "移除游戏的视觉效果。", ru = "Убирает визуальные эффекты игры." },
    ["Avisos de entrada"] = { pt = "Avisa quando alguém entra no servidor.", en = "Alerts you when someone joins the server.", es = "Te avisa cuando alguien entra al servidor.", zh = "有人加入服务器时提醒你。", ru = "Предупреждает, когда кто-то заходит на сервер." },
    ["Jump"] = { pt = "Toca o som de pulo.", en = "Plays the jump sound.", es = "Reproduce el sonido de salto.", zh = "播放跳跃音效。", ru = "Воспроизводит звук прыжка." },
    ["Pegadas"] = { pt = "Toca o som de pegadas.", en = "Plays the footprints sound.", es = "Reproduce el sonido de pisadas.", zh = "播放脚步音效。", ru = "Воспроизводит звук шагов." },
    ["Pouso"] = { pt = "Toca o som de pouso.", en = "Plays the landing sound.", es = "Reproduce el sonido de aterrizaje.", zh = "播放落地音效。", ru = "Воспроизводит звук приземления." },
    ["Capacete"] = { pt = "Toca o som de capacete.", en = "Plays the helmet sound.", es = "Reproduce el sonido de casco.", zh = "播放头盔音效。", ru = "Воспроизводит звук шлема." },
    ["Tiro na cabeça"] = { pt = "Toca o som de tiro na cabeça.", en = "Plays the headshot sound.", es = "Reproduce el sonido de tiro en la cabeza.", zh = "播放爆头音效。", ru = "Воспроизводит звук хедшота." },
    ["Tiro no corpo"] = { pt = "Toca o som de tiro no corpo.", en = "Plays the body shot sound.", es = "Reproduce el sonido de tiro al cuerpo.", zh = "播放击中身体音效。", ru = "Воспроизводит звук попадания в тело." },
    ["Abate"] = { pt = "Toca o som de abate.", en = "Plays the kill sound.", es = "Reproduce el sonido de eliminación.", zh = "播放击杀音效。", ru = "Воспроизводит звук убийства." },
    ["Disparo"] = { pt = "Toca o som de disparo.", en = "Plays the shot sound.", es = "Reproduce el sonido de disparo.", zh = "播放射击音效。", ru = "Воспроизводит звук выстрела." },
    ["Acerto com sangue"] = { pt = "Toca o som de acerto com sangue.", en = "Plays the bloody hit sound.", es = "Reproduce el sonido de impacto con sangre.", zh = "播放流血命中音效。", ru = "Воспроизводит звук кровавого попадания." },
    ["Adicionar ID de som"] = { pt = "Digite o ID do som para adicionar.", en = "Type the sound ID to add.", es = "Escribe el ID del sonido a añadir.", zh = "输入要添加的音效 ID。", ru = "Введите ID звука, чтобы добавить." },
    ["Adicionar amigo"] = { pt = "Tecla para adicionar um amigo.", en = "Key to add a friend.", es = "Tecla para añadir un amigo.", zh = "添加好友的按键。", ru = "Клавиша для добавления друга." },
    ["Ver inventário"] = { pt = "Tecla para abrir o inventário.", en = "Key to open the inventory.", es = "Tecla para abrir el inventario.", zh = "打开背包的按键。", ru = "Клавиша открытия инвентаря." },
    ["Cursor livre"] = { pt = "Segure a tecla do cursor para liberar o mouse.", en = "Hold the cursor key to free the mouse.", es = "Mantén la tecla del cursor para liberar el ratón.", zh = "按住光标键释放鼠标。", ru = "Удерживайте клавишу курсора, чтобы освободить мышь." },
    ["Lista de atalhos"] = { pt = "Mostra a lista de atalhos na tela.", en = "Shows the shortcut list on screen.", es = "Muestra la lista de atajos en pantalla.", zh = "在屏幕上显示快捷键列表。", ru = "Показывает список горячих клавиш на экране." },
    ["Ilha de FPS"] = { pt = "Mostra a ilha de FPS na tela.", en = "Shows the FPS island on screen.", es = "Muestra la isla de FPS en pantalla.", zh = "在屏幕上显示 FPS 浮窗。", ru = "Показывает остров FPS на экране." },
    ["Fixar botão móvel"] = { pt = "Trava o botão móvel no lugar.", en = "Locks the mobile button in place.", es = "Bloquea el botón móvil en su lugar.", zh = "锁定移动按钮位置。", ru = "Фиксирует мобильную кнопку на месте." },
    ["Ocultar indisponíveis"] = { pt = "Esconde as opções indisponíveis.", en = "Hides unavailable options.", es = "Oculta las opciones no disponibles.", zh = "隐藏不可用的选项。", ru = "Скрывает недоступные опции." },
    ["Idioma"] = { pt = "Idioma do menu.", en = "Menu language.", es = "Idioma del menú.", zh = "菜单语言。", ru = "Язык меню." },
    ["Tecla do menu"] = { pt = "Tecla que abre e fecha o menu.", en = "Key that opens and closes the menu.", es = "Tecla que abre y cierra el menú.", zh = "打开/关闭菜单的按键。", ru = "Клавиша открытия и закрытия меню." },
    ["Tecla do cursor"] = { pt = "Tecla que libera o cursor do mouse.", en = "Key that frees the mouse cursor.", es = "Tecla que libera el cursor del ratón.", zh = "释放鼠标光标的按键。", ru = "Клавиша освобождения курсора." },
    ["Tecla de pânico"] = { pt = "Tecla do modo pânico.", en = "Panic mode key.", es = "Tecla del modo pánico.", zh = "恐慌模式按键。", ru = "Клавиша режима паники." },
    ["Rever tutorial"] = { pt = "Mostra o tutorial de novo.", en = "Shows the tutorial again.", es = "Muestra el tutorial de nuevo.", zh = "再次显示教程。", ru = "Снова показывает обучение." },
    ["Sair"] = { pt = "Fecha o menu e encerra o script.", en = "Closes the menu and ends the script.", es = "Cierra el menú y termina el script.", zh = "关闭菜单并结束脚本。", ru = "Закрывает меню и завершает скрипт." },
    ["Cubo"] = { pt = "Mostra o cubo/logo no canto do menu.", en = "Shows the cube/logo in the menu corner.", es = "Muestra el cubo/logo en la esquina del menú.", zh = "在菜单角落显示立方体/图标。", ru = "Показывает куб/логотип в углу меню." },
    ["Rastro ao ativar"] = { pt = "Mostra um rastro de luz ao ativar uma opção.", en = "Shows a light trail when enabling an option.", es = "Muestra un rastro de luz al activar una opción.", zh = "启用选项时显示光轨。", ru = "Показывает светящийся след при включении опции." },
    ["Animação do menu"] = { pt = "Abre e fecha o menu com um efeito suave.", en = "Opens and closes the menu with a smooth effect.", es = "Abre y cierra el menú con un efecto suave.", zh = "以平滑效果打开/关闭菜单。", ru = "Плавно открывает и закрывает меню." },
    ["Fonte"] = { pt = "Fonte do texto do menu.", en = "Menu text font.", es = "Fuente del texto del menú.", zh = "菜单字体。", ru = "Шрифт текста меню." },
    ["Bordas estáticas"] = { pt = "Bordas com a cor fixa do tema.", en = "Borders with the theme's fixed color.", es = "Bordes con el color fijo del tema.", zh = "边框使用主题的固定颜色。", ru = "Границы с фиксированным цветом темы." },
    ["Fundo"] = { pt = "Mostra o fundo do menu.", en = "Shows the menu background.", es = "Muestra el fondo del menú.", zh = "显示菜单背景。", ru = "Показывает фон меню." },
    ["Sombra"] = { pt = "Liga a sombra do painel.", en = "Toggles the panel shadow.", es = "Activa o desactiva la sombra del panel.", zh = "切换面板阴影。", ru = "Включает или выключает тень панели." },
    ["Fixar"] = { pt = "Impede que o painel seja arrastado.", en = "Prevents the panel from being dragged.", es = "Impide que el panel sea arrastrado.", zh = "防止面板被拖动。", ru = "Запрещает перетаскивание панели." },
    ["Campos visíveis"] = { pt = "Escolha os campos mostrados na marca d'água.", en = "Choose the fields shown in the watermark.", es = "Elige los campos mostrados en la marca de agua.", zh = "选择水印中显示的字段。", ru = "Выбирает поля, показываемые в водяном знаке." },
    ["Tamanho"] = { pt = "Tamanho do painel, em porcentagem.", en = "Panel size, as a percentage.", es = "Tamaño del panel, en porcentaje.", zh = "面板大小（百分比）。", ru = "Размер панели в процентах." },
    ["Largura"] = { pt = "Largura do painel.", en = "Panel width.", es = "Ancho del panel.", zh = "面板宽度。", ru = "Ширина панели." },
    ["Altura máxima"] = { pt = "Altura máxima do painel.", en = "Panel maximum height.", es = "Altura máxima del panel.", zh = "面板最大高度。", ru = "Максимальная высота панели." },
    ["Transparência"] = { pt = "Ajusta a transparência do fundo.", en = "Adjusts the background transparency.", es = "Ajusta la transparencia del fondo.", zh = "调整背景透明度。", ru = "Настраивает прозрачность фона." },
    ["Transp. fundo"] = { pt = "Ajusta a transparência do fundo.", en = "Adjusts the background transparency.", es = "Ajusta la transparencia del fondo.", zh = "调整背景透明度。", ru = "Настраивает прозрачность фона." },
    ["Transp. do texto"] = { pt = "Ajusta a transparência do texto.", en = "Adjusts the text transparency.", es = "Ajusta la transparencia del texto.", zh = "调整文字透明度。", ru = "Настраивает прозрачность текста." },
    ["Transp. da borda"] = { pt = "Ajusta a transparência da borda.", en = "Adjusts the border transparency.", es = "Ajusta la transparencia del borde.", zh = "调整边框透明度。", ru = "Настраивает прозрачность границы." },
    ["Raio dos cantos"] = { pt = "Arredonda os cantos do painel.", en = "Rounds the panel corners.", es = "Redondea las esquinas del panel.", zh = "圆角化面板边角。", ru = "Скругляет углы панели." },
    ["Intensidade"] = { pt = "Intensidade do efeito.", en = "Effect intensity.", es = "Intensidad del efecto.", zh = "效果强度。", ru = "Интенсивность эффекта." },
    ["Modo"] = { pt = "Modo de funcionamento da opção.", en = "How the option works.", es = "Cómo funciona la opción.", zh = "选项的工作方式。", ru = "Как работает опция." },
    ["Reproduzir"] = { pt = "Reproduz a animação selecionada.", en = "Plays the selected animation.", es = "Reproduce la animación seleccionada.", zh = "播放所选动画。", ru = "Воспроизводит выбранную анимацию." },
    ["Manuseio da arma"] = { pt = "Abre os ajustes de manuseio da arma.", en = "Opens the weapon handling settings.", es = "Abre los ajustes de manejo del arma.", zh = "打开武器操控设置。", ru = "Открывает настройки управления оружием." },
    ["Animação"] = { pt = "Animação de movimento do personagem.", en = "Character movement animation.", es = "Animación de movimiento del personaje.", zh = "角色移动动画。", ru = "Анимация движения персонажа." },
    ["Deslocamento"] = { pt = "Muda o deslocamento visual do personagem.", en = "Changes the character's visual offset.", es = "Cambia el desplazamiento visual del personaje.", zh = "改变角色的视觉偏移。", ru = "Меняет визуальное смещение персонажа." },
    ["Trocar personagem"] = { pt = "Troca o personagem do jogador.", en = "Swaps the player's character.", es = "Cambia el personaje del jugador.", zh = "切换玩家的角色。", ru = "Меняет персонажа игрока." },
    ["Personagem"] = { pt = "Mostra ou oculta o personagem.", en = "Shows or hides the character.", es = "Muestra u oculta el personaje.", zh = "显示或隐藏角色。", ru = "Показывает или скрывает персонажа." },
    ["Corpo em 1ª pessoa"] = { pt = "Mostra o corpo em primeira pessoa.", en = "Shows the body in first person.", es = "Muestra el cuerpo en primera persona.", zh = "以第一人称显示身体。", ru = "Показывает тело от первого лица." },
    ["Mãos"] = { pt = "Mostra as mãos na primeira pessoa.", en = "Shows the hands in first person.", es = "Muestra las manos en primera persona.", zh = "以第一人称显示双手。", ru = "Показывает руки от первого лица." },
    ["Item na mão"] = { pt = "Mostra o item segurado na mão.", en = "Shows the held item in hand.", es = "Muestra el objeto sostenido en la mano.", zh = "显示手中持有的物品。", ru = "Показывает предмет в руке." },
}) do Library.Internal.tips[k] = v end

for k, v in pairs({
    ["Zoom máximo"] = { pt = "Ajusta: Zoom máximo.", en = "Adjusts: Maximum zoom.", es = "Ajusta: Zoom máximo.", zh = "调整：最大缩放。", ru = "Настройка: Максимальный зум." },
    ["Distância de deslocamento"] = { pt = "Ajusta: Distância de deslocamento.", en = "Adjusts: Offset distance.", es = "Ajusta: Distancia de desplazamiento.", zh = "调整：偏移距离。", ru = "Настройка: Дистанция смещения." },
    ["Altura do quadril"] = { pt = "Ajusta: Altura do quadril.", en = "Adjusts: Hip height.", es = "Ajusta: Altura de cadera.", zh = "调整：髋部高度。", ru = "Настройка: Высота бёдер." },
    ["Rotação por quadro"] = { pt = "Ajusta: Rotação por quadro.", en = "Adjusts: Rotation per frame.", es = "Ajusta: Rotación por cuadro.", zh = "调整：每帧旋转。", ru = "Настройка: Поворот за кадр." },
    ["Duração do aviso"] = { pt = "Ajusta: Duração do aviso.", en = "Adjusts: Notification duration.", es = "Ajusta: Duración del aviso.", zh = "调整：通知时长。", ru = "Настройка: Длительность уведомления." },
    ["Tamanho dos dados"] = { pt = "Ajusta: Tamanho dos dados.", en = "Adjusts: Target data size.", es = "Ajusta: Tamaño de datos del objetivo.", zh = "调整：目标数据大小。", ru = "Настройка: Размер данных цели." },
    ["Tamanho dos números"] = { pt = "Ajusta: Tamanho dos números.", en = "Adjusts: Damage number size.", es = "Ajusta: Tamaño de números de daño.", zh = "调整：伤害数字大小。", ru = "Настройка: Размер чисел урона." },
    ["Tamanho da retícula"] = { pt = "Ajusta o tamanho do ponto central.", en = "Adjusts the center dot size.", es = "Ajusta el tamaño del punto central.", zh = "调整中心点大小。", ru = "Настраивает размер центральной точки." },
    ["Espessura do círculo"] = { pt = "Ajusta a espessura do círculo da mira.", en = "Adjusts the aim circle thickness.", es = "Ajusta el grosor del círculo de mira.", zh = "调整瞄准圆圈的粗细。", ru = "Настраивает толщину круга прицела." },
    ["Duração do rastro"] = { pt = "Ajusta por quanto tempo o rastro fica visível.", en = "Adjusts how long the trail remains visible.", es = "Ajusta cuánto tiempo permanece visible la estela.", zh = "调整轨迹的可见时长。", ru = "Настраивает длительность видимости следа." },
    ["Número de espaços"] = { pt = "Ajusta o máximo de ferramentas mostradas na barra.", en = "Adjusts the maximum tools shown on the bar.", es = "Ajusta el máximo de herramientas mostradas en la barra.", zh = "调整快捷栏显示的工具数量上限。", ru = "Настраивает максимальное число инструментов на панели." },
    ["Volume"] = { pt = "Ajusta o volume deste som local.", en = "Adjusts this local sound's volume.", es = "Ajusta el volumen de este sonido local.", zh = "调整此本地声音的音量。", ru = "Настраивает громкость этого локального звука." },
    ["Multiplicador"] = { pt = "Ajusta: Multiplicador.", en = "Adjusts: Multiplier.", es = "Ajusta: Multiplicador.", zh = "调整：倍率。", ru = "Настройка: Множитель." },
    ["Velocidade de voo"] = { pt = "Ajusta: Velocidade de voo.", en = "Adjusts: Flight speed.", es = "Ajusta: Velocidad de vuelo.", zh = "调整：飞行速度。", ru = "Настройка: Скорость полёта." },
    ["Velocidade de subida"] = { pt = "Ajusta: Velocidade de subida.", en = "Adjusts: Climb speed.", es = "Ajusta: Velocidad de subida.", zh = "调整：攀爬速度。", ru = "Настройка: Скорость подъёма." },
    ["Distância da câmera"] = { pt = "Ajusta: Distância da câmera.", en = "Adjusts: Camera distance.", es = "Ajusta: Distancia de cámara.", zh = "调整：相机距离。", ru = "Настройка: Дистанция камеры." },
    ["Intervalo da troca"] = { pt = "Ajusta: Intervalo da troca.", en = "Adjusts: Swap interval.", es = "Ajusta: Intervalo de cambio.", zh = "调整：切换间隔。", ru = "Настройка: Интервал смены." },
    ["Profundidade da câmera"] = { pt = "Ajusta: Profundidade da câmera.", en = "Adjusts: Camera depth.", es = "Ajusta: Profundidad de cámara.", zh = "调整：相机深度。", ru = "Настройка: Глубина камеры." },
    ["Transparência"] = { pt = "Ajusta: Transparência.", en = "Adjusts: Transparency.", es = "Ajusta: Transparencia.", zh = "调整：透明度。", ru = "Настройка: Прозрачность." },
    ["Alcance da trajetória"] = { pt = "Ajusta: Alcance da trajetória.", en = "Adjusts: Trajectory range.", es = "Ajusta: Alcance de trayectoria.", zh = "调整：轨迹距离。", ru = "Настройка: Дальность траектории." },
    ["Duração da marca"] = { pt = "Ajusta: Duração da marca.", en = "Adjusts: Marker duration.", es = "Ajusta: Duración de marca.", zh = "调整：标记时长。", ru = "Настройка: Длительность маркера." },
    ["Brilho"] = { pt = "Ajusta: Brilho.", en = "Adjusts: Brightness.", es = "Ajusta: Brillo.", zh = "调整：亮度。", ru = "Настройка: Яркость." },
    ["Hora"] = { pt = "Ajusta: Hora.", en = "Adjusts: Time.", es = "Ajusta: Hora.", zh = "调整：时间。", ru = "Настройка: Время." },
    ["Suavidade das sombras"] = { pt = "Ajusta: Suavidade das sombras.", en = "Adjusts: Shadow softness.", es = "Ajusta: Suavidad de sombras.", zh = "调整：阴影柔和度。", ru = "Настройка: Мягкость теней." },
    ["Densidade da neblina"] = { pt = "Ajusta: Densidade da neblina.", en = "Adjusts: Fog density.", es = "Ajusta: Densidad de niebla.", zh = "调整：雾密度。", ru = "Настройка: Плотность тумана." },
    ["Névoa da atmosfera"] = { pt = "Ajusta: Névoa da atmosfera.", en = "Adjusts: Atmosphere haze.", es = "Ajusta: Bruma atmosférica.", zh = "调整：大气霾度。", ru = "Настройка: Атмосферная дымка." },
    ["Cobertura das nuvens"] = { pt = "Ajusta: Cobertura das nuvens.", en = "Adjusts: Cloud cover.", es = "Ajusta: Cobertura de nubes.", zh = "调整：云层覆盖。", ru = "Настройка: Облачность." },
    ["Intensidade do florescer"] = { pt = "Ajusta: Intensidade do florescer.", en = "Adjusts: Bloom intensity.", es = "Ajusta: Intensidad de brillo.", zh = "调整：泛光强度。", ru = "Настройка: Интенсивность свечения." },
    ["Tamanho do desfoque"] = { pt = "Ajusta: Tamanho do desfoque.", en = "Adjusts: Blur size.", es = "Ajusta: Tamaño de desenfoque.", zh = "调整：模糊大小。", ru = "Настройка: Размер размытия." },
    ["Saturação"] = { pt = "Ajusta: Saturação.", en = "Adjusts: Saturation.", es = "Ajusta: Saturación.", zh = "调整：饱和度。", ru = "Настройка: Насыщенность." },
    ["Contraste"] = { pt = "Ajusta: Contraste.", en = "Adjusts: Contrast.", es = "Ajusta: Contraste.", zh = "调整：对比度。", ru = "Настройка: Контрастность." },
    ["Distância de foco"] = { pt = "Ajusta: Distância de foco.", en = "Adjusts: Focus distance.", es = "Ajusta: Distancia de enfoque.", zh = "调整：焦距。", ru = "Настройка: Дистанция фокусировки." },
    ["Desfoque distante"] = { pt = "Ajusta: Desfoque distante.", en = "Adjusts: Far blur.", es = "Ajusta: Desenfoque lejano.", zh = "调整：远处模糊。", ru = "Настройка: Дальнее размытие." },
    ["Intensidade dos raios"] = { pt = "Ajusta: Intensidade dos raios.", en = "Adjusts: Sun ray intensity.", es = "Ajusta: Intensidad de rayos solares.", zh = "调整：阳光强度。", ru = "Настройка: Интенсивность солнечных лучей." },
    ["Dispersão dos raios"] = { pt = "Ajusta: Dispersão dos raios.", en = "Adjusts: Sun ray spread.", es = "Ajusta: Dispersión de rayos solares.", zh = "调整：阳光散布。", ru = "Настройка: Рассеивание солнечных лучей." },
}) do Library.Internal.tips[k] = v end

-- Descrições dos novos ajustes: mostram o limite local, não prometem resultado no servidor.
for key, words in pairs({
    ["Alcance para ignorar obstáculos"] = {"Limita a distância em que a seleção ignora obstáculos; não faz disparos atravessarem paredes.", "Limits the distance at which targeting ignores obstacles; shots do not penetrate walls.", "Limita la distancia a la que la mira ignora obstáculos; los disparos no atraviesan paredes.", "限制瞄准忽略障碍物的距离；不会让子弹穿墙。", "Ограничивает дистанцию игнорирования препятствий; пули не проходят сквозь стены."},
    ["Transparência em primeira pessoa"] = {"Transparência local do corpo em primeira pessoa, exceto cabeça e acessórios.", "Local first-person body transparency, excluding head and accessories.", "Transparencia local del cuerpo en primera persona, sin cabeza ni accesorios.", "第一人称身体的本地透明度，不包括头部和配饰。", "Локальная прозрачность тела от первого лица, кроме головы и аксессуаров."},
    ["Intervalo dos três toques"] = {"Tempo máximo entre os três toques para sair do pânico.", "Maximum time for three taps to exit panic.", "Tiempo máximo para tres toques y salir del pánico.", "退出恐慌模式的三次点击最长时间。", "Максимальное время для трёх касаний выхода из паники."},
    ["Largura da área de retorno"] = {"Ajusta a largura da área de toque no topo durante o pânico.", "Adjusts the width of the panic return touch area at the top.", "Ajusta el ancho del área de retorno durante el pánico.", "调整恐慌模式顶部返回触摸区域的宽度。", "Настраивает ширину верхней области возврата при панике."},
    ["Tempo para retomar a mira"] = {"Exige que o alvo permaneça visível antes de retomar; ignorar obstáculos dispensa a verificação.", "Requires the target to remain visible before resuming; ignoring obstacles bypasses the check.", "Exige que el objetivo siga visible antes de reanudar; ignorar obstáculos omite la comprobación.", "恢复前要求目标保持可见；忽略障碍物会跳过检查。", "Требует видимости цели перед возобновлением; игнорирование препятствий отключает проверку."},
    ["Duração do efeito de acerto"] = {"Duração do realce visual local; a confirmação depende das informações do jogo.", "Duration of the local visual highlight; confirmation depends on game data.", "Duración del resaltado local; la confirmación depende de los datos del juego.", "本地高亮效果的时长；确认取决于游戏数据。", "Длительность локальной подсветки; подтверждение зависит от данных игры."},
    ["Transparência do efeito"] = {"Transparência do realce local aplicado ao alvo.", "Transparency of the local target highlight.", "Transparencia del resaltado local del objetivo.", "目标本地高亮的透明度。", "Прозрачность локальной подсветки цели."},
    ["Distância máxima do saque"] = {"Limita a distância local; o prompt pode ter limite menor.", "Limits local distance; the prompt may have a lower limit.", "Limita la distancia local; el prompt puede tener un límite menor.", "限制本地距离；交互提示可能有更低限制。", "Ограничивает локальную дистанцию; у запроса может быть меньший предел."},
    ["Intervalo do saque"] = {"Espera entre verificações; os limites locais continuam ativos.", "Delay between checks; local rate limits remain active.", "Espera entre comprobaciones; los límites locales siguen activos.", "检查间隔；本地频率限制仍然有效。", "Пауза между проверками; локальные ограничения сохраняются."},
    ["Intervalo da recarga"] = {"Espera entre tentativas; o limite local continua ativo.", "Delay between attempts; the local rate limit remains active.", "Espera entre intentos; el límite local sigue activo.", "尝试间隔；本地频率限制仍然有效。", "Пауза между попытками; локальное ограничение сохраняется."},
    ["Valor local de munição"] = {"Valor tentado localmente ao ativar; pode não valer no servidor.", "Value attempted locally on activation; the server may ignore it.", "Valor intentado localmente al activar; el servidor puede ignorarlo.", "启用时尝试设置的本地值；服务器可能忽略。", "Локальное значение при включении; сервер может его игнорировать."},
    ["Atraso para renascer"] = {"Espera antes da tentativa local; o jogo pode recusar.", "Delay before the local attempt; the game may refuse it.", "Espera antes del intento local; el juego puede rechazarlo.", "本地尝试前的延迟；游戏可能拒绝。", "Задержка перед локальной попыткой; игра может её отклонить."},
    ["Alcance local da aura"] = {"Limita o alcance local; não garante dano no servidor.", "Limits local range; it does not guarantee server damage.", "Limita el alcance local; no garantiza daño en el servidor.", "限制本地范围；不保证服务器受到伤害。", "Ограничивает локальный радиус; урон на сервере не гарантирован."},
    ["Transparência dos chefes"] = {"Ajusta a transparência das marcações locais de chefes.", "Adjusts transparency of local boss markers.", "Ajusta la transparencia de marcas locales de jefes.", "调整本地首领标记的透明度。", "Настраивает прозрачность локальных меток боссов."},
    ["Transparência das saídas"] = {"Ajusta a transparência das marcações locais de saída.", "Adjusts transparency of local exit markers.", "Ajusta la transparencia de marcas locales de salida.", "调整本地出口标记的透明度。", "Настраивает прозрачность локальных меток выходов."},
    ["Número de estrelas"] = {"Ajusta a quantidade de estrelas do céu local.", "Adjusts the number of stars in the local sky.", "Ajusta el número de estrellas del cielo local.", "调整本地天空的星星数量。", "Изменяет количество звёзд локального неба."},
    ["Intensidade da tonalidade"] = {"Ajusta a intensidade do tom quente local.", "Adjusts the local warm tint intensity.", "Ajusta la intensidad del tono cálido local.", "调整本地暖色调强度。", "Изменяет интенсивность локального тёплого оттенка."},
    ["Transparência da água"] = {"Ajusta apenas a aparência local da água, não remove sua física.", "Adjusts only local water appearance, not its physics.", "Ajusta solo la apariencia local del agua, no su física.", "仅调整水的本地外观，不改变物理效果。", "Меняет только локальный вид воды, не физику."},
    ["Tamanho do painel"] = {"Ajusta o tamanho do texto do painel de jogadores.", "Adjusts player panel text size.", "Ajusta el tamaño del texto del panel de jugadores.", "调整玩家面板的文字大小。", "Изменяет размер текста панели игроков."},
    ["Intervalo do painel"] = {"Ajusta a frequência de atualização do painel de jogadores.", "Adjusts player panel refresh frequency.", "Ajusta la frecuencia de actualización del panel.", "调整玩家面板的更新频率。", "Изменяет частоту обновления панели игроков."},
    ["Transparência do personagem"] = {"Ajusta a transparência local quando Personagem está ativo.", "Adjusts local transparency when Character is enabled.", "Ajusta la transparencia local cuando Personaje está activo.", "角色选项启用时调整本地透明度。", "Настраивает локальную прозрачность при включённом персонаже."},
    ["Transparência das mãos"] = {"Ajusta a transparência local quando Mãos está ativo.", "Adjusts local transparency when Hands is enabled.", "Ajusta la transparencia local cuando Manos está activo.", "手部选项启用时调整本地透明度。", "Настраивает локальную прозрачность при включённых руках."},
    ["Transparência do item"] = {"Ajusta a transparência da ferramenta equipada quando a opção está ativa.", "Adjusts equipped tool transparency when the option is enabled.", "Ajusta la transparencia del objeto equipado cuando la opción está activa.", "选项启用时调整已装备工具的透明度。", "Настраивает прозрачность экипированного инструмента при включённой опции."},
}) do
    Library.Internal.tips[key] = { pt = words[1], en = words[2], es = words[3], zh = words[4], ru = words[5] }
end

local MODALS = {}
local ESP_KINDS = { Jogador = true, NPCs = true, Corpo = true, Recipiente = true, ["Item no chão"] = true, ["Itens de missão"] = true }
local function T(tab, name, default, tip)
    local unavailable = { ["Tiro por paredes"] = true, ["Avisos de denúncias"] = true, ["Mira falsa"] = true, ["Alternativa visível"] = true,
        ["Trocar personagem"] = true }
    local o = { Name = name, Default = default or false, Tooltip = tip or function() return Library.Internal.tipFor(name) end }
    if ESP_KINDS[name] then
        o.Callback = function(v) Library.ESPMaster[name] = v end
        Library.ESPMaster[name] = o.Default   -- o padrão da opção vale (senão ficaria sempre ligado)
    else
        local fn = Actions.player[name] or Actions.world[name] or Actions.extra[name]
            or Actions.character[name] or Actions.localfx[name] or Actions.combat[name]
        if name == "Ocultar indisponíveis" then
            o.Callback = function(v) Window:SetHideUnavailable(v) end
        elseif fn and not unavailable[name] then
            o.Callback = fn
        else
            -- Não exibir um controle funcional quando não há implementação.
            o.Disabled = true
            -- A explicação do estado pendente é resolvida dinamicamente na dica.
        end
    end
    if GEARS[name] then
        if name == "Avisos de denúncias" or name == "Notificar" then o.SettingsIcon = "message-circle" end
        o.Settings = buildSettings(name)
        if name ~= "Aura" and name ~= "Auréola" and name ~= "Círculo de salto" and name ~= "Rastro estelar" then
            o.SettingsPath = name
        end
    end
    if MODALS[name] then o.Modal = MODALS[name].build; o.ModalTitles = MODALS[name].titles; o.Settings = nil; o.Prebuild = true end
    if PREMIUM[name] then o.Premium = true end
    if name == "Buscar chefes" then o.Warning = true end
    o.CanSet = function(v)
        if Library.Safety:allow(name, v) then return true end
        notify("Indisponível durante o modo pânico: " .. name)
        return false
    end
    local control = tab:Toggle(o)
    Library.Safety:track(name, control)
    return control
end
local function S(tab, name, min, max, default, suffix, step, cb)
    return tab:Slider({ Name = name, Min = min, Max = max, Default = default, Suffix = suffix or "", Step = step or 1, Tooltip = Library.Internal.tipFor(name), Callback = cb or function(v) end })
end
-- ============ 50_tabs.luau :: Abas, painel do ESP, radar, busca de saque ============
-- ---------------- VISUAIS ----------------

-- ============================================================
--  Painel do ESP (Jogador / NPCs / Corpo): pré-visualização + lista de ajustes
--  A pré-visualização é um desenho; as opções ficam salvas no menu.
-- ============================================================
local function buildEspPanel(kind)
    return function(m)
        local B = Library.Bind
        local CVW, CVH, CX, CY = 212, 205, 106, 100
        local corpse = kind == "Corpo"
        local isProp = kind == "Recipiente" or kind == "Item no chão" or kind == "Itens de missão"
        local ORANGE = Color3.fromRGB(255, 120, 30)
        local DARK = Color3.fromRGB(22, 18, 18)
        local GREEN = Color3.fromRGB(70, 220, 90)
        local S = {
            highlight = { on = true, color = ORANGE, alpha = 0.8, outline = 1.5, outlineColor = DARK },
            box = { on = true, color = ORANGE, thick = 1, style = "Completa", corner = 14 },
            name = { on = true, color = Color3.new(1, 1, 1) },
            healthbar = { on = not corpse and not isProp, auto = false, color = GREEN, width = 4, side = "Esquerda" },
            health = { on = false, color = GREEN },
            distance = { on = true, color = Color3.fromRGB(235, 235, 235), unit = "m" },
            tracers = { on = false, color = Color3.fromRGB(255, 255, 255), thick = 1, origin = "Baixo" },
            skeleton = { on = false, color = Color3.fromRGB(255, 255, 255), thick = 1.5 },
            frozen = false, locked = false,
            lod = { on = true, near = 150 }, nearest = { on = false, color = Color3.fromRGB(255, 60, 60) },
            maxDist = 1000, textSize = 11, prevDist = 120, prevHp = (corpse or isProp) and 0 or 100,
        }
        S.kdr = { on = false }; S.reports = { on = false }
        S.arrows = { on = false, color = Color3.fromRGB(255, 90, 90), size = 18 }
        Library.ESP = Library.ESP or {}
        Library.ESP[kind] = S   -- o motor do ESP lê daqui
        local function new(class, props, parent)
            local i = Instance.new(class)
            for k, v in pairs(props or {}) do i[k] = v end
            i.Parent = parent
            return i
        end
        local function T(parent, props)
            props.BackgroundTransparency = 1
            props.FontFace = props.FontFace or Library.Fonts.Bold
            return new("TextLabel", props, parent)
        end
        local L = m.Left
        -- ---------- tela da pré-visualização ----------
        local cv = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(CVW, CVH), BorderSizePixel = 0, ClipsDescendants = true }, L)
        B(cv, "BackgroundColor3", "Background")
        new("UICorner", { CornerRadius = UDim.new(0, 5) }, cv)
        do local st = new("UIStroke", { Transparency = 0.45 }, cv); B(st, "Color", "Stroke") end
        for i = 1, 8 do   -- grade de fundo (efeito de scanner)
            local v = new("Frame", { Position = UDim2.fromOffset(i * 23.5, 0), Size = UDim2.fromOffset(1, CVH), BorderSizePixel = 0, BackgroundTransparency = 0.94 }, cv)
            B(v, "BackgroundColor3", "Text")
        end
        for i = 1, 6 do
            local h = new("Frame", { Position = UDim2.fromOffset(0, i * 29), Size = UDim2.fromOffset(CVW, 1), BorderSizePixel = 0, BackgroundTransparency = 0.94 }, cv)
            B(h, "BackgroundColor3", "Text")
        end
        -- pedestal (plataforma com borda de luz) embaixo do boneco
        local shadow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0 }, cv)
        local pedBase = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(1, 0.8),
            BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.25, BorderSizePixel = 0 }, shadow)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, pedBase)
        local pedTop = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(1, 0.8), BorderSizePixel = 0 }, shadow)
        B(pedTop, "BackgroundColor3", "Surface2")
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, pedTop)
        local pedStroke = new("UIStroke", { Thickness = 1.5, Transparency = 0.1 }, pedTop); B(pedStroke, "Color", "Accent")
        local pedInner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.6), BackgroundTransparency = 1 }, pedTop)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, pedInner)
        local pedInnerStroke = new("UIStroke", { Thickness = 1, Transparency = 0.5 }, pedInner); B(pedInnerStroke, "Color", "Accent")

        -- boneco em silhueta: blocos separados (cabeça, tronco, braços, pernas e
        -- pés), como um avatar blocudo. O "Corpo" usa a pose caída (deitado).
        local POSE = isProp and {
            w = 96, h = 76,
            parts = {
                { 8, 16, 80, 46, 4 },    -- corpo do recipiente
                { 8, 8, 80, 8, 3 },      -- tampa
                { 42, 16, 12, 12, 2 },   -- fecho
            },
            sk = {},
            skHead = nil,
        } or corpse and {
            w = 150, h = 72,
            parts = {
                { 4, 24, 26, 26, 13 },                          -- cabeça
                { 34, 16, 52, 40, 5 },                          -- tronco
                { 34, 2, 52, 12, 4 }, { 34, 54, 52, 12, 4 },    -- braços
                { 90, 16, 32, 18, 4 }, { 90, 40, 32, 18, 4 },   -- pernas
                { 126, 16, 20, 18, 4 }, { 126, 40, 20, 18, 4 }, -- pés
            },
            sk = {
                { 0.25, 0.50, 0.56, 0.50 }, { 0.25, 0.12, 0.25, 0.88 }, { 0.25, 0.12, 0.60, 0.12 }, { 0.25, 0.88, 0.60, 0.88 },
                { 0.56, 0.30, 0.56, 0.70 }, { 0.56, 0.30, 0.92, 0.30 }, { 0.56, 0.70, 0.92, 0.70 },
            },
            skHead = { 0.09, 0.5 },
        } or {
            w = 96, h = 132,
            parts = {
                { 33, 2, 30, 26, 9 },                              -- cabeça
                { 26, 32, 44, 42, 5 },                             -- tronco
                { 12, 32, 12, 22, 4 }, { 12, 54, 12, 20, 4 }, { 12, 74, 12, 10, 3 },   -- braço esquerdo
                { 72, 32, 12, 22, 4 }, { 72, 54, 12, 20, 4 }, { 72, 74, 12, 10, 3 },   -- braço direito
                { 27, 76, 19, 40, 4 }, { 27, 116, 19, 12, 4 },     -- perna esquerda
                { 50, 76, 19, 40, 4 }, { 50, 116, 19, 12, 4 },     -- perna direita
            },
            sk = {
                { 0.5, 0.27, 0.5, 0.62 }, { 0.22, 0.30, 0.78, 0.30 }, { 0.22, 0.30, 0.12, 0.46 }, { 0.12, 0.46, 0.12, 0.60 },
                { 0.78, 0.30, 0.88, 0.46 }, { 0.88, 0.46, 0.88, 0.60 }, { 0.38, 0.62, 0.62, 0.62 }, { 0.38, 0.62, 0.36, 0.80 },
                { 0.36, 0.80, 0.36, 0.97 }, { 0.62, 0.62, 0.64, 0.80 }, { 0.64, 0.80, 0.64, 0.97 },
            },
            skHead = { 0.5, 0.15 },
        }
        local fg = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(POSE.w, POSE.h), BackgroundTransparency = 1 }, cv)
        local fgScale = new("UIScale", { Scale = 1 }, fg)
        local parts = {}   -- { f = frame, st = stroke } (silhueta preenchida = chams)
        local function part(x, y, w, h, radius)
            local p = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, BorderSizePixel = 0 }, fg)
            new("UICorner", { CornerRadius = UDim.new(0, radius or 4) }, p)
            local st = new("UIStroke", { Thickness = 1, Transparency = 0.3 }, p)
            parts[#parts + 1] = { f = p, st = st }
            return p
        end
        local torso
        for i, p in ipairs(POSE.parts) do
            local f = part(p[1], p[2], p[3], p[4], p[5])
            if i == (isProp and 1 or 2) then torso = f end
        end
        local torsoText = torso and T(torso, { Size = UDim2.fromScale(1, 1), Text = "BBC HUB", TextSize = POSE.w < 120 and 9 or 13, TextColor3 = Color3.new(1, 1, 1), TextWrapped = false }) or nil

        -- esqueleto (linhas ligando as articulações) por cima do boneco
        local skLines = {}
        for i = 1, #POSE.sk do skLines[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, cv) end
        local skHead = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, cv)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, skHead)
        local skHeadStroke = new("UIStroke", { Thickness = 1.5 }, skHead)

        -- caixa (cantos ou completa)
        local brackets = {}
        for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
            for _, horiz in ipairs({ true, false }) do
                brackets[#brackets + 1] = { f = new("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), BorderSizePixel = 0 }, cv), cx = c[1], cy = c[2], horiz = horiz }
            end
        end
        local boxFull = new("Frame", { BackgroundTransparency = 1 }, cv)
        local boxFullStroke = new("UIStroke", { Thickness = 2 }, boxFull)
        local nameL = T(cv, { Size = UDim2.fromOffset(120, 14), Text = kind == "NPCs" and "NPC" or tr(kind) })
        local hbBg = new("Frame", { BackgroundColor3 = Color3.fromRGB(26, 26, 30), BorderSizePixel = 0 }, cv)
        new("UICorner", { CornerRadius = UDim.new(0, 2) }, hbBg)
        local hbFill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, hbBg)
        new("UICorner", { CornerRadius = UDim.new(0, 2) }, hbFill)
        local hpL = T(cv, { Size = UDim2.fromOffset(34, 12), Text = "100" })
        local distL = T(cv, { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(90, 12), FontFace = Library.Fonts.Regular, TextXAlignment = Enum.TextXAlignment.Center })
        local tracer = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0 }, cv)
        local arrow = Library.MakeIcon(cv, "navigation-2", 18, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CVW - 20, 20), Visible = false })
        local farDot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0 }, cv)
        new("UICorner", { CornerRadius = UDim.new(1, 0) }, farDot)
        local oorL = T(cv, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY + 4), Size = UDim2.fromOffset(150, 16), Text = tr("Fora do alcance"), TextSize = 12, Visible = false })
        B(oorL, "TextColor3", "Muted")

        -- botões rápidos (espelham a lista da direita; quebram de linha sozinhos)
        local chipDefs = { { "highlight", "Destaque" }, { "box", "Caixa" }, { "name", "Nome" }, { "healthbar", "Barra de vida" }, { "health", "Vida" }, { "distance", "Distância" } }
        if kind == "Jogador" then table.insert(chipDefs, { "kdr", "K/D" }); table.insert(chipDefs, { "reports", "Denúncias" }) end
        table.insert(chipDefs, { "tracers", "Linhas até alvos" }); table.insert(chipDefs, { "arrows", "Setas" }); table.insert(chipDefs, { "skeleton", "Esqueleto" })
        local chipFrame = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 213), Size = UDim2.fromOffset(CVW, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, L)
        new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, chipFrame)
        local chips, toggles = {}, {}
        for i, d in ipairs(chipDefs) do
            local b = new("TextButton", { Text = d[2], TextSize = 10, AutoButtonColor = false, FontFace = Library.Fonts.Bold, BorderSizePixel = 0, LayoutOrder = i,
                Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false }, chipFrame)
            new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, b)
            B(b, "BackgroundColor3", "Surface3"); B(b, "TextColor3", "Text")
            new("UICorner", { CornerRadius = UDim.new(0, 4) }, b)
            local st = new("UIStroke", { Thickness = 1 }, b)
            chips[d[1]] = { btn = b, stroke = st }
            Actions.connect(b.MouseButton1Click, function()
                if S.locked then return end
                if toggles[d[1]] then toggles[d[1]]:Set(not S[d[1]].on) end
            end)
        end

        local function hpColor()
            local hp = S.prevHp
            if not S.healthbar.auto then return S.healthbar.color end
            if hp > 60 then return Color3.fromRGB(70, 220, 90) elseif hp > 30 then return Color3.fromRGB(240, 200, 60) end
            return Color3.fromRGB(240, 80, 70)
        end
        local function at(frame, x, y) frame.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5)) end
        local function line(frame, x0, y0, x1, y1, thick)
            local dx, dy = x1 - x0, y1 - y0
            frame.Position = UDim2.fromOffset((x0 + x1) / 2, (y0 + y1) / 2)
            frame.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), thick)
            frame.Rotation = math.deg(math.atan2(dy, dx))
        end

        local function refresh()
            local d, maxd, ts = S.prevDist, S.maxDist, S.textSize
            local inRange = d <= maxd
            local far = S.lod.on and d > S.lod.near
            local details = inRange and not far
            local nearColor = S.nearest.on and S.nearest.color or nil -- a prévia simula um único alvo
            farDot.Visible = inRange and far and (S.box.on or S.highlight.on)
            farDot.BackgroundColor3 = nearColor or S.box.color
            -- o tamanho do boneco muda com a distância simulada
            local sc = math.clamp((80 / math.max(d, 20)) ^ 0.55, 0.28, 1.1)
            -- Evita desenho e rótulos fora de sincronia durante alterações rápidas.
            fgScale.Scale = sc
            local bw, bh = POSE.w * sc, POSE.h * sc
            local left, right, top, bottom = CX - bw / 2, CX + bw / 2, CY - bh / 2, CY + bh / 2
            shadow.Size = UDim2.fromOffset(bw * 1.45, math.max(12, 22 * sc)); at(shadow, CX, bottom + 3)
            -- chams: silhueta blocuda preenchida (laranja/vermelho) com contorno escuro fino
            local hl = S.highlight
            for _, p in ipairs(parts) do
                p.f.BackgroundColor3 = nearColor or hl.color
                p.f.BackgroundTransparency = hl.on and (1 - hl.alpha * (inRange and 1 or 0.35)) or 1
                p.st.Color = hl.outlineColor or Library.Theme.Muted
                p.st.Thickness = hl.on and math.max(hl.outline * 0.5, 0.5) or 1
                p.st.Transparency = hl.on and hl.outline > 0 and 0 or 1
            end
            if torsoText then
                torsoText.TextColor3 = hl.on and Color3.new(1, 1, 1) or Library.Theme.Text
                torsoText.TextTransparency = inRange and 0.1 or 0.7
            end
            -- esqueleto
            local sk = S.skeleton
            local showSk = sk.on and details
            for i, seg in ipairs(POSE.sk) do
                local ln = skLines[i]
                ln.Visible = showSk; ln.BackgroundColor3 = nearColor or sk.color
                line(ln, left + seg[1] * bw, top + seg[2] * bh, left + seg[3] * bw, top + seg[4] * bh, sk.thick)
            end
            if POSE.skHead then
                skHead.Visible = showSk; skHeadStroke.Color = nearColor or sk.color; skHeadStroke.Thickness = sk.thick
                local skr = math.min(bw, bh) * 0.3
                skHead.Size = UDim2.fromOffset(skr, skr)
                at(skHead, left + POSE.skHead[1] * bw, top + POSE.skHead[2] * bh)
            else
                skHead.Visible = false
            end
            -- caixa
            local th = S.box.thick
            local showBox = S.box.on and details
            local len = math.min(S.box.corner, bw / 2, bh / 2)
            for _, b in ipairs(brackets) do
                b.f.Visible = showBox and S.box.style == "Cantos"
                b.f.BackgroundColor3 = nearColor or S.box.color
                b.f.Size = b.horiz and UDim2.fromOffset(len, th) or UDim2.fromOffset(th, len)
                at(b.f, b.cx == 0 and left or right, b.cy == 0 and top or bottom)
            end
            boxFull.Visible = showBox and S.box.style == "Completa"
            boxFullStroke.Color = nearColor or S.box.color; boxFullStroke.Thickness = th
            boxFull.Size = UDim2.fromOffset(bw, bh); at(boxFull, left, top)
            -- nome
            nameL.Visible = S.name.on and details; nameL.TextColor3 = S.name.color; nameL.TextSize = ts; at(nameL, CX - 60, top - 18)
            -- barra de vida (lado, largura e cor automática pela vida)
            local W = S.healthbar.width
            local barX = S.healthbar.side == "Esquerda" and (left - 7 - W) or (right + 7)
            hbBg.Visible = S.healthbar.on and details
            hbBg.Size = UDim2.fromOffset(W, bh); at(hbBg, barX, top)
            hbFill.Size = UDim2.fromScale(1, math.clamp(S.prevHp / 100, 0, 1)); hbFill.BackgroundColor3 = hpColor()
            hpL.Visible = S.health.on and details; hpL.TextSize = ts
            hpL.Text = tostring(math.floor(S.prevHp)); hpL.TextColor3 = S.healthbar.auto and hpColor() or S.health.color
            if S.healthbar.side == "Esquerda" then
                hpL.AnchorPoint = Vector2.new(1, 0.5); hpL.TextXAlignment = Enum.TextXAlignment.Right; at(hpL, barX - 4, top + bh / 2)
            else
                hpL.AnchorPoint = Vector2.new(0, 0.5); hpL.TextXAlignment = Enum.TextXAlignment.Left; at(hpL, barX + W + 4, top + bh / 2)
            end
            -- distância
            distL.Visible = S.distance.on and inRange; distL.TextColor3 = S.distance.color; distL.TextSize = ts
            distL.Text = S.distance.unit == "m" and (d .. "m") or (math.floor(d / 0.28) .. " st"); at(distL, CX, far and (CY + 6) or (bottom + 3))
            -- linha (tracer) do ponto de origem até a caixa
            tracer.Visible = S.tracers.on and inRange; tracer.BackgroundColor3 = nearColor or S.tracers.color
            if S.tracers.origin == "Baixo" then line(tracer, CX, CVH, CX, bottom + 16, S.tracers.thick) else line(tracer, CX, 0, CX, top - 20, S.tracers.thick) end
            arrow.Visible = S.arrows.on; arrow.ImageColor3 = S.arrows.color; arrow.Size = UDim2.fromOffset(S.arrows.size, S.arrows.size)
            oorL.Visible = not inRange
            for key, c in pairs(chips) do c.stroke.Color = S[key].on and Library.Theme.Accent or Library.Theme.Stroke end
        end

        -- ---------- lista da direita ----------
        local R = m.Right
        local fold = R:Foldout({ Name = "Configurações gerais", Build = function(p)
            p:Slider({ Name = "Distância máx.", Min = 100, Max = 3000, Default = 1000, Suffix = "m", Step = 50, Callback = function(v) S.maxDist = v; refresh() end })
            p:Slider({ Name = "Tamanho do texto", Min = 9, Max = 16, Default = 11, Callback = function(v) S.textSize = v; refresh() end })
            p:Slider({ Name = "Distância da prévia", Min = 10, Max = 2000, Default = 120, Suffix = "m", Step = 10, Callback = function(v) S.prevDist = v; refresh() end })
            p:Slider({ Name = "Vida da prévia", Min = 0, Max = 100, Default = 100, Callback = function(v) S.prevHp = v; refresh() end })
            p:Toggle({ Name = "Só detalhes de perto", Default = true, Tooltip = tipText("Longe, mostra só um ponto e a distância. Perto, mostra tudo."), Callback = function(v) S.lod.on = v; refresh() end })
            p:Slider({ Name = "Detalhes até", Min = 20, Max = 1000, Default = 150, Suffix = "m", Step = 10, Callback = function(v) S.lod.near = v; refresh() end })
            p:Toggle({ Name = "Destacar mais próximo", Default = false, Tooltip = tipText("O alvo mais perto de você ganha outra cor."),
                Callback = function(v) S.nearest.on = v; refresh() end,
                Settings = function(q) q:ColorPicker({ Name = "Cor", Default = S.nearest.color, Callback = function(c) S.nearest.color = c; refresh() end }) end })
        end })
        local function add(key, label, extra)
            toggles[key] = R:Toggle({ Name = label, Default = S[key].on, Callback = function(v) S[key].on = v; refresh() end,
                Settings = function(p)
                    p:ColorPicker({ Name = "Cor", Default = S[key].color, Callback = function(c) S[key].color = c; refresh() end })
                    if extra then extra(p) end
                end })
        end
        add("highlight", "Destaque", function(p)
            p:ColorPicker({ Name = "Cor do contorno", Default = S.highlight.outlineColor, Callback = function(c) S.highlight.outlineColor = c; refresh() end })
            p:Slider({ Name = "Preenchimento", Min = 5, Max = 90, Default = S.highlight.alpha * 100, Suffix = "%", Callback = function(v) S.highlight.alpha = v / 100; refresh() end })
            p:Slider({ Name = "Contorno", Min = 0, Max = 4, Default = S.highlight.outline, Step = 0.5, Callback = function(v) S.highlight.outline = v; refresh() end })
        end)
        add("box", "Caixa", function(p)
            p:Dropdown({ Name = "Estilo", Options = { "Cantos", "Completa" }, Default = S.box.style, Callback = function(v) S.box.style = v; refresh() end })
            p:Slider({ Name = "Espessura", Min = 1, Max = 5, Default = S.box.thick, Callback = function(v) S.box.thick = v; refresh() end })
            p:Slider({ Name = "Tamanho do canto", Min = 6, Max = 30, Default = 14, Callback = function(v) S.box.corner = v; refresh() end })
        end)
        add("name", "Nome")
        add("healthbar", "Barra de vida", function(p)
            p:Toggle({ Name = "Cor automática", Default = S.healthbar.auto, Callback = function(v) S.healthbar.auto = v; refresh() end })
            p:Dropdown({ Name = "Posição", Options = { "Esquerda", "Direita" }, Default = "Esquerda", Callback = function(v) S.healthbar.side = v; refresh() end })
            p:Slider({ Name = "Largura da barra", Min = 2, Max = 10, Default = 4, Callback = function(v) S.healthbar.width = v; refresh() end })
        end)
        add("health", "Vida")
        add("distance", "Distância", function(p)
            p:Dropdown({ Name = "Unidade", Options = { "m", "studs" }, Default = "m", Callback = function(v) S.distance.unit = v; refresh() end })
        end)
        if kind == "Jogador" then
            toggles.kdr = R:Toggle({ Name = "K/D", Disabled = true, Tooltip = "Indisponível: não há fonte universal confiável para K/D de outros jogadores.", Settings = function(p) p:Label({ Text = "Indisponível neste jogo." }) end })
            toggles.reports = R:Toggle({ Name = "Denúncias", Disabled = true, Tooltip = "Indisponível: denúncias não são públicas.", Settings = function(p) p:Label({ Text = "Indisponível: denúncias não são públicas." }) end })
        end
        add("tracers", "Linhas até alvos", function(p)
            p:Dropdown({ Name = "Origem", Options = { "Baixo", "Cima" }, Default = "Baixo", Callback = function(v) S.tracers.origin = v; refresh() end })
            p:Slider({ Name = "Espessura", Min = 1, Max = 4, Default = 1, Callback = function(v) S.tracers.thick = v; refresh() end })
        end)
        add("arrows", "Setas", function(p)
            p:Slider({ Name = "Tamanho", Min = 12, Max = 30, Default = 18, Callback = function(v) S.arrows.size = v; refresh() end })
        end)
        add("skeleton", "Esqueleto", function(p)
            p:Slider({ Name = "Espessura", Min = 1, Max = 4, Default = 1.5, Step = 0.5, Callback = function(v) S.skeleton.thick = v; refresh() end })
        end)
        local hint = new("TextLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -4), Size = UDim2.new(1, -16, 0, 34),
            Text = tr("TOQUE: ALTERNAR · SEGURE: O QUE É") .. "\n" .. tr("TOQUE NO ÍCONE: AJUSTES"), TextSize = 10, FontFace = Library.Fonts.Regular, TextWrapped = true }, m.RightBox)
        B(hint, "TextColor3", "Muted")
        refresh()

        -- botões no título da prévia: ajustes gerais, travar e congelar a animação
        local RunService = game:GetService("RunService")
        local function headBtn(iconName, rightOffset)
            local b = new("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -rightOffset, 0, 2), Size = UDim2.fromOffset(26, 26),
                BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 3 }, m.LeftBox)
            local ic = Library.MakeIcon(b, iconName, 16, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 3 })
            return b, ic
        end
        local frozenBtn, frozenIcon = headBtn("snowflake", 6)
        local lockBtn, lockIcon = headBtn("lock", 34)
        local setBtn = headBtn("sliders-horizontal", 62)
        local function paintHead()
            frozenIcon.ImageColor3 = S.frozen and Library.Theme.Accent or Library.Theme.Text
            lockIcon.ImageColor3 = S.locked and Library.Theme.Accent or Library.Theme.Text
        end
        paintHead()
        Actions.connect(frozenBtn.MouseButton1Click, function() S.frozen = not S.frozen; paintHead() end)
        Actions.connect(lockBtn.MouseButton1Click, function() S.locked = not S.locked; paintHead() end)
        Actions.connect(setBtn.MouseButton1Click, function()
            fold.Set(not fold.IsOpen())
            m.RightScroll.CanvasPosition = Vector2.new(0, 0)
        end)

        -- animação leve: linha de varredura (scanner) e pedestal pulsando
        local scan = new("Frame", { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, -14), BorderSizePixel = 0, ZIndex = 2 }, cv)
        B(scan, "BackgroundColor3", "Accent")
        new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.85, 0.9), NumberSequenceKeypoint.new(1, 0.55) }) }, scan)
        local clock, conn = 0, nil
        conn = Actions.connect(RunService.Heartbeat, function(dt)
            if not cv.Parent then conn:Disconnect() return end
            if Library.ReduceMotion or S.frozen or not m.Overlay.Visible then return end
            clock += dt
            scan.Position = UDim2.fromOffset(0, math.floor((clock % 3.2) / 3.2 * (CVH + 14) - 14))
            pedStroke.Transparency = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(clock * 2.4))
        end)
    end
end
MODALS["Jogador"] = { build = buildEspPanel("Jogador"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO JOGADOR" } }
MODALS["NPCs"] = { build = buildEspPanel("NPCs"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO NPC" } }
MODALS["Corpo"] = { build = buildEspPanel("Corpo"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO CORPO" } }
MODALS["Recipiente"] = { build = buildEspPanel("Recipiente"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO RECIPIENTE" } }
MODALS["Item no chão"] = { build = buildEspPanel("Item no chão"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO ITEM" } }
MODALS["Itens de missão"] = { build = buildEspPanel("Itens de missão"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO ITEM DE MISSÃO" } }

local visuais = Window:Tab({ Name = "VISUAIS", Icon = "eye" })
local g = visuais:Groupbox({ Name = "ESP", Icon = "scan-eye", Side = "Left" })
for _, n in ipairs({ "Jogador", "NPCs", "Corpo", "Recipiente", "Item no chão", "Itens de missão" }) do
    T(g, n, n == "Jogador" or n == "NPCs" or n == "Corpo")
end
g = visuais:Groupbox({ Name = "INTERFACE DO JOGO", Icon = "layout-dashboard", Side = "Right" })
T(g, "Mochila personalizada"); T(g, "Mochila"); T(g, "Barra rápida")
g = visuais:Groupbox({ Name = "LOCAL", Icon = "map-pin", Side = "Right", Checkbox = true, Default = true, Callback = function(v) Actions.applyLocalFxAll(v) end })
for _, n in ipairs({ "Aura", "Círculo de salto", "Auréola", "Rastro estelar" }) do T(g, n) end
Actions.LOCALFX.ready = true

-- ---------------- JOGADOR ----------------
local jogador = Window:Tab({ Name = "JOGADOR", Icon = "user" })
g = jogador:Groupbox({ Name = "MOVIMENTO", Icon = "move", Side = "Left" })
T(g, "Hack de velocidade"); T(g, "Sprint automático"); T(g, "Pulos seguidos")
T(g, "Controle no ar"); T(g, "Voar"); T(g, "Sem dano de queda"); T(g, "Sempre no chão")
T(g, "Jesus"); T(g, "Aranha")
g = jogador:Groupbox({ Name = "CÂMERA", Icon = "camera", Side = "Left" })
T(g, "Terceira pessoa"); T(g, "Câmera livre")
g = jogador:Groupbox({ Name = "SAQUE", Icon = "package", Side = "Left" })
T(g, "Saque automático")
g = jogador:Groupbox({ Name = "MÃOS E ARMA", Icon = "hand", Side = "Right" })
for _, n in ipairs({ "Deslocamento", "Trocar personagem", "Personagem", "Corpo em 1ª pessoa", "Mãos", "Item na mão" }) do T(g, n) end
g = jogador:Groupbox({ Name = "CAMPO DE VISÃO", Icon = "focus", Side = "Right" })
S(g, "Campo de visão", 30, 120, 120, "", 1, function(v) Actions.CAM.fov = v; Actions.applyFov() end)
S(g, "Visão com zoom", 5, 120, 5, "", 1, function(v) Actions.CAM.zoom = v; Actions.applyFov() end)
g:Keybind({ Name = "Zoom", Default = "N", OnChanged = function(k) keys.zoom = k.Name; Actions.setZoomKey(k.Name); refreshPanels() end, Callback = function() end })
g = jogador:Groupbox({ Name = "ANIMAÇÕES", Icon = "activity", Side = "Right" })
g:Dropdown({ Name = "Animação", Options = { "Swish", "Padrão" }, Default = "Swish", Callback = function(v) Actions.CHAR.anim = v end })
T(g, "Repetir", false, nil)
S(g, "Velocidade", 0.1, 3, 1, "x", 0.1, function(v) Actions.CHAR.speed = v end)
S(g, "Peso", 0, 100, 100, "%", 1, function(v) Actions.CHAR.weight = v end)
g:Button({ Name = "Reproduzir", Callback = function() Actions.playAnim() end })
g = jogador:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Right" })
T(g, "Painel do jogador"); T(g, "Anti AFK"); T(g, "Renascer automático")
T(g, "Remover água"); T(g, "Não se afogar"); T(g, "Mapa e navegação", true)

-- ---------------- COMBATE ----------------
local combate = Window:Tab({ Name = "COMBATE", Icon = "crosshair" })
g = combate:Groupbox({ Name = "MIRA", Icon = "crosshair", Side = "Left", Checkbox = true, Default = false,
    CanSet = function(v)
        if Library.Safety:allow("MIRA", v) then return true end
        notify("Indisponível durante o modo pânico: MIRA")
        return false
    end,
    Callback = function(v) Actions.COMBAT.on = v; Actions.applyAimState() end })
Library.Safety:track("MIRA", g.Checkbox)
g:Segmented({ Name = "Modo", Options = { "Silencioso", "Fixar", "Agressivo" }, Icons = { "crosshair", "lock", "flame" }, Default = "Fixar",
    Tooltip = "Fixar usa a mira de câmera. Silencioso e Agressivo ainda não estão implementados.",
    CanSelect = function(v, quiet)
        if v == "Fixar" then return true end
        if not quiet then notify(v .. ": modo indisponível; apenas Fixar está implementado.") end
        return false
    end })
g:Dropdown({ Name = "Ativação", Options = { "Ao mirar", "Sempre" }, Default = "Ao mirar", Callback = function(v) Actions.COMBAT.activation = v end })
T(g, "Alvo fixo"); T(g, "Previsão")
S(g, "Suavização", 0, 300, 80, "ms", 1, function(v) Actions.COMBAT.smooth = v / 300; Actions.clampCfg() end)
T(g, "Pausa inteligente"); T(g, "Notificar", true)
g = combate:Groupbox({ Name = "ALVOS", Icon = "target", Side = "Left" })
S(g, "Raio da mira", 10, 500, 70, "", 1, function(v) Actions.COMBAT.radius = v; Actions.clampCfg() end)
T(g, "FOV dinâmico", true)
g:Dropdown({ Name = "Ponto de mira", Options = { "Partes selecionadas", "Mais próximo" }, Default = "Partes selecionadas", Callback = function(v) Actions.COMBAT.aimPoint = v end })
g:Dropdown({ Name = "Partes do corpo", Options = { "Cabeça", "Corpo", "Braços", "Pernas" }, Default = { "Cabeça" }, Multi = true, Callback = function(v)
    Actions.COMBAT.parts = {}
    for _, part in ipairs(type(v) == "table" and v or { v }) do Actions.COMBAT.parts[part] = true end
end })
T(g, "Alternativa visível", true); T(g, "Mirar em NPCs", true); T(g, "Tiro por paredes", true)
T(g, "Ignorar obstáculos na mira", true)
g:Keybind({ Name = "Adicionar amigo", Default = "MB3", Callback = function()
    local t = Actions.AIM.target and Actions.AIM.target.t
    if t and t.plr then Actions.COMBAT.friends[t.plr] = true; Actions.say("Amigo: " .. t.plr.Name) else Actions.say("Sem alvo no momento.") end
end })
S(g, "Limite de verificações", 1, 20, 7, "", 1, function(v) Actions.COMBAT.maxChecks = v; Actions.clampCfg() end)
g = combate:Groupbox({ Name = "ESPIADA", Icon = "eye", Side = "Left" })
T(g, "Espiada subterrânea")
g = combate:Groupbox({ Name = "CORPO A CORPO", Icon = "swords", Side = "Left" })
T(g, "Aura letal")
g = combate:Groupbox({ Name = "ARMA", Icon = "target", Side = "Right" })
T(g, "Recarga automática"); T(g, "Abastecer cargadores")
g:Button({ Name = "Manuseio da arma", Arrow = true, Callback = function()
    local m = Window:_getModal("combate/manuseio", { Left = "MANUSEIO DA ARMA", Right = "AJUSTES" }, function(mm)
        mm.Right:Slider({ Name = "Recuo", Min = 0, Max = 100, Default = 20, Suffix = "%", Callback = function(v) Actions.WEAPON.recoil = v / 100 end })
        mm.Right:Label({ Text = "Recuo ajusta a mira, não as configurações da arma." })
    end)
    m.Overlay.Visible = true
end })
T(g, "Mira falsa")
g = combate:Groupbox({ Name = "EFEITOS DE COMBATE", Icon = "sparkles", Side = "Right" })
T(g, "Retícula"); T(g, "Círculo da mira", true); T(g, "Rastro personalizado")
T(g, "Rastros do jogo"); T(g, "Marca de acerto", true); T(g, "Números de dano", true)
T(g, "Efeitos de acerto", true); T(g, "Efeitos de eliminação"); T(g, "Dados do alvo", true)
T(g, "Só acertos confirmados", true)
g = combate:Groupbox({ Name = "ANTI AIM", Icon = "shield", Side = "Right" })
T(g, "Anti aim"); T(g, "Sob o chão"); T(g, "Fantasma")
g = combate:Groupbox({ Name = "GRANADAS", Icon = "bomb", Side = "Right" })
T(g, "Trajetória do arremesso"); T(g, "Sem tremor", true)

-- ---------------- MUNDO ----------------
local mundo = Window:Tab({ Name = "MUNDO", Icon = "globe" })
g = mundo:Groupbox({ Name = "MUNDO", Icon = "globe", Side = "Left" })
g:Foldout({ Name = "Cores do terreno", Build = function(p)
        p:ColorPicker({ Name = "Grama", Default = Color3.fromRGB(72, 160, 76), Callback = function(c) Actions.WORLD_COLORS.grama = c; Actions.paintTerrain("grama", c) end })
        p:ColorPicker({ Name = "Areia", Default = Color3.fromRGB(214, 190, 120), Callback = function(c) Actions.WORLD_COLORS.areia = c; Actions.paintTerrain("areia", c) end })
        p:ColorPicker({ Name = "Rocha", Default = Color3.fromRGB(120, 120, 126), Callback = function(c) Actions.WORLD_COLORS.rocha = c; Actions.paintTerrain("rocha", c) end })
        p:ColorPicker({ Name = "Terra", Default = Color3.fromRGB(110, 78, 52), Callback = function(c) Actions.WORLD_COLORS.terra = c; Actions.paintTerrain("terra", c) end })
    end })
g:Foldout({ Name = "Folhas", Build = function(p)
        p:ColorPicker({ Name = "Cor das folhas", Default = Color3.fromRGB(70, 150, 70), Callback = function(c) Actions.WORLD_COLORS.folhas = c; Actions.paintPlants("folhas", c) end })
    end })
g:Foldout({ Name = "Troncos", Build = function(p)
        p:ColorPicker({ Name = "Cor dos troncos", Default = Color3.fromRGB(100, 70, 45), Callback = function(c) Actions.WORLD_COLORS.troncos = c; Actions.paintPlants("troncos", c) end })
    end })
g:ColorPicker({ Name = "Cor da água", Default = Color3.fromRGB(40, 70, 75), Callback = function(c) Actions.WORLD_COLORS.agua = c; Actions.paintTerrain("agua", c) end })
T(g, "Sem grama", true); T(g, "Desativar minas", true)
g = mundo:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Left" })
T(g, "Carregar jogadores"); T(g, "Buscar chefes"); T(g, "Pontos de saída", true)
Library.RadarCfg = { on = false, range = 150, size = 130, npcs = false, pos = { x = 0.88, y = 0.3 } }
g:Toggle({ Name = "Radar", Default = false, Tooltip = tipText("Mini mapa redondo com os jogadores ao redor. Arraste para mover."),
    Callback = function(v) Library.RadarCfg.on = v end,
    Settings = function(p)
        p:Slider({ Name = "Alcance", Min = 50, Max = 500, Default = 150, Suffix = "m", Step = 10, Callback = function(v) Library.RadarCfg.range = v end })
        p:Slider({ Name = "Tamanho", Min = 90, Max = 220, Default = 130, Step = 5, Callback = function(v) Library.RadarCfg.size = v end })
        p:Toggle({ Name = "Mostrar NPCs", Default = false, Callback = function(v) Library.RadarCfg.npcs = v end })
    end })
g = mundo:Groupbox({ Name = "ILUMINAÇÃO", Icon = "lightbulb", Side = "Right", Checkbox = true, Default = true, Callback = function(v) Actions.WORLD.master = v; Actions.applyLighting() end })
for _, n in ipairs({ "Luz", "Hora e sol", "Sombras", "Renderização", "Neblina", "Atmosfera", "Céu", "Nuvens",
    "Florescer", "Desfoque", "Ajuste de cor", "Profundidade", "Raios de sol", "Tonalidade" }) do
    T(g, n, n == "Luz" or n == "Hora e sol")
end

-- ---------------- EXTRAS ----------------
local extras = Window:Tab({ Name = "EXTRAS", Icon = "layout-grid" })
g = extras:Groupbox({ Name = "EXTRAS", Icon = "layout-grid", Side = "Left" })
T(g, "Troca rápida"); T(g, "Modo pânico"); g:Button({ Name = "Atravessar porta", Callback = function() if Library.Safety:allow("Atravessar porta", true) then Actions.noclipPulse() else notify("Indisponível durante o modo pânico.") end end })
T(g, "Remover efeitos"); T(g, "Avisos de denúncias", true); T(g, "Avisos de entrada")
g = extras:Groupbox({ Name = "SONS", Icon = "volume-2", Side = "Left" })
g:Input({ Name = "Adicionar ID de som", Placeholder = "ID", Callback = function(v) Actions.setSoundId(v) end })
for _, n in ipairs({ "Jump", "Pegadas", "Pouso", "Capacete", "Tiro na cabeça", "Tiro no corpo", "Abate", "Disparo", "Acerto com sangue" }) do
    T(g, n, n == "Disparo")
end
g = extras:Groupbox({ Name = "DETECÇÃO", Icon = "radar", Side = "Right" })
T(g, "Criador"); T(g, "Testador"); T(g, "Moderador", true); T(g, "Trapaceiro")
g = extras:Groupbox({ Name = "ORDENAR DEPÓSITO", Icon = "arrow-down-up", Side = "Right" })
g:Button({ Name = "Por valor", Callback = function() Actions.sortBackpack("valor") end })
g:Button({ Name = "Por tipo", Callback = function() Actions.sortBackpack("tipo") end })
g:Button({ Name = "Por nome", Callback = function() Actions.sortBackpack("nome") end })
g = extras:Groupbox({ Name = "VER INVENTÁRIO", Icon = "backpack", Side = "Right" })
g:Keybind({ Name = "Ver inventário", Default = "Backquote", Callback = function() Actions.toggleInv() end })
g:Dropdown({ Name = "Mostrar", Options = { "Jogadores", "NPCs", "Todos" }, Default = "Jogadores", Callback = function(v) Actions.INV.mode = v; if Actions.INV.on then Actions.refreshInv() end end })
T(g, "Sempre mostrar")

-- ---------------- BUSCAR SAQUE / SERVIDORES / SKINS / MISSÕES / COMERCIANTES ----------------
local saque = Window:Tab({ Name = "BUSCAR SAQUE", Icon = "package-search" })
Library.LootCfg = { rarities = { ["Mítico"] = true, ["Lendário"] = true, ["Épico"] = true, ["Raro"] = true }, maxDist = 300, query = "", mark = false, force = true, until_ = 0 }
do
    local LF = Library.LootCfg
    local RAR_OPTS = { "Mítico", "Lendário", "Épico", "Raro", "Incomum", "Comum", "Outros" }
    local fg = saque:Groupbox({ Name = "FILTROS", Icon = "filter", Side = "Left" })
    fg:Dropdown({ Name = "Raridade", Multi = true, Options = RAR_OPTS, Default = { "Mítico", "Lendário", "Épico", "Raro" },
        Callback = function(v)
            LF.rarities = {}
            for _, r in ipairs(type(v) == "table" and v or { v }) do LF.rarities[r] = true end
            LF.force = true
        end })
    fg:Slider({ Name = "Distância máx.", Min = 20, Max = 1000, Default = 300, Suffix = "m", Step = 10, Callback = function(v) LF.maxDist = v; LF.force = true end })
    fg:Input({ Name = "Buscar por nome", Placeholder = "ex: arma", Callback = function(t) LF.query = string.lower(t or ""); LF.force = true end })
    fg:Toggle({ Name = "Marcar na tela", Default = false, Tooltip = tipText("Mostra o nome e a distância dos itens encontrados direto no jogo, na cor da raridade."),
        Callback = function(v) LF.mark = v; LF.force = true end })
    fg:Button({ Name = "Buscar agora", Callback = function() LF.until_ = os.clock() + 30; LF.force = true end })
    local rg = saque:Groupbox({ Name = "RESULTADOS", Icon = "package-search", Side = "Right" })
    LF.status = rg:Label({ Text = "Toque em Buscar agora para listar o saque por perto." })
    LF.rows = {}
    for i = 1, 25 do
        local r = rg:Label({ Text = "" })
        r.Label.RichText = true
        r.Frame.Visible = false
        LF.rows[i] = r
    end
end
local servidores = Window:Tab({ Name = "SERVIDORES", Icon = "server" })
buildServers(servidores)
local skins = Window:Tab({ Name = "SKINS", Icon = "palette" })
skins:Section("SKINS")
local missoes = Window:Tab({ Name = "MISSÕES", Icon = "scroll-text" })
missoes:Section("MISSÕES")
local comerciantes = Window:Tab({ Name = "COMERCIANTES", Icon = "shopping-cart" })
comerciantes:Section("COMERCIANTES")

-- ---------------- CONFIGURAÇÕES ----------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local overlay = Instance.new("ScreenGui")
Library:ProtectGui(overlay)
overlay.Name = "BBCOverlay"; overlay.ResetOnSpawn = false; overlay.IgnoreGuiInset = true; overlay.DisplayOrder = 998
local overlayParent = Library:ParentGui(overlay)

local function makePanel(name, pos)
    local f = Instance.new("Frame")
    f.Name = name; f.Position = pos; f.AutomaticSize = Enum.AutomaticSize.None
    f.BackgroundColor3 = Color3.fromRGB(10, 10, 10); f.BorderSizePixel = 0; f.Parent = overlay
    local c = Instance.new("UICorner", f)
    local st = Instance.new("UIStroke", f); st.Color = Library.Theme.Accent
    local t = Instance.new("TextLabel", f)
    t.BackgroundTransparency = 1; t.Size = UDim2.new(1, -16, 1, -8); t.Position = UDim2.fromOffset(8, 4)
    t.TextXAlignment = Enum.TextXAlignment.Left; t.TextYAlignment = Enum.TextYAlignment.Top
    t.FontFace = Library.Fonts.Regular; t.TextSize = 14; t.TextColor3 = Color3.fromRGB(235, 235, 235)
    t.RichText = true; t.Text = ""
    return f, c, st, t
end

local WM = { Shadow = true, On = false, Pin = false, Size = 100, Width = 285, MaxH = 290, BgT = 0.10, TxtT = 0, BrdT = 0, Radius = 6, Fields = { "Nome", "FPS", "Ping" } }
local KL = { Shadow = true, Pin = false, On = false, Size = 100, Width = 250, MaxH = 260, BgT = 0.05, TxtT = 0, BrdT = 0.75, Radius = 7 }
local wmFrame, wmCorner, wmStroke, wmText = makePanel("Watermark", UDim2.fromOffset(12, 12))
local klPinToggle
local klFrame = Instance.new("Frame")
klFrame.Name = "KeybindList"; klFrame.BorderSizePixel = 0; klFrame.ClipsDescendants = true
klFrame.Position = UDim2.new(0, 14, 0.28, 0); klFrame.Size = UDim2.fromOffset(250, 150); klFrame.Parent = overlay
local klCorner = Instance.new("UICorner", klFrame)
local klStroke = Instance.new("UIStroke", klFrame)
local klScale = Instance.new("UIScale", klFrame)
-- cabeçalho: ícone de lista, título e alfinete (fixar)
local klHead = Instance.new("Frame", klFrame)
klHead.BackgroundTransparency = 1; klHead.Size = UDim2.new(1, 0, 0, 34); klHead.Active = true
Library.MakeIcon(klHead, "align-left", 16, "Muted", { Position = UDim2.fromOffset(12, 9) })
local klTitle = Instance.new("TextLabel", klHead)
klTitle.BackgroundTransparency = 1; klTitle.Position = UDim2.fromOffset(38, 0); klTitle.Size = UDim2.new(1, -80, 1, 0)
klTitle.TextXAlignment = Enum.TextXAlignment.Left; klTitle.FontFace = Library.Fonts.Bold; klTitle.TextSize = 14
local klPin = Instance.new("TextButton", klHead)
klPin.AnchorPoint = Vector2.new(1, 0.5); klPin.Position = UDim2.new(1, -8, 0.5, 0); klPin.Size = UDim2.fromOffset(28, 28)
klPin.BackgroundTransparency = 1; klPin.Text = ""; klPin.AutoButtonColor = false
local klPinIcon = Library.MakeIcon(klPin, "pin", 16, "Muted", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
local function paintPin() klPinIcon.ImageColor3 = KL.Pin and Library.Theme.Accent or Library.Theme.Muted end
Actions.connect(klPin.MouseButton1Click, function()
    KL.Pin = not KL.Pin
    paintPin()
    if klPinToggle then klPinToggle:Set(KL.Pin, true) end
end)
-- lista com rolagem própria
local klScroll = Instance.new("ScrollingFrame", klFrame)
klScroll.BackgroundTransparency = 1; klScroll.BorderSizePixel = 0; klScroll.Position = UDim2.fromOffset(0, 36); klScroll.Size = UDim2.new(1, 0, 1, -40)
klScroll.ScrollBarThickness = 2; klScroll.CanvasSize = UDim2.new(); klScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
klScroll.ScrollingDirection = Enum.ScrollingDirection.Y
local klList = Instance.new("UIListLayout", klScroll); klList.SortOrder = Enum.SortOrder.LayoutOrder; klList.Padding = UDim.new(0, 0)
local klRowsRef = {}
local function recolorKL()
    local T = Library.Theme
    klFrame.BackgroundColor3 = T.Background; klStroke.Color = T.Stroke; klTitle.TextColor3 = T.Text
    klScroll.ScrollBarImageColor3 = T.Muted
    paintPin()
    for _, r in ipairs(klRowsRef) do
        if r.name.Parent then r.name.TextColor3 = T.Text; r.key.TextColor3 = r.listening and T.Accent or T.Muted end
    end
end
local KL_FIRST = { ["Tecla do menu"] = 1, ["Tecla do cursor"] = 2 }
local function renderKL()
    for _, c in ipairs(klScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    klRowsRef = {}
    klTitle.Text = tr("Atalhos")
    local items = {}
    for i, kb in ipairs(Library.Keybinds) do
        local v = kb.get()
        if v then table.insert(items, { kb = kb, v = v, order = KL_FIRST[kb.name] or (10 + i) }) end
    end
    table.sort(items, function(x, y) return x.order < y.order end)
    for i, it in ipairs(items) do
        local kb, v = it.kb, it.v
        local row = Instance.new("Frame", klScroll); row.BackgroundTransparency = 1; row.Size = UDim2.new(1, 0, 0, 28); row.LayoutOrder = i
        local listening = kb.listening and kb.listening()
        local keyL = Instance.new("TextLabel", row)
        keyL.BackgroundTransparency = 1; keyL.Position = UDim2.fromOffset(12, 0); keyL.Size = UDim2.fromOffset(76, 28); keyL.TextXAlignment = Enum.TextXAlignment.Left
        keyL.FontFace = Library.Fonts.Regular; keyL.TextSize = 12; keyL.TextTruncate = Enum.TextTruncate.AtEnd
        keyL.Text = listening and "..." or ((v.Name == "MouseButton3" and "MB3") or (v.Name == "MouseButton2" and "MB2") or v.Name)
        local nameL = Instance.new("TextLabel", row)
        nameL.BackgroundTransparency = 1; nameL.Position = UDim2.fromOffset(92, 0); nameL.Size = UDim2.new(1, -128, 1, 0); nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.FontFace = Library.Fonts.Bold; nameL.TextSize = 13; nameL.TextTruncate = Enum.TextTruncate.AtEnd; nameL.Text = tr(kb.name)
        local edit = Instance.new("TextButton", row)
        edit.AnchorPoint = Vector2.new(1, 0.5); edit.Position = UDim2.new(1, -8, 0.5, 0); edit.Size = UDim2.fromOffset(26, 26)
        edit.BackgroundTransparency = 1; edit.Text = ""; edit.AutoButtonColor = false
        Library.MakeIcon(edit, "sliders-horizontal", 16, "Muted", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
        Actions.connect(edit.MouseButton1Click, function() if kb.begin then kb.begin() end end)
        table.insert(klRowsRef, { key = keyL, name = nameL, listening = listening })
    end
    klFrame.Size = UDim2.fromOffset(KL.Width, math.min(42 + #items * 28, KL.MaxH))
    recolorKL()
end
table.insert(Library._kbListeners, renderKL)
table.insert(Library._themeListeners, recolorKL)

local function applyPanel(cfg, frame, corner, stroke, text, height)
    frame.Visible = cfg.On
    local sc = cfg.Size / 100
    frame.Size = UDim2.fromOffset(math.min(cfg.Width, 600) * sc, math.min(height, cfg.MaxH) * sc)
    frame.BackgroundTransparency = cfg.BgT
    text.TextTransparency = cfg.TxtT
    text.TextSize = math.floor(14 * sc)
    stroke.Transparency = cfg.BrdT
    corner.CornerRadius = UDim.new(0, cfg.Radius)
    text.TextStrokeTransparency = cfg.Shadow and 0.6 or 1
end
refreshPanels = function()
    applyPanel(WM, wmFrame, wmCorner, wmStroke, wmText, 28)
    klFrame.Visible = KL.On
    klScale.Scale = KL.Size / 100
    klFrame.BackgroundTransparency = KL.BgT
    klStroke.Transparency = KL.BrdT
    klCorner.CornerRadius = UDim.new(0, KL.Radius)
    renderKL()
end
table.insert(onLanguageChanged, refreshPanels)

-- arrastar painéis (mouse ou toque), a menos que "Fixar" esteja ligado
local function makeDraggable(handle, cfg, target)
    local frame = target or handle
    handle.Active = true
    local dragging, startPos, startInput
    Actions.connect(handle.InputBegan, function(i)
        if cfg.Pin then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, frame.Position
        end
    end)
    Actions.connect(LangUIS.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    Actions.connect(LangUIS.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end
makeDraggable(wmFrame, WM)
makeDraggable(klHead, KL, klFrame)

-- Cursor livre: segurando a tecla do cursor, o mouse é liberado para clicar no menu
local cursorFree, cursorHeld, cursorKey = true, false, Enum.KeyCode.LeftAlt
Library:OnPanic(function(on)
    if on then
        cursorHeld = false
        Actions.restoreProperty(LangUIS, "MouseBehavior")
        Actions.restoreProperty(LangUIS, "MouseIconEnabled")
    end
end)
Actions.connect(LangUIS.InputBegan, function(i) if cursorFree and i.KeyCode == cursorKey then cursorHeld = true end end)
Actions.connect(LangUIS.InputEnded, function(i) if i.KeyCode == cursorKey then cursorHeld = false end end)
Actions.connect(RunService.RenderStepped, function()
    if cursorHeld and not Library.Panic then
        Actions.setProperty(LangUIS, "MouseBehavior", Enum.MouseBehavior.Default)
        Actions.setProperty(LangUIS, "MouseIconEnabled", true)
    else
        Actions.restoreProperty(LangUIS, "MouseBehavior")
        Actions.restoreProperty(LangUIS, "MouseIconEnabled")
    end
end)
local frames, last = 0, os.clock()
local fps = 60
Actions.connect(RunService.Heartbeat, function()
    frames += 1
    if os.clock() - last >= 1 then fps = frames; frames = 0; last = os.clock() end
    local parts = { "<b>BBC HUB</b>" }
    for _, f in ipairs(WM.Fields) do
        if f == "Nome" then table.insert(parts, Players.LocalPlayer.Name)
        elseif f == "FPS" then table.insert(parts, fps .. " FPS")
        elseif f == "Ping" then
            local ok, ping = pcall(function() return math.floor(Players.LocalPlayer:GetNetworkPing() * 1000) end)
            table.insert(parts, (ok and ping or 0) .. " ms")
        elseif f == "Hora" then table.insert(parts, os.date("%H:%M")) end
    end
    wmText.Text = table.concat(parts, "  |  ")
end)
refreshPanels()

local function bind(cfg, key, v) cfg[key] = v; refreshPanels() end
local function SB(grp, name, min, max, def, suffix, step, cfg, key)
    return grp:Slider({ Name = name, Min = min, Max = max, Default = def, Suffix = suffix or "", Step = step or 1, Tooltip = Library.Internal.tipFor(name),
        Callback = function(v) bind(cfg, key, v) end })
end


local FONT_URLS = {
    ["Press Start 2P"] = { Name = "PressStart2P", Weights = { Regular = "https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/PressStart2P-Regular.ttf" } },
    ["Silkscreen"] = { Name = "Silkscreen", Weights = {
        Regular = "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Regular.ttf",
        Bold = "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Bold.ttf" } },
}
local function retagFonts(root)
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
            local bold = d:GetAttribute("bbcBold")
            if bold == nil then
                bold = d.FontFace.Weight.Value >= 600
                d:SetAttribute("bbcBold", bold)
            end
            d.FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular
        end
    end
end
local function setFont(name)
    if name == "Arimo" then
        Library.Fonts.Regular = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Regular)
        Library.Fonts.Medium = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Medium)
        Library.Fonts.Bold = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold)
    elseif name == "Arcade" or name == "Code" then
        local f = Font.fromEnum(name == "Arcade" and Enum.Font.Arcade or Enum.Font.Code)
        Library.Fonts.Regular, Library.Fonts.Medium, Library.Fonts.Bold = f, f, f
    elseif FONT_URLS[name] then
        if not Library:LoadFont(FONT_URLS[name]) then
            notify("Fonte indisponível neste executor (precisa de writefile e getcustomasset).")
            return
        end
    else
        return
    end
    if Window.Gui then retagFonts(Window.Gui) end
    retagFonts(overlay)
end

local cfg = Window:Tab({ Name = "CONFIGURAÇÕES", Icon = "settings", Hidden = true, IsSettings = true })

-- Configuração do menu usa o mesmo armazenamento já existente; não apaga perfis.
do
    local box = cfg:Groupbox({ Name = "CONFIGURAÇÃO DO MENU", Icon = "save", Side = "Right" })
    local name = box:Input({ Name = "Nome da configuração", Default = "default", NoPersist = true,
        Tooltip = function() return tr("Escolha um nome para salvar ou carregar os ajustes do menu.") end, Callback = function() end })
    Window._cfgBox = name.Box
    if Window._headerCfgBox then
        local headerBox = Window._headerCfgBox
        Actions.connect(headerBox:GetPropertyChangedSignal("Text"), function() if name.Box.Text ~= headerBox.Text then name.Box.Text = headerBox.Text end end)
        Actions.connect(name.Box:GetPropertyChangedSignal("Text"), function() if headerBox.Text ~= name.Box.Text then headerBox.Text = name.Box.Text end end)
    end
    local active = box:Label({ Text = "Ativa: —" })
    local choices = box:Dropdown({ Name = "Configurações disponíveis", Options = {}, NoPersist = true,
        Tooltip = function() return tr("Seleciona um arquivo existente sem carregá-lo.") end,
        Callback = function(value) if type(value) == "string" then name.Box.Text = value end end })
    local function refreshConfigs()
        local names = Window:ListConfigs()
        choices:SetOptions(names)
        if Window._cfgName and table.find(names, Window._cfgName) then choices:Set(Window._cfgName, true) end
        active:Set(tr("Ativa") .. ": " .. (Window._cfgName or "—"))
        if Window._refreshHomeFavorites then Window._refreshHomeFavorites() end
    end
    Window._configChanged = refreshConfigs
    table.insert(onLanguageChanged, refreshConfigs)
    box:Button({ Name = "Atualizar lista", Tooltip = function() return tr("Lista arquivos de configuração disponíveis no executor.") end, Callback = function()
        if type(listfiles) ~= "function" then notify(tr("Listagem indisponível neste executor.")); return end
        refreshConfigs()
    end })
    box:Button({ Name = "Salvar configuração", Tooltip = function() return tr("Salva os ajustes atuais e seleciona este arquivo para iniciar.") end, Callback = function()
        local n = Library.CleanName(name.Box.Text)
        if n == "" then n = "default" end
        local ok, reason = Window:RequestSaveConfig(n)
        if ok then
            name.Box.Text = n
            if not Window:SetAutoload(n) then notify(tr("Salvo, mas não foi possível selecionar o carregamento inicial.")) end
        elseif reason == "confirmar" then
            notify(tr("Toque em Salvar novamente em até 30 segundos para confirmar."))
        elseif reason == "alterado" then
            notify(tr("Arquivo ou ajustes mudaram; confirme novamente."))
        else
            notify(tr("Falha ao salvar; veja o diagnóstico.") .. " " .. tostring(reason))
        end
    end })
    local previewSummary = box:Label({ Text = "" })
    local previewList = Instance.new("ScrollingFrame")
    previewList.Size = UDim2.new(1, -16, 0, 110); previewList.BackgroundTransparency = 1; previewList.BorderSizePixel = 0
    previewList.LayoutOrder = box:_nextOrder(); previewList.ScrollBarThickness = 4; previewList.Visible = false
    previewList.CanvasSize = UDim2.new(); previewList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    previewList.Parent = box.List
    Library.Bind(previewList, "ScrollBarImageColor3", "Accent")
    local previewText = Instance.new("TextLabel")
    previewText.Size = UDim2.new(1, -8, 0, 0); previewText.AutomaticSize = Enum.AutomaticSize.Y
    previewText.BackgroundTransparency = 1; previewText.TextWrapped = true; previewText.TextTruncate = Enum.TextTruncate.None
    previewText.TextXAlignment = Enum.TextXAlignment.Left; previewText.TextYAlignment = Enum.TextYAlignment.Top
    previewText.TextSize = 12; previewText.FontFace = Library.Fonts.Regular; previewText.Text = ""; previewText.Parent = previewList
    Library.Bind(previewText, "TextColor3", "Text")
    local previewReport, previewPage = nil, 1
    local function drawPreviewPage()
        local lines = {}
        if previewReport then
            local first = (previewPage - 1) * 50 + 1
            local last = math.min(#previewReport.changes, first + 49)
            for i = first, last do
                local change = previewReport.changes[i]
                lines[#lines + 1] = change.key .. ": " .. change.before .. " → " .. change.after
            end
        end
        previewText.Text = table.concat(lines, "\n")
        previewList.Visible = #lines > 0
        previewList.CanvasPosition = Vector2.new(0, 0)
        if previewReport then
            local pages = math.max(1, math.ceil(#previewReport.changes / 50))
            previewSummary:Set(tr("Alterações") .. ": " .. #previewReport.changes .. " · " .. tr("Bloqueadas") .. ": " .. previewReport.skipped .. " · " .. tr("Desconhecidas") .. ": " .. previewReport.unknown .. " · " .. previewPage .. "/" .. pages)
        end
    end
    box:Button({ Name = "Página anterior da prévia", Callback = function() if previewReport and previewPage > 1 then previewPage -= 1; drawPreviewPage() end end })
    box:Button({ Name = "Próxima página da prévia", Callback = function()
        if previewReport and previewPage < math.ceil(#previewReport.changes / 50) then previewPage += 1; drawPreviewPage() end
    end })
    box:Button({ Name = "Revisar configuração", Tooltip = function() return tr("Mostra alterações sem aplicá-las; a prévia expira em 60 segundos.") end, Callback = function()
        local report, err = Window:StageConfigPreview(name.Box.Text)
        previewReport, previewPage = report, 1
        previewList.Visible = false; previewText.Text = ""
        if not report then previewSummary:Set(tr("Prévia indisponível") .. ": " .. tostring(err)); return end
        drawPreviewPage()
    end })
    box:Button({ Name = "Confirmar carregamento", Tooltip = function() return tr("Aplica a prévia se o arquivo, os ajustes e a política não mudaram.") end, Callback = function()
        local n = Library.CleanName(name.Box.Text)
        if n == "" then n = "default" end
        local ok, err = Window:ConfirmConfigPreview(n)
        if not ok then notify(tr("Não foi possível confirmar") .. ": " .. tostring(err)); return end
        previewReport = nil; previewSummary:Set(""); previewList.Visible = false; previewText.Text = ""
        name.Box.Text = n
        if not Window:SetAutoload(n) then notify(tr("Carregado, mas não foi possível selecionar o carregamento inicial.")) end
    end })
    box:Button({ Name = "Recuperar backup", Tooltip = function() return tr("Cria uma cópia do backup e a carrega sem alterar os arquivos antigos.") end, Callback = function()
        local ok, result = Window:RestoreConfigBackup(name.Box.Text)
        if not ok then notify(tr("Não foi possível recuperar o backup.") .. " " .. tostring(result)); return end
        name.Box.Text = result
        if not Window:SetAutoload(result) then notify(tr("Carregado, mas não foi possível selecionar o carregamento inicial.")) end
        refreshConfigs()
    end })
    local versionChoice = box:Dropdown({ Name = "Versão do histórico", Options = {}, NoPersist = true, Callback = function() end })
    box:Button({ Name = "Atualizar histórico", Callback = function() versionChoice:SetOptions(Window:ListConfigVersions(name.Box.Text)) end })
    box:Button({ Name = "Criar versão", Callback = function()
        local ok, result = Window:CreateConfigVersion(name.Box.Text)
        notify(ok and (tr("Versão criada") .. ": " .. result) or (tr("Não foi possível criar versão") .. ": " .. tostring(result)))
        versionChoice:SetOptions(Window:ListConfigVersions(name.Box.Text))
    end })
    box:Button({ Name = "Restaurar versão em cópia", Callback = function()
        local version = versionChoice:Get()
        if type(version) == "table" then version = version[1] end
        local ok, result = Window:RestoreConfigVersion(name.Box.Text, version)
        if ok then name.Box.Text = result; refreshConfigs(); notify(tr("Cópia criada; revise antes de carregar") .. ": " .. result)
        else notify(tr("Não foi possível recuperar a versão") .. ": " .. tostring(result)) end
    end })
    refreshConfigs()
end

-- Segurança: modo pânico
do
    local P = cfg:Groupbox({ Name = "SEGURANÇA", Icon = "shield", Side = "Left" })
    Library._panicToggle = P:Toggle({ Name = "Modo pânico", Default = false, NoPersist = true,
        Tooltip = tipText("Esconde menu, ESP, radar e botões fixos de uma vez. Para voltar, toque 3 vezes no topo da tela (ou use a tecla de pânico)."),
        Callback = function(v) Window:SetPanic(v) end })
    P:Keybind({ Name = "Tecla de pânico", Default = "End", Callback = function() Window:SetPanic(not Library.Panic) end })
end

-- Geral
g = cfg:Groupbox({ Name = "GERAL", Icon = "settings", Side = "Left" })
g:Dropdown({ Name = "Idioma", Options = { "English", "Español", "Português (Brasil)", "简体中文", "Русский" }, Default = LANG_NAMES[currentLang],
    Flags = { ["English"] = "en", ["Español"] = "es", ["Português (Brasil)"] = "pt", ["简体中文"] = "zh", ["Русский"] = "ru" },
    Callback = function(v)
        local code = LANG_CODES[type(v) == "table" and v[1] or v] or "pt"
        setLanguage(code)
        notify(tr("Idioma alterado") .. ": " .. LANG_NAMES[code])
    end })
g:Slider({ Name = "Escala do menu", Min = 70, Max = 130, Default = 100, Step = 5, Suffix = "%",
    Tooltip = function() return tr("Ajusta o tamanho do menu, limitado ao espaço disponível na tela.") end,
    Callback = function(v) Window:SetScaleFactor(v / 100) end })
g:Slider({ Name = "Atualizações do ESP", Min = 10, Max = 60, Default = 30, Step = 5, Suffix = " fps",
    Tooltip = function() return tr("Controla a frequência da busca de alvos, radar e saque; a projeção do ESP acompanha cada quadro.") end,
    Callback = function(v) Library.RenderRate = math.clamp(v, 10, 60) end })
g:Keybind({ Name = "Tecla do menu", Default = "RightShift", OnChanged = function(k) Window:SetKeybind(k); keys.menu = k.Name; refreshPanels() end, Callback = function() end })
g:Keybind({ Name = "Tecla do cursor", Default = "LeftAlt", OnChanged = function(k) cursorKey = k; keys.cursor = k.Name; refreshPanels() end, Callback = function() end })
g:Toggle({ Name = "Cursor livre", Default = true, Callback = function(v) cursorFree = v end })
g:Toggle({ Name = "Lista de atalhos", Default = false, Callback = function(v) bind(KL, "On", v) end })
g:Toggle({ Name = "Ilha de FPS", Default = true, Callback = function(v) Window:SetIsland(v) end })
T(g, "Ocultar indisponíveis")
g:Toggle({ Name = "Fixar botão móvel", Default = false, Callback = function(v) pcall(function() Window:SetIslandDraggable(not v) end) end })
g:Button({ Name = "Rever tutorial", Callback = function() notify(tr(IS_MOBILE and "Toque no botão flutuante para abrir o menu." or "Pressione a tecla do menu para abrir ou fechar.")) end })
g:Button({ Name = "Sair", Callback = function()
    if Library._stopEngine then Library._stopEngine() end   -- desliga ESP/radar e suas GUIs
    Window:Destroy()
end })

-- Diagnóstico informa capacidades locais; não testa serviços nem detecta anticheat.
do
    local panel = cfg:Groupbox({ Name = "DIAGNÓSTICO", Icon = "settings", Side = "Right" })
    local files = panel:Label({ Text = "" })
    local controls = panel:Label({ Text = "" })
    local integration = panel:Label({ Text = "" })
    local reload = panel:Label({ Text = "" })
    local prompt = panel:Label({ Text = "" })
    local engineTiming = panel:Label({ Text = "" })
    local startupState = panel:Label({ Text = "" })
    local storageState = panel:Label({ Text = "" })
    local last = panel:Label({ Text = "" })
    local previous = panel:Label({ Text = "" })
    local older = panel:Label({ Text = "" })
    local pending1 = panel:Label({ Text = "" })
    local pending2 = panel:Label({ Text = "" })
    local pending3 = panel:Label({ Text = "" })
    local pending4 = panel:Label({ Text = "" })
    local pendingGear1 = panel:Label({ Text = "" })
    local pendingGear2 = panel:Label({ Text = "" })
    local function refreshDiagnostics()
        local fs = type(readfile) == "function" and type(writefile) == "function" and type(isfile) == "function"
        files:Set(tr("Arquivos") .. ": " .. tr(fs and "APIs presentes" or "APIs ausentes"))
        controls:Set(tr("Entrada") .. ": " .. (LangUIS.TouchEnabled and "touch " or "") .. (LangUIS.KeyboardEnabled and "teclado " or "") .. (LangUIS.MouseEnabled and "mouse" or ""))
        integration:Set(tr("Saque configurado") .. ": " .. tr(Actions.getLootConfig() and "Sim" or "Não"))
        reload:Set(tr("Recarga configurada") .. ": " .. tr(Actions.getReloadPath() and "Sim" or "Não"))
        prompt:Set(tr("API de prompt") .. ": " .. tr(type(fireproximityprompt) == "function" and "APIs presentes" or "APIs ausentes"))
        startupState:Set(tr("Montagem") .. ": " .. tr(Window._prebuildFailed and "Falhou" or (Window._loaded and "Concluída" or "Pendente")))
        storageState:Set(tr("Salvamento automático") .. ": " .. tr(Window._autoSaveBlocked and "Suspenso" or (Window._ready and "Disponível" or "Pendente")))
        local timing = Library.Diagnostics.engine
        engineTiming:Set(tr("Tempo médio do motor visual") .. ": " .. (timing and string.format("%.2f ms", timing.average) or "—"))
        local recent = Library.Diagnostics.recent
        last:Set(tr("Última falha registrada") .. ": " .. (recent[#recent] or tr("Nenhuma")))
        previous:Set(recent[#recent - 1] or "—")
        older:Set(recent[#recent - 2] or "—")
        pending1:Set(tr("Mochila personalizada") .. ": " .. tr("Não implementado"))
        pending2:Set(tr("Mapa e navegação") .. ": " .. tr("Depende do jogo"))
        pending3:Set(tr("Trocar personagem") .. ": " .. tr("Depende do jogo"))
        pending4:Set(tr("Mira falsa") .. " / " .. tr("Alternativa visível") .. ": " .. tr("Não implementado"))
        pendingGear1:Set(tr("Ajustes pendentes") .. ": " .. tr("Mochila personalizada") .. " / " .. tr("Mochila"))
        pendingGear2:Set(tr("Ajustes pendentes") .. ": " .. tr("Mira falsa") .. " / " .. tr("Trocar personagem"))
    end
    panel:Button({ Name = "Atualizar diagnóstico", Tooltip = function() return tr("Atualiza as capacidades locais e a última falha registrada.") end, Callback = refreshDiagnostics })
    panel:Button({ Name = "Copiar erros recentes", Callback = function()
        local recent = Library.Diagnostics.recent
        if #recent == 0 then notify(tr("Nenhuma falha registrada")); return end
        local copier = type(setclipboard) == "function" and setclipboard or (type(toclipboard) == "function" and toclipboard or nil)
        local ok, result = false, nil
        if copier then ok, result = pcall(copier, table.concat(recent, "\n")) end
        notify(tr(ok and result ~= false and "Erros copiados." or "Cópia indisponível ou falhou."))
    end })
    panel:Label({ Text = "APIs presentes não garantem funcionamento." })
    table.insert(onLanguageChanged, refreshDiagnostics)
    refreshDiagnostics()
end

-- Aparência
local presetNames = Library.ThemeOrder
g = cfg:Groupbox({ Name = "APARÊNCIA", Icon = "palette", Side = "Left" })
do
    -- círculos de cor: tocar aplica o tema na hora
    local swatches = Instance.new("Frame")
    swatches.BackgroundTransparency = 1; swatches.Size = UDim2.new(1, 0, 0, 0); swatches.AutomaticSize = Enum.AutomaticSize.Y
    swatches.LayoutOrder = g:_nextOrder()
    local sp = Instance.new("UIPadding", swatches); sp.PaddingTop = UDim.new(0, 8); sp.PaddingBottom = UDim.new(0, 8); sp.PaddingLeft = UDim.new(0, 12); sp.PaddingRight = UDim.new(0, 8)
    local grid = Instance.new("UIGridLayout", swatches)
    grid.CellSize = UDim2.fromOffset(24, 24); grid.CellPadding = UDim2.fromOffset(5, 6); grid.SortOrder = Enum.SortOrder.LayoutOrder
    swatches.Parent = g.List
    local rings = {}
    local function accentOf(name)
        local p = Library.ThemePresets[name]
        local c = p and p.Accent
        if typeof(c) == "Color3" then return c end
        if type(c) == "string" then local ok, r = pcall(Color3.fromHex, c); if ok then return r end end
        if type(c) == "table" and #c == 3 then return Color3.fromRGB(c[1], c[2], c[3]) end
        return Color3.fromRGB(200, 200, 200)
    end
    local function repaintSwatches()
        for n, r in pairs(rings) do
            local selected = Library.ThemeName == n
            r.ring.Transparency = selected and 0 or 1; r.tick.Visible = selected
            if r.pumpkin then r.pumpkin.Visible = not selected end
        end
    end
    table.insert(Library._themeListeners, repaintSwatches)
    for i, name in ipairs(presetNames) do
        local acc = accentOf(name)
        local b = Instance.new("TextButton")
        b.Text = ""; b.AutoButtonColor = false; b.BackgroundColor3 = Color3.new(1, 1, 1); b.LayoutOrder = i; b.BorderSizePixel = 0
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        local gr = Instance.new("UIGradient", b)
        gr.Rotation = 55
        gr.Color = ColorSequence.new(acc:Lerp(Color3.new(1, 1, 1), 0.35), acc:Lerp(Color3.new(0, 0, 0), 0.3))
        local ring = Instance.new("UIStroke", b); ring.Thickness = 2.5; ring.Color = Color3.new(1, 1, 1)
        ring.Transparency = (Library.ThemeName == name) and 0 or 1
        local tick = Instance.new("TextLabel", b)
        tick.BackgroundTransparency = 1; tick.Size = UDim2.fromScale(1, 1); tick.Text = "✓"; tick.TextSize = 13; tick.TextColor3 = Color3.new(1, 1, 1)
        tick.FontFace = Library.Fonts.Bold; tick.Visible = (Library.ThemeName == name)
        local pumpkin
        if name == "Halloween" then
            pumpkin = Instance.new("TextLabel", b)
            pumpkin.BackgroundTransparency = 1; pumpkin.Size = UDim2.fromScale(1, 1); pumpkin.Text = "🎃"; pumpkin.TextSize = 14
            pumpkin.Visible = not (Library.ThemeName == name)
        end
        rings[name] = { ring = ring, tick = tick, pumpkin = pumpkin }
        Actions.connect(b.MouseButton1Click, function()
            Library:SetTheme(name)
            for n, r in pairs(rings) do r.ring.Transparency = (n == name) and 0 or 1; r.tick.Visible = (n == name); if r.pumpkin then r.pumpkin.Visible = (n ~= name) end end
            wmStroke.Color = Library.Theme.Accent; recolorKL()
            notify(name)
        end)
        b.Parent = swatches
    end
end
do
    local A = Library.Appearance
    local candidate = Color3.new(A.color[1], A.color[2], A.color[3])
    -- Amostra ilustrativa, sem acionar botões reais nem mudar o tema.
    local sample = Instance.new("Frame")
    sample.Size = UDim2.new(1, -16, 0, 76); sample.BorderSizePixel = 0; sample.LayoutOrder = g:_nextOrder(); sample.Parent = g.List
    Library.Bind(sample, "BackgroundColor3", "Background")
    Instance.new("UICorner", sample).CornerRadius = UDim.new(0, 6)
    local sampleLabel = Instance.new("TextLabel")
    sampleLabel.BackgroundTransparency = 1; sampleLabel.Size = UDim2.new(1, -16, 0, 20); sampleLabel.Position = UDim2.fromOffset(8, 6)
    sampleLabel.Text = tr("Prévia do tema"); sampleLabel.TextXAlignment = Enum.TextXAlignment.Left; sampleLabel.TextSize = 13; sampleLabel.FontFace = Library.Fonts.Bold; sampleLabel.Parent = sample
    Library.Bind(sampleLabel, "TextColor3", "Text")
    local sampleControl = Instance.new("Frame")
    sampleControl.Size = UDim2.new(1, -16, 0, 32); sampleControl.Position = UDim2.fromOffset(8, 34); sampleControl.BorderSizePixel = 0; sampleControl.Parent = sample
    Library.Bind(sampleControl, "BackgroundColor3", "Surface2")
    Instance.new("UICorner", sampleControl).CornerRadius = UDim.new(0, 4)
    local sampleName = Instance.new("TextLabel")
    sampleName.BackgroundTransparency = 1; sampleName.Text = tr("Exemplo"); sampleName.TextSize = 12; sampleName.FontFace = Library.Fonts.Regular
    sampleName.TextXAlignment = Enum.TextXAlignment.Left; sampleName.Position = UDim2.fromOffset(8, 0); sampleName.Size = UDim2.new(1, -50, 1, 0); sampleName.Parent = sampleControl
    Library.Bind(sampleName, "TextColor3", "Text")
    local sampleChip = Instance.new("Frame")
    sampleChip.AnchorPoint = Vector2.new(1, 0.5); sampleChip.Position = UDim2.new(1, -8, 0.5, 0); sampleChip.Size = UDim2.fromOffset(30, 16)
    sampleChip.BorderSizePixel = 0; sampleChip.BackgroundColor3 = candidate; sampleChip.Parent = sampleControl
    Instance.new("UICorner", sampleChip).CornerRadius = UDim.new(1, 0)
    table.insert(onLanguageChanged, function() sampleLabel.Text = tr("Prévia do tema"); sampleName.Text = tr("Exemplo") end)
    local contrastLine = g:Label({ Text = "" })
    local contrastWarning = g:Label({ Text = "" })
    local function updateContrast()
        sampleChip.BackgroundColor3 = candidate
        local surface = Library.UISupport.contrast(candidate, Library.Theme.Surface) or 1
        local white = Library.UISupport.contrast(candidate, Color3.new(1, 1, 1)) or 1
        contrastLine:Set(string.format("%s %.1f:1 · %s %.1f:1", tr("Cor/fundo"), surface, tr("Branco/cor"), white))
        contrastWarning:Set(tr((surface < 4.5 or white < 4.5) and "Contraste baixo em uma combinação." or "Contraste adequado nestas combinações."))
    end
    local picker = g:ColorPicker({ Name = "Prévia da cor", Default = candidate, NoPersist = true, Tooltip = function() return tr("Escolha uma cor na amostra; aplique depois para mudar o menu.") end, Callback = function(c) candidate = c; updateContrast() end })
    table.insert(A.colorListeners, function(c)
        candidate = Color3.new(c[1], c[2], c[3])
        picker:Set(candidate, true); updateContrast()
    end)
    table.insert(Library._themeListeners, updateContrast)
    table.insert(onLanguageChanged, updateContrast)
    updateContrast()
    g:Button({ Name = "Aplicar cor personalizada", Callback = function()
        A:setColor({candidate.R, candidate.G, candidate.B})
        Library:SetTheme("Custom")
        notify(tr("Cor personalizada"))
    end })
    g:Toggle({ Name = "Alto contraste", Default = A.contrast, Tooltip = function() return tr("Aumenta o contraste da superfície e do texto; cores escolhidas podem variar.") end, Callback = function(v) A:setFlag("contrast", v) end })
    g:Toggle({ Name = "Reduzir movimento", Default = A.motion, Tooltip = function() return tr("Reduz transições e animações visuais do menu e da prévia.") end, Callback = function(v) A:setFlag("motion", v) end })
    g:Toggle({ Name = "Pular intro na próxima vez", Default = A.skipIntro, Tooltip = function() return tr("Abre o menu sem o cartão de carregamento na próxima inicialização.") end, Callback = function(v) A:setFlag("skipIntro", v) end })
end
g:Toggle({ Name = "Cubo", Default = true, Callback = function(v) Window:SetLogo(v) end })
g:Toggle({ Name = "Rastro ao ativar", Default = true, Tooltip = tipText("Mostra um rastro de luz na cor do menu quando você ativa uma opção."), Callback = function(v) Library.Effects = v end })
g:Toggle({ Name = "Animação do menu", Default = true, Tooltip = tipText("Abre e fecha o menu com um efeito suave."), Callback = function(v) Library.MenuAnim = v end })
g:Dropdown({ Name = "Fonte", Options = { "Arimo", "Arcade", "Code", "Press Start 2P", "Silkscreen" }, Default = "Arimo", Callback = function(v) setFont(type(v) == "table" and v[1] or v) end })
g:Toggle({ Name = "Bordas estáticas", Default = false, Callback = function(v) Window:SetBorderAccent(v) end })
local bgOn, bgVal = false, 25
g:Toggle({ Name = "Fundo", Default = false, Callback = function(v) bgOn = v; Window:SetBackgroundTransparency(v and bgVal / 100 or 0) end,
    Settings = function(p) p:Slider({ Name = "Transparência", Min = 0, Max = 80, Default = 25, Suffix = "%", Callback = function(x) bgVal = x; if bgOn then Window:SetBackgroundTransparency(x / 100) end end }) end })
g:Toggle({ Name = "Sombra", Default = false, Callback = function(v) Window:SetShadow(v) end })

-- Marca d'água
g = cfg:Groupbox({ Name = "MARCA D'ÁGUA", Icon = "scan", Side = "Right", Checkbox = true, Default = false, Callback = function(v) bind(WM, "On", v) end })
g:Toggle({ Name = "Fixar", Default = false, Callback = function(v) WM.Pin = v end })
g:Dropdown({ Name = "Campos visíveis", Options = { "Nome", "FPS", "Ping", "Hora" }, Default = { "Nome", "FPS", "Ping" }, Multi = true,
    Callback = function(v) WM.Fields = v; end })
SB(g, "Tamanho", 50, 200, 100, "%", 1, WM, "Size")
SB(g, "Largura", 150, 600, 285, "", 1, WM, "Width")
SB(g, "Altura máxima", 20, 500, 290, "", 1, WM, "MaxH")
SB(g, "Transp. fundo", 0, 1, 0.10, "", 0.01, WM, "BgT")
SB(g, "Transp. do texto", 0, 1, 0, "", 0.01, WM, "TxtT")
SB(g, "Transp. da borda", 0, 1, 0, "", 0.01, WM, "BrdT")
SB(g, "Raio dos cantos", 0, 20, 6, " px", 1, WM, "Radius")
g:Toggle({ Name = "Sombra", Default = true, Callback = function(v) bind(WM, "Shadow", v) end })

-- Lista de atalhos
g = cfg:Groupbox({ Name = "LISTA DE ATALHOS", Icon = "keyboard", Side = "Right" })
klPinToggle = g:Toggle({ Name = "Fixar", Default = false, Callback = function(v) KL.Pin = v; paintPin() end })
g:Toggle({ Name = "Sombra", Default = true, Callback = function(v) bind(KL, "Shadow", v) end })
SB(g, "Tamanho", 50, 200, 100, "%", 1, KL, "Size")
SB(g, "Largura", 200, 420, 250, "", 1, KL, "Width")
SB(g, "Altura máxima", 100, 500, 260, "", 1, KL, "MaxH")
SB(g, "Transp. fundo", 0, 1, 0.05, "", 0.01, KL, "BgT")
SB(g, "Transp. do texto", 0, 1, 0, "", 0.01, KL, "TxtT")
SB(g, "Transp. da borda", 0, 1, 0.75, "", 0.01, KL, "BrdT")
SB(g, "Raio dos cantos", 0, 20, 7, " px", 1, KL, "Radius")

refreshPanels()
-- ============ 60_engine.luau :: Motor do ESP, radar, loot, zona do pânico e encerramento ============
-- ============================================================
--  Motor: ESP no jogo (usa as opções dos painéis), radar, buscar saque
--  e a zona de retorno do modo pânico.
-- ============================================================
do
    local Workspace = game:GetService("Workspace")
    local UserInputService = game:GetService("UserInputService")
    local LP = Players.LocalPlayer
    local espGui = Instance.new("ScreenGui")
    Library:ProtectGui(espGui)
    espGui.Name = "BBCESP"; espGui.ResetOnSpawn = false; espGui.IgnoreGuiInset = true; espGui.DisplayOrder = 990
    Library:ParentGui(espGui)
    local holder = Instance.new("Folder")
    holder.Name = "BBCMarks"; Library:ParentGui(holder)
    table.insert(Library._panicGuis, overlay)
    table.insert(Library._panicGuis, espGui)

    local function mk(class, props, parent)
        local i = Instance.new(class)
        for k, v in pairs(props) do i[k] = v end
        if class == "ScreenGui" or class == "BillboardGui" then Library:ProtectGui(i) end
        if class == "ScreenGui" then Library:ParentGui(i) else i.Parent = parent end
        return i
    end
    local FONT = Library.Fonts.Bold
    -- o "Sair" usa isso para desligar o motor (laços, conexões e GUIs do ESP/radar)
    local engineConns, engineGuis = {}, { espGui, holder, overlay }
    local engineClosed = false
    local function conn(sig, fn)
        local c = Library.Guards.connect(sig, fn, function() return not engineClosed end,
            function(stage, err)
                warn("[BBC] Motor " .. stage .. ": " .. err)
                if Library.Diagnostics then Library.Diagnostics:record("motor " .. stage, err) end
                if stage == "interrompido" then
                    pcall(function() Library:Notify({ Title = "SEGURANÇA", Content = "Evento do motor interrompido; veja o console.", Duration = 5 }) end)
                end
            end)
        engineConns[#engineConns + 1] = c
        return c
    end

    -- ---------- zona de retorno do modo pânico: 3 toques no topo da tela ----------
    do
        local zoneGui = mk("ScreenGui", { Name = "BBCZone", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1001 }, overlayParent)
        engineGuis[#engineGuis + 1] = zoneGui
        local zone = mk("TextButton", { BackgroundTransparency = 1, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.fromOffset(Actions.getAdjustment("panicZoneWidth"), 56), Visible = false }, zoneGui)
        local taps = {}
        conn(zone.MouseButton1Click, function()
            local now = os.clock()
            table.insert(taps, now)
            for i = #taps, 1, -1 do if now - taps[i] > Actions.getAdjustment("panicTapWindow") then table.remove(taps, i) end end
            if #taps >= 3 then taps = {}; Window:SetPanic(false) end
        end)
        Library._panicZone = zone
    end

    -- ---------- NPCs (modelos com Humanoid que não são jogadores) ----------
    local npcs, npcScan = {}, false
    local function addHum(h)
        if not engineClosed and h:IsA("Humanoid") and h:IsDescendantOf(Workspace) then
            local m = h.Parent
            if m and m:IsA("Model") and not Players:GetPlayerFromCharacter(m) then npcs[m] = h end
        end
    end
    local function startNpcScan()
        if npcScan then return end
        npcScan = true
        conn(Workspace.DescendantAdded, function(d) if d:IsA("Humanoid") then task.defer(addHum, d) end end)
        conn(Workspace.DescendantRemoving, function(d)
            npcs[d] = nil
            if d:IsA("Humanoid") and d.Parent then npcs[d.Parent] = nil end
        end)
        Library.StreamScan.start(Workspace, function() return not engineClosed end, addHum)
    end

    -- ---------- Itens / recipientes (varredura com cache) ----------
    local CONT_KW = { "chest", "bau", "baú", "box", "crate", "container", "depot", "stash", "safe", "locker", "fridge", "register", "dumpster", "sack", "mochila" }
    local MISSION_KW = { "quest", "mission", "missão", "misso", "key", "chave", "document", "documento", "briefcase", "notebook", "laptop", "drive", "pendrive", "usb", "note", "nota", "maca" }
    local ITEM_KW = { "item", "loot", "ammo", "muni", "weapon", "arma", "tool", "ferramenta", "medkit", "kit", "potion", "poção", "pocao",
        "coin", "moeda", "gem", "diamond", "drop", "pickup", "supply", "suprimento", "cell", "celula" }
    local itemCands = { Recipiente = {}, ["Item no chão"] = {}, ["Itens de missão"] = {} }
    local itemScan = false
    local itemCounts = { Recipiente = 0, ["Item no chão"] = 0, ["Itens de missão"] = 0 }
    local function addItemCandidate(kind, inst)
        local set = itemCands[kind]
        if not set[inst] and itemCounts[kind] < 2048 then set[inst] = true; itemCounts[kind] += 1 end
    end
    local function removeItemCandidate(kind, inst)
        local set = itemCands[kind]
        if set[inst] then set[inst] = nil; itemCounts[kind] -= 1 end
    end
    local function hasChild(inst, class)
        return inst:FindFirstChildOfClass(class) ~= nil
    end
    local function classifyItem(inst)
        if engineClosed or not inst:IsDescendantOf(Workspace) then return end
        if not (inst:IsA("BasePart") or inst:IsA("Model")) then return end
        if LP.Character and inst:IsDescendantOf(LP.Character) then return end
        if Players:GetPlayerFromCharacter(inst) then return end
        local par = inst.Parent
        if par and par:IsA("Model") and par:FindFirstChildOfClass("Humanoid") then return end
        local low = string.lower(inst.Name)
        if low == "" then return end
        local cont, miss = false, false
        for _, k in ipairs(CONT_KW) do if string.find(low, k, 1, true) then cont = true; break end end
        for _, k in ipairs(MISSION_KW) do if string.find(low, k, 1, true) then miss = true; break end end
        if cont then addItemCandidate("Recipiente", inst) end
        if miss then addItemCandidate("Itens de missão", inst) end
        if cont or miss then return end
        local item = false
        for _, k in ipairs(ITEM_KW) do if string.find(low, k, 1, true) then item = true; break end end
        if not item and (hasChild(inst, "ProximityPrompt") or hasChild(inst, "ClickDetector")) then item = true end
        local attr = inst:GetAttribute("Rarity") or inst:GetAttribute("Tier") or inst:GetAttribute("Value")
        if attr ~= nil then item = true end
        if item then addItemCandidate("Item no chão", inst) end
    end
    local function startItemScan()
        if itemScan then return end
        itemScan = true
        conn(Workspace.DescendantAdded, classifyItem)
        conn(Workspace.DescendantRemoving, function(inst)
            for kind in pairs(itemCands) do removeItemCandidate(kind, inst) end
        end)
        Library.StreamScan.start(Workspace, function() return not engineClosed end, classifyItem)
    end

    -- ---------- ESP ----------
    local R15 = { { "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" }, { "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
        { "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" }, { "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" },
        { "LeftLowerLeg", "LeftFoot" }, { "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" } }
    local R6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }
    local KEYS = { "highlight", "box", "name", "healthbar", "health", "distance", "tracers", "arrows", "skeleton" }
    local function anyOn(S)
        if not S then return false end
        for _, k in ipairs(KEYS) do if S[k] and S[k].on then return true end end
        return false
    end
    local function hpColor(S, ratio)
        if not S.healthbar.auto then return S.healthbar.color end
        if ratio > 0.6 then return Color3.fromRGB(70, 220, 90) elseif ratio > 0.3 then return Color3.fromRGB(240, 200, 60) end
        return Color3.fromRGB(240, 80, 70)
    end
    local function txt(parent, anchor)
        return mk("TextLabel", { BackgroundTransparency = 1, FontFace = FONT, TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), AnchorPoint = anchor,
            Size = UDim2.fromOffset(120, 14), Visible = false, TextColor3 = Color3.new(1, 1, 1) }, parent)
    end
    local function lineF(f, x0, y0, x1, y1, th, col)
        local dx, dy = x1 - x0, y1 - y0
        f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), th)
        f.Position = UDim2.fromOffset((x0 + x1) / 2, (y0 + y1) / 2)
        f.Rotation = math.deg(math.atan2(dy, dx))
        f.BackgroundColor3 = col
        f.Visible = true
    end
    local pool = { Jogador = {}, NPCs = {}, Corpo = {}, Recipiente = {}, ["Item no chão"] = {}, ["Itens de missão"] = {} }
    local function newDraw()
        local d = { skel = {}, skelOn = false }
        local r = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, espGui)
        d.root = r
        d.boxFull = mk("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false }, r)
        d.boxStroke = mk("UIStroke", { Thickness = 2 }, d.boxFull)
        d.corners = {}
        for i = 1, 8 do d.corners[i] = mk("Frame", { BorderSizePixel = 0, Visible = false }, r) end
        d.hbBg = mk("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false }, r)
        d.hbFill = mk("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, d.hbBg)
        d.name = txt(r, Vector2.new(0.5, 1)); d.hp = txt(r, Vector2.new(1, 0)); d.dist = txt(r, Vector2.new(0.5, 0))
        d.tracer = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, r)
        d.arrow = Library.MakeIcon(r, "navigation-2", 18, "Text", { AnchorPoint = Vector2.new(0.5, 0.5), Visible = false })
        d.dot = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0, Visible = false }, r)
        mk("UICorner", { CornerRadius = UDim.new(1, 0) }, d.dot)
        d.hl = mk("Highlight", { DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false }, holder)
        return d
    end
    local function hideDraw(d)
        d.root.Visible = false
        d.hl.Enabled = false
    end
    -- Alturas estáveis em relação à raiz, sem depender de poses/acessórios.
    local function characterOffsets(t)
        local function partHeight(name)
            local part = t.model:FindFirstChild(name)
            return part and part:IsA("BasePart") and part.Size.Y or nil
        end
        local rootHalf = t.hrp.Size.Y / 2
        local above, below
        local torso = partHeight("Torso")
        if torso then
            above = torso / 2 + (partHeight("Head") or 1)
            below = rootHalf + (partHeight("Left Leg") or partHeight("Right Leg") or 2)
        else
            local upper, lower = partHeight("UpperTorso"), partHeight("LowerTorso")
            above = (lower or t.hrp.Size.Y) / 2 + (upper or 1) + (partHeight("Head") or 1)
            below = rootHalf + math.max(0, t.hum.HipHeight)
        end
        return math.max(above, 1.5), math.max(below, 1.5)
    end
    local function projectBounds(c, center, above, below)
        -- Os extremos ficam no plano da tela e à mesma profundidade da raiz.
        local up = c.CFrame.UpVector
        return c:WorldToViewportPoint(center + up * above), c:WorldToViewportPoint(center - up * below)
    end
    local function drawTarget(d, t, S, c, vp, isNearest)
        local near = isNearest and S.nearest.on
        local ncol = S.nearest.color
        local center, above, below
        if t.hum and t.hum.Health > 0 then
            center = t.hrp.Position
            above, below = characterOffsets(t)
        else
            local sz = t.model:IsA("Model") and t.model:GetExtentsSize() or t.model.Size
            center, above, below = t.model:GetPivot().Position, sz.Y / 2, sz.Y / 2
        end
        local topV, botV = projectBounds(c, center, above, below)
        d.root.Visible = true
        -- esconde tudo; só reaparece o que estiver ligado
        d.boxFull.Visible = false
        for i = 1, 8 do d.corners[i].Visible = false end
        d.hbBg.Visible = false; d.name.Visible = false; d.hp.Visible = false; d.dist.Visible = false
        d.tracer.Visible = false; d.dot.Visible = false; d.arrow.Visible = false
        if d.skelOn then for _, f in ipairs(d.skel) do f.Visible = false end; d.skelOn = false end
        local onScreen = topV.Z > 0 and botV.Z > 0 and topV.X > -60 and topV.X < vp.X + 60 and topV.Y > -120 and botV.Y < vp.Y + 120
        if not onScreen then
            d.hl.Enabled = false
            if S.arrows and S.arrows.on then
                local projected = c:WorldToViewportPoint(center)
                local x, y = projected.X - vp.X / 2, projected.Y - vp.Y / 2
                if projected.Z < 0 then x, y = -x, -y end
                local length = math.sqrt(x * x + y * y)
                if length < 0.001 then x, y, length = 0, -1, 1 end
                x, y = x / length, y / length
                local margin = S.arrows.size + 8
                local rx, ry = math.max(1, vp.X / 2 - margin), math.max(1, vp.Y / 2 - margin)
                local scale = math.min(rx / math.max(math.abs(x), 0.0001), ry / math.max(math.abs(y), 0.0001))
                d.arrow.Position = UDim2.fromOffset(vp.X / 2 + x * scale, vp.Y / 2 + y * scale)
                d.arrow.Rotation = math.deg(math.atan2(y, x)) + 90
                d.arrow.Size = UDim2.fromOffset(S.arrows.size, S.arrows.size)
                d.arrow.ImageColor3 = near and ncol or S.arrows.color
                d.arrow.Visible = true
            end
            return
        end
        local top, bottom = topV.Y, botV.Y
        local hgt = math.max(bottom - top, 8)
        local wid = hgt * 0.55
        local cx = topV.X
        local left = cx - wid / 2
        local ts = S.textSize
        local far = S.lod.on and t.m > S.lod.near
        local boxCol = near and ncol or S.box.color
        local hl = S.highlight
        if d.hl.Adornee ~= t.model then d.hl.Adornee = t.model end
        d.hl.Enabled = hl.on
        d.hl.FillColor = near and ncol or hl.color
        d.hl.FillTransparency = 1 - hl.alpha
        d.hl.OutlineColor = hl.outlineColor or (near and ncol or hl.color):Lerp(Color3.new(1, 1, 1), 0.35)
        d.hl.OutlineTransparency = hl.outline <= 0 and 1 or 0
        local distText = (S.distance.unit == "studs") and (math.floor(t.studs) .. " st") or (math.floor(t.m) .. "m")
        if far then
            -- longe: só um ponto + distância
            if S.box.on or hl.on then
                d.dot.Visible = true; d.dot.BackgroundColor3 = boxCol; d.dot.Position = UDim2.fromOffset(cx, (top + bottom) / 2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = ts; d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, (top + bottom) / 2 + 6)
            end
        else
            if S.box.on then
                local th = S.box.thick
                if S.box.style == "Completa" then
                    d.boxFull.Visible = true
                    d.boxFull.Position = UDim2.fromOffset(left, top); d.boxFull.Size = UDim2.fromOffset(wid, hgt)
                    d.boxStroke.Color = boxCol; d.boxStroke.Thickness = th
                else
                    local len = math.min(S.box.corner, wid / 2, hgt / 2)
                    local L = { { left, top, len, th }, { left, top, th, len }, { left + wid - len, top, len, th }, { left + wid - th, top, th, len },
                        { left, top + hgt - th, len, th }, { left, top + hgt - len, th, len }, { left + wid - len, top + hgt - th, len, th }, { left + wid - th, top + hgt - len, th, len } }
                    for i = 1, 8 do
                        local f, v = d.corners[i], L[i]
                        f.Visible = true; f.BackgroundColor3 = boxCol
                        f.Position = UDim2.fromOffset(v[1], v[2]); f.Size = UDim2.fromOffset(v[3], v[4])
                    end
                end
            end
            local ratio = t.hum and math.clamp(t.hum.Health / math.max(t.hum.MaxHealth, 1), 0, 1) or 1
            if S.healthbar.on and t.hum then
                local bw = S.healthbar.width
                local bx = S.healthbar.side == "Direita" and (left + wid + 3) or (left - 3 - bw)
                d.hbBg.Visible = true; d.hbBg.Position = UDim2.fromOffset(bx, top); d.hbBg.Size = UDim2.fromOffset(bw, hgt)
                d.hbFill.Size = UDim2.fromScale(1, ratio); d.hbFill.BackgroundColor3 = hpColor(S, ratio)
            end
            if S.health.on and t.hum then
                d.hp.Visible = true; d.hp.Text = tostring(math.floor(t.hum.Health)); d.hp.TextSize = ts
                d.hp.TextColor3 = S.healthbar.auto and hpColor(S, ratio) or S.health.color
                if S.healthbar.side == "Direita" then
                    d.hp.AnchorPoint = Vector2.new(0, 0.5); d.hp.TextXAlignment = Enum.TextXAlignment.Left
                    d.hp.Position = UDim2.fromOffset(left + wid + 7 + (S.healthbar.on and S.healthbar.width or 0), top + hgt / 2)
                else
                    d.hp.AnchorPoint = Vector2.new(1, 0.5); d.hp.TextXAlignment = Enum.TextXAlignment.Right
                    d.hp.Position = UDim2.fromOffset(left - 7 - (S.healthbar.on and S.healthbar.width or 0), top + hgt / 2)
                end
            end
            if S.name.on then
                d.name.Visible = true; d.name.Text = t.name; d.name.TextSize = ts; d.name.TextColor3 = S.name.color
                d.name.Position = UDim2.fromOffset(cx, top - 2)
            end
            if S.distance.on then
                d.dist.Visible = true; d.dist.Text = distText; d.dist.TextSize = ts; d.dist.TextColor3 = S.distance.color
                d.dist.Position = UDim2.fromOffset(cx, bottom + 2)
            end
            if S.skeleton.on then
                local list = t.model:FindFirstChild("UpperTorso") and R15 or R6
                d.skelOn = true
                for i, pr in ipairs(list) do
                    local f = d.skel[i]
                    if not f then f = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0 }, d.root); d.skel[i] = f end
                    local a, b = t.model:FindFirstChild(pr[1]), t.model:FindFirstChild(pr[2])
                    if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                        local va, vb = c:WorldToViewportPoint(a.Position), c:WorldToViewportPoint(b.Position)
                        if va.Z > 0 and vb.Z > 0 then lineF(f, va.X, va.Y, vb.X, vb.Y, S.skeleton.thick, near and ncol or S.skeleton.color) else f.Visible = false end
                    else
                        f.Visible = false
                    end
                end
                for i = #list + 1, #d.skel do d.skel[i].Visible = false end
            end
        end
        if S.tracers.on then
            local fromBottom = S.tracers.origin == "Baixo"
            lineF(d.tracer, vp.X / 2, fromBottom and vp.Y or 0, cx, fromBottom and bottom or top, S.tracers.thick, near and ncol or S.tracers.color)
        end
    end
    local function gather(kind, out)
        if kind == "Jogador" then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ch = pl.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health > 0 then
                        out[#out + 1] = { model = ch, hum = hum, hrp = hrp, name = (pl.DisplayName ~= "" and pl.DisplayName) or pl.Name }
                    end
                end
            end
        elseif kind == "Corpo" then
            for _, pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then
                    local ch = pl.Character
                    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                    local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
                    if hum and hrp and hum.Health <= 0 then
                        out[#out + 1] = { model = ch, hum = hum, hrp = hrp, name = (pl.DisplayName ~= "" and pl.DisplayName) or pl.Name }
                    end
                end
            end
        elseif kind == "Recipiente" or kind == "Item no chão" or kind == "Itens de missão" then
            startItemScan()
            local arr = itemCands[kind]
            for inst in pairs(arr) do
                if not inst.Parent or not inst:IsDescendantOf(Workspace) then
                    removeItemCandidate(kind, inst)
                else
                    local hrp = inst:IsA("Model") and (inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart) or inst
                    if hrp and hrp:IsA("BasePart") then
                        out[#out + 1] = { model = inst, hum = nil, hrp = hrp, name = inst.Name }
                    end
                end
            end
        else
            startNpcScan()
            for m, hum in pairs(npcs) do
                if not m.Parent or not m:IsDescendantOf(Workspace) then
                    npcs[m] = nil
                else
                    local hrp = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
                    if hrp and hrp:IsA("BasePart") and hum.Parent and hum.Health > 0 and m ~= LP.Character then
                        out[#out + 1] = { model = m, hum = hum, hrp = hrp, name = m.Name }
                    end
                end
            end
        end
    end
    local selectedTargets, vis = {}, {}
    local function processKind(kind, S, c, vp, slowTick)
        local P = pool[kind]
        local active = S and not Library.Panic and Library.ESPMaster[kind] ~= false and anyOn(S)
        local selected = selectedTargets[kind]
        local camPos = c.CFrame.Position
        if not active then
            selectedTargets[kind] = nil
            selected = {}
        elseif slowTick or not selected then
            local candidates = {}
            gather(kind, candidates)
            table.clear(vis)
            for _, t in ipairs(candidates) do
                if t.model.Parent and t.hrp.Parent and (not t.hum or t.hum.Parent) then
                    t.studs = (t.hrp.Position - camPos).Magnitude
                    t.m = t.studs * 0.28
                    if t.m <= S.maxDist then vis[#vis + 1] = t end
                end
            end
            table.sort(vis, function(a, b) return a.studs < b.studs end)
            selected = {}
            for i = 1, math.min(#vis, 24) do selected[i] = vis[i] end
            selectedTargets[kind] = selected
        end
        local seen = {}
        for i, t in ipairs(selected) do
            if t.model.Parent and t.hrp.Parent and (not t.hum or t.hum.Parent) then
                t.studs = (t.hrp.Position - camPos).Magnitude
                t.m = t.studs * 0.28
                if t.m <= S.maxDist then
                    seen[t.model] = true
                    local d = P[t.model]
                    if not d then d = newDraw(); P[t.model] = d end
                    drawTarget(d, t, S, c, vp, i == 1)
                end
            end
        end
        for model, d in pairs(P) do
            if not seen[model] then
                hideDraw(d)
                if not model.Parent then d.root:Destroy(); d.hl:Destroy(); P[model] = nil end
            end
        end
    end

    -- ---------- radar ----------
    local RC = Library.RadarCfg
    local radar = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(10, 12, 14), BackgroundTransparency = 0.25, BorderSizePixel = 0,
        Visible = false, Active = true }, espGui)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, radar)
    local radarStroke = mk("UIStroke", { Thickness = 2, Color = Library.Theme.Accent }, radar)
    local ring = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, radar)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
    mk("UIStroke", { Thickness = 1, Transparency = 0.65, Color = Color3.new(1, 1, 1) }, ring)
    mk("Frame", { Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0 }, radar)
    mk("Frame", { Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0 }, radar)
    mk("TextLabel", { BackgroundTransparency = 1, Text = "▲", TextSize = 14, FontFace = FONT, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 16) }, radar)
    local radarDots = {}
    local radarDrag, rStart, rPos = false, nil, nil
    conn(radar.InputBegan, function(i)
        local t = i.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1 then radarDrag = true; rStart = i.Position; rPos = radar.Position end
    end)
    conn(UserInputService.InputChanged, function(i)
        if not radarDrag then return end
        local t = i.UserInputType
        if t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseMovement then
            local d = i.Position - rStart
            radar.Position = UDim2.new(rPos.X.Scale, rPos.X.Offset + d.X, rPos.Y.Scale, rPos.Y.Offset + d.Y)
        end
    end)
    conn(UserInputService.InputEnded, function(i)
        local t = i.UserInputType
        if radarDrag and (t == Enum.UserInputType.Touch or t == Enum.UserInputType.MouseButton1) then
            radarDrag = false
            local vp = espGui.AbsoluteSize
            local cpos = radar.AbsolutePosition + radar.AbsoluteSize / 2
            RC.pos = { x = math.clamp(cpos.X / vp.X, 0.05, 0.95), y = math.clamp(cpos.Y / vp.Y, 0.08, 0.92) }
            radar.Position = UDim2.fromScale(RC.pos.x, RC.pos.y)
        end
    end)
    Library.Registry["radar/pos"] = { get = function() return { x = RC.pos.x, y = RC.pos.y } end,
        set = function(v) RC.pos = { x = v.x, y = v.y } end,
        validate = function(v) return type(v) == "table" and type(v.x) == "number" and type(v.y) == "number" and v.x >= 0 and v.x <= 1 and v.y >= 0 and v.y <= 1 end }
    local function updateRadar(c)
        if not RC.on or Library.Panic then radar.Visible = false; return end
        radar.Visible = true
        local size = RC.size
        radar.Size = UDim2.fromOffset(size, size)
        if not radarDrag then radar.Position = UDim2.fromScale(RC.pos.x, RC.pos.y) end
        radarStroke.Color = Library.Theme.Accent
        local look = c.CFrame.LookVector
        local fx, fz = look.X, look.Z
        local mag = math.sqrt(fx * fx + fz * fz)
        if mag < 0.001 then fx, fz = 0, -1 else fx, fz = fx / mag, fz / mag end
        local ch = LP.Character
        local myHrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local myPos = myHrp and myHrp.Position or c.CFrame.Position
        local radius = size / 2 - 5
        local range = RC.range / 0.28
        local n = 0
        local function dot(pos, col)
            if n >= 60 then return end
            n += 1
            local f = radarDots[n]
            if not f then
                f = mk("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0 }, radar)
                mk("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
                radarDots[n] = f
            end
            local rel = pos - myPos
            local x, y = (rel.X * (-fz) + rel.Z * fx) / range, -(rel.X * fx + rel.Z * fz) / range
            local m = math.sqrt(x * x + y * y)
            local out = m > 1
            if out then x, y = x / m, y / m end
            f.Position = UDim2.new(0.5, x * radius, 0.5, y * radius)
            f.BackgroundColor3 = col
            f.BackgroundTransparency = out and 0.6 or 0
            f.Visible = true
        end
        local pcol = (Library.ESP and Library.ESP.Jogador and Library.ESP.Jogador.name.color) or Color3.fromRGB(255, 90, 110)
        for _, pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP and pl.Character then
                local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
                local hum = pl.Character:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then dot(hrp.Position, pcol) end
            end
        end
        if RC.npcs then
            startNpcScan()
            for m, hum in pairs(npcs) do
                local hrp = m.Parent and (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart)
                if hrp and hrp:IsA("BasePart") and hum.Health > 0 and m ~= ch then dot(hrp.Position, Color3.fromRGB(255, 170, 60)) end
            end
        end
        for i = n + 1, #radarDots do radarDots[i].Visible = false end
    end

    -- ---------- buscar saque (filtra por raridade) ----------
    local LF = Library.LootCfg
    local RAR = { { "Mítico", { "mythic", "mítico", "mitico" } }, { "Lendário", { "legendary", "lendário", "lendario" } }, { "Épico", { "epic", "épico", "epico" } },
        { "Raro", { "rare", "raro" } }, { "Incomum", { "uncommon", "incomum" } }, { "Comum", { "common", "comum" } } }
    local RCOL = { ["Mítico"] = Color3.fromRGB(255, 70, 110), ["Lendário"] = Color3.fromRGB(255, 170, 40), ["Épico"] = Color3.fromRGB(180, 90, 255),
        ["Raro"] = Color3.fromRGB(60, 150, 255), ["Incomum"] = Color3.fromRGB(80, 210, 110), ["Comum"] = Color3.fromRGB(205, 205, 205), ["Outros"] = Color3.fromRGB(150, 150, 150) }
    local cands, lootScan, candCount = {}, false, 0
    local function rarityOf(inst, prompt)
        local texts = {}
        for _, a in ipairs({ "Rarity", "Raridade", "Tier", "Quality", "Rank" }) do
            local v = inst:GetAttribute(a)
            if v ~= nil then texts[#texts + 1] = string.lower(tostring(v)) end
        end
        texts[#texts + 1] = string.lower(inst.Name)
        if prompt and prompt.ObjectText ~= "" then texts[#texts + 1] = string.lower(prompt.ObjectText) end
        local par = inst.Parent
        for _ = 1, 2 do
            if par and par ~= Workspace then texts[#texts + 1] = string.lower(par.Name); par = par.Parent end
        end
        for _, r in ipairs(RAR) do
            for _, kw in ipairs(r[2]) do
                for _, tx in ipairs(texts) do
                    if string.find(tx, kw, 1, true) then return r[1] end
                end
            end
        end
        return "Outros"
    end
    local function addCand(obj)
        if engineClosed or not obj:IsDescendantOf(Workspace) then return end
        if obj:IsA("ProximityPrompt") then
            local it = obj.Parent
            if it and it:IsA("Attachment") then it = it.Parent end
            if not it then return end
            local root = (it:IsA("BasePart") and it:FindFirstAncestorOfClass("Model")) or it
            if root:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(root) then return end
            local nm = (obj.ObjectText ~= "" and obj.ObjectText) or root.Name
            if not cands[root] and candCount < 2048 then cands[root] = { name = nm, prompt = obj }; candCount += 1 end
        elseif obj:IsA("Tool") then
            local mdl = obj:FindFirstAncestorOfClass("Model")
            if mdl and mdl:FindFirstChildOfClass("Humanoid") then return end
            if not cands[obj] and candCount < 2048 then cands[obj] = { name = obj.Name }; candCount += 1 end
        end
    end
    local function startLootScan()
        if lootScan then return end
        lootScan = true
        conn(Workspace.DescendantAdded, function(d) if d:IsA("ProximityPrompt") or d:IsA("Tool") then task.defer(function() if not engineClosed and d:IsDescendantOf(Workspace) then addCand(d) end end) end end)
        conn(Workspace.DescendantRemoving, function(d)
            if cands[d] then cands[d] = nil; candCount -= 1 end
            if d:IsA("ProximityPrompt") then
                for root, info in pairs(cands) do
                    if info.prompt == d then cands[root] = nil; candCount -= 1 end
                end
            end
        end)
        Library.StreamScan.start(Workspace, function() return not engineClosed end, addCand)
    end
    local function itemPart(it)
        if it:IsA("BasePart") then return it end
        if it:IsA("Model") then return it.PrimaryPart or it:FindFirstChildWhichIsA("BasePart", true) end
        return it:FindFirstChild("Handle") or it:FindFirstChildWhichIsA("BasePart", true)
    end
    local marks = {}
    local function mark(i)
        local b = marks[i]
        if b then return b end
        local gui = mk("BillboardGui", { Size = UDim2.fromOffset(150, 26), StudsOffset = Vector3.new(0, 2, 0), AlwaysOnTop = true, Enabled = false }, holder)
        b = { gui = gui, label = mk("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), FontFace = FONT, TextSize = 13, TextStrokeTransparency = 0.35, TextColor3 = Color3.new(1, 1, 1) }, gui) }
        marks[i] = b
        return b
    end
    local lootClock, shown = 0, 0
    local function lootRefresh(c)
        local ch = LP.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local origin = hrp and hrp.Position or c.CFrame.Position
        local out = {}
        for it, info in pairs(cands) do
            if not it.Parent or not it:IsDescendantOf(Workspace) then
                cands[it] = nil; candCount -= 1
            else
                local part = itemPart(it)
                if part then
                    local m = (part.Position - origin).Magnitude * 0.28
                    if m <= LF.maxDist then
                        info.rar = info.rar or rarityOf(it, info.prompt)
                        if LF.rarities[info.rar] and (LF.query == "" or string.find(string.lower(info.name), LF.query, 1, true)) then
                            out[#out + 1] = { name = info.name, rar = info.rar, m = m, part = part }
                        end
                    end
                end
            end
        end
        table.sort(out, function(a, b) return a.m < b.m end)
        -- lista na aba
        if LF.rows then
            LF.status:Set(#out == 0 and "Nenhum item com esses filtros por perto." or (#out .. " item(ns) encontrado(s), do mais perto para o mais longe."))
            for i = 1, #LF.rows do
                local it = out[i]
                local row = LF.rows[i]
                if it then
                    local nm = string.gsub(string.gsub(string.gsub(it.name, "&", "&amp;"), "<", "&lt;"), ">", "&gt;")
                    row.Label.Text = string.format('<font color="#%s">●</font> %s  <font color="#9a9a9a">%dm · %s</font>', RCOL[it.rar]:ToHex(), nm, math.floor(it.m), it.rar)
                    row.Frame.Visible = true
                else
                    row.Frame.Visible = false
                end
            end
        end
        -- marcações no jogo
        for i = 1, 40 do
            local it = out[i]
            if it and LF.mark and not Library.Panic then
                local b = mark(i)
                b.gui.Adornee = it.part
                b.label.TextColor3 = RCOL[it.rar]
                b.label.Text = it.name .. " · " .. math.floor(it.m) .. "m"
                b.gui.Enabled = true
            elseif marks[i] then
                marks[i].gui.Enabled = false
            end
        end
        shown = #out
    end
    local function updateLoot(dt, c)
        local active = LF.mark or os.clock() < LF.until_
        if not active then
            if shown > 0 then for _, b in pairs(marks) do b.gui.Enabled = false end; shown = 0 end
            return
        end
        startLootScan()
        lootClock += dt
        if LF.force or lootClock >= 1 then
            LF.force = false
            lootClock = 0
            lootRefresh(c)
        end
    end
    Library:OnPanic(function(on) if on then for _, b in pairs(marks) do b.gui.Enabled = false end end end)

    -- ---------- laço principal ----------
    local errCount, stopped, elapsed = 0, false, 0
    Library.RenderRate = Library.RenderRate or 30
    local function renderEngine(dt)
        if stopped or engineClosed then return end
        elapsed += dt
        local slowTick = elapsed >= 1 / math.clamp(Library.RenderRate or 30, 10, 60)
        local slowDt = elapsed
        if slowTick then elapsed = 0 end
        local started = os.clock()
        local ok, err = pcall(function()
            local c = Workspace.CurrentCamera
            if not c then return end
            local vp = c.ViewportSize
            for kind in pairs(pool) do processKind(kind, Library.ESP and Library.ESP[kind], c, vp, slowTick) end
            if slowTick then
                updateRadar(c)
                updateLoot(slowDt, c)
            end
        end)
        if Library.Diagnostics then Library.Diagnostics:sampleEngine(os.clock() - started) end
        if not ok then
            errCount += 1
            warn("[BBC] ESP: " .. tostring(err))
            if errCount == 1 and Library.Diagnostics then Library.Diagnostics:record("ESP", err) end
            if errCount >= 5 then
                stopped = true
                for _, P in pairs(pool) do for _, d in pairs(P) do hideDraw(d) end end
                Library:Notify({ Title = "BBC HUB", Content = "O ESP parou por causa de um erro (veja o console).", Duration = 5 })
            end
        else
            errCount = 0
        end
    end
    local renderName = "BBC_ESP_" .. tostring({})
    local bound = pcall(function() RunService:BindToRenderStep(renderName, Enum.RenderPriority.Camera.Value + 1, renderEngine) end)
    if not bound then conn(RunService.RenderStepped, renderEngine) end

    -- desliga o motor de vez: laço, conexões, GUIs do ESP/radar e registros do radar
    local function stopEngine()
        if engineClosed then return end
        engineClosed = true
        Actions.alive = false
        stopped = true
        if bound then pcall(function() RunService:UnbindFromRenderStep(renderName) end) end
        for _, c in ipairs(engineConns) do pcall(function() c:Disconnect() end) end
        for _, g in ipairs(engineGuis) do pcall(function() g:Destroy() end) end
        for _, P in pairs(pool) do for _, d in pairs(P) do pcall(hideDraw, d) end end
        for k in pairs(pool) do pool[k] = nil end
        Library.Registry["radar/pos"] = nil
        table.clear(Library._panicGuis)
        Library._panicZone = nil
        for _, fn in ipairs(Actions.cleanups or {}) do pcall(fn) end
    end
    Library._stopEngine = stopEngine
end

Library.Tr = tr
pcall(function() Window:FinishLoading() end)   -- fecha a intro: o cartão vira o menu
Library:Notify({ Title = "BBC HUB", Content = tr("Interface carregada."), Duration = 4 })
if Library.GuiProtection.unavailable > 0 or Library.GuiProtection.failed > 0 then
    Library:Notify({ Title = "BBC HUB", Content = tr("Proteção de interface indisponível ou falhou; o menu pode ser detectado."), Duration = 8 })
end
