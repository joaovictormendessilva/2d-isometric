# Visão do jogo

> Texto do diretor criativo (João), organizado por seções. É a fonte de verdade da intenção do
> projeto. Alterações aqui só com aprovação do João.

## Visão

RPG de ação em fantasia, isométrico em pixel art, inspirado na liberdade de exploração e coleta
de **Forager**, na variedade de combate e progressão de **Terraria** e nos efeitos mágicos e
cosméticos de **Grand Fantasia**.

É uma realização pessoal importante: o João quer efetivamente construir e jogar o próprio jogo.
O trabalho é por **vibe coding**: o João descreve ideias, decisões criativas, problemas e
resultados desejados; o Claude transforma isso em sistemas implementados, integrados, testados
e documentados. O João quer acompanhar o código e entender as decisões importantes, mas a
responsabilidade de escrever e integrar a maior parte do código é do Claude.

Orçamento inicial **R$ 0**: priorizar ferramentas gratuitas, sem aceitar limitações
desnecessárias antes de investigar alternativas.

## Conceito

RPG de ação com exploração, combate, coleta, crafting, equipamentos, habilidades, monstros,
mapas, dungeons, chefes, NPCs, montarias e progressão contínua. Início single-player, com
arquitetura que considera cooperação multiplayer desde o começo.

As referências são de **intenção** — não autorizam copiar personagens, sprites, nomes, músicas,
identidade visual ou conteúdo protegido. O jogo deve ter identidade própria.

## Arte isométrica e pixel art

Objetivos: (1) identidade visual de fantasia atraente com efeitos mágicos marcantes;
(2) projeto viável, leve e fluido em computadores modestos.
**Não** queremos um jogo visualmente pobre por ser leve.

- Cenários isométricos com mais detalhe que pixel art extremamente minimalista.
- Tilesets, personagens, criaturas, vegetação, construções e objetos com linguagem coerente.
- Silhuetas claras, leitura fácil em combate.
- Paletas controladas; animações enxutas; reutilização de componentes.
- Luz e magia que deem sensação de riqueza sem desperdiçar recursos.
- Separação visual clara entre personagens, cenário, projéteis, inimigos e efeitos.
- Qualidade de efeitos escalável conforme o hardware.
- Resolução interna, tamanho de sprite e de tile **não** escolhidos arbitrariamente: propor,
  explicar e validar em protótipo visual.
- Implementar corretamente movimentação, ordenação de profundidade, colisões, navegação,
  perspectiva e interação isométricas. Visual isométrico não implica lógica toda em
  coordenadas isométricas.

## Desempenho (requisito central)

Rodar fluido em hardware modesto, com acessibilidade comparável em espírito à de Terraria —
sem prometer equivalência antes de testar. 2D e mundo dividido em mapas são decisões
deliberadas de desempenho e escopo.

Pixel art não garante desempenho: muitos inimigos, partículas, colisões, efeitos, scripts,
iluminação e rede podem gerar gargalos. Considerar: CPU e memória moderadas, número de
entidades, reutilização de objetos, renderização eficiente de tiles/sprites, limites de
partículas, custo previsível de animações/efeitos, colisões e navegação eficientes, distância de
atualização, frequência dos sistemas, carregamento/descarregamento, salvamento sem travadas,
custo de multiplayer, redução de efeitos em máquinas fracas.

Evitar otimização prematura, mas também decisões estruturais com gargalos previsíveis.
Metas iniciais são **hipóteses a validar**. Criar testes de estresse progressivos e usar
profiling em vez de adivinhar.

## Mapas, conexões e carregamento

Mundo = regiões conectadas por passagens nas extremidades, caminhos, entradas de dungeon e
portais desbloqueáveis. A estrutura deve: dar identidade às regiões, controlar entidades
ativas, facilitar carregar/descarregar/salvar, permitir expansão gradual, simplificar navegação
e depuração, facilitar encontros/eventos/chefes, permitir balanceamento por região, ter
transições coerentes e ser compatível com coop.

Não carregar o mundo inteiro. Definir o que fica ativo, o que é salvo e o que é reconstruído.
Considerar mapas persistentes, instanciados e dungeons temporárias, sem complexidade antes da
necessidade. **Começar com uma única região funcional.**

## Auras, magias e efeitos visuais (pilar da identidade)

Auras em loop, brilhos, pulsação, partículas, runas, rastros, contornos luminosos e efeitos em
equipamentos, personagens, monstros, buffs, debuffs e cosméticos — a sensação dos cosméticos de
Grand Fantasia reinterpretada em pixel art com identidade própria (ver `docs/referencias/`).

Não depender só de sprites grandes desenhados à mão. Investigar camadas de sprites, partículas
procedurais, shaders, paletas configuráveis, máscaras e contornos luminosos, pulsação, animações
cíclicas, composição de efeitos e iluminação adequada à pixel art.

Arquitetura de efeitos reutilizável, parametrizada (cor, intensidade, duração, velocidade…),
com níveis de qualidade e limites de partículas. Efeitos marcantes **sem** comprometer a
leitura de ataques, telegráficos de chefes e visibilidade dos jogadores.

## Personagens, criaturas e assets

O João não é artista. Pipeline de arte acessível com ferramentas gratuitas e recursos criados,
editados, gerados proceduralmente ou reutilizados legalmente. Considerar ferramentas gratuitas
de pixel art, assets com licença adequada, formas e efeitos procedurais, componentes
reutilizáveis, variações de paleta/acessórios/equipamentos, reutilização de esqueletos e
animações, placeholders para validar mecânicas.

Placeholders não justificam abandonar a identidade visual: planejar substituição por arte
própria ou licenciada. Imagem conceitual gerada ≠ sprite animável, tileset consistente ou asset
pronto.

## Combate e liberdade de builds

Sem classe fixa: o personagem troca armas, equipamentos e estilos livremente. Possíveis
elementos: melee, arcos e projéteis, magias direcionadas e skillshots, áreas, buffs e debuffs,
escudos, cura, mobilidade, controle, dano contínuo, resistências e vulnerabilidades, páginas de
habilidades e atributos, sinergias entre armas, equipamentos, habilidades e elementos.

Habilidades com identidade própria sobre sistemas genéricos configuráveis. Parâmetros
explícitos (dano, alcance, recarga, mana, duração, área, velocidade de projétil, resistência…)
alteráveis sem espalhar números pelo código.

## Progressão, grind, crafting e economia

Grind focado em materiais e fabricação, sem repetição excessiva. Itens podem exigir recursos de
regiões específicas, drops de monstros e chefes, componentes intermediários, receitas, moedas e
recursos especiais, requisitos de progressão ou exploração. **Cada sessão de coleta deve
contribuir para uma conquista.**

NPCs podem vender itens, feitiços, receitas, poções de vida e mana, consumíveis de agilidade,
montarias etc. Tabelas de dados configuráveis para receitas, itens, atributos, custos,
raridades e recompensas. Balanceamento iterativo.

## Monstros, mini bosses, bosses e eventos

Monstros comuns com comportamentos simples e reutilizáveis (perseguir, atacar, atirar, defender
área, fugir). Mini bosses e bosses com múltiplos ataques, fases, padrões, telegráficos,
resistências e mecânicas especiais. O desafio não cresce só por vida e dano.

Uma build extremamente poderosa **não** deve derreter todos os chefes finais. Investigar
resistências, limites de multiplicadores, retornos decrescentes, mecânicas que exigem
movimento ou preparação, janelas de oportunidade, sinergias que recompensem builds diferentes
e testes automatizáveis de dano, sobrevivência e duração de combate. Sem build obrigatória:
várias combinações viáveis, algumas especialmente eficientes em certas situações.

Eventos de chefes em momentos aleatórios, sem horários fixos, funcionando em single-player e
em multiplayer.

## Montarias e exploração

Montarias com utilidade real: velocidade adicional moderada, mobilidade, benefícios de
exploração, interação com terrenos, coleta ou habilidades. Viagens entre regiões devem dar
sentido às montarias sem virar tarefa tediosa. Deslocamento por caminhos, passagens, atalhos
desbloqueáveis e portais.

## Multiplayer (planejado desde o início)

Single-player primeiro, sem arquitetura que torne o coop uma reescrita. Coop LAN como meta;
online avaliado depois. LAN e online **não** são equivalentes.

Desde os primeiros sistemas: IDs de jogadores e entidades, lógica separada da apresentação,
nenhum jogador global implícito. Prever: inventário, progressão, equipamentos, habilidades,
vida e dano por jogador; monstros e chefes compartilhados conforme regras; drops pessoais ou
compartilhados definidos explicitamente (drops individuais considerados desde o início); morte,
respawn e reconexão; eventos e transições entre mapas; sincronização de projéteis, habilidades,
efeitos e animações relevantes; salvamento e persistência; desconexões; proteção básica contra
alteração de dano e recompensas.

Número de jogadores é **parâmetro explícito**. Fórmulas configuráveis para escalar vida, dano,
quantidade de inimigos e recompensas. Testes com 1, 2 e mais jogadores. Não implementar toda a
infraestrutura de rede de uma vez, mas testar cedo as decisões que evitam retrabalho.

## Organização e documentação

Manter: visão, plano, registro de decisões, funcionalidades concluídas/pendentes, problemas
conhecidos, catálogo de assets e licenças, tabelas de itens/habilidades/receitas/monstros,
fórmulas de balanceamento, testes de desempenho, plano de testes multiplayer. Controle de
versão com Git; ponto de restauração antes de mudanças grandes; nunca apagar trabalho sem
autorização.

## Critérios de sucesso do primeiro protótipo

Uma pequena experiência própria com:
- Cenário isométrico funcional.
- Personagem controlável.
- Um inimigo com comportamento e combate.
- Uma arma e uma habilidade.
- Coleta e crafting simples.
- Um efeito mágico visualmente marcante.
- Desempenho satisfatório no hardware de referência.
- Estrutura expansível.
- Decisões documentadas para permitir coop.
- Fluxo de vibe coding funcionando: o João pede mudanças e avalia resultados.

## Filosofia geral

Não sacrificar efeitos visuais pelo desempenho: descobrir quais técnicas produzem o resultado
desejado com o menor custo computacional e validá-las no protótipo. A mesma filosofia vale
para o coop e para todas as outras funcionalidades.
