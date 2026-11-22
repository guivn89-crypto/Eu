--[[
    BBC HUB - Feature: Player
    Aba JOGADOR: movimento, câmera, saque, animações, recursos.
    Painel de perfil (Home) com estatísticas reais.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

-- Defensive: Ensure Library.Fonts exists before any UI code accesses it
local InitUtils = BBC.Modules["utils.init"]
if InitUtils and InitUtils.ensureFonts then
    InitUtils.ensureFonts(BBC.Library)
end

-- ---------- Perfil do Jogador (Home) ----------
local function buildProfile(win, page, list)
    local Library = BBC.Library
    local Utils = BBC.Utils
    local Security = BBC.Security
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")
    local StatsService = game:GetService("Stats")
    local LP = Players.LocalPlayer
    local Config = Security.getConfig()
    local VERSION = Config.Version or "0.0.8.2"
    local ACCESS = Config.Access or "FREE"

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

    local function hookCharacter(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end
        local last = hum.Health
        hum.HealthChanged:Connect(function(h)
            if h < last then data.damage += last - h end
            last = h
        end)
        hum.Died:Connect(function() data.deaths += 1 end)
    end
    if LP.Character then task.spawn(hookCharacter, LP.Character) end
    LP.CharacterAdded:Connect(hookCharacter)

    local function hookVictim(plr)
        if plr == LP then return end
        local function onChar(char)
            local hum = char:WaitForChild("Humanoid", 10)
            if not hum then return end
            hum.Died:Connect(function()
                local tag = hum:FindFirstChild("creator")
                if tag and tag.Value == LP then data.kills += 1 end
            end)
        end
        if plr.Character then task.spawn(onChar, plr.Character) end
        plr.CharacterAdded:Connect(onChar)
    end
    for _, p in ipairs(Players:GetPlayers()) do hookVictim(p) end
    Players.PlayerAdded:Connect(hookVictim)

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
        local ok2, p = pcall(function() return LP:GetNetworkPing() * 2000 end)
        return ok2 and math.floor(p) or 0
    end
    local function getDevice()
        local kb = UserInputService.KeyboardEnabled
        if UserInputService.TouchEnabled and not kb then return "Celular" end
        if UserInputService.GamepadEnabled and not kb then return "Console" end
        return "PC"
    end
    local frames, fps = 0, 0
    RunService.RenderStepped:Connect(function() frames += 1 end)

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
        txt(f, string.upper(title), 12, "Muted", false, { LayoutOrder = 0 })
        return f
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
        if ok then thumb = img; avatar.Image = img end
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
    nameL:GetPropertyChangedSignal("TextBounds"):Connect(placeBadge); placeBadge()
    local hidden = false
    local spy = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(44, 44), Text = "OCULTAR", TextSize = 9, AutoButtonColor = false, FontFace = Library.Fonts.Bold }, idc)
    decorate(spy, "Background", 6); th(spy, "TextColor3", "Text")
    spy.MouseButton1Click:Connect(function()
        hidden = not hidden
        pcall(function() win:SetHideName(hidden); win:SetHideAvatar(hidden) end)
        nameL.Text = hidden and "••••••" or LP.DisplayName
        userL.Text = hidden and "@••••••" or ("@" .. LP.Name)
        avatar.Image = hidden and "" or (thumb or "")
        th(spy, "TextColor3", hidden and "Accent" or "Text")
    end)

    -- Estatísticas
    local st = box(root, "Estatísticas", 2)
    local sg = grid(st, 6, 1)
    local vKills = cell(sg, "Abates", 1, 15)
    local vDeaths = cell(sg, "Mortes", 2, 15)
    local vKD, kdCell = cell(sg, "Proporção K/D", 3, 15)
    local vRep = cell(sg, "Denúncias", 4, 15)
    local vPlayed = cell(sg, "Tempo jogado", 5, 15)
    local vDmg = cell(sg, "Dano recebido", 6, 15)
    th(vKD, "TextColor3", "Accent")

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

    -- Valores estáticos
    vUid.Text = tostring(LP.UserId)
    vAge.Text = LP.AccountAge .. " dias"
    vAccess.Text = ACCESS
    vVer.Text = VERSION
    vDev.Text = getDevice()
    table.insert(BBC.onLanguageChanged, function() vDev.Text = getDevice(); vAge.Text = LP.AccountAge .. " dias" end)
    vMap.Text = tostring(game.PlaceId)
    vMapVer.Text = tostring(game.PlaceVersion)
    vJob.Text = (game.JobId ~= "" and game.JobId) or "Servidor local"
    vRuns.Text = tostring(data.runs)
    vRep.Text = "—"

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
            vLeft.Text = left > 0 and fmtDuration(left) or "Expirado"
        else
            vLeft.Text = "Ilimitado"
        end
        if now - lastSave >= 30 then lastSave = now; save() end
    end
    refresh()
    task.spawn(function()
        while list.Parent do
            task.wait(1)
            pcall(refresh)
        end
    end)
    Players.PlayerRemoving:Connect(function(p) if p == LP then save() end end)
end

Features.buildProfile = buildProfile

-- ---------- Aba JOGADOR ----------
function Features.buildPlayer(window)
    local jogador = window:Tab({ Name = "JOGADOR", Icon = "user" })
    local g = jogador:Groupbox({ Name = "MOVIMENTO", Icon = "move", Side = "Left" })
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
    S(g, "Campo de visão", 30, 120, 120)
    S(g, "Visão com zoom", 5, 120, 5)
    g:Keybind({ Name = "Zoom", Default = "N", OnChanged = function(k) BBC.keys.zoom = k.Name; BBC.refreshPanels() end, Callback = function() end })
    g = jogador:Groupbox({ Name = "ANIMAÇÕES", Icon = "activity", Side = "Right" })
    g:Dropdown({ Name = "Animação", Options = { "Swish", "Padrão" }, Default = "Swish", Callback = function(v) end })
    T(g, "Repetir")
    S(g, "Velocidade", 0.1, 3, 1, "x", 0.1)
    S(g, "Peso", 0, 100, 100, "%")
    g:Button({ Name = "Reproduzir", Callback = function() BBC.notify("Reproduzir") end })
    g = jogador:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Right" })
    T(g, "Painel do jogador"); T(g, "Anti AFK"); T(g, "Renascer automático")
    T(g, "Remover água"); T(g, "Não se afogar"); T(g, "Mapa e navegação", true)

    return jogador
end

return { buildPlayer = Features.buildPlayer }