---
name: luau-static-analysis
description: Analisa código Luau estaticamente — detecção de tipos, erros de sintaxe, variáveis não usadas, símbolos não resolvidos e padrões inseguros — sem depender de ambiente de execução Roblox Studio.
---

# Luau Static Analysis

Use quando precisar inspecionar código Luau/Lua sem executá-lo: detecção de tipos, erros de sintaxe, variáveis não usadas, símbolos não resolvidos, dead code e padrões inseguros.

## Quando usar

- Antes de injetar ou buildar um bundle, verifique se há erros de sintaxe ou tipos incompatíveis.
- Audite dependências e imports estáticos para garantir que não há símbolos não resolvidos.
- Detecte código morto (funções/variáveis definidas mas nunca usadas) para reduzir o tamanho do bundle.
- Verifique padrões inseguros (uso de `getfenv`, `setfenv`, `loadstring`, `require` com input do usuário, etc.).

## Regras

1. **Não execute o código.** Toda a análise é estática (leitura de arquivos, regex, AST leve). Nunca rode `loadstring`, `require` ou `dofile` em código não confiável durante a análise.
2. **Resolva imports estaticamente.** `require("./mod")` deve ser resolvido para o arquivo local correspondente, não para runtime do Roblox.
3. **Detecte símbolos não resolvidos.** Identifique funções/variáveis usadas mas nunca definidas nos arquivos fornecidos.
4. **Flaggue padrões perigosos.** `getfenv`/`setfenv`/`loadstring` são removidos do Luau; `require` com string de usuário é vetor de injeção.
5. **Medição de complexidade.** Conte funções por arquivo, níveis de aninhamento e upvalues para evitar exceder limites do Luau (200 locais, 200 upvalues, 255 registros).

## Saída esperada

Um relatório com:
- Erros de sintaxe (arquivo:linha:coluna)
- Símbolos não resolvidos
- Código morto candidato
- Padrões inseguros com severidade
- Métricas de complexidade por arquivo
