# 05 — Node failure and recovery

**Objective:** observe a missing DataNode without turning the lab into an
unsafe destructive exercise. Estimated time: 20 minutes.

After lesson 04 is healthy:

```bash
docker stop hadoop3
./hadoop-lab status                 # expected to report degradation
docker exec -u hadoop hadoop1 hdfs dfsadmin -report
# Inspect http://localhost:9870, then recover:
docker start hadoop3
./hadoop-lab lesson check 05-node-failure-recovery
```

Expected evidence: the NameNode temporarily reports fewer live DataNodes;
`status` exits non-zero while degraded; starting the same container preserves
its named-volume data and restores the node.

Reset/recovery: `./hadoop-lab lesson reset 05-node-failure-recovery`.
