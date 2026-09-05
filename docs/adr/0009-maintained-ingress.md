# ADR 0009: Replace the retired ingress controller with Traefik

- Status: Accepted
- Date: 2026-09-05

## Context

The platform depended on retired ingress-nginx. Pinning an old version does not
provide ongoing fixes. The workload uses standard networking.k8s.io/v1 Ingress
without NGINX-specific annotations. Argo CD reconciles an immutable OCI workload
chart and a separate generated image digest.

## Decision

Use [Traefik chart 41.4.0](https://github.com/traefik/traefik-helm-chart/releases/tag/v41.4.0)
with Traefik v3.7.12 pinned by its multi-architecture image digest. Keep the
[standard Kubernetes Ingress provider](https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-ingress/)
and the private NodePort 30080. The class is explicitly `traefik` and is not the
cluster default. Watch `demo`; disable CRD and Gateway providers, API dashboard,
insecure API and CRD installation. Run two non-root replicas with bounded
resources and the upstream restricted container security context.

Only HTTP is exposed by the default Service. The unused websecure entrypoint
remains internal so operators can opt into TLS separately. Set Ingress status
to `localhost` for this local reference profile because a NodePort Service has
no external load-balancer address. This preserves Argo CD Ingress health without
claiming a public address. AWS still disables workload ingress; any future public
profile must configure its actual published endpoint and TLS policy.

Bump the application chart to 0.4.0 and both Argo references together. Chart 0.3.0
must never be overwritten. The release must publish 0.4.0 before the workload
Application can reconcile it. Until then Argo may report a missing chart.

## Consequences

The replacement requires neither an application API change nor a Gateway API
migration. The Ingress API is frozen upstream; Gateway API remains a future
architecture choice rather than an additional dependency in this maintenance
change. Custom NGINX annotations outside this repository are not translated.

Existing installations require a maintenance window and an explicit migration:
the old Application has no resource-deletion finalizer, so merely removing it
can orphan its NodePort Service. Follow the runbook before allowing main to
reconcile. A fresh cluster has no such conflict. Reverting Git alone does not
remove the new Service or restore the old controller safely.

The default kind CNI does not enforce NetworkPolicy. Contract tests prove the
new namespace selector, not runtime isolation. Cloud production readiness also
requires policy-enforcing CNI tests, TLS ownership and capacity/recovery checks.
