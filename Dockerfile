#
# Copyright 2026 qianqiulp
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# ======================================================================
# Stage 1: Build Hadoop runtime payload
# 阶段 1：构建 Hadoop 运行时载荷
# - Download Hadoop once in builder stage.
# - 在构建阶段下载 Hadoop，避免在最终镜像保留下载工具。
# ======================================================================
FROM eclipse-temurin:8-jdk-jammy AS hadoop-builder

ARG HADOOP_VERSION=3.3.4
ARG HADOOP_BASE_URL=https://repo.huaweicloud.com/apache/hadoop/common
ARG HADOOP_TARBALL_SHA512=""

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL "${HADOOP_BASE_URL}/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz" -o /tmp/hadoop.tar.gz && \
    if [ -z "${HADOOP_TARBALL_SHA512}" ]; then \
        echo "ERROR: HADOOP_TARBALL_SHA512 is required"; \
        exit 1; \
    fi && \
    echo "${HADOOP_TARBALL_SHA512}  /tmp/hadoop.tar.gz" | sha512sum -c - && \
    tar -xzf /tmp/hadoop.tar.gz -C /opt && \
    mv /opt/hadoop-${HADOOP_VERSION} /opt/hadoop && \
    rm -f /tmp/hadoop.tar.gz && \
    rm -rf /opt/hadoop/share/doc && \
    find /opt/hadoop/share/hadoop -type d \( -name sources -o -name jdiff \) -prune -exec rm -rf {} + && \
    rm -rf /opt/hadoop/share/hadoop/mapreduce/lib-examples

# ======================================================================
# Stage 2: Runtime image
# 阶段 2：运行时镜像
# - Keep only Hadoop + sshd + minimal runtime tools.
# - 仅保留 Hadoop、sshd 与最小运行工具。
# ======================================================================
FROM eclipse-temurin:8-jdk-jammy

ARG HADOOP_VERSION=3.3.4

ENV DEBIAN_FRONTEND=noninteractive \
    JAVA_HOME=/opt/java/openjdk \
    HADOOP_VERSION=${HADOOP_VERSION} \
    HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION} \
    HADOOP_CONF_DIR=/opt/hadoop-${HADOOP_VERSION}/etc/hadoop \
    HADOOP_CONF_TEMPLATE_DIR=/opt/hadoop-conf-template \
    HADOOP_LOG_DIR=/hadoop/logs \
    PATH=/opt/java/openjdk/bin:/opt/hadoop-${HADOOP_VERSION}/bin:/opt/hadoop-${HADOOP_VERSION}/sbin:${PATH}

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server bash procps ca-certificates gettext-base && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd --gid 10001 hadoop && \
    useradd --uid 10001 --gid hadoop --create-home --home-dir /home/hadoop --shell /bin/bash hadoop && \
    mkdir -p /run/sshd /root/.ssh /home/hadoop/.ssh /hadoop/dfs/name /hadoop/dfs/data /hadoop/yarn/local /hadoop/yarn/logs /hadoop/mr-history/tmp /hadoop/mr-history/done /hadoop/tmp /hadoop/logs ${HADOOP_CONF_TEMPLATE_DIR}

# Copy Hadoop binaries from builder stage.
# 从构建阶段复制 Hadoop 二进制。
COPY --from=hadoop-builder /opt/hadoop ${HADOOP_HOME}

# Keep only Hadoop config directory writable for runtime template rendering.
# 仅放开 Hadoop 配置目录写权限，避免复制整棵目录产生超大重复层。
RUN chown -R root:root ${HADOOP_CONF_DIR} && \
    chmod -R u+rwX,go+rX ${HADOOP_CONF_DIR}

# Copy config templates to template directory.
# 复制配置模板到模板目录（真正生效配置由 entrypoint 渲染）。
COPY conf/ ${HADOOP_CONF_TEMPLATE_DIR}/

# Copy startup script.
# 复制统一启动脚本。
COPY entrypoint.sh /entrypoint.sh

# Configure SSH and Hadoop runtime defaults.
# 配置 SSH 与 Hadoop 运行时默认行为。
RUN chmod +x /entrypoint.sh && \
    mkdir -p /root/.ssh && \
    mkdir -p /home/hadoop/.ssh && \
    chmod 700 /root/.ssh && \
    chmod 700 /home/hadoop/.ssh && \
    printf 'Host *\n    StrictHostKeyChecking accept-new\n' > /root/.ssh/config && \
    chmod 600 /root/.ssh/config && \
    sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?UseDNS\s+.*/UseDNS no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?GSSAPIAuthentication\s+.*/GSSAPIAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PermitUserEnvironment\s+.*/PermitUserEnvironment no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PubkeyAuthentication\s+.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    printf 'export JAVA_HOME=%s\nexport HADOOP_HOME=%s\nexport HADOOP_CONF_DIR=%s\n' "${JAVA_HOME}" "${HADOOP_HOME}" "${HADOOP_CONF_DIR}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    printf 'export HDFS_NAMENODE_USER=hadoop\nexport HDFS_DATANODE_USER=hadoop\nexport HDFS_SECONDARYNAMENODE_USER=hadoop\nexport YARN_RESOURCEMANAGER_USER=hadoop\nexport YARN_NODEMANAGER_USER=hadoop\n' >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    printf 'export JAVA_HOME=%s\n' "${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/yarn-env.sh && \
    printf 'export JAVA_HOME=%s\n' "${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/mapred-env.sh && \
    chown -R hadoop:hadoop ${HADOOP_HOME} /hadoop /home/hadoop/.ssh

EXPOSE 22 9000 50070 8088 19888 50090

ENTRYPOINT ["/entrypoint.sh"]