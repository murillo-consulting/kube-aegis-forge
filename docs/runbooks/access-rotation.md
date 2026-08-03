# Runbook: access review and rotation

## GitHub

Quarterly and after personnel changes:

1. review repository collaborators, CODEOWNERS, branch rules, and environment reviewers;
2. restrict `aws` and `aws-apply` environments to `main`;
3. review workflow token permissions and every pinned Action SHA;
4. revoke stale personal access tokens and active sessions.

GitHub Actions and AWS use OIDC, so there is no repository AWS access key to rotate. If trust is suspected compromised, disable the IAM OIDC roles, repair the GitHub control plane, then recreate or update the trust policies from the bootstrap root.

## Local Grafana and Argo CD

The local Grafana password is generated during bootstrap and stored only as a Kubernetes Secret. To rotate it, remove that exact Secret and run `task local:up`; do not write the value to Git. Argo CD's bootstrap admin credential is similarly cluster-local; rotate or disable the admin account after configuring a real identity provider in any non-demo environment.

## Audit evidence

Record who reviewed access, which roles or accounts changed, the date, and any follow-up. Never paste secrets into the record.

