class_name FrameStats
extends RefCounted
## Mede tempos de quadro para benchmarks. Rode a Godot com `--fixed-fps 60`: cada quadro
## executa exatamente um passo de física e não espera o relógio, então o tempo medido é o
## custo real de um quadro de jogo (lógica + física + desenho).

var _samples := PackedFloat32Array()
var _last_usec := 0


## Chame uma vez por quadro (depois de `await process_frame`).
func tick(record: bool = true) -> void:
	var now := Time.get_ticks_usec()
	if record and _last_usec > 0:
		_samples.append((now - _last_usec) / 1000.0)
	_last_usec = now


func summary() -> String:
	var sorted := _samples.duplicate()
	sorted.sort()
	var total := 0.0
	for s in sorted:
		total += s
	var avg := total / maxi(sorted.size(), 1)
	return "média %.3f ms (%.0f FPS) | p99 %.3f ms | pior %.3f ms" % [
		avg, 1000.0 / avg, _percentile(sorted, 0.99), sorted[-1]]


func _percentile(sorted: PackedFloat32Array, fraction: float) -> float:
	return sorted[mini(int(sorted.size() * fraction), sorted.size() - 1)]
