# Roteiro de testes em ambiente autorizado

Estes testes **ainda não foram executados** pelo desenvolvimento automatizado.
Use apenas um lugar de teste próprio ou com permissão explícita, contas de teste
e dados descartáveis. O hub usa APIs que podem não existir no Roblox Studio;
registre o ambiente e as limitações em vez de concluir que o teste passou.
Não há teste aqui que prove invisibilidade ou ausência de detecção.

## Preparação

- Anote data, hash/versão do arquivo, ambiente e sua versão, sistema operacional,
  tipo de entrada, resolução e modelo do dispositivo. Teste o mesmo arquivo no PC
  e no celular; um link fixado em commit anterior não recebe a correção nova. Guarde logs sem credenciais, IDs privados ou dados de terceiros.
- Faça cópia de `BBC_HUB/configs` e `BBC_HUB/autoload.txt` antes dos testes.
  Use arquivos novos e nomes de teste, sem substituir configurações pessoais.
- O bloqueio preventivo foi removido. Teste apenas em ambiente controlado e
  autorizado; perfis salvos podem reativar funções. Não há proteção anticheat.

## PC: mouse e teclado

- [ ] Abrir/fechar o menu, buscar uma opção, alternar abas e usar os tooltips.
- [ ] Ajustar escala em 70%, 100% e 130%; verificar que o menu cabe na tela.
- [ ] Alterar tema/idioma e conferir textos, tooltips e o painel de diagnóstico.
- [ ] Salvar uma configuração de teste, alterar valores, carregar e reiniciar.
      Verificar o nome ativo, ações habilitadas e avisos de dados desconhecidos.
- [ ] Gerar backup ao salvar duas vezes, usar **Recuperar backup** e confirmar
      que `-recN` é criado e que o original e `.bak` não são alterados.
- [ ] Testar nome ocupado, backup inválido, `listfiles` indisponível e falha de
      escrita em ambiente simulado. Confirmar avisos e preservação de arquivos.
- [ ] Confirmar ajustes locais de iluminação, marcações, barra rápida, painel,
      corpo em primeira pessoa em um rig R6 e outro R15; desligar e verificar
      restauração. Não presumir compatibilidade com rigs próprios do jogo.
- [ ] Exercitar efeitos de acerto apenas com alvos de teste; conferir duração,
      limite de objetos e limpeza. A tag `creator` pode não existir.
- [ ] Acionar pânico, testar três toques/atalho de retorno, trocar personagem e
      sair. Verificar que loops, realces, atalhos e interfaces são interrompidos.

## Celular: toque

- [ ] Abrir pelo botão flutuante, rolar as duas colunas e abrir engrenagens.
- [ ] Segurar e soltar para exibir descrição sem acionar a opção por acidente.
- [ ] Testar sliders, dropdowns, botão de salvar, teclado virtual, orientação
      vertical/horizontal e escala; verificar recorte e controles acessíveis.
- [ ] Equipar e guardar ferramentas pela barra rápida, incluindo após renascer.
- [ ] Acionar pânico e retornar pela área de três toques; ajustar largura e
      tempo de retorno antes de repetir o teste.

## Desempenho e streaming

- [ ] Em um mapa controlado com streaming, ligar ESP/radar/busca, mover-se para
      carregar/descarregar objetos e observar se marcadores antigos somem.
- [ ] Comparar 10, 30 e 60 atualizações do ESP; registrar fluidez, atraso e
      consumo de recursos sem supor que o limite afeta outras partes do jogo.
- [ ] Entrar/sair repetidas vezes, ativar/desativar funções e inspecionar se há
      conexões ou efeitos duplicados. Verificar limite de candidatos em mapas grandes.

## Resultado

Registre **passou**, **falhou** ou **não testado** para cada item, com passos
para reproduzir e capturas sem dados privados. Testes automáticos em `tests/`
e compilação Luau não substituem este roteiro nem validam regras do servidor.

## Revisão de interface e acessibilidade (a executar)

- Reiniciar com tema salvo, com cor personalizada, com alto contraste e com redução de movimento; verificar intro, persistência e autoload de outro perfil sem habilitar recursos inesperados. Cor escolhida deve aparecer na amostra antes de aplicar. Repetir com APIs de arquivos ausentes e arquivo visual inválido; confirmar que o arquivo é preservado.
- Pular a intro durante a montagem e usar a preferência para a próxima execução. Simular montagem lenta/erro e falha de pré-montagem dos painéis; verificar que não anuncia conclusão antes do `FinishLoading` e que autoload/autosave são suspensos quando há falha ou demora.
- Buscar nome original e traduzido nos cinco idiomas, testar itens em submenus, contagem por aba e ocultação de indisponíveis; limpar a busca e verificar que submenus e grupos voltam ao estado anterior. A busca normaliza cirílico básico, mas não todo Unicode.
- No painel ESP, alterar distância, limite de detalhes, destaque do alvo mais próximo, cor e unidade; comparar prévia com o motor, inclusive distância fora do alcance. Confirmar silhueta Chams e ausência de animação da prévia com movimento reduzido.
- Arrastar a janela e botão móvel até as bordas; alternar orientação, tamanhos pequenos, rolagem, atalhos e toque prolongado para dicas. Testar também os botões fixos e conferir que não ficam inacessíveis.
- Copiar o diagnóstico com e sem API de clipboard, revisar dados antes de compartilhar; testar fechar, pânico, reaparecimento e streaming. Nenhum desses testes foi executado em Roblox/dispositivos nesta revisão.

## Verificações adicionais (não executadas no Roblox)

- Buscar em português, inglês, espanhol, russo (maiúsculas/minúsculas) e chinês; tocar resultados em abas normais, CONFIGURAÇÕES e painéis ESP, conferir rolagem, lista vazia e limite de 40.
- No toque e em orientação retrato, confirmar coluna única, ordem dos grupos, acesso aos submenus e rolagem; girar de volta e conferir restauração das duas colunas. Verificar áreas de toque, modais e sobreposições.
- Revisar um perfil com alterações, mais de 100 alterações e opções que ficam bloqueadas durante pânico; conferir todas as páginas, resumo e confirmar separadamente. Alterar o arquivo, o estado de pânico e um ajuste entre revisão e confirmação; verificar recusa. Conferir expiração, nome diferente, rollback e autoload/recuperação.
- Testar cores claras/escuras, relação de contraste exibida, atualização com tema e idioma; comparar leitura real de textos sem tratar o número como certificação.
- Em ambiente autorizado, iniciar/cancelar repetidamente as opções de ocultação por nome durante a varredura; testar pânico, saída e streaming, verificando restauração e ausência de callbacks após cancelar. Anotar valores de tempo médio do motor visual com diferentes cargas, sem interpretá-los como uso de GPU ou FPS.

## Favoritos, temas e histórico (não executados no Roblox)

- Favoritar/desfavoritar controles, inclusive pendentes e bloqueados; conferir o limite 12, recarregamento do perfil, troca de idioma e navegação em grupo recolhido e submenu. Confirmar que navegar não ativa a opção.
- Abrir opções pela busca e pelos favoritos, conferir ordem e limite dos cinco recentes e a limpeza ao fechar. Esses atalhos só navegam.
- Usar Ctrl+F, Enter e Esc sem interferir em outros campos. Testar teclado/controle e leitor de tela quando disponíveis; não presumir suporte completo.
- Comparar amostra de tema, cor candidata, contraste e aplicação efetiva. Em PC e celular, verificar recortes e toque nas dicas com três ações.
- Salvar arquivo existente: testar confirmação em 30 segundos, mudanças no arquivo, ajustes ou nome, cancelamento e falhas de escrita. Preencher as três versões, verificar aviso, backup e restauração em novo nome sem aplicação. Autosave/API têm fluxo próprio.
- Testar cancelar varredura de efeitos, pânico e saída; conferir restauração condicional e se uma varredura antiga não executa após desligar. Nenhum teste real foi realizado nesta rodada.

## Material e nuvens (não executados no Roblox)

- Abrir o hub no Delta e em um ambiente de PC, registrar versão/commit e conferir
  se não há falha de `Enum.Material` na inicialização. Conferir menu, abas e
  engrenagens antes de testar qualquer ação.
- Executar em uma sessão com personagem presente e outra após respawn; verificar
  se há mensagens novas no console e se os painéis terminam a montagem.
- Em local de teste autorizado, mudar a cor de Terra (`Ground`) e confirmar o
  material afetado e a restauração ao sair. Não presumir resultado em terrenos
  feitos de partes ou materiais diferentes.
- Testar Nuvens com uma nuvem já existente e sem nenhuma: ligar, ajustar a
  cobertura, desligar e sair. Confirmar que a nuvem do jogo não é destruída e
  que os valores são restaurados quando não foram alterados pelo próprio jogo.
  Testar também mapas com várias nuvens e mudanças durante o uso; avisos já
  existentes no mapa não são necessariamente causados pelo hub.

## Restauração do menu e movimento do ESP (a executar no Delta)

- Comparar todas as abas, cabeçalho, ícones, opções e engrenagens com o original; verificar assets Lucide em diferentes redes. Testar rotação e telas pequenas.
- Em COMBATE, confirmar Fixar como padrão; selecionar Silencioso/Agressivo e verificar aviso sem ativação falsa. Tiro por paredes e Avisos de denúncias devem estar indisponíveis.
- No campo do cabeçalho, salvar um perfil novo e confirmar sobrescrita em dois toques; carregar em duas etapas e verificar o resumo na aba de configurações. Repetir sem APIs de arquivos.
- Em um ambiente autorizado com personagens R6 e R15, movimentar jogador e câmera, aproximar/afastar e mudar FOV: conferir caixa, texto, linhas, esqueleto e setas, inclusive alvo atrás da câmera, respawn e pânico. Comparar diversos valores de Atualizações do ESP e observar FPS/consumo em celular com muitos alvos e itens. Testar saída e nova execução.
- Confirmar que K/D e denúncias no ESP não fornecem dados inventados; testar estatísticas do perfil com e sem leaderstats.

Nenhum teste acima foi executado no Roblox/Delta; rigs e acessórios personalizados podem exigir ajustes da caixa.

## Remoção do bloqueio e prévia personalizada (a executar no Delta)

- Sem pânico, ativar e desativar movimento, mira e outras ações implementadas;
  testar atalhos e perfis. Conferir que não há aviso de bloqueio preventivo.
  VIP, recursos pendentes e integrações de saque/recarga ainda têm limitações.
- Ativar pânico com funções ligadas; confirmar interrupção e que só podem ser
  reativadas após sair do pânico. Verificar respawn e saída.
- Abrir ESP Jogador e NPCs: conferir boneco blocudo laranja, caixa e barra,
  mudar cores, estilos e opções e comparar com personagens reais. Um perfil
  antigo pode sobrescrever cores e opções padrão; testar um perfil novo.
- Repetir com câmera inclinada, enquanto move personagem e câmera, em R6/R15
  e rigs personalizados. Registrar vídeo e versão se persistirem tremores.

Não houve execução Roblox/Delta nesta rodada.
