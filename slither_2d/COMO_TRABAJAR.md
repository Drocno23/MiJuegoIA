# 🛠️ Trabajar con VS Code + Godot por comandos (sin líos de sincronización)

Guía corta y práctica para editar este prototipo desde **VS Code**, abrirlo en
**Godot 4.7** y mantener todo sincronizado con GitHub **usando comandos**.

> 🎯 La idea: **una sola fuente de verdad (GitHub)**, comandos cortos y siempre
> `pull --rebase` antes de empezar. Así nunca hay dos versiones del proyecto
> peleándose.

---

## 0. Resumen del flujo

```
GitHub (rama arena/01a0ef16-mijuegoia)
   │  git pull --rebase        ↑  git push
   ▼                            │
TU PC  ──►  VS Code (editas scripts .gd)  ──►  Godot (editas escenas .tscn / juegas)
                                   │
                            git add -A && git commit -m "..."
```

---

## 1. Instalación (una sola vez por máquina)

```bash
# 1.1 Clona el repositorio (si aún no lo tienes)
git clone https://github.com/Drocno23/MiJuegoIA.git
cd MiJuegoIA

# 1.2 Ponte en la rama del prototipo y trae lo último
git checkout arena/01a0ef16-mijuegoia
git pull --rebase

# 1.3 Instala las extensiones de VS Code desde la terminal
code --install-extension geequlim.godot-tools
code --install-extension EditorConfig.EditorConfig
```

**Abre SIEMPRE la carpeta `slither_2d`, no la raíz del repo:**

```bash
code slither_2d
```

> ⚠️ **¿Por qué `slither_2d` y no la raíz?** Porque en este repositorio hay **dos**
> `project.godot` (el de la raíz y `slither_2d/project.godot`), y la extensión de
> Godot, cuando encuentra varios, se queda con el de la ruta más corta
> (el de la raíz). Resultado: autocompletado y `res://` apuntando al proyecto
> equivocado. Abriendo `slither_2d` no hay ambigüedad posible.
> Git sigue funcionando igual desde la subcarpeta (detecta el repo de arriba).

Después:

1. Abre `.vscode/settings.json` y **cambia la ruta de Godot** a la tuya:
   ```jsonc
   "godotTools.editorPath.godot4": "C:/Godot/Godot_v4.7.2-stable_win64.exe"
   ```
2. En VS Code: **F1 → `Tasks: Run Task` → `Godot: importar recursos (--import)`**
   (o simplemente abre el editor con `Godot: abrir el editor (-e)`).
   Esto genera la carpeta `.godot/` y los archivos `.uid`.

### ⚠️ Los primeros `.uid` hay que subirlos (una sola vez)

Godot 4.4+ crea un archivo `.uid` junto a cada script/escena. **Se deben subir al
repo** (lo dice la propia documentación de Godot: si no, las referencias se
rompen al clonar en otra máquina). Tras el primer `--import` verás archivos
nuevos: es normal y hay que commitearlos.

```bash
git status                 # verás los .uid nuevos
git add -A
git commit -m "chore: agrega archivos .uid generados por Godot 4.7"
git push
```

> `*.uid` **no** debe ir nunca al `.gitignore`. En cambio `.godot/` **sí** está
> ignorada (es caché que Godot regenera sola).

---

## 2. El ciclo diario (5 comandos)

```bash
# 1) Antes de empezar: trae lo último y ponlo debajo de lo tuyo
git pull --rebase

# 2) ... edita en VS Code y/o en Godot ...

# 3) Mira qué has tocado (y en qué rama estás)
git status --short --branch

# 4) Guarda el cambio (si creaste archivos nuevos, antes: git add -A)
git add -A
git commit -m "feat: agrego power-up de velocidad"

# 5) Súbelo
git push
```

En VS Code todo esto está en **F1 → `Tasks: Run Task`** (las tareas
`Git: ...`), así no tienes ni que recordar los argumentos.

Si estoy yo (el agente) subiendo cambios a esta rama, tú solo necesitas el
paso 1: `git pull --rebase`.

---

## 3. Cómo se hablan VS Code y Godot

| Sentido | Qué hacer |
|---|---|
| **Godot → VS Code** (doble clic en un script dentro de Godot) | `Editor → Ajustes del editor → Text Editor → External`: `Use External Editor` ✅, `Exec Path` = `code`, y en el desplegable de `Exec Flags` elige el preset **Visual Studio Code** (`--goto {file}:{line}:{col}`) |
| **VS Code → Godot** (que Godot vea tus cambios al volver) | `Editor → Ajustes del editor → Text Editor → Behavior → Files` → **Auto Reload Scripts on External Change** ✅ |
| Que no se te olvide guardar escenas | `Ajustes del editor → Interface → Editor` → **Save on Focus Loss** ✅ (guarda al cambiar de ventana, justo cuando te vas a VS Code) |
| Que importe recursos nuevos solos | Mismo sitio → **Import Resources When Unfocused** ✅ |
| Autocompletado de GDScript en VS Code | Ya configurado en `.vscode/settings.json` (servidor LSP en el puerto 6005) |

Con esos 3 ajustes, el flujo es: **escribes en VS Code → vuelves a la ventana de
Godot → ya está recargado**. Y si cambias una escena en Godot, se guarda sola al
pasar a VS Code.

---

## 4. ¿Qué se sube y qué no?

| Archivo | ¿Al repo? | Por qué |
|---|---|---|
| `scripts/*.gd`, `escenas/*.tscn`, `project.godot` | ✅ Sí | Es el proyecto |
| `*.gd.uid`, `*.tscn.uid` | ✅ Sí | Referencias de Godot 4.4+ (se rompen si no van) |
| `.vscode/` (settings, tasks, extensions) | ✅ Sí | Así las dos máquinas se comportan igual |
| `.godot/` | ❌ No | Caché de importación, Godot la regenera. Ya está en `.gitignore` |
| `preview/render.py`, `preview/*.png` | ✅ Sí | Documentación visual del prototipo (no los necesita el juego) |
| `export_presets.cfg` | ✅ Sí (si exportas) | Configuración de exportación |

---

## 5. Reglas de oro para no tener conflictos

1. **Una máquina a la vez.** Si editas en dos equipos sin subir/bajar, habrá conflicto.
2. **`git pull --rebase` al empezar y antes de `git push`.** Si olvidas el segundo,
   GitHub rechazará el push (`non-fast-forward`): haz `git pull --rebase` y reintenta.
3. **Commits pequeños y frecuentes** (mejor 5 commits de una cosa que 1 de cinco).
4. **Reparto de tareas**: los scripts `.gd` en VS Code, las escenas `.tscn` en Godot.
   Si tocas un `.tscn` a mano en VS Code, ábrelo después en Godot y guárdalo para
   que quede con el formato del editor.
5. **No toques la carpeta `.godot/`** (ni la copies entre máquinas).
6. Si aparece un conflicto en un `.tscn` (son difíciles de fusionar a mano):
   quédate con una de las dos versiones y rehaz el otro cambio en el editor.
   ```bash
   git checkout --ours   slither_2d/escenas/Main.tscn   # o --theirs
   git add slither_2d/escenas/Main.tscn
   git rebase --continue      # o git merge --continue
   ```

---

## 6. Problemas típicos y solución

| Síntoma | Causa y solución |
|---|---|
| En VS Code no hay autocompletado | 1) La ruta de Godot en `.vscode/settings.json` está mal. 2) Asegúrate con **F1 → `Godot Tools: Start Language Server`** y mira la esquina inferior derecha. 3) Si usas `"godotTools.lsp.headless": false`, el editor de Godot debe estar abierto **antes** que VS Code (o pulsa *Retry*). |
| Godot no ve mis cambios de script | Vuelve a la ventana de Godot (recarga al enfocar). Si no, cierra y reabre el editor. Revisa que tienes `Auto Reload Scripts on External Change` activado. |
| Tras un `pull` Godot se queja de recursos | Ejecuta **F1 → `Tasks: Run Task` → `Godot: importar recursos (--import)`**. |
| `error: failed to push some refs` | Te falta `git pull --rebase` antes de subir. |
| Aparecen archivos nuevos raros (`.uid`, `.godot/`) en `git status` | Los `.uid` se commitean; `.godot/` no debería aparecer (si aparece, revisa el `.gitignore` de la raíz del repo). |
| El juego no arranca desde VS Code | Comprueba la ruta de Godot y ejecuta la tarea `Godot: jugar` (debe decir algo como `Godot Engine v4.7.2.stable`). |
| Aviso `render_target_set_msaa: 2D MSAA is not yet supported for GLES3` | Ya está resuelto: se quitó `msaa_2d` del `project.godot` (ver el README). |

---

## 7. Atajos útiles

| Quiero... | Comando (terminal) | Tarea de VS Code |
|---|---|---|
| Abrir el editor de Godot | `godot -e` (dentro de `slither_2d`) | `Godot: abrir el editor (-e)` |
| Jugar | `godot` | `Godot: jugar` |
| Regenerar `.godot/` | `godot --headless --import` | `Godot: importar recursos (--import)` |
| Ver la rama y los cambios | `git status --short --branch` | `Git: estado` |
| Deshacer cambios de un archivo | `git restore slither_2d/scripts/gusano.gd` | — |
| Ver el historial | `git log --oneline --graph -15` | `Git: historial` |

### Si abres la RAÍZ del repo en VS Code

Es posible, pero entonces la extensión de Godot apuntará al `project.godot` de la
raíz (el proyecto viejo). En ese caso trabaja con la ruta explícita:

```bash
godot --path slither_2d -e      # abrir el editor del prototipo
godot --path slither_2d         # jugar
godot --headless --path slither_2d --import
```

…y para tener autocompletado del proyecto correcto, lo más simple sigue siendo
`code slither_2d`.

---

## 8. Publicar en `main` (cuando quieras)

Esta rama (`arena/01a0ef16-mijuegoia`) es la del trabajo en curso. Cuando esté
lista para pasar a `main`:

```bash
gh pr create --base main --head arena/01a0ef16-mijuegoia \
  --title "Prototipo Slither 2D en Godot 4.7" \
  --body "Prototipo con movimiento, crecimiento, muerte y restos de comida."
```
