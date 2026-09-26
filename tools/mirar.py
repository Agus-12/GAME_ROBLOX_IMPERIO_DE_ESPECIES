#!/usr/bin/env python3
"""MIRA EL LOTE SIN ABRIR STUDIO (v49).

El usuario pregunto: "no podemos hacer mas facil esto? que tu de verdad veas el
juego en vivo?" — No se puede ver el juego en vivo (no tengo acceso a tu Studio),
pero SI se puede ver el LOTE que construye CityGenerator: este script lo arma con
el simulador, saca las medidas reales de las piezas y dibuja un SVG con:

  * la FACHADA vista de frente (el porton, la placa de la cochera con su letra,
    el techo, el letrero), con las medidas de cada cosa
  * la PLANTA vista de arriba (el lote, el patio, la cochera, la bici)

Uso:
    python3 tools/mirar.py                 -> guarda /home/user/mirar-lote.svg
    python3 tools/mirar.py salida.svg      -> otro archivo
"""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau            # noqa: E402

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")
SALIDA = sys.argv[1] if len(sys.argv) > 1 else "/home/user/mirar-lote.svg"


def L(ruta):
    return strip_luau(open(os.path.join(ROOT, ruta), encoding="utf-8").read()) \
        .replace("goto cont", "_SKIP=true")


def piezas():
    g = 'dofile("%s/mock.lua")\n' % HERE
    g += "local _cfg=(function()\n" + L("ReplicatedStorage/GameConfig.luau") + "\nend)()\n"
    g += '''
local rs=game:GetService("ReplicatedStorage")
rs.WaitForChild=function(s,n) if n=="GameConfig" then return "__CFG__" end end
require=function(x) if x=="__CFG__" then return _cfg end return {} end
local City=(function() ''' + L("ServerScriptService/CityGenerator.luau") + ''' end)()
local m = City.BuildWarehouse(1)
City.RotularGaraje(m, "GARAJE DE PEPE")
for _, d in ipairs(m:GetDescendants()) do
  if d:IsA("BasePart") then
    local c = d.Color or {R=200,G=200,B=200}
    local txt = ""
    for _, sg in ipairs(d:GetChildren()) do
      if sg:IsA("SurfaceGui") then
        local l = sg:FindFirstChild("Texto")
        if l then txt = l.Text end
      end
    end
    print(string.format("P\\t%s\\t%.2f\\t%.2f\\t%.2f\\t%.2f\\t%.2f\\t%.2f\\t%d\\t%d\\t%d\\t%s",
      d.Name, d.Position.X, d.Position.Y, d.Position.Z,
      d.Size.X, d.Size.Y, d.Size.Z,
      math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255),
      (txt ~= "" and txt or "-")))
  end
end
'''
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False)
    t.write(g)
    t.close()
    r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=300)
    os.unlink(t.name)
    out = []
    for linea in r.stdout.splitlines():
        if not linea.startswith("P\t"):
            continue
        f = linea.split("\t")
        out.append(dict(nombre=f[1], x=float(f[2]), y=float(f[3]), z=float(f[4]),
                        sx=float(f[5]), sy=float(f[6]), sz=float(f[7]),
                        r=int(f[8]), g=int(f[9]), b=int(f[10]), texto=f[11]))
    return out


def color(p):
    return "rgb(%d,%d,%d)" % (max(0, min(255, p["r"])), max(0, min(255, p["g"])),
                              max(0, min(255, p["b"])))


def svg(ps):
    """Dos vistas con las medidas reales: la fachada (de frente) y la planta."""
    W, H = 1400, 1000
    partes = []
    partes.append('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
                  'viewBox="0 0 %d %d" font-family="monospace">' % (W, H, W, H))
    partes.append('<rect width="100%" height="100%" fill="#0f0f16"/>')
    partes.append('<text x="24" y="40" fill="#f5c45c" font-size="24">'
                  'EL LOTE VISTO DE FRENTE (v49)</text>')
    partes.append('<text x="24" y="64" fill="#a9a9bd" font-size="14">'
                  'medidas REALES que construye CityGenerator, parado en el patio</text>')

    # ====== VISTA 1: la fachada. Se mira de frente al porton del garage.
    # El garage esta centrado en GAR_X del lote; aqui se dibuja alrededor de esa X.
    gar = next((p for p in ps if p["nombre"] == "DoorSlab"), None)
    if not gar:
        raise SystemExit("no encontre el porton")
    cx, cz = gar["x"], gar["z"]                 # centro del porton
    e = 11.0                                    # px por stud (horizontal)
    ev = 15.0                                   # px por stud (vertical)

    def X(x):
        return 700 + (x - cx) * e

    def Y(y):
        return 620 - y * ev

    # lo que va detras (piso del patio y la cochera)
    for p in sorted(ps, key=lambda q: q["y"]):
        if p["nombre"] in ("LotApron", "GateApron") and abs(p["z"] - cz) < 40:
            x0 = max(X(p["x"] - p["sx"] / 2), 40)
            x1 = min(X(p["x"] + p["sx"] / 2), W - 40)
            if x1 > x0:
                partes.append('<rect x="%.1f" y="%.1f" width="%.1f" height="8" '
                              'fill="%s" opacity="0.85"/>' % (x0, Y(p["y"]) - 4, x1 - x0,
                                                              color(p)))
    partes.append('<line x1="40" y1="%.1f" x2="%d" y2="%.1f" stroke="#2b2b3d"/>'
                  % (Y(0), W - 40, Y(0)))
    partes.append('<text x="46" y="%.1f" fill="#5c5c72" font-size="13">piso (y=0)</text>'
                  % (Y(0) + 16))

    # capas de la fachada, de atras hacia adelante
    ORDEN = {"GarageWall": 1, "GarageCeiling": 2, "DoorSlab": 3, "DoorSlat": 4,
             "DoorStripe": 5, "DoorWindow": 6, "DoorHandle": 7}
    for nivel in range(1, 8):
        for p in ps:
            if ORDEN.get(p["nombre"], 0) != nivel:
                continue
            if abs(p["z"] - cz) > 4:            # solo lo que esta en el plano del frente
                continue
            x0 = X(p["x"] - p["sx"] / 2)
            y0 = Y(p["y"] + p["sy"] / 2)
            partes.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                          'stroke="#0a0a10" stroke-width="1"/>'
                          % (x0, y0, p["sx"] * e, p["sy"] * ev, color(p)))
    # el letrero de la cochera (pegado al frente, arriba del porton)
    for p in ps:
        if p["nombre"] != "GarageSign":
            continue
        partes.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#262a32" '
                      'stroke="#0a0a10" stroke-width="2"/>'
                      % (X(p["x"] - p["sx"] / 2), Y(p["y"] + p["sy"] / 2),
                         p["sx"] * e, p["sy"] * ev))
        partes.append('<text x="%.1f" y="%.1f" fill="#ffe082" font-size="44" '
                      'text-anchor="middle" font-weight="bold">GARAJE DE PEPE</text>'
                      % (X(gar["x"]), Y(p["y"]) + 15))
    # el dintel con el nombre de la bodega y la placa del cajon
    for p in ps:
        if p["nombre"] in ("FrontWall", "BayPlate") and abs(p["z"] - cz) > 40:
            continue
        if p["nombre"] == "BayPlate":
            partes.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                          'stroke="#0a0a10"/>' % (X(p["x"] - p["sx"] / 2),
                                                  Y(p["y"] + p["sy"] / 2),
                                                  p["sx"] * e, p["sy"] * ev, color(p)))
            partes.append('<text x="%.1f" y="%.1f" fill="#e8ecf5" font-size="17" '
                          'text-anchor="middle">CAJA 1</text>' % (X(p["x"]), Y(p["y"]) + 6))
    # cotas de lo importante
    def cota(txt, x, y, col="#8ce8a8", size=14):
        partes.append('<text x="%.1f" y="%.1f" fill="%s" font-size="%d">%s</text>'
                      % (x, y, col, size, txt))
    cota("porton %.1f de ancho x %.1f de alto" % (gar["sx"], gar["sy"]),
         X(gar["x"] - gar["sx"] / 2), Y(1.0), "#8ce8a8")
    cota("franja de seguridad roja/blanca", X(gar["x"] - gar["sx"] / 2), Y(2.2), "#ff9a8c")
    sign = next((p for p in ps if p["nombre"] == "GarageSign"), None)
    if sign:
        cota("PLACA de la cochera: letra de 4.1 studs (antes 0.2)",
             X(sign["x"] - sign["sx"] / 2), Y(sign["y"] + sign["sy"] / 2) - 10, "#ffe082")
    tech = next((p for p in ps if p["nombre"] == "GarageCeiling"), None)
    if tech:
        cota("techo y=%.1f" % (tech["y"] + tech["sy"] / 2), X(20), Y(tech["y"] + 1.2),
             "#8ce8a8")

    # ====== VISTA 2: la planta (de arriba), con el lote, el patio y la bici
    partes.append('<text x="24" y="740" fill="#f5c45c" font-size="20">'
                  'LA PLANTA (arriba): la cochera, el patio, la calle y donde nace la bici'
                  '</text>')
    ep = 1.9                                    # px por stud (planta)
    ox, oz = 700 - cx * ep, 900

    def PX(x):
        return ox + x * ep

    def PZ(z):
        return oz - (z - cz) * ep

    for p in ps:
        if p["nombre"] not in ("LotApron", "GarageFloor", "GateApron"):
            continue
        partes.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" '
                      'stroke="#0a0a10" opacity="0.8"/>'
                      % (PX(p["x"] - p["sx"] / 2), PZ(p["z"] + p["sz"] / 2) - 6,
                         p["sx"] * ep, p["sz"] * ep, color(p)))
        partes.append('<text x="%.1f" y="%.1f" fill="#cfcfe0" font-size="12">%s</text>'
                      % (PX(p["x"] + p["sx"] / 2) + 4, PZ(p["z"]) + 4, p["nombre"]))
    partes.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#3a3a4e"/>'
                  % (PX(cx - 34), PZ(cz + 62), PX(cx + 34), PZ(cz + 62)))
    partes.append('<text x="%.1f" y="%.1f" fill="#8ce8a8" font-size="13">'
                  'aqui nace la BICI: 6 studs mas alla del patio (nunca adentro)</text>'
                  % (PX(cx - 34), PZ(cz + 62) - 8))
    partes.append('<circle cx="%.1f" cy="%.1f" r="6" fill="#7ad1ff"/>'
                  % (PX(cx), PZ(cz + 62)))
    partes.append('<text x="%.1f" y="%.1f" fill="#7ad1ff" font-size="12">BICI</text>'
                  % (PX(cx) + 10, PZ(cz + 62) + 4))
    partes.append('</svg>')
    return "\n".join(partes)


ps = piezas()
if not ps:
    sys.exit("no se pudo armar el lote")
open(SALIDA, "w", encoding="utf-8").write(svg(ps))
print("listo: %s  (%d piezas del lote dibujadas)" % (SALIDA, len(ps)))
