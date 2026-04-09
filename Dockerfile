# Multi-stage build Dockerfile for Hadoop cluster with Temurin JDK + Aliyun mirrors
FROM eclipse-temurin:8-jdk-jammy AS hadoop-builder

ENV HADOOP_VERSION=3.3.4

RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates && \
    rm -rf /var/lib/apt/lists/* && \
    curl -fsSL https://repo.huaweicloud.com/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz -o /tmp/hadoop.tar.gz && \
    tar -xzf /tmp/hadoop.tar.gz -C /opt && \
    rm -f /tmp/hadoop.tar.gz

FROM eclipse-temurin:8-jdk-jammy

ENV DEBIAN_FRONTEND=noninteractive \
    JAVA_HOME=/opt/java/openjdk \
    HADOOP_VERSION=3.3.4 \
    HADOOP_HOME=/opt/hadoop-3.3.4 \
    PATH=$PATH:/opt/java/openjdk/bin:/opt/hadoop-3.3.4/bin:/opt/hadoop-3.3.4/sbin

RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends openssh-server && \
    mkdir -p /run/sshd /root/.ssh && chmod 755 /run/sshd && \
    rm -rf /var/lib/apt/lists/*

COPY --from=hadoop-builder /opt/hadoop-3.3.4 /opt/hadoop-3.3.4

RUN echo "export JAVA_HOME=/opt/java/openjdk" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export JAVA_HOME=/opt/java/openjdk" >> ${HADOOP_HOME}/etc/hadoop/yarn-env.sh && \
    echo "export JAVA_HOME=/opt/java/openjdk" >> ${HADOOP_HOME}/etc/hadoop/mapred-env.sh && \
    echo "export HDFS_NAMENODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_DATANODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export HDFS_SECONDARYNAMENODE_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_RESOURCEMANAGER_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export YARN_NODEMANAGER_USER=root" >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh && \
    echo "export JAVA_HOME=/opt/java/openjdk" >> /etc/profile && \
    echo "export HADOOP_HOME=${HADOOP_HOME}" >> /etc/profile && \
    echo "export PATH=\$PATH:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin" >> /etc/profile && \
    printf 'JAVA_HOME=/opt/java/openjdk\nHADOOP_HOME=%s\nPATH=%s/bin:%s/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n' "${HADOOP_HOME}" "${HADOOP_HOME}" "${HADOOP_HOME}" > /etc/environment && \
    printf 'export JAVA_HOME=/opt/java/openjdk\nexport HADOOP_HOME=%s\nexport PATH=$PATH:%s/bin:%s/sbin\n' "${HADOOP_HOME}" "${HADOOP_HOME}" "${HADOOP_HOME}" > /etc/profile.d/hadoop.sh && \
    cat > ${HADOOP_HOME}/etc/hadoop/core-site.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>fs.defaultFS</name><value>hdfs://hadoop1:9000</value></property>
    <property><name>hadoop.tmp.dir</name><value>/opt/hadoop-3.3.4/tmp</value></property>
    <property><name>hadoop.proxyuser.root.hosts</name><value>*</value></property>
    <property><name>hadoop.proxyuser.root.groups</name><value>*</value></property>
</configuration>
XMLEOF

RUN cat > ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>dfs.replication</name><value>3</value></property>
    <property><name>dfs.namenode.secondary.http-address</name><value>hadoop3:50090</value></property>
    <property><name>dfs.namenode.http-address</name><value>0.0.0.0:50070</value></property>
</configuration>
XMLEOF

RUN cat > ${HADOOP_HOME}/etc/hadoop/yarn-site.xml << 'XMLEOF'
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
XMLEOF

RUN cat > ${HADOOP_HOME}/etc/hadoop/mapred-site.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property><name>mapreduce.framework.name</name><value>yarn</value></property>
    <property><name>mapreduce.jobhistory.address</name><value>hadoop3:10020</value></property>
    <property><name>mapreduce.jobhistory.webapp.address</name><value>0.0.0.0:19888</value></property>
    <property><name>mapreduce.application.classpath</name><value>${HADOOP_HOME}/share/hadoop/mapreduce/*:${HADOOP_HOME}/share/hadoop/mapreduce/lib/*</value></property>
</configuration>
XMLEOF

RUN cat > ${HADOOP_HOME}/etc/hadoop/workers << 'XMLEOF'
hadoop1
hadoop2
hadoop3
XMLEOF

RUN ssh-keygen -A && \
    ssh-keygen -t rsa -f /root/.ssh/id_rsa -P "" && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config && \
    sed -i 's/#GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config

EXPOSE 22 9000 50070 8088 19888 50090
CMD ["/usr/sbin/sshd", "-D"]
