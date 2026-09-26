#!/usr/bin/env python3
"""LA PRUEBA AL REVES DE LA v48.

El usuario tiene una regla dura: "los chequeos se prueban metiendo el bug". Si un
chequeo pasa con el bug puesto, ese chequeo no sirve. Aqui se mete, UNO POR UNO,
cada uno de los 5 problemas que reporto el usuario en la ronda v48 y se corre la
etapa 23 (tools/reportes48.py): tiene que TRONAR cada vez, y con el mensaje
correcto. Al final se deja todo como estaba (se guardan copias y se restauran).

    python3 tools/alreves48.py
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MAIN = os.path.join(ROOT, "ServerScriptService/Main.luau")
CITY = os.path.join(ROOT, "ServerScriptService/CityGenerator.luau")
UI = os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau")

# (nombre, archivo, texto que hay, texto con el bug, lo que tiene que decir la etapa)
BUGS = [
    ("1. el auto que no se maneja (v47: pura fisica, cero driver)",
     MAIN,
     "\tpcall(hacerConducible, model, info, baseCF)",
     "\tdo end -- BUG DE PRUEBA: el auto sin manejo, como en la v47",
     "el auto solo avanzo"),

    ("2. la bici que no comprueba el lugar (vuelve a nacer adentro)",
     MAIN,
     """		if arriba then return nil end                         -- hay techo: es adentro
		for _, lado in ipairs({Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0),
			Vector3.new(0, 0, 1), Vector3.new(0, 0, -1)}) do
			if Workspace:Raycast(p + Vector3.new(0, 2, 0), lado * 5, rp) then
				return nil                                    -- algo pegado a los lados
			end
		end""",
     """		-- BUG DE PRUEBA: se quitan las comprobaciones (cielo abierto y lados
		-- libres): la bici vuelve a caer adentro del taller""",
     "esta adentro de algo"),

    ("3. el letrero chico (tablero de 15x4 como en la v47)",
     CITY,
     "\t\tSize = Vector3.new(26, 5.4, 0.4),",
     "\t\tSize = Vector3.new(15, 4, 0.4), -- BUG DE PRUEBA: el letrero de la v47",
     "la letra queda de"),

    ("4. el mercado que no se cierra al alejarte",
     UI,
     """					elseif not v and shop.Visible and currentTab == "autos"
						and not aLaCaja(pisoTaller, 8) then""",
     """					elseif not v and shop.Visible and currentTab == "autos"
						and false then -- BUG DE PRUEBA: nunca se cierra solo""",
     "el panel SIGUE ABIERTO"),

    ("5. la bodega plana (sin la decoracion de la v48)",
     CITY,
     None,      # se borra el bloque completo
     None,
     "faltan piezas de detalle"),
]

INICIO_DETALLES = "\t-- ===== v48: DETALLES DE BODEGA"


def corre_etapa():
    r = subprocess.run([sys.executable, os.path.join(HERE, "reportes48.py")],
                       capture_output=True, text=True, cwd=ROOT, timeout=1800)
    return r.returncode, r.stdout + r.stderr


fallas = 0
print("=== AL REVES: cada bug reportado tiene que tronar la etapa 23 ===")
for nombre, archivo, bueno, malo, esperado in BUGS:
    respaldo = "/tmp/alreves48-" + os.path.basename(archivo)
    shutil.copy2(archivo, respaldo)
    try:
        s = open(archivo, encoding="utf-8").read()
        if bueno is None:
            # borrar el bloque completo de decoracion
            i = s.index(INICIO_DETALLES)
            j = s.index("\t-- ===== LAMPARAS DE TECHO =====")
            s = s[:i] + s[j:]
        else:
            if s.count(bueno) != 1:
                print("  ?? no pude meter el bug '%s': el texto aparece %d veces"
                      % (nombre, s.count(bueno)))
                fallas += 1
                continue
            s = s.replace(bueno, malo)
        open(archivo, "w", encoding="utf-8").write(s)

        code, salida = corre_etapa()
        linea = ""
        for l in salida.splitlines():
            if "FALLA" in l or "no llego" in l:
                linea = l.strip()
                break
        if code == 0:
            fallas += 1
            print("  MAL    %s -> la etapa paso: NO caza el bug" % nombre)
        elif esperado not in salida:
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
    print("OK: los 5 bugs de la ronda v48 tronaban la etapa 23 (los chequeos sirven)")
sys.exit(1 if fallas else 0)
