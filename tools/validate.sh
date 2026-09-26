#!/usr/bin/env bash
# Validacion completa. Corre esto ANTES de dar por buena cualquier ronda.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
cd "$ROOT"
bash tools/setup.sh
echo "=== 1. SINTAXIS ==="
python3 tools/check.py \
  ReplicatedStorage/GameConfig.luau \
  ServerScriptService/CityGenerator.luau \
  ServerScriptService/DataService.luau \
  ServerScriptService/Main.luau \
  StarterPlayerScripts/ClientUI.luau
echo "=== 2. SERVIDOR EN RUNTIME ==="
python3 tools/runmain.py
echo "=== 3. CLIENTE EN RUNTIME ==="
python3 tools/runclient.py
echo "=== 4. GLOBALES SOSPECHOSOS ==="
python3 tools/globals.py \
  ReplicatedStorage/GameConfig.luau \
  ServerScriptService/CityGenerator.luau \
  ServerScriptService/DataService.luau \
  ServerScriptService/Main.luau \
  StarterPlayerScripts/ClientUI.luau
echo "=== 5. PARTES DE LA BODEGA ==="
python3 tools/parts.py
echo "=== 6. CAMPOS DE GameConfig ==="
python3 tools/fields.py
echo "=== 7. SE PUEDE CAMINAR A TODO? ==="
python3 tools/walk.py
echo "=== 8. API DE ROBLOX (enums/clases) ==="
python3 tools/api.py || true
echo "=== 9. CONTRATO CLIENTE/SERVIDOR (remotes y versiones) ==="
python3 tools/remotes.py
echo "=== 10. LA PORTADA ABRE RAPIDO? (no trabarse en 'cargando la ciudad') ==="
python3 tools/intro.py
echo "=== 11. NADIE BORRA DENTRO DEL BUCLE (se salta elementos) ==="
python3 tools/loops.py
echo "=== 12. CARPETAS REMOTES DE MAS (el caso real del usuario) ==="
python3 tools/copias.py
echo "=== 13. CLASES DE ROBLOX (nada de Instance.new con nombres inventados) ==="
python3 tools/clases.py
echo "=== 15. LOTES SIN DUENO: bodega clausurada con oficiales ==="
python3 tools/vecinos.py
echo "=== 16. HUD: columna ordenada, estrellas de busqueda y boton Auto ==="
python3 tools/hud42.py
echo "=== 17. BICICLETA Y AUTO DEL GARAJE (bici que rueda, auto que sale) ==="
python3 tools/vehiculos42.py
echo "=== 19. LOS REPORTES DE LAS CAPTURAS (calles y rotulos) ==="
python3 tools/reportes44.py
echo "=== 21. LA NOCHE: LUCES, PORTON, LETREROS, EL MERCADO Y LA VAN (v46) ==="
python3 tools/reportes46.py
echo "=== 18. EL DOCK DE CELULAR (los botones responden al toque) ==="
python3 tools/dock43.py
echo "=== 14. LA PAGINA DE COPIAR: cada pestana muestra su archivo ==="
if command -v node >/dev/null 2>&1; then
  python3 tools/pegar.py /tmp/pagina-pestanas.html && node tools/pestanas.js /tmp/pagina-pestanas.html
else
  echo "  (sin node: se brinca esta etapa)"
fi
