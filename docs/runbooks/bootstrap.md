# Runbook: local bootstrap

## Preconditions

- the public `main` and generated `gitops` branches exist;
- the local environment file in `gitops` contains a released, verified digest;
- Docker exposes at least 10 GiB and ports required by the chosen tasks are free.

## Procedure

```bash
task tools:check
task local:up
task local:status
task local:verify
```

`local:up` is idempotent at the cluster/bootstrap level. It creates only the `kube-aegis-forge` cluster when missing, generates a Grafana password using the operating system CSPRNG, installs Argo CD 3.4.6 through chart 10.2.2, and submits the root application. All remaining components are reconciled by Argo CD.

## Expected state

Every Argo application is `Synced/Healthy`, two API replicas are Ready, <http://localhost:8080/health/ready> returns HTTP 200, Kyverno rejects the negative policy fixture, and Prometheus reports the application target as `UP`.

## Safe cleanup

```bash
task local:down
```

The script resolves and deletes only the exact kind cluster name. It does not remove Docker volumes, other clusters, images, or user containers.

