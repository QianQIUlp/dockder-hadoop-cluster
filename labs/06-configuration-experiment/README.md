# 06 — Externalized configuration

**Objective:** connect `.env` and `conf/*.xml` templates to the effective Hadoop
configuration. Estimated time: 20 minutes.

```bash
./hadoop-lab lesson start 06-configuration-experiment
# Edit DFS_REPLICATION in .env, then recreate the active mode:
./hadoop-lab stop
./hadoop-lab up standalone
./hadoop-lab lesson check 06-configuration-experiment
```

Use a value appropriate to the number of DataNodes. The default remains `1` so
the single-node first-run path does not begin with an under-replication warning.

Reset: restore `DFS_REPLICATION=1` in `.env` and recreate the environment.
