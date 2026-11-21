# Revisão de proteções e lógica — BBC HUB

Esta análise é estática e usa simulações Luau; não houve teste no Roblox,
no anticheat de um jogo específico, em dispositivos reais ou nos executores.
Não há garantia de segurança, de ausência de detecção ou de punição.

## Pesquisa e consequências

- [Detecção no servidor — Roblox](https://create.roblox.com/docs/scripting/security/server-side-detection):
  jogos podem analisar trajetórias, cadência e remotes-isca. Bloquear uma lista
  local de opções, limitar frequência ou esconder uma GUI não informa o que o
  jogo detecta nem desativa decisões no servidor.
- [Fronteira cliente-servidor — Roblox](https://create.roblox.com/docs/scripting/security/client-server-boundary):
  interações e prompts precisam ser validados pelo servidor. A distância e o
  estado vistos pelo cliente não comprovam autorização ou sucesso da ação.
- [Movimento e física — Roblox](https://create.roblox.com/docs/scripting/security/network-ownership):
  o servidor pode validar movimentação; as regras dependem do jogo e da rede.
- [Dependências de terceiros — Roblox](https://create.roblox.com/docs/scripting/security/third-party-vulnerabilities):
  código de terceiros deve ser inspecionado; um limite de tamanho não autentica
  código nem isola um executor comprometido.
- [Documentação histórica de `syn.protect_gui`](https://synapsexdocs.github.io/libraries/syn/):
  descreve proteção contra determinadas buscas recursivas, não invisibilidade
  perante qualquer anticheat. Disponibilidade e semântica variam por executor.

## O que existe

| Camada | Medida atual | Limitação |
| --- | --- | --- |
| Política | Lista bloqueada por padrão; checagem no menu, perfis e ações registradas. | Lista fixa e parcial, não detecta regras nem cobre todos os caminhos e dependências. |
| Interrupção | Pânico/religar a política desliga controles rastreados e tenta interromper estados e tarefas críticos independentemente dos controles. | Callbacks e restaurações podem falhar; estado já processado pelo servidor não é desfeito. |
| Eventos e loops | Interrupção após falhas consecutivas nos caminhos integrados. | Erros já capturados internamente podem passar despercebidos; cobertura incompleta. |
| Remotes e prompts | Limites locais; recarga exige caminho explícito e saque exige PlaceId e caminhos exatos de prompts, recusando ambiguidades. | Isso não comprova autorização nem sucesso no servidor; ambos permanecem bloqueados por padrão. |
| Interface | Tenta API opcional de proteção e parent com fallback; limita notificações. | O executor pode não oferecer a API ou sua implementação pode falhar. Sucesso da chamada não prova ocultação. |
| Configurações | Validação, tentativa de rollback, backup anterior válido e bloqueio do autosave após falha inicial. Arquivos antigos são preservados. | Escrita/backup não são atômicos, não há recuperação automática e callbacks podem ter efeitos externos. |
| Dependências | Ícones Lucide com IDs de asset incluídos localmente (MIT); não executa código remoto/cacheado para ícones. | Outros assets, fontes e o executor ainda têm riscos. |
| Streaming e desempenho | Varredura incremental no motor, na mira e nas marcações de chefes/saídas, caches limitados, remoção em streaming, deduplicação e frequência visual ajustável. | Outras funções ainda usam `GetDescendants`; caches limitados podem omitir objetos. Nem todos os ciclos foram auditados em Roblox. |
| Diagnóstico | Histórico local limitado e painel de capacidades/caminhos declarados. | Não testa funcionamento real das APIs, não captura todos os erros e não detecta anticheat. |

## Lógicas e pendências

- Barra rápida local para até oito `Tool`s; não cobre inventários proprietários.
- Engrenagens do menu foram recolocadas. Parte delas tem ajustes específicos
  ligados à ação; as demais exibem aviso de pendência sem controles fictícios.
  Submenus reintroduzidos usam caminhos de perfil por nome; valores antigos dos
  ajustes genéricos não são migrados. Campos de estatísticas e o marcador
  solicitados para exclusão continuam removidos.
- FOV dinâmico altera o raio com o FOV da câmera. A verificação opcional de
  acertos utiliza a tag `creator`, que pode não existir ou não ser confiável.
- Animações procuram assets existentes no personagem; não inventam IDs.
- Mochila personalizada, Mapa e navegação, Trocar personagem, Mira falsa e
  Alternativa visível continuam desativados. Skins, Missões
  e Comerciantes seguem como seções reservadas. Espalhamento e pausa entre tiros
  não são aplicados e seus ajustes foram removidos. Implementações específicas
  dependem de dados e interfaces do jogo. O mesmo vale para saque e recarga.
- O contorno do `Highlight` é ligado/desligado, não tem espessura variável.
  Em perfis antigos, o caminho de ajuste e o controle de obstáculos na mira
  mudaram e podem precisar ser configurados novamente.

### Engrenagens ainda sem ajustes próprios

Quatro engrenagens mantêm o aviso de pendência: **Mochila**, **Mochila
personalizada**, **Mira falsa** e **Trocar personagem**. Mochila controla a
interface nativa do Roblox e não recebeu ajuste fictício; as demais continuam
sem implementação completa. Integrações específicas por jogo foram deixadas
fora desta etapa, conforme solicitado. As outras 24 engrenagens antes pendentes
receberam ajustes vinculados às suas lógicas locais.

O efeito de acerto é local e depende das informações de vida e, opcionalmente,
da tag `creator`: não é confirmação do servidor. O corpo em primeira pessoa
reconhece peças R6/R15 comuns; rigs diferentes podem não funcionar. O roteiro em
`MANUAL_TESTS.md` ainda precisa ser executado em ambiente autorizado; simulações
não equivalem a testes no Roblox, em dispositivos ou executores reais.

### Revisão adicional local

A tela de revisão de perfil não executa setters e a confirmação relê e valida o
arquivo e os valores relevantes; alterações ou prazo expirado exigem nova
revisão. O painel pagina todas as mudanças e resume valores de tabelas grandes. Autoload, recuperação
e chamadas programáticas não passam por essa confirmação. Validação e rollback
continuam sem tornar os efeitos externos reversíveis. A varredura inicial de
objetos ocultados por nome é incremental e cancelável, mas outras varreduras
permanecem; a média de tempo no diagnóstico não mede GPU nem valida segurança.
Essas mudanças não foram testadas no Roblox.

Favoritos apenas navegam até controles, sem ativá-los. A confirmação de
sobrescrita vale somente para o botão manual; o autosave conserva o fluxo
anterior. O histórico tem três espaços que não são sobrescritos e pode ficar
cheio; nesse caso a gravação usa apenas o backup normal. Escritas e verificação
de existência não são atômicas; restaurações de histórico criam cópias sem
ativá-las. Não foram realizados testes Roblox/executor nesta rodada.
