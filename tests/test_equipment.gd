extends TestCase
## Equipamento (ADR-018): espaços por tipo, regras de mão (1 e 2 mãos, secundário aceito pela
## arma), acessórios sem repetir e trocas com o inventário sem criar nem perder itens. Usa
## itens só de teste (`tests/data/equipment_items/`): arco, cajado e tomo ainda não existem
## no jogo.

const TEST_ITEMS := "res://tests/data/equipment_items/"

var _items: ItemDatabase
var _inventory: Inventory
var _equipment: Equipment


func _setup() -> void:
	_items = ItemDatabase.load_all(TEST_ITEMS)
	_inventory = Inventory.new(6, _items)
	_equipment = Equipment.new(EquipmentLayout.load_default(), _items)


func test_layout_has_hands_armor_backpack_and_two_accessories() -> void:
	_setup()
	var types := range(_equipment.size()).map(func(i: int) -> int: return _equipment.slot_type(i))
	check(types.count(EquipmentData.Slot.ACCESSORY) == 2, "2 acessórios (pedido do João)")
	for slot in [EquipmentData.Slot.MAIN_HAND, EquipmentData.Slot.OFF_HAND,
			EquipmentData.Slot.HEAD, EquipmentData.Slot.CHEST, EquipmentData.Slot.LEGS,
			EquipmentData.Slot.BACKPACK]:
		check(types.count(slot) == 1, "um espaço do tipo %d" % slot)


func test_equip_from_inventory_and_take_off_to_hand() -> void:
	_setup()
	_inventory.add(&"t_helmet", 1)
	check(EquipmentRules.equip_from_inventory(_inventory, _equipment, 0), "vestiu o elmo")
	check(_equipment.item_of_type(EquipmentData.Slot.HEAD).id == &"t_helmet"
		and _inventory.count(&"t_helmet") == 0, "saiu do inventário, está na cabeça")
	var head := _equipment.index_of_type(EquipmentData.Slot.HEAD)
	check(EquipmentRules.click_slot(_inventory, _equipment, head), "clique tira")
	check(_inventory.held_item() == &"t_helmet" and _equipment.item_id(head) == Equipment.EMPTY,
		"o elmo foi para a mão")
	check(EquipmentRules.click_slot(_inventory, _equipment, head) and not _inventory.is_holding(),
		"clicar de novo com ele na mão veste")
	var hand := _equipment.index_of_type(EquipmentData.Slot.MAIN_HAND)
	_inventory.click_slot(_inventory.capacity() - 1)  # pega nada (espaço vazio)
	check(not EquipmentRules.click_slot(_inventory, _equipment, hand), "mão principal vazia: nada a tirar")


func test_items_only_go_to_their_slot_type() -> void:
	_setup()
	_inventory.add(&"t_helmet", 1)
	_inventory.click_slot(0)
	var accessory := _equipment.index_of_type(EquipmentData.Slot.ACCESSORY)
	check(not EquipmentRules.click_slot(_inventory, _equipment, accessory)
		and _inventory.held_item() == &"t_helmet", "elmo não vai no espaço de acessório")


func test_two_handed_weapon_pushes_shield_back_to_inventory() -> void:
	_setup()
	for id in [&"t_sword", &"t_shield", &"t_greatsword"]:
		_inventory.add(id, 1)
	EquipmentRules.equip_from_inventory(_inventory, _equipment, 0)  # espada
	EquipmentRules.equip_from_inventory(_inventory, _equipment, 1)  # escudo
	check(_equipment.off_hand() != null and _equipment.off_hand().id == &"t_shield",
		"espada + escudo")
	EquipmentRules.equip_from_inventory(_inventory, _equipment, 2)  # espadão
	check(_equipment.weapon().id == &"t_greatsword" and _equipment.off_hand() == null,
		"espadão de 2 mãos: o escudo saiu")
	check(_inventory.count(&"t_shield") == 1 and _inventory.count(&"t_sword") == 1,
		"escudo e espada voltaram ao inventário (nada se perdeu)")


func test_off_hand_must_be_accepted_by_the_weapon() -> void:
	_setup()
	for id in [&"t_bow", &"t_quiver", &"t_shield", &"t_staff", &"t_tome"]:
		_inventory.add(id, 1)
	var off := _equipment.index_of_type(EquipmentData.Slot.OFF_HAND)
	EquipmentRules.equip_from_inventory(_inventory, _equipment, 0)  # arco
	check(not EquipmentRules.equip_from_inventory(_inventory, _equipment, 2), "arco não aceita escudo")
	check(EquipmentRules.equip_from_inventory(_inventory, _equipment, 1), "arco aceita aljava")
	EquipmentRules.equip_from_inventory(_inventory, _equipment, 3)  # cajado de 1 mão
	check(_equipment.weapon().id == &"t_staff" and _equipment.item_id(off) == Equipment.EMPTY,
		"cajado não aceita aljava: ela voltou ao inventário")
	check(EquipmentRules.equip_from_inventory(_inventory, _equipment, 4), "cajado aceita tomo")


func test_bare_hands_accept_any_off_hand() -> void:
	_setup()
	_inventory.add(&"t_tome", 1)
	check(EquipmentRules.equip_from_inventory(_inventory, _equipment, 0), "tomo sem arma: pode")


func test_accessories_fill_free_slots_and_never_repeat() -> void:
	_setup()
	_inventory.add(&"t_ring", 2)
	_inventory.add(&"t_amulet", 1)
	check(EquipmentRules.equip_from_inventory(_inventory, _equipment, 0), "1º anel")
	check(not EquipmentRules.equip_from_inventory(_inventory, _equipment, 1), "2º anel igual: não")
	check(EquipmentRules.equip_from_inventory(_inventory, _equipment, 2), "amuleto no 2º espaço")
	var accessories := _equipment.equipped().map(func(e: EquipmentData) -> StringName: return e.id)
	check(&"t_ring" in accessories and &"t_amulet" in accessories, "anel e amuleto vestidos")


## Sem espaço para o escudo que sairia, o espadão não é vestido (nada se perde).
func test_no_room_for_displaced_off_hand_refuses() -> void:
	_items = ItemDatabase.load_all(TEST_ITEMS)
	_inventory = Inventory.new(2, _items)
	_equipment = Equipment.new(EquipmentLayout.load_default(), _items)
	_inventory.add(&"t_shield", 1)
	EquipmentRules.equip_from_inventory(_inventory, _equipment, 0)
	_inventory.add(&"t_sword", 1)
	EquipmentRules.equip_from_inventory(_inventory, _equipment, 0)  # espada (troca nada)
	_inventory.add(&"t_greatsword", 1)
	_inventory.add(&"t_helmet", 1)
	check(_inventory.space_for(&"t_shield") == 0, "inventário cheio")
	var greatsword := 0 if _inventory.slot_item(0) == &"t_greatsword" else 1
	check(not EquipmentRules.equip_from_inventory(_inventory, _equipment, greatsword),
		"sem lugar para o escudo: recusado")
	check(_equipment.weapon().id == &"t_sword" and _equipment.off_hand().id == &"t_shield",
		"nada mudou")


## Bônus somam aos atributos base (sem mudar o recurso compartilhado) e saem ao tirar o item.
func test_bonuses_change_stats_and_come_off() -> void:
	_setup()
	var character := spawn_character(Vector2(400, 300))
	var base_health := character.health.max_health
	var base_speed := character.move_speed()
	var base_radius := character.pickup_radius()
	_inventory.add(&"t_helmet", 1)
	_inventory.add(&"t_ring", 1)
	EquipmentRules.equip_from_inventory(_inventory, _equipment, 0)
	EquipmentRules.equip_from_inventory(_inventory, _equipment, 1)
	character.apply_equipment(_equipment)
	check(character.health.max_health == base_health + 20 and character.health.defense == 3,
		"elmo: +20 de vida máxima e +3 de defesa")
	check(character.health.current == character.health.max_health, "ganho de máximo enche junto")
	check_near(character.move_speed(), base_speed * 1.1, 0.01, "anel: +10% de velocidade")
	check_near(character.pickup_radius(), base_radius + 10.0, 0.01, "anel: ímã maior")
	check(character.stats.max_health == base_health, "o recurso compartilhado não mudou")
	EquipmentRules.click_slot(_inventory, _equipment, _equipment.index_of_type(EquipmentData.Slot.HEAD))
	character.apply_equipment(_equipment)
	check(character.health.max_health == base_health and character.health.current == base_health,
		"tirou o elmo: volta ao normal (sem passar do máximo)")


## Todo jogador começa com a espada vestida; sem arma, o golpe é o desarmado.
func test_weapon_defines_the_attack() -> void:
	var game := start_game()
	var player_id: int = game.local_player_id()
	var equipment := (game.session as GameSession).get_equipment(player_id)
	var inventory := (game.session as GameSession).get_inventory(player_id)
	var character := (game.session as GameSession).get_player_entity(player_id) as Character
	check(equipment.weapon() != null and equipment.weapon().id == &"sword", "começa com a espada")
	check(character.attacker.attack == equipment.weapon().attack, "golpe da espada")
	EquipmentRules.click_slot(inventory, equipment, equipment.index_of_type(EquipmentData.Slot.MAIN_HAND))
	check(inventory.held_item() == &"sword", "tirou a espada para a mão")
	check(character.attacker.attack == character.stats.unarmed_attack, "sem arma: soco")
	inventory.return_held()
	EquipmentRules.equip_from_inventory(inventory, equipment, 0)
	check(character.attacker.attack == equipment.weapon().attack, "vestiu de novo: espada")
