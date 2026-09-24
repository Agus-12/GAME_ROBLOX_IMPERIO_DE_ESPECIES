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
