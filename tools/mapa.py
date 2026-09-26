#!/usr/bin/env python3
"""MAPA COMPLETO DEL MUNDO (v50) — para poder VERLO sin abrir Studio.

Pide el usuario: "mandame la vista del lote... pero si puedes reconstruir literal
todo estaria mejor, lo del lote y los lotes vecinales para que puedas entenderlo
bien, tambien la ciudad y asi".

Este script arma EL MUNDO COMPLETO con el simulador (la ciudad tal cual la
construye `CityGenerator.Build()`, el lote del jugador con su bodega, y los lotes
vecinos con su estado: sin dueno / clausurado) y dibuja CUATRO vistas:

  1. LA CIUDAD COMPLETA, de arriba: el suelo, el agua, las calles de la ciudad y
     donde caen la reja, las tiendas y el spawn (rejilla de 500 studs).
  2. LOS 20 LOTES: la rejilla 5 x 4 con el numero de lote, cual es TU lote (1) y
     a que distancia queda la ciudad.
  3. TU LOTE en detalle, de arriba: la nave, el taller/cochera con su porton, la
     oficina, el patio, los bolardos, la reja y DONDE NACE LA BICI.
  4. TU LOTE de frente: la fachada de la nave y la del garaje con su placa, con
     las medidas reales (porton, techo, letra).

Uso:
    python3 tools/mapa.py                 -> /home/user/mapa-mundo.svg + .png
    python3 tools/mapa.py salida.svg
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
SALIDA = sys.argv[1] if len(sys.argv) > 1 else "/home/user/mapa-mundo.svg"


def L(ruta):
    return strip_luau(open(os.path.join(ROOT, ruta), encoding="utf-8").read()) \
        .replace("goto cont", "_SKIP=true")


def offset_bici():
    """A cuantos studs de la orilla del patio nace la bici: se LEE del codigo real
    (Main.luau), no se escribe a mano. Asi la vista no puede mentir respecto al juego."""
    src = open(os.path.join(ROOT, "ServerScriptService/Main.luau"), encoding="utf-8").read()
    m = re.search(r"patio\.Size\.Z \* 0\.5 \+ (\d+(?:\.\d+)?)\)\)\.Position", src)
    return float(m.group(1)) if m else -1.0


def arma_mundo():
    """Devuelve (partes de la ciudad, partes del lote, datos)."""
    g = 'dofile("%s/mock.lua")\n' % HERE
    g += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    g += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function() ''' + L("ServerScriptService/CityGenerator.luau") + ''' end)()
local ok, ciudad = pcall(function() return City.Build() end)
if ok and ciudad then
  for _, d in ipairs(ciudad:GetDescendants()) do
    if d:IsA("BasePart") then
      local c = d.Color or {R=200,G=200,B=200}
      print(string.format("C\\t%s\\t%.0f\\t%.0f\\t%.0f\\t%.1f\\t%.1f\\t%.1f\\t%d\\t%d\\t%d",
        d.Name, d.Position.X, d.Position.Y, d.Position.Z, d.Size.X, d.Size.Y, d.Size.Z,
        math.floor(c.R), math.floor(c.G), math.floor(c.B)))
    end
  end
end
local L_ = _cfg.WarehouseLots
-- TU lote (el 1) con todo lo de adentro, en coordenadas del mundo
local base = Vector3.new(L_.Origin.X, L_.Origin.Y, L_.Origin.Z)
local m = City.BuildWarehouse(1)
m:PivotTo(CFrame.new(base))
for _, d in ipairs(m:GetDescendants()) do
  if d:IsA("BasePart") then
    local c = d.Color or {R=200,G=200,B=200}
    local txt = ""
    for _, sg in ipairs(d:GetChildren()) do
      if sg:IsA("SurfaceGui") then
        local l = sg:FindFirstChild("Texto")
        if l and l.Text and l.Text ~= "" then txt = l.Text end
      end
    end
    print(string.format("W\\t%s\\t%.1f\\t%.1f\\t%.1f\\t%.1f\\t%.1f\\t%.1f\\t%d\\t%d\\t%d\\t%s",
      d.Name, d.Position.X, d.Position.Y, d.Position.Z, d.Size.X, d.Size.Y, d.Size.Z,
      math.floor(c.R), math.floor(c.G), math.floor(c.B),
      (txt ~= "" and txt or "-")))
  end
end
print(string.format("D\torigen\t%.0f\t%.0f\t%.0f\t%.0f\t%d\t%d\t%d",
  L_.Origin.X, L_.Origin.Z, L_.SpacingX, L_.SpacingZ, L_.PerRow, L_.MaxSlots, 0))
'''
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
    t.write(g)
    t.close()
    r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=900)
    os.unlink(t.name)
    ciudad, lote, datos = [], [], {}
    for linea in r.stdout.splitlines():
        f = linea.split("\t")
        if f[0] == "C":
            ciudad.append(dict(nombre=f[1], x=float(f[2]), y=float(f[3]), z=float(f[4]),
                               sx=float(f[5]), sy=float(f[6]), sz=float(f[7]),
                               r=int(f[8]), g=int(f[9]), b=int(f[10])))
        elif f[0] == "W":
            lote.append(dict(nombre=f[1], x=float(f[2]), y=float(f[3]), z=float(f[4]),
                             sx=float(f[5]), sy=float(f[6]), sz=float(f[7]),
                             r=int(f[8]), g=int(f[9]), b=int(f[10]), texto=f[11]))
        elif f[0] == "D":
            datos = dict(ox=float(f[2]), oz=float(f[3]), ex=float(f[4]), ez=float(f[5]),
                         porFila=int(f[6]), max=int(f[7]))
    if not datos:
        sys.exit("no se pudo armar el mundo:\n" + (r.stdout[-800:] + r.stderr[-800:]))
    return ciudad, lote, datos


def col(p, modo="edificio"):
    """El mundo real es casi todo blanco/gris claro (14405 de 14405 piezas claras):
    pintado tal cual, el mapa sale una mancha blanca. Aqui se baja a tonos medios y
    se pinta por papel (suelo, calle, banqueta) para que se VEA algo."""
    if modo == "suelo":
        return "#1b2318"
    if modo == "calle":
        return "#33334a"
    if modo == "banqueta":
        return "#4a4a5e"
    if modo == "porton":
        return "#c9a24a"
    if modo == "franja":
        return "#c0392b"
    if modo == "placa":
        return "#ffd479"
    if modo == "puerta":
        return "#8a6f3a"
    if modo == "cristal":
        return "#2f5f7a"
    if modo == "detalle":
        return "#7b8290"
    # edificio: se conserva el color pero bajado a un rango que se ve
    r, g, b = norma(p)
    v = (r * 0.30 + g * 0.59 + b * 0.11)
    t = 34 + v * 0.34
    f = t / 255.0
    return "#%02x%02x%02x" % (max(0, min(255, int(r * f))),
                              max(0, min(255, int(g * f))),
                              max(0, min(255, int(b * f))))


def norma(p):
    """Los Color3 del simulador ya vienen en 0-255 (Color3.fromRGB). Solo si
    vinieran en 0-1 (Color3.new) se suben a 255: sin esto el mundo salia blanco."""
    r, g, b = p["r"], p["g"], p["b"]
    if max(r, g, b) <= 1.05:
        r, g, b = r * 255, g * 255, b * 255      # venian en 0-1
    elif max(r, g, b) > 255.5:
        r, g, b = r / 255.0, g / 255.0, b / 255.0  # venian multiplicados dos veces
    return r, g, b


def modo_de(nombre):
    if nombre == "Ground":
        return "suelo"
    if nombre.startswith("Road"):
        return "calle"
    if nombre in ("Sidewalk", "Curb", "CurEdge", "CurbEdge", "CurbRamp"):
        return "banqueta"
    if nombre in ("DoorSlab", "DoorRail", "DoorRollBox", "DoorSlat"):
        return "porton"
    if nombre == "DoorStripe":
        return "franja"
    if nombre in ("GarageSign", "GateSign", "BayPlate", "VaultLabel", "MonitorLabel",
                  "FrontWall", "GarageDoorHead", "OfficeDoorHead"):
        return "placa"
    if nombre in ("DoorWindow", "UpgradeScreen"):
        return "cristal"
    if nombre in ("Window", "Trash", "Stain", "Line", "Ledge", "Tier"):
        return "detalle"
    return "edificio"


def vista_ciudad(ciudad, datos):
    """LA CIUDAD COMPLETA de arriba: manzanas, calles, el suelo y donde caen los
    lotes (para poder entender donde vive el jugador respecto a la ciudad)."""
    xs = [p["x"] + p["sx"] / 2 for p in ciudad] + [p["x"] - p["sx"] / 2 for p in ciudad]
    zs = [p["z"] + p["sz"] / 2 for p in ciudad] + [p["z"] - p["sz"] / 2 for p in ciudad]
    xs += [datos["ox"], datos["ox"] + datos["ex"] * datos["porFila"]]
    zs += [datos["oz"], datos["oz"] - datos["ez"] * 4]
    x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
    M = 80
    W = 1400
    e = (W - 2 * M) / max(1.0, (x1 - x0))
    H = int((z1 - z0) * e + 2 * M + 70)

    def X(x):
        return M + (x - x0) * e

    def Z(z):
        return M + (z1 - z) * e

    def caja(x, y, w, h, relleno, opac=1.0, trazo=None, grosor=0.6):
        t = (' stroke="%s" stroke-width="%s"' % (trazo, grosor)) if trazo else ""
        return ('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                'opacity="%.2f"%s/>' % (x, y, max(0.7, w), max(0.7, h), relleno, opac, t))

    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
           'viewBox="0 0 %d %d" font-family="monospace">' % (W, H, W, H),
           '<rect width="100%%" height="100%%" fill="#0d0d14"/>',
           '<text x="24" y="36" fill="#f5c45c" font-size="23">'
           'EL MUNDO COMPLETO (v50) — visto de arriba, 1 cuadro de la rejilla = 200 studs'
           '</text>',
           '<text x="24" y="60" fill="#a9a9bd" font-size="14">'
           'las 14 mil piezas del juego: el suelo, la ciudad con sus 10 calles y sus 7 '
           'tiendas, y abajo a la izquierda la zona de los 20 lotes de jugador</text>']
    # rejilla
    gx = int(x0 // 200) * 200
    while gx <= x1:
        out.append('<line x1="%.1f" y1="%d" x2="%.1f" y2="%d" stroke="#1c1c28"/>'
                   % (X(gx), M, X(gx), H - 30))
        out.append('<text x="%.1f" y="%d" fill="#3d3d55" font-size="11">x=%d</text>'
                   % (X(gx) + 3, M - 6, gx))
        gx += 200
    gz = int(z0 // 200) * 200
    while gz <= z1:
        out.append('<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#1c1c28"/>'
                   % (M, Z(gz), W - M, Z(gz)))
        out.append('<text x="%d" y="%.1f" fill="#3d3d55" font-size="11">z=%d</text>'
                   % (M - 62, Z(gz) + 4, gz))
        gz += 200
    # el suelo de todo el mundo primero, luego las piezas por capas
    suelo = [p for p in ciudad if p["nombre"] == "Ground"]
    for p in suelo:
        out.append(caja(X(p["x"] - p["sx"] / 2), Z(p["z"] + p["sz"] / 2),
                        p["sx"] * e, p["sz"] * e, col(p, "suelo")))
    # calles y banquetas
    for p in ciudad:
        if p["nombre"].startswith("Road") or p["nombre"] in ("Sidewalk", "Curb"):
            out.append(caja(X(p["x"] - p["sx"] / 2), Z(p["z"] + p["sz"] / 2),
                            p["sx"] * e, p["sz"] * e, col(p, modo_de(p["nombre"]))))
    # manzanas y detalles (lo que no es suelo/calle/banqueta)
    orden = sorted([p for p in ciudad
                    if p["nombre"] != "Ground" and not p["nombre"].startswith("Road")
                    and p["nombre"] not in ("Sidewalk", "Curb")],
                   key=lambda p: (p["y"], -(p["sx"] * p["sz"])))
    for p in orden:
        if p["sx"] * e < 1.0 and p["sz"] * e < 1.0:
            continue
        out.append(caja(X(p["x"] - p["sx"] / 2), Z(p["z"] + p["sz"] / 2),
                        p["sx"] * e, p["sz"] * e, col(p, modo_de(p["nombre"])),
                        0.95, "#101018" if p["sx"] * e > 3 else None))
    # las tiendas: una estrella por cada una
    tiendas = [p for p in ciudad if p["nombre"] == "Storefront"]
    for i, p in enumerate(tiendas):
        out.append('<circle cx="%.1f" cy="%.1f" r="5" fill="#7ad1ff"/>'
                   % (X(p["x"]), Z(p["z"])))
    if tiendas:
        tx = sum(p["x"] for p in tiendas) / len(tiendas)
        tz = sum(p["z"] for p in tiendas) / len(tiendas)
        out.append('<rect x="%.1f" y="%.1f" width="330" height="26" fill="#0d0d14" '
                   'opacity="0.85"/>' % (X(tx) - 160, Z(tz) + 42))
        out.append('<text x="%.1f" y="%.1f" fill="#7ad1ff" font-size="15">'
                   '★ LAS 7 TIENDAS de la ciudad (aqui compras mejoras)</text>'
                   % (X(tx) - 155, Z(tz) + 61))
    # la zona de lotes, bien marcada
    lx0 = X(min(datos["ox"] for _ in (0,)) - 160)
    lx1 = X(datos["ox"] + datos["ex"] * (datos["porFila"] - 1) + 160)
    lz0 = Z(datos["oz"] + 130)
    lz1 = Z(datos["oz"] - datos["ez"] * 3 - 130)
    out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#ffd479" '
               'opacity="0.06"/>' % (lx0, lz0, lx1 - lx0, lz1 - lz0))
    out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="none" '
               'stroke="#ffd479" stroke-width="2" stroke-dasharray="7 5"/>'
               % (lx0, lz0, lx1 - lx0, lz1 - lz0))
    out.append('<rect x="%.1f" y="%.1f" width="360" height="26" fill="#0d0d14"/>'
               % (lx0, lz0 - 30))
    out.append('<text x="%.1f" y="%.1f" fill="#ffd479" font-size="16" '
               'font-weight="bold">LOS 20 LOTES DE JUGADOR (tu lote es el 1)</text>'
               % (lx0 + 5, lz0 - 11))
    # los 20 lotes, uno por uno, con su numero
    for i in range(datos["max"]):
        fila = i // datos["porFila"]
        c = i % datos["porFila"]
        lx = datos["ox"] + c * datos["ex"]
        lz = datos["oz"] - fila * datos["ez"]
        esMio = (i == 0)
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                   'stroke="%s" stroke-width="%.1f"/>'
                   % (X(lx - 135), Z(lz + 80), 271 * e, 160 * e,
                      "#4a3d18" if esMio else "#23232e",
                      "#ffd479" if esMio else "#55557a", 2.4 if esMio else 1.4))
        if 271 * e > 26:
            out.append('<text x="%.1f" y="%.1f" fill="%s" font-size="%d" '
                       'text-anchor="middle">%s</text>'
                       % (X(lx), Z(lz) + 5, "#ffd479" if esMio else "#7a7a9c",
                          15 if esMio else 12, "1 (TUYO)" if esMio else str(i + 1)))
    # flecha del lote 1
    l1x, l1z = X(datos["ox"]), Z(datos["oz"])
    out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#ffd479" '
               'stroke-width="2"/>' % (l1x, lz0, l1x, l1z))
    out.append('<text x="%.1f" y="%.1f" fill="#ffd479" font-size="14">'
               'el 1 es TU LOTE (x=%.0f z=%.0f): la bodega, el taller y la bici '
               '— el detalle va en el cuadro de abajo</text>'
               % (lx0 + 8, lz1 + 22, datos["ox"], datos["oz"]))
    out.append('</svg>')
    return "\n".join(out)


def vista_lotes(datos):
    """Los 20 lotes, con el numero, y la distancia a la ciudad."""
    W, H = 1400, 780
    M = 90
    x0 = datos["ox"] - 200
    x1 = datos["ox"] + datos["ex"] * (datos["porFila"] - 1) + 320
    z0 = datos["oz"] + 160
    z1 = datos["oz"] - datos["ez"] * 3 - 160
    e = min((W - 2 * M) / (x1 - x0), (H - 2 * M) / (z1 - z0))

    def X(x):
        return M + (x - x0) * e

    def Z(z):
        return M + (z0 - z) * e

    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
           'viewBox="0 0 %d %d" font-family="monospace">' % (W, H, W, H),
           '<rect width="100%%" height="100%%" fill="#0d0d14"/>',
           '<text x="24" y="34" fill="#f5c45c" font-size="22">'
           'LOS 20 LOTES (5 x 4) — la huella de cada lote es de 271 x 160 studs, separados 340 en x y 260 en z</text>',
           '<text x="24" y="58" fill="#a9a9bd" font-size="14">'
           'el 1 es TU lote; los demas se llenan con bodegas vecinas (y se clausuran '
           'cuando su dueno se va)</text>']
    for i in range(datos["max"]):
        fila = i // datos["porFila"]
        c = i % datos["porFila"]
        lx = datos["ox"] + c * datos["ex"]
        lz = datos["oz"] - fila * datos["ez"]
        x = X(lx - 135)
        y = Z(lz + 80)
        w = 271 * e
        h = 160 * e
        esMio = (i == 0)
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                   'stroke="%s" stroke-width="2"/>'
                   % (x, y, w, h, "#3a3018" if esMio else "#1b1b26",
                      "#ffd479" if esMio else "#45455e"))
        out.append('<text x="%.1f" y="%.1f" fill="%s" font-size="%d">%s</text>'
                   % (x + w / 2 - 10, y + h / 2 + 5,
                      "#ffd479" if esMio else "#6c6c8a", 20 if esMio else 15,
                      ("TU LOTE" if esMio else str(i + 1))))
        out.append('<text x="%.1f" y="%.1f" fill="#3d3d55" font-size="11">'
                   'x=%.0f z=%.0f</text>' % (x + 6, y + h - 8, lx, lz))
    # la etiqueta de la ciudad
    out.append('<text x="%.1f" y="%.1f" fill="#7ad1ff" font-size="16">'
               '↑ hacia LA CIUDAD (calles, tiendas, aduana) — a ~%.0f studs del lote 1</text>'
               % (X(datos["ox"] - 160), Z(datos["oz"] + 120), abs(-660 - 30)))
    out.append('</svg>')
    return "\n".join(out)


def vista_lote_detalle(lote, datos):
    """TU lote de arriba, en grande, con las cosas importantes marcadas."""
    W, H = 1400, 1010
    piezas = [p for p in lote]
    xs = [p["x"] + p["sx"] / 2 for p in piezas] + [p["x"] - p["sx"] / 2 for p in piezas]
    zs = [p["z"] + p["sz"] / 2 for p in piezas] + [p["z"] - p["sz"] / 2 for p in piezas]
    x0, x1 = min(xs) - 10, max(xs) + 10
    z0, z1 = min(zs) - 10, max(zs) + 34     # +34: la calle y la bici caben arriba
    M = 80
    e = min((W - 2 * M) / (x1 - x0), (H - 2 * M - 260) / (z1 - z0))

    def X(x):
        return M + (x - x0) * e

    def Z(z):
        return M + (z1 - z) * e

    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
           'viewBox="0 0 %d %d" font-family="monospace">' % (W, H, W, H),
           '<rect width="100%%" height="100%%" fill="#0d0d14"/>',
           '<text x="24" y="34" fill="#f5c45c" font-size="23">'
           'TU LOTE (el 1) DE ARRIBA — las %d piezas reales, con la calle arriba</text>'
           % len(piezas),
           '<text x="24" y="58" fill="#a9a9bd" font-size="14">'
           'arriba esta la calle (la bici nace alli); la nave con su porton queda en medio '
           'y el patio del fondo</text>']
    orden = sorted(piezas, key=lambda p: (p["y"], -(p["sx"] * p["sz"])))
    for p in orden:
        w = max(1.5, p["sx"] * e)
        h = max(1.5, p["sz"] * e)
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                   'stroke="#0a0a10" stroke-width="0.6" opacity="0.92"/>'
                   % (X(p["x"] - p["sx"] / 2), Z(p["z"] + p["sz"] / 2), w, h,
                      col(p, modo_de(p["nombre"]))))
    # etiquetas de lo importante: un numerito sobre la pieza y la leyenda aparte
    # (con lineas cruzadas el dibujo quedaba hecho un nudo)
    MARCA = [
        ("GarageFloor", "TALLER / COCHERA (el cajon donde entra el coche)"),
        ("DoorSlab", "PORTON del cajon (se abre solo a 7 studs, con franja roja/blanca)"),
        ("GarageSign", "PLACA 'GARAJE DE ...' arriba del porton"),
        ("VaultLabel", "CAJA FUERTE adentro de la oficina (su placa va aparte, sin taparse)"),
        ("MonitorLabel", "MONITOR de MEJORAS (su placa va arriba del monitor)"),
        ("LotApron", "PATIO del fondo"),
    ]
    COLORES = ["#ffd479", "#7ad1ff", "#ffe082", "#ff9ecf", "#c9a2ff", "#8ce8a8"]
    ley = []
    for k, (nombre, et) in enumerate(MARCA):
        pz = next((q for q in piezas if q["nombre"] == nombre), None)
        if not pz:
            continue
        c = COLORES[k % len(COLORES)]
        cx, cy = X(pz["x"]), Z(pz["z"])
        if nombre == "GarageSign":       # casi encima de la placa del cajon
            cx, cy = cx + 26, cy - 20
        out.append('<circle cx="%.1f" cy="%.1f" r="10" fill="%s" stroke="#0d0d14" '
                   'stroke-width="2"/>' % (cx, cy, c))
        out.append('<text x="%.1f" y="%.1f" fill="#0d0d14" font-size="13" '
                   'font-weight="bold" text-anchor="middle">%d</text>' % (cx, cy + 4.5, k + 1))
        ley.append((k + 1, et, c))
    for n, (num, et, c) in enumerate(ley):
        fy = H - 150 + n * 24
        out.append('<circle cx="%.1f" cy="%.1f" r="9" fill="%s"/>' % (36, fy - 4, c))
        out.append('<text x="36" y="%.1f" fill="#0d0d14" font-size="12" '
                   'font-weight="bold" text-anchor="middle">%d</text>' % (fy, num))
        out.append('<text x="54" y="%.1f" fill="#e8ecf5" font-size="14">%s</text>'
                   % (fy, et))
    # la calle: una franja oscura arriba de la orilla del patio
    if piezas:
        ancho = x1 - x0
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#24242e" '
                   'stroke="#3a3a4c"/>'
                   % (X(x0), Z(z1), ancho * e, 26))
        out.append('<text x="%.1f" y="%.1f" fill="#7ad1ff" font-size="14">'
                   'LA CALLE (la bici nace aqui, 12 studs mas alla de tu terreno)</text>'
                   % (X(x0) + 8, Z(z1) + 18))
    # la calle y el punto donde nace la bici
    OFFSET_BICI = offset_bici()
    patio = next((p for p in lote if p["nombre"] == "LotApron"), None)
    if patio:
        orilla = patio["z"] + patio["sz"] / 2
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#4caf6d" '
                   'stroke-width="1.5" stroke-dasharray="6 4"/>'
                   % (X(x0), Z(orilla), X(x1), Z(orilla)))
        out.append('<text x="%.1f" y="%.1f" fill="#4caf6d" font-size="13">'
                   'orilla del patio: aqui se acaba tu terreno</text>'
                   % (X(x0) + 6, Z(orilla) + 16))
        bx, bz = patio["x"], orilla + OFFSET_BICI
        out.append('<circle cx="%.1f" cy="%.1f" r="7" fill="#7ad1ff"/>'
                   % (X(bx), Z(bz)))
        out.append('<text x="%.1f" y="%.1f" fill="#7ad1ff" font-size="14">'
                   'BICI de la entrega (nace aqui, fuera de tu terreno)</text>'
                   % (X(bx) + 12, Z(bz) + 5))
    out.append('</svg>')
    return "\n".join(out)


def vista_fachadas(lote):
    """LAS DOS FACHADAS de frente, como las ve el jugador parado en el patio:
       izquierda = LA NAVE (la bodega: su porton grande, el letrero, las costillas)
       derecha   = EL CAJON DEL COCHE (su porton de cortina con franja, su placa)
    Se dibujan las piezas de verdad que caen en el plano de cada fachada."""
    W, H = 1500, 1010
    out = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
           'viewBox="0 0 %d %d" font-family="monospace">' % (W, H, W, H),
           '<rect width="100%%" height="100%%" fill="#0d0d14"/>',
           '<text x="24" y="34" fill="#f5c45c" font-size="23">'
           'LAS DOS FACHADAS DE TU LOTE (v50) — parado en el patio</text>',
           '<text x="24" y="58" fill="#a9a9bd" font-size="14">'
           'izquierda: LA NAVE (la bodega) con su porton grande; derecha: EL CAJON DEL '
           'COCHE con su porton de cortina. Medidas y textos tal cual el juego</text>']

    def alzado(px, x_ini, x_fin, titulo, sub, piezas, esc, y_esc, alto_studs, color_titulo):
        """Un alzado: x en studs -> px (desde px), y en studs -> px (piso abajo)."""
        y_piso = 96 + 40 + alto_studs * y_esc
        ancho = (x_fin - x_ini) * esc
        out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#12121a" '
                   'stroke="#2b2b3d"/>' % (px, 96, ancho, y_piso - 96 + 56))
        out.append('<text x="%.1f" y="%d" fill="%s" font-size="18" '
                   'font-weight="bold">%s</text>' % (px + 10, 122, color_titulo, titulo))
        out.append('<text x="%.1f" y="%d" fill="#7a7a9c" font-size="12">%s</text>'
                   % (px + 10, 140, sub))

        def XX(x):
            return px + (x - x_ini) * esc

        def YY(y):
            return y_piso - y * y_esc

        for p in sorted(piezas, key=lambda q: (q["y"], -(q["sx"] * q["sy"]))):
            if p["nombre"] in ("GateSensor", "PlanterBush"):
                continue                      # sensor invisible y arbustos: estorban
            out.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                       'stroke="#0a0a10" stroke-width="0.8"/>'
                       % (XX(p["x"] - p["sx"] / 2), YY(p["y"] + p["sy"] / 2),
                          max(2.0, p["sx"] * esc), max(2.0, p["sy"] * y_esc),
                          col(p, modo_de(p["nombre"]))))
        # los textos de las placas, tal cual los dice el juego
        for p in piezas:
            if not p["texto"] or p["texto"] == "-":
                continue
            alto_letra = max(10.0, min(44.0, p["sx"] * esc * 0.11))
            # la letra del letrero es oscura sobre placa clara; sobre una placa oscura
            # (el respaldo del letrero, por ejemplo) tiene que ir clara o no se ve
            tinta = "#2b1f04" if modo_de(p["nombre"]) == "placa" else "#e8ecf5"
            out.append('<text x="%.1f" y="%.1f" fill="%s" font-size="%.1f" '
                       'text-anchor="middle" font-weight="bold">%s</text>'
                       % (XX(p["x"]), YY(p["y"]) + alto_letra * 0.36,
                          tinta, alto_letra, p["texto"]))
        # el piso
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#4caf6d" '
                   'stroke-width="2"/>' % (XX(x_ini), YY(0), XX(x_fin), YY(0)))
        out.append('<text x="%.1f" y="%.1f" fill="#4caf6d" font-size="12">'
                   'piso (y=0)</text>' % (XX(x_ini) + 4, YY(0) + 15))
        # una regla abajo con el ancho, en studs
        reg = YY(0) + 26
        out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#5c5c72"/>'
                   % (XX(x_ini), reg, XX(x_fin), reg))
        for k in range(int(x_ini), int(x_fin) + 1, 10):
            out.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#3d3d55"/>'
                       % (XX(k), reg - 4, XX(k), reg + 4))
            out.append('<text x="%.1f" y="%.1f" fill="#3d3d55" font-size="10">%d</text>'
                       % (XX(k), reg + 16, k))
        out.append('<text x="%.1f" y="%.1f" fill="#7a7a9c" font-size="12">'
                   'coordenada x (studs) — 1 cuadrito chico = 10 studs</text>'
                   % (XX(x_ini), reg + 32))
        return XX, YY

    # ---- 1) LA NAVE: su fachada es el plano z = -632
    nave = [p for p in lote if abs(p["z"] + 632.0) <= 2.5]
    alzado(60, -668, -532, "1) LA NAVE (la bodega), de frente",
           "porton grande de cortina, letrero IMPERIO DE ESPECIAS y costillas",
           nave, 4.3, 22.0, 27, "#8ce8a8")
    # ---- 2) EL CAJON: su porton esta en el plano z = -652.4, a la izquierda
    cajon = [p for p in lote if abs(p["z"] + 652.4) <= 3.2 and p["x"] <= -627]
    alzado(800, -672, -625, "2) EL CAJON DEL COCHE, de frente",
           "porton de cortina (franja roja/blanca, ventana y rieles) y su placa",
           cajon, 9.6, 32.0, 19, "#ffd479")

    # ---- notas al pie, con las medidas clave
    notas = [
        ("#8ce8a8", "la nave: 70 studs de ancho, 20 de alto; el porton de cortina mide "
                    "23.8 x 16 y el letrero va arriba (y=23.2)"),
        ("#ffd479", "el cajon: 26 de ancho por 24 de fondo; el porton mide 24.3 x 10.4 "
                    "y la placa 'GARAJE DE ...' va arriba (y=15.6): se VE, no la tapa el techo"),
        ("#7ad1ff", "los dos portones de cortina se abren solos cuando te acercas "
                    "(7 studs): por eso a veces se ven levantados y parece que no hay puerta"),
    ]
    for i, (c, t) in enumerate(notas):
        out.append('<text x="60" y="%.1f" fill="%s" font-size="15">%s</text>'
                   % (H - 66 + i * 24, c, t))
    out.append('</svg>')
    return "\n".join(out)


ciudad, lote, datos = arma_mundo()
print("ciudad: %d piezas | tu lote: %d piezas | lotes: %d" %
      (len(ciudad), len(lote), datos.get("max", 0)))
partes = [vista_ciudad(ciudad, datos), vista_lotes(datos),
          vista_lote_detalle(lote, datos), vista_fachadas(lote)]

# los cuatro cuadros apilados en un solo SVG (ancho comun, para que no se corte nada)
ANCHO = 1500
cuerpos, alto = [], 0
for p in partes:
    cab = p.split("\n")
    w = int(cab[0].split('width="')[1].split('"')[0])
    h = int(cab[0].split('height="')[1].split('"')[0])
    interno = "\n".join(cab[2:-1])
    escala = 1.0 if w <= ANCHO else ANCHO / float(w)
    if escala != 1.0:
        interno = ('<g transform="scale(%.4f)">%s</g>' % (escala, interno))
        h = int(h * escala)
        w = int(w * escala)
    cuerpos.append('<g transform="translate(0,%d)">%s</g>' % (alto, interno))
    alto += h + 20

final = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
         'viewBox="0 0 %d %d" font-family="monospace">'
         '<rect width="100%%" height="100%%" fill="#0d0d14"/>%s</svg>'
         % (ANCHO, alto, ANCHO, alto, "\n".join(cuerpos)))
open(SALIDA, "w", encoding="utf-8").write(final)

# resumen para las pruebas (tools/mundo50.py): lo que se midio de verdad
bici = next((q for q in lote if q["nombre"] == "LotApron"), None)
patio_orilla = (bici["z"] + bici["sz"] / 2) if bici else 0
rieles = [q for q in lote if q["nombre"] == "DoorRail"]
placas = [q["nombre"] for q in lote if q["nombre"] in ("VaultLabel", "MonitorLabel")]
print("__MAPA__ vistas=%d ciudad=%d lote=%d lotes=%d rieles=%d placas=%s bici_z=%.1f "
      "orilla=%.1f ancho=%d alto=%d"
      % (len(partes), len(ciudad), len(lote), datos.get("max", 0), len(rieles),
         ",".join(sorted(placas)), (patio_orilla + offset_bici()), patio_orilla, ANCHO, alto))
print("listo: %s" % SALIDA)
