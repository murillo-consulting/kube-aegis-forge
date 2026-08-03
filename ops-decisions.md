# Operational decisions log

This log records implementation-level choices that may need periodic review. Structural choices live in `docs/adr`.

| Date | Decision | Evidence or reason | Review trigger |
|---|---|---|---|
| 2026-08-02 | Use `kind` 0.32.0 with Kubernetes 1.36.1 node digest `sha256:3489c7…` | Reproducible local acceptance on the current workstation | kind or Kubernetes security release |
| 2026-08-02 | Use Argo CD chart 10.2.2 / application 3.4.6 | Current verified chart and app versions | major Argo release or CVE |
| 2026-08-02 | Use Kyverno chart 3.8.2 / application 1.18.2 | Current verified policy engine with keyless verification | ClusterPolicy removal or policy API migration |
| 2026-08-02 | Use kube-prometheus-stack 88.1.2 | One pinned stack provides Prometheus, Grafana, CRDs, and alerting | resource pressure or component CVE |
| 2026-08-02 | Use OpenTofu 1.12.5, AWS provider 6.57.1, VPC module 6.6.1, EKS module 21.24.1 | Versions validated offline with lock files and mocked tests | provider/module upgrade or EKS version retirement |
| 2026-08-02 | Use Cosign 3.1.2, Syft 1.50.0, Trivy 0.72.0, and Gitleaks 8.30.1 baseline | Verified release tooling available on implementation date | monthly dependency review |
| 2026-08-02 | Keep AWS ingress non-public and use one NAT Gateway | Bounded portfolio cost; not a production HA topology | productionization request |
| 2026-08-02 | Pre-create the Grafana admin secret from CSPRNG output | Avoid checked-in credentials and Helm random-value drift | external secret manager introduced |
| 2026-08-02 | Publish the workload chart as versioned OCI artifacts, currently `ghcr.io/murillo-consulting/kube-aegis-forge:0.3.0` | Argo CD intentionally rejects different revisions of one Git repository in a multi-source application; an OCI chart preserves independent immutable chart and digest sources | every chart change requires a version bump |
| 2026-08-02 | Publish the signature and compact SLSA predicate in attached compatibility form; publish the large SPDX SBOM as an OCI 1.1 bundle | Kyverno `ClusterPolicy` reads attached Cosign objects but limits admission context to 2 MiB; the split keeps policy verification small while independent CLI verification covers every evidence type | Migration to `ImageValidatingPolicy` or verified support for OCI bundle referrers |
| 2026-08-02 | Pin the official Fulcio roots and active intermediate in the image policy (`sigstore/root-signing` blobs `6a06ff3`, `3afc46b`, `6d1c298`) | Legacy `ClusterPolicy.verifyImages` otherwise uses OS roots, while Fulcio is a private PKI; explicit roots make admission deterministic and preserve verification across the current root transition | Fulcio root rotation, certificate expiry, or migration to `ImageValidatingPolicy` |
| 2026-08-02 | Enable Argo CD server-side diff, including admission mutations, for Kyverno and policy applications; set `config.preserve=false` | Kyverno and the API server default policy fields and CRDs, which otherwise create permanent false `OutOfSync` drift; this is the Kyverno-documented Argo CD integration mode | Argo/Kyverno comparison behavior changes |
| 2026-08-03 | Declare SLSA Build L2 and keep L3 explicitly out of scope | GitHub provides hosted provenance, but dependency downloads and shared caches make the build non-hermetic | build becomes hermetic and satisfies every SLSA L3 requirement |
| 2026-08-03 | Prove AWS security offline with mocked tests and Trivy IaC scanning | The portfolio needs auditable cloud controls without creating billable resources or fabricating deployment evidence | an authorized AWS deployment is requested |

Primary references: [kind quick start](https://kind.sigs.k8s.io/docs/user/quick-start/), [Argo CD bootstrapping](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/), [Kyverno image verification](https://kyverno.io/docs/policy-types/cluster-policy/verify-images/overview/), [OpenTofu S3 backend](https://opentofu.org/docs/language/settings/backends/s3/), and [AWS GitHub OIDC federation](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp_oidc.html).
