#!/usr/bin/env python3
"""AL REVES (v51): cada bug de esta ronda tiene que TRONAR la etapa 26.

La regla del proyecto es no confiar en un chequeo que nunca se vio fallar.
Aqui se mete el bug DE VERDAD en el archivo real (Main.luau o CityGenerator.luau),
se corre la etapa 26 y se comprueba que truene; luego se deja todo como estaba.

Bugs que se prueban:
  1. la van sale con la altura fija de antes (2.05): queda 1 stud arriba del piso
     del patio (era "la van al spawnearla afuera sale mal")
  2. el cajon se queda sin su patio (BayApron): la van vuelve a salir sobre el pasto
  3. una calle de hilera mal puesta (5 studs al sur): se mete en el patio del lote
  4. se pierde una rampa de entrada (el bucle se corta antes)
  5. los caminos norte-sur dejan de existir

NOTA: este archivo se recupero cortado del chat anterior (los casos 1-4) y se
completo siguiendo el patron de alreves48.py / alreves49.py. Los textos de los
casos 1-4 son LOS MISMOS que escribio el chat anterior, para que sigan siendo
la prueba al reves de esa ronda.
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MAIN = os.path.join(ROOT, "ServerScriptService/Main.luau")
CITY = os.path.join(ROOT, "ServerScriptService/CityGenerator.luau")

print("=== AL REVES (v51): cada bug reportado tiene que tronar la etapa 26 ===")

CASOS = [
    ("1. la van sale con la altura fija de antes (queda 1 stud arriba del patio)",
     MAIN,
     "local baseCF = CFrame.new(sp.X, sp.Y + 0.05, sp.Z)",
     "local baseCF = CFrame.new(sp.X, 2.05, sp.Z)",
     None),

    ("2. el cajon se queda sin su patio (la van vuelve a salir sobre el pasto)",
     CITY,
     "Size = Vector3.new(padAncho, 2, padLargo),",
     "Size = Vector3.new(0.2, 2, padLargo),",
     None),

    ("3. una calle de hilera mal puesta (cae dentro del patio del lote)",
     CITY,
     "return lot.Origin.Z - (r - 1) * lot.SpacingZ + 71",
     "return lot.Origin.Z - (r - 1) * lot.SpacingZ + 40",
     None),

    ("4. se pierde la rampa del ultimo lote de cada hilera",
     CITY,
     "for c = 0, lot.PerRow - 1 do\n\t\t\t\tlocal lx = lot.Origin.X + c * lot.SpacingX",
     "for c = 0, lot.PerRow - 2 do\n\t\t\t\tlocal lx = lot.Origin.X + c * lot.SpacingX",
     None),

    ("5. los caminos norte-sur dejan de existir",
     CITY,
     "buildLotRoads(city)",
     "do end -- BUG DE PRUEBA: sin los caminos de los lotes",
     None),
]


def corre_etapa():
    r = subprocess.run([sys.executable, os.path.join(HERE, "caminos51.py")],
                       capture_output=True, text=True, cwd=ROOT, timeout=900)
    return r.returncode, r.stdout + r.stderr


fallas = 0
for nombre, archivo, bueno, malo, esperado in CASOS:
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

        code, salida = corre_etapa()
        linea = ""
        for l in salida.splitlines():
            if "FALLA" in l or "- " in l[:12]:
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
    print("FALLA: %d bug(s) que la etapa no caza" % fallas)
else:
    print("OK: los 5 bugs de la ronda v51 tronaban la etapa 26 (los chequeos sirven)")
sys.exit(1 if fallas else 0)
