import argparse
import csv
import random
from datetime import datetime, timedelta

def aeroxenerador(id: str, hora: datetime):

    vento = random.randint(0, 30)

    dire = hora.minute + random.randint(-20, 20)
    if(dire < 0):
        dire = 360 - dire

    potencia = 0
    if vento < 3 | vento > 25:
        potencia = 0
    elif vento < 12:
        potencia = 333 * vento
    else:
        potencia = 3000 + random.randint(-40, 0)

    rotor = potencia / 187.5
    if rotor > 15.7:
        rotor = 16

    temp = potencia / 43
    
    return {
        "aeroxenerador_id" : id,
        "data_hora" : hora,
        "vento_ms" : vento,
        "direccion_graos" : dire,
        "potencia_kw": potencia,
        "rotor_rmp" : rotor,
        "temp_xerador_c" : temp,
        "estado" : "ok"
    }

for i in range(0, 20):
    print(aeroxenerador("1", datetime.now()))

#TODO
# lecturas dos 12 aeroxeradores durante os días que se indiquen (polo
# menos 7), que cumpren o contrato do apartado 2. Cunha semente, para que se poidan repetir.

#Campo Tipo Valores
#aeroxerador_id texto MB-01 a MB-12
#data_hora data e hora cada 10 minutos en punto (00:00, 00:10, 00:20…)
#vento_ms decimal, 1 decimal 0,0–30,0 m/s
#direccion_graos enteiro 0–359
#potencia_kw decimal, 1 decimal 0,0–3.000,0 kW
#rotor_rpm decimal, 1 decimal 0,0–16,0 rpm
#temp_xerador_c decimal, 1 decimal 10,0–90,0 °C
#estado texto ok, alarma ou parado

#Todos os campos son obrigatorios.

#2.2 Regras
#1. Cada aeroxerador envía unha lectura cada 10 minutos, sen ocos nin repeticións: 144 lecturas por aeroxerador e día.
#2. Potencia segundo o vento: 0 kW con vento menor de 3 m/s ou maior de 25 m/s; entre 3 e 12 m/s, a potencia sobe co vento; de 12 a 25 m/s, arredor dos 3.000 kW.
#3. Estado:
#– parado: potencia 0 kW e rotor 0 rpm;
#– alarma: o aeroxerador segue funcionando, pero avisa dun problema (por exemplo, temperatura alta). Arredor do 1 % das lecturas;
#– ok: o resto.
#4. O vento dun aeroxerador cambia pouco dunha lectura á seguinte, e os aeroxeradores do parque teñen ventos parecidos á mesma hora.
#A regra 4 non é obrigatoria, pero fai que os datos se parezan aos reais e que as consultas dean resultados con sentido.