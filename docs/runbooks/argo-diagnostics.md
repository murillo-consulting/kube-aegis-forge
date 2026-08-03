# Runbook: Argo CD diagnostics

## Triage

```bash
task local:status
kubectl --context kind-kube-aegis-forge -n argocd get applications
kubectl --context kind-kube-aegis-forge -n argocd describe application demo-api
kubectl --context kind-kube-aegis-forge -n argocd logs deployment/argocd-repo-server --tail=200
```

Classify the failure before changing state:

- `ComparisonError`: inspect repository URL, branch existence, chart path, and value-file path;
- `SyncFailed`: inspect the failing resource event and Kyverno policy report;
- `Progressing`: inspect deployment, probe, scheduling, and image-pull events;
- `Degraded`: inspect controller logs and the application's `status.operationState`.

## Common causes

| Symptom | Check | Recovery |
|---|---|---|
| GitOps value file missing | `git ls-remote origin gitops` and file path | Repair generated branch through a verified release |
| Image rejected | Kyverno admission event and Cosign verification | Follow `image-incident.md`; never bypass the policy |
| Monitoring stuck | `grafana-admin` secret and CRD status | Re-run bootstrap to recreate a missing local secret, then refresh Argo |
| Repo fetch failure | DNS/network and GitHub status | Wait or restore network; do not deploy imperatively |

## Rollback boundary

Do not use `argocd rollback` while automated sync is enabled. If desired state is wrong, use the rollback workflow so Git and cluster converge on the same verified digest.

