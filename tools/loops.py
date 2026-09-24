#!/usr/bin/env python3
"""Caza el bug "borrar DENTRO del bucle que itera los hijos".

POR QUE EXISTE
  En Lua, esto esta MAL:

      for _, c in ipairs(ReplicatedStorage:GetChildren()) do
          c:Destroy()          -- <-- se salta al siguiente
      end

  Al borrar el primer hijo, la lista se encoge y `ipairs` avanza al indice 2,
  que ahora es el que era el 3... o sea que **SIEMPRE queda uno vivo**. Con dos
  carpetas `Remotes` viejas, solo se borraba una -> el cliente se enganchaba a
  la que sobraba y decia "faltan remotes".

  Lo correcto: JUNTAR en una lista y borrar despues.

QUE REVISA
  Cualquier `for ... in ipairs/pairs(<algo>:GetChildren()/GetDescendants())` que
  tenga un `:Destroy()` (o `:Remove()`) ADENTRO del cuerpo. El borrado despues
  del `end` del bucle es correcto y no se marca.

Uso:  python3 tools/loops.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

ARCHIVOS = [
    "ReplicatedStorage/GameConfig.luau",
    "ServerScriptService/CityGenerator.luau",
    "ServerScriptService/DataService.luau",
    "ServerScriptService/Main.luau",
    "StarterPlayerScripts/ClientUI.luau",
]

FOR_HIJOS = re.compile(r"^(\s*)for\s+.*\s+in\s+(?:ipairs|pairs)\s*\(\s*[^)]*Get(?:Children|Descendants)\(\)")
BORRA = re.compile(r":(?:Destroy|Remove)\s*\(\s*\)")


def sangria(linea):
    return len(linea) - len(linea.lstrip())


def revisa(ruta):
    lineas = open(ruta, encoding="utf-8").read().splitlines()
    hallazgos = []
    for i, l in enumerate(lineas):
        m = FOR_HIJOS.match(l)
        if not m:
            continue
        base = sangria(l)
        # recorre el cuerpo del bucle hasta el 'end' que cierra (misma sangria)
        for j in range(i + 1, len(lineas)):
            lj = lineas[j]
            if not lj.strip():
                continue
            if lj.strip().startswith("--"):
                continue
            if sangria(lj) <= base and re.match(r"^\s*end\b", lj):
                break                      # fin del bucle
            if BORRA.search(lj):
                hallazgos.append((i + 1, j + 1, lineas[i].strip(), lj.strip()))
    return hallazgos


def main():
    total = 0
    print("=== BORRAR DENTRO DEL BUCLE (se salta elementos) ===")
    for rel in ARCHIVOS:
        ruta = os.path.join(ROOT, rel)
        if not os.path.exists(ruta):
            continue
        h = revisa(ruta)
        if not h:
            print("  OK    %s" % rel)
            continue
        total += len(h)
        print("  FALLA %s" % rel)
        for forline, dl, txt_for, txt_del in h:
            print("          bucle en la linea %d, borra en la %d" % (forline, dl))
            print("            %s" % txt_for[:90])
            print("            %s" % txt_del[:90])
            print("          arreglo: junta los que vas a borrar en una lista y borra")
            print("                   despues del bucle (asi ipairs no se salta nada)")

    print()
    if total:
        print("FALLA")
        print("  %d lugar(es) borran dentro del bucle: siempre queda uno vivo" % total)
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
