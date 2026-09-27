#!/usr/bin/env python3
"""DIAGNOSTICO 3: el porton del cajon que 'no aparece'. Se prueba el ciclo
abrir/cerrar contra la bodega PIVOTEADA a su lote (como en el juego de verdad):
- donde apunta el atributo HomeCF (¿coordenadas locales pre-PivotTo?)
- que pasa con las piezas del porton cuando el jugador esta cerca / lejos
- el caso del primer tick (garageAbierto nil ~= false)
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

local wh = workspace:FindFirstChild("Warehouse_4242")
if not wh then print("NO WH") return end
print("slot=" .. tostring(wh:GetAttribute("Slot")))

local door = nil
for _, d in ipairs(wh:GetDescendants()) do
  if d:IsA("Model") and d.Name == "GarageDoor" then door = d break end
end
if not door then print("NO GarageDoor") return end
local slab = door:FindFirstChild("DoorSlab")
if not slab then print("NO DoorSlab") return end

local function pos(p) return string.format("(%.1f, %.2f, %.1f)", p.Position.X, p.Position.Y, p.Position.Z) end

print("slab ahora:      " .. pos(slab))
local homeCF = slab:GetAttribute("HomeCF")
print("HomeCF attr:     " .. (homeCF and pos(homeCF) or "NIL"))
print("delta HomeCF-ahora: " .. (homeCF and string.format("(%.1f, %.1f, %.1f)",
  homeCF.Position.X - slab.Position.X, homeCF.Position.Y - slab.Position.Y,
  homeCF.Position.Z - slab.Position.Z) or "?"))

-- el jugador se para FRENTE AL CAJON (a 6 studs del DoorSlab, en el patio)
hrp.Position = slab.Position + Vector3.new(0, 0, 6)
avanzar(2.0)
print("cerca (2s):      " .. pos(slab) .. "  (deberia estar ENROLLADO arriba)")

-- el jugador se va lejos
hrp.Position = slab.Position + Vector3.new(0, 0, 60)
avanzar(2.0)
print("lejos (2s):      " .. pos(slab) .. "  (deberia estar de vuelta EN EL CAJON)")
avanzar(2.0)
print("lejos (4s):      " .. pos(slab))
'''

e = dict(os.environ, TOOLS=HERE)
res = subprocess.run([LUA, "-"], input=GUION, capture_output=True, text=True, env=e, cwd=ROOT, timeout=900)
salida = res.stdout + res.stderr
for linea in salida.splitlines():
    if any(k in linea for k in ("slab", "HomeCF", "slot=", "MAIN", "NO ", "!!")):
        print(linea)
