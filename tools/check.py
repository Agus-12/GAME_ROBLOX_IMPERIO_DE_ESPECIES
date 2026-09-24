import re,sys,subprocess,tempfile,os
HERE=os.path.dirname(os.path.abspath(__file__))
LUAC=os.path.join(HERE,"lua/usr/bin/luac5.4")
def _ocultar_strings(c):
    """Saca los literales de texto del codigo antes de limpiar tipos.

    POR QUE: los regex de aca abajo buscan cosas como `nombre: Tipo` y varios
    de ellos trabajan sobre CUALQUIER cosa entre parentesis. Un texto normal
    del juego como ("===== LISTO: ahora dale Play =====") se veia igual que una
    lista de parametros y le borraba el ": ahora" -- o sea que el simulador NO
    estaba probando el texto real (y un dia le iba a borrar un pedazo de un
    mensaje que si importa). Ahora los textos se apartan y se devuelven iguales.
    """
    partes = []
    fuera = []
    i = 0
    n = len(c)
    while i < n:
        ch = c[i]
        # comentario: pasa de largo
        if ch == "-" and i + 1 < n and c[i+1] == "-":
            if c[i:i+4] == "--[[":
                j = c.find("]]", i + 4)
                j = n if j < 0 else j + 2
            else:
                j = c.find("\n", i)
                j = n if j < 0 else j
            fuera.append(c[i:j]); i = j; continue
        # texto largo [[ ]]
        if c[i:i+2] == "[[":
            j = c.find("]]", i + 2)
            j = n if j < 0 else j + 2
            partes.append(c[i:j]); fuera.append("\x01%d\x01" % (len(partes) - 1)); i = j; continue
        if ch in "\"'":
            j = i + 1
            while j < n:
                if c[j] == "\\": j += 2; continue
                if c[j] == ch: j += 1; break
                j += 1
            partes.append(c[i:j]); fuera.append("\x01%d\x01" % (len(partes) - 1)); i = j; continue
        fuera.append(ch); i += 1
    return "".join(fuera), partes


def _devolver_strings(c, partes):
    for i, t in enumerate(partes):
        c = c.replace("\x01%d\x01" % i, t)
    return c


def strip_luau(c):
    c, _partes = _ocultar_strings(c)
    c=c.replace("--!strict","")
    c=re.sub(r'^(\s*)export\s+type\s+[^\n]*\n',r'\1\n',c,flags=re.M)
    c=re.sub(r'^(\s*)type\s+\w+\s*=[^\n]*\n',r'\1\n',c,flags=re.M)
    c=re.sub(r'::\s*[A-Za-z_][\w.]*(\s*\?)?(\s*\{[^}]*\})?','',c)
    c=re.sub(r'(local\s+[\w\s,]+?)\s*:\s*\{[^=\n]*?\}\s*=',r'\1 =',c)
    c=re.sub(r'(local\s+\w+)\s*:\s*[A-Za-z_][\w.<>\[\]]*(\s*\?)?\s*=',r'\1 =',c)
    c=re.sub(r'(local\s+\w+)\s*:\s*[A-Za-z_][\w.<>\[\]]*(\s*\?)?\s*$',r'\1',c,flags=re.M)
    c=re.sub(r'\)\s*:\s*\([^)]*\)\s*(?=\n)',')',c)
    c=re.sub(r'\)\s*:\s*\{[^}\n]*\}\s*(?=\n)',')',c)
    c=re.sub(r'\)\s*:\s*[A-Za-z_][\w.<>\[\]]*(\s*\?)?\s*(?=\n)',')',c)
    c=re.sub(r':\s*\([^()]*\)\s*->\s*\([^()]*\)','',c)
    c=re.sub(r':\s*\([^()]*\)\s*->\s*[A-Za-z_][\w.]*','',c)
    def params(m):
        inner=m.group(1)
        inner=re.sub(r'(\w+)\s*:\s*\{[^}]*\}',r'\1',inner)
        inner=re.sub(r'(\w+)\s*:\s*[A-Za-z_][\w.<>\[\]]*(\s*\?)?',r'\1',inner)
        inner=re.sub(r'(\w+)\s*\?',r'\1',inner)
        return "("+inner+")"
    c=re.sub(r'\(([^()]*:[^()]*)\)',params,c)
    TAIL = r'(?=\s*(?:end\b|then\b|do\b|;|$))'
    for op,sym in ((r'\+=','+'),(r'-=','-'),(r'\*=','*')):
        c=re.sub(r'([\w\.\[\]"\']+)\s*'+op+r'\s*([^;\n]+?)'+TAIL,
                 r'\1 = \1 '+sym+r' (\2)',c,flags=re.M)
    c=re.sub(r'\bcontinue\b','goto cont',c)
    return _devolver_strings(c, _partes)
if __name__=="__main__":
    if not os.path.exists(LUAC):
        sys.exit("Falta Lua. Corre primero:  bash tools/setup.sh")
    bad=0
    for f in sys.argv[1:]:
        src=strip_luau(open(f).read())
        t=tempfile.NamedTemporaryFile("w",suffix=".lua",delete=False);t.write(src);t.close()
        r=subprocess.run([LUAC,"-p",t.name],capture_output=True,text=True)
        os.unlink(t.name)
        if r.returncode==0: print("OK   ",f)
        elif "no visible label" in r.stderr: print("OK   ",f," (continue)")
        else: print("FAIL ",f);print("   ",r.stderr.strip()[:400]);bad=1
    sys.exit(bad)
