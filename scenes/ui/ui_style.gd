class_name UiStyle
extends RefCounted
## Tokens visuais da interface: cores, transparências e espaçamentos num só lugar (skill
## `game-ui-ux`). Telas usam estes nomes, nunca cores soltas. O tema da Godot
## (`assets/ui/theme.tres`) é GERADO a partir daqui por `tools/generate_ui_theme.gd`: mudou um
## token, rode o gerador.

# --- Superfícies --------------------------------------------------------------------------
## Fundo de janelas.
const PANEL_BACK := Color(0.06, 0.05, 0.09, 0.9)
## Fundo de elementos dentro das janelas (espaços, linhas de receita, barras, botões).
const SLOT_BACK := Color(0.1, 0.08, 0.14, 0.92)
const BORDER := Color(0.32, 0.28, 0.42)
const BORDER_HOVER := Color(0.62, 0.56, 0.78)

# --- Significado ---------------------------------------------------------------------------
## Destaque e "pronto" (progresso, interação possível, seleção).
const ACCENT := Color("e8c15a")
## Recusa leve / aviso ("precisa de ferramenta").
const WARNING := Color("ff9f6b")
## Falta / perigo (ingrediente que falta).
const DANGER := Color(1.0, 0.45, 0.4)
## Ganho bom (subiu de nível).
const POSITIVE := Color("8fe388")
const HEALTH := Color("d94a4a")
## Dano de efeito (veneno...): número amarelo-esverdeado, diferente do golpe e da cura.
const EFFECT_DAMAGE := Color("c8e04a")
## Chefe enfurecido (fase 2): barra de vida e aviso.
const ENRAGED := Color("ff7a3d")

# --- Texto -----------------------------------------------------------------------------------
const TEXT := Color.WHITE
## Texto de ganho de item (menos gritante que o branco).
const TEXT_SOFT := Color("e8e0b0")
const TEXT_OUTLINE := Color.BLACK
## Fonte m5x7: 16 px = escala 2 do desenho original (sempre múltiplos inteiros).
const FONT_SIZE := 16
const TEXT_OUTLINE_SIZE := 4
const HINT_ALPHA := 0.7
## Algo que existe mas não dá para usar agora (receita sem material, botão desligado).
const UNAVAILABLE_ALPHA := 0.45

# --- Espaços ---------------------------------------------------------------------------------
const WINDOW_MARGIN := Vector2(6, 4)
const BUTTON_MARGIN := Vector2(4, 1)
const GAP := 2
const SCROLL_BAR_WIDTH := 4
const ROW_GAP := 4
