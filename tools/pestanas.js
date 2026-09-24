// Prueba REAL de la pagina de copiar: simula el DOM y da clics en cada pestaña.
//
// POR QUE EXISTE
//   La pagina tuvo un bug que dejo al usuario sin poder copiar el ClientUI: el
//   cambio de pestaña tenia el numero de paneles escrito a mano (k<5) y, al
//   agregar el PASO 0 (el limpiador), quedaron 6 pestañas. Al picarle a la
//   ultima, el bucle ocultaba las otras cinco y NUNCA mostraba la sexta:
//   pantalla en blanco, sin ningun error. El usuario le pico y "no salia nada".
//
// QUE HACE
//   Corre el JavaScript de la pagina tal cual viene (no una copia) sobre un DOM
//   de mentiras y comprueba que, al picar cada pestaña, se vea SOLO su panel.
//   Si algo queda oculto o mal marcado, falla.
//
// Uso:  node tools/pestanas.js /tmp/pagina.html
const fs = require("fs");
const ruta = process.argv[2];
if (!ruta) { console.log("uso: node tools/pestanas.js <pagina.html>"); process.exit(2); }

const H = fs.readFileSync(ruta, "utf8");
const js = H.slice(H.lastIndexOf("<script>") + 8, H.lastIndexOf("</script>"));

const nPaneles = (H.match(/<section id="panel-\d+"/g) || []).length;
const nTabs = (H.match(/<button id="tab-\d+"/g) || []).length;
if (nPaneles === 0 || nTabs === 0) {
  console.log("FALLA  la pagina no tiene pestañas o paneles");
  process.exit(1);
}
if (nPaneles !== nTabs) {
  console.log("FALLA  hay " + nTabs + " pestañas y " + nPaneles + " paneles");
  process.exit(1);
}

// --- DOM de mentiras: lo minimo que usa el script de la pagina ---
const nodos = {};
for (let i = 0; i < nPaneles; i++) {
  nodos["panel-" + i] = { className: "panel" };
  nodos["tab-" + i] = { className: "tab" };
  nodos["src-" + i] = { innerText: "x".repeat(50) };
}
nodos["aviso"] = { className: "aviso", textContent: "" };
global.document = {
  body: { className: "" },
  getElementById: (id) => nodos[id] || null,
  querySelectorAll: (sel) => (sel === ".panel"
    ? Object.keys(nodos).filter((k) => k.startsWith("panel-")).map((k) => nodos[k])
    : []),
  createRange: () => ({ selectNodeContents() {} }),
};
global.window = { scrollTo() {}, getSelection: () => ({ removeAllRanges() {}, addRange() {} }) };
global.navigator = {};
global.setTimeout = () => 0;
global.clearTimeout = () => {};

eval(js);   // corre el script de la pagina TAL CUAL

let fallas = 0;
for (let i = 0; i < nPaneles; i++) {
  mostrar(i);
  let ok = true;
  for (let k = 0; k < nPaneles; k++) {
    const visible = nodos["panel-" + k].className.includes("activo");
    if (visible !== (k === i)) {
      console.log("   FALLA  al picar la pestaña " + i + ": el panel " + k + " quedo " +
        (visible ? "VISIBLE" : "oculto") + " y debia estar " + (k === i ? "visible" : "oculto"));
      ok = false;
    }
    if (nodos["tab-" + k].className.includes("activo") !== (k === i)) {
      console.log("   FALLA  la pestaña " + k + " quedo mal marcada al picar la " + i);
      ok = false;
    }
  }
  if (ok) console.log("   OK     pestaña " + i + " -> se ve SOLO el panel " + i);
  else fallas++;
}

if (fallas) {
  console.log("FALLA");
  console.log("  " + fallas + " pestaña(s) no muestran su contenido: el usuario no podria copiar ese archivo");
  process.exit(1);
}
console.log("OK: las " + nPaneles + " pestañas muestran su contenido");
