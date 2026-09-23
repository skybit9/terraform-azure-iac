# terraform-azure-iac

Reference implementation for converting manually provisioned Azure
infrastructure into governed, modular, pipeline-deployed Terraform on Azure
DevOps.

## Layout

```
modules/linux-vm/          reusable module, consumed by git tag
environments/<env>/<stack> one root module per environment and stack
pipelines/                 CI (plan), CD (apply), nightly drift detection
bootstrap/                 one-time Azure and Azure DevOps prerequisites
.checkov.yaml              policy scan config with every exception justified
.tflint.hcl                lint rules
```

## State topology

```
MANAGEMENT SUBSCRIPTION
└── rg-terraform-state
    ├── tfstatedev001       tfstate-networking | tfstate-keyvault | tfstate-app
    ├── tfstatestaging001   same three containers
    └── tfstateprod001      same three containers
```

- **State lives outside the subscriptions it describes.** Deleting or moving a
  workload subscription must not destroy the state that manages it.
- **One container per stack.** A container is an RBAC scope; a blob key is not.
  Each stack's identities can reach only their own container.
- **Shared key access is disabled** on every state account, so the backend
  authenticates with Entra ID (`use_azuread_auth = true`).

## Stacks

| Stack | Resource group | Contains | Read by |
|---|---|---|---|
| `networking` | `rg-networking-<env>` | VNet, subnet, subnet NSG | app |
| `keyvault` | `rg-keyvault-<env>` | Key Vault (RBAC mode) | app |
| `app` | `rg-app-<env>` | VMs from `modules/linux-vm` | |

The app stack reads the others through `terraform_remote_state`, so **apply
order is networking, keyvault, app**. On a brand new environment the first CI
plan of the app stack fails until networking and keyvault have been applied
once; that is expected.

## Adding or removing a VM

VMs are a map in `environments/<env>/app/terraform.tfvars`:

```hcl
vms = {
  "vm-app-dev-01" = { vm_size = "Standard_B2s", os_disk_size_gb = 64, os_disk_type = "StandardSSD_LRS" }
  "vm-app-dev-02" = { vm_size = "Standard_B2s", os_disk_size_gb = 64, os_disk_type = "StandardSSD_LRS" }
}
```

The module is called once with `for_each`, keyed by VM name. Removing an entry
destroys only that VM; the others are never in the plan.

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

18 service principals: 3 environments x 3 stacks x {plan, apply}. No client
secrets: authentication is workload identity federation.

- `plan` holds **Reader**. CI runs on every pull request, so a PR that adds an
  apply step to the YAML still cannot change Azure.
- `apply` holds **Contributor** on its own resource group only.

Every grant and its reason: `bootstrap/README.md`.

## Pipelines

| Pipeline | Trigger | Does |
|---|---|---|
| `ci-plan.yml` | PR into `main` | fmt, validate, tflint, then plan + Checkov for all 9 stacks in parallel. Never applies |
| `cd-apply.yml` | merge to `main` | per environment: **one approval**, then networking, keyvault, app in order. Fresh plan inside the gate, then applies exactly that saved plan |
| `drift-detection.yml` | nightly | read-only plan of prod stacks; exit code 2 fails the run |

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
