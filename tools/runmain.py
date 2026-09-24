#!/usr/bin/env python3
"""Corre la cadena completa del SERVIDOR bajo el mock de la API de Roblox.
   Uso:  python3 tools/runmain.py"""
import subprocess, tempfile, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")
if not os.path.exists(LUA):
    sys.exit("Falta Lua. Corre primero:  bash tools/setup.sh")

def L(f):
    return strip_luau(open(os.path.join(ROOT, f)).read()).replace("goto cont", "_SKIP=true")

cfg  = L("ReplicatedStorage/GameConfig.luau")
city = L("ServerScriptService/CityGenerator.luau")
data = L("ServerScriptService/DataService.luau")
main = L("ServerScriptService/Main.luau")

h = f'''
dofile("{HERE}/mock.lua")
local _cfg=(function() {cfg} end)()
print("Sounds en config: "..tostring(_cfg.Sounds ~= nil))
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
  return {{}} end
_city=(function() {city} end)(); print("CityGenerator OK")
_data=(function() {data} end)(); print("DataService OK")
for t=1,4 do
  local o,e=pcall(function() return _city.BuildWarehouse(t) end)
  print(o and ("  Warehouse tier "..t.." OK") or ("  !! tier "..t..": "..tostring(e)))
end
local o2,e2=pcall(function() _city.SetupLighting() end)
print(o2 and "  SetupLighting OK" or ("  !! SetupLighting: "..tostring(e2)))
local ok,err=pcall(function() {main} end)
print(ok and ">>> Main.luau CORRIO COMPLETO <<<" or ("!! Main TRONO: "..tostring(err)))
-- deja correr los hilos del servidor con el reloj virtual: asi se ejecutan los
-- bucles de fondo (portones, plantas, redadas) y sus errores SE VEN
if task.__sched then
  task.__sched.advance(3)
  print("  (hilos del servidor: 3 s virtuales corridos)")
end
'''
t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False); t.write(h); t.close()
r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=180)
os.unlink(t.name)
salida = r.stdout[-3000:]
print(salida)
if r.stderr: print("STDERR:", r.stderr[-900:])
# OJO: antes este script salia con codigo 0 aunque Main tronara, asi que
# validate.sh daba la etapa por buena. Ahora falla de verdad.
malo = ("!!" in salida) or ("CORRIO COMPLETO" not in salida) or r.returncode != 0
if r.stderr: malo = True
if malo:
    print("  FALLA  el servidor trono en runtime (ver arriba)")
    sys.exit(1)
