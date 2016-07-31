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
          - --kubeconfig=/etc/kubernetes/worker-kubeconfig.yaml
          - --proxy-mode=iptables
          securityContext:
            privileged: true
          volumeMounts:
            - mountPath: /etc/ssl/certs
              name: "ssl-certs"
            - mountPath: /etc/kubernetes/worker-kubeconfig.yaml
              name: "kubeconfig"
              readOnly: true
            - mountPath: /etc/kubernetes/ssl
              name: "etc-kube-ssl"
              readOnly: true
        volumes:
          - name: "ssl-certs"
            hostPath:
              path: "/usr/share/ca-certificates"
          - name: "kubeconfig"
            hostPath:
              path: "/etc/kubernetes/worker-kubeconfig.yaml"
          - name: "etc-kube-ssl"
            hostPath:
              path: "/etc/kubernetes/ssl"

#######################
coreos:
  flannel:
    etcd_endpoints: ${etcd_servers}
  units:
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
            Environment=DOCKER_OPTS='--storage-driver=overlay'
      command: start
    - name: "kubelet.service"
      command: start
      content: |
        [Service]
        ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests

        Environment=KUBELET_VERSION=${k8s_version}_coreos.0
        ExecStart=/usr/lib/coreos/kubelet-wrapper \
        --api-servers=${apiservers} \
        --network-plugin-dir=/etc/kubernetes/cni/net.d \
        --register-node=true \
        --allow-privileged=true \
        --config=/etc/kubernetes/manifests \
        --kubeconfig=/etc/kubernetes/worker-kubeconfig.yaml \
        --hostname-override=$private_ipv4 \
        --cluster-dns=${dns_service_ip} \
        --cluster-domain=cluster.local
        Restart=always
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
