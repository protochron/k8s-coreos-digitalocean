variable etcd_count {
  default     = 1
  description = "Number of etcd droplets"
}

variable region {
  default     = "sfo1"
  description = "Region to launch in"
}

variable discovery_url {
  description = "etcd discovery url"
}

variable etcd_size {
  default     = "1gb"
  description = "Size of the etcd droplet"
}

variable ssh_keys {
  description = "SSH keys to use"
}

variable kubelet_count {
  default     = 1
  description = "Number of kubelets to use"
}

variable kubelet_size {
  default     = "1gb"
  description = "Size of the kubelet server"
}

variable apiserver_size {
  default     = "1gb"
  description = "Size of the apiserver"
}

variable apiserver_count {
  default     = 1
  description = "Number of apiservers"
}

variable image {
  description = "Name of the image to use"
}
