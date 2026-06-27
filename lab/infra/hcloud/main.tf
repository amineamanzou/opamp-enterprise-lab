data "hcloud_ssh_key" "existing" {
  count = var.ssh_key_name == null ? 0 : 1
  name  = var.ssh_key_name
}

resource "hcloud_ssh_key" "lab" {
  count      = var.ssh_key_name == null ? 1 : 0
  name       = "${var.project_name}-lab"
  public_key = file(pathexpand(var.ssh_public_key_path))
  labels     = local.common_labels
}

resource "hcloud_firewall" "lab" {
  name   = "${var.project_name}-lab"
  labels = local.common_labels

  dynamic "rule" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "22"
      source_ips = var.allowed_ssh_cidrs
    }
  }

  dynamic "rule" {
    for_each = length(var.allowed_http_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "80"
      source_ips = var.allowed_http_cidrs
    }
  }

  dynamic "rule" {
    for_each = length(var.allowed_http_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "443"
      source_ips = var.allowed_http_cidrs
    }
  }

  dynamic "rule" {
    for_each = length(var.allowed_opamp_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "4320"
      source_ips = var.allowed_opamp_cidrs
    }
  }

  dynamic "rule" {
    for_each = length(var.allowed_admin_api_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "4321"
      source_ips = var.allowed_admin_api_cidrs
    }
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "4317-4318"
    source_ips = var.allowed_otlp_cidrs
  }

  dynamic "rule" {
    for_each = length(local.k3s_api_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "6443"
      source_ips = local.k3s_api_cidrs
    }
  }

  dynamic "rule" {
    for_each = length(var.allowed_k3s_peer_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "tcp"
      port       = "10250"
      source_ips = var.allowed_k3s_peer_cidrs
    }
  }

  dynamic "rule" {
    for_each = length(var.allowed_k3s_peer_cidrs) > 0 ? [1] : []
    content {
      direction  = "in"
      protocol   = "udp"
      port       = "8472"
      source_ips = var.allowed_k3s_peer_cidrs
    }
  }
}

resource "hcloud_server" "lab" {
  for_each = local.servers

  name        = "${var.project_name}-${each.key}"
  image       = var.image
  server_type = lookup(var.server_type_overrides, each.value.role, var.server_type)
  location    = var.location
  ssh_keys    = var.ssh_key_name == null ? [hcloud_ssh_key.lab[0].id] : [data.hcloud_ssh_key.existing[0].id]
  labels = merge(
    local.common_labels,
    {
      role = each.value.role
    }
  )

  firewall_ids = [hcloud_firewall.lab.id]

  public_net {
    ipv4_enabled = var.public_ipv4_enabled
    ipv6_enabled = var.public_ipv6_enabled
  }
}
