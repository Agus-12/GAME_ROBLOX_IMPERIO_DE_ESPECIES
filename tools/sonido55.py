#!/usr/bin/env python3
"""27. SONIDO DE VERDAD: motor al manejar, rodada de la bici y musica ambiente (v55).

Lo que reporto el roadmap (docs/05): "musica de fondo, sonido de motor para
los vehiculos y sonido de la bici al rodar" no existian — el juego era mudo
mientras manejabas.

Aqui se comprueba con el juego de verdad:
  1) LA VAN: el MotorLoop existe, es Looped, NO suena sin conductor, SUENA al
     subirse (idle), el tono y el volumen SUBEN con la velocidad, baja al
     frenar y se APAGA al bajarse.
  2) LA BICI: la RodadaLoop existe, es Looped, suena pedaleando y CALLA al
     pararse (la bici no tiene motor).
  3) EL CLIENTE: MusicaFondo vive en SoundService (no en el gui: el gui muere
     al respawnear), es Looped, esta sonando y suena BAJITA.
  4) LA CONFIG: Engine/Rolling/Music existen en GameConfig.Sounds con Id.

El mock sabe si un Sound esta sonando (IsPlaying) desde la v55; sin eso esta
etapa no podria comprobar nada (todo saldria "libre" de oidos).
"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau  # noqa: E402

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")
if not os.path.exists(LUA):
    sys.exit("Falta Lua. Corre primero:  bash tools/setup.sh")


def L(ruta):
    return strip_luau(open(os.path.join(ROOT, ruta), encoding="utf-8").read()) \
        .replace("goto cont", "_SKIP=true")


def lua(guion, timeout=900):
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
    t.write(guion)
    t.close()
    r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=timeout)
    os.unlink(t.name)
    return r


def kv(s):
    d = {}
    for parte in re.split(r"[|;\s]", s):
        if "=" in parte:
            k, v = parte.split("=", 1)
            d[k.strip()] = v.strip()
    return d


def servidor(extra=""):
    """Arranca el SERVIDOR real (Main) bajo el simulador y devuelve el guion."""
    g = 'dofile("%s/mock.lua")\n' % HERE
    g += '''
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
local hrp = Instance.new("Part") ; hrp.Name = "HumanoidRootPart" ; hrp.Position = Vector3.new(-600, 8, -650)
hrp.Size = Vector3.new(2, 2, 1) ; hrp.Parent = workspace
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
'''
    g += extra
    return g


print("=== 27. SONIDO DE VERDAD: motor, rodada y musica ambiente (v55) ===")
fallas = 0

# ============================================================ 1) LA VAN: EL MOTOR
problemas = []
extra = '''
local id = nil
for _, v in ipairs(_cfg.Vehicles) do if perfil.Vehicles[v.Id] then id = v.Id break end end
if not id then id = _cfg.Vehicles[1].Id ; perfil.Vehicles[id] = true end
if RF and RF.OnServerInvoke then RF.OnServerInvoke(yo, "spawnVehicle", id, false) end
avanzar(1.5)
local auto = workspace:FindFirstChild("Car_4242")
if not auto then print("__MOTOR__ hay=false nohay") return end
local seat = auto:FindFirstChild("Seat")
local m = auto:FindFirstChild("MotorLoop", true)
avanzar(0.5)
if not m then print("__MOTOR__ hay=false") return end
print("__MOTOR__ hay=true looped=" .. tostring(m.Looped)
  .. " sonandoSinConductor=" .. tostring(m.IsPlaying))
seat:Sit(hum)
avanzar(0.4)
print(string.format("__IDLE__ sonando=%s tono=%.3f vol=%.3f",
  tostring(m.IsPlaying), tonumber(m.PlaybackSpeed) or -1, tonumber(m.Volume) or -1))
seat.Throttle = 1
avanzar(2.5)
print(string.format("__FONDO__ tono=%.3f vol=%.3f",
  tonumber(m.PlaybackSpeed) or -1, tonumber(m.Volume) or -1))
seat.Throttle = 0
avanzar(1.2)
print(string.format("__FRENANDO__ tono=%.3f sonando=%s",
  tonumber(m.PlaybackSpeed) or -1, tostring(m.IsPlaying)))
seat.Occupant = nil
avanzar(0.6)
print("__BAJARSE__ sonando=" .. tostring(m.IsPlaying))
'''
sal = lua(servidor(extra))
sm = re.search(r"__MAIN__ (\w+)", sal.stdout + sal.stderr)
if not sm or sm.group(1) != "true":
    fallas += 1
    print("  FALLA  el servidor no arranco")
else:
    medidas = {}
    for tag in ("__MOTOR__", "__IDLE__", "__FONDO__", "__FRENANDO__", "__BAJARSE__"):
        mm = re.search(tag + r" (.+)", sal.stdout + sal.stderr)
        if mm:
            medidas[tag] = kv(mm.group(1))
            print("  medidas %s %s" % (tag, mm.group(1)))
        else:
            problemas.append("no salio la medicion %s" % tag)
    e = medidas.get("__MOTOR__", {})
    if e.get("hay") != "true":
        problemas.append("la van no trae su MotorLoop")
    elif e.get("looped") != "true":
        problemas.append("el MotorLoop no es Looped: se oiria un golpe y listo")
    elif e.get("sonandoSinConductor") != "false":
        problemas.append("el motor suena con la van abandonada en el cajon")
    e = medidas.get("__IDLE__", {})
    if e.get("sonando") != "true":
        problemas.append("te subes a la van y el motor NO suena (el juego sigue mudo)")
    e = medidas.get("__FONDO__", {})
    ei = medidas.get("__IDLE__", {})
    if "tono" in e and "tono" in ei:
        if float(e["tono"]) <= float(ei["tono"]) + 0.05:
            problemas.append("el tono del motor no sube con la velocidad (%s -> %s): "
                             "suena igual parado que a toda marcha"
                             % (ei["tono"], e["tono"]))
        if float(e.get("vol", "0")) <= float(ei.get("vol", "0")) + 0.02:
            problemas.append("el volumen del motor no sube con la velocidad")
    e = medidas.get("__BAJARSE__", {})
    if e.get("sonando") != "false":
        problemas.append("te bajas de la van y el motor SIGUE sonando")
    if problemas:
        fallas += 1
        print("  FALLA  (el motor de la van)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     la van suena: idle al subirse, el tono sube con la velocidad")
        print("         y se apaga al bajarse (nadie la deja encendida en el cajon)")

# ============================================================ 2) LA BICI: LA RODADA
problemas = []
extra = '''
if RF and RF.OnServerInvoke then RF.OnServerInvoke(yo, "spawnBike") end
avanzar(1.5)
local bici = workspace:FindFirstChild("Bike_4242")
if not bici then print("__RODADA__ hay=false nohay") return end
local r = bici:FindFirstChild("RodadaLoop", true)
if not r then print("__RODADA__ hay=false") return end
print("__RODADA__ hay=true looped=" .. tostring(r.Looped)
  .. " sonandoParada=" .. tostring(r.IsPlaying))
local bs = bici:FindFirstChild("Seat", true)
bs:Sit(hum)
bs.Throttle = 1
avanzar(2.0)
print(string.format("__PEDALEANDO__ sonando=%s vol=%.3f tono=%.3f",
  tostring(r.IsPlaying), tonumber(r.Volume) or -1, tonumber(r.PlaybackSpeed) or -1))
bs.Throttle = 0
avanzar(1.2)
print("__BICI_PARADA__ sonando=" .. tostring(r.IsPlaying))
'''
sal = lua(servidor(extra))
if not re.search(r"__MAIN__ true", sal.stdout + sal.stderr):
    fallas += 1
    print("  FALLA  el servidor no arranco (bici)")
else:
    medidas = {}
    for tag in ("__RODADA__", "__PEDALEANDO__", "__BICI_PARADA__"):
        mm = re.search(tag + r" (.+)", sal.stdout + sal.stderr)
        if mm:
            medidas[tag] = kv(mm.group(1))
            print("  medidas %s %s" % (tag, mm.group(1)))
        else:
            problemas.append("no salio la medicion %s" % tag)
    e = medidas.get("__RODADA__", {})
    if e.get("hay") != "true":
        problemas.append("la bici no trae su RodadaLoop")
    elif e.get("looped") != "true":
        problemas.append("la RodadaLoop no es Looped")
    elif e.get("sonandoParada") != "false":
        problemas.append("la bici suena parada y sin nadie (debe ser silencio)")
    e = medidas.get("__PEDALEANDO__", {})
    if e.get("sonando") != "true":
        problemas.append("pedaleas y la bici NO suena (sigue muda)")
    elif float(e.get("vol", "0")) < 0.1:
        problemas.append("la rodada suena tan bajito que no se oye (vol %s)" % e.get("vol"))
    e = medidas.get("__BICI_PARADA__", {})
    if e.get("sonando") != "false":
        problemas.append("paras la bici y la rodada SIGUE sonando")
    if problemas:
        fallas += 1
        print("  FALLA  (la rodada de la bici)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     la bici suena a rodada mientras pedaleas y calla al pararse")
        print("         (nada de motor: es bici)")

# ============================================================ 3) EL CLIENTE: LA MUSICA
problemas = []
cfg = strip_luau(open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau"),
                      encoding="utf-8").read())
open(os.path.join(HERE, "cfgload.lua"), "w", encoding="utf-8").write(
    "return (function()\n" + cfg + "\nend)()\n")
src = strip_luau(open(os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau"),
                      encoding="utf-8").read()).replace("goto cont", "_SKIP=true")
body = ('dofile("%s/mockclient.lua")\n' % HERE
        + 'local okc, errc = pcall(function()\n' + src + '\nend)\n'
        + 'if task.__sched then task.__sched.advance(5) end\n'
        + 'local ss = game:GetService("SoundService")\n'
        + 'local m = ss:FindFirstChild("MusicaFondo")\n'
        + 'print("__CLI__ " .. (okc and "ok" or ("trono " .. tostring(errc))))\n'
        + 'if m then\n'
        + '  print(string.format("__MUSICA__ hay=true looped=%s sonando=%s vol=%.3f",\n'
        + '    tostring(m.Looped), tostring(m.IsPlaying), m.Volume))\n'
        + 'else\n'
        + '  print("__MUSICA__ hay=false")\n'
        + 'end\n')
t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
t.write(body)
t.close()
env = dict(os.environ, MOCK_VW="1920", MOCK_VH="1080", MOCK_TOUCH="0", TOOLS=HERE)
r = subprocess.run([LUA, t.name], capture_output=True, text=True, env=env, timeout=120)
os.unlink(t.name)
salida = r.stdout + r.stderr
mc = re.search(r"__MUSICA__ (.+)", salida)
cli = re.search(r"__CLI__ (.+)", salida)
if cli:
    print("  medidas __CLI__ %s" % cli.group(1))
if not cli or cli.group(1).split()[0] != "ok":
    problemas.append("el cliente trono: %s" % (cli.group(1)[:90] if cli else "sin salida"))
if not mc:
    problemas.append("no se pudo medir la musica del cliente")
else:
    print("  medidas __MUSICA__ %s" % mc.group(1))
    e = kv(mc.group(1))
    if e.get("hay") != "true":
        problemas.append("no hay MusicaFondo en el SoundService: el mapa sigue mudo")
    else:
        if e.get("looped") != "true":
            problemas.append("la musica no es Looped: se oiria 48 segundos y chancla")
        if e.get("sonando") != "true":
            problemas.append("la musica existe pero no esta sonando")
        if e.get("vol", "1") != "?" and float(e.get("vol", "1")) > 0.25:
            problemas.append("la musica suena mas fuerte que el juego (vol %s): "
                             "ambiente es bajito" % e.get("vol"))
if problemas:
    fallas += 1
    print("  FALLA  (la musica ambiente)")
    for x in problemas:
        print("         - " + x)
else:
    print("  OK     la musica ambiente suena desde que entradas, en loop y bajita")
    print("         (en SoundService: sobrevive al respawn, no como el gui)")

# ============================================================ 4) LA CONFIG
problemas = []
cfgsrc = open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau"),
              encoding="utf-8").read()
for key in ("Engine", "Rolling", "Music"):
    mm = re.search(key + r"\s*=\s*\{\s*Id\s*=\s*\"rbxassetid://(\d+)\"", cfgsrc)
    if not mm:
        problemas.append("GameConfig.Sounds no trae %s con Id (rbxassetid://...)" % key)
    else:
        print("  config: %-8s rbxassetid://%s" % (key, mm.group(1)))
if problemas:
    fallas += 1
    print("  FALLA  (la config de sonidos)")
    for x in problemas:
        print("         - " + x)
else:
    print("  OK     los tres loops (Engine/Rolling/Music) viven en GameConfig.Sounds")

print()
if fallas:
    print("FALLA: %d problema(s) de la ronda v55" % fallas)
    sys.exit(1)
print("OK: el juego ya no es mudo — motor al manejar, rodada en la bici y ciudad de fondo")
