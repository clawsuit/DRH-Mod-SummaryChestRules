# Summary Chest Rules

Keeps or discards the four chests of the victory summary according to their rarity, without pressing
KEEP/DROP four times.

<!-- drh:show -->
**No usa tecla.** Se configura desde el hub (`F1`) → **Cofres del resumen** → **OPCIONES**.
El hub arranca en inglés y el botón **EN/ES** traduce también estas opciones.

- **Activo**: por defecto está apagado; actívalo para que procese los cofres.
- **Guardar RARO / LEGENDARIO / POCO COMÚN / COMÚN**: cada rareza se guarda o se descarta.
- **Guardar item boxes**: las cajas de objetos pequeñas y royal.
- **Si no hay hueco**: pausar y avisar, o descartar.

Al terminar la partida, el mod espera a que el resumen esté listo y va resolviendo los cofres uno a
uno con las mismas llamadas que los botones KEEP y DROP. No abre los cofres: solo decide si entran al
inventario o se descartan. El contenido lo sigue decidiendo el servidor.

Si el inventario de cofres está lleno, la regla **Si no hay hueco** decide. Un cambio de opciones
reanuda el procesamiento si estaba pausado.
<!-- /drh:show -->

## Ojo con otras automatizaciones

Si otro mod también recoge los cofres del resumen, no uses las dos automatizaciones a la vez sobre la
misma partida: deja una apagada mientras la otra esté activa.

## Dependencia

Necesita **Mod Hub API** (`mod_hub_api`). No necesita el panel del hub para funcionar, pero sin él no
hay forma de cambiar las opciones desde el juego (quedan las de `settings.json`).

## Datos

`settings.json` y `last.log` viven en `data/summary_chest_rules/`.

## Licencia

MIT. Ver `LICENSE`.
