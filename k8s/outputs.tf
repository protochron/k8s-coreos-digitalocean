output "apiservers" {
  value = "${join(", ", digitalocean_droplet.apiserver.*.ipv4_address_public)}"
}
