#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

compose_files=("-f" "docker-compose.yml")
mode="standard"

if [[ "${1:-}" == "--secure" ]]; then
    compose_files+=("-f" "docker-compose.secure.yml")
    mode="secure"
    shift
fi

if [[ "${1:-}" == "--" ]]; then
    shift
fi

extra_args=("$@")

echo "[up.sh] compose mode: ${mode}"
docker compose "${compose_files[@]}" up -d --build "${extra_args[@]}"

mapfile -t required_images < <(docker compose "${compose_files[@]}" config --images | sort -u)
if [[ ${#required_images[@]} -eq 0 ]]; then
    echo "[up.sh] no compose images found, skip cleanup"
    exit 0
fi

declare -A keep_images=()
declare -A repo_names=()
for image in "${required_images[@]}"; do
    keep_images["${image}"]=1
    repo_names["${image%%:*}"]=1
done

for repo in "${!repo_names[@]}"; do
    while IFS= read -r tagged_image; do
        [[ -z "${tagged_image}" ]] && continue
        [[ "${tagged_image}" == "<none>:<none>" ]] && continue
        if [[ -z "${keep_images[${tagged_image}]+x}" ]]; then
            echo "[up.sh] removing old tag: ${tagged_image}"
            docker image rm "${tagged_image}" >/dev/null 2>&1 || true
        fi
    done < <(docker image ls "${repo}" --format '{{.Repository}}:{{.Tag}}' | sort -u)
done

# Remove only dangling images generated from this repository image.
docker image prune -f \
    --filter "dangling=true" \
    --filter "label=org.opencontainers.image.source=https://github.com/QianQIUlp/dockder-hadoop-cluster" \
    >/dev/null || true

echo "[up.sh] keep image set:"
printf '  - %s\n' "${required_images[@]}"
