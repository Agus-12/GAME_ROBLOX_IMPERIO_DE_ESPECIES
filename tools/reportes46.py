#!/usr/bin/env python3
"""ETAPA 21 (v46): LOS 5 REPORTES DE LA CAPTURA DE LA NOCHE.

Lo que reporto el usuario (capturas del 25-sep 9:47/9:48 p.m.):

  1. "de noche la bodega y cochera demasiado iluminados por dentro"
       -> las lamparas de la nave y de la cochera iban a 1.1 / 1.15 de brillo con
          alcanza 42 y 24. Ahora tienen brillo de DIA y de NOCHE (0.75 / 0.45-0.5)
          y menos alcance. Aqui se PRENDE y se APAGA la noche de verdad (se llama
          al ciclo del juego) y se miden los brillos que quedan.
  2. "el garage sigue sin porton"
       -> el porton medía 12 de ancho (un numero fijo de GameConfig) pero el hueco
          entre pilares mide 24.6: tapaba la mitad y a los lados quedaban dos
          huecos negros. Ahora el ancho sale del hueco REAL y se mide la holgura.
  3. "los letreros aun tienen la letra demasiada pequeña"
       -> el tablero del garaje era de 17 x 3.6 con el texto escalado por envoltura
          (letra chiquita en medio de un tablero grande). Ahora el tablero es mas
          chico y el texto va en TextScaled SIN envolver: crece hasta llenarlo.
          Aqui se mide el tablero, los pixeles por stud y que el texto llene.
  4. "cuando me acerco a la cochera de repente se me abre el mercado"
       -> se medía la distancia al CENTRO del piso del garaje con radio 26, y el
          piso mide 26x24: el circulo llegaba a la calle. Aqui se ARRANCA la
          ClientUI de verdad, se mueve al personaje a la calle y se comprueba que
          el mercado NO se abre; despues se entra al taller y SI se abre.
  5. "la van sigue con las ruedas al revés dentro del garaje"
       -> la llanta se armaba con CFrame.Angles(0, 0, 90) y quedaba PARADA (las
          caras redondas al cielo). Aqui se arma la van y se mide el EJE de cada
          llanta: tiene que quedar horizontal y con su rin pegado.

Probado al reves (v46): devolviendo el porton a 12 de ancho, la llanta a 90
grados, las luces a 1.15 y la regla vieja de la cochera, esta etapa caza los 4.
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
    """el entorno del simulador + las 3 librerias que hace falta cargar"""
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


print("=== 21. LA NOCHE: LUCES, PORTON, LETREROS, EL MERCADO Y LA VAN (v46) ===")

# ============================================================ 1) LAS RUEDAS
guion = cabeza()
guion += '''
local spec
for _, v in ipairs(_cfg.Vehicles) do if v.Id == "van" then spec = v end end
local okc, car = pcall(function() return City.BuildCar(spec, CFrame.new(0, 2, 0), true) end)
if not okc then print("__RUEDAS__ trono: " .. tostring(car)) return end

-- El eje de una llanta cilindrica es el eje X del Size. Con la rotacion anotada
-- en el simulador (v46) se calcula a donde apunta ese eje en el mundo.
-- Rz(Z) y luego Ry(Y) aplicadas a (1,0,0):
local function eje(pieza)
  local r = (pieza.CFrame and pieza.CFrame.rot) or {X = 0, Y = 0, Z = 0}
  local cz, sz = math.cos(r.Z), math.sin(r.Z)
  local cy, sy = math.cos(r.Y), math.sin(r.Y)
  return Vector3.new(cz * cy, sz, -cz * sy)
end

local llantas, paradas, sinRin, rines = 0, 0, 0, 0
local rinOtroEje, detalle = 0, ""
for _, d in ipairs(car:GetChildren()) do
  -- es una llanta: cilindro acostado (grueso sobre X, redondo en Y/Z). OJO: no
  -- se compara d.Shape contra Enum.PartType.Cylinder porque el simulador devuelve
  -- tablas nuevas cada vez y la comparacion seria siempre falsa (me paso).
  local redonda = math.abs(d.Size.Y - d.Size.Z) < 0.01 and d.Size.X < d.Size.Y
  if d.Name == "Wheel" and redonda then
    llantas = llantas + 1
    local e = eje(d)
    -- |e.Y| = 1 significa el eje apuntando al cielo: la llanta esta PARADA
    if math.abs(e.Y) > 0.05 then paradas = paradas + 1 end
    local rin, hub
    for _, h in ipairs(car:GetChildren()) do
      if (h.Position - d.Position).Magnitude < 0.01 then
        if h.Name == "Rim" then rin = h end
        if h.Name == "Hub" then hub = h end
      end
    end
    if rin then
      rines = rines + 1
      if math.abs(eje(rin).Y) > 0.05 then rinOtroEje = rinOtroEje + 1 end
    else
      sinRin = sinRin + 1
    end
    if llantas == 1 then detalle = string.format("ejeY=%.2f", e.Y) end
  end
end
print("__RUEDAS__ llantas=" .. llantas .. "|paradas=" .. paradas .. "|rines=" .. rines ..
  "|rinOtroEje=" .. rinOtroEje .. "|" .. detalle)
'''
sal = lua(guion)
m = re.search(r"__RUEDAS__ (.+)", sal.stdout + sal.stderr)
problemas = []
if not m:
    fallas += 1
    problemas.append("la van no se pudo armar")
    print("  FALLA  la van no se pudo armar")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-4:]:
        print("         | " + x[:150])
else:
    d = dict(kv.split("=") for kv in m.group(1).split("|") if "=" in kv)
    print("  medidas: " + m.group(1))
    if int(d.get("llantas", 0)) < 4:
        problemas.append("solo %s llantas (deberian ser 4)" % d.get("llantas"))
    if int(d.get("paradas", 0)) > 0:
        problemas.append("%s llanta(s) PARADAS: el eje mira al cielo (asi se veian "
                         "'al reves' desde afuera)" % d.get("paradas"))
    if int(d.get("sinRin", 0)) > 0:
        problemas.append("hay llantas sin rin")
    if int(d.get("rinOtroEje", 0)) > 0:
        problemas.append("el rin de %s llanta(s) quedo en otro eje que la goma" % d.get("rinOtroEje"))
    if problemas:
        fallas += 1
        print("  FALLA  (las ruedas de la van)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     las 4 llantas de la van van ACOSTADAS (eje horizontal) "
              "y con su rin en el mismo eje")

# ============================================ 2) EL PORTON TAPA EL HUECO
problemas = []
guion = cabeza()
guion += '''
local okw, wh = pcall(function() return City.BuildWarehouse(1) end)
if not okw then print("__PORTON__ trono: " .. tostring(wh)) return end
local puertas, peorHolgura, peorArriba, detalle = 0, -99, -99, ""
for _, d in ipairs(wh:GetDescendants()) do
  if d:IsA("Model") and d.Name == "GarageDoor" then
    puertas = puertas + 1
    local slab
    for _, h in ipairs(d:GetChildren()) do if h.Name == "DoorSlab" then slab = h end end
    if slab then
      local zPared = slab.Position.Z + 0.35          -- el frente de la pared
      local izq, der = -1e9, 1e9
      local dintelAbajo = 1e9
      for _, w2 in ipairs(wh:GetDescendants()) do
        if w2:IsA("BasePart") and w2.Name == "GarageWall"
           and math.abs(w2.Position.Z - zPared) < 0.4 then
          if w2.Size.Y >= 6 then                     -- pilar
            if w2.Position.X < slab.Position.X then
              izq = math.max(izq, w2.Position.X + w2.Size.X * 0.5)
            elseif w2.Position.X > slab.Position.X then
              der = math.min(der, w2.Position.X - w2.Size.X * 0.5)
            end
          else                                       -- dintel
            dintelAbajo = math.min(dintelAbajo, w2.Position.Y - w2.Size.Y * 0.5)
          end
        end
      end
      local hueco = der - izq
      -- cuanto hueco se queda SIN porton, a los lados (entre los dos lados, el peor)
      local holgura = hueco - slab.Size.X
      -- y cuanto hueco queda ARRIBA del porton
      local arriba = dintelAbajo - (slab.Position.Y + slab.Size.Y * 0.5)
      local abajo = slab.Position.Y - slab.Size.Y * 0.5
      if holgura > peorHolgura then peorHolgura = holgura end
      if arriba > peorArriba then peorArriba = arriba end
      detalle = string.format("hueco=%.1f ancho=%.1f alto=%.1f abajo=%.2f",
        hueco, slab.Size.X, slab.Size.Y, abajo)
    end
  end
end
print("__PORTON__ puertas=" .. puertas ..
  "|holgura=" .. string.format("%.2f", peorHolgura) ..
  "|arriba=" .. string.format("%.2f", peorArriba) .. "|" .. detalle)
'''
sal = lua(guion)
m = re.search(r"__PORTON__ puertas=(\d+)\|holgura=(-?[\d.]+)\|arriba=(-?[\d.]+)\|(.*)", sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  la bodega no se pudo construir (portones)")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-4:]:
        print("         | " + x[:150])
else:
    puertas = int(m.group(1))
    holgura = float(m.group(2))
    arriba = float(m.group(3))
    print("  medidas: " + m.group(4))
    if puertas < 1:
        problemas.append("la bodega no tiene portones")
    # a los lados: el porton tiene que tapar casi todo el hueco
    if holgura > 0.6:
        problemas.append("queda(n) %.2f studs de hueco SIN porton a los lados "
                         "(se ve el taller por la orilla)" % holgura)
    if holgura < 0:
        problemas.append("el porton es mas ancho que el hueco (%.2f): se mete en los pilares" % holgura)
    # arriba: entre el porton y el dintel no debe quedar una franja abierta
    if arriba > 0.35:
        problemas.append("queda una franja de %.2f studs abierta arriba del porton" % arriba)
    if arriba < -0.05:
        problemas.append("el porton choca con el dintel (%.2f)" % arriba)
    if problemas:
        fallas += 1
        print("  FALLA  (el porton del garaje)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el porton tapa el hueco completo (holgura %.2f studs a los "
              "lados, %.2f arriba)" % (holgura, arriba))

# ================================================= 3) LAS LUCES DE NOCHE
problemas = []
guion = cabeza()
guion += '''
local okw, wh = pcall(function() return City.BuildWarehouse(1) end)
if not okw then print("__LUCES__ trono: " .. tostring(wh)) return end
-- el ciclo de verdad del juego (cielo, efectos y el prende/apaga de luces)
City.SetupLighting()

local function lucesDe(nombre)
  local out = {}
  for _, d in ipairs(wh:GetDescendants()) do
    if d:IsA("BasePart") and d.Name == nombre then
      for _, h in ipairs(d:GetChildren()) do
        if h:IsA("Light") then table.insert(out, h) end
      end
    end
  end
  return out
end
local function mide(lista)
  local n, maxB, maxR, minB, suma = 0, 0, 0, 99, 0
  for _, l in ipairs(lista) do
    n = n + 1
    maxB = math.max(maxB, l.Brightness or 0)
    maxR = math.max(maxR, l.Range or 0)
    minB = math.min(minB, l.Brightness or 0)
    suma = suma + (l.Brightness or 0)
  end
  if n == 0 then minB = 0 end
  return n, maxB, maxR, minB, suma
end

City.SetCityLights(true)      -- NOCHE
local gN_n, gN_max, gN_alc = mide(lucesDe("GarageLamp"))
local nN_n, nN_max, nN_alc, nN_min, nN_suma = mide(lucesDe("NaveLamp"))
local fN_n, fN_max = mide(lucesDe("GarageWallLamp"))
City.SetCityLights(false)     -- DIA (las de adentro NO se apagan)
local gD_n, gD_max = mide(lucesDe("GarageLamp"))
local nD_n, nD_max, nD_alc, nD_min = mide(lucesDe("NaveLamp"))
print(string.format("__LUCES__ cocheraNoche=%.2f|cocheraAlc=%.0f|cocheraDia=%.2f|" ..
  "naveNocheMax=%.2f|naveAlc=%.0f|naveDiaMin=%.2f|naveSumaNoche=%.2f|fachadaNoche=%.2f|n=%d/%d",
  gN_max, gN_alc, gD_max, nN_max, nN_alc, nD_min, nN_suma, fN_max, gN_n, nN_n))
'''
sal = lua(guion)
m = re.search(r"__LUCES__ (.+)", sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  las luces no se pudieron medir")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-4:]:
        print("         | " + x[:150])
else:
    d = dict(kv.split("=") for kv in m.group(1).split("|") if "=" in kv)
    print("  medidas: " + m.group(1))
    if int(d["n"].split("/")[0] or 0) < 1:
        problemas.append("el cajon no tiene lampara de techo")
    if int(d["n"].split("/")[1] or 0) < 1:
        problemas.append("la nave no tiene lamparas")
    if float(d["cocheraNoche"]) > 0.6:
        problemas.append("la lampara de la cochera queda en %.2f de noche: lavada"
                         % float(d["cocheraNoche"]))
    if float(d["cocheraAlc"]) > 20:
        problemas.append("la lampara de la cochera alcanza %.0f studs: se sale por "
                         "la puerta a la calle" % float(d["cocheraAlc"]))
    if float(d["naveNocheMax"]) > 0.6:
        problemas.append("las lamparas de la nave quedan en %.2f de noche: lavada"
                         % float(d["naveNocheMax"]))
    if float(d["naveAlc"]) > 32:
        problemas.append("las lamparas de la nave alcanzan %.0f studs" % float(d["naveAlc"]))
    if float(d["naveSumaNoche"]) > 2.0:
        problemas.append("las 3 lamparas de la nave suman %.2f de brillo de noche"
                         % float(d["naveSumaNoche"]))
    if float(d["cocheraDia"]) < 0.4:
        problemas.append("de DIA la cochera queda en %.2f: se ve negra adentro "
                         "(el reporte de la ronda v42 vuelve)" % float(d["cocheraDia"]))
    if float(d["naveDiaMin"]) < 0.4:
        problemas.append("de DIA la nave queda en %.2f: se ve negra adentro" % float(d["naveDiaMin"]))
    if float(d["fachadaNoche"]) > 1.1:
        problemas.append("la lampara de la fachada queda en %.2f de noche"
                         % float(d["fachadaNoche"]))
    if problemas:
        fallas += 1
        print("  FALLA  (las luces de noche)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     de noche la cochera y la nave quedan SUAVES (%.2f / %.2f) y "
              "de dia siguen prendidas (%.2f / %.2f)"
              % (float(d["cocheraNoche"]), float(d["naveNocheMax"]),
                 float(d["cocheraDia"]), float(d["naveDiaMin"])))

# ==================================== 4) LOS LETREROS: LETRA QUE LLENA
problemas = []
guion = cabeza()
guion += '''
local okw, wh = pcall(function() return City.BuildWarehouse(1) end)
if not okw then print("__LETRERO__ trono: " .. tostring(wh)) return end
local gar = wh:FindFirstChild("GarageSign", true)
local cambios = City.RotularGaraje(wh, "GARAJE DE PEPE")
local sg = gar and gar:FindFirstChild("Rotulo")
local lbl = sg and sg:FindFirstChild("Texto")
local caja = wh:FindFirstChild("BayPlate", true)
local sgC = caja and caja:FindFirstChild("Rotulo")
local texto = lbl and lbl.Text or "?"
local dosRenglones = string.find(texto, string.char(10)) ~= nil
-- letra estimada (v48): el texto va en UN renglon en un tablero ancho; la letra
-- mas grande que cabe es la menor de (el alto del tablero) o (el ancho repartido
-- entre las letras pintadas). Se cuentan las letras del texto.
local letras = 0
for _ in string.gmatch(texto, "[%w]") do letras = letras + 1 end
print(string.format("__LETRERO__ anchoTablero=%.1f|altoTablero=%.1f|px=%s|pxCaja=%s|" ..
  "scaled=%s|wrapped=%s|dosRenglones=%s|letras=%d|textSize=%s|texto=%s",
  gar and gar.Size.X or 0, gar and gar.Size.Y or 0,
  sg and sg.PixelsPerStud or 0, sgC and sgC.PixelsPerStud or 0,
  tostring(lbl and lbl.TextScaled), tostring(lbl and lbl.TextWrapped),
  tostring(dosRenglones), letras, tostring(lbl and lbl.TextSize),
  string.gsub(texto, string.char(10), " + ")))
'''
sal = lua(guion)
m = re.search(r"__LETRERO__ (.+)", sal.stdout + sal.stderr)
if not m:
    fallas += 1
    print("  FALLA  el letrero del garaje no se pudo medir")
    for x in (sal.stdout + sal.stderr).strip().splitlines()[-4:]:
        print("         | " + x[:150])
else:
    d = dict(kv.split("=") for kv in m.group(1).split("|") if "=" in kv)
    print("  medidas: " + m.group(1))
    # v49 (CUARTO reporte del usuario: "la letra sigue quedando re chiquita"): el
    # tamaño ya NO se estima ni se deja a TextScaled: se MIDE el TextSize real del
    # rotulo y se convierte a studs con los pixeles por stud del tablero.
    letras = max(1, int(float(d.get("letras", 1))))
    px = float(d.get("px", 0)) or 1
    letra = float(d.get("textSize", 0) or 0) / px
    if float(d["anchoTablero"]) < 20:
        problemas.append("el tablero mide %.1f de ancho: con menos de 20 la letra no "
                         "tiene de donde crecer" % float(d["anchoTablero"]))
    if float(d.get("textSize", 0) or 0) <= 0:
        problemas.append("el rotulo NO trae tamaño medido (TextSize=0): vuelve a estar "
                         "en manos de TextScaled, que es lo que se ve chiquito")
    elif letra < 2.4:
        problemas.append("la letra mide %.2f studs: sigue pequeña (el usuario lo "
                         "reporto CUATRO veces)" % letra)
    if int(float(d["px"])) < 90:
        problemas.append("el tablero del garaje va a %s pixeles por stud: la letra "
                         "sale pixelada" % d["px"])
    if int(float(d["pxCaja"])) < 88:
        problemas.append("las placas de cajon van a %s pixeles por stud" % d["pxCaja"])
    if d["scaled"] == "true" and float(d.get("textSize", 0) or 0) <= 0:
        problemas.append("el texto del garaje quedo en TextScaled sin tamaño medido")
    if d["wrapped"] == "true":
        problemas.append("el texto del garaje esta envuelto (TextWrapped): con eso "
                         "el escalado lo deja chiquito")
    if d["dosRenglones"] == "true":
        problemas.append("'GARAJE DE PEPE' va en DOS renglones: cada uno cabe en medio "
                         "tablero y la letra sale chiquita (la v48 lo pide en uno)")
    if problemas:
        fallas += 1
        print("  FALLA  (los letreros)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el tablero del garaje mide %.1f x %.1f con letra de ~%.1f "
              "studs, a %s px/stud, en UN renglon"
              % (float(d["anchoTablero"]), float(d["altoTablero"]), letra, d["px"]))

# ============================= 5) EL MERCADO NO SE ABRE EN LA CALLE
problemas = []
CLIENTE = L("StarterPlayerScripts/ClientUI.luau")
guion = 'dofile("%s/mockclient.lua")\n' % HERE
guion += "local __cli = function()\n" + CLIENTE + "\nend\n__cli()\n"
guion += '''
if task.__sched then task.__sched.advance(2) end
local plr = game:GetService("Players").LocalPlayer
local pg = plr:FindFirstChild("PlayerGui")
local sg = pg and pg:FindFirstChild("SpiceEmpireUI")
-- una bodega de mentiras con el piso del garaje en el origen: 26 x 24 studs
local wh = Instance.new("Model") ; wh.Name = "Warehouse_" .. plr.UserId ; wh.Parent = workspace
local piso = Instance.new("Part") ; piso.Name = "GarageFloor" ; piso.Anchored = true
piso.Size = Vector3.new(26, 2, 24) ; piso.Position = Vector3.new(0, 1, 0) ; piso.Parent = wh
local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")

local function mercadoAbierto()
  for _, d in ipairs(sg and sg:GetDescendants() or {}) do
    if d.ClassName == "TextLabel" and d.Text == "MERCADO" then
      local p = d.Parent
      if p and p.Visible then return true end
    end
  end
  return false
end
-- OJO: advance() recibe el tiempo ABSOLUTO (no segundos de mas). Con advance(1)
-- despues de avanzar 2 segundos, el reloj se quedaba en 2 y el bucle del cliente
-- no corria ni una vez (por eso el mercado "no se abria" en mi propia prueba).
local function pararse(x, z)
  hrp.Position = Vector3.new(x, 3, z)
  task.__sched.advance((task.__sched.vtime or 0) + 1.5)
end

local okCalle, okAdentro = false, false
if hrp then
  pararse(0, 16)                 -- en la CALLE, 4 studs frente al porton
  okCalle = mercadoAbierto()
  pararse(0, 0)                  -- adentro del taller
  okAdentro = mercadoAbierto()
  -- y de nuevo afuera, al otro lado, para que no quede pegado
  pararse(0, 20)
end
print("__MERCADO__ calle=" .. tostring(okCalle) .. "|adentro=" .. tostring(okAdentro) ..
  "|hayHrp=" .. tostring(hrp ~= nil))
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
    if d.get("hayHrp") != "true":
        problemas.append("el simulador no dio personaje (no se pudo probar)")
    if d.get("calle") == "true":
        problemas.append("el mercado SE ABRE en la calle, pasando frente al porton "
                         "(es justo el reporte del usuario)")
    if d.get("adentro") != "true":
        problemas.append("adentro del taller el mercado NO se abre (ahi si lo quieres)")
    if problemas:
        fallas += 1
        print("  FALLA  (el mercado que se abria solo)")
        for x in problemas:
            print("         - " + x)
    else:
        print("  OK     el mercado NO se abre en la calle y SI adentro del taller")

print()
if fallas:
    print("FALLA: %d problema(s) de la captura de la noche" % fallas)
    sys.exit(1)
print("OK: luces suaves de noche, porton que tapa el hueco, letreros grandes, "
      "el mercado solo adentro y la van con las llantas bien")
