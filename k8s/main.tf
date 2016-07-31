resource template_file "apiserver" {
  template = "${file("${path.module}/templates/apiserver.tpl")}"

  vars {
    etcd_servers = "${var.etcd_server_urls}"
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

  user_data = "${template_file.apiserver.rendered}"
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

