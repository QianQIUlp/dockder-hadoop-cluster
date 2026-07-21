# Troubleshooting decision guide

Start with:

```bash
./hadoop-lab doctor
./hadoop-lab status
```

| Symptom | Likely cause | Evidence | Recovery |
|---|---|---|---|
| Docker engine unreachable | Docker Desktop/service is stopped | `docker info` fails | Start Docker, rerun `doctor` |
| Port already in use | Another local service owns a Hadoop UI port | `doctor` names the port | Stop it or change the port in `.env` |
| Image pull denied/not found | Wrong image/tag or unavailable GHCR | `docker compose pull` fails | Restore `.env.example` image values or use `--build` |
| Container is `unhealthy` | Hadoop daemon or safemode readiness failed | `status`, `logs NODE` | Inspect logs, then `restart MODE` |
| `/input` is missing | preload is disabled or not finished | `hdfs dfs -ls /input` | Wait, check entrypoint logs, or enable `PRELOAD_TEST_DATA` |
| WordCount output exists | Hadoop refuses an existing output directory | lab script output | The provided demo safely replaces only `/labs/wordcount/output` |
| Fewer live DataNodes | node stopped or failed | NameNode UI, `dfsadmin -report` | Start/restart the named node |
| Old data conflicts after changing Hadoop version | persisted metadata belongs to another version | entrypoint version messages | Export anything needed, then confirmed `reset --data` |
| Machine becomes memory constrained | three-node heap total is too large | `doctor` warning, Docker metrics | Use standalone or lower documented heap values |

If the cause remains unclear, create a redacted evidence bundle:

```bash
./hadoop-lab diagnose
```
