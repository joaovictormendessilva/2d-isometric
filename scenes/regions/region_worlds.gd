class_name RegionWorlds
extends Node
## Regiões carregadas neste computador (ADR-020). Cada uma fica num SubViewport próprio, com
## mundo (física e desenho) só dela: no host, várias podem estar ativas ao mesmo tempo, uma
## por região com jogador (coop), sem se enxergarem. O SubViewport nunca desenha sozinho: a
## janela passa a usar o mundo da região de quem joga aqui (`show_region`), então câmera,
## interface e textos do mundo continuam onde sempre estiveram. O nome de cada SubViewport é o
## id da região, para os caminhos dos nós serem iguais no host e nos clientes (rede).

## Regiões conhecidas (`data/regions/`). Ids vindos de rede ou save só servem para buscar aqui.
var catalog: DataCatalog

var _shown: Region


## Região já carregada com esse id (null se não estiver).
func get_region(region_id: StringName) -> Region:
	var world := get_node_or_null(NodePath(String(region_id)))
	return world.get_child(0) as Region if world and world.get_child_count() > 0 else null


func loaded() -> Array[Region]:
	var regions: Array[Region] = []
	for world in get_children():
		if not world.is_queued_for_deletion() and world.get_child_count() > 0:
			regions.append(world.get_child(0) as Region)
	return regions


## Carrega a região (se o id existir no catálogo e ela ainda não estiver carregada).
func load_region(region_id: StringName) -> Region:
	var loaded_region := get_region(region_id)
	if loaded_region:
		return loaded_region
	var data := catalog.get_entry(region_id) as RegionData
	if data == null:
		return null
	var world := SubViewport.new()
	world.name = String(region_id)
	world.render_target_update_mode = SubViewport.UPDATE_DISABLED
	world.size = Vector2i(2, 2)  # nunca desenha: a janela desenha o mundo dele
	world.disable_3d = true
	world.gui_disable_input = true
	add_child(world)
	var region: Region = data.scene.instantiate()
	world.add_child(region)
	return region


## Libera a região (com tudo o que está nela) na hora.
func unload(region: Region) -> void:
	if region == _shown:
		_shown = null
	var world := region.get_parent()
	remove_child(world)
	world.free()


## A janela deste computador passa a mostrar `region`.
func show_region(region: Region) -> void:
	_shown = region
	get_viewport().world_2d = region.get_world_2d()


func shown() -> Region:
	return _shown if is_instance_valid(_shown) else null
