#!/usr/bin/env python3
"""Revisa que cada Instance.new("X") del juego use una CLASE de verdad.

POR QUE EXISTE (v41)
    El cliente hacia  Instance.new("AutomaticSize")  y AutomaticSize NO es una clase
    de Roblox (es una PROPIEDAD del objeto). En Studio eso truena ahi mismo, a media
    construccion de la interfaz: la barra ancha ya estaba dibujada y el script moria
    ANTES de esconderla. Resultado: el jugador veia el tablero viejo para siempre.
    El simulador no lo cazo porque Instance.new aceptaba cualquier nombre inventado.

    Este chequeo compara todos los Instance.new() del juego contra la lista real de
    clases de Roblox (tools/clases-roblox.txt, sacada del API-Dump).
"""
import os
import re
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
LISTA = os.path.join(AQUI, "clases-roblox.txt")

ARCHIVOS = [
    "ReplicatedStorage/GameConfig.luau",
    "ServerScriptService/CityGenerator.luau",
    "ServerScriptService/DataService.luau",
    "ServerScriptService/Main.luau",
    "StarterPlayerScripts/ClientUI.luau",
    "tools/limpiar.luau",
]


def clases_validas():
    if not os.path.exists(LISTA):
        print("FALLA  falta %s (corre tools/api.py o copiala del API-Dump)" % LISTA)
        return None
    with open(LISTA, encoding="utf-8") as f:
        return set(l.strip() for l in f if l.strip() and not l.startswith("#"))


def sin_comentarios(src):
    src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.S)
    return re.sub(r"--[^\n]*", "", src)


def main():
    validas = clases_validas()
    if validas is None:
        return 1
    # sin argumentos revisa los archivos del juego; con argumentos, esos
    # (asi tools/copias.py puede probar que este chequeo SI cace una clase inventada)
    lista = sys.argv[1:] or ARCHIVOS
    problemas = 0
    for rel in lista:
        ruta = os.path.join(RAIZ, rel)
        if not os.path.exists(ruta):
            continue
        src = sin_comentarios(open(ruta, encoding="utf-8").read())
        for m in re.finditer(r'Instance\.new\(\s*"([A-Za-z0-9_]+)"', src):
            cls = m.group(1)
            if cls not in validas:
                linea = src[:m.start()].count("\n") + 1
                print("FALLA  %s linea %d: Instance.new(\"%s\") - eso NO es una clase de"
                      " Roblox (truena en Studio)" % (rel, linea, cls))
                problemas += 1
        # clases con nombre mal escrito (mayusculas/minusculas): aviso suave
        for m in re.finditer(r'Instance\.new\(\s*"([A-Za-z0-9_]+)"', src):
            cls = m.group(1)
            if cls in validas:
                continue
            cerca = [v for v in validas if v.lower() == cls.lower()]
            if cerca:
                linea = src[:m.start()].count("\n") + 1
                print("  ojo  %s linea %d: %s -> sera %s?" % (rel, linea, cls, cerca[0]))
    if problemas:
        print("\n%d Instance.new con clase inventada. En Studio truenan y dejan la"
              " interfaz a medias." % problemas)
        return 1
    print("OK    todos los Instance.new usan clases de Roblox (%d clases en la lista)"
          % len(validas))
    return 0


if __name__ == "__main__":
    sys.exit(main())
