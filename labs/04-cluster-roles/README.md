# 04 — Three-node role map

**Objective:** map the logical Hadoop services onto three observable teaching
nodes. Estimated time: 15 minutes.

```bash
./hadoop-lab stop all
./hadoop-lab up cluster
./hadoop-lab lesson start 04-cluster-roles
./hadoop-lab lesson check 04-cluster-roles
```

Expected mapping:

- `hadoop1`: NameNode and DataNode
- `hadoop2`: ResourceManager, NodeManager and DataNode
- `hadoop3`: SecondaryNameNode, JobHistoryServer and DataNode

Reset: `./hadoop-lab stop cluster` preserves the data volumes.
