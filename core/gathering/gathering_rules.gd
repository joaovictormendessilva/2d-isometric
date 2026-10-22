class_name GatheringRules
extends RefCounted
## Fórmulas da coleta (sem nós nem estado): o que o jogador pode coletar, quanto tempo leva e
## quanto rende. Usadas pelo host para decidir e por todos para mostrar.

enum Check { OK, NEEDS_TOOL, NEEDS_LEVEL, INVENTORY_FULL }


## Melhor ferramenta do tipo do ponto entre as que o jogador tem (null = mãos).
static func best_tool(node: ResourceNodeData, tools: Array[ToolData]) -> ToolData:
	var best: ToolData
	for tool in tools:
		if tool.skill == node.skill and (best == null or tool.tier > best.tier \
				or (tool.tier == best.tier and tool.speed > best.speed)):
			best = tool
	return best


static func check(node: ResourceNodeData, skill_level: int, tool: ToolData) -> Check:
	var tool_tier := tool.tier if tool else 0
	if tool_tier < node.min_tool_tier:
		return Check.NEEDS_TOOL
	if skill_level < node.min_skill_level:
		return Check.NEEDS_LEVEL
	return Check.OK


## Segundos de uma coleta: mais rápida com ferramenta melhor e com nível maior.
static func gather_duration(node: ResourceNodeData, skill_level: int, tool: ToolData,
		balance: GatheringBalance) -> float:
	var speed := tool.speed if tool else balance.hands_speed
	speed *= 1.0 + node.skill.speed_bonus_per_level * (skill_level - 1)
	return node.gather_time / speed


## O máximo que uma coleta pode render (todas as chances saindo, com o bônus de nível): o
## inventário precisa ter espaço para isso antes de coletar.
static func max_yield(node: ResourceNodeData, skill_level: int) -> Dictionary[StringName, int]:
	var bonus := 1 if node.skill.bonus_yield_chance_per_level * (skill_level - 1) > 0.0 else 0
	var result: Dictionary[StringName, int] = {}
	for entry in node.yields:
		result[entry.item.id] = result.get(entry.item.id, 0) + entry.max_amount + bonus
	return result


## Itens de uma coleta: a tabela do ponto (com chances) e, pelo nível, chance de +1 em cada
## item que saiu.
static func roll_yield(node: ResourceNodeData, skill_level: int,
		rng: RandomNumberGenerator) -> Dictionary[StringName, int]:
	var bonus_chance := node.skill.bonus_yield_chance_per_level * (skill_level - 1)
	var result: Dictionary[StringName, int] = {}
	for entry in node.yields:
		var amount := entry.roll(rng)
		if amount <= 0:
			continue
		if rng.randf() < bonus_chance:
			amount += 1
		result[entry.item.id] = result.get(entry.item.id, 0) + amount
	return result
