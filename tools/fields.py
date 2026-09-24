#!/usr/bin/env python3
"""Auditoria de CAMPOS de GameConfig.

Nacio porque en la v22 se quito 'StorageBonus' de WarehouseTiers pero tres
lugares lo seguian leyendo (Main y ClientUI). En Lua eso NO truena al compilar:
devuelve nil, y si el nil cae dentro de string.format o de una suma, revienta
en TIEMPO DE EJECUCION, en el servidor o en el cliente. El sintoma tipico es
"la computadora no me abre" / "la pestana sale vacia" y no hay error visible.

Que hace:
  1. Carga GameConfig de verdad (bajo el mock) y saca el ESQUEMA: que campos
     tiene cada tabla y cada entrada de lista.
  2. Escanea los consumidores (Main, ClientUI, CityGenerator, DataService)
     buscando TODOS los accesos 'Config.algo.campo' y los alias que salen de
     bucles ('for _, b in ipairs(Config.Carry.Backpacks)' -> 'b' es una mochila).
  3. Reporta cualquier campo que el codigo lea y que la config NO tenga.
"""
import subprocess, tempfile, sys, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")

CONSUMERS = [
    "ServerScriptService/Main.luau",
    "ServerScriptService/CityGenerator.luau",
    "ServerScriptService/DataService.luau",
    "StarterPlayerScripts/ClientUI.luau",
]

# ======================================================================
# 1. ESQUEMA REAL DE LA CONFIG
# ======================================================================
DUMP = r'''
dofile("__MOCK__")
local CFG=(function() __CFG__ end)()
local out={}
local function isTable(v) return type(v)=="table" end
local function walk(path, t, depth)
  if depth>4 or not isTable(t) then return end
  local keys={}
  for k,v in pairs(t) do
    if type(k)=="string" or type(k)=="number" then
      table.insert(keys, tostring(k))
      if isTable(v) and not (v.X or v.R or v.p) then
        walk(path.."."..tostring(k), v, depth+1)
      end
    end
  end
  table.sort(keys)
  out[#out+1]=path.."\t"..table.concat(keys,",")
end
walk("ROOT", CFG, 0)
local f=io.open("__OUT__","w")
for _,line in ipairs(out) do f:write(line,"\n") end
f:close()
print("esquema listo")
'''

def schema():
    cfg = strip_luau(open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau")).read())
    h = DUMP.replace("__MOCK__", os.path.join(HERE, "mock.lua")) \
            .replace("__CFG__", cfg).replace("__OUT__", "/tmp/schema.tsv")
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False); t.write(h); t.close()
    r = subprocess.run([LUA, t.name], capture_output=True, text=True, timeout=120)
    os.unlink(t.name)
    if r.returncode != 0:
        sys.exit("no se pudo sacar el esquema: " + r.stderr[-400:])
    tree = {}
    for line in open("/tmp/schema.tsv"):
        path, keys = line.rstrip("\n").split("\t", 1)
        tree[path] = set(keys.split(",")) if keys else set()
    return tree

def children(tree, path):
    """Subtablas directas de una ruta: {'2': {...}, 'Leaf': {...}}"""
    pref = path + "."
    out = {}
    for k, v in tree.items():
        if k.startswith(pref):
            rest = k[len(pref):]
            if "." not in rest:
                out[rest] = v
    return out

def fieldset(tree, path):
    """Campos validos de una ruta.

    - Si es un MAPA devuelve sus llaves (Config.Carry -> BaseCapacity, ...).
    - Si es una LISTA (llaves numericas) devuelve la UNION de las entradas,
      para que T.VaultLeaves valide contra WarehouseTiers[1..4].
    """
    keys = tree.get(path)
    sub = children(tree, path)
    if keys is None and not sub:
        return set()
    if keys and not all(k.isdigit() for k in keys):
        return set(keys)
    out = set()
    for k, v in sub.items():
        if k.isdigit() or k in (keys or ()):   # entradas de la lista
            out |= v
    if keys and not out:
        return set(keys)
    return out

# ======================================================================
# 2. AGREGAR ALIAS
# ======================================================================
# Cualquier variable que se ligue a un subarbol de la config cuenta como alias.
#   local T = Config.WarehouseTiers[cur]        -> T   = ROOT.WarehouseTiers
#   for _, b in ipairs(Config.Carry.Backpacks)  -> b   = ROOT.Carry.Backpacks
#   local def = Config.Sounds and Config.Sounds[key] (dinamico, se ignora)
ALIAS_ASSIGN = re.compile(r"local\s+(\w+)\s*=\s*Config\.([A-Za-z_][\w.]*)")
ALIAS_LOOP   = re.compile(r"for\s+[^,]+,\s*(\w+)\s+in\s+ipairs\s*\(\s*Config\.([A-Za-z_][\w.]*)\s*\)")

# Cualquier linea que REBINDE un nombre (local, parametro, for) cierra el
# alcance del alias anterior. Sin esto, un 'b' de mochila y un 'b' de boton
# del mismo archivo se mezclan y salen falsos positivos.
REBIND = [
    re.compile(r"\blocal\s+(\w+)\s*="),
    re.compile(r"\blocal\s+function\s+(\w+)"),
    re.compile(r"\bfunction\s+[\w.:]*?(\w+)\s*\("),
    re.compile(r"\bfor\s+([^=\n]+?)\s+in\b"),
    re.compile(r"\blocal\s+function\s+\w+\s*\(([^)]*)\)"),
    re.compile(r"\bfunction\s*[\w.:]*\s*\(([^)]*)\)"),
]

def aliases(src):
    """Eventos por nombre: [(linea, ruta|None)] en orden.

    None = el nombre se reuso para otra cosa (un boton, un frame...) y ya no
    se puede auditar contra la config.
    """
    ev = {}   # name -> lista de (linea, path o None)
    def add(line, name, path):
        ev.setdefault(name, []).append((line, path))

    for m in ALIAS_ASSIGN.finditer(src):
        # 'local def = Config.Sounds and Config.Sounds.Talk': el alias apunta a
        # la ULTIMA ruta de la linea, no a la primera.
        line = src[m.start():src.find("\n", m.start())]
        found = list(re.finditer(r"Config\.([A-Za-z_][\w.]*)", line))
        path = "ROOT." + (found[-1].group(1) if found else m.group(2))
        # 'Config.Buyers[i]': el alias es UNA ENTRADA de la tabla, asi que se
        # valida contra la union de las entradas.
        entry = "[" in line[line.rfind("Config"):]
        add(line_of(src, m.start()), m.group(1), path + (".__entry__" if entry else ""))
    for m in ALIAS_LOOP.finditer(src):
        add(line_of(src, m.start()), m.group(1), "ROOT." + m.group(2) + ".__entry__")
    # la misma linea que declara un alias ('local T = Config...') tambien
    # rebindea el nombre: no hay que marcar None ahi.
    is_alias = set()
    for nm, lst in ev.items():
        for ln, path in lst:
            if path:
                is_alias.add((ln, nm))
    for rx in REBIND:
        for m in rx.finditer(src):
            ln = line_of(src, m.start())
            for nm in re.split(r"[,\s]+", m.group(1).strip()):
                nm = nm.split(":")[0].rstrip("?")      # 'info: any' -> 'info'
                if re.fullmatch(r"\w+", nm) and (ln, nm) not in is_alias:
                    add(ln, nm, None)
    for k in ev:
        ev[k].sort(key=lambda t: t[0])
    return ev

def path_at(ev, name, line):
    """Ruta vigente de 'name' en esa linea (None si ya no es un alias)."""
    best = None
    for ln, p in ev.get(name, ()):
        if ln <= line:
            best = (ln, p)
        else:
            break
    return best[1] if best else None

def fieldset_of_alias(tree, path):
    """Campos validos de un alias. '__entry__' = union de las entradas."""
    if path.endswith(".__entry__"):
        base = path[:-len(".__entry__")]
        out = set()
        for k, v in children(tree, base).items():
            out |= v
        return out or fieldset(tree, base)
    return fieldset(tree, path)

# ======================================================================
# 3. ACCESOS
# ======================================================================
SEG = re.compile(r"([A-Za-z_]\w*)(\[[^\]]*\])?")
CFG_ACCESS = re.compile(
    r"\b(?:Config|CFG)\.([A-Za-z_]\w*(?:\[[^\]]*\])?(?:\.[A-Za-z_]\w*(?:\[[^\]]*\])?)*)")

def line_of(src, pos):
    return src.count("\n", 0, pos) + 1

def strip_comments(src):
    """Quita comentarios SIN perder lineas (los numeros de linea se reportan).

    Sin esto el auditor se queja de los comentarios que MENCIONAN un campo
    viejo, que es justo lo que uno escribe al explicar el arreglo.
    """
    src = re.sub(r"--\[\[.*?\]\]", lambda m: "\n" * m.group(0).count("\n"), src, flags=re.S)
    out = []
    for line in src.split("\n"):
        idx, i, instr = -1, 0, None
        while i < len(line):
            ch = line[i]
            if instr:
                if ch == "\\":
                    i += 2
                    continue
                if ch == instr:
                    instr = None
            elif ch in "\"'":
                instr = ch
            elif ch == "-" and line[i:i + 2] == "--":
                idx = i
                break
            i += 1
        out.append(line[:idx] if idx >= 0 else line)
    return "\n".join(out)

def audit(path, tree):
    src = strip_comments(open(os.path.join(ROOT, path)).read())
    als = aliases(src)
    bad = []

    # --- Config.campo, Config.lista[i].campo, Config.campo.lista[i].campo ---
    for m in CFG_ACCESS.finditer(src):
        segs = [(mm.group(1), mm.group(2) is not None) for mm in SEG.finditer(m.group(1))]
        cur, entry, why = "ROOT", False, None
        for name, hasidx in segs:
            fs = fieldset_of_alias(tree, cur + ".__entry__") if entry else fieldset(tree, cur)
            if name not in fs:
                why = "%s no tiene el campo '%s'" % (
                    cur.replace("ROOT.", "Config.").replace(".__entry__", "[...]"), name)
                break
            cur = cur + "." + name
            entry = hasidx
        if why:
            bad.append((line_of(src, m.start()), m.group(0), why))

    # --- alias.campo (T.VaultLeaves, b.Capacity, ...) ---
    for name in als:
        for m in re.finditer(r"\b%s\.([A-Za-z_]\w*)" % re.escape(name), src):
            ln = line_of(src, m.start())
            path = path_at(als, name, ln)
            if not path:
                continue      # el nombre ya es otra cosa aqui
            valid = fieldset_of_alias(tree, path)
            if not valid:
                continue
            field = m.group(1)
            if field not in valid:
                hint = ", ".join(sorted(valid))[:120]
                bad.append((ln, name + "." + field,
                            "'%s' no tiene ese campo (si: %s)" % (
                                path.replace("ROOT.", "").replace(".__entry__", ""), hint)))
    return bad

if __name__ == "__main__":
    if not os.path.exists(LUA):
        sys.exit("Falta Lua. Corre primero:  bash tools/setup.sh")
    tree = schema()
    total = 0
    for f in CONSUMERS:
        bad = audit(f, tree)
        print("\n%s" % f)
        if not bad:
            print("   todos los campos que lee existen en GameConfig")
        for ln, what, why in bad:
            print("   ⚠️  linea %d: %s  ->  %s" % (ln, what, why))
            total += 1
    print()
    if total:
        print("FALLO: %d campos fantasma" % total)
    else:
        print("OK")
    sys.exit(1 if total else 0)
