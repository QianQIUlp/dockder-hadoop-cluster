FROM ubuntu:22.04

RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl wget git vim openssh-server openjdk-8-jdk net-tools telnet iputils-ping && \
    ssh-keygen -A && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH=$PATH:$JAVA_HOME/bin

# ==========================
# HADOOP 3.3.4
# ==========================
RUN wget -P /opt https://repo.huaweicloud.com/apache/hadoop/common/hadoop-3.3.4/hadoop-3.3.4.tar.gz && \
    tar -zxvf /opt/hadoop-3.3.4.tar.gz -C /opt && \
    rm -rf /opt/*.tar.gz

ENV HADOOP_HOME=/opt/hadoop-3.3.4
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin

# ==========================
# Hadoop configuration
# ==========================

#配置JAVA_HOME
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> $HADOOP_HOME/etc/hadoop/yarn-env.sh
RUN echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> $HADOOP_HOME/etc/hadoop/mapred-env.sh

#在hadoop-env.sh中添加root启动权限
RUN echo "export HDFS_NAMENODE_USER=\"root\"" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh
RUN echo "export HDFS_DATANODE_USER=\"root\"" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh
RUN echo "export HDFS_SECONDARYNAMENODE_USER=\"root\"" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh
RUN echo "export YARN_RESOURCEMANAGER_USER=\"root\"" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh
RUN echo "export YARN_NODEMANAGER_USER=\"root\"" >> $HADOOP_HOME/etc/hadoop/hadoop-env.sh

#配置core-site.xml
RUN cat > $HADOOP_HOME/etc/hadoop/core-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <!--指定HDFS中NameNode的地址-->
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://hadoop1:9000</value>
    </property>
    <!--指定Hadoop运⾏时产⽣⽂件的存储路径-->
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/opt/hadoop-3.3.4/tmp</value>
    </property>
    <property>
        <name>hadoop.proxyuser.root.hosts</name>
        <value>*</value>
    </property>
    <property>
        <name>hadoop.proxyuser.root.groups</name>
        <value>*</value>
    </property>
</configuration>
EOF

#配置hdfs-site.xml
RUN cat > $HADOOP_HOME/etc/hadoop/hdfs-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <!--指定HDFS副本的数量-->
    <property>
        <name>dfs.replication</name>
        <value>3</value>
    </property>
    <!--指定Hadoop Secondary NameNode配置-->
    <property>
        <name>dfs.namenode.secondary.http-address</name>
        <value>hadoop3:50090</value>
    </property>
    <!--NaneNode的Web端地址-->
    <property>
        <name>dfs.namenode.http-address</name>
        <value>0.0.0.0:50070</value>
    </property>
</configuration>
EOF

#配置yarn-site.xml
RUN cat > $HADOOP_HOME/etc/hadoop/yarn-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <!--YARN的ResourceManager的地址-->
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>hadoop2</value>
    </property>
    <!--Reducer获取数据的⽅式-->
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <!--YARN的ResourceManager的Web端地址-->
    <property>
	<name>yarn.resourcemanager.webapp.address</name>
	<value>0.0.0.0:8088</value>
    </property>
    <!--⽇志聚合功能使能-->
    <property>
	<name>yarn.log-aggregation-enable</name>
	<value>true</value>
    </property>
    <!--⽇志保留时间，设置为七天-->
    <property>
	<name>yarn.log-aggregation.retain-seconds</name>
	<value>604800</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>yarn.nodemanager.pmem-check-enabled</name>
        <value>false</value>
    </property>
</configuration>
EOF

#配置mapred-site.xml
RUN cat > $HADOOP_HOME/etc/hadoop/mapred-site.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <!--指定MapReduce运⾏在Yarn上-->
    <property>
	<name>mapreduce.framework.name</name>
	<value>yarn</value>
    </property>
    <!--历史服务器端地址--> 
    <property>
	<name>mapreduce.jobhistory.address</name>
	<value>hadoop3:10020</value>
    </property>
    <!--历史服务器Web端地址-->
    <property>
	<name>mapreduce.jobhistory.webapp.address</name>
	<value>0.0.0.0:19888</value>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
</configuration>
EOF

#配置workers
RUN cat > $HADOOP_HOME/etc/hadoop/workers << EOF
hadoop1
hadoop2
hadoop3
EOF

# ==========================
# SSH免密与服务配置
# ==========================
# 生成统一密钥对，严格设置权限（sshd强制要求，否则拒绝认证）
RUN ssh-keygen -t rsa -f /root/.ssh/id_rsa -P "" && \
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# 修复SSH配置：允许root登录，关闭DNS解析加速连接
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config && \
    sed -i 's/#GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/sshd_config

# 前台稳定启动sshd，保持容器不退出
CMD ["/bin/bash", "-c", "mkdir -p /run/sshd && chmod 755 /run/sshd && /usr/sbin/sshd -D & tail -f /dev/null"]

