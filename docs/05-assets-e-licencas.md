# Assets, ferramentas e licenças

Regra: nada entra no jogo sem uma linha nesta tabela. "Gratuito para uso pessoal" **não**
basta — a licença precisa permitir **uso comercial**.

## Ferramentas

| Ferramenta | Uso | Licença | Custo | Comercial? |
|---|---|---|---|---|
| Godot 4.7.x (Standard) | Engine | MIT | R$ 0 | Sim (manter aviso de licença nos créditos) |
| VS Code | Editor | MIT (código) / licença Microsoft (build) | R$ 0 | Sim |
| Claude Code | Implementação | Incluído no Claude Pro do João | já pago | Sim |
| Git / GitHub | Versionamento | GPL (Git) / serviço gratuito | R$ 0 | Sim |
| Pixelorama | Pixel art (planejado) | MIT | R$ 0 | Sim |
| Ferramentas próprias (`tools/capture_frames.gd`, `art_check.gd`, `generate_ui_theme.gd`) e skills em `.claude/skills/` | Captura de animação, conferência de arte, tema da UI, guias de qualidade | Próprias do projeto | R$ 0 | Sim |

## Assets do jogo

| Asset | Origem | Autor | Licença | Atribuição exigida | Arquivo(s) |
|---|---|---|---|---|---|
| Arte provisória (tiles grama/terra/água, personagem, árvore, pedra, sombra, slime, gosma, rastro de espada, pontos de coleta e seus restos, ícones de itens e ferramentas, bancada, mercador, moeda, poção de vida, Rei Slime com coroa, sombra grande, núcleo do Rei Slime) | Gerada por código (`tools/generate_placeholder_art.gd`) | Claude (para o projeto) | Própria do projeto | Não | `assets/tilesets/placeholder/`, `assets/sprites/placeholder/` |
| Fonte pixel art m5x7 (textos do jogo, tamanho 16) | https://managore.itch.io/m5x7 (baixada 2026-10-22, SHA-256 em `assets/fonts/m5x7-LICENSE.txt`) | Daniel Linssen (managore) | CC0 1.0 (domínio público, uso comercial livre) | Não (o autor agradece crédito: incluir nos créditos) | `assets/fonts/m5x7.ttf` |

## Referências (não entram no jogo)

| Arquivo | O que é | Uso permitido |
|---|---|---|
| `docs/referencias/gf-1.png` | Captura de Grand Fantasia (anel de runas dourado, faíscas) | Só referência de sensação visual |
| `docs/referencias/gf-2.png` | Captura de Grand Fantasia (espadas flutuantes azuis) | Só referência de sensação visual |
| `docs/referencias/exemplo-de-personagens.png` | Exemplo de escala/estilo de personagens montados | Só referência de escala e estilo |

Nunca copiar, traçar ou reutilizar conteúdo dessas imagens no jogo.
