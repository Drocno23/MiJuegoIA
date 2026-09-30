# 🧭 Cómo trabajar en este repositorio (VS Code + Godot + Git por comandos)

Este repositorio tiene **dos proyectos**:

| Carpeta | Qué es |
|---|---|
| `/` (raíz) | El proyecto `MiJuegoIA` (Godot 4.7, `project.godot` propio) |
| `slither_2d/` | El prototipo tipo slither.io (proyecto Godot 4.7 **independiente**) |

## ⚠️ Regla nº 1: abre la carpeta del proyecto que vas a tocar

```bash
code slither_2d      # para trabajar en el prototipo
code .               # para trabajar en el proyecto de la raíz
```

¿Por qué importa? La extensión *Godot Tools* de VS Code busca `**/project.godot`
en el workspace y, **cuando encuentra varios, elige el de la ruta más corta**
(lo hace así en `get_project_dir()`, `src/utils/godot_utils.ts`). Si abres la
raíz con los dos proyectos dentro, el autocompletado y los `res://` apuntarán al
de la raíz. Abriendo `slither_2d` no hay ambigüedad.

## 🚀 Flujo diario (5 comandos)

```bash
git pull --rebase                       # 1) antes de empezar
#    ... editas en VS Code y/o Godot ...
git status --short --branch             # 2) ver qué cambió
git add -A && git commit -m "mensaje"   # 3) guardar
git push                                # 4) subir
```

## 🌿 Ramsas

* `main` → versión estable de cada proyecto.
* `arena/01a0ef16-mijuegoia` → rama donde el agente de Arena sube los cambios del
  prototipo `slither_2d`. **Haz `git pull --rebase` para recibirlos.**

Para pasar el trabajo a `main` cuando esté listo:

```bash
gh pr create --base main --head arena/01a0ef16-mijuegoia --title "..." --body "..."
```

## 🧩 Detalle por proyecto

* **Prototipo slither 2D** → [`slither_2d/COMO_TRABAJAR.md`](slither_2d/COMO_TRABAJAR.md):
  instalación de la extensión, tareas de VS Code, archivos `.uid`, qué se sube y
  qué no, y solución de problemas de sincronización.
* **Proyecto de la raíz** → sirve el mismo flujo; solo cambia la carpeta que
  abres en VS Code.

## 📌 Recordatorios importantes de Git + Godot 4.4+

* Los archivos **`.uid` se commitean** (junto a cada `.gd`/`.tscn`): son las
  referencias del proyecto. Si no se suben, al clonar en otra máquina Godot
  imprime avisos y puede perder referencias.
* La carpeta **`.godot/` NO se sube** (caché de importación; ya está en
  `.gitignore`). Se regenera con `godot --headless --import`.
* No edites nunca archivos dentro de `.godot/`.
