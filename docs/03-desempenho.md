# Desempenho

Todas as metas abaixo são **hipóteses a validar**, não promessas.

## Hardware

- **Desenvolvimento (PC do João)**: Ryzen 5 5500, Radeon RX 6600, 16 GB DDR4 3200, SSD NVMe.
  É uma máquina intermediária — **não** serve sozinha como referência de "hardware modesto".
- **Referência "modesto" (alvo hipotético)**: CPU de 4 núcleos de ~2015–2017, GPU integrada
  (classe Intel UHD 620 / Vega 8), 8 GB de RAM, SSD ou HDD.
- Como testar sem essa máquina: renderizador Compatibility, limite de FPS, testes de estresse
  com orçamento de tempo por quadro bem abaixo do disponível no PC do João, e medição de
  memória. Se surgir acesso a uma máquina fraca real, ela vira a referência.

## Metas iniciais (hipóteses)

| Métrica | Meta no hardware modesto | Margem no PC de dev |
|---|---|---|
| FPS em combate normal | 60 estável | tempo de quadro < 4 ms |
| Pior caso (evento/chefe) | ≥ 45 | tempo de quadro < 8 ms |
| Memória do jogo | < 500 MB | — |
| Troca de região | < 1 s, sem travar o áudio | — |
| Salvamento | sem travada perceptível (< 1 quadro) | — |

## Estratégias planejadas

- Pooling de projéteis, números de dano e partículas.
- Limite global de partículas por nível de qualidade (baixo/médio/alto).
- Entidades distantes do jogador atualizam com menor frequência ou dormem.
- IA e busca de caminho em frequência reduzida (não a cada quadro).
- Efeitos com blend aditivo e shaders simples, em vez de pós-processamento.
- Medir com o profiler e os monitores da Godot antes de otimizar.

## Testes de estresse planejados

| Cena de teste | Parâmetros | Status |
|---|---|---|
| Muitos inimigos | 50 / 100 / 200 perseguindo | ⬜ |
| Muitos projéteis | 200 / 500 / 1000 | ⬜ |
| Partículas e auras | 10 / 30 / 60 auras ativas | ⬜ |
| Itens no chão | 200 / 500 | ⬜ |
| Coop | 2 / 4 jogadores na mesma região | ⬜ |

Os testes rodarão por linha de comando e registrarão resultados nesta tabela.
