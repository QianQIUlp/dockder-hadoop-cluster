# 01 — HDFS basics

**Objective:** put a host-provided stream into HDFS, list it and read it back.
Estimated time: 15 minutes.

```bash
./hadoop-lab lesson start 01-hdfs-basics
./hadoop-lab shell
hdfs dfs -ls /labs/hdfs-basics
hdfs dfs -cat /labs/hdfs-basics/input.txt
exit
./hadoop-lab lesson check 01-hdfs-basics
```

Expected evidence: `input.txt` is visible in the HDFS namespace and its content
can be read from either mode. The path is not a host path and is persisted in a
Docker named volume.

Reset: `./hadoop-lab lesson reset 01-hdfs-basics`.
