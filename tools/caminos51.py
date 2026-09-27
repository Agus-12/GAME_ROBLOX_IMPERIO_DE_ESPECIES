#!/usr/bin/env python3
"""ETAPA 26 (v51): LOS CAMINOS DE LOS LOTES Y LA VAN QUE SALE BIEN.

Lo que reporto y pidio el usuario:
  * "la van al spawnearla afuera sale mal" -> el cajon no tenia PISO enfrente
    (solo pasto, 1.5 studs mas abajo): el coche salia colgando y se asentaba en
    el pasto. Ahora el cajon tiene su patio (BayApron) con rampa, y el coche
    nace a nivel de ese patio.
  * "quiero que los conectes con calles a la ciudad ... haciendo el trazo por
    cada lote de manera correcta" -> 4 calles (una por hilera, justo en la linea
    de enfrente de los 5 lotes), 2 caminos norte-sur (el principal baja de la
    calle de la ciudad; el de en medio cierra el circuito), 20 rampas de entrada
    (una por lote) y faroles.

v52: el usuario reporto "la bodega (vecina) de en medio esta como al ras de
la calle" — el patio del frente CREE con el nivel de la bodega (nivel 4 llega
a +101 del centro) y las calles de la v51 (+61..+81) quedaban DEBAJO de los
patios niveles 2-4. Ahora las calles van a +121 (sur en +111: 10 studs mas
alla del patio mas grande), los caminos norte-sur van centrados en el hueco
real entre bodegas nivel 4 (13.5 al poniente de la linea de lotes) y las
rampas bajan al pasto. NUEVO chequeo: ninguna calle/rampa toca una bodega de
ningun nivel (se construyen los 4 niveles en los lotes 1..4 y se miden).

Aqui se mide TODO con el mundo real armado por el simulador: ni un numero a mano.
"""
import os
import re
import sys
import subprocess
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau                    # noqa: E402

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")


def L(ruta):
    return strip_luau(open(os.path.join(ROOT, ruta), encoding="utf-8").read()) \
        .replace("goto cont", "_SKIP=true")


print("=== 26. LOS CAMINOS DE LOS LOTES Y LA VAN QUE MIDE BIEN AL SALIR (v51) ===")

cuenta = {}
guion = 'dofile("%s/mock.lua")\n' % HERE
guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
guion += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function() ''' + L("ServerScriptService/CityGenerator.luau") + ''' end)()
local mundo = City.Build()
local L_ = _cfg.WarehouseLots

local c = {}
for _, d in ipairs(mundo:GetDescendants()) do
  if d:IsA("BasePart") then c[d.Name] = (c[d.Name] or 0) + 1 end
end

-- ===== 1) los caminos =====
print(string.format("__CONTA__ calleshilera=%d caminosNS=%d rampas=%d faroles=%d",
  (c.RoadLotesZ1 or 0) + (c.RoadLotesZ2 or 0) + (c.RoadLotesZ3 or 0) + (c.RoadLotesZ4 or 0),
  (c.RoadLotesX or 0) + (c.RoadLotesX2 or 0), c.RoadLoteRamp or 0, c.LightPole or 0))

-- las 4 calles de hilera: a +117 del centro de SU hilera (v52: la v51 las
-- ponia a +71 y los patios de las bodegas niveles 2-4 llegan hasta +101,
-- o sea que la calle quedaba DEBAJO del patio: "la bodega de en medio esta
-- como al ras de la calle"). Cubren los 5 lotes.
local malas = {}
for r = 1, 4 do
  local d = mundo:FindFirstChild("RoadLotesZ" .. r, true)
  if not d then
    table.insert(malas, "falta la calle de la hilera " .. r)
  else
    local esperado = L_.Origin.Z - (r - 1) * L_.SpacingZ + 121
    if math.abs(d.Position.Z - esperado) > 0.6 then
      table.insert(malas, string.format("la calle de la hilera %d esta en z=%.1f y deberia ir en %.1f",
        r, d.Position.Z, esperado))
    end
    local x0, x1 = d.Position.X - d.Size.X / 2, d.Position.X + d.Size.X / 2
    local lx0 = L_.Origin.X - 140
    local lx1 = L_.Origin.X + (L_.PerRow - 1) * L_.SpacingX + 140
    if x0 > lx0 or x1 < lx1 then
      table.insert(malas, string.format("la calle de la hilera %d no cubre los 5 lotes (x %.0f..%.0f)", r, x0, x1))
    end
  end
end
print("__MALAS__ " .. (#malas == 0 and "ninguna" or table.concat(malas, " ; ")))

-- los dos caminos norte-sur y su union con la ciudad
local bx = mundo:FindFirstChild("RoadLotesX", true)
local mx = mundo:FindFirstChild("RoadLotesX2", true)
if bx then
  print(string.format("__PRINCIPAL__ x=%.0f z %.0f..%.0f", bx.Position.X, bx.Position.Z - bx.Size.Z / 2, bx.Position.Z + bx.Size.Z / 2))
end
if mx then
  print(string.format("__MEDIO__ x=%.0f z %.0f..%.0f", mx.Position.X, mx.Position.Z - mx.Size.Z / 2, mx.Position.Z + mx.Size.Z / 2))
end
-- la calle de la ciudad mas al sur (para ver si el camino principal la toca)
local pegado = false
local calleCiudad = mundo:FindFirstChild("RoadZ0", true)
if bx and calleCiudad then
  local a0, a1 = bx.Position.Z - bx.Size.Z / 2, bx.Position.Z + bx.Size.Z / 2
  local b0, b1 = calleCiudad.Position.Z - calleCiudad.Size.Z / 2, calleCiudad.Position.Z + calleCiudad.Size.Z / 2
  pegado = (a0 <= b1 and a1 >= b0)
end
print("__UNIDO__ " .. tostring(pegado))
-- v53: el camino de EN MEDIO tambien tiene que tocar la calle de la ciudad
-- (antes terminaba en la calle de la primera hilera y los lotes del lado
-- oriente tenian que dar toda la vuelta por el principal)
local pegado2 = false
if mx and calleCiudad then
  local a0, a1 = mx.Position.Z - mx.Size.Z / 2, mx.Position.Z + mx.Size.Z / 2
  local b0, b1 = calleCiudad.Position.Z - calleCiudad.Size.Z / 2, calleCiudad.Position.Z + calleCiudad.Size.Z / 2
  pegado2 = (a0 <= b1 and a1 >= b0)
end
print("__UNIDO2__ " .. tostring(pegado2))

-- ===== 2) ninguna calle se mete a la parte de ADENTRO de un lote =====
-- (la calle SI pasa por el frente del lote: ahi esta su patio y sus bolardos.
--  Lo que no puede pasar es que cruce la nave, el taller o el patio del fondo,
--  o sea z < centro + 54)
local estorbos = {}
for slot = 1, L_.MaxSlots do
  local col = (slot - 1) % L_.PerRow
  local row = math.floor((slot - 1) / L_.PerRow)
  local lx = L_.Origin.X + col * L_.SpacingX
  local cz = L_.Origin.Z - row * L_.SpacingZ
  for _, d in ipairs(mundo:GetDescendants()) do
    if d:IsA("BasePart") and (d.Name:sub(1, 9) == "RoadLotes" or d.Name == "RoadLoteRamp") then
      local dx0, dx1 = d.Position.X - d.Size.X / 2, d.Position.X + d.Size.X / 2
      local dz0, dz1 = d.Position.Z - d.Size.Z / 2, d.Position.Z + d.Size.Z / 2
      if dx0 < lx + 140 and dx1 > lx - 140 and dz0 < cz + 54 and dz1 > cz - 80 then
        table.insert(estorbos, string.format("%s en el lote %d", d.Name, slot))
        break
      end
    end
  end
end
print("__ESTORBOS__ " .. (#estorbos == 0 and "ninguno" or table.concat(estorbos, " ; ")))

-- ===== 2b) NINGUNA calle toca la bodega de NINGUN nivel =====
-- (v52: este chequeo faltaba y por eso la v51 salio con la calle debajo de
-- los patios: el patio del frente CREE con el nivel. Se construye cada
-- nivel en los lotes 1..4 y se revisa que ningun camino la toque, con 2
-- studs de margen. Nace del reporte real: "la bodega de en medio esta como
-- al ras de la calle").
local tocan = {}
for tier = 1, 4 do
  for lote = 1, 4 do
    local col = (lote - 1) % L_.PerRow
    local bx = L_.Origin.X + col * L_.SpacingX
    local m2 = City.BuildWarehouse(tier)
    m2:PivotTo(CFrame.new(bx, L_.Origin.Y, L_.Origin.Z))
    m2.Parent = workspace
    local x0, x1, z0, z1 = 1e9, -1e9, 1e9, -1e9
    for _, d in ipairs(m2:GetDescendants()) do
      if d:IsA("BasePart") then
        x0 = math.min(x0, d.Position.X - d.Size.X / 2)
        x1 = math.max(x1, d.Position.X + d.Size.X / 2)
        z0 = math.min(z0, d.Position.Z - d.Size.Z / 2)
        z1 = math.max(z1, d.Position.Z + d.Size.Z / 2)
      end
    end
    for _, d in ipairs(mundo:GetDescendants()) do
      if d:IsA("BasePart") and (d.Name:sub(1, 9) == "RoadLotes" or d.Name == "RoadLoteRamp") then
        local rx0 = d.Position.X - d.Size.X / 2
        local rx1 = d.Position.X + d.Size.X / 2
        local rz0 = d.Position.Z - d.Size.Z / 2
        local rz1 = d.Position.Z + d.Size.Z / 2
        if rx0 < x1 + 2 and rx1 > x0 - 2 and rz0 < z1 + 2 and rz1 > z0 - 2 then
          table.insert(tocan, string.format("%s toca la bodega nivel %d en el lote %d (frente z=%.0f contra calle z=%.0f)",
            d.Name, tier, lote, z1 - L_.Origin.Z, rz0 - L_.Origin.Z))
        end
      end
    end
    m2:Destroy()
  end
end
print("__TOCAN__ " .. (#tocan == 0 and "ninguna" or table.concat(tocan, " ; ")))

-- ===== 3) el patio del cajon y la van =====
local base = Vector3.new(L_.Origin.X, L_.Origin.Y, L_.Origin.Z)
local m = City.BuildWarehouse(1)
m:PivotTo(CFrame.new(base))
m.Parent = workspace

local pad = m:FindFirstChild("BayApron", true)
local exit = m:FindFirstChild("GarageExit", true)
local door = m:FindFirstChild("DoorSlab", true)
print(string.format("__PATIO_CAJON__ x=%.1f z %.1f..%.1f tope_y=%.2f | salida z=%.1f | porton z=%.1f",
  pad.Position.X, pad.Position.Z - pad.Size.Z / 2, pad.Position.Z + pad.Size.Z / 2,
  pad.Position.Y + pad.Size.Y / 2, exit.Position.Z, door.Position.Z))

-- la van, tal cual la pone Main: baseCF = salida + 5 centesimas
local info
for _, v in ipairs(_cfg.Vehicles) do if v.Id == "van" then info = v end end
local baseCF = CFrame.new(exit.Position.X, exit.Position.Y + 0.05, exit.Position.Z)
local okv, van = pcall(function() return City.BuildCar(info, baseCF, false) end)
if okv and van then
  local minY, minZ, maxZ, maxX, minX = 1e9, 1e9, -1e9, -1e9, 1e9
  for _, d in ipairs(van:GetDescendants()) do
    if d:IsA("BasePart") then
      minY = math.min(minY, d.Position.Y - d.Size.Y / 2)
      minZ = math.min(minZ, d.Position.Z - d.Size.Z / 2)
      maxZ = math.max(maxZ, d.Position.Z + d.Size.Z / 2)
      minX = math.min(minX, d.Position.X - d.Size.X / 2)
      maxX = math.max(maxX, d.Position.X + d.Size.X / 2)
    end
  end
  -- ¿toda la van cae sobre el patio? (nada de pasto ni de rampa)
  local pz0, pz1 = pad.Position.Z - pad.Size.Z / 2, pad.Position.Z + pad.Size.Z / 2
  print(string.format("__VAN__ z %.1f..%.1f (patio %.1f..%.1f) x %.1f..%.1f (patio %.1f..%.1f) ruedas_y=%.2f (patio tope=%.2f)",
    minZ, maxZ, pz0, pz1, minX, maxX,
    pad.Position.X - pad.Size.X / 2, pad.Position.X + pad.Size.X / 2,
    minY, pad.Position.Y + pad.Size.Y / 2))
  print(string.format("__VAN_EXIT__ puerta_z=%.1f van_trasera_z=%.1f (debe quedar del lado del patio: mayor que la puerta)",
    door.Position.Z, minZ))
else
  print("__VAN__ no se pudo armar: " .. tostring(van))
end
'''
t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
t.write(guion)
t.close()
r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=900)
os.unlink(t.name)
salida = r.stdout + r.stderr
for linea in salida.splitlines():
    if linea.startswith("__"):
        print("  " + linea)

fallas = 0
problemas = []


def kv(txt):
    return dict(p.split("=", 1) for p in txt.replace("|", " ").split() if "=" in p)


m1 = re.search(r"__CONTA__ (.+)", salida)
if not m1:
    fallas += 1
    print("  FALLA  no se pudo armar el mundo con los caminos")
    for x in salida.strip().splitlines()[-6:]:
        print("         | " + x[:150])
else:
    e = kv(m1.group(1))
    if int(e["calleshilera"]) != 4:
        problemas.append("hay %s calles de hilera (deben ser 4)" % e["calleshilera"])
    if int(e["caminosNS"]) != 2:
        problemas.append("hay %s caminos norte-sur (deben ser 2)" % e["caminosNS"])
    if int(e["rampas"]) != 20:
        problemas.append("hay %s rampas de entrada (deben ser 20: una por lote)" % e["rampas"])
    if int(e["faroles"]) < 100:
        problemas.append("no hay faroles en los caminos (%s)" % e["faroles"])
m2 = re.search(r"__MALAS__ (.+)", salida)
if not m2 or m2.group(1) != "ninguna":
    problemas.append("calles mal puestas: " + (m2.group(1) if m2 else "?"))
m3 = re.search(r"__UNIDO__ (.+)", salida)
if not m3 or m3.group(1).strip() != "true":
    problemas.append("el camino principal NO toca la calle de la ciudad")
m3b = re.search(r"__UNIDO2__ (.+)", salida)
if not m3b or m3b.group(1).strip() != "true":
    problemas.append("el camino de en medio NO toca la calle de la ciudad (v53): "
                     "los lotes del lado oriente siguen sin salida directa")
m4 = re.search(r"__ESTORBOS__ (.+)", salida)
if not m4 or m4.group(1) != "ninguno":
    problemas.append("calles metidas dentro de un lote: " + (m4.group(1) if m4 else "?"))
m5 = re.search(r"__TOCAN__ (.+)", salida)
if not m5 or m5.group(1).strip() != "ninguna":
    problemas.append("calles tocando bodegas (v52): " + (m5.group(1) if m5 else "?"))
v1 = re.search(r"__VAN__ z ([-\d.]+)\.\.([-\d.]+) \(patio ([-\d.]+)\.\.([-\d.]+)\) x ([-\d.]+)\.\.([-\d.]+) \(patio ([-\d.]+)\.\.([-\d.]+)\) ruedas_y=([-\d.]+) \(patio tope=([-\d.]+)\)", salida)
if not v1:
    problemas.append("no se pudo medir la van al salir")
else:
    vminz, vmaxz = float(v1.group(1)), float(v1.group(2))
    pz0, pz1 = float(v1.group(3)), float(v1.group(4))
    vminx, vmaxx = float(v1.group(5)), float(v1.group(6))
    px0, px1 = float(v1.group(7)), float(v1.group(8))
    ruedas, ptop = float(v1.group(9)), float(v1.group(10))
    if vminz < pz0 - 0.3 or vmaxz > pz1 + 0.3:
        problemas.append("la van se sale del patio del cajon (z %.1f..%.1f contra %.1f..%.1f): "
                         "parte queda sobre el pasto o la rampa" % (vminz, vmaxz, pz0, pz1))
    if vminx < px0 - 0.3 or vmaxx > px1 + 0.3:
        problemas.append("la van se sale del patio de lado (x)")
    if abs(ruedas - ptop) > 0.4:
        problemas.append("las ruedas de la van no quedan sobre el piso del patio (y=%.2f contra tope=%.2f)"
                         % (ruedas, ptop))
v2 = re.search(r"__VAN_EXIT__ puerta_z=([-\d.]+) van_trasera_z=([-\d.]+)", salida)
if not v2:
    problemas.append("no se pudo medir si la van queda fuera del cajon")
else:
    puerta, trasera = float(v2.group(1)), float(v2.group(2))
    if trasera < puerta:
        problemas.append("la van queda metida en el cajon (su parte de atras en z=%.1f, el porton en z=%.1f)"
                         % (trasera, puerta))

# ===== 4) Main tiene que nacer la van a la altura del patio (no fija) =====
# La etapa arma la van POR SU CUENTA con exit + 0.05; eso solo prueba la
# geometria del patio, NO que Main lo haga asi (lo destapo el alreves51: con
# la altura fija de antes la etapa pasaba igual). Se revisa el codigo real,
# con el mismo truco que usa mapa.py con la bici: si alguien regresa a la
# altura fija, aqui truena.
src_main = open(os.path.join(ROOT, "ServerScriptService/Main.luau"), encoding="utf-8").read()
VAN_BUENA = "local baseCF = CFrame.new(sp.X, sp.Y + 0.05, sp.Z)"
VAN_MALA = "CFrame.new(sp.X, 2.05, sp.Z)"
if src_main.count(VAN_BUENA) != 1:
    problemas.append("Main no nace la van a la altura del GarageExit (falta: " + VAN_BUENA + ")")
if VAN_MALA in src_main:
    problemas.append("Main vuelve a usar la altura fija 2.05 para la van (la deja colgada)")

if problemas:
    fallas += 1
    print("  FALLA  (caminos / van)")
    for x in problemas:
        print("         - " + x)
else:
    print("  OK     los 20 lotes quedan conectados: 4 calles de hilera justo en su linea de "
          "enfrente, 2 caminos norte-sur (uno baja de la calle de la ciudad y la toca), "
          "20 rampas de entrada y faroles; y la van sale apoyada en el patio del cajon, "
          "completa y fuera del taller")

if fallas:
    print("\nFALLA: los caminos o la van (%d problema(s))" % fallas)
    sys.exit(1)
print("\nOK: los caminos conectan los lotes con la ciudad y la van sale bien")
