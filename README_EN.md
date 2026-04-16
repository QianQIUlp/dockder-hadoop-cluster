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
7. The runtime baseline is upgraded to Temurin JRE 11, aligned with Hadoop 3.4.x recommendations.

> Note: Common troubleshooting tools are preinstalled (for example: vim, net-tools, ping) for easier labs and debugging.

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

### 1.1 Pull Public Image Directly (No Local Build)

If you just want to try the cluster quickly, you can pull the public GHCR image directly:

```bash
docker pull ghcr.io/qianqiulp/hadoop-cluster-3.4.1:latest
```

To pin a specific release tag:

```bash
docker pull ghcr.io/qianqiulp/hadoop-cluster-3.4.1:v3.4.7
```

Then set image source in `.env` and skip build:

```bash
IMAGE_NAME=ghcr.io/qianqiulp/hadoop-cluster-3.4.1
IMAGE_TAG=latest
```

Start with:

```bash
docker compose up -d --no-build
```

If pull returns `denied`, confirm the GHCR package visibility is set to Public.

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
- Use no hard total download timeout by default (`HADOOP_DOWNLOAD_MAX_TIME=0`) so slow links do not fail mid-transfer.
- Fail and retry only when speed stays too low (default `< 1KB/s` for `30s`) to avoid infinite hangs.
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
  --build-arg HADOOP_DOWNLOAD_MAX_TIME=1200 \
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
- Hadoop download mirrors and timeout/retry controls (`HADOOP_BASE_URL`, `HADOOP_FALLBACK_BASE_URLS`, `HADOOP_DOWNLOAD_*`)
- Hadoop tarball checksum (`HADOOP_TARBALL_SHA512` can be used for local builds; per-arch values are recommended for CI publish)
- Per-architecture checksums (`HADOOP_TARBALL_SHA512_AMD64`, `HADOOP_TARBALL_SHA512_ARM64`)
- Optional per-architecture archive names (`HADOOP_ARCHIVE_AMD64`, `HADOOP_ARCHIVE_ARM64`, default fallback is `hadoop-${HADOOP_VERSION}.tar.gz`)
- AWS SDK bundle patch version (`AWS_SDK_BUNDLE_VERSION`, default `2.41.30`)
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

- In GitHub Settings -> Secrets and variables -> Actions, set (Secrets are recommended):
  - `HADOOP_TARBALL_SHA512_AMD64` (required for Linux AMD64)
  - `HADOOP_TARBALL_SHA512_ARM64` (required for Linux ARM64)
  - `HADOOP_ARCHIVE_AMD64` (optional if AMD64 archive name differs from default `hadoop-${HADOOP_VERSION}.tar.gz`)
  - `HADOOP_ARCHIVE_ARM64` (optional if ARM64 archive name differs from default `hadoop-${HADOOP_VERSION}.tar.gz`)
- Optionally set `AWS_SDK_BUNDLE_VERSION` (for example `2.41.30`) to override the AWS SDK bundle version replaced during Docker build.
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
- fail fast when `HADOOP_TARBALL_SHA512_AMD64` or `HADOOP_TARBALL_SHA512_ARM64` is missing

### Trivy Ignore List for Lab Environments

- The workflow reads `.trivyignore` from the repository root as the vulnerability exception list.
- This repository now includes an auditable baseline file: `TRIVY_AUDIT_BASELINE.md` with scan commands, evidence and risk context.
- Recommended maintenance flow:
  1. Regenerate `trivy-local-scan.json` from a fresh local scan.
  2. Add only reviewed and accepted-risk CVE/GHSA IDs to `.trivyignore`.
  3. Record rationale and follow-up upgrade plans in `TRIVY_AUDIT_BASELINE.md`.

After the first publish, switch package visibility to Public in GitHub Packages if needed.

Pull example:

```bash
docker pull ghcr.io/qianqiulp/hadoop-cluster-3.4.1:latest
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

## 📘 Step-by-Step: Enter Container, Format NameNode, Start HDFS/YARN

> Note first: this project starts role daemons automatically when containers boot (NameNode/DataNode/RM/NM, etc.).
> The commands below are mainly for learning, manual restart, or recovery after you stopped services yourself.

### 1. Enter a Hadoop container

```bash
# Enter NameNode node (hadoop1)
docker exec -it hadoop1 bash

# Optional: verify Hadoop CLI is available
hdfs version
```

### 2. Format NameNode manually (be careful)

> Formatting resets HDFS metadata. In lab scenarios, run this on a fresh environment, or clear volumes first with `docker compose down -v`.

Run inside `hadoop1`:

```bash
# If NameNode is already running, stop it first
hdfs --daemon stop namenode

# Format NameNode metadata
hdfs namenode -format -nonInteractive

# Start NameNode again
hdfs --daemon start namenode
```

### 3. Start HDFS cluster

Recommended on `hadoop1` (NameNode node):

```bash
start-dfs.sh
```

Quick checks:

```bash
jps
hdfs dfsadmin -report
```

### 4. Start YARN cluster

Recommended on `hadoop2` (ResourceManager node):

```bash
# Leave hadoop1 shell, then enter hadoop2
exit
docker exec -it hadoop2 bash

start-yarn.sh
```

Quick checks:

```bash
jps
yarn node -list
```

### 5. Most-used post-start verification commands

Run on host:

```bash
# Process-level view
docker exec -it hadoop1 jps
docker exec -it hadoop2 jps
docker exec -it hadoop3 jps

# Web UIs
# NameNode: http://localhost:9870
# ResourceManager: http://localhost:8088
```

### 6. Matching stop commands (easy to remember)

- Stop YARN in `hadoop2`: `stop-yarn.sh`
- Stop HDFS in `hadoop1`: `stop-dfs.sh`

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
