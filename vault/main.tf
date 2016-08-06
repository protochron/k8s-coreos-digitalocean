resource template_file "vault" {
  template = "${file("${path.module}/templates/vault.tpl")}"

  vars {
    volume_name = "${digitalocean_volume.vault.name}"
  }
}

resource digitalocean_volume "vault" {
  region      = "${var.region}"
  size        = "${var.volume_size}"
  name        = "vault-volume"
  description = "Volume to store Vault data"
}

resource digitalocean_droplet "vault" {
  count              = "${var.count}"
  image              = "${var.image}"
  region             = "${var.region}"
  size               = "${var.size}"
  name               = "vault"
  ssh_keys           = ["${var.ssh_keys}"]
  volume_ids         = ["${digitalocean_volume.vault.id}"]
  private_networking = true

  user_data = "${template_file.vault.rendered}"
}
