# Hadoop Lab learning path

The lessons deliberately move from observable outcomes to internals. Run them
in order on a disposable local environment:

```bash
./hadoop-lab lesson list
./hadoop-lab lesson start 00-first-run
./hadoop-lab lesson check 00-first-run
```

Every lesson documents its objective, expected evidence, explanation and reset
path. `standalone` is enough for lessons 00–03 and 06. Lessons 04–05 require
`./hadoop-lab up cluster`.

| Lesson | Outcome | Mode |
|---|---|---|
| 00 | Identify the six Hadoop services and three web surfaces | standalone |
| 01 | Store, list and retrieve a file from HDFS | either |
| 02 | Submit WordCount and inspect its output | either |
| 03 | Relate an application to YARN nodes and history | either |
| 04 | Map daemons to the three physical teaching roles | cluster |
| 05 | Observe and recover from one stopped DataNode | cluster |
| 06 | Change one externalized Hadoop setting and verify it | either |
