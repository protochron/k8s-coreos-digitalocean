data "template_file" "apiserver" {
  template = "${file("${path.module}/templates/apiserver.tpl")}"

  vars {
    etcd_servers     = "${var.etcd_server_urls}"
    dns_service_ip   = "${var.dns_service_ip}"
    service_ip_range = "${var.service_ip_range}"
    k8s_version      = "v1.3.4"
  }
}

data "template_file" "kubelet" {
  template = "${file("${path.module}/templates/kubelet.tpl")}"

  vars {
    etcd_servers     = "${var.etcd_server_urls}"
    dns_service_ip   = "${var.dns_service_ip}"
    service_ip_range = "${var.service_ip_range}"

    #master           = "${digitalocean_droplet.lb.ipv4_address}"
    master      = "http://${digitalocean_droplet.apiserver.ipv4_address_private}:8080"
    k8s_version = "v1.3.4"
    apiservers  = "${join(",", formatlist("http://%s:8080", digitalocean_droplet.apiserver.*.ipv4_address_private))}"
  }
}

resource digitalocean_droplet "apiserver" {
  count              = "${var.apiserver_count}"
  image              = "${var.image}"
  region             = "${var.region}"
  size               = "${var.apiserver_size}"
  name               = "${format("apiserver-%02d", count.index + 1)}"
  ssh_keys           = ["${var.ssh_keys}"]
  private_networking = true

  user_data = "${data.template_file.apiserver.rendered}"
}

resource digitalocean_droplet "kubelet" {
  count              = "${var.kubelet_count}"
  image              = "${var.image}"
  region             = "${var.region}"
  size               = "${var.kubelet_size}"
  name               = "${format("kubelet-%02d", count.index + 1)}"
  ssh_keys           = ["${var.ssh_keys}"]
  private_networking = true

  user_data = "${data.template_file.kubelet.rendered}"
}

resource digitalocean_droplet "lb" {
  count              = "${var.lb_count}"
  image              = "${var.lb_image}"
  size               = "${var.lb_size}"
  region             = "${var.region}"
  name               = "${format("lb-%02d", count.index + 1)}"
  ssh_keys           = ["${var.ssh_keys}"]
  private_networking = true
}
