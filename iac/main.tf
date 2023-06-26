locals {
  private_dns_zones = {
    privatelink-blob-core-windows-net           = "privatelink.blob.core.windows.net"
    privatelink-vaultcore-azure-net             = "privatelink.vaultcore.azure.net"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource-group-name
  location = var.location
}

resource "azurerm_private_dns_zone" "private_dns_zones" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.location}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "Github_Runner_Subnet" {
  name                 = "GitHubRunnerSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
  depends_on           = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "Private_Endpoint_Subnet" {
  name                                           = "PrivateEndpointSubnet"
  resource_group_name                            = azurerm_resource_group.rg.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = ["10.1.2.0/24"]
  enforce_private_link_endpoint_network_policies = true
  depends_on                                     = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "Azure_Bastion_Subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.3.0/24"]
  depends_on           = [azurerm_virtual_network.vnet]
}

resource "azurerm_public_ip" "bastion" {
  name                = "bastion-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "bastion" {
  name                = "bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                 = "bastion-ip"
    subnet_id            = azurerm_subnet.Azure_Bastion_Subnet.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

resource "azurerm_network_interface" "linux_vm_nic" {
  name                = "linux-vm-01-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.Github_Runner_Subnet.id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
  }
}

resource "azurerm_virtual_machine" "linux_vm" {
  name                  = "linux-vm-01"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.linux_vm_nic.id]
  vm_size               = "Standard_DS1_v2"

  identity {
    type = "SystemAssigned"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "linux-vm-01-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = var.ssh_public_key
    }
  }

  os_profile {
    computer_name  = "linux-vm-01"
    admin_username = var.admin_username
  }
}

resource "azurerm_role_assignment" "github_runner_contributor_role" {
  role_definition_name = "Contributor"
  principal_id = azurerm_virtual_machine.linux_vm.identity.0.principal_id
  scope = azurerm_resource_group.rg.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_network_links" {
  for_each              = local.private_dns_zones
  name                  = "${azurerm_virtual_network.vnet.name}-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.vnet.id
  depends_on            = [azurerm_private_dns_zone.private_dns_zones]
}

resource "random_string" "random" {
  length  = 4
  special = false
}

resource "azurerm_storage_account" "sa" {
  name                     = "${var.location}${random_string.random.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
  access_tier = "hot"
  account_kind = "StorageV2"
  default_to_oauth_authentication = true
  shared_access_key_enabled = false
  enable_https_traffic_only = true
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
  public_network_access_enabled = false
}

resource "azurerm_storage_account_container" "sa_container" {
  name                  = "test"
  storage_account_name  = azurerm_storage_account.sa.name
  container_access_type = "private"
}

resource "azurerm_private_endpoint" "sa_pe" {
  name                = "${azurerm_storage_account.name}-pe"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = azurerm_subnet.Private_Endpoint_Subnet.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-blob-core-windows-net"].id]
  }
  private_service_connection {
    is_manual_connection           = false
    private_connection_resource_id = azurerm_storage_account.sa.id
    name                           = "${azurerm_storage_account.sa.name}-psc"
    subresource_names              = ["blob"]
  }
  depends_on = [azurerm_storage_account.sa]
}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.location}-${random_string.random.result}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  enable_rbac_authorization   = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"
  public_network_access_enabled = false
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

resource "azurerm_role_assignment" "sa_data_contributor" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Storage Account Data Contributor"
  principal_id         = azurerm_virtual_machine.linux_vm.identity.0.principal_id
}

resource "azurerm_storage_blob" "blobs" {
  for_each = fileset(path.cwd, "uploads/*")
 
  name                   = trim(each.key, "uploads/")
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_account_container.sa_container.name
  type                   = "Block"
  source                 = each.key
  depends_on = [ azurerm_role_assignment.sa_data_contributor ]
}

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "${azurerm_key_vault.kv.name}-pe"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  subnet_id           = azurerm_subnet.Private_Endpoint_Subnet.id
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.private_dns_zones["privatelink-vaultcore-azure-net"].id]
  }
  private_service_connection {
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.kv.id
    name                           = "${azurerm_key_vault.kv.name}-psc"
    subresource_names              = ["vault"]
  }
  depends_on = [azurerm_key_vault.kv]
}

resource "azurerm_role_assignment" "kv_admin" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_virtual_machine.linux_vm.identity.0.principal_id
}

resource "azurerm_key_vault_secret" "secret" {
  content_type = "text/plain"
  key_vault_id = azurerm_key_vault.kv.id
  name  = "mysecret"
  value = "1234567890"
  depends_on = [ 
    azurerm_role_assignment.github_runner_contributor_role,
    azurerm_role_assignment.kv_admin
    ]
}