# terraform-azure-iac

Reference implementation for converting manually provisioned Azure
infrastructure into governed, modular, pipeline-deployed Terraform.

## State topology

```
MANAGEMENT SUBSCRIPTION
└── rg-terraform-state
    ├── tfstatedev001
    │   ├── tfstate-networking   -> terraform.tfstate
    │   ├── tfstate-keyvault     -> terraform.tfstate
    │   └── tfstate-app          -> terraform.tfstate
    ├── tfstatestaging001  (same three containers)
    └── tfstateprod001     (same three containers)
```

**State lives outside the subscription it describes.** If a workload
subscription is deleted, disabled, or moved between tenants, the state
describing it would die with it and every resource would need re-importing by
hand. The management subscription removes that dependency.

**One container per stack, not one container with many blob keys.** A container
is an RBAC scope; a blob key is not. Scoping `Storage Blob Data Contributor` at
the container means the app pipeline identity cannot read networking state. With
one shared container, any identity with data access reads every state file in it.

**One storage account per environment.** State cannot cross an environment
boundary by accident, even through a misconfigured backend block.

## Stacks

Each stack is one resource group, one container, one state file, and its own
pipeline identities.

| Stack | Resource group | Owns | Consumed by |
|---|---|---|---|
| `networking` | `rg-networking-<env>` | VNet, subnets | keyvault, app |
| `keyvault` | `rg-keyvault-<env>` | Key Vault | app |
| `app` | `rg-app-<env>` | Linux VM via module | - |

The app stack reads upstream outputs through `terraform_remote_state`, so CD
applies networking, then keyvault, then app. That order is not optional.

## Identities

18 service principals: 3 environments x 3 stacks x {plan, apply}.

| Kind | Azure scope | State scope |
|---|---|---|
| `plan` | Reader on the stack's resource group | Blob Data Contributor on its own container |
| `apply` | Contributor on the stack's resource group | Blob Data Contributor on its own container |

Plan and apply are separate because CI runs on every pull request. A plan needs
Reader only, so a PR that adds an apply step to the YAML still cannot change
Azure.

The app identities additionally hold **Blob Data Reader** on the networking and
keyvault containers, granted per container rather than at the account, so the
isolation above survives.

No client secrets anywhere. Authentication is **workload identity federation**:
the app registration trusts an OIDC token issued by Azure DevOps for one
specific org, project, and service connection.

## Branch strategy

| Branch | Trigger | Pipeline |
|---|---|---|
| `feature/*` | PR into `main` | `ci-plan.yml`: fmt, validate, tflint, Checkov, plan. Never applies |
| `main` | Merge | `cd-apply.yml`: fresh plan, then apply behind Environment approval gates |

CD re-plans inside the approval gate rather than replaying the PR artifact, so a
PR merged in between cannot cause a stale plan to be applied. Branch policy
requires branches to be up to date with `main` before merge.

## Bootstrap

Azure-side prerequisites must exist before either pipeline runs.

```bash
cd bootstrap
source ./00-variables.sh     # edit values first
./01-state-backend.sh        # storage accounts and containers
./02-identities.sh           # 18 service principals
source ./identities.env
./03-rbac.sh                 # container-scoped and RG-scoped RBAC
# create the service connections in Azure DevOps, then:
./04-federated-credentials.sh
./05-providers.sh
./99-verify.sh
```

Service connection names must match `SVC-TF-<env>-<stack>-<plan|apply>`.

## Bringing existing infrastructure under management

1. Bootstrap the state backend outside the Terraform it serves
2. Inventory the subscription, exclude `MC_*`, `NetworkWatcherRG`, `DefaultResourceGroup-*`
3. Export one resource group at a time with `aztfexport`, or use `import` blocks
4. Reconcile until `terraform plan` returns **No changes**
5. Refactor into modules using `moved` blocks so nothing is destroyed
6. Wire into CI and CD, enable nightly drift detection
7. Remove Contributor from humans so the pipeline is the only write path

## Security notes

- State contains secrets in plaintext. Storage accounts disable public blob
  access, disable shared key access (forcing Entra auth), enforce TLS 1.2, and
  enable versioning plus soft delete as the recovery path.
- `.gitignore` excludes `*.tfstate`, saved plans, and `bootstrap/identities.env`.
- Checkov scans the resolved plan JSON, not raw HCL, so values from variables,
  locals, and module outputs are evaluated.
- Azure Policy `Deny` effects at management group level are the backstop and
  apply regardless of origin: pipeline, portal, CLI, or SDK.
