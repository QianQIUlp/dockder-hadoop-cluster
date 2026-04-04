# ==============================================================================
# Base Image
# 使用 Ubuntu 22.04 LTS 作为底层系统
# ==============================================================================
FROM ubuntu:22.04

# 设置环境变量，防止在 apt-get install 时出现交互式前台提示
ENV DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# System Dependencies & Mirror Configuration
# 替换为阿里云镜像源并安装基础依赖
# ==============================================================================
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget git vim openssh-server openjdk-8-jdk net-tools telnet iputils-ping && \
    # 生成 SSH 主机密钥 (供 sshd 服务使用)
    ssh-keygen -A && \
    # 提前创建 sshd 运行所需的运行时目录
    mkdir -p /run/sshd && chmod 755 /run/sshd && \
    # 清理 apt 缓存以缩减镜像体积
    rm -rf /var/lib/apt/lists/*

# 设置 Java 环境变量
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# ==============================================================================
# Hadoop Installation
# 从华为开源镜像站拉取 Hadoop 3.3.4
# ==============================================================================
ENV HADOOP_VERSION=3.3.4
ENV HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

RUN wget -q -P /opt https://repo.huaweicloud.com/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    tar -zxvf /opt/hadoop-${HADOOP_VERSION}.tar.gz -C /opt && \
    rm -rf /opt/*.tar.gz

# ==============================================================================
# Hadoop Configuration
# 集中写入 Hadoop 的核心配置文件
# ==============================================================================
# 1. 配置 Hadoop 环境变量及 Root 运行权限许可
RUN echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/yarn-env.sh && \
    echo "export JAVA_HOME=${JAVA_HOME}" >> ${HADOOP_HOME}/etc/hadoop/mapred-env.sh && \
    echo "export HDFS_NAMENODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_DATANODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_SECONDARYNAMENODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_RESOURCEMANAGER_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_NODEMANAGER_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh

# 2. 配置 XML 文件 (利用 EOF 语法直接写入内容)
RUN cat > ${HADOOP_HOME}/etc/hadoop/core-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>fs.defaultFS</name><value>hdfs://hadoop1:9000</value></property>
    <property><name>hadoop.tmp.dir</name><value>/opt/hadoop-${HADOOP_VERSION}/tmp</value></property>
    <property><name>hadoop.proxyuser.root.hosts</name><value>*</value></property>
    <property><name>hadoop.proxyuser.root.groups</name><value>*</value></property>
</configuration>
EOF

RUN cat > ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>dfs.replication</name><value>3</value></property>
    <property><name>dfs.namenode.secondary.http-address</name><value>hadoop3:50090</value></property>
    <property><name>dfs.namenode.http-address</name><value>0.0.0.0:50070</value></property>
</configuration>
EOF

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

RUN cat > ${HADOOP_HOME}/etc/hadoop/mapred-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>mapreduce.framework.name</name><value>yarn</value></property>
    <property><name>mapreduce.jobhistory.address</name><value>hadoop3:10020</value></property>
    <property><name>mapreduce.jobhistory.webapp.address</name><value>0.0.0.0:19888</value></property>
    <property><name>mapreduce.application.classpath</name><value>${HADOOP_HOME}/share/hadoop/mapreduce/*:${HADOOP_HOME}/share/hadoop/mapreduce/lib/*</value></property>
</configuration>
EOF

RUN cat > ${HADOOP_HOME}/etc/hadoop/workers << EOF
hadoop1
hadoop2
hadoop3
EOF

# ==============================================================================
# SSH & Security Configuration
# 配置免密登录及修复 SSHD 行为
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
# 将 sshd 设置为主进程在前台运行，保持容器存活
# ==============================================================================
EXPOSE 22 9000 50070 8088 19888 50090
CMD ["/usr/sbin/sshd", "-D"]