# 🐳 Docker-Hadoop-Cluster

![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg?logo=docker)
![Hadoop](https://img.shields.io/badge/Hadoop-3.3.4-yellow.svg?logo=apache)
![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)

This project is designed for teaching and lab usage, and builds a 3-node Hadoop 3.3.4 fully distributed cluster with Docker Compose.

Key features:

1. Hadoop configs are externalized in `conf/` for direct XML editing.
2. A unified `entrypoint.sh` starts sshd and role-specific daemons automatically.
3. `.env` provides centralized parameterization.
4. `.gitignore` filters runtime artifacts and temporary binaries.

> Note: To keep the image lean, common troubleshooting tools are not preinstalled by default.

---

## 🏗️ Cluster Roles

| Hostname | Core Roles |
| :--- | :--- |
| **hadoop1** | `NameNode` + `DataNode` |
| **hadoop2** | `ResourceManager` + `NodeManager` + `DataNode` |
| **hadoop3** | `SecondaryNameNode` + `JobHistoryServer` + `DataNode` |

All containers start sshd, which keeps node-to-node communication and maintenance workflows straightforward.

---

## 📁 Project Layout

```text
docker-hadoop-cluster/
├── conf/
│   ├── core-site.xml
│   ├── hdfs-site.xml
│   ├── yarn-site.xml
│   ├── mapred-site.xml
│   └── workers
├── .env
├── data/                         # generated at runtime (ignored by .gitignore)
│   ├── hadoop1/
│   ├── hadoop2/
│   └── hadoop3/
├── docker-compose.yml
├── docker-compose.secure.yml
├── Dockerfile
├── entrypoint.sh
├── README.md
└── README_EN.md
```

---

## 🌐 Port Mapping (Default)

- HDFS NameNode UI: <http://localhost:50070>
- HDFS RPC: `9000`
- YARN ResourceManager UI: <http://localhost:8088>
- SecondaryNameNode UI: <http://localhost:50090>
- JobHistory UI: <http://localhost:19888>

All defaults can be adjusted in `.env`.

---

## 🚀 Quick Start

### 1. Clone repository

```bash
git clone git@github.com:YourUsername/docker-hadoop-cluster.git
cd docker-hadoop-cluster
```

### 2. Build and start cluster

```bash
docker compose up -d --build
```

Containers will run role-based initialization automatically after startup.

If you want to apply extra resource hardening:

```bash
docker compose -f docker-compose.yml -f docker-compose.secure.yml up -d --build
```

### 3. Verify container and daemon status

```bash
docker compose ps
docker exec -it hadoop1 jps
docker exec -it hadoop2 jps
docker exec -it hadoop3 jps
```

---

## ⚙️ Configuration Workflow

### Option A: Edit `conf/` directly (recommended)

Update only these files:

- `conf/core-site.xml`
- `conf/hdfs-site.xml`
- `conf/yarn-site.xml`
- `conf/mapred-site.xml`
- `conf/workers`

`docker-compose.yml` mounts the whole `conf/` directory as templates, and `entrypoint.sh` renders runtime config files on startup.

### Option B: Build-time defaults via COPY

Dockerfile also copies `conf/` into the image template directory, so it can run without host mounts when needed.

---

## ⚙️ .env Parameterization

You can centrally control in `.env`:

- Hadoop version and image tag
- Service RPC/Web ports
- HDFS replication factor
- NameNode auto-format switch
- Healthcheck and startup-gate behavior

---

## 🧠 NameNode Auto-Format Logic

`hadoop1` is configured with:

- `AUTO_FORMAT=true`
- Format only if `/hadoop/dfs/name/current` does not exist

That means:

- First startup formats NameNode metadata automatically
- Existing metadata is preserved on later restarts

If you need a full metadata reset:

```bash
docker compose down
# Remove data/hadoop1/name manually
docker compose up -d
```

---

## 🔐 SSH Environment Variable Fix

A common issue in containerized Hadoop setups is missing variables across SSH sessions (`JAVA_HOME`, `HADOOP_HOME`, etc.).

This project now handles it in `entrypoint.sh` by:

- writing `/root/.ssh/environment`
- enabling `PermitUserEnvironment yes` in sshd
- generating `/etc/profile.d/hadoop.sh`

This greatly reduces cross-node SSH failures caused by incomplete runtime environments.

---

## 🛠️ Useful Operations

```bash
# Follow container logs
docker logs -f hadoop1

# Enter a container shell
docker exec -it hadoop2 bash

# Stop and remove containers/network (keep data)
docker compose down

# Stop and remove containers/network/volumes
docker compose down -v
```

---

## 📄 License

Apache License 2.0
