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

- **Status**: Hipótese (validar na Etapa C/H)
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

- **Status**: Hipótese (validar na Etapa C/F)
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

- **Status**: Hipótese (validar na Etapa C)
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

## ADR-007 — Hipóteses visuais iniciais

- **Status**: Hipótese (validar na Etapa C)
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

- **Status**: Hipótese (validar na Etapa C com o João)
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
