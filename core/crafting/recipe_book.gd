class_name RecipeBook
extends RefCounted
## Receitas que UM jogador aprendeu (F3c, ADR-023): as marcadas `must_learn` só se fabricam
## depois de aprendidas (compradas de um NPC); as outras todo mundo sabe. Aprendida, fica para
## sempre com o personagem (vai no save). Só o host altera (`learn`); na rede, o dono recebe o
## que aprendeu (`replicate`). Mesmo padrão da Wallet e do SkillProgress.

## Uma receita entrou no livro. `is_new`: aprendida agora (aviso "Receita aprendida"), e não
## vinda do save ou do estado completo enviado ao entrar.
signal learned(recipe_id: StringName, is_new: bool)

var _known: Dictionary[StringName, bool] = {}


## Pode fabricar `recipe` (quanto a saber a receita; lugar e ingredientes à parte)?
func knows(recipe: RecipeData) -> bool:
	return not recipe.must_learn or _known.has(recipe.id)


## Ids aprendidos (save do mundo), em ordem estável.
func all_learned() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_known.keys())
	ids.sort()
	return ids


## Host: aprende `recipe`. Falso se não precisa aprender ou já sabia (nada muda).
func learn(recipe: RecipeData) -> bool:
	return _add(recipe, true)


## Cliente (o host avisou; `is_new` vem com o aviso) e host ao carregar o save
## (CharacterRecord). Mesmas regras do `learn`.
func replicate(recipe: RecipeData, is_new: bool = false) -> void:
	_add(recipe, is_new)


func _add(recipe: RecipeData, is_new: bool) -> bool:
	if knows(recipe):
		return false
	_known[recipe.id] = true
	learned.emit(recipe.id, is_new)
	return true
