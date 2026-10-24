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
| F | Região jogável com progressão, NPCs e mini boss | ✅ (save, 2 regiões, NPC, Rei Slime, coroa do núcleo) |
| G | Efeitos mágicos, auras, buffs, debuffs, cosméticos | ✅ (buffs e debuffs; habilidades: projétil e explosão arcanos, ameaça; auras e cosméticos: qualidade dos efeitos, aura da coroa, transmog, carga de auras) |
| H | Testes de desempenho e riscos da arquitetura multiplayer | ✅ (carga de projéteis, itens no chão, coop com 4 jogadores, riscos de rede: paredes e inundação) |
| I | Primeiro coop LAN | 🟡 I1 ✅ (código da partida) · I2 ✅ (criptografia) · I3 ✅ (tela de partida) · I4 ⬜ (adiada para o final: falta o 2º PC; com jogo exportado) |
| J | Expansão: mapas, dungeons, chefes, montarias, eventos, progressão | 🟡 J1 (dungeon) e J2 (arco e cajado) concluídas; J3a (montaria) validada; J4a (chefe errante) validada; J5a (pedras de portal) validada; J6a (maestria por arma) em validação |

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
      `AttackData` (dano, alcance, arco, recuo, bote, preparação/recuperação),
      `CombatRules` (defesa com retorno decrescente, escala de vida por nº de jogadores)
- [x] Componentes reutilizáveis: `Health`, `Attacker`, `ActorFeedback` (flash,
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
- **F4 – Mini boss** ✅ (branch `stage-f/mini-boss`, ADR-024): o **Rei Slime** (escolha do João).
  F4a: salto com aviso no chão, barra de vida de chefe, drop especial; F4b: fase 2 (divide-se em
  slimes pequenos e salta mais rápido).
  F4a ✅ implementado: clareira no leste da floresta; o chefe salta em quem está a meia distância
  (círculo vermelho no chão enche até a queda; sair dele evita o dano), golpeia quem está perto,
  barra de vida no alto da tela, Núcleo do Rei Slime ao morrer, renasce em 5 min. No coop o host
  decide e os clientes veem o salto. 138 testes.
  Correção do teste do João (todos os slimes): o bote virou investida que acerta no avanço e
  começa de mais longe; apanhando, o aviso vermelho não some mais.
  F4b ✅ implementado: na metade da vida o Rei Slime se enfurece (salta mais rápido, barra
  laranja, aviso na tela) e cada queda solta 2 slimes (no máximo 4, sem drops; somem com ele).
  Correção do teste do João: os filhotes seguem o chefe e atacam o alvo dele (antes, correndo um
  pouco, eles ficavam parados). O Rei Slime é banco de testes; as mecânicas são o core.
  144 testes. Validado pelo João (2026-10-23).
- **F5 – Ciclo de progressão** ✅ (branch `stage-f/progression`): algo liberado pelo chefe e balanceamento.
  F5a ✅ implementado (escolha do João: receita de equipamento): o Núcleo do Rei Slime fabrica na
  bancada a **Coroa do Rei Slime** (cabeça: +20 de vida, +3 de defesa; o elmo de cobre dá +10/+2)
  com 1 núcleo, 8 gosmas e 4 cobres. Teste genérico: todo drop exclusivo de chefe tem que servir
  para alguma receita. 146 testes. Validado pelo João (2026-10-23): ciclo chefe → núcleo → coroa
  funcionando; a dificuldade atual (slimes com investida, chefe em 2 fases) é a desejada, então o
  balanceamento fica como está (números provisórios em `data/`, revistos com mais conteúdo).

## Etapa G — incrementos

Ordem combinada com o João (2026-10-23), cada um validado por ele antes do próximo:

- **G1 – Buffs e debuffs** ✅ (branch `stage-g/status-effects`): base de efeitos com duração,
  em dados, para jogadores e criaturas; o host decide.
  - G1a ✅ implementado (ADR-025): núcleo (efeito em `data/`: duração, bônus de atributos,
    dano/cura por tick; reaplicar renova), aplicado pelo host e enviado aos clientes; vai no save.
    Primeiros efeitos: veneno (3 por segundo, 6 s) e rapidez (+25% de velocidade, 30 s). Ainda
    sem nada visível no jogo (vem na G1b/G1c). 154 testes.
  - G1b ✅ implementado: acima da vida, um quadrado por efeito com ícone e segundos (borda verde =
    buff, vermelha = debuff); partículas no ator (bolhas verdes subindo no veneno, rastro azul nos
    pés na rapidez; em dados, no máximo 8 por efeito); aviso flutuante ao ganhar um efeito; dano de
    veneno em amarelo-esverdeado. Captura: `--effect=<id>` (tela) e `--effects=` (folha de
    quadros). 155 testes.
  - G1c ✅ implementado: **slime venenoso** (escolha do João; verde-limão, só na floresta, metade
    dos pontos alternados com o slime comum, mesmos atributos e bote; o bote que acerta envenena;
    solta 1 a 3 gosmas) e **poção de rapidez** (mercador, 25 moedas; +25% de velocidade por 30 s;
    espera própria de 5 s, não divide com a poção de vida; vale beber com vida cheia). Golpes de
    qualquer criatura podem aplicar efeitos (`on_hit_effects` nos dados). 159 testes.
    Validado pelo João (2026-10-23): rapidez conferida pelo painel F3, veneno e HUD ok.
- **G2 – Primeira habilidade mágica** ✅ (na `main`; branches `stage-g/first-ability` e
  `stage-g/arcane-blast`; ADR-026, ADR-027): habilidades
  **aprendidas e equipadas** (escolha do João, 2026-10-23: livre para montar builds; mago e arqueiro
  são escolhas, não classe fixa). 4 espaços nas teclas 1–4, mira no cursor, só tempo de recarga
  (sem mana, como no V Rising).
  - G2a ✅ (validado pelo João, 2026-10-23): núcleo e o **Projétil arcano** (primeira habilidade): dados em
    `data/abilities/`, livro de habilidades por jogador, lançar decidido pelo host com recarga
    (2,5 s), projétil violeta que acerta o primeiro inimigo no caminho (14 de dano, alcance 170);
    aprender lendo o "Tomo: Projétil arcano" (mercador, 50 moedas; vai para a tecla 1); coop
    (o dono vê na hora, o host decide) e save. Ainda sem barra no HUD (G2b). 169 testes.
  - G2b ✅ (validado pelo João, 2026-10-23): barra de habilidades embaixo no meio da tela (4 quadrados com ícone, a
    tecla embaixo e a recarga escurecendo o ícone com os segundos); dica com dano e recarga;
    botão direito numa tecla escolhe qual habilidade aprendida vai nela (ou esvazia). Pendente:
    trocar de tecla só com teclado/controle. 170 testes.
  - Teste do João (2026-10-23), corrigido: o projétil saía para onde o personagem olhava, não
    para o mouse (apertar qualquer tecla trocava a mira para "olhar"; agora só o controle troca);
    a transparência da criatura voltando para casa sumia se um flash de dano ou um golpe
    interrompido viesse logo depois (agora todo efeito curto volta à cor do estado). 172 testes.
  - **Mira no controle**: adiada (João, 2026-10-23). Hoje o controle mira para onde o personagem
    olha. Proposta para depois: analógico direito mira (estilo twin-stick) e, sem ele, leve
    ajuda de mira no inimigo mais próximo à frente. Mexe só na entrada (`LocalPlayerInput`): o
    lançamento já recebe uma direção pronta.
  - G2c ✅ (validado pelo João, 2026-10-23; ADR-027): criaturas e chefes perseguem quem os fere de longe (ameaça por dano; ver "Direção de
    combate"). Achado do João: atacada de fora do raio de agressão, a criatura nem reage; e,
    perseguindo, desiste assim que o jogador sai desse raio (volta andando, sem ficar imune),
    bem antes da coleira. Escopo: quem fere vira alvo de qualquer distância; perseguição com
    raio maior que o de agressão (só desiste na coleira); e criaturas sem alvo passeiam pela
    própria área (pedido do João), com o raio de passeio nos dados de cada criatura (slimes 40,
    Rei Slime 24). Feito com tabela de ameaça: quem fere mais é perseguido (troca de alvo com 10%
    de vantagem). 177 testes.
  - G2d ✅ (escolha do João: **Explosão arcana**; validado pelo João, 2026-10-23):
    segunda habilidade, a primeira **em área**. Aperta a tecla → preparação curta (0,25 s) → um
    círculo violeta aparece no chão no ponto do mouse (até 140 de distância) e o miolo enche por
    0,6 s → explode e fere todos os inimigos dentro (20 de dano, raio 26, empurra para fora),
    com onda clara e faíscas. Recarga 6 s. "Tomo: Explosão arcana" no mercador (80 moedas). A
    mira passou a levar a distância (não só a direção); no controle, sem mira própria ainda, a
    área cai 80 à frente. O aviso no chão é o mesmo do salto do Rei Slime, na cor da habilidade
    (vermelho continua sendo só "perigo para você"). 179 testes.
- **G3 – Auras e cosméticos** ✅ (na `main`): brilhos, runas e auras em volta do personagem (estilo Grand
  Fantasia), ligados a equipamentos e efeitos; níveis de qualidade e limite de partículas.
  Divisão proposta (2026-10-23), cada parte validada pelo João antes da próxima:
  - G3a ✅ (validado pelo João, 2026-10-23; branch `stage-g/effect-quality`, ADR-028): níveis de
    qualidade dos efeitos (baixo/médio/alto) e teto de partículas do computador, em
    `data/vfx/quality.tres`; valem para o veneno, a rapidez, as faíscas e o rastro das magias.
    Troca: F4 com o painel F3 aberto (provisório, sem menu de opções ainda); `--quality=` nas
    capturas. 182 testes.
  - G3b ✅ (validado pelo João, 2026-10-23; branch `stage-g/crown-aura`, ADR-029): aura em dados
    (`data/auras/`), ligada ao equipamento vestido. A **Coroa do Rei Slime** (escolha do João,
    2026-10-23) acende a primeira: anel dourado nos pés com 4 runas violeta girando devagar
    (metade de trás atrás do corpo, metade da frente na frente), luz translúcida no chão
    pulsando e faíscas douradas subindo. Aparece para todos no coop. Capturas: `--equip=<ids>`
    (tela e folha de quadros). 185 testes.
  - G3c ✅ (validado pelo João, 2026-10-23; branch `stage-g/transmog`, ADR-030):
    cosméticos (aparência separada dos atributos) e **transmog** (pedido do João,
    2026-10-23: a aparência de um item com os atributos de outro). Diretrizes de efeitos em ADR-029.
    Escolha do João (2026-10-23): **coleção permanente**, conseguir o item uma vez libera a
    aparência para sempre, mesmo vendendo ou destruindo o item.
    A **aura vai junto com a aparência** (João, 2026-10-23): quem colecionou a coroa exibe a aura
    dela com qualquer capacete. E a aparência **vale sozinha**, sem nada vestido no espaço, e dá
    para esconder um espaço (João, 2026-10-23).
    - G3c1: núcleo (coleção por jogador, aparência por espaço, aura do que aparece), rede
      (protocolo 13, host confere com a coleção dele) e save (saves antigos colecionam o que o
      personagem tem).
    - G3c2: botão direito num espaço de equipamento → menu de aparências; selo no canto do
      espaço; dica com a aparência; aviso "Nova aparência: X". Captura: `--look=<ids>`.
      Pendente: escolher só com teclado/controle. 192 testes.
    - Ajustes pós-avaliação do João (2026-10-23): o item vestido não se repete no menu pelo
      nome ("Mostrar o item vestido" já é ele); "Nova aparência" não aparece mais para o que o
      jogador já tinha (espada inicial num mundo novo, itens ao entrar no mundo de outro), só
      para item novo de verdade. 193 testes.
    - Futuro (pedido do João, 2026-10-23): com muitos itens por tipo, trocar a lista por uma
      **tela de aparências com a grade de imagens** liberadas daquele tipo. Fica para quando a
      interface definitiva (menus, inventário, bolsa, HUD) for desenhada, na referência Hero Siege.
  - G3d ✅ (validado pelo João, 2026-10-23; branch `stage-g/aura-load-test`): teste de
    carga com 10 / 30 / 60 auras (`tests/benchmark_auras.gd`, `docs/03-desempenho.md`). Achado:
    picos de 7,5 ms com 60 auras (o anel era pintado pixel a pixel em cada personagem). Corrigido:
    cada quadro do anel é pintado uma vez e dividido por todos com a mesma aura; mesmo visual,
    p99 1,5 ms. 194 testes.

## Etapa H — incrementos

Divisão proposta (2026-10-23), a partir dos testes de estresse ainda abertos em
`docs/03-desempenho.md` e das limitações de `docs/04-multiplayer.md`; cada parte validada pelo
João antes da próxima:

- **H1 – Carga de projéteis** ✅ (validado pelo João, 2026-10-23: projétil acerta, segue o mouse e mata; branch
  `stage-h/projectile-load-test`): `tests/benchmark_projectiles.gd`, 200 / 500 / 1000 Projéteis
  arcanos no ar, sem e com alvos, em cada nível de qualidade. Achado: ~13 µs e 3 chamadas de
  desenho por projétil (os 3 círculos eram polígonos, que não se agrupam). Corrigido: imagem do
  projétil pintada uma vez por habilidade e consulta física reaproveitada na busca de alvos (vale
  também para golpes). 1000 projéteis: 13,0 → 5,5 ms; mesmo visual. Fecha o risco 3 da Etapa D+.
- **H2 – Itens no chão** ✅ (validado pelo João, 2026-10-23, inclusive no coop; branch
  `stage-h/drop-load-test`): `tests/benchmark_drops.gd`, 200 / 500 gosmas no chão (parados,
  inventário cheio, coleta contínua, queda num quadro só) e o tráfego com host + cliente.
  Achados: cada item conferia o inventário do dono a cada quadro e mexia no balanço todo quadro
  (~13 µs por item); e o host enviava os drops pessoais também a quem não era dono (~250 B cada,
  ficavam escondidos lá). Corrigido: item longe do dono "dorme" (teto 0,25 s), inventário só
  com o dono ao alcance, balanço só muda o nó quando troca de pixel, e o drop só vai ao
  computador do dono (também melhora a privacidade: um cliente não sabe mais o que o outro
  ganhou). 500 itens: 6,5 → 3,2 ms; mesmo visual. Captura: cenário `drop` em `capture_frames.gd`.
  Teste do João no coop (2026-10-23), corrigido: às vezes o item pousava e não balançava para um
  dos jogadores (o balanço econômico guardava alturas quebradas, que caíam no mesmo pixel com a
  câmera em meio pixel; agora anda de pixel inteiro). E, uma vez, a tecla da Explosão arcana
  ficou mostrando "1" depois de a recarga acabar (comparação aproximada achava 0,000005 igual a
  0; antigo, desde a G2b). 197 testes.
- **H3 – Coop com 4 jogadores na mesma região** ✅ (validado pelo João, 2026-10-23: movimento suave no coop)
  (branch `stage-h/coop-4-players`): `tests/benchmark_coop.gd`, host na janela e 1 ou 3
  clientes em outros processos, andando e em combate. CPU do host: 1 → 4 jogadores em combate,
  2,7 → 3,4 ms (cabe). Achado: o tráfego era quase todo estado repetido de criatura parada
  (20 por segundo, ~0,9 KB/s cada). Corrigido: corpo parado repete só a cada 0,5 s, e ao voltar
  a andar manda primeiro o estado parado com o instante certo (sem "largar" antes da hora).
  4 jogadores: por cliente 10,8 → 3,7 KB/s andando e 13,8 → 10,2 em combate. 198 testes.
- **H4 – Riscos da arquitetura de rede antes da Etapa I** ✅ (validado pelo João, 2026-10-23)
  (branch `stage-h/network-risk-review`). Revisão: todas as RPCs que o cliente pode chamar
  conferem remetente e valores. Resolvido já (ADR-013):
  - **Paredes**: o host refaz o deslize do dono nas paredes; atravessar árvore é recusado, deslizar
    de verdade nunca é corrigido (testes: 8 lados de uma árvore, passeio de 1 min entre obstáculos).
  - **Inundação**: cota de pedidos por cliente (`PeerGuard`, 60/s, folga 120); quem esgota é
    desconectado. Combate com 4 jogadores fica bem abaixo.
  - Custo no host igual (4 jogadores em combate ~3,2 ms). 202 testes.
  Fica para a Etapa I (antes de abrir para a LAN): código da partida e criptografia (DTLS), que
  também protege o segredo do perfil. Fica para depois: compensação de atraso (só online); vida
  das criaturas recalculada quando alguém entra no meio da luta; espera da poção no save.
- Em aberto: medir num computador fraco de verdade (o alvo "modesto" ainda é hipótese).

## Etapa I — incrementos

Divisão proposta (2026-10-23), a partir das pendências da ADR-013; cada parte validada pelo
João antes da próxima:

- **I1 – Código da partida** ✅ (validado pelo João, 2026-10-23: três janelas, só o código certo entra) (branch
  `stage-i/match-code`). `--host-lan` mostra no canto da tela os IPs da rede local, a porta e
  um código de 6 letras sorteado; quem entra usa `--join=<ip> --code=<código>` (minúsculas,
  espaços e hífen aceitos). O código não trafega (desafio e resposta, ADR-013); 5 erros do
  mesmo endereço = 1 minuto bloqueado. O cliente recusado vê o motivo (código errado, bloqueio,
  versão diferente, perfil repetido). Protocolo 15. 208 testes; testado também com dois
  processos (código errado recusado, certo entra).
- **I2 – Tráfego criptografado** ✅ (validado pelo João, 2026-10-24) (branch
  `stage-i/encryption`). Tudo trafega criptografado (DTLS), inclusive o segredo do perfil e a
  prova do código. Antes de conectar, o cliente pega o certificado do host na "porta da
  frente" (porta + 1), selado com o código; código errado já para ali ("Código da partida
  errado"), host ausente avisa "Host não encontrado". Código agora com 8 letras (`ABCD-2345`):
  corrige uma falha da I1 (quem gravasse a conversa conseguia adivinhar o código de 6 letras;
  detalhes na ADR-013). Cliente que não consegue entrar não monta mais um mundo próprio. Custo
  (4 jogadores): CPU do host +0,1–0,25 ms, andando 3,7 → 6,3 KB/s por cliente; entrar leva
  ~0,6 s. Protocolo 16. 212 testes (com conexão sem criptografia recusada e certificado
  adulterado recusado); testado também com processos (errado, certo, sem host).
- **I3 – Tela de partida** ✅ (validado pelo João, 2026-10-24) (branch
  `stage-i/match-screen`, feita a partir da da I2, que ainda não foi para a main). A janela abre
  em "Escolha a partida": Jogar sozinho, Hospedar na rede local (IP, porta e código no canto da
  tela, como na I1) ou Entrar numa partida (IP + código; Entrar fica apagado com o motivo até os
  dois estarem certos; o IP é lembrado, o código não). A tela fica por cima mostrando
  "Conectando..." até o personagem chegar; código errado, host não encontrado, porta em uso ou
  host que cai no meio do jogo fecham a partida e voltam à tela com o motivo. Argumentos de rede
  ou captura pulam a tela (testes, `coop-local.bat`). Host que não consegue abrir a porta agora
  volta à tela (antes seguia sozinho sem avisar direito). 217 testes; benchmark de coop com
  clientes em processos continua entrando.
- **I4 – Teste em dois computadores** ⬜: firewall do Windows e partida de verdade na rede local.
  Fica para o fim da Etapa I (João, 2026-10-23): I1–I3 se validam no mesmo PC, com duas janelas.
  Adiada (João, 2026-10-24): ainda não há o segundo computador; fica para o final, e será feita
  com o **jogo exportado** (.exe copiado para o outro PC, sem Godot nem repositório lá). Até
  lá o projeto segue para as próximas etapas.

## Etapa J — incrementos

Frentes propostas (2026-10-24), núcleo genérico com conteúdo de teste, cada uma validada pelo
João antes da próxima: **dungeon instanciada** (escolha do João para começar), eventos de chefe
aleatórios, montarias, portais/atalhos desbloqueáveis, variedade de armas (arco, cajado).

- **J1a – Dungeon temporária** ✅ (validada pelo João, 2026-10-24; branch
  `stage-j/dungeon`, ADR-031). Boca de caverna no meio da floresta (ao norte do caminho, entre a
  entrada e o Rei Slime): andar para dentro dela leva à **caverna dos slimes**, escura, com
  abismos, slimes comuns e venenosos, cobre e o Rei Slime no fundo (leste). A passagem a oeste
  volta para a frente da boca. A caverna começa do zero sempre que alguém entra depois de ela
  ficar vazia; lá dentro as criaturas não renascem e não dá para construir; quem sai do jogo lá
  dentro volta para a frente da boca. 224 testes (7 novos); campina e floresta continuam iguais
  (save vale).
- **J1b – Baú do chefe e saída rápida** ✅ (validada pelo João, 2026-10-24; branch
  `stage-j/dungeon`, ADR-032). Quando o Rei Slime morre na caverna, depois que o corpo some,
  surgem um baú (com faíscas) onde ele caiu e um círculo mágico roxo no chão um pouco mais
  longe. Perto do baú aparece "[E] Abrir o baú": cada jogador abre o seu uma vez e a recompensa
  (poções de vida, cobre, às vezes poção de rapidez) salta em volta, só para ele. Entrar no
  círculo leva para a frente da boca da caverna, na floresta. O Rei Slime da floresta continua
  sem baú. 230 testes (6 novos); protocolo de rede 17.
- **J2a – Arco** ✅ (validada pelo João, 2026-10-24; branch `stage-j/weapons`, ADR-033). Novo item
  **Arco** (2 mãos, aceita aljava), feito na bancada com 10 madeiras e 3 gosmas. Vestido, o
  clique esquerdo solta uma flecha na direção do mouse: acerta o primeiro inimigo no caminho
  (6 de dano) ou some no alcance. Na preparação o personagem recua 1 px e no disparo sai um
  sopro de faíscas. Magias e armas agora usam o mesmo projétil. 234 testes (4 novos);
  protocolo de rede 18.
  - Ajustes após o teste do João: flechas e magias voam igual em todas as direções na tela
    (antes, para cima/baixo, iam com metade da velocidade e do alcance); arco mais lento (puxar
    0,25 s, recarregar 0,55 s, menos recuo; antes os slimes nem chegavam perto); flecha com 64
    direções em degraus regulares e ponta escura (antes parecia torta). 235 testes.
- **J2b – Cajado** ✅ (validada pelo João, 2026-10-24; branch `stage-j/weapons`, ADR-034). Novo item
  **Cajado** (2 mãos), feito na bancada com 8 madeiras, 4 cobres e 5 gosmas. O clique solta um
  orbe azul mais lento que a flecha; ao acertar, ele **explode** e fere todos em volta (9 de dano,
  com onda no chão e faíscas). Ritmo mais lento que o arco. Correção junto: o personagem não fica
  mais vermelho ao preparar ataques lentos (o aviso vermelho é só das criaturas). 237 testes.
- **J3a – Montaria** ✅ (validada pelo João, 2026-10-24; branch `stage-j/mounts`, ADR-035). Novo
  item **Slime de montaria** (espaço novo "Montaria" no equipamento), feito na bancada com 12
  gosmas e 10 madeiras. Vestido, **R** (ou direcional para baixo) sobe: 1 s parado com barrinha;
  montado, +80% de velocidade, mas sem atacar, coletar ou lançar; apanhar derruba; R ou ataque
  descem. Continua montado ao passar entre regiões. 244 testes (7 novos); protocolo 19.
- **J4a – Chefe errante** ✅ (validada pelo João, 2026-10-24; branch `stage-j/boss-events`,
  ADR-036). A cada 10–20 min de jogo, um **Rei Slime errante** surge na campina ou na floresta
  (onde houver jogador), com aviso no alto da tela para todos ("Rei Slime apareceu!" / "Região:
  Campina") e uma seta dourada na borda apontando para ele. Se ninguém o derrotar em 5 min (e
  ele não estiver lutando), vai embora. Derrotado, deixa um baú só para quem o feriu. Paredes de
  arena ficam para a J4b. 250 testes (6 novos); protocolo 20.
- **J5a – Pedras de portal** ✅ (validada pelo João, 2026-10-24; branch `stage-j/waystones`,
  ADR-037). Obeliscos de pedra: um na campina (perto da entrada) e dois na floresta (entrada e
  boca da caverna). Perto de um, **E ativa** (a runa acende, só para você, e fica no save); numa
  pedra acesa, **E abre a lista** das outras que você ativou; escolher **canaliza 1 s** (barrinha;
  apanhar ou andar interrompem) e leva até a frente da pedra escolhida. 256 testes (6 novos);
  protocolo 21. Correção após o teste do João: montado também dá para viajar (chega montado).
  Também: canalizando, atacar, lançar, coletar, montar e reabrir o menu ficam bloqueados (andar
  continua possível e cancela a viagem)
  e aparece uma aura de teleporte roxa em volta do personagem. 259 testes.
- **J6a – Maestria por arma** 🟡 (aguardando validação do João; branch `stage-j/weapon-mastery`,
  ADR-038). Progressão de combate estilo Albion, escolha do João: Espada, Arco, Cajado e Arcano
  (as magias) têm nível próprio, que sobe matando inimigos com elas (experiência = dano que cada
  um causou, paga na morte; filhotes de chefe não pagam).
  Cada nível dá +3% de dano àquela arma ou magia (até o nível 20). No HUD, acima da coleta,
  aparece a maestria do que está em uso ("Espada 3 (40%)"); ao subir, "Espada nível 3! (+6% de
  dano)". Fica no save; no coop o host decide. 270 testes (11 novos); protocolo 22.

## Funcionalidades

- Dungeon (J1a): boca de caverna na floresta leva à caverna dos slimes (temporária).
- Fim da dungeon (J1b): o chefe morto deixa um baú (E abre; recompensa de cada jogador) e uma
  saída rápida para a entrada.
- Arco (J2a): feito na bancada; o golpe vira flecha na direção do mouse.
- Cajado (J2b): feito na bancada; o golpe vira um orbe que explode em volta de onde acerta.
- Montaria (J3a): espaço de montaria; R sobe (1 s parado) e desce; montado, mais rápido e sem
  lutar; dano derruba.
- Chefe errante (J4a): de tempos em tempos um chefe surge com aviso e seta; baú para quem o feriu.
- Pedras de portal (J5a): E ativa; numa pedra acesa, E escolhe para qual outra viajar (1 s).
- Maestria por arma (J6a): matar com espada, arco, cajado ou magias sobe o nível delas (+dano);
  o HUD mostra a do que está em uso.
- Tela de partida ao abrir o jogo: Jogar sozinho, Hospedar na rede local, Entrar numa partida
  (IP + código) ou Sair. Setas/Enter ou controle também escolhem; Esc volta do formulário.
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
- **Mercador de testes** (pedido do João, 2026-10-23; provisório): mercador dourado ao lado do
  mercador da campina que vende todos os itens e ensina todas as receitas por 0 moedas. Só em
  compilações de desenvolvimento (editor/F5), com `game/debug/dev_merchant` no project.godot
  (false desliga). Pendente: decidir se sai do código ou fica só em desenvolvimento.
- Painel F3 mostra também a velocidade (base -> atual), a defesa e os efeitos ativos com os
  segundos: o jeito de conferir se um buff/debuff entrou e saiu.
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
- Rei Slime (F4a): na floresta, siga para o leste até a clareira. Ele salta em quem está a meia
  distância: saia do círculo vermelho antes de ele cair e bata nele enquanto se recupera.
  Na metade da vida ele se enfurece: salta mais rápido e solta slimes a cada queda.
- Coroa do Rei Slime (F5a): com o Núcleo do Rei Slime, 8 gosmas e 4 cobres, perto de uma bancada,
  aparece na coluna Fabricar. Vista na cabeça no lugar do elmo de cobre.
- Buffs e debuffs (G1): na floresta, slimes verde-limão envenenam com o bote (3 de dano por segundo,
  6 s; sem atordoar). Poção de rapidez no mercador (25 moedas): botão direito → Usar, +25% de
  velocidade por 30 s. Os efeitos aparecem acima da vida com os segundos (borda verde = bom,
  vermelha = ruim) e como partículas no personagem.
- Habilidades (G2): compre o "Tomo: Projétil arcano" no mercador (50 moedas, ou de graça no de
  testes), botão direito → Usar: a habilidade vai para a tecla 1. Aperte 1 para lançar na direção
  do mouse (recarga de 2,5 s, mostrada na barra embaixo no meio). Botão direito numa tecla da
  barra muda a habilidade de tecla.
- Explosão arcana (G2d): "Tomo: Explosão arcana" no mercador (80 moedas). Na tecla, mire com o
  mouse onde quer a explosão: aparece um círculo violeta no chão e, 0,6 s depois, ela fere
  todos os inimigos dentro (recarga 6 s).
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
- Corrigido (2026-10-23): avisos "leaked at exit" na saída da Godot (452 objetos nos testes).
  Nós criados antes de entrar na árvore e postos nela só depois (`call_deferred` ou no `setup`)
  ficavam soltos quando o jogo fechava antes: frente da aura, menu da barra de habilidades,
  barras do chefe e de habilidades, peças da loja, efeitos no chão da região. Agora nascem já
  dentro da árvore. Os testes terminam sem nenhum aviso.
- Corrigido (2026-10-23): `render_checks.gd` reprovava desde a G3c2: o aviso falso "Nova
  aparência: Espada" num mundo novo cobria o texto de teste.
- Corrigido (2026-10-23, achado do João; branch `stage-g/aura-load-test`): ao abrir o jogo
  apareciam "Nova habilidade: X", "Minerador nível N!" e o nome de efeitos ativos (ex.:
  "Rapidez"). É a mesma causa do aviso falso de aparência: os avisos anotavam o que o jogador
  tinha no instante em que o personagem aparecia, e o save (ou o estado vindo do host) chegava
  logo depois. Agora os avisos do jogador local ficam em silêncio até o estado chegar (host:
  save aplicado; cliente: última resposta do estado completo, protocolo 14). Teste: reabrir o
  mundo e voltar como amigo não avisa nada; habilidade nova de verdade avisa. 195 testes.
- O recuo da espada empurra o slime um pouco para fora do alcance (ele resiste 40%): é
  preciso avançar a cada golpe. Intencional (dá ritmo); ajustável em `data/`.

## Pendências de decisão

- Mercador de testes (2026-10-23): remover do código ou manter só em desenvolvimento.

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
- **Chefes corpo a corpo x classes à distância** (João, 2026-10-23): mago e arqueiro têm menos
  defesa, mas não podem lutar com folga. O chefe tem que se "irritar" com quem o ataca de longe e
  ir atrás dele, obrigando a correr, usar dash etc. Técnica prevista: ameaça por dano recebido
  (quem causa dano vira alvo, mesmo fora do raio de visão) e habilidades de aproximação do chefe
  (salto/investida já existem). Entra junto com armas e habilidades à distância.
  Ameaça por dano feita na G2c (ADR-027).
- **Dificuldade** (João, 2026-10-23): o nível atual (slimes com investida, Rei Slime) é o desejado.
- **Magia x corpo a corpo** (achado do João no teste da G2d, 2026-10-23): o Rei Slime morre fácil
  com magia à distância; com a espada é preciso se reposicionar o tempo todo e o risco de apanhar
  é bem maior. Hoje o dano por segundo da espada é maior que o das magias (projétil 14 a cada
  2,5 s; explosão 20 a cada 6 s), mas à distância quase não se apanha, e quem usa magia não perde
  nada em troca (mesma defesa, espada junto). Fica para o balanceamento, com mais conteúdo.
  Alavancas previstas: custo de build para quem usa magia (equipamento de mago com menos
  defesa, arma mágica em vez da espada); chefes com mais pressão em quem ataca de longe
  (investida/salto até o alvo da ameaça, ataques à distância); recompensa para o corpo a corpo
  (janelas de punição depois dos ataques do chefe, golpes mais fortes, roubo de vida).

## Textos e idiomas

- Feito (`chore/localization`, ADR-015): todos os textos do jogador vêm de
  `data/i18n/texts.csv` (pt-BR e en). `-- --lang=en` testa em inglês.

## Ideias futuras (backlog criativo)

Ideias do João para considerar nas etapas certas — não são compromissos ainda.

- **Energia e mana** (João, 2026-10-24): energia para ataques físicos e mana para magia, como
  dificuldade. Antes, analisar os custos (quanto gasta cada ataque, como recupera, interface).
  Hoje armas não gastam nada e habilidades só têm recarga.
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

- **Coroa de ouro** (João, 2026-10-23): numa visão mais de fantasia, uma coroa pede minério de
  ouro. Quando houver ouro no mundo, a receita da coroa (ou do equipamento final de chefe) usa ouro.

- **Atravessar água**: buff, poção ou montaria que permite andar sobre a água (ou nadar),
  abrindo atalhos e áreas escondidas. Técnica prevista: mover a colisão da água para uma
  camada de física própria (hoje está em "world") e o efeito tiraria essa camada da máscara
  de colisão do personagem. (Etapa E/J — montarias)
