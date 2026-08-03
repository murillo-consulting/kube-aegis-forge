# Runbook: AWS destruction and retained state

## Cost and impact warning

Destroy removes the optional EKS cluster, node group, VPC networking, and related project resources. It does not remove the separately bootstrapped S3 state bucket or OIDC roles. Confirm no workload or audit requirement depends on the cluster.

## GitHub workflow

1. Open **AWS infrastructure** and select `destroy`.
2. Provide the current `admin_cidrs` JSON value.
3. Enter exactly `kube-aegis-forge` in the confirmation field.
4. Obtain approval from the `aws-apply` environment.
5. Review the completed run and confirm EKS and NAT Gateway removal in AWS.

## Local CLI

Set `TF_STATE_BUCKET`, `TF_VAR_admin_cidrs`, and `TF_VAR_cluster_admin_role_arn`, then run `task aws:destroy`. The script requires the full project name interactively and leaves the bucket and its KMS key untouched.

## Separate state-bucket retirement

State deletion is intentionally not automated with cluster destruction. Before retiring it:

1. export the current and historical state versions to approved archival storage;
2. confirm there are no remaining OpenTofu roots using the bucket;
3. remove `prevent_destroy` through a reviewed bootstrap change;
4. delete object versions and lockfiles using an explicitly authorized operator procedure;
5. destroy the bootstrap root and record the audit evidence.

This is destructive and not recoverable after versioned objects and backups are removed.

