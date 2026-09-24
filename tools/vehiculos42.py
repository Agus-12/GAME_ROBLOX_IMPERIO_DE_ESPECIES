#!/usr/bin/env python3
"""v42: prueba de la BICICLETA y del AUTO DEL GARAJE (lo que reporto el jugador).

   Que dijo el jugador:
     * "al moverme los rines se quedan ahi"  -> la rueda completa (goma, aro,
       maza y rayos) tiene que viajar con la bici.
     * "en el celular el letrero 'E para conducir' no tiene sentido: solo me
       acerco y se sube"  -> en tactil el letrero se apaga y el personaje se
       sube solo al acercarse.
     * "me subo y no me deja andar"  -> el asiento tiene que ACEPTAR controles
       (Torque y TurnSpeed en cero = no responde ni con los botones del celular).
     * "el auto del garaje sale con las llantas como plato y no me deja andar"
       -> rin = aro + maza + rayos, y "Sacar y conducir" tiene que dejar el auto
       AFUERA del cajon y con el jugador sentado.

   Esta etapa corre el SERVIDOR de mentira y revisa eso.
"""
import subprocess, tempfile, sys, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau
LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")


def L(ruta):
    return strip_luau(open(os.path.join(ROOT, ruta)).read()).replace("goto cont", "_SKIP=true")


cfg, city, data, main = (L("ReplicatedStorage/GameConfig.luau"),
                         L("ServerScriptService/CityGenerator.luau"),
                         L("ServerScriptService/DataService.luau"),
                         L("ServerScriptService/Main.luau"))

GUION = '''local TACTIL = @@TACTIL@@          -- 1 = celular, 0 = compu
dofile("@@TOOLS@@/mock.lua")
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
_cfg = (function() @@CFG@@ end)()
_city = (function() @@CITY@@ end)()
_data = (function() @@DATA@@ end)()

local Players = game:GetService("Players")
local yo = Instance.new("Player") ; yo.Name = "Tester" ; yo.UserId = 4242 ; yo.Parent = Players
local hum = Instance.new("Humanoid")
local hrp = Instance.new("Part") ; hrp.Name = "HumanoidRootPart" ; hrp.Position = Vector3.new(0, 3, 0)
hrp.Size = Vector3.new(2, 2, 1) ; hrp.Parent = workspace
local chr = Instance.new("Model") ; chr.Name = "Tester"
hum.Parent = chr ; hrp.Parent = chr ; chr.PrimaryPart = hrp ; chr.Parent = workspace
yo.Character = chr
-- TACTIL=1 => celular (sin teclado). Lo pone la prueba segun el caso.
yo:SetAttribute("Tactil", TACTIL == 1)
Players.GetPlayers = function() return {yo} end

local okMain, errMain = pcall(function() @@MAIN@@ end)
print("__MAIN__ " .. tostring(okMain) .. " " .. tostring(errMain))

local T = 6
local function avanzar(dt)
  T = T + dt
  if task.__sched then task.__sched.advance(T) end
end
avanzar(6)

-- ===== BICICLETA =====
local bici = workspace:FindFirstChild("Bike_4242")
local torque, turn, promptCerca, promptLejos = -1, -1, 0, 0
local goma, aro, maza, rayos = 0, 0, 0, 0
local goma, aro, maza, rayos = 0, 0, 0, 0
local tieneTodo = false
if bici then
  local seat = bici:FindFirstChild("Seat", true)
  if seat then
    torque = tonumber(seat.Torque) or -1
    turn = tonumber(seat.TurnSpeed) or -1
  end
  -- piezas de la rueda: tienen que EXISTIR (no solo la goma)
  for _, d in ipairs(bici:GetDescendants()) do
    if string.find(d.Name, "Wheel") then goma = goma + 1 end
    if d.Name == "Rim" then aro = aro + 1 end
    if d.Name == "Hub" then maza = maza + 1 end
    if d.Name == "Spoke" then rayos = rayos + 1 end
  end
  tieneTodo = (goma >= 2 and aro >= 2 and maza >= 2 and rayos >= 6)
  -- letrero: se apaga en tactil. Y el prompt solo se prende cuando estas LEJOS
  -- (asi no te sale el letrero estorbando parado al lado de la bici)
  for _, d in ipairs(bici:GetDescendants()) do
    if d:IsA("ProximityPrompt") then
      promptLejos = promptLejos + (d.Enabled and 1 or 0)
    end
  end
end
local detalle = {}
if bici then
  for _, d in ipairs(bici:GetDescendants()) do
    if d:IsA("ProximityPrompt") then
      table.insert(detalle, tostring(d.Name) .. "=" .. tostring(d.Enabled))
    end
  end
end
print("__BICI__ existe=" .. tostring(bici ~= nil) .. " torque=" .. torque .. " turn=" .. turn ..
  " rueda=" .. tostring(tieneTodo) .. " prompts=" .. promptLejos ..
  " tactil=" .. tostring(yo:GetAttribute("Tactil")) .. " detalle=" .. table.concat(detalle, ",") ..
  " piezas=" .. tostring(goma) .. "/" .. tostring(aro) .. "/" .. tostring(maza) .. "/" .. tostring(rayos))

-- ===== AUTO DEL GARAJE =====
local perfil = _data.Get(yo)
local id = nil
for _, v in ipairs(_cfg.Vehicles) do
  if perfil.Vehicles[v.Id] then id = v.Id break end
end
if not id then
  id = _cfg.Vehicles[1].Id
  perfil.Vehicles[id] = true
end
local RF = nil
for _, c in ipairs(rs:GetChildren()) do
  if c.Name == "Remotes" then
    for _, r in ipairs(c:GetChildren()) do if r.Name == "Action" then RF = r end end
  end
end
local salida = "sin-remote"
if RF and RF.OnServerInvoke then
  local r = RF.OnServerInvoke(yo, "spawnVehicle", id, true)
  if type(r) == "table" then salida = tostring(r.ok) .. " | " .. tostring(r.msg) end
end
avanzar(3)

local auto = workspace:FindFirstChild("Car_4242")
local yAuto, salidaExiste, ySalida, sentado = -1, false, -1, false
if auto and auto.PrimaryPart then
  yAuto = auto.PrimaryPart.Position.Y
  local seat = auto:FindFirstChild("Seat")
  if seat then sentado = (seat.Occupant ~= nil) end
end
local wh = workspace:FindFirstChild("Warehouse_4242")
if wh then
  local ex = wh:FindFirstChild("GarageExit", true)
  if ex then salidaExiste = true ; ySalida = ex.Position.Y end
end
-- rines del auto: aro, maza y rayos, no un disco del tamano de la llanta
local aroA, mazaA, rayosA, gomaA = 0, 0, 0, 0
if auto then
  for _, d in ipairs(auto:GetDescendants()) do
    if d.Name == "Rim" then aroA = aroA + 1 end
    if d.Name == "Hub" then mazaA = mazaA + 1 end
    if d.Name == "Spoke" then rayosA = rayosA + 1 end
    if d.Name == "Wheel" then gomaA = gomaA + 1 end
  end
end
print("__AUTO__ " .. salida .. " | existe=" .. tostring(auto ~= nil) .. " rines=" ..
  gomaA .. "/" .. aroA .. "/" .. mazaA .. "/" .. rayosA .. " sentado=" .. tostring(sentado))

-- el auto NO puede quedar dentro del cajon: se mide contra el PISO DEL GARAJE
-- (el cajon real), no contra una corazonada de coordenadas.
local dentroDelCajon = false
if auto and auto.PrimaryPart and wh then
  local piso = wh:FindFirstChild("GarageFloor", true)
  if piso then
    local ap = auto.PrimaryPart.Position
    local pp = piso.Position
    local dx = math.abs(ap.X - pp.X)
    local dz = math.abs(ap.Z - pp.Z)
    if dx < piso.Size.X / 2 and dz < piso.Size.Z / 2 then dentroDelCajon = true end
  end
end
print("__PUESTO__ dentroDelCajon=" .. tostring(dentroDelCajon) .. " yAuto=" .. tostring(yAuto))
'''


def corre(tactil, parche_main=None):
    m_main = main
    if parche_main:
        m_main = main.replace(parche_main[0], parche_main[1])
    g = (GUION.replace("@@TOOLS@@", HERE)
              .replace("@@CFG@@", cfg).replace("@@CITY@@", city)
              .replace("@@DATA@@", data).replace("@@MAIN@@", m_main)
              .replace("@@TACTIL@@", str(tactil)))
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
    t.write(g)
    t.close()
    try:
        return subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=300)
    finally:
        os.unlink(t.name)


print("=== 17. BICICLETA Y AUTO DEL GARAJE (bici que rueda y auto que sale) ===")
fallas = 0
res = {}
for etiqueta, tactil in (("CELULAR (tactil)", 1), ("COMPU (teclado)", 0)):
    r = corre(tactil)
    sal = r.stdout
    if "--verbose" in sys.argv or r.returncode != 0:
        print("  --- %s ---" % etiqueta)
        print("  " + (sal.strip().replace("\n", "\n  ")[:1000] or r.stderr[:400]))

    def lee(tag):
        m = re.search(r"__%s__ (.*)" % tag, sal)
        return m.group(1).strip() if m else None

    b = lee("BICI")
    res[etiqueta] = (b, lee("AUTO"), lee("PUESTO"))
    if b is None:
        print("  FALLA [%s] no pude leer la bici" % etiqueta)
        fallas += 1
        continue
    m = re.match(r"existe=(\w+) torque=(-?\d+) turn=(-?\d+) rueda=(\w+) prompts=(\d+)", b)
    if not m:
        print("  FALLA [%s] formato raro de la bici: %s" % (etiqueta, b))
        fallas += 1
        continue
    existe, torque, turn, rueda, prompts = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4), int(m.group(5))
    ok = (existe == "true" and torque > 0 and turn > 0 and rueda == "true")
    esperado = 0 if tactil == 1 else 1
    okp = (prompts == esperado)
    print("  %s [%s] bici: existe=%s, asiento torque=%d/turn=%d, rueda completa=%s, letreros encendidos=%d (esperaba %d)"
          % ("OK   " if (ok and okp) else "FALLA", etiqueta, existe, torque, turn, rueda, prompts, esperado))
    if not (ok and okp):
        fallas += 1

a = lee("AUTO")
p = lee("PUESTO")
if a is None or p is None:
    print("  FALLA  no pude leer el auto del garaje")
    fallas += 1
else:
    m = re.match(r"(\w+) \|.*\| existe=(\w+) rines=(\d+)/(\d+)/(\d+)/(\d+) sentado=(\w+)", a)
    if not m:
        print("  FALLA  formato raro del auto: %s" % a)
        fallas += 1
    else:
        salida, existe, goma, aro, maza, rayos, sentado = m.groups()
        ok = (salida == "true" and existe == "true" and int(goma) >= 4 and int(aro) >= 4
              and int(maza) >= 4 and int(rayos) >= 20 and sentado == "true")
        print("  %s sacar el auto del cajon: %s | llantas=%s gomas, %s aros, %s mazas, %s rayos | te sienta=%s"
              % ("OK   " if ok else "FALLA", salida, goma, aro, maza, rayos, sentado))
        if not ok:
            fallas += 1
    okp = "dentroDelCajon=false" in p
    print("  %s el auto queda AFUERA del cajon: %s" % ("OK   " if okp else "FALLA", p))
    if not okp:
        fallas += 1

# ---------------- FAIL-HARD ------------------------------------------------
print("  -- fail-hard (se mete el bug a proposito) --")
# BUG 1: el asiento con Torque/TurnSpeed en cero (el "me subo y no deja andar")
r = corre(1, parche_main=("seat.Torque = 40\n\tseat.TurnSpeed = 14", "seat.Torque = 0\n\tseat.TurnSpeed = 0"))
m = re.search(r"__BICI__ (.*)", r.stdout)
if m and "torque=0" in m.group(1) and "turn=0" in m.group(1):
    print("  OK    con el asiento en 0, la prueba lo caza: %s" % m.group(1)[:64])
else:
    print("  FALLA  no caza el asiento muerto: %s" % (m.group(1) if m else "(sin datos)"))
    fallas += 1
# BUG 2: el auto sale otra vez DENTRO del cajon (la causa del "no me deja andar")
r = corre(1, parche_main=("local sp = exit and exit.Position or (hrp.Position + Vector3.new(0, 0, -14))",
                         'local _b = wh0 and wh0:FindFirstChild("Bay1", true)\n\tlocal sp = (_b and _b.Position) or (hrp.Position + Vector3.new(0, 0, -14))'))
m = re.search(r"__PUESTO__ (.*)", r.stdout)
if m and "dentroDelCajon=true" in m.group(1):
    print("  OK    con el auto puesto en el cajon, la prueba lo caza: %s" % m.group(1)[:64])
else:
    print("  FALLA  no caza el auto atorado en el cajon: %s" % (m.group(1) if m else "(sin datos)"))
    fallas += 1

print("FALLO" if fallas else "OK")
sys.exit(1 if fallas else 0)
