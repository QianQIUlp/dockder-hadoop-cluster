# Contributing to Docker Hadoop Cluster

First off, thank you for considering contributing to the Docker Hadoop Cluster project! It's people like you who make this project better for everyone.

Here is a set of guidelines and instructions to help you get started with contributing.

## How to Contribute

### 1. Propose Changes or Report Bugs
- Search existing issues to see if your bug or request has already been reported.
- If not, create a new issue using our **Bug Report** or **Feature Request** templates.

### 2. Local Development Environment
To test your changes locally, make sure you have:
- Docker installed and running.
- Docker Compose installed.

Follow these steps to set up the cluster locally:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/dockder-hadoop-cluster.git
   cd dockder-hadoop-cluster
   ```

2. **Initialize Environment Variables:**
   Copy the example environment file to `.env`:
   ```bash
   cp .env.example .env
   ```
   You can customize the Hadoop version or port mapping in the `.env` file if needed.

3. **Build the Shared Base Image:**
   Build the Hadoop cluster image locally:
   ```bash
   docker-compose build
   ```

4. **Spin up the Cluster:**
   - For the standard 3-node cluster:
     ```bash
     ./scripts/up.sh
     ```
   - For the lightweight single-node standalone cluster:
     ```bash
     docker compose -f docker-compose.standalone.yml up -d
     ```

5. **Verify the Installation:**
   - Access the NameNode Web UI: [http://localhost:9870](http://localhost:9870)
   - Access the YARN ResourceManager Web UI: [http://localhost:8088](http://localhost:8088)
   - Access the JobHistory Server Web UI: [http://localhost:19888](http://localhost:19888)

6. **Check Cluster Health & Use Helpers:**
   - Use our built-in checker to verify health, Java processes, and cluster statistics:
     ```bash
     ./scripts/status.sh
     ```
   - Access the interactive container shell as the secure `hadoop` user:
     ```bash
     ./scripts/shell.sh
     ```

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
