# Sync-secrets workflows (monorepo)

Push this repo's GitHub Environment secrets/variables into the AWS resources that
`infrastructure-v1` created (Secrets Manager, SSM Parameter Store, Amplify).
Terraform owns the resources (placeholders + `ignore_changes`); these workflows
own the values.

Drop these files into `.github/workflows/` in the monorepo.

## How it works

- Trigger: `workflow_dispatch` (manual).
- Keys are **derived from the live AWS resource** — no mapping file, no checkout:
  - Backends: keys from the secret doc + SSM params under `/hc/stage/01/<service>`.
  - Amplify: keys from `get-app` (app-level) and each branch from `get-branch`.
- GitHub secret/variable **name == AWS key**. For Amplify branch vars the name is
  `<BRANCH_UPPER>_<key>` (e.g. `STAGE_CASE_INGESTION_URL`).
- Missing/empty GitHub value -> the current AWS value is kept (no wipe).
- After a sync: backends roll the ECS service; Amplify starts a release per branch.

## One-time setup (per service)

1. Create the GitHub Environment `<service>-stage` (e.g. `case-ingestion-stage`,
   `amplify-hellocounsel-dashboard-stage`).
2. Add the app secrets/variables to it, named to match the AWS keys.
3. Add an environment **variable** `DEPLOY_ROLE_ARN` = the deploy role in the
   target account (same value across services in one env).
4. Make the deploy role's OIDC trust policy allow this repo:
   `repo:HelloCounsel/receptionist-monorepo:*` (workflows use `id-token: write`).
5. Confirm the runner label `codebuild-github-actions-runner-*` is available.

## Notes

- Run `terraform apply` (infrastructure-v1) **first** so the secret/params/branches
  exist; otherwise the AWS calls fail (intended guard).
- A key only exists if Terraform seeded it. Adding a key in GitHub alone does
  nothing until infra seeds it.
- Frontend is on Vercel in the monorepo today. Only run the Amplify workflow if
  Amplify is the real target for the dashboard.
