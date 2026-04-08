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
进入主节点 `hadoop1` 的终端：
```bash!
docker exec -it hadoop1 bash
```
在 `hadoop1` 内部，执行格式化并启动HDFS
```bash!
# 格式化 NameNode（仅首次启动需要）
hdfs namenode -format

start-dfs.sh
```
在 `hadoop2` 内部， 启动YARN
```bash!
start-yarn.sh
```
（可选）在 `hadoop3` 内部， 启动历史服务器
```bash
mapred --daemon start historyserver
```
记得使用 `jps` 来检查进程是否生效哦~