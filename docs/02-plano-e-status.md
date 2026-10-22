# Plano e status

Atualize este arquivo ao final de cada incremento.
Legenda: ✅ concluído e validado · 🟡 em andamento · ⬜ pendente

## Etapas

| Etapa | Descrição | Status |
|---|---|---|
| A | Escolher ambiente de vibe coding, engine e ferramentas | ✅ (ADR-001, ADR-002) |
| B | Configurar projeto, controle de versão e primeiro executável | ✅ |
| C | Protótipo isométrico: movimentação, câmera, colisões, cenário (validar ADR-003/005/006/007) | ✅ |
| D | Combate, vida, dano, primeiro inimigo, recompensas | ✅ |
| D+ | **Teste de risco de rede cedo**: 2 instâncias locais trocando movimento e dano | ✅ |
| E | Coleta, inventário, equipamentos, crafting | 🟡 E1 ✅; E2 ✅; E3 ✅; E4 (equipamentos) em andamento |
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
| `tests/` | Testes (`test_*.gd`, descobertos automaticamente) e benchmarks pela linha de comando |
| `tools/` | Scripts geradores (arte e regiões provisórias); não entram na lógica do jogo |
| `docs/` | Documentação; tem `.gdignore`, então a Godot **não** importa as referências |

### Validação da Etapa B (Claude, 2026-10-21)

- `--headless --path . --import`: sem erros nem avisos.
- `--headless --path . --quit-after 120`: imprime `[main] ready: viewport 640x360, renderer
  gl_compatibility`, código de saída 0.
- Execução com janela (RX 6600, OpenGL 3.3 Compatibility): mesma saída, sem erros.
- Validação visual (F5 no editor, João, 2026-10-21): janela 1280×720, texto legível, losango de
  tiles nítido (pixels em escadinha, sem borrão), painel Saída com 0 erros e 0 avisos.

## Etapa C — checklist (branch `stage-c/iso-prototype`)

- [x] Arte provisória gerada por código (`tools/generate_placeholder_art.gd`)
- [x] TileSet isométrico 32×16 (losango) com colisão na água
- [x] Região "Prado" (`scenes/regions/meadow/`) gerada com semente fixa: borda de água,
      lagos, caminhos de terra, 164 árvores e 74 pedras (`tools/generate_meadow_region.gd`)
- [x] Sessão com IDs de jogador/entidade (`core/game_session.gd`), sem jogador global
- [x] Personagem movido por intenções, velocidade igual em todas as direções no plano do chão
- [x] Colisão por "pegada" redonda no chão (`scenes/components/footprint.gd`); o personagem
      desliza em volta de árvores e pedras em vez de travar
- [x] Y-sort: personagem passa atrás/na frente de árvores conforme a posição dos pés
- [x] Câmera seguindo o jogador local, limitada à região; interpolação de física ligada
- [x] Painel de debug (F3): FPS, tempo de quadro, draw calls, posição
- [x] Ajustes pedidos pelo João: velocidade lateral reduzida (ADR-006) e objetos altos
      transparentes com o personagem atrás (ADR-010)
- [x] 13 testes automáticos passando (`tests/`), benchmark de desempenho registrado
- [x] Validação de sensação (movimento, colisão, câmera nas bordas, F3) — João, 2026-10-21
- [x] Merge na `main` — autorizado pelo João após os ajustes

## Etapa D — checklist (branch `stage-d/combat`)

- [x] Núcleo de combate em dados: `ActorStats` (vida, defesa, invulnerabilidade, recuo),
      `MeleeAttackData` (dano, alcance, arco, recuo, bote, preparação/recuperação),
      `CombatRules` (defesa com retorno decrescente, escala de vida por nº de jogadores)
- [x] Componentes reutilizáveis: `Health`, `MeleeAttacker`, `ActorFeedback` (flash,
      telegrafia, piscar, sumir)
- [x] Espada: golpe em arco na direção do mouse (ou do olhar no teclado/controle), segurar
      repete, recuo no alvo, rastro do golpe, números de dano
- [x] Slime: persegue, telegrafa (encolhe e avermelha), dá o bote, volta para casa se
      levado longe, morre e renasce (15–25 s) em 8 pontos da região
- [x] Drops pessoais (gosma) com ímã; inventário por jogador; HUD com vida e itens
- [x] Morte e renascimento do jogador no ponto de entrada (2,5 s)
- [x] 25 testes automáticos (o executor agora também reprova erros de script)
- [x] Estresse: 200 slimes em 3,1 ms/quadro (`docs/03-desempenho.md`)
- [x] Primeira rodada de feedback do João (2026-10-22): bote telegrafado e recuo aprovados;
      corrigidos a oscilação na borda da coleira e o stun-lock ao segurar o ataque (espada
      mais lenta: 0,48 s por golpe; slime resiste 40% do recuo e o bote não é interrompido).
      Valores ainda provisórios: o balanceamento real vem com mais armas e inimigos.
- [x] Evasão na coleira: criatura que desiste volta imune e recupera a vida em casa
      (pedido do João: antes dava para matá-la pelas costas enquanto voltava)
- [x] Validação de sensação do combate — João, 2026-10-22
- [x] Merge na `main` — autorizado pelo João

## Etapa D+ — checklist (branch `stage-d-plus/network-test`)

- [x] Rede com host autoritativo (ADR-012): cada jogador simula o próprio movimento e o host
      valida; criaturas e outros jogadores interpolados; criação pelo MultiplayerSpawner
- [x] Segurança de rede (ADR-013, regra permanente do João): porta só quando pedida (127.0.0.1
      por padrão), aperto de mão com versão, sem repasse entre clientes, validação de tudo
- [x] Dano, vida, morte, renascimento, imunidade, drops pessoais e inventário pela rede
- [x] Outros jogadores com tom esverdeado; situação da rede no canto superior direito
- [x] `tools/coop-local.bat`: abre host + cliente neste PC com dois cliques
- [x] 12 testes de rede (host e cliente no mesmo processo, ENet real em 127.0.0.1), 37 no total
- [x] Desempenho offline preservado (200 slimes: 3,2–3,3 ms); tráfego ~0,9 KB/s por entidade
- [x] Validação de sensação (João, 2026-10-22): movimento do outro jogador suave, sem atraso
      perceptível; drops individuais em cada janela
- [x] Merge na `main` — autorizado pelo João

## Etapa E — incrementos (branch `stage-e/gathering` para o E1)

- **E1 – Coleta** ✅: árvores de lenha, veios de cobre e carvalhos antigos; mãos, ferramentas,
  níveis de Lenhador e Minerador, regeneração, coop (ADR-014). 55 testes passando.
  Validado pelo João (2026-10-22).
- **E2 – Inventário** ✅: espaços com pilhas (12 sem mochila), janela livre (I/Tab/Esc),
  clicar para segurar, jogar fora e dividir, inventário cheio tratado, coop (ADR-016). Kit para
  testes em compilações de desenvolvimento. 69 testes passando. Validado pelo João (2026-10-22).
- **E3 – Crafting** ✅ (branch `stage-e/crafting`, ADR-017): na mão, na bancada e com NPCs.
  Passo 1 ✅ receitas em dados e fabricação decidida pelo host. Passo 2 ✅ coluna "Fabricar" na
  janela do inventário. Passo 3 ✅ bancada fabricada e colocada pelo jogador; receitas de
  bancada por perto. Ajustes do João: Fabricar recolhível e menu do botão direito (Dividir /
  Soltar). 80 testes. Validado pelo João (2026-10-22).
- **E4 – Equipamentos** 🟡 (branch `stage-e/equipment`, ADR-018): espaços estilo Terraria/Forager
  com 2 acessórios e mãos estilo Path of Exile. Passo 1 ✅ núcleo (espaços, regras de mão,
  trocas com o inventário, host decide; 88 testes). Passo 2 ⬜ atributos, mochila e espada como
  item. Passo 3 ⬜ tela de equipamento e itens de exemplo.

## Funcionalidades

- Andar pela região inicial (WASD, setas ou analógico esquerdo); F3 liga/desliga o debug.
- Árvores (e futuros prédios) ficam semitransparentes quando o personagem está atrás delas.
- Combate com espada (clique esquerdo, J ou botão X do controle; segurar repete) contra slimes;
  gosma cai como drop pessoal e aparece no HUD (canto inferior esquerdo) com a vida.
- Coop local de teste: `tools/coop-local.bat` abre duas janelas (host + cliente) neste PC.
- Inventário: tecla I ou Tab (botão Y), Esc fecha; arraste a janela pelo título; clique pega e
  põe itens, clique fora joga no chão, botão direito abre um menu (Dividir / Soltar).
- Fabricar: coluna à direita no inventário (clique no título recolhe/abre); clique numa
  receita acesa fabrica (machado e picareta de pedra e bancada, na mão; machado de cobre perto
  de uma bancada). Passar o mouse mostra o que falta.
- Bancada: pegue-a no inventário e clique no chão (prévia verde = pode; vermelha = não pode).
  Bloqueia a passagem; ainda não dá para recolher (pendência).
- Kit de testes: no editor (F5) o jogador já começa com itens (`data/debug/starter_kit.tres`,
  liga/desliga em `game/debug/starter_kit` no project.godot). Jogo exportado nunca tem kit.
- Coleta: tecla E (botão A) perto de uma árvore de lenha (copa amarelada) ou veio de cobre
  (pedra com pontos laranja); níveis de coleta no HUD.

## Preparação de qualidade visual (`chore/skills`, 2026-10-22)

- Skills do projeto em `.claude/skills/` (movimento, pixel art, game feel, UI/UX, checklist)
  e ferramentas: folha de quadros, conferência de sprite, tema da UI gerado de tokens.
- Achados para a Etapa G e a arte final: golpe da espada sem pose nem antecipação e rastro
  quase invisível; silhuetas de frente e costas do personagem iguais.

## Problemas conhecidos

- Arte e mapa são provisórios (placeholders gerados por código).
- O personagem só tem 2 quadros (frente/costas, espelhados); sem animação de caminhada além
  de um balanço de 1 px.
- O painel de debug mostra tempos altos nos primeiros quadros (carregamento); o custo em
  regime está em `docs/03-desempenho.md`.
- Criaturas não têm busca de caminho: contornam obstáculos redondos, mas podem ficar presas
  atrás de lagos. Avaliar navegação quando houver mapas mais fechados.
- Corrigido (`fix/death-cancels-attack`): criatura que morria no meio da preparação ainda dava
  o bote ("fantasma", sem acertar). Agora a morte encerra qualquer ataque.
- O recuo da espada empurra o slime um pouco para fora do alcance (ele resiste 40%): é
  preciso avançar a cada golpe. Intencional (dá ritmo); ajustável em `data/`.

## Pendências de decisão

- Coop: jogadores em regiões diferentes ao mesmo tempo? (ADR-005, decidir até a Etapa H)
- Drops: regra padrão pessoal vs. compartilhado por tipo de item (decidir na Etapa D/E)
- Nome do jogo e identidade visual própria (paleta, tom) — decisão criativa do João

## Direção para a Etapa E (João, 2026-10-22)

- **Coleta no estilo Albion**: árvores, minérios e outros pontos de coleta no mundo, cada tipo
  com a **ferramenta própria** (machado, picareta...) e **especialização** por tipo (coletar
  melhora a coleta daquele tipo). Pontos **regeneram** com o tempo.
- **Monstros também dropam** (diferente de Albion): tabelas de drop com **chances**, raros
  inclusos, no estilo Grand Fantasia e MMORPGs antigos — "a magia do grind".
- Drops caem no chão e o jogador vai até eles (feito em `fix/drop-placement`), com raio de
  coleta ("ímã") nos atributos do jogador para equipamentos futuros aumentarem.

## Direção de combate (para ter em mente)

- Referências: **Albion Online** e **V Rising** no **jeito de lançar as habilidades** (o "cast"):
  teclas de habilidade, mira no cursor, habilidades em linha e em área com aviso no chão,
  tempo de conjuração. Correção do João: NÃO significa que cada arma define os ataques (isso
  foi coincidência entre os dois jogos); de onde vêm as habilidades fica para decidir.
  Registrar ADR quando o sistema de habilidades começar.

## Textos e idiomas

- Feito (`chore/localization`, ADR-015): todos os textos do jogador vêm de
  `data/i18n/texts.csv` (pt-BR e en). `-- --lang=en` testa em inglês.

## Ideias futuras (backlog criativo)

Ideias do João para considerar nas etapas certas — não são compromissos ainda.

- **Escolher em que mão segurar** (escudo/tomo à direita ou à esquerda, mudando a animação):
  adiado (ADR-018) — com o personagem espelhado ao virar, dobraria a arte de combate por 2–3 px
  de diferença. Reavaliar se os sprites crescerem.
- **Variedade de armas** (arco + aljava, cajados, tomo): regras de mão prontas no E4; o
  comportamento precisa do sistema de habilidades e projéteis (etapa própria, a definir).

- **Atravessar água**: buff, poção ou montaria que permite andar sobre a água (ou nadar),
  abrindo atalhos e áreas escondidas. Técnica prevista: mover a colisão da água para uma
  camada de física própria (hoje está em "world") e o efeito tiraria essa camada da máscara
  de colisão do personagem. (Etapa E/J — montarias)
