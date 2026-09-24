#!/usr/bin/env python3
"""Alcanzabilidad REAL de la bodega.

parts.py solo comprueba que las partes EXISTAN. Eso no dice nada de si el
jugador puede llegar a ellas: en la v27 el garaje existia, con sus cajones y
todo, pero estaba SELLADO (la pared izquierda no tenia hueco) y ninguna
validacion lo noto.

Que hace:
  1. Construye los 4 niveles de bodega bajo el mock y exporta TODAS las
     partes (nombre, tamano, posicion, colision).
  2. Tira un flood fill en 2D a la altura del torso del jugador, tratando
     como muro toda parte con colision que le tape el paso.
  3. Verifica que desde el punto de aparicion se pueda CAMINAR hasta:
     la oficina, la caja fuerte, la computadora, la prensa, la mesa 1,
     el garaje y la calle (salir por el porton).
  4. Revisa que el anexo no choque con la bodega del vecino.
"""
import subprocess, tempfile, sys, os, re
from collections import deque
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")

# Piezas que NO cuentan como muro aunque tengan colision:
#  - hojas del porton: se abren solas al acercarte (Main::setupGate)
#  - partes decorativas de menos de 0.6 de alto (rayas, tapetes)
#  - el modelo del vigilante y demas NPC
EXEMPT = re.compile(r"^(GateLeft|GateRight|GateRib|GateSensor)$")
NPC = re.compile(r"Lookout|Buyer|Worker|Raider|Guard|NPC|Vigilante")

DUMP = r'''
dofile("@@MOCK@@")
local CFG=(function() @@CFG@@ end)()
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function() return "__CFG__" end
require=function(x) if x=="__CFG__" then return CFG end return {} end
local city=(function() @@CITY@@ end)()

local out={}
local function ser(inst, chain)
  local p=inst
  for _, c in ipairs(p:GetChildren()) do
    local n=c.Name
    local cls=c.ClassName
    local ch=chain.."/"..n
    local sz=c.Size
    local pos=c.Position
    local cc=c.CanCollide
    if cc==nil then cc=true end
    if sz and pos and cls=="Part" then
      out[#out+1]=table.concat({n, ch, sz.X, sz.Y, sz.Z, pos.X, pos.Y, pos.Z,
        cc and 1 or 0, (c.Transparency or 0)}, "\t")
    end
    ser(c, ch)
  end
end
local L=CFG.WarehouseLots
if L then
  out[#out+1]=("###LOTES\t%f\t%f\t%f\t%f\t%d\t%d"):format(
    L.Origin.X, L.Origin.Z, L.SpacingX, L.SpacingZ, L.PerRow, L.MaxSlots)
end
for tier=1,4 do
  local ok, wh = pcall(function() return city.BuildWarehouse(tier) end)
  if ok then
    out[#out+1]=("###TIER\t%d"):format(tier)
    ser(wh, "Warehouse")
  else
    out[#out+1]=("###ERR\t%d\t%s"):format(tier, tostring(wh))
  end
end
-- el suelo de la ciudad (para comprobar que los lotes caen SOBRE el)
local okc, cityF = pcall(function() return city.Build() end)
if okc and cityF then
  for _, c in ipairs(cityF:GetChildren()) do
    if c.Name == "Ground" and c.Size and c.Position then
      out[#out+1]=("###GROUND\t%f\t%f\t%f\t%f"):format(c.Position.X, c.Position.Z, c.Size.X, c.Size.Z)
    end
  end
end
local f=io.open("@@OUT@@","w")
for _,l in ipairs(out) do f:write(l,"\n") end
f:close()
print("geometria exportada")
'''

class Part:
    __slots__ = ("name", "chain", "x", "y", "z", "sx", "sy", "sz", "collide", "tr")

def load():
    cfg = strip_luau(open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau")).read())
    city = strip_luau(open(os.path.join(ROOT, "ServerScriptService/CityGenerator.luau")).read())
    city = city.replace("goto cont", "_SKIP=true")   # 'continue' de Luau
    h = (DUMP.replace("@@MOCK@@", os.path.join(HERE, "mock.lua"))
             .replace("@@CFG@@", cfg).replace("@@CITY@@", city)
             .replace("@@OUT@@", "/tmp/geom.tsv"))
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False); t.write(h); t.close()
    r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=180)
    os.unlink(t.name)
    if r.returncode != 0:
        sys.exit("no se pudo construir la geometria: " + r.stderr[-500:])
    tiers, cur, lots, ground = {}, None, None, None
    for line in open("/tmp/geom.tsv"):
        if line.startswith("###TIER"):
            cur = int(line.split("\t")[1]); tiers[cur] = []
        elif line.startswith("###LOTES"):
            f = line.split("\t")
            lots = dict(ox=float(f[1]), oz=float(f[2]), sx=float(f[3]),
                        sz=float(f[4]), per_row=int(f[5]), max_slots=int(f[6]))
        elif line.startswith("###GROUND"):
            f = line.split("\t")
            ground = dict(cx=float(f[1]), cz=float(f[2]), w=float(f[3]), d=float(f[4]))
        elif line.startswith("###ERR"):
            print("  !! " + line.strip())
        else:
            f = line.rstrip("\n").split("\t")
            p = Part()
            p.name, p.chain = f[0], f[1]
            p.sx, p.sy, p.sz = float(f[2]), float(f[3]), float(f[4])
            p.x, p.y, p.z = float(f[5]), float(f[6]), float(f[7])
            p.collide, p.tr = f[8] == "1", float(f[9])
            tiers[cur].append(p)
    return tiers, lots, ground

# ----------------------------------------------------------------------
def is_blocker(p, feet, head):
    """¿Esta parte le tapa el paso a un jugador parado en el piso?"""
    if not p.collide:
        return False
    if EXEMPT.match(p.name):
        return False
    if NPC.search(p.chain):
        return False
    if p.tr >= 0.95:                      # invisible decorativo
        return False
    # la parte tiene que invadir la franja del torso
    lo, hi = p.y - p.sy / 2, p.y + p.sy / 2
    if hi <= feet + 0.35 or lo >= head:   # se pisa o se pasa debajo
        return False
    return True

def reach(tier_parts, start, targets, feet=2.0, head=6.4, R=1.7, cell=1.0):
    """Flood fill 2D a la altura del torso. Devuelve (resultado por objetivo,
    si el spawn quedo dentro de un muro)."""
    blockers = [p for p in tier_parts if is_blocker(p, feet, head)]

    xs = [start[0]] + [t[0] for t in targets.values()]
    zs = [start[1]] + [t[1] for t in targets.values()]

    for p in blockers:
        xs += [p.x - p.sx / 2, p.x + p.sx / 2]
        zs += [p.z - p.sz / 2, p.z + p.sz / 2]
    x0, x1 = min(xs) - 4, max(xs) + 4
    z0, z1 = min(zs) - 4, max(zs) + 4
    W = int((x1 - x0) / cell) + 2
    H = int((z1 - z0) / cell) + 2

    def cix(x):
        return int(round((x - x0) / cell)) + 1

    def ciz(z):
        return int(round((z - z0) / cell)) + 1

    grid = bytearray(W * H)      # 0 = libre, 1 = muro
    for p in blockers:           # se "estampa" cada muro en la rejilla
        for ix in range(cix(p.x - p.sx / 2 - R), cix(p.x + p.sx / 2 + R) + 1):
            if not (1 <= ix <= W):
                continue
            cx = x0 + (ix - 1) * cell
            if abs(cx - p.x) > p.sx / 2 + R:
                continue
            for iz in range(ciz(p.z - p.sz / 2 - R), ciz(p.z + p.sz / 2 + R) + 1):
                if not (1 <= iz <= H):
                    continue
                if abs((z0 + (iz - 1) * cell) - p.z) > p.sz / 2 + R:
                    continue
                grid[(ix - 1) * H + (iz - 1)] = 1

    sc = (cix(start[0]), ciz(start[1]))
    inwall = grid[(sc[0] - 1) * H + (sc[1] - 1)] == 1
    if inwall:
        return {}, True

    seen = bytearray(W * H)
    seen[(sc[0] - 1) * H + (sc[1] - 1)] = 1
    q = deque([sc])
    while q:
        ix, iz = q.popleft()
        for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, nz = ix + dx, iz + dz
            if not (1 <= nx <= W and 1 <= nz <= H):
                continue
            k = (nx - 1) * H + (nz - 1)
            if seen[k] or grid[k]:
                continue
            seen[k] = 1
            q.append((nx, nz))

    out = {}
    for name, tgt in targets.items():
        tx, tz = tgt[0], tgt[1]
        ok = False
        rad = tgt[2] if len(tgt) > 2 else 3
        tc = (cix(tx), ciz(tz))
        for dx in range(-rad, rad + 1):
            for dz in range(-rad, rad + 1):
                nx, nz = tc[0] + dx, tc[1] + dz
                if 1 <= nx <= W and 1 <= nz <= H and seen[(nx - 1) * H + (nz - 1)]:
                    ok = True
                    break
            if ok:
                break
        out[name] = ok
    return out, False

def main():
    if not os.path.exists(LUA):
        sys.exit("Falta Lua. Corre primero:  bash tools/setup.sh")
    tiers, lots, ground = load()
    bad = 0
    SPACING = lots["sx"] if lots else 340
    for tier in sorted(tiers):
        parts = tiers[tier]
        by = {}
        for p in parts:
            by.setdefault(p.name, p)
        if not by:
            print("tier %d: no se genero nada" % tier)
            bad = 1
            continue

        def pos(name):
            p = by.get(name)
            return (p.x, p.z) if p else None

        start = (0.0, 0.0)                       # centro del piso (ahi te deja el spawn)
        targets = {}
        # A que distancia del centro de la pieza cuenta como "llegue": son los
        # radios que usa el juego para ofrecerte el boton, con colchon.
        for label, name, rad in (("oficina", "OfficeSlab", 8), ("caja fuerte", "VaultPad", 10),
                                 ("computadora", "UpgradePad", 10), ("prensa", "PressBase", 12),
                                 ("mesa 1", "Plot1", 10), ("garaje", "GarageFloor", 6),
                                 ("cajon 1", "Bay1", 6), ("escalon del porton", "GateSensor", 6)):
            q = pos(name)
            if q:
                targets[label] = (q[0], q[1], rad)
        # la calle: 20 studs afuera del frente
        front = max(p.z + p.sz / 2 for p in parts)
        targets["la calle"] = (0.0, front + 20, 6)

        res, inwall = reach(parts, start, targets)
        print("\n=== TIER %d ===" % tier)
        if inwall:
            print("  !! el punto de aparicion queda DENTRO de una parte solida")
            bad = 1
        if res:
            for k in sorted(res):
                print("  %s %s" % ("OK   " if res[k] else "FALLA", k))
                if not res[k]:
                    bad = 1

        # la oficina tiene que estar POR FUERA del muro derecho
        off = by.get("OfficeSlab")
        wall3 = [p for p in parts if p.name == "Wall3"]
        if off and wall3:
            borde = max(p.x + p.sx / 2 for p in wall3)
            if off.x - off.sx / 2 < borde - 1:
                print("  FALLA la oficina esta DENTRO de la nave (x=%.0f, el muro esta en %.0f)"
                      % (off.x, borde))
                bad = 1
            else:
                print("  OK    la oficina esta por fuera (x=%.0f, muro en %.0f)" % (off.x, borde))

        # el anexo no debe ensimismarse con la bodega vecina
        xs = [p.x - p.sx / 2 for p in parts] + [p.x + p.sx / 2 for p in parts]
        ancho = max(xs) - min(xs)
        if ancho > SPACING - 4:
            print("  FALLA el anexo mide %.0f studs de ancho y las bodegas se "
                  "siembran cada %d: choca con la del vecino" % (ancho, SPACING))
            bad = 1
        else:
            print("  OK    ancho total %.0f studs (separacion %d)" % (ancho, SPACING))

    # el suelo tiene que cubrir TODOS los lotes, o al salir de tu bodega
    # te caes al vacio gris
    if lots and ground:
        cols = max(1, min(lots["per_row"], lots["max_slots"]))
        rows = max(1, -(-lots["max_slots"] // lots["per_row"]))
        hw, hd = 150, 95
        lx0 = lots["ox"] - hw
        lx1 = lots["ox"] + (cols - 1) * lots["sx"] + hw
        lz0 = lots["oz"] - (rows - 1) * lots["sz"] - hd
        lz1 = lots["oz"] + hd
        gx0, gx1 = ground["cx"] - ground["w"] / 2, ground["cx"] + ground["w"] / 2
        gz0, gz1 = ground["cz"] - ground["d"] / 2, ground["cz"] + ground["d"] / 2
        print("\n=== LOTES vs SUELO ===")
        print("  lotes:  x %.0f..%.0f   z %.0f..%.0f" % (lx0, lx1, lz0, lz1))
        print("  suelo:  x %.0f..%.0f   z %.0f..%.0f" % (gx0, gx1, gz0, gz1))
        if lx0 >= gx0 and lx1 <= gx1 and lz0 >= gz0 and lz1 <= gz1:
            print("  OK    los %d lotes caen sobre el suelo" % lots["max_slots"])
        else:
            print("  FALLA hay lotes FUERA del suelo: el jugador cae al vacio")
            bad = 1

    print()
    if bad:
        print("FALLO")
    else:
        print("OK")
    sys.exit(1 if bad else 0)

if __name__ == "__main__":
    main()
