variable "hcloud_token" {
  description = "Hetzner Cloud API token. Set with TF_VAR_hcloud_token; never commit it."
  type        = string
  sensitive   = true
  nullable    = false
}

variable "project_name" {
  description = "Short name used as a prefix for lab resources."
  type        = string
  default     = "opamp-enterprise-lab"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 3-32 lowercase letters, digits, or hyphens, and cannot start or end with a hyphen."
  }
}

variable "location" {
  description = "Hetzner Cloud location."
  type        = string
  default     = "fsn1"
}

variable "image" {
  description = "Linux image used by all lab VMs."
  type        = string
  default     = "ubuntu-24.04"
}

variable "server_type" {
  description = "Default frugal server type used by all lab VMs unless overridden in server_type_overrides."
  type        = string
  default     = "cx23"
}

variable "server_type_overrides" {
  description = "Optional per-role server type overrides keyed by role name."
  type        = map(string)
  default     = {}
}

variable "enable_optional_load_host" {
  description = "Create the fifth VM for extra synthetic logs/load."
  type        = bool
  default     = false
}

variable "enable_host_agent_vm" {
  description = "Create the host-agent VM. Disable for quota-constrained single-VM smoke runs."
  type        = bool
  default     = true
}

variable "enable_kubernetes_vms" {
  description = "Create the k3s server and worker VMs. Disable for quota-constrained single-VM smoke runs."
  type        = bool
  default     = true
}

variable "public_ipv4_enabled" {
  description = "Attach public IPv4 addresses to lab VMs. Disable when the Hetzner project has no Primary IPv4 quota."
  type        = bool
  default     = true
}

variable "public_ipv6_enabled" {
  description = "Attach public IPv6 addresses to lab VMs."
  type        = bool
  default     = true
}

variable "ssh_key_name" {
  description = "Name of an existing Hetzner Cloud SSH key. Leave null to import ssh_public_key_path."
  type        = string
  default     = null
}

variable "ssh_public_key_path" {
  description = "Path to a local public SSH key to import if ssh_key_name is null."
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "allowed_ssh_cidrs" {
  description = "CIDRs allowed to SSH into lab hosts. Empty by default; set explicitly before applying."
  type        = list(string)
  default     = []
}

variable "allowed_http_cidrs" {
  description = "CIDRs allowed to reach HTTP/HTTPS endpoints on lab hosts. Empty by default; set explicitly before applying."
  type        = list(string)
  default     = []
}

variable "allowed_opamp_cidrs" {
  description = "CIDRs allowed to reach the OpAMP WebSocket endpoint on port 4320. Empty by default; set explicitly before applying."
  type        = list(string)
  default     = []
}

variable "allowed_admin_api_cidrs" {
  description = "CIDRs allowed to reach the OpAMP admin API on port 4321. Empty by default; set explicitly before applying."
  type        = list(string)
  default     = []
}

variable "allowed_otlp_cidrs" {
  description = "CIDRs allowed to send OTLP traffic to lab collectors on ports 4317-4318."
  type        = list(string)
  default     = ["10.0.0.0/8"]
}

variable "allowed_k3s_api_cidrs" {
  description = "CIDRs allowed to reach the k3s API server on port 6443. Include operator CIDRs and the k3s pod CIDR when workloads use the public API endpoint."
  type        = list(string)
  default     = []
}

variable "allowed_k3s_peer_cidrs" {
  description = "CIDRs for k3s node-to-node traffic on kubelet and flannel VXLAN ports."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Additional labels applied to all resources."
  type        = map(string)
  default     = {}
}
