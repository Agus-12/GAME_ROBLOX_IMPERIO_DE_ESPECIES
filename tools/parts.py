#!/usr/bin/env python3
"""Construye la bodega de los 4 niveles bajo el mock y verifica que TODAS
   las partes que buscan Main y ClientUI sigan existiendo.

   Nacio porque en la v25 se borro la caja fuerte sin querer al reescribir
   una seccion, y ninguna validacion lo detecto."""
import subprocess, tempfile, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau
LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")

REQUIRED = [
    "Floor", "Wall1", "Wall2", "Wall3",          # estructura
    "PressBase", "Piston", "PressPad",           # prensa
    "UpgradePad", "UpgradeScreen", "Desk",       # computadora
    "VaultBody", "VaultPad", "VaultScreen",      # caja fuerte
    "SafePad", "Couch", "BedFrame",              # oficina
    "OfficeWall", "OfficeDoorJamb",              # puerta de la oficina
    "GarageDoorJamb", "GarageDoorHead",          # puerta del garaje
    "GateApron", "ApronRail",                    # rampa de la entrada
    "GarageFloor", "GarageExit", "Bay1", "Bay4", # garaje
    "GarageDoor", "DoorSlab", "DoorSlat",        # portones que suben (v29)
    "GarageWallLamp", "GarageThreshold",         # luces y umbral del taller
    "GarageTrigger", "GarageSign",               # marcador y letrero
    "OfficeWindowGlass", "OfficeWindowFrame",    # ventana DE VERDAD (v29)
    "OfficeWindowMullion", "OfficeWindowSill",
    "LotWallLamp", "GateSign", "LampPost",       # ambientacion exterior (v29)
    "LotApron", "Planter", "Bollard", "Dumpster",
    "RoofAC", "NaveLamp", "OfficeCanopy",
    "Plot1", "Plant", "Lookout",                 # cultivo y vigilante
    "Gate", "GateSensor",                        # porton
]

cfg  = strip_luau(open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau")).read())
city = strip_luau(open(os.path.join(ROOT, "ServerScriptService/CityGenerator.luau")).read())

names = "{" + ",".join('"%s"' % n for n in REQUIRED) + "}"
h = f'''
dofile("{HERE}/mock.lua")
local _cfg=(function() {cfg} end)()
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function() return "__CFG__" end
require=function(x) if x=="__CFG__" then return _cfg end return {{}} end
local _city=(function() {city} end)()

local function collect(inst, out, depth)
  if depth > 6 then return end
  for _, c in ipairs(inst:GetChildren()) do
    out[c.Name] = true
    collect(c, out, depth + 1)
  end
end

local REQ = {names}
local bad = 0
for tier = 1, 4 do
  local ok, wh = pcall(function() return _city.BuildWarehouse(tier) end)
  if not ok then
    print("  !! tier "..tier.." trono: "..tostring(wh)); bad = 1
  else
    local found = {{}}
    collect(wh, found, 0)
    local missing = {{}}
    for _, n in ipairs(REQ) do
      if not found[n] then table.insert(missing, n) end
    end
    if #missing == 0 then
      print("  tier "..tier..": todas las partes presentes")
    else
      print("  !! tier "..tier.." FALTAN: "..table.concat(missing, ", ")); bad = 1
    end
  end
end
if bad == 1 then print("FALLO") else print("OK") end
'''
t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False); t.write(h); t.close()
r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=180)
os.unlink(t.name)
print(r.stdout.strip())
if r.stderr: print("STDERR:", r.stderr[-700:])
sys.exit(1 if ("FALLO" in r.stdout or r.returncode != 0) else 0)
