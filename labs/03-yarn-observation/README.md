# 03 — Observe YARN

**Objective:** connect NodeManager capacity, an application state and completed
job history. Estimated time: 15 minutes.

Run lesson 02 first, then:

```bash
./hadoop-lab lesson start 03-yarn-observation
./hadoop-lab lesson check 03-yarn-observation
```

Open ResourceManager on port 8088 for current applications and JobHistory on
19888 for completed MapReduce jobs. A finished job disappearing from the first
page is not data loss; those two services have different responsibilities.

Reset: none.
