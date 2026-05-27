#!/usr/bin/env bash
# =====================================================================
# Hadoop Cluster Status Checker
# 检查 Hadoop 集群各节点及服务运行状态的快捷脚本
# =====================================================================
set -euo pipefail

# Find all running hadoop containers
containers=$(docker ps --format '{{.Names}}' | grep -E '^hadoop(1|2|3|-standalone)$' || true)

if [[ -z "${containers}" ]]; then
    echo "=================================================="
    echo " No running Hadoop containers found."
    echo "=================================================="
    echo "Please start the cluster first:"
    echo "  - Standalone: docker compose -f docker-compose.standalone.yml up -d"
    echo "  - Standard:   ./scripts/up.sh"
    exit 0
fi

echo "=================================================="
echo " 1. Running Hadoop Containers"
echo "=================================================="
docker ps --filter "name=hadoop"

for container in ${containers}; do
    echo ""
    echo "=================================================="
    echo " Node: ${container} - Active JVM Processes (JPS)"
    echo "=================================================="
    # Exec jps to verify which Hadoop daemons are up and healthy
    docker exec "${container}" bash -l -c "jps" || true
done

# If standalone or namenode is running, print HDFS / YARN cluster summary
master_container=""
if echo "${containers}" | grep -q "^hadoop-standalone$"; then
    master_container="hadoop-standalone"
elif echo "${containers}" | grep -q "^hadoop1$"; then
    master_container="hadoop1"
fi

if [[ -n "${master_container}" ]]; then
    echo ""
    echo "=================================================="
    echo " 2. HDFS Cluster Report"
    echo "=================================================="
    docker exec -u hadoop "${master_container}" hdfs dfsadmin -report | head -n 25 || true
    
    echo ""
    echo "=================================================="
    echo " 3. YARN Node Manager List"
    echo "=================================================="
    docker exec -u hadoop "${master_container}" yarn node -list || true
fi
