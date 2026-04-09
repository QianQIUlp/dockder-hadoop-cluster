# 🐳 Docker-Hadoop-Cluster
[中文](README.md) | [English](README_EN.md)

![Docker](https://img.shields.io/badge/Docker-Supported-blue.svg?logo=docker)
![Hadoop](https://img.shields.io/badge/Hadoop-3.3.4-yellow.svg?logo=apache)
![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)

本项目通过 Docker 和 Docker Compose，基于 Ubuntu 22.04 镜像，一键快速构建 Hadoop 3.3.4 完全分布式集群。适合作为大数据入门学习、实验环境搭建以及集群测试使用。\
这也是我的第一个Git项目，正在学习关于Linux，Git，Hadoop，Docker的知识，希望能和大家一起进步！

## 🏗️ 集群架构设计

本项目包含 3 个节点，完全模拟企业级分布式部署结构：

| 主机名 (Hostname) | 核心角色分配 |
| :--- | :--- |
| **hadoop1** | `NameNode`, `DataNode` |
| **hadoop2** | `ResourceManager`, `NodeManager`, `DataNode` |
| **hadoop3** | `SecondaryNameNode`, `JobHistoryServer`, `DataNode` |

> **提示**：由于 3 个容器是基于同一个 Docker 镜像构建的，它们在构建阶段生成了相同的 SSH 密钥对，因此天然支持节点间的 root 免密登录，无需额外配置。

---
## 🌐 端口映射说明
集群启动后，可以直接在宿主机（Windows/Mac）的浏览器中访问以下 Hadoop 原生 Web UI 界面：

HDFS NameNode 面板: http://localhost:50070

YARN 资源管理面板: http://localhost:8088

SecondaryNameNode: http://localhost:50090

JobHistory 面板: http://localhost:19888

---

## 🚀 快速开始 (Quick Start)

请确保你的宿主机已经安装了 Git、Docker 和 Docker Compose。

### 1. 克隆代码仓库
```bash
git clone git@github.com:你的用户名/docker-hadoop-cluster.git
cd docker-hadoop-cluster
```
### 2. 一键构建并启动集群
```bash!
# 自动构建镜像并在后台拉起 3 个节点
docker compose up -d --build
```
### 3. 初始化并启动 Hadoop

#### 3.1 在 hadoop1 启动 HDFS

**方法 1：使用 docker exec（推荐快速操作）**
```bash
# 格式化 NameNode（仅首次启动需要）
docker exec -it hadoop1 hdfs namenode -format

# 启动 HDFS
docker exec -it hadoop1 start-dfs.sh
```

**方法 2：使用 SSH 远程登录（适合多步操作）**
```bash
# SSH 登录到 hadoop1（基于容器的 22 号端口）
ssh root@localhost -p 50001

# 或查询 hadoop1 容器的 IP 地址后，直接登录
docker inspect hadoop1 | grep IPAddress
ssh root@<hadoop1-ip>

# 在 hadoop1 内部执行
hdfs namenode -format
start-dfs.sh
```

#### 3.2 在 hadoop2 启动 YARN

**方法 1：使用 docker exec**
```bash
docker exec -it hadoop2 start-yarn.sh
```

**方法 2：使用 SSH 远程登录**
```bash
ssh root@localhost -p 50002  # 或 ssh root@<hadoop2-ip>
start-yarn.sh
```

#### 3.3 在 hadoop3 启动历史服务器（可选）

**方法 1：使用 docker exec**
```bash
docker exec -it hadoop3 mapred --daemon start historyserver
```

**方法 2：使用 SSH 远程登录**
```bash
ssh root@localhost -p 50003  # 或 ssh root@<hadoop3-ip>
mapred --daemon start historyserver
```

---

## 4️⃣ 清理和关闭集群

当需要关闭整个集群时，执行以下命令：

```bash
# 停止 Docker Compose 中的所有服务，并删除容器和网络
docker compose down
```

**可选**：如果还需要删除已构建的镜像，执行：
```bash
docker image rm hadoop-cluster:latest
```

> **提示**：使用 `docker compose down` 是完全清理集群的推荐方式，它会同时移除容器、网络和卷（如果在 docker-compose.yml 中定义了的话），开启下一次完整的 `docker compose up --build` 时能获得最清洁的环境。

---

## 🔍 常用命令参考

```bash
# 查看集群状态
docker compose ps

# 查看 hadoop1 容器日志
docker compose logs -f hadoop1

# 进入某个容器交互式终端
docker exec -it hadoop1 bash

# 在容器中检查 HDFS 状态
docker exec -it hadoop1 hdfs dfsadmin -report
```