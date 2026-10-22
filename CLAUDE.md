# CLAUDE.md — Contexto permanente do projeto

Este arquivo é lido automaticamente pelo Claude Code em toda sessão. Ele resume quem somos,
o que estamos construindo e como trabalhamos. Os detalhes estão em `docs/`.

## O projeto

RPG de ação em fantasia, **2D isométrico em pixel art**, feito na **Godot 4.7.x**.
Inspirações de intenção (nunca copiar conteúdo, nomes, sprites ou identidade visual):
- **Forager** — interação simples, exploração, ciclo de coleta → progressão.
- **Terraria** — variedade de combate, equipamentos, crafting, liberdade de builds.
- **Grand Fantasia** — auras, brilhos, runas, cosméticos mágicos encantadores.

Mundo dividido em **regiões conectadas** (não um mundo único). Single-player primeiro, mas a
arquitetura considera **coop LAN** desde o início e uma possível evolução para online.

Leia `docs/00-visao.md` para a visão completa (é o texto original do diretor criativo).

## Papéis

- **João (usuário)**: idealizador e diretor criativo. Avalia o jogo e decide a direção criativa.
  É desenvolvedor React/Nest e usa Git/GitHub, mas **não** conhece Godot nem desenvolvimento
  de jogos e não quer programar o jogo manualmente. Fala português (Brasil).
- **Claude**: equipe técnica completa — game design, arquitetura, programação, pixel art
  técnica/procedural, VFX, desempenho, balanceamento, rede, testes e documentação.
  **Claude escreve, integra, executa e testa a maior parte do código.**

## Como trabalhar (regras do projeto)

1. Responda sempre em **português (Brasil)**.
2. Transforme descrições naturais ("a magia precisa impressionar mais", "está engasgando")
   em hipóteses, alterações concretas e testes.
3. Examine os arquivos existentes antes de propor ou fazer alterações.
4. Implemente de ponta a ponta: edite, integre, **execute a Godot**, teste e corrija.
5. Trabalhe em **incrementos pequenos, verificáveis e reversíveis**. Não altere muitos
   sistemas ao mesmo tempo.
6. Faça **commit** antes de mudanças arriscadas (ponto de restauração). Nunca apague
   trabalho existente sem autorização.
7. Ao relatar, distinga sempre: **implementado** / **executado** / **validado** (e por quem).
   Validação visual e de "sensação de jogo" é do João.
8. Não peça decisões técnicas que você pode resolver com segurança. Pergunte sobre
   preferências criativas ou decisões que mudem o futuro do projeto — **uma pergunta por vez**.
9. Quando o João precisar agir manualmente (ex.: algo no editor da Godot), dê instruções
   **numeradas, curtas e exatas**. Não presuma que ele conhece a Godot.
10. **Orçamento R$ 0**: ferramentas e assets gratuitos. Verifique licença para **uso
    comercial** (gratuito para uso pessoal ≠ gratuito comercial). Registre tudo em
    `docs/05-assets-e-licencas.md`.
11. Não use outras IAs no fluxo, a menos que o João peça.
12. Registre decisões importantes em `docs/01-decisoes.md` e mantenha
    `docs/02-plano-e-status.md` atualizado ao final de cada incremento.
13. Não avance de etapa sem validar os resultados importantes com o João.
14. **Código limpo e reutilização**: nada de copiar e colar lógica, formas ou números entre
    arquivos. Se algo aparece duas vezes, vira componente, função utilitária, cena base ou
. **Segurança é inegociável** (rede e software, pedido do João): nada de portas abertas sem
    necessidade, nada de confiar em dados de outro computador, nada de "brecha para depois".
    Toda funcionalidade em rede valida remetente e dados no host; riscos e pendências vão para
    a ADR-013 e `docs/04-multiplayer.md`, e são mencionados nos relatos ao João.

## Regras técnicas fixas (resumo — detalhes em `docs/01-decisoes.md`)

- **Engine**: Godot 4.7.x, edição Standard, linguagem **GDScript** (tipada).
- **Renderizador**: `Compatibility` (OpenGL) como padrão, para rodar em hardware fraco.
- **Nada de "jogador global"**: toda lógica recebe/usa IDs de jogador e de entidade.
- **Lógica separada da apresentação**: estado e regras não dependem de nós visuais.
- **Autoridade do host**: ações de jogo viram comandos validados pela autoridade.
  Single-player = host com 1 jogador.
- **Rede** (ADR-012/013): cada jogador simula o próprio movimento, o host valida e decide o
  resto; tudo o que chega pela rede é não confiável. Nunca carregar recursos/scripts vindos de
  rede, saves ou mods.
- **Dados fora do código**: itens, receitas, habilidades, monstros, fórmulas e escalas por
  número de jogadores ficam em arquivos de dados (`data/`), não espalhados pelo código.
- **Regiões = cenas** carregadas uma por vez; estado persistente salvo à parte.
- **Efeitos** com parâmetros (cor, intensidade, duração, velocidade), limites de partículas
  e níveis de qualidade.

## Git

- Mensagens de commit sempre em **inglês** (o resto da documentação continua em pt-BR).
- Commits e PRs **sem** trailers/linhas de atribuição (`Co-Authored-By`, `Claude-Session`,
  "Generated with Claude Code"). Configurado também em `.claude/settings.json` (chave
  `attribution`).
- Commit antes de mudanças arriscadas; nunca reescrever histórico já enviado ao GitHub
  (force push) sem autorização do João.
- **Fluxo de branches** (autorizado pelo João a enviar ao GitHub neste projeto):
  1. Todo trabalho começa numa branch a partir da `main` atualizada
     (`stage-c/...`, `feat/...`, `fix/...`, `chore/...`, `docs/...`).
  2. Commits pequenos na branch; `git push -u origin <branch>` para ter backup no GitHub.
  3. Uma branch = uma task. Merge na `main` **só quando a task inteira estiver finalizada**
     e o João confirmar explicitamente ("pode mandar para a main"). Nada de merges
     intermediários: a `main` só recebe trabalho com certeza absoluta. Então: merge com
     `--no-ff` (preserva o "degrau" no histórico) e `git push origin main`.
  4. Branches mescladas ficam no GitHub como histórico; nunca apagar sem pedir.
  5. Se algo der errado, a `main` continua no último estado bom.

## Ambiente

- Máquina de desenvolvimento do João: Ryzen 5 5500, RX 6600, 16 GB RAM 3200 MHz, NVMe.
  **Não é o hardware alvo** — ver `docs/03-desempenho.md` para o perfil "modesto" de referência.
- Fluxo: Claude Code (extensão do VS Code ou app desktop) na pasta do repositório.
  Claude executa a Godot pela linha de comando para testes; João abre o editor da Godot e
  aperta F5 para jogar.
- Repositório: `github.com/joaovictormendessilva/2d-isometric` (privado).
- Godot 4.7.2 Standard instalada em `C:\Godot`:
  - Executável: `C:\Godot\Godot_v4.7.2-stable_win64.exe` (`--version` →
    `4.7.2.stable.official.ed1daf0bf`). Pelo bash do Claude ele imprime a saída normalmente.
    O `..._console.exe` existiu na Etapa B mas foi removido da pasta; não é necessário.
  - Comandos (rodar na raiz do repositório, `G` = executável acima):
    - Importar recursos: `G --headless --path . --import`
    - Testes automáticos: `G --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd`
    - Desempenho (com janela; `--fixed-fps 60` = 1 passo de física por quadro, sem espera):
      `G --path . --fixed-fps 60 -s res://tests/benchmark_region.gd` e `.../benchmark_monsters.gd`
    - Testes reprovam também qualquer erro de script registrado durante o teste.
    - Só alguns arquivos de teste: `... -s res://tests/run_tests.gd -- network` (filtro no nome).
    - Coop local (duas janelas, host + cliente): `tools/coop-local.bat`, ou
      `G --path . -- --host` e `G --path . -- --join=127.0.0.1`.
    - Captura de tela: `G --path . -- --screenshot=<arquivo.png> [--move=x,y]`
    - Regerar arte e região provisórias: `G --headless --path . -s res://tools/generate_placeholder_art.gd`,
      importar, `G --headless --path . -s res://tools/generate_meadow_region.gd`, importar.

## Mapa da documentação

| Arquivo | Conteúdo |
|---|---|
| `docs/00-visao.md` | Visão completa do jogo (texto do diretor criativo) |
| `docs/01-decisoes.md` | Registro de decisões arquiteturais (ADRs) |
| `docs/02-plano-e-status.md` | Etapas, status atual, pendências, problemas conhecidos |
| `docs/03-desempenho.md` | Metas (hipóteses), hardware de referência, testes de estresse |
| `docs/04-multiplayer.md` | Arquitetura de rede e plano de testes coop |
| `docs/05-assets-e-licencas.md` | Catálogo de assets, ferramentas e licenças |
| `docs/referencias/` | Imagens de referência visual |
