#cloud-config
write_files:
  - path: '/etc/flannel/options.env'
    owner: root
    permissions: 0644
    content: |
      FLANNELD_IFACE=$private_ipv4
      FLANNELD_ETCD_ENDPOINTS=${etcd_servers}
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
      command: start
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
