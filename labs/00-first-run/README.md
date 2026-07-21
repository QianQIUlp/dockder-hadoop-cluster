# 00 — First run and service map

**Objective:** distinguish container health from Hadoop daemon health and know
where HDFS, YARN and completed MapReduce jobs are observed. Estimated time:
10 minutes.

```bash
./hadoop-lab lesson start 00-first-run
./hadoop-lab open
./hadoop-lab lesson check 00-first-run
```

Expected evidence: every expected daemon has a green check; NameNode opens on
9870, ResourceManager on 8088 and JobHistory on 19888.

Why it matters: Docker reports whether the process boundary is alive. The lab
also matches the Java service class for every expected daemon inside that
boundary. A useful Hadoop diagnosis needs both views; the runtime stays on the
smaller JRE image and does not require the JDK-only `jps` utility.

Reset: none; this lesson creates no data.
