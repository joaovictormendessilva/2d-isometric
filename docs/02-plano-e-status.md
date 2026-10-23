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
| E | Coleta, inventário, equipamentos, crafting | ✅ |
| F | Região jogável com progressão, NPCs e mini boss | 🟡 F1 ✅; F2 ✅; F3 ✅ (moedas, poção, receitas de NPC); F4 a seguir |
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
      lagos, caminhos de terra, 164 árvores e 74 pedras (hoje `tools/generate_regions.gd`)
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
- **E4 – Equipamentos** ✅ (branch `stage-e/equipment`, ADR-018): espaços estilo Terraria/Forager
  com 2 acessórios e mãos estilo Path of Exile. Passo 1 ✅ núcleo (espaços, regras de mão,
  trocas com o inventário, host decide). Passo 2a ✅ bônus de atributos, arma define o golpe
  (espada vestida ao entrar; sem arma, soco, nunca mais rápido que a espada), equipamento
  enviado a todos. Passo 2b ✅ mochila soma espaços; tirar só com eles vazios (93 testes).
  Passo 3 ✅ coluna Equipamento no inventário (dourado onde o item da mão cabe, "Equipar" no
  menu, dica com bônus), receitas com rolagem e 4 itens de bancada (escudo de madeira, elmo de
  cobre, mochila simples, anel magnético). Correções do teste do João: trocar equipamento não
  cura nem fere (vida atual não muda) e a defesa pequena agora reduz dano (97 testes).
  Validado pelo João (2026-10-22).

## Etapa F — incrementos

Ordem proposta (cada um com validação do João antes do próximo):

- **F1 – Save** ✅ (branch `stage-f/save`, ADR-019): progresso de cada personagem no mundo do
  host (escolha do João), estruturas colocadas e pontos de coleta; identidade por perfil;
  reconexão devolve o personagem. 105 testes. Validado pelo João, inclusive no coop (2026-10-22).
- **F2 – Segunda região** ✅ (branch `stage-f/regions`): no coop cada jogador vai para onde quiser
  (escolha do João, se o host aguentar). F2a: segunda região e passagem, sozinho (regiões já
  prontas para várias ativas no host). F2b: benchmark do host com 2–4 regiões ativas. F2c: coop
  com jogadores em regiões diferentes (cada cliente só recebe a sua).
  F2a ✅ implementado (ADR-020): floresta densa (mais escura, 8 carvalhos antigos, 10 pontos de
  slime), passagens nas bordas (campina leste ↔ floresta oeste), região deixada guardada, save
  lembra a região. 110 testes. Validado pelo João (2026-10-22).
  F2b ✅ executado (`tests/benchmark_regions.gd`): 4 regiões ativas em combate ~3 ms no PC de
  dev, viável (detalhes em `docs/03-desempenho.md`).
  F2c ✅ implementado (ADR-020): cada região num mundo próprio; no coop cada jogador vai para
  onde quiser e cada cliente só recebe a própria região; viajar recria o personagem lá. 111
  testes. Validado pelo João, inclusive no coop (2026-10-22). Correção do teste dele: os textos
  do mundo (dano, itens, "[E]") sumiam; agora há verificação com imagem (`tests/render_checks.gd`).
- **F3 – NPC** ✅ (branch `stage-f/npc`, ADR-021): F3a moedas e mercador (compra e venda); F3b
  poção de vida (cura do jogador); F3c receitas de NPC.
  F3a ✅ implementado: carteira separada do inventário (escolha do João), mercador perto da
  entrada da campina, loja com o inventário ao lado, venda pelo botão direito, moedas no save e
  no coop pelo host. Correção do teste dele: mochila depois de viajar. 121 testes. Validado
  pelo João (2026-10-22).
  F3b ✅ implementado (branch `stage-f/potion`, ADR-022): poção de vida (cura 40, espera de 10 s),
  vendida pelo mercador; tecla Q (LB) bebe, ou "Usar" no menu do inventário; poção e espera no
  HUD; "+40" e brilho verdes; no coop o host decide. 127 testes. Validado pelo João
  (2026-10-22).
  F3c ✅ implementado (branch `stage-f/npc-recipes`, ADR-023): receitas que se aprendem com NPC
  (escolha do João: aprender e levar). O mercador ensina a poção de vida (40 moedas); depois ela
  se fabrica em qualquer lugar com 3 gosmas (João: sem bancada). Fica no save e no coop o
  host decide. 133 testes. Validado pelo João (2026-10-22).
- **F4 – Mini boss** ⬜: ataques com aviso no chão, fases, drop especial.
- **F5 – Ciclo de progressão** ⬜: algo liberado pelo chefe (área ou receita) e balanceamento.

## Funcionalidades

- Andar pela região inicial (WASD, setas ou analógico esquerdo); F3 liga/desliga o debug.
- Árvores (e futuros prédios) ficam semitransparentes quando o personagem está atrás delas.
- Combate com espada (clique esquerdo, J ou botão X do controle; segurar repete) contra slimes;
  gosma cai como drop pessoal e aparece no HUD (canto inferior esquerdo) com a vida.
- Coop local de teste: `tools/coop-local.bat` abre duas janelas (host + cliente) neste PC.
- Inventário: tecla I ou Tab (botão Y), Esc fecha; arraste a janela pelo título; clique pega e
  põe itens, clique fora joga no chão, botão direito abre um menu (Equipar / Dividir / Soltar).
- Equipamento: coluna à esquerda no inventário; clique num espaço com o item na mão veste, com
  a mão vazia tira. Começa com espada; sem arma, soco. Bônus aparecem ao passar o mouse.
- Fabricar: coluna à direita no inventário (clique no título recolhe/abre); clique numa
  receita acesa fabrica (machado e picareta de pedra e bancada, na mão; machado de cobre perto
  de uma bancada). Passar o mouse mostra o que falta.
- Bancada: pegue-a no inventário e clique no chão (prévia verde = pode; vermelha = não pode).
  Bloqueia a passagem; ainda não dá para recolher (pendência).
- Kit de testes: no editor (F5) o jogador já começa com itens (`data/debug/starter_kit.tres`,
  liga/desliga em `game/debug/starter_kit` no project.godot). Jogo exportado nunca tem kit.
- Save: o mundo é guardado sozinho (ao fechar a janela, quando alguém sai e a cada 30 s) em
  `%APPDATA%\Godot\app_userdata\2D Isometric\saves\world.json`. Para começar do zero, apague
  esse arquivo. No coop, o progresso do amigo fica no save de quem hospeda.
- Regiões: no fim do caminho de terra na borda leste da campina fica a passagem para a floresta
  (e na borda oeste da floresta, a volta). No coop cada um viaja sozinho; quem volta ao jogo
  começa na região onde estava.
- Mercador (F3a): perto da entrada da campina (chapéu marrom, túnica verde). Tecla E perto dele
  abre a loja e o inventário: clique numa oferta compra; botão direito num item do inventário
  vende ("Vender 1" / "Vender tudo"). Moedas aparecem no inventário e na loja. Preços em
  `data/npcs/merchant.tres` (compra) e no `sell_price` de cada item (venda).
- Poção de vida (F3b): tecla Q (botão LB) bebe uma poção (cura 40; espera de 10 s entre
  poções); também pelo botão direito no inventário → "Usar". O quadrado ao lado da vida mostra
  quantas há e os segundos de espera. Vida cheia não gasta poção. Compre no mercador (15 moedas);
  o kit de testes já traz 5. Valores em `data/items/health_potion.tres`.
- Receitas de NPC (F3c): na loja do mercador, seção "Receitas": clique em "Receita: Poção de vida"
  (40 moedas) para aprender. Depois a poção aparece acesa na coluna Fabricar (3 gosmas, em
  qualquer lugar). Antes de aprender ela fica apagada com o motivo na dica. Fica salvo.
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
- Corrigido (F3a, relato do João): depois de viajar entre regiões, vestir a mochila não abria os
  espaços e tirá-la não os fechava (o tamanho usava os bônus do equipamento anterior; o
  personagem é recriado a cada viagem). Agora o tamanho vem direto do equipamento vestido.
- Corrigido (`fix/death-cancels-attack`): criatura que morria no meio da preparação ainda dava
  o bote ("fantasma", sem acertar). Agora a morte encerra qualquer ataque.
- O recuo da espada empurra o slime um pouco para fora do alcance (ele resiste 40%): é
  preciso avançar a cada golpe. Intencional (dá ritmo); ajustável em `data/`.

## Pendências de decisão

- ~~Coop: jogadores em regiões diferentes ao mesmo tempo?~~ Sim (João, 2026-10-22); benchmark da F2b confirmou que o host aguenta.
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
- **Cura do jogador** (E4): hoje a vida só volta ao renascer. Vestir item de vida deixa a
  diferença para curar — poções, regeneração fora de combate etc. entram com consumíveis/NPCs.
- **Dano final e tela de atributos** (pergunta do João, E4): hoje o dano é o da arma (espada
  10, soco 5). Quando houver atributos de dano e buffs (habilidades/Etapa G), o dano final vira
  fórmula em `CombatRules` (base da arma × modificadores) e uma tela de atributos mostra os
  valores finais (vida, defesa, dano, velocidade, ímã); a dica do item continua com a base.
- **Variedade de armas** (arco + aljava, cajados, tomo): regras de mão prontas no E4; o
  comportamento precisa do sistema de habilidades e projéteis (etapa própria, a definir).

- **Atravessar água**: buff, poção ou montaria que permite andar sobre a água (ou nadar),
  abrindo atalhos e áreas escondidas. Técnica prevista: mover a colisão da água para uma
  camada de física própria (hoje está em "world") e o efeito tiraria essa camada da máscara
  de colisão do personagem. (Etapa E/J — montarias)
