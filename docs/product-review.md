# Platform review and adoption guide

Reviewed against public documentation on 2026-09-05. This is an engineering
comparison, not a performance benchmark or a security certification.

## Where the platform fits

Use Kube Aegis Forge to demonstrate and reproduce the path from a reviewed
change to a signed artifact, policy admission and observable GitOps delivery.
Its useful differentiator is a local acceptance path with explicit evidence.
It is a reference implementation, not a managed Kubernetes service.

| Reference | Practice to adopt | Decision for this repository |
| --- | --- | --- |
| [Flux security guidance](https://fluxcd.io/flux/security/best-practices/) | Make controller permissions and tenancy boundaries explicit | Keep Argo CD and the existing separated projects. Re-test repository and namespace restrictions when adding tenants. |
| [Argo Rollouts](https://argoproj.github.io/argo-rollouts/) | Canary and blue/green delivery with analysis | A future optional overlay should prove automatic abort on an injected error before becoming the default. |
| [Prometheus instrumentation](https://prometheus.io/docs/practices/instrumentation/) | Bound labels and instrument failures | HTTP methods now use a finite label set. Unhandled application failures produce a 500 series and safe response headers. |

## Production adoption blocker

The current platform still uses ingress-nginx. Kubernetes announced its
[retirement for March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/).
Pinning a historical image does not provide future security fixes. Keep this
configuration confined to the local reference lab. Before production adoption,
replace it with a maintained controller or Gateway API implementation and
validate traffic, TLS, NetworkPolicies and the local verification scripts.
That migration is not implemented by this review.

## Improvements in this change

- Failure accounting: unhandled endpoint errors pass through the same metrics
  and response headers as successful requests.
- Cardinality control: extension HTTP methods share the `OTHER` label.
- Promotion integrity: a temporary file is flushed and atomically renamed.
  A failed replacement preserves the previous values and cleans the temporary.
- Metadata fidelity: versions such as `1.0`, `null` and `0123` remain strings.
- CI regression coverage: promotion tests require no cluster or cloud account.

## Reproduce the checks

```bash
task app:check
task promotion:check
task helm:check
```

The new tests cover a failing endpoint, arbitrary HTTP methods, YAML-ambiguous
versions, invalid input, a symlink escape and a simulated filesystem failure.
An atomic replacement is not a substitute for reviewing and signing the Git
commit. Local tests do not establish EKS or Kubernetes end-to-end success.

## Prioritized next milestones

| Priority | Work | Acceptance criterion |
| --- | --- | --- |
| P0 | Replace the retired ingress controller | A clean local cluster passes routing, TLS, network isolation and self-healing checks with a maintained implementation. |
| P1 | Separate user-traffic SLOs from probes and scrapes | Inject 5xx and latency into user traffic and prove alerts fire without probe traffic diluting the denominator. |
| P1 | Exercise recovery | Restore a cluster from Git and verified artifacts, record elapsed time and distinguish it from application-data recovery. |
| P2 | Add progressive delivery | A canary aborts on a failing analysis and leaves the last healthy revision serving traffic. |
| P2 | Publish repeatable capacity measurements | Record hardware, workload, versions, concurrency and latency distributions. No unmeasured throughput claims. |

## Rollback and compatibility

Metric names and existing standard-method labels stay stable. New `OTHER`
series consolidate custom methods. Existing image values remain valid. Revert
the change commit to restore prior behavior; no state migration is needed.
Do not revert failure instrumentation simply to make an alert disappear.
