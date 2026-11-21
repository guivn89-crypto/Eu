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
