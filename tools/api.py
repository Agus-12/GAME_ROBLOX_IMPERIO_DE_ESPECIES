#!/usr/bin/env python3
"""Contrasta el codigo contra el API REAL de Roblox.

El mock del simulador se traga CUALQUIER cosa: si escribes
Enum.Material.PlasticoDeMierda o Instance.new("Parte"), el mock lo acepta y
el error solo aparece al darle Play en Studio, en ingles y sin decirte en
que linea. Este validador revisa:

  1. Enum.X.Y            -> el enum y el item existen
  2. Instance.new("C")   -> la clase existe
  3. :GetService("S")    -> el servicio existe
  4. tablas de props de los helpers (part{...}, frame{...}, label{...})
     -> cada propiedad existe en esa clase (o en alguna clase, si es Gui)

Necesita el API-Dump.json (7 MB). Si no hay red, avisa y se salta: no es
motivo para bloquear la entrega.
"""
import json, os, re, sys, subprocess, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau

FILES = [
    "ReplicatedStorage/GameConfig.luau",
    "ServerScriptService/CityGenerator.luau",
    "ServerScriptService/DataService.luau",
    "ServerScriptService/Main.luau",
    "StarterPlayerScripts/ClientUI.luau",
]
DUMP_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/API-Dump.json"
CACHE = "/tmp/roblox-API-Dump.json"

# Helpers de UI -> clase que construyen (para revisar sus props)
HELPERS = {"part": "Part", "frame": "Frame", "label": "TextLabel",
           "button": "TextButton", "pc": "Part", "gw": "Part", "furn": "Part",
           "couchPart": "Part", "owall": "Part", "wall": "Part"}


def load_dump():
    if not os.path.exists(CACHE):
        try:
            print("   (descargando API-Dump.json ...)")
            urllib.request.urlretrieve(DUMP_URL, CACHE)
        except Exception as e:
            print("   !! sin API-Dump.json y sin red: %s" % e)
            return None
    with open(CACHE) as f:
        return json.load(f)


def build_index(dump):
    classes = {}
    enums = {}
    for c in dump["Classes"]:
        props = set()
        mem = {}
        for m in c["Members"]:
            mem[m["Name"]] = m["MemberType"]
            if m["MemberType"] in ("Property", "Function", "Event", "Callback"):
                props.add(m["Name"])
        classes[c["Name"]] = {"super": c.get("Superclass"), "own": props, "mem": mem}
    for e in dump["Enums"]:
        enums[e["Name"]] = {i["Name"] for i in e["Items"]}
    return classes, enums


def all_props(classes, name):
    """Propiedades propias + heredadas."""
    out, seen = set(), set()
    while name and name not in seen:
        seen.add(name)
        c = classes.get(name)
        if not c:
            break
        out |= c["own"]
        name = c["super"]
    return out


def main():
    dump = load_dump()
    if dump is None:
        print("   (saltado)")
        return 0
    classes, enums = build_index(dump)
    any_prop = set()
    for c in classes.values():
        any_prop |= c["own"]

    bad = 0
    for f in FILES:
        src = strip_luau(open(os.path.join(ROOT, f)).read())
        lines = src.split("\n")
        problems = []

        for i, line in enumerate(lines, 1):
            # 1) Enums
            for m in re.finditer(r"Enum\.(\w+)\.(\w+)", line):
                en, it = m.group(1), m.group(2)
                if en not in enums:
                    problems.append((i, m.group(0), "ese Enum no existe"))
                elif it not in enums[en]:
                    near = [x for x in enums[en] if x.lower() == it.lower()]
                    problems.append((i, m.group(0),
                                     "no existe (¿%s?)" % near[0] if near else "el enum %s no tiene ese item" % en))
            # 2) Instance.new / 3) GetService
            for m in re.finditer(r'Instance\.new\(\s*"(\w+)"', line):
                if m.group(1) not in classes:
                    problems.append((i, m.group(0) + ")", "esa clase no existe"))
            for m in re.finditer(r'GetService\(\s*"(\w+)"', line):
                if m.group(1) not in classes:
                    problems.append((i, m.group(0) + ")", "ese servicio no existe"))
            for m in re.finditer(r'(?:IsA|FindFirstChildOfClass|FindFirstChildWhichIsA)\(\s*"(\w+)"', line):
                if m.group(1) not in classes:
                    problems.append((i, m.group(0) + ")", "esa clase no existe"))

        # 4) props de los helpers: se juntan las lineas hasta cerrar la llave
        for hname, cls in HELPERS.items():
            for m in re.finditer(r"\b%s\(\s*(?:[^,{{}}()]+,)?\s*\{" % re.escape(hname), src):
                depth, j = 0, m.end() - 1
                while j < len(src):
                    if src[j] == "{":
                        depth += 1
                    elif src[j] == "}":
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                block = src[m.end():j]
                starts = src.count("\n", 0, m.start())
                valid = all_props(classes, cls)
                for k in re.finditer(r"([A-Z]\w*)\s*=", block):
                    prop = k.group(1)
                    if prop in valid:
                        continue
                    if prop in any_prop:
                        continue          # existe en otra clase: no es typo claro
                    ln = starts + block.count("\n", 0, k.start()) + 1
                    problems.append((ln, hname + "{" + prop + "}", "no es propiedad de " + cls))

        print("\n%s" % f)
        if not problems:
            print("   enums, clases y props: todo existe en el API de Roblox")
        for ln, what, why in sorted(set(problems)):
            print("   ⚠️  linea %d: %s  ->  %s" % (ln, what, why))
            bad += 1
    print()
    if bad:
        print("FALLO: %d referencias al API que no existen" % bad)
    else:
        print("OK")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
