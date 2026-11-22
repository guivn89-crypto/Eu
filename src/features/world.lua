--[[
    BBC HUB - Feature: World
    Aba MUNDO, EXTRAS, busca de saque, skins, missões, comerciantes
    e navegador de servidores (API pública do Roblox).
]]

local Features = BBC.Features or {}
BBC.Features = Features

local Library = BBC.Library
local Utils = BBC.Utils
local Security = BBC.Security
local Controls = BBC.UI.Controls
local T = Controls.T
local S = Controls.S

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local LocalPlayer = Players.LocalPlayer

local function tr(text)
    return BBC.I18n and BBC.I18n.tr(text) or text
end

local function notify(text)
    Utils.notifyText(text)
end

local function onLanguageChanged(callback)
    if BBC.I18n then
        table.insert(BBC.I18n.onChanged, callback)
    end
end

-- ============================================================
--  Navegador de servidores
-- ============================================================
function Features.buildServers(tab)
    local list = tab.List
    local themed = {}
    local function th(instance, property, key)
        themed[#themed + 1] = { instance, property, key }
        instance[property] = Library.Theme[key]
    end
    table.insert(Library._themeListeners, function()
        for _, item in ipairs(themed) do
            if item[1].Parent then
                item[1][item[2]] = Library.Theme[item[3]]
            end
        end
    end)
    local function mk(class, props, parent)
        local instance = Instance.new(class)
        for key, value in pairs(props) do
            instance[key] = value
        end
        instance.Parent = parent
        return instance
    end
    local function txt(parent, text, size, key, bold, extra)
        local textLabel = mk("TextLabel", {
            BackgroundTransparency = 1,
            Text = text,
            TextSize = size,
            FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Size = UDim2.new(1, 0, 0, size + 4),
        }, parent)
        th(textLabel, "TextColor3", key or "Text")
        for property, value in pairs(extra or {}) do
            textLabel[property] = value
        end
        return textLabel
    end
    local function decorate(frame, key, radius)
        th(frame, "BackgroundColor3", key)
        frame.BorderSizePixel = 0
        mk("UICorner", { CornerRadius = UDim.new(0, radius or 6) }, frame)
        th(mk("UIStroke", {}, frame), "Color", "Stroke")
    end
    local function button(parent, text, width, onClick, order)
        local instance = mk("TextButton", {
            Size = UDim2.fromOffset(width, 28),
            Text = text,
            TextSize = 13,
            AutoButtonColor = false,
            FontFace = Library.Fonts.Bold,
            LayoutOrder = order or 0,
        }, parent)
        decorate(instance, "Surface3", 6)
        th(instance, "TextColor3", "Text")
        instance.MouseButton1Click:Connect(onClick)
        return instance
    end

    local historyFile = "BBC_HUB/historico_servidores.json"
    local history = Security.readJSON(historyFile) or {}
    local function saveHistory()
        Security.ensureFolder("BBC_HUB")
        Security.writeJSON(historyFile, history)
    end
    local mapName = "Servidor"
    task.spawn(function()
        local ok, info = pcall(function()
            return MarketplaceService:GetProductInfo(game.PlaceId)
        end)
        if ok and info and info.Name then
            mapName = info.Name
        end
    end)

    local root = mk("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
    }, list)
    mk("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, root)

    local state = {
        all = {},
        sort = "players",
        desc = true,
        query = "",
        hideFull = true,
        hideMine = false,
        showHistory = false,
        selected = nil,
        loading = false,
        failed = false,
    }

    -- Cabeçalho
    local head = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 1 }, root)
    local title = txt(head, "", 15, "Text", true, { Size = UDim2.new(0.5, 0, 1, 0), TextYAlignment = Enum.TextYAlignment.Center })
    local right = mk("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.new(0.6, 0, 1, 0),
    }, head)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, right)
    local refreshButton, historyButton, filtersButton
    local filtersFrame

    -- Busca + ordenação
    local bar = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2 }, root)
    local searchBox = mk("TextBox", {
        Size = UDim2.new(1, -190, 1, 0),
        Text = "",
        TextSize = 13,
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        FontFace = Library.Fonts.Regular,
    }, bar)
    decorate(searchBox, "Surface2", 6)
    th(searchBox, "TextColor3", "Text")
    th(searchBox, "PlaceholderColor3", "Muted")
    mk("UIPadding", { PaddingLeft = UDim.new(0, 8) }, searchBox)
    local sortButton = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -34, 0, 0),
        Size = UDim2.fromOffset(150, 30),
        TextSize = 13,
        AutoButtonColor = false,
        FontFace = Library.Fonts.Bold,
        Text = "",
    }, bar)
    decorate(sortButton, "Surface2", 6)
    th(sortButton, "TextColor3", "Text")
    local directionButton = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, 0, 0, 0),
        Size = UDim2.fromOffset(28, 30),
        TextSize = 16,
        AutoButtonColor = false,
        FontFace = Library.Fonts.Bold,
        Text = "↓",
    }, bar)
    decorate(directionButton, "Surface2", 6)
    th(directionButton, "TextColor3", "Accent")

    -- Colunas
    local columns = mk("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4 }, root)
    local columnName = txt(columns, "", 12, "Muted", false, { Size = UDim2.new(0.34, 0, 1, 0), Position = UDim2.fromOffset(10, 0) })
    local columnPing = txt(columns, "", 12, "Muted", false, { Size = UDim2.new(0.15, 0, 1, 0), Position = UDim2.new(0.37, 0, 0, 0) })
    local columnPlayers = txt(columns, "", 12, "Muted", false, { Size = UDim2.new(0.17, 0, 1, 0), Position = UDim2.new(0.52, 0, 0, 0) })
    local columnFps = txt(columns, "", 12, "Muted", false, { Size = UDim2.new(0.12, 0, 1, 0), Position = UDim2.new(0.69, 0, 0, 0) })

    -- Lista com rolagem própria
    local scroller = mk("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 220),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        LayoutOrder = 5,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, root)
    th(scroller, "ScrollBarImageColor3", "Accent")
    local rowLayout = mk("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, scroller)
    mk("UIPadding", { PaddingRight = UDim.new(0, 8) }, scroller)
    rowLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        local scale = scroller.AbsoluteSize.Y > 0 and (scroller.AbsoluteSize.Y / 220) or 1
        scroller.CanvasSize = UDim2.fromOffset(0, rowLayout.AbsoluteContentSize.Y / math.max(scale, 0.05) + 4)
    end)

    -- Cartão de detalhes
    local details = mk("Frame", { Size = UDim2.new(1, 0, 0, 64), LayoutOrder = 6 }, root)
    decorate(details, "Surface2", 8)
    local detailsName = txt(details, "", 15, "Text", true, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -190, 0, 20) })
    local detailsSub = txt(details, "", 12, "Muted", false, { Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -190, 0, 18) })
    local detailsButtons = mk("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(170, 28),
    }, details)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, detailsButtons)
    local detailsButton, joinButton

    local function shortId(id)
        return string.sub(id or "", 1, 13)
    end

    local function visibleList()
        local result = {}
        if state.showHistory then
            for _, entry in ipairs(history) do
                table.insert(result, {
                    id = entry.id,
                    playing = entry.playing,
                    maxPlayers = entry.maxPlayers,
                    ping = entry.ping,
                    fps = entry.fps,
                    when = entry.when,
                })
            end
            return result
        end
        local query = string.lower(state.query)
        for _, server in ipairs(state.all) do
            local pass = true
            if state.hideFull and server.playing >= server.maxPlayers then
                pass = false
            end
            if state.hideMine and server.id == game.JobId then
                pass = false
            end
            if pass and query ~= "" then
                local haystack = string.lower(mapName .. " " .. server.id .. " " .. server.playing .. "/" .. server.maxPlayers)
                if not string.find(haystack, query, 1, true) then
                    pass = false
                end
            end
            if pass then
                table.insert(result, server)
            end
        end
        local key = state.sort == "ping" and "ping" or (state.sort == "fps" and "fps" or "playing")
        table.sort(result, function(a, b)
            local x, y = tonumber(a[key]) or 0, tonumber(b[key]) or 0
            if x == y then
                return a.id < b.id
            end
            if state.desc then
                return x > y
            end
            return x < y
        end)
        return result
    end

    local function joinServer(server)
        if not server then
            return
        end
        table.insert(history, 1, {
            id = server.id,
            playing = server.playing,
            maxPlayers = server.maxPlayers,
            ping = server.ping,
            fps = server.fps,
            when = os.time(),
        })
        while #history > 30 do
            table.remove(history)
        end
        saveHistory()
        notify(tr("Entrando no servidor..."))
        Library:JoinServer(server.id)
    end

    local function renderDetails()
        local server = state.selected
        if not server then
            detailsName.Text = mapName
            detailsSub.Text = tr("Pronto para entrar")
            return
        end
        detailsName.Text = mapName .. (server.id == game.JobId and ("  •  " .. tr("Seu servidor")) or "")
        detailsSub.Text = tr("Pronto para entrar") .. "  ·  " .. string.sub(server.id or "", 1, 22)
    end

    local render
    local function selectServer(server)
        state.selected = server
        renderDetails()
        render()
    end

    render = function()
        for _, child in ipairs(scroller:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        for index = #themed, 1, -1 do
            if not themed[index][1].Parent then
                table.remove(themed, index)
            end
        end
        local items = visibleList()
        local total = #state.all
        title.Text = string.upper(tr("Servidor")) .. "   " .. #items .. " / " .. total .. " " .. tr("servidores")
        columnName.Text = tr("Servidor")
        columnPing.Text = "Ping"
        columnPlayers.Text = tr("Jogadores")
        columnFps.Text = "FPS"
        sortButton.Text = tr("Ordenar") .. ": "
            .. (state.sort == "players" and tr("Jogadores") or (state.sort == "ping" and "Ping" or "FPS"))
        directionButton.Text = state.desc and "↓" or "↑"
        searchBox.PlaceholderText = tr("Buscar mapa, nome ou ID do servidor")
        refreshButton.Text = tr("Atualizar")
        historyButton.Text = tr("Histórico")
        filtersButton.Text = tr("Filtros")
        detailsButton.Text = tr("Detalhes")
        joinButton.Text = tr("Entrar")
        if state.loading then
            txt(scroller, tr("Carregando servidores..."), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        elseif state.failed and not state.showHistory then
            txt(scroller, tr("Falha ao carregar a lista"), 14, "Muted", false, { Size = UDim2.new(1, 0, 0, 24) })
        elseif #items == 0 then
            txt(scroller, tr(state.showHistory and "Histórico vazio" or "Nenhum servidor encontrado"), 14, "Muted", false, {
                Size = UDim2.new(1, 0, 0, 24),
            })
        end
        for index, server in ipairs(items) do
            if index > 150 then
                break
            end
            local row = mk("TextButton", {
                Size = UDim2.new(1, 0, 0, 44),
                Text = "",
                AutoButtonColor = false,
                LayoutOrder = index,
            }, scroller)
            decorate(row, "Surface2", 6)
            local selected = state.selected and state.selected.id == server.id
            if selected then
                th(row:FindFirstChildOfClass("UIStroke"), "Color", "Accent")
            end
            txt(row, mapName, 14, "Text", true, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(0.34, -10, 0, 18) })
            txt(row, (server.id == game.JobId and (tr("Seu servidor") .. " · ") or "") .. shortId(server.id), 11, "Muted", false, {
                Position = UDim2.fromOffset(10, 24),
                Size = UDim2.new(0.34, -10, 0, 16),
            })
            local ping = tonumber(server.ping)
            txt(row, ping and (math.floor(ping) .. " ms") or "—", 13, "Text", false, {
                Position = UDim2.new(0.37, 0, 0, 12),
                Size = UDim2.new(0.15, 0, 0, 18),
            })
            txt(row, (server.playing or 0) .. "/" .. (server.maxPlayers or 0), 13, "Text", false, {
                Position = UDim2.new(0.52, 0, 0, 12),
                Size = UDim2.new(0.17, 0, 0, 18),
            })
            local fps = tonumber(server.fps)
            txt(row, fps and tostring(math.floor(fps)) or "—", 13, "Text", false, {
                Position = UDim2.new(0.69, 0, 0, 12),
                Size = UDim2.new(0.12, 0, 0, 18),
            })
            local full = (server.playing or 0) >= (server.maxPlayers or 0) and (server.maxPlayers or 0) > 0
            local join = mk("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.fromOffset(62, 28),
                Text = tr("Entrar"),
                TextSize = 13,
                AutoButtonColor = false,
                FontFace = Library.Fonts.Bold,
                BorderSizePixel = 0,
                ZIndex = 3,
            }, row)
            th(join, "BackgroundColor3", full and "Surface3" or "Accent")
            th(join, "TextColor3", "Text")
            mk("UICorner", { CornerRadius = UDim.new(0, 5) }, join)
            join.MouseButton1Click:Connect(function()
                state.selected = server
                renderDetails()
                joinServer(server)
            end)
            row.MouseButton1Click:Connect(function()
                selectServer(server)
            end)
        end
    end

    local function load()
        if state.loading then
            return
        end
        state.loading, state.failed = true, false
        render()
        task.spawn(function()
            local all, cursor = {}, nil
            for _ = 1, 3 do
                local page, nextCursor = Library:FetchServers("Desc", cursor)
                if not page then
                    if #all == 0 then
                        state.failed = true
                    end
                    break
                end
                for _, server in ipairs(page) do
                    if type(server) == "table" and server.id then
                        table.insert(all, {
                            id = server.id,
                            playing = tonumber(server.playing) or 0,
                            maxPlayers = tonumber(server.maxPlayers) or 0,
                            ping = server.ping,
                            fps = server.fps,
                        })
                    end
                end
                cursor = nextCursor
                if not cursor then
                    break
                end
            end
            state.all, state.loading = all, false
            render()
        end)
    end

    refreshButton = button(right, "", 88, function()
        state.showHistory = false
        load()
    end, 3)
    historyButton = button(right, "", 88, function()
        state.showHistory = not state.showHistory
        render()
    end, 2)
    filtersButton = button(right, "", 78, function()
        filtersFrame.Visible = not filtersFrame.Visible
    end, 1)
    detailsButton = button(detailsButtons, "", 80, function()
        local server = state.selected
        if not server then
            return
        end
        local info = string.format(
            "%s | %d/%d | %s ms | %s fps",
            server.id,
            server.playing or 0,
            server.maxPlayers or 0,
            tostring(server.ping and math.floor(server.ping) or "—"),
            tostring(server.fps and math.floor(server.fps) or "—")
        )
        if not pcall(function()
            setclipboard(server.id)
        end) then
            notify(info)
        else
            notify(tr("Copiar ID") .. ": " .. string.sub(server.id, 1, 13))
        end
    end, 1)
    joinButton = button(detailsButtons, "", 80, function()
        joinServer(state.selected)
    end, 2)

    -- Filtros
    filtersFrame = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Visible = false,
        LayoutOrder = 3,
    }, root)
    decorate(filtersFrame, "Surface2", 6)
    mk("UIPadding", {
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 6),
        PaddingBottom = UDim.new(0, 6),
    }, filtersFrame)
    mk("UIListLayout", {
        Padding = UDim.new(0, 6),
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, filtersFrame)
    local function filterToggle(key, label, order)
        local toggle = mk("TextButton", {
            Size = UDim2.fromOffset(150, 26),
            TextSize = 13,
            AutoButtonColor = false,
            FontFace = Library.Fonts.Regular,
            LayoutOrder = order,
            Text = "",
        }, filtersFrame)
        decorate(toggle, "Surface3", 6)
        th(toggle, "TextColor3", "Text")
        local function paint()
            toggle.Text = (state[key] and "● " or "○ ") .. tr(label)
        end
        paint()
        toggle.MouseButton1Click:Connect(function()
            state[key] = not state[key]
            paint()
            render()
        end)
        onLanguageChanged(paint)
    end
    filterToggle("hideFull", "Ocultar cheios", 1)
    filterToggle("hideMine", "Ocultar meu servidor", 2)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        state.query = searchBox.Text
        render()
    end)
    sortButton.MouseButton1Click:Connect(function()
        state.sort = state.sort == "players" and "ping" or (state.sort == "ping" and "fps" or "players")
        render()
    end)
    directionButton.MouseButton1Click:Connect(function()
        state.desc = not state.desc
        render()
    end)
    onLanguageChanged(function()
        renderDetails()
        render()
    end)
    renderDetails()
    load()
end

-- ============================================================
--  Abas MUNDO / EXTRAS / CONTEÚDO
-- ============================================================
function Features.buildWorld(window)
    local world = window:Tab({ Name = "MUNDO", Icon = "globe" })

    local group = world:Groupbox({ Name = "MUNDO", Icon = "globe", Side = "Left" })
    group:Foldout({
        Name = "Cores do terreno",
        Build = function(panel)
            panel:ColorPicker({ Name = "Grama", Default = Color3.fromRGB(72, 160, 76), Callback = function() end })
            panel:ColorPicker({ Name = "Areia", Default = Color3.fromRGB(214, 190, 120), Callback = function() end })
            panel:ColorPicker({ Name = "Rocha", Default = Color3.fromRGB(120, 120, 126), Callback = function() end })
            panel:ColorPicker({ Name = "Terra", Default = Color3.fromRGB(110, 78, 52), Callback = function() end })
        end,
    })
    group:Foldout({
        Name = "Folhas",
        Build = function(panel)
            panel:ColorPicker({ Name = "Cor das folhas", Default = Color3.fromRGB(70, 150, 70), Callback = function() end })
        end,
    })
    group:Foldout({
        Name = "Troncos",
        Build = function(panel)
            panel:ColorPicker({ Name = "Cor dos troncos", Default = Color3.fromRGB(100, 70, 45), Callback = function() end })
        end,
    })
    group:ColorPicker({ Name = "Cor da água", Default = Color3.fromRGB(40, 70, 75), Callback = function() end })
    T(group, "Sem grama", true)
    T(group, "Desativar minas", true)

    group = world:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Left" })
    T(group, "Carregar jogadores")
    T(group, "Buscar chefes")
    T(group, "Pontos de saída", true)
    T(group, "Radar")

    group = world:Groupbox({
        Name = "ILUMINAÇÃO",
        Icon = "lightbulb",
        Side = "Right",
        Checkbox = true,
        Default = true,
        Callback = function() end,
    })
    for _, name in ipairs({
        "Luz", "Hora e sol", "Sombras", "Renderização", "Neblina", "Atmosfera", "Céu", "Nuvens",
        "Florescer", "Desfoque", "Ajuste de cor", "Profundidade", "Raios de sol", "Tonalidade",
    }) do
        T(group, name, name == "Luz" or name == "Hora e sol")
    end

    -- EXTRAS
    local extras = window:Tab({ Name = "EXTRAS", Icon = "layout-grid" })
    group = extras:Groupbox({ Name = "EXTRAS", Icon = "layout-grid", Side = "Left" })
    T(group, "Troca rápida")
    T(group, "Modo pânico")
    group:Button({
        Name = "Atravessar porta",
        Callback = function()
            notify("Atravessar porta")
        end,
    })
    T(group, "Remover efeitos")
    T(group, "Avisos de denúncias", true)
    T(group, "Avisos de entrada")

    group = extras:Groupbox({ Name = "SONS", Icon = "volume-2", Side = "Left" })
    group:Input({ Name = "Adicionar ID de som", Placeholder = "ID", Callback = function() end })
    for _, name in ipairs({
        "Jump", "Pegadas", "Pouso", "Capacete", "Tiro na cabeça", "Tiro no corpo",
        "Abate", "Disparo", "Acerto com sangue",
    }) do
        T(group, name, name == "Disparo")
    end

    group = extras:Groupbox({ Name = "DETECÇÃO", Icon = "radar", Side = "Right" })
    T(group, "Criador")
    T(group, "Testador")
    T(group, "Moderador", true)
    T(group, "Trapaceiro")

    group = extras:Groupbox({ Name = "ORDENAR DEPÓSITO", Icon = "arrow-down-up", Side = "Right" })
    group:Button({ Name = "Por valor", Callback = function() notify("Por valor") end })
    group:Button({ Name = "Por tipo", Callback = function() notify("Por tipo") end })
    group:Button({ Name = "Por nome", Callback = function() notify("Por nome") end })

    group = extras:Groupbox({ Name = "VER INVENTÁRIO", Icon = "backpack", Side = "Right" })
    group:Keybind({ Name = "Ver inventário", Default = "Backquote", Callback = function() end })
    group:Dropdown({
        Name = "Mostrar",
        Options = { "Jogadores", "NPCs", "Todos" },
        Default = "Jogadores",
        Callback = function() end,
    })
    T(group, "Sempre mostrar")

    -- Conteúdo
    local loot = window:Tab({ Name = "BUSCAR SAQUE", Icon = "package-search" })
    loot:Section("BUSCAR SAQUE")
    loot:Label({ Text = "Resultados da busca aparecerão aqui." })

    local servers = window:Tab({ Name = "SERVIDORES", Icon = "server" })
    Features.buildServers(servers)

    local skins = window:Tab({ Name = "SKINS", Icon = "palette" })
    skins:Section("SKINS")

    local quests = window:Tab({ Name = "MISSÕES", Icon = "scroll-text" })
    quests:Section("MISSÕES")

    local merchants = window:Tab({ Name = "COMERCIANTES", Icon = "shopping-cart" })
    merchants:Section("COMERCIANTES")

    return world
end

return Features
