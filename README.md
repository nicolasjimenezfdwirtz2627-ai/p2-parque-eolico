# p2-parque-eolico

## 4.1 Modelo de datos: Xustificación e tipos CQL

### Paso do contrato de datos a tipos de CQL

Para transformar o contrato de datos do sistema SCADA ás táboas de Cassandra, escolléronse os tipos de CQL que mellor se axustan ao dominio e precisión de cada variable:

| Campo no contrato | Tipo no contrato | Tipo en CQL | Xustificación da elección |
| :--- | :--- | :--- | :--- |
| `aeroxerador_id` | texto (`MB-01` a `MB-12`) | `text` | Identificador alfanumérico de lonxitude variable (permite escalar a outros parques con distintos códigos sen cambiar o esquema). |
| `data_hora` | data e hora | `timestamp` | Almacena a marca temporal exacta (con precisión de milisegundos) e permite ordenar cronoloxicamente as lecturas de forma nativa. |
| `dia` *(campo derivado)* | data (`YYYY-MM-DD`) | `date` | Extráese de `data_hora` (formato ISO sen hora) para usalo como parte da clave de partición e evitar particións infinitas. |
| `vento_ms` | decimal, 1 decimal | `decimal` | Representa números decimais de precisión arbitraria, evitando os erros de redondeo típicos dos tipos de coma flotante (`float`/`double`). |
| `direccion_graos` | enteiro (`0-359`) | `int` | Enteiro de 32 bits con signo, máis que suficiente para almacenar valores entre 0 e 359 graos. |
| `potencia_kw` | decimal, 1 decimal | `decimal` | Garante precisión exacta nas cifras de potencia para que os cálculos de enerxía acumulada sexan rigorosos. |
| `rotor_rpm` | decimal, 1 decimal | `decimal` | Mantén a precisión exacta dun decimal esixida polo contrato para as revolucións por minuto. |
| `temp_xerador_c` | decimal, 1 decimal | `decimal` | Permite rexistrar a temperatura do xerador coa décima de grao exacta sen perda de precisión. |
| `estado` | texto (`ok`, `alarma`, `parado`) | `text` | Cadea de texto curta para os estados operativos definidos polo sistema SCADA. |

---

### Xustificación das claves de partición, columnas de agrupación e tamaño ao cabo dun ano

O deseño segue o enfoque *query-driven* (unha táboa por consulta) e garante que **ningunha partición medre sen límite** co paso do tempo (*unbounded partitions*).

#### 1. Táboa `lecturas_por_aeroxerador_dia` (Consulta 1: lecturas dun aeroxerador nun día, das máis recentes ás máis antigas)
* **Clave de partición (`PARTITION KEY`):** `(aeroxerador_id, dia)`
  * **Xustificación:** A consulta filtra por un aeroxerador concreto e un día determinado (`WHERE aeroxerador_id = ? AND dia = ?`). Ao combinar ambos os campos nunha clave de partición composta, todas as lecturas dese día para esa máquina gárdanse xuntas nun mesmo nodo, permitindo lelas nunha única operación de disco sen percorrer o clúster. Ademais, repartir por día evita que a partición dun aeroxerador medre indefinidamente.
* **Columnas de agrupación (`CLUSTERING COLUMNS`):** `data_hora` con `CLUSTERING ORDER BY (data_hora DESC)`
  * **Xustificación:** Dentro de cada partición (aeroxerador + día), `data_hora` identifica de xeito único cada lectura e ordénaas fisicamente en disco de maior a menor (`DESC`). Deste xeito, a consulta devolve as lecturas da máis recente á máis antiga directamente, sen necesidade de ordenación en memoria.
* **Cálculo de filas por partición ao cabo dun ano:**
  * Cada aeroxerador envía 1 lectura cada 10 minutos: $6 \text{ lecturas/hora} \times 24 \text{ horas} = \mathbf{144 \text{ filas/día}}$.
  * Como o `dia` forma parte da clave de partición, **unha partición nunca supera as 144 filas** (ao cabo dun ano xéranse $12 \times 365 = 4.380$ particións independentes, pero cada unha segue tendo un máximo estrito de **144 filas**).

#### 2. Táboa `enerxia_por_aeroxerador_dia` (Consulta 2: enerxía producida por un aeroxerador nun día)
* **Clave de partición (`PARTITION KEY`):** `(aeroxerador_id, dia)`
  * **Xustificación:** Igual que na táboa anterior, a consulta necesita acceder a todos os rexistros dun aeroxerador nun día concreto para sumar a súa potencia. Esta clave agrupa os datos nun único nodo e acouta o tamaño da partición a 24 horas. Gardamos unicamente `potencia_kw` (sen os demais sensores) para minimizar a lectura de disco e o tráfico de rede ao calcular o total diario.
* **Columnas de agrupación (`CLUSTERING COLUMNS`):** `data_hora`
  * **Xustificación:** É necesaria para que cada lectura de 10 minutos sexa unha fila distinta dentro da partición e non se sobrescriban as potencias das distintas horas do día.
* **Cálculo de filas por partición ao cabo dun ano:**
  * Exactamente igual que no caso anterior: **144 filas por partición como máximo**, independentemente de cantos anos pasen.

#### 3. Táboa `alarmas_por_dia` (Consulta 3: alarmas dun día en todo o parque, en orde horaria)
* **Clave de partición (`PARTITION KEY`):** `(dia)`
  * **Xustificación:** A consulta pide todas as incidencias do parque completo para unha data concreta (`WHERE dia = ?`), sen filtrar por aeroxerador. Usar `dia` como clave de partición permite recuperar nunha soa consulta todas as alarmas dese día.
* **Columnas de agrupación (`CLUSTERING COLUMNS`):** `data_hora, aeroxerador_id` con `CLUSTERING ORDER BY (data_hora ASC, aeroxerador_id ASC)`
  * **Xustificación:** `data_hora` en orde ascendente (`ASC`) almacena as alarmas en orde horaria (das primeiras do día ás últimas). Engádese `aeroxerador_id` como segunda columna de agrupación para garantir a unicidade da clave primaria: se dous aeroxeradores distintas entran en alarma no mesmo intervalo de 10 minutos, non se sobrescriben entre si.
* **Cálculo de filas por partición ao cabo dun ano:**
  * O parque ten 12 aeroxeradores que xeran $12 \times 144 = 1.728$ lecturas totais ao día.
  * Segundo o contrato, as alarmas son arredor do 1% das lecturas: $1.728 \times 0,01 \approx \mathbf{17 \text{ filas/día}}$ de media.
  * Incluso no peor escenario posible (que os 12 aeroxeradores estivesen en alarma durante as 24 horas), **o límite máximo absoluto é de 1.728 filas por partición** (ao cabo dun ano hai 365 particións, pero ningunha pasa dese tope diario).

#### 4. Táboa `ultima_lectura_aeroxerador` (Consulta 4: última lectura de cada aeroxerador para o panel de control)
* **Clave de partición (`PARTITION KEY`):** `(aeroxerador_id)`
  * **Xustificación:** O panel de control amosa o estado actual de cada aeroxerador. Ao usar só `aeroxerador_id` como clave primaria (sen `dia` nin `data_hora`), cada nova lectura que chega executa un *UPSERT* (actualización) sobre a fila existente dese aeroxerador, mantendo sempre a máis recente dispoñible de forma inmediata.
* **Columnas de agrupación (`CLUSTERING COLUMNS`):** *Ningunha*
  * **Xustificación:** Non queremos almacenar historial nesta táboa, só a fotografía actual de cada máquina, polo que non se precisan columnas de agrupación.
* **Cálculo de filas por partición ao cabo dun ano:**
  * **1 fila por partición** (12 particións en total no clúster, unha por cada aeroxerador de `MB-01` a `MB-12`). Este tamaño mantense constante en 1 fila por partición ao cabo dun día, dun ano ou de dez anos.
```[cite: 1, 2, 3, 4]