#!/usr/bin/env bash
set -euo pipefail

command_name="${1:-}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tofu_root="$repo_root/infra/aws/eks"
plan_directory="$repo_root/.plans"
plan_path="$plan_directory/aws.tfplan"
hash_path="$plan_directory/aws.tfplan.sha256"

: "${TF_STATE_BUCKET:?TF_STATE_BUCKET must be set}"
: "${TF_VAR_admin_cidrs:?TF_VAR_admin_cidrs must be set to a JSON list}"
: "${TF_VAR_cluster_admin_role_arn:?TF_VAR_cluster_admin_role_arn must be set to an existing IAM role ARN}"

tofu -chdir="$tofu_root" init \
  -backend-config="bucket=$TF_STATE_BUCKET" \
  -backend-config="region=eu-west-3" \
  -backend-config="key=eks/kube-aegis-forge.tfstate" \
  -backend-config="use_lockfile=true"

case "$command_name" in
  plan)
    mkdir -p "$plan_directory"
    tofu -chdir="$tofu_root" plan -out="$plan_path"
    sha256sum "$plan_path" >"$hash_path"
    printf 'Saved plan and SHA256 under %s\n' "$plan_directory"
    ;;
  apply)
    [[ -f "$plan_path" && -f "$hash_path" ]] || { printf 'Run task aws:plan first.\n' >&2; exit 1; }
    sha256sum --check "$hash_path"
    read -r -p 'Enter APPLY to apply the saved plan: ' confirmation
    [[ "$confirmation" == "APPLY" ]] || { printf 'Apply cancelled.\n' >&2; exit 1; }
    tofu -chdir="$tofu_root" apply "$plan_path"
    ;;
  destroy)
    read -r -p 'Enter kube-aegis-forge to destroy EKS resources: ' confirmation
    [[ "$confirmation" == "kube-aegis-forge" ]] || { printf 'Destroy cancelled.\n' >&2; exit 1; }
    tofu -chdir="$tofu_root" destroy
    printf 'EKS resources destroyed. The bootstrap state bucket was retained.\n'
    ;;
  *)
    printf 'Usage: %s {plan|apply|destroy}\n' "$0" >&2
    exit 2
    ;;
esac

