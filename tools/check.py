import re,sys,subprocess,tempfile,os
def strip_luau(c):
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
    return c
if __name__=="__main__":
    bad=0
    for f in sys.argv[1:]:
        src=strip_luau(open(f).read())
        t=tempfile.NamedTemporaryFile("w",suffix=".lua",delete=False);t.write(src);t.close()
        r=subprocess.run(["/tmp/lua/usr/bin/luac5.4","-p",t.name],capture_output=True,text=True)
        os.unlink(t.name)
        if r.returncode==0: print("OK   ",f)
        elif "no visible label" in r.stderr: print("OK   ",f," (continue)")
        else: print("FAIL ",f);print("   ",r.stderr.strip()[:400]);bad=1
    sys.exit(bad)
