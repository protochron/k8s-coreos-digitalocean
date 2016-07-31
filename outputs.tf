output "etcd_servers" {
  value = "${module.etcd.public_ipv4}"
}

#output "apiservers" {


#  value = "${module.k8s.apiservers}"


#}

