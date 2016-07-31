module "etcd" {
  source        = "./etcd"
  size          = "${var.etcd_size}"
  image         = "${var.image}"
  region        = "${var.region}"
  ssh_keys      = "${var.ssh_keys}"
  count         = "${var.etcd_count}"
  discovery_url = "${var.discovery_url}"
  pod_network   = "${var.pod_network}"
  vxlan_id      = "${var.vxlan_id}"
}

module "k8s" {
  source   = "./k8s"
  image    = "${var.image}"
  region   = "${var.region}"
  ssh_keys = "${var.ssh_keys}"

  # K8s specific
  apiserver_count  = "${var.apiserver_count}"
  apiserver_size   = "${var.apiserver_size}"
  kubelet_count    = "$var.kubelet_count}"
  kubelet_size     = "${var.kubelet_size}"
  service_ip_range = "${var.service_ip_range}"
  k8s_service_ip   = "${var.k8s_service_ip}"
  dns_service_ip   = "${var.dns_service_ip}"
  etcd_server_urls = "${module.etcd.server_urls}"
}

resource null_resource "flannel" {
  triggers = {
    etcd_servers = "${module.etcd.server_urls}"
  }

  connection = {
    host    = "${element(split(",", module.etcd.public_ipv4), 0)}"
    timeout = "30s"
    user    = "core"
    agent   = true
  }

  provisioner "remote-exec" {
    inline = [
      "curl -X PUT ${element(split(",", module.etcd.server_urls), 1)}/v2/keys/coreos.com/network/config -d value='{\"Network\": \"${var.pod_network}\", \"Backend\": {\"Type\": \"vxlan\", \"VNI\": ${var.vxlan_id}}}'",
    ]
  }
}
