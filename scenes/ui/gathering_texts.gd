class_name GatheringTexts
extends RefCounted
## Textos da coleta mostrados ao jogador (um lugar só para o aviso flutuante e o rótulo).


## Por que não dá para coletar; vazio se dá.
static func refusal(data: ResourceNodeData, check: GatheringRules.Check) -> String:
	match check:
		GatheringRules.Check.NEEDS_TOOL:
			return "Precisa de ferramenta nível %d" % data.min_tool_tier
		GatheringRules.Check.NEEDS_LEVEL:
			return "Precisa de %s nível %d" % [data.skill.display_name, data.min_skill_level]
	return ""
