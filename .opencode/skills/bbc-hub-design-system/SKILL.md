---
name: bbc-hub-design-system
description: Design system visual oficial do menu BBC HUB (Roblox/Delta) - tokens de cor exatos (#FF8C00, fundos derivados de HSV, UIStroke), icone "3 setinhas" (sliders-horizontal) ao lado de cada item, layout da tela dividida PREVIA (boneco R6 100x108 com logo BBC HUB no tronco, "Jogador" acima, barra de vida a esquerda, "1133m" abaixo, grade 3x4 de quick-toggles sem cortar texto) + AJUSTES DO JOGADOR com hints de toque. Use SEMPRE que criar ou editar qualquer UI visual em src/ (janela, modais, preview, ESP, widgets, hint boxes) para manter consistencia com o menu existente. Complementa a skill bbc-hub-delta (arquitetura/build).
---

# BBC HUB — Design System Visual

Fontes da verdade: `src/ui/theme.lua` (tokens), `src/ui/components.lua` (rows + gear + modais),
`src/ui/window.lua` (janela + cabeçalhos de modal), `src/features/visuals.lua` (Prévia ESP).
Esta skill cobre **apenas** o visual; arquitetura/build/nil-safety estão na skill `bbc-hub-delta`.

## 1. Tokens de cor (tema "Orange", modo neutral — theme.lua)

Os fundos NÃO são hex fixado: `preset(accent, "neutral")` deriva tudo de `Color3.fromHSV(0, 0, V)`.

| Token | Origem (theme.lua) | Hex resultante | Uso |
|---|---|---|---|
| `Accent` | `RGB(255, 130, 25)` (preset Orange) | `#FF8219` | Strokes ativos, toggles on, fill de slider, seleção |
| `Background` | `HSV(0,0,0.04)` | ≈ `#0A0A0A` | Fundo da janela, overlay de modal |
| `Surface` | `HSV(0,0,0.055)` | ≈ `#0E0E0E` | Groupboxes, caixas de modal |
| `Surface2` | `HSV(0,0,0.08)` | ≈ `#141414` | cfgBar, searchBox, botões off |
| `Surface3` | `HSV(0,0,0.125)` | ≈ `#202020` | Track de slider, checkbox off, toggle off |
| `Stroke` | `HSV(0,0,0.2)` | ≈ `#333333` | UIStroke padrão de rows/pills |
| `Text` / `Muted` | `RGB(242,242,242)` / `RGB(150,150,150)` | `#F2F2F2` / `#969696` | Texto principal / secundário |

Laranjas da Prévia ESP (visuals.lua, fixos por design):
- `#FF8C00` = `RGB(255,140,0)` — `BOX_STROKE_COLOR` (caixa/contorno do ESP)
- `#FF8200` = `RGB(255,130,0)` — `CHAMS_COLOR` e a borda do `previewFrame`

> O tom `#121216` visto em screenshots é a família de fundo (Surface2 ≈ `#141414`) renderizada
> sob strokes/transparências. **Nunca** escreva `Color3.fromRGB`/hex direto em UI nova: use
> `bind(x, "BackgroundColor3", "Surface2")` / `bind(x, "TextColor3", "Text")` para respeitar a troca de tema.
> `UIStroke` padrão: `stroke(x, "Stroke", 0.2)` ou `stroke(x, "Accent", 0.1)`; espessura 1 (2 em elementos focados).

## 2. Ícone "3 setinhas" (gear) ao lado de cada item

- Toda row de toggle tem o ícone **`sliders-horizontal`** (as "3 setinhas") à direita: 20px,
  `ZIndex = 4` (`GEAR_ZINDEX`), dentro de botão touch de **44×44** (`TOUCH_TARGET_SIZE`),
  `AnchorPoint (1, 0.5)`, `Position (1, -62, 0.5, 0)` → `-(padding 12 + 44 + gap 6)`.
- Fonte única: `createGearButton()` em `ui/components.lua`. Ícones são Lucide via `Utils.icon`
  (`BBC.lucide`, com fallback de glyph quando o download falha).
- Rows com modal (Jogador/NPCs): o gear **fica visível** e é o **único** gatilho do modal —
  o clique na linha/pill só **liga e desliga** o toggle (a aba VISUAIS continua aberta).
  Rows com submenu (Corpo/Recipiente): gear abre o `subPanel`.
- Estado ativo: `ImageColor3` = `Library.Theme.Accent` quando aberto, `Text` quando fechado.

## 3. Tela dividida do modal ESP (PRÉVIA + AJUSTES DO JOGADOR)

Janela 640×388 com `UIScale` de ajuste (0.45–1.3). `_content` em `(160, 54)`, tamanho `472×326`.
O modal é um overlay `ZIndex 20` com 2 caixas `0.5, -4` cada, header de **28px** + divisória
`(8, 28, 1, -16)`. Cabeçalhos posicionados manualmente (sem UIListLayout+spacer — isso
transbordava os ícones para a coluna vizinha):

- Coluna esquerda: título **"PRÉVIA"** à esquerda (8px) e 3 ícones de ação
  (`layout-grid`, `lock`, `star`) alinhados à direita **dentro** da coluna (`(1, -10, 0, 3)`,
  botões 24×24, gap 4). Coluna direita: título à esquerda das ações (`sliders-horizontal`, `x`).

### Coluna esquerda — PRÉVIA (visuals.lua `SetupCharacterPreview`)
- `previewFrame` **200×268**, fundo `RGB(15,15,20)`, canto 8, `UIStroke` laranja
  `RGB(255,130,0)`, `ClipsDescendants = true`; `previewContainer` = escala `0.95` disso.
- **Boneco R6** (`holder`) **100×108** em `(0.5, 0.3)` (âncora 0.5,0.5) — terço superior,
  sem clipar a cabeça e sem tocar a grade. Partes em escala do holder:
  Head 0.28×0.18 @(0.36,0.02) · Torso 0.46×0.36 @(0.27,0.22) · Braços 0.20×0.36
  @(0.04/0.76, 0.22) · Pernas 0.21×0.38 @(0.27/0.52, 0.60). Canto 8 na cabeça, 4 no resto.
  Cada parte tem **UIStroke escuro de 1px** (preto, transparência 0.35, **sem** `bind` de tema —
  é o mesmo contorno preto do Chams no jogo).
- **Sombra de chão**: elipse (`UICorner` 1,0 + `UIGradient` 1→0→1) 64%×5% sob os pés,
  `ZIndex 1` (atrás do boneco).
- **Logo "BBC HUB" no tronco**: `ImageLabel` se `BBC.Config.LogoAssetId` existir; senão
  `TextLabel` "BBC HUB" `TextScaled`, branco, transparência 0.25, 92%×55% do Torso.
- Overlays ligados aos toggles (defaults: chams/box/skeleton/name/distance/healthbar ON):
  - **"Jogador"** (nameLabel): 16px bold, âncora `(0.5, 1)` em `(0.5, -0.03)` — acima da cabeça.
  - **"1133m"** (distanceLabel): 10px, âncora `(0.5, 0)` em `(0.5, 1.03)` — abaixo dos pés.
  - **Barra de vida à esquerda**: `healthBarBg` 4px de largura, altura em **escala** `(0,4,1,0)`,
    âncora `(1,0)` em `(0,0)`; fill por ratio (`#2DCDCE` default, assume a cor do chams).
  - **Contorno**: `boundingBox` (frame 1,1 do holder) com `UIStroke` `#FF8C00`.
  - **Esqueleto**: linhas com comprimento em **PIXELS** (`lineSpec` usa `holder.AbsoluteSize`);
    nunca compute distância na escala 0–1 (linhas ficam sub-pixel/invisíveis). Re-sincroniza
    em `GetPropertyChangedSignal("AbsoluteSize")`. Juntas nos **centros dos membros**:
    pescoço `(0.5,0.21)`, mãos `(0.14/0.86, 0.58)`, pés `(0.375/0.625, 0.98)`.
- **Grade 2×4 de quick-toggles** (8 botões: Destaque, Caixa, Nome, Barra vida | Vida,
  Distância, Linhas, Esqueleto): `toggleButtonsFrame` `Size (1, 0, 0, 64)`, fundeado
  `(0.5, 0, 1, -3)` → **64px = 2×30 + 1×4 de gap**, ~8px de respiro até a borda laranja.
  `UIGridLayout` células **44×30**, gap 4, 4 células por linha (4+4), alinhamento central.
  Célula: `TextScaled = true` + `UITextSizeConstraint` (Min 7, Max 10) para **nunca cortar**
  rótulos longos ("Distância"). Botão on = `Accent` + texto branco; off = `Surface2` + `Text`,
  stroke `Accent`/`Stroke`. Features **K/D, Denúncias e Setas não existem** — removidas
  do ESP, da prévia e dos ajustes do jogador.

### Coluna direita — AJUSTES DO JOGADOR
- Scroll a partir de `y=32`, altura `1, -32-50` (reserva 40px de rodapé).
- **Rodapé fixo com hints de toque** (right-aligned, 10px, `Muted`):
  **"Toque: ativar" · "Arraste: mover" · "Segure: ajustes"**.
- Conteúdo: `Foldout` "Configurações gerais" (Distância máx., Tamanho do texto,
  Distância/Vida da prévia, LOD) + um Toggle por feature do ESP, cada um com gear →
  ColorPicker/sliders/dropdowns.

## 4. Checklist de consistência visual (UI nova em src/)

1. Cores sempre via `bind(...)` com token do tema — zero hex/RGB hardcoded.
2. `pad(f, left, right, top, bottom)` — cuidado com a ordem dos argumentos.
3. Responsivo com `UDim2.fromScale` + `UISizeConstraint`/`UIAspectRatioConstraint`; validar em 640×388.
4. Todo painel: `corner(x, raio)` + `stroke(x, ...)`; cantos padrão 4 (rows) / 6 (janela) / 8 (preview).
5. ZIndex: conteúdo 1–3, gear 4, labels/overlays 5+, tooltip 50+, overlay de modal 20.
6. Painéis expansíveis (preview, ESP engine): destruir instâncias antigas e desconectar sinais antes de recriar.
7. Texto em célula pequena: sempre `TextScaled` + `UITextSizeConstraint`, nunca `TextSize` fixo grande.
8. Ícones: sempre `Utils.icon` (Lucide + fallback); gear de row sempre `createGearButton` (posição/touch padronizados).
