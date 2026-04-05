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

# ==============================================================================
# Base Image
# 国内用户记得使用镜像加速
# ==============================================================================
FROM ubuntu:22.04

# Prevent interactive prompts during apt-get install | 设置环境变量，防止在 apt-get install 时出现交互式前台提示
ENV DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# System Dependencies
# Install basic tools and dependencies | 安装基础依赖
# ==============================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget git vim openssh-server openjdk-8-jdk net-tools telnet iputils-ping && \
    # Generate SSH host keys | 生成 SSH 主机密钥 (供 sshd 服务使用)
    ssh-keygen -A && \
    # Create sshd run directory to prevent startup failures | 提前创建 sshd 运行时目录，防止集群其他节点 sshd 启动失败
    mkdir -p /run/sshd && chmod 755 /run/sshd && \
    rm -rf /var/lib/apt/lists/*

# Configure Java environment variables | 配置Java环境变量（使用默认的路径）
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# ==============================================================================
# Hadoop Installation
# ==============================================================================
ENV HADOOP_VERSION=3.3.4
ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

RUN wget -q -P /opt https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -zxvf /opt/hadoop-${HADOOP_VERSION}.tar.gz -C /opt && \
    rm -rf /opt/*.tar.gz

# ==============================================================================
# Hadoop Configuration
# ==============================================================================
# Configure Hadoop env and allow root execution | 配置 Hadoop 环境变量及 root 运行权限许可
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/yarn-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/mapred-env.sh && \
    echo "export HDFS_NAMENODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_DATANODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_SECONDARYNAMENODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_RESOURCEMANAGER_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_NODEMANAGER_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh

# Sync env vars to /etc/profile for SSH logins | 将环境变量同步到 /etc/profile 中，确保 SSH 登录后也能加载
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> /etc/profile && \
    echo "export HADOOP_HOME=${HADOOP_HOME}" >> /etc/profile && \
    echo "export PATH=\$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin" >> /etc/profile

# Configure core-site.xml: NameNode=hadoop1, temp dir, root proxy | 配置 core-site.xml
RUN cat > ${HADOOP_HOME}/etc/hadoop/core-site.xml << EOF
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

# ==============================================================================
# SSH & Security Configuration
# ==============================================================================
RUN ssh-keygen -t rsa -f /root/.ssh/id_rsa -P "" && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config && \
    sed -i 's/#GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config

# ==============================================================================
# Entrypoint
# Run sshd in foreground to keep container alive | 将 sshd 设置为主进程在前台运行，保持容器存活
# ==============================================================================
# Expose SSH and Hadoop Web UI ports | 暴露 SSH、Hadoop Web UI 等端口方便访问
EXPOSE 22 9000 50070 8088 19888 50090
CMD ["/usr/sbin/sshd", "-D"]