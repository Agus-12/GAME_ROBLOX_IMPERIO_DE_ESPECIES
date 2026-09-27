#!/usr/bin/env python3
"""AL REVES (v51/v52): cada bug de esta ronda tiene que TRONAR la etapa 26.

La regla del proyecto es no confiar en un chequeo que nunca se vio fallar.
Aqui se mete el bug DE VERDAD en el archivo real (Main.luau o CityGenerator.luau),
se corre la etapa 26 y se comprueba que truene; luego se deja todo como estaba.

Bugs que se prueban:
  1. la van sale con la altura fija de antes (2.05): queda 1 stud arriba del piso
     del patio (era "la van al spawnearla afuera sale mal")
  2. el cajon se queda sin su patio (BayApron): la van vuelve a salir sobre el pasto
  3. la calle de hilera donde la ponia la v51 (+71): queda DEBAJO de los patios de
     las bodegas nivel 2-4 ("la bodega de en medio esta como al ras de la calle")
  4. se pierde una rampa de entrada (el bucle se corta antes)
  5. los caminos norte-sur dejan de existir
  6. el camino principal pegado a la linea de lotes (la v51): toca las paredes de
     las bodegas nivel 4, que no estan centradas en su lote
  7. (v53) se quita el re-sellado de HomeCF: el porton del cajon vuelve a
     "cerrarse" hacia las coordenadas del template y se vuela al origen del
     mundo (el "porton que nunca aparece", reportado desde la v44)
  8. (v53) se apaga la adopcion de movimientos externos del bucle de manejo:
     el boton "Auto" vuelve a pelear con el PivotTo y el carro regresa a la
     bodega ("la van con las piezas una arriba de la otra")
  9. (v53) el camino de en medio vuelve a quedarse corto (no toca la ciudad):
     los lotes del lado oriente sin salida directa
  10. (v54) se apaga el corrimiento de la van al nacer: con el jugador parado
     en el patio del cajon (la banda de los 12 studs del boton) le nace encima
     ("la tengo que respawnear dos veces para poder conducirla")
  11. (v54) se quitan el empujon Y el rescate de la bici a la CALLE de su
     hilera: vuelve al pasto de +12, que sigue dentro del rectangulo del
     terreno ("la bici aparece adentro de la bodega"). OJO: hay que matar las
     dos capas — con solo el empujon fuera, el rescate de dentroDeAlgo tambien
     manda a la calle (defensa en profundidad, a proposito)
  12. (v54) se pierde el tercer camino norte-sur (el callejon del oriente):
     la esquina oriente de los lotes vuelve a quedar a ~500 studs del asfalto
     ("las calles de la esquina quedan desconectadas")
  13. (v55) se apaga el Play del motor: la van se arma bien pero al manejarla
     no se oye nada ("le falta sonido al juego")
  14. (v55) la musica ambiente nunca arranca: entras y el mapa esta mudo

NOTA: los casos 1-5 se recuperaron cortados del chat anterior y se conservan
(los textos de ancla de 1, 2, 4 y 5 son los originales). El caso 3 se ajusto a
la v52 (la formula ahora suma +121; el bug lo regresa a +71, que era el error
real de la v51) y el 6 es nuevo de la v52. Los 7, 8 y 9 son de la v53. Los 10, 11 y 12 de la v54. Los 13 y 14 de la v55.
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
MAIN = os.path.join(ROOT, "ServerScriptService/Main.luau")
CITY = os.path.join(ROOT, "ServerScriptService/CityGenerator.luau")
CLIENTE = os.path.join(ROOT, "StarterPlayerScripts/ClientUI.luau")

print("=== AL REVES (v55): cada bug reportado tiene que tronar las etapas ===")

CASOS = [
    ("1. la van sale con la altura fija de antes (queda 1 stud arriba del patio)",
     MAIN,
     "local baseCF = CFrame.new(sp.X, sp.Y + 0.05, sp.Z)",
     "local baseCF = CFrame.new(sp.X, 2.05, sp.Z)",
     None, "caminos51.py"),

    ("2. el cajon se queda sin su patio (la van vuelve a salir sobre el pasto)",
     CITY,
     "Size = Vector3.new(padAncho, 2, padLargo),",
     "Size = Vector3.new(0.2, 2, padLargo),",
     None, "caminos51.py"),

    ("3. la calle de hilera donde la ponia la v51 (+71: debajo de los patios)",
     CITY,
     "return lot.Origin.Z - (r - 1) * lot.SpacingZ + 121",
     "return lot.Origin.Z - (r - 1) * lot.SpacingZ + 71",
     None, "caminos51.py"),

    ("4. se pierde la rampa del ultimo lote de cada hilera",
     CITY,
     "for c = 0, lot.PerRow - 1 do\n\t\t\t\tlocal lx = lot.Origin.X + c * lot.SpacingX",
     "for c = 0, lot.PerRow - 2 do\n\t\t\t\tlocal lx = lot.Origin.X + c * lot.SpacingX",
     None, "caminos51.py"),

    ("5. los caminos norte-sur dejan de existir",
     CITY,
     "buildLotRoads(city)",
     "do end -- BUG DE PRUEBA: sin los caminos de los lotes",
     None, "caminos51.py"),

    ("6. el camino principal pegado a la linea de lotes (toca las bodegas nivel 4)",
     CITY,
     "local principalX = lot.Origin.X + 1.5 * lot.SpacingX - 13.5",
     "local principalX = lot.Origin.X + 1.5 * lot.SpacingX - 0",
     None, "caminos51.py"),

    ("7. sin re-sellar HomeCF: el porton del cajon se vuela al cerrarse",
     MAIN,
     "clone:PivotTo(CFrame.new(warehouseSlotPos(slot)))\n\tresellarHome(clone)",
     "clone:PivotTo(CFrame.new(warehouseSlotPos(slot)))",
     None, "reportes48.py"),

    ("8. el bucle de manejo no adopta movimientos externos (boton Auto roto)",
     MAIN,
     "if (cfb.Position - ultCF.Position).Magnitude > 0.35 then",
     "if false and (cfb.Position - ultCF.Position).Magnitude > 0.35 then",
     None, "reportes48.py"),

    ("9. el camino de en medio no llega a la ciudad (lotes oriente sin salida)",
     CITY,
     'Name = "RoadLotesX2",\n\t\tSize = Vector3.new(ROAD_W, 1, zCiudad - zUltima),',
     'Name = "RoadLotesX2",\n\t\tSize = Vector3.new(ROAD_W, 1, zPrimera - zUltima),',
     None, "caminos51.py"),

    ("10. (v54) sin el corrimiento de la van: le nace encima al jugador del cajon",
     MAIN,
     "baseCF = baseCF + Vector3.new(0, 0, 6)   -- hacia la calle (norte)",
     "do end -- BUG DE PRUEBA: la van no se corre de las figuras",
     "la van le nace encima", "reportes48.py"),

    ("11. (v54) sin el empujon NI el rescate: la bici vuelve al pasto de la orilla",
     MAIN,
     "if zCalle then\n\t\t\tbasePos = Vector3.new(basePos.X, basePos.Y, zCalle)\n\t\tend\n"
     "\t\t-- v54: capa de abajo: si aun quedo dentro de algo (por ejemplo si\n"
     "\t\t-- CalleDeHileraZ no existiera), se manda DIRECTO a la calle — la\n"
     "\t\t-- calle queda 39 studs mas alla de la orilla del rectangulo del\n"
     "\t\t-- lote (lz + 121 contra lz + 82), o sea fuera de todos los\n"
     "\t\t-- terrenos. El buscarLibre de rayos solito no sirve aqui: un pasto\n"
     "\t\t-- DENTRO del rectangulo del lote no tiene techo y los rayos lo\n"
     "\t\t-- ven \"libre\".\n"
     "\t\tif dentroDeAlgo(basePos) then\n"
     "\t\t\tbasePos = Vector3.new(basePos.X, basePos.Y, zCalle or basePos.Z)\n"
     "\t\t\tif dentroDeAlgo(basePos) then\n"
     "\t\t\t\tbasePos = buscarLibre(basePos, Vector3.new(0, 0, 1), basePos.Y) or basePos\n"
     "\t\t\tend\n\t\tend",
     "if zCalle then\n\t\t\tdo end -- BUG DE PRUEBA: sin el empujon a la calle\n\t\tend\n"
     "\t\tdo end -- BUG DE PRUEBA: y sin el rescate de dentroDeAlgo",
     "no nace en la calle de su hilera", "reportes48.py"),

    ("12. (v54) se pierde el callejon del oriente: la esquina de la ciudad queda desconectada",
     CITY,
     'Name = "RoadLotesX3",',
     'Name = "RoadLotesX3OFF",',
     "caminos norte-sur", "caminos51.py"),

    ("13. (v55) nadie le da Play al motor: la van existe pero sigue muda al manejar",
     MAIN,
     "if motor then\n\t\t\tif ocupante then\n\t\t\t\tif not motor.IsPlaying then pcall(function() motor:Play() end) end",
     "if false and motor then\n\t\t\tif ocupante then\n\t\t\t\tif not motor.IsPlaying then pcall(function() motor:Play() end) end",
     "motor NO suena", "sonido55.py"),

    ("14. (v55) la musica ambiente nunca arranca: el mapa entra mudo",
     CLIENTE,
     "m.Looped = true\n\t\t\tm.Parent = game:GetService(\"SoundService\")\n\t\t\tm:Play()",
     "m.Looped = true\n\t\t\tm.Parent = game:GetService(\"SoundService\")\n\t\t\tdo end -- BUG DE PRUEBA: la musica nunca arranca",
     "no esta sonando", "sonido55.py"),
]


def corre_etapa(cual):
    r = subprocess.run([sys.executable, os.path.join(HERE, cual)],
                       capture_output=True, text=True, cwd=ROOT, timeout=900)
    return r.returncode, r.stdout + r.stderr


fallas = 0
for nombre, archivo, bueno, malo, esperado, etapa in CASOS:
    respaldo = "/tmp/alreves51-" + os.path.basename(archivo)
    shutil.copy2(archivo, respaldo)
    try:
        s = open(archivo, encoding="utf-8").read()
        if s.count(bueno) != 1:
            print("  ?? no pude meter el bug '%s': el texto aparece %d veces"
                  % (nombre, s.count(bueno)))
            fallas += 1
            continue
        open(archivo, "w", encoding="utf-8").write(s.replace(bueno, malo))

        code, salida = corre_etapa(etapa)
        linea = ""
        for l in salida.splitlines():
            if "FALLA" in l or l.strip().startswith("- "):
                linea = l.strip()
                if linea.startswith("- "):
                    break
        if code == 0:
            fallas += 1
            print("  MAL    %s -> la etapa paso: NO caza el bug" % nombre)
        elif esperado and esperado not in salida:
            fallas += 1
            print("  MAL    %s -> trono, pero por otra cosa (%s)" % (nombre, linea[:90]))
        else:
            print("  OK     %s\n         -> %s" % (nombre, linea[:110]))
    finally:
        shutil.copy2(respaldo, archivo)

print()
if fallas:
    print("FALLA: %d bug(s) que las etapas no cazan" % fallas)
else:
    print("OK: los 14 bugs de las rondas v51-v55 tronaban las etapas (los chequeos sirven)")
sys.exit(1 if fallas else 0)
