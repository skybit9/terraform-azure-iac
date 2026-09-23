# terraform-azure-iac

Reference implementation for converting manually provisioned Azure
infrastructure into governed, modular, pipeline-deployed Terraform on Azure
DevOps.

## Getting started

Two separate systems. **Bootstrap** is run by hand, once, from your terminal.
**Pipelines** run automatically in Azure DevOps afterward. Editing
`bootstrap/00-variables.sh` does not trigger any pipeline, and pipelines never
read it.

### Phase 1: bootstrap (manual, once)

Prerequisites: Azure CLI logged in (`az login`) as someone who can create app
registrations, role assignments, and a custom role in all four subscriptions.

| Step | Where | Action |
|---|---|---|
| 1 | `bootstrap/00-variables.sh` | Set `SUB_MGMT`, `SUB_DEV`, `SUB_STAGING`, `SUB_PROD`, `ADO_ORG_NAME`, `ADO_PROJECT` |
| 2 | terminal | `az storage account check-name --name tfstatedev001` (and staging, prod). All must return `true` |
| 3 | terminal | `./01-state-backend.sh` |
| 4 | terminal | `./02-identities.sh` |
| 5 | terminal | `./03-rbac.sh` |
| 6 | Azure DevOps | Create **2 service connections per stack per environment** (18 for the starting layout): Azure Resource Manager, Workload identity federation (manual), named exactly `SVC-TF-<env>-<stack id>-<plan\|apply>` where stack id is `networking`, `keyvault`, or the lowercased RG name. Each scoped to its environment's subscription |
| 7 | terminal | `./04-federated-credentials.sh` |
| 8 | Azure DevOps | **Verify and save** each service connection |
| 9 | terminal | `./05-providers.sh` |
| 10 | terminal | `./99-verify.sh`. Do not continue until it passes |

### Phase 2: Azure DevOps setup (manual, once)

| Step | Where | Action |
|---|---|---|
| 11 | Pipelines > Environments | Create `terraform-dev`, `terraform-staging`, `terraform-prod`. Add approvers (a senior approver on prod) |
| 12 | Pipelines > New pipeline | Register `pipelines/ci-plan.yml`, `pipelines/cd-apply.yml`, `pipelines/drift-detection.yml` |
| 13 | Repos > Branches > `main` | Branch policy: minimum reviewers, **ci-plan** as required build validation, require branch up to date before merge |
| 14 | Repo | Push `main`, then tag the module: `git tag -a v1.0.0 -m "linux-vm initial release" && git push origin v1.0.0`. Protect the tag |

### Phase 3: first deployment

| Step | Action | Expect |
|---|---|---|
| 15 | Run **cd-apply** manually, or merge any change under `environments/` | Approve `dev`; shared/networking, shared/keyvault, then workload RGs |
| 16 | Approve `staging`, then `prod` | Same order in each |
| 17 | Next morning | **drift-detection** runs green |

On a brand new environment the **app** stack's CI plan fails until
networking and keyvault have been applied once, because there is no upstream
state to read yet. This happens only the first time.

### From then on (automatic)

1. Branch `feature/*`, change code or tfvars, open a PR
2. **CI** plans all stacks; review the plan output
3. Merge: **CD** applies each environment after its approval
4. **Drift detection** checks prod nightly

### Kept in sync by hand

| Value | Defined in | Must match |
|---|---|---|
| Workload RG list | folders under `environments/<env>/` except `shared/` (read by bootstrap) | `workloads` in `pipelines/templates/environments.yml`. **CI enforces** |
| State storage account names `tfstate<env>001` | `sa_for_env()` in `bootstrap/00-variables.sh` | `pipelines/templates/*-steps.yml` and `state_storage_account` in every workload `terraform.tfvars` |
| Service connection names | `04-federated-credentials.sh` prints them | Azure DevOps connection names |

If a storage account name is taken globally, bump `001` to `002` in **all**
places in the second row.

## Layout

```
modules/linux-vm/                       reusable module, consumed by git tag
environments/<env>/
├── shared/
│   ├── networking/                     one VNet per environment
│   └── keyvault/                       one Key Vault per environment
└── <resource-group-name>/              one folder per workload RG; folder name = RG name
pipelines/
├── ci-plan.yml | cd-apply.yml | drift-detection.yml
└── templates/environments.yml          THE list of environments and workload RGs
bootstrap/                              one-time Azure and Azure DevOps prerequisites
.checkov.yaml | .tflint.hcl
```

## State topology

```
MANAGEMENT SUBSCRIPTION
└── rg-terraform-state
    ├── tfstatedev001       tfstate-networking | tfstate-keyvault | tfstate-<each dev RG>
    ├── tfstatestaging001   same pattern
    └── tfstateprod001      same pattern
```

- **State lives outside the subscriptions it describes.** Deleting or moving a
  workload subscription must not destroy the state that manages it.
- **One container per stack.** A container is an RBAC scope; a blob key is not.
  Each stack's identities can reach only their own container (workloads also
  get read on the two shared containers).
- **Shared key access is disabled** on every state account, so the backend
  authenticates with Entra ID (`use_azuread_auth = true`).

## Stacks

| Kind | Folder | Resource group | State container |
|---|---|---|---|
| shared | `shared/networking` | `rg-networking-<env>` | `tfstate-networking` |
| shared | `shared/keyvault` | `rg-keyvault-<env>` | `tfstate-keyvault` |
| workload | `<rg-name>` | `<rg-name>` exactly | `tfstate-<lowercased rg-name>` |

**Networking and Key Vault are shared by every workload RG in an
environment.** A new workload RG never gets its own VNet or vault; it reads the
shared ones through `terraform_remote_state`.

Apply order per environment: `shared/networking`, `shared/keyvault`, then all
workload RGs in parallel. On a brand new environment, workload CI plans fail
until the shared stacks have been applied once; that is expected.

## Adding a workload resource group

1. `mkdir environments/<env>/<rg-name>` and copy `backend.tf`,
   `providers.tf`, `versions.tf` from an existing workload
2. Write the Terraform (or import, below). `resource_group_name` in its
   `terraform.tfvars` must equal the folder name
3. Add `<rg-name>` to that environment's `workloads` in
   `pipelines/templates/environments.yml`
4. Bootstrap: rerun `01` to `04`, then create its two service connections
   `SVC-TF-<env>-<lowercased rg-name>-plan` and `-apply`
5. PR, CI, merge, CD

`shared` is reserved and cannot be a workload name. CI fails if step 3 is forgotten, if an extra entry has no folder, or if the
folder name and `resource_group_name` differ.

Lowercased RG names must be 3 to 55 characters of `a-z`, `0-9`, and single
hyphens, because they become state container names. Bootstrap and CI both
reject anything else.

## Bringing an existing resource group under Terraform

Same as above, with the code generated from Azure instead of written:

```bash
cd environments/dev/<existing-rg-name>
aztfexport resource-group <existing-rg-name> \
  --hcl-only --generate-import-block --non-interactive --output-dir ./export
mv export/main.tf main.tf && mv export/import.tf import.tf && rm -rf export
terraform init -backend=false && terraform plan
```

`--hcl-only` writes no state: state is only ever written by CD, through the
approval gate. Reconcile the HCL until the plan reads **N to import, 0 to add,
0 to change, 0 to destroy**, then continue from step 3 above. After CD applies,
remove `import.tf` in a follow-up PR and remove human write access on the RG.

Bootstrap never modifies an existing resource group: `az group create` on an
existing group replaces its tags, which would show as drift immediately after
import, so groups are only created when missing.

## Adding or removing a VM

VMs are defined in `locals` in `environments/<env>/rg-app-<env>/main.tf`:

```hcl
locals {
  vms = {
    "vm-app-dev-01" = { vm_size = "Standard_B2s", os_disk_size_gb = 64, os_disk_type = "StandardSSD_LRS" }
    "vm-app-dev-02" = { vm_size = "Standard_B2s", os_disk_size_gb = 64, os_disk_type = "StandardSSD_LRS" }
  }
}
```

The module is called once with `for_each = local.vms`, keyed by VM name.
Removing an entry destroys only that VM; the others are never in the plan.
**Never rename a key**: Terraform treats it as destroy old, create new.

Trade-off accepted: `locals` has no type checking, so a misspelled attribute
surfaces as a module error at plan rather than a variable type error.

## Module versioning

Stacks consume the module by git tag:

```hcl
source = "git::https://github.com/skybit9/terraform-azure-iac.git//modules/linux-vm?ref=v1.0.0"
```

To release a module change: merge it, tag `v1.1.0`, bump `?ref=` in **dev**
only, let it run, then staging, then prod. Run `terraform init -upgrade` after
changing a ref. **Protect release tags** so a tag cannot be moved; a movable
tag is a moving target.

## Identities

Two service principals per stack per environment, `plan` and `apply`
(18 for the starting layout). No client secrets: authentication is workload
identity federation.

- `plan` holds **Reader**. CI runs on every pull request, so a PR that adds an
  apply step to the YAML still cannot change Azure.
- `apply` holds **Contributor** on its own resource group only.
- Workload identities also get read access to the shared networking and
  keyvault state, Key Vault secrets roles, and subnet join on the shared VNet.

Every grant and its reason: `bootstrap/README.md`.

## Pipelines

| Pipeline | Trigger | Does |
|---|---|---|
| `ci-plan.yml` | PR into `main` | fmt, config-matches-folders check, validate, tflint, then plan + Checkov for every stack in parallel. Never applies |
| `cd-apply.yml` | merge to `main` | per environment: **one approval**, then shared/networking, shared/keyvault, then all workload RGs in parallel. Fresh plan inside the gate, then applies exactly that saved plan |
| `drift-detection.yml` | nightly | read-only plan of every stack in `driftEnvironments` (prod); exit code 2 fails the run |

Optional: a secret pipeline variable `GITHUB_TOKEN` (GitHub PAT, no scopes)
lifts GitHub's unauthenticated rate limit for the tflint ruleset download.
Do not use `System.AccessToken` for this; it is an Azure DevOps token.

CD re-plans rather than replaying the PR's plan artifact, so a PR merged in
between cannot cause a stale plan to be applied. Branch policy requires the
branch to be up to date with `main` before merge.

## Policy scanning

Checkov scans the **resolved plan JSON** in CI, not only raw HCL, so values
from variables, locals, and module outputs are evaluated. Open source Checkov
has no severities without a Prisma Cloud API key, so this repo **fails on every
finding** and lists each accepted exception, with its reason, in
`.checkov.yaml`. Adding an exception therefore requires a reviewed PR.

Azure Policy `Deny` assignments at management group level are the backstop:
they apply regardless of origin, pipeline, portal, CLI, or SDK.

## Known limits and hardening path

| Limit | Why | Hardening |
|---|---|---|
| Key Vault public endpoint reachable | Microsoft hosted agents write the SSH secrets from outside the VNet | Private endpoint + self hosted agent in the VNet, then `public_network_access_enabled = false` |
| Generated SSH private key is in state | `tls_private_key` stores it there, in plaintext | Generate keys outside Terraform and pass only the public key |
| Module pinned by tag, not commit SHA | Readable promotion | Tag protection, or pin SHAs |

## Verification performed on this revision

| Check | Tool | Result |
|---|---|---|
| Formatting and HCL syntax, all files | OpenTofu `fmt -check` | clean |
| Resource argument names | checked against azurerm **4.81.0** provider source | all present |
| Module inputs, tfvars, remote state outputs, version pins | custom cross-reference check | pass |
| Security policy | Checkov 3.3 | 47 passed, 0 failed |
| Bootstrap scripts | shellcheck, `bash -n` | clean |
| Pipelines | yamllint strict + simulated template expansion | clean |

Not verifiable without Azure credentials and provider downloads: `terraform
validate` against the real provider schema, and a live plan. Run
`terraform init -backend=false && terraform validate` in each stack, which the
CI Validate stage does on every PR.
