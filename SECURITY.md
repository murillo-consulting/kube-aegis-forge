# Security policy

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Use the repository's **Security → Report a vulnerability** private advisory flow and include:

- affected file, image digest, or workflow run;
- reproduction steps and expected impact;
- any known exploit prerequisites;
- a suggested remediation, if available.

Avoid including real credentials, personal data, or destructive proof-of-concept payloads. The maintainer will acknowledge a complete report within five business days and coordinate disclosure after a fix is available.

## Supported version

Security fixes target the current `main` branch and currently promoted image digests. Historical digests remain available for audit and rollback but may contain dependencies that have since become vulnerable.

## Security design

The project uses CodeQL, full-history secret and IaC scanning, short-lived OIDC identities, immutable image references, keyless signatures, SBOM and provenance attestations, protected GitOps promotion, restricted Kubernetes workloads, default-deny networking, and retained audit history. The detailed assumptions and residual risks are documented in [docs/threat-model.md](docs/threat-model.md).
