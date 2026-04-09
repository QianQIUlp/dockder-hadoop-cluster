# 🐳 Docker-Hadoop-Cluster

![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg?logo=docker)
![Hadoop](https://img.shields.io/badge/Hadoop-3.3.4-yellow.svg?logo=apache)
![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)

This project provides a one-click solution to build a Hadoop 3.3.4 fully distributed cluster based on a lighter Java runtime image using Docker and Docker Compose. Compared with the previous Ubuntu + full JDK setup, the resulting image is significantly smaller. It is highly suitable for big data beginners, experimental environment setup, and cluster testing.

> Note: To keep the image lean, debugging tools such as git, vim, net-tools, telnet, and ping are no longer preinstalled by default. Install them inside the container only when needed.

This is also my first Git project. I am currently learning about Linux, Git, Hadoop, and Docker, and I hope we can make progress together!

## 🏗️ Cluster Architecture Design

This project contains 3 nodes, fully simulating an enterprise-level distributed deployment structure:

| Hostname | Core Roles |
| :--- | :--- |
| **hadoop1** | `NameNode`, `DataNode` |
| **hadoop2** | `ResourceManager`, `NodeManager`, `DataNode` |
| **hadoop3** | `SecondaryNameNode`, `JobHistoryServer`, `DataNode` |

> **Note**: Since all 3 containers are built from the exact same Docker image, they generate identical SSH key pairs during the build phase. Therefore, passwordless root SSH login between nodes is naturally supported without any extra configuration.

---

## 🌐 Port Mapping Guide

Once the cluster is up and running, you can directly access the native Hadoop Web UI dashboards via your host machine's (Windows/Mac) browser:

* **HDFS NameNode UI**: http://localhost:50070
* **YARN ResourceManager UI**: http://localhost:8088
* **SecondaryNameNode UI**: http://localhost:50090
* **JobHistory UI**: http://localhost:19888

---

## 🚀 Quick Start

Please ensure that Git, Docker, and Docker Compose are installed on your host machine.

### 1. Clone the repository
```bash
git clone git@github.com:YourUsername/docker-hadoop-cluster.git
cd docker-hadoop-cluster
```

### 2. Build and start the cluster
```bash!
# Automatically build images and pull up 3 nodes in the background
docker compose up -d --build
```
### 3. Initialize and Start Hadoop
#### 3.1 Start NameNode and HDFS (Execute on `hadoop1`)
Enter the terminal of the master node `hadoop1`:
```bash!
docker exec -it hadoop1 bash
```
Inside `hadoop1`, format the filesystem and start HDFS:
```bash!
# Format the NameNode (Only required for the first startup)
hdfs namenode -format

start-dfs.sh
```

#### 3.2 Start YARN ResourceManager (Execute on `hadoop2`)
Open a new terminal on your host machine and enter the `hadoop2` container:
```bash!
# Method 1: Enter via docker
docker exec -it hadoop2 bash

# Method 2: Enter via SSH (requires knowing the container IP)
ssh root@hadoop2
```
After entering `hadoop2`, start YARN:
```bash!
start-yarn.sh
```

#### 3.3 Start JobHistoryServer (Execute on `hadoop3`, Optional)
Enter the `hadoop3` container and start the JobHistoryServer:
```bash!
# Method 1: Enter via docker
docker exec -it hadoop3 bash

# Method 2: Enter via SSH
ssh root@hadoop3

# Start the JobHistoryServer
mapred --daemon start historyserver
```

Use the `jps` command on each node to verify that all processes are running correctly.

### 4. Cleanup and Shutdown Cluster
When you want to stop and remove all containers, execute the following command on your host machine:
```bash!
# Stop all containers and remove them along with the network (images and data are preserved)
docker compose down
```

If you also want to remove the data volumes:
```bash!
# Also remove data volumes
docker compose down -v
```