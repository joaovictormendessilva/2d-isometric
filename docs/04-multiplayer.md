# Multiplayer

## Modelo

- **Host autoritativo** (listen server): um jogador hospeda; os outros se conectam.
  Single-player é o mesmo código com 1 jogador e sem rede.
- O cliente envia **intenções** (mover, mirar, atacar, usar habilidade, coletar, craftar).
  O host valida e aplica; o resultado (posições, vida, drops) é replicado.
- Transporte: **ENet** (UDP), embutido na Godot.

## LAN vs. online

| | LAN | Online |
|---|---|---|
| Conexão | IP local direto | Precisa atravessar roteadores (NAT) |
| Latência | ~1 ms | 20–200 ms, variável |
| Perda de pacotes | rara | comum |
| Custo | R$ 0 | R$ 0 com rede virtual entre amigos (ex.: Tailscale/ZeroTier) ou abertura de porta; servidores dedicados/serviços de relay podem custar |
| Exige | só a API de rede | predição/interpolação, tolerância a perda, reconexão robusta |

Começamos pela LAN. O código deve ser escrito sem supor latência zero (interpolação de
entidades remotas desde o início), para não quebrar quando formos para o online.

## Regras de jogo dependentes de jogadores

- Número de jogadores é parâmetro explícito (`player_count`) das fórmulas de escala.
- Fórmulas de vida/dano/quantidade de inimigos/recompensas ficam em `data/` (nada de
  multiplicadores soltos no código).
- Drops: padrão **pessoal** (cada jogador vê e coleta os seus), salvo itens explicitamente
  marcados como compartilhados. Regra final por tipo de item: a decidir.
- Inventário, progressão, equipamentos, habilidades, vida e dano: por jogador.

## Riscos a testar cedo (Etapa D+)

1. Duas instâncias locais da Godot conectadas: movimento replicado e suave.
2. Dano aplicado só pelo host, refletido no cliente.
3. Projéteis: quem cria, quem decide acerto, como aparece no cliente.
4. Desconexão do cliente sem travar o host.

## Plano de testes

| Teste | 1 jogador | 2 jogadores | 3–4 jogadores |
|---|---|---|---|
| Movimento e câmera | ⬜ | ⬜ | ⬜ |
| Combate e dano | ✅ testes automáticos | ⬜ | ⬜ |
| Drops pessoais | ✅ | ✅ simulado (2 jogadores na mesma sessão, sem rede) | ⬜ |
| Transição de região | ⬜ | ⬜ | ⬜ |
| Morte e respawn | ⬜ | ⬜ | ⬜ |
| Desconexão/reconexão | — | ⬜ | ⬜ |
| Salvamento | ⬜ | ⬜ | ⬜ |
