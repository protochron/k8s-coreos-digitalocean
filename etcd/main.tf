data template_file "etcd" {
  template = "${file("${path.module}/templates/etcd.tpl")}"

  vars {
    discovery_url = "${var.discovery_url}"
    key           = "${var.do_read_token}"
  }
}

resource digitalocean_droplet "etcd" {
  count              = "${var.count}"
  image              = "${var.image}"
  region             = "${var.region}"
  size               = "${var.size}"
  name               = "${format("etcd-%02d", count.index + 1)}"
  ssh_keys           = ["${var.ssh_keys}"]
  private_networking = true

  user_data = "${data.template_file.etcd.rendered}"
}
