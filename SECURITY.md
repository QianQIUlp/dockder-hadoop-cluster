# Security Policy

## Supported Versions

Currently, security updates are provided for the following versions:

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |
| < 2.0   | :x:                |

## Reporting a Vulnerability

We take the security of this project seriously. If you find a security vulnerability, please do **not** report it via a public GitHub issue. Instead, please report it through the following process:

1. Send an email describing the vulnerability to the project maintainer.
2. We will acknowledge receipt of your report within 48 hours.
3. We will work to resolve the issue as soon as possible and keep you updated on our progress.

## Automated Security Audits

This repository integrates automated security scanning using **Trivy** in the CI pipeline to scan the Hadoop Docker images for known vulnerabilities.
- Baseline audits and known exceptions are tracked in [TRIVY_AUDIT_BASELINE.md](TRIVY_AUDIT_BASELINE.md).
- If you notice new CVEs or package vulnerabilities that are not covered by the baseline or can be resolved, feel free to submit a Pull Request updating the baseline or the base image version.
