# Plano e status

Atualize este arquivo ao final de cada incremento.
Legenda: ✅ concluído e validado · 🟡 em andamento · ⬜ pendente

## Etapas

| Etapa | Descrição | Status |
|---|---|---|
| A | Escolher ambiente de vibe coding, engine e ferramentas | ✅ (ADR-001, ADR-002) |
| B | Configurar projeto, controle de versão e primeiro executável | ✅ |
| C | Protótipo isométrico: movimentação, câmera, colisões, cenário (validar ADR-003/005/006/007) | ⬜ |
| D | Combate, vida, dano, primeiro inimigo, recompensas | ⬜ |
| D+ | **Teste de risco de rede cedo**: 2 instâncias locais trocando movimento e dano | ⬜ |
| E | Coleta, inventário, equipamentos, crafting | ⬜ |
| F | Região jogável com progressão, NPCs e mini boss | ⬜ |
| G | Efeitos mágicos, auras, buffs, debuffs, cosméticos | ⬜ |
| H | Testes de desempenho e riscos da arquitetura multiplayer | ⬜ |
| I | Primeiro coop LAN | ⬜ |
| J | Expansão: mapas, dungeons, chefes, montarias, eventos, progressão | ⬜ |

Reorganização em relação ao plano original: foi incluída a etapa **D+** (teste de rede
mínimo logo após o combate básico), para descobrir cedo problemas de autoridade e
sincronização antes que muitos sistemas dependam deles. Um efeito mágico simples pode
aparecer já na Etapa C/D para validar a técnica visual cedo.

## Etapa B — checklist

- [x] Repositório GitHub criado (`joaovictormendessilva/2d-isometric`)
- [x] Pacote de contexto (`CLAUDE.md`, `docs/`) criado
- [x] Godot 4.7.2 instalada no PC do João (`C:\Godot`)
- [x] Claude Code instalado e logado no VS Code (ou app desktop)
- [x] Repositório clonado no PC e aberto no Claude Code
- [x] Claude Code consegue executar a Godot pela linha de comando (`--version` → 4.7.2.stable)
- [x] Projeto Godot criado (estrutura de pastas, renderizador Compatibility, pixel art)
- [x] Primeira cena executável aberta pelo João com F5 (validado pelo João, 2026-10-21)
- [x] Primeiro commit do projeto Godot
- [x] Regras de Git: commits em inglês, sem trailers de atribuição (`.claude/settings.json`)

### Configuração do projeto (`project.godot`)

| Item | Valor | Origem |
|---|---|---|
| Renderizador | `gl_compatibility` (desktop e mobile) | ADR-003 |
| Resolução interna | 640×360 | ADR-007 |
| Janela inicial | 1280×720 (×2) — cabe em monitores pequenos; tela cheia escala ×3 em 1080p | ADR-007 |
| Stretch | `viewport`, aspecto `keep`, escala `integer` | ADR-007 |
| Filtro de textura padrão | Nearest | ADR-007 |
| Snap 2D ao pixel | ligado | pixel art |
| Aviso de declaração sem tipo | warning | GDScript tipado (ADR-002) |

### Estrutura de pastas

| Pasta | Conteúdo |
|---|---|
| `core/` | Lógica e estado de jogo sem nós visuais (IDs, comandos, regras, serviços) |
| `scenes/` | Cenas e scripts de apresentação, uma subpasta por cena (`scenes/main/`) |
| `data/` | Itens, receitas, habilidades, monstros, fórmulas, escalas por jogadores |
| `assets/` | `sprites/`, `tilesets/`, `vfx/`, `fonts/`, `audio/` (registrar em `05-assets-e-licencas.md`) |
| `shaders/` | Shaders de CanvasItem (brilho, contorno, pulsação…) |
| `tests/` | Testes e cenas de estresse executados pela linha de comando |
| `docs/` | Documentação; tem `.gdignore`, então a Godot **não** importa as referências |

### Validação da Etapa B (Claude, 2026-10-21)

- `--headless --path . --import`: sem erros nem avisos.
- `--headless --path . --quit-after 120`: imprime `[main] ready: viewport 640x360, renderer
  gl_compatibility`, código de saída 0.
- Execução com janela (RX 6600, OpenGL 3.3 Compatibility): mesma saída, sem erros.
- Validação visual (F5 no editor, João, 2026-10-21): janela 1280×720, texto legível, losango de
  tiles nítido (pixels em escadinha, sem borrão), painel Saída com 0 erros e 0 avisos.

## Funcionalidades

Nenhuma funcionalidade de jogo implementada ainda. A cena principal (`scenes/main/main.tscn`)
é só um marcador: texto de status e um losango de tiles 32×16 para conferir a nitidez do pixel.

## Problemas conhecidos

Nenhum.

## Pendências de decisão

- Coop: jogadores em regiões diferentes ao mesmo tempo? (ADR-005, decidir até a Etapa H)
- Drops: regra padrão pessoal vs. compartilhado por tipo de item (decidir na Etapa D/E)
- Nome do jogo e identidade visual própria (paleta, tom) — decisão criativa do João
