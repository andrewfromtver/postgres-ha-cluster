#!/bin/bash

# install additional software
export DEBIAN_FRONTEND=noninteractive
apt-get -y install gnupg2
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" | tee  /etc/apt/sources.list.d/pgdg.list
apt-get update
apt-get -y install postgresql-13 postgresql-client-13 python3-pip python3-dev libpq-dev etcd
pip3 install psycopg2 patroni[etcd]

# setup postgres
pg_ctlcluster 13 main start
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/13/main/postgresql.conf
su postgres << EOF
  psql -c "alter user postgres with password '$POSTGRES_PASSWORD';"
EOF

# stop services
systemctl stop etcd &
systemctl stop patroni &
systemctl stop postgresql &

# setup etcd
echo "\
Description=etcd service
Documentation=https://github.com/coreos/etcd
 
[Service]
User=etcd
Type=notify
ExecStart=/usr/bin/etcd \\
 --name ${NODE_NAME} \\
 --data-dir /var/lib/etcd \\
 --initial-advertise-peer-urls http://${CURRENT_NODE_IP}:2380 \\
 --listen-peer-urls http://${CURRENT_NODE_IP}:2380 \\
 --listen-client-urls http://${CURRENT_NODE_IP}:2379,http://127.0.0.1:2379 \\
 --advertise-client-urls http://${CURRENT_NODE_IP}:2379 \\
 --initial-cluster-token etcd-cluster-1 \\
 --initial-cluster pgnode1=http://${MASTER_IP}:2380,pgnode2=http://${SLAVE_1_IP}:2380,pgnode3=http://${SLAVE_2_IP}:2380 \\
 --initial-cluster-state new \\
 --heartbeat-interval 1000 \\
 --election-timeout 5000
Restart=on-failure
RestartSec=5
 
[Install]
WantedBy=multi-user.target
" > /lib/systemd/system/etcd.service

# setup patroni
echo "\
[Unit]
Description=Runners to orchestrate a high-availability PostgreSQL
After=syslog.target network.target

[Service]
Type=simple
User=postgres
Group=postgres
ExecStart=/usr/local/bin/patroni /etc/patroni.yml
KillMode=process
TimeoutSec=30
Restart=on-abnormal
RestartSec=5s

[Install]
WantedBy=multi-user.targ\
" > /etc/systemd/system/patroni.service

echo "\
scope: pgsql
namespace: /cluster/
name: $NODE_NAME

restapi:
    listen: $CURRENT_NODE_IP:8008
    connect_address: $CURRENT_NODE_IP:8008

etcd:
    hosts: [\"$MASTER_IP:2379\", \"$SLAVE_1_IP:2379\", \"$SLAVE_2_IP:2379\"]

bootstrap:
    dcs:
        ttl: 15
        loop_wait: 10
        retry_timeout: 10
        maximum_lag_on_failover: 1024000
        postgresql:
            use_pg_rewind: true
            use_slots: true
            parameters:
                wal_level: replica
                hot_standby: on
                wal_keep_segments: 5120
                max_wal_senders: 5
                max_replication_slots: 5
                checkpoint_timeout: 10

    initdb:
    - encoding: UTF8
    - data-checksums
    - locale: en_US.UTF8
    pg_hba:
    - host replication postgres 127.0.0.1/32 md5
    - host replication postgres $MASTER_IP/0 md5
    - host replication postgres $SLAVE_1_IP/0 md5
    - host replication postgres $SLAVE_2_IP/0 md5
    - host all all $HA_PROXY_IP/0 md5

    users:
        admin:
            password: admin
            options:
                - createrole
                - createdb

postgresql:
    listen: $CURRENT_NODE_IP:5432
    connect_address: $CURRENT_NODE_IP:5432
    data_dir: /data/patroni
    bin_dir:  /usr/lib/postgresql/13/bin
    pgpass: /tmp/pgpass
    authentication:
        replication:
            username: postgres
            password: $POSTGRES_PASSWORD
        superuser:
            username: postgres
            password: $POSTGRES_PASSWORD
    create_replica_methods:
        basebackup:
            checkpoint: 'fast'
    parameters:
        unix_socket_directories: '.'

        basebackup:
            checkpoint: 'fast'
    parameters:
        unix_socket_directories: '.'

tags:
    nofailover: false
    noloadbalance: false
    clonefrom: false
    nosync: false\
" > /etc/patroni.yml

mkdir -p /data/patroni
chown postgres:postgres /data/patroni
chmod 700 /data/patroni

# realod systemd
systemctl daemon-reload
