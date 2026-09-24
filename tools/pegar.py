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
.rescate{margin:0;background:#2a1414;border-bottom:2px solid #ff7a6b}
.rescate summary{cursor:pointer;list-style:none;padding:9px 12px;font-weight:700;
  color:#ffb3a7;font-size:14px}
.rescate summary::-webkit-details-marker{display:none}
.rescate .cuerpo{padding:2px 14px 14px;font-size:14px;color:#f0ded9}
.rescate .cuerpo b{color:#ffd9d1}
.rescate .cuerpo code{background:#1b1b24;padding:1px 5px;border-radius:5px;font-size:13px}
.rescate .cuerpo pre{background:#12121a;border:1px solid #33334a;border-radius:8px;
  padding:8px;overflow-x:auto;font-size:12px;color:#cfe8d4}
.rescate .cuerpo ul{margin:6px 0 6px 18px;padding:0}
.rescate .cuerpo li{margin:2px 0}
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
  // OJO: el numero de paneles NO se escribe a mano. Estaba en 5 y al agregar el
  // PASO 0 (limpiador) quedaron 6 pestañas: al picarle a la ultima (ClientUI) el
  // bucle ocultaba las otras 5 y nunca mostraba la 6 -> PANTALLA EN BLANCO. El
  // usuario no podia copiar el ClientUI y por eso se le quedo viejo. Se cuenta solo.
  var total = document.querySelectorAll('.panel').length;
  for (var k=0;k<total;k++){
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
  <p class="destacado">&#128264; <b>LA PRUEBA DE 10 SEGUNDOS:</b> dale Play. Arriba al centro de la pantalla tiene
  que salir una placa verde <b>"RONDA %(ver)s"</b>, y arriba de donde apareces un letrero
  <b>"SERVIDOR %(ver)s"</b>. Si alguno no sale (o sale otra ronda), ese archivo no se pego:
  toca el boton rojo <b>"PEGUE TODO Y SIGUE IGUAL"</b> aqui abajo (paso a paso).</p>
</header>

<details class="rescate">
  <summary>&#128680; PEGUE TODO Y SIGUE IGUAL (tocalo: explicacion paso a paso)</summary>
  <div class="cuerpo">
    <p><b>Paso 1 &mdash; la prueba de 10 segundos.</b> Dale <b>Play</b> y mira <b>arriba al centro</b>
    de la pantalla: tiene que salir una placa verde con la ronda
    (<b>"RONDA %(ver)s"</b>), y arriba de donde apareces un letrero <b>"SERVIDOR %(ver)s"</b>.</p>
    <ul>
      <li>Sale <b>RONDA %(ver)s&nbsp;&nbsp;OK</b> &rarr; el archivo nuevo SI corre (lo que falte es otro archivo).</li>
      <li>Se queda en <b>(arrancando...)</b> &rarr; la ClientUI corre pero <b>truena</b>: mira el Output (paso 3).</li>
      <li><b>No sale placa</b> &rarr; esa ClientUI <b>no corre</b>: sigue el paso 2.</li>
      <li>Sale <b>otra ronda</b> (v32, v36...) &rarr; estas corriendo un archivo viejo: vuelve a pegar.</li>
    </ul>
    <p><b>Paso 2 &mdash; la ClientUI tiene que ser LocalScript y estar prendida.</b> En el
    Explorer: <code>StarterPlayer &gt; StarterPlayerScripts &gt; ClientUI</code>. Arriba del panel
    de codigo debe decir <b>LocalScript</b> (si dice <b>Script</b>, ese NO corre ahi: borralo y crea
    un LocalScript). Y en Propiedades, <b>Enabled</b> tiene que estar palomeado.</p>
    <p><b>Paso 3 &mdash; mira el Output.</b> Pestana <b>View</b> (de adentro de Studio) &gt; boton
    <b>Output</b>. Ahi el juego escribe un INVENTARIO con la ronda de <b>cada</b> archivo:</p>
    <pre>[SpiceEmpire] ==== INVENTARIO DE ARCHIVOS DEL JUEGO (%(ver)s, al arrancar) ====
[SpiceEmpire]   OK     ReplicatedStorage &gt; GameConfig
[SpiceEmpire]   VIEJO  [v32] StarterPlayer &gt; StarterPlayerScripts &gt; ClientUI  &lt;- pegalo de nuevo
[SpiceEmpire]   COPIA  [%(ver)s] ServerScriptService &gt; Main  &lt;- borra esta
[SpiceEmpire]   BASURA StarterGui &gt; SpiceEmpireUI  &lt;- interfaz guardada en el lugar
[SpiceEmpire]   FALTA  ServerScriptService &gt; DataService  &lt;- pegalo (falta por completo)</pre>
    <p><b>FALTA</b> = pegalo. <b>VIEJO [vNN]</b> = es de otra ronda, pegalo otra vez.
    <b>COPIA</b> = deja uno y borra los demas. <b>BASURA</b> = interfaz guardada dentro del lugar
    (la ronda nueva ya la borra sola).</p>
    <p><b>Paso 4 &mdash; la limpieza.</b> En el Explorer borra cualquier <b>SpiceEmpireUI</b> que
    este dentro de <b>StarterGui</b> (es una interfaz GUARDADA: sale en pantalla en cada Play
    aunque pegues todo). Deja <b>uno solo</b> de cada archivo y <b>una sola</b> carpeta Remotes.</p>
    <p><b>Paso 5 &mdash; si sigue igual.</b> Mandame dos capturas: la de la <b>placa de ronda</b>
    (arriba al centro) y la del <b>Output</b>. Con eso se sabe exactamente que archivo falta.</p>
  </div>
</details>

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

    # ---- SE VERIFICA SOLO ----
    # Paso de verdad: la pagina tuvo un bug donde el JavaScript del cambio de
    # pestaña tenia el numero escrito a mano (5) y, al agregar el PASO 0, quedo
    # una pestaña que NUNCA se mostraba (pantalla en blanco). El usuario no pudo
    # copiar el ClientUI. Ahora la generacion falla si algo no cuadra.
    tabs = len(re.findall(r'<button id="tab-\d+"', doc))
    paneles = len(re.findall(r'<section id="panel-\d+"', doc))
    esperado = len(FILES)
    problemas = []
    if tabs != esperado:
        problemas.append("hay %d pestañas y %d archivos" % (tabs, esperado))
    if paneles != esperado:
        problemas.append("hay %d paneles y %d archivos" % (paneles, esperado))
    if "k<5" in doc or "k < 5" in doc:
        problemas.append("el cambio de pestaña tiene el numero escrito a mano (k<5)")
    if "querySelectorAll('.panel').length" not in doc:
        problemas.append("el cambio de pestaña no cuenta los paneles solo")
    # cada panel tiene que traer su boton de copiar y su codigo
    for i, (titulo, rel, _, _) in enumerate(FILES):
        if ('<section id="panel-%d"' % i) not in doc:
            problemas.append("falta el panel %d (%s)" % (i, titulo))
        if ('onclick="copiar(%d)"' % i) not in doc:
            problemas.append("el panel %d (%s) no tiene boton de copiar" % (i, titulo))
    if problemas:
        print("FALLA  la pagina quedo mal armada:")
        for x in problemas:
            print("   - " + x)
        return 1

    print("listo: %s  (%.0f KB)" % (out, len(doc.encode("utf-8")) / 1024.0))
    print("  verificado: %d archivos = %d pestanas = %d paneles, cada uno con su boton de copiar"
          % (esperado, tabs, paneles))
    return 0


if __name__ == "__main__":
    import sys as _sys
    _sys.exit(main())
