#!/usr/bin/env bash
# Instala Lua 5.4 dentro de tools/lua para poder validar los scripts.
# Solo hay que correrlo una vez por maquina (o cada vez que se limpie /tmp
# si se trabaja en un sandbox efimero).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
# El bit de ejecucion se pierde al restaurar snapshots del workspace,
# asi que lo reponemos siempre antes de decidir si hay que reinstalar.
chmod +x lua/usr/bin/* 2>/dev/null || true
if [ -x "lua/usr/bin/luac5.4" ]; then echo "Lua ya esta instalado."; exit 0; fi
echo "Descargando lua5.4..."
apt-get download lua5.4 >/dev/null 2>&1
dpkg -x lua5.4*.deb "$HERE/lua"
rm -f lua5.4*.deb
echo "Listo: $HERE/lua/usr/bin/lua5.4"
