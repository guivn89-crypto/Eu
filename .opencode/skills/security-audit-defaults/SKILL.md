---
name: security-audit-defaults
description: Audita código-fonte por configurações inseguras por padrão (secrets de fallback, credenciais default, fail-open, crypto fraca, acesso permissivo e vazamento de debug), sem depender de ambiente Roblox Studio.
---

# Security Audit — Insecure Defaults

Audita uma base de código por configurações inseguras por padrão, traceando cada candidato antes de reportar.

## Quando usar

- Antes de commitar ou gerar o `dist/menu_bundle.lua`, verifique se não há senhas hardcoded, credenciais default ou chaves expostas.
- Audite wrappers de configuração que possam retornar valores inseguros como fallback.
- Detecte criptografia fraca (MD5, SHA1, DES) e controle de acesso permisivo (CORS `*`, ACL pública, `0o666`).
- Flaggue vazamento de debug (stack traces expostos em respostas) e switches fail-open (`REQUIRE_AUTH=false`).

## Categorias de detecção

| Categoria | Exemplo | O que procurar |
|-----------|---------|----------------|
| Fallback secrets | `SECRET = env.get('KEY') or 'dev'` | Lookup com fallback inseguro |
| Default credentials | `admin` / `admin123` seedado | Usuário/senha default no código |
| Fail-open switches | `getenv('REQUIRE_AUTH', 'false')` | Controle de segurança desligado por padrão |
| Weak crypto | `hashlib.md5(password)` | Algoritmos criptográficos fracos |
| Permissive access | `ACL='public-read'`, `0o666`, CORS `*` | Controle de acesso excessivamente aberto |
| Debug leakage | `traceback.format_exc()` na resposta | Stack traces ou detalhes internos expostos |

## Regras

1. **Não considere ausência de variável de ambiente como refutação.** Um valor inseguro sem condicional permanece inseguro.
2. **Deduplicação por `categoria:arquivo:linha`.** Duas categorias podem flaggar a mesma linha; cada uma conta separadamente.
3. **Verifique alcançabilidade.** Apenas reporte se o código inseguro pode ser executado em produção.
4. **Cite o sink.** Para cada achado, indique onde o valor inseguro atinge uma decisão de segurança.
5. **Nenhuma dependência de Roblox Studio.** Toda a análise é sobre código-fonte, não sobre o ambiente de execução.

## Saída esperada

Relatório com severidade, remediação e cobertura por categoria, sem falsos positivos não verificados.
