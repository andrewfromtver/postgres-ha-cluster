#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
apt-get -y install haproxy

echo "\
global
  maxconn 100

defaults
  log global
  mode tcp
  retries 2
  timeout client 30m
  timeout connect 4s
  timeout server 30m
  timeout check 5s

listen stats
  mode http
  bind *:80
  stats enable
  stats uri /

listen postgres
  bind *:5432
  option httpchk
  http-check expect status 200
  default-server inter 3s fall 3 rise 2 on-marked-down shutdown-sessions
  server pgnode1 $MASTER_IP:5432 maxconn 100 check port 8008
  server pgnode2 $SLAVE_1_IP:5432 maxconn 100 check port 8008
  server pgnode3 $SLAVE_2_IP:5432 maxconn 100 check port 8008
" > /etc/haproxy/haproxy.cfg

systemctl restart haproxy
