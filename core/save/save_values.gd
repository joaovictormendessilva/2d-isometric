class_name SaveValues
extends RefCounted
## Leitura de valores do save (ADR-019). O arquivo é dado NÃO confiável (mexido à mão, versão
## antiga, corrompido): cada número passa por aqui antes de ser usado. O JSON devolve todo
## número como float; estas funções aceitam só números finitos dentro da faixa e devolvem
## `fallback` para qualquer outra coisa.


## Número inteiro (sem parte fracionária) entre `low` e `high`.
static func to_int(value: Variant, low: int, high: int, fallback: int) -> int:
	if not (value is float or value is int) or not is_finite(value) or value != floorf(value) \
			or value < low or value > high:
		return fallback
	return int(value)


## Número entre `low` e `high`.
static func to_float(value: Variant, low: float, high: float, fallback: float) -> float:
	if not (value is float or value is int) or not is_finite(value) or value < low or value > high:
		return fallback
	return float(value)
