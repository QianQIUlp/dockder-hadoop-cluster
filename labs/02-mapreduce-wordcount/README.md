# 02 — MapReduce WordCount

**Objective:** follow one job from HDFS input through YARN execution to HDFS
output. Estimated time: 20 minutes.

```bash
./hadoop-lab lesson start 02-mapreduce-wordcount
./hadoop-lab lesson check 02-mapreduce-wordcount
./hadoop-lab open
```

Expected evidence: `/labs/wordcount/output/part-r-00000` is non-empty, the
terminal shows the most frequent words, and the application is visible in YARN
or JobHistory.

The example replaces only its own `/labs/wordcount/output` path. It never
deletes a generic `/output` path that might belong to a student.

Reset: `./hadoop-lab lesson reset 02-mapreduce-wordcount`.
