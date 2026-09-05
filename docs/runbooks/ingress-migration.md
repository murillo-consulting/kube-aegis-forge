# Migrate ingress-nginx to Traefik

This change replaces the controller, its Argo Application, IngressClass and
NetworkPolicy peer namespace. The local URL stays `http://localhost:8080` and
the private NodePort stays `30080`. AWS workload ingress remains disabled.
There is no public TLS listener by default.

## Fresh installation

After release automation publishes workload chart **0.4.0**, use the normal
`task local:up` and `task local:verify` path. Before publication, Argo cannot
resolve the new immutable chart. Do not overwrite or retag chart 0.3.0.

## Existing local laboratory: preferred migration

The reference lab has no persistent application data. If its generated Grafana
credentials and local history are disposable, recreate only this project's
cluster with `task local:down`, then `task local:up` and `task local:verify`.
This clears the legacy NodePort, webhook and RBAC resources together. Review
any personal additions before choosing recreation; do not use it on EKS.

## Existing cluster: maintenance-window migration

Do this **before merging or otherwise allowing this revision to reconcile**.
The old ingress Application lacks a resources finalizer: deleting its manifest
alone can leave its Service behind. The new controller cannot allocate the
same NodePort until the old Service has been deleted. A brief HTTP interruption
is expected. These commands intentionally target the named local lab only.
For EKS, use its explicitly reviewed context and a separate change window.

1. Record the currently reconciled Git revision, chart version, image digest and
   all local customizations. Keep the prior revision available for rollback.
2. Freeze the three reconcilers in parent-to-child order, then the old ingress
   Application. Do not disable the entire Argo installation.

```bash
context=kind-kube-aegis-forge
for app in platform-root platform-common demo-api ingress-nginx; do
  kubectl --context "$context" -n argocd patch application "$app" --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"enabled":false}}}}'
done
```

3. Merge the reviewed revision and wait for chart publication. Confirm
   `helm show chart oci://ghcr.io/murillo-consulting/kube-aegis-forge --version 0.4.0`
   succeeds. Review the release status before proceeding.
4. Give the old Application an Argo resources finalizer, then remove it through
   Argo. This removes its tracked controller resources rather than orphaning
   its NodePort or admission webhook.

```bash
kubectl --context "$context" -n argocd patch application ingress-nginx --type merge \
  -p '{"metadata":{"finalizers":["resources-finalizer.argocd.argoproj.io"]}}'
kubectl --context "$context" -n argocd delete application ingress-nginx --wait=true --timeout=5m
kubectl --context "$context" -n ingress-nginx get service ingress-nginx-controller --ignore-not-found
```

The final command must return no Service. If deletion is stuck, inspect Argo
logs and tracked resources; do not remove the finalizer to force progress.

5. From the reviewed checkout, restore the parents using the new manifests.
   Applying the root last prevents it from restoring an old child definition.

```bash
kubectl --context "$context" apply -f platform/argocd/common/00-projects.yaml
kubectl --context "$context" apply -f platform/argocd/common/10-traefik.yaml
kubectl --context "$context" apply -f platform/argocd/local/30-demo-api.yaml
kubectl --context "$context" apply -f platform/argocd/local/00-platform-common.yaml
kubectl --context "$context" apply -f platform/bootstrap/root-local.yaml
# Explicitly undo the freeze: applying YAML may retain a manually patched field.
for app in demo-api platform-common platform-root; do
  kubectl --context "$context" -n argocd patch application "$app" --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"enabled":true}}}}'
done
task local:verify
```

6. Confirm the old controller Deployment, Service, admission webhook and RBAC
   resources are gone, the demo Ingress uses `traefik`, and its status reports
   `localhost`. The namespace itself may remain empty. Remove custom NGINX
   annotations only after translating and testing their intended behavior.

## Rollback

Freeze `platform-root`, `platform-common` and `demo-api` again. Prepare a reviewed
Git revert restoring the previous application chart reference and ingress
manifests. Before resuming reconciliation, delete the `traefik` Application
through its resources finalizer and wait for its NodePort Service to disappear.
Restore the prior project allowlist and old Application from the recorded
revision, then restore the parents and verify traffic. A Git revert alone is
insufficient because both Services would compete for NodePort 30080.

Returning to retired ingress-nginx is an emergency local-lab recovery measure,
not a supported production solution. Prefer correcting the new controller and
rolling forward. No image promotion or application-data migration is required
by the ingress change itself.

## Reproducible focused checks

`task ingress:check` renders the pinned Traefik chart and both workload profiles.
It verifies the image digest, private Service exposure, matching NodePort,
explicit class, namespace policy peers and matching immutable chart versions.

The CI job **Traefik HTTP, TLS and recovery** creates a disposable one-node kind
cluster from the repository's pinned node image and uses a published application
digest recorded in its log. It exercises all four HTTP endpoints, Ingress status,
TLS with a temporary certificate and verified hostname, controller restart and
return to the default configuration. It deletes the cluster afterward. It does
not bootstrap the entire Argo/monitoring/policy stack or call AWS.

For the same local test, create the generated kind fixture with
`uv run --locked --script scripts/check-ingress.py --output /your/temp/directory`,
use the name `aegis-ingress-test`, a temporary kubeconfig and that directory's
`kind.yaml`, then run
`bash scripts/test-ingress.sh kind-aegis-ingress-test /path/to/released/image-values.yaml`.
Ports 18080 and 18443 must be available. Delete only that test cluster afterward.

NetworkPolicy selectors are checked in rendered manifests. Default kindnet does
not enforce them. Production acceptance must separately prove permitted traffic
from Traefik and monitoring plus denied traffic from an unrelated namespace
using the target policy-enforcing CNI. The test certificate does not establish
public-domain ownership, ACME renewal or production TLS policy.
