#!/usr/bin/env python3
"""Contrato cliente/servidor.

Dos comprobaciones que nacen del bug mas caro de la v28:

  1. REMOTES: todo remote que el CLIENTE pide tiene que existir en el SERVIDOR.
     El cliente pide con 'need(Remotes, "X")' (o WaitForChild / FindFirstChild) y
     el servidor los crea con mkEvent/mkFunc en Main.luau. Si el cliente pide uno
     que el servidor no crea, la UI se queda sin esa funcion... y si el usuario
     tiene un Main.luau viejo pegado, dice "faltan remotes" y no sabe que pegar.

  2. VERSIONES: GameConfig.Build, MI_VERSION de ClientUI y el numero del ultimo
     CAMBIOS-vN.md tienen que coincidir (mas README y CONTINUACION). Esto es lo
     que evita que el usuario corra 5 archivos de rondas distintas.

Uso:  python3 tools/remotes.py
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

MAIN = os.path.join(ROOT, "ServerScriptService/Main.luau")
CLIENT = os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau")
CFG = os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau")
README = os.path.join(ROOT, "README.md")
CONT = os.path.join(ROOT, "CONTINUACION.md")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def server_remotes(src):
    """Nombres creados por el servidor. Se ignora lo comentado."""
    out = {}
    for m in re.finditer(r'^[^\-\n]*mk(?:Event|Func)\(\s*"([^"]+)"', src, re.M):
        line = src[src.rfind("\n", 0, m.start()) + 1:m.start()]
        if "--" in line:            # la creacion esta comentada
            continue
        out[m.group(1)] = src[:m.start()].count("\n") + 1
    return out


def client_remotes(src):
    """Nombres que pide el cliente, con la linea donde los pide."""
    out = {}
    pats = [
        r'need\(\s*Remotes\s*,\s*"([^"]+)"',
        r'Remotes:WaitForChild\(\s*"([^"]+)"',
        r'Remotes:FindFirstChild\(\s*"([^"]+)"',
    ]
    for pat in pats:
        for m in re.finditer(pat, src):
            line = src[src.rfind("\n", 0, m.start()) + 1:m.start()]
            if "--" in line:
                continue
            out.setdefault(m.group(1), src[:m.start()].count("\n") + 1)
    return out


def build_of(src, pattern, what, path):
    m = re.search(pattern, src)
    if not m:
        return None
    return m.group(1)


def main():
    errores = []
    main_src = read(MAIN)
    cli_src = read(CLIENT)

    # ---------- 1. remotes ----------
    srv = server_remotes(main_src)
    cli = client_remotes(cli_src)

    print("=== CONTRATO CLIENTE/SERVIDOR ===")
    print("  servidor crea %d remotes (Main.luau)" % len(srv))
    print("  cliente pide %d remotes (ClientUI.luau)" % len(cli))

    faltan = sorted(set(cli) - set(srv))
    sobran = sorted(set(srv) - set(cli))
    if faltan:
        print("  FALLA  el cliente pide remotes que el servidor NO crea:")
        for n in faltan:
            print("           %s  (ClientUI linea %d)" % (n, cli[n]))
        errores.append("remotes: faltan %s" % ", ".join(faltan))
    else:
        print("  OK     el servidor crea todos los remotes que el cliente pide")
    if sobran:
        print("  nota   el servidor crea y nadie pide: %s" % ", ".join(sobran))

    # ---------- 2. versiones ----------
    v_cfg = build_of(read(CFG), r'GameConfig\.Build\s*=\s*"([^"]+)"', "GameConfig", CFG)
    v_cli = build_of(cli_src, r'local\s+MI_VERSION\s*=\s*"([^"]+)"', "ClientUI", CLIENT)
    v_doc = build_of(read(README), r'Versión actual:\s*\**\s*(v\d+)', "README", README)
    v_cont = build_of(read(CONT), r'Última actualización:\s*\**\s*(v\d+)', "CONTINUACION", CONT)

    docs = sorted(
        [f for f in os.listdir(ROOT) if re.fullmatch(r"CAMBIOS-v(\d+)\.md", f)],
        key=lambda f: int(re.search(r"\d+", f).group()),
    )
    v_last = docs[-1][:-3] if docs else None      # "CAMBIOS-v28.md" -> "CAMBIOS-v28"

    # ---------- 3. sello de ronda en los 5 archivos ----------
    # El sello es la linea "RONDA: vNN" que va ARRIBA de cada archivo: sirve para
    # que el usuario sepa CUAL copia conservar cuando tiene duplicados en Studio
    # (busca con Ctrl+F). Si un archivo se queda sin sello, esta prueba chilla.
    print("\n=== SELLO DE RONDA EN LOS 5 ARCHIVOS ===")
    ARCHIVOS = [
        ("GameConfig", CFG), ("CityGenerator", os.path.join(ROOT, "ServerScriptService/CityGenerator.luau")),
        ("DataService", os.path.join(ROOT, "ServerScriptService/DataService.luau")),
        ("Main", MAIN), ("ClientUI", CLIENT),
    ]
    if v_last is None:
        print("  FALLA  no hay CAMBIOS-vN.md, no se puede saber la ronda")
        errores.append("sin ronda para el sello")
    else:
        esperado = "v" + re.search(r"\d+", v_last).group()
        for nombre, ruta in ARCHIVOS:
            cabeza = "\n".join(read(ruta).splitlines()[:6])
            tiene = ("RONDA: " + esperado) in cabeza
            print("  %s %-14s %s" % ("OK    " if tiene else "FALLA ", nombre,
                                     "sello 'RONDA: %s'" % esperado if tiene
                                     else "SIN sello de la ronda (debe decir 'RONDA: %s')" % esperado))
            if not tiene:
                errores.append("%s no tiene el sello 'RONDA: %s' arriba" % (nombre, esperado))

    def show(etiqueta, valor, esperado):
        marca = "OK    " if valor == esperado else "FALLA "
        print("  %s %-28s %s" % (marca, etiqueta, valor))
        if valor != esperado:
            errores.append("%s dice %s y la ronda es %s" % (etiqueta, valor, esperado))

    if v_last is None:
        print("  FALLA  no hay ningun CAMBIOS-vN.md en la raiz")
        errores.append("no hay CAMBIOS-vN.md")
    else:
        esperado = "v" + re.search(r"\d+", v_last).group()
        print("\n=== VERSIONES ===")
        print("  ronda (ultimo %s): %s" % (v_last + ".md", esperado))
        show("GameConfig.Build", v_cfg, esperado)
        show("ClientUI MI_VERSION", v_cli, esperado)
        show("README version", v_doc, esperado)
        show("CONTINUACION version", v_cont, esperado)
        print("  (estos son los numeros que ve el jugador si los archivos son de otra ronda)")

    print()
    if errores:
        print("FALLA")
        for e in errores:
            print("  - " + e)
        print("  pega las versiones de la ronda en TODOS los archivos antes de entregar")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
