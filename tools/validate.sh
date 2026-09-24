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
