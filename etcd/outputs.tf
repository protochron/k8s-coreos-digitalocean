output "server_urls" {
  value = "${join(",", formatlist("http://%s:2379", digitalocean_droplet.etcd.*.ipv4_address_private))}"
}

output "public_ipv4" {
  value = "${join(", ", digitalocean_droplet.etcd.*.ipv4_address)}"
}
