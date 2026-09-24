#!/usr/bin/env python3
"""Arma UN solo archivo HTML con los 5 codigos adentro, listos para copiar.

Por que existe: los links de GitHub NO se pueden abrir desde la previsualizacion
del navegador del usuario (el visor trabaja aislado, sin internet), asi que al
picarle no pasa nada. Este HTML trae el codigo EMBEBIDO (no pide nada a la red)
y con un boton que copia el archivo completo al portapapeles.

Uso:
    python3 tools/pegar.py [salida.html]

Por defecto escribe 'pegar-vNN.html' junto al repo (un nivel arriba), asi no se
duplica el codigo dentro del propio repositorio.
"""
import html
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

# (titulo de la pestana, archivo, donde va en Studio, tipo de objeto)
FILES = [
    ("0. LIMPIADOR (Command Bar)", "tools/limpiar.luau",
     "NO va en el juego: Command Bar (View > Command Bar, SIN dar Play)", "pegar y Enter"),
    ("1. GameConfig", "ReplicatedStorage/GameConfig.luau",
     "ReplicatedStorage  >  GameConfig", "ModuleScript"),
    ("2. CityGenerator", "ServerScriptService/CityGenerator.luau",
     "ServerScriptService  >  CityGenerator", "ModuleScript"),
    ("3. DataService", "ServerScriptService/DataService.luau",
     "ServerScriptService  >  DataService", "ModuleScript"),
    ("4. Main", "ServerScriptService/Main.luau",
     "ServerScriptService  >  Main", "Script  (NO ModuleScript)"),
    ("5. ClientUI", "StarterPlayerScripts/ClientUI.luau",
     "StarterPlayer  >  StarterPlayerScripts  >  ClientUI", "LocalScript"),
]


def version():
    cfg = open(os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau"), encoding="utf-8").read()
    m = re.search(r'GameConfig\.Build\s*=\s*"([^"]+)"', cfg)
    return m.group(1) if m else "v?"


CSS = """
*{box-sizing:border-box}
body{margin:0;background:#0d0d12;color:#e8e8f0;
  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;
  font-size:16px;line-height:1.45;-webkit-text-size-adjust:100%}
header{position:sticky;top:0;z-index:20;background:#15151d;border-bottom:2px solid #f5c45c;
  padding:10px 12px 8px}
h1{margin:0 0 4px;font-size:19px;color:#f5c45c}
header p{margin:3px 0;font-size:13px;color:#a9a9bd}
.pasos{display:flex;gap:6px;flex-wrap:wrap;margin-top:6px}
.paso{background:#22222e;border:1px solid #33334a;border-radius:8px;padding:4px 8px;font-size:12px}
.destacado{background:#3a2a12;border:1px solid #f5c45c;border-radius:8px;padding:7px 9px;
  font-size:13px;color:#ffe6b3;margin:8px 0 2px}
/* Sin JS: se ven los 5 archivos uno tras otro (nada se pierde).
   Con JS: se convierte en pestanas, que es mas comodo en el telefono. */
.tabs{display:none;position:sticky;top:74px;z-index:19;gap:6px;overflow-x:auto;
  background:#0d0d12;padding:8px 12px;border-bottom:1px solid #26263a}
body.js .tabs{display:flex}
.panel{display:block;padding:12px}
body.js .panel{display:none}
body.js .panel.activo{display:block}
.tab{flex:0 0 auto;background:#1e1e2a;border:1px solid #33334a;color:#d8d8e8;
  border-radius:999px;padding:9px 14px;font-size:14px;font-weight:600;cursor:pointer}
.tab.activo{background:#f5c45c;color:#1a1408;border-color:#f5c45c}
.destino{background:#16261c;border:1px solid #2f5c3d;border-radius:10px;padding:10px 12px;margin-bottom:10px}
.destino b{color:#8ce8a8;font-size:15px}
.destino div{font-size:13px;color:#b6d8c2;margin-top:3px}
.barra{display:flex;gap:8px;align-items:center;margin-bottom:8px;flex-wrap:wrap}
.copiar{flex:1;min-width:210px;background:#2f9e5b;color:#fff;border:0;border-radius:10px;
  padding:15px 18px;font-size:17px;font-weight:700;cursor:pointer}
.copiar:active{background:#25804a}
.info{font-size:12px;color:#8a8aa0}
pre{margin:0;background:#13131c;border:1px solid #2a2a3e;border-radius:10px;padding:10px;
  overflow:auto;white-space:pre;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;
  font-size:11.5px;line-height:1.35;max-height:60vh;user-select:text;-webkit-user-select:text}
.aviso{position:fixed;left:50%;bottom:16px;transform:translateX(-50%);background:#f5c45c;color:#1a1408;
  padding:12px 16px;border-radius:10px;font-weight:700;font-size:14px;max-width:92vw;text-align:center;
  opacity:0;pointer-events:none;transition:opacity .2s;z-index:40}
.aviso.ver{opacity:1}
footer{padding:14px 12px 40px;font-size:13px;color:#8a8aa0}
a{color:#f5c45c}
code{background:#1e1e2a;padding:1px 5px;border-radius:5px;font-size:13px}
"""

JS = """
var actual = 0;
function activar(){
  document.body.className = 'js';
  mostrar(0);
}
function mostrar(i){
  for (var k=0;k<5;k++){
    document.getElementById('tab-'+k).className = 'tab' + (k===i ? ' activo' : '');
    document.getElementById('panel-'+k).className = 'panel' + (k===i ? ' activo' : '');
  }
  actual = i;
  window.scrollTo({top:0,behavior:'smooth'});
}
function aviso(txt){
  var a = document.getElementById('aviso');
  a.textContent = txt; a.className = 'aviso ver';
  clearTimeout(a._t); a._t = setTimeout(function(){ a.className='aviso'; }, 2600);
}
function seleccionar(pre){
  try{
    var r = document.createRange(); r.selectNodeContents(pre);
    var s = window.getSelection(); s.removeAllRanges(); s.addRange(r);
    return true;
  }catch(e){ return false; }
}
function copiar(i){
  var pre = document.getElementById('src-'+i);
  var txt = pre.innerText;
  // 1) portapapeles moderno
  if (navigator.clipboard && navigator.clipboard.writeText){
    navigator.clipboard.writeText(txt).then(function(){
      aviso('\\u2705 Copiado ' + txt.length + ' caracteres. Ahora pega en Studio.');
    }).catch(function(){ copiarRespaldo(pre, txt); });
    return;
  }
  copiarRespaldo(pre, txt);
}
function copiarRespaldo(pre, txt){
  // 2) metodo clasico
  seleccionar(pre);
  var ok = false;
  try{ ok = document.execCommand('copy'); }catch(e){ ok = false; }
  if (ok){ aviso('\\u2705 Copiado ' + txt.length + ' caracteres.'); return; }
  // 3) si el navegador bloquea el copiado (pasa dentro de vistas aisladas):
  //    dejamos el texto YA seleccionado para que toques "Copiar" o Ctrl+C
  aviso('\\uD83D\\uDC49 Ya quedo seleccionado todo: toca Copiar (o Ctrl+C).');
}
"""


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(ROOT), "pegar-%s.html" % version())
    ver = version()

    tabs, paneles = [], []
    for i, (titulo, rel, destino, tipo) in enumerate(FILES):
        src = open(os.path.join(ROOT, rel), encoding="utf-8").read()
        kb = len(src.encode("utf-8")) / 1024.0
        lineas = src.count("\n") + 1
        tabs.append('<button id="tab-%d" class="tab%s" onclick="mostrar(%d)">%s</button>'
                    % (i, " activo" if i == 0 else "", i, html.escape(titulo)))
        paneles.append(
            '<section id="panel-%d" class="panel%s">'
            '<div class="destino"><b>Se pega en: %s</b><div>Tipo de objeto: %s'
            ' &nbsp;|&nbsp; %s &nbsp;|&nbsp; %d lineas</div></div>'
            '<div class="barra">'
            '<button class="copiar" onclick="copiar(%d)">&#128203; COPIAR TODO %s</button>'
            '<span class="info">si no copia, se selecciona solo: toca Copiar / Ctrl+C</span>'
            '</div>'
            '<pre id="src-%d">%s</pre>'
            '</section>'
            % (i, " activo" if i == 0 else "", html.escape(destino), html.escape(tipo),
               rel, lineas, i, html.escape(FILES[i][0].split(". ")[1]), i,
               html.escape(src)))

    doc = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>IMPERIO DE ESPECIAS %(ver)s - archivos para copiar</title>
<style>%(css)s</style>
</head>
<body>
<header>
  <h1>&#127798;&#65039; IMPERIO DE ESPECIAS %(ver)s</h1>
  <div class="pasos">
    <span class="paso">1&#65039;&#8419; elige la pestana</span>
    <span class="paso">2&#65039;&#8419; COPIAR TODO</span>
    <span class="paso">3&#65039;&#8419; en Studio: Ctrl+A y Ctrl+V</span>
  </div>
  <p class="destacado">&#129529; <b>&iquest;Te sale el cartel de COPIAS PEGADAS o "faltan remotes"?</b>
  Empieza por la pestana <b>0. LIMPIADOR</b>: se pega en la <b>Command Bar</b> de Studio
  (View &gt; Command Bar, <b>sin</b> dar Play) y borra las copias solo.</p>
  <p>&#9888;&#65039; Pega SIEMPRE <b>encima</b> del script que ya existe (nunca "Insert Object" con el mismo
  nombre: eso crea copias y sale todo doble).</p>
</header>
<nav class="tabs">%(tabs)s</nav>
<main>%(paneles)s</main>
<div id="aviso" class="aviso"></div>
<footer>
  Todo el codigo viaja DENTRO de este archivo (no pide nada a internet).
  Si tu navegador bloquea el copiado, el boton deja el texto ya seleccionado:
  solo toca <b>Copiar</b> o <b>Ctrl+C</b>.<br><br>
  Respaldo: <code>github.com/Agus-12/GAME_ROBLOX_IMPERIO_DE_ESPECIES</code>
  (abre el archivo y usa el boton de copiar de GitHub).
</footer>
<script>%(js)s
try{ document.body.className='js'; mostrar(0); }catch(e){ document.body.className=''; }
</script>
</body>
</html>
""" % {"ver": ver, "css": CSS, "js": JS, "tabs": "".join(tabs), "paneles": "".join(paneles)}

    with open(out, "w", encoding="utf-8") as f:
        f.write(doc)
    print("listo: %s  (%.0f KB)" % (out, len(doc.encode("utf-8")) / 1024.0))


if __name__ == "__main__":
    main()
