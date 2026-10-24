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

- **Status**: Hipótese (uma região funcionando na Etapa C; estado salvo na F1 — ADR-019, pelo `SaveService`; transições na F2)
- **Decisão**:
  - Cada região é **uma cena Godot** (TileMapLayers + entidades), carregada uma por vez no
    single-player.
  - Um serviço de estado do mundo (`WorldState`) guarda o que persiste: recursos coletados e
    tempo de regeneração, baús, chefes derrotados, portais desbloqueados, NPCs.
  - Ao entrar em uma região: carrega a cena e aplica o estado salvo. Ao sair: salva o estado
    e libera a cena.
  - Chunks dentro de uma região só se medições mostrarem necessidade.
  - Dungeons temporárias/instanciadas: decidir quando forem implementadas.
- **Coop (decidido pelo João, 2026-10-22)**: jogadores podem estar em regiões diferentes; o host
  simula toda região ocupada. Benchmark da F2b (2026-10-22, `docs/03-desempenho.md`): 4 regiões
  em combate ~3 ms no PC de dev, viável. Texto original do ponto aberto:
  jogadores em regiões diferentes ao mesmo tempo (o host
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
  - **Personagens e cosméticos** (João, 2026-10-22): `docs/referencias/exemplo-hero-siege.png`
    é o "exemplo perfeito" de sprites de personagem e cosméticos (Hero Siege): silhueta
    própria por classe (chapéus, capuzes, chifres, armas grandes), poucas cores fortes por
    personagem, contorno escuro e leitura clara sobre chão escuro. Referência de intenção, sem
    copiar personagens nem sprites.
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
  entidade EM MOVIMENTO do host para cada cliente; parada, ~0,1 KB/s (H3: estado repetido só a
  cada 0,5 s; `docs/03-desempenho.md`); muitas criaturas online vão
  pedir agrupamento de mensagens e "área de interesse".

## ADR-013 — Segurança de rede e de software

- **Status**: Aceita (regra permanente pedida pelo João, 2026-10-22)
- **Princípio**: tudo o que vem de outro computador é **não confiável** — inclusive o host,
  para o cliente. Nenhuma porta aberta sem necessidade, nenhuma "brecha para depois".
- **Decisões (Etapa D+)**:
  - **Porta só quando pedida**: offline não abre porta. `--host` escuta só em 127.0.0.1
    (invisível para a rede); só `--host-lan` escuta na rede local (Etapa I). Porta UDP
    padrão 24680 (jogo) e 24681 (porta da frente, I2); portas < 1024 recusadas.
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
  - **Regiões (F2c)**: o cliente não escolhe região: só o host decide, pelas passagens que
    ele mesmo detecta. O id de região que chega ao cliente só serve para buscar no catálogo.
    Cada cliente só recebe a própria região. Custo aceito: o host simula até uma região por
    jogador (medido na F2b).
- **Pendências registradas** (antes do coop pela internet — não aceitar sem resolver):
  - ✅ **Código da partida** (I1, `MatchCode`): o host da rede local sorteia 8 letras (sem
    0/O, 1/I/L; 6 na I1, ver abaixo) e as mostra na tela; só entra quem as digitar. O código
    nunca trafega: já dentro da conexão criptografada, o host manda um desafio aleatório de
    16 bytes e o cliente responde com HMAC-SHA256 do desafio, tendo o código como chave
    (comparação em tempo constante). 5 provas erradas seguidas do mesmo endereço bloqueiam
    esse endereço por 1 minuto. O cliente só conclui o aperto de mão quando o host diz
    "aceito"; recusado, o host diz o motivo (versão, código, bloqueio, perfil repetido) e
    desconecta 0,25 s depois. O host só deste computador (`--host`) não pede código.
  - ✅ **Criptografia** (I2, DTLS do ENet; `HostIdentity`, `DoorProtocol`): todo o tráfego do
    jogo é criptografado, inclusive o segredo do perfil e a prova do código. Na Godot 4.7 o
    cliente DTLS só conecta se já tiver o certificado do host (até o modo "sem conferir" confere
    a cadeia; medido), então:
    1. O host cria chave RSA 2048 e certificado próprio a cada execução (~250 ms, nada em
       disco) e abre a **porta da frente** (UDP, porta do jogo + 1).
    2. O cliente pede o certificado ali; o host responde certificado + selo HMAC-SHA256 do
       desafio do cliente e do certificado, com chave derivada do código. O cliente confere o
       selo antes de confiar: sem o código, um intermediário não troca o certificado. Código
       errado é detectado aqui (o cliente nem conecta).
    3. Conexão DTLS confiando só nesse certificado (nome conferido); cliente sem DTLS ou com
       outro certificado não conecta (testado).
    - Contra **adivinhar o código** a partir do selo (que é público: qualquer um pode pedir):
      8 letras (31^8 ≈ 850 bilhões), chave lenta (65 536 SHA-256 por tentativa, ~70 ms) e
      "sal" com o certificado (novo a cada execução: nenhuma tabela pronta serve). Estimativa:
      meses numa placa de vídeo por código, e o código muda a cada vez que se hospeda.
    - **Porta da frente sem amplificação**: pedido de 1400 bytes, resposta ~1200 (ninguém a usa
      para multiplicar tráfego contra outro computador); uma resposta por endereço a cada 0,1 s;
      lê no máximo 32 pedidos por quadro.
    - **Correção sobre a I1**: sem criptografia, o desafio e a resposta HMAC trafegavam abertos
      e o código tinha 6 letras; quem gravasse a conversa poderia testar códigos no próprio
      computador em segundos. A I2 resolve: a prova vai criptografada, e o único valor aberto (o
      selo) tem chave lenta e 8 letras. A I1 nunca foi usada fora deste PC.
    - Custo (teste de carga, 4 jogadores): CPU do host +0,1–0,25 ms; ~29 bytes a mais por pacote
      (andando, 3,7 → 6,3 KB/s por cliente; combate igual). Entrar leva ~0,6 s: o ENet reenvia o
      primeiro pacote, perdido enquanto a criptografia se acerta.
    - Pendente para a internet (não para a LAN): o código é a única prova de identidade do host;
      bom para amigos que trocam o código por voz/mensagem.
  - ✅ Detecção de atravessar paredes (H4): o host refaz o caminho desde a última posição aceita
    deslizando nas paredes como o `move_and_slide` do dono (mesma pegada, 4 deslizes); parou a
    mais de 3 px do ponto recebido = parede no caminho, e o dono volta para onde o deslize parou
    (engano raro do host vira ajuste pequeno). Testado: atravessar recusado; deslizar em volta de
    uma árvore por 8 lados e 1 minuto de passeio entre árvores e pedras sem nenhuma correção.
    **Toda habilidade futura que mova o personagem (investida, teleporte) passa por esta
    conferência ou é decidida no host.**
  - ✅ Limite de pedidos por cliente (H4, `PeerGuard`): cota de 60 por segundo com folga de 120,
    no relógio do host; esgotou = desconectado (a saída passa pelo caminho normal e o save guarda o
    personagem). Conta ações e pedidos que fazem o host responder muito; os "uma vez por
    computador" ao receber entidades (centenas ao entrar numa região) ficam de fora, e repetidos
    não custam nada. Um jogador em combate fica bem abaixo (teste de carga H3 sem desconexões).
  - ✅ **Segredo do perfil** (ADR-019): trafega só dentro da conexão criptografada (I2).
  - **Espera da poção não vai no save** (ADR-022): sair e voltar zera a espera (10 s). Risco
    pequeno; se incomodar, guardar o tempo restante no personagem.
- **Ferramentas de desenvolvimento** (kit de testes, mercador de testes que dá tudo por 0): só
  existem com `OS.is_debug_build()` e a chave em `game/debug/` ligada; um jogo exportado nunca as
  tem. No coop de desenvolvimento o host com o mercador de testes também dá tudo de graça aos
  clientes (é o objetivo); a compra continua decidida no host, com o preço dos dados dele.
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

## ADR-015 — Textos centralizados para tradução

- **Status**: Aceita (pedido do João, 2026-10-22)
- **Decisão**:
  - Todo texto que o jogador vê vem de **uma tabela**: `data/i18n/texts.csv`, uma linha por
    chave e uma coluna por idioma (sistema de tradução nativo da Godot). Hoje: `pt_BR` (base e
    idioma reserva) e `en`.
  - Código usa `Texts.get_text(chave)` / `Texts.format(chave, valores)`; nada de frase para o
    jogador escrita no código ou nos dados. Textos de depuração (painel F3, logs) ficam fora.
  - **Nomes vêm do id**: item `wood` → `ITEM_WOOD`; também `SKILL_`, `NODE_`, `MONSTER_`.
    Os `.tres` não guardam nomes (`get_display_name()`).
  - Idioma: o do sistema operacional; `-- --lang=en` força outro (menu de opções no futuro).
  - Teclas mostradas ao jogador saem do mapa de entrada, no layout do teclado dele
    (`Texts.action_key`).
- **Consequências**: novo idioma = nova coluna na tabela (o teste confere que todo idioma
  tem todos os textos, com os mesmos marcadores de valores). A fonte m5x7 cobre o alfabeto
  latino com acentos; idiomas com outros alfabetos pedirão outra fonte.

## ADR-016 — Inventário em espaços com pilhas

- **Status**: Aceita (validada pelo João na Etapa E2, 2026-10-22)
- **Decisões**:
  - **Espaços com pilhas** (escolha do João): cada espaço guarda um tipo de item até
    `ItemData.max_stack` (99; ferramentas 1).
  - **Mochilas** (pedido do João, estilo Grand Fantasia/Forager): sem mochila, 12 espaços
    (`ActorStats.inventory_slots`); mochilas equipadas somam espaços até um máximo — chegam
    com os equipamentos (E4).
  - **Cheio**: drops esperam no chão; a coleta só começa/continua se couber o pior caso do
    rendimento (nada se perde no meio).
  - **Janela livre** (pedido do João): I / Tab / botão Y abrem e fecham, Esc fecha; o jogador
    arrasta a janela pela barra de título e ela lembra a posição (`UserSettings`, só neste
    computador). Andar e lutar com ela aberta funcionam; cliques sobre a janela não atacam.
    Grade com ícone, quantidade e nome ao passar o mouse.
  - **Clicar para segurar** (pedido do João, no lugar de arrastar): um clique pega a pilha, que
    segue o ponteiro; clicar num espaço põe, junta ou troca (o item do espaço vem para a mão);
    clicar fora da janela joga no chão (o dono só pega de volta depois de se afastar); fechar
    o inventário devolve a mão aos espaços. A **mão é estado do host** (parte do inventário):
    nada some nem se duplica no coop.
  - **Menu do botão direito** (pedido do João, E3): "Dividir" (pilhas de 2+) e "Soltar" (a
    pilha inteira cai no chão; o host pega e joga fora de uma vez). Fecha com Esc ou clique
    fora, sem atacar.
  - **Dividir pilha** (pelo menu, mão vazia): janelinha com régua; a parte separada vai
    para a mão (pode ser posta em qualquer espaço ou jogada fora).
  - **Clique da interface não ataca**: um clique de mouse só vira ataque se começou com o
    cursor livre (fora de janelas, sem item na mão, sem arrastar janela).
  - **Filtro por categoria** (ideia do João): preferido a abas, por manter a grade real e
    só apagar o que não é da categoria. Entra quando houver consumíveis e itens de missão.
  - **Rede**: o host decide; o dono recebe cada espaço alterado e os ganhos como eventos
    separados (mover itens não gera aviso "+1"). Pedidos do dono (mover, jogar fora) são
    conferidos: só o próprio inventário, índices válidos. Estado por jogador em
    `PlayerStateSync` (separado da conexão em `Network`).
- **Consequências**: crafting (E3) usa `Inventory.remove`/`can_add_all`; equipamentos (E4)
  e bolsas mudarão o tamanho por jogador.

## ADR-017 — Fabricação em três níveis: mão, bancada e NPC

- **Status**: Aceita (validada pelo João na Etapa E3, 2026-10-22)
- **Direção do João (2026-10-22)**: coisas simples são feitas **na mão**, outras só **numa
  bancada**, e algumas só **com NPCs específicos**.
- **Decisões**:
  - **Receitas em dados** (`RecipeData`, um `.tres` por receita em `data/recipes/`):
    ingredientes (id → quantidade), resultado e lugar (`HAND`, `WORKBENCH`, `NPC`).
  - **Regras puras** em `CraftingRules`: confere lugar, ingredientes e espaço; a troca é
    tudo-ou-nada. Os ingredientes liberam espaço antes de o resultado entrar
    (`Inventory.can_exchange`), então dá para fabricar com o inventário cheio se uma pilha
    acabar.
  - **Rede**: o dono pede por id; o host confere tudo de novo (id desconhecido, lugar fora de
    alcance ou falta de ingrediente = nada acontece) e só ele mexe no inventário (ADR-013).
  - **Bancada** (escolha do João: o jogador fabrica e coloca, como Terraria/Forager): receita
    feita na mão; vira estrutura no mundo (`StructureData` + item `PlaceableData`). Com ela na
    mão (inventário), uma prévia segue o ponteiro, verde onde pode e vermelha onde não pode;
    clicar fora da janela coloca. Regra única (`PlacementRules`): até 48 px de chão do
    jogador, chão livre de água, objetos e personagens, e sem obstáculo no caminho. O host
    usa o que ELE sabe estar na mão do jogador e confere o ponto. Estruturas bloqueiam a
    passagem e qualquer jogador usa qualquer bancada. As receitas da bancada aparecem sempre
    na lista, apagadas longe de uma; acendem a até 40 px de chão dela, e o host confere a
    distância. **NPC**: receitas ficam indisponíveis até haver NPCs (Etapa F), que dirão
    quais ensinam.
  - **Coluna recolhível** (pedido do João): clicar em "Fabricar" esconde/mostra as receitas;
    a escolha fica em `UserSettings` (só neste computador).
  - Uma unidade por pedido, instantânea (tempo de fabricação e "fazer N" ficam para depois,
    se o João quiser).
- **Consequências**: nova receita = novo `.tres`; nova estrutura = `StructureData` + item
  `PlaceableData` (fornalha, baú...). Versão do protocolo de rede: 2. Pendências: recolher
  ou desmontar uma estrutura colocada; estruturas somem ao fechar o jogo (sem saves ainda).
  O teste confere que ingredientes e resultado existem.

## ADR-018 — Equipamento: espaços estilo Terraria/Forager e mãos estilo Path of Exile

- **Status**: Hipótese (Etapa E4, aguardando validação do João)
- **Direção do João (2026-10-22)**: espaços como Terraria/Forager, mas com **poucos
  acessórios** (para não exigir muita variedade de itens logo no início); armas de 1 e 2 mãos,
  cajado de 1 mão com tomo, cajado de 2 mãos, arco de 2 mãos com aljava (como Path of Exile).
- **Decisões**:
  - **Espaços** (`EquipmentLayout`, em `data/balance/equipment_layout.tres`): mão principal,
    mão secundária, cabeça, peito, pernas, mochila e **2 acessórios**. Mais espaços = só dados.
  - **Itens**: `EquipmentData` (tipo de espaço), `WeaponData` (1 ou 2 mãos e quais
    secundários aceita: `off_hand_kinds`), `OffHandData` (escudo, tomo, aljava). Pilha de 1.
  - **Mãos**: o secundário precisa ser aceito pela arma (espadão: nenhum; arco: aljava;
    cajado de 1 mão: tomo; espada: escudo — tudo em dados). De mãos vazias, qualquer
    secundário serve. Vestir uma arma que não aceita o secundário atual o devolve ao
    inventário; sem espaço para ele, a arma não é vestida (nada se perde).
  - **Acessórios**: nunca dois iguais.
  - **Como vestir**: menu "Equipar" no item do inventário, ou segurar o item e clicar no
    espaço; clicar num espaço com a mão vazia tira o item para a mão. Regras puras em
    `EquipmentRules`; estado por jogador em `Equipment` (sessão); o host decide e envia cada
    espaço ao dono (ADR-012/013), que confere tipo e índice.
  - **Escolher a mão (direita/esquerda)**: proposto pelo João e **não adotado** por enquanto.
    O personagem é espelhado ao virar (a "mão direita" troca de lado na tela); escolher a mão
    dobraria a arte de cada animação de arma para uma diferença de 2–3 px. Fica no backlog.
  - **Variedade de armas**: arco, cajados e tomo ficam previstos nas regras (testados com
    itens de teste), mas o comportamento (projéteis, magias) depende do sistema de
    habilidades, que terá etapa própria.
- **Consequências**: o equipamento passa a ser a fonte de atributos (passo 2: defesa, vida,
  velocidade, ímã, espaços de mochila, ataque da arma). Visual do equipamento no personagem
  fica para a arte real. Pendência: navegar inventário e equipamento só por teclado/controle
  (hoje é com mouse; vale para toda a janela, não só o equipamento).
- **Ajustes após o teste do João**: trocar equipamento **não mexe na vida atual**, só a limita
  ao novo máximo (escolha do João; sem brecha de cura). Antes, somar o ganho curava e manter a
  proporção ia baixando a vida no arredondamento. Defesa: o ponto de "metade
  do dano" saiu do código para `data/balance/combat.tres` e caiu de 100 para 20 — com 100, a
  defesa 2 do escudo sumia no arredondamento.

## ADR-019 — Save do mundo no host, com o progresso de todos os personagens

- **Status**: Aceita (validada pelo João na Etapa F1, inclusive no coop, 2026-10-22)
- **Contexto**: sem save não há progressão. Escolha do João: o progresso fica **no mundo do
  host** (como o coop do Stardew Valley), não num arquivo de personagem que viaja entre mundos
  (Terraria). O amigo continua de onde parou sempre que entra no mesmo mundo; o personagem dele
  não vai para outros mundos. Ganho de segurança: nada do progresso vem do PC do amigo.
- **Decisões**:
  - **Um arquivo por mundo** (`user://saves/world.json`; vários mundos e menu vêm depois):
    personagens por chave de jogador e estado de cada região (estruturas colocadas, cargas e
    renascimento dos pontos de coleta). `WorldSave` (arquivo), `CharacterRecord` (personagem:
    inventário com a mão, equipamento, experiência, vida atual), `SaveService` (host).
  - **Não são guardados**: itens no chão e criaturas (o mundo volta com criaturas novas) nem a
    posição do jogador (volta ao ponto de entrada da região).
  - **Quando grava**: jogador saiu, janela fechada e a cada 30 s. Parar pelo editor da Godot
    mata o processo: perde no máximo 30 s.
  - **Arquivo = dado não confiável**: JSON puro (nunca objetos, recursos ou scripts), até 4 MB,
    versão conferida; cada valor passa por `SaveValues` (número finito na faixa). Item que não
    existe, pilha acima do limite e equipamento fora do lugar são ignorados. Gravação segura
    (temporário + troca; o anterior vira `.bak`). Arquivo ilegível nunca é sobrescrito: vai
    para `.corrupt-<hora>`; se nem isso der, o save desliga.
  - **Identidade do jogador**: cada computador cria um segredo aleatório de 32 bytes
    (`user://profile.cfg`, `PlayerProfile`) e o envia no aperto de mão; o host guarda só o
    SHA-256 como chave. Quem hospeda usa a chave `host`. A mesma chave conectada duas vezes é
    recusada. Protocolo de rede: versão 4.
  - **Kit de testes** só para personagem novo (quem volta não ganha outro).
- **Consequências**: reconexão funciona (quem volta recebe o próprio personagem). Testes,
  capturas de tela e `capture_frames` não leem nem gravam o save de quem joga.

## ADR-020 — Várias regiões, passagens e viagem

- **Status**: Aceita (F2 validada pelo João, inclusive no coop, 2026-10-22)
- **Contexto**: segunda região (floresta densa, escolha do João) ligada à campina. No coop,
  cada jogador poderá estar numa região diferente (decisão do João, ADR-005), se o benchmark
  da F2b mostrar que o host aguenta.
- **Decisões (F2a, jogando sozinho)**:
  - **Catálogo** `data/regions/` (`RegionData`: id e cena). Ids vindos do save só servem para
    buscar no catálogo.
  - **Passagem** (`scenes/regions/passage.tscn`): gatilho no fim de um caminho de terra que
    atravessa o anel de água, parede invisível atrás (não se sai do mapa) e ponto de chegada
    longe do gatilho. Destino em dados: região e passagem de destino.
  - **Viagem**: a região anterior vai para o save (memória) e é liberada com as criaturas e os
    itens no chão; o personagem troca de pai na árvore (sem sair da sessão) e chega na
    passagem de volta. Renascimentos agendados na região anterior são descartados.
  - **Save**: o host sempre tem o save na memória (sem arquivo = só memória); cada personagem
    guarda a região onde estava e volta ao ponto de entrada dela.
  - **Ambientação**: cada região tem luz ambiente (`ambient`, CanvasModulate); a floresta é
    mais escura e esverdeada. Textos do mundo (números, avisos) ficam numa camada própria, fora
    dessa luz, para continuarem legíveis.
  - **Gerador** `tools/generate_regions.gd` (antes `generate_meadow_region.gd`): receitas por
    região; o caminho é aberto depois de tudo sorteado, então a campina continua idêntica
    (mesmos nomes e posições: o save dela continua valendo).
- **Decisões (F2c, coop: cada jogador na região que quiser)** — benchmark da F2b: viável:
  - **Cada região num mundo próprio** (`RegionWorlds`): um SubViewport por região carregada,
    com física e desenho só dela, que nunca desenha sozinho. A janela passa a usar o mundo da
    região do jogador local (`Viewport.world_2d`), então câmera, interface e textos do mundo
    ficam onde sempre estiveram. A câmera copia a posição do personagem a cada passo de física
    (antes era filha dele). Mira do mouse calculada pela janela.
  - **Host**: carrega toda região com jogador (no máximo uma por jogador) e simula todas; a que
    fica vazia é guardada no save (memória) e liberada pouco depois (1,5 s, ver abaixo).
  - **Quem está onde**: a própria região guarda os jogadores presentes (host). É a única fonte:
    decide criaturas que perseguem (só da mesma região), drops pessoais (só de quem está lá),
    vida das criaturas pela quantidade de jogadores na região e o que cada cliente recebe.
  - **Cada cliente só recebe a região dele**: um replicador (MultiplayerSpawner) por região, com
    o mesmo caminho nos dois lados, e um "portão" em cada entidade (MultiplayerSynchronizer sem
    propriedades) cuja visibilidade o host decide. Mensagens sobre nós de uma região
    (`HostBroadcast`) só vão para quem está nela; pedido atrasado de quem já saiu fica sem
    resposta.
  - **Viagem = personagem recriado** na região de destino (o replicador de uma região não leva
    um nó para a outra). Inventário, equipamento e níveis ficam na sessão; a vida vai junto. O
    personagem antigo some para todos na hora, mas fica 1 s parado no host ignorando mensagens
    atrasadas do dono; a região vazia espera um pouco mais que isso antes de ser liberada.
  - **Ordem na viagem de um cliente** (canal confiável, em ordem): some o que é da região antiga
    → aviso "carregue a região X" (`Main._enter_region`, id conferido no catálogo) → chegam as
    entidades da nova e o personagem dele. Quem entra na partida segue o mesmo caminho e volta
    para a região onde estava (save).
  - Protocolo de rede: versão 5.
  - **Textos do mundo**: a Godot solta a camada que segue a câmera ao trocar o mundo da janela;
    o Main a recoloca na árvore a cada troca. Verificado com imagem (`tests/render_checks.gd`).
- **Limitações**: pontos de coleta de uma região sem ninguém não renascem enquanto ninguém está
  lá; itens no chão somem ao sair da região; a troca de região é um corte seco (sem
  transição).

## ADR-021 — Moedas, NPCs fixos e loja

- **Status**: Aceita (F3a validada pelo João, 2026-10-22)
- **Direção do João (2026-10-22)**: moedas numa **carteira separada** do inventário (como a prata
  do Albion e as moedas do Forager): não ocupam espaço nem caem no chão.
- **Decisões**:
  - **Carteira** (`Wallet`, por jogador na `GameSession`): só o host altera, tudo ou nada, teto
    de 999.999.999. O dono recebe o valor oficial e cada ganho (aviso "+N moedas"). Vai no save
    do personagem (`coins`, conferido por `SaveValues`).
  - **De onde vêm** (escolha técnica, ajustável): por enquanto só da **venda ao mercador**.
    Moedas caindo de criaturas ficam como opção para quando o João quiser.
  - **Preços em dados**: `ItemData.sell_price` (quanto um mercador paga por unidade; 0 = ninguém
    compra) e `NpcData.offers` (item → preço de compra). Teste garante que nada se compra por
    menos do que se vende (sem moedas infinitas).
  - **Regras puras** em `TradeRules`: comprar uma unidade; vender N de um espaço. Tudo ou nada
    (sem moedas, inventário cheio, carteira no teto = nada muda).
  - **NPC fixo** (`Npc` + `NpcData` em `data/npcs/`): faz parte da cena da região (igual em
    todos os computadores, sem estado de jogo). O mercador é posto pelo gerador perto da entrada
    da campina, depois de todo o sorteio (o resto do mapa e o save continuam iguais).
  - **Rede**: o cliente pede "comprar item X" ou "vender N do espaço i"; o host usa o NPC que ELE
    sabe estar ao alcance do jogador vivo e os preços dos dados dele, nunca algo dito pelo
    cliente. Protocolo de rede: versão 6.
  - **Interface**: a tecla de interagir perto de um NPC abre a loja (prioridade sobre a coleta);
    o "[E] Mercador" aparece ao chegar perto. A loja abre junto com o inventário; comprar é
    clicar na oferta (apagada com o motivo na dica quando não dá); vender é pelo menu do botão
    direito do inventário ("Vender 1" / "Vender tudo", com quanto rende), o mesmo gesto de opções.
    Afastar-se, interagir de novo ou fechar o inventário encerra a conversa.
- **Consequências**: novo NPC = `NpcData` + cena + posição no gerador. A F3c (receitas de NPC)
  pode usar o mesmo NPC como estação `NPC`. Pendência: navegar a loja só por teclado/controle
  (como o inventário, ADR-018).

## ADR-022 — Consumíveis e poção de vida

- **Status**: Aceita (F3b validada pelo João, 2026-10-22)
- **Decisões** (técnicas, ajustáveis em `data/`):
  - **Consumível** = `ConsumableData` (item com `heal`, `cooldown` e `cooldown_group`). Usar gasta
    uma unidade. Regras puras em `ConsumableRules`, tudo ou nada: vida cheia não bebe (não
    desperdiça), morto não bebe, esperando não bebe.
  - **Poção de vida**: cura 40 (de 100) na hora, espera de 10 s entre poções (grupo `potion`),
    pilha de 20. O mercador vende por 15 e compra por 4. Cura instantânea com espera (como Hero
    Siege/Diablo) em vez de cura ao longo do tempo: mais legível no combate de agora.
  - **Como beber**: tecla de poção (**Q**, botão LB do controle) bebe a primeira poção de vida do
    inventário, sem abrir nada; no inventário, botão direito → "Usar". O HUD mostra a poção ao
    lado da vida (quantidade, tecla e os segundos de espera). Sem poções o quadrado fica apagado.
  - **Esperas** (`Cooldowns`, por jogador na `GameSession`): o host decide e envia ao dono cada
    espera começada; o dono conta no próprio relógio (chega depois, então nunca libera antes do
    host). Não vão no save.
  - **Rede**: o cliente pede "usar espaço i" ou "beber poção"; o host escolhe a poção e confere
    tudo com o estado dele. A cura é decidida só no host (`Health.heal`); todos veem o "+40" verde
    e o brilho verde. O dono confere antes de pedir para explicar a recusa ("Vida cheia",
    "Poção ainda não está pronta", "Sem poções"). Protocolo de rede: versão 7.
- **Consequências**: comida, antídotos e buffs (Etapa G) entram como novos campos ou subclasses de
  `ConsumableData`, usando o mesmo pedido e as mesmas esperas. A F3c pode ensinar a fabricar a
  poção (ex.: com gosma) num NPC.

## ADR-023 — Receitas aprendidas com NPCs

- **Status**: Aceita (F3c validada pelo João, 2026-10-22)
- **Direção do João (2026-10-22)**: **aprender e levar** — o NPC vende a receita; aprendida uma
  vez, fica com o personagem e se fabrica longe dele (na bancada ou na mão, conforme a receita).
- **Decisões** (técnicas, ajustáveis em `data/`):
  - **Receita a aprender** = `RecipeData.must_learn`. As outras todo mundo sabe, como antes. O
    lugar "NPC" das receitas (`Station.NPC`, nunca usado) saiu: o NPC ensina, não fabrica.
  - **Livro de receitas** (`RecipeBook`, por jogador na `GameSession`): só o host altera; vai no
    save do personagem (`recipes`, só ids de receitas que existem e se aprendem).
  - **Quem ensina**: `NpcData.recipe_offers` (receita → preço). Regras puras em `TradeRules`
    (`check_learn`/`learn`, tudo ou nada): ensinada por ele, ainda não sabida, moedas que bastem.
    Teste garante que toda receita a aprender é ensinada por alguém e que comprar ingredientes,
    fabricar e vender nunca dá lucro (fabricar com o que foi coletado pode render: é trabalho).
  - **Primeira receita**: poção de vida = 3 gosmas, na mão (em qualquer lugar; pedido do João na
    validação); o mercador ensina por 40 moedas
    (a poção custa 15 na loja e é vendida por 4; 3 gosmas valem 6).
  - **Rede**: o cliente pede "aprender receita X"; o host usa o NPC que ELE sabe estar perto e o
    preço dos dados dele. O dono recebe cada receita aprendida (marcada "nova" só quando acabou
    de aprender, para o aviso não repetir ao entrar). Fabricar confere o livro do host.
    Protocolo de rede: versão 8.
  - **Interface**: a loja ganha a seção "Receitas" ("Receita: Poção de vida" + preço; dica com
    onde e com o quê se fabrica). Aprendida, a linha fica apagada com "Já aprendida". Na lista
    de fabricação, receitas a aprender aparecem apagadas com "Aprenda esta receita com um NPC"
    (não esconder o que o jogador vai poder usar). Aviso verde "Receita aprendida: ...".
- **Consequências**: a F5 (chefe libera receita) pode dar uma receita pelo mesmo livro
  (`learn` no host), sem NPC. Novas receitas de NPC = arquivo em `data/recipes/` com
  `must_learn` + preço no `recipe_offers` do NPC.

## ADR-024 — Mini boss: Rei Slime e o salto com aviso no chão

- **Status**: Aceita (F4a + F4b validadas pelo João, 2026-10-23)
- **Direção do João (2026-10-22)**: o primeiro mini boss é o **Rei Slime** (slime gigante), numa
  clareira da floresta; fase 2 se divide em slimes pequenos e salta mais rápido (F4b).
- **Decisões** (técnicas, ajustáveis em `data/`):
  - **Salto com queda em área** = `SlamAttackData` (dano, raio, recuo, distâncias, aviso, voo,
    recuperação, espera, altura, tremor) num componente reaproveitável `SlamAttacker`: qualquer
    criatura com o nó e `MonsterData.slam` salta. A IA (`MonsterBrain`) salta em alvos a meia
    distância se o ponto de queda for chão livre; perto, usa o golpe comum.
  - **Justo e legível** (game-feel): o ponto de queda é decidido no início (onde o alvo estava) e
    mostrado no chão (`GroundTelegraph`: contorno + miolo que enche até a queda). Sair do
    círculo evita o dano. Depois da queda, 1,2 s parado (janela para bater). O chefe avermelha
    no aviso, sobe num arco com a sombra no chão, esborracha ao cair, com onda no chão e tremor
    de câmera para quem está perto (só apresentação, nada pela rede).
  - **Camada de efeitos no chão** (`Region.ground_effects`): criada em cada computador, entre o
    chão e as entidades; nunca replicada.
  - **Alvos** de golpes e do impacto num lugar só (`ActorQuery.hostiles_near`).
  - **Chefe** = `MonsterData.is_boss`: barra de vida no alto da tela (`BossBar`) para quem está
    perto. Rei Slime: 300 de vida (escala por jogadores como as criaturas), lento, imune a recuo,
    golpe 12, salto 25. Drop pessoal: **Núcleo do Rei Slime** (sempre) e 5 a 10 gosmas.
    Renasce em 5 min. Clareira aberta pelo gerador no leste da floresta (último ponto de
    criatura: os outros mantêm o número).
  - **Rede**: só o host simula o chefe e aplica o dano; ele avisa os clientes do salto (ponto de
    queda, conferido) e eles o mostram com o mesmo atraso de desenho da posição.
    Protocolo de rede: versão 9.
  - **Fase 2** (F4b, `MonsterData.phase_two_*`): abaixo de metade da vida o chefe se enfurece:
    salto mais rápido (aviso 0,6 s, espera 2 s), aviso "Rei Slime se enfurece!" e barra laranja;
    curado (voltou para casa), volta à fase 1. A fase vem da vida, que todo computador conhece.
    Cada queda na fase 2 solta 2 filhotes (slimes comuns, no máximo 4 vivos), sem drops (não vira
    fazenda de gosma) e sem renascer; somem se o chefe morre ou desiste. Rede: tipo de criação
    "filhote" ligado ao chefe que o invocou (o cliente confere que esse chefe existe ali e tem
    filhotes; nada de cena vinda da rede). Protocolo de rede: versão 10.
  - **Bote dos slimes vira investida** (relato do João na F4a): o flash de dano apagava o
    vermelho do aviso (o bote parecia sair do nada) e o dano só valia no instante do golpe, para
    quem estava colado (correr anulava o bote). Agora o flash volta ao vermelho, o avanço é mais
    longo e acerta quem tocar (`lunge_hit_time`, uma vez cada) e a criatura começa de mais longe
    (`engage_distance`). Vale para todos os slimes. Desempenho: uma consulta de física por bote
    (candidatos), depois só distância.
- **Core x conteúdo** (João, 2026-10-22): o Rei Slime é um **banco de testes** das mecânicas de
  chefe, não um chefe definitivo (arte, números, nome e lugar podem mudar quando os chefes de
  verdade forem desenhados). O que é core e fica: salto com aviso, fases por vida, filhotes
  ligados ao chefe (seguem o chefe e atacam o alvo dele; correção do teste do João), barra de
  chefe, drop especial.
- **Consequências**: novos chefes ou criaturas que saltam = dados + cena com `SlamAttacker`. A F4b
  (fases) e a F5 (o núcleo libera algo) usam esta base.
- **F5a (João, 2026-10-23)**: o drop do chefe libera uma **receita de equipamento** (não uma área).
  O núcleo é ingrediente da Coroa do Rei Slime (bancada; cabeça, melhor que o elmo de cobre).
  Regra testada (`tests/test_progression.gd`): drop exclusivo de chefe sempre serve a uma receita.
  Validado pelo João (2026-10-23). Pendente para quando houver ataques à distância: o chefe passa a
  perseguir quem o fere de longe (ameaça por dano), ver "Direção de combate" no plano.

## ADR-025 — Buffs e debuffs (efeitos com duração)

- **Status**: Aceita (G1a, G1b e G1c validadas pelo João, 2026-10-23)
- **Direção do João (2026-10-23)**: a Etapa G começa por buffs e debuffs (base que habilidades,
  auras e poções vão usar); auras e cosméticos vêm na G3.
- **Decisões** (técnicas, ajustáveis em `data/`):
  - **Efeito = dado** (`StatusEffectData` em `data/effects/`): duração, buff ou debuff, bônus de
    atributos (o mesmo `StatBonuses` do equipamento, podendo ser negativo) e dano/cura por tick.
    Quem aplica (golpe, poção, habilidade) só aponta para o efeito.
  - **Reaplicar renova** o tempo cheio, sem empilhar nem somar; o ritmo dos ticks continua.
  - **Regras sem nós** em `ActiveEffects`; o componente `StatusEffects` (na cena base de todo ator)
    cobra os ticks no host. Bônus dos efeitos somam aos do equipamento em `Character.bonuses`.
    Pisos: velocidade nunca abaixo de 20%, defesa nunca negativa, vida máxima no mínimo 1.
  - **Dano de efeito** (`DamageInfo.periodic`): ignora defesa e invulnerabilidade e não atordoa,
    empurra nem interrompe (veneno não trava o jogador nem vira "stun-lock").
  - **Jogadores**: os efeitos ficam na sessão, por jogador (como carteira e esperas): continuam
    depois de viajar entre regiões e vão no save (tempo restante). Criaturas: no próprio componente.
  - **Morrer ou ficar imune** (criatura voltando para casa) limpa os efeitos.
  - **Desempenho**: sem efeito ativo, o componente não roda por quadro (medido: sem custo extra
    com 200 slimes).
- **Rede e segurança** (ADR-013): só o host aplica efeitos e cobra ticks; nenhuma RPC nova que o
  cliente possa chamar. O host envia a lista inteira ({id: segundos}) a cada mudança e no estado
  completo; o cliente confere cada id no catálogo local e limita o tempo à duração do efeito
  (nada de recurso vindo da rede). O save passa pela mesma conferência. Protocolo: versão 11.
- **Apresentação** (G1b): ícone, cor e partículas do efeito ficam nos dados (`vfx_amount`,
  `vfx_color`, `vfx_rise_speed`, `vfx_at_feet`); teto de 8 partículas por efeito até os níveis de
  qualidade da G3. O efeito não tinge o ator (a cor do Visual é do flash e do aviso de ataque; a do
  sprite marca os outros jogadores): usa partículas próprias. Cor `UiStyle.EFFECT_DAMAGE` para
  números de dano de efeito.
- **Fontes** (G1c): `MonsterData.on_hit_effects` (efeitos em quem o golpe ou o salto acerta de
  fato; `Character.apply_hit_effects`, pronto para armas depois) e `ConsumableData.effects`.
  `ConsumableRules.use` devolve o item usado; o host aplica cura e efeitos. Slime venenoso (João,
  2026-10-23) = mesmos atributos e bote do slime (`data/actors/slime_stats.tres` e
  `slime_lunge.tres`, um arquivo só) + veneno no golpe. Poção de rapidez com grupo de espera
  próprio (`tonic`).
- **Consequências**: novas fontes de efeito (G1c: golpe que envenena, poção de buff; G2:
  habilidades; G3: auras) só chamam `StatusEffects.apply`.

## ADR-026 — Habilidades aprendidas e equipadas

- **Status**: Aceita (G2a, G2b e G2d validadas pelo João em 2026-10-23)
- **Direção do João (2026-10-23)**: habilidades **aprendidas e equipadas** (livre para montar
  builds, estilo Terraria); mago e arqueiro são escolhas de equipamento e habilidade, não classe
  fixa. Lançar no estilo Albion/V Rising (tecla, mira no cursor).
- **Decisões** (técnicas, ajustáveis em `data/`):
  - **Habilidade = dado** (`AbilityData` em `data/abilities/`): recarga, preparação (anda mais
    devagar; apanhar não interrompe), dano, recuo, velocidade, alcance, raio, efeitos no alvo
    (os de ADR-025), cores. Projéteis e áreas (G2d), no mesmo formato.
  - **Sem mana**: só recarga, como no V Rising (decisão técnica reversível).
  - **4 espaços**, teclas **1–4** (controle: RB, B, direcional ↑ e →); mira = a do ataque (mouse
    ou direção do olhar).
  - **Livro por jogador** (`AbilityBook` na sessão, como a carteira): aprendidas, espaços e
    recargas; vai no save. Aprender põe na primeira tecla livre.
  - **Aprender lendo um tomo** (`ConsumableData.teaches_ability`): quem já conhece não gasta.
    Primeiro tomo, "Projétil arcano", no mercador (50 moedas).
  - **Projétil** (`Projectile`): voa no plano do chão e para no primeiro inimigo; não é entidade
    (nada dele passa pela rede). Em todo computador ele voa e some ao tocar; só o do host fere.
  - **Barra** (G2b, `AbilityBar`): embaixo no meio (V Rising); recarga escurece o ícone de cima
    para baixo; botão direito numa tecla abre `ChoiceMenu` (base `ContextMenu`, extraída do menu
    do inventário) com as habilidades aprendidas.
  - **Pendências**: projéteis ainda atravessam árvores e pedras; trocar de tecla só com
    teclado/controle (hoje só com o mouse).
  - **Área** (G2d, escolha do João: Explosão arcana): `shape = AREA` no mesmo `AbilityData`
    (`area_radius`, `area_delay`). A **mira passou a ser o caminho até o ponto mirado** (direção
    e distância, no chão); o projétil usa só a direção, a área cai no ponto, limitada ao
    `max_range` (`AbilityData.area_offset`). Controle, sem mira própria: 80 à frente.
    `AreaBlast` (camada de efeitos do chão) mostra o aviso (`GroundTelegraph`, agora com cor por
    uso: vermelho = perigo para o jogador; habilidade = cor dela) e, no fim, onda e faíscas; só o
    do host fere. O dano em área virou `AreaStrike.hit`, usado também pelo salto dos chefes; as
    faíscas, `SparkBurst` (também no projétil); os efeitos do golpe, `Character.apply_effects`.
    O ponto é calculado em cada computador a partir da posição de quem lançou lá (no cliente, a
    desenhada um pouco no passado): pode diferir alguns pixels, só na imagem; o dano é do host.
    Protocolo: versão 12 (a mira do lançamento passou a levar a distância).
- **Rede e segurança** (ADR-013): `AbilitySync` (base `HostRequests`, extraída do
  `PlayerStateSync`). O dono confere antes de pedir, mostra o lançamento na hora (previsão) e
  pede ao host com espaço e mira; o host confere livro, recarga, vida e mira (NaN/zero/gigante
  recusados; a distância só vale até o alcance da habilidade) com o estado DELE e lança; o
  NetSync avisa os outros clientes (o id que chega é
  conferido no catálogo local). RPCs novas que o cliente chama: pedir lançamento, trocar espaço e
  pedir o livro — todas só mexem no livro de quem pediu. O host manda ao dono o livro inteiro a
  cada mudança e as recargas. Previsão recusada pelo host = só um projétil sem efeito no dono.
- **Consequências**: novas habilidades = um `.tres` + nome na tabela de textos + tomo (ou outra
  fonte). A G2c (ameaça) usa o dano à distância que agora existe.
- **Mira** (correção do teste do João): teclas não trocam a mira; teclado e mouse se usam juntos.
  Só o controle mira para onde o personagem olha. Mira própria do controle (analógico direito,
  ajuda de mira) fica para depois e mexe só em `LocalPlayerInput`.

## ADR-027 — Ameaça e passeio das criaturas

- **Status**: Aceita (G2c validada pelo João em 2026-10-23)
- **Contexto**: João (2026-10-23): atacada de longe, a criatura nem reagia, e perseguindo desistia
  assim que o jogador saía do raio de agressão, bem antes da coleira. Chefes corpo a corpo
  precisam ir atrás de magos e arqueiros. E, sem alvo, as criaturas ficavam paradas.
- **Decisões** (genéricas, valem para toda criatura; números em `data/` ou no topo da IA):
  - **Tabela de ameaça** (`ThreatTable`, lógica pura, por criatura, só no host): dano soma
    ameaça (golpe sem dano ainda conta o mínimo); entrar no raio de agressão dá a ameaça mínima.
    A criatura persegue a maior ameaça e só troca de alvo com 10% de vantagem (não fica virando).
    Quem morre ou sai da região sai da tabela.
  - **Quem fere vira alvo de qualquer distância** e a criatura reage no mesmo quadro.
  - **Perseguição só acaba na coleira** (`leash_radius`): sair do raio de agressão não basta.
    Na coleira, desiste imune e limpa a tabela (ADR-024 continua valendo).
  - **Passeio** (`MonsterData.wander_radius`, 0 = parado): sem alvo, anda devagar até pontos
    sorteados perto de casa, com pausas de 1,5–4 s; desiste de um ponto que não alcança em 4 s.
    Filhotes de chefe não passeiam (seguem o chefe).
- **Rede e segurança**: nada novo na rede. A ameaça usa o dano já decidido pelo host (o jogador
  responsável vem do host, nunca do cliente); o passeio só move a criatura no host, e a posição
  chega aos clientes como antes.
- **Consequências**: classes à distância precisam se mexer (o chefe vem e salta neles). Futuro:
  ameaça extra por cura/provocação e "fúria" que esquece a ameaça com o tempo, se o João quiser.

## ADR-028 — Níveis de qualidade dos efeitos e teto de partículas

- **Status**: Aceita (G3a validada pelo João em 2026-10-23)
- **Contexto**: a visão pede efeitos marcantes com níveis de qualidade e limite de partículas
  (`docs/03-desempenho.md`); as auras da G3 vão somar muitas partículas na tela.
- **Decisões** (técnicas, valores em `data/vfx/quality.tres`):
  - Três níveis: **baixo** (40% das partículas, teto 150), **médio** (70%, teto 400) e **alto**
    (100%, teto 800). Padrão: alto (até existir menu de opções e medição em hardware modesto).
  - Serviço `VfxQuality` (só apresentação, um por execução): todo emissor de partículas passa por
    `claim`, que corta a quantidade pelo nível e pelo que sobra do teto do computador. Teto cheio:
    o efeito aparece sem partículas (o resto do efeito continua). Conta só emissores na árvore.
  - Trocar de nível refaz as partículas dos efeitos que duram (veneno, rapidez); faíscas e rastros
    curtos pegam o nível novo no próximo uso.
  - A escolha fica nas preferências locais (`UserSettings`, seção `graphics`). Por enquanto troca
    com **F4 com o painel F3 aberto** (provisório); `--quality=low|medium|high` vale só para a
    execução (capturas e testes de desempenho).
- **Rede e segurança**: nada passa pela rede; cada computador escolhe a própria qualidade.
- **Consequências**: as auras (G3b) usam o mesmo `claim`. Pendente: menu de opções para o jogador
  (com textos traduzíveis); o host com várias regiões conta também as partículas das regiões que
  não está mostrando (aceitável; revisar se pesar).

## ADR-029 — Auras (anel de runas, luz no chão e faíscas)

- **Status**: Aceita (G3b validada pelo João em 2026-10-23: acompanha o personagem, some ao tirar a coroa)
- **Direção do João (2026-10-23)**: a primeira aura vem da **Coroa do Rei Slime** (recompensa
  visível de quem venceu o chefe).
- **Decisões** (técnicas, ajustáveis em `data/auras/`):
  - **Aura = dado** (`AuraData`): raio, cores do anel e das runas, número de runas, giro, pulso
    (clarear e período), luz no chão e faíscas. Só aparência: não muda atributo nem regra.
  - **Fonte**: `EquipmentData.aura`. O personagem junta as auras do equipamento vestido
    (`Character.auras`, sinal `auras_changed`); efeitos e criaturas podem ser fontes depois.
  - **Desenho** (técnica de ADR-007): anel elíptico pixel a pixel, metade de trás antes do sprite
    e metade da frente depois (`AuraRing`), dentro do Visual (pisca e some junto com o ator).
    Giro e pulso em passos de 12 por segundo, como animação de pixel art. Cor cheia, sem soma de
    luz: somada, a cor desbotava sobre a grama (dourado virava amarelo-claro, violeta sumia).
    Luz translúcida no chão dentro do anel, pulsando com ele.
  - **Faíscas** de 2 px subindo de dentro do anel, pelo `VfxQuality.claim` (ADR-028).
  - **Primeira aura** (`slime_royalty`): anel dourado da coroa, 4 runas violeta do Rei Slime
    girando devagar, faíscas douradas.
- **Rede e segurança**: nada novo. O equipamento de cada jogador já chega a todos (o host envia,
  o cliente confere cada id no catálogo local); a aura sai dos dados locais desse item.
- **Desempenho**: sem aura, nada roda por quadro (200 slimes: 3,8 ms, igual às medições
  anteriores). Com aura: 2 desenhos simples a cada passo do giro + 6 partículas.
  **Teste de carga (G3d, 2026-10-23)**: pintar o anel pixel a pixel em cada ator dava picos de
  ~7,5 ms com 60 auras (todos os anéis redesenhavam no mesmo quadro, 12 vezes por segundo). Agora
  cada (aura, metade) tem uma imagem compartilhada (`AuraRingImage`), pintada uma vez por passo;
  cada anel só desenha a textura, atualizada no lugar. Mesmo visual. 60 auras: +0,45 ms de média,
  p99 1,5 ms. Medido com `tests/benchmark_auras.gd` (`docs/03-desempenho.md`). Consequência: auras
  futuras de outro tipo devem seguir a mesma ideia (pintar uma vez, dividir entre atores).
- **Consequências**: qualquer item ganha aura apontando para um arquivo. O sprite da coroa na
  cabeça do personagem ainda não existe (só o ícone); fica para a arte de equipamentos.
- **Diretrizes do João para os próximos efeitos (2026-10-23)**:
  - O anel de runas **não é o padrão de todas as auras**: é o primeiro tipo e o nível "simples".
    Haverá itens sem aura, com aura simples e com muito efeito. Temas diferentes (sombrio com
    caveirinhas e mãos de esqueleto saindo do chão, angelical, etc.) serão definidos junto com as
    habilidades.
  - Os efeitos **podem sair do pixel quadrado**: a ideia é fantasia (formas, brilho e movimento
    mais livres), desde que leiam bem na tela e não briguem com a arte (referência Hero Siege).
  - **Efeitos são seletivos e difíceis de conseguir**: precisam despertar vontade de conquistar.
    Isso vale para o balanceamento de drops e receitas, não para o código.
  - **Transmog** entra nos cosméticos (G3c): usar a aparência de um item com os atributos de outro,
    para o item bonito do começo não ficar preso ao baú.
  - Consequência técnica: a `AuraData` vira uma lista de camadas de tipos diferentes (anel,
    sprites animados saindo do chão, partículas com forma), em vez de crescer com campos de um
    tipo só. Fazer quando o primeiro efeito de outro tipo for pedido.

## ADR-030 — Cosméticos e transmog: coleção permanente de aparências

- **Status**: Aceita (G3c validada pelo João em 2026-10-23)
- **Direção do João (2026-10-23)**: transmog = aparência de um item com os atributos de outro;
  **coleção permanente** (conseguir o item uma vez libera a aparência para sempre, mesmo
  vendendo ou destruindo); a **aura vai junto com a aparência**; a aparência **vale sozinha**,
  sem item vestido no espaço (estilo Terraria/Grand Fantasia), e um espaço pode ser escondido.
- **Decisões** (técnicas):
  - **Coleção** (`AppearanceCollection`, uma por jogador na `GameSession`): todo
    `EquipmentData` que entra no inventário, na mão ou no corpo é colecionado
    (`AppearanceCollection.watch`). Sem item especial de "desbloqueio" e sem custo.
  - **Aparência por espaço** no `Equipment` (não por tipo: os 2 acessórios têm a sua):
    `OWN_LOOK` (o item vestido), `HIDDEN_LOOK` (nada) ou o id de um equipamento colecionado
    **do mesmo tipo de espaço**. `Equipment.shown` / `shown_items` dizem o que aparece.
    Atributos e golpe continuam vindo de `equipped()`; auras (e, um dia, sprites), de `shown`.
    A mesma aura não se repete (ex.: duas aparências iguais nos acessórios).
  - **Regra** em `EquipmentRules.set_look` (só o host aplica); `is_valid_look` confere o que
    é possível sem conhecer a coleção (usado para aparências de outros jogadores).
  - **Tela**: botão direito num espaço de equipamento → menu (mostrar o item vestido, as
    aparências colecionadas do tipo, esconder); selo 10×10 no canto do espaço com a aparência
    escolhida (ou um traço, se escondida); a dica diz a aparência. Aviso "Nova aparência: X".
    O item vestido não se repete no menu pelo nome (é o "mostrar o item vestido").
  - **Novidade** (`AppearanceCollection.announces`): só depois de o jogador estar montado (host:
    equipamento inicial ou save aplicados; cliente: primeira coleção oficial do host). Antes
    disso nada avisa nem é enviado; depois, a coleção oficial que chega também avisa o que
    trouxer de novo (o host pode mandá-la antes do próprio item).
  - **Avisos ao carregar** (2026-10-23, vale para todos os avisos do jogador local):
    `PlayerFeedback` fica em silêncio até `start_announcing` (host: `local_player_prepared` do
    spawner, com o save aplicado; cliente: `AbilitySync.full_state_received`, a resposta
    `_full_book` ao pedido de estado completo, que é o último a sair e chega por último porque
    as mensagens confiáveis chegam na ordem de envio). Até lá, só anota habilidades, níveis e
    efeitos que o jogador já tem. Protocolo 14 (mensagem nova).
  - **Save**: `appearances` (ids) e `looks` (um por espaço) no registro do personagem. A
    coleção volta antes do inventário, então saves anteriores colecionam o que o personagem
    já tem.
- **Rede e segurança (ADR-013)**: protocolo 13. As aparências escolhidas vão a todos junto
  com o equipamento (`_equipment`), tudo ou nada: cada uma é a própria, escondida ou um
  equipamento conhecido do tipo do espaço. A coleção vai só ao dono (`_collection`), conferida
  contra o catálogo local e limitada a 1024 ids. O pedido `_set_look_requested` só mexe no
  equipamento de quem pediu e é conferido com a coleção **do host** (aparência não colecionada
  é recusada). Nada de recursos pela rede: só ids procurados no catálogo.
- **Consequências**: o personagem ainda não desenha capacete, armadura nem arma vestidos (só a
  aura muda); quando houver sprites de equipamento, eles saem de `shown`, sem mudar a regra.
  Itens puramente cosméticos (sem atributos) já cabem: são equipamentos com bônus vazios.
  Pendente: escolher a aparência só com teclado/controle (como a troca de tecla das
  habilidades).

## ADR-031 — Dungeons temporárias (primeira: caverna dos slimes)

- **Status**: Aceita (J1a validada pelo João, 2026-10-24)
- **Contexto**: Etapa J, primeira frente escolhida pelo João (2026-10-24): dungeon instanciada.
  A visão pede "mapas persistentes, instanciados e dungeons temporárias, sem complexidade antes
  da necessidade".
- **Decisões**:
  - **Dungeon = região** (ADR-020) marcada `temporary` no catálogo (`RegionData`), com
    `exit_region`/`exit_passage` (a entrada, do lado de fora). Reaproveita carregamento, viagem,
    replicação por região e coop.
  - **Temporária**: nunca vai para o save; quando fica vazia, é liberada como qualquer região e
    esquecida; ao entrar de novo, começa do zero (criaturas, pontos de coleta). Criaturas mortas
    lá **não renascem** (a dungeon limpa fica limpa enquanto houver alguém dentro). Não se
    constrói nela (a bancada sumiria): `Region.can_place`, a mesma regra no host e na prévia.
  - **Quem sai do jogo lá dentro** volta para a entrada: o save guarda `exit_region` e a
    passagem `exit_passage` (campo `passage` do personagem, só procurado entre as passagens da
    região).
  - **Uma instância por dungeon no host**: todos os jogadores que entram na mesma dungeon ficam
    na mesma cópia (coop LAN de até 4 amigos). Instâncias por grupo ficam para quando houver
    grupos (o nome do mundo da região é o id, usado nos caminhos de rede).
  - **Entrada**: objeto do cenário (monte com a boca, com colisão e Y-sort) + passagem sem
    parede (`doorway.tscn`) na frente da boca; chega-se logo abaixo dela. Gerada pela receita
    (`entrances`), numa clareira, depois de todo o resto (a floresta continua idêntica: mesmos
    nós, posições e chão; o save dela vale).
  - **Mapa**: mesmo gerador, com terreno por receita (piso, caminho e borda): a caverna usa piso
    de pedra e abismos (bloqueiam como a água). O gerador agora confere que do ponto de entrada
    se anda até cada passagem e até o chefe (falha se um abismo fechar o caminho).
- **Rede e segurança (ADR-013)**: nenhuma mensagem nova (protocolo continua 16). Ids de região
  e passagem do save só são procurados no catálogo e nas passagens da região.
- **Conteúdo de teste** (troca sem mexer na regra): caverna com slimes comuns e venenosos,
  cobre e o Rei Slime no fundo; entrada no meio da floresta.
- **Limitações**: a dungeon recomeça só quando fica vazia (quem fica dentro mantém o progresso
  dos outros); o caminho de saída na caverna não tem marca no chão (mesmo piso). Recompensa de
  fim e saída rápida: ADR-032.

## ADR-032 — Fim de dungeon: baú do chefe e saída rápida

- **Status**: Hipótese (J1b, aguarda validação do João)
- **Contexto**: J1b, continuação da ADR-031: a dungeon não tinha recompensa de fim nem como sair
  depois do chefe sem voltar a pé.
- **Decisões**:
  - **Gatilho em dados**: a dungeon diz qual é o baú dela (`RegionData.reward_chest`, arquivo em
    `data/chests/`). Quando um chefe (`MonsterData.is_boss`) morre numa região com baú, surgem o
    baú (onde ele caiu) e a saída rápida (um pouco mais longe), depois que o corpo some. O mesmo
    chefe fora de dungeon (Rei Slime da floresta) só deixa os drops de sempre.
  - **Baú pessoal**: um baú só, e cada jogador da dungeon abre o seu uma vez (tecla de interagir,
    rótulo "[E] Abrir o baú"). A tabela (`DropEntry`, como os drops) é sorteada só para quem
    abriu e cai em volta do baú como drop pessoal. Cada computador mostra o baú como o jogador
    local o deixou (aberto para quem já abriu). Prioridade da tecla: NPC, baú, coleta.
  - **Saída rápida = passagem** (`ExitPortal` herda `Passage`): círculo mágico no chão que leva
    a `exit_region`/`exit_passage` (frente da boca da caverna). A viagem é a mesma das outras
    passagens (o Main decide).
  - Baú e saída são entidades criadas pelo host (`EntitySpawner`, tipos novos), então quem
    entra na dungeon depois também os recebe; somem quando a dungeon é esquecida.
- **Rede e segurança (ADR-013)**: protocolo **17**. Mensagens novas: pedido "abrir baú" (sem
  argumentos: o host escolhe o baú ao alcance e ainda não aberto por quem pediu, com o estado
  dele; passa pela cota do `PeerGuard`) e "baú aberto" (host → só o dono). Dados de criação do
  baú e da saída só levam id e posição (conferidos); tipo do baú e destino da saída vêm do
  catálogo da região, nunca da rede.
- **Conteúdo de teste** (troca sem mexer na regra): baú da caverna com 1–2 poções de vida, 4–8
  minérios de cobre e 50% de uma poção de rapidez.
- **Limitações**: quem entrar depois do chefe morto também pode abrir o baú (uma instância por
  dungeon, ADR-031); a saída não tem rótulo (entrar nela já leva para fora).
