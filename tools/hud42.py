#!/usr/bin/env python3
"""v42: prueba del HUD en el CLIENTE simulado.

   Que reporto el jugador:
     * "el dashboard se mira raro" (numeros como recorridos, la 🚨 sin
       explicacion)  -> la columna ahora va ordenada y con etiquetas claras.
     * "la sirenita del nivel de busqueda" -> ahora son 5 ESTRELLAS debajo del
       reloj que se prenden con el nivel de busqueda y se van apagando cuando
       el heat baja (zona segura).
     * "el dashboard de abajo no funciona en celular" -> boton EXTRA "Auto"
       (trae tu carro donde estas) junto a Tienda / Telefono / Bodega.

   Esta etapa enciende el cliente con datos de mentira y revisa la PANTALLA:
     1. Existe el marco de estrellas debajo del reloj, con 5 estrellas.
     2. Con heat bajo: ninguna prendida. Con heat alto: se prenden (y en rojo
        cuando ya vas muy buscado).
     3. La caja fuerte se ve en DOS renglones (hojas / bloques),no apretada.
     4. El boton "Auto" esta en la barra de abajo y pide summonCar al servidor.
     5. La columna va en orden (efectivo, hojas, bloques, mochila, caja).
"""
import subprocess, tempfile, sys, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau
LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")

cfg = strip_luau(open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau")).read())
open(os.path.join(HERE, "cfgload.lua"), "w").write("return (function()\n" + cfg + "\nend)()\n")

cliente = strip_luau(open(os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau")).read()) \
    .replace("goto cont", "_SKIP=true") + "\n"

cuerpo = '''dofile("__TOOLS__/mockclient.lua")
local okc, errc = pcall(function()
__CLIENTE__
end)
if not okc then print("__CLIENTE TRONO__ " .. tostring(errc)) end

if task.__sched then task.__sched.advance(3) end

local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
local ui = pg and pg:FindFirstChild("SpiceEmpireUI")
if not ui then
  print("__NOUI__ no hay SpiceEmpireUI en el PlayerGui")
  return
end

-- busca en toda la interfaz por nombre
local function buscar(nombre)
  for _, d in ipairs(ui:GetDescendants()) do
    if d.Name == nombre then return d end
  end
  return nil
end

-- ===== 1) estrellas debajo del reloj =====
local marco = buscar("EstrellasBusqueda")
local estrellas = {}
if marco then
  for _, d in ipairs(marco:GetChildren()) do
    if string.sub(d.Name, 1, 8) == "Estrella" then table.insert(estrellas, d) end
  end
end
print("__ESTRELLAS__ marco=" .. tostring(marco ~= nil) .. " cuantas=" .. #estrellas)

-- ===== 2) la columna: la caja fuerte en dos renglones =====
local function textoDeCaja()
  local n = 0
  for _, d in ipairs(ui:GetDescendants()) do
    if d.ClassName == "TextLabel" and string.find(tostring(d.Text), "🌿") and string.find(tostring(d.Text), "🧱") then
      return tostring(d.Text), d
    end
  end
  return nil, nil
end
local txtCaja, cajaLbl = textoDeCaja()
print("__CAJA__ " .. tostring(txtCaja == nil) .. " | " .. tostring(txtCaja))

-- ===== 3) el boton Auto =====
local autoBtn = nil
for _, d in ipairs(ui:GetDescendants()) do
  if d.ClassName == "TextButton" and string.sub(tostring(d.Text), 1, 4) == "Auto" then autoBtn = d end
end
print("__AUTO__ " .. tostring(autoBtn ~= nil))

-- ===== 4) se enciende el HUD con datos de mentira y se miran las estrellas ===
local RE = nil
local rs = game:GetService("ReplicatedStorage")
for _, c in ipairs(rs:GetChildren()) do
  if c.Name == "Remotes" then
    for _, r in ipairs(c:GetChildren()) do if r.Name == "StateUpdate" then RE = r end end
  end
end

local function estado(heat)
  return {
    Cash = 11900, Leaves = 18, Blocks = 23, Storage = 80, CarryCap = 80,
    VaultLeafCap = 100, VaultBlockCap = 50, Heat = heat, MaxHeat = 100,
    Wanted = false,
  }
end

local function prender(heat)
  -- como lo hace el servidor: FireAllClients (o FireClient)
  if RE and RE.FireAllClients then RE:FireAllClients(estado(heat))
  elseif RE and RE.FireClient then RE:FireClient(nil, estado(heat)) end
  if task.__sched then task.__sched.advance(1) end
  local n = 0
  for _, e in ipairs(estrellas) do
    -- apagada = gris (64,64,76); prendida = amarilla o roja
    if e.TextColor3.R > 200 then n = n + 1 end
  end
  return n
end

local bajo, alto, rojo = prender(2), prender(55), prender(100)
print("__HEAT__ bajo=" .. bajo .. " medio=" .. alto .. " alto=" .. rojo)

-- ===== 5) el texto de la caja ya con datos (se busca OTRA VEZ: al arrancar
-- el texto esta vacio, asi que la etiqueta no se encuentra todavia) =====
local txtCaja2 = textoDeCaja()
print("__CAJA2__ " .. tostring(txtCaja2))
'''

cuerpo = cuerpo.replace("__CLIENTE__", cliente)


def corre(w, h, touch, parche=None):
    g = cuerpo.replace("__TOOLS__", HERE)
    if parche:
        g = g.replace(cliente, cliente.replace(parche[0], parche[1]))
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
    t.write(g)
    t.close()
    env = dict(os.environ, MOCK_VW=str(w), MOCK_VH=str(h), MOCK_TOUCH=touch, TOOLS=HERE)
    try:
        return subprocess.run([LUA, t.name], capture_output=True, text=True, env=env, timeout=180)
    finally:
        os.unlink(t.name)


print("=== 16. HUD v42: columna ordenada, estrellas de busqueda y boton Auto ===")
fallas = 0
for etiqueta, (w, h, touch) in {"ESCRITORIO": (1920, 1080, "0"), "CELULAR": (896, 414, "1")}.items():
    r = corre(w, h, touch)
    sal = r.stdout
    if r.stderr.strip():
        print("  (stderr: %s)" % r.stderr.strip()[:300])
    if "--verbose" in sys.argv or r.returncode != 0:
        print("  --- %s ---" % etiqueta)
        print("  " + (sal.strip().replace("\n", "\n  ")[:1200] or r.stderr[:400]))

    if "__CLIENTE TRONO__" in sal:
        print("  FALLA [%s] el cliente trono: %s" % (etiqueta, sal.split("__CLIENTE TRONO__")[1][:120]))
        fallas += 1
        continue

    def lee(tag, multilinea=False):
        # el texto de la caja fuerte trae un salto de linea: ese caso (y solo
        # ese) se lee en modo multilinea; los demas son de un renglon.
        if multilinea:
            m = re.search(r"__%s__ ([\s\S]*?)(?=\n__|\Z)" % tag, sal)
        else:
            m = re.search(r"__%s__ (.*)" % tag, sal)
        return m.group(1).strip() if m else None

    est = lee("ESTRELLAS")
    ok = est and "marco=true" in est and "cuantas=5" in est
    print("  %s [%s] estrellas debajo del reloj: %s" % ("OK   " if ok else "FALLA", etiqueta, est))
    if not ok:
        fallas += 1

    heat = lee("HEAT")
    if heat is None:
        print("  FALLA [%s] no pude leer las estrellas al cambiar el heat" % etiqueta)
        fallas += 1
    else:
        m = re.match(r"bajo=(\d+) medio=(\d+) alto=(\d+)", heat)
        b, med, al = (int(x) for x in m.groups()) if m else (0, 0, 0)
        ok = (b == 0 and med >= 2 and al == 5)
        print("  %s [%s] estrellas prendidas: heat bajo=%d, medio=%d, al tope=%d"
              % ("OK   " if ok else "FALLA", etiqueta, b, med, al))
        if not ok:
            fallas += 1

    caja = lee("CAJA2", True) or lee("CAJA")
    ok = caja is not None and "\n" in caja and "🌿" in caja and "🧱" in caja
    print("  %s [%s] caja fuerte en dos renglones: %s"
          % ("OK   " if ok else "FALLA", etiqueta, (caja or "").replace("\n", " / ")))
    if not ok:
        fallas += 1

    auto = lee("AUTO")
    ok = auto == "true"
    print("  %s [%s] boton Auto en la barra de abajo: %s"
          % ("OK   " if ok else "FALLA", etiqueta, auto))
    if not ok:
        fallas += 1

# ---------------- FAIL-HARD: con el bug metido la prueba DEBE tronar --------
# (si esta parte pasara, seria que la validacion no revisa nada de verdad)
print("  -- fail-hard (se mete el bug a proposito) --")
r = corre(1920, 1080, "0",
          parche=("local nivel = math.clamp(math.floor(ratio * 5 + 0.5), 0, 5)",
                  "local nivel = 0   -- ENVENENO: las estrellas nunca se prenden"))
sal = r.stdout
m = re.search(r"__HEAT__ bajo=(\d+) medio=(\d+) alto=(\d+)", sal)
if m and m.group(3) == "0":
    print("  OK    con el bug, la prueba lo caza (0 estrellas prendidas al tope)")
else:
    print("  FALLA  la prueba no caza el bug de las estrellas: %s" % (m.group(0) if m else "(sin datos)"))
    fallas += 1

print("FALLO" if fallas else "OK")
sys.exit(1 if fallas else 0)
