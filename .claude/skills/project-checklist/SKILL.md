---
name: project-checklist
description: Checklist de arquitetura, segurança e documentação deste projeto antes de commits relevantes, ao fim de cada incremento e antes de pedir merge na main. Use ao terminar uma funcionalidade, ao revisar mudanças de rede, dados ou interface, e antes de relatar uma etapa ao João.
---

# Checklist do projeto

Passe item por item e relate o que **não** se aplica ou ficou pendente. Detalhes das regras:
`CLAUDE.md` e `docs/01-decisoes.md`.

## Arquitetura

- [ ] Lógica e estado em `core/` (sem nós visuais); apresentação em `scenes/`.
- [ ] Nada de "jogador global": tudo por `player_id`/`entity_id` (perguntar à `GameSession`).
- [ ] Números de jogo em `data/` (itens, receitas, monstros, fórmulas, efeitos), não no código.
- [ ] Sem duplicação: lógica, forma, número ou cor que aparece 2 vezes virou função,
      componente, cena base, dado ou token (`UiStyle`).
- [ ] Nomes claros, funções curtas, comentários explicando o *porquê*.

## Rede e segurança (ADR-012/013 — inegociável)

- [ ] Ação de jogo = pedido ao host; o host confere remetente, índices, ids, vetores
      (`NetRules.is_valid_vector`), alcance e posse **com o estado dele**, nunca com o que o
      cliente disse.
- [ ] Dados de criação do `EntitySpawner` validados em `_valid_kind`; nada de caminhos,
      recursos ou objetos vindos da rede.
- [ ] Mudou RPC ou dados de criação? Subir `NetRules.PROTOCOL_VERSION`.
- [ ] Teste de rede cobrindo o caminho feliz **e** pedidos adulterados (`tests/test_network.gd`).
- [ ] Riscos/pendências anotados na ADR-013 e em `docs/04-multiplayer.md`, e citados ao João.

## Jogador

- [ ] Textos só por `data/i18n/texts.csv`, todos os idiomas (o teste `test_texts` confere).
- [ ] UI conforme a skill `game-ui-ux`; arte conforme `pixel-art-style`; animação conforme
      `game-feel` (com folha de quadros de `game-motion-capture`).

## Execução

- [ ] Importar: `G --headless --path . --import` sem erros.
- [ ] Testes: `G --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd` — todos passando
      (o executor reprova erro de script).
- [ ] Mudou desempenho (muitas entidades, partículas, física)? Rodar os benchmarks e comparar
      com `docs/03-desempenho.md`.
- [ ] Captura de tela ou folha de quadros quando algo visual mudou — e olhar.
- [ ] Mexeu em câmera, camadas, regiões ou textos do mundo? Rodar `tests/render_checks.gd`
      (com janela) — os testes headless não veem pixels.

## Documentação e Git

- [ ] Decisão nova → ADR em `docs/01-decisoes.md` (status Hipótese até o João validar).
- [ ] `docs/02-plano-e-status.md` atualizado (incremento, funcionalidades, problemas).
- [ ] Asset novo → `docs/05-assets-e-licencas.md` (licença comercial conferida).
- [ ] Commit pequeno, em inglês, sem trailers de atribuição; `git add` só do que é da tarefa
      (conferir `git status` — o editor da Godot às vezes reordena o `project.godot`).
- [ ] Merge na `main` só com "pode mandar para a main" do João; `--no-ff`.

## Relato ao João

Separar **implementado** / **executado** / **validado (por quem)**; instruções manuais
numeradas e curtas; uma pergunta criativa por vez.
