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

## Como funciona hoje (Etapa D+, ADR-012)

- Host decide tudo o que é regra; cada jogador simula o próprio movimento e o host valida.
- Entidades remotas aparecem interpoladas (0,1 s no passado), 20 estados por segundo.
- Criação/remoção pelo `MultiplayerSpawner`; eventos e estados por entidade no `NetSync`.
- Segurança: ADR-013 (porta só quando pedida, aperto de mão, sem repasse entre clientes,
  validação de tudo o que chega).

Testar no PC (duas janelas): dê dois cliques em `tools/coop-local.bat`. Pela linha de
comando: `Godot --path . -- --host` e `Godot --path . -- --join=127.0.0.1`.

## Riscos testados cedo (Etapa D+)

1. ✅ Duas instâncias conectadas: movimento replicado e suave (validado pelo João; teste mede o passo
   por quadro).
2. ✅ Dano aplicado só pelo host, refletido no cliente (nos dois sentidos).
3. ⬜ Projéteis: ainda não existem; o desenho previsto é o mesmo dos ataques (o dono pede,
   o host decide o acerto e cria/remove o projétil pelo Replicator).
4. ✅ Desconexão do cliente sem travar o host, e do host sem travar o cliente.

## Limitações conhecidas

- Acerto decidido com posições ~0,1 s atrasadas do outro lado: ok no LAN; o online pede
  compensação de atraso.
- O host valida velocidade, não paredes: um cliente adulterado poderia atravessar árvores.
- Vida das criaturas não é recalculada quando alguém entra no meio da luta.
- Sem identidade persistente: quem sai e volta é um jogador novo (inventário vazio).
- Tráfego ~0,9 KB/s por entidade por cliente: muitas criaturas online pedem agrupamento.

## Plano de testes

| Teste | 1 jogador | 2 jogadores | 3–4 jogadores |
|---|---|---|---|
| Movimento e câmera | ✅ | ✅ automático (2 instâncias no mesmo processo) | ⬜ |
| Combate e dano | ✅ testes automáticos | ✅ automático (host decide, cliente vê) | ⬜ |
| Drops pessoais | ✅ | ✅ automático em rede (só o dono vê e coleta) | ⬜ |
| Transição de região | ⬜ | ⬜ | ⬜ |
| Morte e respawn | ✅ | ✅ automático (host ordena, cliente renasce) | ⬜ |
| Inventário | ✅ | ✅ automático (host decide; pedidos adulterados recusados) | ⬜ |
| Coleta | ✅ | ✅ automático (host decide; pedidos adulterados recusados; entrada no meio) | ⬜ |
| Desconexão/reconexão | — | ✅ desconexão (host e cliente); reconexão ⬜ | ⬜ |
| Salvamento | ⬜ | ⬜ | ⬜ |
