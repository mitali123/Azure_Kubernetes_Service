variable "location" {default="East US"}
variable "resource_group" {default="kcluster"}
variable "cluster_name" {default="kcluster"}
variable "dns_prefix" {default="kcluster"}
variable "ssh_public_key" {}
variable "node_count" {default="4"}
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

provider "azurerm" {
  version = "=2.20.0"
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  features {}
}

resource "azurerm_resource_group" "k8s" {
  name     = "${var.resource_group}"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "aksvpc" {
  name                = "aks-vnet"
  location            = azurerm_resource_group.k8s.location
  resource_group_name = azurerm_resource_group.k8s.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "akssubnet" {
  name                 = "aks-subnet"
  virtual_network_name = azurerm_virtual_network.aksvpc.name
  resource_group_name  = azurerm_resource_group.k8s.name
  address_prefixes     = ["10.1.0.0/22"]
  service_endpoints    = ["Microsoft.Sql"]
}

resource "azurerm_kubernetes_cluster" "k8s" {
  name                = "${var.cluster_name}"
  location            = "${azurerm_resource_group.k8s.location}"
  resource_group_name = "${azurerm_resource_group.k8s.name}"
  dns_prefix          = "${var.dns_prefix}"

    linux_profile {
        admin_username = "ubuntu"

        ssh_key {
        key_data = "${file("${var.ssh_public_key}")}"
        }
    }
    addon_profile {
      kube_dashboard {
        enabled = true
    }
  }

    network_profile {
    network_plugin     = "azure"
    load_balancer_sku  = "standard"
    network_policy     = "calico"
  }

    default_node_pool {
        name                = "default"
        node_count          = 4
        vm_size             = "Standard_D2_v2"
        type                = "VirtualMachineScaleSets"
        availability_zones  = ["1", "2", "3"]
        enable_auto_scaling = true
        max_count           = 6
        min_count           = 4
        vnet_subnet_id = azurerm_subnet.akssubnet.id
    }

    service_principal {
        client_id     = "${var.client_id}"
        client_secret = "${var.client_secret}"
    }
}



output "kube_config" {
  value = "${azurerm_kubernetes_cluster.k8s.kube_config_raw}"
}

output "host" {
  value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.host}"
}

resource "azurerm_resource_group" "main" {
    name     = "database"
    location = "East US"
}

resource "azurerm_virtual_network" "k8s" {
  name                = "database-network"
  location            = "${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.1.0.0/24"]
}
#webappdb
resource "azurerm_mysql_server" "webapp-server" {
  name                = "webapp5"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
 
  administrator_login = "testadmin"
  administrator_login_password = "Root123#"
 
  sku_name = "GP_Gen5_2"
  version  = "8.0"
 
  storage_mb = "5120"
  auto_grow_enabled = true
  
  backup_retention_days = 7
  geo_redundant_backup_enabled = false
  public_network_access_enabled = true
  ssl_enforcement_enabled = false
  infrastructure_encryption_enabled = true
}

resource "azurerm_mysql_database" "webapp-db" {
  name                = "webappdb"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.webapp-server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

data "azurerm_subnet" "akssubnetcreated" {
  name                 = "aks-subnet"
  virtual_network_name = "aks-vnet"
  resource_group_name  = "kcluster"
  depends_on = ["azurerm_subnet.akssubnet"]
}

resource "azurerm_mysql_virtual_network_rule" "dbaccess" {
  name                = "mysql-vnet-rule"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.webapp-server.name
  subnet_id           = "${data.azurerm_subnet.akssubnetcreated.id}"
}

#pollerdb
resource "azurerm_mysql_server" "poller-server" {
  name                = "poller5"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
 
  administrator_login = "testadmin"
  administrator_login_password = "Root123#"
 
  sku_name = "GP_Gen5_2"
  version  = "8.0"
 
  storage_mb = "5120"
  auto_grow_enabled = true
  
  backup_retention_days = 7
  geo_redundant_backup_enabled = false
  public_network_access_enabled = true
  ssl_enforcement_enabled = false
  infrastructure_encryption_enabled = true
}

resource "azurerm_mysql_database" "poller-db" {
  name                = "pollerdb"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.poller-server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}


resource "azurerm_mysql_virtual_network_rule" "dbaccesspoller" {
  name                = "mysql-vnet-rule"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.poller-server.name
  subnet_id           = "${data.azurerm_subnet.akssubnetcreated.id}"
}

#notifier
resource "azurerm_mysql_server" "notifier-server" {
  name                = "notifier5"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"
 
  administrator_login = "testadmin"
  administrator_login_password = "Root123#"
 
  sku_name = "GP_Gen5_2"
  version  = "8.0"
 
  storage_mb = "5120"
  auto_grow_enabled = true
  
  backup_retention_days = 7
  geo_redundant_backup_enabled = false
  public_network_access_enabled = true
  ssl_enforcement_enabled = false
  infrastructure_encryption_enabled = true
}

resource "azurerm_mysql_database" "notifier-db" {
  name                = "notifierdb"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.notifier-server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}


resource "azurerm_mysql_virtual_network_rule" "dbaccessnotifier" {
  name                = "mysql-vnet-rule"
  resource_group_name = azurerm_resource_group.main.name
  server_name         = azurerm_mysql_server.notifier-server.name
  subnet_id           = "${data.azurerm_subnet.akssubnetcreated.id}"
}
