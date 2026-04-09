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

FROM ubuntu:22.04

ARG HADOOP_VERSION=2.7.2
ARG HADOOP_ARCHIVE=hadoop-2.7.2.tar.gz
ARG JDK_ARCHIVE=jdk-8u144-linux-x64.tar.gz

ENV DEBIAN_FRONTEND=noninteractive \
    JAVA_HOME=/opt/jdk8u144 \
    HADOOP_VERSION=${HADOOP_VERSION} \
    HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION} \
    HADOOP_CONF_DIR=/opt/hadoop-${HADOOP_VERSION}/etc/hadoop \
    HADOOP_CONF_TEMPLATE_DIR=/opt/hadoop-conf-template \
    PATH=/opt/jdk8u144/bin:/opt/hadoop-${HADOOP_VERSION}/bin:/opt/hadoop-${HADOOP_VERSION}/sbin:${PATH}

RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server bash procps ca-certificates gettext-base tar && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/sshd /root/.ssh /hadoop/dfs/name /hadoop/dfs/data /hadoop/yarn/local /hadoop/yarn/logs /hadoop/mr-history/tmp /hadoop/mr-history/done /hadoop/tmp ${HADOOP_CONF_TEMPLATE_DIR}

# Copy local offline packages from repository root.
# 从仓库根目录复制离线安装包。
COPY ${HADOOP_ARCHIVE} /tmp/hadoop.tar.gz
COPY ${JDK_ARCHIVE} /tmp/jdk.tar.gz

# Install JDK 8u144 and Hadoop 2.7.2 from local tarballs.
# 从本地压缩包安装 JDK 8u144 与 Hadoop 2.7.2。
RUN set -eux; \
    tar -xzf /tmp/jdk.tar.gz -C /opt; \
    jdk_dir="$(find /opt -maxdepth 1 -mindepth 1 -type d -name 'jdk*' | head -n 1)"; \
    test -n "${jdk_dir}"; \
    mv "${jdk_dir}" "${JAVA_HOME}"; \
    tar -xzf /tmp/hadoop.tar.gz -C /opt; \
    if [ ! -d "${HADOOP_HOME}" ]; then \
        extracted_hadoop_dir="$(find /opt -maxdepth 1 -mindepth 1 -type d -name 'hadoop*' | sort | head -n 1)"; \
        test -n "${extracted_hadoop_dir}"; \
        mv "${extracted_hadoop_dir}" "${HADOOP_HOME}"; \
    fi; \
    chown -R root:root "${JAVA_HOME}" "${HADOOP_HOME}"; \
    chmod -R u+rwX "${HADOOP_HOME}"; \
    rm -f /tmp/jdk.tar.gz /tmp/hadoop.tar.gz

# Copy config templates to template directory.
# 复制配置模板到模板目录（真正生效配置由 entrypoint 渲染）。
COPY conf/ ${HADOOP_CONF_TEMPLATE_DIR}/

# Copy startup script.
# 复制统一启动脚本。
COPY entrypoint.sh /entrypoint.sh

# Configure SSH and Hadoop runtime defaults.
# 配置 SSH 与 Hadoop 运行时默认行为。
RUN chmod +x /entrypoint.sh && \
    ssh-keygen -A && \
    ssh-keygen -t rsa -f /root/.ssh/id_rsa -N "" && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys && \
    printf 'Host *\n    StrictHostKeyChecking no\n    UserKnownHostsFile /dev/null\n' > /root/.ssh/config && \
    chmod 600 /root/.ssh/config && \
    sed -ri 's/^#?PermitRootLogin\s+.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?UseDNS\s+.*/UseDNS no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?GSSAPIAuthentication\s+.*/GSSAPIAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PasswordAuthentication\s+.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -ri 's/^#?PubkeyAuthentication\s+.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    grep -q '^PermitUserEnvironment yes$' /etc/ssh/sshd_config || echo 'PermitUserEnvironment yes' >> /etc/ssh/sshd_config && \
    printf 'export JAVA_HOME=%s\nexport HADOOP_HOME=%s\nexport HADOOP_CONF_DIR=%s\n' "${JAVA_HOME}" "${HADOOP_HOME}" "${HADOOP_CONF_DIR}" >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    printf 'export HDFS_NAMENODE_USER=root\nexport HDFS_DATANODE_USER=root\nexport HDFS_SECONDARYNAMENODE_USER=root\nexport YARN_RESOURCEMANAGER_USER=root\nexport YARN_NODEMANAGER_USER=root\n' >> ${HADOOP_CONF_DIR}/hadoop-env.sh && \
    printf 'export JAVA_HOME=%s\n' "${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/yarn-env.sh && \
    printf 'export JAVA_HOME=%s\n' "${JAVA_HOME}" >> ${HADOOP_CONF_DIR}/mapred-env.sh

EXPOSE 22 9000 50070 8088 19888 50090

ENTRYPOINT ["/entrypoint.sh"]