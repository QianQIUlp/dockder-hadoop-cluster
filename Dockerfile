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
# Build Stage
# 下载并解压 Hadoop，避免在运行时保留下载工具
# ======================================================================
FROM eclipse-temurin:8-jdk-jammy AS hadoop-builder

ENV HADOOP_VERSION=3.3.4

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL https://repo.huaweicloud.com/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz -o /tmp/hadoop.tar.gz && \
    tar -xzf /tmp/hadoop.tar.gz -C /opt && \
    rm -f /tmp/hadoop.tar.gz

# ======================================================================
# Runtime Image
# 国内用户记得使用镜像加速
# ======================================================================
FROM eclipse-temurin:8-jdk-jammy

# Prevent interactive prompts during apt-get install | 设置环境变量，防止在 apt-get install 时出现交互式前台提示
ENV DEBIAN_FRONTEND=noninteractive

ENV JAVA_HOME=/opt/java/openjdk
ENV HADOOP_VERSION=3.3.4
ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# ======================================================================
# System Dependencies
# Install only the runtime essentials | 只安装运行时必需组件
# ======================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends openssh-server && \
    mkdir -p /run/sshd /root/.ssh && chmod 755 /run/sshd && \
    rm -rf /var/lib/apt/lists/*

COPY --from=hadoop-builder /opt/hadoop-3.3.4 /opt/hadoop-3.3.4

# ======================================================================
# Hadoop Configuration
# ======================================================================
# Configure Hadoop env and allow root execution | 配置 Hadoop 环境变量及 root 运行权限许可
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/yarn-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/mapred-env.sh && \
    echo "export HDFS_NAMENODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_DATANODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_SECONDARYNAMENODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_RESOURCEMANAGER_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_NODEMANAGER_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/profile && \
    echo "export HADOOP_HOME=${HADOOP_HOME}" >> /etc/profile && \
    echo "export PATH=\$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin" >> /etc/profile && \
    printf 'JAVA_HOME=%s\nHADOOP_HOME=%s\nPATH=%s/bin:%s/sbin:%s\n' "${JAVA_HOME}" "${HADOOP_HOME}" "${JAVA_HOME}" "${HADOOP_HOME}" "${PATH}" > /etc/environment && \
    printf 'export JAVA_HOME=%s\nexport HADOOP_HOME=%s\nexport PATH=$PATH:%s/bin:%s/sbin\n' "${JAVA_HOME}" "${HADOOP_HOME}" "${HADOOP_HOME}" "${HADOOP_HOME}" > /etc/profile.d/hadoop.sh && \
    cat > ${HADOOP_HOME}/etc/hadoop/core-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>fs.defaultFS</name><value>hdfs://hadoop1:9000</value></property>
    <property><name>hadoop.tmp.dir</name><value>/opt/hadoop-${HADOOP_VERSION}/tmp</value></property>
    <property><name>hadoop.proxyuser.root.hosts</name><value>*</value></property>
    <property><name>hadoop.proxyuser.root.groups</name><value>*</value></property>
</configuration>
EOF

# Configure hdfs-site.xml: replication=3, NN & 2NN HTTP addresses | 配置 hdfs-site.xml
RUN cat > ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>dfs.replication</name><value>3</value></property>
    <property><name>dfs.namenode.secondary.http-address</name><value>hadoop3:50090</value></property>
    <property><name>dfs.namenode.http-address</name><value>0.0.0.0:50070</value></property>
</configuration>
EOF

# Configure yarn-site.xml: RM=hadoop2, enable log aggregation | 配置 yarn-site.xml
RUN cat > ${HADOOP_HOME}/etc/hadoop/yarn-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>yarn.resourcemanager.hostname</name><value>hadoop2</value></property>
    <property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
    <property><name>yarn.resourcemanager.webapp.address</name><value>0.0.0.0:8088</value></property>
    <property><name>yarn.log-aggregation-enable</name><value>true</value></property>
    <property><name>yarn.log-aggregation.retain-seconds</name><value>604800</value></property>
    <property><name>yarn.nodemanager.vmem-check-enabled</name><value>false</value></property>
    <property><name>yarn.nodemanager.pmem-check-enabled</name><value>false</value></property>
</configuration>
EOF

# Configure mapred-site.xml: MapReduce framework=YARN, JHS address | 配置 mapred-site.xml
RUN cat > ${HADOOP_HOME}/etc/hadoop/mapred-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>mapreduce.framework.name</name><value>yarn</value></property>
    <property><name>mapreduce.jobhistory.address</name><value>hadoop3:10020</value></property>
    <property><name>mapreduce.jobhistory.webapp.address</name><value>0.0.0.0:19888</value></property>
    <property><name>mapreduce.application.classpath</name><value>${HADOOP_HOME}/share/hadoop/mapreduce/*:${HADOOP_HOME}/share/hadoop/mapreduce/lib/*</value></property>
</configuration>
EOF

# Configure workers: Specify DataNodes and NodeManagers | 配置 workers 文件
RUN cat > ${HADOOP_HOME}/etc/hadoop/workers << EOF
hadoop1
hadoop2
hadoop3
EOF

# ======================================================================
# SSH & Security Configuration
# ======================================================================
RUN ssh-keygen -A && \
    ssh-keygen -t rsa -f /root/.ssh/id_rsa -P "" && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config && \
    sed -i 's/#GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config

# ======================================================================
# Entrypoint
# Run sshd in foreground to keep container alive | 将 sshd 设置为主进程在前台运行，保持容器存活
# ======================================================================
# Expose SSH and Hadoop Web UI ports | 暴露 SSH、Hadoop Web UI 等端口方便访问
EXPOSE 22 9000 50070 8088 19888 50090
CMD ["/usr/sbin/sshd", "-D"]