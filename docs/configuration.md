# Configuration reference

Start from `.env.example` by running `./hadoop-lab init`. Compose reads `.env`;
the container entrypoint renders the XML templates under `conf/` at runtime.

## Settings students commonly change

| Variable | Default | Purpose |
|---|---:|---|
| `IMAGE_NAME` | GHCR public image | Published or locally built image name |
| `IMAGE_TAG` | `latest` | Image release selector |
| `HOST_BIND_IP` | `127.0.0.1` | Keeps web/RPC surfaces local |
| `DFS_REPLICATION` | `1` | HDFS block replication for the lab |
| `PRELOAD_TEST_DATA` | `true` | Adds the shared `/input` examples |
| `AUTO_FORMAT_NAMENODE` | `true` | Formats only an empty/new metadata volume |
| `AUTO_RESET_DATANODE_DATA_ON_VERSION_CHANGE` | `false` | Optional destructive compatibility reset; keep disabled |
| `HADOOP_NICENESS` | `10` | Lets non-root daemons lower their own CPU scheduling priority |
| `HADOOP_*_OPTS` | role-specific | JVM heap boundaries |
| `STANDALONE_*_OPTS` | lower role-specific values | Shared-container heap budget |

## Published image versus local build

The normal path pulls the signed multi-architecture public image:

```bash
./hadoop-lab up standalone
```

Use a local build only after changing the Dockerfile, entrypoint or bundled
configuration:

```bash
./hadoop-lab up standalone --build
```

The full download mirror, checksum, port, path, heap, volume and health-check
variables remain documented inline in `.env.example`. Treat that file as the
schema; keep personal overrides in the ignored `.env` file.

Compose mounts `entrypoint.sh` and `conf/` read-only from the checkout. This is
intentional: the large binary runtime remains cached, while teaching behavior
and XML templates match the exact repository revision being studied.

Existing NameNode metadata is never reformatted merely because its image marker
is missing or different. The entrypoint preserves it and emits a recovery hint.
Use the confirmed host-side data reset only for disposable lab state.
