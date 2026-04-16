# 🐳 Docker-Hadoop-Cluster

[中文](README.md) | [English](README_EN.md)

![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg?logo=docker)
![Hadoop](https://img.shields.io/badge/Hadoop-3.4.1-yellow.svg?logo=apache)
![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)

本项目用于教学场景下快速搭建 Hadoop 3.4.1 三节点完全分布式集群。

核心特性：

1. Hadoop 配置外置到 `conf/`，方便直接修改 XML。
2. 使用统一 `entrypoint.sh` 自动启动 sshd 与角色对应 Daemon。
3. 提供 `.env` 参数化控制，减少硬编码。
4. 默认使用 Docker 命名卷持久化数据，并通过共享 SSH 密钥卷保障节点互信。
5. 提供 `.gitignore`，避免提交运行期二进制和临时文件。
6. 提供 GHCR 发布工作流，默认包含漏洞扫描、镜像签名与 SBOM/Provenance。
7. 基础运行时升级到 Temurin JRE 11，更匹配 Hadoop 3.4.x 官方推荐。

> 说明：为控制镜像体积，默认不预装常见排障工具（如 vim、net-tools、ping）。

---

## 🏗️ 集群角色设计

| 主机名 | 核心角色 |
| :--- | :--- |
| **hadoop1** | `NameNode` + `DataNode` |
| **hadoop2** | `ResourceManager` + `NodeManager` + `DataNode` |
| **hadoop3** | `SecondaryNameNode` + `JobHistoryServer` + `DataNode` |

每个容器都启动 sshd，便于节点间通信和后续运维操作。

---

## 📁 目录结构

```text
docker-hadoop-cluster/
├── conf/
│   ├── core-site.xml
│   ├── hdfs-site.xml
│   ├── yarn-site.xml
│   ├── mapred-site.xml
│   └── workers
├── .env.example
├── data/                         # 可选：仅在你改回 bind mount 时使用（默认使用命名卷）
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

## 🌐 端口映射（默认值）

默认仅绑定到 `127.0.0.1`（通过 `HOST_BIND_IP` 控制），避免误暴露到公网网卡。

- HDFS NameNode UI: <http://localhost:9870>
- HDFS RPC: `9000`
- YARN ResourceManager UI: <http://localhost:8088>
- SecondaryNameNode UI: <http://localhost:9868>
- JobHistory UI: <http://localhost:19888>

以上默认值均可在 `.env` 中调整。

---

## 🚀 快速开始

### 1. 拉取项目

```bash
git clone git@github.com:你的用户名/docker-hadoop-cluster.git
cd docker-hadoop-cluster
cp .env.example .env
```

### 1.1 直接拉取公开镜像（免本地构建）

如果你只想快速体验，不想本地 build，可直接拉取 GHCR 公共镜像：

```bash
docker pull ghcr.io/qianqiulp/hadoop-cluster-3.4.1:latest
```

如需固定版本，也可用版本标签：

```bash
docker pull ghcr.io/qianqiulp/hadoop-cluster-3.4.1:v3.4.7
```

然后在 `.env` 中设置镜像来源并跳过构建：

```bash
IMAGE_NAME=ghcr.io/qianqiulp/hadoop-cluster-3.4.1
IMAGE_TAG=latest
```

启动时使用：

```bash
docker compose up -d --no-build
```

如果拉取时报 `denied`，请确认 GHCR 包可见性为 Public。

### 2. 构建并启动集群

```bash
./scripts/up.sh
```

该命令会执行两件事：

- 仅构建一次共享核心镜像（由 hadoop1 触发），hadoop2/hadoop3 复用同一标签。
- 启动完成后自动清理本仓库相关的悬空镜像与旧标签，尽量保持本地只保留当前 compose 所需镜像。

默认情况下：

- 运行数据写入 Docker 命名卷（避免 macOS/WSL2 下 bind mount 的 I/O 损耗）。
- 三节点共享同一套 SSH 密钥卷，可直接支持 `start-dfs.sh` / `start-yarn.sh` 这类跨节点 SSH 脚本。

如果你仍想使用原生 compose 命令，也可以：

```bash
docker compose up -d --build
```

启动后，容器会自动执行角色对应的初始化流程。

如果你希望叠加安全资源限制模板：

```bash
./scripts/up.sh --secure
```

### 2.1 构建耗时优化与详细日志

Dockerfile 已内置以下默认优化：

- 默认优先使用更快镜像源（`repo.huaweicloud.com`），再回退官方源。
- 默认不设置下载总时长硬上限（`HADOOP_DOWNLOAD_MAX_TIME=0`），避免慢网大文件中途被截断。
- 当网络长期低速（默认 `< 1KB/s` 且持续 `30s`）时自动失败并重试，避免无限等待。
- 下载阶段增加每个镜像源的开始/成功/失败与耗时日志。

如果你希望看到完整构建日志，建议使用：

```bash
docker build --progress=plain \
  --build-arg HADOOP_TARBALL_SHA512=<官方SHA512> \
  -t dockder-hadoop-cluster:dev .
```

如果你网络环境不同，也可手动调整：

```bash
docker build --progress=plain \
  --build-arg HADOOP_BASE_URL=https://dlcdn.apache.org/apache/hadoop/common \
  --build-arg HADOOP_DOWNLOAD_RETRY=1 \
  --build-arg HADOOP_DOWNLOAD_MAX_TIME=1200 \
  --build-arg HADOOP_TARBALL_SHA512=<官方SHA512> \
  -t dockder-hadoop-cluster:dev .
```

### 3. 查看容器状态与进程

```bash
docker compose ps
docker exec -it hadoop1 jps
docker exec -it hadoop2 jps
docker exec -it hadoop3 jps
```

---

## ⚙️ 配置方式（重点）

### 方式一：直接修改 `conf/`（推荐）

你只需要修改以下文件：

- `conf/core-site.xml`
- `conf/hdfs-site.xml`
- `conf/yarn-site.xml`
- `conf/mapred-site.xml`
- `conf/workers`

`docker-compose.yml` 会把 `conf/` 整体挂载为模板目录，再由 `entrypoint.sh` 渲染成运行配置。

### 方式二：镜像内默认 COPY

Dockerfile 也会把 `conf/` COPY 到镜像内模板目录，便于无挂载场景直接运行。

---

## ⚙️ .env 参数化

你可以在 `.env` 中统一修改：

建议从 `.env.example` 复制后再本地调整，仓库默认不再跟踪 `.env`。

- Hadoop 版本与镜像标签
- Hadoop 下载镜像源与超时重试参数（`HADOOP_BASE_URL`、`HADOOP_FALLBACK_BASE_URLS`、`HADOOP_DOWNLOAD_*`）
- Hadoop 安装包校验值（本地构建可用 `HADOOP_TARBALL_SHA512`，CI 发布建议使用分架构值）
- 分架构 Hadoop 安装包校验值（`HADOOP_TARBALL_SHA512_AMD64`、`HADOOP_TARBALL_SHA512_ARM64`）
- 可选分架构包名（`HADOOP_ARCHIVE_AMD64`、`HADOOP_ARCHIVE_ARM64`，默认回退 `hadoop-${HADOOP_VERSION}.tar.gz`）
- AWS SDK bundle 修复版本（`AWS_SDK_BUNDLE_VERSION`，默认 `2.41.30`）
- 端口绑定地址（`HOST_BIND_IP`）
- 各 Web/RPC 端口
- HDFS 副本数
- NameNode 自动格式化开关
- root 代理允许列表（`HADOOP_PROXYUSER_ROOT_HOSTS` / `HADOOP_PROXYUSER_ROOT_GROUPS`）
- Daemon 运行用户与 SSH 注入开关（`HADOOP_DAEMON_USER` / `ENABLE_SSH_USER_ENV`）
- DataNode 版本切换自动重置开关（`AUTO_RESET_DATANODE_DATA_ON_VERSION_CHANGE`）
- 健康检查与启动闸门参数
- 共享 SSH 目录与命名卷名称
- JVM 堆内存上限参数（`HADOOP_HEAPSIZE_MAX`、`HADOOP_NAMENODE_OPTS`、`YARN_RESOURCEMANAGER_OPTS` 等）

---

## 📦 发布到 GitHub Packages (GHCR)

仓库已内置工作流：`.github/workflows/publish-ghcr.yml`。

发布前建议：

- 在 GitHub 仓库 Settings -> Secrets and variables -> Actions 中设置（推荐放在 Secrets）：
  - `HADOOP_TARBALL_SHA512_AMD64`（必填，64 位 Linux AMD 架构）
  - `HADOOP_TARBALL_SHA512_ARM64`（必填，64 位 Linux ARM 架构）
  - `HADOOP_ARCHIVE_AMD64`（可选，若 AMD64 包名不是默认 `hadoop-${HADOOP_VERSION}.tar.gz`）
  - `HADOOP_ARCHIVE_ARM64`（可选，若 ARM64 包名不是默认 `hadoop-${HADOOP_VERSION}.tar.gz`）
- 可选设置 `AWS_SDK_BUNDLE_VERSION`（如 `2.41.30`），用于覆盖 Docker 构建阶段替换的 AWS SDK bundle 版本。
- 推送版本标签触发发布：

```bash
git tag v3.3.6
git push origin v3.3.6
```

工作流会自动执行：

- Build 本地镜像并用 Trivy 扫描高危漏洞
- 构建并推送到 GHCR
- 生成 SBOM 与 Provenance 证明
- 使用 Cosign（OIDC 无密钥模式）对镜像摘要签名
- 若缺少 `HADOOP_TARBALL_SHA512_AMD64` 或 `HADOOP_TARBALL_SHA512_ARM64`，工作流会直接失败

### Trivy 豁免清单（教学实验环境）

- 工作流会读取仓库根目录的 `.trivyignore` 作为漏洞豁免列表。
- 本仓库已提供首版审计基线：`TRIVY_AUDIT_BASELINE.md`，包含扫描命令、证据与风险说明。
- 更新方式建议：
  1. 先重新生成 `trivy-local-scan.json`。
  2. 仅把经过评审且可接受风险的 CVE/GHSA 写入 `.trivyignore`。
  3. 在 `TRIVY_AUDIT_BASELINE.md` 记录原因与下一步升级计划。

首次发布后如包默认非公开，可在 GitHub Packages 页面将可见性改为 Public。

拉取示例：

```bash
docker pull ghcr.io/qianqiulp/hadoop-cluster-3.4.1:latest
```

---

## 🧠 NameNode 自动格式化逻辑

`hadoop1`（NameNode）默认配置为：

- `AUTO_FORMAT=true`
- 仅当 `/hadoop/dfs/name/current` 不存在时执行格式化

这意味着：

- 首次启动会自动格式化
- 已有元数据时不会重复格式化，避免误清空

如果你确实要重置集群元数据：

```bash
docker compose down
# 删除 NameNode 元数据命名卷后再启动
docker volume rm hadoop1_name
docker compose up -d
```

---

## 🔐 关于 SSH 与环境变量问题

曾遇到容器间 SSH 执行命令时环境变量缺失的问题（例如 `JAVA_HOME` / `HADOOP_HOME` 不生效）。

当前方案在 `entrypoint.sh` 中统一处理：

- 运行时动态生成 SSH host key，并在共享卷中生成/复用同一套集群 SSH key
- 将共享密钥同步到 `root` 与 `hadoop` 两个用户，兼容 Hadoop 批量启停脚本
- 启动前写入 `/root/.ssh/environment`
- 默认关闭 `PermitUserEnvironment`（仅当 `ENABLE_SSH_USER_ENV=true` 时开启）
- 生成 `/etc/profile.d/hadoop.sh`

这样可以显著降低跨容器 SSH 调用时“命令找不到/变量缺失”的概率。

---

## 🛠️ 常用运维命令

```bash
# 查看某节点日志
docker logs -f hadoop1

# 进入容器
docker exec -it hadoop2 bash

# 停止并移除容器网络（保留数据）
docker compose down

# 停止并移除容器网络和数据卷
docker compose down -v
```

---

## 📄 License

Apache License 2.0
