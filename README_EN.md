# 🐳 Docker-Hadoop-Cluster

![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg?logo=docker)
![Hadoop](https://img.shields.io/badge/Hadoop-3.4.1-yellow.svg?logo=apache)
![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)

This project is designed for teaching and lab usage, and builds a 3-node Hadoop 3.4.1 fully distributed cluster with Docker Compose.

Key features:

1. Hadoop configs are externalized in `conf/` for direct XML editing.
2. A unified `entrypoint.sh` starts sshd and role-specific daemons automatically.
3. `.env` provides centralized parameterization.
4. `.gitignore` filters runtime artifacts and temporary binaries.
5. A GHCR publishing workflow is included with vulnerability scanning, image signing, and SBOM/provenance.

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
├── .env.example
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

Ports are bound to `127.0.0.1` by default (controlled by `HOST_BIND_IP`) to avoid accidental public exposure.

- HDFS NameNode UI: <http://localhost:9870>
- HDFS RPC: `9000`
- YARN ResourceManager UI: <http://localhost:8088>
- SecondaryNameNode UI: <http://localhost:9868>
- JobHistory UI: <http://localhost:19888>

All defaults can be adjusted in `.env`.

---

## 🚀 Quick Start

### 1. Clone repository

```bash
git clone git@github.com:YourUsername/docker-hadoop-cluster.git
cd docker-hadoop-cluster
cp .env.example .env
```

### 2. Build and start cluster

```bash
docker compose up -d --build
```

This command now builds the shared core image only once (triggered by hadoop1). hadoop2/hadoop3 reuse the same image tag and no longer trigger duplicate builds.

If you already have old dangling images from previous builds, clean them once with:

```bash
docker image prune -f
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

Start from `.env.example`, then adjust local values. `.env` is no longer tracked by git.

- Hadoop version and image tag
- Hadoop tarball checksum (`HADOOP_TARBALL_SHA512`, required for build)
- bind address for published ports (`HOST_BIND_IP`)
- Service RPC/Web ports
- HDFS replication factor
- NameNode auto-format switch
- root proxy allowlist (`HADOOP_PROXYUSER_ROOT_HOSTS` / `HADOOP_PROXYUSER_ROOT_GROUPS`)
- daemon user and SSH env injection switch (`HADOOP_DAEMON_USER` / `ENABLE_SSH_USER_ENV`)
- Healthcheck and startup-gate behavior

---

## 📦 Publish to GitHub Packages (GHCR)

The repository includes `.github/workflows/publish-ghcr.yml`.

Recommended before publishing:

- In GitHub Settings -> Secrets and variables -> Actions -> Variables, set `HADOOP_TARBALL_SHA512` to the official SHA512 checksum of `hadoop-3.4.1.tar.gz` (required).
- Push a version tag to trigger publishing:

```bash
git tag v3.3.6
git push origin v3.3.6
```

The workflow will automatically:

- build a local image and scan HIGH/CRITICAL vulnerabilities with Trivy
- build and push to GHCR
- emit SBOM and provenance attestations
- sign image digest with keyless Cosign (OIDC)
- fail fast when `HADOOP_TARBALL_SHA512` is missing

After the first publish, switch package visibility to Public in GitHub Packages if needed.

Pull example:

```bash
docker pull ghcr.io/<your-github-username>/dockder-hadoop-cluster:latest
```

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

- generating SSH host/root keys at container runtime (no baked private keys in image layers)
- writing `/root/.ssh/environment`
- keeping `PermitUserEnvironment` disabled by default (enable only with `ENABLE_SSH_USER_ENV=true`)
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
