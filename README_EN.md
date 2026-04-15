# 🐳 Docker-Hadoop-Cluster

![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg?logo=docker)
![Hadoop](https://img.shields.io/badge/Hadoop-3.4.1-yellow.svg?logo=apache)
![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)

This project is designed for teaching and lab usage, and builds a 3-node Hadoop 3.4.1 fully distributed cluster with Docker Compose.

Key features:

1. Hadoop configs are externalized in `conf/` for direct XML editing.
2. A unified `entrypoint.sh` starts sshd and role-specific daemons automatically.
3. `.env` provides centralized parameterization.
4. Docker named volumes are used by default, and a shared SSH key volume enables inter-node trust.
5. `.gitignore` filters runtime artifacts and temporary binaries.
6. A GHCR publishing workflow is included with vulnerability scanning, image signing, and SBOM/provenance.
7. The runtime baseline is upgraded to Temurin JDK 11, aligned with Hadoop 3.4.x recommendations.

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
├── data/                         # optional: only used if you switch back to bind mounts
│   ├── hadoop1/
│   ├── hadoop2/
│   └── hadoop3/
├── docker-compose.yml
├── docker-compose.secure.yml
├── Dockerfile
├── entrypoint.sh
├── scripts/
│   └── up.sh
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
./scripts/up.sh
```

This command now does two things:

- Builds the shared core image only once (triggered by hadoop1), while hadoop2/hadoop3 reuse the same image tag.
- Cleans dangling images and stale tags related to this repository after startup, so the local image set stays close to a single required runtime image.

By default:

- Runtime data is persisted in Docker named volumes (avoiding bind-mount I/O penalties on macOS/WSL2).
- All three nodes reuse one shared SSH keypair volume, so scripts like `start-dfs.sh` and `start-yarn.sh` can SSH across nodes without password prompts.

If you still prefer native compose directly, you can run:

```bash
docker compose up -d --build
```

Containers will run role-based initialization automatically after startup.

If you want to apply extra resource hardening:

```bash
./scripts/up.sh --secure
```

### 2.1 Build Time Tuning and Verbose Logs

The Dockerfile now includes these default optimizations:

- Prefer a faster mirror (`repo.huaweicloud.com`) first, then fall back to Apache mirrors.
- Reduce retry/timeout (`retry=2`, `max-time=180`) to avoid long "stuck but eventually succeeds" waits.
- Print per-mirror download start/success/failure with elapsed time.

To get full step-by-step build output, use:

```bash
docker build --progress=plain \
  --build-arg HADOOP_TARBALL_SHA512=<official-sha512> \
  -t dockder-hadoop-cluster:dev .
```

You can also tune behavior per environment:

```bash
docker build --progress=plain \
  --build-arg HADOOP_BASE_URL=https://dlcdn.apache.org/apache/hadoop/common \
  --build-arg HADOOP_DOWNLOAD_RETRY=1 \
  --build-arg HADOOP_DOWNLOAD_MAX_TIME=120 \
  --build-arg HADOOP_TARBALL_SHA512=<official-sha512> \
  -t dockder-hadoop-cluster:dev .
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
- DataNode auto-reset on version change (`AUTO_RESET_DATANODE_DATA_ON_VERSION_CHANGE`)
- Healthcheck and startup-gate behavior
- Shared SSH directory and named-volume names
- JVM heap limits (`HADOOP_HEAPSIZE_MAX`, `HADOOP_NAMENODE_OPTS`, `YARN_RESOURCEMANAGER_OPTS`, etc.)

---

## 📦 Publish to GitHub Packages (GHCR)

The repository includes `.github/workflows/publish-ghcr.yml`.

Recommended before publishing:

- In GitHub Settings -> Secrets and variables -> Actions -> Variables, configure checksum variables:
  - `HADOOP_TARBALL_SHA512` (generic archive), or
  - `HADOOP_TARBALL_SHA512_AMD64` / `HADOOP_TARBALL_SHA512_ARM64` (arch-specific checksums).
- Maintain `.trivyignore` in repo root for accepted-risk upstream vulnerabilities that cannot be fixed immediately.
- Push a version tag to trigger publishing:

```bash
git tag v3.3.6
git push origin v3.3.6
```

The workflow will automatically:

- build a local image and scan HIGH/CRITICAL vulnerabilities with Trivy
- build and push multi-arch images (`linux/amd64` + `linux/arm64`) to GHCR
- emit SBOM and provenance attestations
- sign image digest with keyless Cosign (OIDC)
- fail fast when no valid Hadoop checksum variable is configured

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
# Remove the NameNode metadata volume
docker volume rm hadoop1_name
docker compose up -d
```

---

## 🔐 SSH Environment Variable Fix

A common issue in containerized Hadoop setups is missing variables across SSH sessions (`JAVA_HOME`, `HADOOP_HOME`, etc.).

This project now handles it in `entrypoint.sh` by:

- generating SSH host keys at runtime and generating/reusing one shared cluster SSH keypair in a named volume
- syncing that shared keypair into both `root` and `hadoop` user SSH dirs for Hadoop batch scripts
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
