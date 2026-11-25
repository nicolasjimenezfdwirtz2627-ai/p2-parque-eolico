-- Creación do Keyspace con 3 réplicas (NetworkTopologyStrategy)
CREATE KEYSPACE IF NOT EXISTS parque_eolico
WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'datacenter1': 3
};

USE parque_eolico;

-- Consulta 1: As lecturas dun aeroxerador nun día, das máis recentes ás máis antigas.
CREATE TABLE IF NOT EXISTS lecturas_por_aeroxerador_dia (
    aeroxerador_id text,
    dia date,
    data_hora timestamp,
    vento_ms decimal,
    direccion_graos int,
    potencia_kw decimal,
    rotor_rpm decimal,
    temp_xerador_c decimal,
    estado text,
    PRIMARY KEY ((aeroxerador_id, dia), data_hora)
) WITH CLUSTERING ORDER BY (data_hora DESC);

-- Consulta 2: A enerxía producida por un aeroxerador nun día (suma da potencia × 10 minutos).
-- Nota: Gardamos data_hora e potencia_kw para que o script sume (potencia_kw * (10/60)) en kWh.
CREATE TABLE IF NOT EXISTS enerxia_por_aeroxerador_dia (
    aeroxerador_id text,
    dia date,
    data_hora timestamp,
    potencia_kw decimal,
    PRIMARY KEY ((aeroxerador_id, dia), data_hora)
);

-- Consulta 3: As alarmas dun día en todo o parque, en orde horaria.
-- Nota: Só se inserirán nesta táboa as lecturas con estado = 'alarma'.
CREATE TABLE IF NOT EXISTS alarmas_por_dia (
    dia date,
    data_hora timestamp,
    aeroxerador_id text,
    vento_ms decimal,
    potencia_kw decimal,
    temp_xerador_c decimal,
    estado text,
    PRIMARY KEY ((dia), data_hora, aeroxerador_id)
) WITH CLUSTERING ORDER BY (data_hora ASC, aeroxerador_id ASC);

-- Consulta 4: A última lectura de cada aeroxerador do parque, para o panel de control.
-- Nota: Ao ter só aeroxerador_id como clave primaria, cada nova lectura sobrescribe a anterior (UPSERT).
CREATE TABLE IF NOT EXISTS ultima_lectura_aeroxerador (
    aeroxerador_id text,
    data_hora timestamp,
    vento_ms decimal,
    direccion_graos int,
    potencia_kw decimal,
    rotor_rpm decimal,
    temp_xerador_c decimal,
    estado text,
    PRIMARY KEY (aeroxerador_id)
);