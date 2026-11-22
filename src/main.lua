--[[
    BBC HUB - Entry point
    Bootstrap da aplicação: i18n, configuração, janela, overlays,
    features e aba de configurações.
]]

local Library = BBC.Library
local Utils = BBC.Utils
local Security = BBC.Security
local UI = BBC.UI
local Controls = UI.Controls
local T = Controls.T

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

Security.init()

-- ============================================================
--  IDIOMAS (English / Español / Português / 简体中文 / Русский)
-- ============================================================
local LANG_CODES = {
    ["English"] = "en",
    ["Español"] = "es",
    ["Português (Brasil)"] = "pt",
    ["简体中文"] = "zh",
    ["Русский"] = "ru",
}
local LANG_NAMES = {
    en = "English",
    es = "Español",
    pt = "Português (Brasil)",
    zh = "简体中文",
    ru = "Русский",
}
local DICT = {}
do
    local RAW = [==[
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
Tiro por paredes|Shoot through walls|Disparo a través de paredes|穿墙射击|Стрельба сквозь стены
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
Avisos de denúncias|Report alerts|Avisos de denuncias|举报提醒|Уведомления о жалобах
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
Proporção K/D|K/D ratio|Ratio K/D|K/D比|Соотношение K/D
Denúncias|Reports|Denuncias|举报|Жалобы
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
Em breve|Coming soon|Próximamente|即将推出|Скоро
Pressione a tecla do menu para abrir ou fechar.|Press the menu key to open or close.|Pulsa la tecla del menú para abrir o cerrar.|按菜单键打开或关闭。|Нажмите клавишу меню, чтобы открыть или закрыть.
Toque no botão flutuante para abrir o menu.|Tap the floating button to open the menu.|Toca el botón flotante para abrir el menú.|点击悬浮按钮打开菜单。|Нажмите на плавающую кнопку, чтобы открыть меню.
]==]
    for line in string.gmatch(RAW, "[^\n]+") do
        local parts = string.split(line, "|")
        if #parts >= 5 then
            DICT[parts[1]] = { en = parts[2], es = parts[3], zh = parts[4], ru = parts[5] }
        end
    end
end

local currentLang = "pt"
local notify = function(text)
    pcall(function()
        Library:Notify({ Title = "BBC HUB", Content = text, Duration = 2 })
    end)
end
local keys = { menu = "RightShift", cursor = "LeftAlt", zoom = "N" }
local LANG_FILE = "BBC_HUB/idioma.txt"
pcall(function()
    if type(isfile) == "function" and isfile(LANG_FILE) then
        local code = string.gsub(readfile(LANG_FILE), "%s", "")
        if LANG_NAMES[code] then
            currentLang = code
        end
    end
end)

local function tr(text)
    if currentLang == "pt" then
        return text
    end
    local entry = DICT[text]
    return entry and entry[currentLang] or text
end

local function trKey(text)
    text = string.gsub(text, "&apos;", "'")
    text = string.gsub(text, "&amp;", "&")
    return text
end

local function translateInstance(instance)
    if not (instance:IsA("TextLabel") or instance:IsA("TextButton")) then
        return
    end
    local current = instance.Text
    local original, last = instance:GetAttribute("pt"), instance:GetAttribute("tx")
    if original ~= nil and current ~= last then
        original = nil
    end
    if original == nil then
        local key = trKey(current)
        if DICT[key] then
            original = key
        else
            return
        end
    end
    local translated = tr(original)
    instance:SetAttribute("pt", original)
    instance:SetAttribute("tx", translated)
    if current ~= translated then
        instance.Text = translated
    end
end

local onLanguageChanged = {}
local function setLanguage(code, silent)
    if not LANG_NAMES[code] or code == currentLang then
        return
    end
    currentLang = code
    pcall(function()
        if type(writefile) == "function" then
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then
                makefolder("BBC_HUB")
            end
            writefile(LANG_FILE, code)
        end
    end)
    for _, callback in ipairs(onLanguageChanged) do
        pcall(callback)
    end
end

local Config = Security.getConfig()
Library.Access = Config.Access or "FREE"

BBC.State = {
    Config = Config,
    Keys = keys,
    IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
    refreshPanels = function() end,
    notify = notify,
}

BBC.I18n = {
    tr = tr,
    trKey = trKey,
    translateInstance = translateInstance,
    setLanguage = setLanguage,
    onChanged = onLanguageChanged,
    LANG_NAMES = LANG_NAMES,
    LANG_CODES = LANG_CODES,
    current = function()
        return currentLang
    end,
}
Library.Tr = tr

Utils.init()

local Window = Library:Window({
    Title = "BBC HUB",
    Subtitle = "v0.0.8.2",
    Size = UDim2.fromOffset(640, 388),
    Keybind = "RightShift",
    Theme = "Orange",
    Home = { Build = BBC.Features.buildProfile, Expiry = Config.Expiry },
})
local IS_MOBILE = BBC.State.IsMobile
pcall(function()
    Window:SetToggleButton(true)
end)

-- tradução automática de tudo que aparece na janela
do
    local gui = Window.Gui or Window.ScreenGui or Window.Root
    if gui then
        for _, descendant in ipairs(gui:GetDescendants()) do
            translateInstance(descendant)
        end
        gui.DescendantAdded:Connect(function(descendant)
            task.defer(translateInstance, descendant)
        end)
        table.insert(onLanguageChanged, function()
            for _, descendant in ipairs(gui:GetDescendants()) do
                translateInstance(descendant)
            end
        end)
    else
        warn("[BBC HUB] não achei a ScreenGui da janela para traduzir")
    end
end

-- Overlays (watermark / lista de atalhos)
local overlays = UI.Overlays.create()
BBC.State.refreshPanels = overlays.refresh
local WM, KL = overlays.WM, overlays.KL

-- Features
BBC.Features.buildVisuals(Window)
BBC.Features.buildPlayer(Window)
BBC.Features.buildCombat(Window)
BBC.Features.buildWorld(Window)

local FONT_URLS = {
    ["Press Start 2P"] = {
        Name = "PressStart2P",
        Weights = {
            Regular = "https://raw.githubusercontent.com/google/fonts/main/ofl/pressstart2p/PressStart2P-Regular.ttf",
        },
    },
    ["Silkscreen"] = {
        Name = "Silkscreen",
        Weights = {
            Regular = "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Regular.ttf",
            Bold = "https://raw.githubusercontent.com/google/fonts/main/ofl/silkscreen/Silkscreen-Bold.ttf",
        },
    },
}

local function retagFonts(root)
    for _, descendant in ipairs(root:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
            local bold = descendant:GetAttribute("bbcBold")
            if bold == nil then
                bold = descendant.FontFace.Weight.Value >= 600
                descendant:SetAttribute("bbcBold", bold)
            end
            descendant.FontFace = bold and Library.Fonts.Bold or Library.Fonts.Regular
        end
    end
end

local function setFont(name)
    if name == "Arimo" then
        Library.Fonts.Regular = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Regular)
        Library.Fonts.Medium = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Medium)
        Library.Fonts.Bold = Font.new("rbxasset://fonts/families/Arimo.json", Enum.FontWeight.Bold)
    elseif name == "Arcade" or name == "Code" then
        local font = Font.fromEnum(name == "Arcade" and Enum.Font.Arcade or Enum.Font.Code)
        Library.Fonts.Regular, Library.Fonts.Medium, Library.Fonts.Bold = font, font, font
    elseif FONT_URLS[name] then
        if not Library:LoadFont(FONT_URLS[name]) then
            notify("Fonte indisponível neste executor (precisa de writefile e getcustomasset).")
            return
        end
    else
        return
    end
    if Window.Gui then
        retagFonts(Window.Gui)
    end
    retagFonts(overlays.overlay)
end

-- ============================================================
--  CONFIGURAÇÕES
-- ============================================================
local settings = Window:Tab({ Name = "CONFIGURAÇÕES", Icon = "settings", Hidden = true, IsSettings = true })

local function bindCfg(cfg, key, value)
    cfg[key] = value
    overlays.refresh()
end

local function SB(group, name, min, max, default, suffix, step, cfg, key)
    return group:Slider({
        Name = name,
        Min = min,
        Max = max,
        Default = default,
        Suffix = suffix or "",
        Step = step or 1,
        Tooltip = Controls.TIPS[name],
        Callback = function(value)
            bindCfg(cfg, key, value)
        end,
    })
end

-- Geral
local group = settings:Groupbox({ Name = "GERAL", Icon = "settings", Side = "Left" })
group:Dropdown({
    Name = "Idioma",
    Options = { "English", "Español", "Português (Brasil)", "简体中文", "Русский" },
    Default = LANG_NAMES[currentLang],
    Flags = {
        ["English"] = "en",
        ["Español"] = "es",
        ["Português (Brasil)"] = "pt",
        ["简体中文"] = "zh",
        ["Русский"] = "ru",
    },
    Callback = function(value)
        local code = LANG_CODES[type(value) == "table" and value[1] or value] or "pt"
        setLanguage(code)
        notify(tr("Idioma alterado") .. ": " .. LANG_NAMES[code])
    end,
})
group:Keybind({
    Name = "Tecla do menu",
    Default = "RightShift",
    OnChanged = function(key)
        Window:SetKeybind(key)
        keys.menu = key.Name
        overlays.refresh()
    end,
    Callback = function() end,
})
group:Keybind({
    Name = "Tecla do cursor",
    Default = "LeftAlt",
    OnChanged = function(key)
        overlays.setCursorKey(key)
        keys.cursor = key.Name
        overlays.refresh()
    end,
    Callback = function() end,
})
group:Toggle({
    Name = "Cursor livre",
    Default = true,
    Callback = function(value)
        overlays.setCursorFree(value)
    end,
})
group:Toggle({
    Name = "Lista de atalhos",
    Default = false,
    Callback = function(value)
        bindCfg(KL, "On", value)
    end,
})
group:Toggle({
    Name = "Ilha de FPS",
    Default = true,
    Callback = function(value)
        Window:SetIsland(value)
    end,
})
T(group, "Ocultar indisponíveis")
group:Toggle({
    Name = "Fixar botão móvel",
    Default = false,
    Callback = function(value)
        pcall(function()
            Window:SetIslandDraggable(not value)
        end)
    end,
})
group:Button({
    Name = "Rever tutorial",
    Callback = function()
        notify(tr(IS_MOBILE and "Toque no botão flutuante para abrir o menu." or "Pressione a tecla do menu para abrir ou fechar."))
    end,
})
group:Button({
    Name = "Sair",
    Callback = function()
        overlays.destroy()
        Window:Destroy()
    end,
})

-- Aparência
local presetNames = Library.ThemeOrder
group = settings:Groupbox({ Name = "APARÊNCIA", Icon = "palette", Side = "Left" })
do
    local swatches = Instance.new("Frame")
    swatches.BackgroundTransparency = 1
    swatches.Size = UDim2.new(1, 0, 0, 0)
    swatches.AutomaticSize = Enum.AutomaticSize.Y
    swatches.LayoutOrder = group:_nextOrder()
    local swatchPadding = Instance.new("UIPadding", swatches)
    swatchPadding.PaddingTop = UDim.new(0, 8)
    swatchPadding.PaddingBottom = UDim.new(0, 8)
    swatchPadding.PaddingLeft = UDim.new(0, 12)
    swatchPadding.PaddingRight = UDim.new(0, 8)
    local swatchGrid = Instance.new("UIGridLayout", swatches)
    swatchGrid.CellSize = UDim2.fromOffset(24, 24)
    swatchGrid.CellPadding = UDim2.fromOffset(5, 6)
    swatchGrid.SortOrder = Enum.SortOrder.LayoutOrder
    swatches.Parent = group.List
    local rings = {}
    local function accentOf(name)
        local palette = Library.ThemePresets[name]
        local accent = palette and palette.Accent
        if typeof(accent) == "Color3" then
            return accent
        end
        if type(accent) == "string" then
            local ok, result = pcall(Color3.fromHex, accent)
            if ok then
                return result
            end
        end
        if type(accent) == "table" and #accent == 3 then
            return Color3.fromRGB(accent[1], accent[2], accent[3])
        end
        return Color3.fromRGB(200, 200, 200)
    end
    for index, name in ipairs(presetNames) do
        local accent = accentOf(name)
        local button = Instance.new("TextButton")
        button.Text = ""
        button.AutoButtonColor = false
        button.BackgroundColor3 = Color3.new(1, 1, 1)
        button.LayoutOrder = index
        button.BorderSizePixel = 0
        Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
        local gradient = Instance.new("UIGradient", button)
        gradient.Rotation = 55
        gradient.Color = ColorSequence.new(
            accent:Lerp(Color3.new(1, 1, 1), 0.35),
            accent:Lerp(Color3.new(0, 0, 0), 0.3)
        )
        local ring = Instance.new("UIStroke", button)
        ring.Thickness = 2.5
        ring.Color = Color3.new(1, 1, 1)
        ring.Transparency = (Library.ThemeName == name) and 0 or 1
        local tick = Instance.new("TextLabel", button)
        tick.BackgroundTransparency = 1
        tick.Size = UDim2.fromScale(1, 1)
        tick.Text = "✓"
        tick.TextSize = 13
        tick.TextColor3 = Color3.new(1, 1, 1)
        tick.FontFace = Library.Fonts.Bold
        tick.Visible = (Library.ThemeName == name)
        local pumpkin
        if name == "Halloween" then
            pumpkin = Instance.new("TextLabel", button)
            pumpkin.BackgroundTransparency = 1
            pumpkin.Size = UDim2.fromScale(1, 1)
            pumpkin.Text = "🎃"
            pumpkin.TextSize = 14
            pumpkin.Visible = not (Library.ThemeName == name)
        end
        rings[name] = { ring = ring, tick = tick, pumpkin = pumpkin }
        button.MouseButton1Click:Connect(function()
            Library:SetTheme(name)
            for themeName, themeRing in pairs(rings) do
                themeRing.ring.Transparency = (themeName == name) and 0 or 1
                themeRing.tick.Visible = (themeName == name)
                if themeRing.pumpkin then
                    themeRing.pumpkin.Visible = (themeName ~= name)
                end
            end
            overlays.setAccent(Library.Theme.Accent)
            notify(name)
        end)
        button.Parent = swatches
    end
end
group:Toggle({
    Name = "Cubo",
    Default = true,
    Callback = function(value)
        Window:SetLogo(value)
    end,
})
group:Dropdown({
    Name = "Fonte",
    Options = { "Arimo", "Arcade", "Code", "Press Start 2P", "Silkscreen" },
    Default = "Arimo",
    Callback = function(value)
        setFont(type(value) == "table" and value[1] or value)
    end,
})
group:Toggle({
    Name = "Bordas estáticas",
    Default = false,
    Callback = function(value)
        Window:SetBorderAccent(value)
    end,
})
local bgOn, bgValue = false, 25
group:Toggle({
    Name = "Fundo",
    Default = false,
    Callback = function(value)
        bgOn = value
        Window:SetBackgroundTransparency(value and bgValue / 100 or 0)
    end,
    Settings = function(panel)
        panel:Slider({
            Name = "Transparência",
            Min = 0,
            Max = 80,
            Default = 25,
            Suffix = "%",
            Callback = function(value)
                bgValue = value
                if bgOn then
                    Window:SetBackgroundTransparency(value / 100)
                end
            end,
        })
    end,
})
group:Toggle({
    Name = "Sombra",
    Default = false,
    Callback = function(value)
        Window:SetShadow(value)
    end,
})

-- Marca d'água
group = settings:Groupbox({
    Name = "MARCA D'ÁGUA",
    Icon = "scan",
    Side = "Right",
    Checkbox = true,
    Default = false,
    Callback = function(value)
        bindCfg(WM, "On", value)
    end,
})
group:Toggle({
    Name = "Fixar",
    Default = false,
    Callback = function(value)
        WM.Pin = value
    end,
})
group:Dropdown({
    Name = "Campos visíveis",
    Options = { "Nome", "FPS", "Ping", "Hora" },
    Default = { "Nome", "FPS", "Ping" },
    Multi = true,
    Callback = function(value)
        WM.Fields = value
    end,
})
SB(group, "Tamanho", 50, 200, 100, "%", 1, WM, "Size")
SB(group, "Largura", 150, 600, 285, "", 1, WM, "Width")
SB(group, "Altura máxima", 20, 500, 290, "", 1, WM, "MaxH")
SB(group, "Transp. fundo", 0, 1, 0.10, "", 0.01, WM, "BgT")
SB(group, "Transp. do texto", 0, 1, 0, "", 0.01, WM, "TxtT")
SB(group, "Transp. da borda", 0, 1, 0, "", 0.01, WM, "BrdT")
SB(group, "Raio dos cantos", 0, 20, 6, " px", 1, WM, "Radius")
group:Toggle({
    Name = "Sombra",
    Default = true,
    Callback = function(value)
        bindCfg(WM, "Shadow", value)
    end,
})

-- Lista de atalhos
group = settings:Groupbox({ Name = "LISTA DE ATALHOS", Icon = "keyboard", Side = "Right" })
local klPinToggle = group:Toggle({
    Name = "Fixar",
    Default = false,
    Callback = function(value)
        KL.Pin = value
        overlays.recolor()
    end,
})
overlays.setPinToggle(klPinToggle)
group:Toggle({
    Name = "Sombra",
    Default = true,
    Callback = function(value)
        bindCfg(KL, "Shadow", value)
    end,
})
SB(group, "Tamanho", 50, 200, 100, "%", 1, KL, "Size")
SB(group, "Largura", 200, 420, 250, "", 1, KL, "Width")
SB(group, "Altura máxima", 100, 500, 260, "", 1, KL, "MaxH")
SB(group, "Transp. fundo", 0, 1, 0.05, "", 0.01, KL, "BgT")
SB(group, "Transp. do texto", 0, 1, 0, "", 0.01, KL, "TxtT")
SB(group, "Transp. da borda", 0, 1, 0.75, "", 0.01, KL, "BrdT")
SB(group, "Raio dos cantos", 0, 20, 7, " px", 1, KL, "Radius")

overlays.refresh()
Library.Tr = tr
Library:Notify({ Title = "BBC HUB", Content = tr("Interface carregada."), Duration = 4 })
