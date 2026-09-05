#!/usr/bin/env bash
set -euo pipefail

command_name="${1:-}"
cluster_name="kube-aegis-forge"
context="kind-${cluster_name}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cluster_exists() {
  kind get clusters 2>/dev/null | grep -Fxq "$cluster_name"
}

wait_for_application() {
  local application="$1"
  local deadline=$((SECONDS + 1200))
  while ((SECONDS < deadline)); do
    sync="$(kubectl --context "$context" -n argocd get application "$application" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)"
    health="$(kubectl --context "$context" -n argocd get application "$application" -o jsonpath='{.status.health.status}' 2>/dev/null || true)"
    if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then
      printf '  [ok] %s is Synced/Healthy\n' "$application"
      return
    fi
    sleep 10
  done
  kubectl --context "$context" -n argocd get application "$application" -o yaml
  printf 'Argo application %s did not become Synced/Healthy.\n' "$application" >&2
  exit 1
}

case "$command_name" in
  up)
    bash "$repo_root/scripts/tools-check.sh"
    if ! cluster_exists; then
      kind create cluster --name "$cluster_name" --config "$repo_root/platform/kind/cluster.yaml" --wait 180s
    fi
    kubectl --context "$context" create namespace monitoring --dry-run=client -o yaml | kubectl --context "$context" apply -f -
    secret_dir="$(mktemp -d)"
    trap 'rm -rf -- "$secret_dir"' EXIT
    umask 077
    printf 'admin' >"$secret_dir/admin-user"
    head -c 32 /dev/urandom | base64 | tr -d '=+/' >"$secret_dir/admin-password"
    kubectl --context "$context" -n monitoring create secret generic grafana-admin \
      --from-file="admin-user=$secret_dir/admin-user" \
      --from-file="admin-password=$secret_dir/admin-password" \
      --dry-run=client -o yaml | kubectl --context "$context" apply -f -
    helm repo add argo https://argoproj.github.io/argo-helm --force-update
    helm repo update argo
    helm upgrade --install argocd argo/argo-cd --kube-context "$context" --namespace argocd \
      --create-namespace --version 10.2.2 --values "$repo_root/platform/bootstrap/argocd-values.yaml" \
      --wait --timeout 10m
    kubectl --context "$context" apply -f "$repo_root/platform/bootstrap/root-local.yaml"
    printf 'Bootstrap complete. Run task local:verify after Argo reconciles.\n'
    ;;
  verify)
    cluster_exists || { printf 'Cluster %s does not exist.\n' "$cluster_name" >&2; exit 1; }
    kubectl --context "$context" wait --for=condition=Ready nodes --all --timeout=5m
    for application in platform-common traefik metrics-server kyverno monitoring security-policies demo-api platform-root; do
      wait_for_application "$application"
    done
    kubectl --context "$context" -n demo wait deployment/demo-api --for=condition=Available --timeout=5m # gitleaks:allow
    root_response="$(curl --fail --silent --show-error http://localhost:8080/)"
    live_response="$(curl --fail --silent --show-error http://localhost:8080/health/live)"
    ready_response="$(curl --fail --silent --show-error http://localhost:8080/health/ready)"
    metrics_response="$(curl --fail --silent --show-error http://localhost:8080/metrics)"
    grep -Fq '"name":"devsecops-demo-api"' <<<"$root_response"
    grep -Fq '"status":"ok"' <<<"$live_response"
    grep -Fq '"status":"ready"' <<<"$ready_response"
    grep -Fq demo_api_http_requests_total <<<"$metrics_response"
    kubectl --context "$context" -n demo get servicemonitor demo-api
    kubectl --context "$context" -n demo get prometheusrule demo-api
    kubectl --context "$context" -n demo get configmap demo-api-dashboard
    kubectl --context "$context" -n demo get resourcequota demo-api-quota
    kubectl --context "$context" -n demo get limitrange demo-api-limits
    kubectl --context "$context" get clusterpolicy demo-workload-hardening verify-demo-image
    [[ "$(kubectl --context "$context" -n demo get deployment demo-api -o jsonpath='{.spec.template.spec.automountServiceAccountToken}')" == "false" ]]
    if denial_output="$(kubectl --context "$context" apply --dry-run=server -f "$repo_root/platform/policies/tests/unsigned-pod.yaml" 2>&1)"; then
      printf 'Kyverno accepted the intentionally invalid workload.\n' >&2
      exit 1
    fi
    printf '%s\n' "$denial_output"
    if ! grep -Fq 'verify-demo-image' <<<"$denial_output"; then
      printf 'The negative control was not rejected by the image-verification policy.\n' >&2
      exit 1
    fi
    printf '[ok] Kyverno rejected the unsigned image digest.\n'
    targets="$(kubectl --context "$context" get --raw '/api/v1/namespaces/monitoring/services/http:monitoring-kube-prometheus-prometheus:9090/proxy/api/v1/targets')"
    grep -Fq '"job":"demo-api"' <<<"$targets"
    grep -Fq '"health":"up"' <<<"$targets"
    old_pod="$(kubectl --context "$context" -n demo get pod -l app.kubernetes.io/name=demo-api -o jsonpath='{.items[0].metadata.name}')"
    kubectl --context "$context" -n demo delete pod "$old_pod" --wait=false
    kubectl --context "$context" -n demo wait deployment/demo-api --for=condition=Available --timeout=3m # gitleaks:allow
    kubectl --context "$context" -n demo scale deployment demo-api --replicas=1
    deadline=$((SECONDS + 180))
    until [[ "$(kubectl --context "$context" -n demo get deployment demo-api -o jsonpath='{.spec.replicas}')" == "2" ]]; do
      ((SECONDS < deadline)) || { printf 'Argo did not self-heal replica drift.\n' >&2; exit 1; }
      sleep 5
    done
    printf 'Local verification passed.\n'
    ;;
  status)
    if ! cluster_exists; then
      printf 'Cluster %s is not running.\n' "$cluster_name"
      exit 0
    fi
    kubectl --context "$context" get nodes
    kubectl --context "$context" -n argocd get applications
    kubectl --context "$context" -n demo get deployments,pods,services,ingresses 2>/dev/null || true
    printf 'Application: http://localhost:8080\n'
    ;;
  down)
    if cluster_exists; then
      kind delete cluster --name "$cluster_name"
    else
      printf 'Cluster %s does not exist.\n' "$cluster_name"
    fi
    ;;
  *)
    printf 'Usage: %s {up|verify|status|down}\n' "$0" >&2
    exit 2
    ;;
esac
