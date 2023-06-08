# encoding: utf-8
# -*- mode: ruby -*-
# vi: set ft=ruby :

HA_PROXY_RAM = 1024
HA_PROXY_CPU = 1

DB_NODE_RAM = 2048
DB_NODE_CPU = 2

VM_BOX = "generic/debian10"

HA_PROXY_IP = "192.168.56.100"
MASTER_IP = "192.168.56.101"
SLAVE_1_IP = "192.168.56.102"
SLAVE_2_IP = "192.168.56.103"

POSTGRES_PASSWORD = "qwerty12"
ETCD_CLUSTER_TOKEN = "etcdtesttoken"

Vagrant.configure(2) do |config|
  $count = 3
  IP_ARRAY = [MASTER_IP, SLAVE_1_IP, SLAVE_2_IP]
  (1..$count).each do |i|
    config.vm.define "pgnode#{i}" do |pgnode|
      pgnode.vm.box = VM_BOX
      pgnode.vm.provider "virtualbox" do |v|
        v.name = "pg node #{i}"
        v.memory = DB_NODE_RAM
        v.cpus = DB_NODE_CPU
      end
      pgnode.vm.hostname = "pgnode#{i}"
      pgnode.vm.network "private_network", ip: IP_ARRAY[i - 1]
      pgnode.vm.provision "shell", path: 'db_node_init.sh', env: {
        "NODE_NAME" => "pgnode#{i}",
        "ETCD_CLUSTER_TOKEN" => ETCD_CLUSTER_TOKEN,
        "POSTGRES_PASSWORD" => POSTGRES_PASSWORD,
        "HA_PROXY_IP" => HA_PROXY_IP,
        "MASTER_IP" => MASTER_IP,
        "SLAVE_1_IP" => SLAVE_1_IP,
        "SLAVE_2_IP" => SLAVE_2_IP,
        "CURRENT_NODE_IP" => IP_ARRAY[i - 1]
      }
      pgnode.trigger.after :up do
        if(i <= $count) then
          pgnode.vm.provision "shell", inline: <<-SHELL
            systemctl enable etcd &
            systemctl start etcd &
            systemctl enable patroni &
            systemctl start patroni &
          SHELL
        end
        if(i == $count) then
          pgnode.vm.provision "shell", run: 'always', inline: <<-SHELL
            # check cluster status
            etcdctl member list
            patronictl -c /etc/patroni.yml list
          SHELL
        end
      end
    end
  end

  config.vm.define "haproxy" do |haproxy|
    haproxy.vm.box = VM_BOX
    haproxy.vm.provider "virtualbox" do |v|
      v.name = "ha proxy"
      v.memory = HA_PROXY_RAM
      v.cpus = HA_PROXY_CPU
    end
    haproxy.vm.network "private_network", ip: HA_PROXY_IP
    haproxy.vm.provision "shell", path: "ha_proxy_init.sh", env: {
      "MASTER_IP" => MASTER_IP,
      "SLAVE_1_IP" => SLAVE_1_IP,
      "SLAVE_2_IP" => SLAVE_2_IP
    }
  end
end
