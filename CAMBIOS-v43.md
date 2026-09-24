# Cambios de la ronda v43

> ## 🎯 ESTA RONDA TERMINA EL PEDIDO DEL DASHBOARD EN CELULAR
>
> La v42 arregló casi toda tu lista, pero al revisarla encontré que **una parte
> quedaba a medias**: el cuadro de botones de abajo en el celular.
>
> | Lo que pediste | Cómo estaba en la v42 | Qué hace la v43 |
> |---|---|---|
> | "El dashboard de abajo no funciona en celular" | Ya tenía el botón **Auto**, pero los botones eran **puro texto chiquito** (14) de 112x52 apretados, **sin `Active`** (el toque puede caer en el marco y perderse) | Rejilla de **ICONOS grandes** (78x62), 2 columnas x 3 renglones, con el nombre chiquito abajo de cada icono, y los botones con `Active = true` / `Selectable = false` |
> | "Que se abra el menú al acercarse a la computadora **o a la bodega**" | Solo la computadora lo hacía | La **bodega** también: al llegar al portón se abre la pestaña de **Autos** |
>
> No se le quitó nada a la v42: **esto es encima**. Todo lo de la ronda pasada
> (bici que rueda, auto que sale del garaje, lotes clausurados con oficiales,
> estrellas de búsqueda) sigue igual.

---

## 1. 📱 El dock de celular, ahora de iconos

**El problema real:** en celular los botones medían 112x52 con puro texto a 14 px y
estaban apretados con 6 px de separación. Además **no traían `Active`**: en táctil, si
el toque cae en el marco del cuadro en vez del botón, el tap **se pierde** y parece que
"no funciona". Y con `Selectable` encendido, un control o mando podía seleccionar un
botón sin querer.

**Cómo queda:**

```
┌──────────────┬──────────────┐
│   🌿         │   ⚙️         │      (a la derecha, a media altura:
│  Cosechar    │   Prensar    │       ahí no estorba el joystick de abajo
├──────────────┼──────────────┤       izquierda ni el botón de saltar
│   💰         │   🅿️         │       de abajo derecha)
│   Vender     │   Garaje     │
├──────────────┼──────────────┤
│   🚗         │   🏠         │
│    Auto      │   Bodega     │
└──────────────┴──────────────┘
```

Más: `🛒 Tienda`, `📱 Teléfono`, `⬆️ Mejoras`, `🔐 Caja` (esos salen según el caso).
Cada botón trae **icono arriba y nombre abajo**, y todos llevan `Active = true` y
`Selectable = false`.

## 2. 🏭 La bodega abre el menú sola

Cuando llegas al portón de tu bodega (el mismo lugar que ya abría el portón), se abre
el panel en la pestaña **Autos**, que es lo que vas a querer ahí (sacar o guardar un
vehículo). Igual que la computadora.

**Al salir NO se cierra**: te quedarías sin poder moverte dentro de la lista mientras
estás adentro del garaje. Se cierra con su `X` (o alejándote de la computadora, que
esa sí cierra sola, como siempre).

## 3. 🧪 Cómo se probó (etapa 18, nueva)

Se agregó **`tools/dock43.py`** y es la **etapa 18** de `tools/validate.sh`. Revisa dos
cosas:

1. **En el código:** que `dockBtn` reciba icono, ponga `Active`/`Selectable`, que los
   botones táctiles midan lo suficiente para un dedo y que la bodega abra el menú.
2. **A toques de verdad (lo importante):** arranca la interfaz en el simulador **en modo
   táctil** (`MOCK_TOUCH=1`), **busca los botones en pantalla y les da clic**, y después
   revisa **qué acción le llegó al servidor**. También comprueba que el **Teléfono
   abra su pantalla**.

> Esto antes **no se podía probar**: los remotos no existían en el simulador, así que
> `act()` moría dentro de un `pcall` y un botón roto pasaba las pruebas sin que nadie
> se enterara. Por eso el "no funciona en celular" llegó hasta ti. En esta ronda se
> arregló eso también: ahora el simulador **anota cada acción** que manda el cliente.

**Probado al revés** (metiendo el bug a propósito): se le quitó el icono al botón Auto,
se apagó el `Active` y se desconectó el menú de la bodega. La etapa **cazó los tres**
(`botones del dock sin icono: Auto`, `sin Active: Telefono,Bodega,Auto` y
`al llegar a la BODEGA no se abre el menu`) y volvió a pasar al restaurarlos.

## 4. ✅ Qué deberías ver ahora

1. La placa dice **`RONDA v43  OK`** y el letrero del spawn dice **`SERVIDOR v43`**.
2. En celular: a la derecha, **iconos grandes** con su nombre abajo (Auto, Bodega,
   Teléfono...). Toca `🚗 Auto` y el carro aparece a tu lado.
3. Camina hasta el portón de tu bodega: **se abre el panel solo** en la pestaña Autos.

## 5. 🧷 Lo que se conserva de la v42 (no se tocó)

- Bici: los rines (llanta, aro, maza y rayos) la siguen; `Torque`/`TurnSpeed` ya no en 0;
  en celular te subes al acercarte sin letrero de `E`.
- Garaje por niveles: nivel 1 = un cajón y **un solo auto**; al subir de nivel todo crece.
- Portones: se abre **solo el portón que te toca** (antes se medía a un punto al centro
  y con el garaje grande ese portón no abría nunca).
- Lotes sin dueño: nave clausurada con tablas, cadena, candado, letreros y **oficial
  que te habla al acercarte**.
- HUD: columna ordenada y **estrellas de búsqueda** bajo el reloj.
