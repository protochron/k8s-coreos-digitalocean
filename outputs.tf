output "etcd_servers" {
  value = "${module.etcd.public_ipv4}"
}

output "apiservers" {
  value = "${module.k8s.apiservers}"
}

output "kubelets" {
  value = "${module.k8s.kubelets}"
}

output "load-balancer" {
  value = "${module.k8s.load-balancer}"
}

output "cluster-tag" {
  value = "${digitalocean_tag.cluster_tag.id}"
}
