module "rg" {
  source  = "tfedemo.tfedemo.com/hrb1/resource-group/azurerm"
  version = "1.1.1"

  location = "Central US"
  name = var.resourse_group_name
  
}
  
module "virtual_network" {
  source  = "tfedemo.tfedemo.com/hrb1/virtual-network/azurerm"
  version = "1.1.1"

  resource_group_location = module.rg.resource_group_location
  resource_group_name = module.rg.resource_group_name
  prefix = var.prefix
}

module "network_security_group" {
  source  = "tfedemo.tfedemo.com/hrb1/network-security-group/azurerm"
  version = "1.1.2"

  location = "centralus"
  resource_group_name = "${module.rg.resource_group_name}"
  predefined_rules = [
      {
        name                   = "SSH"
      },
      {
        name                   = "HTTP"
      },
      {
        name                   = "HTTPS"
      }
  ]
}
  
module "compute_module" {
  source  = "tfedemo.tfedemo.com/hrb1/computeModule/azurerm"
  version = "1.1.1"
  resource_group_name = module.rg.resource_group_name
  network_security_group_id = module.network_security_group.network_security_group_id
  subnet_id = module.virtual_network.subnet_id
  location = "centralus"
  prefix = var.prefix
}

  resource "null_resource" "configure-cat-app" {
  depends_on = [
    "module.compute_module",
  ]

  # Terraform 0.11
  # triggers {
  #   build_number = "${timestamp()}"
  # }

  # Terraform 0.12
  triggers = {
    build_number = "${timestamp()}"
  }

  provisioner "file" {
    source      = "files/"
    destination = "/home/${var.admin_username}/"

    connection {
      type     = "ssh"
      user     = "${var.admin_username}"
      password = "${var.admin_password}"
      host     = module.compute_module.app_fqdn
    }
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt -y update",
      "sudo apt -y install apache2",
      "sudo systemctl start apache2",
      "sudo chown -R ${var.admin_username}:${var.admin_username} /var/www/html",
      "chmod +x *.sh",
      "PLACEHOLDER=${var.placeholder} WIDTH=${var.width} HEIGHT=${var.height} PREFIX=${var.prefix} ./deploy_app.sh",
    ]

    connection {
      type     = "ssh"
      user     = "${var.admin_username}"
      password = "${var.admin_password}"
      host     = module.compute_module.app_fqdn
    }
  }
}

