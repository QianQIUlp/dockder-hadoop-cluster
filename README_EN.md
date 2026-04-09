# 🐳 Docker-Hadoop-Cluster

![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg?logo=docker)
![Hadoop](https://img.shields.io/badge/Hadoop-3.3.4-yellow.svg?logo=apache)
![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)

This project provides a one-click solution to build a Hadoop 3.3.4 fully distributed cluster based on the Ubuntu 22.04 image using Docker and Docker Compose. It is highly suitable for big data beginners, experimental environment setup, and cluster testing.

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

#### 3.1 Start HDFS on hadoop1

**Method 1: Using docker exec (Recommended for quick operations)**
```bash
# Format the NameNode (Only required for the first startup)
docker exec -it hadoop1 hdfs namenode -format

# Start HDFS
docker exec -it hadoop1 start-dfs.sh
```

**Method 2: Using SSH remote login (Suitable for multi-step operations)**
```bash
# SSH login to hadoop1 (port 50001 for container's port 22)
ssh root@localhost -p 50001

# Or find the container's IP address first, then login
docker inspect hadoop1 | grep IPAddress
ssh root@<hadoop1-ip>

# Execute inside hadoop1
hdfs namenode -format
start-dfs.sh
```

#### 3.2 Start YARN on hadoop2

**Method 1: Using docker exec**
```bash
docker exec -it hadoop2 start-yarn.sh
```

**Method 2: Using SSH remote login**
```bash
ssh root@localhost -p 50002  # Or ssh root@<hadoop2-ip>
start-yarn.sh
```

#### 3.3 Start JobHistoryServer on hadoop3 (Optional)

**Method 1: Using docker exec**
```bash
docker exec -it hadoop3 mapred --daemon start historyserver
```

**Method 2: Using SSH remote login**
```bash
ssh root@localhost -p 50003  # Or ssh root@<hadoop3-ip>
mapred --daemon start historyserver
```

---

## 4️⃣ Cluster Cleanup and Shutdown

When you need to shut down the entire cluster, execute:

```bash
# Stop all services in Docker Compose, and remove containers and networks
docker compose down
```

**Optional**: If you also want to delete the built images, execute:
```bash
docker image rm hadoop-cluster:latest
```

> **Tip**: Using `docker compose down` is the recommended way to completely clean up the cluster. It will remove containers, networks, and volumes (if defined in docker-compose.yml), ensuring a clean environment for the next `docker compose up --build`.

---

## 🔍 Common Commands Reference

```bash
# Check cluster status
docker compose ps

# View logs of hadoop1 container
docker compose logs -f hadoop1

# Enter interactive terminal of a container
docker exec -it hadoop1 bash

# Check HDFS status inside a container
docker exec -it hadoop1 hdfs dfsadmin -report
```