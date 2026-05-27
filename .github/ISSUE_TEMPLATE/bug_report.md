---
name: Bug report
about: Create a report to help us improve the Docker Hadoop Cluster
title: '[BUG] '
labels: bug
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**Docker Environment Details (please complete the following information):**
- OS: [e.g. Windows 11, Ubuntu 22.04]
- Docker Desktop / Engine Version: [e.g. 24.0.7]
- Docker Compose Version: [e.g. 2.22.0]
- Hadoop Version (from `.env`): [e.g. 3.4.1]

**Steps to Reproduce**
Steps to reproduce the behavior:
1. Copy `.env.example` to `.env` and change `...`
2. Run `docker-compose up -d`
3. See error in logs...

**Expected Behavior**
A clear and concise description of what you expected to happen.

**Logs & Diagnostic Output**
If applicable, add container logs or console output to help explain your problem:
```bash
docker-compose logs hadoop1 # NameNode logs
docker-compose logs hadoop2 # ResourceManager logs
```

**Additional Context**
Add any other context about the problem here (e.g. custom site-xml configuration templates in `conf/`).
