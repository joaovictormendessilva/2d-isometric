---
name: game-ui-ux
description: Interface e experiência do jogador — janelas, HUD, inventário, menus, dicas, estados (hover, pressionado, desligado, foco), feedback de ações, teclado/mouse/controle, textos traduzíveis. Use ao criar ou alterar qualquer tela, botão, HUD ou mensagem ao jogador, e quando o João achar algo confuso, apertado, feio ou difícil de usar.
---

# UI/UX do jogo

## Fonte única de estilo

- **Tokens** em `scenes/ui/ui_style.gd` (`UiStyle`): cores (superfícies, significado,
  texto), transparências e espaços. Telas usam `UiStyle.X`; nunca `Color(...)` solto em tela.
  Precisa de cor nova? Crie o token com um nome de **significado** (`WARNING`, não `ORANGE`).
- **Tema** `assets/ui/theme.tres` é gerado: mudou token → rodar
  `G --headless --path . -s res://tools/generate_ui_theme.gd` e importar. Não edite o
  `.tres` à mão (some na próxima geração). Controle novo da Godot (Slider, CheckBox...) →
  estilizar no gerador antes de usar.
- **Textos** só por `data/i18n/texts.csv` (`Texts.get_text`/`format`, ADR-015), todos os
  idiomas preenchidos. Nomes de teclas por `Texts.action_key`.
- **Componentes reaproveitáveis** já existentes: `DraggableWindow` (janela que arrasta e
  lembra posição), `InventorySlot`, `ItemIcon`, `RecipeRow`, `SlotMenu`, `SplitDialog`,
  `HeldItemCursor`. Tela nova monta com eles; padrão novo vira componente.

## Regras de experiência

1. **Tudo responde**: hover muda borda/cor, clique tem efeito visível no mesmo quadro (mesmo
   que o host confirme depois).
2. **Indisponível explica o porquê**: apagado (`UNAVAILABLE_ALPHA`) + dica dizendo o que falta.
   Não esconder o que o jogador ainda vai poder usar (ex.: receitas de bancada).
3. **Não bloquear o jogo**: janelas não pausam (coop); clique na UI nunca vira ataque (grupo
   `LocalPlayerInput.MOUSE_CAPTURE_GROUP` + controle sob o ponteiro).
4. **Três entradas**: teclado+mouse, controle e só teclado. Toda janela abre/fecha por ação do
   mapa de entrada; Esc fecha o que estiver por cima; foco visível (borda dourada) para
   navegação sem mouse.
5. **Pouca tela**: 640×360. Coisas opcionais são recolhíveis e lembram o estado
   (`UserSettings`). HUD nas bordas; centro livre para a ação.
6. **Legibilidade**: fonte m5x7 em 16 px (múltiplos inteiros), contorno preto 4; texto curto;
   números alinhados; ícone + quantidade antes de texto.
7. **Hierarquia de cor**: dourado = destaque/pronto, laranja = recusa leve, vermelho = falta
   ou perigo, verde = ganho. Mesma cor, mesmo significado, em todo o jogo.
8. **Consistência de gesto**: clique esquerdo age, botão direito abre opções, arrastar a barra
   move janela. Não inventar gesto novo sem motivo.
9. **Movimento na UI** (abrir janela, item ganho, nível) segue a skill `game-feel`: curto
   (0,1–0,2 s), com easing, nunca atrasando a ação.

## Verificação

1. Captura de tela (`G --path . -- --screenshot=<scratchpad>/ui.png --open-inventory`) e
   olhar a tela inteira: alinhamento, sobreposição, corte de texto.
2. Testar em inglês também (`-- --lang=en`): textos maiores quebram layout.
3. Animações de UI: `capture_frames.gd --scenario=inventory --crop=0x0`.
4. Teste automático do comportamento (abrir, clicar, estado desligado, lembrar preferência).
