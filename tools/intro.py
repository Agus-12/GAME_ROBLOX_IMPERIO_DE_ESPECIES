#!/usr/bin/env python3
"""Mide cuanto tarda en salir el boton "ENTRAR AL BARRIO".

Por que existe: el usuario se quedo atorado en la portada ("Cargando la
ciudad...") porque el boton esperaba una respuesta del servidor con un respaldo
de 30 intentos x 0.4 s = 12 segundos. El simulador NO podia verlo: su task.spawn
no corria nada y su task.wait no esperaba, asi que aquel bucle terminaba al
instante y las pruebas salian en verde.

Ahora el mock trae reloj virtual y este script revisa dos escenarios:

  A) servidor listo (ciudad + personaje) -> la portada debe abrir AL INSTANTE
  B) servidor lento (sin ciudad todavia) -> como mucho 3.2 s

Uso:  python3 tools/intro.py
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")
if not os.path.exists(LUA):
    sys.exit("Falta Lua. Corre primero:  bash tools/setup.sh")

cfg = strip_luau(open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau")).read())
open(os.path.join(HERE, "cfgload.lua"), "w").write("return (function()\n" + cfg + "\nend)()\n")

src = (strip_luau(open(os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau")).read())
       .replace("goto cont", "_SKIP=true"))

BODY = '''dofile("%s/mockclient.lua")
local ok, err = pcall(function()
%s
end)
if not ok then print("!! el cliente trono: " .. tostring(err)) end
-- OJO: hay que DEJAR CORRER el reloj virtual antes de medir: si no, se mide
-- el estado del instante cero y cualquier cosa parece "NUNCA".
local T = task.__sched
T.advance(6)          -- 6 segundos virtuales: mas que cualquiera de los topes
print(string.format("  se abrio a los %%s s virtuales", tostring(__INTRO_AT or "NUNCA")))
'''

escenarios = [
    # (nombre, ciudad, personaje, retraso del personaje, tope en segundos virtuales)
    ("A) servidor listo (ciudad + personaje)", "1", "1", "0", 0.6),
    ("B) el personaje tarda 0.8 s en aparecer", "1", "0", "0.8", 1.4),
    ("C) servidor lento (sin ciudad todavia)", "0", "0", "0", 3.2),
]

fallos = 0
for nombre, city, char, char_delay, tope in escenarios:
    print(nombre)
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
    t.write(BODY % (HERE, src))
    t.close()
    env = dict(os.environ, MOCK_VW="896", MOCK_VH="414", MOCK_TOUCH="1",
               MOCK_CITY=city, MOCK_CHAR=char, MOCK_CHAR_DELAY=char_delay, TOOLS=HERE)
    r = subprocess.run([LUA, t.name], capture_output=True, text=True, env=env, timeout=180)
    os.unlink(t.name)
    salida = (r.stdout + r.stderr).strip()
    print(salida[-1200:])

    # saca el numero del renglon que imprime el script
    valor, marca = None, "  ??  "
    for linea in salida.splitlines():
        if "se abrio a los" in linea:
            trozo = linea.split("se abrio a los")[1].strip().split(" ")[0]
            try:
                valor = float(trozo)
            except ValueError:
                valor = None
    if valor is None:
        marca = "  FALLA  la portada NUNCA se abrio"
        fallos += 1
    elif valor <= tope:
        marca = "  OK     abre a los %.2f s (tope %.1f s)" % (valor, tope)
    else:
        marca = "  FALLA  tarda %.2f s (tope %.1f s)" % (valor, tope)
        fallos += 1
    print(marca)

print()
if fallos:
    print("FALLA")
    print("  La portada no debe depender del servidor: revisa el bloque")
    print("  'CUANDO SE ABRE EL BOTON ENTRAR AL BARRIO' en ClientUI.luau")
    sys.exit(1)
print("OK")
