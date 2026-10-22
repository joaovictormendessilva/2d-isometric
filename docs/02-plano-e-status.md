# Plano e status

Atualize este arquivo ao final de cada incremento.
Legenda: ✅ concluído e validado · 🟡 em andamento · ⬜ pendente

## Etapas

| Etapa | Descrição | Status |
|---|---|---|
| A | Escolher ambiente de vibe coding, engine e ferramentas | ✅ (ADR-001, ADR-002) |
| B | Configurar projeto, controle de versão e primeiro executável | 🟡 |
| C | Protótipo isométrico: movimentação, câmera, colisões, cenário (validar ADR-003/005/006/007) | ⬜ |
| D | Combate, vida, dano, primeiro inimigo, recompensas | ⬜ |
| D+ | **Teste de risco de rede cedo**: 2 instâncias locais trocando movimento e dano | ⬜ |
| E | Coleta, inventário, equipamentos, crafting | ⬜ |
| F | Região jogável com progressão, NPCs e mini boss | ⬜ |
| G | Efeitos mágicos, auras, buffs, debuffs, cosméticos | ⬜ |
| H | Testes de desempenho e riscos da arquitetura multiplayer | ⬜ |
| I | Primeiro coop LAN | ⬜ |
| J | Expansão: mapas, dungeons, chefes, montarias, eventos, progressão | ⬜ |

Reorganização em relação ao plano original: foi incluída a etapa **D+** (teste de rede
mínimo logo após o combate básico), para descobrir cedo problemas de autoridade e
sincronização antes que muitos sistemas dependam deles. Um efeito mágico simples pode
aparecer já na Etapa C/D para validar a técnica visual cedo.

## Etapa B — checklist

- [x] Repositório GitHub criado (`joaovictormendessilva/2d-isometric`)
- [x] Pacote de contexto (`CLAUDE.md`, `docs/`) criado
- [ ] Godot 4.7.2 instalada no PC do João
- [ ] Claude Code instalado e logado no VS Code (ou app desktop)
- [ ] Repositório clonado no PC e aberto no Claude Code
- [ ] Claude Code consegue executar a Godot pela linha de comando
- [ ] Projeto Godot criado (estrutura de pastas, renderizador Compatibility, pixel art)
- [ ] Primeira cena executável aberta pelo João com F5
- [ ] Primeiro commit do projeto Godot

## Funcionalidades

Nenhuma funcionalidade de jogo implementada ainda.

## Problemas conhecidos

Nenhum.

## Pendências de decisão

- Coop: jogadores em regiões diferentes ao mesmo tempo? (ADR-005, decidir até a Etapa H)
- Drops: regra padrão pessoal vs. compartilhado por tipo de item (decidir na Etapa D/E)
- Nome do jogo e identidade visual própria (paleta, tom) — decisão criativa do João
