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
Bloqueado pelo modo preventivo.|Blocked by preventive mode.|Bloqueado por el modo preventivo.|已被预防模式阻止。|Заблокировано превентивным режимом.
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
O bloqueio preventivo continua ativo ao iniciar.|The preventive block remains active at startup.|El bloqueo preventivo sigue activo al iniciar.|启动时预防性阻止仍然有效。|Предупредительная блокировка остаётся активной при запуске.
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
Bloqueio preventivo|Preventive block|Bloqueo preventivo|预防性拦截|Превентивная блокировка
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
    ["Bloqueia uma lista de opções de maior risco, sem detectar o anticheat do jogo. Não garante segurança."] = {
        en = "Blocks a list of higher-risk options without detecting the game's anti-cheat. It does not guarantee safety.",
        es = "Bloquea una lista de opciones de mayor riesgo sin detectar el antitrampas del juego. No garantiza seguridad.",
        zh = "阻止一系列风险较高的选项，但不会检测游戏的反作弊系统，也无法保证安全。",
        ru = "Блокирует список опций повышенного риска, не обнаруживая античит игры. Безопасность не гарантируется." },
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
