variable "subscription_id" {
  description = "Azure subscription ID. Leave null to use the CLI's default subscription."
  type        = string
  default     = null
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "canadacentral"
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "mxc-openclaw"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default = {
    project = "mxc-openclaw"
    managed = "terraform"
  }
}

variable "vm_size" {
  description = "Azure VM size. Standard_D4s_v5 supports nested virtualization for future MXC backends."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "admin_username" {
  description = "Local administrator username for the Windows VM."
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  description = "Local administrator password. Must meet Azure Windows complexity requirements."
  type        = string
  sensitive   = true
}

variable "windows_image" {
  description = "Marketplace image for Windows 11 Enterprise 24H2 (Gen2). Confirm SKU availability in your region/subscription."
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-24h2-ent-g2"
    version   = "latest"
  }
}

variable "license_type" {
  description = "Windows license type for client images. Use Windows_Client when eligible for multitenant hosting rights."
  type        = string
  default     = "Windows_Client"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
  default     = 256
}

variable "allowed_rdp_cidr" {
  description = "CIDR allowed to connect to the VM over RDP (3389)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "openclaw_gateway_port" {
  description = "TCP port exposed for the OpenClaw gateway."
  type        = number
  default     = 18789
}

variable "allowed_gateway_cidr" {
  description = "CIDR allowed to reach the OpenClaw gateway port."
  type        = string
  default     = "0.0.0.0/0"
}

variable "enable_public_ip" {
  description = "Attach a static public IP for RDP and gateway access."
  type        = bool
  default     = true
}

variable "run_bootstrap_extension" {
  description = "Run the Custom Script Extension to install Node, WSL2, MXC SDK, and OpenClaw."
  type        = bool
  default     = true
}

variable "mxc_sdk_version" {
  description = "Pinned npm version for @microsoft/mxc-sdk."
  type        = string
  default     = "0.6.0-alpha"
}

variable "openclaw_npm_package" {
  description = "npm package spec for OpenClaw."
  type        = string
  default     = "openclaw@latest"
}

variable "node_major_version" {
  description = "Major Node.js version to install."
  type        = number
  default     = 24
}
