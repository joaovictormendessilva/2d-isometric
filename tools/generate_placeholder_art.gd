extends SceneTree
## Gera a arte PROVISÓRIA da Etapa C (tiles, árvore, pedra, personagem, sombra) como PNG.
## Tudo é desenhado por código (sem assets externos), só para validar escala, leitura e
## ordenação isométrica. Será substituída por arte própria.
##
## Uso: Godot --headless --path . -s res://tools/generate_placeholder_art.gd
## Depois rode --import para a Godot importar os PNGs.

const TerrainAtlas := preload("res://tools/terrain_atlas.gd")

const TILE := Iso.TILE_SIZE
const OUT_DIR := "res://assets/sprites/placeholder/"

# Paletas de 3 tons: [base, sombra, luz].
const GRASS := [Color("4f8a3f"), Color("437a36"), Color("68a24f")]
const DIRT := [Color("8b6b47"), Color("75583a"), Color("a3825a")]
const WATER := [Color("3d6fa8"), Color("335f92"), Color("6a9fd4")]
const LEAVES := [Color("4f8f3e"), Color("356b2f"), Color("7cb85a")]
const STONE := [Color("7f7f93"), Color("5d5d70"), Color("a8a8b8")]
const TRUNK := [Color("6b4a2f"), Color("4e3522")]
const LEAVES_OUTLINE := Color("1c3320")
const STONE_OUTLINE := Color("2a2a36")
## Caverna (J1): piso de pedra frio, mais escuro e menos saturado que quem anda nele; abismo
## quase preto, puxado para o roxo (sombra fria).
const CAVE_FLOOR := [Color("4a4452"), Color("3b3646"), Color("5c5566")]
const CHASM := [Color("141019"), Color("0c0a10"), Color("221c2a")]
## Rampa de cada tile do terreno (os de grama usam GRASS).
const TILE_PALETTES := {&"dirt": DIRT, &"water": WATER, &"cave_floor": CAVE_FLOOR, &"chasm": CHASM}
const LUMBER_LEAVES := [Color("7a9a3a"), Color("5b7a2c"), Color("a8c45a")]
const OAK_LEAVES := [Color("2f6a3a"), Color("234f2c"), Color("4f8a4a")]
const OAK_TRUNK := [Color("4e3522"), Color("3a271a")]
const COPPER := [Color("d9823b"), Color("a85f28"), Color("f2b06a")]
const SLIME := [Color("8a5cc7"), Color("6a42a3"), Color("b48ae8")]
const SLIME_OUTLINE := Color("2a1840")
## Slime venenoso (G1c): verde-limão mais claro e saturado que a grama, contorno verde-escuro.
const POISON_SLIME := [Color("9ccc3a"), Color("4f8a3a"), Color("d4f05a")]
const POISON_SLIME_OUTLINE := Color("1c2e1a")
const SLIME_EYES := Color("1b1a26")
## Slime de montaria (J3): azul, para nunca ser confundido com os slimes inimigos (roxo e verde).
const RIDING_SLIME := [Color("4a9ad8"), Color("2e4a8a"), Color("a8e8f8")]
const RIDING_SLIME_OUTLINE := Color("16243f")
const SLASH := Color(1.0, 0.97, 0.85)
const SHADOW := Color(0.05, 0.04, 0.1, 0.35)

const CHARACTER_PALETTE := {
	"o": Color("1b1a26"),  # contorno
	"C": Color("3b4f8f"),  # capa
	"L": Color("5a74c4"),  # capa (luz)
	"D": Color("2a3566"),  # capa (sombra)
	"s": Color("f2c29b"),  # pele
	"S": Color("d19a74"),  # pele (sombra)
	"e": Color("1b1a26"),  # olhos
	"t": Color("8a5a3b"),  # túnica
	"T": Color("6a4430"),  # túnica (sombra)
	"b": Color("4a3020"),  # cinto
	"g": Color("e8c15a"),  # fivela
	"k": Color("3a2a2a"),  # botas
}

# Personagem 16x23 montado por partes; frente e costas compartilham capuz e pernas.
const HOOD_TOP := [
	"......oooo......",
	".....oLLCCo.....",
	"....oLLCCCCo....",
	"...oLCCCCCCDo...",
]
const FRONT_MIDDLE := [
	"...oLCooooCDo...",
	"..oLCossssoCDo..",
	"..oLosesseSoDo..",
	"..oLossssSSoDo..",
	"..oCDoSSSSoDDo..",
	"...oCDooooDDo...",
	"..oLCCtttTCCDo..",
	".oLCCtttttTCCDo.",
	".oLCCtttttTCCDo.",
	".oLCsbbgbbbsCDo.",
	".oLCCtttttTCCDo.",
	".oLCCtttttTCCDo.",
	"..oCCTtttTTCDo..",
	"..oDCCTTTTCDDo..",
]
const BACK_MIDDLE := [
	"...oLCCCCCCDo...",
	"..oLCCCCCCCCDo..",
	"..oLCCCCCCCCDo..",
	"..oLCCCCCCCDDo..",
	"..oCDDCCCCDDDo..",
	"...oCDDDDDDDo...",
	"..oLCCCCCCCCDo..",
	".oLCCCCCCCCCCDo.",
	".oLCCCCCCCCCCDo.",
	".oLCsCCCCCCsCDo.",
	".oLCCCCCCCCCCDo.",
	".oLCCCCCCCCCCDo.",
	"..oCCCCCCCCCDo..",
	"..oDCCCCCCCDDo..",
]
const LEGS := [
	"...oDDDDDDDDo...",
	"....okkookko....",
	"....okkookko....",
	"...okkkookkko...",
	"...oooo..oooo...",
]



# Mercador 16x24 (F3): chapéu de aba larga (silhueta diferente do capuz do jogador) e túnica
# verde até o chão; luz à esquerda, sombra fria à direita.
const MERCHANT_PALETTE := {
	"o": Color("1b1a26"),  # contorno
	"H": Color("9c6a3e"),  # chapéu (luz)
	"h": Color("7a4f2e"),  # chapéu
	"d": Color("53332a"),  # chapéu (sombra)
	"g": Color("e8c15a"),  # fita e botões dourados
	"s": Color("f2c29b"),  # pele
	"S": Color("d19a74"),  # pele (sombra)
	"e": Color("1b1a26"),  # olhos
	"R": Color("5fa082"),  # túnica (luz)
	"r": Color("3f7f6a"),  # túnica
	"q": Color("2c5a5a"),  # túnica (sombra)
	"b": Color("4a3020"),  # cinto
	"k": Color("3a2a2a"),  # botas
}
const MERCHANT := [
	"......oooo......",
	".....oHhhdo.....",
	".....ohhhdo.....",
	"....oggggggo....",
	".oooHhhhhhhdooo.",
	"oHhhhhhhhhhhhddo",
	".ooosssssssSooo.",
	"...osesssseSo...",
	"...ossssssSSo...",
	"....oSSSSSSo....",
	"...oRrrrrrrqo...",
	"..oRrrrrrrrrqo..",
	".oRrrrrgrrrrqqo.",
	".osRrrrrrrrrqSo.",
	".oRrbbbbgbbbqqo.",
	".oRrrrrrrrrrqqo.",
	".oRrrrrgrrrrqqo.",
	".oRrrrrrrrrrqqo.",
	".oRrrrrrrrrqqqo.",
	"..oqrrrrrrqqqo..",
	"..oqqqqqqqqqqo..",
	"...okkoo.okko...",
	"...okkko.okkko..",
	"...ooooo.ooooo..",
]
# Ícones de itens 8x8, desenhados por letra. Variações trocam letras (`ICONS[nome][1]`).
const ICON_PALETTE := {
	"o": Color("1b1a26"),  # contorno
	"w": Color("a3784a"),  # madeira
	"W": Color("6b4a2f"),  # madeira (sombra)
	"K": Color("6b4a2f"),  # carvalho
	"k": Color("3a271a"),  # carvalho (sombra)
	"r": Color("d8b07a"),  # anéis da madeira
	"l": Color("a8a8b8"),  # pedra (luz)
	"s": Color("7f7f93"),  # pedra
	"S": Color("5d5d70"),  # pedra (sombra)
	"C": Color("f2b06a"),  # cobre (luz)
	"c": Color("d9823b"),  # cobre
	"d": Color("a85f28"),  # cobre (sombra)
	"h": Color("8a5a3b"),  # cabo
	"G": Color("f6dc7a"),  # ouro (luz)
	"y": Color("e8b84a"),  # ouro
	"Y": Color("b07a2a"),  # ouro (sombra)
	"g": Color("d8eef0"),  # vidro (reflexo)
	"R": Color("f0705a"),  # poção (luz, puxa para o quente)
	"e": Color("c8323c"),  # poção
	"E": Color("7a1c3e"),  # poção (sombra, puxa para o roxo)
	"q": Color("b48ae8"),  # gosma (luz)
	"p": Color("8a5cc7"),  # gosma
	"P": Color("6a42a3"),  # gosma (sombra)
	"t": Color("c8e04a"),  # veneno (luz, puxa para o amarelo)
	"v": Color("7fb83a"),  # veneno
	"V": Color("3f7a4a"),  # veneno (sombra, puxa para o azul)
	"b": Color("a8e8f8"),  # rapidez (luz)
	"B": Color("4a9ad8"),  # rapidez
	"N": Color("2e4a8a"),  # rapidez (sombra, puxa para o roxo)
	"a": Color("e0c8ff"),  # arcano (luz)
	"A": Color("9a6cff"),  # arcano
	"Z": Color("4a2a9a"),  # arcano (sombra)
}
const LOG := [
	"........",
	".oooooo.",
	"owwwwwro",
	"oWwwwrro",
	"oWWWWWro",
	".oooooo.",
	"........",
	"........",
]
const PEBBLE := [
	"........",
	"...ooo..",
	"..olsoo.",
	".olsssSo",
	".osssSSo",
	"..oSSSo.",
	"...ooo..",
	"........",
]
const AXE := [
	".....oo.",
	"....olso",
	"...ohsSo",
	"..oho.o.",
	".oho....",
	"oho.....",
	"oo......",
	"........",
]
const PICKAXE := [
	".oooooo.",
	"olsssSSo",
	".ooohoo.",
	"...oho..",
	"...oho..",
	"...oho..",
	"...oho..",
	"....o...",
]
const BENCH := [
	"........",
	"oooooooo",
	"orwwwwro",
	"oWWWWWWo",
	"oWooooWo",
	"oWo..oWo",
	"ooo..ooo",
	"........",
]
const SWORD := [
	"......oo",
	".....olo",
	"....olso",
	"o..olso.",
	"oooslo..",
	".ohoo...",
	"oho.o...",
	"oo......",
]
## Arco (J2): madeira em arco no canto de cima à esquerda, corda clara na diagonal.
const BOW := [
	"...oooo.",
	"..owwwWo",
	".owoo.lo",
	"owo..lo.",
	"owo.lo..",
	"owolo...",
	"oWlo....",
	".oo.....",
]
## Cajado (J2b): haste de madeira na diagonal com uma gema azul na ponta.
const STAFF := [
	".....oo.",
	"....obBo",
	"....oBNo",
	"...owoo.",
	"..owo...",
	".owo....",
	"oWo.....",
	"oo......",
]
## Slime de montaria (J3): gota azul com sela.
## Sela da montaria: assento de madeira com a borda clara (luz de cima).
const SADDLE := [
	".oooooo.",
	"owwrrwwo",
	"oWWWWWWo",
	".oooooo.",
]
const RIDING_SLIME_ICON := [
	"........",
	"..oooo..",
	".owwwWo.",
	"obBWWBNo",
	"obBBBBNo",
	"oBBoBoNo",
	".oNNNNo.",
	"..oooo..",
]
## Pedra de portal (J5): obelisco de pedra com runa no meio ("1" e "2"): entalhada (apagada) ou
## acesa em arcano para quem a ativou. Luz de cima à esquerda; pés no meio da base.
const WAYSTONE := [
	"......oo......",
	".....ollo.....",
	"....ollsSo....",
	"....olssSo....",
	"...ollssSSo...",
	"...olssssSo...",
	"...ols1ssSo...",
	"...ol121sSo...",
	"...ols1ssSo...",
	"...olss1sSo...",
	"...ols121So...",
	"...olss1sSo...",
	"...ols1ssSo...",
	"...ol121sSo...",
	"...ols1ssSo...",
	"...olssssSo...",
	"...olssssSo...",
	"...olssssSo...",
	"...olssssSo...",
	"..oollsssSSo..",
	".ollllssssSSo.",
	".olssssssSSSo.",
	"oollssssssSSSo",
	"olsssssssSSSSo",
	".oooooooooooo.",
]
const WAYSTONE_DORMANT := {"1": "S", "2": "S"}
const WAYSTONE_LIT := {"1": "A", "2": "a"}
const SHIELD := [
	".oooooo.",
	"owwWwwWo",
	"owwWwwWo",
	"owWllWWo",
	"owwSswWo",
	".owWwWo.",
	"..owwo..",
	"...oo...",
]
const HELMET := [
	"........",
	"..oooo..",
	".oCccdo.",
	"oCccccdo",
	"ocooooco",
	"oco..oco",
	"oo....oo",
	"........",
]
const BACKPACK := [
	"..oooo..",
	".o.oo.o.",
	"oWwwwwWo",
	"owwrrwwo",
	"owwwwwWo",
	"owWWWWWo",
	".oooooo.",
	"........",
]
const RING := [
	"...oo...",
	"..oCco..",
	"..oooo..",
	".oc..do.",
	"oc....do",
	"oc....do",
	".od..do.",
	"..oooo..",
]
const COIN := [
	"..oooo..",
	".oGGyyo.",
	"oGyyyyYo",
	"oGyYYyYo",
	"oyyYYyYo",
	"oyyyyYYo",
	".oyYYYo.",
	"..oooo..",
]
## Frasco redondo com rolha; reflexo do vidro em cima à esquerda (luz única).
const POTION := [
	"..ohho..",
	"..oggo..",
	".ogRReo.",
	"ogRReeEo",
	"oRReeeEo",
	"oeeeeEEo",
	".oeEEEo.",
	"..oooo..",
]
## Núcleo do Rei Slime: esfera de gosma com reflexo e um brilho dourado no meio (drop do chefe).
const KING_CORE := [
	"..oooo..",
	".oqqppo.",
	"oqgpppPo",
	"oqpGypPo",
	"oppyYpPo",
	"oppppPPo",
	".oPPPPo.",
	"..oooo..",
]
## Efeitos (HUD): gota de veneno com luz em cima à esquerda; rapidez = duas setas para a frente.
const POISON_DROP := [
	"...oo...",
	"..otvo..",
	".otvvVo.",
	".otvvVo.",
	"otvvvvVo",
	"ovvvvVVo",
	".oVVVVo.",
	"..oooo..",
]
const SWIFT_ARROWS := [
	"........",
	"oo..oo..",
	"obo.obo.",
	".obo.obo",
	".oBo.oBo",
	"oBo.oBo.",
	"oo..oo..",
	"........",
]
## Habilidade (G2): faísca arcana em losango; tomo = livro de capa arcana com as páginas embaixo.
const ARCANE_SPARK := [
	"...oo...",
	"..oaAo..",
	".oaAAZo.",
	"oaAAAAZo",
	"oAAAAZZo",
	".oAAZZo.",
	"..oZZo..",
	"...oo...",
]
const TOME := [
	"........",
	".oooooo.",
	"oaAAAAZo",
	"oAAaAAZo",
	"oAAAAAZo",
	"oZZZZZZo",
	"orrrrrro",
	".oooooo.",
]
## Explosão arcana (G2d): anel de energia com o miolo claro (lê como "área"); o tomo dela traz o
## anel na capa, para não confundir com o do projétil.
const ARCANE_RING := [
	"..oooo..",
	".oaAAZo.",
	"oaAooZZo",
	"oAoaaoZo",
	"oAoaaoZo",
	"oZZooZZo",
	".oZZZZo.",
	"..oooo..",
]
const RING_TOME := [
	"........",
	".oooooo.",
	"oAaaaaZo",
	"oAaZZaZo",
	"oAaaaaZo",
	"oZZZZZZo",
	"orrrrrro",
	".oooooo.",
]
## Ícone da coroa fabricada com o núcleo: ouro com uma gema de gosma no meio.
const CROWN_ICON := [
	"........",
	".o.oo.o.",
	"oGoyyoYo",
	"oGyqpyYo",
	"oGyPPyYo",
	"oyyyyyYo",
	"oYYYYYYo",
	".oooooo.",
]
## Coroa do Rei Slime, pousada no alto da gota; contorno em ouro escuro (cor do material).
const CROWN := [
	".o..o..o.",
	"oGooyooYo",
	"oGyyyyyYo",
	"oyyyeyyYo",
	".ooooooo.",
]
const CROWN_OUTLINE := Color("6a4a1a")
## Baú de recompensa da dungeon (J1b), de frente: madeira com faixas de ouro e fechadura. Aberto, a
## tampa cai para trás e aparece o tesouro. Contorno em madeira escura (cor do material).
const CHEST_CLOSED := [
	"..oooooooooooo..",
	".orrrrrrrrrrrro.",
	"owwwwwwwwwwwwwWo",
	"owwwwwwwwwwwwwWo",
	"oGyyyyyGGyyyyyYo",
	"owwwwwwoowwwwwWo",
	"owwwwwoGyowwwwWo",
	"owwwwwoyYowwwwWo",
	"owwwwwwoowwwwwWo",
	"oGyyyyyyyyyyyyYo",
	"oWWWWWWWWWWWWWWo",
	".oooooooooooooo.",
]
const CHEST_OPEN := [
	"..oooooooooooo..",
	".oWWWWWWWWWWWWo.",
	".okkkkkkkkkkkko.",
	"oooooooooooooooo",
	"okGgGGkGyGkGGyko",
	"okkyGkkkGykkGkko",
	"oGyyyyyyyyyyyyYo",
	"owwwwwwoowwwwwWo",
	"owwwwwoGyowwwwWo",
	"owwwwwoyYowwwwWo",
	"owwwwwwoowwwwwWo",
	"oGyyyyyyyyyyyyYo",
	"oWWWWWWWWWWWWWWo",
	".oooooooooooooo.",
]
const CHEST_OUTLINE := Color("2a1a10")
## Saída da dungeon (J1b): círculo mágico arcano no chão, com o meio translúcido.
const PORTAL := [ICON_PALETTE["A"], ICON_PALETTE["Z"], ICON_PALETTE["a"]]
const PORTAL_INSIDE := Color(0.29, 0.16, 0.6, 0.55)
const COPPER_SWAP := {"l": "C", "s": "c", "S": "d"}
const ICONS := {
	"wood": [LOG, {}],
	"oak_wood": [LOG, {"w": "K", "W": "k"}],
	"stone": [PEBBLE, {}],
	"copper_ore": [PEBBLE, {"l": "C", "S": "d"}],
	"stone_axe": [AXE, {}],
	"stone_pickaxe": [PICKAXE, {}],
	"copper_axe": [AXE, COPPER_SWAP],
	"workbench": [BENCH, {}],
	"sword": [SWORD, {}],
	"wooden_shield": [SHIELD, {}],
	"bow": [BOW, {}],
	"staff": [STAFF, {}],
	"riding_slime": [RIDING_SLIME_ICON, {}],
	"copper_helmet": [HELMET, {}],
	"simple_backpack": [BACKPACK, {}],
	"magnet_ring": [RING, {}],
	"coin": [COIN, {}],
	"health_potion": [POTION, {}],
	"swiftness_potion": [POTION, {"R": "b", "e": "B", "E": "N"}],
	"king_slime_core": [KING_CORE, {}],
	"king_slime_crown": [CROWN_ICON, {}],
	"effect_poison": [POISON_DROP, {}],
	"effect_swiftness": [SWIFT_ARROWS, {}],
	"arcane_bolt": [ARCANE_SPARK, {}],
	"tome_arcane_bolt": [TOME, {}],
	"arcane_blast": [ARCANE_RING, {}],
	"tome_arcane_blast": [RING_TOME, {}],
}


func _initialize() -> void:
	_save(_terrain_atlas(), TerrainAtlas.TEXTURE_PATH)
	_save(_character_sheet(), OUT_DIR + "character.png")
	_save(_tree(LEAVES, TRUNK), OUT_DIR + "tree.png")
	_save(_rock(), OUT_DIR + "rock.png")
	_save(_marked_tree(LUMBER_LEAVES, TRUNK, 2), OUT_DIR + "lumber_tree.png")
	_save(_marked_tree(OAK_LEAVES, OAK_TRUNK, 3), OUT_DIR + "old_oak.png")
	_save(_stump(TRUNK), OUT_DIR + "stump.png")
	_save(_stump(OAK_TRUNK), OUT_DIR + "oak_stump.png")
	_save(_rock(COPPER), OUT_DIR + "copper_vein.png")
	_save(_rubble(), OUT_DIR + "rubble.png")
	_save(_cave_entrance(), OUT_DIR + "cave_entrance.png")
	var chest_palette := ICON_PALETTE.merged({"o": CHEST_OUTLINE}, true)
	_save(_sprite(CHEST_CLOSED, chest_palette), OUT_DIR + "chest_closed.png")
	_save(_sprite(CHEST_OPEN, chest_palette), OUT_DIR + "chest_open.png")
	_save(_exit_portal(), OUT_DIR + "exit_portal.png")
	_save(_workbench(), OUT_DIR + "workbench.png")
	_save(_sprite(MERCHANT, MERCHANT_PALETTE), OUT_DIR + "merchant.png")
	for icon: String in ICONS:
		_save(_icon(ICONS[icon][0], ICONS[icon][1]), OUT_DIR + "icon_%s.png" % icon)
	_save(_shadow(Vector2i(12, 5)), OUT_DIR + "shadow.png")
	_save(_slime(), OUT_DIR + "slime.png")
	_save(_slime(POISON_SLIME, POISON_SLIME_OUTLINE), OUT_DIR + "poison_slime.png")
	_save(_king_slime(), OUT_DIR + "king_slime.png")
	_save(_riding_slime(), OUT_DIR + "riding_slime.png")
	_save(_icon(WAYSTONE, WAYSTONE_DORMANT), OUT_DIR + "waystone.png")
	_save(_icon(WAYSTONE, WAYSTONE_LIT), OUT_DIR + "waystone_lit.png")
	_save(_shadow(Vector2i(26, 8)), OUT_DIR + "shadow_large.png")
	_save(_gel(), OUT_DIR + "gel.png")
	_save(_slash(), OUT_DIR + "slash.png")
	quit(0)


func _save(image: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Falha ao salvar %s (%d)" % [path, err])
		quit(1)
	print("[art] %s (%dx%d)" % [path, image.get_width(), image.get_height()])


# --- Formas -----------------------------------------------------------------------------

## Pixel (x, y) pertence ao losango do tile? Teste no centro do pixel: losangos vizinhos
## encaixam sem buracos nem sobreposição (bordas em degraus de 2 px).
static func in_tile(x: int, y: int) -> bool:
	return in_ellipse(x, y, Vector2(TILE) / 2.0, Vector2(TILE) / 2.0, 1)


## Pixel dentro da elipse? `norm` 1 = losango (|dx|+|dy|), 2 = elipse comum.
static func in_ellipse(x: int, y: int, center: Vector2, radii: Vector2, norm: int = 2) -> bool:
	var d := ((Vector2(x, y) + Vector2(0.5, 0.5)) - center) / radii
	if norm == 1:
		return absf(d.x) + absf(d.y) < 1.0
	return d.length_squared() < 1.0


## Tom da paleta [base, sombra, luz] para um pixel, com luz vinda de cima/esquerda.
## `v` < -band = luz, > band = sombra; perto das faixas, pontilhado em xadrez.
static func shade(palette: Array, v: float, band: float, x: int, y: int) -> Color:
	var dither := (x + y) % 2 == 0
	if v < -band or (v < -band + 1.5 and dither):
		return palette[2]
	if v > band or (v > band - 1.5 and dither):
		return palette[1]
	return palette[0]


## Base com pontinhos aleatórios de sombra e luz.
static func speckle(rng: RandomNumberGenerator, palette: Array, dark: float, light: float) -> Color:
	var r := rng.randf()
	if r < dark:
		return palette[1]
	return palette[2] if r < dark + light else palette[0]


## Pinta de `color` todo pixel transparente vizinho (4 direções) de um pixel opaco.
static func outline(img: Image, color: Color) -> void:
	var source := img.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			if source.get_pixel(x, y).a > 0.0:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if Rect2i(Vector2i.ZERO, img.get_size()).has_point(n) and source.get_pixelv(n).a > 0.0:
					img.set_pixel(x, y, color)
					break


# --- Imagens ----------------------------------------------------------------------------

func _terrain_atlas() -> Image:
	var columns := TerrainAtlas.COLUMNS
	var img := Image.create(TILE.x * columns.size(), TILE.y, false, Image.FORMAT_RGBA8)
	for i in columns.size():
		var tile := columns[i]
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + i
		var palette: Array = TILE_PALETTES.get(tile, GRASS)
		var flat := tile in [&"water", &"chasm"]
		for y in TILE.y:
			for x in TILE.x:
				if in_tile(x, y):
					var color: Color = palette[0] if flat else speckle(rng, palette, 0.11, 0.07)
					img.set_pixel(i * TILE.x + x, y, color)
		if tile == &"water":
			_water_waves(img, i * TILE.x, rng)
		elif tile == &"cave_floor":
			_floor_cracks(img, i * TILE.x, rng)
		elif tile in TerrainAtlas.GRASS:
			_grass_blades(img, i * TILE.x, rng)
	return img


func _grass_blades(img: Image, ox: int, rng: RandomNumberGenerator) -> void:
	for n in 4:
		var x := rng.randi_range(6, TILE.x - 7)
		var y := rng.randi_range(4, TILE.y - 4)
		if in_tile(x, y) and in_tile(x, y - 1):
			img.set_pixel(ox + x, y, GRASS[2])
			img.set_pixel(ox + x, y - 1, GRASS[2])


## Rachaduras curtas (3 px em diagonal, na direção do losango) no piso da caverna.
func _floor_cracks(img: Image, ox: int, rng: RandomNumberGenerator) -> void:
	for n in 2:
		var x := rng.randi_range(8, TILE.x - 11)
		var y := rng.randi_range(4, TILE.y - 6)
		for d in 3:
			if in_tile(x + d * 2, y + d):
				img.set_pixel(ox + x + d * 2, y + d, CAVE_FLOOR[1])
				img.set_pixel(ox + x + d * 2 + 1, y + d, CAVE_FLOOR[1])


func _water_waves(img: Image, ox: int, rng: RandomNumberGenerator) -> void:
	for n in 3:
		var x := rng.randi_range(6, TILE.x - 10)
		var y := rng.randi_range(4, TILE.y - 5)
		for dx in 3:
			if in_tile(x + dx, y):
				img.set_pixel(ox + x + dx, y, WATER[2])
		if in_tile(x + 1, y + 1):
			img.set_pixel(ox + x + 1, y + 1, WATER[1])


func _character_sheet() -> Image:
	var frames := [HOOD_TOP + FRONT_MIDDLE + LEGS, HOOD_TOP + BACK_MIDDLE + LEGS]
	var w: int = HOOD_TOP[0].length()
	var h: int = frames[0].size()
	var img := Image.create(w * frames.size(), h, false, Image.FORMAT_RGBA8)
	for f in frames.size():
		for y in h:
			var row: String = frames[f][y]
			for x in w:
				if CHARACTER_PALETTE.has(row[x]):
					img.set_pixel(f * w + x, y, CHARACTER_PALETTE[row[x]])
	return img


## Árvore 32x48: tronco + copa feita de 4 círculos, sombreada e contornada. `trunk_width`
## engrossa o tronco (árvores antigas).
func _tree(leaves: Array, trunk: Array, trunk_width: int = 2) -> Image:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var blobs := [[Vector2(16, 15), 11.0], [Vector2(9, 21), 8.0], [Vector2(23, 21), 8.0],
		[Vector2(16, 25), 9.0]]
	for y in img.get_height():
		for x in img.get_width():
			if _in_trunk(x, y, trunk_width, 28):
				img.set_pixel(x, y, trunk[1] if x >= 15 + trunk_width else trunk[0])
			for blob: Array in blobs:
				if in_ellipse(x, y, blob[0], Vector2.ONE * blob[1]):
					var v := (x - 16.0) * 0.5 + (y - 18.0) * 0.8
					img.set_pixel(x, y, shade(leaves, v, 5.0, x, y))
					break
	outline(img, LEAVES_OUTLINE)
	return img


## Pedra 20x14. Com `ore`, ganha pontos de minério (veio).
func _rock(ore: Array = []) -> Image:
	var img := Image.create(20, 14, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in img.get_height():
		for x in img.get_width():
			if in_ellipse(x, y, Vector2(10, 7.5), Vector2(8.5, 5.5)):
				var v := (x - 10.0) * 0.4 + (y - 7.0) * 0.9
				img.set_pixel(x, y, shade(STONE, v, 2.5, x, y))
				if not ore.is_empty() and rng.randf() < 0.16:
					img.set_pixel(x, y, ore[2] if v < 0.0 else ore[0])
	outline(img, STONE_OUTLINE)
	return img


func _shadow(size: Vector2i) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var half := Vector2(img.get_size()) / 2.0
	for y in img.get_height():
		for x in img.get_width():
			if in_ellipse(x, y, half, half):
				img.set_pixel(x, y, SHADOW)
	return img


## Gota de gosma sombreada com brilho; usada pelo slime e pelo item que ele derruba.
func _blob(size: Vector2i, center: Vector2, radii: Vector2, band: float, palette: Array = SLIME,
		outline_color: Color = SLIME_OUTLINE) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			if in_ellipse(x, y, center, radii):
				var v := (x - center.x) * 0.5 + (y - center.y) * 0.9
				img.set_pixel(x, y, shade(palette, v, band, x, y))
	var shine := Vector2i(center - radii * 0.45)
	img.set_pixelv(shine, Color.WHITE)
	outline(img, outline_color)
	return img


func _slime(palette: Array = SLIME, outline_color: Color = SLIME_OUTLINE) -> Image:
	var img := _blob(Vector2i(16, 12), Vector2(8, 6.5), Vector2(7.5, 5.5), 2.5, palette, outline_color)
	for eye in [Vector2i(6, 6), Vector2i(10, 6)]:
		img.set_pixelv(eye, SLIME_EYES)
		img.set_pixelv(eye + Vector2i.DOWN, SLIME_EYES)
	return img


## Rei Slime (F4): gota grande com olhos de 2x2 e coroa. Pés no centro da base: (15, 24).
func _king_slime() -> Image:
	var img := _blob(Vector2i(30, 25), Vector2(15, 15.5), Vector2(14, 8.5), 4.0)
	for eye in [Vector2i(10, 14), Vector2i(18, 14)]:
		img.fill_rect(Rect2i(eye, Vector2i(2, 3)), SLIME_EYES)
	var crown := _sprite(CROWN, ICON_PALETTE.merged({"o": CROWN_OUTLINE}, true))
	img.blend_rect(crown, Rect2i(Vector2i.ZERO, crown.get_size()), Vector2i(11, 2))
	return img


## Montaria (J3): gota larga azul com olhos olhando para a direita (o lado da frente; o jogo
## espelha) e sela de madeira nas costas. Domo alto: o cavaleiro tampa só o topo, e o corpo e
## os olhos aparecem embaixo dele. Pés no centro da base: (13, 17).
func _riding_slime() -> Image:
	var img := _blob(Vector2i(26, 18), Vector2(13, 10.5), Vector2(12, 7), 3.5, RIDING_SLIME,
		RIDING_SLIME_OUTLINE)
	for eye in [Vector2i(18, 11), Vector2i(21, 11)]:
		img.fill_rect(Rect2i(eye, Vector2i(1, 3)), SLIME_EYES)
	var saddle := _sprite(SADDLE, ICON_PALETTE)
	img.blend_rect(saddle, Rect2i(Vector2i.ZERO, saddle.get_size()), Vector2i(7, 3))
	return img


func _gel() -> Image:
	return _blob(Vector2i(8, 7), Vector2(4, 3.5), Vector2(3.5, 2.5), 1.0)


## Rastro do golpe: arco em meia-lua apontando para a direita, mais opaco no meio.
func _slash() -> Image:
	var size := 48
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) / 2.0
	var half_arc := deg_to_rad(60.0)
	for y in size:
		for x in size:
			var p := Vector2(x, y) + Vector2(0.5, 0.5) - center
			var angle := absf(p.angle())
			if p.length() < 17.0 or p.length() > 24.0 or angle > half_arc:
				continue
			# Mais grosso e opaco no centro do arco, afinando nas pontas.
			var along := 1.0 - angle / half_arc
			if p.length() < 24.0 - 7.0 * along:
				continue
			img.set_pixel(x, y, Color(SLASH, 0.35 + 0.65 * along))
	return img


## Tronco centrado em x = 16 com meia-largura `half_width`, de `top` até a base (y 45), que
## alarga um pixel de cada lado.
static func _in_trunk(x: int, y: int, half_width: int, top: int) -> bool:
	return (x >= 16 - half_width and x <= 15 + half_width and y >= top and y <= 45) \
		or (y == 45 and x >= 15 - half_width and x <= 16 + half_width)


## Árvore coletável: a marca de todo ponto de madeira é o corte de machado no tronco e a lenha
## empilhada ao pé (o resto do cenário não tem), na cor da própria madeira.
func _marked_tree(leaves: Array, trunk: Array, trunk_width: int) -> Image:
	var img := _tree(leaves, trunk, trunk_width)
	for y in range(37, 40):
		img.set_pixel(16 - trunk_width, y, ICON_PALETTE["r"])
	for log_row: Array in [[43, 20, 27], [41, 21, 26]]:
		for x in range(log_row[1] + trunk_width - 2, log_row[2] + trunk_width - 1):
			var end: bool = x == log_row[2] + trunk_width - 2
			img.set_pixel(x, log_row[0], ICON_PALETTE["r"] if end else trunk[0])
			img.set_pixel(x, log_row[0] + 1, trunk[1])
	return img


## Toco (ponto de madeira esgotado), no mesmo quadro 32x48 da árvore para alinhar.
func _stump(trunk: Array) -> Image:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			if _in_trunk(x, y, 3, 39):
				img.set_pixel(x, y, ICON_PALETTE["r"] if y == 39 else (trunk[1] if x >= 18 else trunk[0]))
	outline(img, LEAVES_OUTLINE)
	return img


## Entrada de caverna (J1): monte de pedra com a boca escura embaixo, no meio. Base no centro
## de baixo: (20, 29).
func _cave_entrance() -> Image:
	var img := Image.create(40, 30, false, Image.FORMAT_RGBA8)
	var center := Vector2(20, 24)  # domo: elipse cortada na base, apoiada no chão
	for y in img.get_height():
		for x in img.get_width():
			if in_ellipse(x, y, center, Vector2(19, 20)):
				var v := (x - center.x) * 0.35 + (y - 12.0) * 0.8
				img.set_pixel(x, y, shade(STONE, v, 3.0, x, y))
			if y >= 14 and in_ellipse(x, y, Vector2(20, 30), Vector2(7, 14)):
				# Por dentro: a parede direita da boca pega a luz da esquerda.
				img.set_pixel(x, y, CHASM[2] if x >= 25 and y >= 19 else CHASM[0])
	outline(img, STONE_OUTLINE)
	return img


## Círculo mágico da saída (26x14), deitado no chão: anel com luz de cima/esquerda, runas
## claras nos quatro pontos e o meio translúcido. Centro: (13, 7).
func _exit_portal() -> Image:
	var img := Image.create(26, 14, false, Image.FORMAT_RGBA8)
	var center := Vector2(13, 7)
	for y in img.get_height():
		for x in img.get_width():
			if not in_ellipse(x, y, center, Vector2(13, 7)):
				continue
			if in_ellipse(x, y, center, Vector2(10, 5)):
				img.set_pixel(x, y, PORTAL_INSIDE)
			else:
				var v := (x - center.x) * 0.3 + (y - center.y) * 0.9
				img.set_pixel(x, y, shade(PORTAL, v, 2.5, x, y))
	for rune: Vector2i in [Vector2i(1, 6), Vector2i(24, 7), Vector2i(12, 1), Vector2i(13, 12)]:
		img.set_pixelv(rune, Color.WHITE)
	return img


## Cascalho (veio esgotado), no mesmo quadro 20x14 da pedra.
func _rubble() -> Image:
	var img := Image.create(20, 14, false, Image.FORMAT_RGBA8)
	for stone: Array in [[Vector2(6, 10), Vector2(3.5, 2.5)], [Vector2(13, 10.5), Vector2(4, 2.5)],
			[Vector2(10, 7.5), Vector2(2.5, 2)]]:
		for y in img.get_height():
			for x in img.get_width():
				if in_ellipse(x, y, stone[0], stone[1]):
					img.set_pixel(x, y, shade(STONE, (y - stone[0].y) * 0.9, 0.8, x, y))
	outline(img, STONE_OUTLINE)
	return img


## Sprite desenhado por letras com a paleta dada (letra fora da paleta = transparente).
func _sprite(rows: Array, palette: Dictionary) -> Image:
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row: String = rows[y]
		assert(row.length() == img.get_width(), "linha %d com largura errada" % y)
		for x in row.length():
			if palette.has(row[x]):
				img.set_pixel(x, y, palette[row[x]])
	return img


## Ícone com a paleta dos ícones; `swap` troca letras (variação de material).
func _icon(rows: Array, swap: Dictionary) -> Image:
	var palette := ICON_PALETTE.duplicate()
	for key: String in swap:
		palette[key] = ICON_PALETTE[swap[key]]
	return _sprite(rows, palette)


## Bancada 28x22 vista do alto em losango (tampo de tábuas, lados em sombra) com uma morsa de
## pedra. Os pés ficam no centro da base: (14, 14).
func _workbench() -> Image:
	var img := Image.create(28, 22, false, Image.FORMAT_RGBA8)
	var top := func(x: int, y: int) -> bool:
		return absf(x + 0.5 - 14.0) / 12.0 + absf(y + 0.5 - 8.0) / 6.0 <= 1.0
	for y in img.get_height():
		for x in img.get_width():
			if top.call(x, y):
				var plank_line := (x + 2 * y) % 6 == 0
				img.set_pixel(x, y, ICON_PALETTE["W"] if plank_line else ICON_PALETTE["w"])
				continue
			for drop in range(1, 7):
				if y - drop >= 8 and top.call(x, y - drop):
					img.set_pixel(x, y, ICON_PALETTE["W"] if x < 14 else ICON_PALETTE["k"])
					break
	for vise: Vector2i in [Vector2i(17, 5), Vector2i(18, 5), Vector2i(17, 6), Vector2i(18, 6)]:
		img.set_pixelv(vise, ICON_PALETTE["s"] if vise.y == 6 else ICON_PALETTE["l"])
	outline(img, LEAVES_OUTLINE)
	return img
