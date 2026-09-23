# terraform-azure-iac

Reference implementation for converting manually provisioned Azure infrastructure
into governed, modular, pipeline-deployed Terraform.

## Layout

```
modules/            Reusable Azure modules (main, variables, outputs, versions)
environments/       One folder per environment, each with its own state key
pipelines/          Azure DevOps CI (plan) and CD (apply) definitions
```

Environments are separate folders rather than Terraform workspaces. A forgotten
`terraform workspace select` applies Dev changes to Production; separate folders
with their own backend config make that structurally impossible.

## Branch strategy

| Branch      | Trigger        | Pipeline                                   |
|-------------|----------------|--------------------------------------------|
| `feature/*` | PR into `main` | `ci-plan.yml`: fmt, validate, tflint, Checkov, plan. Never applies |
| `main`      | Merge          | `cd-apply.yml`: fresh plan, then apply behind environment approval gates |

CD re-plans inside the approval gate rather than replaying the PR artifact, so a
PR merged in between cannot cause a stale plan to be applied. Branch policy
requires branches to be up to date with `main` before merge.

## Modules

### linux-vm

Production pattern: no public IP, SSH key generated at plan time and stored in
Key Vault, NSG restricted to a private CIDR, system assigned managed identity,
password authentication disabled.

```hcl
module "app_vm" {
  source = "../../modules/linux-vm"

  vm_name             = "vm-app-prod-001"
  resource_group_name = "rg-app-prod"
  location            = "canadacentral"
  subnet_id           = module.networking.app_subnet_id
  key_vault_id        = module.keyvault.key_vault_id
  tags                = var.tags
}
```

## Bringing existing infrastructure under management

1. Bootstrap the state storage account outside the Terraform it serves
2. Inventory the subscription, exclude `MC_*`, `NetworkWatcherRG`, `DefaultResourceGroup-*`
3. Export one resource group at a time with `aztfexport`, or use `import` blocks
4. Reconcile until `terraform plan` returns **No changes**
5. Refactor into modules using `moved` blocks so nothing is destroyed
6. Wire into CI and CD, enable nightly drift detection
7. Remove Contributor from humans so the pipeline is the only write path

## Security notes

- State contains secrets in plaintext. Storage account uses encryption at rest,
  private endpoint, versioning, and RBAC scoped to the pipeline identity.
- `.gitignore` excludes `*.tfstate`, `*.tfvars`, and saved plans. Only
  `*.tfvars.example` is committed.
- Checkov scans the resolved plan JSON, not raw HCL, so values from variables,
  locals, and module outputs are evaluated.
- Azure Policy `Deny` effects at management group level are the backstop and
  apply regardless of origin: pipeline, portal, CLI, or SDK.
