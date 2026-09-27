#!/usr/bin/env python3
"""DIAGNOSTICO (v52): la van que "sale con las piezas una arriba de la otra".

Reporte del usuario con v52 pegada: "la van cuando esta dentro del garage esta
bien pero cuando la spawneo aparece como que las piezas una arriba de la otra
pero con bloques de aire".

Aqui se reproduce el camino REAL: Main de verdad, ciudad de verdad, jugador con
lote guardado (Slot=5, como el usuario), bodega mejorada (upgradeWarehouse x2),
y el boton "Sacar y conducir" (spawnVehicle con ySubir=true). Se avanza el
reloj 3 segundos y se mide la van PIEZA POR PIEZA (posiciones relativas al
chasis, anclaje, apiladas, traslapes) y se compara con la van ESTACIONADA.

NO es etapa de validate: es el estetoscopio para encontrar la causa.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")


def L(ruta):
    return strip_luau(open(os.path.join(ROOT, ruta), encoding="utf-8").read()) \
        .replace("goto cont", "_SKIP=true")


def lua(guion, timeout=900):
    e = dict(os.environ, TOOLS=HERE)
    return subprocess.run([LUA, "-"], input=guion, capture_output=True, text=True,
                          env=e, cwd=ROOT, timeout=timeout)


GUION = 'dofile("%s/mock.lua")\n' % HERE
GUION += '''
local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")
local mGen = Instance.new("ModuleScript") ; mGen.Name = "CityGenerator" ; mGen.Parent = sss
local mDat = Instance.new("ModuleScript") ; mDat.Name = "DataService"    ; mDat.Parent = sss
local mCfg = Instance.new("ModuleScript") ; mCfg.Name = "GameConfig"     ; mCfg.Parent = rs
local mMain = Instance.new("Script")      ; mMain.Name = "Main"          ; mMain.Parent = sss
local _cfg, _city, _data
rs.WaitForChild = function(s, n) return s:FindFirstChild(n) end
require = function(x)
  if x == mCfg then return _cfg end
  if x == mGen then return _city end
  if x == mDat then return _data end
  return {}
end
_cfg = (function() ''' + L("ReplicatedStorage/GameConfig.luau") + ''' end)()
_city = (function() ''' + L("ServerScriptService/CityGenerator.luau") + ''' end)()
_data = (function() ''' + L("ServerScriptService/DataService.luau") + ''' end)()
pcall(function() _city.Build() end)

local Players = game:GetService("Players")
local yo = Instance.new("Player") ; yo.Name = "Tester" ; yo.UserId = 4242

-- el usuario TIENE lote guardado: pre-existe Warehouse_4242 con Slot=5
local marca = Instance.new("Model") ; marca.Name = "Warehouse_4242"
local mp = Instance.new("Part") ; mp.Parent = marca ; marca:SetAttribute("Slot", 5)
marca.Parent = workspace

yo.Parent = Players
local hum = Instance.new("Humanoid")
local hrp = Instance.new("Part") ; hrp.Name = "HumanoidRootPart"
hrp.Position = Vector3.new(0, 8, 0) ; hrp.Size = Vector3.new(2, 2, 1) ; hrp.Parent = hrp and workspace
local chr = Instance.new("Model") ; chr.Name = "Tester"
hum.Parent = chr ; hrp.Parent = chr ; chr.PrimaryPart = hrp ; chr.Parent = workspace
yo.Character = chr
Players.GetPlayers = function() return {yo} end

local okMain, errMain = pcall(function() ''' + L("ServerScriptService/Main.luau") + ''' end)
print("__MAIN__ " .. tostring(okMain) .. " " .. tostring(errMain))

local T = 6
local function avanzar(dt)
  T = T + dt
  if task.__sched then task.__sched.advance(T) end
end
avanzar(6)

local RF = nil
for _, c in ipairs(rs:GetChildren()) do
  if c.Name == "Remotes" then
    for _, r in ipairs(c:GetChildren()) do if r.Name == "Action" then RF = r end end
  end
end
local perfil = _data.Get(yo)
if not perfil then print("__SINPERFIL__") return end
perfil.Cash = 5000000
if not perfil.Vehicles["van"] then perfil.Vehicles["van"] = true end

local wh = workspace:FindFirstChild("Warehouse_4242")
print("__LOTE__ slot=" .. tostring(wh and wh:GetAttribute("Slot") or "?") ..
      " tier=" .. tostring(perfil.WarehouseTier or 1))

local function dumpModel(tag, m)
  if not m then print(tag .. " NOHAY") return end
  local body = m.PrimaryPart
  local piezas = {}
  for _, d in ipairs(m:GetDescendants()) do
    if d:IsA("BasePart") then table.insert(piezas, d) end
  end
  local minx, maxx, miny, maxy, minz, maxz = 1e9, -1e9, 1e9, -1e9, 1e9, -1e9
  local sinAnclar = 0
  for _, p in ipairs(piezas) do
    local q = p.Position
    if q.X < minx then minx = q.X end ; if q.X > maxx then maxx = q.X end
    if q.Y < miny then miny = q.Y end ; if q.Y > maxy then maxy = q.Y end
    if q.Z < minz then minz = q.Z end ; if q.Z > maxz then maxz = q.Z end
    if not p.Anchored then sinAnclar = sinAnclar + 1 end
  end
  local apiladas, traslapes = 0, 0
  for i = 1, #piezas do
    for j = i + 1, #piezas do
      local a, b = piezas[i].Position, piezas[j].Position
      if math.abs(a.X - b.X) < 1.5 and math.abs(a.Z - b.Z) < 1.5 and math.abs(a.Y - b.Y) > 2 then
        apiladas = apiladas + 1
      end
      local pa, pb = piezas[i], piezas[j]
      if math.abs(a.X - b.X) < (pa.Size.X + pb.Size.X) / 2 - 0.2
        and math.abs(a.Y - b.Y) < (pa.Size.Y + pb.Size.Y) / 2 - 0.2
        and math.abs(a.Z - b.Z) < (pa.Size.Z + pb.Size.Z) / 2 - 0.2 then
        traslapes = traslapes + 1
      end
    end
  end
  print(string.format("%s piezas=%d sinAnclar=%d bbox=%.1f x %.1f x %.1f apiladas=%d traslapes=%d",
    tag, #piezas, sinAnclar, maxx - minx, maxy - miny, maxz - minz, apiladas, traslapes))
  if body then
    for i = 1, math.min(#piezas, 22) do
      local rel = body.CFrame:PointToObjectSpace(piezas[i].Position)
      print(string.format("%s   %-12s rel(%6.1f,%6.1f,%6.1f)  y=%5.2f",
        tag, piezas[i].Name, rel.X, rel.Y, rel.Z, piezas[i].Position.Y))
    end
  end
end

local function exitInfo(tag)
  local w = workspace:FindFirstChild("Warehouse_4242")
  if not w then print(tag .. " sinWarehouse") return end
  local e = w:FindFirstChild("GarageExit", true)
  local apron = w:FindFirstChild("BayApron", true)
  local piso = w:FindFirstChild("GarageFloor", true)
  -- PORTON CHICO DEL CAJON: existe? donde? tapa el hueco?
  local ds, gf = nil, nil
  for _, d in ipairs(w:GetDescendants()) do
    if d:IsA("BasePart") then
      if d.Name == "DoorSlab" and not ds then ds = d end
      if d.Name == "GarageFloor" and not gf then gf = d end
    end
  end
  if ds and gf then
    print(string.format("%s PORTON cajon: DoorSlab(%.1f,%.2f,%.1f) tam %.1fx%.1fx%.1f transparente=%s colisiona=%s | pisoCajon z %.1f..%.1f top=%.2f",
      tag, ds.Position.X, ds.Position.Y, ds.Position.Z, ds.Size.X, ds.Size.Y, ds.Size.Z,
      tostring(ds.Transparency), tostring(ds.CanCollide),
      gf.Position.Z - gf.Size.Z / 2, gf.Position.Z + gf.Size.Z / 2, gf.Position.Y + gf.Size.Y / 2))
  elseif gf then
    print(tag .. " PORTON cajon: SIN DoorSlab | pisoCajon z " ..
      string.format("%.1f..%.1f top=%.2f", gf.Position.Z - gf.Size.Z / 2, gf.Position.Z + gf.Size.Z / 2, gf.Position.Y + gf.Size.Y / 2))
  else
    print(tag .. " PORTON cajon: sin GarageFloor")
  end
  print(string.format("%s exit=%s apron=%s pisoTaller=%s",
    tag,
    e and string.format("(%.1f, %.2f, %.1f)", e.Position.X, e.Position.Y, e.Position.Z) or "NO",
    apron and string.format("(%.1f,%.1f,%.1f)+%.1fx%.2fx%.1f top=%.2f",
      apron.Position.X, apron.Position.Y, apron.Position.Z,
      apron.Size.X, apron.Size.Y, apron.Size.Z, apron.Position.Y + apron.Size.Y / 2) or "NO",
    piso and string.format("top=%.2f", piso.Position.Y + piso.Size.Y / 2) or "NO"))
end

local function cuentaParked(tag)
  local n, lista = 0, {}
  for _, d in ipairs(workspace:GetChildren()) do
    if d:IsA("Model") and string.sub(d.Name, 1, 7) == "Parked_" then
      n = n + 1 ; table.insert(lista, d)
    end
  end
  print(tag .. " parked=" .. n)
  for _, m in ipairs(lista) do dumpModel(tag .. " PARKED", m) end
end

-- ============ CASO A: nivel 1, boton "Sacar y conducir" ============
print("=== CASO A: tier 1, spawnVehicle(van, subir=true) ===")
exitInfo("A")
cuentaParked("A-antes")
if RF and RF.OnServerInvoke then
  local r = RF.OnServerInvoke(yo, "spawnVehicle", "van", true)
  if type(r) == "table" then print("__SPAWN_A__ " .. tostring(r.ok) .. " | " .. tostring(r.msg)) end
end
avanzar(3.0)
dumpModel("A CAR", workspace:FindFirstChild("Car_4242"))
cuentaParked("A-despues")
local asiento = workspace:FindFirstChild("Car_4242")
if asiento then
  local s = asiento:FindFirstChild("Seat")
  print("A ocupante=" .. tostring(s and s.Occupant or "sin asiento"))
end

-- ============ CASO B: bodega mejorada (tier 3) ============
print("=== CASO B: upgradeWarehouse x2 -> tier 3 ===")
if RF and RF.OnServerInvoke then
  local r1 = RF.OnServerInvoke(yo, "upgradeWarehouse")
  if type(r1) == "table" then print("__UP1__ " .. tostring(r1.ok) .. " | " .. tostring(r1.msg)) end
  avanzar(1.5)
  local r2 = RF.OnServerInvoke(yo, "upgradeWarehouse")
  if type(r2) == "table" then print("__UP2__ " .. tostring(r2.ok) .. " | " .. tostring(r2.msg)) end
  avanzar(1.5)
end
print("__TIER__ " .. tostring(perfil.WarehouseTier or 1))
exitInfo("B")
local viejo = workspace:FindFirstChild("Car_4242")
print("B carViejo=" .. tostring(viejo ~= nil))
if RF and RF.OnServerInvoke then
  local r = RF.OnServerInvoke(yo, "spawnVehicle", "van", true)
  if type(r) == "table" then print("__SPAWN_B__ " .. tostring(r.ok) .. " | " .. tostring(r.msg)) end
end
avanzar(3.0)
dumpModel("B CAR", workspace:FindFirstChild("Car_4242"))

-- ============ CASO C: el boton "Auto" del telefono (summonCar/PivotTo) ============
print("=== CASO C: summonCar (PivotTo) ===")
if RF and RF.OnServerInvoke then
  local r = RF.OnServerInvoke(yo, "summonCar")
  if type(r) == "table" then print("__SUMMON__ " .. tostring(r.ok) .. " | " .. tostring(r.msg)) end
end
avanzar(2.0)
dumpModel("C CAR", workspace:FindFirstChild("Car_4242"))

-- ============ CASO D: spawn de nueva cuenta (sin lote guardado) ============
print("=== CASO D: releer GarageExit tras upgrades ===")
exitInfo("D")
'''

r = lua(GUION)
salida = r.stdout + r.stderr
print(salida)
print("EXIT=%d" % r.returncode)
