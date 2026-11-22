--[[
    BBC HUB - Feature: Player
    Aba JOGADOR + painel de perfil (dados reais da conta, sessão e jogo).
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
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local StatsService = game:GetService("Stats")
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
--  Aba JOGADOR
-- ============================================================
function Features.buildPlayer(window)
    local player = window:Tab({ Name = "JOGADOR", Icon = "user" })

    local group = player:Groupbox({ Name = "MOVIMENTO", Icon = "move", Side = "Left" })
    T(group, "Hack de velocidade")
    T(group, "Sprint automático", true)
    T(group, "Pulos seguidos")
    T(group, "Controle no ar")
    T(group, "Voar")
    T(group, "Sem dano de queda")
    T(group, "Sempre no chão")
    T(group, "Jesus")
    T(group, "Aranha")

    group = player:Groupbox({ Name = "CÂMERA", Icon = "camera", Side = "Left" })
    T(group, "Terceira pessoa")
    T(group, "Câmera livre")

    group = player:Groupbox({ Name = "SAQUE", Icon = "package", Side = "Left" })
    T(group, "Saque automático")

    group = player:Groupbox({ Name = "MÃOS E ARMA", Icon = "hand", Side = "Right" })
    for _, name in ipairs({ "Deslocamento", "Trocar personagem", "Personagem", "Corpo em 1ª pessoa", "Mãos", "Item na mão" }) do
        T(group, name)
    end

    group = player:Groupbox({ Name = "CAMPO DE VISÃO", Icon = "focus", Side = "Right" })
    S(group, "Campo de visão", 30, 120, 120)
    S(group, "Visão com zoom", 5, 120, 5)
    group:Keybind({
        Name = "Zoom",
        Default = "N",
        OnChanged = function(key)
            BBC.State.Keys.zoom = key.Name
            BBC.State.refreshPanels()
        end,
        Callback = function() end,
    })

    group = player:Groupbox({ Name = "ANIMAÇÕES", Icon = "activity", Side = "Right" })
    group:Dropdown({
        Name = "Animação",
        Options = { "Swish", "Padrão" },
        Default = "Swish",
        Callback = function() end,
    })
    T(group, "Repetir")
    S(group, "Velocidade", 0.1, 3, 1, "x", 0.1)
    S(group, "Peso", 0, 100, 100, "%")
    group:Button({
        Name = "Reproduzir",
        Callback = function()
            notify("Reproduzir")
        end,
    })

    group = player:Groupbox({ Name = "RECURSOS", Icon = "puzzle", Side = "Right" })
    T(group, "Painel do jogador")
    T(group, "Anti AFK")
    T(group, "Renascer automático")
    T(group, "Remover água")
    T(group, "Não se afogar")
    T(group, "Mapa e navegação", true)

    return player
end

-- ============================================================
--  Painel de perfil (Home)
-- ============================================================
function Features.buildProfile(win, page, list)
    local config = BBC.State.Config or {}
    local version = config.Version or "0.0.8.2"
    local access = config.Access or "FREE"

    -- ---------- Persistência ----------
    local folder = "BBC_HUB"
    local file = folder .. "/perfil_" .. LocalPlayer.UserId .. ".json"
    local data = { kills = 0, deaths = 0, damage = 0, played = 0, runs = 0 }
    local canFS = Security.canFS()
    if canFS then
        Security.ensureFolder(folder)
        local saved = Security.readJSON(file)
        if type(saved) == "table" then
            for key, value in pairs(saved) do
                data[key] = value
            end
        end
    end
    data.runs = (tonumber(data.runs) or 0) + 1
    local function save()
        if canFS then
            Security.writeJSON(file, data)
        end
    end
    save()

    -- ---------- Rastreamento real ----------
    local function hookCharacter(character)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if not humanoid then
            return
        end
        local lastHealth = humanoid.Health
        humanoid.HealthChanged:Connect(function(health)
            if health < lastHealth then
                data.damage += lastHealth - health
            end
            lastHealth = health
        end)
        humanoid.Died:Connect(function()
            data.deaths += 1
        end)
    end
    if LocalPlayer.Character then
        task.spawn(hookCharacter, LocalPlayer.Character)
    end
    LocalPlayer.CharacterAdded:Connect(hookCharacter)

    local function hookVictim(player)
        if player == LocalPlayer then
            return
        end
        local function onCharacter(character)
            local humanoid = character:WaitForChild("Humanoid", 10)
            if not humanoid then
                return
            end
            humanoid.Died:Connect(function()
                local tag = humanoid:FindFirstChild("creator")
                if tag and tag.Value == LocalPlayer then
                    data.kills += 1
                end
            end)
        end
        if player.Character then
            task.spawn(onCharacter, player.Character)
        end
        player.CharacterAdded:Connect(onCharacter)
    end
    for _, player in ipairs(Players:GetPlayers()) do
        hookVictim(player)
    end
    Players.PlayerAdded:Connect(hookVictim)

    local function leaderStat(patterns)
        local leaderstats = LocalPlayer:FindFirstChild("leaderstats")
        if not leaderstats then
            return nil
        end
        for _, value in ipairs(leaderstats:GetChildren()) do
            if value:IsA("ValueBase") then
                local name = string.lower(value.Name)
                for _, pattern in ipairs(patterns) do
                    if string.find(name, pattern, 1, true) then
                        return tonumber(value.Value)
                    end
                end
            end
        end
        return nil
    end

    -- ---------- Leituras ----------
    local function fmtDuration(seconds, withSeconds)
        seconds = math.max(math.floor(seconds), 0)
        local days = math.floor(seconds / 86400)
        local hours = math.floor(seconds % 86400 / 3600)
        local minutes = math.floor(seconds % 3600 / 60)
        local secs = seconds % 60
        if days > 0 then
            return days .. "d " .. hours .. "h"
        end
        if hours > 0 then
            return hours .. "h " .. minutes .. "m"
        end
        if withSeconds then
            return minutes .. "m " .. secs .. "s"
        end
        return minutes .. "m"
    end
    local function fmtBig(number)
        number = tonumber(number) or 0
        if number >= 1e6 then
            return string.format("%.1fM", number / 1e6)
        end
        if number >= 1e3 then
            return string.format("%.1fK", number / 1e3)
        end
        return tostring(math.floor(number))
    end
    local function getPing()
        local ok, value = pcall(function()
            return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        if ok and value then
            return math.floor(value)
        end
        local ok2, ping = pcall(function()
            return LocalPlayer:GetNetworkPing() * 2000
        end)
        return ok2 and math.floor(ping) or 0
    end
    local function getDevice()
        local keyboard = UserInputService.KeyboardEnabled
        if UserInputService.TouchEnabled and not keyboard then
            return tr("Celular")
        end
        if UserInputService.GamepadEnabled and not keyboard then
            return tr("Console")
        end
        return "PC"
    end
    local frames, fps = 0, 0
    RunService.RenderStepped:Connect(function()
        frames += 1
    end)

    -- ---------- UI ----------
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
        mk("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, frame)
        th(mk("UIStroke", {}, frame), "Color", "Stroke")
    end
    local function box(parent, title, order, size)
        local frame = mk("Frame", {
            Size = size or UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = order,
        }, parent)
        decorate(frame, "Surface2", 8)
        mk("UIPadding", {
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            PaddingTop = UDim.new(0, 8),
            PaddingBottom = UDim.new(0, 10),
        }, frame)
        mk("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, frame)
        txt(frame, string.upper(title), 12, "Muted", false, { LayoutOrder = 0 })
        return frame
    end
    local function grid(parent, columns, order)
        local frame = mk("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = order,
        }, parent)
        mk("UIGridLayout", {
            CellPadding = UDim2.fromOffset(6, 6),
            CellSize = UDim2.new(1 / columns, -(6 * (columns - 1) / columns), 0, 46),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, frame)
        return frame
    end
    local function cell(parent, title, order, big)
        local frame = mk("Frame", { LayoutOrder = order }, parent)
        decorate(frame, "Background", 6)
        txt(frame, title, 12, "Muted", false, { Position = UDim2.fromOffset(8, 3), Size = UDim2.new(1, -16, 0, 15) })
        local value = txt(frame, "…", big or 16, "Text", true, {
            Position = UDim2.fromOffset(8, 20),
            Size = UDim2.new(1, -16, 0, 22),
        })
        return value, frame
    end
    local function spark(parent)
        local width, height, count = 56, 22, 20
        local holder = mk("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -8, 0, 4),
            Size = UDim2.fromOffset(width, height),
            ClipsDescendants = true,
        }, parent)
        local segments, samples = {}, {}
        for index = 1, count - 1 do
            local segment = mk("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(0, 2),
                Visible = false,
            }, holder)
            th(segment, "BackgroundColor3", "Accent")
            segments[index] = segment
        end
        return function(value)
            table.insert(samples, value)
            if #samples > count then
                table.remove(samples, 1)
            end
            local low, high = math.huge, -math.huge
            for _, sample in ipairs(samples) do
                low = math.min(low, sample)
                high = math.max(high, sample)
            end
            if high - low < 1 then
                high = low + 1
            end
            local offset, step, points = count - #samples, width / (count - 1), {}
            for index, sample in ipairs(samples) do
                points[index] = Vector2.new(
                    (offset + index - 1) * step,
                    height - 2 - ((sample - low) / (high - low)) * (height - 4)
                )
            end
            for index = 1, count - 1 do
                local a, b = points[index - offset], points[index - offset + 1]
                local segment = segments[index]
                if a and b then
                    local delta = b - a
                    segment.Visible = true
                    segment.Size = UDim2.fromOffset(delta.Magnitude + 1, 2)
                    segment.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
                    segment.Rotation = math.deg(math.atan2(delta.Y, delta.X))
                else
                    segment.Visible = false
                end
            end
        end
    end

    local root = mk("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
    }, list)
    mk("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, root)

    -- Identidade
    local identity = mk("Frame", { Size = UDim2.new(1, 0, 0, 78), LayoutOrder = 1 }, root)
    decorate(identity, "Surface2", 8)
    local avatar = mk("ImageLabel", {
        Position = UDim2.fromOffset(10, 9),
        Size = UDim2.fromOffset(60, 60),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ScaleType = Enum.ScaleType.Crop,
    }, identity)
    th(avatar, "BackgroundColor3", "Surface3")
    mk("UICorner", { CornerRadius = UDim.new(0, 6) }, avatar)
    local thumbnail
    task.spawn(function()
        local ok, image = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size150x150
            )
        end)
        if ok then
            thumbnail = image
            avatar.Image = image
        end
    end)
    local nameLabel = txt(identity, LocalPlayer.DisplayName, 20, "Text", true, {
        Position = UDim2.fromOffset(82, 12),
        Size = UDim2.new(1, -230, 0, 26),
    })
    local userLabel = txt(identity, "@" .. LocalPlayer.Name, 15, "Muted", false, {
        Position = UDim2.fromOffset(82, 42),
        Size = UDim2.new(1, -230, 0, 20),
    })
    local badge = mk("TextLabel", {
        AnchorPoint = Vector2.new(0, 0),
        Position = UDim2.fromOffset(0, 16),
        Size = UDim2.fromOffset(46, 20),
        BackgroundTransparency = 0.6,
        Text = access,
        TextSize = 12,
        FontFace = Library.Fonts.Bold,
    }, identity)
    decorate(badge, "Surface3", 4)
    th(badge, "TextColor3", "Text")
    local function placeBadge()
        badge.Position = UDim2.fromOffset(82 + nameLabel.TextBounds.X + 8, 15)
    end
    nameLabel:GetPropertyChangedSignal("TextBounds"):Connect(placeBadge)
    placeBadge()
    local hidden = false
    local hideButton = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(44, 44),
        Text = "OCULTAR",
        TextSize = 9,
        AutoButtonColor = false,
        FontFace = Library.Fonts.Bold,
    }, identity)
    decorate(hideButton, "Background", 6)
    th(hideButton, "TextColor3", "Text")
    hideButton.MouseButton1Click:Connect(function()
        hidden = not hidden
        pcall(function()
            win:SetHideName(hidden)
            win:SetHideAvatar(hidden)
        end)
        nameLabel.Text = hidden and "••••••" or LocalPlayer.DisplayName
        userLabel.Text = hidden and "@••••••" or ("@" .. LocalPlayer.Name)
        avatar.Image = hidden and "" or (thumbnail or "")
        th(hideButton, "TextColor3", hidden and "Accent" or "Text")
    end)

    -- Estatísticas
    local stats = box(root, "Estatísticas", 2)
    local statsGrid = grid(stats, 6, 1)
    local vKills = cell(statsGrid, "Abates", 1, 15)
    local vDeaths = cell(statsGrid, "Mortes", 2, 15)
    local vKD = cell(statsGrid, "Proporção K/D", 3, 15)
    local vReports = cell(statsGrid, "Denúncias", 4, 15)
    local vPlayed = cell(statsGrid, "Tempo jogado", 5, 15)
    local vDamage = cell(statsGrid, "Dano recebido", 6, 15)
    th(vKD, "TextColor3", "Accent")

    -- Sessão e Conta lado a lado
    local row = mk("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 3,
    }, root)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, row)
    local sessionBox = box(row, "Sessão", 1, UDim2.new(0.5, -5, 0, 0))
    local accountBox = box(row, "Conta", 2, UDim2.new(0.5, -5, 0, 0))
    local sessionGrid, accountGrid = grid(sessionBox, 2, 1), grid(accountBox, 2, 1)
    local vFps, fpsCell = cell(sessionGrid, "FPS", 1)
    local vPing, pingCell = cell(sessionGrid, "Ping", 2)
    local vSession = cell(sessionGrid, "Tempo da sessão", 3)
    local vPlayers = cell(sessionGrid, "Jogadores", 4)
    local vDevice = cell(sessionGrid, "Dispositivo", 5)
    local vResolution = cell(sessionGrid, "Resolução", 6)
    local pushFps, pushPing = spark(fpsCell), spark(pingCell)
    local vAge = cell(accountGrid, "Idade da conta", 1)
    local vUserId = cell(accountGrid, "ID do usuário", 2)
    local vRuns = cell(accountGrid, "Execuções", 3)
    local vAccess = cell(accountGrid, "Acesso", 4)
    local vLeft = cell(accountGrid, "Tempo restante", 5)
    local vVersion = cell(accountGrid, "Versão do script", 6)

    -- Servidores
    local serversBox = box(root, "Servidores", 4)
    local serversGrid = grid(serversBox, 3, 1)
    local vMap = cell(serversGrid, "ID do mapa", 1)
    local vMapVersion = cell(serversGrid, "Versão do mapa", 2)
    local vJob = cell(serversGrid, "ID do servidor", 3, 14)

    -- Valores estáticos (reais)
    vUserId.Text = tostring(LocalPlayer.UserId)
    vAge.Text = LocalPlayer.AccountAge .. " " .. tr("dias")
    vAccess.Text = access
    vVersion.Text = version
    vDevice.Text = getDevice()
    onLanguageChanged(function()
        vDevice.Text = getDevice()
        vAge.Text = LocalPlayer.AccountAge .. " " .. tr("dias")
    end)
    vMap.Text = tostring(game.PlaceId)
    vMapVersion.Text = tostring(game.PlaceVersion)
    vJob.Text = (game.JobId ~= "" and game.JobId) or tr("Servidor local")
    vRuns.Text = tostring(data.runs)
    vReports.Text = "—"

    local started, lastSave, lastTick = os.clock(), os.clock(), os.clock()
    local function refresh()
        local now = os.clock()
        data.played += now - lastTick
        lastTick = now
        fps = frames
        frames = 0
        local ping = getPing()
        vFps.Text = tostring(fps)
        pushFps(fps)
        vPing.Text = ping .. " ms"
        pushPing(ping)
        vFps.TextColor3 = fps >= 50 and Library.Theme.Text or (fps >= 30 and Library.Theme.Warning or Library.Theme.Error)
        vPing.TextColor3 = ping <= 90 and Library.Theme.Text or (ping <= 180 and Library.Theme.Warning or Library.Theme.Error)
        vSession.Text = fmtDuration(now - started, true)
        vPlayers.Text = #Players:GetPlayers() .. " / " .. Players.MaxPlayers
        local camera = workspace.CurrentCamera
        if camera then
            vResolution.Text = math.floor(camera.ViewportSize.X) .. " x " .. math.floor(camera.ViewportSize.Y)
        end
        local kills = leaderStat({ "kill", "abate", "elimin" }) or data.kills
        local deaths = leaderStat({ "death", "morte", "died" }) or data.deaths
        vKills.Text = tostring(kills)
        vDeaths.Text = tostring(deaths)
        vKD.Text = string.format("%.2f", kills / math.max(deaths, 1))
        vPlayed.Text = fmtDuration(data.played)
        vDamage.Text = fmtBig(data.damage)
        local expiry = config.Expiry
        if type(expiry) == "function" then
            local ok, result = pcall(expiry)
            expiry = ok and result or nil
        end
        if type(expiry) == "number" then
            local left = expiry - os.time()
            vLeft.Text = left > 0 and fmtDuration(left) or tr("Expirado")
        else
            vLeft.Text = tr("Ilimitado")
        end
        if now - lastSave >= 30 then
            lastSave = now
            save()
        end
    end
    refresh()
    task.spawn(function()
        while list.Parent do
            task.wait(1)
            pcall(refresh)
        end
    end)
    Players.PlayerRemoving:Connect(function(player)
        if player == LocalPlayer then
            save()
        end
    end)

    return root
end

return Features
