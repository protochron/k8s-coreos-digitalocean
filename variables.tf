# Common
variable region {
  default     = "sfo1"
  description = "Region to launch in"
}

variable ssh_keys {
  description = "SSH keys to use"
}

variable image {
  description = "Name of the image to use"
}

variable do_read_token {
  description = "Read-only token for the DO api"
}

# Etcd
variable etcd_count {
  description = "Number of etcd droplets"
  default     = 1
}

variable discovery_url {
  description = "etcd discovery url"
  default = "https://discovery.etcd.io/cedd96b8d0e1a1f8dd8a196534e8ae69"
}

variable etcd_size {
  description = "Size of the etcd droplet"
  default     = "1gb"
}

# K8s
variable kubelet_count {
  description = "Number of kubelets to use"
  default     = 1
}

variable kubelet_size {
  description = "Size of the kubelet server"
  default     = "1gb"
}

variable kubernetes_version {
  description = "Version of Kubernetes to install"
  default     = "1.3.6"
}

variable apiserver_size {
  description = "Size of the apiserver"
  default     = "1gb"
}

variable apiserver_count {
  description = "Number of apiservers"
  default     = 1
}

variable pod_network {
  description = "CIDR of pod IPs"
  default     = "10.2.0.0/16"
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

variable vxlan_id {
  description = "Vxlan id of the flannel network"
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
