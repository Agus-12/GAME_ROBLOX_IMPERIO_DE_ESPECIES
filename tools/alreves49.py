#!/usr/bin/env python3
"""LA PRUEBA AL REVES DE LA v49.

Regla dura del proyecto: "los chequeos se prueban metiendo el bug". Si un chequeo
pasa con el bug puesto, ese chequeo no sirve. Aqui se mete, UNO POR UNO, cada uno
de los problemas que reporto el usuario en esta ronda y se corre la etapa 24
(tools/reportes49.py): tiene que TRONAR cada vez. Al final se deja todo igual.

    python3 tools/alreves49.py
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
CITY = os.path.join(ROOT, "ServerScriptService/CityGenerator.luau")
MAIN = os.path.join(ROOT, "ServerScriptService/Main.luau")
GC = os.path.join(ROOT, "ReplicatedStorage/GameConfig.luau")
UI = os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau")

BUGS = [
    ("1. la letra chiquita (el rotulo pintado en la cara ANGOSTA de la placa, "
     "como estaba antes: 'TALLER' de 0.8 studs)",
     CITY,
     """		local sz = parte.Size
		if sz.Z * sz.Y > sz.X * sz.Y then
			caras = { Enum.NormalId.Left, Enum.NormalId.Right }
		else
			caras = { Enum.NormalId.Back, Enum.NormalId.Front }
		end""",
     """		caras = { Enum.NormalId.Back, Enum.NormalId.Front } -- BUG: cara angosta""",
     "la letra chiquita"),

    ("2. la letra otra vez a TextScaled (lo que hacia el motor por su cuenta, "
     "que es lo que se veia chiquito)",
     CITY,
     "				lbl.TextSize = math.max(8, math.floor(em * (o.pixels or 58)))\n				lbl.TextScaled = false",
     "				lbl.TextSize = 0 -- BUG: sin tamaño medido\n				lbl.TextScaled = true",
     "no tiene TextSize"),

    ("2b. el cartel de la caja fuerte pintado en el CUERPO (la puerta y la rueda lo "
     "tapan: 'el cartel aparece adentro de la caja')",
     CITY,
     """	textoPlano(vaultLabel, "CAJA FUERTE [C]", Color3.fromRGB(130, 255, 190),
		{ pixels = 96, letra = 0.9 })""",
     """	textoPlano(vaultLabel, "CAJA FUERTE [C]", Color3.fromRGB(130, 255, 190),
		{ pixels = 96, letra = 0.9, unaCara = true, face = Enum.NormalId.Back })
	vaultLabel.Size = Vector3.new(6.4, 12.0, 0.3) -- BUG: la pieza tapa su propia cara""",
     "TODAS sus caras pintadas"),

    ("2c. la bici otra vez pegada a la orilla del patio (6 studs: se ve dentro del "
     "terreno)",
     MAIN,
     "		local orilla = (patio.CFrame * CFrame.new(0, 0, patio.Size.Z * 0.5 + 12)).Position",
     "		local orilla = (patio.CFrame * CFrame.new(0, 0, patio.Size.Z * 0.5 + 6)).Position -- BUG",
     "se ve"),

    ("3. el porton cerrado a 10 studs (se abria en cuanto andabas el patio: "
     "el usuario nunca lo veia)",
     GC,
     "	OpenRadius = 7,               -- a que distancia se abre solo el porton",
     "	OpenRadius = 10,              -- BUG: se abre demasiado lejos",
     "se abre a"),

    ("4. sin la franja roja/blanca del porton (una hoja gris sobre un hueco "
     "oscuro: 'sigue sin aparecer el porton')",
     CITY,
     """		for i = 0, 5 do
			local franja = part({
				Name = "DoorStripe",""",
     """		for i = 0, 0 do
			local franja = part({
				Name = "DoorStripeVieja",""",
     "franja de seguridad"),

    ("5. las manchas de aceite otra vez como TUBO parado (los 'palitos negros')",
     CITY,
     "			Size = Vector3.new(0.12, 4.6, 4.6),",
     "			Size = Vector3.new(4.6, 0.12, 4.6), -- BUG: vuelve el palito",
     "palitos negros"),

    ("6. el mercado que no se cierra (volver a atarlo al cruce del garage)",
     UI,
     """		if shop.Visible and currentTab == "autos"
			and not aLaCaja(pisoTaller, 12) then
			shop.Visible = false
		end""",
     """		if false then -- BUG: nunca se cierra solo
			shop.Visible = false
		end""",
     "SIGUE ABIERTO"),
]


def corre_etapa():
    r = subprocess.run([sys.executable, os.path.join(HERE, "reportes49.py")],
                       capture_output=True, text=True, cwd=ROOT, timeout=900)
    return r.returncode, r.stdout + r.stderr


fallas = 0
print("=== AL REVES: cada bug reportado tiene que tronar la etapa 24 ===")
for nombre, archivo, bueno, malo, esperado in BUGS:
    respaldo = "/tmp/alreves49-" + os.path.basename(archivo)
    shutil.copy2(archivo, respaldo)
    try:
        s = open(archivo, encoding="utf-8").read()
        if s.count(bueno) != 1:
            print("  ?? no pude meter el bug '%s': el texto aparece %d veces"
                  % (nombre, s.count(bueno)))
            fallas += 1
            continue
        s = s.replace(bueno, malo)
        if archivo == MAIN and "PointToObjectSpace(basePos)" in s:
            # para reproducir el bug de verdad: tambien se quita la garantia
            # geometrica (que fue el arreglo de la v50)
            s = s.replace("""		if basePos then
			local rel = patio.CFrame:PointToObjectSpace(basePos)
			local minimoZ = patio.Size.Z * 0.5 + 4
			if rel.Z < minimoZ then
				-- esta adentro del patio (o encima de el): se saca a la fuerza
				basePos = (patio.CFrame * CFrame.new(0, 0, minimoZ + 6)).Position
			end
		end""", "		-- BUG: sin la garantia de estar fuera del patio")
        open(archivo, "w", encoding="utf-8").write(s)

        code, salida = corre_etapa()
        linea = ""
        for l in salida.splitlines():
            if "FALLA" in l or "no llego" in l:
                linea = l.strip()
                break
        if code == 0:
            fallas += 1
            print("  MAL    %s -> la etapa paso: NO caza el bug" % nombre)
        elif esperado not in salida:
            fallas += 1
            print("  MAL    %s -> trono, pero por otra cosa (%s)" % (nombre, linea[:90]))
        else:
            print("  OK     %s\n         -> %s" % (nombre, linea[:110]))
    finally:
        shutil.copy2(respaldo, archivo)

print()
if fallas:
    print("FALLA: %d bug(s) que la etapa no caza" % fallas)
else:
    print("OK: los 6 bugs de la ronda v49 tronaban la etapa 24 (los chequeos sirven)")
sys.exit(1 if fallas else 0)
