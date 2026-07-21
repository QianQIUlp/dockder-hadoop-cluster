#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

lessons=(
    00-first-run
    01-hdfs-basics
    02-mapreduce-wordcount
    03-yarn-observation
    04-cluster-roles
    05-node-failure-recovery
    06-configuration-experiment
)

usage() {
    echo "Usage: ./hadoop-lab lesson list|start|check|reset [LESSON]"
}

valid_lesson() {
    local candidate="$1" item
    for item in "${lessons[@]}"; do [[ "${item}" == "${candidate}" ]] && return 0; done
    return 1
}

master_container() {
    if docker ps --format '{{.Names}}' | grep -qx hadoop-standalone; then echo hadoop-standalone
    elif docker ps --format '{{.Names}}' | grep -qx hadoop1; then echo hadoop1
    else echo "No Hadoop environment is running. Start one with ./hadoop-lab up standalone." >&2; return 1; fi
}

show_lesson() {
    local lesson="$1"
    sed -n '1,220p' "labs/${lesson}/README.md"
}

start_lesson() {
    local lesson="$1" master
    case "${lesson}" in
        00-first-run)
            "${ROOT_DIR}/hadoop-lab" status
            ;;
        01-hdfs-basics)
            master="$(master_container)"
            docker exec -u hadoop "${master}" hdfs dfs -mkdir -p /labs/hdfs-basics
            printf 'HDFS stores blocks independently from the host filesystem.\n' |
                docker exec -i -u hadoop "${master}" hdfs dfs -put -f - /labs/hdfs-basics/input.txt
            docker exec -u hadoop "${master}" hdfs dfs -ls /labs/hdfs-basics
            ;;
        02-mapreduce-wordcount)
            "${ROOT_DIR}/examples/run-wordcount.sh"
            ;;
        03-yarn-observation)
            master="$(master_container)"
            docker exec -u hadoop "${master}" yarn node -list
            docker exec -u hadoop "${master}" yarn application -list -appStates ALL
            ;;
        04-cluster-roles)
            if ! docker ps --format '{{.Names}}' | grep -qx hadoop3; then
                echo "This lesson needs three-node mode: ./hadoop-lab stop all && ./hadoop-lab up cluster" >&2
                exit 1
            fi
            "${ROOT_DIR}/hadoop-lab" status
            ;;
        05-node-failure-recovery)
            if ! docker ps --format '{{.Names}}' | grep -qx hadoop3; then
                echo "This lesson needs three-node mode: ./hadoop-lab stop all && ./hadoop-lab up cluster" >&2
                exit 1
            fi
            show_lesson "${lesson}"
            echo
            echo "Failure injection is deliberately manual. Follow the commands above, then run lesson check."
            ;;
        06-configuration-experiment)
            show_lesson "${lesson}"
            echo
            echo "Current rendered replication setting:"
            master="$(master_container)"
            docker exec -u hadoop "${master}" hdfs getconf -confKey dfs.replication
            ;;
    esac
}

check_lesson() {
    local lesson="$1" master output
    master="$(master_container)"
    case "${lesson}" in
        00-first-run) "${ROOT_DIR}/hadoop-lab" status ;;
        01-hdfs-basics)
            output="$(docker exec -u hadoop "${master}" hdfs dfs -cat /labs/hdfs-basics/input.txt)"
            grep -q 'HDFS stores blocks' <<<"${output}"
            echo "PASS: the prepared file can be read back from HDFS."
            ;;
        02-mapreduce-wordcount)
            docker exec -u hadoop "${master}" hdfs dfs -test -s /labs/wordcount/output/part-r-00000
            echo "PASS: MapReduce produced a non-empty reducer output."
            ;;
        03-yarn-observation)
            docker exec -u hadoop "${master}" yarn node -list 2>&1 | grep -Eq 'RUNNING|Total Nodes'
            echo "PASS: YARN responds and reports its node set."
            ;;
        04-cluster-roles) "${ROOT_DIR}/hadoop-lab" status ;;
        05-node-failure-recovery)
            if [[ "$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' hadoop3 2>/dev/null || true)" == "healthy" ]]; then
                docker exec -u hadoop "${master}" hdfs dfsadmin -report | grep -q 'Hostname: hadoop3'
                echo "PASS: hadoop3 is healthy and registered as a live HDFS DataNode."
            else
                echo "OBSERVED: hadoop3 is stopped. Inspect NameNode, then recover with: docker start hadoop3" >&2
                exit 1
            fi
            ;;
        06-configuration-experiment)
            output="$(docker exec -u hadoop "${master}" hdfs getconf -confKey dfs.replication)"
            [[ "${output}" =~ ^[0-9]+$ ]]
            echo "PASS: dfs.replication is rendered as ${output}."
            ;;
    esac
}

reset_lesson() {
    local lesson="$1" master
    master="$(master_container)"
    case "${lesson}" in
        01-hdfs-basics) docker exec -u hadoop "${master}" hdfs dfs -rm -r -f /labs/hdfs-basics ;;
        02-mapreduce-wordcount) docker exec -u hadoop "${master}" hdfs dfs -rm -r -f /labs/wordcount ;;
        05-node-failure-recovery)
            docker start hadoop3 >/dev/null 2>&1 || true
            for _ in $(seq 1 60); do
                [[ "$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' hadoop3 2>/dev/null || true)" == "healthy" ]] && break
                sleep 2
            done
            ;;
        *) echo "No lesson-specific data to reset." ;;
    esac
    echo "Lesson state reset: ${lesson}"
}

action="${1:-list}"
case "${action}" in
    list)
        printf '%s\n' "${lessons[@]}"
        ;;
    start|check|reset)
        lesson="${2:-}"
        valid_lesson "${lesson}" || { usage >&2; exit 2; }
        "${action}_lesson" "${lesson}"
        ;;
    *) usage >&2; exit 2 ;;
esac
