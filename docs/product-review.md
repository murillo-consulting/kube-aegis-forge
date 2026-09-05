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

## Maintained ingress controller

Traefik chart 41.4.0 replaces ingress-nginx, whose retirement was announced for
[March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/).
The controller image is pinned by a multi-architecture digest. Standard Ingress
resources, Argo CD and the private NodePort contract are preserved. No public
load balancer, ACME service or Gateway API CRDs are introduced.

Existing clusters must follow the [migration runbook](runbooks/ingress-migration.md)
to release the old NodePort and remove orphaned controller resources. The
[architecture decision](adr/0009-maintained-ingress.md) records the tradeoffs.
The local test validates HTTP, opt-in TLS and controller restart. NetworkPolicy
selectors are validated structurally; kind's default kindnet CNI does not enforce
them. Enforce and test those policies with the target production CNI before
claiming network isolation.

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
task ingress:check
```

The new tests cover a failing endpoint, arbitrary HTTP methods, YAML-ambiguous
versions, invalid input, a symlink escape and a simulated filesystem failure.
An atomic replacement is not a substitute for reviewing and signing the Git
commit. Local tests do not establish EKS or Kubernetes end-to-end success.

## Prioritized next milestones

| Priority | Work | Acceptance criterion |
| --- | --- | --- |
| P0 | Validate production network isolation | With the target policy-enforcing CNI, allowed ingress and monitoring traffic succeeds while a pod in an unrelated namespace is denied. |
| P1 | Separate user-traffic SLOs from probes and scrapes | Inject 5xx and latency into user traffic and prove alerts fire without probe traffic diluting the denominator. |
| P1 | Exercise recovery | Restore a cluster from Git and verified artifacts, record elapsed time and distinguish it from application-data recovery. |
| P2 | Add progressive delivery | A canary aborts on a failing analysis and leaves the last healthy revision serving traffic. |
| P2 | Publish repeatable capacity measurements | Record hardware, workload, versions, concurrency and latency distributions. No unmeasured throughput claims. |

## Rollback and compatibility

Metric names and existing standard-method labels stay stable. New `OTHER`
series consolidate custom methods. Existing image values remain valid. Revert
the change commit to restore prior behavior; no state migration is needed.
Do not revert failure instrumentation simply to make an alert disappear.
