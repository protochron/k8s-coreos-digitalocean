variable region {
  description = "Region to launch in"
  default     = "sfo1"
}

variable ssh_keys {
  description = "SSH keys to use"
}

variable cluster_id {
  description = "A unique id for the cluster"
}

variable cluster_tag {
  description = "A unique tag for the cluster"
}

variable image {
  description = "Name of the image to use"
}

variable do_read_token {
  description = "Read-only DO token"
}

variable etcd_server_urls {
  description = "Comma-separated list of etcd urls"
}

variable kubelet_count {
  description = "Number of kubelets to use"
  default     = 1
}

variable kubernetes_version {
  description = "Version of Kubernetes to install"
  default     = "1.4.3"
}

variable kubelet_size {
  description = "Size of the kubelet server"
  default     = "1gb"
}

variable apiserver_size {
  description = "Size of the apiserver"
  default     = "1gb"
}

variable apiserver_count {
  description = "Number of apiservers"
  default     = 1
}

variable service_ip_range {
  description = "CIDR for service IPs"
  default     = "10.3.0.0/16"
}

variable k8s_service_ip {
  description = "VIP address of the API service"
  default     = "10.3.0.1"
}

variable dns_service_ip {
  description = "DNS service VIP"
  default     = "10.3.0.10"
}

# Load balancer
variable lb_image {
  description = "Image to use for the load balancer"
  default     = "ubuntu-16-04-x64"
}

variable lb_count {
  description = "Number of load balancers for the apiservers"
  default     = 1
}

variable lb_size {
  description = "Size of the lb droplet"
}

variable resource_prefix {
  description = "a prefix for each resource name"
  default = ""
}
