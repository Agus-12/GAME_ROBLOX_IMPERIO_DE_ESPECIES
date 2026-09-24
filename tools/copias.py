#!/usr/bin/env python3
"""Prueba el caso REAL del usuario: carpetas Remotes de mas y copias pegadas.

POR QUE EXISTE
  El usuario mando una captura con el cartel "HAY COPIAS PEGADAS EN STUDIO" y
  dos carpetas Remotes en ReplicatedStorage. Con eso a la vista:
    * el cliente tiene que agarrar SIEMPRE la carpeta buena (la que el servidor
      marco con la etiqueta Build de ESTA ronda), no "la mas grande" ni la
      primera que aparezca;
    * si la buena esta completa, NO tiene que salir el cartel rojo que asusta:
      solo un avisito de que hay basura vieja de sobra;
    * el servidor tiene que limpiar las Remotes viejas al arrancar Y volver a
      revisar despues (si aparece otra, es que hay un segundo Main corriendo).

ESCENARIOS
  1) servidor: 3 carpetas Remotes + 2 Main + 2 bodegas guardadas  -> queda 1
  2) cliente: Remotes buena (con etiqueta) + vieja llena          -> avisito, sin cartel
  3) cliente: la buena esta INCOMPLETA (le faltan 2)              -> cartel (si hay que arreglar)
  4) cliente: dos carpetas viejas (ninguna con etiqueta)          -> cartel con nombres
  5) cliente: dos carpetas con etiqueta (una de una partida vieja)-> usa la buena

Uso:  python3 tools/copias.py
"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")
if not os.path.exists(LUA):
    sys.exit("Falta Lua. Corre primero:  bash tools/setup.sh")

fallas = 0


def L(f):
    return strip_luau(open(os.path.join(ROOT, f)).read()).replace("goto cont", "_SKIP=true")


# variables de entorno del cliente simulado (sin esto, mockclient.lua no sabe
# el tamano de pantalla ni encuentra cfgload.lua)
ENTORNO = dict(os.environ, MOCK_VW="896", MOCK_VH="414", MOCK_TOUCH="1",
               MOCK_CITY="1", MOCK_CHAR="1", MOCK_CHAR_DELAY="0",
               MOCK_SERVER_MUDO="0", TOOLS=HERE)


def lua(guion, timeout=240, env=None):
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
    t.write(guion)
    t.close()
    # SIEMPRE se pasa TOOLS: el mock lo necesita para encontrar clases-roblox.txt
    # (validacion de Instance.new) y cfgload.lua. Sin esto, esas validaciones se
    # apagaban solas en los escenarios que no armaban su propio entorno (falso verde).
    usar = dict(os.environ, TOOLS=HERE)
    if env:
        usar.update(env)
    r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=timeout,
                       env=usar)
    os.unlink(t.name)
    return r.stdout + ("\nSTDERR: " + r.stderr if r.stderr else "")


def version():
    ui = open(os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau"), encoding="utf-8").read()
    m = re.search(r'MI_VERSION\s*=\s*"([^"]+)"', ui)
    return m.group(1) if m else "v?"


RONDA = version()

# ----------------------------------------------------------------- 1) SERVIDOR
# el cliente simulado carga el GameConfig ya serializado
cfg, city, data, main = (L("ReplicatedStorage/GameConfig.luau"),
                         L("ServerScriptService/CityGenerator.luau"),
                         L("ServerScriptService/DataService.luau"),
                         L("ServerScriptService/Main.luau"))
open(os.path.join(HERE, "cfgload.lua"), "w").write(
    "return (function()\n" + cfg + "\nend)()\n")

guion = 'dofile("%s/mock.lua")\n' % HERE
guion += 'local _cfg=(function()\n%s\nend)()\n' % cfg
guion += '''
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
  return {} end
_city=(function()
''' + city + '''
end)()
_data=(function()
''' + data + '''
end)()
-- ===== el Studio del usuario =====
for i, n in ipairs({"Remotes", "Remotes2", "Remotes3"}) do
  local f=Instance.new("Folder") ; f.Name=n ; f.Parent=rs
  for k=1,9 do local e=Instance.new("RemoteEvent") ; e.Name="Viejo"..k ; e.Parent=f end
end
for i=1,2 do
  local w=Instance.new("Model") ; w.Name="Warehouse_999"..i ; w.Parent=workspace
end
local m1=Instance.new("Script") ; m1.Name="Main"  ; m1.Parent=sss
local m2=Instance.new("Script") ; m2.Name="Main2" ; m2.Parent=sss
local function contar(p, pref)
  local n=0
  for _, c in ipairs(p:GetChildren()) do
    if string.sub(c.Name,1,#pref)==pref then n=n+1 end
  end
  return n
end
print("ANTES  -> Remotes: "..contar(rs,"Remotes").."  bodegas viejas: 2  Main: "..contar(sss,"Main"))
local ok,err=pcall(function()
''' + main + '''
end)
if task.__sched then task.__sched.advance(20) end      -- corre tambien los re-chequeos
local nr=contar(rs,"Remotes")
local nw=0
for _, c in ipairs(workspace:GetChildren()) do
  if string.sub(c.Name,1,9)=="Warehouse" then nw=nw+1 end
end
print("DESPUES -> Remotes: "..nr.."  bodegas viejas: "..nw.."  ("..(ok and "Main corrio completo" or ("!! "..tostring(err)))..")")
'''
sal = lua(guion)
print("=== 1. SERVIDOR: limpia carpetas Remotes y bodegas guardadas ===")
for linea in sal.strip().splitlines():
    if linea.startswith(("ANTES", "DESPUES", "[SpiceEmpire]")):
        print("  " + linea[:150])
m = re.search(r"DESPUES -> Remotes: (\d+)  bodegas viejas: (\d+)  \((.*?)\)", sal)
if not m:
    print("  FALLA  no pude leer el resultado (ver el guion arriba)")
    fallas += 1
else:
    nr, nw, fin = int(m.group(1)), int(m.group(2)), m.group(3)
    ok = (nr == 1 and nw == 0 and fin == "Main corrio completo")
    print("  %s  queda 1 carpeta Remotes, 0 bodegas viejas y Main corre" % ("OK   " if ok else "FALLA"))
    if not ok:
        fallas += 1

# ------------------------------------------------------------------ 2..5) CLIENTE
CLIENTE = L("StarterPlayerScripts/ClientUI.luau")
NEEDED = ["StateUpdate", "PhoneAlert", "Toast", "MissionUpdate", "IncomingCall", "OpenUpgrades",
          "OpenVault", "Sfx", "Shoot", "TerritoryUpdate", "Action"]


def siembra(remotes, con_etiqueta, sin_etiqueta, faltan_en_buena):
    """Arma el escenario dentro del cliente simulado."""
    s = """
-- ===== siembra del escenario =====
local rs2 = game:GetService("ReplicatedStorage")
local base = nil
for _, c in ipairs(rs2:GetChildren()) do
  if c.Name == "Remotes" then base = c end
end
"""
    if con_etiqueta:
        s += 'base:SetAttribute("Build", "%s")\n' % RONDA
        if faltan_en_buena:
            s += """local quitar = {"%s", "%s"}
for _, c in ipairs(base:GetChildren()) do
  for _, n in ipairs(quitar) do if c.Name == n then c:Destroy() end end
end
""" % tuple(faltan_en_buena)
    else:
        s += 'base:SetAttribute("Build", nil)\n'
    if sin_etiqueta == "llena":
        s += """local f = Instance.new("Folder") ; f.Name = "Remotes2" ; f.Parent = rs2
for _, n in ipairs({%s}) do
  local e = Instance.new("RemoteEvent") ; e.Name = n ; e.Parent = f
end
""" % ", ".join('"%s"' % n for n in NEEDED)
    elif sin_etiqueta == "vacia":
        s += 'local f = Instance.new("Folder") ; f.Name = "Remotes2" ; f.Parent = rs2\n'
    return s


# (el conteo de conexiones por carpeta vive en tools/mockclient.lua: tiene que
# ver tambien las carpetas que se crean DESPUES, como en la carrera)


def corre_cliente(nombre, cuerpo, avanza=8.0):
    guion = 'dofile("%s/mockclient.lua")\n' % HERE
    guion += cuerpo
    # el codigo del cliente se encierra en su propia funcion: asi sus locales no
    # se suman a los del guion (Lua/Roblox permiten 200 por funcion) y la prueba
    # mide lo mismo que corre el juego.
    guion += "local __cli = function()\n" + CLIENTE + "\nend\n__cli()\n"
    guion += '''
-- el veredicto del cliente se da a los 1.5 s y a los 4.5 s: hay que dejar correr
-- el reloj virtual antes de mirar la pantalla
if task.__sched then task.__sched.advance(%s) end
local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local cartel = pg and pg:FindFirstChild("SpiceEmpire_Error")
local aviso  = pg and pg:FindFirstChild("SpiceEmpire_Avisito")
local enganchados = {}
for k, v in pairs(_G.__CON or {}) do
  if v > 0 then table.insert(enganchados, k .. "=" .. v) end
end
table.sort(enganchados)
print("__RESULTADO__ cartel=" .. tostring(cartel ~= nil) .. " aviso=" .. tostring(aviso ~= nil) ..
  " enganchados=" .. table.concat(enganchados, ","))
''' % str(avanza)
    sal = lua(guion, env=ENTORNO)
    m = re.search(r"__RESULTADO__ cartel=(\w+) aviso=(\w+) enganchados=(\S*)", sal)
    if not m:
        print("  FALLA  %s: el cliente no llego al final" % nombre)
        for linea in sal.strip().splitlines()[-8:]:
            print("         | " + linea[:140])
        return None
    return m.group(1) == "true", m.group(2) == "true", m.group(3)


CASOS = [
    # nombre, etiqueta buena, la otra, faltan en la buena, cartel?, aviso?
    ("2. cliente: la buena (con etiqueta) + vieja LLENA  -> solo avisito",
     True, "llena", None, False, True),
    ("3. cliente: la buena esta INCOMPLETA (le faltan 2) -> cartel",
     True, "llena", ("Shoot", "TerritoryUpdate"), True, False),
    ("4. cliente: dos VIEJAS (sin etiqueta)              -> cartel",
     False, "llena", None, True, False),
    ("5. cliente: la buena + vieja VACIA                 -> solo avisito",
     True, "vacia", None, False, True),
]

print()
for nombre, etiqueta, otra, faltan, cartel_esperado, aviso_esperado in CASOS:
    print("=== %s ===" % nombre)
    res = corre_cliente(nombre, siembra(True, etiqueta, otra, faltan))
    if res is None:
        fallas += 1
        continue
    cartel, aviso, enganchados = res
    ok = (cartel == cartel_esperado) and (aviso == aviso_esperado)
    print("  %s  cartel rojo: %s (esperado %s)   avisito: %s (esperado %s)" % (
        "OK   " if ok else "FALLA",
        "si" if cartel else "no", "si" if cartel_esperado else "no",
        "si" if aviso else "no", "si" if aviso_esperado else "no"))
    print("         enganchado a: %s" % (enganchados or "(nada)"))
    if not ok:
        fallas += 1

# ------------------------------------------------- 6) LA CARRERA (caso real v34)
# El cliente arranca ANTES de que el servidor cree su carpeta: al principio solo
# ve la carpeta VIEJA guardada en el lugar. A los 0.6 s el servidor la borra y
# crea la suya con sello. El cliente tiene que MUDARSE solo, sin cartel y sin
# quedarse con remotes muertos.
print()
print("=== 6. LA CARRERA: el servidor crea su carpeta 0.6 s DESPUES ===")


def corre_carrera():
    guion = 'dofile("%s/mockclient.lua")\n' % HERE
    guion += CLIENTE
    guion += '''
if task.__sched then task.__sched.advance(8.0) end
local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local cartel = pg and pg:FindFirstChild("SpiceEmpire_Error")
local aviso  = pg and pg:FindFirstChild("SpiceEmpire_Avisito")
local vivos, muertos = {}, {}
for k, v in pairs(_G.__CON or {}) do
  if v > 0 then table.insert(vivos, k .. "=" .. v) else table.insert(muertos, k) end
end
table.sort(vivos) ; table.sort(muertos)
print("__CARRERA__ cartel=" .. tostring(cartel ~= nil) .. " aviso=" .. tostring(aviso ~= nil) ..
  " vivos=" .. table.concat(vivos, ",") .. " muertos=" .. table.concat(muertos, ";"))
'''
    env = dict(ENTORNO, MOCK_REMOTES_TARDE="1")
    return lua(guion, env=env)


sal = corre_carrera()
m = re.search(r"__CARRERA__ cartel=(\w+) aviso=(\w+) vivos=(\S*) muertos=(.*)", sal)
if not m:
    print("  FALLA  no pude leer el resultado")
    for linea in sal.strip().splitlines()[-8:]:
        print("         | " + linea[:140])
    fallas += 1
else:
    cartel, aviso, vivos, muertos = m.group(1) == "true", m.group(2) == "true", m.group(3), m.group(4)
    fin = [k for k in vivos.split(",") if k.startswith("Remotes#true")]
    vieja_viva = [k for k in vivos.split(",") if k.startswith("Remotes#false")]
    vieja_muerta = [k for k in (vivos + "," + muertos).split(",") if k.startswith("Remotes#false=")]
    ok = (not cartel) and (not aviso) and fin and not vieja_viva and (not vieja_muerta or "=0" in str(vieja_muerta))
    print("  %s  cartel: %s   avisito: %s" % ("OK   " if ok else "FALLA",
                                              "si" if cartel else "no", "si" if aviso else "no"))
    print("         escuchando la carpeta del servidor: %s" % (", ".join(fin) or "NO"))
    print("         todavia enganchado a la vieja:      %s" % (", ".join(vieja_viva) or "no (bien)"))
    print("         desconectado de la vieja:            %s" % (", ".join(vieja_muerta) or "si (bien)"))
    if not ok:
        fallas += 1

# ------------------------------------------------- 7) DOS ClientUI CORRIENDO
# Caso real (v35): el usuario tenia la ronda nueva pegada, pero seguia corriendo
# una ClientUI VIEJA en otra parte del lugar. El cartel que veia era el de la
# COPIA (decia "esta ronda es v32" con el servidor ya en v34). Ahora la copia se
# apaga sola y lo dice en la consola.
print()
print("=== 7. DOS ClientUI corriendo: la copia se apaga sola ===")


def corre_dos_clientes():
    guion = 'dofile("%s/mockclient.lua")\n' % HERE
    guion += "-- primera copia (la buena)\n"
    guion += "local ok1, err1 = pcall(function()\n" + CLIENTE + "\nend)\n"
    guion += 'print("__COPIA1__ ok=" .. tostring(ok1))\n'
    guion += "-- segunda copia (la que sobra)\n"
    guion += "local ok2, err2 = pcall(function()\n" + CLIENTE + "\nend)\n"
    guion += 'print("__COPIA2__ ok=" .. tostring(ok2))\n'
    return lua(guion, env=ENTORNO)


sal = corre_dos_clientes()
ui = sal.count("[SpiceEmpire] UI cargada.")
se_apago = "HAY OTRA ClientUI CORRIENDO" in sal
ok = (ui == 1) and se_apago
print("  %s  el juego salio %d vez (debe ser 1) y la copia aviso que se apaga: %s" %
      ("OK   " if ok else "FALLA", ui, "si" if se_apago else "no"))
if not ok:
    for linea in sal.strip().splitlines()[-6:]:
        print("         | " + linea[:140])
    fallas += 1

# ------------------------------- 8) INTERFAZ VIEJA GUARDADA EN EL LUGAR (StarterGui)
# EL BUG DE LA v37: si en el lugar quedo guardada una interfaz del juego (por
# ejemplo en StarterGui, que Roblox mete en pantalla al arrancar), la ClientUI
# nueva la tomaba por "otra copia corriendo" y SE APAGABA A SI MISMA (con cartel
# rojo). Resultado: el jugador pegaba los archivos y seguia viendo el tablero
# viejo: "no cambio nada". Ahora borra esa basura y sigue dibujando la suya.
print()
print("=== 8. interfaz vieja guardada en el lugar: el cliente NO se apaga ===")


def corre_interfaz_guardada():
    guion = 'dofile("%s/mockclient.lua")\n' % HERE
    guion += '''
-- basura guardada en el lugar (lo que Roblox copia a la pantalla al arrancar),
-- y con el nombre ya renombrado por Roblox en otra copia
local pg0 = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local a = Instance.new("ScreenGui") ; a.Name = "SpiceEmpireUI"  ; a.Parent = pg0
local b = Instance.new("ScreenGui") ; b.Name = "SpiceEmpireUI2" ; b.Parent = pg0
print("__ANTES__ " .. #pg0:GetChildren())
'''
    guion += "local __cli = function()\n" + CLIENTE + "\nend\n__cli()\n"
    guion += '''
if task.__sched then task.__sched.advance(2) end
local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local guis, visibles = 0, 0
for _, g in ipairs(pg:GetChildren()) do
  if string.sub(g.Name or "", 1, 11) == "SpiceEmpire" and g.Name ~= "SpiceEmpire_Error"
     and g.Name ~= "SpiceEmpire_Avisito" then
    guis = guis + 1
    for _, c in ipairs(g:GetChildren()) do
      if c.Visible then visibles = visibles + 1 end
    end
  end
end
print("__RESULTADO__ guis=" .. guis .. " visibles=" .. visibles)
'''
    return lua(guion, env=ENTORNO)


sal = corre_interfaz_guardada()
llego = "UI cargada" in sal
m = re.search(r"__RESULTADO__ guis=(\d+) visibles=(\d+)", sal)
if not m:
    print("  FALLA  no pude leer el resultado")
    for linea in sal.strip().splitlines()[-6:]:
        print("         | " + linea[:140])
    fallas += 1
else:
    guis, visibles = int(m.group(1)), int(m.group(2))
    ok = llego and guis == 1 and visibles >= 4
    print("  %s  el cliente llego al final: %s | quedan %d interfaz(es) del juego, %d cuadros visibles"
          % ("OK   " if ok else "FALLA", "si" if llego else "NO", guis, visibles))
    if not ok:
        print("         (esperado: llegar al final, 1 sola interfaz y su contenido visible)")
        fallas += 1

# ------------------------------- 9) TESTIGOS DE RONDA (v38)
# El usuario probaba y no podia saber si el codigo que dibujaba era el nuevo. La
# v38 pone un TESTIGO: una placa que dice la ronda (cliente) y un letrero arriba
# del spawn (servidor). Aqui se prueba que los dos salen con la ronda del codigo.
print()
print("=== 9. testigo de ronda del CLIENTE (la placa en pantalla) ===")


def corre_testigo_cliente():
    guion = 'dofile("%s/mockclient.lua")\n' % HERE
    guion += "local __cli = function()\n" + CLIENTE + "\nend\n__cli()\n"
    guion += '''
local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local sg = pg:FindFirstChild("AvisoRonda")
if not sg then print("__RESULTADO__ no hay placa") return end
local textos = {}
for _, d in ipairs(sg:GetDescendants()) do
  if d.Text and #d.Text > 0 then table.insert(textos, d.Text) end
end
local placa = sg:FindFirstChild("Placa")
local vis = placa ~= nil
for _, d in ipairs(sg:GetDescendants()) do
  if d.Visible then vis = true end
end
print("__RESULTADO__ " .. tostring(vis) .. "||" .. table.concat(textos, " | "))
'''
    return lua(guion, env=ENTORNO)


sal = corre_testigo_cliente()
m = re.search(r"__RESULTADO__ (.*)", sal)
if not m:
    print("  FALLA  no pude leer el resultado")
    for linea in sal.strip().splitlines()[-6:]:
        print("         | " + linea[:140])
    fallas += 1
else:
    cuerpo = m.group(1)
    partes = cuerpo.split("||")
    visible = partes[0] == "true"
    textos = partes[1] if len(partes) > 1 else ""
    ronda = re.search(r"v\d+", textos)
    dicho = "RONDA " in textos or "ronda" in textos
    ok = visible and dicho and ronda is not None
    print("  %s  placa visible: %s | dice: %s"
          % ("OK   " if ok else "FALLA", "si" if visible else "NO", textos[:90]))
    if not ok:
        print("         (la placa tiene que estar visible y decir la ronda)")
        fallas += 1

print()
print("=== 10. testigo de ronda del SERVIDOR (letrero arriba del spawn) ===")


def corre_testigo_servidor():
    guion = 'dofile("%s/mock.lua")\n' % HERE
    guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    guion += '''
local rs = game:GetService("ReplicatedStorage")
rs.WaitForChild = function(s, n) if n == "GameConfig" then return "__CFG__" end end
require = function(x) return _cfg end
local City = (function()
'''
    guion += L("ServerScriptService/CityGenerator.luau")
    guion += '''
end)()
local ok, city = pcall(City.Build)
if not ok then print("__RESULTADO__ ciudad fallo: " .. tostring(city)) return end
local sp = city:FindFirstChild("CitySpawn")
local bb = sp and sp:FindFirstChild("TestigoRonda")
if not bb then print("__RESULTADO__ no hay letrero") return end
local textos = {}
for _, d in ipairs(bb:GetDescendants()) do
  if d.Text and #d.Text > 0 then table.insert(textos, d.Text) end
end
print("__RESULTADO__ " .. table.concat(textos, " | "))
'''
    return lua(guion, env=dict(ENTORNO, MOCK_CITY="1"))


sal = corre_testigo_servidor()
m = re.search(r"__RESULTADO__ (.*)", sal)
if not m:
    print("  FALLA  no pude leer el resultado")
    for linea in sal.strip().splitlines()[-6:]:
        print("         | " + linea[:140])
    fallas += 1
else:
    textos = m.group(1)
    tiene = "SERVIDOR" in textos and re.search(r"v\d+|sin numero", textos) is not None
    print("  %s  letrero: %s" % ("OK   " if tiene else "FALLA", textos[:90]))
    if not tiene:
        print("         (el letrero tiene que decir SERVIDOR + la ronda)")
        fallas += 1

# ------------------- 11) EL TABLERO VIEJO CON OTRO NOMBRE (v39)
# Reporte del usuario CON la placa nueva en pantalla: "sigue viendose el viejo".
# El barrido anterior solo reconocia nombres que empiezan con "SpiceEmpire"; si la
# copia vieja se llama distinto (o esta dentro de una carpeta), no la tocaba. La
# v39 reconoce el tablero por su CONTENIDO ("Hojas", "HEAT", "Espacio").
print()
print("=== 11. el tablero viejo con OTRO nombre (y en una carpeta): se borra ===")


def corre_tablero_raro():
    guion = 'dofile("%s/mockclient.lua")\n' % HERE
    guion += '''
local pg0 = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local raro = Instance.new("ScreenGui") ; raro.Name = "MiUI_vieja" ; raro.Parent = pg0
local fr = Instance.new("Frame") ; fr.Parent = raro
local l1 = Instance.new("TextLabel") ; l1.Text = "Hojas 0  |  Bloques 0  |  Espacio 0/200" ; l1.Parent = fr
local l2 = Instance.new("TextLabel") ; l2.Text = "HEAT 0%" ; l2.Parent = fr
local carpeta = Instance.new("Folder") ; carpeta.Name = "Cosas" ; carpeta.Parent = pg0
local hondo = Instance.new("ScreenGui") ; hondo.Name = "Pantalla" ; hondo.Parent = carpeta
local l3 = Instance.new("TextLabel") ; l3.Text = "Hojas 5  |  Espacio 2/200" ; l3.Parent = hondo
'''
    guion += "local __cli = function()\n" + CLIENTE + "\nend\n__cli()\n"
    guion += '''
if task.__sched then task.__sched.advance(2) end
local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local quedan = 0
for _, g in ipairs(pg:GetDescendants()) do
  if g.ClassName == "ScreenGui" and (g.Name == "MiUI_vieja" or g.Name == "Pantalla") then quedan = quedan + 1 end
end
local aviso = pg:FindFirstChild("AvisoRonda")
local placa = aviso and aviso:FindFirstChild("Placa")
local pie = placa and placa:FindFirstChild("Pie")
print("__RESULTADO__ viejos=" .. quedan .. "||" .. tostring(pie and pie.Text))
'''
    return lua(guion, env=ENTORNO)


sal = corre_tablero_raro()
m = re.search(r"__RESULTADO__ viejos=(\d+)\|\|(.*)", sal)
if not m:
    print("  FALLA  no pude leer el resultado")
    for linea in sal.strip().splitlines()[-6:]:
        print("         | " + linea[:140])
    fallas += 1
else:
    quedan, texto = int(m.group(1)), m.group(2)
    ok = quedan == 0 and "borre" in texto
    print("  %s  quedan tableros viejos: %d | la placa dice: %s"
          % ("OK   " if ok else "FALLA", quedan, texto[:80]))
    if not ok:
        print("         (los dos (incluso el de la carpeta) deben borrarse, y la placa decirlo)")
        fallas += 1

print()
print("=== 12. el SERVIDOR borra la interfaz vieja escondida y lista lo que dibuja ===")


def corre_barrido_servidor():
    guion = 'dofile("%s/mock.lua")\n' % HERE
    guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    guion += '''
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
  return {} end
-- el tablero viejo ESCONDIDO en una carpeta de StarterGui, con otro nombre
local sg = game:GetService("StarterGui")
local carpeta = Instance.new("Folder") ; carpeta.Name = "Guardado" ; carpeta.Parent = sg
local tab = Instance.new("ScreenGui") ; tab.Name = "MiTablero" ; tab.Parent = carpeta
local f = Instance.new("Frame") ; f.Parent = tab
local l = Instance.new("TextLabel") ; l.Text = "Hojas 0 | Bloques 0 | Espacio 0/200" ; l.Parent = f
-- una copia vieja de interfaz escondida en StarterCharacterScripts
local sps = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local scs = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
local bueno = Instance.new("LocalScript") ; bueno.Name = "ClientUI" ; bueno.Parent = sps
local viejo = Instance.new("LocalScript") ; viejo.Name = "OldHud" ; viejo.Parent = scs
_city=(function()
'''
    guion += L("ServerScriptService/CityGenerator.luau")
    guion += '''
end)()
_data=(function()
'''
    guion += L("ServerScriptService/DataService.luau")
    guion += '''
end)()
local ok, err = pcall(function()
'''
    guion += L("ServerScriptService/Main.luau")
    guion += '''
end)
if task.__sched then task.__sched.advance(20) end
print("__RESULTADO__ quedan=" .. #carpeta:GetChildren() .. "||" .. tostring(ok))
'''
    return lua(guion)


sal = corre_barrido_servidor()
m = re.search(r"__RESULTADO__ quedan=(\d+)\|\|(.*)", sal)
if not m:
    print("  FALLA  no pude leer el resultado")
    for linea in sal.strip().splitlines()[-8:]:
        print("         | " + linea[:140])
    fallas += 1
else:
    quedan, ok = int(m.group(1)), m.group(2) == "true"
    reporto_basura = "BASURA" in sal
    reporto_dibuja = "DIBUJA" in sal and "OldHud" in sal
    no_marco_buena = "ClientUI (LocalScript)" not in sal.replace("DIBUJA", "DIBUJA ") or sal.count("DIBUJA") == 1
    todo = quedan == 0 and ok and reporto_basura and reporto_dibuja and no_marco_buena
    print("  %s  la carpeta quedo vacia: %s | reporto la BASURA: %s | reporto al OldHud: %s | no marco la ClientUI buena: %s"
          % ("OK   " if todo else "FALLA", "si" if quedan == 0 else "NO",
             "si" if reporto_basura else "NO", "si" if reporto_dibuja else "NO",
             "si" if no_marco_buena else "NO"))
    if not todo:
        fallas += 1

# ---------- 13) EL VIGILANTE DEL SERVIDOR (v40)
# CASO REAL: quedo un 'Main' viejo de mas corriendo y ese crea SU carpeta Remotes
# (sin sello, con 9 remotes) a media partida. Antes solo se revisaba 3 veces (0, 5 y
# 15 s) y la carpeta sobrevivia: el cliente la veia y salia el aviso de "carpetas de
# mas" aunque el juego funcionara. Ahora se borra AL INSTANTE.
print()
print("=== 13. aparece una carpeta Remotes a media partida: se borra al instante ===")


def corre_vigilante():
    guion = 'dofile("%s/mock.lua")\n' % HERE
    guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    guion += '''
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
  return {} end
_city=(function()
'''
    guion += L("ServerScriptService/CityGenerator.luau")
    guion += '''
end)()
_data=(function()
'''
    guion += L("ServerScriptService/DataService.luau")
    guion += '''
end)()
local ok, err = pcall(function()
'''
    guion += L("ServerScriptService/Main.luau")
    guion += '''
end)
task.__sched.advance(6)
-- a media partida, el "Main viejo" crea SU carpeta con 9 remotes
local vieja = Instance.new("Folder") ; vieja.Name = "Remotes" ; vieja.Parent = rs
for i=1,9 do local e = Instance.new("RemoteEvent") ; e.Name = "Viejo"..i ; e.Parent = vieja end
task.__sched.advance(task.__sched.vtime + 3)
local cuantas, viva = 0, false
for _, c in ipairs(rs:GetChildren()) do
  if string.sub(c.Name,1,7) == "Remotes" then cuantas = cuantas + 1 end
  if c == vieja then viva = true end
end
print("__RESULTADO__ " .. cuantas .. "||" .. tostring(viva) .. "||" .. tostring(ok))
'''
    return lua(guion)


sal = corre_vigilante()
m = re.search(r"__RESULTADO__ (\d+)\|\|(.*?)\|\|(.*)", sal)
if not m:
    print("  FALLA  no pude leer el resultado")
    for linea in sal.strip().splitlines()[-8:]:
        print("         | " + linea[:140])
    fallas += 1
else:
    cuantas, viva, ok = int(m.group(1)), m.group(2) == "true", m.group(3) == "true"
    aviso = "OTRA COPIA DEL JUEGO ESTA CORRIENDO" in sal
    todo = cuantas == 1 and not viva and ok and aviso
    print("  %s  quedan %d carpeta(s) Remotes | la vieja sigue viva: %s | aviso del Main viejo: %s"
          % ("OK   " if todo else "FALLA", cuantas, "si" if viva else "NO",
             "si" if aviso else "NO"))
    if not todo:
        fallas += 1

# ---------- 14) EL AVISO DEL CLIENTE SE QUITA SOLO (v40)
# El usuario veia el aviso de "carpetas Remotes de mas" y parecia que seguia roto
# aunque el servidor ya hubiera limpiado. Ahora, si el problema desaparece, el aviso
# se quita solo: no se queda pegado en la pantalla.
print()
print("=== 14. el aviso de carpetas de mas se quita solo cuando ya hay 1 ===")


def corre_aviso():
    guion = 'dofile("%s/mockclient.lua")\n' % HERE
    guion += '''
-- mockclient ya crea la carpeta BUENA (con sello). Se agrega SOLO la vieja.
local rs = game:GetService("ReplicatedStorage")
local vieja = Instance.new("Folder") ; vieja.Name = "Remotes" ; vieja.Parent = rs
for i=1,9 do local e = Instance.new("RemoteEvent") ; e.Name = "Viejo"..i ; e.Parent = vieja end
'''
    guion += "local __cli = function()\n" + CLIENTE + "\nend\n__cli()\n"
    guion += '''
local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
task.__sched.advance(5)
local a = pg:FindFirstChild("SpiceEmpire_Avisito")
local texto = ""
if a then
  for _, d in ipairs(a:GetDescendants()) do
    if d.Text and #d.Text > 30 then texto = d.Text break end
  end
end
-- el vigilante del servidor borra la vieja y el aviso debe irse solo
vieja:Destroy()
task.__sched.advance(task.__sched.vtime + 6)
print("__RESULTADO__ " .. tostring(a ~= nil) .. "||" .. tostring(pg:FindFirstChild("SpiceEmpire_Avisito") ~= nil) ..
  "||" .. texto:sub(1, 60))
'''
    return lua(guion, env=ENTORNO)


sal = corre_aviso()
m = re.search(r"__RESULTADO__ (.*?)\|\|(.*?)\|\|(.*)", sal)
if not m:
    print("  FALLA  no pude leer el resultado")
    for linea in sal.strip().splitlines()[-8:]:
        print("         | " + linea[:140])
    fallas += 1
else:
    salio, sigue, texto = m.group(1) == "true", m.group(2) == "true", m.group(3)
    ok = salio and not sigue and "puedes jugar normal" in texto.lower()
    print("  %s  el aviso salio: %s | sigue pegado al final: %s | dice: %s"
          % ("OK   " if ok else "FALLA", "si" if salio else "NO",
             "si" if sigue else "NO", texto[:60]))
    if not ok:
        print("         (debe salir, decir que puedes jugar normal, y quitarse solo)")
        fallas += 1

# ---------- 15) CLASES INVENTADAS (v41) ----------
# EL BUG QUE ROMPIO LA INTERFAZ VARIAS RONDAS: el cliente hacia
# Instance.new("AutomaticSize") y AutomaticSize NO es una clase de Roblox (es una
# PROPIEDAD). En Studio truena ahi mismo: la barra ancha ya estaba dibujada y el
# script moria antes de esconderla (el jugador veia el tablero viejo para siempre).
# El simulador aceptaba cualquier nombre inventado, asi que no lo cazo.
# Aqui se prueba que el detector SI cace una clase inventada (y que el mock truene).
print()
print("=== 15. clases inventadas: Instance.new(\"X\") con X que no existe ===")


def corre_detector_clases():
    # 1) el detector de python (tools/clases.py) tiene que cazar una clase inventada
    falso = os.path.join(ROOT, "ServerScriptService", "_PruebaClaseInventada.luau")
    with open(falso, "w", encoding="utf-8") as f:
        f.write('local o = Instance.new("AutomaticSize")\n')
    try:
        r = subprocess.run([sys.executable, os.path.join(HERE, "clases.py"), falso],
                           capture_output=True, text=True, timeout=60)
        caza = r.returncode != 0 and "AutomaticSize" in (r.stdout + r.stderr)
    finally:
        os.unlink(falso)
    # 2) el simulador tambien tiene que tronar (igual que Studio)
    guion = 'dofile("%s/mock.lua")\n' % HERE
    guion += 'local ok, err = pcall(function() return Instance.new("AutomaticSize") end)\n'
    guion += 'print("__RESULTADO__ " .. tostring(not ok))\n'
    sal = lua(guion)
    m = re.search(r"__RESULTADO__ (true|false)", sal)
    trono = bool(m) and m.group(1) == "true"
    # y una clase de verdad NO debe tronar
    guion2 = 'dofile("%s/mock.lua")\n' % HERE
    guion2 += 'local ok = pcall(function() return Instance.new("TextLabel") end)\n'
    guion2 += 'print("__RESULTADO__ " .. tostring(ok))\n'
    sal2 = lua(guion2)
    m2 = re.search(r"__RESULTADO__ (true|false)", sal2)
    buena_ok = bool(m2) and m2.group(1) == "true"
    return caza, trono, buena_ok


caza, trono, buena_ok = corre_detector_clases()
ok = caza and trono and buena_ok
print("  %s  tools/clases.py la caza: %s | el simulador truena: %s | una clase de verdad"
      " pasa: %s" % ("OK   " if ok else "FALLA", "si" if caza else "NO",
                     "si" if trono else "NO", "si" if buena_ok else "NO"))
if not ok:
    print("         (AutomaticSize no es clase: tiene que tronar en el chequeo y en el mock)")
    fallas += 1

# ---------- 16) LA BICI: los rines siguen a la bici (v42) ----------
# El usuario: "cuando la muevo literalmente los rines se quedan ahi". El bucle de
# movimiento solo movia la llanta y el aro: la MAZA y los RAYOS se quedaban
# clavados donde nacio la bici (y la rueda parecia un plato vacio).
#
# Esta prueba revisa el codigo del bucle: la rueda tiene CUATRO piezas (llanta,
# aro, maza y rayos) y las cuatro tienen que moverse con la bici. Es la forma
# honesta de probarlo: el servidor simulado no tiene jugadores, asi que no se
# puede arrancar la bici de verdad (el mock no tiene Humanoid ni personaje).
print()
print("=== 16. la bici: el bucle mueve las 4 piezas de la rueda ===")

MAIN_SRC = open(os.path.join(ROOT, "ServerScriptService/Main.luau"), encoding="utf-8").read()


def bloque_bici(src):
    # desde el comentario "6) las ruedas" hasta el final del bucle for
    i = src.find("-- 6) las ruedas ademas giran")
    if i < 0:
        return ""
    j = src.find("end)", i)
    return src[i:j if j > i else i + 2000]


bloque = bloque_bici(MAIN_SRC)
falta = []
for pieza, aguja in [("llanta", ".wheel.CFrame"), ("aro", ".rim.CFrame"),
                     ("maza", ".hub.CFrame"), ("rayos", "sp.CFrame")]:
    if aguja not in bloque:
        falta.append(pieza)
# y que la bici tenga controles (si no, en celular no sale el volante)
if "seat.Torque = 20" not in MAIN_SRC:
    falta.append("controles (Torque)")
# y que en celular no salga el letrero de E (se sube acercandose)
if "AutoSubir" not in MAIN_SRC:
    falta.append("auto-subir en celular")

if not bloque:
    print("  FALLA  no encontre el bloque que mueve las ruedas (¿se reescribio?)")
    fallas += 1
elif falta:
    print("  FALLA  falta mover: %s" % ", ".join(falta))
    print("         (si la maza o los rayos no se mueven, los rines se quedan atras)")
    fallas += 1
else:
    print("  OK     se mueven la llanta, el aro, la maza y los rayos; la bici tiene controles")
    print("         y en celular se sube al acercarse (sin letrero de E)")

# ---------- 20) EL LIMITE DE CAJONES Y "MI AUTO AQUI" (v42) ----------
# Los dos pedidos de esta ronda, probados con un JUGADOR DE VERDAD dentro del
# servidor simulado (antes era imposible: Players:GetPlayers() devolvia {} y
# PlayerAdded nunca se disparaba, asi que ninguna accion del servidor se probo).
#   1. Con la bodega en nivel 1 solo puedes comprar UN auto; el segundo se
#      rechaza con el aviso de que mejores la bodega. Al subir a nivel 2, ya
#      puedes comprar el segundo.
#   2. "Mi auto aqui" (el boton del celular) saca tu auto y lo deja JUSTO a un
#      lado tuyo (10 studs); si lo vuelves a pedir, te lo trae (no te hace otro).
print()
print("=== 20. un auto por nivel de bodega + el auto viene a donde estas ===")


def corre_acciones():
    guion = 'dofile("%s/mock.lua")\n' % HERE
    guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    guion += '''
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
  return {} end
_city=(function()
'''
    guion += L("ServerScriptService/CityGenerator.luau")
    guion += '''
end)()
_data=(function()
'''
    guion += L("ServerScriptService/DataService.luau")
    guion += '''
end)()
local ok, err = pcall(function()
'''
    guion += L("ServerScriptService/Main.luau")
    guion += '''
end)
if not ok then print("__ACC__ el Main trono: " .. tostring(err)) return end
local rem = rs:FindFirstChild("Remotes")
local accion
for _, c in ipairs(rem and rem:GetChildren() or {}) do
  if c.Name == "Action" then accion = c end
end
if not accion or not accion.OnServerInvoke then
  print("__ACC__ el servidor no expuso la accion")
  return
end
-- jugador simulado
local Players = game:GetService("Players")
local pl = Instance.new("Player") ; pl.Name = "Tester" ; pl.UserId = 777 ; pl.Parent = Players
task.__sched.advance(8)
local prof = _data.Get(pl)
if not prof then print("__ACC__ el jugador no tuvo perfil") return end
prof.Cash = 900000
-- personaje (sin esto no se puede probar traer el auto al lado tuyo)
local char = Instance.new("Model") ; char.Name = "Tester"
local hum = Instance.new("Humanoid") ; hum.Parent = char
local hrp = Instance.new("Part") ; hrp.Name = "HumanoidRootPart"
hrp.CFrame = CFrame.new(Vector3.new(20, 3, -40))
hrp.Parent = char ; char.PrimaryPart = hrp ; char.Parent = workspace
pl.Character = char
task.__sched.advance(1)

-- el anti-spam usa os.clock() (reloj real): hay que dejar pasar el tiempo
local esperar = function()
  local t0 = os.clock()
  while os.clock() - t0 < 0.12 do end
end
local llamar = function(...)
  esperar()
  local r = accion.OnServerInvoke(...)
  if type(r) == "table" then return tostring(r.ok), tostring(r.msg) end
  return tostring(r), ""
end

local v1, v2 = _cfg.Vehicles[1], _cfg.Vehicles[2]
local r1 = { llamar(pl, "buyVehicle", v1.Id) }
local r2 = { llamar(pl, "buyVehicle", v2.Id) }
local r3 = { llamar(pl, "carAqui") }
local r4 = { llamar(pl, "carAqui") }
-- ¿donde quedo el auto?
local car = workspace:FindFirstChild("Car_" .. pl.UserId)
local cerca = -1
if car then
  local yo = hrp.CFrame.Position
  local mejor = 1e9
  for _, d in ipairs(car:GetDescendants()) do
    local cf = d.CFrame
    if cf and cf.Position then
      local dist = (cf.Position - yo).Magnitude
      if dist < mejor then mejor = dist end
    end
  end
  if mejor < 1e8 then cerca = mejor end
end
-- ahora sube la bodega a nivel 2: ya debe dejar comprar el segundo
prof.WarehouseTier = 2
local r5 = { llamar(pl, "buyVehicle", v2.Id) }
local cuantos = 0
for _ in pairs(prof.Vehicles) do cuantos = cuantos + 1 end
print("__ACC__ 1=" .. r1[1] .. "|1m=" .. r1[2] ..
  "||2=" .. r2[1] .. "|2m=" .. r2[2] ..
  "||3=" .. r3[1] .. "|3m=" .. r3[2] ..
  "||4=" .. r4[1] .. "|4m=" .. r4[2] ..
  "||car=" .. tostring(car ~= nil) .. "|cerca=" .. string.format("%.1f", cerca) ..
  "||5=" .. r5[1] .. "|5m=" .. r5[2] ..
  "||autos=" .. cuantos)
'''
    return lua(guion)


sal = corre_acciones()
m = re.search(r"__ACC__ (.*)", sal)
if not m:
    print("  FALLA  el servidor simulado no termino la prueba")
    for linea in sal.strip().splitlines()[-6:]:
        print("         | " + linea[:150])
    fallas += 1
elif m.group(1).startswith("el Main trono") or m.group(1).startswith("el servidor") or \
        m.group(1).startswith("el jugador"):
    print("  FALLA  " + m.group(1)[:160])
    fallas += 1
else:
    d = {}
    for trozo in m.group(1).split("||"):
        for kv in trozo.split("|"):
            if "=" in kv:
                k, v = kv.split("=", 1)
                d[k] = v
    problemas = []
    if d.get("1") != "true":
        problemas.append("no lo dejo comprar el PRIMER auto")
    if d.get("2") != "false":
        problemas.append("lo dejo comprar 2 autos con la bodega en nivel 1")
    if "lleno" not in d.get("2m", ""):
        problemas.append("el aviso del segundo auto no explica que el garaje esta lleno")
    if d.get("3") != "true" or "Sacaste" not in d.get("3m", ""):
        problemas.append("no saco el auto del garaje (%s)" % d.get("3m"))
    if d.get("car") != "true":
        problemas.append("el vehiculo no aparecio en el mapa")
    try:
        cerca = float(d.get("cerca", "-1"))
    except ValueError:
        cerca = -1.0
    if not (4.0 <= cerca <= 22.0):
        problemas.append("el auto quedo a %s studs de ti (debe caer a un lado tuyo)" % d.get("cerca"))
    if d.get("4") != "true" or "Traje" not in d.get("4m", ""):
        problemas.append("al pedirlo otra vez no te lo trajo (%s)" % d.get("4m"))
    if d.get("5") != "true":
        problemas.append("con la bodega en nivel 2 sigue sin dejar comprar el segundo")
    if d.get("autos") != "2":
        problemas.append("quedaron %s autos en la cuenta (deben ser 2)" % d.get("autos"))
    if problemas:
        print("  FALLA  " + " | ".join(problemas))
        fallas += 1
    else:
        print("  OK     nivel 1: 1 auto (el 2do se rechaza: \"%s\")" % d.get("2m"))
        print("         \"mi auto aqui\" lo dejo a %s studs y a la segunda te lo trae" % d.get("cerca"))
        print("         nivel 2: ya deja el segundo auto (quedan %s en la cuenta)" % d.get("autos"))

# ---------- 19) EL LOTE VACIO: NAVE CLAUSURADA + OFICIAL (v42) ----------
# Lo que pidio el usuario: "donde no hay bodega, que se vea una bodega clausurada
# con estilo distinto y oficiales con los que puedas hablar al acercarte". El
# error que se corrige: un lote sin dueno era un cuadro vacio y parecia un mapa
# a medio hacer.
print()
print("=== 19. el lote vacio se ve clausurado y trae oficial ===")


def corre_clausurada():
    guion = 'dofile("%s/mock.lua")\n' % HERE
    guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    guion += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function()
'''
    guion += L("ServerScriptService/CityGenerator.luau")
    guion += '''
end)()
local ok, nave = pcall(function() return City.BuildClosedWarehouse() end)
if not ok or not nave then
  print("__RESULTADO__ trono: " .. tostring(nave))
  return
end
local function hay(nombre, clase)
  for _, d in ipairs(nave:GetDescendants()) do
    if d.Name == nombre and (not clase or d.ClassName == clase) then return d end
  end
end
local partes, luces = 0, 0
for _, d in ipairs(nave:GetDescendants()) do
  if d:IsA("BasePart") then partes = partes + 1 end
  if d.ClassName == "PointLight" then luces = luces + 1 end
end
local ofi  = hay("OficialMunicipal")
local burb = hay("Dialogo", "BillboardGui")
local promo = hay("PromptOficial", "ProximityPrompt")
local function si(x) if x then return "si" else return "no" end end
-- ¿el globo nace apagado? (si nace prendido, se ve un cuadro de texto flotando
-- en cada lote vacio de la ciudad)
local apagado = burb and burb.Enabled == false
print("__RESULTADO__ partes=" .. partes .. " luces=" .. luces ..
  " oficial=" .. si(ofi) .. " burbuja=" .. si(burb) .. " apagada=" .. si(apagado) ..
  " prompt=" .. si(promo) ..
  " alcance=" .. tostring(promo and promo.MaxActivationDistance) ..
  " tablas=" .. si(hay("Tabla1") and hay("Tabla3")) ..
  " cadena=" .. si(hay("Cadena")) .. " candado=" .. si(hay("Candado")) ..
  " letrero=" .. si(hay("LetreroBase")) ..
  " principal=" .. si(nave.PrimaryPart ~= nil))
'''
    return lua(guion)


sal = corre_clausurada()
m = re.search(r"__RESULTADO__ (.*)", sal)
if not m or m.group(1).startswith("trono"):
    print("  FALLA  la nave clausurada no se pudo construir")
    for linea in sal.strip().splitlines()[-6:]:
        print("         | " + linea[:150])
    fallas += 1
else:
    campos = dict(kv.split("=") for kv in m.group(1).split())
    problemas = []
    if int(campos.get("partes", "0")) < 25:
        problemas.append("muy pocas piezas (%s): se veria vacia" % campos.get("partes"))
    if campos.get("luces") != "1":
        problemas.append("luces=%s (va UNA, la del foco que parpadea)" % campos.get("luces"))
    for k, que in [("oficial", "el oficial"), ("burbuja", "el globo de dialogo"),
                   ("prompt", "el prompt de Hablar"), ("tablas", "las tablas del porton"),
                   ("cadena", "la cadena"), ("candado", "el candado"),
                   ("letrero", "el letrero de CLAUSURADA"), ("principal", "la parte principal")]:
        if campos.get(k) != "si":
            problemas.append("falta " + que)
    if campos.get("apagada") != "si":
        problemas.append("el globo nace PRENDIDO (se veria texto flotando en todo lote vacio)")
    if campos.get("alcance") != "12":
        problemas.append("el oficial se puede hablar de lejos (%s studs)" % campos.get("alcance"))
    if problemas:
        print("  FALLA  " + " | ".join(problemas))
        fallas += 1
    else:
        print("  OK     nave gris con %s piezas, porton con tablas+cadena+candado, letrero"
              % campos["partes"])
        print("         oficial con globo apagado y prompt de Hablar a %s studs; 1 foco"
              % campos["alcance"])

# ...y que el SERVIDOR ponga y quite la clausurada en el lote que toca
main_src = open(os.path.join(ROOT, "ServerScriptService/Main.luau"), encoding="utf-8").read()
fallas_lote = []
if "BuildClosedWarehouse()" not in main_src:
    fallas_lote.append("el servidor nunca construye la nave clausurada")
if "quitarClausurada(slot)" not in main_src:
    fallas_lote.append("al ocupar un lote no se quita la clausurada (se verian las dos)")
if "ponerClausurada(i)" not in main_src:
    fallas_lote.append("al soltar un lote no vuelve la clausurada")
if ".Magnitude <= 420" not in main_src or "ponerClausurada(slot)\n\t\t\t\t\t\t\t\t\tlevante" not in main_src.replace("\t", "\t"):
    # la nave se levanta al acercarse (no las 20 de golpe: serian 1200 piezas)
    if "ponerClausurada(slot)" not in main_src:
        fallas_lote.append("los lotes vacios no se clausuran cuando el jugador anda cerca")
print("  %s  el servidor: %s" % ("OK   " if not fallas_lote else "FALLA",
      "pone y quita la clausurada en el lote correcto" if not fallas_lote
      else "; ".join(fallas_lote)))
if fallas_lote:
    fallas += 1

# ---------- 18) LOS BOTONES DEL DOCK DE VERDAD (v42) ----------
# El usuario: "el dashboard de abajo no funciona en celular". Antes esta prueba
# no se podia escribir: el mock no tenia InvokeServer, asi que act() moria dentro
# de su pcall y NADIE veia que boton mandaba que accion. Ahora los remotes
# existen y las llamadas se registran, asi que aqui se TOCAN los botones (como un
# dedo en la pantalla) y se revisa que accion le llego al servidor.
print()
print("=== 18. el dock: cada boton manda la accion que debe ===")


def corre_dock():
    guion = 'dofile("%s/mockclient.lua")\n' % HERE
    guion += "local __cli = function()\n" + CLIENTE + "\nend\n__cli()\n"
    guion += '''
if task.__sched then task.__sched.advance(2) end
local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local sg = pg and pg:FindFirstChild("SpiceEmpireUI")
local function buscaBoton(txt)
  if not sg then return nil end
  for _, d in ipairs(sg:GetDescendants()) do
    if d.ClassName == "TextButton" and string.find(d.Text or "", txt, 1, true) then
      return d
    end
  end
end
local nombres = {"Telefono", "Bodega", "Auto", "Tienda", "Mejoras"}
local faltan, tocados = {}, {}
for _, n in ipairs(nombres) do
  local b = buscaBoton(n)
  if not b then
    table.insert(faltan, n)
  else
    b.MouseButton1Click:Fire()
    table.insert(tocados, n)
  end
end
if task.__sched then task.__sched.advance(3) end
local accs = {}
for _, l in ipairs(LLAMADAS or {}) do
  local a = l.args and l.args[1]
  if type(a) == "string" then table.insert(accs, a) end
end
table.sort(accs)
-- ¿la pantalla del telefono se abrio de verdad? (se busca por su titulo)
local telefonoAbierto = false
for _, d in ipairs(sg and sg:GetDescendants() or {}) do
  if d.ClassName == "TextLabel" and d.Text == "MENSAJES" and d.Visible then
    local pap = d.Parent
    if pap and pap.Visible then telefonoAbierto = true end
  end
end
local gui = tostring(sg ~= nil)
print("__DOCK__ faltan=" .. table.concat(faltan, ",") ..
  "|botones=" .. tostring(#nombres) ..
  "|acciones=" .. table.concat(accs, ",") ..
  "|telefono=" .. tostring(telefonoAbierto) ..
  "|pantalla=" .. gui)
'''
    return lua(guion, env=ENTORNO)


sal = corre_dock()
m = re.search(r"__DOCK__ faltan=(\S*)\|botones=(\d+)\|acciones=(\S*)\|telefono=(\w+)\|pantalla=(\w+)", sal)
if not m:
    print("  FALLA  el cliente no llego al final")
    for linea in sal.strip().splitlines()[-8:]:
        print("         | " + linea[:150])
    fallas += 1
else:
    faltan, _nb, acciones, telefono, pantalla = m.groups()
    faltan = [x for x in faltan.split(",") if x]
    tiene = set(x for x in acciones.split(",") if x)
    # lo que TIENE que pasar: existen los botones, la bodega teletransporta,
    # el auto llama a carAqui (lo nuevo de la v42) y el telefono ABRE su pantalla.
    esperadas = {"teleportHome", "carAqui"}
    problemas = []
    if pantalla != "true":
        problemas.append("la interfaz ni se dibujo")
    if faltan:
        problemas.append("faltan botones: " + ", ".join(faltan))
    if not esperadas.issubset(tiene):
        problemas.append("no mandaron: " + ", ".join(sorted(esperadas - tiene)))
    if telefono != "true":
        problemas.append("el boton Telefono no abrio su pantalla")
    if problemas:
        print("  FALLA  " + " | ".join(problemas))
        print("         acciones que si llegaron: %s" % (acciones or "(ninguna)"))
        fallas += 1
    else:
        print("  OK     los 5 botones existen y responden al toque")
        print("         acciones al servidor: %s" % acciones)
        print("         el telefono abre su pantalla al tocarlo")

# ---------- 17) LOS CAJONES Y PORTONES DEPENDEN DEL NIVEL (v42) ----------
print()
print("=== 17. el garaje arranca con 1 cajon y crece con la bodega ===")


def corre_cajones():
    guion = 'dofile("%s/mock.lua")\n' % HERE
    guion += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    guion += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function()
'''
    guion += L("ServerScriptService/CityGenerator.luau")
    guion += '''
end)()
local lineas = {}
for tier = 1, 4 do
  local ok, wh = pcall(function() return City.BuildWarehouse(tier) end)
  if not ok then print("__RESULTADO__ tier " .. tier .. " trono"); return end
  local cajones, portones = 0, 0
  for _, d in ipairs(wh:GetDescendants()) do
    if string.match(d.Name, "^Bay%d+$") then cajones = cajones + 1 end
    if d:IsA("Model") and d.Name == "GarageDoor" then portones = portones + 1 end
  end
  table.insert(lineas, tier .. ":" .. cajones .. "/" .. portones)
end
print("__RESULTADO__ " .. table.concat(lineas, " "))
'''
    return lua(guion, env=dict(ENTORNO, MOCK_CITY="1"))


sal = corre_cajones()
m = re.search(r"__RESULTADO__ (.*)", sal)
if not m:
    print("  FALLA  no pude leer el resultado")
    for linea in sal.strip().splitlines()[-6:]:
        print("         | " + linea[:140])
    fallas += 1
else:
    datos = m.group(1).split()
    esperado = ["1:1/1", "2:2/2", "3:3/3", "4:4/4"]
    ok = datos == esperado
    print("  %s  cajones/portones por nivel: %s (esperado: %s)"
          % ("OK   " if ok else "FALLA", " ".join(datos), " ".join(esperado)))
    if not ok:
        fallas += 1

print()
if fallas:
    print("FALLA")
    print("  %d escenario(s) del caso 'carpetas Remotes de mas' salieron mal" % fallas)
    sys.exit(1)
print("OK")
