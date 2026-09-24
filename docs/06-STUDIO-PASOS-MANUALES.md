# 🖱️ Pasos manuales en Studio

Cosas que **no se pueden hacer desde un script** y el usuario tiene que hacer a mano.

## 1. Iluminación (Unified Lighting)

`Lighting.Technology` ya no existe; ahora es `LightingStyle`, y es **solo lectura desde
scripts**.

1. Selecciona **Lighting** en el Explorer
2. En Properties, filtra por `style`
3. `LightingStyle` = **Realistic**
4. También pon `PrioritizeLightingQuality` = **true**

**Si no aparece la propiedad:** File → Beta Features → activa **Unified Lighting**
(y opcionalmente desactiva "Auto-Enable Upcoming Features"). Reinicia Studio.

**Si el juego se ve distinto que en Studio:** Studio Settings → Rendering → General →
Graphics Mode → **Direct3D11**. Con OpenGL se rompe. Reinicia.

### Equivalencias
| Antes | Ahora |
|---|---|
| Future | Realistic |
| ShadowMap | Soft (con sombras) |
| Voxel | Soft (sin sombras) |

## 2. Probar en celular

**Dentro de Studio:** pestaña **TEST** → **Device** → elige un modelo → Play.

**En el celular de verdad:**
1. File → **Publish to Roblox As...**
2. Entra a create.roblox.com y ajusta la privacidad
3. Abre la app de Roblox con la **misma cuenta**
4. Perfil → Creaciones → ahí está

⚠️ Cada cambio requiere **volver a publicar**.

## 3. DataStores

Para que el guardado funcione en Studio:
Game Settings → Security → **Enable Studio Access to API Services**.

Sin esto el juego corre igual pero no guarda (el código ya lo maneja con `pcall`).
