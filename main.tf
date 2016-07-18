resource digitalocean_droplet "etcd" {
  count    = "${var.etcd_count}"
  image    = "coreos-stable"
  region   = "${var.region}"
  size     = "${var.etcd_size}"
  name     = "${format("etcd-%02d", count.index + 1)}"
  ssh_keys = ["${var.ssh_key}"]
}
