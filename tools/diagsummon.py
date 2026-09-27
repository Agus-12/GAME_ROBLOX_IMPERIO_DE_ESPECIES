#!/usr/bin/env python3
"""DIAGNOSTICO 2: que hace el heartbeat de hacerConducible tras un PivotTo
(el camino de summonCar, el boton 'Auto' del telefono)."""
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
if not perfil.Vehicles["van"] then perfil.Vehicles["van"] = true end

local function posCar()
  local car = workspace:FindFirstChild("Car_4242")
  if not car or not car.PrimaryPart then return "NOHAY" end
  local p = car.PrimaryPart.Position
  return string.format("(%.1f, %.2f, %.1f)", p.X, p.Y, p.Z)
end

-- spawn por el boton del cajon
RF.OnServerInvoke(yo, "spawnVehicle", "van", false)
avanzar(1.0)
print("tras spawn+1s:  " .. posCar())

-- el jugador se va lejos (a la ciudad) y le pica "Auto" al telefono
hrp.Position = Vector3.new(100, 8, -100)
local r = RF.OnServerInvoke(yo, "summonCar")
print("__SUMMON__ " .. tostring(type(r) == "table" and r.ok) .. " | " .. tostring(type(r) == "table" and r.msg))
print("justo tras summon: " .. posCar())
for k = 1, 12 do
  avanzar(1 / 30)
  print(string.format("tick %2d (t=%.2f): %s", k, k / 30.0, posCar()))
end
avanzar(2.0)
print("tras 2s mas:     " .. posCar())
'''

e = dict(os.environ, TOOLS=HERE)
res = subprocess.run([LUA, "-"], input=GUION, capture_output=True, text=True, env=e, cwd=ROOT, timeout=900)
salida = res.stdout + res.stderr
for linea in salida.splitlines():
    if "!!" in linea or "tick" in linea or "tras" in linea or "SUMMON" in linea or "__MAIN__" in linea:
        print(linea)
