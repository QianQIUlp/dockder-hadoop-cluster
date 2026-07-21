# Contributing to Docker Hadoop Cluster

First off, thank you for considering contributing to the Docker Hadoop Cluster project! It's people like you who make this project better for everyone.

Here is a set of guidelines and instructions to help you get started with contributing.

## How to Contribute

### 1. Propose Changes or Report Bugs
- Search existing issues to see if your bug or request has already been reported.
- If not, create a new issue using our **Bug Report** or **Feature Request** templates.

### 2. Local Development Environment
To test changes locally, install Docker with Compose v2 and ShellCheck.

Follow these steps to set up the cluster locally:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/docker-hadoop-cluster.git
   cd docker-hadoop-cluster
   ```

2. **Initialize and check the environment:**
   ```bash
   ./hadoop-lab init
   ./hadoop-lab doctor
   ```

3. **Run static checks:**
   ```bash
   shellcheck hadoop-lab entrypoint.sh scripts/*.sh examples/*.sh tests/*.sh
   bash tests/test-cli.sh
   docker compose --env-file .env.example -f docker-compose.standalone.yml config --quiet
   docker compose --env-file .env.example -f docker-compose.yml config --quiet
   ```

4. **Exercise the affected runtime path:**
   ```bash
   ./hadoop-lab up standalone
   ./hadoop-lab lesson start 02-mapreduce-wordcount
   ./hadoop-lab lesson check 02-mapreduce-wordcount
   ```

   Changes to shared role/configuration logic should also pass:

   ```bash
   ./hadoop-lab stop standalone
   ./hadoop-lab up cluster
   ./hadoop-lab lesson check 04-cluster-roles
   ```

5. **Verify the Installation:**
   - Access the NameNode Web UI: [http://localhost:9870](http://localhost:9870)
   - Access the YARN ResourceManager Web UI: [http://localhost:8088](http://localhost:8088)
   - Access the JobHistory Server Web UI: [http://localhost:19888](http://localhost:19888)

6. **Collect evidence and clean up:**
   ```bash
   ./hadoop-lab status
   ./hadoop-lab diagnose
   ./hadoop-lab stop all
   ```

Use `./hadoop-lab up MODE --build` only when the image contents changed. Do not
delete named volumes as part of a routine test; use the confirmed reset flow
only for disposable lab data.

### 3. Security Audits (Trivy Scan)
We enforce strict security checks in our CI using Trivy to scan the built images.
Before submitting any changes (especially if you modify the `Dockerfile` or add dependencies):
- Run Trivy locally to audit the built image:
  ```bash
  trivy image hadoop-cluster:3.4.1
  ```
- If you introduce a new vulnerability that cannot be fixed (e.g., upstream issue) or you update baseline exceptions, please ensure you document it in [TRIVY_AUDIT_BASELINE.md](TRIVY_AUDIT_BASELINE.md) and update `.trivyignore` accordingly.

### 4. Submitting a Pull Request
1. Commit your changes. Ensure your commit messages are clear and atomic.
2. Submit your Pull Request.
3. Fill out the **Pull Request Template** completely.
4. Ensure the GitHub Actions CI (Trivy scan, image building) passes successfully on your branch.
