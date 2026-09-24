#!/usr/bin/env python3
"""ETAPA 18 (v43): EL DOCK DE CELULAR, PROBADO A TOQUES.

Que revisa y por que:

El usuario dijo **"el dashboard de abajo eso no funciona en celular"**. La v42 le
agrego el boton "Auto", pero el cuadro seguia con botones de puro texto chiquito y
los botones no tenian `Active`/`Selectable`. Esta etapa comprueba TRES cosas:

  1. EN EL CODIGO: los botones del dock traen icono, van con `Active = true` y
     `Selectable = false`, y la rejilla tactil usa los tamanos grandes.
  2. EN EL SIMULADOR (lo importante): se ARRANCA la ClientUI, se BUSCAN los botones
     en pantalla y se les da clic como un dedo. Despues se revisa **que accion le
     llego al servidor** (`teleportHome`, `summonCar`...) y que el Telefono de
     verdad ABRA su pantalla.
     Antes esto era imposible: los remotes del simulador no existian, asi que
     `act()` moria dentro de un pcall y el clic no mandaba nada. O sea que un boton
     roto pasaba las pruebas sin que nadie se enterara.
  3. AL LLEGAR A LA BODEGA: el menu se abre solo (pestana Autos), como la
     computadora.

Se probo al reves (v43): quitandole el `Active` a un boton y dejando el
`MouseButton1Click` sin accion, la etapa lo caza.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau            # noqa: E402

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")

fallas = 0


def L(ruta):
    return strip_luau(open(os.path.join(ROOT, ruta), encoding="utf-8").read()) \
        .replace("goto cont", "_SKIP=true")


def lua(guion, env=None):
    e = dict(os.environ, TOOLS=HERE)
    if env:
        e.update(env)
    return subprocess.run([LUA, "-"], input=guion, capture_output=True,
                          text=True, env=e, cwd=ROOT, timeout=600)


UI = open(os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau"), encoding="utf-8").read()

# ---------------------------------------------------------------- 1) EL CODIGO
print("=== 18. EL DOCK DE CELULAR (v43) ===")
problemas = []

# el boton del dock: icono + Active/Selectable
m = re.search(r"local function dockBtn\((.*?)\nend\n", UI, re.S)
if not m:
    problemas.append("no encontre la funcion dockBtn")
else:
    cuerpo = m.group(1)
    if "Active = true" not in cuerpo:
        problemas.append("los botones del dock NO traen Active = true "
                         "(en celular el toque puede caer en el marco y no hace nada)")
    if "Selectable = false" not in cuerpo:
        problemas.append("los botones del dock no desactivan Selectable")
    if "TextYAlignment" not in cuerpo:
        problemas.append("los botones del dock no ponen el nombre abajo del icono")
    if "icon" not in UI.split("local function dockBtn")[1][:200]:
        problemas.append("dockBtn no acepta icono (el boton de celular saldria sin dibujo)")

# la rejilla tactil: grande y en 2 columnas
if not re.search(r"local BTN_W = IS_MOBILE and (\d+)", UI):
    problemas.append("no encontre el ancho de boton")
else:
    ancho = int(re.search(r"local BTN_W = IS_MOBILE and (\d+)", UI).group(1))
    alto = int(re.search(r"local BTN_H = IS_MOBILE and (\d+)", UI).group(1))
    # el minimo comodo para un dedo es ~48 px
    if ancho < 72 or alto < 56:
        problemas.append("los botones de celular miden %dx%d: muy chicos para un dedo"
                         % (ancho, alto))
    if ancho * 2 + 20 > 230:
        problemas.append("dos columnas de botones no caben a lo ancho (%d)" % (ancho * 2 + 20))

# cada boton del dock tiene su icono (sin icono = puro cuadro de texto en celular).
# Se leen las llamadas de verdad: se busca "dockBtn(" y se camina hasta cerrar el
# parentesis contando parentesis y respetando las cadenas, porque las llamadas
# traen funciones de varias lineas adentro y una busqueda simple se equivoca.
def llamadas_dock(texto):
    fuera = []
    i = texto.find("dockBtn(")
    while i != -1:
        # la DEFINICION no cuenta, solo las llamadas
        if texto[max(0, i - 9):i].strip().endswith("function"):
            i = texto.find("dockBtn(", i + 1)
            continue
        j, prof, en_cadena = i + len("dockBtn("), 1, False
        while j < len(texto) and prof > 0:
            ch = texto[j]
            if ch == '"' and texto[j - 1] != "\\":
                en_cadena = not en_cadena
            elif not en_cadena:
                if ch in "([{":
                    prof += 1
                elif ch in ")]}":
                    prof -= 1
                    if prof == 0:
                        break
            j += 1
        fuera.append(texto[i:j])
        i = texto.find("dockBtn(", j)
    return fuera


sin_icono = []
for ll in llamadas_dock(UI.replace("goto cont", "")):
    # el ultimo argumento del dock es el icono: tiene que ser una cadena
    if not re.search(r',\s*(?:nil\s*,\s*)?"[^"]*"\s*$', ll.strip()):
        nombre = re.search(r'dockBtn\(\s*"([^"]+)"', ll)
        sin_icono.append(nombre.group(1) if nombre else ll[:40])
if sin_icono:
    problemas.append("botones del dock sin icono: " + ", ".join(sin_icono))

# el menu se abre al llegar a la bodega
if 'k == "garage"' not in UI or 'renderTab("autos")' not in UI:
    problemas.append("al llegar a la BODEGA no se abre el menu (el usuario lo pidio)")

if problemas:
    fallas += 1
    print("  FALLA  (en el codigo)")
    for x in problemas:
        print("         - " + x)
else:
    print("  OK     en el codigo: dockBtn con icono, Active/Selectable, botones de "
          "%dx%d y el menu de la bodega al llegar" % (ancho, alto))

# ------------------------------------------------- 2) A TOQUES EN EL SIMULADOR
CLIENTE = L("StarterPlayerScripts/ClientUI.luau")
guion = 'dofile("%s/mockclient.lua")\n' % HERE
guion += "local __cli = function()\n" + CLIENTE + "\nend\n__cli()\n"
guion += '''
if task.__sched then task.__sched.advance(2) end
local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local sg = pg and pg:FindFirstChild("SpiceEmpireUI")
local function busca(txt)
  if not sg then return nil end
  for _, d in ipairs(sg:GetDescendants()) do
    if d.ClassName == "TextButton" and string.find(d.Text or "", txt, 1, true) then
      return d
    end
  end
end
-- los botones del dock que SIEMPRE estan visibles en celular
local nombres = {"Telefono", "Bodega", "Auto"}
local faltan, sinActivo = {}, {}
for _, n in ipairs(nombres) do
  local b = busca(n)
  if not b then
    table.insert(faltan, n)
  else
    if b.Active ~= true then table.insert(sinActivo, n) end
    b.MouseButton1Click:Fire()
  end
end
if task.__sched then task.__sched.advance(3) end
local accs = {}
for _, l in ipairs(LLAMADAS or {}) do
  local a = l.args and l.args[1]
  if type(a) == "string" then table.insert(accs, a) end
end
table.sort(accs)
-- ¿el Telefono abre su pantalla? (se busca su titulo, visible, con panel visible)
local abierto = false
for _, d in ipairs(sg and sg:GetDescendants() or {}) do
  if d.ClassName == "TextLabel" and d.Text == "MENSAJES" and d.Visible then
    if d.Parent and d.Parent.Visible then abierto = true end
  end
end
print("__DOCK__ faltan=" .. table.concat(faltan, ",") ..
  "|sinactivo=" .. table.concat(sinActivo, ",") ..
  "|acciones=" .. table.concat(accs, ",") ..
  "|telefono=" .. tostring(abierto))
'''
sal = lua(guion, env={"MOCK_TOUCH": "1"})
m = re.search(r"__DOCK__ faltan=(\S*)\|sinactivo=(\S*)\|acciones=(\S*)\|telefono=(\w+)",
              sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  el cliente no llego al final en modo tactil")
    for linea in (sal.stdout + sal.stderr).strip().splitlines()[-8:]:
        print("         | " + linea[:150])
else:
    faltan, sinactivo, acciones, telefono = m.groups()
    tiene = set(x for x in acciones.split(",") if x)
    quiero = {"teleportHome", "summonCar"}
    prob = []
    if faltan:
        prob.append("no aparece(n) en pantalla: " + faltan)
    if sinactivo:
        prob.append("sin Active (el toque se puede perder): " + sinactivo)
    if not quiero.issubset(tiene):
        prob.append("no le llego al servidor: " + ", ".join(sorted(quiero - tiene)))
    if telefono != "true":
        prob.append("el boton Telefono NO abrio su pantalla")
    if prob:
        fallas += 1
        print("  FALLA  (a toques, con MOCK_TOUCH=1)")
        for x in prob:
            print("         - " + x)
        print("         acciones que si llegaron: %s" % (acciones or "(ninguna)"))
    else:
        print("  OK     a toques: los 3 botones fijos existen, tienen Active y "
              "mandan su accion")
        print("         acciones al servidor: %s" % acciones)
        print("         y el Telefono abre su pantalla")

print()
if fallas:
    print("FALLA: %d problema(s) del dock de celular" % fallas)
    sys.exit(1)
print("OK: el dock de celular responde al toque")
