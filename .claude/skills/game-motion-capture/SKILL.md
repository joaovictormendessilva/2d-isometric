---
name: game-motion-capture
description: Ver o jogo EM MOVIMENTO como folha de quadros (contact sheet) — golpes, andar, coleta, efeitos, animações de interface. Use antes e depois de qualquer mudança de animação, "juice", VFX, câmera ou transição de UI, e sempre que o João disser que algo "parece travado", "sem impacto", "duro" ou "engasgando visualmente". Capturas paradas não mostram ritmo; esta skill mostra.
---

# Captura de movimento (folha de quadros)

Claude só enxerga imagens paradas. Para julgar animação, ritmo e impacto, capture uma
sequência de quadros do jogo real e monte uma folha ampliada (esquerda → direita, cima → baixo).

## Comando

Na raiz do repositório, `G` = `C:\Godot\Godot_v4.7.2-stable_win64.exe`, saída sempre no
scratchpad da sessão (nunca dentro do repositório):

```
G --path . --fixed-fps 60 -s res://tools/capture_frames.gd -- --out=<scratchpad>/cap.png --scenario=attack
```

- `--fixed-fps 60` é obrigatório: 1 passo de física por quadro, tempo idêntico entre execuções
  (é o que permite comparar antes/depois).
- Cenários: `idle`, `walk`, `attack` (põe uma criatura parada à frente), `gather` (encosta na
  árvore/veio mais próximo), `inventory` (janela aberta, para animações de UI), `drop` (a
  criatura à frente morre: salto e balanço dos itens; o ponto de pouso é sorteado).
- `--frames=16 --every=2` = 16 quadros a 30 por segundo (≈ 0,5 s). Golpes rápidos: `--every=1`.
  Ciclos longos (andar, respirar): `--frames=24 --every=3`.
- `--crop=96x72 --scale=3` recorta em volta do jogador; `--crop=0x0` = tela inteira (use para
  tremor de câmera e UI).
- Precisa de janela (não use `--headless`: não há imagem renderizada).
- Novo cenário = nova entrada em `_prepare`/`_act` de `tools/capture_frames.gd` (não crie
  scripts avulsos de captura).

## Como avaliar uma folha

Leia a folha quadro a quadro e responda por escrito:

1. **Antecipação**: há 1–3 quadros de preparo antes da ação (recuo, encolher)?
2. **Impacto**: o quadro do acerto é claramente diferente (flash, pausa, deslocamento)?
   Dura pelo menos 2 quadros a 30 fps? Senão o olho não registra.
3. **Ação legível**: dá para ver a direção e o alcance do golpe/efeito em algum quadro?
4. **Recuperação**: a volta ao repouso é gradual (easing), não um corte seco?
5. **Pixels**: nada borrado, nada em meio-pixel, nada que tremeleca entre quadros sem querer.
6. **Ruído**: números/efeitos se sobrepõem ou poluem o personagem?

## Antes/depois (obrigatório em mudanças de animação)

1. Capture ANTES de mexer, com os mesmos argumentos.
2. Mude.
3. Capture DEPOIS e compare as duas folhas lado a lado, citando os quadros ("antes, o impacto
   aparecia só no quadro 3; agora nos quadros 3–5 com pausa").
4. No relato ao João: o que a folha mostra é **verificação de Claude**; a sensação final é
   validação do João (regra 7 do CLAUDE.md).

## Achados registrados (atualize ao corrigir)

- 2026-10-22, `attack`: o flash do slime é claro (quadros 3–5), mas o rastro da espada quase
  não aparece e o personagem não muda de pose ao golpear (sem antecipação nem quadro de golpe).
