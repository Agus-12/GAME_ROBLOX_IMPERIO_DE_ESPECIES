#!/usr/bin/env python3
"""Carga ClientUI.luau bajo el mock, en 3 tamanos de pantalla.
   Uso:  python3 tools/runclient.py"""
import subprocess, tempfile, sys, os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau

LUA = os.path.join(HERE, "lua/usr/bin/lua5.4")
if not os.path.exists(LUA):
    sys.exit("Falta Lua. Corre primero:  bash tools/setup.sh")

# GameConfig precompilado para que el mock lo pueda requerir
cfg = strip_luau(open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau")).read())
open(os.path.join(HERE, "cfgload.lua"), "w").write("return (function()\n" + cfg + "\nend)()\n")

src = strip_luau(open(os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau")).read()) \
        .replace("goto cont", "_SKIP=true")
body = ('dofile("%s/mockclient.lua")\nlocal ok,err=pcall(function()\n' % HERE) + src + \
       '\nend)\nprint(ok and "  OK" or ("  !! "..tostring(err)))\n'
t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False); t.write(body); t.close()

CASES = {"ESCRITORIO 1920x1080": (1920,1080,"0"),
         "CELULAR    896x414":   (896,414,"1"),
         "TABLET     1180x820":  (1180,820,"1")}
for name,(w,h,touch) in CASES.items():
    env = dict(os.environ, MOCK_VW=str(w), MOCK_VH=str(h), MOCK_TOUCH=touch, TOOLS=HERE)
    print(name)
    r = subprocess.run([LUA, t.name], capture_output=True, text=True, env=env, timeout=120)
    print(r.stdout.strip() or r.stderr.strip()[:700])
os.unlink(t.name)
