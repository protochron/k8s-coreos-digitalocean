output "apiservers" {
  value = "${join(", ", digitalocean_droplet.apiserver.*.ipv4_address)}"
}

output "load-balancer" {
  value = "${digitalocean_droplet.lb.ipv4_address}"
}

output "kubelets" {
  value = "${join(", ", digitalocean_droplet.kubelet.*.ipv4_address)}"
}
