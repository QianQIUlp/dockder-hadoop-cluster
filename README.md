# 🐳 Docker-Hadoop-Cluster

[中文](README.md) | [English](README_EN.md)

![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg?logo=docker)
![Hadoop](https://img.shields.io/badge/Hadoop-3.3.4-yellow.svg?logo=apache)
![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)

本项目用于教学场景下快速搭建 Hadoop 3.3.4 三节点完全分布式集群。

核心特性：

1. Hadoop 配置外置到 `conf/`，方便直接修改 XML。
2. 使用统一 `entrypoint.sh` 自动启动 sshd 与角色对应 Daemon。
3. 提供 `.env` 参数化控制，减少硬编码。
4. 提供 `.gitignore`，避免提交运行期二进制和临时文件。

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
├── .env
├── data/                         # 运行后自动生成（已被 .gitignore 忽略）
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

## 🌐 端口映射（默认值）

- HDFS NameNode UI: <http://localhost:50070>
- HDFS RPC: `9000`
- YARN ResourceManager UI: <http://localhost:8088>
- SecondaryNameNode UI: <http://localhost:50090>
- JobHistory UI: <http://localhost:19888>

以上默认值均可在 `.env` 中调整。

---

## 🚀 快速开始

### 1. 拉取项目

```bash
git clone git@github.com:你的用户名/docker-hadoop-cluster.git
cd docker-hadoop-cluster
```

### 2. 构建并启动集群

```bash
docker compose up -d --build
```

该命令现在仅构建一次共享核心镜像（由 hadoop1 触发），hadoop2/hadoop3 直接复用同一镜像标签，不再重复构建。

如果你历史上已经产生过悬空镜像，可一次性清理：

```bash
docker image prune -f
```

启动后，容器会自动执行角色对应的初始化流程。

如果你希望叠加安全资源限制模板：

```bash
docker compose -f docker-compose.yml -f docker-compose.secure.yml up -d --build
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

- Hadoop 版本与镜像标签
- 各 Web/RPC 端口
- HDFS 副本数
- NameNode 自动格式化开关
- 健康检查与启动闸门参数

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
# 手动删除 data/hadoop1/name 目录后再启动
docker compose up -d
```

---

## 🔐 关于 SSH 与环境变量问题

曾遇到容器间 SSH 执行命令时环境变量缺失的问题（例如 `JAVA_HOME` / `HADOOP_HOME` 不生效）。

当前方案在 `entrypoint.sh` 中统一处理：

- 启动前写入 `/root/.ssh/environment`
- 在 sshd 配置中启用 `PermitUserEnvironment yes`
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
