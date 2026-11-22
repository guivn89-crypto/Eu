--[[
    BBC HUB - Feature: World
    Abas MUNDO, EXTRAS, BUSCAR SAQUE, SERVIDORES, SKINS, MISSÕES, COMERCIANTES.
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

-- ---------- Servidores (buildServers) ----------
local function buildServers(tab)
    local Library = BBC.Library
    local Utils = BBC.Utils
    local Security = BBC.Security
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
        b.MouseButton1Click:Connect(onClick)
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
    rowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
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

    local function fmtUp(n) return tostring(n or 0) end
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
        BBC.notify("Entrando no servidor...")
        Library:JoinServer(sv.id)
    end

    local function renderDetails()
        local sv = state.selected
        if not sv then
            detName.Text = mapName
            detSub.Text = "Pronto para entrar"
            return
        end
        detName.Text = mapName .. (sv.id == game.JobId and ("  •  Seu servidor") or "")
        detSub.Text = "Pronto para entrar  ·  " .. string.sub(sv.id or "", 1, 22)
    end

    local render
    local function selectServer(sv) state.selected = sv; renderDetails(); render() end

    render = function()
        for _, c in ipairs(scroller:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
        for i = #themed, 1, -1 do if not themed[i][1].Parent then table.remove(themed, i) end end
        local items = visibleList()
        local total = #state.all
        title.Text = "SERVIDOR   " .. #items .. " / " .. total .. " servidores"
        cName.Text = "Servidor"; cPing.Text = "Ping"; cPl.Text = "Jogadores"; cFps.Text = "FPS"
        sortBtn.Text = "Ordenar: " .. (state.sort == "players" and "Jogadores" or (state.sort == "ping" and "Ping" or "FPS"))
        dirBtn.Text = state.desc and "↓" or "↑"
        box.PlaceholderText = "Buscar mapa, nome ou ID do servidor"
        bRefresh.Text = "Atualizar"; bHistory.Text = "Histórico"; bFilters.Text = "Filtros"
        bDetails.Text = "Detalhes"; bJoin.Text = "Entrar"
        if state.loading then
            txt(scroller, "Carregando servidores...", 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        elseif state.failed and not state.showHistory then
            txt(scroller, "Falha ao carregar a lista", 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        elseif #items == 0 then
            txt(scroller, state.showHistory and "Histórico vazio" or "Nenhum servidor encontrado", 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        end
        for i, sv in ipairs(items) do
            if i > 150 then break end
            local row = mk("TextButton", { Size = UDim2.new(1, 0, 0, 44), Text = "", AutoButtonColor = false, LayoutOrder = i }, scroller)
            decorate(row, "Surface2", 6)
            local selected = state.selected and state.selected.id == sv.id
            if selected then th(row:FindFirstChildOfClass("UIStroke"), "Color", "Accent") end
            txt(row, mapName, 14, "Text", true, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.34, -10, 0, 18) })
            txt(row, (sv.id == game.JobId and ("Seu servidor  ·  ") or "") .. shortId(sv.id), 11, "Muted", false, { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(0.34, -10, 0, 16) })
            local ping = tonumber(sv.ping)
            txt(row, ping and (math.floor(ping) .. " ms") or "—", 13, "Text", false, { Position = UDim2.new(0.37, 0, 0, 12), Size = UDim2.new(0.15, 0, 0, 18) })
            txt(row, (sv.playing or 0) .. "/" .. (sv.maxPlayers or 0), 13, "Text", false, { Position = UDim2.new(0.52, 0, 0, 12), Size = UDim2.new(0.17, 0, 0, 18) })
            local fps = tonumber(sv.fps)
            txt(row, fps and tostring(math.floor(fps)) or "—", 13, "Text", false, { Position = UDim2.new(0.69, 0, 0, 12), Size = UDim2.new(0.12, 0, 0, 18) })
            local full = (sv.playing or 0) >= (sv.maxPlayers or 0) and (sv.maxPlayers or 0) > 0
            local joinB = mk("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(62, 28), Text = "Entrar", TextSize = 13,
                AutoButtonColor = false, FontFace = Library.Fonts.Bold, BorderSizePixel = 0, ZIndex = 3 }, row)
            th(joinB, "BackgroundColor3", full and "Surface3" or "Accent")
            th(joinB, "TextColor3", "Text")
            mk("UICorner", { CornerRadius = UDim.new(0, 5) }, joinB)
            joinB.MouseButton1Click:Connect(function() state.selected = sv; renderDetails(); joinServer(sv) end)
            row.MouseButton1Click:Connect(function() selectServer(sv) end)
        end
    end

    local function load()
        if state.loading then return end
        state.loading, state.failed = true, false
        render()
        task.spawn(function()
            local all, cursor = {}, nil
            for _ = 1, 3 do
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
            state.all, state.loading = all, false
            render()
        end)
    end

    bRefresh = btn(right, "", 88, function() state.showHistory = false; load() end, 3)
    bHistory = btn(right, "", 88, function() state.showHistory = not state.showHistory; render() end, 2)
    bFilters = btn(right, "", 78, function() filtersFrame.Visible = not filtersFrame.Visible end, 1)
    bDetails = btn(detBtns, "", 80, function()
        local sv = state.selected
        if not sv then return end
        local info = string.format("%s | %d/%d | %s ms | %s fps", sv.id, sv.playing or 0, sv.maxPlayers or 0, tostring(sv.ping and math.floor(sv.ping) or "—"), tostring(sv.fps and math.floor(sv.fps) or "—"))
        if not pcall(function() setclipboard(sv.id) end) then BBC.notify(info) else BBC.notify("Copiar ID: " .. string.sub(sv.id, 1, 13)) end
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
        local function paint() b.Text = (state[key] and "● " or "○ ") .. label end
        paint()
        b.MouseButton1Click:Connect(function() state[key] = not state[key]; paint(); render() end)
        table.insert(BBC.onLanguageChanged, paint)
    end
    filterToggle("hideFull", "Ocultar cheios", 1)
    filterToggle("hideMine", "Ocultar meu servidor", 2)

    box:GetPropertyChangedSignal("Text"):Connect(function() state.query = box.Text; render() end)
    sortBtn.MouseButton1Click:Connect(function()
        state.sort = state.sort == "players" and "ping" or (state.sort == "ping" and "fps" or "players")
        render()
    end)
    dirBtn.MouseButton1Click:Connect(function() state.desc = not state.desc; render() end)
    table.insert(BBC.onLanguageChanged, function() renderDetails(); render() end)
    renderDetails()
    load()
end

Features.buildServers = buildServers

-- ---------- Aba MUNDO ----------
function Features.buildWorld(window)
    local mundo = window:Tab({ Name = "MUNDO", Icon = "globe" })
    local g = mundo:Groupbox({ Name = "MUNDO", Icon = "globe", Side = "Left" })
    g:Foldout({ Name = "Cores do terreno", Build = function(p)
        p:ColorPicker({ Name = "Grama", Default = Color3.fromRGB(72, 160, 76), Callback = function(c) BBC.TerrainColor(Enum.Material.Grass, c) end })
        p:ColorPicker({ Name = "Areia", Default = Color3.fromRGB(214, 190, 120), Callback = function(c) BBC.TerrainColor(Enum.Material.Sand, c) end })
        p:ColorPicker({ Name = "Rocha", Default = Color3.fromRGB(120, 120, 126), Callback = function(c) BBC.TerrainColor(Enum.Material.Rock, c) end })
        p:ColorPicker({ Name = "Terra", Default = Color3.fromRGB(110, 78, 52), Callback = function(c) BBC.TerrainColor(Enum.Material.Ground, c) end })
    end })
    g:Foldout({ Name = "Folhas", Build = function(p)
        p:ColorPicker({ Name = "Cor das folhas", Default = Color3.fromRGB(70, 150, 70), Callback = function(c) end })
    end })
    g:Foldout({ Name = "Troncos", Build = function(p)
        p:ColorPicker({ Name = "Cor dos troncos", Default = Color3.fromRGB(100, 70, 45), Callback = function(c) end })
    end })
    g:ColorPicker({ Name = "Cor da água", Default = Color3.fromRGB(40, 70, 75), Callback = function(c) BBC.TerrainColor("Water", c) end })
    T(g, "Sem grama"); T(g, "Desativar minas", true)
    g = mundo:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Left" })
    T(g, "Carregar jogadores"); T(g, "Buscar chefes"); T(g, "Pontos de saída", true)
    BBC.RadarCfg = { on = false, range = 150, size = 130, npcs = false, pos = { x = 0.88, y = 0.3 } }
    g:Toggle({ Name = "Radar", Default = false, NoPin = true, Tooltip = "Mini mapa redondo com os jogadores ao redor. Arraste para mover.",
        Callback = function(v) BBC.RadarCfg.on = v end,
        Settings = function(p)
            p:Slider({ Name = "Alcance", Min = 50, Max = 500, Default = 150, Suffix = "m", Step = 10, Callback = function(v) BBC.RadarCfg.range = v end })
            p:Slider({ Name = "Tamanho", Min = 90, Max = 220, Default = 130, Step = 5, Callback = function(v) BBC.RadarCfg.size = v end })
            p:Toggle({ Name = "Mostrar NPCs", Default = false, Callback = function(v) BBC.RadarCfg.npcs = v end })
        end })
    g = mundo:Groupbox({ Name = "ILUMINAÇÃO", Icon = "lightbulb", Side = "Right", Checkbox = true, Default = true, Callback = function(v) end })
    for _, n in ipairs({ "Luz", "Hora e sol", "Sombras", "Renderização", "Neblina", "Atmosfera", "Céu", "Nuvens",
        "Florescer", "Desfoque", "Ajuste de cor", "Profundidade", "Raios de sol", "Tonalidade" }) do
        T(g, n)
    end
    return mundo
end

-- ---------- Aba EXTRAS ----------
function Features.buildExtras(window)
    local extras = window:Tab({ Name = "EXTRAS", Icon = "layout-grid" })
    local g = extras:Groupbox({ Name = "EXTRAS", Icon = "layout-grid", Side = "Left" })
    T(g, "Troca rápida"); g:Button({ Name = "Atravessar porta", Callback = function() BBC.notify("Atravessar porta") end })
    T(g, "Remover efeitos"); T(g, "Avisos de denúncias", true); T(g, "Avisos de entrada")
    g = extras:Groupbox({ Name = "SONS", Icon = "volume-2", Side = "Left" })
    g:Input({ Name = "Adicionar ID de som", Placeholder = "ID", Callback = function(v) end })
    for _, n in ipairs({ "Jump", "Pegadas", "Pouso", "Capacete", "Tiro na cabeça", "Tiro no corpo", "Abate", "Disparo", "Acerto com sangue" }) do
        T(g, n, n == "Disparo")
    end
    g = extras:Groupbox({ Name = "DETECÇÃO", Icon = "radar", Side = "Right" })
    T(g, "Criador"); T(g, "Testador"); T(g, "Moderador", true); T(g, "Trapaceiro")
    g = extras:Groupbox({ Name = "ORDENAR DEPÓSITO", Icon = "arrow-down-up", Side = "Right" })
    g:Button({ Name = "Por valor", Callback = function() BBC.notify("Por valor") end })
    g:Button({ Name = "Por tipo", Callback = function() BBC.notify("Por tipo") end })
    g:Button({ Name = "Por nome", Callback = function() BBC.notify("Por nome") end })
    g = extras:Groupbox({ Name = "VER INVENTÁRIO", Icon = "backpack", Side = "Right" })
    g:Keybind({ Name = "Ver inventário", Default = "Backquote", Callback = function() end })
    g:Dropdown({ Name = "Mostrar", Options = { "Jogadores", "NPCs", "Todos" }, Default = "Jogadores", Callback = function(v) end })
    T(g, "Sempre mostrar")
    return extras
end

-- ---------- Buscar Saque ----------
function Features.buildLoot(window)
    local saque = window:Tab({ Name = "BUSCAR SAQUE", Icon = "package-search" })
    BBC.LootCfg = { rarities = { ["Mítico"] = true, ["Lendário"] = true, ["Épico"] = true, ["Raro"] = true }, maxDist = 300, query = "", mark = false, force = true, until_ = 0 }
    do
        local LF = BBC.LootCfg
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
        fg:Toggle({ Name = "Marcar na tela", Default = false, Tooltip = "Mostra o nome e a distância dos itens encontrados direto no jogo, na cor da raridade.",
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
    return saque
end

-- ---------- Skins / Missões / Comerciantes (placeholders) ----------
function Features.buildSkins(window)
    local skins = window:Tab({ Name = "SKINS", Icon = "palette" })
    skins:Section("SKINS")
    return skins
end

function Features.buildQuests(window)
    local missoes = window:Tab({ Name = "MISSÕES", Icon = "scroll-text" })
    missoes:Section("MISSÕES")
    return missoes
end

function Features.buildMerchants(window)
    local comerciantes = window:Tab({ Name = "COMERCIANTES", Icon = "shopping-cart" })
    comerciantes:Section("COMERCIANTES")
    return comerciantes
end

Features.buildWorldTab = Features.buildWorld
Features.buildExtrasTab = Features.buildExtras
Features.buildLootTab = Features.buildLoot
Features.buildSkinsTab = Features.buildSkins
Features.buildQuestsTab = Features.buildQuests
Features.buildMerchantsTab = Features.buildMerchants

return { buildWorld = Features.buildWorld }