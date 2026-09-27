#!/usr/bin/env python3
"""AL REVES (v51/v52): cada bug de esta ronda tiene que TRONAR la etapa 26.

La regla del proyecto es no confiar en un chequeo que nunca se vio fallar.
Aqui se mete el bug DE VERDAD en el archivo real (Main.luau o CityGenerator.luau),
se corre la etapa 26 y se comprueba que truene; luego se deja todo como estaba.

Bugs que se prueban:
  1. la van sale con la altura fija de antes (2.05): queda 1 stud arriba del piso
     del patio (era "la van al spawnearla afuera sale mal")
  2. el cajon se queda sin su patio (BayApron): la van vuelve a salir sobre el pasto
  3. la calle de hilera donde la ponia la v51 (+71): queda DEBAJO de los patios de
     las bodegas nivel 2-4 ("la bodega de en medio esta como al ras de la calle")
  4. se pierde una rampa de entrada (el bucle se corta antes)
  5. los caminos norte-sur dejan de existir
  6. el camino principal pegado a la linea de lotes (la v51): toca las paredes de
     las bodegas nivel 4, que no estan centradas en su lote
  7. (v53) se quita el re-sellado de HomeCF: el porton del cajon vuelve a
     "cerrarse" hacia las coordenadas del template y se vuela al origen del
     mundo (el "porton que nunca aparece", reportado desde la v44)
  8. (v53) se apaga la adopcion de movimientos externos del bucle de manejo:
     el boton "Auto" vuelve a pelear con el PivotTo y el carro regresa a la
     bodega ("la van con las piezas una arriba de la otra")
  9. (v53) el camino de en medio vuelve a quedarse corto (no toca la ciudad):
     los lotes del lado oriente sin salida directa

NOTA: los casos 1-5 se recuperaron cortados del chat anterior y se conservan
(los textos de ancla de 1, 2, 4 y 5 son los originales). El caso 3 se ajusto a
la v52 (la formula ahora suma +121; el bug lo regresa a +71, que era el error
real de la v51) y el 6 es nuevo de la v52. Los 7, 8 y 9 son de la v53.
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MAIN = os.path.join(ROOT, "ServerScriptService/Main.luau")
CITY = os.path.join(ROOT, "ServerScriptService/CityGenerator.luau")

print("=== AL REVES (v53): cada bug reportado tiene que tronar las etapas ===")

CASOS = [
    ("1. la van sale con la altura fija de antes (queda 1 stud arriba del patio)",
     MAIN,
     "local baseCF = CFrame.new(sp.X, sp.Y + 0.05, sp.Z)",
     "local baseCF = CFrame.new(sp.X, 2.05, sp.Z)",
     None, "caminos51.py"),

    ("2. el cajon se queda sin su patio (la van vuelve a salir sobre el pasto)",
     CITY,
     "Size = Vector3.new(padAncho, 2, padLargo),",
     "Size = Vector3.new(0.2, 2, padLargo),",
     None, "caminos51.py"),

    ("3. la calle de hilera donde la ponia la v51 (+71: debajo de los patios)",
     CITY,
     "return lot.Origin.Z - (r - 1) * lot.SpacingZ + 121",
     "return lot.Origin.Z - (r - 1) * lot.SpacingZ + 71",
     None, "caminos51.py"),

    ("4. se pierde la rampa del ultimo lote de cada hilera",
     CITY,
     "for c = 0, lot.PerRow - 1 do\n\t\t\t\tlocal lx = lot.Origin.X + c * lot.SpacingX",
     "for c = 0, lot.PerRow - 2 do\n\t\t\t\tlocal lx = lot.Origin.X + c * lot.SpacingX",
     None, "caminos51.py"),

    ("5. los caminos norte-sur dejan de existir",
     CITY,
     "buildLotRoads(city)",
     "do end -- BUG DE PRUEBA: sin los caminos de los lotes",
     None, "caminos51.py"),

    ("6. el camino principal pegado a la linea de lotes (toca las bodegas nivel 4)",
     CITY,
     "local principalX = lot.Origin.X + 1.5 * lot.SpacingX - 13.5",
     "local principalX = lot.Origin.X + 1.5 * lot.SpacingX - 0",
     None, "caminos51.py"),

    ("7. sin re-sellar HomeCF: el porton del cajon se vuela al cerrarse",
     MAIN,
     "clone:PivotTo(CFrame.new(warehouseSlotPos(slot)))\n\tresellarHome(clone)",
     "clone:PivotTo(CFrame.new(warehouseSlotPos(slot)))",
     None, "reportes48.py"),

    ("8. el bucle de manejo no adopta movimientos externos (boton Auto roto)",
     MAIN,
     "if (cfb.Position - ultCF.Position).Magnitude > 0.35 then",
     "if false and (cfb.Position - ultCF.Position).Magnitude > 0.35 then",
     None, "reportes48.py"),

    ("9. el camino de en medio no llega a la ciudad (lotes oriente sin salida)",
     CITY,
     'Name = "RoadLotesX2",\n\t\tSize = Vector3.new(ROAD_W, 1, zCiudad - zUltima),',
     'Name = "RoadLotesX2",\n\t\tSize = Vector3.new(ROAD_W, 1, zPrimera - zUltima),',
     None, "caminos51.py"),
]


def corre_etapa(cual):
    r = subprocess.run([sys.executable, os.path.join(HERE, cual)],
                       capture_output=True, text=True, cwd=ROOT, timeout=900)
    return r.returncode, r.stdout + r.stderr


fallas = 0
for nombre, archivo, bueno, malo, esperado, etapa in CASOS:
    respaldo = "/tmp/alreves51-" + os.path.basename(archivo)
    shutil.copy2(archivo, respaldo)
    try:
        s = open(archivo, encoding="utf-8").read()
        if s.count(bueno) != 1:
            print("  ?? no pude meter el bug '%s': el texto aparece %d veces"
                  % (nombre, s.count(bueno)))
            fallas += 1
            continue
        open(archivo, "w", encoding="utf-8").write(s.replace(bueno, malo))

        code, salida = corre_etapa(etapa)
        linea = ""
        for l in salida.splitlines():
            if "FALLA" in l or l.strip().startswith("- "):
                linea = l.strip()
                if linea.startswith("- "):
                    break
        if code == 0:
            fallas += 1
            print("  MAL    %s -> la etapa paso: NO caza el bug" % nombre)
        elif esperado and esperado not in salida:
            fallas += 1
            print("  MAL    %s -> trono, pero por otra cosa (%s)" % (nombre, linea[:90]))
        else:
            print("  OK     %s\n         -> %s" % (nombre, linea[:110]))
    finally:
        shutil.copy2(respaldo, archivo)

print()
if fallas:
    print("FALLA: %d bug(s) que las etapas no cazan" % fallas)
else:
    print("OK: los 9 bugs de las rondas v51-v53 tronaban las etapas (los chequeos sirven)")
sys.exit(1 if fallas else 0)
