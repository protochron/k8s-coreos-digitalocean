#cloud-config
write_files:
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
          - --kubeconfig=/etc/kubernetes/worker-kubeconfig.yaml
          securityContext:
            privileged: true
          volumeMounts:
            - mountPath: /etc/ssl/certs
              name: "ssl-certs"
            - mountPath: /etc/kubernetes/ssl
              name: "etc-kube-ssl"
              readOnly: true
            - mountPath: /etc/kubernetes/worker-kubeconfig.yaml
              name: "kubeconfig"
              readOnly: true
        volumes:
          - name: "ssl-certs"
            hostPath:
              path: "/usr/share/ca-certificates"
          - name: "etc-kube-ssl"
            hostPath:
              path: "/etc/kubernetes/ssl"
          - name: "kubeconfig"
            hostPath:
              path: "/etc/kubernetes/worker-kubeconfig.yaml"
  - path: '/etc/kubernetes/worker-kubeconfig.yaml'
    owner: root
    permissions: 0644
    content: |
      apiVersion: v1
      kind: Config
      clusters:
      - name: local
        cluster:
          certificate-authority: /etc/kubernetes/ssl/ca.pem
      users:
      - name: kubelet
        user:
          client-certificate: /etc/kubernetes/ssl/worker.pem
          client-key: /etc/kubernetes/ssl/worker-key.pem
      contexts:
      - context:
          cluster: local
          user: kubelet
        name: kubelet-context
      current-context: kubelet-context

#######################
coreos:
  flannel:
    etcd_endpoints: ${etcd_servers}
  units:
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
        OnCalendar=*:0/2
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
        --node-labels="role=edge-router" \
        --register-schedulable=false \
        --kubeconfig=/etc/kubernetes/worker-kubeconfig.yaml \
        --tls-cert-file=/etc/kubernetes/ssl/worker.pem \
        --tls-private-key-file=/etc/kubernetes/ssl/worker-key.pem
        Restart=always
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
    - name: droplan.service
      enable: true
      content: |
        [Unit]
        Description=updates iptables with peer droplets
        Requires=docker.service

        [Service]
        Type=oneshot
        Environment=DO_KEY=${key}
        ExecStart=/usr/bin/docker run --rm --net=host --cap-add=NET_ADMIN -e DO_KEY tam7t/droplan:latest
    - name: droplan.timer
      enable: true
      command: start
      content: |
        [Unit]
        Description=Run droplan.service every 5 minutes

        [Timer]
        OnCalendar=*:0/5
