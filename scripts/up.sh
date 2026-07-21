#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
args=(up cluster --build)
if [[ "${1:-}" == "--secure" ]]; then args+=(--secure); shift; fi
if (( $# > 0 )); then
    printf '[up.sh] legacy wrapper does not forward raw Compose arguments. Use ./hadoop-lab help.\n' >&2
    exit 2
fi
exec "${ROOT_DIR}/hadoop-lab" "${args[@]}"
