resource template_file "etcd" {
  template = "${file("${path.module}/templates/etcd.tpl")}"

  vars {
    discovery_url = "${var.discovery_url}"
  }
}

resource digitalocean_droplet "etcd" {
  count              = "${var.etcd_count}"
  image              = "${var.image}"
  region             = "${var.region}"
  size               = "${var.etcd_size}"
  name               = "${format("etcd-%02d", count.index + 1)}"
  ssh_keys           = ["${var.ssh_keys}"]
  private_networking = true

  user_data = "${template_file.etcd.rendered}"
}

#resource digitalocean_droplet "kubelet" {


#  count    = "${var.kubelet_count}"


#  image    = "${var.image}"


#  region   = "${var.region}"


#  size     = "${var.kubelet_size}"


#  name     = "${format("kubelet-%02d", count.index + 1)}"


#  ssh_keys = ["${var.ssh_keys}"]


#}


#


#resource digitalocean_droplet "apiserver" {


#  count    = "${var.apiserver_count}"


#  image    = "${var.image}"


#  region   = "${var.region}"


#  size     = "${var.apiserver_size}"


#  name     = "${format("apiserver-%02d", count.index + 1)}"


#  ssh_keys = ["${var.ssh_keys}"]


#}

