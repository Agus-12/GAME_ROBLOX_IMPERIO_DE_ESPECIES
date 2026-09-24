#!/usr/bin/env python3
"""Lista los GLOBALES que toca cada script. Sirve para cazar typos como
   'Workspace' (que en Roblox no existe; el global es 'workspace')."""
import subprocess, tempfile, sys, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
from check import strip_luau
LUAC = os.path.join(HERE, "lua/usr/bin/luac5.4")

# globales que SI existen en Roblox (o en Lua)
OK = {
 "game","workspace","script","shared","require","print","warn","error","assert",
 "pcall","xpcall","select","type","typeof","tostring","tonumber","ipairs","pairs",
 "next","unpack","rawget","rawset","rawequal","rawlen","setmetatable","getmetatable",
 "table","string","math","os","coroutine","utf8","task","tick","wait","spawn","delay",
 "Instance","Vector2","Vector3","Vector2int16","Vector3int16","CFrame","Color3",
 "ColorSequence","ColorSequenceKeypoint","NumberSequence","NumberSequenceKeypoint",
 "NumberRange","UDim","UDim2","Rect","Region3","Ray","RaycastParams","BrickColor",
 "PhysicalProperties","TweenInfo","Enum","Random","Faces","Axes","DateTime","buffer",
 "_G","_VERSION","gcinfo","newproxy","loadstring","collectgarbage","string",
}

bad = 0
for f in sys.argv[1:]:
    src = strip_luau(open(os.path.join(ROOT, f)).read()).replace("continue","goto cont")
    t = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False); t.write(src); t.close()
    r = subprocess.run([LUAC, "-l", "-l", "-p", t.name], capture_output=True, text=True)
    if r.returncode != 0 and "no visible label" in r.stderr:
        src2 = src.replace("goto cont", "_SKIP=true")
        t2 = tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False); t2.write(src2); t2.close()
        r = subprocess.run([LUAC, "-l", "-l", "-p", t2.name], capture_output=True, text=True)
        os.unlink(t2.name)
    os.unlink(t.name)
    if r.returncode != 0:
        print("  no se pudo compilar", f); continue
    names = set(re.findall(r'_ENV "([A-Za-z_]\w*)"', r.stdout))
    susp = sorted(n for n in names if n not in OK)
    print(f"\n{f}")
    if susp:
        for n in susp:
            print(f"   ⚠️  {n}")
        bad = 1
    else:
        print("   sin globales sospechosos")
sys.exit(bad)
