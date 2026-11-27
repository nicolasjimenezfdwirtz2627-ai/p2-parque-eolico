# p2-parque-eolico

## 1. Infraestrutura e arranque do clúster

### Estrutura do repositorio
- `compose.yaml`: definición dos 3 nodos de Cassandra (`cass1`, `cass2`, `cass3`) e do contedor cliente `app`.
- `cql/esquema.cql`: creación do *keyspace* `parque_eolico` (factor de replicación 3 en `dc1`) e das táboas.
- `src/`: scripts en Python e dependencias (`requirements.txt`).

### Arrancar o clúster de Cassandra
Para levantar os tres nodos en segundo plano (arrancan de xeito secuencial grazas aos *healthchecks*):
```bash
docker compose up -d