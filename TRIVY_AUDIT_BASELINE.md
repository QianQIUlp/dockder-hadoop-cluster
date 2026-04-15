# Trivy Audit Baseline

Date: 2026-04-15
Image: local/hadoop-cluster:scan
Scope: HIGH,CRITICAL with --ignore-unfixed

## Evidence Commands

```bash
docker build --progress=plain -t local/hadoop-cluster:scan \
  --build-arg HADOOP_TARBALL_SHA512=09cda6943625bc8e4307deca7a4df76d676a51aca1b9a0171938b793521dfe1ab5970fdb9a490bab34c12a2230ffdaed2992bad16458169ac51b281be1ab6741 \
  --build-arg HADOOP_TARBALL_SHA512_AMD64=09cda6943625bc8e4307deca7a4df76d676a51aca1b9a0171938b793521dfe1ab5970fdb9a490bab34c12a2230ffdaed2992bad16458169ac51b281be1ab6741 \
  --build-arg HADOOP_TARBALL_SHA512_ARM64=09cda6943625bc8e4307deca7a4df76d676a51aca1b9a0171938b793521dfe1ab5970fdb9a490bab34c12a2230ffdaed2992bad16458169ac51b281be1ab6741 \
  .

docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "$PWD":/work \
  -e TRIVY_DB_REPOSITORY=public.ecr.aws/aquasecurity/trivy-db \
  -e TRIVY_JAVA_DB_REPOSITORY=public.ecr.aws/aquasecurity/trivy-java-db \
  aquasec/trivy:0.52.2 image \
  --ignore-unfixed --severity HIGH,CRITICAL --timeout 60m \
  --format json --output /work/trivy-local-scan.json --quiet \
  local/hadoop-cluster:scan
```

## Summary

- OS layer findings in this scope: 0
- Java layer findings in this scope: 115
- Unique vulnerability IDs (HIGH/CRITICAL): 70
- Baseline ignore list file: .trivyignore

## Why this baseline exists

- The blocking findings are concentrated in Hadoop-bundled transitive dependencies, not in the base OS layer after package upgrade.
- Manual in-image JAR replacement is intentionally avoided because it can break Hadoop runtime compatibility.
- This baseline is a temporary risk-acceptance set for lab and teaching environments with constrained exposure.

## Concentration hotspots

- com.fasterxml.jackson.core:jackson-databind@2.4.0 (46 findings)
- io.netty:netty-codec-http2@4.1.100.Final (10 findings)
- org.apache.avro:avro@1.9.2 (8 findings)
- org.apache.zookeeper:zookeeper@3.8.4 (8 findings)
- io.netty:netty-codec-http@4.1.100.Final (5 findings)
- io.netty:netty-handler@4.1.100.Final (5 findings)

## Risk acceptance notes

- This baseline should be treated as controlled technical debt.
- Each release cycle should re-run Trivy and re-evaluate whether entries can be removed.
- If production deployment is planned, migrate to a stricter policy that removes broad ignores and upgrades vulnerable dependency trees upstream.
