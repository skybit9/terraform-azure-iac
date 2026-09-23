# Terraform Azure DevOps Bootstrap

Creates everything that must exist **before** the CI and CD pipelines can run.

## Run order

```bash
source ./00-variables.sh     # edit the values in this file first
./01-state-backend.sh        # storage account for state (chicken-and-egg resource)
./02-identities.sh           # 6 service principals: plan + apply per environment
source ./identities.env      # load the generated IDs
./03-rbac.sh                 # role assignments, including the data-plane role
# --- create the 6 service connections in Azure DevOps now (manual WIF) ---
./04-federated-credentials.sh
./05-providers.sh            # register resource providers
./99-verify.sh               # confirm everything before a pipeline run
```

Step 04 has a manual break: the Azure DevOps service connection must exist first
so you can match its subject identifier.

## What gets created

| Script | Creates |
|---|---|
| 01 | `rg-terraform-state`, storage account with versioning and soft delete, `tfstate` container, delete lock |
| 02 | 6 app registrations: `sp-terraform-{env}-{plan,apply}` |
| 03 | Reader (plan) or Contributor (apply) on each subscription, plus Storage Blob Data Contributor on the state account |
| 04 | Federated credentials so no client secrets exist |
| 05 | Resource provider registration per subscription |
| 99 | Verification of all of the above |

## Two design choices worth defending

**Plan and apply use separate identities.** CI runs on every pull request. A plan
needs Reader only. If CI ran as Contributor, a PR could add an apply step to the
YAML and escalate. Separate identities close that path.

**No client secrets.** Workload identity federation means the app registration
trusts an OIDC token from a specific Azure DevOps org, project, and service
connection. Nothing to rotate, leak, or store.

## The failure this is built to avoid

Contributor on a storage account is a **management plane** role. It does not grant
read or write on the blobs inside. Terraform needs **Storage Blob Data Contributor**,
a **data plane** role, to touch the state file. Without it `terraform init` succeeds
and `terraform plan` fails with a 403, which reads like a bug rather than a missing
role assignment. Script 99 checks for it explicitly.

## Still manual in Azure DevOps

- 6 service connections (workload identity federation, manual)
- 3 Environments: `terraform-dev`, `terraform-staging`, `terraform-prod`, with approvers
- Branch policy on `main`: required reviewers, CI must pass, branch up to date before merge
