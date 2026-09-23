# ── PROVIDERS AND DATA ────────────────────────────────────────────────────────

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ── SSH KEY PAIR ──────────────────────────────────────────────────────────────
# Generate a 4096-bit RSA key pair at plan time.
# Private key is stored in Key Vault only. Never written to disk or state in plaintext.

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Store the private key in Key Vault as a secret.
# Pipeline managed identity needs Key Vault Secrets Officer role.
resource "azurerm_key_vault_secret" "ssh_private_key" {
  name         = "${var.vm_name}-ssh-private-key"
  value        = tls_private_key.ssh.private_key_pem
  key_vault_id = var.key_vault_id

  tags = var.tags
}

# Store the public key in Key Vault for reference and auditing.
resource "azurerm_key_vault_secret" "ssh_public_key" {
  name         = "${var.vm_name}-ssh-public-key"
  value        = tls_private_key.ssh.public_key_openssh
  key_vault_id = var.key_vault_id

  tags = var.tags
}

# ── NETWORK SECURITY GROUP ────────────────────────────────────────────────────
# Allows SSH only from a private CIDR. No public IP means no internet exposure.
# Deny-all outbound is intentionally not set here; adjust per security baseline.

resource "azurerm_network_security_group" "vm" {
  name                = "nsg-${var.vm_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow SSH inbound from private network only
  security_rule {
    name                       = "Allow-SSH-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.nsg_allowed_ssh_source
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic explicitly
  security_rule {
    name                       = "Deny-All-Inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# ── NETWORK INTERFACE ─────────────────────────────────────────────────────────
# Private IP only. No public IP attached. VM reachable via bastion or VPN only.

resource "azurerm_network_interface" "vm" {
  name                = "nic-${var.vm_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id intentionally omitted
  }

  tags = var.tags
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# ── LINUX VIRTUAL MACHINE ─────────────────────────────────────────────────────

resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  # Disable password authentication; SSH key only
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  os_disk {
    name                 = "osdisk-${var.vm_name}"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb

    # Encrypt OS disk with platform managed key (PMK).
    # Swap disk_encryption_set_id in for customer managed key (CMK) if required.
  }

  source_image_reference {
    publisher = var.source_image.publisher
    offer     = var.source_image.offer
    sku       = var.source_image.sku
    version   = var.source_image.version
  }

  # Assign system managed identity so VM can authenticate to Key Vault without credentials
  identity {
    type = "SystemAssigned"
  }

  # Boot diagnostics to a managed storage account (no SA URI = managed)
  boot_diagnostics {}

  tags = var.tags
}

# ── KEY VAULT ACCESS POLICY FOR VM MANAGED IDENTITY ──────────────────────────
# Allows the VM itself to read secrets from Key Vault at runtime (e.g. app secrets).
# Separate from the pipeline managed identity that wrote the SSH keys.

resource "azurerm_key_vault_access_policy" "vm" {
  key_vault_id = var.key_vault_id
  tenant_id    = azurerm_linux_virtual_machine.vm.identity[0].tenant_id
  object_id    = azurerm_linux_virtual_machine.vm.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}
