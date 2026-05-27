#!/usr/bin/env bash
# =====================================================================
# Hadoop MapReduce WordCount Tutorial
# 运行经典 WordCount 词频统计 MapReduce 任务的快捷演示脚本
# =====================================================================
set -euo pipefail

# Determine which container is running
CONTAINER_NAME=""
if docker ps --format '{{.Names}}' | grep -q "^hadoop-standalone$"; then
    CONTAINER_NAME="hadoop-standalone"
elif docker ps --format '{{.Names}}' | grep -q "^hadoop1$"; then
    CONTAINER_NAME="hadoop1"
else
    echo "Error: Neither hadoop-standalone nor hadoop1 container is running."
    echo "Please start the cluster first:"
    echo "  - Standalone: docker compose -f docker-compose.standalone.yml up -d"
    echo "  - Standard:   ./scripts/up.sh"
    exit 1
fi

echo "=================================================="
echo " Hadoop MapReduce WordCount Demonstration"
echo "=================================================="
echo "Target Container: ${CONTAINER_NAME}"

echo ""
echo "--------------------------------------------------"
echo " Step 1: Checking HDFS Input Files"
echo "--------------------------------------------------"
# Executed as non-root 'hadoop' user for security compliance
docker exec -u hadoop "${CONTAINER_NAME}" hdfs dfs -ls -R /input || {
    echo "Error: Input directory '/input' not found in HDFS."
    echo "If you just started the cluster, the background data preloader might still be running."
    echo "Please wait a few seconds and try again."
    exit 1
}

echo ""
echo "--------------------------------------------------"
echo " Step 2: Cleaning up previous output directory"
echo "--------------------------------------------------"
# Ensure clean run by removing any stale /output
docker exec -u hadoop "${CONTAINER_NAME}" hdfs dfs -rm -r -f /output >/dev/null 2>&1 || true
echo "Output directory '/output' in HDFS cleaned up."

echo ""
echo "--------------------------------------------------"
echo " Step 3: Submitting MapReduce WordCount Job"
echo "--------------------------------------------------"
# Locate the mapreduce examples jar dynamically inside the container and submit
docker exec -u hadoop "${CONTAINER_NAME}" bash -l -c '
    JAR_PATH=$(find ${HADOOP_HOME}/share/hadoop/mapreduce -name "hadoop-mapreduce-examples-*.jar" | head -n 1)
    if [ -z "$JAR_PATH" ]; then
        echo "Error: mapreduce examples jar not found under ${HADOOP_HOME}."
        exit 1
    fi
    echo "Found MapReduce Examples JAR: $JAR_PATH"
    echo "Running command: hadoop jar $JAR_PATH wordcount /input /output"
    echo "--------------------------------------------------"
    hadoop jar "$JAR_PATH" wordcount /input /output
'

echo ""
echo "--------------------------------------------------"
echo " Step 4: Printing Results (Top 20 words by count)"
echo "--------------------------------------------------"
# Fetch output file from HDFS and sort/print top results nicely
docker exec -u hadoop "${CONTAINER_NAME}" bash -l -c '
    echo "Output files in /output:"
    hdfs dfs -ls /output
    echo ""
    echo "Results Preview (part-r-00000):"
    echo "----------------------------------"
    # Sort results numerically (highest word counts first)
    hdfs dfs -cat /output/part-r-00000 | sort -k2 -n -r | head -n 20
'
echo "--------------------------------------------------"
echo "Success! To view the full output, run:"
echo "  docker exec -it -u hadoop ${CONTAINER_NAME} hdfs dfs -cat /output/part-r-00000"
echo "=================================================="
