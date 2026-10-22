---
name: pixel-art-style
description: Regras de pixel art do projeto e como conferir cada sprite — paleta, luz, sombreamento, contornos, silhuetas, leitura em 640x360, quadros de animação. Use SEMPRE que criar ou alterar arte (tools/generate_placeholder_art.gd, sprites, ícones, tiles, efeitos) ou avaliar um asset externo, e quando o João pedir arte "mais bonita", "com mais vida" ou "sem cara de IA".
---

# Pixel art do projeto

Objetivo do João: arte bonita e **sem cara de IA genérica**. Na prática, "cara de IA" é:
cores demais, gradientes suaves, bordas borradas, ruído de pixels soltos, sombra em volta de
tudo ("pillow shading"), luz incoerente e silhuetas que não se leem. As regras abaixo evitam
isso. A identidade visual final (paleta oficial, tom) é **decisão criativa do João**: até lá,
estas regras valem para a arte provisória e para avaliar assets.

## Base técnica (fixa)

- Resolução interna 640×360, escala inteira; filtro Nearest; tiles isométricos 32×16 (2:1).
- Nunca girar, escalar fracionado ou suavizar sprites. Movimento em pixels inteiros.
- Personagens ~16 px de largura, ~23 px de altura; ícones 8×8 desenhados em escala ×2 na UI.
- Arte provisória é gerada por código em `tools/generate_placeholder_art.gd` (cores nas
  constantes do topo; ícones desenhados por letra). Gerar → importar → conferir.

## Regras de estilo

1. **Paleta curta**: até ~16 cores por sprite, idealmente 4–8; cada material com 3–4 tons
   (sombra, base, luz, brilho opcional). Reaproveite as rampas existentes antes de criar cor.
2. **Hue shifting**: tons de sombra vão para frio (azul/roxo) e um pouco mais saturados; luzes
   vão para quente (amarelo). Escurecer só o brilho da mesma cor = aparência de filtro.
3. **Luz única**: de cima à esquerda, em todo o jogo. Sombra do lado direito/baixo.
4. **Contorno seletivo**: contorno escuro **da cor do material** (verde-escuro na copa, roxo
   escuro no slime), não preto puro; pode clarear onde a luz bate. Sem contorno duplo.
5. **Blocos, não ruído**: agrupe pixels em massas (clusters); pixel solto só como brilho
   intencional (olho, faísca). Textura vem de poucos pixels bem postos, não de pontilhado.
6. **Sem anti-alias e sem semitransparência** em sprites (exceto efeitos e sombras no chão).
7. **Silhueta primeiro**: o objeto tem que ser reconhecível preenchido de uma cor só. Frente,
   costas e lados de um personagem devem ter silhuetas diferentes.
8. **Contraste de valor**: em tons de cinza, 4–6 valores distintos; o personagem precisa
   destacar do chão (o chão é mais escuro e menos saturado que quem joga).
9. **Hierarquia**: jogador > criaturas > objetos interativos (coleta: marca visível) >
   cenário. Cenário nunca é mais saturado que o que se pode usar.
10. **Coerência**: mesmo tamanho de pixel, mesma espessura de contorno, mesma luz em tudo.

## Animação (quadros)

- Andar: 4–6 quadros; golpe: antecipação (1–2) + golpe (1–2) + recuperação (2–3); idle: 2–4
  quadros com respiração de 1 px. Detalhes de ritmo e impacto: skill `game-feel`.
- Mexer poucos pixels por quadro; o que se move deve manter volume (squash compensa stretch).
- Conferir em movimento com a skill `game-motion-capture`.

## Conferência obrigatória (cada sprite novo ou alterado)

```
G --headless --path . -s res://tools/art_check.gd -- assets/sprites/<arquivo>.png --preview=<scratchpad>/art.png
```

Leia o relatório (cores, valores, semitransparentes, soltos) e **abra a prévia** (original |
cinza | silhueta, ampliados). Depois veja o sprite no jogo com captura de tela
(`--screenshot`), porque o contexto (chão, vizinhos) muda a leitura. `--palette=<png>` acusa
cores fora de uma paleta, quando houver paleta oficial.

## Assets externos

Só gratuitos para **uso comercial**, registrados em `docs/05-assets-e-licencas.md` (regra 10).
Passe-os pelo `art_check` também: misturar estilos (resolução, contorno, luz) é a forma mais
rápida de parecer genérico.

## Achados registrados (atualize ao corrigir)

- 2026-10-22, `character.png`: silhuetas de frente e de costas idênticas (só a cor muda);
  5 pixels soltos no cinto (linha 13).
