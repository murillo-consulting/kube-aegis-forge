# Contributing

## Development workflow

1. Create a branch from `main` and keep the change focused.
2. Never add credentials, copied production data, generated plans, or screenshots from an unverified run.
3. Update an ADR when a change affects a trust boundary, deployment contract, or major dependency.
4. Run the relevant checks before opening a pull request.

```bash
task app:check
task helm:check
task tofu:check
task security:check
```

For platform changes, also run the Kyverno tests and, when workstation capacity permits, `task local:up` followed by `task local:verify` and `task local:down`.

## Pull requests

A pull request must explain the problem, the chosen solution, security and operational impact, test evidence, and rollback path. Required checks must pass. CODEOWNERS routes sensitive changes; an independent required approval must be enabled when a second maintainer exists. Force pushes to `main` are prohibited.

Dependencies and GitHub Actions must be pinned to an immutable version or full commit SHA. Generated `gitops` state is changed only by the promotion and rollback workflows.
