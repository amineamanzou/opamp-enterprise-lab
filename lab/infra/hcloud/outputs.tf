output "servers" {
  description = "Inventory-oriented server metadata. Contains public IPs but no secrets."
  value = {
    for key, server in hcloud_server.lab : key => {
      name        = server.name
      role        = server.labels.role
      ipv4        = server.ipv4_address
      ipv6        = server.ipv6_address
      public_host = coalesce(server.ipv4_address, server.ipv6_address)
      location    = server.location
      server_type = server.server_type
    }
  }
}

output "ansible_inventory_hint" {
  description = "Sketch of the groups expected by lab/ansible/inventory/example.ini."
  value = {
    opamp_server = [for key, server in hcloud_server.lab : coalesce(server.ipv4_address, server.ipv6_address) if server.labels.role == "opamp_server"]
    host_agents  = [for key, server in hcloud_server.lab : coalesce(server.ipv4_address, server.ipv6_address) if contains(["host_agents", "optional_load"], server.labels.role)]
    k3s_servers  = [for key, server in hcloud_server.lab : coalesce(server.ipv4_address, server.ipv6_address) if server.labels.role == "k3s_server"]
    k3s_workers  = [for key, server in hcloud_server.lab : coalesce(server.ipv4_address, server.ipv6_address) if server.labels.role == "k3s_worker"]
  }
}
