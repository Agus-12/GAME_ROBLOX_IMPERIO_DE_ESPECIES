#!/usr/bin/env python3
"""ETAPA 25 (v50): LA VISTA DEL MUNDO — el mapa que se manda en cada entrega.

El usuario pidio: "mandame la vista del lote... y si puedes reconstruir literal
todo estaria mejor, lo del lote y los lotes vecinales... tambien la ciudad".

Aqui se comprueba que el mapa del mundo (tools/mapa.py) se puede armar de verdad y
que trae lo que debe traer:
  - las CUATRO vistas (mundo, los 20 lotes, tu lote de arriba, las dos fachadas),
  - la ciudad con sus calles y sus tiendas,
  - los 20 lotes de jugador,
  - tu lote con las piezas del arreglo de esta ronda: los rieles del porton, la
    plaquita de la caja fuerte y la del monitor (los carteles que antes quedaban
    tapados),
  - y el punto donde nace la bici, que tiene que caer FUERA del terreno (12 studs
    mas alla de la orilla del patio).
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
SALIDA = "/tmp/mapa-etapa25.svg"

print("=== 25. LA VISTA DEL MUNDO: la ciudad, los 20 lotes, tu lote y las fachadas (v50) ===")

r = subprocess.run([sys.executable, os.path.join(HERE, "mapa.py"), SALIDA],
                   capture_output=True, text=True, cwd=ROOT, timeout=900)
salida = r.stdout + r.stderr
m = re.search(r"__MAPA__ (.+)", salida)
fallas = 0


def kv(txt):
    return dict(p.split("=", 1) for p in txt.replace("|", " ").split() if "=" in p)


if not m:
    fallas += 1
    print("  FALLA  no se pudo armar el mapa del mundo")
    for x in salida.strip().splitlines()[-6:]:
        print("         | " + x[:160])
else:
    e = kv(m.group(1))
    print("  medidas: " + m.group(1))
    problemas = []
    if int(e.get("vistas", 0)) != 4:
        problemas.append("el mapa no trae las 4 vistas (trae %s)" % e.get("vistas"))
    if int(e.get("lotes", 0)) != 20:
        problemas.append("no estan los 20 lotes de jugador (dice %s)" % e.get("lotes"))
    if int(e.get("ciudad", 0)) < 10000:
        problemas.append("la ciudad salio casi vacia (%s piezas)" % e.get("ciudad"))
    if int(e.get("lote", 0)) < 400:
        problemas.append("tu lote salio incompleto (%s piezas)" % e.get("lote"))
    if int(e.get("rieles", 0)) < 2:
        problemas.append("el porton no trae sus 2 rieles en el mapa: %s" % e.get("rieles"))
    placas = (e.get("placas") or "").split(",")
    for p in ("VaultLabel", "MonitorLabel"):
        if p not in placas:
            problemas.append("falta la plaquita %s (el cartel que quedaba tapado)" % p)
    # la bici: el mapa tiene que dibujarla con el MISMO numero que usa el juego
    # (Main.luau), no con uno escrito a mano en el mapa
    try:
        fuera = float(e["bici_z"]) - float(e["orilla"])
        if abs(fuera - 12.0) > 0.6:
            problemas.append("la bici del mapa no esta a 12 studs de la orilla (%.1f): "
                             "el mapa y el juego no dicen lo mismo" % fuera)
    except Exception:
        problemas.append("no se pudo medir la bici en el mapa")
    if not os.path.exists(SALIDA) or os.path.getsize(SALIDA) < 200000:
        problemas.append("el SVG del mapa salio vacio o incompleto")
    else:
        svg = open(SALIDA, encoding="utf-8").read()
        for debe in ("EL MUNDO COMPLETO", "LOS 20 LOTES", "TU LOTE (el 1) DE ARRIBA",
                     "LAS DOS FACHADAS"):
            if debe not in svg:
                problemas.append("al mapa le falta la vista '%s'" % debe)
        if "#ffffff" in svg:
            problemas.append("hay piezas pintadas en blanco puro: el mapa sale manchado")
    if problemas:
        fallas += 1
        print("  FALLA  (el mapa del mundo)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el mapa trae las 4 vistas (la ciudad con sus calles y tiendas, los "
              "20 lotes, tu lote con sus rieles/placas y las dos fachadas), y la bici cae "
              "12 studs fuera del terreno")

if fallas:
    print("\nFALLA: la vista del mundo no se pudo armar (%d problema(s))" % fallas)
    sys.exit(1)
print("\nOK: la vista del mundo se arma y trae todo lo de la ronda")
