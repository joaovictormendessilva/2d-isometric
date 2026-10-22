# Registro de decisões (ADRs)

Formato: cada decisão tem **status** (Aceita / Hipótese / Substituída), contexto, decisão e
consequências. "Hipótese" = decisão provisória que precisa ser validada em protótipo.
Para mudar uma decisão aceita, crie uma nova ADR que a substitua — não apague a antiga.

---

## ADR-001 — Ambiente de vibe coding

- **Status**: Aceita (2026-10-21)
- **Contexto**: O João já tem VS Code, GitHub e Claude Pro. Quer o fluxo mais simples, sem
  envolver outras IAs, com o Claude editando, executando e testando o jogo.
- **Decisão**:
  - **Claude Code** (incluído no Claude Pro) trabalhando direto na pasta local do repositório,
    via extensão do VS Code (ou aba Code do app desktop — equivalentes).
  - **Godot 4.7.x** instalada no PC do João; o Claude a executa pela linha de comando para
    validar scripts, rodar testes e benchmarks.
  - **Git + GitHub** (repositório privado) para histórico e pontos de restauração.
  - Contexto permanente no próprio repositório (`CLAUDE.md` + `docs/`), para que qualquer
    sessão nova já conheça o projeto.
- **Consequências**:
  - Custo adicional: R$ 0 (o uso do Claude Code conta nos limites do plano Pro).
  - Risco: atingir o limite de uso no meio de uma tarefa → mitigado com incrementos pequenos,
    commits frequentes e documentação sempre atualizada.
  - Alternativas descartadas: GitHub Copilot Free (reserva só se o João pedir), Gemini CLI
    (fim do acesso gratuito por login Google em 18/06/2026), Claude só pelo navegador
    (sem acesso direto aos arquivos locais).

## ADR-002 — Engine: Godot 4.7.x (Standard, GDScript)

- **Status**: Aceita (2026-10-21)
- **Decisão**: Godot 4.7.x, edição **Standard** (não a .NET), scripts em **GDScript tipado**.
  Versão inicial: 4.7.2-stable (18/08/2026). Atualizações só em versões de manutenção
  (4.7.x) após commit; troca de versão menor (4.8+) exige nova ADR.
- **Motivos**:
  - Licença MIT: gratuita, sem royalties, uso comercial livre.
  - Cenas (`.tscn`) e recursos (`.tres`) são texto: o Claude consegue ler, editar e versionar.
  - Executável por linha de comando (`--headless`, scripts de teste): o Claude testa sozinho.
  - 2D nativo: TileMapLayer com modo isométrico, Y-sort, partículas, shaders de CanvasItem,
    luzes 2D, animação, salvamento, exportação desktop gratuita.
  - API de multiplayer embutida (ENet, RPCs, MultiplayerSpawner/Synchronizer).
  - GDScript: menos atrito que C# para iteração rápida e para o João acompanhar.
- **Descartadas**: Unity (proprietária, mais pesada, arquivos menos amigáveis para IA);
  frameworks "faça você mesmo" (LÖVE, Phaser, MonoGame) — exigiriam reconstruir editor de
  mapas, partículas e rede.

## ADR-003 — Renderizador Compatibility

- **Status**: Aceita para cenário e personagens (Etapa C validada pelo João, 2026-10-21); efeitos mágicos ainda a validar (Etapa G/H)
- **Decisão**: usar o renderizador **Compatibility** (OpenGL 3.3 / WebGL2) por padrão.
- **Motivo**: maior alcance em GPUs integradas e antigas; suficiente para 2D.
- **A validar**: se os efeitos desejados (brilho, shaders, luzes 2D) ficam bons nele. Se algum
  efeito essencial exigir Forward+/Mobile, reavaliar com testes.

## ADR-004 — Autoridade do host desde o primeiro sistema

- **Status**: Aceita (2026-10-21)
- **Decisão**:
  - Modelo **host autoritativo** (listen server). Single-player = host local com 1 jogador.
  - Entradas do jogador viram **comandos/intenções** (mover, atacar, usar habilidade, coletar,
    craftar). Só a autoridade aplica dano, gera drops e altera inventários.
  - Todo jogador tem `player_id`; toda entidade relevante tem `entity_id` estável.
  - Proibido "jogador global" implícito (ex.: `get_node("Player")` em sistemas de jogo).
  - Estado de jogo (dados) separado da apresentação (nós visuais, animações, efeitos).
- **Consequências**: um pouco mais de estrutura no início; em troca, o coop LAN não exige
  reescrita. Detalhes em `docs/04-multiplayer.md`.

## ADR-005 — Regiões como cenas, estado persistente à parte

- **Status**: Hipótese (uma região funcionando na Etapa C; transições e estado salvo na Etapa F)
- **Decisão**:
  - Cada região é **uma cena Godot** (TileMapLayers + entidades), carregada uma por vez no
    single-player.
  - Um serviço de estado do mundo (`WorldState`) guarda o que persiste: recursos coletados e
    tempo de regeneração, baús, chefes derrotados, portais desbloqueados, NPCs.
  - Ao entrar em uma região: carrega a cena e aplica o estado salvo. Ao sair: salva o estado
    e libera a cena.
  - Chunks dentro de uma região só se medições mostrarem necessidade.
  - Dungeons temporárias/instanciadas: decidir quando forem implementadas.
- **Ponto aberto para o coop**: jogadores em regiões diferentes ao mesmo tempo (o host
  precisaria simular mais de uma região). Decidir até a Etapa H.

## ADR-006 — Representação isométrica

- **Status**: Aceita (validada pelo João na Etapa C, 2026-10-21), com o ajuste de velocidade abaixo
- **Decisão inicial**:
  - Mapa com TileMapLayer em modo **isométrico** nativo da Godot; ordenação de profundidade
    por **Y-sort**.
  - Entidades se movem em coordenadas de tela (nós 2D), com a velocidade ajustada para que o
    deslocamento pareça uniforme na perspectiva isométrica.
  - Distâncias de gameplay (alcance, áreas, agro) calculadas num **"plano do chão"**
    (eixo Y corrigido ×2), para que círculos de efeito pareçam corretos e o alcance seja justo
    em todas as direções. Funções utilitárias centralizam essa conversão.
- **A validar no protótipo**: sensação de movimento, colisões nas bordas dos tiles, ordenação
  com objetos altos (árvores, construções), navegação de inimigos.
- **Ajuste (2026-10-21, pedido do João)**: com velocidade igual no chão, andar na horizontal
  parecia mais rápido (percorre mais pixels de tela). A velocidade de MOVIMENTO agora é
  multiplicada por `Iso.move_speed_factor` (cos⁴ da direção; `horizontal_speed_factor` = 0,8
  em `data/actors/player.tres`). A direção não muda, e alcances/áreas seguem justos no chão.

## ADR-007 — Hipóteses visuais iniciais

- **Status**: Aceita para resolução, escala e tile (Etapa C, 2026-10-21); tamanho final e direções do personagem seguem hipótese até haver arte própria
- **Valores iniciais propostos**:
  - Resolução interna: **640×360**, escalada por inteiro (×3 = 1920×1080), filtro *nearest*.
  - Tile isométrico: **32×16 px** (proporção 2:1).
  - Personagens: **~32 px de altura** (escala próxima da referência
    `docs/referencias/exemplo-de-personagens.png`).
  - Direções de animação: **4 (diagonais) com espelhamento**; avaliar 8 depois.
- **Motivos**: 640×360 escala perfeitamente para 720p, 1080p e 1440p, mostra área suficiente
  para combate e mantém o custo de arte baixo; 32×16 é o padrão isométrico com mais recursos e
  referências.
- **Técnicas de VFX inspiradas nas referências** (`gf-1.png`, `gf-2.png`):
  - Anel de runas no chão: sprite girando dividido em **metade de trás** (atrás do
    personagem) e **metade da frente** (na frente), para dar volume na perspectiva isométrica.
  - Objetos orbitando (ex.: espadas): sprites com Y-sort e shader de brilho pulsante.
  - Faíscas/estrelas: partículas com limite e níveis de qualidade.
  - Brilho: sprites com blend aditivo e shaders de contorno, em vez de pós-processamento caro.

## ADR-008 — Licenças e orçamento

- **Status**: Aceita (2026-10-21)
- **Decisão**: só usar assets, fontes, áudios e ferramentas cuja licença permita **uso
  comercial** (preferência: CC0, MIT, CC-BY com atribuição registrada). Todo asset externo
  entra em `docs/05-assets-e-licencas.md` antes de ser commitado.
- **Ferramenta de pixel art recomendada**: Pixelorama (gratuita, MIT). Aseprite é paga.

## ADR-009 — Colisão por "pegada" no plano do chão e interpolação de física

- **Status**: Aceita (colisão, Y-sort e câmera validados pelo João, 2026-10-21)
- **Contexto**: ADR-006 pede distâncias justas em todas as direções. Colisões desenhadas em
  coordenadas de tela ficariam "esticadas" na horizontal.
- **Decisão**:
  - Toda entidade colide por uma **pegada**: um círculo no plano do chão (raio em pixels),
    desenhado na tela como elipse 2:1 (`scenes/components/footprint.gd`). Só o raio muda
    entre personagem (5), árvore (6) e pedra (8).
  - Por ser redonda, o personagem **desliza em volta** de obstáculos ao empurrá-los, em vez
    de travar. Comportamento desejado para RPG de ação; testado em `tests/test_movement.gd`.
  - Origem dos nós nos **pés/base** (usada pelo Y-sort). Sprites usam `offset` para isso.
  - **Physics interpolation** ligada (física a 60 Hz, tela suave em monitores de 144 Hz);
    a câmera é filha do personagem seguido para herdar a posição interpolada.
- **Consequências**: teleportes precisam chamar `reset_physics_interpolation()`.

## ADR-010 — Objetos altos ficam transparentes com o jogador atrás

- **Status**: Aceita (pedido do João, 2026-10-21)
- **Decisão**: componente `OccluderFade` (`scenes/components/occluder_fade.gd`) na cena base
  dos objetos (`scenes/props/prop.tscn`). Quando o personagem do jogador LOCAL (grupo
  `occlusion_viewer`) está atrás do objeto (pés acima da base), o objeto vai a 45% de
  opacidade em 0,15 s. Objetos com menos de 20 px de altura (pedras) desligam o efeito
  sozinhos. Prédios e outros objetos altos futuros herdam o comportamento.
- **Motivo**: o jogador nunca deve perder o próprio personagem de vista.
- **Consequências**: só apresentação (cada máquina do coop decide pelo seu jogador local);
  custo medido desprezível (0,43 ms/quadro com 164 árvores).

## ADR-011 — Arquitetura de combate: controladores, corpo único e componentes

- **Status**: Aceita (validada pelo João na Etapa D, 2026-10-22)
- **Decisão**:
  - **Um corpo para todos**: jogador e criaturas usam o mesmo `Character` (movimento, recuo,
    morte, renascimento). O que muda é o **controlador** que gera intenções: `LocalPlayerInput`
    (teclado/mouse/controle) ou `MonsterBrain` (IA). No coop, um terceiro controlador vai
    receber intenções pela rede — sem mudar o corpo.
  - **Componentes reutilizáveis** na cena base `scenes/actors/actor.tscn`: `Footprint`,
    `Health`, `MeleeAttacker`, `ActorFeedback`. Jogador e slime são cenas herdadas.
  - **Dano só na autoridade**: `MeleeAttacker` só aplica dano se `is_multiplayer_authority()`;
    `DamageInfo` carrega `source_player_id` para drops pessoais.
  - **Ataques em fases** (preparação → golpe → recuperação), definidos em dados. Preparação
    ≥ 0,2 s é telegrafada automaticamente (tom avermelhado) — regra testada.
  - **Acerto no plano do chão**: busca física larga + filtro exato de distância e ângulo
    no chão, para o arco ser justo em todas as direções.
  - **Defesa com retorno decrescente** (`dano × 100 / (100 + defesa)`) e vida das criaturas
    escalada por jogador extra (`data/balance/player_scaling.tres`).
  - **Drops pessoais**: a tabela é sorteada por jogador; cada um só vê e coleta os seus.
  - **Drops caem no chão** (pedido do João): o item salta da criatura até um ponto andável e
    alcançável em linha reta (`GroundQuery`; nunca na água ou dentro de objetos) e só pode
    ser pego depois de pousar, passando por cima. O "ímã" (16 px) é `ActorStats.pickup_radius`,
    para equipamentos futuros aumentarem por jogador.
  - Apresentação (números de dano em pool, rastro, flash, HUD) só **lê** sinais.
  - **Bote comprometido** (`MeleeAttackData.interruptible = false` no slime): levar dano não
    cancela a preparação do inimigo. Sem isso, segurar o ataque travava o slime para sempre
    (stun-lock, apontado pelo João). Teste `test_holding_attack_does_not_stun_lock_slime`.
  - **Coleira com evasão** (padrão de MMOs): ao passar da coleira, a criatura volta até casa
    em velocidade cheia, **imune** (semitransparente; golpes mostram "Imune") e sem perceber
    ninguém; em casa recupera a vida toda. Evita a oscilação na borda e os dois abusos
    apontados pelo João: bater nela pelas costas enquanto volta, e puxá-la para a borda para
    bater sem risco. Alternativas descartadas: perseguir sem limite (arrasta criaturas pelo
    mapa todo) e voltar a perseguir quem bate (abusável a distância).
- **Consequências**: criaturas novas = dados + cena herdada + (opcional) outro cérebro.
  Custo medido: ~15 µs por criatura ativa (`docs/03-desempenho.md`).

## ADR-012 — Replicação em rede: quem simula, quem decide

- **Status**: Aceita para o LAN (validada pelo João na Etapa D+, 2026-10-22); revisar antes do online
- **Decisão**:
  - **Quem decide é o host** (ADR-004): dano, vida, morte, renascimento, IA, criação e remoção
    de entidades, drops e inventários. Offline o jogo é o mesmo host, sem porta aberta.
  - **Quem simula o movimento**: o próprio jogador simula o SEU personagem (resposta imediata
    ao controle, sem esperar o host) e envia a posição ao host 20 vezes por segundo; o host
    **valida** (ADR-013) e repassa. Todo o resto (criaturas, outros jogadores) o host simula.
    Alternativa descartada por ora: predição com reconciliação (o host simula tudo e o cliente
    "adivinha" e corrige) — muito mais complexa; reavaliar se o online exigir.
  - **Entidades remotas são interpoladas**: desenhadas 0,1 s no passado, entre os dois
    estados recebidos vizinhos. Saltos acima de 48 px viram teletransporte (renascer).
  - **Criação** pelo `MultiplayerSpawner` ("Replicator"): o host chama `spawn_*`, cada
    computador monta o nó com a mesma função a partir de dados simples (sem caminhos nem
    objetos). Quem entra no meio da partida recebe tudo o que existe.
  - **Eventos confiáveis** (dano, vida, imunidade, renascimento, ataques) e **estados não
    confiáveis** (posição), por entidade, no componente `NetSync`. O host só manda mensagens
    sobre uma entidade a quem já confirmou tê-la (evita mensagens para nós que ainda não
    existem no cliente).
  - Ataques do jogador rodam na hora no computador dele (golpe, bote) e são pedidos ao host,
    que confere as próprias regras (vivo, ritmo) e decide o acerto com as posições que conhece.
- **Consequências**: no LAN o acerto usa posições ~0,1 s atrasadas do outro lado — fino no
  LAN, mas o online vai precisar de compensação de atraso. Custo medido: ~0,9 KB/s por
  entidade do host para cada cliente (`docs/03-desempenho.md`); muitas criaturas online vão
  pedir agrupamento de mensagens e "área de interesse".

## ADR-013 — Segurança de rede e de software

- **Status**: Aceita (regra permanente pedida pelo João, 2026-10-22)
- **Princípio**: tudo o que vem de outro computador é **não confiável** — inclusive o host,
  para o cliente. Nenhuma porta aberta sem necessidade, nenhuma "brecha para depois".
- **Decisões (Etapa D+)**:
  - **Porta só quando pedida**: offline não abre porta. `--host` escuta só em 127.0.0.1
    (invisível para a rede); só `--host-lan` escuta na rede local (Etapa I). Porta UDP
    padrão 24680; portas < 1024 recusadas.
  - **Aperto de mão**: identificação do jogo + versão do protocolo, comparada byte a byte
    (nada é interpretado). Errou ou não respondeu em 3 s: desconectado.
  - **Sem repasse entre clientes** (`server_relay = false`): cliente só fala com o host,
    que valida e repassa.
  - **Sem objetos pela rede** (`allow_object_decoding = false`); dados de criação conferidos
    campo a campo (tipo, faixa, item existente) e nunca carregam caminhos de arquivo,
    recursos ou scripts.
  - **RPCs mínimas e conferidas**: as do host → cliente são `authority` (cliente não pode
    chamá-las); as poucas `any_peer` (posição, pedido de ataque, pedido de estado) conferem o
    remetente (só o dono da entidade) e rejeitam NaN/infinito/valores fora de faixa.
  - **Validação de movimento**: o host aceita no máximo 3× a velocidade do personagem
    (cobre recuo e bote), medida no relógio DO HOST; teletransporte é recusado e o cliente
    volta à última posição aceita. Estados chegando rápido demais são descartados.
  - **Ritmo de ataque** conferido no host (folga de 0,05 s para variação de chegada).
  - **Dano só no host**: `Health.apply_damage` não faz nada fora dele, nem por engano.
  - **Limites**: no máximo 3 clientes; pacotes de sincronização até 1 KB.
- **Pendências registradas** (antes do coop pela internet — não aceitar sem resolver):
  - **Criptografia** (DTLS do ENet) e **código/senha da partida** — hoje desnecessários no
    127.0.0.1, obrigatórios antes de LAN aberta (código) e internet (ambos).
  - Detecção de atravessar paredes (hoje só velocidade é validada).
  - Limite de mensagens por segundo por cliente, com desconexão de quem abusar.
- **Software em geral**: nunca carregar recursos (`.tres`/`.tscn`) ou scripts vindos de
  saves, mods ou rede (podem conter código); saves em formato de dados puro (JSON ou
  `var_to_bytes` sem objetos). Nada de executar comandos do sistema a partir do jogo.

## ADR-014 — Coleta: pontos no mundo, ferramentas e níveis por tipo

- **Status**: Aceita (validada pelo João na Etapa E1, 2026-10-22)
- **Direção do João**: coleta no estilo Albion; monstros também dropam (tabelas com chance).
- **Decisões**:
  - **Pontos próprios de coleta** (`ResourceNode`), marcados visualmente (árvore de lenha,
    veio de cobre, carvalho antigo); o cenário comum é só enfeite. Cada ponto tem cargas,
    esgota (toco, cascalho) e **regenera** (`ResourceNodeData`, em `data/resource_nodes/`).
  - **Mãos coletam o básico**: sem ferramenta, só pontos que não exigem ferramenta, na
    metade da velocidade. Ferramentas (`ToolData`, um item) aceleram e liberam pontos de
    nível maior. Enquanto não há equipamentos (E4), vale a melhor ferramenta do inventário.
  - **Nível por tipo de coleta, pelo uso** (Lenhador, Minerador — `GatheringSkillData`):
    experiência a cada coleta; o nível acelera, dá chance de +1 no rendimento e é exigido
    por pontos melhores. Sem árvore de talentos por enquanto.
  - **Rendimento com chances**, reaproveitando `DropEntry` (o mesmo formato dos drops).
  - **Interação**: tecla E (botão A no controle) coleta o ponto mais próximo ao alcance;
    a coleta continua sozinha até esgotar; andar, atacar, apanhar ou morrer interrompem.
    Itens coletados vão **direto para o inventário** com aviso "+1 Madeira" (decisão
    técnica padrão; os drops de criaturas continuam caindo no chão). Revisável.
  - **Coop**: o dono coleta na hora e pede ao host, que confere alcance, ferramenta e nível
    de novo e decide itens, experiência e cargas (ADR-012/013). Nomes de pontos vindos da
    rede são validados (sem caminhos). Quem entra no meio da partida recebe o estado dos
    pontos.
- **Consequências**: novos recursos = dados + cena herdada de `resource_node.tscn`. Ainda
  não há como obter ferramentas no jogo (vem com o crafting, E3).
