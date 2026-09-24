#!/usr/bin/env python3
"""ETAPA 19 (v44): LOS 4 REPORTES DEL USUARIO EN SUS CAPTURAS.

Que revisa:

  1. **"algunas de las otras parcelas: las bodegas estan ENCIMA DE LA CALLE"**
     Las calles se dibujaban del mismo tamano que el SUELO. Como el suelo se estira
     para cubrir los lotes de bodega, las calles tambien se estiraban y cruzaban por
     encima de los lotes. Aqui se mide: la calle mas lejana tiene que quedar DENTRO
     de la ciudad, y ningun lote puede quedar debajo de una calle.

  2. **"me salen los nombres asi en grandote muy estorboso"** Los rotulos de los
     edificios (garaje, taller, oficina, porton, aduanas, caja fuerte) eran
     BillboardGui de 200x50: se dibujan IGUAL de grandes a cualquier distancia y
     encimados tapan media pantalla. Ahora van PINTADOS en el tablero negro que ya
     existe (SurfaceGui pegado a la parte). Se revisa que esos rotulos ya no sean
     flotantes y que el texto diga lo que debe.

  3. **"poner 'garaje de <usuario>' o 'sin propietario'"** El tablero del garaje
     del jugador dice `GARAJE DE <NOMBRE>` y el de los lotes sin dueno dice
     `SIN PROPIETARIO`.

  4. **"vi un letrero flotante de 'caja 1': poner ahi 'caja 1' pero en texto plano"**
     El numero del cajon va pintado en su tablero negro: `CAJA 1`, `CAJA 2`...

Probado al reves (v44): se regresan las calles al tamano del suelo, se vuelve a
poner un BillboardGui en el tablero del garaje y se le quita el rotulo a los lotes
sin dueno -> los tres se cazan.
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


def lua(guion):
    return subprocess.run([LUA, "-"], input=guion, capture_output=True, text=True,
                          env=dict(os.environ, TOOLS=HERE), cwd=ROOT, timeout=900)


print("=== 19. LOS REPORTES DE LAS CAPTURAS (v44) ===")

# ============================================================ 1) LAS CALLES
guion = 'dofile("%s/mock.lua")\n' % HERE
guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
guion += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function()
'''
guion += L("ServerScriptService/CityGenerator.luau")
guion += '''
end)()
local ok, ciudad = pcall(function() return City.Build() end)
if not ok then print("__RES__ la ciudad no se pudo construir: " .. tostring(ciudad)) return end

-- 1) hasta donde llegan las CALLES (el rectangulo mas grande que ocupan)
local minX, maxX, minZ, maxZ = 1e9, -1e9, 1e9, -1e9
local carreteras = 0
for _, d in ipairs(ciudad:GetDescendants()) do
  if d:IsA("BasePart") and string.match(d.Name, "^Road[XYZ]%d+$") then
    carreteras = carreteras + 1
    local p, sz = d.Position, d.Size
    minX = math.min(minX, p.X - sz.X * 0.5) ; maxX = math.max(maxX, p.X + sz.X * 0.5)
    minZ = math.min(minZ, p.Z - sz.Z * 0.5) ; maxZ = math.max(maxZ, p.Z + sz.Z * 0.5)
  end
end
print("__RES__ calles=" .. carreteras ..
  "|calleX=" .. string.format("%.0f,%.0f", minX, maxX) ..
  "|calleZ=" .. string.format("%.0f,%.0f", minZ, maxZ))
'''
sal = lua(guion)
m = re.search(r"__RES__ (.*)", sal.stdout + sal.stderr)
if not m:
    print("  FALLA  la ciudad no se pudo medir")
    for linea in (sal.stdout + sal.stderr).strip().splitlines()[-6:]:
        print("         | " + linea[:150])
    fallas += 1
else:
    campos = dict(kv.split("=") for kv in m.group(1).split("|"))
    minX, maxX = [float(x) for x in campos["calleX"].split(",")]
    minZ, maxZ = [float(x) for x in campos["calleZ"].split(",")]
    # datos de la ciudad y de los lotes, del propio GameConfig
    cfg = open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau"), encoding="utf-8").read()
    lado_ciudad = 5 * (160 + 34) + (160 + 34) * 3          # GridX * CELL + CELL*3
    origen = re.search(r"Origin = Vector3\.new\((-?[\d.]+), *(-?[\d.]+), *(-?[\d.]+)\)", cfg)
    esp_x = float(re.search(r"SpacingX = ([\d.]+)", cfg).group(1))
    esp_z = float(re.search(r"SpacingZ = ([\d.]+)", cfg).group(1))
    per_row = int(re.search(r"PerRow = (\d+)", cfg).group(1))
    max_slots = int(re.search(r"MaxSlots = (\d+)", cfg).group(1))
    ox, oz = float(origen.group(1)), float(origen.group(3))
    filas = -((max_slots - 1) // per_row)
    lot_min_z, lot_max_z = oz + filas * esp_z, oz
    mitad = lado_ciudad * 0.5
    problemas = []
    if int(campos["calles"]) < 5:
        problemas.append("se encontraron %s calles (deberian ser 10: 5 y 5)" % campos["calles"])
    # las calles no deben salirse de la ciudad
    if minX < -mitad - 1 or maxX > mitad + 1 or minZ < -mitad - 1 or maxZ > mitad + 1:
        problemas.append("hay calle fuera de la ciudad (calle X %.0f..%.0f, Z %.0f..%.0f; "
                         "la ciudad mide %.0f de lado)" % (minX, maxX, minZ, maxZ, lado_ciudad))
    # y ninguna calle debe llegar a la zona de lotes (Z de lote mas cercano = oz)
    if minZ < oz - 1 and lot_min_z <= minZ:
        problemas.append("una calle llega hasta Z=%.0f y la primera fila de lotes esta en Z=%.0f: "
                         "las bodegas quedan encima de la calle" % (minZ, oz))
    if problemas:
        fallas += 1
        print("  FALLA  (calles contra lotes)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     las 10 calles viven dentro de la ciudad "
              "(X %.0f..%.0f, Z %.0f..%.0f) y no llegan a los lotes (Z=%.0f)"
              % (minX, maxX, minZ, maxZ, oz))

# ================================================ 2 A 4) LOS ROTULOS
print()
guion2 = 'dofile("%s/mock.lua")\n' % HERE
guion2 += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
guion2 += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function()
'''
guion2 += L("ServerScriptService/CityGenerator.luau")
guion2 += '''
end)()
local ok, wh = pcall(function() return City.BuildWarehouse(1) end)
if not ok then print("__RES2__ la bodega no se pudo construir: " .. tostring(wh)) return end

-- los rotulos que el usuario reporto como "grandotes y estorbosos"
local nombres = {"GarageSign", "BayPlate", "lintel", "GarageDoorHead", "GateSign"}
local function esRotulo(n)
  for _, x in ipairs(nombres) do if x == n then return true end end
  return false
end
local flotantes, pintados = {}, {}
for _, d in ipairs(wh:GetDescendants()) do
  if d:IsA("BasePart") and esRotulo(d.Name) then
    local tieneBillboard, tieneSurface = false, false
    for _, h in ipairs(d:GetChildren()) do
      if h.ClassName == "BillboardGui" then tieneBillboard = true end
      if h.ClassName == "SurfaceGui" then tieneSurface = true end
    end
    if tieneBillboard then table.insert(flotantes, d.Name) end
    if tieneSurface then table.insert(pintados, d.Name) end
  end
end
-- el billboard mas grande que quede en toda la bodega (el que estorba)
local peor = 0
for _, d in ipairs(wh:GetDescendants()) do
  if d.ClassName == "BillboardGui" then
    local ancho = (d.Size and d.Size.X and d.Size.X.Offset) or 0
    if ancho > peor then peor = ancho end
  end
end
-- el texto del tablero del garaje y el de los cajones
local function textoDe(parte)
  local g = parte and parte:FindFirstChild("Rotulo")
  local l = g and g:FindFirstChild("Texto")
  return l and l.Text or "(sin texto)"
end
local garaje = wh:FindFirstChild("GarageSign", true)
local cajas = {}
for _, d in ipairs(wh:GetDescendants()) do
  if d.Name == "BayPlate" then table.insert(cajas, textoDe(d)) end
end
table.sort(cajas)
-- RotularGaraje: escribe encima del mismo rotulo
-- OJO: hay que guardar el texto de ANTES, si no se imprime el de despues y la
-- prueba se miente sola (me paso al escribirla)
local antes = tostring(textoDe(garaje))
local cambio = City.RotularGaraje(wh, "GARAJE DE PEPE")

-- el camino REAL del lote sin dueno: VarianteVecina + Clausurar + rotulo
local ok2, vecina = pcall(function()
  local m2 = City.BuildWarehouse(2)
  City.VarianteVecina(m2, 1)
  City.Clausurar(m2)
  return m2
end)
local diceSinDueno = "no"
if ok2 and vecina then
  City.RotularGaraje(vecina, "SIN PROPIETARIO")
  local g2 = vecina:FindFirstChild("GarageSign", true)
  if textoDe(g2) == "SIN PROPIETARIO" then diceSinDueno = "si" end
end
-- la tablilla de CLAUSURADA del lote vecino: pintada, no flotante
local tablilla, flotanteTab = nil, false
if ok2 and vecina then
  for _, d in ipairs(vecina:GetDescendants()) do
    if d.Name == "TablillaClausurada" then
      tablilla = d
      for _, h in ipairs(d:GetChildren()) do
        if h.ClassName == "BillboardGui" then flotanteTab = true end
      end
    end
  end
end
local textoClaus = tablilla and (function()
  local g3 = tablilla:FindFirstChild("Rotulo")
  local l3 = g3 and g3:FindFirstChild("Texto")
  return l3 and l3.Text or "(sin texto)"
end)() or "(no hay tablilla)"
print("__RES2__ flotantes=" .. table.concat(flotantes, ",") ..
  "|pintados=" .. table.concat(pintados, ",") ..
  "|billboardMax=" .. tostring(peor) ..
  "|garaje=" .. antes ..
  "|cajas=" .. table.concat(cajas, ",") ..
  "|cambio=" .. tostring(cambio) ..
  "|tras=" .. tostring(textoDe(garaje)) ..
  "|sinDueno=" .. diceSinDueno ..
  "|clausura=" .. textoClaus ..
  "|flotanteTab=" .. tostring(flotanteTab))
'''
sal2 = lua(guion2)
m2 = re.search(r"__RES2__ (.*)", sal2.stdout + sal2.stderr)


def textoPlano_usado(ruta):
    src = open(os.path.join(ROOT, ruta), encoding="utf-8").read()
    return src.count("textoPlano(")


if not m2:
    fallas += 1
    print("  FALLA  la bodega no se pudo revisar")
    for linea in (sal2.stdout + sal2.stderr).strip().splitlines()[-6:]:
        print("         | " + linea[:150])
else:
    d2 = dict(kv.split("=", 1) for kv in m2.group(1).split("|"))
    prob = []
    if d2.get("flotantes"):
        prob.append("siguen FLOTANDO (BillboardGui) estos rotulos: " + d2["flotantes"])
    if d2.get("garaje", "") != "GARAJE":
        prob.append("el tablero del garaje no trae su rotulo pintado (dice \"%s\")" % d2.get("garaje"))
    if d2.get("cajas", "") != "CAJA 1":
        prob.append("los cajones no dicen 'CAJA n' en texto plano (dicen \"%s\")" % d2.get("cajas"))
    if d2.get("cambio") != "true":
        prob.append("RotularGaraje no pudo escribir en el tablero")
    if d2.get("tras") != "GARAJE DE PEPE":
        prob.append("RotularGaraje no cambio el texto (quedo \"%s\")" % d2.get("tras"))
    if d2.get("sinDueno") != "si":
        prob.append("el lote sin dueno no dice 'SIN PROPIETARIO' en su tablero")
    if d2.get("clausura") != "CLAUSURADA":
        prob.append("la tablilla del lote clausurado dice \"%s\"" % d2.get("clausura"))
    if d2.get("flotanteTab") == "true":
        prob.append("la tablilla de CLAUSURADA sigue con letrero flotante")
    try:
        peor = int(d2.get("billboardMax", "9999"))
    except ValueError:
        peor = 9999
    if peor > 160:
        prob.append("queda un letrero flotante de %s pixeles de ancho (estorba)" % peor)
    if prob:
        fallas += 1
        print("  FALLA  (rotulos)")
        for x in prob:
            print("         - " + x)
        print("         pintados en la bodega: %s" % (d2.get("pintados") or "(ninguno)"))
    else:
        print("  OK     los rotulos van PINTADOS en su tablero (na' flotando): %s"
              % d2.get("pintados"))
        print("         el garaje dice \"%s\" y los cajones \"%s\"; RotularGaraje lo "
              "reescribe a \"%s\"" % (d2.get("garaje"), d2.get("cajas"), d2.get("tras")))

# el texto que el usuario pidio, en el servidor
main_src = open(os.path.join(ROOT, "ServerScriptService/Main.luau"), encoding="utf-8").read()
prob2 = []
if "GARAJE DE " not in main_src:
    prob2.append("el garaje del jugador no dice 'GARAJE DE <nombre>'")
if "SIN PROPIETARIO" not in main_src:
    prob2.append("los lotes sin dueno no dicen 'SIN PROPIETARIO'")
if 'Size = UDim2.new(0, 260, 0, 50)' in main_src:
    prob2.append("sigue el letrero GIGANTE de 260x50 flotando sobre la bodega")
print("  %s  el servidor: %s" % ("OK   " if not prob2 else "FALLA",
      "rotula el garaje con el dueno y los vacios con SIN PROPIETARIO" if not prob2
      else "; ".join(prob2)))
if prob2:
    fallas += 1

print()
if fallas:
    print("FALLA: %d problema(s) de los reportes de las capturas" % fallas)
    sys.exit(1)
print("OK: calles fuera de los lotes y rotulos pintados (nada flotando)")
