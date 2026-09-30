#!/usr/bin/env bash
# =============================================================================
#  herramientas.sh — atajos para trabajar en slither_2d desde la terminal
#  (pensado para la terminal integrada de VS Code en Linux/Kali)
#
#  Uso:   ./herramientas.sh <comando>
#         ./herramientas.sh            -> muestra la ayuda
#
#  Comandos:
#    todo       Sincroniza con GitHub + importa recursos + prueba las mecánicas
#    sync       git pull --rebase (traer lo último de GitHub)
#    probar     Prueba automática de las 7 mecánicas (headless, ~2 segundos)
#    importar   Genera .godot/ y los .uid sin abrir ventana
#    jugar      Ejecuta el juego
#    editar     Abre el editor de Godot con este proyecto
#    estado     Rama, cambios pendientes y versión de Godot
#    subir      git add -A + commit + push   (uso: ./herramientas.sh subir "mensaje")
#
#  Si Godot no está en el PATH puedes indicar la ruta:
#    GODOT=/ruta/a/godot ./herramientas.sh probar
# =============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

ESCENA_PRUEBA="res://tests/PruebaMecanicas.tscn"

# ------------------------------- colores -------------------------------------
if [ -t 1 ]; then
	VERDE=$'\033[0;32m'; ROJO=$'\033[0;31m'; AMAR=$'\033[0;33m'
	AZUL=$'\033[0;36m'; NEGRITA=$'\033[1m'; FIN=$'\033[0m'
else
	VERDE=""; ROJO=""; AMAR=""; AZUL=""; NEGRITA=""; FIN=""
fi
ok()    { echo "${VERDE}✔${FIN} $*"; }
aviso() { echo "${AMAR}!${FIN} $*"; }
error() { echo "${ROJO}✘${FIN} $*" >&2; }
paso()  { echo ""; echo "${NEGRITA}${AZUL}==> $*${FIN}"; }

# ------------------------------- Godot ---------------------------------------
# Busca Godot y deja la ruta en GODOT_BIN. Devuelve 1 si no lo encuentra
# (sin salir del script: cada comando decide si puede continuar sin él).
buscar_godot() {
	if [ -n "${GODOT:-}" ] && [ -x "${GODOT}" ]; then
		GODOT_BIN="$GODOT"
	elif command -v godot >/dev/null 2>&1; then
		GODOT_BIN="$(command -v godot)"
	elif command -v godot4 >/dev/null 2>&1; then
		GODOT_BIN="$(command -v godot4)"
	else
		GODOT_BIN=""
		return 1
	fi

	local version
	version="$("$GODOT_BIN" --version 2>/dev/null || echo "?")"
	case "$version" in
		4.*) ;;
		*) aviso "El ejecutable dice ser la versión '$version' y el proyecto usa Godot 4.7. Puede fallar." ;;
	esac
	return 0
}

# Como la anterior, pero aborta con instrucciones si no hay Godot.
exigir_godot() {
	if buscar_godot; then
		return 0
	fi
	error "No encuentro el ejecutable de Godot."
	echo "  Opciones:" >&2
	echo "    1) Crea el enlace:" >&2
	echo "       sudo ln -sf \"\$HOME/Godot/Godot_v4.7.2-stable_linux.x86_64\" /usr/local/bin/godot" >&2
	echo "    2) Indica la ruta al vuelo:" >&2
	echo "       GODOT=/ruta/a/godot $0 $COMANDO" >&2
	echo "  Pasos completos en COMO_TRABAJAR.md, sección 1." >&2
	exit 1
}

# ------------------------------ comandos -------------------------------------
cmd_estado() {
	paso "Estado del repositorio"
	git status --short --branch
	local rama
	rama="$(git rev-parse --abbrev-ref HEAD)"
	echo ""
	echo "  Rama actual: ${NEGRITA}${rama}${FIN}"
	paso "Herramientas"
	echo "  Proyecto: $DIR"
	if buscar_godot; then
		echo "  Godot:    $GODOT_BIN ($("$GODOT_BIN" --version 2>/dev/null || echo '?'))"
	else
		aviso "Godot no está en el PATH (mira COMO_TRABAJAR.md, sección 1.3)"
	fi
}

cmd_sync() {
	local con_cambios="${1:-}"
	paso "Sincronizando con GitHub (git pull --rebase)"

	if [ -n "$(git status --porcelain)" ]; then
		echo "  Cambios pendientes en el proyecto:"
		git status --short | sed 's/^/      /'
		echo ""

		if [ "$con_cambios" != "--con-cambios" ]; then
			aviso "No se puede hacer pull --rebase con cambios sin marcar. Elige UNA opción:"
			echo "      A) ${NEGRITA}Automático${FIN} (los aparta y los devuelve después):"
			echo "           ./herramientas.sh sync --con-cambios"
			echo "      B) ${NEGRITA}Guardarlos en un commit${FIN} (si son tuyos o son los .uid de Godot):"
			echo "           git add -A && git commit -m \"mis cambios\"   &&   ./herramientas.sh sync"
			echo "      C) ${NEGRITA}Descartarlos${FIN} (¡se pierden! sirve si son los re-guardados de Godot):"
			echo "           git checkout -- . && git clean -fd"
			exit 1
		fi

		aviso "Apartando tus cambios con 'git stash -u' (volverán después del pull)"
		git stash -u --quiet
		if ! git pull --rebase; then
			error "El pull falló. Tus cambios están a salvo: recupéralos con  git stash pop"
			exit 1
		fi
		if ! git stash pop --quiet; then
			error "Conflicto al devolver tus cambios (git stash pop)."
			echo "  - Si son los re-guardados de Godot (.tscn, project.godot):" >&2
			echo "      git checkout -- . && git stash drop" >&2
			echo "  - Si eran cambios tuyos: no toques nada más y pásame la salida de 'git status'." >&2
			exit 1
		fi
		ok "Cambios apartados y devueltos sin conflicto"
	else
		git pull --rebase
	fi

	ok "Al día. Últimos commits:"
	git --no-pager log --oneline -5 | sed 's/^/      /'
}

cmd_importar() {
	paso "Importando recursos (.godot/ y .uid) — sin abrir ventana"
	exigir_godot
	"$GODOT_BIN" --headless --import
	ok "Importación terminada"
	if [ -n "$(git status --porcelain)" ]; then
		echo "  Archivos nuevos (normalmente los .uid, que SÍ se suben al repo):"
		git status --short | sed 's/^/      /'
		echo "  Súbelos con:  ./herramientas.sh subir \"chore: archivos .uid\""
	fi
}

cmd_probar() {
	paso "Prueba automática de las mecánicas (headless)"
	exigir_godot
	local salida=0
	if "$GODOT_BIN" --headless "$ESCENA_PRUEBA"; then
		salida=0
	else
		salida=$?
	fi
	echo ""
	if [ "$salida" -eq 0 ]; then
		ok "${NEGRITA}TODO BIEN${FIN} — las 7 comprobaciones han pasado (código de salida 0)"
	else
		error "HAY FALLOS (código de salida $salida). Copia la salida de arriba y pásala para arreglarlo."
	fi
	return "$salida"
}

cmd_jugar() {
	paso "Ejecutando el juego"
	exigir_godot
	"$GODOT_BIN"
}

cmd_editar() {
	paso "Abriendo el editor de Godot"
	exigir_godot
	"$GODOT_BIN" -e
}

cmd_subir() {
	local mensaje="${1:-}"
	paso "Guardando y subiendo a GitHub"
	if [ -z "$(git status --porcelain)" ]; then
		aviso "No hay cambios que subir."
	else
		if [ -z "$mensaje" ]; then
			mensaje="cambios desde la terminal ($(date '+%Y-%m-%d %H:%M'))"
			aviso "Sin mensaje: se usará \"$mensaje\""
		fi
		git add -A
		git commit -m "$mensaje"
	fi
	git push
	ok "Subido. Rama: $(git rev-parse --abbrev-ref HEAD)"
}

cmd_todo() {
	echo "${NEGRITA}=== Sincronizar + importar + probar ===${FIN}"
	cmd_sync "${1:-}"
	cmd_importar
	cmd_probar
	echo ""
	ok "${NEGRITA}Todo listo.${FIN} Si quieres, ahora: ./herramientas.sh jugar"
}

cmd_ayuda() {
	cat <<EOF
${NEGRITA}herramientas.sh${FIN} — atajos para slither_2d (terminal de VS Code)

  ./herramientas.sh todo       Sincroniza + importa + prueba (empieza por aquí)
  ./herramientas.sh sync       Traer lo último de GitHub (git pull --rebase)
  ./herramientas.sh sync --con-cambios
                               Lo mismo, pero apartando tus cambios sin guardar
                               (git stash -u) y devolviéndolos después
  ./herramientas.sh probar     Prueba automática de las 7 mecánicas (~2 s)
  ./herramientas.sh importar   Genera .godot/ y los .uid sin abrir ventana
  ./herramientas.sh jugar      Ejecuta el juego
  ./herramientas.sh editar     Abre el editor de Godot
  ./herramientas.sh estado     Rama, cambios pendientes y versión de Godot
  ./herramientas.sh subir "m"  git add -A + commit + push

  GODOT=/ruta/a/godot ./herramientas.sh probar     (si no está en el PATH)

Guía completa: COMO_TRABAJAR.md
EOF
}

# ------------------------------- entrada -------------------------------------
COMANDO="${1:-ayuda}"
case "$COMANDO" in
	todo)     shift || true; cmd_todo "${1:-}" ;;
	probar)   cmd_probar ;;
	importar) cmd_importar ;;
	jugar)    cmd_jugar ;;
	editar)   cmd_editar ;;
	estado)   cmd_estado ;;
	sync)     shift || true; cmd_sync "${1:-}" ;;
	subir)    shift || true; cmd_subir "${1:-}" ;;
	ayuda|-h|--help) cmd_ayuda ;;
	*) error "Comando desconocido: $COMANDO"; echo ""; cmd_ayuda; exit 1 ;;
esac
