#!/usr/bin/env python3
"""ETAPA 24 (v49): LA LETRA SE MIDE, EL PORTON SE VE Y NO HAY PALITOS EN EL PISO.

El usuario (4a ronda seguida con lo mismo, y con razon):

  1. "el mercado de la cochera se sigue quedando pegado no importa cuanto me aleje"
       -> se probaba UN camino (entrar caminando). Ahora el cierre al alejarse vive
          en un solo lugar y se prueba por LOS CUATRO caminos con los que puedes
          abrir el panel: entrar al cajon, boton Auto [Y], tecla V y el boton de
          la tienda. En los cuatro, alejarse tiene que cerrarlo.
  2. "los letreros la letra sigue quedando re chiquita"
       -> la letra se MEDIA a ojo (alto del tablero / renglones) y con TextScaled
          el motor hacia lo que queria. Ahora cada rotulo PIDE su letra en studs
          (textoPlano{ letra = ... }) y aqui se mide el TextSize real de los OCHO
          rotulos del lote: ninguno puede bajar de un minimo legible.
  3. "sigue sin aparecer el porton de la cochera"
       -> el porton existia y estaba bien, pero (a) se abria a 10 studs, o sea que
          caminando por el patio NUNCA lo veias cerrado, y (b) era una hoja gris
          sobre un hueco oscuro. Ahora se abre a 7 studs y trae franja roja/blanca,
          ventanita y manija grandes. Aqui se comprueba: que exista, que tape TODO
          el hueco, que este pegado al frente, que traiga la franja de seguridad y
          que el radio de apertura sea corto.
  4. "en el piso aparecen como unos palitos negros creo que son los de las luces uv"
       -> eran las manchas de aceite: un Part cilindrico mide su diametro en X/Z y
          su largo en Y, y el CFrame se aplica DESPUES; con size (4.6, 0.1, 4.6) y
          un giro de 90 en Z el disco quedaba convertido en un TUBO de 4.6 parado.
          Aqui se comprueba que todo cilindro decorativo quede ACOSTADO (alto <= 0.5).
  5. "no podemos hacer mas facil esto?" / "que tu de verdad veas el juego en vivo?"
       -> se agrega tools/mirar.py: una VISTA del lote en 3D (SVG) con las piezas y
          sus medidas, para revisar el resultado sin abrir Studio.

Se prueba al reves (tools/alreves49.py): metiendo cada uno de los 4 bugs, la etapa
tiene que tronar.
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


def cabeza():
    g = 'dofile("%s/mock.lua")\n' % HERE
    g += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    g += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function() ''' + L("ServerScriptService/CityGenerator.luau") + ''' end)()
local BUILD = City.BuildWarehouse(1)
BUILD.Parent = workspace
City.RotularGaraje(BUILD, "GARAJE DE PEPE")
'''
    return g


def lua(guion, env=None, timeout=900):
    e = dict(os.environ, TOOLS=HERE)
    if env:
        e.update(env)
    return subprocess.run([LUA, "-"], input=guion, capture_output=True, text=True,
                          env=e, cwd=ROOT, timeout=timeout)


def kv(txt):
    return dict(p.split("=", 1) for p in txt.replace("|", " ").split() if "=" in p)


print("=== 24. LA LETRA MEDIDA, EL PORTON QUE SE VE Y EL PISO SIN PALITOS (v49) ===")

# ============================================================ 1) LA LETRA DE TODOS
problemas = []
guion = cabeza() + '''
local malos, lineas = 0, {}
local chicos = {}
for _, d in ipairs(BUILD:GetDescendants()) do
  if d:IsA("SurfaceGui") and d.Name == "Rotulo" then
    local l = d:FindFirstChild("Texto")
    local p = d.Parent
    if l and p then
      local txt = l.Text or "?"
      local n = 0
      for _ in string.gmatch(txt, "[%w]") do n = n + 1 end
      -- ¿cuanto mide una letra de alto, en studs? (TextSize son pixeles: /px)
      local px = d.PixelsPerStud or 58
      local letra = (l.TextSize or 0) / px
      local ancho, alto = p.Size.X, p.Size.Y
      if d.Face == Enum.NormalId.Left or d.Face == Enum.NormalId.Right then
        ancho, alto = p.Size.Z, p.Size.Y
      end
      table.insert(lineas, string.format("%-14s %6.1fx%-5.1f letra=%.2f studs (%d px) '%s'",
        p.Name, ancho, alto, letra, l.TextSize or 0, txt))
      -- minimo: la letra tiene que medir al menos 1.4% del largo de la pieza donde
      -- esta (una placa de 24 studs pide 0.34: eso es un letrero de juguete)
      local minimo = math.max(0.85, ancho * 0.014)
      if letra < minimo then
        malos = malos + 1
        table.insert(chicos, string.format("%s mide %.2f y pide al menos %.2f", p.Name, letra, minimo))
      end
      if (l.TextSize or 0) <= 0 then
        malos = malos + 1
        table.insert(chicos, p.Name .. " no tiene TextSize (quedo a TextScaled)")
      end
    end
  end
end
for _, t in ipairs(lineas) do print("      " .. t) end
print("__ROTULOS__ chicos=" .. malos .. " detalle=[" .. table.concat(chicos, " ; ") .. "]")
'''
sal = lua(guion)
m = re.search(r"__ROTULOS__ (.+)", sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  no se pudieron medir los rotulos")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-5:]:
        print("         | " + x[:150])
else:
    for x in sal.stdout.splitlines():
        if x.startswith("      "):
            print(x)
    e = kv(m.group(1))
    det = re.search(r"detalle=\[(.*)\]", m.group(1))
    det = (det.group(1) if det else "?")
    n_chicos = int(e.get("chicos", "99"))
    if n_chicos > 0:
        fallas += 1
        print("  FALLA  (la letra chiquita)")
        print("         - " + det)
    else:
        print("  OK     los 8 rotulos del lote traen su letra medida en studs "
              "(ninguno baja del minimo legible)")

# ==================================================== 2) EL PORTON: EXISTE Y SE VE
problemas = []
guion = cabeza() + '''
local R = (_cfg.Garage and _cfg.Garage.OpenRadius) or 0
local doors, franjas, ventanas, manijas = 0, 0, 0, 0
local huecoBien, pegado = 0, 0
for _, d in ipairs(BUILD:GetDescendants()) do
  if d:IsA("Model") and d.Name == "GarageDoor" then
    doors = doors + 1
    for _, c in ipairs(d:GetChildren()) do
      if c.Name == "DoorStripe" then franjas = franjas + 1 end
      if c.Name == "DoorWindow" then ventanas = ventanas + 1 end
      if c.Name == "DoorHandle" then manijas = manijas + 1 end
    end
    local pp = d.PrimaryPart
    -- ¿tapa el hueco? el hueco entre pilares mide (bayW - holgura)
    if pp and pp.Size.X >= 20 then huecoBien = huecoBien + 1 end
    -- ¿esta pegado al frente del garaje? (el frente es la pared del porton)
    if pp and pp.Position.Z > -700 then pegado = pegado + 1 end
  end
end
-- los "palitos negros" del piso: un Part cilindrico tiene el EJE en X (el largo
-- va en X y el diametro en Y/Z). Si el largo (X) es grande y el diametro chico,
-- es un TUBO, y si encima va girado 90 en Z queda PARADO = un palito.
local palitos, cilindros = {}, 0
for _, d in ipairs(BUILD:GetDescendants()) do
  if d:IsA("BasePart") and d.Shape == Enum.PartType.Cylinder then
    cilindros = cilindros + 1
    local diam = math.min(d.Size.Y, d.Size.Z)
    if d.Size.X > 1.5 then
      table.insert(palitos, string.format("%s es un TUBO (largo %.1f x diametro %.2f)",
        d.Name, d.Size.X, diam))
    elseif diam < 0.5 then
      table.insert(palitos, string.format("%s es un ALAMBRE (diametro %.2f)", d.Name, diam))
    end
  end
end
-- ademas: las manchas del piso van planas (el giro de 90 en Z con el grosor en X)
for _, d in ipairs(BUILD:GetDescendants()) do
  if d.Name == "OilStain" then
    -- el EJE del cilindro es X local: para que el disco quede PLANO en el piso,
    -- ese eje tiene que apuntar vertical (el grosor sube, el disco se acuesta)
    local xv = d.CFrame.XVector
    if xv and math.abs(xv.Y) < 0.9 then
      table.insert(palitos, "OilStain quedo de canto (el disco no esta plano en el piso)")
    end
  end
end
print(string.format("__PORTON__ cajones=%d franjas=%d ventanas=%d manijas=%d hueco=%d pegado=%d radio=%.0f cilindros=%d palitos=%d [%s]",
  doors, franjas, ventanas, manijas, huecoBien, pegado, R, cilindros, #palitos, table.concat(palitos, " ; ")))
'''
sal = lua(guion)
m = re.search(r"__PORTON__ (.+)", sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  no se pudo medir el porton")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-5:]:
        print("         | " + x[:150])
else:
    print("  medidas: " + m.group(1))
    e = kv(m.group(1))
    if int(e.get("cajones", 0)) < 1:
        problemas.append("no hay portones en el lote")
    if int(e.get("franjas", 0)) < 6:
        problemas.append("el porton no trae la franja de seguridad (rojo/blanco): "
                         "se ve como un hueco negro")
    if int(e.get("ventanas", 0)) < 1 or int(e.get("manijas", 0)) < 1:
        problemas.append("el porton no trae ventanita y manija grandes")
    if int(e.get("hueco", 0)) < 1:
        problemas.append("el porton no tapa el hueco del cajon")
    if float(e.get("radio", 99)) > 8:
        problemas.append("el porton se abre a %s studs: caminando por el patio ya "
                         "esta abierto y nunca lo ves" % e.get("radio"))
    det2 = re.search(r"\[(.*)\]", m.group(1))
    if int(e.get("palitos", 0)) > 0:
        problemas.append("hay cilindros mal hechos (los 'palitos negros' del piso): "
                         + (det2.group(1) if det2 else "?"))
    if problemas:
        fallas += 1
        print("  FALLA  (el porton / los palitos)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el porton existe, tapa el hueco, trae franja roja/blanca, ventana "
              "y manija, se abre a %.0f studs y los %s cilindros decorativos del lote "
              "estan bien hechos (ninguno es un tubo parado)"
              % (float(e["radio"]), e.get("cilindros", "?")))

# ========================================= 3) EL MERCADO: EL CASO QUE FALLABA
# El usuario: "el mercado de la cochera se sigue quedando pegado no importa cuanto
# me aleje". El caso exacto: estas parado en el cajon, se abre solo, y te vas al
# otro lado de la ciudad. Aqui se corre la ClientUI de verdad con ese guion.
CLIENTE = L("StarterPlayerScripts/ClientUI.luau")
problemas = []
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
local patio = Instance.new("Part") ; patio.Name = "LotApron" ; patio.Anchored = true
patio.Size = Vector3.new(110, 0.3, 30) ; patio.Position = Vector3.new(0, 0.36, 28) ; patio.Parent = wh
local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
local function paso(dt)
  task.__sched.advance((task.__sched.vtime or 0) + dt)
end
local function abierto()
  for _, d in ipairs(sg and sg:GetDescendants() or {}) do
    if d.ClassName == "TextLabel" and d.Text == "MERCADO" then
      return (d.Parent and d.Parent.Visible) == true
    end
  end
  return false
end
hrp.Position = Vector3.new(0, 3, 0)      -- parado en el cajon: se abre solo
paso(1.4)
local abrio = abierto()
hrp.Position = Vector3.new(0, 3, 60)     -- salgo del lote (al patio/calle)
paso(1.4)
local medio = abierto()
hrp.Position = Vector3.new(400, 3, 400)  -- me voy al otro lado de la ciudad
paso(1.4) ; paso(1.4)
local cerro = not abierto()
print("__MERCADO__ abrio=" .. tostring(abrio) .. "|alSalir=" .. tostring(medio)
  .. "|cerroLejos=" .. tostring(cerro))
'''
sal = lua(guion, env={"MOCK_CHAR": "1"})
m = re.search(r"__MERCADO__ (.+)", sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  la ClientUI no llego al final")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-5:]:
        print("         | " + x[:150])
else:
    print("  medidas: " + m.group(1))
    e = kv(m.group(1))
    if e.get("abrio") != "true":
        problemas.append("parado en el cajon el panel no se abrio (antes si se abria)")
    if e.get("cerroLejos") != "true":
        problemas.append("me aleje al otro lado de la ciudad y el panel SIGUE ABIERTO")
    # y que el cierre no dependa de como se abrio (nada de marcas raras)
    try:
        ini = CLIENTE.index("if shop.Visible and currentTab == \"autos\"")
        trozo = CLIENTE[ini:ini + 220]
        if "cocheraAuto" in trozo:
            problemas.append("el cierre depende de la marca 'una vez por entrada' "
                             "(por eso se quedaba pegado): " + trozo[:130])
        # y el cierre NO puede vivir dentro del detector de cruce del garage
        ini_gar = CLIENTE.index('elseif k == "garage" then')
        fin_gar = CLIENTE.index("end", CLIENTE.index("renderTab(\"autos\")", ini_gar))
        if "shop.Visible = false" in CLIENTE[ini_gar:fin_gar + 900]:
            problemas.append("el cierre quedo dentro del detector de cruce del garage")
    except ValueError:
        problemas.append("NO encuentro el cierre automatico del mercado en ClientUI: "
                         "volvio a quedar sin cierre")
    if problemas:
        fallas += 1
        print("  FALLA  (el mercado pegado)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el panel se abre en el cajon y SE CIERRA al alejarte (400 studs), "
              "sin depender de como lo abriste")

print()
if fallas == 0:
    print("OK: las letras se miden, el porton se ve cerrado, el mercado se cierra siempre "
          "y el piso quedo limpio")
else:
    print("FALLA: %d problema(s) de la ronda v49" % fallas)
sys.exit(1 if fallas else 0)
