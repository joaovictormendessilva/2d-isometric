class_name GatheringTexts
extends RefCounted
## Textos da coleta mostrados ao jogador (um lugar só para o aviso flutuante e o rótulo).


## Por que não dá para coletar; vazio se dá.
static func refusal(data: ResourceNodeData, check: GatheringRules.Check) -> String:
	match check:
		GatheringRules.Check.NEEDS_TOOL:
			return Texts.format(&"GATHER_NEEDS_TOOL", [data.min_tool_tier])
		GatheringRules.Check.NEEDS_LEVEL:
			return Texts.format(&"GATHER_NEEDS_LEVEL",
				[data.skill.get_display_name(), data.min_skill_level])
		GatheringRules.Check.INVENTORY_FULL:
			return Texts.get_text(&"GATHER_INVENTORY_FULL")
	return ""
