# Hadoop Lab

[中文](README.md) · [English](README_EN.md)

**A repeatable learning path for Hadoop setup, service observation, MapReduce execution, node failure and recovery.**

[![CI](https://github.com/QianQIUlp/docker-hadoop-cluster/actions/workflows/ci.yml/badge.svg)](https://github.com/QianQIUlp/docker-hadoop-cluster/actions/workflows/ci.yml)
[![Hadoop](https://img.shields.io/badge/Hadoop-3.4.1-EF5B25?logo=apache)](https://hadoop.apache.org/)
[![Image](https://img.shields.io/badge/GHCR-multi--arch-2496ED?logo=docker)](https://github.com/QianQIUlp/docker-hadoop-cluster/pkgs/container/hadoop-cluster-3.4.1)
[![License](https://img.shields.io/badge/License-Apache--2.0-green.svg)](LICENSE)

Hadoop Lab is a Hadoop 3.4.1 environment for classes, self-study and local experiments. A beginner gets one entrypoint for preflight checks, startup, a first MapReduce job, evidence-based status and safe recovery. Three-node mode is available when physical role placement becomes the lesson.

> [!IMPORTANT]
> This is a teaching and local experimentation tool, not a production Hadoop platform. It does not provide Kerberos, NameNode HA, multi-host orchestration, backup, capacity planning or an operational SLA. Web and RPC ports bind to `127.0.0.1` by default.

## First run

Requirement: Docker Desktop, or Docker Engine with Compose v2. Windows users can run `hadoop-lab.ps1` from PowerShell; it uses the Bash shipped with Git for Windows.

```bash
git clone https://github.com/QianQIUlp/docker-hadoop-cluster.git
cd docker-hadoop-cluster

./hadoop-lab init
./hadoop-lab doctor
./hadoop-lab up standalone
./hadoop-lab demo wordcount
```

Normal startup pulls the published multi-architecture GHCR image. Build locally only after changing the Dockerfile, entrypoint or image-bundled configuration:

```bash
./hadoop-lab up standalone --build
```

## Two learning modes

| Mode | Best for | Layout | Start |
|---|---|---|---|
| `standalone` | first contact, lower-memory machines, quick demos | six Hadoop daemons in one container | `./hadoop-lab up standalone` |
| `cluster` | node roles, SSH and DataNode failure | three containers model a distributed cluster | `./hadoop-lab up cluster` |

Cluster placement:

| Node | Hadoop services |
|---|---|
| `hadoop1` | NameNode, DataNode |
| `hadoop2` | ResourceManager, NodeManager, DataNode |
| `hadoop3` | SecondaryNameNode, JobHistoryServer, DataNode |

Both modes use the same image. Runtime role settings select the daemon set.

## One operational entrypoint

```text
./hadoop-lab init                         create .env without overwriting it
./hadoop-lab doctor [MODE]                check Docker, memory, ports and Compose
./hadoop-lab up [MODE]                    pull, start and wait for health
./hadoop-lab status [--json]              verify containers and expected daemons
./hadoop-lab open [--launch]              show or open the three observation UIs
./hadoop-lab shell [NODE]                 enter a node as the non-root hadoop user
./hadoop-lab logs [NODE] [--tail N]       inspect cluster or node logs
./hadoop-lab diagnose                     create a redacted evidence bundle
./hadoop-lab stop [MODE|all]              stop while preserving data
./hadoop-lab reset MODE                   recreate runtime while preserving data
./hadoop-lab reset MODE --data            remove that mode's volumes after confirmation
```

`doctor`, `status` and `lesson check` exit non-zero on failure, so teachers and CI can use the same evidence as students. Legacy helper scripts remain as compatibility wrappers.

## Seven guided labs

```bash
./hadoop-lab lesson list
./hadoop-lab lesson start 00-first-run
./hadoop-lab lesson check 00-first-run
```

The path covers first-run observation, HDFS basics, WordCount, YARN, three-node roles, node failure/recovery and externalized configuration. Each lesson has an objective, expected evidence, explanation, automated check and narrow reset. See [`labs/`](labs/README.md).

The WordCount demo replaces only `/labs/wordcount/output`; it never deletes a generic `/output` path that may belong to a student.

## Observe and recover

```bash
./hadoop-lab status
./hadoop-lab logs hadoop-standalone
./hadoop-lab diagnose
```

Status verifies Docker health and the JVM processes expected on each role. The diagnostic archive contains versions, selected state, status output and recent logs, while excluding `.env` and full container environment values. Review it before sharing.

Stopping preserves named volumes. Only `reset MODE --data` deletes the selected mode's declared volumes, with interactive confirmation or explicit `--yes`.

## Observation surfaces

- NameNode / HDFS: <http://localhost:9870>
- ResourceManager / YARN: <http://localhost:8088>
- SecondaryNameNode: <http://localhost:9868>
- MapReduce JobHistory: <http://localhost:19888>

## Documentation

- [Architecture and boundaries](docs/architecture.md)
- [Configuration](docs/configuration.md)
- [Operations and recovery](docs/operations.md)
- [Troubleshooting guide](docs/troubleshooting.md)
- [90-minute teaching guide](docs/teaching-guide.md)
- [Portfolio source material](docs/project-showcase.md)

## Development verification

```bash
shellcheck hadoop-lab scripts/*.sh examples/*.sh
bash tests/test-cli.sh
docker compose --env-file .env.example -f docker-compose.standalone.yml config --quiet
docker compose --env-file .env.example -f docker-compose.yml config --quiet
```

CI starts standalone mode, waits for health, runs WordCount and verifies HDFS output. A cluster smoke test checks three containers and their role daemons. Image publishing retains multi-architecture builds, Trivy, SBOM, provenance and Cosign signing.

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), [CHANGELOG.md](CHANGELOG.md) and the [Apache-2.0 license](LICENSE).
