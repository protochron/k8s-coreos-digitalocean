output "etcd_servers" {
  value = "${module.etcd.public_ipv4}"
}

output "apiservers" {
  value = "${module.k8s.apiservers}"
}

output "load-balancer" {
  value = "${module.k8s.load-balancer}"
}
