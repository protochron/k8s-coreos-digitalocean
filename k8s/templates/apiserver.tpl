#cloud-config
write_files:
  - path: '/etc/kubernetes/ssl/openssl.cnf'
    owner: root
    permissions: 0644
    content: |
      [req]
      req_extensions = v3_req
      distinguished_name = req_distinguished_name
      [req_distinguished_name]
      [ v3_req ]
      basicConstraints = CA:FALSE
      keyUsage = nonRepudiation, digitalSignature, keyEncipherment
      subjectAltName = @alt_names
      [alt_names]
      DNS.1 = kubernetes
      DNS.2 = kubernetes.default
      DNS.3 = kubernetes.default.svc
      DNS.4 = kubernetes.default.svc.cluster.local
      IP.1 = ${dns_service_ip}
      IP.2 = $private_ipv4
  - path: '/etc/kubernetes/ssl/generate_cert'
    owner: root
    permissions: 0644
    content: |
      openssl genrsa -out apiserver-key.pem 2048
      openssl req -new -key apiserver-key.pem -out apiserver.csr -subj "/CN=kube-apiserver" -config openssl.cnf
      openssl x509 -req -in apiserver.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out apiserver.pem -days 365 -extensions v3_req -extfile openssl.cnf
  - path: '/etc/kubernetes/ssl/ca.pem'
    owner: root
    permissions: 0644
    encoding: base64
    content: |
      ${ca}
  - path: '/etc/kubernetes/ssl/ca.key'
    owner: root
    permissions: 0644
    encoding: base64
    content: |
      ${ca_key}
  - path: '/etc/flannel/options.env'
    owner: root
    permissions: 0644
    content: |
      FLANNELD_IFACE=$private_ipv4
      FLANNELD_ETCD_ENDPOINTS=${etcd_servers}
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
  - path: '/etc/kubernetes/manifests/kube-apiserver.yaml'
    owner: root
    permissions: 0644
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: kube-apiserver
        namespace: kube-system
      spec:
        hostNetwork: true
        containers:
          - name: kube-apiserver
            image: quay.io/coreos/hyperkube:${k8s_version}_coreos.0
            command:
            - /hyperkube
            - apiserver
            - --etcd-servers=${etcd_servers}
            - --allow-privileged=true
            - --bind-address=0.0.0.0
            - --insecure-bind-address=0.0.0.0
            - --service-cluster-ip-range=${service_ip_range}
            - --secure-port=443
            - --advertise-address=$private_ipv4
            - --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota
            - --runtime-config=extensions/v1beta1=true,extensions/v1beta1/networkpolicies=true
            ports:
            - containerPort: 443
              hostPort: 443
              name: https
            - containerPort: 8080
              hostPort: 8080
              name: local
            volumeMounts:
            - mountPath: /etc/kubernetes/ssl
              name: ssl-certs-kubernetes
              readOnly: true
            - mountPath: /etc/ssl/certs
              name: ssl-certs-host
              readOnly: true
        volumes:
        - hostPath:
          path: /etc/kubernetes/ssl
          name: ssl-certs-kubernetes
        - hostPath:
          path: /usr/share/ca-certificates
          name: ssl-certs-host
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
          - --master=http://127.0.0.1:8080
          - --proxy-mode=iptables
          securityContext:
            privileged: true
          volumeMounts:
          - mountPath: /etc/ssl/certs
            name: ssl-certs-host
            readOnly: true
        volumes:
        - hostPath:
            path: /usr/share/ca-certificates
          name: ssl-certs-host
  - path: '/etc/kubernetes/manifests/kube-controller-manager.yaml'
    owner: root
    permissions: 0644
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: kube-controller-manager
        namespace: kube-system
      spec:
        hostNetwork: true
        containers:
        - name: kube-controller-manager
          image: quay.io/coreos/hyperkube:${k8s_version}_coreos.0
          command:
          - /hyperkube
          - controller-manager
          - --master=http://127.0.0.1:8080
          - --leader-elect=true
            #- --service-account-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
            #- --root-ca-file=/etc/kubernetes/ssl/ca.pem
          livenessProbe:
            httpGet:
              host: 127.0.0.1
              path: /healthz
              port: 10252
            initialDelaySeconds: 15
            timeoutSeconds: 1
          volumeMounts:
          - mountPath: /etc/kubernetes/ssl
            name: ssl-certs-kubernetes
            readOnly: true
          - mountPath: /etc/ssl/certs
            name: ssl-certs-host
            readOnly: true
        volumes:
        - hostPath:
            path: /etc/kubernetes/ssl
          name: ssl-certs-kubernetes
        - hostPath:
            path: /usr/share/ca-certificates
          name: ssl-certs-host
  - path: '/etc/kubernetes/manifests/kube-scheduler.yaml'
    owner: root
    permissions: 0644
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: kube-scheduler
        namespace: kube-system
      spec:
        hostNetwork: true
        containers:
        - name: kube-scheduler
          image: quay.io/coreos/hyperkube:${k8s_version}_coreos.0
          command:
          - /hyperkube
          - scheduler
          - --master=http://127.0.0.1:8080
          - --leader-elect=true
          livenessProbe:
            httpGet:
              host: 127.0.0.1
              path: /healthz
              port: 10251
            initialDelaySeconds: 15
            timeoutSeconds: 1

#######################
coreos:
  flannel:
    etcd_endpoints: ${etcd_servers}
  units:
    - name: iptables-restore.service
      enable: true
      command: start
    - name: install-kubectl.service
      command: start
      content: |
        [Unit]
        After=network-online.target
        Description=Installs kubectl Binary
        Requires=network-online.target

        [Service]
        Type=oneshot
        ExecStartPre=/bin/mkdir -p /opt/bin
        ExecStart=/usr/bin/curl -sL -o /opt/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${k8s_version}/bin/linux/amd64/kubectl
        ExecStartPost=/usr/bin/chmod a+x /opt/bin/kubectl
        RemainAfterExit=yes
    - name: droplan.service
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
            Environment="DOCKER_OPTS=--storage-driver=overlay --iptables=false"
      command: startfl
    - name: "generate-certificates"
      content: |
        [Unit]
        Description=Generates the apiserver certificate

        [Service]
        Type=oneshot
        ExecStartPre=/bin/chmod +x /etc/kubernetes/ssl/generate_cert
        WorkingDirectory=/etc/kubernetes/ssl
        Exec=./generate_cert
    - name: "kubelet.service"
      command: start
      content: |
        [Service]
        ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests

        Environment=KUBELET_VERSION=${k8s_version}_coreos.0
        ExecStart=/usr/lib/coreos/kubelet-wrapper \
        --api-servers=http://127.0.0.1:8080 \
        --network-plugin-dir=/etc/kubernetes/cni/net.d \
        --register-schedulable=false \
        --allow-privileged=true \
        --config=/etc/kubernetes/manifests \
        --hostname-override=$private_ipv4 \
        --cluster-dns=${dns_service_ip} \
        --cluster-domain=cluster.local
        Restart=always
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
