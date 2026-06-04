output "resource_group_name" {
  description = "Name of the deployed resource group."
  value       = azurerm_resource_group.main.name
}

output "vm_name" {
  description = "Name of the Windows VM."
  value       = azurerm_windows_virtual_machine.main.name
}

output "vm_private_ip" {
  description = "Private IP address of the VM."
  value       = azurerm_network_interface.vm.private_ip_address
}

output "vm_public_ip" {
  description = "Public IP address of the VM (null when enable_public_ip is false)."
  value       = var.enable_public_ip ? azurerm_public_ip.vm[0].ip_address : null
}

output "rdp_connection" {
  description = "RDP connection string for Remote Desktop."
  value       = var.enable_public_ip ? "mstsc /v:${azurerm_public_ip.vm[0].ip_address}" : "Use Azure Bastion or private connectivity; public IP disabled."
}

output "openclaw_gateway_url" {
  description = "Default OpenClaw gateway URL once bootstrap completes."
  value       = var.enable_public_ip ? "http://${azurerm_public_ip.vm[0].ip_address}:${var.openclaw_gateway_port}" : "http://${azurerm_network_interface.vm.private_ip_address}:${var.openclaw_gateway_port}"
}

output "bootstrap_log_path" {
  description = "Path to the bootstrap log on the VM."
  value       = "C:\\bootstrap\\bootstrap.log"
}

output "next_steps" {
  description = "Post-deploy configuration required on the VM."
  value       = <<-EOT
    1. RDP to the VM and review C:\bootstrap\bootstrap.log
    2. Read gateway URL + token from C:\openclaw\gateway-access.txt
    3. Add OPENAI_API_KEY or ANTHROPIC_API_KEY to C:\openclaw\config\.env, then run: powershell -File C:\openclaw\start-gateway.ps1 -Restart
    4. Open the Control UI at the gateway URL from your browser and paste the token
    5. Configure MXC processcontainer backend per OpenClaw + @microsoft/mxc-sdk docs
  EOT
}
