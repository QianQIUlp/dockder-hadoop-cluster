#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------------------
# Global environment defaults
# 全局环境变量默认值
# ----------------------------------------------------------------------
export JAVA_HOME="${JAVA_HOME:-/opt/java/openjdk}"
export HADOOP_VERSION="${HADOOP_VERSION:-3.4.1}"
export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop-${HADOOP_VERSION}}"
export HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-${HADOOP_HOME}/etc/hadoop}"
export HADOOP_CONF_TEMPLATE_DIR="${HADOOP_CONF_TEMPLATE_DIR:-/opt/hadoop-conf-template}"
export PATH="${JAVA_HOME}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${PATH}"

# ----------------------------------------------------------------------
# Role and startup control
# 角色与启动控制参数
# ----------------------------------------------------------------------
NODE_ROLE="${NODE_ROLE:-worker}"
AUTO_FORMAT="${AUTO_FORMAT:-false}"
WAIT_FOR_NAMENODE_RETRIES="${WAIT_FOR_NAMENODE_RETRIES:-60}"
WAIT_FOR_NAMENODE_INTERVAL="${WAIT_FOR_NAMENODE_INTERVAL:-2}"
HADOOP_DAEMON_USER="${HADOOP_DAEMON_USER:-hadoop}"
ENABLE_SSH_USER_ENV="${ENABLE_SSH_USER_ENV:-false}"

# ----------------------------------------------------------------------
# Runtime path defaults used by config templates
# 模板渲染中使用的运行目录默认值
# ----------------------------------------------------------------------
NAMENODE_HOST="${NAMENODE_HOST:-hadoop1}"
NAMENODE_RPC_PORT="${NAMENODE_RPC_PORT:-9000}"
NAMENODE_HTTP_PORT="${NAMENODE_HTTP_PORT:-9870}"
RESOURCEMANAGER_HOST="${RESOURCEMANAGER_HOST:-hadoop2}"
RESOURCEMANAGER_WEB_PORT="${RESOURCEMANAGER_WEB_PORT:-8088}"
SECONDARY_NAMENODE_HOST="${SECONDARY_NAMENODE_HOST:-hadoop3}"
SECONDARY_NAMENODE_HTTP_PORT="${SECONDARY_NAMENODE_HTTP_PORT:-9868}"
JOBHISTORY_HOST="${JOBHISTORY_HOST:-hadoop3}"
JOBHISTORY_RPC_PORT="${JOBHISTORY_RPC_PORT:-10020}"
JOBHISTORY_WEB_PORT="${JOBHISTORY_WEB_PORT:-19888}"
DFS_REPLICATION="${DFS_REPLICATION:-3}"

HADOOP_TMP_DIR="${HADOOP_TMP_DIR:-/hadoop/tmp}"
HDFS_NAMENODE_NAME_DIR="${HDFS_NAMENODE_NAME_DIR:-/hadoop/dfs/name}"
HDFS_DATANODE_DATA_DIR="${HDFS_DATANODE_DATA_DIR:-/hadoop/dfs/data}"
YARN_NODEMANAGER_LOCAL_DIR="${YARN_NODEMANAGER_LOCAL_DIR:-/hadoop/yarn/local}"
YARN_NODEMANAGER_LOG_DIR="${YARN_NODEMANAGER_LOG_DIR:-/hadoop/yarn/logs}"
MAPRED_HISTORY_TMP_DIR="${MAPRED_HISTORY_TMP_DIR:-/hadoop/mr-history/tmp}"
MAPRED_HISTORY_DONE_DIR="${MAPRED_HISTORY_DONE_DIR:-/hadoop/mr-history/done}"

log() {
    printf '[entrypoint] %s\n' "$*"
}

# ----------------------------------------------------------------------
# Render XML/workers from templates.
# 从模板渲染 XML/workers 配置文件。
# ----------------------------------------------------------------------
render_hadoop_configs() {
    local files
    files=(core-site.xml hdfs-site.xml yarn-site.xml mapred-site.xml workers)

    if [[ ! -d "${HADOOP_CONF_TEMPLATE_DIR}" ]]; then
        log "Template dir not found: ${HADOOP_CONF_TEMPLATE_DIR}; use image defaults"
        return
    fi

    for file in "${files[@]}"; do
        if [[ -f "${HADOOP_CONF_TEMPLATE_DIR}/${file}" ]]; then
            envsubst < "${HADOOP_CONF_TEMPLATE_DIR}/${file}" > "${HADOOP_CONF_DIR}/${file}"
            log "Rendered config: ${file}"
        fi
    done
}

ensure_ssh_runtime_env() {
    # Ensure runtime directories for sshd and root key materials.
    # 确保 sshd 与 root 密钥运行目录存在。
    mkdir -p /run/sshd /root/.ssh
    chmod 700 /root/.ssh

    # Generate host keys at runtime so published images never contain private keys.
    # 运行期生成 host key，避免公开镜像层中固化私钥。
    if [[ ! -s /etc/ssh/ssh_host_rsa_key ]]; then
        log "Generating SSH host keys"
        ssh-keygen -A
    fi

    # Generate one root keypair per container instance when absent.
    # 若不存在 root key，则为当前容器生成唯一密钥对。
    if [[ ! -s /root/.ssh/id_rsa ]]; then
        log "Generating root SSH keypair"
        ssh-keygen -t rsa -b 4096 -f /root/.ssh/id_rsa -N ""
    fi

    touch /root/.ssh/authorized_keys
    local pub_key
    pub_key="$(cat /root/.ssh/id_rsa.pub)"
    if ! grep -qxF "${pub_key}" /root/.ssh/authorized_keys; then
        printf '%s\n' "${pub_key}" >> /root/.ssh/authorized_keys
    fi
    chmod 600 /root/.ssh/id_rsa /root/.ssh/authorized_keys
    chmod 644 /root/.ssh/id_rsa.pub

    # Export variables into SSH session environment.
    # 将关键变量注入 SSH 会话环境。
    cat > /root/.ssh/environment <<EOF
JAVA_HOME=${JAVA_HOME}
HADOOP_HOME=${HADOOP_HOME}
HADOOP_CONF_DIR=${HADOOP_CONF_DIR}
PATH=${JAVA_HOME}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
    chmod 600 /root/.ssh/environment

    # Export variables for interactive shell login.
    # 为交互式 shell 登录导出环境变量。
    cat > /etc/profile.d/hadoop.sh <<EOF
export JAVA_HOME=${JAVA_HOME}
export HADOOP_HOME=${HADOOP_HOME}
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR}
export PATH=\$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${JAVA_HOME}/bin
EOF
    chmod 644 /etc/profile.d/hadoop.sh

    # Keep SSH user environment disabled by default.
    # 默认禁用 SSH 用户环境变量注入，仅在显式开启时允许。
    if [[ "${ENABLE_SSH_USER_ENV}" == "true" ]]; then
        sed -ri 's/^#?PermitUserEnvironment\s+.*/PermitUserEnvironment yes/' /etc/ssh/sshd_config
    else
        sed -ri 's/^#?PermitUserEnvironment\s+.*/PermitUserEnvironment no/' /etc/ssh/sshd_config
    fi
}

run_as_daemon_user() {
    local cmd="$1"
    if ! id -u "${HADOOP_DAEMON_USER}" >/dev/null 2>&1; then
        log "Daemon user ${HADOOP_DAEMON_USER} not found, fallback to root"
        bash -lc "${cmd}"
        return
    fi
    su -s /bin/bash -c "${cmd}" "${HADOOP_DAEMON_USER}"
}

start_sshd() {
    # Run sshd in background; container lifetime is tied to this process.
    # 后台运行 sshd；容器生命周期绑定到该进程。
    /usr/sbin/sshd -D &
    SSHD_PID=$!
    log "sshd started (pid=${SSHD_PID})"
}

prepare_runtime_dirs() {
    # Ensure all runtime data directories exist before daemon startup.
    # 在启动各 Daemon 前，确保运行目录均已创建。
    mkdir -p \
        "${HADOOP_TMP_DIR}" \
        "${HDFS_NAMENODE_NAME_DIR}" \
        "${HDFS_DATANODE_DATA_DIR}" \
        "${YARN_NODEMANAGER_LOCAL_DIR}" \
        "${YARN_NODEMANAGER_LOG_DIR}" \
        "${MAPRED_HISTORY_TMP_DIR}" \
        "${MAPRED_HISTORY_DONE_DIR}"
    chown -R "${HADOOP_DAEMON_USER}:${HADOOP_DAEMON_USER}" \
        "${HADOOP_TMP_DIR}" \
        "${HDFS_NAMENODE_NAME_DIR}" \
        "${HDFS_DATANODE_DATA_DIR}" \
        "${YARN_NODEMANAGER_LOCAL_DIR}" \
        "${YARN_NODEMANAGER_LOG_DIR}" \
        "${MAPRED_HISTORY_TMP_DIR}" \
        "${MAPRED_HISTORY_DONE_DIR}" \
        "${HADOOP_CONF_DIR}" || true
}

wait_for_namenode() {
    local i
    if [[ "${NODE_ROLE}" == "namenode" ]]; then
        return
    fi

    log "Waiting for NameNode ${NAMENODE_HOST}:${NAMENODE_RPC_PORT}"
    for ((i = 1; i <= WAIT_FOR_NAMENODE_RETRIES; i++)); do
        if bash -c "</dev/tcp/${NAMENODE_HOST}/${NAMENODE_RPC_PORT}" >/dev/null 2>&1; then
            log "NameNode RPC is reachable"
            return
        fi
        log "NameNode not ready yet (${i}/${WAIT_FOR_NAMENODE_RETRIES}); sleep ${WAIT_FOR_NAMENODE_INTERVAL}s"
        sleep "${WAIT_FOR_NAMENODE_INTERVAL}"
    done

    log "NameNode wait timeout reached; continue startup for debugging"
}

format_namenode_if_needed() {
    # Format only when explicitly enabled and metadata directory is empty.
    # 仅在显式开启 AUTO_FORMAT 且元数据目录为空时执行格式化。
    if [[ "${AUTO_FORMAT}" == "true" ]]; then
        if [[ ! -d "${HDFS_NAMENODE_NAME_DIR}/current" ]]; then
            log "NameNode metadata not found, formatting..."
            run_as_daemon_user "hdfs namenode -format -nonInteractive"
        else
            log "NameNode metadata exists, skipping format"
        fi
    else
        log "AUTO_FORMAT=false, skipping format"
    fi
}

start_role_daemons() {
    # Start role-specific daemon sets.
    # 按节点角色启动对应 Daemon 组合。
    case "${NODE_ROLE}" in
        namenode)
            format_namenode_if_needed
            log "Starting NameNode and local DataNode"
            run_as_daemon_user "hdfs --daemon start namenode"
            run_as_daemon_user "hdfs --daemon start datanode"
            ;;
        resourcemanager)
            log "Starting ResourceManager, NodeManager and local DataNode"
            run_as_daemon_user "hdfs --daemon start datanode"
            run_as_daemon_user "yarn --daemon start resourcemanager"
            run_as_daemon_user "yarn --daemon start nodemanager"
            ;;
        secondary)
            log "Starting SecondaryNameNode, JobHistoryServer and local DataNode"
            run_as_daemon_user "hdfs --daemon start datanode"
            run_as_daemon_user "hdfs --daemon start secondarynamenode"
            run_as_daemon_user "mapred --daemon start historyserver"
            ;;
        worker)
            log "Starting worker daemons (DataNode + NodeManager)"
            run_as_daemon_user "hdfs --daemon start datanode"
            run_as_daemon_user "yarn --daemon start nodemanager"
            ;;
        *)
            log "Unknown NODE_ROLE=${NODE_ROLE}, only sshd will run"
            ;;
    esac
}

render_hadoop_configs
ensure_ssh_runtime_env
prepare_runtime_dirs
start_sshd
wait_for_namenode
start_role_daemons

# Keep container alive by waiting on sshd foreground process.
# 通过等待 sshd 进程保持容器存活。
wait "${SSHD_PID}"
