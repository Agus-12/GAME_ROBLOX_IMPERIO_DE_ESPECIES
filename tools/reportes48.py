#!/usr/bin/env python3
"""ETAPA 23 (v48): EL AUTO QUE SI SE MANEJA, LA BICI AFUERA, EL LETRERO GRANDE,
EL MERCADO QUE SE CIERRA AL ALEJARTE Y LA BODEGA CON DETALLES.

Lo que reporto el usuario (5 puntos):

  1. "al spawnear la van o los autos me sube si pero no me deja conducirlo"
       -> el auto usaba FISICA: VehicleSeat + ruedas con HingeConstraint. Las
          propiedades Torque/MaxSpeed/TurnSpeed del asiento estan DEPRECADAS en
          Roblox: te sientan pero no empujan nada cuando las ruedas son
          HingeConstraint (solo funcionaban con las viejas bisagras de
          superficie). Aqui se ARRANCA el servidor de verdad, se spawnea la van,
          se le pisa el acelerador (seat.Throttle = 1) y se mide si AVANZA, si
          GIRA, si las ruedas giran y si el carro se queda entero (ninguna pieza
          se queda atras) y sobre el piso.
  2. "la bici sigue apareciendo adentro"
       -> la cuenta de "6 studs mas alla del patio" nunca se COMPROBABA. Ahora
          el punto se verifica (piso abajo, CIELO ABIERTO arriba, nada pegado a
          los lados) y, si el lote todavia no existe, se busca alrededor del
          jugador (antes era "7 studs a su izquierda": si el jugador esta dentro
          del taller, la bici nacia ADENTRO). Aqui se mide: (a) el caso normal,
          (b) el caso "todavia no hay lote" con el jugador adentro del taller.
  3. "el letrero aun siguen las letras muy pequeñas"
       -> el tablero era de 15x4 con DOS renglones (letra ~1.7). Ahora es de
          26x5.4, en UN renglon y recargado hacia la calle: la letra pasa de
          ~3 studs. Aqui se mide con el texto real ("GARAJE DE <nombre>").
  4. "me gustaria mas que al alejarme se quitara como el de la computadora"
       -> el panel del mercado se CIERRA SOLO al alejarte. (Se prueba completo
          en la etapa 22, que corre la ClientUI de verdad; aqui se repite el
          punto clave: me alejo y se cierra.)
  5. "las bodegas... se vieran mas realistas, unas mejores texturas"
       -> nueva decoracion con materiales de Roblox (zocalo, costillas, ventanas
          altas, columnas de acero, viga de carga, canoa, respiraderos, franjas
          de seguridad, placa de acero del anden, juntas y manchas del patio, y
          las paredes en metal industrial). Aqui se cuentan las piezas nuevas y
          los materiales distintos.

Probado al reves (tools/alreves48.py): quitando el manejo del auto, volviendo la
bici a "7 studs a la izquierda del jugador", regresando el letrero a 15x4 en dos
renglones, quitando el cierre automatico del mercado y borrando la decoracion, la
etapa caza los 5.
"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau            # noqa: E402

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")
fallas = 0


def L(ruta):
    return strip_luau(open(os.path.join(ROOT, ruta), encoding="utf-8").read()) \
        .replace("goto cont", "_SKIP=true")


def lua(guion, env=None, timeout=900):
    e = dict(os.environ, TOOLS=HERE, **({"__TOOLS__": HERE} if False else {}))
    if env:
        e.update(env)
    return subprocess.run([LUA, "-"], input=guion, capture_output=True, text=True,
                          env=e, cwd=ROOT, timeout=timeout)


def servidor(extra="", ciudad=True):
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
'''
    if ciudad:
        g += 'pcall(function() _city.Build() end)\n'
    g += '''
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


print("=== 23. EL AUTO CONDUCIBLE, LA BICI AFUERA, EL LETRERO Y LA BODEGA (v48) ===")

# ==================================================================== 1) EL AUTO
problemas = []
extra = '''
local id = nil
for _, v in ipairs(_cfg.Vehicles) do if perfil.Vehicles[v.Id] then id = v.Id break end end
if not id then id = _cfg.Vehicles[1].Id ; perfil.Vehicles[id] = true end
if RF and RF.OnServerInvoke then
  local r = RF.OnServerInvoke(yo, "spawnVehicle", id, false)
  if type(r) == "table" then print("__SPAWN__ " .. tostring(r.ok) .. " | " .. tostring(r.msg)) end
end
avanzar(1.5)
local auto = workspace:FindFirstChild("Car_4242")
if not auto then print("__NOAUTO__") return end
local seat = auto:FindFirstChild("Seat")
local body = auto.PrimaryPart
local p0 = Vector3.new(body.Position.X, body.Position.Y, body.Position.Z)
print(string.format("__NACE__ %.2f,%.2f,%.2f", p0.X, p0.Y, p0.Z))

seat:Sit(hum)
avanzar(0.2)
seat.Throttle = 1
avanzar(2.5)
local p1 = Vector3.new(body.Position.X, body.Position.Y, body.Position.Z)
local avance = (p1 - p0).Magnitude
print(string.format("__AVANZO__ %.1f y=%.2f", avance, p1.Y))

-- gira
local _, oy0 = body.CFrame:GetOrientation()
seat.Steer = 1
avanzar(1.5)
local _, oy1 = body.CFrame:GetOrientation()
print(string.format("__GIRO__ %.1f", math.abs(math.deg(oy1 - oy0))))

-- frena
seat.Throttle = 0
seat.Steer = 0
avanzar(1.5)
local p2 = Vector3.new(body.Position.X, body.Position.Y, body.Position.Z)
avanzar(1.0)
local p3 = Vector3.new(body.Position.X, body.Position.Y, body.Position.Z)
print(string.format("__FRENO__ %.2f", (p3 - p2).Magnitude))

-- el carro entero: ninguna pieza se queda atras y no hay bisagras fisicas
local lejos, total, bisagras, ancladas = 0, 0, 0, 0
for _, d in ipairs(auto:GetDescendants()) do
  if d:IsA("BasePart") then
    total = total + 1
    if (d.Position - body.Position).Magnitude > 20 then lejos = lejos + 1 end
    if d.Anchored then ancladas = ancladas + 1 end
  end
  if d:IsA("HingeConstraint") then bisagras = bisagras + 1 end
end
local giradas = 0
for _, d in ipairs(auto:GetDescendants()) do
  if d.Name == "Wheel" then
    local x = select(1, d.CFrame:GetOrientation())
    if math.abs(math.deg(x)) > 1 then giradas = giradas + 1 end
  end
end
print(string.format("__CARRO__ piezas=%d lejos=%d bisagras=%d giradas=%d ancladas=%d",
  total, lejos, bisagras, giradas, ancladas))

-- y el piso: el chasis tiene que ir a la altura de rueda, no flotando ni hundido
local abajo = workspace:Raycast(Vector3.new(body.Position.X, body.Position.Y, body.Position.Z),
  Vector3.new(0, -1, 0) * 40, RaycastParams.new())
print(string.format("__ALTURA__ %.2f piso=%.2f", body.Position.Y, abajo and abajo.Position.Y or -999))
'''
g = servidor(extra)
t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
t.write(g)
t.close()
r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=900)
os.unlink(t.name)
sal = r.stdout + r.stderr
d = {}
for k in ("NACE", "AVANZO", "GIRO", "FRENO", "CARRO", "ALTURA", "SPAWN"):
    m = re.search(r"__%s__ (.+)" % k, sal)
    if m:
        d[k] = m.group(1).strip()


def kv(txt):
    return dict(p.split("=", 1) for p in txt.split() if "=" in p)


if "AVANZO" not in d:
    fallas += 1
    print("  FALLA  el auto no llego a manejarse")
    for x in sal.strip().splitlines()[-6:]:
        print("         | " + x[:150])
else:
    print("  medidas: avance=%s giro=%s freno=%s | %s" % (d["AVANZO"], d["GIRO"], d["FRENO"], d["CARRO"]))
    avance = float(d["AVANZO"].split()[0])
    a = kv(d["CARRO"])
    if avance < 40:
        problemas.append("el auto solo avanzo %.1f studs con el acelerador a fondo: "
                         "te sube pero no te deja conducirlo (el reporte)" % avance)
    if float(d["GIRO"]) < 20:
        problemas.append("el auto no gira (el volante movio la orientacion %.1f grados)"
                         % float(d["GIRO"]))
    if float(d["FRENO"]) > 6:
        problemas.append("el auto sigue andando solo cuando sueltas el acelerador "
                         "(avanzo %.1f sin nadie pisando)" % float(d["FRENO"]))
    if int(a["lejos"]) > 0:
        problemas.append("%s pieza(s) del carro se quedaron atras (volando lejos del chasis)"
                         % a["lejos"])
    if int(a["giradas"]) < 4:
        problemas.append("solo %s de 4 ruedas giraron" % a["giradas"])
    if int(a["bisagras"]) > 0:
        problemas.append("quedaron %s bisagras fisicas en el auto" % a["bisagras"])
    if problemas:
        fallas += 1
        print("  FALLA  (el auto que no se manejaba)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el auto AVANZA %.0f studs con el acelerador, gira con el volante, "
              "frena, las 4 ruedas giran y el carro viaja entero (sin fisica)" % avance)

# ================================================= 2) LA BICI AFUERA (las dos rutas)
problemas = []
MAIN = L("ServerScriptService/Main.luau")
ini = MAIN.find("-- INICIO BICI AFUERA")
fin = MAIN.find("basePos = Vector3.new(basePos.X")
if ini == -1 or fin == -1:
    fallas += 1
    print("  FALLA  no encontre el pedazo de spawnBike en Main.luau")
else:
    trozo = MAIN[ini:fin]
    CASOS = {
        # (a) con lote: la bici sale a la calle
        "conLote": '''
local m = City.BuildWarehouse(1)
m:PivotTo(CFrame.new(base))
m.Parent = workspace          -- el lote en el mundo: si no, no hay nada que esquivar
local player = {UserId = 1}
local warehouses = {}
warehouses[player] = m
local wh = m
local hrp = {CFrame = CFrame.new(Vector3.new(base.X, base.Y + 8, base.Z)),
  Position = Vector3.new(base.X, base.Y + 8, base.Z)}
''',
        # (b) SIN lote y con el jugador ADENTRO del taller (el caso del reporte)
        "sinLote": '''
local m = City.BuildWarehouse(1)
m:PivotTo(CFrame.new(base))
m.Parent = workspace
local interior = m.PrimaryPart
local player = {UserId = 1}
local warehouses = {}
local wh = nil
local hrp = {CFrame = CFrame.new(interior.Position), Position = interior.Position}
''',
    }
    for nombre, pre in CASOS.items():
        guion = 'dofile("%s/mock.lua")\n' % HERE
        guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
        guion += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function() ''' + L("ServerScriptService/CityGenerator.luau") + ''' end)()
local L_ = _cfg.WarehouseLots
local base = Vector3.new(L_.Origin.X, L_.Origin.Y, L_.Origin.Z)
'''
        guion += pre
        guion += 'local Workspace = workspace\nlocal RaycastParams = RaycastParams\nlocal Enum = Enum\n'
        guion += 'local TEXTO = [==[\n' + trozo + '\n]==]\n'
        guion += '''
local env = setmetatable({wh = wh, hrp = hrp, player = player, warehouses = warehouses,
  CFrame = CFrame, Vector3 = Vector3, workspace = workspace, pcall = pcall,
  Workspace = workspace, RaycastParams = RaycastParams, Enum = Enum}, {__index = _G})
local f, err = load(TEXTO .. string.char(10) .. "return basePos", "bici", "t", env)
if not f then print("__BICI__ trono al compilar: " .. tostring(err)) return end
local ok, basePos = pcall(f)
if not ok then print("__BICI__ trono: " .. tostring(basePos)) return end

-- ¿hay techo arriba? (si hay, la bici nacio ADENTRO de algo)
local rp = RaycastParams.new()
local arriba = workspace:Raycast(basePos + Vector3.new(0, 1, 0), Vector3.new(0, 40, 0), rp)
-- ¿la bici quedo TAPADA por una pared? (el recuadro va de media bici de alto
-- para arriba: asi el piso del taller no cuenta como choque)
local caja = {basePos.X - 2.5, basePos.Y + 0.5, basePos.Z - 2.5,
              basePos.X + 2.5, basePos.Y + 3.0, basePos.Z + 2.5}
local choques = {}
for _, o in ipairs(m:GetDescendants()) do
  if o:IsA("BasePart") and (o.CanCollide == nil or o.CanCollide) then
    local p, s = o.Position, o.Size
    local c = {p.X - s.X/2, p.Y - s.Y/2, p.Z - s.Z/2, p.X + s.X/2, p.Y + s.Y/2, p.Z + s.Z/2}
    if caja[1] < c[4] and caja[4] > c[1] and caja[2] < c[5] and caja[5] > c[2]
       and caja[3] < c[6] and caja[6] > c[3] then
      table.insert(choques, o.Name)
    end
  end
end
local patio = m:FindFirstChild("LotApron", true)
local orilla = patio and (patio.Position.Z + patio.Size.Z * 0.5) or 0
print(string.format("__BICI__ x=%.1f z=%.1f techo=%s orillaPatio=%.1f choques=%d [%s]",
  basePos.X, basePos.Z, arriba and arriba.Instance.Name or "libre", orilla, #choques,
  table.concat(choques, ",")))
'''
        sal2 = lua(guion)
        m2 = re.search(r"__BICI__ (.+)", sal2.stdout + sal2.stderr)
        if not m2:
            fallas += 1
            print("  FALLA  no se pudo medir la bici (%s)" % nombre)
            for x in (sal2.stdout + sal2.stderr).strip().splitlines()[-4:]:
                print("         | " + x[:150])
            continue
        print("  medidas [%s]: %s" % (nombre, m2.group(1)))
        e = kv(m2.group(1).replace("|", " "))
        if e.get("techo", "libre") != "libre":
            problemas.append("[%s] la bici nace DEBAJO DE %s: esta adentro de algo"
                             % (nombre, e["techo"]))
        if int(e.get("choques", "0")) > 0:
            problemas.append("[%s] la bici nace PEGADA a: %s" % (nombre, e.get("choques")))
        if nombre == "conLote":
            z, orilla = float(e["z"]), float(e["orillaPatio"])
            if z - orilla < 2:
                problemas.append("la bici cae dentro del lote (z=%.1f, el patio termina en "
                                 "%.1f)" % (z, orilla))
    if problemas:
        fallas += 1
        print("  FALLA  (la bici adentro)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     la bici nace en la calle con cielo abierto, y si el lote todavia "
              "no existe TAMPOCO nace adentro del taller")

# ================================================================= 3) EL LETRERO
problemas = []
guion = 'dofile("%s/mock.lua")\n' % HERE
guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
guion += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function() ''' + L("ServerScriptService/CityGenerator.luau") + ''' end)()
local m = City.BuildWarehouse(1)
local sign = nil
for _, d in ipairs(m:GetDescendants()) do if d.Name == "GarageSign" then sign = d end end
City.RotularGaraje(m, "GARAJE DE PEPE")
local rot = sign and sign:FindFirstChild("Rotulo")
local lbl = rot and rot:FindFirstChild("Texto")
local renglones = 1
if lbl then
  for _ in string.gmatch(lbl.Text, string.char(10)) do renglones = renglones + 1 end
end
local letras = 0
if lbl then for _ in string.gmatch(lbl.Text, "[%w]") do letras = letras + 1 end end
print(string.format("__LETRERO__ ancho=%.1f alto=%.1f letras=%d renglones=%d texto=%s",
  sign.Size.X, sign.Size.Y, letras, renglones, lbl and lbl.Text or "?"))
'''
sal3 = lua(guion)
m3 = re.search(r"__LETRERO__ (.+)", sal3.stdout + sal3.stderr)
if not m3:
    fallas += 1
    print("  FALLA  no se pudo medir el letrero nuevo")
else:
    print("  medidas: " + m3.group(1))
    e = kv(m3.group(1).replace("|", " "))
    # la letra mas grande que quepa: o el alto del renglon o el ancho repartido
    letra = min(float(e["alto"]) * 0.78, float(e["ancho"]) / (0.62 * max(1, int(e["letras"]))))
    if int(e["renglones"]) > 1:
        problemas.append("el letrero sigue en %s renglones" % e["renglones"])
    if letra < 2.4:
        problemas.append("la letra queda de ~%.1f studs: sigue pequeña" % letra)
    if problemas:
        fallas += 1
        print("  FALLA  (el letrero chico)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     la letra de 'GARAJE DE PEPE' sale de ~%.1f studs en un tablero "
              "de %.0fx%.1f y un solo renglon" % (letra, float(e["ancho"]), float(e["alto"])))

# ============================================ 4) EL MERCADO SE CIERRA AL ALEJARSE
# (el detalle completo lo prueba la etapa 22; aqui va el caso del reporte: me alejo)
problemas = []
CLIENTE = L("StarterPlayerScripts/ClientUI.luau")
guion = 'dofile("%s/mockclient.lua")\n' % HERE
guion += "local __cli = function()\n" + CLIENTE + "\nend\n__cli()\n"
guion += '''
if task.__sched then task.__sched.advance(2) end
local plr = game:GetService("Players").LocalPlayer
local pg = plr:FindFirstChild("PlayerGui")
local sg = pg and pg:FindFirstChild("SpiceEmpireUI")
local wh = Instance.new("Model") ; wh.Name = "Warehouse_" .. plr.UserId ; wh.Parent = workspace
local piso = Instance.new("Part") ; piso.Name = "GarageFloor" ; piso.Anchored = true
piso.Size = Vector3.new(26, 2, 24) ; piso.Position = Vector3.new(0, 1, 0) ; piso.Parent = wh
local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
local function panel()
  for _, d in ipairs(sg and sg:GetDescendants() or {}) do
    if d.ClassName == "TextLabel" and d.Text == "MERCADO" then return d.Parent end
  end
end
local function abierto() local p = panel() ; return (p and p.Visible) == true end
local function paso(x, z)
  hrp.Position = Vector3.new(x, 3, z)
  task.__sched.advance((task.__sched.vtime or 0) + 1.3)
end
paso(0, 0)              -- entra al taller: se abre solo
local abrioSolo = abierto()
paso(0, 30)             -- me alejo
local seCerro = not abierto()
print("__MERCADO__ abrioAlEntrar=" .. tostring(abrioSolo) .. "|seCerroAlAlejarme=" .. tostring(seCerro))
'''
sal4 = lua(guion, env={"MOCK_CHAR": "1"})
m4 = re.search(r"__MERCADO__ (.+)", sal4.stdout + sal4.stderr)
if not m4:
    fallas += 1
    print("  FALLA  la ClientUI no llego al final")
else:
    print("  medidas: " + m4.group(1))
    e = kv(m4.group(1).replace("|", " "))
    if e.get("abrioAlEntrar") != "true":
        problemas.append("al entrar al taller no se abrio solo")
    if e.get("seCerroAlAlejarme") != "true":
        problemas.append("me aleje del taller y el panel SIGUE ABIERTO (el usuario queria "
                         "que se quitara como el de la computadora)")
    if problemas:
        fallas += 1
        print("  FALLA  (el mercado al alejarte)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el mercado se abre al entrar al taller y SE CIERRA SOLO al alejarte")

# ============================================================ 5) LA BODEGA CON DETALLES
problemas = []
DETALLES = ["WallSkirt", "WallRib", "WallBand", "Clerestory", "SteelColumn", "ColumnBase",
            "HoistBeam", "HoistTrolley", "RoofGutter", "RoofStack", "DockSteelPlate",
            "FloorStripe", "OilStain", "ApronJoint", "ApronStain", "WallPipe", "Extinguisher"]
guion = 'dofile("%s/mock.lua")\n' % HERE
guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
guion += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function() ''' + L("ServerScriptService/CityGenerator.luau") + ''' end)()
local L_ = _cfg.WarehouseLots
local m = City.BuildWarehouse(1)
m:PivotTo(CFrame.new(Vector3.new(L_.Origin.X, L_.Origin.Y, L_.Origin.Z)))
local cuenta, materiales, total = {}, {}, 0
for _, d in ipairs(m:GetDescendants()) do
  if d:IsA("BasePart") then
    total = total + 1
    cuenta[d.Name] = (cuenta[d.Name] or 0) + 1
    if d.Material then materiales[tostring(d.Material.Name or d.Material)] = true end
  end
end
local faltan, nmat = 0, 0
for nombre, _ in pairs(materiales) do nmat = nmat + 1 end
local lista = ""
for _, det in ipairs({@LISTA@}) do
  if not cuenta[det] then faltan = faltan + 1 ; lista = lista .. det .. "," end
end
-- las paredes de la nave, en metal industrial (textura de bodega)
local paredMetal = false
for _, d in ipairs(m:GetDescendants()) do
  if d.Name == "Wall1" and tostring(d.Material) == "CorrodedMetal" then paredMetal = true end
  if d.Name == "Wall1" and d.Material == Enum.Material.CorrodedMetal then paredMetal = true end
end
print(string.format("__BODEGA__ piezas=%d materiales=%d faltan=%d [%s] paredMetal=%s detalles=%d",
  total, nmat, faltan, lista, tostring(paredMetal),
  (cuenta.WallSkirt or 0) + (cuenta.SteelColumn or 0) + (cuenta.WallRib or 0) + (cuenta.HoistBeam or 0)))
'''.replace("@LISTA@", ",".join('"%s"' % x for x in DETALLES))
sal5 = lua(guion)
m5 = re.search(r"__BODEGA__ (.+)", sal5.stdout + sal5.stderr)
if not m5:
    fallas += 1
    print("  FALLA  no se pudo medir la bodega")
    for x in (sal5.stdout + sal5.stderr).strip().splitlines()[-4:]:
        print("         | " + x[:150])
else:
    print("  medidas: " + m5.group(1))
    e = kv(m5.group(1).replace("|", " "))
    if int(e["faltan"]) > 0:
        problemas.append("faltan piezas de detalle: %s" % e.get("[", "?"))
    if int(e["materiales"]) < 8:
        problemas.append("la bodega usa solo %s materiales distintos: se ve plana" % e["materiales"])
    if e.get("paredMetal") != "true":
        problemas.append("las paredes de la nave no tienen textura de bodega (metal industrial)")
    if problemas:
        fallas += 1
        print("  FALLA  (la bodega se ve igual de plana)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     la bodega trae los 17 detalles nuevos, %s materiales distintos y las "
              "paredes en metal industrial" % e["materiales"])

print()
if fallas == 0:
    print("OK: el auto se maneja, la bici nace afuera, la letra es grande, el mercado se "
          "cierra al alejarte y la bodega tiene detalles")
else:
    print("FALLA: %d problema(s) de la ronda v48" % fallas)
sys.exit(1 if fallas else 0)
