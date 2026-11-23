# Publicar Summary Chest Rules

Repositorio: <https://github.com/clawsuit/DRH-Mod-SummaryChestRules>
Versión preparada: **0.4.1**

## Antes de etiquetar

- `mod.json` con `version: "0.4.1"`, `api: "1.5"` y `drh: "18"`.
- `README.md` con la zona `<!-- drh:show -->` actualizada.
- `LICENSE` presente.
- `--check-mod` correcto.
- Compilación en staging con `mode: compiled`.

## Con Git

Desde esta carpeta:

```powershell
git add -A
git commit -m "Summary Chest Rules 0.4.1: remove Enabled, harden summary handling"
git tag v0.4.1
git push origin main
git push origin v0.4.1
```

El workflow `Release` compila el zip y deja un **draft release** con el zip y la entrada del índice.

## Publicar el release

Abre el borrador en GitHub y pulsa **Publish release**. No subas un zip hecho a mano: la entrada lleva
el `size` y el `sha256` del zip que generó el workflow.

## Enviar al índice

```powershell
& "C:\Users\iClaw\AppData\Local\DRH Launcher\DRH-Launcher.exe" --submit-mod "C:\Users\iClaw\Documents\DRH-Mod-SummaryChestRules"
```

Abre el navegador para crear el fork la primera vez y luego la página del PR. El CI del índice descarga
el zip del release y comprueba `size`, `sha256` y la entrada.

## Validación local opcional

```powershell
$env:PATH = "C:\Program Files\Git\cmd;" + $env:PATH
& "C:\Users\iClaw\AppData\Local\DRH Launcher\DRH-Launcher.exe" --pack-mod `
  "C:\Users\iClaw\Documents\DRH-Mod-SummaryChestRules" `
  "C:\Users\iClaw\Documents\DrhRelease"
```

Genera `summary_chest_rules-0.4.1.zip` y `summary_chest_rules-0.4.1.json`. El zip que se publica es el
del workflow; el JSON del workflow es el que se envía al índice.