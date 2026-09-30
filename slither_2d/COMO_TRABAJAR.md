# 🛠️ Trabajar con VS Code + Godot en Kali Linux por comandos (sin líos de sincronización)

Guía para editar este prototipo desde **VS Code** (o desde la **terminal de VS
Code**), abrirlo en **Godot 4.7** y mantenerlo sincronizado con GitHub **usando
comandos**.

> 🎯 La idea: **una sola fuente de verdad (GitHub)**, comandos cortos y siempre
> `git pull --rebase` antes de empezar. Así nunca hay dos versiones del proyecto
> peleándose.
> 🐧 Todo está escrito para **Linux (Kali/Debian)**; al final hay notas por si
> algún día lo abres en Windows/macOS.

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

## 1. Instalación en Kali Linux (una sola vez)

### 1.1 Requisitos

Kali ya trae lo necesario, pero por si acaso:

```bash
sudo apt update && sudo apt install -y wget unzip git
whoami && echo "$HOME" && uname -m      # tu usuario, tu carpeta y tu arquitectura
```

Si `uname -m` dice `x86_64` usa el paquete **x86_64**; si dice `aarch64` usa
**arm64** (Kali en Raspberry/ARM).

### 1.2 Descargar Godot 4.7

> ⚠️ El Godot de los repositorios de Kali/Debian suele ser una versión antigua.
> Para este proyecto (etiqueta `4.7` en `project.godot`) usa el binario oficial.

```bash
mkdir -p "$HOME/Godot" && cd "$HOME/Godot"

# x86_64 (lo normal en un PC):
wget https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip

# (solo si tu uname -m dijo aarch64, usa esta en su lugar):
# wget https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.arm64.zip

unzip -o Godot_v4.7.2-stable_linux.x86_64.zip
chmod +x Godot_v4.7.2-stable_linux.x86_64
./Godot_v4.7.2-stable_linux.x86_64 --version     # debe imprimir: 4.7.2.stable.official
```

*(También puedes bajarlo desde https://godotengine.org/download/linux/ — es el
mismo archivo.)*

### 1.3 Ponerlo en el PATH con un symlink (recomendado)

Así el comando se llama siempre `godot`, no tienes que tocar `.zshrc`/`.bashrc`
y **la ruta de VS Code nunca cambia** aunque actualices de versión:

```bash
sudo ln -sf "$HOME/Godot/Godot_v4.7.2-stable_linux.x86_64" /usr/local/bin/godot
godot --version                                  # 4.7.2.stable.official ✅
```

`/usr/local/bin` ya está en el PATH, así que funciona en la terminal de Kali,
en la terminal integrada de VS Code y en las tareas del proyecto.

> ¿Prefieres no usar `sudo`? Entonces copia el binario a `~/.local/bin/` (asegúrate
> de que está en tu PATH) y pon esa ruta completa en `.vscode/settings.json`.

### 1.4 Clonar el repositorio y ponerse en la rama

```bash
git clone https://github.com/Drocno23/MiJuegoIA.git "$HOME/MiJuegoIA"
cd "$HOME/MiJuegoIA"
git checkout arena/01a0ef16-mijuegoia
git pull --rebase
```

### 1.5 Extensiones de VS Code (desde la terminal)

```bash
code --install-extension geequlim.godot-tools
code --install-extension EditorConfig.EditorConfig
```

### 1.6 Abrir la carpeta correcta en VS Code

```bash
code "$HOME/MiJuegoIA/slither_2d"
```

> ⚠️ **Abre `slither_2d`, NO la raíz del repo.** Hay dos `project.godot` (el de
> la raíz y `slither_2d/project.godot`) y la extensión de Godot, cuando encuentra
> varios, se queda con el de la ruta más corta (mira `get_project_dir()` en
> `src/utils/godot_utils.ts` del plugin). Abriendo `slither_2d` no hay ambigüedad.
> Git sigue funcionando igual desde la subcarpeta: detecta el repo de arriba.

Después revisa `.vscode/settings.json`:

```jsonc
"godotTools.editorPath.godot4": "/usr/local/bin/godot"   // ✅ ya configurado así
```

Si usaste otra ruta, cámbiala aquí. **Debe ser una ruta absoluta** (escribir
`godot` a secas no vale) y apuntar a un **Godot 4.x**: la extensión ejecuta el
binario y comprueba la versión; si no coincide te pedirá elegir otro.

### 1.7 Primer arranque y subida de los `.uid`

```bash
code "$HOME/MiJuegoIA/slither_2d"
```
En VS Code: **F1 → `Tasks: Run Task` → `Godot: importar recursos (--import)`**.
Eso genera la carpeta `.godot/` y los archivos `.uid`.

> ⚠️ **Los `.uid` SÍ se suben al repo** (Godot 4.4+): son las referencias del
> proyecto. Si no van al repo, al clonar en otra máquina Godot avisa y puede
> perder referencias. Tras el primer `--import`:

```bash
git status                 # verás los .uid nuevos: es normal
git add -A
git commit -m "chore: agrega archivos .uid generados por Godot 4.7"
git push
```

Y recuerda: `*.uid` **nunca** al `.gitignore`; `.godot/` **sí** está ignorada
(es caché que Godot regenera sola).

---

## 2. Todo desde la terminal de VS Code

Abre la terminal integrada con **Ctrl + `** (la tecla del acento grave, la de
la derecha de la P en teclados en español) o en el menú **Terminal → Nueva
terminal**. Ya se abre **dentro de `slither_2d`** (lo dejé configurado en
`settings.json` con `terminal.integrated.cwd`).

| Cosa | Cómo |
|---|---|
| Cambiar de shell (bash/zsh) | F1 → `Terminal: Select Default Profile` |
| Saber tu shell | `echo $SHELL` |
| Editar tu PATH/aliases | `~/.zshrc` si es zsh, `~/.bashrc` si es bash (`source` el archivo después) |
| Ejecutar las tareas del proyecto | F1 → `Tasks: Run Task` (se ejecutan **en esa misma terminal**) |
| Repetir la última tarea | F1 → `Tasks: Rerun Last Task` |
| Sincronizar y probar todo de golpe | `bash herramientas.sh todo` (tarea `Proyecto: TODO`) |
| Ver los atajos disponibles | `bash herramientas.sh` (tarea `Proyecto: ayuda`) |

> ⚠️ **No abras VS Code como root** (`sudo code`). Los archivos quedarían
> propiedad de root y Git fallaría con `dubious ownership` / permisos.
> Si ya te pasó, se arregla así:
> ```bash
> sudo chown -R "$USER:$USER" "$HOME/MiJuegoIA"
> git config --global --add safe.directory "$HOME/MiJuegoIA"
> ```

---

## 3. El ciclo diario (4 comandos, en la terminal de VS Code)

> 🧭 **Comprueba la rama antes de nada**: `git status --short --branch`. Debe decir
> `## arena/01a0ef16-mijuegoia`. Si dice `## main`, tú no estás en la rama del
> prototipo y no recibirás los cambios: cambia con
> `git checkout arena/01a0ef16-mijuegoia` (una sola vez).
> Los atajos del script hacen esa comprobación por ti: `./herramientas.sh estado`.

```bash
# 1) Antes de empezar: trae lo último y ponlo debajo de lo tuyo
git pull --rebase

# 2) ... edita en VS Code y/o juega/edita escenas en Godot ...

# 3) Mira qué has tocado y en qué rama estás
git status --short --branch

# 4) Guarda y sube
git add -A && git commit -m "feat: agrego power-up de velocidad" && git push
```

Si el paso 1 te da `Tienes cambios sin marcar` (típico tras abrir el proyecto en
Godot: aparecen `.uid` y re-guarda escenas), tienes una salida de un comando:

```bash
./herramientas.sh sync --con-cambios    # aparta tus cambios, hace el pull y los devuelve
```

En VS Code estos pasos están como tareas (`Git: ...`), así no recuerdas los
argumentos. Si estoy yo (el agente) subiendo cambios a esta rama, tú solo
necesitas el paso 1: `git pull --rebase`.

---

## 4. Cómo se hablan VS Code y Godot

| Sentido | Qué hacer |
|---|---|
| **Godot → VS Code** (doble clic en un script dentro de Godot) | `Editor → Ajustes del editor → Text Editor → External`: `Use External Editor` ✅, `Exec Path` = `code`, y en el desplegable de `Exec Flags` elige el preset **Visual Studio Code** (`--goto {file}:{line}:{col}`) |
| **VS Code → Godot** (que Godot vea tus cambios al volver) | `Editor → Ajustes del editor → Text Editor → Behavior → Files` → **Auto Reload Scripts on External Change** ✅ |
| Que no se te olvide guardar escenas | `Ajustes del editor → Interface → Editor` → **Save on Focus Loss** ✅ (guarda al cambiar de ventana, justo cuando te vas a VS Code) |
| Que importe recursos nuevos | Mismo sitio → **Import Resources When Unfocused** ✅ |
| Autocompletado de GDScript | Ya configurado en `.vscode/settings.json` (LSP en el puerto 6005, modo headless) |

Con eso el flujo es: **escribes en VS Code → vuelves a la ventana de Godot → ya
está recargado**. Y si cambias una escena en Godot, se guarda sola al pasar a VS Code.

### Godot en español

* Interfaz: `Ajustes del editor → Interface → Editor → Language` → **Español**.
* O arráncalo con el idioma forzado (tarea `Godot: abrir el editor en español`):
  ```bash
  godot -l es -e
  ```
* Los mensajes de error de GDScript salen en inglés; eso no se traduce.

---

## 5. ¿Qué se sube y qué no?

| Archivo | ¿Al repo? | Por qué |
|---|---|---|
| `scripts/*.gd`, `escenas/*.tscn`, `project.godot` | ✅ Sí | Es el proyecto |
| `*.gd.uid`, `*.tscn.uid` | ✅ Sí | Referencias de Godot 4.4+ (se rompen si no van) |
| `.vscode/` (settings, tasks, extensions) | ✅ Sí | Así las dos máquinas se comportan igual |
| `.godot/` | ❌ No | Caché de importación, Godot la regenera. Ya está en `.gitignore` |
| `tests/` (escena + script de prueba) | ✅ Sí | Prueba automática de las mecánicas: útil para todos |
| `herramientas.sh` | ✅ Sí | Atajos de terminal para este proyecto (Linux) |
| `preview/render.py`, `preview/*.png` | ✅ Sí | Documentación visual (el juego no los necesita) |
| `export_presets.cfg` | ✅ Sí (si exportas) | Configuración de exportación |

---

## 6. Reglas de oro para no tener conflictos

1. **Una máquina a la vez.** Si editas en dos equipos sin subir/bajar, habrá conflicto.
2. **`git pull --rebase` al empezar y antes de `git push`.** Si olvidas el segundo,
   GitHub rechaza el push (`non-fast-forward`). Con `./herramientas.sh subir` ya no
   tienes que preocuparte: si el push es rechazado, hace el `pull --rebase` y
   reintenta automáticamente. A mano sería `git pull --rebase && git push`.
3. **Commits pequeños y frecuentes** (mejor 5 commits de una cosa que 1 de cinco).
4. **Reparto de tareas**: los `.gd` en VS Code, los `.tscn` en Godot. Si tocas un
   `.tscn` a mano en VS Code, ábrelo después en Godot y guárdalo para que quede
   con el formato del editor.
5. **No toques la carpeta `.godot/`** (ni la copies entre máquinas).
6. Si hay conflicto en un `.tscn` (difíciles de fusionar a mano): quédate con una
   versión y rehaz el otro cambio en el editor.
   ```bash
   git checkout --ours   slither_2d/escenas/Main.tscn   # o --theirs
   git add slither_2d/escenas/Main.tscn
   git rebase --continue      # o git merge --continue
   ```

---

## 7. Problemas típicos (y solución)

| Síntoma | Causa y solución |
|---|---|
| VS Code pide elegir el ejecutable de Godot, o avisa de *"wrong version"* | La ruta no apunta a un Godot 4.x. Comprueba con la tarea `Godot: comprobar versión` (debe decir `4.7.x`) o con `godot --version`. |
| En VS Code no hay autocompletado | 1) Ruta mal en `.vscode/settings.json`. 2) F1 → `Godot Tools: Restart Language Server`. 3) En la barra inferior derecha verás el estado del LSP. |
| Godot no ve mis cambios de script | Vuelve a la ventana de Godot (recarga al enfocar). Revisa `Auto Reload Scripts on External Change`. |
| `godot: command not found` en la terminal integrada | Falta el symlink (o `~/.local/bin` no está en el PATH). Rehaz §1.3 y **reinicia VS Code** para que herede el PATH nuevo. |
| Warnings de `inotify` / "too many open files" / Godot vigilando demasiados archivos | Sube el límite de Kali (y reinicia sesión): `echo fs.inotify.max_user_watches=524288 \| sudo tee -a /etc/sysctl.conf && sudo sysctl -p`. También ayuda que `.godot/` esté excluida del vigilante (ya está en `settings.json`). |
| El juego no abre ventana (o sale en negro) | Comprueba driver/pantalla: `godot --rendering-driver opengl3` y, si usas Wayland, `godot --display-driver wayland` (con X11, `--display-driver x11`). El proyecto ya usa *GL Compatibility*, el más compatible. |
| `git: dubious ownership` o permisos raros | Abriste VS Code como root. Solución en §2 (`chown` + `safe.directory`). |
| `error: no se puede pull con rebase: Tienes cambios sin marcar` | Godot ha creado o re-guardado archivos (`.uid`, `.import`, `.tscn`, `project.godot`) y Git no deja hacer el pull. El script lo detecta y te da 3 salidas:<br>• **`.uid` / `.import` (recomendado)**: súbelos una vez, así dejan de estorbar para siempre → `./herramientas.sh subir "chore: archivos de Godot"`<br>• **Apartarlos y recuperarlos**: `./herramientas.sh sync --con-cambios` (o `./herramientas.sh todo --con-cambios` para el ciclo completo)<br>• **Descartarlos** (solo si son re-guardados, se regeneran solos): `git checkout -- . && git clean -fd` |
| `bash: [herramientas.sh](http://herramientas.sh): No existe el fichero o el directorio` | No es un error de Linux: el nombre del archivo se convirtió en un **enlace de chat** al copiarlo. Escribe el comando a mano, sin corchetes ni paréntesis: `./herramientas.sh todo` |
| Errores en el EDITOR de Godot o en VS Code que la prueba ya no da | Son **errores viejos en caché**: el editor guarda los scripts parseados y la lista de clases globales en `.godot/`. Solución: cierra y vuelve a abrir el editor de Godot (`Proyecto → Recargar proyecto actual`) y, en VS Code, `F1 → Godot Tools: Restart Language Server`. Si sigue igual: `rm -rf .godot && ./herramientas.sh importar`. Fíjate en la prueba automática: si su comprobación 0 dice que los 8 scripts cargan, tu código está bien. |
| `Cannot infer the type of "X" variable because the value doesn't have a set type` | GDScript no puede deducir el tipo: pasa al recorrer listas sin tipar (`for x in [-1.0, 1.0]`). Solución: tipar la colección (`PackedFloat32Array([-1.0, 1.0])`) o anotar la variable (`var ojo: Vector2 = ...`). |
| `ERROR: Can't change this state while flushing queries. Use call_deferred() or set_deferred() to change monitoring state instead.` | Se creó un nodo con forma de colisión (un segmento, una comida) **dentro** de un callback de física, como la señal `area_entered` al comer. Solución: crearlos en diferido (`crecer_diferido()` en `gusano.gd`, `_esparcir_restos.call_deferred()` en `main.gd`). Ya está resuelto; si reaparece al añadir código nuevo, usa el mismo patrón. |
| `SCRIPT ERROR: Parse Error: Cannot find member "X" in base "Y"` | **Error real de GDScript**: ese método no existe en ese tipo (nos pasó con `push_front` en un `PackedVector2Array`, que solo tiene `insert`). No es un problema de tu instalación: hay que corregir el script. La prueba automática lo detecta en la comprobación 0 (antes incluso de montar el mundo). |
| `ERROR: RID allocations ... were leaked at exit` | Aviso al cerrar: quedaban nodos vivos al salir. La prueba ya libera el mundo antes de terminar, así que no debería aparecer. |
| Commiteé en `main` en vez de en la rama del prototipo | No pasa nada, el commit está a salvo. Lo que subiste a `main` se puede traer a la rama de trabajo con `git checkout main -- <archivo>` (así trajimos los `.uid`). Para seguir con lo actualizado, cámbiate de rama: `git fetch origin && git checkout arena/01a0ef16-mijuegoia && git pull --rebase`. Antes de commitear, mira siempre la rama: `git status --short --branch` |
| `error: failed to push some refs` | Te falta `git pull --rebase` antes de subir. |
| Aparecen `.uid` o `.godot/` nuevos en `git status` | Los `.uid` se commitean; `.godot/` no debería aparecer (si aparece, revisa el `.gitignore`). |
| Tras un `pull` Godot se queja de recursos | Tarea `Godot: importar recursos (--import)`. |
| Aviso `render_target_set_msaa: 2D MSAA is not yet supported for GLES3` | Ya está resuelto (se quitó `msaa_2d` del `project.godot`; ver el README). |

---

## 8. Atajos y utilidades en Linux

```bash
# Abrir el editor del prototipo desde cualquier carpeta
godot --path "$HOME/MiJuegoIA/slither_2d" -e

# Jugar directamente
godot --path "$HOME/MiJuegoIA/slither_2d"

# Regenerar .godot/ y .uid sin abrir ventana
godot --headless --path "$HOME/MiJuegoIA/slither_2d" --import

# Ver qué versión tienes y dónde está
godot --version && which godot && ls -l "$(which godot)"

# Aliases cómodos (añádelos a ~/.zshrc o ~/.bashrc)
echo 'alias slither="godot --path $HOME/MiJuegoIA/slither_2d"'          >> ~/.zshrc
echo 'alias slither-edit="godot --path $HOME/MiJuegoIA/slither_2d" -e"' >> ~/.zshrc
source ~/.zshrc
```

| Quiero... | Comando | Tarea de VS Code |
|---|---|---|
| Ver rama y cambios | `git status --short --branch` | `Git: estado` |
| Deshacer cambios de un archivo | `git restore slither_2d/scripts/gusano.gd` | — |
| Historial | `git log --oneline --graph -15` | `Git: historial` |
| Traer / subir | `git pull --rebase` / `git push` | `Git: traer cambios` / `Git: subir` |
| Sincronizar + probar todo | `bash herramientas.sh todo` | `Proyecto: TODO` |
| Probar las mecánicas | `godot --headless res://tests/PruebaMecanicas.tscn` | `Probar: mecánicas (headless)` |
| Subir con un mensaje | `bash herramientas.sh subir "mensaje"` | `Proyecto: subir cambios` |

### Si abres la RAÍZ del repo en VS Code

Funciona, pero la extensión de Godot apuntará al `project.godot` de la raíz. Usa
la ruta explícita con `--path` (ver arriba). Para tener autocompletado del
proyecto correcto, lo simple sigue siendo `code "$HOME/MiJuegoIA/slither_2d"`.

### Notas para Windows / macOS (por si algún día cambias de equipo)

* Windows: `godotTools.editorPath.godot4` = `"C:/Godot/Godot_v4.7.2-stable_win64.exe"`.
* macOS: `"/Applications/Godot.app/Contents/MacOS/Godot"`.
* Todo lo demás de esta guía (Git, tareas, `.uid`) es idéntico.

---

## 9. Sincronizar y comprobar que todo está bien

### 9.0 Versión corta: el script `herramientas.sh` (recomendado)

Todo lo de esta sección en **un solo comando**, desde la terminal integrada de
VS Code:

```bash
./herramientas.sh todo           # sincroniza + importa + prueba (código 0 = todo bien)
```

> 📍 **Funciona desde cualquier carpeta del repo**: hay un lanzador en la raíz
> (`MiJuegoIA/herramientas.sh`) que llama al de `slither_2d/`. Así el mismo
> comando vale estés en `~/Proyectos/MiJuegoIA` o en `~/Proyectos/MiJuegoIA/slither_2d`.
> Si `./` te da pereza, `bash herramientas.sh todo` hace lo mismo (ojo: sin
> corchetes; si al copiar de un chat te aparece `[herramientas.sh](...)`, es un
> enlace y bash no lo entiende).

Y el resto de atajos:

| Comando | Qué hace |
|---|---|
| `./herramientas.sh todo` | `git pull --rebase` + `--import` + prueba (14 comprobaciones) |
| `./herramientas.sh todo --con-cambios` | Lo mismo, apartando antes los cambios sin guardar |
| `./herramientas.sh sync` | Traer lo último de GitHub (se niega si hay cambios sin guardar y te da 3 opciones) |
| `./herramientas.sh sync --con-cambios` | Lo mismo, pero apartando tus cambios con `git stash -u` y devolviéndolos después (perfecto para los `.uid` y los re-guardados de Godot) |
| `./herramientas.sh probar` | Prueba automática (también a mano: `godot --headless res://tests/PruebaMecanicas.tscn`) |
| `./herramientas.sh importar` | Genera `.godot/` y los `.uid` sin abrir ventana |
| `./herramientas.sh jugar` | Ejecuta el juego |
| `./herramientas.sh editar` | Abre el editor de Godot |
| `./herramientas.sh estado` | Rama, cambios pendientes y versión de Godot |
| `./herramientas.sh subir "mensaje"` | `git add -A` + commit + push |
| `./herramientas.sh` | Ayuda |

También están como tareas de VS Code (F1 → `Tasks: Run Task`), en el grupo
**`Proyecto: ...`**. Si Godot no está en el PATH:
`GODOT=/ruta/a/godot ./herramientas.sh probar`.

### 9.1 Traer lo último y verificar

```bash
cd ~/MiJuegoIA
git pull --rebase

git status --short --branch     # debe empezar por "## arena/01a0ef16-mijuegoia" y no listar nada más
git log --oneline -8            # aquí debe salir el último commit del agente
```

Si `git status` te muestra archivos `.gd.uid` nuevos, es normal (los genera
Godot): súbelos una vez con `git add -A && git commit -m "chore: .uid" && git push`.

### 9.2 Prueba automática de las mecánicas (1 comando)

```bash
cd ~/MiJuegoIA/slither_2d
godot --headless res://tests/PruebaMecanicas.tscn
echo "código de salida: $?"      # 0 = todo bien | 1 = hay fallos
```

Salida esperada (resumen):

```
===============================================================
  PRUEBA AUTOMÁTICA — slither_2d
  Godot 4.7.2.stable.official   |   /home/tu_usuario/MiJuegoIA/slither_2d/
===============================================================
  ✔  0) Los scripts del juego se cargan
        8 scripts cargados sin errores
  ✔  1) El mundo se monta
        jugador: ok | bots: 7/7 | comidas: 150/150
  ✔  2) Cuerpo: segmentos con separación fija
        8 segmentos | separación máx. medida: 15.00 px (esperada: 15.0)
  ✔  3) Comer suma puntos y alarga el cuerpo
        puntos 0 -> 1 | longitud 9 -> 10
  ✔  4) La comida se destruye al comerse
  ✔  5) Tocar el propio cuerpo no mata
  ✔  6) La cola se afila
        primer segmento: 11.0 px | último: 6.1 px
  ✔  7) Turbo: corre más y suelta segmentos
        velocidad 180 -> 306 px/s | longitud 9 -> 8 | segmentos soltados: 1
  ✔  8) El escudo evita la muerte
  ✔  9) El imán atrae la comida
        la comida se acercó 140.0 px a la cabeza
  ✔ 10) Los power-ups se generan en el mundo
        1 power-up(s) en el mundo | duración del último: 5.0 s
  ✔ 11) HUD: minimapa, clasificación y barra de turbo
  ✔ 12) La cabeza muere al tocar el cuerpo de otro gusano
  ✔ 13) Restos: una comida por cada parte del cuerpo
        +10 comidas (se esperaban 10) | comida en la posición exacta de la cabeza: sí
---------------------------------------------------------------
  RESULTADO: 14/14 comprobaciones OK   ✔  TODO BIEN
===============================================================
```

Son **14 comprobaciones**: la 0 (todos los scripts cargan) + las 13 de mecánicas.
(los números entre paréntesis son de una partida de ejemplo: como el mundo lleva
algo de azar —posición de la comida, tipo de power-up— pueden variar un poco;
lo que importa es que todas salgan con ✔ y que el resultado sea `14/14`).

Es la misma prueba que puedes lanzar desde VS Code con
**F1 → `Tasks: Run Task` → `Probar: mecánicas (headless)`**.
El código de salida (0/1) permite usarla también en un script de CI.

> 💡 La **comprobación 0** es la más útil del día a día: carga los 8 scripts del
> juego y, si alguno tiene un error de sintaxis o de API (un método que no
> existe), lo dice ahí arriba y en claro, en vez de fallar más adelante con una
> cascada de errores difíciles de leer. Un linter solo ve la sintaxis; esto
> ejecuta el motor de verdad.

### 9.3 Comprobación a mano en el juego (5 minutos)

```bash
cd ~/MiJuegoIA/slither_2d && godot        # o la tarea "Godot: jugar"
```

| # | Qué mirar | Qué debe pasar |
|---|---|---|
| 1 | Mueve el ratón | El gusano gira **suave** hacia el ratón (no da giros secos) y el cuerpo mantiene la separación, también en las curvas (no se "encoge") |
| 1b | Mantén **SHIFT** (o clic derecho) | El gusano corre más, **suelta** un segmento cada ~0,35 s (queda comida amarilla atrás) y la barra verde de abajo se va vaciando |
| 2 | Pasa por encima de la comida amarilla | Desaparece con un "pop", suben **PUNTOS** y **LONGITUD**, y la bola nueva aparece al final de la cola |
| 3 | Cruza delante de un bot | Si **su** cabeza toca **tu** cuerpo, el bot muere y deja comida **naranja** en su rastro |
| 4 | Choca **tu** cabeza contra el cuerpo de un bot | Pantalla **"¡TE HAN COMIDO!"** con tus puntos y tu cuerpo convertido en comida naranja |
| 5 | Pulsa ESPACIO o haz clic | Empieza una partida nueva (mundo limpio, puntos a 0) |
| 6 | Mira los bordes de los círculos | Suaves, sin dientes de sierra |
| 7 | Mira la cola del gusano | Va **adelgazando** hacia el final (los 8 últimos segmentos) |
| 8 | Espera a que aparezca un power-up (aro de color) y cómetelo | Efecto distinto según el color: IMÁN (cian) atrae la comida, ESCUDO (verde) y FANTASMA (lila) te hacen invulnerable, TURBO (rosa) corre gratis. El HUD abajo a la izquierda dice cuál tienes y cuánto dura |
| 9 | Mira la esquina superior derecha | **Minimapa**: el jugador en el centro con aro blanco, los bots con su color, la comida en puntos pequeños y los restos en naranja |
| 10 | Mira la parte de arriba, en el centro | **CLASIFICACIÓN** con los 5 gusanos más largos en orden, **TÚ** marcado con una estrella y el récord de la partida |
| 11 | Cruza delante de un bot con turbo | Si el bot es de los valientes, acelerará para escaparte dejando su rastro de comida |
| 12 | Mira la consola | Sin errores ni avisos (el de MSAA 2D ya no debe aparecer) |

### 9.4 Si algo falla

Copia y pégame la salida completa del comando de 9.2 (o el error de la consola
de Godot) y lo arreglo. Cuanto más texto de la consola, mejor.

---

## 10. Publicar en `main` (cuando quieras)

Esta rama (`arena/01a0ef16-mijuegoia`) es la del trabajo en curso. Cuando esté
lista para pasar a `main`:

```bash
gh pr create --base main --head arena/01a0ef16-mijuegoia \
  --title "Prototipo Slither 2D en Godot 4.7" \
  --body "Prototipo con movimiento, crecimiento, muerte y restos de comida."
```
