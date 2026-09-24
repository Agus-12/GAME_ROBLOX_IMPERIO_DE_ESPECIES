#!/usr/bin/env python3
"""v42: prueba de LOS LOTES SIN DUENO.

   El jugador pidio que su parcela no se viera vacia: en las demas parcelas
   tienen que estar las bodegas ya cargadas (cada una de su estilo) y las que
   no tengan dueno, CLAUSURADAS con oficiales afuera que te avisen.

   Que comprueba esta etapa:
     1. Al entrar el jugador, los lotes libres se amueblan (BodegaVecina_N).
     2. Cada bodega vecina esta repintada de otro color (estilo propio).
     3. Cada una trae cinta policial + tablilla CLAUSURADA.
     4. NO se puede tocar nada de adentro (ningun ProximityPrompt activo).
     5. Los oficiales estan plantados afuera, con su globo de dialogo.
     6. Al acercarse el jugador, el oficial dice la linea de "area clausurada"
        y, si reincide, la amenaza de la carcel.
     7. El lote del jugador NO queda clausurado (no tiene cinta encima).
"""
import subprocess, tempfile, sys, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau
LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")


def L(ruta, quitar_goto=True):
    s = strip_luau(open(os.path.join(ROOT, ruta)).read())
    if quitar_goto:
        s = s.replace("goto cont", "_SKIP=true")
    return s


cfg = L("ReplicatedStorage/GameConfig.luau")
city = L("ServerScriptService/CityGenerator.luau")
data = L("ServerScriptService/DataService.luau")
main = L("ServerScriptService/Main.luau")

guion = f'''
dofile("{HERE}/mock.lua")
local rs = game:GetService("ReplicatedStorage")
local sss = game:GetService("ServerScriptService")

-- ===== los archivos del juego dentro del lugar simulado =====
-- Main los busca con WaitForChild: si no estan, se planta (igual que en Studio
-- cuando falta un script). Y require() tiene que devolver EL modulo bueno.
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
  return {{}}
end

_cfg = (function() {cfg} end)()
_city = (function() {city} end)()
_data = (function() {data} end)()

-- ===== jugador de mentira, con personaje, ANTES de correr Main =====
local Players = game:GetService("Players")
local yo = Instance.new("Player")
yo.Name = "Tester"
yo.UserId = 4242
yo.Parent = Players
local chr = Instance.new("Model")
chr.Name = "Tester"
local hum = Instance.new("Humanoid")
hum.Parent = chr
local hrp = Instance.new("Part")
hrp.Name = "HumanoidRootPart"
hrp.Size = Vector3.new(2, 2, 1)
hrp.Position = Vector3.new(0, 3, 0)
hrp.Parent = chr
chr.PrimaryPart = hrp
chr.Parent = workspace
yo.Character = chr
Players.GetPlayers = function() return {{yo}} end

local okMain, errMain = pcall(function() {main} end)
if task.__sched then task.__sched.advance(6) end

print("__MAIN__ " .. tostring(okMain) .. " " .. tostring(errMain))

-- ===== inventario de lotes =====
local vecinas, conCinta, conTablilla, promptsVivos = 0, 0, 0, 0
local estilos = {{}}
for _, m in ipairs(workspace:GetChildren()) do
  local nm = m.Name
  if string.sub(nm, 1, 12) == "BodegaVecina" then
    vecinas = vecinas + 1
    table.insert(estilos, tostring(m:GetAttribute("EstiloVecina")))
    local cinta, tabla = false, false
    for _, d in ipairs(m:GetDescendants()) do
      if d.Name == "CintaPolicial" then cinta = true end
      if d.Name == "TablillaClausurada" then tabla = true end
      if d:IsA("ProximityPrompt") and d.Enabled then promptsVivos = promptsVivos + 1 end
    end
    if cinta then conCinta = conCinta + 1 end
    if tabla then conTablilla = conTablilla + 1 end
  end
end
table.sort(estilos)
print("__VECINAS__ " .. vecinas .. " cinta=" .. conCinta .. " tablilla=" .. conTablilla ..
  " prompts=" .. promptsVivos .. " estilos=" .. table.concat(estilos, ","))

-- ===== oficiales =====
local ofi = workspace:FindFirstChild("Oficiales")
local nOfi, conGlobo = 0, 0
local primero = nil
if ofi then
  for _, n in ipairs(ofi:GetChildren()) do
    nOfi = nOfi + 1
    if not primero then primero = n end
    local head = n:FindFirstChild("Head")
    if head and head:FindFirstChild("GloboOficial") then conGlobo = conGlobo + 1 end
  end
end
print("__OFICIALES__ " .. nOfi .. " globos=" .. conGlobo)

-- ===== el jugador se acerca al primer oficial: debe recibir el aviso =====
-- OJO: el juego te teletransporta a tu bodega al entrar (y alguna tarea tardia
-- puede volver a hacerlo). Por eso la posicion se REAFIRMA en cada tick: si
-- solo se pone una vez y luego corre el reloj virtual, te manda de vuelta.
-- OJO: el reloj virtual de la simulacion es ABSOLUTO (advance(t) = "pon el
-- reloj en t"), no un avance de t segundos. Ir hacia atras no corre nada.
local T = 6
local function avanzar(dt)
  T = T + dt
  if task.__sched then task.__sched.advance(T) end
end
local function estarEn(v, ticks)
  for _ = 1, ticks do
    hrp.Position = v
    avanzar(0.5)
  end
end

local function textoGlobo(npc)
  local head = npc and npc:FindFirstChild("Head")
  local bb = head and head:FindFirstChild("GloboOficial")
  local fondo = bb and bb:FindFirstChild("Fondo")
  local txt = fondo and fondo:FindFirstChild("Texto")
  return tostring(txt and txt.Text or ""), (bb ~= nil and bb.Enabled == true)
end

avanzar(4)   -- deja que se acomode todo

local aviso1, prendido1 = "", false
local cerca = nil
if primero then
  local ohrp = primero:FindFirstChild("HumanoidRootPart")
  if ohrp then
    cerca = ohrp.Position + Vector3.new(0, 0, 4)
    estarEn(cerca, 6)
    aviso1, prendido1 = textoGlobo(primero)
  end
end
print("__AVISO1__ " .. tostring(prendido1) .. " | " .. aviso1)

-- ===== se va y vuelve (reincide): la segunda linea =====
local aviso2, prendido2 = "", false
if primero and cerca then
  estarEn(Vector3.new(0, 3, 0), 40)          -- lejos, y que pase el enfriamiento
  estarEn(cerca, 6)
  aviso2, prendido2 = textoGlobo(primero)
end
print("__AVISO2__ " .. tostring(prendido2) .. " | " .. aviso2)

-- ===== el lote del jugador no quedo clausurado =====
local mio = workspace:FindFirstChild("Warehouse_4242")
local miCinta, miSlot = false, nil
if mio then
  miSlot = mio:GetAttribute("Slot")
  for _, d in ipairs(mio:GetDescendants()) do
    if d.Name == "CintaPolicial" then miCinta = true end
  end
end
print("__MIO__ tiene=" .. tostring(mio ~= nil) .. " cinta=" .. tostring(miCinta) ..
  " slot=" .. tostring(miSlot))
'''


def corre(guion, etiqueta, inyectar=None):
    """Corre el guion. Si 'inyectar' viene, se mete ese texto ANTES de correr
       Main: sirve para envenenar el escenario y comprobar que la prueba si
       truena cuando algo se rompe (fail-hard)."""
    g = guion
    if inyectar:
        g = guion.replace("local okMain, errMain = pcall", inyectar + "\nlocal okMain, errMain = pcall")
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
    t.write(g)
    t.close()
    try:
        r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=300)
    finally:
        os.unlink(t.name)
    return r.stdout


sal = corre(guion, "normal")
if "--verbose" in sys.argv:
    print(sal)

fallas = 0


def lee(tag):
    m = re.search(r"__%s__ (.*)" % tag, sal)
    return m.group(1).strip() if m else None


main_res = lee("MAIN")
print("=== 15. LOTES SIN DUENO: BODEGA CLAUSURADA CON OFICIALES ===")
if main_res is None or not main_res.startswith("true"):
    print("  FALLA  Main no corre: %s" % main_res)
    for linea in sal.strip().splitlines()[-10:]:
        print("         | " + linea[:150])
    fallas += 1

v = lee("VECINAS")
if v is None:
    print("  FALLA  no pude leer las bodegas vecinas")
    fallas += 1
else:
    m = re.match(r"(\d+) cinta=(\d+) tablilla=(\d+) prompts=(\d+) estilos=(\S*)", v)
    if not m:
        print("  FALLA  formato raro: %s" % v)
        fallas += 1
    else:
        nv, nc, nt, np_, estilos = int(m.group(1)), int(m.group(2)), int(m.group(3)), int(m.group(4)), m.group(5)
        # el jugador ocupa el lote 1 => deben amueblarse los lotes 2..VecinasMax
        esperadas = max(0, int(re.search(r"VecinasMax = (\d+)",
                                         open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau")).read()).group(1)) - 1)
        ok = (nv == esperadas and nc == nv and nt == nv and np_ == 0
              and len(set(estilos.split(","))) >= 2)
        print("  %s  %d bodegas vecinas (esperaba %d), %d con cinta, %d con tablilla, "
              "%d botones activos, estilos: %s"
              % ("OK   " if ok else "FALLA", nv, esperadas, nc, nt, np_, estilos))
        if not ok:
            fallas += 1

o = lee("OFICIALES")
if o is None:
    print("  FALLA  no pude leer los oficiales")
    fallas += 1
else:
    n_ofi, globos = (int(x) for x in o.split(" globos="))
    # 2 oficiales por lote clausurado (los lotes 2..5)
    esperados_min = 2
    ok = (n_ofi >= esperados_min and globos == n_ofi)
    print("  %s  %d oficiales afuera, %d con globo de dialogo"
          % ("OK   " if ok else "FALLA", n_ofi, globos))
    if not ok:
        fallas += 1

a1 = lee("AVISO1")
ok1 = bool(a1) and a1.startswith("true") and "clausurada" in a1.lower()
print("  %s  primer aviso al acercarte: %s" % ("OK   " if ok1 else "FALLA", a1))
if not ok1:
    fallas += 1

a2 = lee("AVISO2")
ok2 = bool(a2) and a2.startswith("true") and ("carcel" in a2.lower() or "c\u00e1rcel" in a2.lower()
                                             or "detenido" in a2.lower())
print("  %s  al reincidir: %s" % ("OK   " if ok2 else "FALLA", a2))
if not ok2:
    fallas += 1

mi = lee("MIO")
okm = bool(mi) and "cinta=false" in mi and "tiene=true" in mi
print("  %s  tu lote no queda clausurado: %s" % ("OK   " if okm else "FALLA", mi))
if not okm:
    fallas += 1

# ---------------- FAIL-HARD: con el bug metido, la prueba DEBE tronar -------
print("  -- fail-hard (se mete el bug a proposito) --")
bug = corre(guion, "sin vecinas",
            inyectar="\n-- ENVENENO: se apaga el amueblado de lotes\n"
                     "local _L = _cfg.WarehouseLots ; _L.Enabled = false\n")
if bug.count("__VECINAS__ 0 cinta=0 tablilla=0") == 1 and "clausurada" not in bug.lower():
    print("  OK    con el amueblado apagado, la prueba lo caza (0 vecinas, 0 avisos)")
else:
    print("  FALLA  la prueba no caza el bug: la validacion estaba apagada")
    print("         | " + "\n         | ".join(bug.strip().splitlines()[-6:]))
    fallas += 1

print("FALLO" if fallas else "OK")
sys.exit(1 if fallas else 0)
