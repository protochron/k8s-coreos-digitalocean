#cloud-config
write_files:
  - path: /var/lib/iptables/rules-save
    permissions: 0644
    owner: 'root:root'
    content: |
      *filter
      :INPUT DROP [0:0]
      :FORWARD DROP [0:0]
      :OUTPUT ACCEPT [0:0]
      -A INPUT -i lo -j ACCEPT
      -A INPUT -i eth1 -j ACCEPT
      -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
      -A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
      -A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
      -A INPUT -p icmp -m icmp --icmp-type 0 -j ACCEPT
      -A INPUT -p icmp -m icmp --icmp-type 3 -j ACCEPT
      -A INPUT -p icmp -m icmp --icmp-type 11 -j ACCEPT
      -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      COMMIT
  - path: '/etc/flannel/options.env'
    owner: root
    permissions: 0644
    content: |
      FLANNELD_IFACE=$private_ipv4
      FLANNELD_ETCD_ENDPOINTS=${etcd_servers}
  - path: '/etc/kubernetes/manifests/kube-proxy.yaml'
    owner: root
    permissions: 0644
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: kube-proxy
        namespace: kube-system
      spec:
        hostNetwork: true
        containers:
        - name: kube-proxy
          image: quay.io/coreos/hyperkube:${k8s_version}_coreos.0
          command:
          - /hyperkube
          - proxy
          - --master=${master}
          - --proxy-mode=iptables
          securityContext:
            privileged: true
          volumeMounts:
            - mountPath: /etc/ssl/certs
              name: "ssl-certs"
            - mountPath: /etc/kubernetes/ssl
              name: "etc-kube-ssl"
              readOnly: true
        volumes:
          - name: "ssl-certs"
            hostPath:
              path: "/usr/share/ca-certificates"
          - name: "etc-kube-ssl"
            hostPath:
              path: "/etc/kubernetes/ssl"

#######################
coreos:
  flannel:
    etcd_endpoints: ${etcd_servers}
  units:
    - name: iptables-restore.service
      enable: true
      command: start
    - name: "flanneld.service"
      drop-ins:
        - name: "40-ExecStartPre-symlink.conf"
          content: |
            [Service]
            ExecStartPre=/usr/bin/ln -sf /etc/flannel/options.env /run/flannel/options.env
      command: start
    - name: "docker.service"
      drop-ins:
        - name: "50-require-flannel.conf"
          content: |
            [Unit]
            Requires=flanneld.service
            After=flanneld.service
        - name: "60-docker-config.conf"
          content: |
            [Service]
            Environment="DOCKER_OPTS=--storage-driver=overlay"
      command: start
    - name: droplan.service
      enable: true
      command: start
      content: |
        [Unit]
        Description=updates iptables with peer droplets
        Requires=docker.service

        [Service]
        Type=oneshot
        Environment=DO_KEY=${key}
        ExecStart=/usr/bin/docker run --rm --net=host --cap-add=NET_ADMIN -e DO_KEY tam7t/droplan:latest
    - name: droplan.timer
      command: start
      content: |
        [Unit]
        Description=Run droplan.service every 5 minutes

        [Timer]
        OnCalendar=*:0/5
    - name: drophosts.service
      enable: true
      command: start
      content: |
        [Unit]
        Description=updates hosts with peer droplets
        Requires=docker.service

        [Service]
        Type=oneshot
        Environment=DO_KEY=${key}
        Environment=DO_TAG=${tag}
        ExecStartPre=-/usr/bin/docker pull qmxme/drophosts:latest
        ExecStart=/usr/bin/docker run --rm --privileged -e DO_KEY -e DO_TAG -v /etc/hosts:/etc/hosts qmxme/drophosts:latest
    - name: drophosts.timer
      enable: true
      command: start
      content: |
        [Unit]
        Description=Run drophosts.service every 5 minutes

        [Timer]
        OnCalendar=*:0/5
    - name: "kubelet.service"
      command: start
      content: |
        [Service]
        ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests

        Environment=KUBELET_VERSION=${k8s_version}_coreos.0
        Environment="RKT_OPTS=--volume=resolv,kind=host,source=/etc/hosts --mount volume=resolv,target=/etc/hosts"
        ExecStart=/usr/lib/coreos/kubelet-wrapper \
        --api-servers=${apiservers} \
        --network-plugin-dir=/etc/kubernetes/cni/net.d \
        --register-node=true \
        --allow-privileged=true \
        --config=/etc/kubernetes/manifests \
        --hostname-override=$private_ipv4 \
        --cluster-dns=${dns_service_ip} \
        --cluster-domain=cluster.local \
        --tls-cert-file=/etc/kubernetes/ssl/worker.pem \
        --tls-private-key-file=/etc/kubernetes/ssl/worker-key.pem
        Restart=always
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
