#!/usr/bin/env bash
set -euo pipefail

required=(docker git kubectl helm kind tofu)
optional=(task gh cosign syft trivy gitleaks kubeconform kyverno)
missing=()

printf 'Required tools\n'
for tool in "${required[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  [ok] %s\n' "$tool"
  else
    printf '  [missing] %s\n' "$tool"
    missing+=("$tool")
  fi
done

printf 'Optional validation and release tools\n'
for tool in "${optional[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  [ok] %s\n' "$tool"
  else
    printf '  [optional] %s\n' "$tool"
  fi
done

if ((${#missing[@]} > 0)); then
  printf 'Missing required tools: %s\n' "${missing[*]}" >&2
  exit 1
fi

docker info >/dev/null
docker_memory="$(docker info --format '{{.MemTotal}}')"
minimum_memory=$((10 * 1024 * 1024 * 1024))
if ((docker_memory < minimum_memory)); then
  printf 'Docker exposes less than the required 10 GiB.\n' >&2
  exit 1
fi

printf 'Docker memory: %s GiB\n' "$((docker_memory / 1024 / 1024 / 1024))"

kind version | grep -Eq '0\.32\.0' || { printf 'kind 0.32.0 is required.\n' >&2; exit 1; }
helm version --short | grep -Eq '^v4\.2\.3' || { printf 'Helm 4.2.3 is required.\n' >&2; exit 1; }
tofu version -json | grep -Eq '"terraform_version"[[:space:]]*:[[:space:]]*"1\.12\.5"' || {
  printf 'OpenTofu 1.12.5 is required.\n' >&2
  exit 1
}

printf 'Pinned versions: kind 0.32.0, Helm 4.2.3, OpenTofu 1.12.5\n'
printf 'Tooling check passed.\n'
