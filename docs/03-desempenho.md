# Desempenho

Todas as metas abaixo são **hipóteses a validar**, não promessas.

## Hardware

- **Desenvolvimento (PC do João)**: Ryzen 5 5500, Radeon RX 6600, 16 GB DDR4 3200, SSD NVMe.
  É uma máquina intermediária — **não** serve sozinha como referência de "hardware modesto".
- **Referência "modesto" (alvo hipotético)**: CPU de 4 núcleos de ~2015–2017, GPU integrada
  (classe Intel UHD 620 / Vega 8), 8 GB de RAM, SSD ou HDD.
- Como testar sem essa máquina: renderizador Compatibility, limite de FPS, testes de estresse
  com orçamento de tempo por quadro bem abaixo do disponível no PC do João, e medição de
  memória. Se surgir acesso a uma máquina fraca real, ela vira a referência.

## Metas iniciais (hipóteses)

| Métrica | Meta no hardware modesto | Margem no PC de dev |
|---|---|---|
| FPS em combate normal | 60 estável | tempo de quadro < 4 ms |
| Pior caso (evento/chefe) | ≥ 45 | tempo de quadro < 8 ms |
| Memória do jogo | < 500 MB | — |
| Troca de região | < 1 s, sem travar o áudio | — |
| Salvamento | sem travada perceptível (< 1 quadro) | — |

## Estratégias planejadas

- Pooling de projéteis, números de dano e partículas.
- Limite global de partículas por nível de qualidade (baixo/médio/alto).
- Entidades distantes do jogador atualizam com menor frequência ou dormem.
- IA e busca de caminho em frequência reduzida (não a cada quadro).
- Efeitos com blend aditivo e shaders simples, em vez de pós-processamento.
- Medir com o profiler e os monitores da Godot antes de otimizar.

## Testes de estresse planejados

| Cena de teste | Parâmetros | Status |
|---|---|---|
| Muitos inimigos | 50 / 100 / 200 perseguindo | ✅ 2026-10-21 (ver Resultados) |
| Muitos projéteis | 200 / 500 / 1000 | ✅ 2026-10-23 (ver Resultados) |
| Partículas e auras | 10 / 30 / 60 auras ativas | ✅ 2026-10-23 (ver Resultados) |
| Itens no chão | 200 / 500 | ✅ 2026-10-23 (ver Resultados) |
| Coop | 2 / 4 jogadores na mesma região | 🟡 2 jogadores (tráfego medido); 4 ⬜ |

Os testes rodarão por linha de comando e registrarão resultados nesta tabela.

## Resultados

| Data | Teste | Máquina | Resultado |
|---|---|---|---|
| 2026-10-21 | ~~`benchmark_region.gd` sem `--fixed-fps`~~ — média 0,41 ms | PC de dev | **Medição subestimada**: sem `--fixed-fps` a física (60 Hz) rodava só em ~1 de cada 40 quadros. Substituída pelas linhas abaixo. |
| 2026-10-21 | `benchmark_region.gd --fixed-fps 60` — Prado com 238 objetos, 8 slimes, ~1180 nós, personagem andando, 1200 quadros | PC de dev (RX 6600, Compatibility) | média **0,82 ms**, p99 1,15 ms, pior 1,40 ms, 38 draw calls, 43 MB de memória estática |
| 2026-10-21 | `benchmark_monsters.gd --fixed-fps 60` — N slimes perseguindo e atacando 1 jogador, 600 quadros | PC de dev | 50: **0,81 ms** (p99 1,21) · 100: **1,54 ms** (p99 2,07) · 200: **3,13 ms** (p99 4,03, pior 4,47) |
| 2026-10-22 | Mesmo `benchmark_monsters.gd -- 200` com a camada de rede (offline) | PC de dev | 200: **3,2–3,3 ms** (p99 4,0–4,5): +~4% pelo componente NetSync; ele se desliga offline |
| 2026-10-22 | Tráfego em rede: host + 1 cliente, 10 entidades, 10 s de jogo andando | PC de dev (127.0.0.1) | host → cliente **8,8 KB/s**, cliente → host **1,0 KB/s** (~0,9 KB/s por entidade replicada) |
| 2026-10-22 | `benchmark_regions.gd` — N regiões ativas, cada uma num SubViewport (física própria, só a 1ª desenhada), 1 jogador andando por região; calmo = criaturas dos pontos; combate = +25 slimes perseguindo cada jogador; 900 quadros, 2 rodadas | PC de dev | calmo: 1 → **0,57 ms** · 2 → **0,76 ms** · 4 → **1,0–1,1 ms** (p99 1,8). Combate: 1 → **1,0 ms** · 2 → **1,6 ms** · 4 → **2,8–3,0 ms** (p99 4,5–5,2, pior 6,3). Memória 45 → 59 → 80 MB; nós 1,3k → 3,7k → 7,4k |
| 2026-10-22 | `benchmark_monsters.gd` depois do bote virar investida (F4) | PC de dev | 50: **0,88 ms** (p99 1,26) · 100: **1,70 ms** (p99 2,17) · 200: **3,73 ms** (p99 4,74, pior 5,6). A 1ª versão (consulta de física a cada quadro do avanço) dobrava o custo (50: 1,6 ms); agora 1 consulta por bote. O resto da alta: slimes atacam de mais longe, mais vezes |
| 2026-10-23 | `benchmark_monsters.gd` com o componente de efeitos (G1a) em todo ator, medido junto com a `main` na mesma sessão | PC de dev | 200 slimes: `main` **4,0–4,2 ms**, branch **3,8–3,9 ms** (sem custo extra: o componente só roda com efeito ativo). Variação entre sessões da máquina: ~0,5 ms |
| 2026-10-23 | `benchmark_monsters.gd` com ameaça e passeio (G2c), medido junto com a `main` na mesma sessão | PC de dev | 200 slimes: `main` **4,19 ms**, branch **4,43 ms** (+5%: as criaturas agora andam pela área em vez de ficar paradas; dentro da variação entre sessões) |
| 2026-10-23 | `benchmark_monsters.gd` com o nó de aura (G3b) em todo ator, sem aura ativa | PC de dev | 50: **0,94 ms** · 100: **1,75 ms** · 200: **3,79 ms** (p99 4,76): sem custo extra (sem aura, nada roda por quadro) |
| 2026-10-23 | `benchmark_auras.gd` (G3d) — N personagens parados, todos na tela, sem aura e com a aura da coroa em cada nível de qualidade, 600 quadros. **Antes** (anel pintado pixel a pixel em cada ator) | PC de dev | sem aura → com aura (média, p99): 10: 0,25 → **0,35 ms** (p99 0,53) · 30: 0,45 → **0,83 ms** (p99 2,5–3,6) · 60: 0,69 → **1,6–1,7 ms** (p99 **7,5**, picos a cada passo do giro, iguais em todo nível: o custo era o desenho do anel, não as partículas) |
| 2026-10-23 | Mesmo `benchmark_auras.gd` **depois** da imagem compartilhada (`AuraRingImage`) | PC de dev | 10: 0,26 → **0,33 ms** (p99 0,48) · 30: 0,43 → **0,67–0,71 ms** (p99 0,9–1,1) · 60: 0,71–0,76 → **1,14–1,23 ms** (p99 1,4–1,6). Partículas (60 auras): 120 / 240 / 360 em baixo / médio / alto; draw calls +3 por aura (2 metades do anel + faíscas) |
| 2026-10-23 | `benchmark_projectiles.gd` (H1) — N Projéteis arcanos no ar o tempo todo (quem some é reposto), "no ar" = sem alvos, "com alvos" = +40 slimes em volta levando os acertos; 600 quadros. **Antes** (cada projétil desenhava 3 círculos) | PC de dev | no ar, baixo: 200: **2,6 ms** · 500: **6,3 ms** · 1000: **13,0 ms** (~13 µs e **3 draw calls por projétil**). Com alvos, baixo: 200: 3,5 · 500: 7,8 · 1000: 15,0 ms. Separando: desenho ~7 ms de 13 (polígonos não se agrupam no Compatibility), busca de alvo ~3 ms (forma física nova a cada busca) |
| 2026-10-23 | Mesmo `benchmark_projectiles.gd` **depois**: imagem do projétil pintada uma vez por habilidade (textura agrupa) e consulta física reaproveitada no `ActorQuery` | PC de dev | no ar (baixo / médio / alto): 200: **1,5 / 1,6 / 1,8 ms** · 500: **2,9 / 3,1 / 3,4 ms** · 1000: **5,5 / 5,9 / 6,2 ms** (p99 6,9–7,3). Com alvos: 200: 2,6 / 2,9 / 3,1 · 500: 5,5 / 5,7 / 6,1 · 1000: 9,5 / 10,0 / 10,3 ms. Draw calls com 1000: 3077 → **154–272**. Visual igual (captura antes/depois: só diferenças de 1/255 na sombra). `benchmark_monsters.gd` sem mudança (200: 3,6 ms) |
| 2026-10-23 | `benchmark_drops.gd` (H2) — N gosmas no chão da campina (jogo completo, sem rede), 600 quadros: "parados" = dono fora do ímã de todas; "cheio" = dono no meio, inventário cheio; "coleta" = dono andando em círculo e pegando (cada item pego renasce); "queda" = N criados no mesmo quadro. **Antes** | PC de dev | parados: 200: **3,0 ms** · 500: **6,5 ms** (~13 µs por item: ~9 de lógica, ~2 de desenho). Cheio: 2,8 / 5,7 · coleta: 3,5 / 7,0 ms. Draw calls ~2 por item (sombra e ícone se alternam). Queda: criação **~60 µs por item** (200: 12 ms, 500: 31 ms no quadro). Rede: os drops do host iam também ao cliente (~250 B cada), que nem os via |
| 2026-10-23 | Mesmo `benchmark_drops.gd` **depois**: item dorme enquanto o dono não pode chegar (teto 0,25 s), inventário só consultado com o dono ao alcance, balanço só mexe no nó quando troca de pixel, e o host envia o drop só ao computador do dono | PC de dev | parados: 200: **1,6 ms** · 500: **3,2 ms**. Cheio: 1,8 / 3,7 · coleta: 2,3 / 3,9 ms. Queda sem mudança (~60 µs por item: montar o nó, pôr na região, ligar à rede; a busca do ponto de pouso agora reaproveita a consulta física, sem ganho medido). Rede: drop do host → cliente **0 B** (antes ~250 B); drop do cliente ~160–430 B só na queda (o fundo de 0,3–8,8 KB/s atrapalha a medida), nada depois. Visual igual (folha de quadros antes/depois, cenário `drop`) |
| 2026-10-22 | `benchmark_region.gd` depois da F2c (regiões em mundos próprios), campina, sem save | PC de dev | média **0,87–0,88 ms**, p99 1,4–1,5 ms, 55,6 draw calls, 56 MB (conteúdo da Etapa E incluso; antes da F2c o teste lia o save de quem joga, agora não) |

Leitura: o custo cresce de forma linear, ~15 µs por criatura ativa (IA + física + desenho).
200 criaturas cabem na meta de 4 ms do PC de dev. Supondo que o hardware modesto seja 3–4×
mais lento, ~100 criaturas ativas por região seguem dentro de 60 FPS. Ainda não diz nada sobre o
hardware modesto real nem sobre projéteis e efeitos — esses testes vêm nas próximas etapas.

Leitura das auras (G3d): depois da correção, ~7,5 µs por aura na tela (anel + faíscas), sem
picos. 60 auras somam ~0,45 ms; supondo o hardware modesto 3–4× mais lento, ~1,5–2 ms. Cabe com
folga. O nível de qualidade quase não muda o tempo no PC de dev (as partículas são baratas aqui);
ele existe para GPUs integradas, onde ainda não foi medido. O teto de partículas (150 / 400 / 800)
não chegou a cortar nada com 60 auras da coroa.

Leitura dos projéteis (H1): depois da correção, ~5,5 µs por projétil no ar (voo + busca de alvo +
desenho) e ~10 µs com acertos (dano, recuo, faíscas, número de dano). 200 projéteis no ar somam
~1,5 ms no PC de dev; supondo o hardware modesto 3–4× mais lento, ~5–6 ms: cabe, junto com uma
luta normal. 1000 de uma vez (~6 ms aqui, ~20 ms no modesto) não cabe, mas é muito além do que o
jogo prevê (4 jogadores com recarga de 2,5 s; futuras criaturas atiradoras). O teto de
partículas segura o rastro (150 / 400 / 800). O que sobra no custo é a busca física de cada
projétil a cada quadro; a alavanca, se um dia precisar, é buscar em quadros alternados ou por
uma grade de atores. Nada passa pela rede (cada computador voa o seu; o host decide o acerto).

Leitura dos itens no chão (H2): depois da correção, ~5 µs por item parado na tela, quase tudo
desenho (2 draw calls por item: a sombra e o ícone se alternam na ordenação por altura e não se
agrupam). 200 itens somam ~0,9 ms no PC de dev; supondo o hardware modesto 3–4× mais lento,
~3–4 ms: cabe. Uma luta normal deixa bem menos que isso no chão. Criar um item custa ~60 µs:
um chefe com 20 itens gasta ~1 ms no quadro da morte; 200 de uma vez travariam (12 ms aqui), mas
o jogo não prevê isso. Alavancas, se precisar: sombra e ícones na mesma textura (agrupa o
desenho) e criação espalhada por quadros. Na rede, cada drop custa ~200–400 B uma vez, só para o
dono; não há tráfego contínuo (a coleta é decidida no host e só a remoção viaja).

Leitura das regiões ativas (F2b): uma região a mais que só simula (sem desenho) custa ~0,15–0,2 ms
calma; o que pesa são as criaturas em combate (~15 µs cada, como acima), não as regiões em si.
4 jogadores cada um numa região, todos em combate com ~34 criaturas, ficam em ~3 ms no PC de dev;
supondo o hardware modesto 3–4× mais lento, ~9–12 ms de média (dentro de 60 FPS), com picos
perto do limite. Conclusão: viável. Se o hardware modesto real apertar, as alavancas são
criaturas longe de qualquer jogador dormirem e IA em frequência menor. A memória cresce
~12 MB por região ativa. Não mede a rede (cada cliente só vai receber a própria região, F2c).
