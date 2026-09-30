#!/usr/bin/env bash
# =============================================================================
#  Lanzador de atajos DESDE LA RAÍZ del repositorio.
#
#  El proyecto Godot vive en slither_2d/, así que el script de verdad está ahí.
#  Este solo lo llama, para que puedas teclear el mismo comando desde la raíz:
#
#      ./herramientas.sh todo          # desde ~/Proyectos/MiJuegoIA
#      ./herramientas.sh               # ayuda
#
#  Las rutas con las que trabaja (git, Godot) las resuelve el script real.
# =============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL="$DIR/slither_2d/herramientas.sh"

if [ ! -f "$REAL" ]; then
	echo "✘ No encuentro $REAL" >&2
	echo "  ¿Estás dentro del repositorio MiJuegoIA?" >&2
	exit 1
fi

exec bash "$REAL" "$@"
