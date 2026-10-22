class_name PhysicsLayers
## Máscaras de bits das camadas de física (nomes em Project Settings > Layer Names > 2D Physics).
## Arquivos .tscn usam os números direto; no código, use sempre estas constantes.

const WORLD := 1 << 0  ## Terreno bloqueante e objetos fixos (árvores, pedras, prédios).
const ACTORS := 1 << 1  ## Personagens e criaturas.
