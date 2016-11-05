#cloud-config

coreos:
  etcd2:
    discovery: ${discovery_url}
    advertise-client-urls: http://$private_ipv4:2379
    initial-advertise-peer-urls: http://$private_ipv4:2380
    listen-client-urls: http://$private_ipv4:2379,http://$private_ipv4:4001
    listen-peer-urls: http://$private_ipv4:2380
  units:
    - name: etcd2.service
      command: start
    - name: docker.service
      drop-ins:
        - name: "60-docker-config.conf"
          content: |
            [Service]
            Environment="DOCKER_OPTS=--storage-driver=overlay --iptables=false"
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
