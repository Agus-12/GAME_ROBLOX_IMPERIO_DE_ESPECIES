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
    r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=timeout,
                       env=env)
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

print()
if fallas:
    print("FALLA")
    print("  %d escenario(s) del caso 'carpetas Remotes de mas' salieron mal" % fallas)
    sys.exit(1)
print("OK")
