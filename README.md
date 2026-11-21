# BBC HUB

Interface (hub) para Roblox em **Luau**. O código-fonte fica separado em
módulos (`src/`) e é montado em um único arquivo (`BBC_HUB.luau`), que é o que
se cola no executor. Monta um menu completo com abas, temas, perfis de
configuração, ESP, radar e busca de saque. As descrições de todas as opções
aparecem ao **segurar** (toque) ou passar o mouse por cima.

## Estrutura dos arquivos

| Arquivo | Conteúdo |
| --- | --- |
| `src/00_head.luau` | Biblioteca base: fontes, tema, utilidades, Registry, atalhos |
| `src/05_ui_support.luau` | Normalização limitada de busca, contraste e layout compacto |
| `src/23_appearance.luau` | Preferências visuais iniciais e temas |
| `src/10_ui.luau` | Elementos de UI (Toggle, Slider, Dropdown, Button, Keybind, cor…) |
| `src/20_config.luau` | Perfil, idiomas, configuração e persistência |
| `src/24_runtime.luau` | Diagnóstico local, escala e varredura incremental |
| `src/25_security.luau` | Lista e regras do bloqueio preventivo |
| `src/26_guard.luau` | Proteção de eventos e laços periódicos |
| `src/27_profiles.luau` | Validação e aplicação defensiva de perfis |
| `src/28_operations.luau` | Limites locais e seleção explícita de remote |
| `src/29_favorites.luau` | Favoritos de navegação salvos no perfil |
| `src/30_actions.luau` | Lógica de movimento, mundo, extras e combate |
| `src/40_menu.luau` | Janela, registro de opções e auxiliares |
| `src/50_tabs.luau` | Abas, painel do ESP, radar e busca de saque |
| `src/60_engine.luau` | Motor do ESP, radar, loot e zona do modo pânico |
| `build.py` | Monta `BBC_HUB.luau` a partir de `src/` |

**Edite os módulos em `src/`, não o `BBC_HUB.luau`** (ele é gerado). Depois rode:

```bash
python3 build.py
```

Os módulos não são scripts independentes: eles se assumem em ordem, como
fatias do mesmo arquivo.

## Como usar

Cole o conteúdo de `BBC_HUB.luau` no seu executor, ou carregue por URL:

```lua
loadstring(game:HttpGet("URL_DO_ARQUIVO"))()
```

`URL_DO_ARQUIVO` é um exemplo, não um endereço funcional. Use o conteúdo bruto
(**Raw**) de `BBC_HUB.luau` na versão publicada e verificada que deseja testar;
não use a página HTML `github.com/.../blob/...`. Um link fixado em um hash de
commit sempre aponta para aquela versão, mesmo após novas correções. Não baixe
nem execute arquivos de origem desconhecida.

### Arquivos e compatibilidade: PC e celular

- O mesmo `BBC_HUB.luau` é o artefato gerado para os dois tipos de dispositivo;
  não é necessário instalar `src/`, `build.py`, testes ou documentos no aparelho.
  Os módulos são partes do mesmo arquivo e não devem ser executados isoladamente.
- O formato único não garante que todos os ambientes consigam executá-lo. O
  carregamento por URL depende das APIs de download e compilação disponíveis no
  ambiente. Os recursos opcionais variam: perfis dependem de APIs de arquivos;
  algumas fontes adicionais também dependem de acesso à rede e `getcustomasset`;
  copiar texto e outras ações dependem de APIs próprias. A presença de uma API
  não comprova que funcione. Dados locais não são sincronizados automaticamente
  entre aparelhos ou executores.
- Teclado/mouse e toque exigem testes separados; um dispositivo pode ter mais de
  um método de entrada. O tamanho da tela, orientação, elementos de toque,
  recursos disponíveis e versão do ambiente podem mudar o resultado. O
  `MANUAL_TESTS.md` registra o que precisa ser testado.
- A [documentação oficial de entrada](https://create.roblox.com/docs/input)
  descreve métodos de entrada e dispositivos híbridos; o
  [Device Emulator do Studio](https://create.roblox.com/docs/tutorials/curriculums/user-interface-design/implement-designs-in-studio)
  ajuda a verificar layouts, mas não reproduz um executor externo. Em uma
  experiência própria, scripts de cliente e módulos podem ser organizados pelo
  [modelo de scripts do Roblox](https://create.roblox.com/docs/scripting/locations);
  isso não transforma automaticamente este hub, que usa APIs específicas de
  executores, em um projeto Studio pronto para uso.
- O Roblox informa que software que modifica o cliente não é permitido e pode
  levar a restrições na conta; consulte [Anti-cheat Messages](https://en.help.roblox.com/hc/en-us/articles/24275616578708-Anti-cheat-Messages).
  Não há garantia de segurança ou compatibilidade em executores de terceiros.

## Abas

| Aba | Conteúdo |
| --- | --- |
| VISUAIS | ESP (Jogador, NPCs, Corpo, recipientes, itens), interface do jogo, efeitos locais |
| JOGADOR | Movimento, câmera, saque, mãos/arma, campo de visão, animações, recursos |
| COMBATE | Mira, alvos, espiada, corpo a corpo, arma, efeitos, anti-aim, granadas |
| MUNDO | Iluminação, cores do terreno, grama/minas, cargas, chefes, saídas |
| EXTRAS | Troca rápida, modo pânico, sons, detecção de cargos |
| BUSCAR SAQUE | Filtros por nome/raridade e marcação dos itens na tela |
| SERVIDORES | Lista de servidores, busca, entrada |
| SKINS / MISSÕES / COMERCIANTES | Seções reservadas |
| CONFIGURAÇÕES | Segurança, geral, aparência, marca d'água, lista de atalhos |

## ESP (estilo Chams)

- Silhueta **blocuda** (cabeça, tronco, braços, mãos, pernas e pés separados),
  preenchimento **laranja/vermelho translúcido** e **contorno escuro fino**.
- **Caixa retangular fina** laranja (cantos ou completa), **barra de vida
  vertical** verde no lado esquerdo, nome e distância.
- O modo **Corpo** mostra a pose **caída** (deitado).
- **Recipiente**, **Item no chão** e **Itens de missão** marcam baús, caixas,
  itens soltos (com prompt/clique ou atributo de raridade) e itens de missão.
- Pré-visualização ao vivo na aba, com chips de atalho e ajustes por opção.

## Lógica dos botões

Há implementações locais nas áreas abaixo. Seu resultado depende das APIs e
da estrutura do jogo; alterações no cliente não garantem efeito no servidor:

- Movimento: velocidade, sprint, pulos seguidos, controle no ar, voar (espaço
  sobe / shift desce), sem dano de queda, sempre no chão, Jesus, aranha,
  terceira pessoa, câmera livre, anti-AFK, renascer automático, não se afogar.
- Mundo: luz, hora/sol, sombras, neblina, atmosfera, céu, nuvens, florescimento,
  desfoque, ajuste de cor, profundidade, raios de sol e tonalidade; cores de
  grama/areia/rocha/terra/água, folhas e troncos; sem grama, desativar minas,
  carregar jogadores, marcar chefes e saídas.
- Extras: troca rápida de ferramentas, modo pânico, atravessar porta (alguns
  segundos sem colisão), remover efeitos, avisos de entrada, identificação heurística de
  cargos, ordenar mochila por valor/tipo/nome, inventário com lista de itens,
  saque automático e sons de eventos (pulo, pouso, pegadas, disparo, abate).
- Visuais locais: aura, círculo de salto, auréola e rastro estelar têm ajuste
  de intensidade; o círculo aparece por um curto período após o pulo. O
  controle geral LOCAL pausa os efeitos preservando as seleções individuais.
- **Ocultar indisponíveis** filtra opções bloqueadas por VIP ou ainda sem lógica,
  preservando o filtro de busca. Mochila personalizada, Mapa e navegação,
  Trocar personagem, Mira falsa e Alternativa visível estão
  desativados por não terem implementação completa. As engrenagens foram
  recolocadas: as que ainda não possuem ajustes específicos mostram um aviso,
  não controles fictícios.
- Ajustes específicos implementados nas engrenagens incluem multiplicadores de
  movimento, velocidades de voo/subida, distância da câmera, intervalo da troca,
  iluminação e efeitos atmosféricos, volume dos sons, limite de espaços da barra,
  transparência do fantasma, trajetória, retícula e marca de acerto. A lista
  dos submenus ainda pendentes está em SECURITY_REVIEW.md. Mais 24 engrenagens
  receberam ajustes locais: tempos e distâncias, efeitos, corpo em primeira
  pessoa, marcações e apresentação. As quatro ainda sem ajustes são Mochila,
  Mochila personalizada, Mira falsa e Trocar personagem. Mudanças numéricas
  passam por limites locais; não alteram a política preventiva.
- **Barra rápida**: painel local para até oito objetos `Tool` da mochila e do
  personagem, com toque/clique para equipar ou guardar. Não substitui a barra
  nativa e não suporta inventários próprios que não usem `Tool`.
- Câmera: campo de visão, zoom ao segurar a tecla e painel de jogadores.
- Combate: mira com raio e suavização ajustáveis, escolha de parte do corpo,
  previsão de movimento, alvo fixo, pausa inteligente, filtro de amigos local,
  retícula, círculo da mira, dados do alvo, marca de acerto e números de dano;
  aura letal, espiada subterrânea, anti-aim, sob o chão, fantasma, trajetória
  do arremesso, sem tremor e recarga automática. O ajuste de recuo compensa
  a direção da mira, não altera a arma. Ignorar obstáculos na mira não faz
  disparos atravessarem paredes. Efeitos confirmados dependem da tag `creator`.
- **Efeitos de acerto** usam um `Highlight` local temporário ao observar perda
  de vida. Com “Só acertos confirmados” ligado, dependem da tag `creator`, que
  pode não existir ou não ser confiável. Não comprovam acerto no servidor.
- **Corpo em 1ª pessoa** ajusta localmente `LocalTransparencyModifier` de
  partes R6/R15 reconhecidas e bloqueia a câmera em primeira pessoa; rigs
  diferentes podem não funcionar. A restauração é de melhor esforço.
- Animações: “Swish” procura uma `Animation` com esse nome e “Padrão” procura
  uma animação em `Animate/idle` do personagem; o jogo precisa fornecer o asset.

A revisão das proteções e das limitações conhecidas está em [SECURITY_REVIEW.md](SECURITY_REVIEW.md).

## Compatibilidade da interface

- Ao inserir uma GUI, o hub tenta `gethui()`, depois `CoreGui` e por fim
  `PlayerGui`, protegendo tanto a obtenção quanto a atribuição de `Parent`.
  Se todas falharem, a criação é interrompida em vez de fingir sucesso. A
  aceitação do `Parent` não comprova que a GUI será exibida ou ficará oculta.
- O menu ajusta `UIScale` ao tamanho da tela; o controle **Escala do menu**
  permite escolher 70% a 130%, limitado pelo espaço disponível. Toque, teclado e mouse são
  considerados para escolher as instruções de uso; dispositivos híbridos
  podem usar tanto toque quanto mouse. Um teste relatado no Delta móvel falhou
  na compilação da versão anterior por limite de registradores; a correção ainda
  precisa de teste real. Não há validação completa em Delta, Arceus, Wave ou
  Potassium nem em PC e aparelhos móveis.

## Segurança e limitações

- A biblioteca tenta chamar `protectgui` ou `syn.protect_gui`, quando
  disponíveis no executor, antes de associar as GUIs do menu, avisos, overlay,
  ESP e marcadores à hierarquia. A chamada é opcional e, se faltar ou falhar,
  há um aviso; o menu ainda abre. A proteção depende do executor e do tipo de
  GUI. Mesmo uma chamada sem erro não prova que ela esteja oculta. A pasta de
  objetos do ESP, objetos no mundo, executor e ações não estão cobertos por
  essa API. Há tentativa de remover a proteção ao destruir as GUIs ou sair.
- A pesquisa usou a [documentação histórica de `syn.protect_gui`](https://synapsexdocs.github.io/libraries/syn/),
  que descreve proteção contra buscas recursivas específicas, e as
  [orientações de segurança do Roblox](https://create.roblox.com/docs/scripting/security/security-tactics),
  que descrevem validação no servidor. Essas fontes não garantem compatibilidade
  com executores atuais nem imunidade ao anticheat.
- O **Bloqueio preventivo** começa ligado em CONFIGURAÇÕES → SEGURANÇA. Ele
  bloqueia uma lista fixa de opções de maior risco, inclusive quando ativadas
  por atalho, botão fixo ou perfil. O bloqueio inclui Anti AFK, que simula
  entrada. A política também é verificada na entrada das ações listadas e
  antes de algumas operações (saque, recarga, mira, aura e atravessar porta).
  Não examina o anticheat do jogo. Para usar
  essas opções, é necessário desligá-lo manualmente a cada sessão.
- Para reduzir chamadas acidentais, o saque automático respeita a distância
  anunciada pelo `ProximityPrompt` e está limitado a uma tentativa a cada 2 s e
  dez por 60 s; a recarga, a uma tentativa a cada 5 s e seis por 60 s. Esses
  limites são locais e conservadores, **não são os limites do jogo** e não
  impedem detecção ou punição. Falhas ao disparar interrompem a função.
- O saque automático também exige `BBC_CONFIG.LootPlaceId` igual ao PlaceId
  atual e `BBC_CONFIG.LootPromptPaths`, lista de 1 a 20 caminhos exatos de
  `ProximityPrompt` relativos ao `Workspace` (cada caminho tem até oito nomes).
  Sem configuração válida, ele não inicia; caminhos ausentes ou ambíguos não
  são acionados. Configure apenas prompts conhecidos e autorizados, por exemplo:

  ```lua
  getgenv().BBC_CONFIG = getgenv().BBC_CONFIG or {}
  getgenv().BBC_CONFIG.LootPlaceId = 123456 -- substitua pelo PlaceId real
  getgenv().BBC_CONFIG.LootPromptPaths = {{"PastaConhecida", "Objeto", "Prompt"}}
  ```

  Isso não verifica autorização do servidor. Nomes repetidos são rejeitados e
  objetos em streaming podem estar ausentes temporariamente.
- A recarga não procura mais um remote por conter "reload" no nome. Mesmo com
  o bloqueio preventivo desligado, ela exige `getgenv().BBC_CONFIG.ReloadRemotePath`,
  uma lista de nomes exatos do caminho relativo à ferramenta equipada. Use
  apenas um caminho conhecido e autorizado para o jogo; sem configuração, ou
  com caminho incorreto/ambíguo, nenhum remote é enviado. O caminho não prova
  que o remote seja seguro e o recurso pode precisar de argumentos que este
  hub não fornece. Exemplo estrutural, substitua pelos nomes reais:

  ```lua
  getgenv().BBC_CONFIG = getgenv().BBC_CONFIG or {}
  getgenv().BBC_CONFIG.ReloadRemotePath = {"PastaConhecida", "RemoteConhecido"}
  ```

- Ao religar o bloqueio ou acionar o pânico, as opções da lista que estiverem
  ligadas são desligadas. O pânico também oculta interface e ESP, mas não
  reverte todas as alterações. Após sair do pânico, opções desligadas não são
  religadas automaticamente. Um mecanismo adicional tenta interromper estados
  e tarefas de risco mesmo se algum controle falhar ao desligar; a restauração
  continua sendo de melhor esforço.
- Eventos da interface, ações e motor usam proteção de erro e interrompem a
  conexão após cinco falhas consecutivas; alguns laços também têm esse limite.
  Sliders limitam valores, e o encerramento desconecta eventos e tenta restaurar
  propriedades e objetos locais. Para propriedades acompanhadas, uma mudança
  posterior do jogo não é sobrescrita ao restaurar. Essas medidas são parciais:
  nem todas as tarefas ou dependências externas são verificadas, e efeitos já
  processados pelo servidor não podem ser desfeitos pelo cliente.
- Ícones usam símbolos locais ou IDs de asset fornecidos, sem baixar ou executar
  código Lua de terceiros. Fontes personalizadas ainda podem usar rede e assets.
- Caches de itens e saque descartam entradas que saem do Workspace e limitam
  candidatos a 2.048 por categoria; objetos excedentes podem não aparecer até
  uma nova sessão/entrada em streaming. As varreduras iniciais do motor e de
  NPCs da mira percorrem os filhos incrementalmente, mas outras opções ainda
  usam `GetDescendants`. **Atualizações do ESP** limita ESP/radar/busca a 10–60
  atualizações por segundo (padrão 30); pode reduzir fluidez. A troca de
  personagem interrompe opções de risco; limpeza/restauração são parciais.
  Marcações de chefes e saídas usam varredura incremental, cancelam ao desligar,
  respeitam o pânico e têm limite de 100 por categoria. Elas não acompanham
  automaticamente novos objetos: desligue e ligue para procurar novamente.
- Em **CONFIGURAÇÕES → DIAGNÓSTICO**, atualize capacidades de arquivos/entrada,
  configuração de caminhos, estado preventivo e até três falhas registradas.
  Presença de API ou caminho válido não comprova execução, autorização,
  compatibilidade do jogo ou proteção anticheat; nem todas as falhas são capturadas.
- A [documentação de detecção no servidor do Roblox](https://create.roblox.com/docs/scripting/security/server-side-detection)
  descreve heurísticas de velocidade, cadência e remotes-isca; a
  [documentação da fronteira cliente-servidor](https://create.roblox.com/docs/scripting/security/client-server-boundary)
  explica limites de frequência e validação. Um limite local não substitui as
  regras de cada jogo nem torna as chamadas indetectáveis.
- Não há detector universal de anticheat nem garantia contra detecção ou
  punição. O código local não chama `hookmetamethod` nem `getnamecallmethod`,
  mas o executor, dependências externas e outras ações também podem ser
  detectados. `pcall` não evita detecção. O projeto não instala hooks para
  falsificar `__namecall`, `__index`, `getfenv`, `Kick` ou nomes de remotes;
  essas técnicas não garantem imunidade e podem causar falhas. Use somente em
  ambientes autorizados.
- O compilador Luau e os testes de política podem ser executados definindo
  `LUAU_COMPILE` e `LUAU_BIN`, respectivamente, antes de
  `python3 -m unittest discover -s tests -v`. A suíte também verifica a
  compilação do arquivo completo com otimizações 0, 1 e 2, além de `loadstring`,
  sem executar o hub. Isso não comprova compatibilidade com executores nem
  substitui testes no Roblox.
  O roteiro de verificação em ambiente autorizado está em [MANUAL_TESTS.md](MANUAL_TESTS.md).

## Configuração do menu

Em **CONFIGURAÇÕES → CONFIGURAÇÃO DO MENU**, escolha um nome e use **Salvar
configuração** ou **Revisar configuração** seguido de **Confirmar carregamento**.
A revisão não executa controles e mostra todas as alterações em páginas de 50,
com contagens de bloqueios e dados desconhecidos. A confirmação expira em 60 segundos e exige
nova revisão se o arquivo, os valores relevantes ou a política mudarem. Valores
tabulados grandes são resumidos. Essa confirmação é do botão do menu: autoload,
recuperação e APIs programáticas continuam tendo seu fluxo próprio. Salvar ou
confirmar também seleciona o arquivo para iniciar; após isso o salvamento
automático acompanha alterações.
Para sobrescrever manualmente um arquivo existente, toque em **Salvar
configuração** duas vezes em até 30 segundos; mudanças no arquivo ou nos valores
entre os toques exigem confirmação nova. Autosave e APIs programáticas não usam
essa confirmação. Na confirmação manual, o hub tenta guardar uma versão anterior
em um dos três espaços fixos `*.json.version1` a `*.json.version3`. Não apaga
versões antigas: se estiverem cheios ou houver falha, avisa e segue com o backup
normal `.bak`. Também é possível criar uma versão manualmente e restaurá-la em
um novo perfil `-histN`, sem carregá-lo automaticamente. A cópia exige APIs de
arquivo e a escrita não é atômica.

O painel mostra a configuração ativa e lista até 100 arquivos quando `listfiles`
está disponível; arquivos além desse limite ainda podem ser carregados pelo nome.
O bloqueio preventivo continua ativo ao iniciar e pode impedir opções de risco.
O nome usa até 24 letras, números, espaços, hífen ou sublinhado. O nome
`none` é reservado para desativar o carregamento inicial; esse arquivo pode ser
salvo ou carregado manualmente, mas não selecionado para iniciar.

Os arquivos anteriores em `BBC_HUB/configs/<nome>.json` e
`BBC_HUB/autoload.txt` são reaproveitados, sem exclusão ou migração destrutiva.
Quando um arquivo válido é sobrescrito, a versão anterior é copiada para
`<nome>.json.bak`; se o backup falhar ou o conteúdo anterior for inválido, a
sobrescrita é recusada. A cópia é apenas a última versão, não é atômica e não
restaura automaticamente. **Recuperar backup** cria e carrega uma nova cópia
`<nome>-recN.json`, sem alterar o original ou o backup; nomes existentes não
são sobrescritos. Ao carregar, o hub informa quantos ajustes desconhecidos ou
bloqueados foram ignorados. O autoload aguarda a pré-montagem dos painéis; se
algum falhar ou demorar demais, autoload e autosave inicial são suspensos com
aviso. Se a configuração inicial falhar ao carregar, ou
existir um `default.json` sem seleção de inicialização, o salvamento automático
fica suspenso até salvar ou carregar explicitamente, para preservar arquivos.

São aceitos dados antigos sem versão e versões 1 e 2. O JSON é limitado a
256 KiB, profundidade 8, 20.000 valores e strings de 4.096 bytes. Controles
conhecidos são validados, desconhecidos ignorados e opções bloqueadas são
ignoradas. Submenus reintroduzidos usam novos caminhos por nome; os ajustes
antigos genéricos não são migrados. A aplicação tenta desfazer alterações se
um setter falhar, mas callbacks e efeitos externos não garantem reversão.
Leitura, backup e escrita dependem do executor; não são transações atômicas.
O salvamento requer `writefile`, `readfile`, `isfile` e criação prévia da pasta
ou suporte a `isfolder` e `makefolder`. Falhas são notificadas no salvamento
manual e na primeira falha do autosave; o autosave tenta novamente. Fontes personalizadas exigem `getcustomasset`.

## Idiomas

Português (Brasil), English, Español, 简体中文 e Русский — nomes e descrições
das opções acompanham o idioma escolhido.

## Teclas

Menu, cursor, zoom e pânico são reconfiguráveis; as opções também podem receber
um atalho e um botão fixo na tela.

## Aviso

Projeto de estudo/entretenimento. Use por sua conta e risco.

### Interface e acessibilidade

- A intro pode ser pulada no botão do cartão ou desativada na próxima execução em **Configurações → Aparência**. A barra representa etapas, não tempo estimado; se a montagem demorar, o aviso não declara que terminou.
- Aparência oferece temas, prévia e aplicação explícita de cor personalizada, alto contraste e redução de movimento. A cor é apenas visual. Alto contraste melhora superfícies e texto, mas não garante uma razão de contraste para toda cor escolhida. Movimento reduzido cobre as principais transições da biblioteca e a animação da prévia; não é garantia sobre animações do jogo ou outras GUIs.
- A busca aceita o nome original e a tradução disponível, mostra até 40 resultados clicáveis com caminho e abre temporariamente submenus correspondentes. Contagens aparecem nas abas; Enter seleciona o primeiro resultado, Ctrl+F abre a busca e Esc a fecha quando ela está em foco. A normalização cobre ASCII, letras latinas comuns e cirílico básico, mas não todo Unicode; traduções ausentes permanecem no original.
- Em telas estreitas ou retrato com toque, os grupos passam a uma coluna e algumas linhas têm área de toque maior; quando há espaço suficiente novamente, a divisão original é restaurada. Painéis de prévia ainda precisam de teste em dispositivos reais e a escala continua limitada pelo tamanho da tela.
- A prévia de cor mostra razões de contraste aproximadas entre cor e superfície atual e entre branco e cor; o aviso de 4,5:1 não certifica a interface inteira. Dicas distinguem opção pendente, VIP e bloqueio preventivo.
- O diagnóstico apresenta uma média aproximada do tempo do callback visual do ESP/radar/busca, em milissegundos, atualizada ao solicitar diagnóstico. Não mede GPU, FPS nem o custo total do jogo.
- As preferências visuais são espelhadas em `BBC_HUB/appearance.json` e aplicadas antes da intro, sem carregar opções de jogo. Temas e cores também entram nos perfis; contrastes e preferências de movimento são controles de perfil. O autoload de perfil ocorre depois da montagem e pode substituir a aparência inicial. O arquivo visual anterior é copiado para `appearance.json.bak`; arquivos visuais inválidos são preservados e seu salvamento bloqueado. As APIs de arquivo podem não existir e a escrita não é atômica.
- O diagnóstico pode copiar erros recentes se o executor fornecer uma API de área de transferência; revise o conteúdo antes de compartilhá-lo, pois mensagens podem conter informações locais. Presença da API não garante funcionamento.

### Favoritos e saúde do hub

Na página inicial há até 12 favoritos por perfil. Para adicionar ou remover um
controle compatível, segure a opção (ou use a dica no mouse) e toque em
**Favoritar**. O favorito navega até o controle original e abre grupos ou
submenus; não o ativa nem contorna bloqueios. Alguns controles sem salvamento
não oferecem favorito. **Recentes nesta sessão** guarda em memória até cinco
opções abertas pela busca ou pelos favoritos; não registra todas as ações e é
apagado ao fechar. A seção de diagnóstico existente mostra a situação da
montagem, salvamento automático e últimas falhas. APIs presentes não garantem
funcionamento, e não há detecção de anticheat.

A prévia de tema é ilustrativa. Tamanho de texto independente com adaptação
completa, suporte a leitor de tela e navegação por controle ainda não foram
implementados ou validados integralmente. Os testes automatizados são simulados;
o roteiro Roblox/dispositivos permanece em `MANUAL_TESTS.md`.

#### Referências para acessibilidade

As [diretrizes do Roblox](https://create.roblox.com/docs/production/publishing/accessibility)
descrevem preferência de tamanho de texto e seus limites: textos `TextScaled` e
layouts fixos precisam de atenção. A documentação de
[`GuiObject`](https://create.roblox.com/docs/reference/engine/classes/GuiObject#NextSelectionDown)
descreve seleção e direções para navegação por controle. Isso não comprova que
este menu funciona com essas configurações. Não foi confirmada uma integração
de leitor de tela para esta interface; é necessário investigar e testar com
recursos de acessibilidade reais antes de prometer suporte.
