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
local function sinSaltos(t)
  if type(t) ~= "string" then return tostring(t) end
  return (string.gsub(t, string.char(10), " / "))
end

local function textoDe(parte)
  local g = parte and parte:FindFirstChild("Rotulo")
  local l = g and g:FindFirstChild("Texto")
  return sinSaltos(l and l.Text or "(sin texto)")
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
  return sinSaltos(l3 and l3.Text or "(sin texto)")
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
    tras = (d2.get("tras") or "").replace("\\n", " / ")
    if tras != "GARAJE DE / PEPE":
        prob.append("RotularGaraje no cambio el texto (quedo \"%s\")" % tras)
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

# ============================================ 5) OBRAS VIEJAS + LA PISTOLA (v45)
print()
print("=== 20. OBRAS VIEJAS GUARDADAS Y LA PISTOLA (v45) ===")

# --- 5a) el servidor borra las obras viejas que quedaron guardadas en el lugar
guion3 = 'dofile("%s/mock.lua")\n' % HERE
guion3 += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
guion3 += '''
local _city,_data
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
local sss=game:GetService("ServerScriptService")
sss.WaitForChild=function(s,n)
  if n=="CityGenerator" then return "__CITY__" end
  if n=="DataService" then return "__DATA__" end end
require=function(x)
  if x=="__CFG__" then return _cfg end
  if x=="__CITY__" then return _city end
  if x=="__DATA__" then return _data end
  return {} end
-- LO QUE EL USUARIO VEIA: obras de partidas anteriores GUARDADAS en el lugar
local viejas = {}
local function obra(nombre, attrs)
  local m = Instance.new("Model") ; m.Name = nombre
  for k, v in pairs(attrs or {}) do m:SetAttribute(k, v) end
  m.Parent = workspace ; table.insert(viejas, m)
  return m
end
obra("BodegaVecina_1", {Vecina = true})
obra("BodegaVecina_2", {Vecina = true, Clausurada = true})
obra("BodegaClausurada_3", {Slot = 3})
local cartelViejo = Instance.new("Folder") ; cartelViejo.Name = "Oficiales" ; cartelViejo.Parent = workspace
local ajeno = Instance.new("Model") ; ajeno.Name = "MiCasita" ; ajeno.Parent = workspace
_city=(function()
'''
guion3 += L("ServerScriptService/CityGenerator.luau")
guion3 += '''
end)()
_data=(function()
'''
guion3 += L("ServerScriptService/DataService.luau")
guion3 += '''
end)()
local ok, err = pcall(function()
'''
guion3 += L("ServerScriptService/Main.luau")
guion3 += '''
end)
task.__sched.advance(2)
local quedan, seQuedo = 0, 0
for _, v in ipairs(viejas) do if v.Parent then quedan = quedan + 1 end end
if ajeno.Parent then seQuedo = 1 end
print("__VIEJAS__ ok=" .. tostring(ok) .. "|quedan=" .. quedan .. "|ajeno=" .. seQuedo ..
  "|oficiales=" .. tostring(workspace:FindFirstChild("Oficiales") ~= nil))
'''
sal3 = lua(guion3)
m3 = re.search(r"__VIEJAS__ (.*)", sal3.stdout + sal3.stderr)
if not m3:
    fallas += 1
    print("  FALLA  el servidor no arranco con las obras viejas puestas")
    for linea in (sal3.stdout + sal3.stderr).strip().splitlines()[-6:]:
        print("         | " + linea[:150])
else:
    d3 = dict(kv.split("=") for kv in m3.group(1).split("|"))
    prob3 = []
    if d3.get("ok") != "true":
        prob3.append("el Main trono con obras viejas en el lugar")
    if d3.get("quedan") != "0":
        prob3.append("quedaron %s obra(s) vieja(s) en el mapa" % d3.get("quedan"))
    if d3.get("ajeno") != "1":
        prob3.append("se borro algo que NO era de los lotes (no debe tocar lo demas)")
    if prob3:
        fallas += 1
        print("  FALLA  (obras viejas)")
        for x in prob3:
            print("         - " + x)
    else:
        print("  OK     el servidor borra las obras viejas de los lotes (3 modelos + la")
        print("         carpeta Oficiales) y NO toca lo demas del lugar")

# --- 5b) la pistola: nada flotando
guion4 = 'dofile("%s/mock.lua")\n' % HERE
guion4 += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
# el pedazo del arma se saca de Main.luau YA LIMPIO (sin anotaciones de tipo de
# Luau, que Lua 5.4 no entiende) y se inyecta como texto entre corchetes
_fuente = L("ServerScriptService/Main.luau")
_i = _fuente.index("local function makeWeapon")
_j = _fuente.index("function giveWeapon")
_arma_src = _fuente[_i:_j]
guion4 += """
local TEXTO_ARMA = [==[
""" + _arma_src + """
]==]
local env = setmetatable({
  Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3,
  Enum = Enum, math = math, string = string, table = table, pcall = pcall,
  Config = _cfg,
}, {__index = _G})
local f, err = load(TEXTO_ARMA .. string.char(10) .. "return makeWeapon()", "arma", "t", env)
if not f then print("__ARMA__ trono: " .. tostring(err)) return end
local armada, arma = pcall(f)
if not armada then print("__ARMA__ trono: " .. tostring(arma)) return end
-- se miden las piezas: ninguna puede quedar despegada del cuerpo del arma
local minY, maxY, minZ, maxZ = 1e9, -1e9, 1e9, -1e9
local total = 0
for _, d in ipairs(arma:GetChildren()) do
  if d.ClassName == "Part" and d.Name ~= "Handle" then
    total = total + 1
    minY = math.min(minY, d.CFrame.p.Y - d.Size.Y * 0.5)
    maxY = math.max(maxY, d.CFrame.p.Y + d.Size.Y * 0.5)
    minZ = math.min(minZ, d.CFrame.p.Z - d.Size.Z * 0.5)
    maxZ = math.max(maxZ, d.CFrame.p.Z + d.Size.Z * 0.5)
  end
end
-- el cañon: ¿toca la corredera?
local slide = arma:FindFirstChild("Slide")
local canon = arma:FindFirstChild("Barrel")
local hueco = 999
if slide and canon then
  local frenteSlide = slide.CFrame.p.Z - slide.Size.Z * 0.5
  -- el cañon va ACOSTADO (rotado 90 grados en Y): su largo corre sobre Z y su
  -- largo es Size.X (asi funciona un cilindro en Roblox)
  local atrasCanon = canon.CFrame.p.Z + canon.Size.X * 0.5
  hueco = math.abs(frenteSlide - atrasCanon)
end
print("__ARMA__ piezas=" .. total .. "|hueco=" .. string.format("%.3f", hueco) ..
  "|largo=" .. string.format("%.2f", maxZ - minZ) ..
  "|alto=" .. string.format("%.2f", maxY - minY) ..
  "|grip=" .. tostring(arma.GripPos ~= nil))
"""
sal4 = subprocess.run([LUA, "-"], input=guion4, capture_output=True, text=True,
                      env=dict(os.environ, TOOLS=HERE), cwd=ROOT, timeout=600)
sal4 = subprocess.run([LUA, "-"], input=guion4, capture_output=True, text=True,
                      env=dict(os.environ, TOOLS=HERE), cwd=ROOT, timeout=600)
m4 = re.search(r"__ARMA__ (.*)", sal4.stdout + sal4.stderr)
if not m4:
    fallas += 1
    print("  FALLA  no se pudo armar la pistola")
    for linea in (sal4.stdout + sal4.stderr).strip().splitlines()[-6:]:
        print("         | " + linea[:150])
else:
    d4 = dict(kv.split("=") for kv in m4.group(1).split("|"))
    prob4 = []
    if int(d4.get("piezas", "0")) < 12:
        prob4.append("faltan piezas del arma (%s)" % d4.get("piezas"))
    try:
        hueco = float(d4.get("hueco", "99"))
    except ValueError:
        hueco = 99.0
    if hueco > 0.02:
        prob4.append("el CAÑON esta separado de la corredera por %.3f studs "
                     "(eso es el tubito gris flotando)" % hueco)
    if d4.get("grip") != "true":
        prob4.append("el arma no tiene agarre (GripPos)")
    if prob4:
        fallas += 1
        print("  FALLA  (la pistola)")
        for x in prob4:
            print("         - " + x)
    else:
        print("  OK     la pistola: %s piezas, el cañon pegado a la corredera "
              "(hueco %.3f)" % (d4.get("piezas"), hueco))
        print("         arma de %s de largo x %s de alto, con agarre propio"
              % (d4.get("largo"), d4.get("alto")))

print()
if fallas:
    print("FALLA: %d problema(s) de los reportes de las capturas" % fallas)
    sys.exit(1)
print("OK: calles fuera de los lotes, rotulos pintados y obras viejas borradas")
