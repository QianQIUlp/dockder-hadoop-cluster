# Teaching guide

## Suggested 90-minute session

1. **10 min — Mental model:** run lesson 00 and distinguish container health,
   Java daemons and web UIs.
2. **15 min — HDFS:** lesson 01; compare the HDFS namespace with host files.
3. **25 min — MapReduce:** lesson 02; follow input, YARN application and output.
4. **15 min — YARN:** lesson 03; connect current applications to history.
5. **15 min — Roles:** switch to cluster mode and run lesson 04.
6. **10 min — Recovery:** demonstrate lesson 05 and return to healthy state.

## Classroom contract

- Students use `hadoop-lab` for lifecycle actions, then Hadoop commands inside
  the lab for learning.
- Every exercise ends with `lesson check`; the exit code is objective evidence.
- Lesson resets touch only `/labs/<lesson>` paths.
- Full volume deletion is an instructor-approved recovery action, not a normal
  exercise step.

## Pre-class verification

```bash
./hadoop-lab init
./hadoop-lab doctor standalone
./hadoop-lab up standalone
./hadoop-lab lesson start 02-mapreduce-wordcount
./hadoop-lab lesson check 02-mapreduce-wordcount
./hadoop-lab diagnose
```
