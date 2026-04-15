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
ROOT_DAEMON_ENV="HDFS_NAMENODE_USER=root HDFS_DATANODE_USER=root HDFS_SECONDARYNAMENODE_USER=root YARN_RESOURCEMANAGER_USER=root YARN_NODEMANAGER_USER=root MAPRED_HISTORYSERVER_USER=root"
AUTO_RESET_DATANODE_DATA_ON_VERSION_CHANGE="${AUTO_RESET_DATANODE_DATA_ON_VERSION_CHANGE:-true}"
SSH_SHARED_DIR="${SSH_SHARED_DIR:-/shared-ssh}"

# ----------------------------------------------------------------------
# JVM memory defaults for container runtime
# 容器运行时 JVM 内存默认值
# ----------------------------------------------------------------------
HADOOP_HEAPSIZE_MAX="${HADOOP_HEAPSIZE_MAX:-1024}"
HADOOP_NAMENODE_OPTS="${HADOOP_NAMENODE_OPTS:--Xms512m -Xmx1024m}"
HADOOP_DATANODE_OPTS="${HADOOP_DATANODE_OPTS:--Xms256m -Xmx768m}"
HADOOP_SECONDARYNAMENODE_OPTS="${HADOOP_SECONDARYNAMENODE_OPTS:--Xms256m -Xmx512m}"
YARN_RESOURCEMANAGER_OPTS="${YARN_RESOURCEMANAGER_OPTS:--Xms256m -Xmx768m}"
YARN_NODEMANAGER_OPTS="${YARN_NODEMANAGER_OPTS:--Xms256m -Xmx512m}"
MAPRED_HISTORYSERVER_OPTS="${MAPRED_HISTORYSERVER_OPTS:--Xms256m -Xmx512m}"

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

upsert_export_var() {
    local file="$1"
    local key="$2"
    local value="$3"
    local tmp_file

    tmp_file="$(mktemp)"

    if [[ -f "${file}" ]]; then
        grep -vE "^export ${key}=" "${file}" > "${tmp_file}" || true
    fi

    printf 'export %s=%q\n' "${key}" "${value}" >> "${tmp_file}"
    cat "${tmp_file}" > "${file}"
    rm -f "${tmp_file}"
}

configure_jvm_runtime_env() {
    # Apply JVM memory controls to Hadoop env files at runtime.
    # 在运行时向 Hadoop 环境脚本注入 JVM 内存限制。
    upsert_export_var "${HADOOP_CONF_DIR}/hadoop-env.sh" HADOOP_HEAPSIZE_MAX "${HADOOP_HEAPSIZE_MAX}"
    upsert_export_var "${HADOOP_CONF_DIR}/hadoop-env.sh" HADOOP_NAMENODE_OPTS "${HADOOP_NAMENODE_OPTS}"
    upsert_export_var "${HADOOP_CONF_DIR}/hadoop-env.sh" HADOOP_DATANODE_OPTS "${HADOOP_DATANODE_OPTS}"
    upsert_export_var "${HADOOP_CONF_DIR}/hadoop-env.sh" HADOOP_SECONDARYNAMENODE_OPTS "${HADOOP_SECONDARYNAMENODE_OPTS}"
    upsert_export_var "${HADOOP_CONF_DIR}/yarn-env.sh" YARN_RESOURCEMANAGER_OPTS "${YARN_RESOURCEMANAGER_OPTS}"
    upsert_export_var "${HADOOP_CONF_DIR}/yarn-env.sh" YARN_NODEMANAGER_OPTS "${YARN_NODEMANAGER_OPTS}"
    upsert_export_var "${HADOOP_CONF_DIR}/mapred-env.sh" MAPRED_HISTORYSERVER_OPTS "${MAPRED_HISTORYSERVER_OPTS}"
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
    local shared_private_key
    local shared_public_key
    local shared_authorized_keys
    local pub_key
    local ssh_dir
    local sync_hadoop_ssh
    local owner
    local group

    # Ensure runtime directories for sshd and ssh key materials.
    # 确保 sshd 与 ssh 密钥运行目录存在。
    mkdir -p /run/sshd /root/.ssh "${SSH_SHARED_DIR}"
    chmod 700 /root/.ssh "${SSH_SHARED_DIR}"

    sync_hadoop_ssh="false"
    if id -u hadoop >/dev/null 2>&1 && mkdir -p /home/hadoop/.ssh >/dev/null 2>&1; then
        chmod 700 /home/hadoop/.ssh >/dev/null 2>&1 || true
        if [[ -w /home/hadoop/.ssh ]]; then
            sync_hadoop_ssh="true"
        else
            log "Skip syncing /home/hadoop/.ssh: not writable under current dropped capabilities"
        fi
    fi

    # Generate host keys at runtime so published images never contain private keys.
    # 运行期生成 host key，避免公开镜像层中固化私钥。
    if [[ ! -s /etc/ssh/ssh_host_rsa_key ]]; then
        log "Generating SSH host keys"
        ssh-keygen -A
    fi

    # Share one cluster keypair across all nodes via named volume.
    # 通过命名卷在所有节点共享同一套 SSH 密钥。
    shared_private_key="${SSH_SHARED_DIR}/id_rsa"
    shared_public_key="${SSH_SHARED_DIR}/id_rsa.pub"
    shared_authorized_keys="${SSH_SHARED_DIR}/authorized_keys"

    if [[ ! -s "${shared_private_key}" || ! -s "${shared_public_key}" ]]; then
        log "Generating shared SSH keypair in ${SSH_SHARED_DIR}"
        ssh-keygen -t rsa -b 4096 -f "${shared_private_key}" -N ""
    fi

    touch "${shared_authorized_keys}"
    pub_key="$(cat "${shared_public_key}")"
    if ! grep -qxF "${pub_key}" "${shared_authorized_keys}"; then
        printf '%s\n' "${pub_key}" >> "${shared_authorized_keys}"
    fi
    chmod 600 "${shared_private_key}" "${shared_authorized_keys}"
    chmod 644 "${shared_public_key}"

    # Sync shared keys to root and hadoop users for start-*.sh compatibility.
    # 将共享密钥同步到 root 与 hadoop 用户目录，兼容 start-*.sh 场景。
    for ssh_dir in /root/.ssh /home/hadoop/.ssh; do
        if [[ "${ssh_dir}" == "/home/hadoop/.ssh" ]] && [[ "${sync_hadoop_ssh}" != "true" ]]; then
            continue
        fi

        cp -f "${shared_private_key}" "${ssh_dir}/id_rsa"
        cp -f "${shared_public_key}" "${ssh_dir}/id_rsa.pub"
        cp -f "${shared_authorized_keys}" "${ssh_dir}/authorized_keys"

        cat > "${ssh_dir}/config" <<EOF
Host *
    StrictHostKeyChecking accept-new
EOF

        chmod 600 "${ssh_dir}/id_rsa" "${ssh_dir}/authorized_keys" "${ssh_dir}/config"
        chmod 644 "${ssh_dir}/id_rsa.pub"

        if [[ "${ssh_dir}" == "/root/.ssh" ]]; then
            owner="root"
            group="root"
        else
            owner="hadoop"
            group="hadoop"
        fi
        chown -R "${owner}:${group}" "${ssh_dir}" >/dev/null 2>&1 || true
    done

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
export HADOOP_HEAPSIZE_MAX="${HADOOP_HEAPSIZE_MAX}"
export HADOOP_NAMENODE_OPTS="${HADOOP_NAMENODE_OPTS}"
export HADOOP_DATANODE_OPTS="${HADOOP_DATANODE_OPTS}"
export HADOOP_SECONDARYNAMENODE_OPTS="${HADOOP_SECONDARYNAMENODE_OPTS}"
export YARN_RESOURCEMANAGER_OPTS="${YARN_RESOURCEMANAGER_OPTS}"
export YARN_NODEMANAGER_OPTS="${YARN_NODEMANAGER_OPTS}"
export MAPRED_HISTORYSERVER_OPTS="${MAPRED_HISTORYSERVER_OPTS}"
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
    if [[ "${HADOOP_DAEMON_USER}" == "root" ]]; then
        bash -lc "${ROOT_DAEMON_ENV} ${cmd}"
        return
    fi
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
    local runtime_dirs
    local dir
    runtime_dirs=(
        "${HADOOP_LOG_DIR}"
        "${HADOOP_TMP_DIR}"
        "${HDFS_NAMENODE_NAME_DIR}"
        "${HDFS_DATANODE_DATA_DIR}"
        "${YARN_NODEMANAGER_LOCAL_DIR}"
        "${YARN_NODEMANAGER_LOG_DIR}"
        "${MAPRED_HISTORY_TMP_DIR}"
        "${MAPRED_HISTORY_DONE_DIR}"
    )

    mkdir -p \
        "${runtime_dirs[@]}"

    # With dropped Linux capabilities, recursive chown can fail on bind-mounts.
    # Use group+mode alignment first, then verify daemon-user writability.
    # 在能力裁剪下 bind-mount 上 chown 可能失败，优先调整组与权限位。
    for dir in "${runtime_dirs[@]}"; do
        chgrp -R "${HADOOP_DAEMON_USER}" "${dir}" >/dev/null 2>&1 || true
        chmod -R ug+rwX "${dir}" >/dev/null 2>&1 || true

        # If group alignment is blocked on bind-mount metadata, open write bit
        # for others to keep daemon user non-root in constrained containers.
        # 若 bind-mount 元数据导致组授权失败，则放开 other 写位保证降权可运行。
        if [[ "${HADOOP_DAEMON_USER}" != "root" ]] && ! su -s /bin/bash -c "test -w \"${dir}\"" "${HADOOP_DAEMON_USER}" >/dev/null 2>&1; then
            chmod -R a+rwX "${dir}" >/dev/null 2>&1 || true
        fi
    done
}

ensure_daemon_user_writable() {
    local check_paths
    local p

    if [[ "${HADOOP_DAEMON_USER}" == "root" ]]; then
        return
    fi

    if ! id -u "${HADOOP_DAEMON_USER}" >/dev/null 2>&1; then
        log "Daemon user ${HADOOP_DAEMON_USER} not found, fallback to root"
        HADOOP_DAEMON_USER="root"
        return
    fi

    if ! su -s /bin/bash -c "id -u >/dev/null" "${HADOOP_DAEMON_USER}" >/dev/null 2>&1; then
        log "Cannot switch to daemon user ${HADOOP_DAEMON_USER} under current capabilities, fallback to root"
        HADOOP_DAEMON_USER="root"
        return
    fi

    check_paths=(
        "${HADOOP_LOG_DIR}"
        "${HADOOP_TMP_DIR}"
        "${HDFS_NAMENODE_NAME_DIR}"
        "${HDFS_DATANODE_DATA_DIR}"
        "${YARN_NODEMANAGER_LOCAL_DIR}"
        "${YARN_NODEMANAGER_LOG_DIR}"
        "${MAPRED_HISTORY_TMP_DIR}"
        "${MAPRED_HISTORY_DONE_DIR}"
    )

    for p in "${check_paths[@]}"; do
        if ! su -s /bin/bash -c "test -w \"${p}\"" "${HADOOP_DAEMON_USER}" >/dev/null 2>&1; then
            log "Daemon user ${HADOOP_DAEMON_USER} cannot write ${p}, fallback to root"
            HADOOP_DAEMON_USER="root"
            return
        fi
    done
}

wait_for_namenode() {
    local i
    if [[ "${NODE_ROLE}" == "namenode" ]]; then
        return
    fi

    log "Waiting for NameNode HTTP/RPC readiness on ${NAMENODE_HOST}:${NAMENODE_HTTP_PORT}/${NAMENODE_RPC_PORT}"
    for ((i = 1; i <= WAIT_FOR_NAMENODE_RETRIES; i++)); do
        if curl -fsS "http://${NAMENODE_HOST}:${NAMENODE_HTTP_PORT}/" >/dev/null 2>&1 && \
            hdfs dfsadmin -fs "hdfs://${NAMENODE_HOST}:${NAMENODE_RPC_PORT}" -safemode get >/dev/null 2>&1; then
            log "NameNode HTTP and RPC are reachable"
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
    local current_dir
    local version_marker

    current_dir="${HDFS_NAMENODE_NAME_DIR}/current"
    version_marker="${HDFS_NAMENODE_NAME_DIR}/.formatted_by_image_version"

    if [[ "${AUTO_FORMAT}" == "true" ]]; then
        if [[ ! -d "${current_dir}" ]]; then
            log "NameNode metadata not found, formatting..."
            run_as_daemon_user "hdfs namenode -format -nonInteractive"
            printf '%s\n' "${HADOOP_VERSION}" > "${version_marker}" || true
        elif [[ ! -f "${version_marker}" ]] || [[ "$(cat "${version_marker}" 2>/dev/null || true)" != "${HADOOP_VERSION}" ]]; then
            log "Detected metadata from different/unknown image version, reformatting NameNode metadata"
            rm -rf "${HDFS_NAMENODE_NAME_DIR:?}"/*
            mkdir -p "${HDFS_NAMENODE_NAME_DIR}"
            run_as_daemon_user "hdfs namenode -format -nonInteractive"
            printf '%s\n' "${HADOOP_VERSION}" > "${version_marker}" || true
        else
            log "NameNode metadata exists, skipping format"
        fi
    else
        log "AUTO_FORMAT=false, skipping format"
    fi
}

reset_datanode_data_if_needed() {
    local current_dir
    local version_marker

    if [[ "${AUTO_RESET_DATANODE_DATA_ON_VERSION_CHANGE}" != "true" ]]; then
        return
    fi

    current_dir="${HDFS_DATANODE_DATA_DIR}/current"
    version_marker="${HDFS_DATANODE_DATA_DIR}/.formatted_by_image_version"

    if [[ ! -d "${current_dir}" ]]; then
        printf '%s\n' "${HADOOP_VERSION}" > "${version_marker}" || true
        return
    fi

    if [[ ! -f "${version_marker}" ]] || [[ "$(cat "${version_marker}" 2>/dev/null || true)" != "${HADOOP_VERSION}" ]]; then
        log "Detected DataNode data from different/unknown image version, resetting ${HDFS_DATANODE_DATA_DIR}"
        rm -rf "${HDFS_DATANODE_DATA_DIR:?}"/*
        mkdir -p "${HDFS_DATANODE_DATA_DIR}"
    fi

    printf '%s\n' "${HADOOP_VERSION}" > "${version_marker}" || true
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
configure_jvm_runtime_env
ensure_ssh_runtime_env
prepare_runtime_dirs
ensure_daemon_user_writable
reset_datanode_data_if_needed
start_sshd
wait_for_namenode
start_role_daemons

# Keep container alive by waiting on sshd foreground process.
# 通过等待 sshd 进程保持容器存活。
wait "${SSHD_PID}"
