CREATE KEYSPACE IF NOT EXISTS parque_eolico
WITH replication = {
  'class': 'NetworkTopologyStrategy',
  'dc1': 3
};