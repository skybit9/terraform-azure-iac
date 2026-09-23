# Bootstrap

Creates everything that must exist before the pipelines can run. Idempotent:
every script is safe to re-run.

## Run order

```bash
cd bootstrap
# 1. edit subscription IDs, ADO org and project in 00-variables.sh
./01-state-backend.sh           # state accounts + containers (management sub)
./02-identities.sh              # 18 service principals -> identities.env
./03-rbac.sh                    # resource groups, custom role, all role assignments
#    ── create 18 service connections in Azure DevOps (see 04 header) ──
./04-federated-credentials.sh   # workload identity federation, no secrets
./05-providers.sh               # resource provider registration
./99-verify.sh                  # exits non-zero if anything is missing
```

Also create in Azure DevOps: Environments `terraform-dev`, `terraform-staging`,
`terraform-prod` with approvers, and branch policy on `main` (reviewers, CI
must pass, branch up to date before merge).

## Why each role exists

| Identity | Role | Scope | Needed because |
|---|---|---|---|
| every `*-plan` | Reader | own RG | plan refreshes existing resources |
| every `*-apply` | Contributor | own RG | apply creates and changes resources |
| every identity | Storage Blob Data Contributor | own state container | Contributor on a storage account does not grant blob access; plan also writes state |
| `app-*` | Storage Blob Data Reader | networking + keyvault containers | `terraform_remote_state` reads their outputs |
| `app-*` | Reader | `rg-keyvault-<env>` | read the vault's properties |
| `app-plan` | Key Vault Secrets User | `rg-keyvault-<env>` | refresh reads existing secret values |
| `app-apply` | Key Vault Secrets Officer | `rg-keyvault-<env>` | writes the VM SSH key secrets |
| `app-apply` | Terraform Subnet Joiner (custom) | `rg-networking-<env>` | a NIC joining a subnet in another RG needs `subnets/join/action` there |

The custom role grants only VNet read and subnet join. Network Contributor
would also let the app stack modify the network.
