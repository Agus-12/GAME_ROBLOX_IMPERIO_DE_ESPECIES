#!/usr/bin/env python3
"""ETAPA 22 (v47): LA CINTA GIGANTE, LA BICI, EL LETRERO Y EL MERCADO QUE REAPARECE.

Lo que reporto el usuario (capturas del 26-sep 1:17/1:18 a.m.):

  1. "la cinta sigue una otra gigante desde las bodegas inactivas hasta mi bodega"
       -> en `Clausurar` la cinta medía `math.abs(gl.Position.X) * 2 + 2`: eso solo
          da bien con el modelo en el origen (como en las pruebas). Con el lote
          vecino en x = -600 la cinta salia de ~1200 studs y ademas se colocaba en
          x = 0, o sea encima del patio del jugador. Aqui se ARMA un lote vecino de
          verdad (PivotTo al lote) y se mide: la cinta tiene que quedar alrededor
          de SU porton y de nadie mas.
  2. "la bici aparece adentro de la bodega y no afuera"
       -> se medía desde el piso de la nave (centro + media profundidad + 18), y esa
          cuenta cae adentro del PATIO (el patio llega 29 studs mas alla). Ahora se
          mide desde el patio (LotApron) + 6. Aqui se mide donde cae la bici.
  3. "la bodega aun la letra se ve super pequeña"
       -> el tablero del garaje estaba a y = 14.5 con la pared del frente a 14: un
          tercio del tablero quedaba METIDO en la pared/techo y la letra se veia
          cortada. Ahora el tablero se para sobre el techo (completo, visible) y es
          mas grande. Aqui se mide que el tablero quede ARRIBA del techo y que la
          letra sea grande.
  4. "si no quiero spawnear nada y me alejo el menu sigue ahi apareciendo" (v47)
     y "me gustaria mas que al alejarme se quitara como el de la computadora o la
     boveda" (v48)
       -> el detector reaccionaba al cruce y el panel no se cerraba al salir: si lo
          cerrabas y te movias dentro del taller, volvia a aparecer. Ahora se abre
          UNA VEZ por entrada y se CIERRA SOLO al alejarte. Aqui se ARRANCA la
          ClientUI, se entra, se camina, se sale y se comprueba TODO eso.

Probado al reves (v47): regresando la cinta a `math.abs(gl.Position.X)`, la bici al
piso de la nave, el letrero a y=14.5 y el auto-abrir sin la marca de entrada, la
etapa caza los 4.
"""
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau            # noqa: E402

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")

fallas = 0


def L(ruta):
    return strip_luau(open(os.path.join(ROOT, ruta), encoding="utf-8").read()) \
        .replace("goto cont", "_SKIP=true")


def lua(guion, env=None):
    e = dict(os.environ, TOOLS=HERE)
    if env:
        e.update(env)
    return subprocess.run([LUA, "-"], input=guion, capture_output=True,
                          text=True, env=e, cwd=ROOT, timeout=900)


def cabeza():
    g = 'dofile("%s/mock.lua")\n' % HERE
    g += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    g += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function()
'''
    g += L("ServerScriptService/CityGenerator.luau")
    g += "\nend)()\n"
    return g


print("=== 22. LA CINTA, LA BICI, EL LETRERO Y EL MERCADO (v47) ===")

TROZO_BICI = (
    "\n"
    'local L_ = _cfg.WarehouseLots\n'
    'local base = Vector3.new(L_.Origin.X, L_.Origin.Y, L_.Origin.Z)\n'
    'local m = City.BuildWarehouse(1)\n'
    'm:PivotTo(CFrame.new(base))\n'
    'm.Parent = workspace   -- v48: el lote tiene que ESTAR en el mundo; si no,\n'
    '                       -- los raycast de la bici no ven la bodega y la\n'
    '                       -- prueba pasaba sin probar nada\n'
    'local patio = m:FindFirstChild("LotApron", true)\n'
    'local piso = m.PrimaryPart\n'
    'local player = {UserId = 1}\n'
    'local warehouses = {}\n'
    'warehouses[player] = m\n'
    'local wh = m\n'
    'local hrp = {CFrame = CFrame.new(base)}\n'
    'local TEXTO = [==[\n'
    '__CODIGO__\n'
    ']==]\n'
    'local env = setmetatable({wh = wh, hrp = hrp, player = player, warehouses = warehouses,\n'
    '  CFrame = CFrame, Vector3 = Vector3, workspace = workspace, pcall = pcall,\n'
    '  Workspace = workspace, RaycastParams = RaycastParams, Enum = Enum},\n'
    '  {__index = _G})\n'
    'local f, err = load(TEXTO .. string.char(10) .. "return basePos", "bici", "t", env)\n'
    'if not f then print("__BICI__ trono al compilar: " .. tostring(err)) return end\n'
    'local ok, basePos = pcall(f)\n'
    'if not ok then print("__BICI__ trono: " .. tostring(basePos)) return end\n'
    'local orillaPatio = patio and (patio.Position.Z + patio.Size.Z * 0.5) or 0\n'
    'local paredNave = piso and (piso.Position.Z + piso.Size.Z * 0.5) or 0\n'
    'print(string.format("__BICI__ z=%.1f|x=%.1f|orillaPatio=%.1f|paredNave=%.1f|loteX=%.1f|usaPatio=%s",\n'
    '  basePos.Z, basePos.X, orillaPatio, paredNave, base.X,\n'
    '  tostring(string.find(TEXTO, "LotApron") ~= nil)))\n'
)


# ============================================ 1) LA CINTA DE UN LOTE VECINO
problemas = []
guion = cabeza()
guion += '''
-- el lote vecino como en el juego de verdad: se arma y se MANDA al lote 1
-- (warehouseSlotPos(1) = WarehouseLots.Origin = x -600, z -660)
local L_ = _cfg.WarehouseLots
local base = Vector3.new(L_.Origin.X, L_.Origin.Y, L_.Origin.Z)
local okv, m = pcall(function() return City.BuildWarehouse(2) end)
if not okv then print("__CINTA__ trono: " .. tostring(m)) return end
m.Name = "BodegaVecina_1"
m:PivotTo(CFrame.new(base))
pcall(City.VarianteVecina, m, 1)
local puestos = City.Clausurar(m)

-- todas las piezas de la cinta y la tablilla: ¿donde cayeron?
local x0, x1 = 1e9, -1e9
local nCinta, nPoste, nTablilla = 0, 0, 0
local tablaX, tablaZ
for _, d in ipairs(m:GetDescendants()) do
  if d:IsA("BasePart") then
    if d.Name == "CintaPolicial" or d.Name == "CintaRayas" then
      nCinta = nCinta + 1
      x0 = math.min(x0, d.Position.X - d.Size.X * 0.5)
      x1 = math.max(x1, d.Position.X + d.Size.X * 0.5)
    elseif d.Name == "CintaPoste" then
      nPoste = nPoste + 1
    elseif d.Name == "TablillaClausurada" then
      nTablilla = nTablilla + 1
      tablaX, tablaZ = d.Position.X, d.Position.Z
    end
  end
end
-- el porton del lote (GateLeft) para comparar
local gl
for _, d in ipairs(m:GetDescendants()) do if d.Name == "GateLeft" then gl = d break end end
print(string.format("__CINTA__ loteX=%.0f|glX=%.0f|cintaX0=%.0f|cintaX1=%.0f|ancho=%.1f|" ..
  "postes=%d|tablilla=%d|tablaX=%.0f|tablaZ=%.0f|glZ=%.0f|of1=%.0f|of2=%.0f",
  base.X, gl and gl.Position.X or 0, x0, x1, x1 - x0, nPoste, nTablilla,
  tablaX or 0, tablaZ or 0, gl and gl.Position.Z or 0,
  puestos[1] and puestos[1].X or 0, puestos[2] and puestos[2].X or 0))
'''
sal = lua(guion)
m = re.search(r"__CINTA__ (.+)", sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  no se pudo armar el lote vecino")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-4:]:
        print("         | " + x[:150])
else:
    d = dict(kv.split("=") for kv in m.group(1).split("|") if "=" in kv)
    print("  medidas: " + m.group(1))
    loteX = float(d["loteX"])
    cintaX0, cintaX1 = float(d["cintaX0"]), float(d["cintaX1"])
    ancho = float(d["ancho"])
    if int(d["postes"]) < 2:
        problemas.append("la cinta no tiene postes (faltan)")
    if int(d["tablilla"]) < 1:
        problemas.append("falta la tablilla de CLAUSURADA")
    # la cinta tiene que vivir JUNTO a su lote (a menos de un lote de distancia)
    if abs(cintaX0 - loteX) > 120 or abs(cintaX1 - loteX) > 120:
        problemas.append("la cinta cae lejisimos de su lote (x %.0f..%.0f con el lote "
                         "en %.0f): es la cinta GIGANTE" % (cintaX0, cintaX1, loteX))
    if ancho > 80:
        problemas.append("la cinta mide %.0f studs de ancho (deberia medir lo del "
                         "porton, ~40)" % ancho)
    # y NO puede llegar al lote del jugador (x = 0)
    if cintaX0 <= 0 <= cintaX1:
        problemas.append("la cinta PASA POR ENCIMA del lote del jugador (x = 0)")
    if abs(float(d["tablaX"]) - loteX) > 60:
        problemas.append("la tablilla de CLAUSURADA cae en x=%.0f, fuera de su lote "
                         "(%.0f)" % (float(d["tablaX"]), loteX))
    for k, nom in (("of1", "oficial 1"), ("of2", "oficial 2")):
        if abs(float(d[k]) - loteX) > 200:
            problemas.append("el %s queda a %.0f studs de su lote" % (nom, abs(float(d[k]) - loteX)))
    if problemas:
        fallas += 1
        print("  FALLA  (la cinta de clausura)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     la cinta mide %.1f y queda en x %.0f..%.0f, pegada a SU lote "
              "(%.0f): no llega al lote del jugador" % (ancho, cintaX0, cintaX1, loteX))

# ============================================================ 2) LA BICI
# Esta prueba NO copia la formula: saca el pedazo de codigo REAL de Main.luau
# (el que decide donde nace la bici) y lo EJECUTA con una bodega de verdad.
# Asi, si alguien vuelve a mover ese calculo, la prueba lo caza.
problemas = []
MAIN = L("ServerScriptService/Main.luau")
ini = MAIN.find("-- INICIO BICI AFUERA")
if ini == -1:
    ini = MAIN.find("local basePos")
fin = MAIN.find("basePos = Vector3.new(basePos.X")
if ini == -1 or fin == -1:
    fallas += 1
    print("  FALLA  no encontre el pedazo de spawnBike en Main.luau")
else:
    trozo = MAIN[ini:fin]
    guion = cabeza()
    guion += TROZO_BICI.replace('__CODIGO__', trozo)
    sal = lua(guion)
    m2 = re.search(r"__BICI__ (.+)", sal.stdout + sal.stderr)
    if not m2:
        fallas += 1
        print("  FALLA  no se pudo ejecutar el pedazo de spawnBike")
        for x in (sal.stdout + sal.stderr).strip().splitlines()[-4:]:
            print("         | " + x[:150])
    else:
        d = dict(kv.split("=") for kv in m2.group(1).split("|") if "=" in kv)
        print("  medidas: " + m2.group(1))
        if "z" not in d or "orillaPatio" not in d:
            fallas += 1
            print("  FALLA  el pedazo de spawnBike no llego a calcular la posicion")
            problemas.append("spawnBike truena o no devuelve basePos: " + m2.group(1))
            z = orilla = pared = 0.0
            z, orilla, pared = float(d.get("z", 0)), float(d.get("orillaPatio", 0)), \
                float(d.get("paredNave", 0))
            if problemas:
                print("         - " + problemas[-1])
        z, orilla, pared = float(d.get("z", 0)), float(d.get("orillaPatio", 0)), \
            float(d.get("paredNave", 0))
        if "z" not in d:
            pass
        elif d.get("usaPatio") != "true":
            problemas.append("spawnBike NO usa el patio (LotApron) para medir: la "
                             "bici vuelve a nacer adentro del lote")
        if "z" in d and z <= orilla:
            problemas.append("la bici cae ADENTRO del lote (z=%.1f, el patio "
                             "termina en %.1f): se ve adentro de la bodega" % (z, orilla))
        if "z" in d and z - orilla < 2:
            problemas.append("la bici queda pegada a la orilla del patio (%.1f "
                             "studs): se ve adentro" % (z - orilla))
        if "x" in d and abs(float(d["x"]) - float(d["loteX"])) > 60:
            problemas.append("la bici cae fuera de su lote en X")
        if problemas:
            fallas += 1
            print("  FALLA  (la bici adentro de la bodega)")
            for x in problemas:
                print("         - " + x)
        elif "z" in d:
            print("  OK     la bici nace en la calle: %.1f studs mas alla de la "
                  "orilla del patio (%.1f mas alla de la pared de la nave)"
                  % (z - orilla, z - pared))

# ========================================================= 3) EL LETRERO
problemas = []
guion = cabeza()
guion += '''
local m = City.BuildWarehouse(1)
-- el techo de la cochera y la pared del frente
local techoY, paredY = 0, 0
for _, d in ipairs(m:GetDescendants()) do
  if d.Name == "GarageCeiling" then techoY = d.Position.Y + d.Size.Y * 0.5 end
  if d.Name == "GarageWall" and d.Size.Y < 3 and d.Size.X > 10 then
    paredY = math.max(paredY, d.Position.Y + d.Size.Y * 0.5)   -- el dintel
  end
end
local sign, postes = nil, 0
for _, d in ipairs(m:GetDescendants()) do
  if d.Name == "GarageSign" then sign = d end
  if d.Name == "GarageSignPost" then postes = postes + 1 end
end
local rotulo
if sign then rotulo = sign:FindFirstChild("Rotulo") end
local lbl = rotulo and rotulo:FindFirstChild("Texto")
City.RotularGaraje(m, "GARAJE DE PEPE")
local texto = lbl and lbl.Text or "?"
print(string.format("__LETRERO__ abajo=%.2f|arriba=%.2f|techoY=%.2f|paredY=%.2f|" ..
  "ancho=%.1f|alto=%.1f|postes=%d|dosRenglones=%s|scaled=%s|px=%s",
  sign and (sign.Position.Y - sign.Size.Y * 0.5) or 0,
  sign and (sign.Position.Y + sign.Size.Y * 0.5) or 0,
  techoY, paredY, sign and sign.Size.X or 0, sign and sign.Size.Y or 0, postes,
  tostring(string.find(texto, string.char(10)) ~= nil), tostring(lbl and lbl.TextScaled),
  tostring(rotulo and rotulo.PixelsPerStud)))
'''
sal = lua(guion)
m = re.search(r"__LETRERO__ (.+)", sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  no se pudo medir el letrero")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-4:]:
        print("         | " + x[:150])
else:
    d = dict(kv.split("=") for kv in m.group(1).split("|") if "=" in kv)
    print("  medidas: " + m.group(1))
    abajo, arriba = float(d["abajo"]), float(d["arriba"])
    techo, pared = float(d["techoY"]), float(d["paredY"])
    if abajo < techo - 0.05:
        problemas.append("el tablero empieza en %.2f y el techo llega a %.2f: se mete "
                         "en la losa y la letra se ve cortada" % (abajo, techo))
    if abajo < pared:
        problemas.append("el tablero arranca DEBAJO del dintel (%.2f < %.2f): la pared "
                         "lo tapa" % (abajo, pared))
    if float(d["alto"]) < 5:
        problemas.append("el tablero mide %.1f de alto: la letra sale chica" % float(d["alto"]))
    if float(d["ancho"]) < 22:
        problemas.append("el tablero mide %.1f de ancho: 'GARAJE DE PEPE' no cabe "
                         "grande" % float(d["ancho"]))
    if int(d["postes"]) < 2:
        problemas.append("el tablero no tiene postes: se ve flotando")
    if d["dosRenglones"] == "true":
        problemas.append("el texto va en DOS renglones: cada renglon cabe en la mitad "
                         "del tablero y la letra sale chiquita (reporte del usuario: "
                         "'aun siguen las letras muy pequeñas')")
    if d["scaled"] != "true":
        problemas.append("el texto no es TextScaled (no llena el tablero)")
    # letra estimada: lo que la limite (alto del renglon o el ancho del tablero
    # repartido entre las letras de "GARAJE DE PEPE" = 14 caracteres)
    letra = min(float(d["alto"]) * 0.78, float(d["ancho"]) / (0.62 * 14))
    if letra < 2.4:
        problemas.append("la letra queda de %.2f studs (deberia pasar de 2.4)" % letra)
    if problemas:
        fallas += 1
        print("  FALLA  (el letrero del garaje)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el tablero queda completo ARRIBA del techo (%.1f..%.1f, techo "
              "%.1f), mide %.0fx%.1f y la letra sale de ~%.1f studs"
              % (abajo, arriba, techo, float(d["ancho"]), float(d["alto"]), letra))

# ============ 4) EL MERCADO: SE ABRE AL ENTRAR Y SE CIERRA AL ALEJARSE (v48)
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

local function panel()   -- el panel del mercado
  for _, d in ipairs(sg and sg:GetDescendants() or {}) do
    if d.ClassName == "TextLabel" and d.Text == "MERCADO" then return d.Parent end
  end
end
local function abierto() local p = panel() ; return (p and p.Visible) == true end
local function paso(x, z)
  hrp.Position = Vector3.new(x, 3, z)
  task.__sched.advance((task.__sched.vtime or 0) + 1.3)
end

local r = {}
paso(0, 20)                   -- en la calle: no debe abrir
r.calle = abierto()
paso(0, 0)                    -- entra al taller: debe abrirse SOLO
r.entroAbrio = abierto()
paso(0, 30)                   -- se ALEJA (fuera del taller): debe CERRARSE SOLO
r.cerroAlAlejarme = not abierto()
paso(0, 0)                    -- vuelve a entrar: se abre otra vez (como la compu)
r.reentroAbrio = abierto()
if panel() then panel().Visible = false end     -- lo cierro yo (como el usuario)
paso(0, 6)                    -- camino adentro
r.sigueCerrado = not abierto()
paso(0, -4)                   -- sigo adentro, del otro lado
r.sigueCerrado2 = not abierto()
paso(0, 40)                   -- me voy del todo (y ya estaba cerrado)
r.afueraCerrado = not abierto()
paso(0, 0)                    -- vuelvo a entrar: se abre de nuevo
r.alVolver = abierto()
print("__MERCADO__ calle=" .. tostring(r.calle) .. "|entroAbrio=" .. tostring(r.entroAbrio) ..
  "|cerroAlAlejarme=" .. tostring(r.cerroAlAlejarme) ..
  "|reentroAbrio=" .. tostring(r.reentroAbrio) ..
  "|cerradoTrasCerrar=" .. tostring(r.sigueCerrado) ..
  "|cerradoCaminando=" .. tostring(r.sigueCerrado2) ..
  "|afueraCerrado=" .. tostring(r.afueraCerrado) ..
  "|alVolver=" .. tostring(r.alVolver))
'''
sal = lua(guion, env={"MOCK_CHAR": "1"})
m = re.search(r"__MERCADO__ (.+)", sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  la ClientUI no llego al final")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-6:]:
        print("         | " + x[:150])
else:
    d = dict(kv.split("=") for kv in m.group(1).split("|") if "=" in kv)
    print("  medidas: " + m.group(1))
    if d.get("calle") == "true":
        problemas.append("el mercado se abre en la calle")
    if d.get("entroAbrio") != "true":
        problemas.append("al entrar al taller no se abrio solo (eso si lo quieres)")
    if d.get("cerradoTrasCerrar") != "true":
        problemas.append("lo cierro y al caminar adentro VUELVE a abrirse (el reporte)")
    if d.get("cerradoCaminando") != "true":
        problemas.append("sigue reabriendose mientras camino adentro")
    # v48: el usuario pidio que al ALEJARSE se cierre solo, como el de la
    # computadora y el de la boveda.
    if d.get("cerroAlAlejarme") != "true":
        problemas.append("me alejo del taller y el panel SE QUEDA ABIERTO (el usuario: "
                         "'me gustaria mas que al alejarme se quitara')")
    if d.get("afueraCerrado") == "true" and d.get("alVolver") != "true":
        problemas.append("me voy, vuelvo y entro: ya no se abre (deberia abrirse como "
                         "el de la computadora)")
    if d.get("reentroAbrio") != "true":
        problemas.append("entro, me alejo y vuelvo a entrar: no se vuelve a abrir")
    if d.get("alVolver") != "true":
        problemas.append("vuelvo a entrar al taller y el panel no se abre")
    if problemas:
        fallas += 1
        print("  FALLA  (el mercado que reaparece)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el mercado se abre SOLO al entrar, SE CIERRA SOLO al alejarte "
              "(v48), no reaparece si lo cierras y vuelve al taller")

print()
if fallas:
    print("FALLA: %d problema(s) de la ronda v47" % fallas)
    sys.exit(1)
print("OK: la cinta es de su lote, la bici sale a la calle, el letrero se ve "
      "completo y el mercado no reaparece")
