--[[
    BBC HUB - Entry point
    Bootstrap da aplicação: i18n, configuração, janela, overlays,
    features e aba de configurações.
]]

-- Safe module access with fallbacks
local Library = BBC.Library or {}
local Utils = BBC.Utils or {}
local Security = BBC.Security or { init = function() end }
local UI = BBC.UI or { Controls = { T = function() end, S = function() end } }
local Controls = UI.Controls or { T = function() end, S = function() end }
local T = Controls.T
local S = Controls.S

-- Verify critical dependencies
if not Library or not Library.Windows then
    warn("[BBC] Library not loaded, some features may not work")
end
if not Utils.create then
    warn("[BBC] Utils not loaded, UI elements may not render")
end

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
PRÉ-VISUALIZAÇÃO|PREVIEW|VISTA PREVIA|预览|ПРЕДПРОСМОТР
CONFIGURAÇÕES DO JOGADOR|PLAYER SETTINGS|AJUSTES DEL JUGADOR|玩家设置|НАСТРОЙКИ ИГРОКА
CONFIGURAÇÕES DO NPC|NPC SETTINGS|AJUSTES DE NPC|NPC设置|НАСТРОЙКИ NPC
Destaque|Highlight|Resaltado|高亮|Подсветка
Caixa|Box|Caja|方框|Бокс
Barra de vida|Health Bar|Barra de vida|血条|Полоса здоровья
Vida|Health|Vida|生命值|Здоровье
Linhas|Tracers|Líneas|射线|Линии
Linhas até alvos|Lines to targets|Líneas a objetivos|目标连线|Линии до целей
SEGURANÇA|SECURITY|SEGURIDAD|安全|БЕЗОПАСНОСТЬ
Brilho|Brightness|Brillo|亮度|Яркость
Hora|Time|Hora|时间|Время
Zoom máximo|Max zoom|Zoom máximo|最大缩放|Макс. зум
Saturação|Saturation|Saturación|饱和度|Насыщенность
Contraste|Contrast|Contraste|对比度|Контраст
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
Fixar na tela|Pin to screen|Fijar en pantalla|固定到屏幕|Закрепить на экране
Desafixar|Unpin|Desfijar|取消固定|Открепить
Esqueleto|Skeleton|Esqueleto|骨骼|Скелет
Rastro ao ativar|Activation trail|Rastro al activar|激活拖尾|Шлейф при включении
Animação do menu|Menu animation|Animación del menú|菜单动画|Анимация меню
TOQUE: ALTERNAR · SEGURE: O QUE É|TAP: TOGGLE · HOLD: WHAT IT IS|TOQUE: ACTIVAR · MANTÉN: QUÉ ES|点击:切换 · 长按:说明|НАЖАТЬ: ВКЛ · УДЕРЖАТЬ: ОПИСАНИЕ
ATIVO|ON|ACTIVO|开启|ВКЛ
INATIVO|OFF|INACTIVO|关闭|ВЫКЛ
Toque para ativar ou desativar.|Tap to turn on or off.|Toca para activar o desactivar.|点击开启或关闭。|Нажмите, чтобы включить или выключить.
Setas|Arrows|Flechas|箭头|Стрелки
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
BBC.refreshPanels = function() end
BBC.onLanguageChanged = {}
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
local function trKey(text)
    text = string.gsub(text, "&apos;", "'")
    text = string.gsub(text, "&", "&")
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
local function setLanguage(code, silent)
    if not LANG_NAMES[code] or code == currentLang then return end
    currentLang = code
    pcall(function()
        if type(writefile) == "function" then
            if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("BBC_HUB") then makefolder("BBC_HUB") end
            writefile(LANG_FILE, code)
        end
    end)
    for _, fn in ipairs(BBC.onLanguageChanged) do pcall(fn) end
end

local Config = Security.getConfig()
Library.Access = Config.Access or "FREE"

-- GEARS (opções que têm submenu de ajustes)
local GEARS = {}
for _, n in ipairs({
    "Jogador","NPCs","Corpo","Recipiente","Item no chão","Itens de missão","Mochila personalizada","Mochila","Barra rápida",
    "Aura","Círculo de salto","Auréola","Rastro estelar",
    "Hack de velocidade","Sprint automático","Voar","Aranha","Deslocamento","Trocar personagem","Personagem",
    "Corpo em 1ª pessoa","Mãos","Item na mão","Terceira pessoa","Câmera livre","Saque automático","Painel do jogador",
    "Renascer automático","Remover água",
    "Pausa inteligente","Tiro por paredes","Aura letal","Espiada subterrânea","Anti aim","Sob o chão","Fantasma",
    "Trajetória do arremesso","Recarga automática","Abastecer cargadores","Mira falsa","Retícula","Círculo da mira",
    "Rastro personalizado","Marca de acerto","Números de dano","Efeitos de acerto","Efeitos de eliminação","Dados do alvo",
    "Luz","Hora e sol","Sombras","Renderização","Neblina","Atmosfera","Céu","Nuvens","Florescer","Desfoque",
    "Ajuste de cor","Profundidade","Raios de sol","Tonalidade","Buscar chefes","Pontos de saída","Radar",
    "Modo pânico","Avisos de entrada","Criador","Testador","Moderador","Trapaceiro","Jump","Pegadas","Pouso",
    "Capacete","Tiro na cabeça","Tiro no corpo","Abate","Disparo","Acerto com sangue","Fundo","Sombra","Destaque próprio",
}) do GEARS[n] = true end

local function buildSettings(name)
    local SPEC = {
        ["Hack de velocidade"] = { { "Velocidade", 16, 250, 40, "" } },
        ["Sprint automático"] = { { "Velocidade", 16, 120, 26, "" } },
        ["Voar"] = { { "Velocidade", 10, 250, 60, "" } },
        ["Aranha"] = { { "Velocidade", 10, 80, 30, "" } },
        ["Terceira pessoa"] = { { "Zoom máximo", 10, 500, 100, "" } },
        ["Luz"] = { { "Brilho", 0, 5, 2, "", 0.1 } },
        ["Hora e sol"] = { { "Hora", 0, 24, 14, "h", 0.5 } },
        ["Florescer"] = { { "Intensidade", 0, 3, 1, "", 0.1 } },
        ["Desfoque"] = { { "Tamanho", 0, 40, 8, "" } },
        ["Ajuste de cor"] = { { "Saturação", -1, 2, 0.4, "", 0.1 }, { "Contraste", -1, 1, 0.1, "", 0.1 } },
        ["Raios de sol"] = { { "Intensidade", 0, 1, 0.25, "", 0.05 } },
        ["Retícula"] = { { "Tamanho", 4, 40, 12, "px" }, { "Espessura", 1, 4, 2, "" } },
    }
    for _, n in ipairs({ "Sombras", "Neblina", "Atmosfera", "Nuvens" }) do GEARS[n] = nil end
    return function(p)
        local spec = SPEC[name]
        if spec then
            BBC.Library.FO[name] = BBC.Library.FO[name] or {}
            for _, sp in ipairs(spec) do
                p:Slider({ Name = sp[1], Min = sp[2], Max = sp[3], Default = sp[4], Suffix = sp[5] or "", Step = sp[6] or 1,
                    Callback = function(v) BBC.Library.FO[name][sp[1]] = v end })
            end
            return
        end
        p:Dropdown({ Name = "Modo", Options = { "Sempre", "Ao segurar", "Alternar" }, Default = "Alternar", Callback = function(v) end })
        p:Slider({ Name = "Intensidade", Min = 0, Max = 100, Default = 50, Suffix = "%", Callback = function(v) end })
        p:Slider({ Name = "Distância", Min = 10, Max = 1000, Default = 300, Suffix = "m", Callback = function(v) end })
        p:Toggle({ Name = "Notificar", Default = false, Callback = function(v) end })
    end
end

BBC.GEARS = GEARS
BBC.buildSettings = buildSettings
BBC.PREMIUM = { ["Anti aim"] = true, ["Sob o chão"] = true, ["Espiada subterrânea"] = true, ["Saque automático"] = true, ["Sem dano de queda"] = true }
BBC.SETTINGS_ICON = { ["Notificar"] = "message-circle", ["Avisos de denúncias"] = "message-circle" }
GEARS["Notificar"] = true; GEARS["Avisos de denúncias"] = true
BBC.TIPS = {
    ["Transp. fundo"] = "Ajusta a transparência do fundo.", ["Transp. do texto"] = "Ajusta a transparência do texto.",
    ["Transp. da borda"] = "Ajusta a transparência da borda.", ["Raio dos cantos"] = "Arredonda os cantos do painel.",
    ["Largura"] = "Define a largura do painel.", ["Altura máxima"] = "Define a altura máxima do painel.",
    ["Tamanho"] = "Muda o tamanho do painel.", ["Suavização"] = "Quanto maior, mais suave o movimento.",
    ["Raio da mira"] = "Alcance do círculo da mira.", ["Cursor livre"] = "Segure a tecla do cursor para liberar o mouse.",
    ["Limite de verificações"] = "Quantas checagens por quadro.", ["Fixar"] = "Impede que o painel seja arrastado.",
}
BBC.MODALS = {}

-- ---------- Janela Principal ----------
local Window = Library:Window({
    Title = "BBC HUB",
    Subtitle = "v0.0.8.2",
    Size = UDim2.fromOffset(640, 388),
    Keybind = "RightShift",
    Theme = "Orange",
    Home = { Build = BBC.Features.buildProfile, Expiry = Config.Expiry },
})
local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
pcall(function() Window:SetToggleButton(true) end)

-- Tradução automática
do
    local gui = Window.Gui
    if gui then
        for _, d in ipairs(gui:GetDescendants()) do translateInstance(d) end
        gui.DescendantAdded:Connect(function(d) task.defer(translateInstance, d) end)
        table.insert(BBC.onLanguageChanged, function()
            for _, d in ipairs(gui:GetDescendants()) do translateInstance(d) end
        end)
    else
        warn("[BBC HUB] não achei a ScreenGui da janela para traduzir")
    end
end

-- ---------- Features ----------
BBC.Features.buildVisuals(Window)

-- Register ESP preview modals (after visuals builds the buildEspPanel)
BBC.MODALS["Jogador"] = { build = BBC.Features.buildEspPanel("Jogador"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO JOGADOR" } }
BBC.MODALS["NPCs"] = { build = BBC.Features.buildEspPanel("NPCs"), titles = { Left = "PRÉ-VISUALIZAÇÃO", Right = "CONFIGURAÇÕES DO NPC" } }

BBC.Features.buildPlayer(Window)
BBC.Features.buildCombat(Window)
BBC.Features.buildWorld(Window)

-- Abas extras
local saque = BBC.Features.buildLootTab(Window)
local servidores = Window:Tab({ Name = "SERVIDORES", Icon = "server" })
BBC.Features.buildServers(servidores)
local skins = BBC.Features.buildSkinsTab(Window)
local missoes = BBC.Features.buildQuestsTab(Window)
local comerciantes = BBC.Features.buildMerchantsTab(Window)

-- ---------- Overlays (Watermark + Keybind List) ----------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local overlayParent = (type(gethui) == "function" and gethui()) or LocalPlayer:WaitForChild("PlayerGui")
local overlay = Instance.new("ScreenGui")
overlay.Name = "BBCOverlay"; overlay.ResetOnSpawn = false; overlay.IgnoreGuiInset = true; overlay.DisplayOrder = 998
overlay.Parent = overlayParent

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
klPin.MouseButton1Click:Connect(function()
    KL.Pin = not KL.Pin
    paintPin()
    if klPinToggle then klPinToggle:Set(KL.Pin, true) end
end)
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
        edit.MouseButton1Click:Connect(function() if kb.begin then kb.begin() end end)
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
BBC.refreshPanels = function()
    applyPanel(WM, wmFrame, wmCorner, wmStroke, wmText, 28)
    klFrame.Visible = KL.On
    klScale.Scale = KL.Size / 100
    klFrame.BackgroundTransparency = KL.BgT
    klStroke.Transparency = KL.BrdT
    klCorner.CornerRadius = UDim.new(0, KL.Radius)
    renderKL()
end
table.insert(BBC.onLanguageChanged, BBC.refreshPanels)

local function makeDraggable(handle, cfg, target)
    local frame = target or handle
    handle.Active = true
    local dragging, startPos, startInput
    handle.InputBegan:Connect(function(i)
        if cfg.Pin then return end
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end
makeDraggable(wmFrame, WM)
makeDraggable(klHead, KL, klFrame)

local cursorFree, cursorHeld, cursorKey = true, false, Enum.KeyCode.LeftAlt
UserInputService.InputBegan:Connect(function(i) if cursorFree and i.KeyCode == cursorKey then cursorHeld = true end end)
UserInputService.InputEnded:Connect(function(i) if i.KeyCode == cursorKey then cursorHeld = false end end)
RunService.RenderStepped:Connect(function()
    if cursorHeld then
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end
end)
local frames, last = 0, os.clock()
local fps = 60
RunService.Heartbeat:Connect(function()
    frames += 1
    if os.clock() - last >= 1 then fps = frames; frames = 0; last = os.clock() end
    local parts = { "<b>BBC HUB</b>" }
    for _, f in ipairs(WM.Fields) do
        if f == "Nome" then table.insert(parts, LocalPlayer.Name)
        elseif f == "FPS" then table.insert(parts, fps .. " FPS")
        elseif f == "Ping" then
            local ok, ping = pcall(function() return math.floor(LocalPlayer:GetNetworkPing() * 2000) end)
            table.insert(parts, (ok and ping or 0) .. " ms")
        elseif f == "Hora" then table.insert(parts, os.date("%H:%M")) end
    end
    wmText.Text = table.concat(parts, "  |  ")
end)
BBC.refreshPanels()

local function bind(cfg, key, v) cfg[key] = v; BBC.refreshPanels() end
local function SB(grp, name, min, max, def, suffix, step, cfg, key)
    return grp:Slider({ Name = name, Min = min, Max = max, Default = def, Suffix = suffix or "", Step = step or 1, Tooltip = BBC.TIPS[name],
        Callback = function(v) bind(cfg, key, v) end })
end

-- ---------- Fontes ----------
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
            BBC.notify("Fonte indisponível neste executor (precisa de writefile e getcustomasset).")
            return
        end
    else
        return
    end
    if Window.Gui then retagFonts(Window.Gui) end
    retagFonts(overlay)
end

-- ---------- Aba CONFIGURAÇÕES ----------
local cfg = Window:Tab({ Name = "CONFIGURAÇÕES", Icon = "settings", Hidden = true, IsSettings = true })

-- Segurança: modo pânico + status de proteção
do
    local Protection = BBC.Protection
    local P = cfg:Groupbox({ Name = "SEGURANÇA", Icon = "shield", Side = "Left" })
    Library._panicToggle = P:Toggle({ Name = "Modo pânico", Default = false, NoPersist = true,
        Tooltip = "Esconde menu, ESP, radar e botões fixos de uma vez. Para voltar, toque 3 vezes no topo da tela (ou use a tecla de pânico).",
        Callback = function(v) Window:SetPanic(v) end })
    P:Keybind({ Name = "Tecla de pânico", Default = "End", Callback = function() Window:SetPanic(not Library.Panic) end })

    -- Protection Status Display
    local protInfo = P:Label({ Text = "Executor: Detectando..." })
    local protLevel = P:Label({ Text = "Nível: --" })
    local protCaps = P:Label({ Text = "APIs: --" })

    task.spawn(function()
        task.wait(1) -- wait for Protection.init()
        local prot = BBC.Protection
        if prot then
            protInfo.Set("Executor: " .. (prot.Executor or "Unknown"))
            local level, desc = prot.getProtectionLevel()
            protLevel.Set("Nível: " .. level .. " - " .. desc)
            local caps = prot.Capabilities or {}
            local count = 0
            for _, v in pairs(caps) do if v then count = count + 1 end end
            protCaps.Set("APIs disponíveis: " .. count .. "/" .. (function() local c=0 for _ in pairs(caps) do c=c+1 end return c end)())
        end
    end)
end

-- Geral
local g = cfg:Groupbox({ Name = "GERAL", Icon = "settings", Side = "Left" })
g:Dropdown({ Name = "Idioma", Options = { "English", "Español", "Português (Brasil)", "简体中文", "Русский" }, Default = LANG_NAMES[currentLang],
    Flags = { ["English"] = "en", ["Español"] = "es", ["Português (Brasil)"] = "pt", ["简体中文"] = "zh", ["Русский"] = "ru" },
    Callback = function(v)
        local code = LANG_CODES[type(v) == "table" and v[1] or v] or "pt"
        setLanguage(code)
        BBC.notify(tr("Idioma alterado") .. ": " .. LANG_NAMES[code])
    end })
g:Keybind({ Name = "Tecla do menu", Default = "RightShift", OnChanged = function(k) Window:SetKeybind(k); keys.menu = k.Name; BBC.refreshPanels() end, Callback = function() end })
g:Keybind({ Name = "Tecla do cursor", Default = "LeftAlt", OnChanged = function(k) cursorKey = k; keys.cursor = k.Name; BBC.refreshPanels() end, Callback = function() end })
g:Toggle({ Name = "Cursor livre", Default = true, Callback = function(v) cursorFree = v end })
g:Toggle({ Name = "Lista de atalhos", Default = false, Callback = function(v) bind(KL, "On", v) end })
g:Toggle({ Name = "Ilha de FPS", Default = true, Callback = function(v) Window:SetIsland(v) end })
T(g, "Ocultar indisponíveis")
g:Toggle({ Name = "Fixar botão móvel", Default = false, Callback = function(v) pcall(function() Window:SetIslandDraggable(not v) end) end })
g:Button({ Name = "Rever tutorial", Callback = function() BBC.notify(tr(IS_MOBILE and "Toque no botão flutuante para abrir o menu." or "Pressione a tecla do menu para abrir ou fechar.")) end })
g:Button({ Name = "Sair", Callback = function() overlay:Destroy(); Window:Destroy() end })

-- Aparência
local presetNames = Library.ThemeOrder
g = cfg:Groupbox({ Name = "APARÊNCIA", Icon = "palette", Side = "Left" })
do
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
        b.MouseButton1Click:Connect(function()
            Library:SetTheme(name)
            for n, r in pairs(rings) do r.ring.Transparency = (n == name) and 0 or 1; r.tick.Visible = (n == name); if r.pumpkin then r.pumpkin.Visible = (n ~= name) end end
            wmStroke.Color = Library.Theme.Accent; recolorKL()
            BBC.notify(name)
        end)
        b.Parent = swatches
    end
end
g:Toggle({ Name = "Cubo", Default = true, Callback = function(v) Window:SetLogo(v) end })
g:Toggle({ Name = "Rastro ao ativar", Default = true, Tooltip = "Mostra um rastro de luz na cor do menu quando você ativa uma opção.", Callback = function(v) Library.Effects = v end })
g:Toggle({ Name = "Animação do menu", Default = true, Tooltip = "Abre e fecha o menu com um efeito suave.", Callback = function(v) Library.MenuAnim = v end })
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

BBC.refreshPanels()

-- Expor funções globais para compatibilidade
Library.Tr = tr
Library._toggleBinds = Library._toggleBinds or {}
Library.Keybinds = Library.Keybinds or {}
Library.Features = Library.Features or {}
Library.FS = Library.FS or {}
Library.SV = Library.SV or {}
Library.FO = Library.FO or {}
Library.ESP = Library.ESP or {}
Library.LootCfg = Library.LootCfg or {}
Library.RadarCfg = Library.RadarCfg or {}

pcall(function() Window:FinishLoading() end)
Library:Notify({ Title = "BBC HUB", Content = tr("Interface carregada."), Duration = 4 })

-- return BBC  -- handled by build.py FOOTER