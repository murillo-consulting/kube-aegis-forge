#!/usr/bin/env bash
# Run only against a disposable cluster created by the ingress test workflow.
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
context="${1:?Usage: test-ingress.sh kind-aegis-ingress-NAME image-values.yaml}"
image_values="${2:?A released image-values.yaml file is required}"
case "$context" in
  kind-aegis-ingress-*) ;;
  *) printf 'Refusing a context outside the disposable ingress test namespace.\n' >&2; exit 2 ;;
esac
test_url="${INGRESS_TEST_URL:-http://127.0.0.1:18080}"
scratch="$(mktemp -d)"
forward_pid=""
cleanup() {
  if [[ -n "$forward_pid" ]]; then kill "$forward_pid" 2>/dev/null || true; wait "$forward_pid" 2>/dev/null || true; fi
  rm -rf -- "$scratch"
}
trap cleanup EXIT
uv run --locked --script "$repo_root/scripts/check-ingress.py" --output "$scratch"
kubectl --context "$context" create namespace demo --dry-run=client -o yaml | kubectl --context "$context" apply -f -
kubectl --context "$context" create namespace traefik --dry-run=client -o yaml | kubectl --context "$context" apply -f -
kubectl --context "$context" apply -n traefik -f "$scratch/traefik.yaml"
kubectl --context "$context" -n traefik rollout status deployment/traefik --timeout=5m

install_workload() {
  helm upgrade --install demo-api "$repo_root/platform/charts/demo-api" \
    --kube-context "$context" --namespace demo \
    --values "$repo_root/platform/environments/local/values.yaml" \
    --values "$image_values" \
    --set monitoring.serviceMonitor.enabled=false \
    --set monitoring.prometheusRule.enabled=false \
    "$@" --wait --timeout 5m
}
expect_http() {
  local path="$1" expected="$2" response="" attempt
  for attempt in {1..30}; do
    if response="$(curl --fail --silent --show-error --max-time 5 "$test_url$path")" &&
      grep -Fq "$expected" <<<"$response"; then return; fi
    sleep 2
  done
  printf 'HTTP contract failed for %s\n' "$path" >&2; return 1
}
install_workload
expect_http / '"name":"devsecops-demo-api"'
expect_http /health/live '"status":"ok"'
expect_http /health/ready '"status":"ready"'
expect_http /metrics demo_api_http_requests_total
[[ "$(kubectl --context "$context" -n demo get ingress demo-api -o jsonpath='{.spec.ingressClassName}')" == traefik ]]
kubectl --context "$context" -n demo wait ingress/demo-api \
  --for=jsonpath='{.status.loadBalancer.ingress[0].hostname}'=localhost --timeout=60s
printf '[ok] HTTP endpoints, NodePort and Ingress status\n'

# TLS is an opt-in compatibility check, not a public listener or ACME setup.
cat >"$scratch/cert.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = extensions
prompt = no
[dn]
CN = aegis.test
[extensions]
subjectAltName = DNS:aegis.test
EOF
umask 077
openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -config "$scratch/cert.cnf" -keyout "$scratch/tls.key" -out "$scratch/tls.crt" 2>/dev/null
kubectl --context "$context" -n demo create secret tls ingress-test-tls \
  --cert="$scratch/tls.crt" --key="$scratch/tls.key"
install_workload --set 'ingress.hosts[0].host=aegis.test' \
  --set 'ingress.tls[0].hosts[0]=aegis.test' --set 'ingress.tls[0].secretName=ingress-test-tls'
kubectl --context "$context" -n traefik port-forward --address 127.0.0.1 \
  deployment/traefik 18443:8443 >"$scratch/forward.log" 2>&1 &
forward_pid=$!
tls_ok=false
for attempt in {1..30}; do
  if response="$(curl --fail --silent --show-error --max-time 5 --noproxy '*' \
    --cacert "$scratch/tls.crt" --resolve aegis.test:18443:127.0.0.1 \
    https://aegis.test:18443/health/ready)" && grep -Fq '"status":"ready"' <<<"$response"; then
    tls_ok=true; break
  fi
  sleep 2
done
[[ "$tls_ok" == true ]]
printf '[ok] TLS routing with hostname and certificate verification\n'
kill "$forward_pid"; wait "$forward_pid" 2>/dev/null || true; forward_pid=""
install_workload
kubectl --context "$context" -n demo delete secret ingress-test-tls
kubectl --context "$context" -n traefik rollout restart deployment/traefik
kubectl --context "$context" -n traefik rollout status deployment/traefik --timeout=5m
expect_http /health/ready '"status":"ready"'
printf '[ok] Controller restart and return to the default HTTP configuration\n'
printf 'Ingress integration passed. NetworkPolicy peers are rendered checks; kindnet does not enforce network isolation.\n'
