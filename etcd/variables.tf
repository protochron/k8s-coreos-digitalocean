variable count {
  description = "Number of etcd droplets"
  default     = 1
}

variable region {
  description = "Region to launch in"
  default     = "sfo1"
}

variable do_read_token {
  description = "A read-only token for configuring droplan"
}

variable discovery_url {
  description = "etcd discovery url"
}

variable size {
  description = "Size of the etcd droplet"
  default     = "1gb"
}

variable ssh_keys {
  description = "SSH keys to use"
}

variable image {
  description = "The image to use"
}

variable vxlan_id {
  description = "The vxlan id to use for the flannel network"
}

variable pod_network {
  description = "CIDR of pod IPs"
  default     = "10.2.0.0/16"
}
