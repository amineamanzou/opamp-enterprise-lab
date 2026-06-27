locals {
  common_labels = merge(
    {
      project    = var.project_name
      component  = "opamp-fleet-lab"
      managed_by = "terraform"
    },
    var.labels
  )

  opamp_servers = {
    opamp = {
      role        = "opamp_server"
      description = "OpAMP server and evidence/log sink host"
    }
  }

  host_agent_servers = {
    agent = {
      role        = "host_agents"
      description = "Host agent and synthetic log source"
    }
  }

  kubernetes_servers = {
    k3s-server = {
      role        = "k3s_server"
      description = "k3s control-plane candidate"
    }
    k3s-worker = {
      role        = "k3s_worker"
      description = "k3s worker candidate"
    }
  }

  required_servers = merge(
    local.opamp_servers,
    var.enable_host_agent_vm ? local.host_agent_servers : {},
    var.enable_kubernetes_vms ? local.kubernetes_servers : {}
  )

  optional_servers = {
    load = {
      role        = "optional_load"
      description = "Optional extra synthetic load host"
    }
  }

  servers = var.enable_optional_load_host ? merge(local.required_servers, local.optional_servers) : local.required_servers

  k3s_api_cidrs = distinct(concat(var.allowed_k3s_api_cidrs, var.allowed_k3s_peer_cidrs))
}
