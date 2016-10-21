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
            - --admission-control=NamespaceLifecycle,ServiceAccount,LimitRanger,DefaultStorageClass,ResourceQuota
            - --runtime-config=extensions/v1beta1=true,extensions/v1beta1/networkpolicies=true
            - --service-account-key-file=/etc/kubernetes/ssl/service_account.key
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
          - --service-account-private-key-file=/etc/kubernetes/service_account.key
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
  - path: "/etc/kubernetes/manifests/addons.yaml"
    owner: root
    permissions: 0644
    content: |
      apiVersion: v1
      kind: Pod
      metadata:
        name: kube-addon-manager
        namespace: kube-system
        labels:
          component: kube-addon-manager
          version: v4
      spec:
        hostNetwork: true
        containers:
        - name: kube-addon-manager
          # When updating version also bump it in cluster/images/hyperkube/static-pods/addon-manager.json
          image: gcr.io/google-containers/kube-addon-manager:v5.1
          resources:
            requests:
              cpu: 5m
              memory: 50Mi
          volumeMounts:
          - mountPath: /etc/kubernetes/
            name: addons
            readOnly: true
        volumes:
        - hostPath:
            path: /etc/kubernetes/
          name: addons
  - path: "/etc/kubernetes/addons/kube-dns/kube-dns-svc.yaml"
    owner: root
    permissions: 0644
    content: |
      apiVersion: v1
      kind: Service
      metadata:
        name: kube-dns
        namespace: kube-system
        labels:
          k8s-app: kube-dns
          kubernetes.io/cluster-service: "true"
          kubernetes.io/name: "KubeDNS"
      spec:
        selector:
          k8s-app: kube-dns
        clusterIP: 10.3.0.10
        ports:
        - name: dns
          port: 53
          protocol: UDP
        - name: dns-tcp
          port: 53
          protocol: TCP
  - path: "/etc/kubernetes/addons/kube-dns/kube-dns-rc.yaml"
    owner: root
    permissions: 0644
    content: |
      apiVersion: v1
      kind: ReplicationController
      metadata:
        name: kube-dns-v20
        namespace: kube-system
        labels:
          k8s-app: kube-dns
          version: v20
          kubernetes.io/cluster-service: "true"
      spec:
        replicas: 1
        selector:
          k8s-app: kube-dns
          version: v20
        template:
          metadata:
            labels:
              k8s-app: kube-dns
              version: v20
            annotations:
              scheduler.alpha.kubernetes.io/critical-pod: ''
              scheduler.alpha.kubernetes.io/tolerations: '[{"key":"CriticalAddonsOnly", "operator":"Exists"}]'
          spec:
            containers:
            - name: kubedns
              image: gcr.io/google_containers/kubedns-amd64:1.8
              resources:
                limits:
                  memory: 170Mi
                requests:
                  cpu: 100m
                  memory: 70Mi
              livenessProbe:
                httpGet:
                  path: /healthz-kubedns
                  port: 8080
                  scheme: HTTP
                initialDelaySeconds: 60
                timeoutSeconds: 5
                successThreshold: 1
                failureThreshold: 5
              readinessProbe:
                httpGet:
                  path: /readiness
                  port: 8081
                  scheme: HTTP
                initialDelaySeconds: 3
                timeoutSeconds: 5
              args:
              - --domain=cluster.local.
              - --dns-port=10053
              ports:
              - containerPort: 10053
                name: dns-local
                protocol: UDP
              - containerPort: 10053
                name: dns-tcp-local
                protocol: TCP
            - name: dnsmasq
              image: gcr.io/google_containers/kube-dnsmasq-amd64:1.4
              livenessProbe:
                httpGet:
                  path: /healthz-dnsmasq
                  port: 8080
                  scheme: HTTP
                initialDelaySeconds: 60
                timeoutSeconds: 5
                successThreshold: 1
                failureThreshold: 5
              args:
              - --cache-size=1000
              - --no-resolv
              - --server=127.0.0.1#10053
              - --log-facility=-
              ports:
              - containerPort: 53
                name: dns
                protocol: UDP
              - containerPort: 53
                name: dns-tcp
                protocol: TCP
            - name: healthz
              image: gcr.io/google_containers/exechealthz-amd64:1.2
              resources:
                limits:
                  memory: 50Mi
                requests:
                  cpu: 10m
                  memory: 50Mi
              args:
              - --cmd=nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
              - --url=/healthz-dnsmasq
              - --cmd=nslookup kubernetes.default.svc.cluster.local 127.0.0.1:10053 >/dev/null
              - --url=/healthz-kubedns
              - --port=8080
              - --quiet
              ports:
              - containerPort: 8080
                protocol: TCP
            dnsPolicy: Default

#######################
coreos:
  flannel:
    etcd_endpoints: ${etcd_servers}
  units:
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
    - name: gen-service-account-key.service
      command: start
      content: |
        [Unit]
        Description=Generates a key for the default service account

        [Service]
        Type=oneshot
        ExecStartPre=/bin/mkdir -p /etc/kubernetes
        ExecStart=/bin/openssl genrsa -out /etc/kubernetes/service_account.key 2048
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
