---
name: game-feel
description: Animação e "juice" — antecipação, impacto, squash & stretch, hitstop, tremor de câmera, partículas, easing, feedback de ações. Use ao criar ou ajustar golpes, habilidades, coleta, dano, morte, drops, movimentação e efeitos mágicos, e quando o João disser que algo está "sem graça", "fraco", "duro" ou "sem impacto".
---

# Game feel (sensação de jogo)

Referências de intenção: Forager (tudo responde com um pulinho e brilho), Grand Fantasia
(auras e brilhos encantadores), V Rising/Albion (habilidades com aviso no chão e peso).

## Princípios

1. **Toda ação do jogador responde no mesmo quadro** (som/flash/pose), mesmo que o resultado
   venha do host depois (no coop o dono prevê; ADR-012).
2. **Antecipação → ação → recuperação**. A antecipação diz "vai acontecer"; a recuperação
   diz "acabou". Inimigos precisam de antecipação legível (telegrafia) para serem justos.
3. **Impacto em camadas**, do mais barato ao mais forte: flash branco no alvo → recuo/knockback
   → número de dano → partículas → hitstop → tremor de câmera. Use as camadas fortes só em
   eventos fortes (crítico, chefe, morte), senão nada se destaca.
4. **Exagero com volume**: squash & stretch mantém a área (x 1,2 ⇒ y ~0,83).
5. **Easing sempre**: nada se move em velocidade constante. Saída rápida e chegada suave
   (`EASE_OUT` com `TRANS_QUAD`/`TRANS_CUBIC`) para golpes e pulos; `TRANS_BACK` para
   "pop" de itens e UI; `TRANS_ELASTIC` só em coisas fofas e raras.
6. **Pixel art**: posições em pixels inteiros na tela; escala de sprite em passos que não
   borrem (preferir trocar quadros a escalar); tremor de câmera em pixels inteiros.

## Valores de partida (ajustar vendo a folha de quadros)

| Efeito | Valor inicial |
|---|---|
| Flash de dano | 2–4 quadros (≈ 0,05 s) |
| Hitstop (pausa no acerto) | 0,03–0,06 s normal; 0,08–0,12 s crítico/morte |
| Tremor de câmera | 1–2 px, 0,1–0,15 s, decaindo; só em impactos fortes |
| Squash & stretch | 1,15–1,25 / 0,8–0,87, 0,08–0,12 s |
| "Pop" de drop | sobe 6–10 px e cai com quique, 0,25–0,35 s |
| Antecipação de golpe | 0,06–0,12 s (jogador); telegrafia de inimigo 0,3–0,6 s |
| Números de dano | sobem 12–16 px, somem em 0,5–0,7 s |

## Como implementar aqui (Godot 4, regras do projeto)

- **Parâmetros em dados** (`data/`), nunca números soltos espalhados: cor, intensidade,
  duração, velocidade, como manda o CLAUDE.md (efeitos com níveis de qualidade e limite de
  partículas).
- Reaproveite os componentes: `ActorFeedback` (flash, telegrafia, piscar, sumir),
  `DamageNumbers`, `PlayerFeedback`. Efeito novo de ator = método/parâmetro novo ali, não
  código copiado em cada criatura.
- Tweens (`create_tween()`) para movimentos curtos; `AnimationPlayer` para sequências
  autorais; partículas com `GPUParticles2D` **ou** `CPUParticles2D` (Compatibility/OpenGL:
  preferir CPUParticles2D em quantidades pequenas; medir com os benchmarks).
- Hitstop: pausar só os envolvidos (velocidade de animação/física local), nunca
  `Engine.time_scale` — no coop o tempo global é do host e de todos.
- Tremor de câmera só no computador de quem sofreu/causou o impacto (é apresentação, não
  estado de jogo; nada disso passa pela rede).
- Efeitos são apresentação: a lógica (dano, morte) não espera a animação terminar.

## Verificação

1. Folha de quadros antes e depois (skill `game-motion-capture`), citando quadros.
2. Benchmark se houver partículas ou muitos tweens (`tests/benchmark_monsters.gd`).
3. Testes automáticos continuam passando (efeito nenhum pode mudar regra de jogo).
4. Relato: "verificado por Claude na folha de quadros"; **sensação** = validação do João.
