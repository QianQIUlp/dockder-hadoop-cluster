# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
