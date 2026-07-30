# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A zero-dependency bilingual project site in `site/`, ready for Cloudflare Pages Git deployment from `main` with security headers and local static checks.
- A Cloudflare Pages deployment runbook covering the one-time GitHub connection, preview branches, custom domains, and post-deployment verification.

## [2.0.0] - 2026-07-19

### Added

- One `hadoop-lab` lifecycle CLI with preflight checks, readiness waits,
  role-aware health evidence, JSON status, logs, redacted diagnostics and
  confirmation-gated data reset; PowerShell and legacy wrappers use the same
  behavior.
- Seven guided lessons covering first-run observation, HDFS, MapReduce, YARN,
  three-node placement, recoverable node failure and externalized configuration.
- Static CLI tests plus standalone and three-node runtime smoke tests in CI.
- Architecture, configuration, operations, troubleshooting, teaching and
  portfolio documentation.

### Changed

- Published GHCR image and standalone mode are now the default first-run path;
  local image builds are explicit.
- README content is organized around student outcomes, learning modes, evidence
  and recovery rather than a feature/configuration inventory.
- Canonical repository metadata now consistently uses `docker-hadoop-cluster`.

### Fixed

- Standalone mode no longer requests an unpublished `-standalone` image tag.
- Compose mounts the checked-out entrypoint read-only so the published Hadoop
  runtime follows the repository's current standalone and recovery behavior.
- Runtime capabilities now allow Hadoop daemons to remain on the non-root
  `hadoop` account and receive their runtime SSH files instead of silently
  falling back to root.
- Standalone mode has a separate lower heap budget; Hadoop daemons use a
  positive niceness value that works without privileged scheduling capability.
- Three-node mode preloads the same namespaced teaching input as standalone.
- WordCount no longer removes a generic `/output` HDFS path.
- Existing NameNode/DataNode volumes are no longer erased automatically when an
  image-version marker differs or is missing.
- MapReduce containers receive `HADOOP_MAPRED_HOME`, and sample preloading
  repairs a partially created `/input` directory file by file.
- Health/status checks use Hadoop Java class processes rather than the JDK-only
  `jps` utility, which is intentionally absent from the smaller JRE image.
- Named-volume roots are assigned to the non-root daemon user so DataNode's
  permission validation succeeds without broad filesystem capabilities.

## [1.3.0] - 2026-05-27

### Added
- **Lightweight Standalone Mode** (`docker-compose.standalone.yml`): A single-container pseudo-distributed Hadoop deployment consolidated with all core Hadoop services (NameNode, SecondaryNameNode, DataNode, ResourceManager, NodeManager, and JobHistoryServer).
- **HDFS Test Data Preloader**: Automatic background pre-loading of sample datasets (`hadoop-intro.txt` and `quotes.txt`) into `/input` once NameNode exits safemode.
- **Interactive Helper Scripts**:
  - `scripts/shell.sh`: One-click interactive container shell as the secure, non-root `hadoop` user.
  - `scripts/status.sh`: Observability checker displaying active containers, JVM processes, HDFS storage metrics, and YARN nodes.
  - Registered POSIX executable flags (+x) directly in the Git repository index for out-of-the-box script execution.
- **Instant MapReduce WordCount Tutorial**:
  - `examples/run-wordcount.sh`: Automated MapReduce demonstration script verifying datasets, cleaning outputs, submitting jobs, and sorting/printing word counts.
- **Bilingual Documentation & Contribution Guidelines**: Documented new standalone/helper/demo features inside `README.md`, `README_EN.md`, and `CONTRIBUTING.md`.

## [1.2.0] - 2026-05-27

### Added
- Standardized open-source repository files:
  - `CODE_OF_CONDUCT.md` (Contributor Covenant v2.1)
  - `SECURITY.md` (Security Policy)
  - `CONTRIBUTING.md` (Docker-Hadoop development instructions)
- GitHub issue templates:
  - `bug_report.md`
  - `feature_request.md`
- GitHub Pull Request template `PULL_REQUEST_TEMPLATE.md`.
- Initialized `CHANGELOG.md` to track project evolution.

## [1.1.0] - 2026-05-15

### Added
- GitHub Actions CI workflow to publish Docker images to GHCR (`publish-ghcr.yml`).
- Integrated Trivy security auditing (`TRIVY_AUDIT_BASELINE.md` and `.trivyignore`).
- Troubleshooting utilities in the runtime Docker image (e.g., netstat, curl, ssh tools).
- Bilingual `README.md` and `README_EN.md` for better accessibility.
- Support for pulling pre-built Docker images directly without local compilation.

### Fixed
- Stabilized multi-arch (amd64 / arm64) Docker builds and added multiple Huawei Cloud / Apache archive fallback URLs for Hadoop download resilience.

## [1.0.0] - 2026-04-20

### Added
- Initial 3-node containerized Hadoop cluster deployment utilizing `docker-compose`.
- Custom XML config templates renderer (`entrypoint.sh`).
- Passwordless SSH configuration between cluster nodes.
