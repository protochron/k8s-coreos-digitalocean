data "template_file" "apiserver" {
  template = "${file("${path.module}/templates/apiserver.tpl")}"

  vars {
    etcd_servers     = "${var.etcd_server_urls}"
    dns_service_ip   = "${var.dns_service_ip}"
    service_ip_range = "${var.service_ip_range}"
    k8s_version      = "v${var.kubernetes_version}"
    key              = "${var.do_read_token}"
    tag              = "${var.cluster_tag}"
  }
}

data "template_file" "kubelet" {
  template = "${file("${path.module}/templates/kubelet.tpl")}"

  vars {
    etcd_servers     = "${var.etcd_server_urls}"
    dns_service_ip   = "${var.dns_service_ip}"
    service_ip_range = "${var.service_ip_range}"

    master      = "https://${digitalocean_droplet.apiserver.ipv4_address_private}:8443"
    k8s_version = "v${var.kubernetes_version}"
    apiservers  = "${join(",", formatlist("https://%s.kubelocal:8443", digitalocean_droplet.apiserver.*.name))}"
    key         = "${var.do_read_token}"
    tag         = "${var.cluster_tag}"
  }
}

data "template_file" "lb" {
  template = "${file("${path.module}/templates/lb.tpl")}"

  vars {
    etcd_servers     = "${var.etcd_server_urls}"
    dns_service_ip   = "${var.dns_service_ip}"
    service_ip_range = "${var.service_ip_range}"

    master      = "https://${digitalocean_droplet.apiserver.ipv4_address_private}:8443"
    k8s_version = "v${var.kubernetes_version}"
    apiservers  = "${join(",", formatlist("https://%s.kubelocal:8443", digitalocean_droplet.apiserver.*.name))}"
    key         = "${var.do_read_token}"
    tag         = "${var.cluster_tag}"
  }
}

resource digitalocean_droplet "apiserver" {
  count              = "${var.apiserver_count}"
  image              = "${var.image}"
  region             = "${var.region}"
  size               = "${var.apiserver_size}"
  name               = "${format("%sapiserver-%02d-%s", var.resource_prefix, count.index + 1, var.cluster_id)}"
  ssh_keys           = ["${split(",", var.ssh_keys)}"]
  tags               = ["${var.cluster_tag}"]
  private_networking = true

  user_data = "${data.template_file.apiserver.rendered}"

  connection = {
    timeout = "30s"
    user    = "core"
    agent   = true
  }

  provisioner "local-exec" {
    command = "bin/generate_apiserver_cert ${self.name} ${self.ipv4_address_private} ${var.dns_service_ip} ${self.name}.kubelocal"
  }

  provisioner "file" {
    source = "${path.module}/../CA/ca.pem"
    destination = "/home/core/ca.pem"
  }

  provisioner "file" {
    source = "${path.module}/../ssl/${self.name}.pem"
    destination = "/home/core/apiserver.pem"
  }

  provisioner "file" {
    source = "${path.module}/../ssl/${self.name}-key.pem"
    destination = "/home/core/apiserver-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/kubernetes/ssl",
      "sudo mv /home/core/*.pem /etc/kubernetes/ssl/",
      "sudo chown root:root /etc/kubernetes/ssl/*.pem",
      "sudo chmod 600 /etc/kubernetes/ssl/*.pem",
      "sudo sed -i \"s@#MASTERURL#@https://${self.ipv4_address_private}:8443@\" /etc/kubernetes/addons/kube-dns/kube-dns-rc.yaml"
    ]
  }
}

resource digitalocean_droplet "kubelet" {
  count              = "${var.kubelet_count}"
  image              = "${var.image}"
  region             = "${var.region}"
  size               = "${var.kubelet_size}"
  name               = "${format("%skubelet-%02d-%s", var.resource_prefix, count.index + 1, var.cluster_id)}"
  ssh_keys           = ["${split(",", var.ssh_keys)}"]
  tags               = ["${var.cluster_tag}"]
  private_networking = true

  user_data = "${data.template_file.kubelet.rendered}"

  connection = {
    timeout = "30s"
    user    = "core"
    agent   = true
  }

  provisioner "local-exec" {
    command = "bin/generate_worker_cert ${self.name} ${self.ipv4_address_private} ${self.name}.kubelocal"
  }

  provisioner "file" {
    source = "${path.module}/../CA/ca.pem"
    destination = "/home/core/ca.pem"
  }

  provisioner "file" {
    source = "${path.module}/../ssl/${self.name}.pem"
    destination = "/home/core/worker.pem"
  }

  provisioner "file" {
    source = "${path.module}/../ssl/${self.name}-key.pem"
    destination = "/home/core/worker-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/kubernetes/ssl",
      "sudo mv /home/core/*.pem /etc/kubernetes/ssl/",
      "sudo chown root:root /etc/kubernetes/ssl/*.pem",
      "sudo chmod 600 /etc/kubernetes/ssl/*.pem"
    ]
  }
}

resource digitalocean_droplet "lb" {
  count              = "${var.lb_count}"
  image              = "${var.image}"
  region             = "${var.region}"
  size               = "${var.lb_size}"
  name               = "${format("%slb-%02d-%s", var.resource_prefix, count.index + 1, var.cluster_id)}"
  ssh_keys           = ["${split(",", var.ssh_keys)}"]
  tags               = ["${var.cluster_tag}"]
  private_networking = true

  user_data = "${data.template_file.lb.rendered}"

  connection = {
    timeout = "30s"
    user    = "core"
    agent   = true
  }

  provisioner "local-exec" {
    command = "bin/generate_worker_cert ${self.name} ${self.ipv4_address_private} ${self.name}.kubelocal"
  }

  provisioner "file" {
    source = "${path.module}/../CA/ca.pem"
    destination = "/home/core/ca.pem"
  }

  provisioner "file" {
    source = "${path.module}/../ssl/${self.name}.pem"
    destination = "/home/core/worker.pem"
  }

  provisioner "file" {
    source = "${path.module}/../ssl/${self.name}-key.pem"
    destination = "/home/core/worker-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/kubernetes/ssl",
      "sudo mv /home/core/*.pem /etc/kubernetes/ssl/",
      "sudo chown root:root /etc/kubernetes/ssl/*.pem",
      "sudo chmod 600 /etc/kubernetes/ssl/*.pem"
    ]
  }
}
