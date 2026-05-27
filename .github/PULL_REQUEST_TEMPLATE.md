## Description

Please include a summary of the change and which issue is fixed. Also include relevant motivation and context. List any dependencies that are required for this change.

Closes # (issue number)

## Type of Change

Please delete options that are not relevant.

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## How Has This Been Tested?

Please describe the tests that you ran to verify your changes. Provide instructions so we can reproduce. Please also list any relevant details for your test configuration.

- [ ] Local Cluster Test: Ran `docker-compose up -d` and checked Namenode health status.
- [ ] Secure Profile Test: Verified secure config using `docker-compose -f docker-compose.secure.yml up -d`.
- [ ] Environment Check: Verified custom configurations compile and apply in container configurations.

## Checklist

- [ ] My code follows the style guidelines of this project
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas (e.g. `entrypoint.sh` modifications)
- [ ] I have made corresponding changes to the documentation (e.g. `README.md` or `README_EN.md`)
- [ ] My changes generate no new warnings or security issues in **Trivy** scan
- [ ] Any new/modified Trivy exceptions are audited and documented in `TRIVY_AUDIT_BASELINE.md`
- [ ] My changes build and pass GitHub Actions CI tests
