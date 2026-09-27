#!/usr/bin/env python3
"""DIAGNOSTICO 4 (v53): (a) la bici que "aparece adentro de la bodega" — se
prueba en cada nivel de bodega, con el jugador en el spawn de la ciudad y
tambien adentro de la nave; (b) el grafo de calles de la CIUDAD — que calles
tocan cuales, para encontrar las esquinas desconectadas.
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
    return strip_luau(open(os.path.join(ROOT, ruta)).read()) \
        .replace("goto cont", "_SKIP=true")


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
local yo = Instance.new("Player") ; yo.Name = "Tester" ; yo.UserId = 4242 ; yo.Parent = Players
local hum = Instance.new("Humanoid")
local hrp = Instance.new("Part") ; hrp.Name = "HumanoidRootPart"
hrp.Position = Vector3.new(0, 8, 0) ; hrp.Size = Vector3.new(2, 2, 1) ; hrp.Parent = workspace
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
perfil.Cash = 5000000

local function dondeBici(tag)
  local bici = workspace:FindFirstChild("Bike_4242")
  if not (bici and bici.PrimaryPart) then print(tag .. " NOHAY") return end
  local p = bici.PrimaryPart.Position
  -- ¿esta adentro de alguna bodega (nave/cajon)? se busca la pieza mas alta
  -- justo encima de la bici: si hay TECHO, esta adentro de algo
  local rp = RaycastParams.new()
  rp.FilterType = Enum.RaycastFilterType.Exclude
  rp.FilterDescendantsInstances = { bici }
  local arriba = workspace:Raycast(Vector3.new(p.X, p.Y + 1, p.Z), Vector3.new(0, 60, 0), rp)
  local abajo = workspace:Raycast(Vector3.new(p.X, p.Y + 3, p.Z), Vector3.new(0, -60, 0), rp)
  print(string.format("%s bici=(%.1f, %.2f, %.1f) techo=%s piso=%s", tag, p.X, p.Y, p.Z,
    arriba and string.format("%s(%.1f y=%.1f)", arriba.Instance.Name, arriba.Position.X, arriba.Position.Y) or "LIBRE",
    abajo and string.format("%s(y=%.1f)", abajo.Instance.Name, abajo.Position.Y) or "nada"))
end

-- ===== (a) LA BICI EN CADA NIVEL, DESDE EL SPAWN Y DESDE ADENTRO DE LA NAVE =====
for intento = 1, 3 do
  if RF and RF.OnServerInvoke then
    RF.OnServerInvoke(yo, "spawnBike")
  end
  avanzar(1.0)
  dondeBici(string.format("join  tier=%d", perfil.WarehouseTier or 1))

  -- el jugador adentro de la nave (o donde este la bodega), re-invoca la bici
  local wh = workspace:FindFirstChild("Warehouse_4242")
  if wh and wh.PrimaryPart then
    hrp.Position = wh.PrimaryPart.Position + Vector3.new(0, 4, 0)
  end
  if RF and RF.OnServerInvoke then RF.OnServerInvoke(yo, "spawnBike") end
  avanzar(1.0)
  dondeBici(string.format("adentro tier=%d", perfil.WarehouseTier or 1))

  -- sube de nivel y repite
  if intento < 3 and RF and RF.OnServerInvoke then
    RF.OnServerInvoke(yo, "upgradeWarehouse")
    avanzar(1.5)
  end
end
print("__TIERFINAL__ " .. tostring(perfil.WarehouseTier or 1))

-- ===== (b) EL GRAFO DE CALLES DE LA CIUDAD =====
local calles = {}
for _, d in ipairs(workspace:GetDescendants()) do
  if d:IsA("BasePart") and (d.Name:sub(1, 5) == "RoadZ" or d.Name:sub(1, 5) == "RoadX") then
    table.insert(calles, d)
  end
end
print("__NCALLES__ " .. #calles)
for _, c in ipairs(calles) do
  local x0, x1 = c.Position.X - c.Size.X / 2, c.Position.X + c.Size.X / 2
  local z0, z1 = c.Position.Z - c.Size.Z / 2, c.Position.Z + c.Size.Z / 2
  -- cuantas otras calles toca esta (traslape de mas de 4 studs en ambos ejes)
  local toca = 0
  local lista = {}
  for _, o in ipairs(calles) do
    if o ~= c then
      local ox0, ox1 = o.Position.X - o.Size.X / 2, o.Position.X + o.Size.X / 2
      local oz0, oz1 = o.Position.Z - o.Size.Z / 2, o.Position.Z + o.Size.Z / 2
      if x0 < ox1 - 2 and x1 > ox0 + 2 and z0 < oz1 - 2 and z1 > oz0 + 2 then
        toca = toca + 1
        table.insert(lista, o.Name)
      end
    end
  end
  print(string.format("__CALLE__ %s x %.0f..%.0f z %.0f..%.0f toca=%d %s",
    c.Name, x0, x1, z0, z1, toca, table.concat(lista, ",")))
end
'''

e = dict(os.environ, TOOLS=HERE)
res = subprocess.run([LUA, "-"], input=GUION, capture_output=True, text=True, env=e, cwd=ROOT, timeout=900)
salida = res.stdout + res.stderr
for linea in salida.splitlines():
    if any(k in linea for k in ("bici=", "NOHAY", "TIER", "NCALLES", "CALLE", "MAIN", "!!")):
        print(linea)
