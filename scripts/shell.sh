#!/usr/bin/env bash
# =====================================================================
# Interactive Shell Helper
# 进入运行中的 Hadoop 容器 Shell 的快捷脚本
# =====================================================================
set -euo pipefail

# Determine which container is running
CONTAINER_NAME=""
if docker ps --format '{{.Names}}' | grep -q "^hadoop-standalone$"; then
    CONTAINER_NAME="hadoop-standalone"
elif docker ps --format '{{.Names}}' | grep -q "^hadoop1$"; then
    CONTAINER_NAME="hadoop1"
else
    echo "Error: No running Hadoop master or standalone container found."
    echo "Please start the cluster first."
    echo "  - Standalone: docker compose -f docker-compose.standalone.yml up -d"
    echo "  - Standard:   ./scripts/up.sh"
    exit 1
fi

echo "Connecting to '${CONTAINER_NAME}' as user 'hadoop'..."
echo "--------------------------------------------------"
docker exec -it -u hadoop "${CONTAINER_NAME}" bash -l
