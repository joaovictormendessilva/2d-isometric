class_name VfxQuality
extends RefCounted
## Qualidade dos efeitos neste computador (ADR-028): o nível escolhido corta as partículas que cada
## efeito pede, e um teto soma as partículas vivas de todos os efeitos. Só apresentação: nada daqui
## muda regras nem passa pela rede. Um só por execução (`shared`); a escolha fica nas preferências.
##
## Todo emissor de partículas passa por `claim` antes de entrar na árvore.

signal changed

const DATA_PATH := "res://data/vfx/quality.tres"
const SETTINGS_SECTION := "graphics"
const SETTINGS_KEY := "effects_quality"
## `--quality=low|medium|high`: nível só desta execução (capturas e testes de desempenho).
const QUALITY_ARG := "--quality="

static var _shared: VfxQuality

var _levels: VfxQualityLevels = load(DATA_PATH)
var _index := 0
var _in_use := 0


static func shared() -> VfxQuality:
	if _shared == null:
		_shared = VfxQuality.new()
		_shared._index = _shared._clamped(UserSettings.get_value(SETTINGS_SECTION, SETTINGS_KEY,
			_shared._levels.default_level))
	return _shared


func level() -> VfxQualityLevel:
	return _levels.levels[_index]


func level_index() -> int:
	return _index


## Troca o nível. `remember`: grava nas preferências (falso para escolhas só desta execução).
func set_level(index: int, remember := true) -> void:
	index = _clamped(index)
	if remember:
		UserSettings.set_value(SETTINGS_SECTION, SETTINGS_KEY, index)
	if index != _index:
		_index = index
		changed.emit()


## Próximo nível, voltando ao mais leve depois do mais caprichado (tecla do painel de debug).
func cycle() -> void:
	set_level((_index + 1) % _levels.levels.size())


func apply_command_line(args: PackedStringArray) -> void:
	for arg in args:
		if arg.begins_with(QUALITY_ARG):
			var id := StringName(arg.trim_prefix(QUALITY_ARG))
			for index in _levels.levels.size():
				if _levels.levels[index].id == id:
					set_level(index, false)


## Partículas vivas agora, somando todos os efeitos (painel de debug e testes).
func in_use() -> int:
	return _in_use


## Quantas partículas um efeito ganha neste nível (pelo menos 1 se ele pediu alguma).
func scaled(requested: int) -> int:
	if requested <= 0:
		return 0
	return maxi(1, roundi(requested * level().particle_scale))


## Dá ao emissor a quantidade deste nível, cortada no que sobra do teto, e a conta enquanto ele
## estiver na árvore (sair e voltar, como numa troca de pai, conta certo). Falso se não sobrou
## nada: quem chamou não deve mostrar o emissor.
func claim(particles: CPUParticles2D, requested: int) -> bool:
	var amount := mini(scaled(requested), level().particle_budget - _in_use)
	if amount <= 0:
		return false
	particles.amount = amount
	particles.tree_entered.connect(func() -> void: _in_use += amount)
	particles.tree_exiting.connect(func() -> void: _in_use -= amount)
	if particles.is_inside_tree():
		_in_use += amount
	return true


func _clamped(index: int) -> int:
	return clampi(index, 0, _levels.levels.size() - 1)
